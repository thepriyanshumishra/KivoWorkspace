# app/core/config.py
# Purpose: Application configuration for Kivo Workspace backend.
# Inputs: Environment variables (optional).
# Outputs: Settings instance used across the application.
# Responsibilities: Defines configurable settings with sensible defaults.

from pydantic_settings import BaseSettings
from pathlib import Path


class Settings(BaseSettings):
    """
    Kivo Workspace Backend Configuration.
    All settings have sensible defaults for local development.
    """

    # --- Application ---
    app_name: str = "Kivo Workspace API"
    app_version: str = "1.0.0"
    debug: bool = False

    # --- Storage ---
    # Root storage directory, relative to backend/
    storage_dir: Path = Path("storage")
    workspaces_dir: Path = Path("storage/workspaces")

    # --- Ollama ---
    ollama_base_url: str = "http://localhost:11434"
    ollama_default_model: str = "qwen2.5:1.5b"
    ollama_fallback_model: str = "llama3.2:1b"

    # --- Retrieval ---
    retrieval_top_k_default: int = 5
    retrieval_top_k_max: int = 10

    # --- Chunking ---
    chunk_size: int = 1000
    chunk_overlap: int = 200

    # --- Whisper ---
    whisper_model: str = "base"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


# Singleton settings instance used throughout the app
settings = Settings()
