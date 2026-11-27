# NEXUS AI

Персональный Android AI. Отдельный проект, не изменять соседние каталоги.

## Интеграции (план, пока не реализованы)
- Android base: https://github.com/google-ai-edge/gallery (Apache-2.0)
- Local inference: https://github.com/ggml-org/llama.cpp and https://github.com/google-ai-edge/LiteRT-LM
- Models: Qwen, Gemma; check individual model licenses.
- Server: SearXNG, Crawl4AI, LiteLLM, Mem0, LangGraph, OpenHands, Aider, ComfyUI.
- Mobile: SQLite, SQLCipher, Android Keystore, sherpa-onnx, whisper.cpp.

## Requirements
Russian UI; offline chat; optional authenticated online backend; explicit confirmation for device actions; no secrets or personal memory in this public repository. Preserve upstream licenses. Pin tested dependency revisions. Build and verify APK before marking features complete.

Status: project initialization only; no APK or integrated runtime yet.
