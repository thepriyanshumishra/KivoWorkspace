# app/api/routes/sources.py
# Purpose: APIRouter for workspace sources.
# Responsibilities: Handles file uploads, YouTube URL registration, source listing, and deletion.

from fastapi import APIRouter, HTTPException, Path, UploadFile, File, Body
import shutil
import json
import uuid
import logging
import re
from datetime import datetime, timezone
from pathlib import Path as FilePath
from typing import List

from urllib.parse import urlparse
from app.core.config import settings
from app.models.source import Source, YouTubeCreate, WebsiteCreate, TextCreate
from app.api.routes.workspaces import get_workspace_dir, get_metadata_path
from app.models.workspace import Workspace

logger = logging.getLogger("kivo.sources")
router = APIRouter()

def get_sources_json_path(workspace_id: str):
    return get_workspace_dir(workspace_id) / "sources.json"

def get_sources_upload_dir(workspace_id: str):
    return get_workspace_dir(workspace_id) / "sources"

def load_sources(workspace_id: str) -> List[Source]:
    sources_file = get_sources_json_path(workspace_id)
    if not sources_file.exists():
        return []
    try:
        with open(sources_file, "r") as f:
            data = json.load(f)
        return [Source(**item) for item in data]
    except Exception as e:
        logger.error(f"Failed to load sources from {sources_file}: {e}")
        return []

def save_sources(workspace_id: str, sources: List[Source]):
    sources_file = get_sources_json_path(workspace_id)
    try:
        with open(sources_file, "w") as f:
            # Serialize each pydantic model in the list
            json_data = [json.loads(s.model_dump_json()) for s in sources]
            json.dump(json_data, f, indent=2)
    except Exception as e:
        logger.error(f"Failed to save sources to {sources_file}: {e}")
        raise HTTPException(status_code=500, detail="Failed to save source registry")

def update_workspace_sources_count(workspace_id: str, count: int):
    metadata_file = get_metadata_path(workspace_id)
    if not metadata_file.exists():
        return
    try:
        with open(metadata_file, "r") as f:
            data = json.load(f)
        workspace = Workspace(**data)
        workspace.sources_count = count
        with open(metadata_file, "w") as f:
            f.write(workspace.model_dump_json())
    except Exception as e:
        logger.error(f"Failed to update workspace sources count for {workspace_id}: {e}")

@router.get("", response_model=List[Source])
def list_sources(workspace_id: str = Path(..., description="The unique workspace ID")):
    """List all sources attached to the workspace."""
    workspace_dir = get_workspace_dir(workspace_id)
    if not workspace_dir.exists():
        raise HTTPException(status_code=404, detail="Workspace not found")
    return load_sources(workspace_id)

