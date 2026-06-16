# app/core/processors/text.py
# Purpose: Copied text content chunking pipeline.
# Responsibilities: Reads saved raw copied text, chunks it, and saves the chunks to disk.

import json
import logging
from pathlib import Path
from typing import Dict, Any

from app.core.config import settings

logger = logging.getLogger("kivo.processors.text")

class TextProcessor:
    def __init__(self, chunk_size: int = 1000, chunk_overlap: int = 200):
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap

    def process(self, file_path: Path, workspace_id: str, source_id: str) -> Dict[str, Any]:
        """
        Reads raw copied text, splits it into overlapping chunks,
        saves them to disk, and returns statistics and preview summary.
        """
        logger.info(f"Processing Text file: {file_path}")
        
        if not file_path.exists():
            raise FileNotFoundError(f"Text file not found at {file_path}")
            
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read().strip()
        except Exception as e:
            logger.error(f"Failed to read text file at {file_path}: {e}")
            raise RuntimeError(f"Failed to read text file: {e}")
            
        if not content:
            content = "Empty text content."
            
        # Split text into overlapping chunks
        chunks = []
        chunk_idx = 0
        text_len = len(content)
        start = 0
        
        while start < text_len:
            end = min(start + self.chunk_size, text_len)
            chunk_text = content[start:end].strip()
            if chunk_text:
                chunks.append({
                    "index": chunk_idx,
                    "text": chunk_text,
                    "metadata": {"source": "pasted_text"}
                })
                chunk_idx += 1
            start += (self.chunk_size - self.chunk_overlap)
            
        # Save chunks to storage/workspaces/<workspace_id>/chunks/<source_id>.json
        workspace_dir = settings.workspaces_dir / workspace_id
        chunks_dir = workspace_dir / "chunks"
        chunks_dir.mkdir(parents=True, exist_ok=True)
        chunks_file = chunks_dir / f"{source_id}.json"
        
        with open(chunks_file, "w", encoding="utf-8") as f:
            json.dump(chunks, f, indent=2)
            
        summary = content[:300].strip() + ("..." if len(content) > 300 else "")
        total_words = len(content.split())
        
        logger.info(f"Text processed: {total_words} words, {len(chunks)} chunks generated.")
        
        return {
            "stats": {
                "pages": 1,  # Text documents are represented as a single virtual page
                "words": total_words,
                "chunks": len(chunks)
            },
            "summary": summary
        }
