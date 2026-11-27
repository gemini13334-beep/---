# FORGE ENGINE

Android 12+ (API 31), ARM64, Russian-first touch UI. Godot 4.4.1-stable initial reproducible baseline; upgrade after tests. Fork editor, keep project format and export templates compatible. Compatibility renderer default. GDScript first; C# remote build experimental, other languages via sandboxed plugins or remote toolchains.

## AI
Provider abstraction for OpenAI-compatible HTTPS endpoints, separate adapters for other APIs, optional Codex remote service. Never embed keys; Android Keystore. Chat and proposed project diffs, explicit approval before applying changes; restrict paths to project, reject traversal and symlinks. No arbitrary agent shell on phone.

## Candidates
Godot MIT (https://github.com/godotengine/godot); Codex Apache-2.0 (https://github.com/openai/codex); llama.cpp MIT (https://github.com/ggml-org/llama.cpp). Further candidates: Monaco, Sora Editor, tree-sitter, Jolt, Lua, QuickJS, LiteLLM. Verify licenses at pinned revisions before adding dependencies.

## Milestones
1. Upstream Android editor baseline build and device smoke test.
2. Russian touch-friendly UI and project manager.
3. AI chat and reviewable edits.
4. APK export and templates.

Status: planning and initial source-fetch tooling only. No integrated APK yet. Do not modify sibling projects.
