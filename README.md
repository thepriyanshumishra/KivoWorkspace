# Kivo Workspace 🚀

An **edge-first, privacy-respecting AI knowledge workspace** designed to run entirely locally on your host machine. Kivo Workspace allows you to upload multiple source formats (PDFs, Images, Audio files, YouTube videos, Websites, or custom notes), compile them into an isolated vector database, and explore your knowledge base through an interactive, source-grounded chat interface with robust citations and follow-up recommendations.

---

## 🌟 Key Features

*   **Isolated Workspace Directory:** Organize topics or projects into standalone workspaces. Each workspace retains its own isolated documents, FAISS vector index, database mappings, and custom rules.
*   **Flexible Source Ingestion:**
    *   **PDF Documents:** Extracts clean, structured page-by-page text.
    *   **Images (OCR):** Local OCR powered by Tesseract to extract text from screenshots, scanned documents, and images.
    *   **Local Audio Files:** Offline transcription supporting `.mp3`, `.wav`, `.m4a`, `.flac`, and `.ogg` formats.
    *   **YouTube Videos:** Subtitle-first parser that fetches transcriptions in seconds, with automatic fallback to local transcription models when subtitles are unavailable.
    *   **Websites:** Full-page extraction using Playwright headless Chromium browser to execute JS and Mozilla's Readability algorithm to clean out navbars, sidebars, and ads.
    *   **Text Pasting:** Hand-typed or copy-pasted custom notes saved directly as text sources.
*   **Interactive Source Grid:** Notion-like visual interface to upload, track, and manage sources.
*   **Sequential Extraction Pipeline:** Renders real-time, checkpoint-by-checkpoint visual progress updates on the frontend.
*   **Privacy-First & Offline:** All chunking, embedding generation (using BGE-M3), FAISS index building, and LLM text generation (Ollama) run 100% locally. Raw uploaded files are securely purged after database compilation.
*   **Dynamic Custom Instructions:** Customize LLM behavior, tone, formatting, and language (e.g. "Answer in Hindi", "Use bullet lists only") on a per-workspace level. Implemented with **Double Prompt Reinforcement** for small models.
*   **Quick Actions & Follow-ups:** One-click capsule action chips (`Summarize`, `Create Notes`, `Generate Quiz`, `Key Concepts`) and context-aware follow-up suggestions dynamically generated after each AI message.
*   **Interactive Citation Panel:** Footnotes linking each sentence back to the exact parent chunks of the source documents.

---

## 🛠️ Prerequisites & Setup

### Global Dependencies
*   **Python:** Version `3.11` or `3.12`
*   **Flutter SDK:** Version `3.0` or higher
*   **Ollama:** Install the [Ollama desktop client](https://ollama.com) and pull the default model:
    ```bash
    ollama pull qwen2.5:1.5b
    ```
*   **System Binaries:**
    *   **FFmpeg:** Required for audio/video extraction (e.g. `brew install ffmpeg` on macOS).
    *   **Tesseract OCR:** Required for image text extraction (e.g. `brew install tesseract` on macOS).

---

## 🏃 Getting Started

### 1. Backend Server Setup (FastAPI)

1. Navigate to the backend folder:
   ```bash
   cd backend
   ```
2. Create and activate a Python virtual environment:
   * **macOS/Linux:**
     ```bash
     python3 -m venv venv
     source venv/bin/activate
     ```
   * **Windows:**
     ```bash
     python3 -m venv venv
     venv\Scripts\activate
     ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Install Playwright browser binaries:
   ```bash
   playwright install chromium
   ```
5. Run the server:
   ```bash
   uvicorn main:app --reload --port 8000
   ```
   *The Kivo Workspace API will be running locally at `http://localhost:8000`.*

### 2. Frontend Client Setup (Flutter)

1. Navigate to the frontend folder:
   ```bash
   cd frontend
   ```
2. Retrieve packages:
   ```bash
   flutter pub get
   ```
3. Launch the desktop client:
   * **macOS:** `flutter run -d macos`
   * **Windows:** `flutter run -d windows`
   * **Linux:** `flutter run -d linux`

---

## 📂 Project Structure

```
Kivo Workspace/
├── frontend/       # Flutter cross-platform desktop application
├── backend/        # FastAPI Python web server (RAG engine, pipelines, API routes)
└── Docs/           # Project specifications, architecture reviews, and sprint tasks (Gitignored)
```

---

## 🎯 Development Roadmap & Status

| Sprint | Focus | Status |
| :--- | :--- | :--- |
| **Sprint 0** | Project Foundation | ✅ Complete |
| **Sprint 1** | Workspace System CRUD | ✅ Complete |
| **Sprint 2** | Source Upload UI | ✅ Complete |
| **Sprint 3** | Processing Framework (Queues) | ✅ Complete |
| **Sprint 4–7** | Extraction Pipelines (PDF, OCR, Audio, YouTube) | ✅ Complete |
| **Wildcard** | Website & Copy-Text Ingestion | ✅ Complete |
| **Sprint 8–9** | Embeddings & FAISS Vector Database | ✅ Complete |
| **Sprint 10–11** | Retrieval Engine & Chat Interface | ✅ Complete |
| **Sprint 12** | Interactive Citation System | ✅ Complete |
| **Sprint 13** | Workspace Custom System Instructions | ✅ Complete |
| **Sprint 14** | Welcome Cards & Quick Actions Row | ✅ Complete |
| **Sprint 15** | Suggested Follow-Up Questions | ✅ Complete |
| **Sprint 16** | **Polish & Stabilization** | 🔲 **Up Next** |

---

## 🔒 Security & Optimization Note (macOS)
The local RAG pipeline has been updated with safety import ordering to prevent runtime conflicts between `faiss` and `torch` (OpenMP/MKL runtime collision) on macOS CPU. All code compiles and analyses cleanly with static checks.
