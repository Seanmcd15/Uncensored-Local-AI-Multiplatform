# AGENTS.md

## Cursor Cloud specific instructions

This is a **Flutter** app ("Uncensored Local AI" / package `portable_ai_flutter`) that runs
local GGUF LLMs on-device via the native `llamadart` (llama.cpp) engine. The primary product
targets are **Android/iOS**, but those SDKs are not installed on this Linux VM. On this VM the
runnable target is the **Linux desktop** build (Chrome/web is also available). Standard commands
live in `README.md`, `pubspec.yaml`, and `.github/workflows/build-apk.yml`.

### Toolchain / how to run
- Flutter (stable, includes Dart) is preinstalled at `/opt/flutter` and symlinked onto `PATH`
  via `/usr/local/bin/flutter` and `/usr/local/bin/dart`. `enable-linux-desktop` is already on.
- Lint: `flutter analyze` (currently reports pre-existing info/warnings only, no errors).
- Tests: `flutter test`.
- Run (dev mode): `flutter run -d linux`. A window needs an X display — export `DISPLAY=:1`.
  Rendering falls back to software (llvmpipe); the `libEGL warning: DRI3 error` line is harmless.

### Non-obvious gotchas
- **Never run `flutter build`/`flutter run` as root, and don't let a build cache pin the install
  prefix.** If a Linux build fails with `file INSTALL cannot copy ... to /usr/local/... Permission
  denied`, a stale `build/linux/x64/debug/CMakeCache.txt` has `CMAKE_INSTALL_PREFIX=/usr/local`.
  Fix with `flutter clean && flutter pub get`, then rebuild fresh.
- The native `llamadart` (llama.cpp) sources compile on the first `flutter build linux`; later
  builds reuse the cached native assets, so only the first build is slow.
- The one failing test, `init starts the localhost server by default`
  (`test/local_api_server_service_test.dart`), is a **pre-existing repo bug**, not an environment
  issue: `LocalApiServerService.init()` only starts the server when
  `ChatStorageService.localApiServerEnabled` is true, but that setting defaults to `false`
  (`lib/services/chat_storage_service.dart`) and the test never enables it. The other 3 tests pass.

### Core feature quick-check (no model download needed)
- The built-in OpenAI-compatible **Local API Server** is real core functionality you can exercise
  without downloading a model: in the app go to **Settings → Local API Server** and toggle it ON.
  It binds `127.0.0.1:4891`. Verify with:
  - `curl http://127.0.0.1:4891/healthz`
  - `curl http://127.0.0.1:4891/v1/models`
  - Chat completions return `503 model_not_loaded` until a GGUF model is loaded.
- Actually chatting requires downloading a multi-GB GGUF model from the in-app **Models** tab and
  loading it (CPU backend works; there is no GPU/Vulkan ICD on this VM), which is impractical for a
  quick demo.
