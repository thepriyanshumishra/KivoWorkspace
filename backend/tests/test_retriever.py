import sys
from pathlib import Path

# Add backend directory to sys.path
backend_path = Path(__file__).resolve().parents[1]
sys.path.append(str(backend_path))

from app.core.retriever import sanitize_response, estimate_tokens

def test_estimate_tokens():
    assert estimate_tokens("hello world") == int(2 * 1.3)
    assert estimate_tokens("") == 0

def test_sanitize_response_empty():
    answer_footnoted, citations_meta, answer_plain = sanitize_response("")
    assert answer_footnoted == ""
    assert citations_meta == []
    assert answer_plain == ""

def test_sanitize_response_no_citations():
    text = "This is a clean response with no citations."
    answer_footnoted, citations_meta, answer_plain = sanitize_response(text)
    assert answer_footnoted == text
    assert citations_meta == []
    assert answer_plain == text

def test_sanitize_response_with_chunk_tags():
    text = "This is <chunk id=\"1\">important</chunk> info."
    answer_footnoted, citations_meta, answer_plain = sanitize_response(text)
    assert answer_footnoted == "This is important info."
    assert citations_meta == []
    assert answer_plain == "This is important info."

def test_sanitize_response_with_citations():
    text = "Here is some fact [source_123_p0]. And another one [source_123_c1]."
    source_map = {"source_123": "My Document.pdf"}
    
    answer_footnoted, citations_meta, answer_plain = sanitize_response(text, source_map)
    
    # Check footnoted text has replaced citation tags with sequential indices
    assert "[1]" in answer_footnoted
    assert "[2]" in answer_footnoted
    assert "[source_123_p0]" not in answer_footnoted
    
    # Check plain text has stripped citation tags completely
    assert "[1]" not in answer_plain
    assert "[source_123_p0]" not in answer_plain
    
    # Check metadata structure
    assert len(citations_meta) == 2
    assert citations_meta[0]["index"] == 1
    assert citations_meta[0]["raw_id"] == "source_123_p0"
    assert citations_meta[0]["source_id"] == "source_123"
    assert citations_meta[0]["source_name"] == "My Document.pdf"
