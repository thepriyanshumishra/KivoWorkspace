# app/core/processors/youtube.py
# Purpose: YouTube video subtitle-first and fallback audio transcription pipeline.
# Responsibilities: Attempts to fetch pre-existing subtitles from YouTube. If found, parses and chunks them instantly without downloading audio.
# If subtitles are unavailable, falls back to downloading the audio stream, transcribing it using local faster-whisper, and cleaning up temp files.

import re
import glob
import logging
from pathlib import Path
from typing import Dict, Any, List
import yt_dlp

logger = logging.getLogger("kivo.processors.youtube")

def clean_vtt_timestamps(vtt_text: str) -> List[Dict[str, Any]]:
    """
    Parses WebVTT subtitles text, cleans HTML tags/styles, and extracts timestamped segments.
    """
    lines = vtt_text.splitlines()
    parsed_segments = []
    
    # WebVTT timestamp pattern (e.g. 00:01:23.456 --> 00:01:25.789 or 01:23.456 --> 01:25.789)
    time_pattern = re.compile(r'(?:(\d{2}):)?(\d{2}):(\d{2})[\.,](\d{3})\s*-->\s*(?:(\d{2}):)?(\d{2}):(\d{2})[\.,](\d{3})')
    
    def to_seconds(match_groups, offset):
        # groups: (hr, min, sec, ms)
        hr = int(match_groups[offset] or 0)
        min_val = int(match_groups[offset+1] or 0)
        sec = int(match_groups[offset+2] or 0)
        ms = int(match_groups[offset+3] or 0)
        return hr * 3600 + min_val * 60 + sec + ms / 1000.0

    current_start = None
    current_end = None
    current_text = []

    for line in lines:
        line = line.strip()
        if not line:
            continue
        
        # Skip VTT header lines
        if line.startswith("WEBVTT") or line.startswith("Kind:") or line.startswith("Language:"):
            continue
        
        match = time_pattern.search(line)
        if match:
            # Save the previous segment before starting a new one
            if current_text and current_start is not None:
                text_content = " ".join(current_text).strip()
                if text_content:
                    parsed_segments.append({
                        "start": current_start,
                        "end": current_end,
                        "text": text_content
                    })
            
            groups = match.groups()
            current_start = to_seconds(groups, 0)
            current_end = to_seconds(groups, 4)
            current_text = []
        else:
            # Clean HTML markup (like <c> styles) YouTube uses in auto-captions
            clean_line = re.sub(r'<[^>]+>', '', line).strip()
            # Avoid repeating exactly identical adjacent lines
            if clean_line and clean_line not in current_text:
                current_text.append(clean_line)
                
    # Append the last segment
    if current_text and current_start is not None:
        text_content = " ".join(current_text).strip()
        if text_content:
            parsed_segments.append({
                "start": current_start,
                "end": current_end,
                "text": text_content
            })
            
    return parsed_segments

