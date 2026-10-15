# CHECKLIST — Quant RD

## Phase 0 — Intake
- [x] Restate product, extract explicit + implicit requirements
- [x] Record assumptions, constraints and out-of-scope

## Phase 1 — Blueprint
- [x] Tech-stack decision + rationale
- [x] Folder tree, navigation map, data architecture
- [x] Service contracts, security model, risk register

## Phase 2 — Design system
- [x] Design tokens (colour, type, spacing, radii, elevation, motion)
- [x] Dark + light themes; accessibility contrast

## Phase 3 — Foundation
- [x] Project scaffold (android, windows, web)
- [x] Dependencies pinned via pub
- [x] Storage layer, secure store, repositories
- [x] `flutter analyze` clean

## Phase 4 — Core logic
- [x] Indicators (SMA, EMA, RSI, MACD, Bollinger, ATR, Stochastic, ROC)
- [x] Strategy model + rule evaluation + warm-up
- [x] Event-driven backtester (fees, slippage, SL/TP, no look-ahead)
- [x] Metrics suite
- [x] CSV parser (delimiters, headers, dates, dedupe, malformed rows)
- [x] Market-data clients (5 providers) with retry/backoff
- [x] Built-in strategies (6)

## Phase 5 — UI
- [x] App shell, responsive sidebar
- [x] Sidebar tabs: Navigate / API Keys / Configs
- [x] Dashboard, Market Data, Strategy Lab (+ builder), Backtest, Results
- [x] Charts (equity, drawdown, price), trade table, metric tiles
- [x] Loading / empty / error states everywhere
- [x] Animations and transitions

## Phase 6 — Hardening
- [x] Typed error handling; retries; offline fallbacks
- [x] Layout-overflow guard (navigation test walks every screen)
- [x] Charts downsample for performance
- [x] Responsive breakpoints (sidebar ↔ drawer)

## Phase 7 — Build & ship
- [x] Web release build produced and verified locally
- [x] Android + Windows + web CI workflows
- [x] Tag-based signed release workflow
- [x] BUILD.md, README.md, troubleshooting table
- [x] Memory files complete
- [ ] Android `.apk` compiled **locally** — blocked by sandbox proxy (see KNOWN_ISSUES); CI builds it

## Tests
- [x] indicators (9) · strategy engine (4) · backtester (7) · metrics (3)
- [x] csv parser (7) · repositories (4) · widget smoke (1) · navigation (1)
- [x] 38 passing, 0 failing

## Session 2 — audit, protocols & shipping
- [x] Deep audit of the whole codebase against the protocol set
- [x] Multi-project isolation (Workspaces) + v1→v2 migration
- [x] Workspace switcher + project management UI
- [x] Plain-English activity log + Activity Log screen
- [x] Self-healing error reporting (global handlers + fallback UI)
- [x] 60/120 Hz performance pass (blur opt-in, RepaintBoundary, chart downsampling)
- [x] CSV export (trades, metrics, equity, datasets)
- [x] 53 tests passing; analyzer clean
- [x] CI on GitHub Actions: verify + android + windows + web all succeeded
- [x] Real `.apk`, `.aab` and Windows `.exe` build delivered
