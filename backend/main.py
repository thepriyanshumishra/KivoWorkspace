# main.py
# Purpose: FastAPI application entry point for Kivo Workspace backend.
# Inputs: HTTP requests from the Flutter frontend.
# Outputs: JSON responses.
# Responsibilities: Creates FastAPI app, configures CORS, registers routers,
#                   ensures storage directories exist on startup.

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

app.include_router(workspaces_router, prefix="/workspaces", tags=["Workspaces"])
app.include_router(sources_router, prefix="/workspaces/{workspace_id}/sources", tags=["Sources"])
app.include_router(processing_router, prefix="/workspaces/{workspace_id}/processing", tags=["Processing"])