class YouTubeProcessor:
    def __init__(self, audio_processor):
        self.audio_processor = audio_processor

    def process(self, url: str, workspace_id: str, source_id: str, sources_dir: Path) -> Dict[str, Any]:
        """
        Attempts to fetch subtitles from YouTube without downloading media.
        If found, chunks and processes them. Otherwise, falls back to downloading
        the audio stream and transcribing it using local faster-whisper.
        """
        logger.info(f"Processing YouTube URL: {url}")
        
        video_title = f"YouTube Video ({source_id})"
        duration = 0.0
        subs_downloaded = False
        segments = []
        
        # --- PHASE 1: Attempt Subtitle Fetch ---
        temp_sub_template = sources_dir / f"{source_id}_sub_temp"
        ydl_opts_subs = {
            'skip_download': True,        # Do not download video/audio
            'writesubtitles': True,       # Write manual subtitles
            'writeautomaticsubtitles': True,  # Fallback to auto-generated subtitles
            'subtitlesformat': 'vtt',
            'subtitleslangs': ['en', 'hi', 'pa', 'auto'], # Prioritize English, Hindi, Punjabi, or Auto
            'outtmpl': str(temp_sub_template),
            'quiet': True,
            'no_warnings': True,
        }
        
        try:
            logger.info("Attempting to download subtitles metadata...")
            with yt_dlp.YoutubeDL(ydl_opts_subs) as ydl:
                info_dict = ydl.extract_info(url, download=True)
                video_title = info_dict.get('title', video_title)
                duration = float(info_dict.get('duration') or 0.0)
                
            # Locate downloaded subtitle file
            downloaded_files = glob.glob(str(sources_dir / f"{source_id}_sub_temp*"))
            vtt_files = [f for f in downloaded_files if f.endswith(".vtt")]
            
            if vtt_files:
                vtt_file = Path(vtt_files[0])
                try:
                    with open(vtt_file, "r", encoding="utf-8") as f:
                        vtt_content = f.read()
                    segments = clean_vtt_timestamps(vtt_content)
                    if segments:
                        subs_downloaded = True
                        logger.info(f"Successfully fetched {len(segments)} subtitle segments for YouTube video: '{video_title}'")
                except Exception as parse_err:
                    logger.error(f"Error parsing VTT subtitles: {parse_err}")
                finally:
                    # Clean up the downloaded subtitle file
                    try:
                        vtt_file.unlink()
                    except Exception as del_err:
                        logger.error(f"Failed to delete temp subtitle file {vtt_file}: {del_err}")
        except Exception as sub_err:
            logger.warning(f"Could not retrieve subtitles from YouTube: {sub_err}")
            
        # If subtitles were found and parsed, chunk directly and return
        if subs_downloaded and segments:
            logger.info("Ingesting subtitles directly, skipping audio download and local ASR.")
            chunks_dir = sources_dir.parent / "chunks"
            res = self.audio_processor.create_chunks_from_segments(segments, duration, chunks_dir, source_id)
            return {
                "title": video_title,
                "stats": res["stats"],
                "summary": res["summary"]
            }
            
        # --- PHASE 2: Fallback to Audio Download & Local AI ---
        logger.info(f"Subtitles not available for '{video_title}'. Falling back to local AI transcription...")
        temp_audio_template = sources_dir / f"{source_id}_temp"
        ydl_opts_audio = {
            'format': 'bestaudio[abr<=96]/bestaudio[abr<=128]/bestaudio',
            'outtmpl': str(temp_audio_template),
            'postprocessors': [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '96',
            }],
            'quiet': True,
            'no_warnings': True,
        }
        
        try:
            with yt_dlp.YoutubeDL(ydl_opts_audio) as ydl:
                info_dict = ydl.extract_info(url, download=True)
                if not video_title or "YouTube Video" in video_title:
                    video_title = info_dict.get('title', f"YouTube Video ({source_id})")
        except Exception as e:
            logger.error(f"yt-dlp audio download fallback failed: {e}")
            raise RuntimeError(f"Failed to fetch YouTube audio stream: {e}")
            
        real_audio_path = sources_dir / f"{source_id}_temp.mp3"
        
        if not real_audio_path.exists():
            raise FileNotFoundError(f"Extracted YouTube audio file not found at {real_audio_path}")
            
        try:
            logger.info("Delegating transcription of downloaded YouTube stream to AudioProcessor...")
            res = self.audio_processor.process(real_audio_path, workspace_id, source_id)
        finally:
            # Absolute Rule: Delete raw source files post-processing
            if real_audio_path.exists():
                try:
                    real_audio_path.unlink()
                    logger.info(f"Deleted temporary YouTube audio file: {real_audio_path}")
                except Exception as e:
                    logger.error(f"Failed to delete temporary audio file {real_audio_path}: {e}")
                    
        return {
            "title": video_title,
            "stats": res["stats"],
            "summary": res["summary"]
        }
