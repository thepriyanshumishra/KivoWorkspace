# run_dual_model_evaluation.py
# Purpose: Script to execute the dual-model retrieval and generation evaluation.
# Responsibilities:
#   1. Ingests, chunks, embeds, and indexes the sample text.
#   2. Runs FAISS retrieval for the 60 benchmark questions (Top-K=3, 768-d).
#   3. Queries local Ollama for Llama 3.2 1B and Qwen 2.5 1.5B for each question.
#   4. Measures latency and answer lengths.
#   5. Saves results to raw_dual_model_evaluation.json.
#   6. Cleans up the temporary workspace.

import os
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["VECLIB_MAXIMUM_THREADS"] = "1"
os.environ["NUMEXPR_NUM_THREADS"] = "1"
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"
import sys
import json
import time
import shutil
import logging
from pathlib import Path
import numpy as np

# Set up logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(name)s | %(message)s")
logger = logging.getLogger("kivo.evaluation")

# Set sys.path so we can import app
sys.path.insert(0, str(Path(__file__).parent.absolute()))

import torch
import faiss
import requests

from app.core.config import settings
from app.core.processors.text import TextProcessor
from app.core.processors.embeddings import EmbeddingProcessor, get_embedding_model
from app.core.processors.vector_db import VectorDBProcessor

# Sample Text
SAMPLE_TEXT = """The Evolution of Artificial Intelligence

Artificial Intelligence (AI) is one of the most transformative technologies developed by humanity. Although modern AI systems have become widely popular only in recent years, the foundations of the field were established decades ago. The concept of machines performing intelligent tasks can be traced back to ancient myths and mechanical inventions, but the scientific study of AI began in the mid-20th century.

In 1950, British mathematician and computer scientist Alan Turing published a paper titled Computing Machinery and Intelligence. In this work, he proposed what later became known as the Turing Test, a method for evaluating whether a machine could exhibit behavior indistinguishable from that of a human. Turing's ideas significantly influenced future AI research.

The term Artificial Intelligence was officially coined in 1956 during the Dartmouth Summer Research Project on Artificial Intelligence. Researchers believed that human intelligence could be precisely described and simulated by machines. Early optimism led many scientists to predict rapid progress toward human-level intelligence.

During the 1960s and 1970s, AI research focused heavily on symbolic reasoning systems. These systems relied on explicitly programmed rules to solve problems. Expert systems emerged as one of the most successful applications of symbolic AI. They were capable of making decisions in specialized domains such as medical diagnosis and industrial troubleshooting.

However, progress was slower than expected. Computers lacked sufficient processing power, and many real-world problems proved too complex for rule-based approaches. This led to periods known as "AI winters," during which funding and public interest declined significantly.

The resurgence of AI began in the 1990s and accelerated in the 2000s due to three major factors: increased computational power, the availability of large datasets, and advances in machine learning algorithms. Unlike symbolic systems, machine learning models learn patterns directly from data rather than relying entirely on manually written rules.

One notable milestone occurred in 1997 when IBM's Deep Blue defeated world chess champion Garry Kasparov. This event demonstrated the growing capabilities of computational systems in specialized tasks.

The emergence of deep learning marked another turning point. Deep learning uses artificial neural networks inspired by the structure of the human brain. These networks contain multiple layers capable of learning hierarchical representations of data. Breakthroughs in image recognition, speech recognition, and natural language processing followed.

In 2012, a deep neural network known as AlexNet achieved remarkable success in the ImageNet competition, significantly reducing image classification error rates. This achievement is often considered the beginning of the modern deep learning revolution.

Natural Language Processing (NLP) experienced major advances with the introduction of transformer architectures. Transformers rely on self-attention mechanisms that allow models to process relationships between words more effectively than previous recurrent neural network approaches.

The transformer architecture was introduced in 2017 through the paper Attention Is All You Need. This innovation enabled the development of increasingly powerful language models capable of generating coherent text, answering questions, translating languages, and assisting with software development.

Large Language Models (LLMs) are trained on vast amounts of text data collected from books, articles, websites, and other sources. During training, models learn statistical relationships between words, phrases, and concepts. Although these models can generate highly convincing responses, they do not possess human consciousness or genuine understanding.

Modern AI systems are now deployed across numerous industries. Healthcare organizations use AI for medical imaging analysis, drug discovery, and patient risk assessment. Financial institutions employ AI for fraud detection, algorithmic trading, and credit scoring. Manufacturing companies use predictive maintenance systems to reduce equipment downtime.

Transportation has also been transformed by AI technologies. Autonomous vehicle research combines computer vision, sensor fusion, planning algorithms, and machine learning to navigate complex environments. While fully autonomous vehicles remain a challenging goal, substantial progress continues.

Ethical considerations have become increasingly important as AI capabilities grow. Researchers and policymakers debate issues including algorithmic bias, privacy, accountability, transparency, intellectual property, labor displacement, and the societal impact of automation.

Algorithmic bias can emerge when training data contains historical inequalities or lacks sufficient diversity. As a result, AI systems may produce unfair outcomes for certain groups. Addressing bias requires careful dataset design, testing procedures, and ongoing monitoring.

Privacy concerns arise because many AI systems rely on large amounts of user data. Organizations must balance innovation with responsible data governance practices. Regulations in various countries seek to establish standards for data protection and AI deployment.

Another significant concern involves misinformation. Generative AI systems can create realistic text, images, audio, and videos. While these capabilities offer many beneficial applications, they also create opportunities for deception, fraud, and manipulation.

The future of AI remains uncertain. Some experts predict the development of Artificial General Intelligence (AGI), a hypothetical system capable of performing any intellectual task that a human can perform. Others argue that current approaches may face fundamental limitations that require entirely new breakthroughs.

Regardless of the ultimate trajectory, AI is likely to remain one of the most influential technologies of the 21st century. Its impact will depend not only on technical innovation but also on governance, ethics, education, and society's collective choices regarding how these systems are developed and used."""

