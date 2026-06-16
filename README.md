# Kivo Workspace

An edge-first AI knowledge workspace. Upload sources, build a local knowledge base, and chat with your files — entirely locally on your machine.

---

## 🚀 Key Features

*   **Workspace System**: Create isolated knowledge spaces for different projects or topics.
*   **Flexible Source Ingestion**:
    *   **PDF Documents**: Extracts clean page-by-page text.
    *   **Images**: Performs local OCR (using Tesseract) to ingest scanned text/screenshots.
    *   **Local Audio Files**: High-speed, offline transcription of `.mp3`, `.wav`, `.m4a`, `.flac`, and `.ogg` files.
    *   **YouTube Ingestion**: Fast subtitle-first parser that grabs transcriptions in under 5 seconds (with fallback to local audio models).
    *   **Website Links**: Boilerplate-free scraping that strips headers, navbars, and script/style tags, leaving clean Markdown content.
    *   **Copy Text Pasting**: Ingests custom typed or pasted notes, saving them directly to disk as raw text files.
*   **Interactive 3x2 Notion-like Grid**: Beautiful frontend layout to upload and manage sources.
*   **Sequential Extraction Pipeline**: Renders real-time, step-by-step progress timelines for all processing checkpoints.
*   **Local Processing**: Privacy-focused architecture where all vector embeddings and LLM calls run entirely on the host machine.

---

## 🛠️ Prerequisites & System Requirements

Before running the project, ensure you have the following installed:

### Global Dependencies
*   **Python**: Version `3.11` or `3.12`
*   **Flutter SDK**: Version `3.0` or higher
*   **Ollama**: Install the [Ollama desktop client](https://ollama.com) and pull the default LLM:
    ```bash
    ollama pull qwen2.5:1.5b
    ```
*   **System Libraries**:
    *   **FFmpeg**: Required for audio processing and video extraction.
        *   *macOS*: `brew install ffmpeg`
        *   *Windows*: Download from FFmpeg website and add to System PATH.
    *   **Tesseract OCR**: Required for extracting text from images.
        *   *macOS*: `brew install tesseract`
        *   *Windows*: Install via vcpkg or installer.

---

## 🏃 Getting Started

### 1. Backend Setup (FastAPI)

1.  Navigate to the backend directory:
    ```bash
    cd backend
    ```
2.  Create a virtual environment:
    ```bash
    python3 -m venv venv
    ```
3.  Activate the virtual environment:
    *   **macOS/Linux**:
        ```bash
        source venv/bin/activate
        ```
    *   **Windows**:
        ```bash
        venv\Scripts\activate
        ```
4.  Install the required dependencies:
    ```bash
    pip install -r requirements.txt
    ```
5.  Start the FastAPI server:
    ```bash
    uvicorn main:app --reload --port 8000
    ```

The backend API will be running locally at `http://localhost:8000`.

### 2. Frontend Setup (Flutter)

1.  Navigate to the frontend directory:
    ```bash
    cd frontend
    ```
2.  Fetch packages and dependencies:
    ```bash
    flutter pub get
    ```
3.  Run the application:
    *   **macOS Desktop**:
        ```bash
        flutter run -d macos
        ```
    *   **Windows Desktop**:
        ```bash
        flutter run -d windows
        ```
    *   **Linux Desktop**:
        ```bash
        flutter run -d linux
        ```

---

## 📂 Project Structure

```
Kivo Workspace/
├── frontend/       # Flutter cross-platform desktop frontend application
├── backend/        # FastAPI Python backend (processors, schemas, routes)
└── Docs/           # Sprint documentation (Local Gitignored folder)
```

---

## 🎯 Development Roadmap & Status

| Sprint | Focus | Status |
| :--- | :--- | :--- |
| **Sprint 0** | Project Foundation | ✅ Complete |
| **Sprint 1** | Workspace System | ✅ Complete |
| **Sprint 2** | Source Upload | ✅ Complete |
| **Sprint 3** | Processing Framework | ✅ Complete |
| **Sprint 4–7** | Source Pipelines (PDF, Image OCR, Audio, YouTube) | ✅ Complete |
| **Wildcard** | Website Ingestion & Copy Text Pasting | ✅ Complete |
| **Sprint 8–9** | Embeddings + Vector DB (BGE-M3 Integration) | 🔲 Up Next |
| **Sprint 10–11**| Retrieval + Chat | 🔲 Pending |
| **Sprint 12–15**| Citations, Instructions, Actions | 🔲 Pending |
| **Sprint 16** | Polish & Stabilization | 🔲 Pending |
