# DeskPilot MLX Backend Setup

## Overview

DeskPilot uses a local MLX-LM server as its AI backend. The server runs a quantized LLM on Apple Silicon and exposes an OpenAI-compatible API at `http://127.0.0.1:8080`.

## Prerequisites

- macOS with Apple Silicon (M1 or later)
- Python 3.12+

## Setup

### 1. Create a Python virtual environment

From the project root (the directory containing `DeskPilot.xcodeproj`'s parent):

```bash
cd path/to/DeskPilotProject
python3 -m venv .venv
source .venv/bin/activate
```

### 2. Install mlx-lm

```bash
pip install mlx-lm
```

If you get a `transformers` compatibility error (`'str' object has no attribute '__module__'`), try:

```bash
pip install --upgrade mlx-lm
```

Or pin transformers:

```bash
pip install "transformers<4.52"
```

### 3. Start the server

```bash
mlx_lm.server --model mlx-community/Qwen3-4B-4bit
```

The first run downloads the model (~2-3 GB). Once running, the server listens at `http://127.0.0.1:8080`.

### 4. Test the server

```bash
curl -X POST http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"default_model","messages":[{"role":"user","content":"Hello!"}]}'
```

You should get a JSON response with the model's reply.

## Project Structure

```
DeskPilotProject/
├── DeskPilot/          ← Xcode project (Swift/SwiftUI)
├── .venv/              ← Python virtual environment (git-ignored)
└── backend_setup.md    ← This file
```

## Notes

- The `.venv/` folder should be in `.gitignore`.
- The Swift app calls `localhost:8080` using URLSession.
- When the server is not running, the app falls back to deterministic mock responses.
