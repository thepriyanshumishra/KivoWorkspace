# main.py
# Purpose: FastAPI application entry point for Kivo Workspace backend.
# Inputs: HTTP requests from the Flutter frontend.
# Outputs: JSON responses.
# Responsibilities: Creates FastAPI app, configures CORS, registers routers,
#                   ensures storage directories exist on startup.

import os
import shutil
import requests
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["VECLIB_MAXIMUM_THREADS"] = "1"
os.environ["NUMEXPR_NUM_THREADS"] = "1"
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings

# --- Logging Setup ---
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("kivo")


def run_diagnostics():
    """Runs non-blocking startup sanity checks for dependencies."""
    logger.info("--- Starting Kivo Diagnostics ---")
    
    # 1. Check FFmpeg
    ffmpeg_path = shutil.which("ffmpeg")
    if ffmpeg_path:
        logger.info(f"[DIAGNOSTIC] FFmpeg binary found: {ffmpeg_path}")
    else:
        logger.warning("[DIAGNOSTIC WARNING] FFmpeg was NOT found on system PATH. Audio transcription and YouTube processing will fail. Please install ffmpeg.")

    # 2. Check Tesseract
    tesseract_path = shutil.which("tesseract")
    if tesseract_path:
        logger.info(f"[DIAGNOSTIC] Tesseract OCR binary found: {tesseract_path}")
    else:
        logger.warning("[DIAGNOSTIC WARNING] Tesseract was NOT found on system PATH. Image OCR processing will fail. Please install tesseract-ocr.")

    # 3. Check Ollama
    try:
        ollama_url = f"{settings.ollama_base_url}/api/tags"
        response = requests.get(ollama_url, timeout=3)
        if response.status_code == 200:
            models_data = response.json()
            models_list = [m.get("name") for m in models_data.get("models", [])]
            logger.info(f"[DIAGNOSTIC] Ollama service is active. Available models: {models_list}")
            
            # Check default model
            default_model = settings.ollama_default_model
            if default_model in models_list or any(default_model in m for m in models_list):
                logger.info(f"[DIAGNOSTIC] Default LLM model '{default_model}' is available in Ollama.")
            else:
                logger.warning(f"[DIAGNOSTIC WARNING] Default LLM model '{default_model}' is NOT pulled in Ollama. Please run: ollama pull {default_model}")
        else:
            logger.warning(f"[DIAGNOSTIC WARNING] Ollama service returned status code {response.status_code}.")
    except Exception as e:
        logger.warning(f"[DIAGNOSTIC WARNING] Could not connect to Ollama service at {settings.ollama_base_url}. Is Ollama running? Error: {e}")
        
    logger.info("--- Diagnostics Completed ---")


# --- Startup / Shutdown Lifecycle ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan handler.
    Runs setup tasks on startup and cleanup on shutdown.
    """
    # Ensure storage directories exist
    settings.storage_dir.mkdir(parents=True, exist_ok=True)
    settings.workspaces_dir.mkdir(parents=True, exist_ok=True)
    logger.info("Storage directories verified.")
    
    # Run startup diagnostic checks
    run_diagnostics()
    
    logger.info(f"Kivo Workspace API v{settings.app_version} started.")
    logger.info(f"Ollama target: {settings.ollama_base_url}")
    logger.info(f"Default model: {settings.ollama_default_model}")

    yield

    logger.info("Kivo Workspace API shutting down.")


# --- FastAPI Application ---
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="Edge-first AI Knowledge Workspace Backend",
    lifespan=lifespan,
)


# --- CORS Middleware ---
# Allows Flutter desktop app (running on localhost) to communicate with the API.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restricted to localhost in production builds
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Core Routes ---
@app.get("/", tags=["Root"])
async def root():
    """API root — returns basic app info."""
    return {
        "app": settings.app_name,
        "version": settings.app_version,
        "status": "running",
    }


@app.get("/health", tags=["Health"])
async def health_check():
    """
    Health check endpoint.
    Used by the Flutter frontend to verify the backend is reachable.
    """
    return {"status": "ok"}


# --- Router Registration ---
from app.api.routes.workspaces import router as workspaces_router
from app.api.routes.sources import router as sources_router
from app.api.routes.processing import router as processing_router
from app.api.routes.chat import router as chat_router

app.include_router(workspaces_router, prefix="/workspaces", tags=["Workspaces"])
app.include_router(sources_router, prefix="/workspaces/{workspace_id}/sources", tags=["Sources"])
app.include_router(processing_router, prefix="/workspaces/{workspace_id}/processing", tags=["Processing"])
app.include_router(chat_router, prefix="/workspaces/{workspace_id}/chat", tags=["Chat"])



