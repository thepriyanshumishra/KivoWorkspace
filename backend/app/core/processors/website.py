# app/core/processors/website.py
# Purpose: Web page content extraction and chunking pipeline.
# Responsibilities: Fetches website content, isolates the main body container, strips boilerplate elements (menus, navbars, sidebars, scripts, ads), converts HTML to clean plaintext with preserved table structure, and chunks the result.

import json
import logging
import requests
from bs4 import BeautifulSoup
from pathlib import Path
from typing import Dict, Any

from app.core.config import settings

logger = logging.getLogger("kivo.processors.website")

class WebsiteProcessor:
    def __init__(self, chunk_size: int = 1000, chunk_overlap: int = 200):
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap

    def _html_to_clean_text(self, element) -> str:
        """
        Recursively converts HTML elements to clean, human-readable plain text,
        preserving table cell formatting (tab-separated) and list structures,
        while stripping all raw HTML tags.
        """
        if not element:
            return ""
        if element.name in ["script", "style", "nav", "footer", "header", "aside", "iframe", "noscript"]:
            return ""
            
        # Format tables cleanly as tab-separated values
        if element.name == "table":
            table_text = []
            for row in element.find_all("tr"):
                row_cells = []
                cells = row.find_all(["td", "th"], recursive=False)
                if not cells:
                    continue
                for cell in cells:
                    cell_txt = " ".join(cell.get_text().split())
                    row_cells.append(cell_txt)
                table_text.append("\t".join(row_cells))
            return "\n".join(table_text) + "\n"
            
        if isinstance(element, str):
            return element
            
        text_parts = []
        for child in element.children:
            child_text = self._html_to_clean_text(child)
            if child_text:
                text_parts.append(child_text)
                
        name = element.name
        if name == "tr":
            return "".join(text_parts).strip() + "\n"
        elif name in ["td", "th"]:
            cleaned = " ".join("".join(text_parts).split())
            return cleaned + "\t"
        elif name in ["p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "li", "ul", "ol", "pre", "blockquote", "section", "article"]:
            joined = "".join(text_parts)
            if name == "li":
                joined = "* " + joined.strip()
            return joined.strip() + "\n"
        elif name == "br":
            return "\n"
        else:
            return "".join(text_parts)

    def process(self, url: str, workspace_id: str, source_id: str) -> Dict[str, Any]:
        """
        Fetches webpage HTML, isolates the main content block, strips boilerplate elements,
        classes, and IDs, converts HTML to clean plaintext, splits plaintext into chunks, and saves them to disk.
        """
        logger.info(f"Processing Website URL: {url}")
        
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        
        try:
            # 1. Fetch web content
            response = requests.get(url, headers=headers, timeout=15)
            response.raise_for_status()
            html_content = response.text
        except Exception as e:
            logger.error(f"Failed to fetch webpage at {url}: {e}")
            raise RuntimeError(f"Failed to fetch webpage: {e}")
            
        # 2. Parse HTML and extract Title
        soup = BeautifulSoup(html_content, "html.parser")
        title = soup.title.string.strip() if soup.title else "Website Source"
        
        # 3. Isolate the main content container to bypass headers, footers, left/right sidebars
        main_content = None
        
        # Look for semantic main or article tags
        for tag_name in ["main", "article"]:
            main_content = soup.find(tag_name)
            if main_content:
                logger.info(f"Isolating content using semantic tag <{tag_name}>")
                break
                
        # If not found, look for common main/content IDs
        if not main_content:
            for id_name in ["main", "content", "main-content", "article-body", "post-body"]:
                main_content = soup.find(id=id_name)
                if main_content:
                    logger.info(f"Isolating content using container ID '{id_name}'")
                    break
                    
        # If not found, look for common main/content classes
        if not main_content:
            for class_name in ["main", "content", "main-content", "article", "post"]:
                main_content = soup.find(class_=class_name)
                if main_content:
                    logger.info(f"Isolating content using container class '{class_name}'")
                    break

        # Fallback to body or whole soup if no specific main container was found
        content_node = main_content if main_content else (soup.body if soup.body else soup)
        
        # 4. Strip boilerplate semantic elements
        boilerplate_tags = ["script", "style", "nav", "footer", "header", "aside", "iframe", "noscript"]
        for element in content_node(boilerplate_tags):
            element.decompose()
            
        # 5. Strip class / ID based boilerplate (e.g. sidebars, navbars, menus, ads, socials, pagers)
        blacklist_keywords = [
            "sidebar", "navbar", "footer", "header", "menu", "ad-", "adsense",
            "leaderboard", "nextprev", "prevnext", "pager", "pagination",
            "breadcrumb", "share", "social", "banner", "signup", "login", "signin"
        ]
        
        all_elements = list(content_node.find_all(True))
        for element in all_elements:
            if element.parent is None:
                continue
                
            elem_id = element.get("id", "")
            if isinstance(elem_id, str):
                elem_id = elem_id.lower()
                if any(x in elem_id for x in blacklist_keywords):
                    element.decompose()
                    continue
            
            elem_classes = element.get("class", [])
            if isinstance(elem_classes, list):
                elem_classes = [c.lower() for c in elem_classes if isinstance(c, str)]
                if any(any(x in c for x in blacklist_keywords) for c in elem_classes):
                    element.decompose()
                    continue
            
        # 6. Convert clean body HTML to clean plaintext preserving structure
        try:
            clean_text = self._html_to_clean_text(content_node)
        except Exception as e:
            logger.error(f"Error extracting plaintext: {e}")
            clean_text = content_node.get_text()
            
        # Post-process to remove multiple newlines but preserve tabs
        raw_lines = clean_text.splitlines()
        cleaned_lines = []
        for line in raw_lines:
            trimmed = line.strip()
            if trimmed:
                # Strip spaces around tab-separated fields
                parts = [p.strip() for p in line.split("\t")]
                cleaned_lines.append("\t".join(parts))
                
        final_text = "\n".join(cleaned_lines).strip()
            
        if not final_text:
            final_text = f"Empty page content for URL: {url}"
            
        # 7. Split plaintext into overlapping chunks
        chunks = []
        chunk_idx = 0
        text_len = len(final_text)
        start = 0
        
        while start < text_len:
            end = min(start + self.chunk_size, text_len)
            chunk_text = final_text[start:end].strip()
            if chunk_text:
                chunks.append({
                    "index": chunk_idx,
                    "text": chunk_text,
                    "metadata": {"url": url}
                })
                chunk_idx += 1
            start += (self.chunk_size - self.chunk_overlap)
            
        # 8. Save chunks to storage/workspaces/<workspace_id>/chunks/<source_id>.json
        workspace_dir = settings.workspaces_dir / workspace_id
        chunks_dir = workspace_dir / "chunks"
        chunks_dir.mkdir(parents=True, exist_ok=True)
        chunks_file = chunks_dir / f"{source_id}.json"
        
        with open(chunks_file, "w", encoding="utf-8") as f:
            json.dump(chunks, f, indent=2)
            
        # 9. Generate summary preview (first 300 characters of the extracted text)
        summary = final_text[:300].strip() + ("..." if len(final_text) > 300 else "")
        total_words = len(final_text.split())
        
        logger.info(f"Website processed: '{title}', {total_words} words, {len(chunks)} chunks generated.")
        
        return {
            "title": title,
            "stats": {
                "pages": 1,
                "words": total_words,
                "chunks": len(chunks)
            },
            "summary": summary
        }
