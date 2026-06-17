# app/core/retriever.py
import torch  # Prevent OpenMP/MKL conflict with faiss on macOS
import re
import json
import time
import logging
from pathlib import Path
from typing import Dict, Any, List, Tuple
import numpy as np
import faiss
import requests

from app.core.config import settings
from app.core.processors.embeddings import get_embedding_model

logger = logging.getLogger("kivo.core.retriever")

# Broad retrieval keywords regex
INTENT_REGEX = re.compile(
    r"\b(list\s+every|find\s+all|retrieve\s+all|timeline\s+of|summarize\s+references\s+to|discuss\s+all|retrieve\s+every|find\s+content\s+connected\s+to|find\s+every|retrieve\s+information|retrieve\s+content)\b",
    re.IGNORECASE
)

# Token estimation helper
def estimate_tokens(text: str) -> int:
    return int(len(text.split()) * 1.3)

STANDARD_QA_PROMPT = """You are a helpful assistant. Answer the user's question based strictly on the provided context.
If the context does not contain enough information to answer the question, state that you cannot answer based on the provided context.
Do not make up facts or assume anything not mentioned.

If the workspace system instructions specify a custom language (e.g. Hindi, French, Spanish, German, etc.) or formatting constraint, you MUST translate the facts from the context and write your entire response (including explanations and sentences) strictly in that requested language/format.

Format your response using professional Markdown. To make your response easy to read, visual, and well-structured:
1. Use bold text to highlight key concepts, terms, or actions.
2. Use bulleted lists for unordered points, and numbered lists for sequences or steps. Use lettered sub-bullets (a, b, c) if nesting is required.
3. Use tables when presenting comparative data, key-value pairs, or structured details.
4. Use code blocks with the appropriate language tag (e.g. ```bash, ```python, etc.) for commands, code snippets, or configuration.
5. Use italics for emphasis, definitions, or quotes.

For every factual claim you make, you MUST cite the chunk ID of the context where the information was found using the format [chunk_id] (e.g. [source_id_p0]) at the end of the sentence or statement.

At the very end of your response, you MUST suggest exactly 3 relevant follow-up questions the user can ask next about the content. Format them strictly inside a <followup> tag like this:
<followup>
- Question 1?
- Question 2?
- Question 3?
</followup>

Context:
{context}

Question:
{question}

Answer:"""

META_RETRIEVAL_PROMPT = """You are a retrieval and synthesis assistant. The user is asking for a comprehensive list or summary of references across the entire knowledge base.
Analyze the provided context chunks, aggregate all relevant instances, and synthesize them.

If the workspace system instructions specify a custom language (e.g. Hindi, French, Spanish, German, etc.) or formatting constraint, you MUST translate the facts from the context and write your entire response (including explanations and sentences) strictly in that requested language/format.

Format your response using professional Markdown. To make your response easy to read, visual, and well-structured:
1. Use bold text to highlight key concepts, terms, or actions.
2. Use bulleted lists for unordered points, and numbered lists for sequences or steps. Use lettered sub-bullets (a, b, c) if nesting is required.
3. Use tables when presenting comparative data, key-value pairs, or structured details.
4. Use code blocks with the appropriate language tag (e.g. ```bash, ```python, etc.) for commands, code snippets, or configuration.
5. Use italics for emphasis, definitions, or quotes.

For every factual claim you make, you MUST cite the chunk ID of the context where the information was found using the format [chunk_id] (e.g. [source_id_p0]) at the end of the sentence or statement.

At the very end of your response, you MUST suggest exactly 3 relevant follow-up questions the user can ask next about the content. Format them strictly inside a <followup> tag like this:
<followup>
- Question 1?
- Question 2?
- Question 3?
</followup>

Context:
{context}

Question:
{question}

Answer:"""

def sanitize_response(answer: str, source_id_to_name: Dict[str, str] = None) -> Tuple[str, List[Dict[str, Any]], str]:
    """
    Removes XML tags, maps raw citations like [source_id_p0] to sequential footnotes like [1], [2],
    and returns the clean answer with footnotes, the citations metadata, and a completely plain text answer (no citations).
    """
    import re
    
    # 1. Remove XML tags like <chunk ...> and </chunk>
    answer_clean = re.sub(r'</?chunk[^>]*>', '', answer)
    
    # Find all raw citation tags like [uuid_p0] or [uuid_c0]
    raw_citations = re.findall(r'\[([a-zA-Z0-9_-]+_[pc]\d+)\]', answer_clean)
    
    unique_citations = []
    for cit in raw_citations:
        if cit not in unique_citations:
            unique_citations.append(cit)
            
    citations_meta = []
    answer_footnoted = answer_clean
    answer_plain = answer_clean
    
    for i, cit in enumerate(unique_citations, 1):
        # Extract source_id from composite citation id: source_id_pX or source_id_cX
        source_id = None
        if "_p" in cit:
            source_id = cit.split("_p")[0]
        elif "_c" in cit:
            source_id = cit.split("_c")[0]
            
        source_name = "Source Document"
        if source_id and source_id_to_name and source_id in source_id_to_name:
            source_name = source_id_to_name[source_id]
            
        citations_meta.append({
            "index": i,
            "raw_id": cit,
            "source_id": source_id,
            "source_name": source_name
        })
        
        # Replace raw citation with sequential footnote
        answer_footnoted = answer_footnoted.replace(f"[{cit}]", f"[{i}]")
        # Strip raw citation completely for plain text version
        answer_plain = answer_plain.replace(f"[{cit}]", "")
        
    # Clean up excessive spacing
    answer_footnoted = re.sub(r' +', ' ', answer_footnoted).strip()
    answer_plain = re.sub(r' +', ' ', answer_plain).strip()
    
    # Clean up spaces before punctuation (e.g. "word ." -> "word.")
    for char in ['.', ',', ';', '?', '!']:
        answer_footnoted = answer_footnoted.replace(f" {char}", char)
        answer_plain = answer_plain.replace(f" {char}", char)
        
    return answer_footnoted, citations_meta, answer_plain