# Evaluation Questions
QUESTIONS = [
    # Level 1: Basic Retrieval Questions
    "Who proposed the Turing Test?",
    "In which year was the Dartmouth conference held?",
    "What defeated Garry Kasparov in 1997?",
    "What competition made AlexNet famous?",
    "What are the three factors that accelerated AI progress in the 2000s?",
    "What does NLP stand for?",
    "In which year was the transformer architecture introduced?",
    "What paper introduced transformers?",
    "What does AGI stand for?",
    "Name two industries that use AI today.",
    
    # Level 2: Semantic Retrieval Questions
    "Which historical event is considered the beginning of modern deep learning?",
    "Why did early rule-based AI systems struggle?",
    "What made machine learning different from symbolic AI?",
    "Which technology allows transformers to understand relationships between words?",
    "Why are autonomous vehicles difficult to build?",
    "What concerns arise from AI-generated media?",
    "Why is dataset diversity important?",
    "What factors contributed to AI winters?",
    "How do LLMs acquire knowledge?",
    "What challenges exist in deploying AI responsibly?",
    
    # Level 3: Multi-Hop Questions
    "How did improvements in computing power influence the success of deep learning?",
    "Explain the relationship between ImageNet, AlexNet, and modern AI development.",
    "Why did AI experience periods of decline before eventually succeeding?",
    "How are privacy concerns connected to the growth of large language models?",
    "What combination of technologies is required for autonomous vehicles?",
    "Compare symbolic AI and machine learning approaches.",
    "How did the transformer architecture contribute to the rise of LLMs?",
    "What factors influence whether AI benefits society?",
    "How can algorithmic bias emerge and be mitigated?",
    "Explain the progression from the Turing Test to modern generative AI.",
    
    # Level 4: Complex Reasoning Questions
    "If computational power had not improved significantly after the 1990s, how might AI development have differed?",
    "Why might a healthcare organization be especially concerned about algorithmic bias?",
    "What trade-offs exist between AI innovation and user privacy?",
    "Why do some experts believe AGI may require fundamentally new breakthroughs?",
    "How could misinformation generated by AI affect public trust?",
    "What characteristics distinguish deep learning from traditional expert systems?",
    "Why was the transformer architecture more effective than recurrent neural networks for many NLP tasks?",
    "How might labor markets change as AI adoption increases?",
    "Why is governance considered as important as technological advancement?",
    "What lessons can modern AI researchers learn from previous AI winters?",
    
    # Level 5: Hard RAG Evaluation Questions
    "Which paragraph indirectly explains why GPUs became important for AI?",
    "What chain of events connects the Dartmouth conference to modern LLMs?",
    "What evidence in the text suggests that AI progress is not purely a technical issue?",
    "Which sections would be most relevant for writing a policy paper on AI regulation?",
    "Which concepts appear in both healthcare and ethics discussions?",
    "What information supports the argument that AI is both beneficial and risky?",
    "If you wanted to predict future AI adoption trends, which sections should be retrieved together?",
    "Which technological developments were prerequisites for transformer-based systems?",
    "What evidence argues against the idea that LLMs truly understand language?",
    "Construct a timeline of at least eight major AI milestones mentioned in the text.",
    
    # Embedding Stress Tests (Very Difficult)
    "Find all passages related to 'limitations of AI' even though the exact phrase never appears.",
    "Retrieve every chunk discussing 'data' regardless of context.",
    "Retrieve content related to 'decision making' across different industries.",
    "Find all sections discussing 'trust'.",
    "Find content connected to 'human intelligence' even when not explicitly using those words.",
    "Retrieve all chunks that could support a debate about AI regulation.",
    "Find every paragraph that contains a cause-and-effect relationship.",
    "Retrieve information relevant to 'risk management.'",
    "Find all passages discussing uncertainty about the future.",
    "What factors contributed to the resurgence of AI, and how did those factors later enable transformers and LLMs?"
]

