# app/core/processors/pdf.py
# Purpose: PDF text extraction and chunking pipeline.
# Responsibilities: Uses PyMuPDF (fitz) to extract text page-by-page, chunk it, and save chunks to disk.

import fitz  # PyMuPDF
import json
import logging
from pathlib import Path
from typing import Dict, Any, List

logger = logging.getLogger("kivo.processors.pdf")

class PDFProcessor:
    def __init__(self, chunk_size: int = 1000, chunk_overlap: int = 200):
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap

    def process(self, file_path: Path, workspace_id: str, source_id: str) -> Dict[str, Any]:
        """
        Extracts text from PDF, splits it into overlapping chunks page-by-page,
        saves chunks to disk, and returns statistics and preview summary.
        """
        logger.info(f"Processing PDF file: {file_path}")
        
        if not file_path.exists():
            raise FileNotFoundError(f"PDF file not found at {file_path}")
            
        doc = fitz.open(file_path)
        page_count = len(doc)
        total_words = 0
        total_chars = 0
        
        # 1. Extract text page by page
        pages_text = []
        for page_num in range(page_count):
            page = doc[page_num]
            text = page.get_text("text")  # Extract clean layout text
            pages_text.append(text)
            
            # Update stats
            total_words += len(text.split())
            total_chars += len(text)
            
        # 2. Chunk text page-by-page to preserve precise page boundaries for citations
        chunks = []
        chunk_idx = 0
        
        for page_num, page_text in enumerate(pages_text):
            page_text_len = len(page_text)
            if page_text_len == 0:
                continue
                
            # If the page text fits inside a single chunk size, just add it.
            if page_text_len <= self.chunk_size:
                chunks.append({
                    "index": chunk_idx,
                    "text": page_text.strip(),
                    "metadata": {"page": page_num + 1}
                })
                chunk_idx += 1
                continue
                
            # Otherwise, split page text into overlapping chunks
            start = 0
            while start < page_text_len:
                end = min(start + self.chunk_size, page_text_len)
                chunk_text = page_text[start:end].strip()
                if chunk_text:
                    chunks.append({
                        "index": chunk_idx,
                        "text": chunk_text,
                        "metadata": {"page": page_num + 1}
                    })
                    chunk_idx += 1
                
                # Slide window
                start += (self.chunk_size - self.chunk_overlap)
                
        # 3. Save chunks to storage/workspaces/<workspace_id>/chunks/<source_id>.json
        # The file_path is storage/workspaces/<workspace_id>/sources/<filename>
        # So file_path.parent is 'sources' directory, and file_path.parent.parent is '<workspace_id>' directory
        chunks_dir = file_path.parent.parent / "chunks"
        chunks_dir.mkdir(parents=True, exist_ok=True)
        chunks_file = chunks_dir / f"{source_id}.json"
        
        with open(chunks_file, "w") as f:
            json.dump(chunks, f, indent=2)
            
        # 4. Generate summary preview (first 300 characters of the document)
        preview_text = ""
        for page_text in pages_text:
            if page_text.strip():
                preview_text += page_text.strip() + " "
                if len(preview_text) > 300:
                    break
        summary = preview_text[:300].strip() + ("..." if len(preview_text) > 300 else "")
        
        doc.close()
        
        logger.info(f"PDF processed: {page_count} pages, {total_words} words, {len(chunks)} chunks generated.")
        return {
            "stats": {
                "pages": page_count,
                "words": total_words,
                "chunks": len(chunks)
            },
            "summary": summary
        }