def retrieve_and_generate(
    workspace_id: str,
    question: str,
    model_name: str = "qwen2.5:1.5b",
    max_parent_tokens: int = 3500
) -> Dict[str, Any]:
    """
    Executes the Sprint 12 SQLite-based RAG Pipeline:
    1. Dynamic Intent Routing: Detect standard QA vs Meta-Retrieval.
    2. Vector Search & DB Lookup: Retrieve child chunks from FAISS index and fetch texts from SQLite.
    3. Parent Reconstruction & Budgeting: Map child chunks to parents via SQLite batch queries,
       deduplicate, and reconstruct parent context up to max_parent_tokens.
    4. Model Generation: Query Ollama with intent-specific prompts.
    5. Claim Sanitization: Strip XML tags, map citation markers sequentially, and construct metadata.
    """
    t_start = time.time()
    workspace_dir = settings.workspaces_dir / workspace_id
    index_file = workspace_dir / "index.faiss"

    if not index_file.exists():
        logger.warning(f"Workspace {workspace_id} FAISS index not built.")
        return {
            "question": question,
            "answer": "Error: Knowledge base index is not compiled. Please process your sources first.",
            "plain_answer": "Error: Knowledge base index is not compiled.",
            "citations": [],
            "child_ids": [],
            "parent_ids": [],
            "retrieved_child_chunks": [],
            "retrieved_parent_chunks": [],
            "routing_mode": "ERROR",
            "latency_ms": int((time.time() - t_start) * 1000)
        }

    # 1. Intent Routing
    routing_mode = "STANDARD_QA"
    k = 5
    system_prompt = STANDARD_QA_PROMPT
    if INTENT_REGEX.search(question):
        routing_mode = "META_RETRIEVAL"
        k = 10
        system_prompt = META_RETRIEVAL_PROMPT

    logger.info(f"Question routed to {routing_mode} (Top-K={k})")

    # Load FAISS index
    index = faiss.read_index(str(index_file))

    # 2. Vector Search (Child Chunks)
    model = get_embedding_model()
    query_emb = model.encode([question], normalize_embeddings=True)[0]
    query_contiguous = query_emb.copy().astype(np.float32)
    faiss.normalize_L2(query_contiguous.reshape(1, -1))

    scores, indices = index.search(query_contiguous.reshape(1, -1), k)

    valid_indices = [int(idx) for idx in indices[0] if idx >= 0]

    # Load matching child chunks from SQLite
    from app.core.database import get_child_chunks_by_global_indices, get_parent_chunks_by_ids
    db_chunks = get_child_chunks_by_global_indices(workspace_id, valid_indices)
    chunks_by_global_idx = {c["global_vector_index"]: c for c in db_chunks}

    # Collect unique parent chunks sorted by similarity
    retrieved_child_chunks = []
    parent_keys_seen = set()
    parent_records = []  # List of {"score": float, "parent_id": str}

    for rank, (score, chunk_idx) in enumerate(zip(scores[0], indices[0]), 1):
        chunk_idx_int = int(chunk_idx)
        if chunk_idx_int in chunks_by_global_idx:
            c_chunk = chunks_by_global_idx[chunk_idx_int]
            source_id = c_chunk["source_id"]
            parent_id = c_chunk["parent_id"]
            
            c_record = {
                "rank": rank,
                "score": float(score),
                "id": c_chunk["id"],
                "text": c_chunk["text"],
                "parent_id": parent_id
            }
            retrieved_child_chunks.append(c_record)

            if parent_id is not None:
                if parent_id not in parent_keys_seen:
                    parent_keys_seen.add(parent_id)
                    parent_records.append({
                        "score": float(score),
                        "parent_id": parent_id
                    })

    # Sort parent records in descending order of child chunk similarity score
    parent_records.sort(key=lambda x: x["score"], reverse=True)

    # 3. Load Parents and enforce budget
    parent_ids = [r["parent_id"] for r in parent_records if r["parent_id"] is not None]
    db_parents = get_parent_chunks_by_ids(workspace_id, parent_ids)
    parents_by_id = {p["id"]: p["text"] for p in db_parents}

    context_parts = []
    retrieved_parent_chunks = []
    current_tokens = 0
    parent_ids_used = []

    for p_rec in parent_records:
        p_id = p_rec["parent_id"]
        if p_id in parents_by_id:
            p_text = parents_by_id[p_id]
            p_tokens = estimate_tokens(p_text)
            
            # Check context budget
            if current_tokens + p_tokens > max_parent_tokens:
                logger.info(f"Parent chunk {p_id} ({p_tokens} tokens) excluded. Adding it would exceed budget ({current_tokens + p_tokens} > {max_parent_tokens}).")
                continue

            current_tokens += p_tokens
            context_parts.append(f'<chunk id="{p_id}">\n{p_text}\n</chunk>')
            parent_ids_used.append(p_id)
            retrieved_parent_chunks.append({
                "id": p_id,
                "text": p_text,
                "score": p_rec["score"]
            })

    context_str = "\n".join(context_parts)

    # 4. Load Custom Workspace Instructions
    instructions = ""
    metadata_file = workspace_dir / "metadata.json"
    if metadata_file.exists():
        try:
            with open(metadata_file, "r") as f:
                meta_data = json.load(f)
                instructions = meta_data.get("instructions", "").strip()
        except Exception as e:
            logger.error(f"Failed to read instructions from metadata for {workspace_id}: {e}")

    # Inject workspace instructions if present
    if instructions:
        # 1. Top Reinforcement: prepend to system prompt
        system_prompt = f"CRITICAL WORKSPACE SYSTEM INSTRUCTIONS:\n- {instructions}\n\n" + system_prompt
        # 2. Bottom Reinforcement: append directly above Answer:
        instruction_block = f"\nCRITICAL CUSTOM INSTRUCTION (Apply this strictly to your answer): {instructions}\n"
        system_prompt = system_prompt.replace("Answer:", f"{instruction_block}\nAnswer:")

    prompt = system_prompt.format(context=context_str, question=question)
    url = f"{settings.ollama_base_url}/api/generate"
    payload = {
        "model": model_name,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": 0.0
        }
    }

    raw_answer = ""
    try:
        response = requests.post(url, json=payload, timeout=180)
        if response.status_code == 200:
            result = response.json()
            raw_answer = result.get("response", "").strip()
        else:
            raw_answer = f"Error: Ollama returned status code {response.status_code}"
    except Exception as e:
        raw_answer = f"Error calling Ollama API: {e}"

    # Parse recommended follow-up questions from Ollama response
    recommended_questions = []
    followup_match = re.search(r'<followup>(.*?)</followup>', raw_answer, re.DOTALL | re.IGNORECASE)
    if followup_match:
        followup_content = followup_match.group(1)
        # Find lines starting with a bullet or number
        for line in followup_content.split('\n'):
            line_clean = line.strip().lstrip('-').lstrip('*').strip()
            if line_clean:
                # Remove leading numbers like "1. "
                line_clean = re.sub(r'^\d+\.\s*', '', line_clean).strip()
                if line_clean:
                    recommended_questions.append(line_clean)
        # Remove the <followup> tag and its contents from the raw answer
        raw_answer = raw_answer.replace(followup_match.group(0), "").strip()

    # Generate robust fallbacks if Ollama didn't output the followup questions
    if len(recommended_questions) < 3:
        q_lower = question.lower()
        if "git" in q_lower or "github" in q_lower:
            recommended_questions = [
                "What is a git branch and how do I create one?",
                "What is the difference between git merge and git rebase?",
                "How do I configure a remote repository on GitHub?"
            ]
        elif "summary" in q_lower or "about" in q_lower or "what is" in q_lower:
            recommended_questions = [
                "What are the most important sections of this document?",
                "Can you list the key concepts explained in this file?",
                "Who are the main figures or organizations discussed?"
            ]
        else:
            recommended_questions = [
                "Can you explain the main points of this document in detail?",
                "What are the key terms or definitions used here?",
                "Provide a bulleted summary of this reference."
            ]
    recommended_questions = recommended_questions[:3]

    # Load sources to get source names for citation metadata
    from app.api.routes.sources import load_sources
    try:
        sources = load_sources(workspace_id)
        source_id_to_name = {s.id: s.name for s in sources}
    except Exception:
        source_id_to_name = {}

    # 5. Claim Sanitization
    answer_footnoted, citations_meta, answer_plain = sanitize_response(raw_answer, source_id_to_name)

    latency_ms = int((time.time() - t_start) * 1000)

    return {
        "question": question,
        "answer": answer_footnoted,
        "plain_answer": answer_plain,
        "citations": citations_meta,
        "child_ids": [c["id"] for c in retrieved_child_chunks],
        "parent_ids": parent_ids_used,
        "retrieved_child_chunks": retrieved_child_chunks,
        "retrieved_parent_chunks": retrieved_parent_chunks,
        "routing_mode": routing_mode,
        "latency_ms": latency_ms,
        "recommended_questions": recommended_questions
    }