@router.post("/upload", response_model=List[Source])
async def upload_sources(
    workspace_id: str = Path(..., description="The unique workspace ID"),
    files: List[UploadFile] = File(...)
):
    """Upload one or more files (PDF, Image, Audio) to the workspace."""
    workspace_dir = get_workspace_dir(workspace_id)
    if not workspace_dir.exists():
        raise HTTPException(status_code=404, detail="Workspace not found")
        
    upload_dir = get_sources_upload_dir(workspace_id)
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    current_sources = load_sources(workspace_id)
    new_sources = []
    
    for file in files:
        if not file.filename:
            continue
            
        # Detect type from extension
        ext = FilePath(file.filename).suffix.lower()
        if ext == ".pdf":
            source_type = "pdf"
        elif ext in [".png", ".jpg", ".jpeg", ".webp"]:
            source_type = "image"
        elif ext in [".mp3", ".wav", ".m4a", ".flac", ".ogg"]:
            source_type = "audio"
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported file format for {file.filename}")
            
        # Create safe unique file path on disk
        source_id = str(uuid.uuid4())
        filename = f"{source_id}_{FilePath(file.filename).name}"
        dest_path = upload_dir / filename
        
        # Save file to disk
        try:
            with open(dest_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
        except Exception as e:
            logger.error(f"Failed to write file {filename} to disk: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to save file {file.filename}")
            
        # Get file size
        size_bytes = dest_path.stat().st_size
        
        # Create Source metadata
        src = Source(
            id=source_id,
            name=file.filename,
            type=source_type,
            path=str(dest_path.relative_to(settings.storage_dir.parent)),
            url=None,
            added_at=datetime.now(timezone.utc),
            size_bytes=size_bytes,
            status="pending"
        )
        new_sources.append(src)
        
    current_sources.extend(new_sources)
    save_sources(workspace_id, current_sources)
    update_workspace_sources_count(workspace_id, len(current_sources))
    
    logger.info(f"Uploaded {len(new_sources)} files to workspace {workspace_id}")
    return new_sources

@router.post("/youtube", response_model=Source)
def add_youtube_source(
    workspace_id: str = Path(..., description="The unique workspace ID"),
    payload: YouTubeCreate = Body(...)
):
    """Add a YouTube URL as a source for the workspace."""
    workspace_dir = get_workspace_dir(workspace_id)
    if not workspace_dir.exists():
        raise HTTPException(status_code=404, detail="Workspace not found")
        
    # Validate YouTube URL pattern
    url = payload.url.strip()
    youtube_pattern = re.compile(
        r'(https?://)?(www\.)?(youtube|youtu|youtube-nocookie)\.(com|be)/(watch\?v=|embed/|v/|.+\?v=)?([^&=%\?]{11})'
    )
    match = youtube_pattern.match(url)
    if not match:
        raise HTTPException(status_code=400, detail="Invalid YouTube video URL")
        
    video_id = match.group(6)
    
    current_sources = load_sources(workspace_id)
    
    # Check if this URL is already added
    for src in current_sources:
        if src.type == "youtube" and src.url == url:
            raise HTTPException(status_code=400, detail="YouTube URL already registered in this workspace")
            
    source_id = str(uuid.uuid4())
    src = Source(
        id=source_id,
        name=f"YouTube: {video_id}",
        type="youtube",
        path=None,
        url=url,
        added_at=datetime.now(timezone.utc),
        size_bytes=None,
        status="pending"
    )
    
    current_sources.append(src)
    save_sources(workspace_id, current_sources)
    update_workspace_sources_count(workspace_id, len(current_sources))
    
    logger.info(f"Registered YouTube video {video_id} in workspace {workspace_id}")
    return src

@router.post("/website", response_model=Source)
def add_website_source(
    workspace_id: str = Path(..., description="The unique workspace ID"),
    payload: WebsiteCreate = Body(...)
):
    """Add a website URL as a source for the workspace."""
    workspace_dir = get_workspace_dir(workspace_id)
    if not workspace_dir.exists():
        raise HTTPException(status_code=404, detail="Workspace not found")
        
    url = payload.url.strip()
    if not (url.startswith("http://") or url.startswith("https://")):
        raise HTTPException(status_code=400, detail="Invalid website URL. Must start with http:// or https://")
        
    current_sources = load_sources(workspace_id)
    
    # Check if URL already exists
    for src in current_sources:
        if src.type == "website" and src.url == url:
            raise HTTPException(status_code=400, detail="Website URL already registered in this workspace")
            
    parsed_url = urlparse(url)
    domain = parsed_url.netloc or parsed_url.path
    if not domain:
        domain = "Unknown Website"
        
    source_id = str(uuid.uuid4())
    src = Source(
        id=source_id,
        name=f"Website: {domain}",
        type="website",
        path=None,
        url=url,
        added_at=datetime.now(timezone.utc),
        size_bytes=None,
        status="pending"
    )
    
    current_sources.append(src)
    save_sources(workspace_id, current_sources)
    update_workspace_sources_count(workspace_id, len(current_sources))
    
    logger.info(f"Registered website {domain} in workspace {workspace_id}")
    return src

@router.post("/text", response_model=Source)
def add_text_source(
    workspace_id: str = Path(..., description="The unique workspace ID"),
    payload: TextCreate = Body(...)
):
    """Add pasted text as a source for the workspace."""
    workspace_dir = get_workspace_dir(workspace_id)
    if not workspace_dir.exists():
        raise HTTPException(status_code=404, detail="Workspace not found")
        
    name = payload.name.strip()
    if not name:
        name = "Pasted Text"
        
    # Standardize name extension if not present
    if not name.endswith(".txt"):
        name = f"{name}.txt"
        
    upload_dir = get_sources_upload_dir(workspace_id)
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    source_id = str(uuid.uuid4())
    filename = f"{source_id}_text.txt"
    dest_path = upload_dir / filename
    
    try:
        with open(dest_path, "w", encoding="utf-8") as f:
            f.write(payload.content)
    except Exception as e:
        logger.error(f"Failed to write text file {filename} to disk: {e}")
        raise HTTPException(status_code=500, detail="Failed to save copied text source")
        
    size_bytes = dest_path.stat().st_size
    
    current_sources = load_sources(workspace_id)
    src = Source(
        id=source_id,
        name=name,
        type="text",
        path=str(dest_path.relative_to(settings.storage_dir.parent)),
        url=None,
        added_at=datetime.now(timezone.utc),
        size_bytes=size_bytes,
        status="pending"
    )
    
    current_sources.append(src)
    save_sources(workspace_id, current_sources)
    update_workspace_sources_count(workspace_id, len(current_sources))
    
    logger.info(f"Registered copied text source {name} in workspace {workspace_id}")
    return src

@router.delete("/{source_id}")
def delete_source(
    workspace_id: str = Path(..., description="The unique workspace ID"),

    source_id: str = Path(..., description="The unique source ID")
):
    """Delete a source from the workspace."""
    workspace_dir = get_workspace_dir(workspace_id)
    if not workspace_dir.exists():
        raise HTTPException(status_code=404, detail="Workspace not found")
        
    current_sources = load_sources(workspace_id)
    source_to_delete = None
    
    for src in current_sources:
        if src.id == source_id:
            source_to_delete = src
            break
            
    if not source_to_delete:
        raise HTTPException(status_code=404, detail="Source not found")
        
    # Delete file if it exists
    if source_to_delete.path:
        file_path = FilePath(source_to_delete.path)
        if file_path.exists():
            try:
                file_path.unlink()
            except Exception as e:
                logger.error(f"Failed to delete source file {file_path}: {e}")
                
    # Delete chunks from SQLite database
    from app.core.database import delete_source_chunks
    try:
        delete_source_chunks(workspace_id, source_id)
    except Exception as e:
        logger.error(f"Failed to delete SQLite chunks for source {source_id}: {e}")
                
    # Update list & save
    current_sources.remove(source_to_delete)
    save_sources(workspace_id, current_sources)
    update_workspace_sources_count(workspace_id, len(current_sources))
    
    logger.info(f"Deleted source {source_id} from workspace {workspace_id}")
    return {"status": "ok", "message": f"Source {source_id} deleted successfully"}
