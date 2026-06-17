# app/core/processors/embeddings.py
# Purpose: Local text embedding generation pipeline.
# Responsibilities:
#   1. Loads Alibaba-NLP/gte-multilingual-base model once (singleton pattern).
#   2. Auto-detects acceleration (MPS for Apple Silicon, CUDA for GPU, CPU fallback).
#   3. Generates high-accuracy multilingual embeddings for text chunks.
#   4. Cache vectors to disk as .npy files to allow incremental updates.

import logging
from pathlib import Path
from typing import Dict, Any, List
import json
import numpy as np

from app.core.config import settings

logger = logging.getLogger("kivo.processors.embeddings")

# Singleton instance of the model to avoid loading 610MB model weights repeatedly
_model_instance = None

def get_embedding_model():
    """
    Lazy-loads and caches the GTE-Multilingual-Base model in memory.
    Ensures hardware acceleration (MPS/CUDA) is utilized.
    """
    global _model_instance
    if _model_instance is not None:
        return _model_instance

    from sentence_transformers import SentenceTransformer
    import torch
    import platform

    # Determine best device
    # Note: PyTorch MPS backend can crash/segfault with exit code 139 on certain custom transformer operations
    # in gte-multilingual-base. We force CPU on macOS to ensure 100% stability.
    if torch.cuda.is_available():
        device = "cuda"
    else:
        device = "cpu"

    logger.info(f"Loading Alibaba-NLP/gte-multilingual-base model onto device: {device}")
    
    # Load model (gte-multilingual-base requires trust_remote_code=True for custom architectures)
    _model_instance = SentenceTransformer(
        "Alibaba-NLP/gte-multilingual-base",
        trust_remote_code=True,
        device=device
    )
    logger.info("Embedding model loaded successfully.")
    return _model_instance


class EmbeddingProcessor:
    def __init__(self):
        pass

    def process(self, workspace_id: str, source_id: str) -> Dict[str, Any]:
        """
        Loads the chunks from SQLite for the given source, computes embeddings for
        all chunks, and saves them to a NumPy binary file for cached storage.
        """
        workspace_dir = settings.workspaces_dir / workspace_id
        if not workspace_dir.exists():
            logger.warning(f"Workspace directory {workspace_dir} does not exist. Aborting embedding generation.")
            return {
                "source_id": source_id,
                "chunks_count": 0,
                "embedding_dim": 0,
                "cached": False
            }
        
        # Ensure directories exist
        embeddings_dir = workspace_dir / "embeddings"
        embeddings_dir.mkdir(parents=True, exist_ok=True)
        npy_file = embeddings_dir / f"{source_id}.npy"

        # Check if embeddings are already cached on disk (incremental indexing)
        if npy_file.exists():
            logger.info(f"Embeddings cache hit for source {source_id}. Skipping generation.")
            # Load from cache to verify shape and return stats
            cached_vectors = np.load(npy_file)
            return {
                "source_id": source_id,
                "chunks_count": len(cached_vectors),
                "embedding_dim": cached_vectors.shape[1],
                "cached": True
            }

        # Load text chunks from SQLite database
        from app.core.database import get_child_chunks
        try:
            chunks = get_child_chunks(workspace_id, source_id)
        except Exception as e:
            logger.error(f"Failed to load child chunks from SQLite for source {source_id}: {e}")
            chunks = []

        if not chunks:
            logger.info(f"No chunks found for source {source_id}. Skipping embeddings.")
            return {
                "source_id": source_id,
                "chunks_count": 0,
                "embedding_dim": 0,
                "cached": False
            }

        texts = [chunk["text"] for chunk in chunks]
        
        # Get singleton model
        model = get_embedding_model()

        logger.info(f"Encoding {len(texts)} chunks for source {source_id}...")
        
        # Generate normalized embeddings (so Inner Product matches Cosine Similarity in FAISS)
        embeddings = model.encode(
            texts,
            batch_size=16,
            show_progress_bar=False,
            normalize_embeddings=True
        )
        
        # Save as float32 NumPy array
        vectors = np.array(embeddings, dtype=np.float32)
        np.save(npy_file, vectors)

        logger.info(f"Saved {len(vectors)} vectors of shape {vectors.shape} to {npy_file}")

        return {
            "source_id": source_id,
            "chunks_count": len(vectors),
            "embedding_dim": vectors.shape[1],
            "cached": False
        }
