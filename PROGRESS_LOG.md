# PROGRESS_LOG — Quant RD

## 2026-10-15 — Session 1 (recovery + full build)

**Context recovery:** the sandbox was empty; no prior artifacts existed. The
product definition was re-established with the user and the app was rebuilt from
scratch.

**Completed**
- Installed Flutter 3.47.7 SDK; scaffolded the project (android, windows, web).
- Pinned 13 dependencies via `pub add` (versions resolved live, not from memory).
- Verified the exact API surface of Riverpod 3.4.3, fl_chart 1.2.0,
  flutter_secure_storage 11.2.0, file_picker 13.1.0, csv 8.0.0 before writing code.
- Built the full domain engine: indicators, strategy evaluation, event-driven
  backtester, metrics.
- Built the data layer: SQLite/in-memory database + repositories, secure store,
  five market-data provider clients, chunked asset-pack downloader, CSV parser,
  synthetic sample data.
- Built the UI: app shell, multi-tab sidebar (Navigate / API Keys / Configs),
  five screens, glass component library, charts.
- Wrote and passed 38 tests.
- Produced a **release web build** (`flutter build web --release` → success).

**Verified**
- `flutter analyze` → **No issues found!**
- `flutter test` → **All tests passed! (38)**
- `flutter build web --release` → `✓ Built build/web`

**Blocked / not done here**
- Local Android `.apk`: Gradle cannot reach the Gradle Plugin Portal host through
  the sandbox's egress proxy (HTTP 403). Code is verified; CI builds the APK.
- Local Windows `.exe`: requires a Windows toolchain (or Wine), absent here. CI builds it.

**Fixes made during the session (evidence-driven)**
- Rewrote the backtest loop when the pending-exit logic was ambiguous.
- Corrected the warm-up calculation (it over-skipped bars for indicator-free rules).
- Fixed a `MetricTile` layout overflow caught by the widget test.
- Updated the CSV parser to `csv` 8.x's `Csv` codec after the API changed.
- Made timezone-less CSV timestamps UTC for deterministic tests.
