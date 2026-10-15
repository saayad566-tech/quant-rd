# PROJECT_SPEC — Quant RD

## Verbatim request (user)
> "the other agent AiO stop in between due to error when working on quant rd. make sure you finish the project use your full power to analyze plan and complete app"

Clarified via intake questions:
- **Product:** Quantitative trading strategy research + backtesting platform.
- **Deliverable:** production-ready app that runs **offline**, targeting
  **Android (.apk)** and **Windows (.exe)**.
- **Distribution:** split code and assets into separate GitHub repositories;
  chunk large files to bypass size limits; download resources at runtime via a
  main manifest file.
- **Constraints:** offline-first local execution; a dedicated multi-tab sidebar
  for **navigation**, **API-key settings** and **custom configuration**, without
  compromising the main screen layout. Users bring their own API keys.

## Product in five lines
1. **Who:** retail quants, students and independent traders researching rules.
2. **Problem:** most backtest tools are cloud-only, hide their assumptions, or
   leak future data. Quant RD is local, transparent and offline.
3. **Killer features:** (a) honest event-driven backtester with fees/slippage and
   no look-ahead; (b) a visual rule builder over 15 indicators; (c) full
   analytics suite with equity/drawdown charts and a trade log.
4. **Platforms:** Android (native), Windows (native), web (offline demo).
5. **Model:** free, open-source, offline. No backend, no accounts, no telemetry.

## Explicit requirements
- [x] Runs offline, locally.
- [x] Android .apk + Windows .exe from one codebase.
- [x] Sidebar with separate tabs for navigation, API keys and configs.
- [x] Users bring and configure their own API keys.
- [x] Assets split into a separate repository, chunked, downloaded at runtime.
- [x] Production-ready: no placeholders, no stubs, verified.

## Implicit requirements (a premium product of this type must have)
- [x] CSV import with messy real-world files.
- [x] Loading / empty / error / offline states on every screen.
- [x] Typed error handling with user-facing messages and retry.
- [x] Secure key storage (OS secure store), never logged.
- [x] Honest backtest assumptions documented in-app.
- [x] Dark and light themes; responsive layouts.
- [x] Financial disclaimer.

## Out of scope (deliberate)
- Live order execution / broker integration (no trading, research only).
- Cloud sync or accounts.
- iOS build (no macOS available to produce it).

## Constraints
Free-only, open-source libraries, offline-first, BYO API keys, regional
awareness (₹ / INR defaults, Indian market examples in sample data).