def query_ollama(model_name: str, context: str, question: str) -> tuple:
    prompt = f"""You are a helpful assistant. Answer the user's question based strictly on the provided context. If the answer cannot be found in the context, say "I cannot answer based on the provided context." Do not make up facts.

Context:
{context}

Question:
{question}

Answer:"""
    
    url = f"{settings.ollama_base_url}/api/generate"
    payload = {
        "model": model_name,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": 0.0
        }
    }
    
    t0 = time.time()
    try:
        response = requests.post(url, json=payload, timeout=180)
        latency = time.time() - t0
        if response.status_code == 200:
            result = response.json()
            return result.get("response", "").strip(), latency
        else:
            return f"Error: Ollama returned status code {response.status_code}", latency
    except Exception as e:
        latency = time.time() - t0
        return f"Error calling Ollama API: {e}", latency

def run_evaluation():
    workspace_id = "eval_dual_model_ws"
    source_id = "eval_dual_source_id"
    
    workspace_dir = settings.workspaces_dir / workspace_id
    shutil.rmtree(workspace_dir, ignore_errors=True)
    workspace_dir.mkdir(parents=True, exist_ok=True)
    
    # Create sources directory
    sources_dir = workspace_dir / "sources"
    sources_dir.mkdir(parents=True, exist_ok=True)
    
    # Write the sample text file
    txt_file_path = sources_dir / "evolution_of_ai.txt"
    with open(txt_file_path, "w", encoding="utf-8") as f:
        f.write(SAMPLE_TEXT)
        
    logger.info(f"Saved sample text to {txt_file_path}")
    
    # Create sources.json metadata
    sources_metadata = [
        {
            "name": "The Evolution of Artificial Intelligence",
            "type": "text",
            "id": source_id,
            "path": str(txt_file_path.relative_to(settings.storage_dir.parent)),
            "url": None,
            "added_at": "2026-06-17T00:00:00.000000Z",
            "size_bytes": len(SAMPLE_TEXT.encode("utf-8")),
            "status": "ready"
        }
    ]
    
    with open(workspace_dir / "sources.json", "w", encoding="utf-8") as f:
        json.dump(sources_metadata, f, indent=2)
    
    # 1. Run Chunking (TextProcessor - Boundary-aware Sprint 10)
    logger.info("Step 1: Chunking the text document...")
    text_processor = TextProcessor(chunk_size=1000, chunk_overlap=200)
    text_processor.process(txt_file_path, workspace_id, source_id)
    
    # 2. Run Embedding Generation (EmbeddingProcessor)
    logger.info("Step 2: Generating GTE embeddings...")
    emb_processor = EmbeddingProcessor()
    emb_processor.process(workspace_id, source_id)
    
    # 3. Run Vector DB Index Compilation (VectorDBProcessor - 768-d Sprint 10)
    logger.info("Step 3: Compiling FAISS index at 768-d...")
    vdb_processor = VectorDBProcessor(dimension=768)
    vdb_processor.process(workspace_id)
    
    # Load index and chunks
    index_file = workspace_dir / "index.faiss"
    index = faiss.read_index(str(index_file))
    
    with open(workspace_dir / "chunk_map.json", "r", encoding="utf-8") as f:
        chunk_map = json.load(f)
        
    model = get_embedding_model()
    eval_results = []
    
    logger.info("Step 4: Running question-by-question RAG generation...")
    for idx, question in enumerate(QUESTIONS, 1):
        logger.info(f"Evaluating Question {idx}/{len(QUESTIONS)}: {question}")
        
        # Retrieval
        query_emb = model.encode([question], normalize_embeddings=True)[0]
        query_contiguous = query_emb.copy().astype(np.float32)
        faiss.normalize_L2(query_contiguous.reshape(1, -1))
        
        # Search Top K = 3
        k = 3
        scores, indices = index.search(query_contiguous.reshape(1, -1), k)
        
        retrieved_chunks = []
        context_parts = []
        for rank, (score, chunk_idx) in enumerate(zip(scores[0], indices[0]), 1):
            if chunk_idx >= 0 and chunk_idx < len(chunk_map):
                c_text = chunk_map[chunk_idx]["text"]
                retrieved_chunks.append({
                    "rank": rank,
                    "score": float(score),
                    "text": c_text,
                    "chunk_index": chunk_map[chunk_idx]["chunk_index"]
                })
                context_parts.append(c_text)
                
        context_str = "\n\n---\n\n".join(context_parts)
        
        # Generate with Llama
        llama_answer, llama_latency = query_ollama("llama3.2:1b", context_str, question)
        
        # Generate with Qwen
        qwen_answer, qwen_latency = query_ollama("qwen2.5:1.5b", context_str, question)
        
        eval_results.append({
            "number": idx,
            "question": question,
            "retrieved": retrieved_chunks,
            "llama": {
                "answer": llama_answer,
                "latency_s": llama_latency
            },
            "qwen": {
                "answer": qwen_answer,
                "latency_s": qwen_latency
            }
        })
        
    # Save raw results
    raw_output_path = Path("/Users/thedarkpcm/.gemini/antigravity/brain/c5dc8fba-7b42-49be-9c39-1e8e2ed4bf2b/raw_dual_model_evaluation.json")
    with open(raw_output_path, "w", encoding="utf-8") as f:
        json.dump(eval_results, f, indent=2)
        
    logger.info(f"Saved raw evaluation results to {raw_output_path}")
    
    # Cleanup workspace
    shutil.rmtree(workspace_dir, ignore_errors=True)
    logger.info("Cleanup completed: Temporary evaluation workspace deleted.")
    
    print("SUCCESS: Dual-model evaluation execution complete.")

if __name__ == "__main__":
    run_evaluation()
