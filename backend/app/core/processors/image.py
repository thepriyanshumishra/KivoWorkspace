# app/core/processors/image.py
# Purpose: Image OCR text extraction and chunking pipeline.
# Responsibilities: Uses Pillow to read dimensions, pytesseract to run OCR, chunks text, and saves chunks to disk.

from PIL import Image
import pytesseract
import json
import logging
from pathlib import Path
from typing import Dict, Any

logger = logging.getLogger("kivo.processors.image")

class ImageProcessor:
    def __init__(self, chunk_size: int = 1000, chunk_overlap: int = 200):
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap

    def process(self, file_path: Path, workspace_id: str, source_id: str) -> Dict[str, Any]:
        """
        Extracts text from an image using OCR (Tesseract), splits it into overlapping chunks,
        saves chunks to disk, and returns statistics and preview summary.
        """
        logger.info(f"Processing Image file: {file_path}")
        
        if not file_path.exists():
            raise FileNotFoundError(f"Image file not found at {file_path}")
            
        # 1. Open image and get dimensions & extract text via OCR
        try:
            with Image.open(file_path) as img:
                width, height = img.size
                extracted_text = pytesseract.image_to_string(img)
        except Exception as e:
            logger.error(f"Failed to run Tesseract OCR on {file_path}: {e}")
            raise RuntimeError(f"OCR processing failed: {e}")
            
        # Clean extracted text
        clean_text = extracted_text.strip()
        total_words = len(clean_text.split())
        total_chars = len(clean_text)
        
        # 2. Chunk text using a sliding window
        chunks = []
        chunk_idx = 0
        
        if total_chars > 0:
            if total_chars <= self.chunk_size:
                chunks.append({
                    "index": chunk_idx,
                    "text": clean_text,
                    "metadata": {"image_dimensions": f"{width}x{height}"}
                })
                chunk_idx += 1
            else:
                start = 0
                while start < total_chars:
                    end = min(start + self.chunk_size, total_chars)
                    chunk_text = clean_text[start:end].strip()
                    if chunk_text:
                        chunks.append({
                            "index": chunk_idx,
                            "text": chunk_text,
                            "metadata": {"image_dimensions": f"{width}x{height}"}
                        })
                        chunk_idx += 1
                    
                    # Slide window
                    start += (self.chunk_size - self.chunk_overlap)
                    
        # 3. Save chunks to storage/workspaces/<workspace_id>/chunks/<source_id>.json
        chunks_dir = file_path.parent.parent / "chunks"
        chunks_dir.mkdir(parents=True, exist_ok=True)
        chunks_file = chunks_dir / f"{source_id}.json"
        
        with open(chunks_file, "w") as f:
            json.dump(chunks, f, indent=2)
            
        # 4. Generate summary preview (first 300 characters of the document)
        summary = clean_text[:300].strip() + ("..." if total_chars > 300 else "")
        
        logger.info(f"Image processed: {width}x{height}, {total_words} words, {len(chunks)} chunks generated.")
        return {
            "stats": {
                "width": width,
                "height": height,
                "words": total_words,
                "chunks": len(chunks)
            },
            "summary": summary
        }
