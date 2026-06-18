# app/models/chat.py
# Purpose: Pydantic schemas for RAG workspace query / chat.
# Responsibilities: Defines validation models for chat requests and responses.

from pydantic import BaseModel, Field
from typing import List, Optional

class Citation(BaseModel):
    index: int = Field(..., description="Sequential footnote index")
    raw_id: str = Field(..., description="Raw chunk ID in context (e.g. source_id_p0)")
    source_id: Optional[str] = Field(None, description="Original source document ID")
    source_name: str = Field("Source Document", description="Human-readable source name")

class ChatRequest(BaseModel):
    message: str = Field(..., description="The user question to the workspace RAG pipeline", min_length=1)
    is_strict: bool = Field(True, description="Strict source-based mode toggle")
    temperature: Optional[float] = Field(None, description="LLM Temperature override")
    similarity_threshold: Optional[float] = Field(None, description="RAG similarity threshold override")
    ollama_url: Optional[str] = Field(None, description="Ollama API base URL override")
    model_name: Optional[str] = Field(None, description="Ollama LLM model override")

class ChatResponse(BaseModel):
    answer: str = Field(..., description="Footnoted answer from the model")
    plain_answer: str = Field(..., description="Answer stripped of citation markers")
    citations: List[Citation] = Field(..., description="List of citation footnotes mapped to source documents")
    latency_ms: int = Field(..., description="Total processing latency in milliseconds")
    recommended_questions: List[str] = Field(default_factory=list, description="Follow-up recommended questions")

class UniversalChatRequest(BaseModel):
    message: str = Field(..., description="The user question to search across workspaces", min_length=1)
    workspace_ids: List[str] = Field(..., description="List of workspace IDs to include in search scope")
    is_strict: bool = Field(True, description="Strict source-based mode toggle")
    temperature: Optional[float] = Field(None, description="LLM Temperature override")
    similarity_threshold: Optional[float] = Field(None, description="RAG similarity threshold override")
    ollama_url: Optional[str] = Field(None, description="Ollama API base URL override")
    model_name: Optional[str] = Field(None, description="Ollama LLM model override")
