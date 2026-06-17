# app/core/retriever.py
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
If the context contains partial information, synthesize it logically and state what is missing.
Only state that you cannot answer if the retrieved context is completely irrelevant to the topic.
Do not make up facts. Answer in a direct and concise manner.

For every factual claim you make, you MUST cite the chunk ID of the context where the information was found using the format [chunk_id] (e.g. [source_id_p0]) at the end of the sentence or statement.

Context:
{context}

Question:
{question}

Answer:"""

META_RETRIEVAL_PROMPT = """You are a retrieval and synthesis assistant. The user is asking for a comprehensive list or summary of references across the entire knowledge base.
Analyze the provided context chunks, aggregate all relevant instances, and synthesize them into a clean, structured list.
Identify each instance clearly. Do not extrapolate beyond the provided text.

For every factual claim you make, you MUST cite the chunk ID of the context where the information was found using the format [chunk_id] (e.g. [source_id_p0]) at the end of the sentence or statement.

Context:
{context}

Question:
{question}

Answer:"""

def retrieve_and_generate(
    workspace_id: str,
    question: str,
    model_name: str = "qwen2.5:1.5b",
    max_parent_tokens: int = 3500
) -> Dict[str, Any]:
    """
    Executes the Sprint 11 RAG Pipeline:
    1. Dynamic Intent Routing: Detect standard QA vs Meta-Retrieval.
    2. Vector Search: Retrieve child chunks from FAISS index.
    3. Parent Reconstruction & Budgeting: Map child chunks to parents, deduplicate,
       and reconstruct parent context up to max_parent_tokens.
    4. Model Generation: Query Ollama with intent-specific prompts.
    """
    t_start = time.time()
    workspace_dir = settings.workspaces_dir / workspace_id
    index_file = workspace_dir / "index.faiss"
    chunk_map_file = workspace_dir / "chunk_map.json"

    if not index_file.exists() or not chunk_map_file.exists():
        logger.warning(f"Workspace {workspace_id} index or chunk map not built.")
        return {
            "question": question,
            "answer": "Error: Knowledge base index is not compiled. Please process your sources first.",
            "child_ids": [],
            "parent_ids": [],
            "retrieved_child_chunks": [],
            "retrieved_parent_chunks": [],
            "routing_mode": "ERROR",
            "latency_ms": int((time.time() - t_start) * 1000)
        }

    # 1. Intent Routing
    routing_mode = "STANDARD_QA"
    k = 3
    system_prompt = STANDARD_QA_PROMPT
    if INTENT_REGEX.search(question):
        routing_mode = "META_RETRIEVAL"
        k = 10
        system_prompt = META_RETRIEVAL_PROMPT

    logger.info(f"Question routed to {routing_mode} (Top-K={k})")

    # Load FAISS index and chunk map
    index = faiss.read_index(str(index_file))
    with open(chunk_map_file, "r", encoding="utf-8") as f:
        chunk_map = json.load(f)

    # 2. Vector Search (Child Chunks)
    model = get_embedding_model()
    query_emb = model.encode([question], normalize_embeddings=True)[0]
    query_contiguous = query_emb.copy().astype(np.float32)
    faiss.normalize_L2(query_contiguous.reshape(1, -1))

    scores, indices = index.search(query_contiguous.reshape(1, -1), k)

    # Collect unique parent chunks sorted by similarity
    retrieved_child_chunks = []
    parent_keys_seen = set()
    parent_records = []  # List of {"score": float, "source_id": str, "parent_id": int}

    # Cache loaded parent json files to avoid re-reading disk
    parent_cache = {}

    for rank, (score, chunk_idx) in enumerate(zip(scores[0], indices[0]), 1):
        if chunk_idx >= 0 and chunk_idx < len(chunk_map):
            c_chunk = chunk_map[chunk_idx]
            source_id = c_chunk["source_id"]
            p_id = c_chunk["metadata"].get("parent_id")
            
            c_record = {
                "rank": rank,
                "score": float(score),
                "id": f"{source_id}_c{c_chunk['chunk_index']}",
                "text": c_chunk["text"],
                "parent_id": f"{source_id}_p{p_id}" if p_id is not None else None
            }
            retrieved_child_chunks.append(c_record)

            if p_id is not None:
                p_key = (source_id, p_id)
                if p_key not in parent_keys_seen:
                    parent_keys_seen.add(p_key)
                    parent_records.append({
                        "score": float(score),
                        "source_id": source_id,
                        "parent_id": p_id
                    })

    # Sort parent records in descending order of child chunk similarity score
    parent_records.sort(key=lambda x: x["score"], reverse=True)

    # 3. Load Parents and enforce budget
    context_parts = []
    retrieved_parent_chunks = []
    current_tokens = 0
    parent_ids_used = []

    for p_rec in parent_records:
        src_id = p_rec["source_id"]
        p_id = p_rec["parent_id"]

        # Load parent texts for this source
        if src_id not in parent_cache:
            p_file = workspace_dir / "parent_chunks" / f"{src_id}.json"
            if p_file.exists():
                try:
                    with open(p_file, "r", encoding="utf-8") as f:
                        parent_cache[src_id] = json.load(f)
                except Exception as e:
                    logger.error(f"Failed to load parent chunks for source {src_id}: {e}")
                    parent_cache[src_id] = []
            else:
                parent_cache[src_id] = []

        src_parents = parent_cache[src_id]
        if p_id >= 0 and p_id < len(src_parents):
            p_text = src_parents[p_id]
            p_tokens = estimate_tokens(p_text)
            
            # Check context budget
            if current_tokens + p_tokens > max_parent_tokens:
                logger.info(f"Parent chunk {src_id}_p{p_id} ({p_tokens} tokens) excluded. Adding it would exceed budget ({current_tokens + p_tokens} > {max_parent_tokens}).")
                continue

            current_tokens += p_tokens
            parent_id = f"{src_id}_p{p_id}"
            context_parts.append(f'<chunk id="{parent_id}">\n{p_text}\n</chunk>')
            parent_ids_used.append(parent_id)
            retrieved_parent_chunks.append({
                "id": parent_id,
                "text": p_text,
                "score": p_rec["score"]
            })

    context_str = "\n".join(context_parts)

    # 4. Ollama Generation
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

    answer = ""
    try:
        response = requests.post(url, json=payload, timeout=60)
        if response.status_code == 200:
            result = response.json()
            answer = result.get("response", "").strip()
        else:
            answer = f"Error: Ollama returned status code {response.status_code}"
    except Exception as e:
        answer = f"Error calling Ollama API: {e}"

    latency_ms = int((time.time() - t_start) * 1000)

    return {
        "question": question,
        "answer": answer,
        "child_ids": [c["id"] for c in retrieved_child_chunks],
        "parent_ids": parent_ids_used,
        "retrieved_child_chunks": retrieved_child_chunks,
        "retrieved_parent_chunks": retrieved_parent_chunks,
        "routing_mode": routing_mode,
        "latency_ms": latency_ms
    }
