# app/api/routes/chat.py
# Purpose: APIRouter for workspace chat/query operations.
# Responsibilities: Exposes query endpoint to invoke RAG engine retrieve_and_generate.

from fastapi import APIRouter, HTTPException, Path
import logging

from app.core.retriever import retrieve_and_generate
from app.models.chat import ChatRequest, ChatResponse

logger = logging.getLogger("kivo.chat")
router = APIRouter()

@router.post("", response_model=ChatResponse)
def query_workspace(
    workspace_id: str = Path(..., description="The workspace ID"),
    payload: ChatRequest = ...
):
    """
    Query the workspace RAG pipeline.
    Retrieves relevant parent chunks and generates a cited answer using Ollama.
    """
    logger.info(f"Received query for workspace {workspace_id}: '{payload.message}'")
    try:
        res = retrieve_and_generate(
            workspace_id=workspace_id,
            question=payload.message
        )
        if res.get("routing_mode") == "ERROR" or res["answer"].startswith("Error"):
            # Check if it was a real connection error or missing index
            raise HTTPException(status_code=500, detail=res["answer"])
            
        return ChatResponse(
            answer=res["answer"],
            plain_answer=res["plain_answer"],
            citations=res["citations"],
            latency_ms=res["latency_ms"]
        )
    except Exception as e:
        logger.error(f"Error querying workspace {workspace_id}: {e}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"RAG query failed: {e}")
