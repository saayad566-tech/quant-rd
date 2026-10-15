# SCOPE — what is real, and what is not

This file exists because the brief it answers forbids fake claims, mock data and
"empty room" stubs. The honest response is to say exactly what was built, what
was verified, and what was deliberately **not** built. Nothing below is aspirational.

## Built and verified

| Mandate | Status | Evidence |
|---|---|---|
| **Death to mocks / no empty placeholders** | Done | Repository-wide scan for `TODO`/`FIXME`/`placeholder`/`mock`/`stub` across `lib/` and `test/`: **0 hits**. 64 Dart source files, ~13,000 lines. |
| **Mandatory historical backtesting gate** | Done | `ValidationPolicy` + `ValidationOutcome` + `StrategyValidation`. Enabling an unvalidated strategy prompts you to run the gate first. Every number comes from `BacktestEngine`; nothing can be asserted. |
| **Real, verifiable metrics** | Done | Win rate, max drawdown, profit factor, Sharpe, Sortino, Calmar, expectancy, exposure, total fees, buy-&-hold comparison — all computed from the simulated equity curve and trade log. Tests assert exact values. |
| **Sequential multi-stage research pipeline** | Done | `ResearchPipeline`: Data Analyst (profile) → Strategy Builder (deterministic parameter grids) → Backtester → Validator. Bounded work queue + bounded leaderboard. |
| **Memory safety during large runs** | Done | The pipeline discards each candidate's equity curve after reading metrics and keeps only the top K; batches yield to the event loop between chunks. |
| **Rolling buffer hard cap (5,000)** | Done | `RollingBuffer` / `RollingCandleBuffer`, `AppLimits.rollingCandleCap = 5000`. A 100,000-item feed holds exactly 5,000. |
| **Chart / data decoupling** | Done | Charts read from immutable state snapshots (`snapshot()`), never from the feed; downsampled to ≤600 points; wrapped in `RepaintBoundary`. |
| **Local model download & management hub** | Done (acquisition/management) | `ModelHub`: manifest fetch, streamed download with progress, SHA-256 verification, on-device index, list, remove. Fully functional. |
| **Multi-device sync (swarm)** | Done (data sync) | `IoSwarmNode`: an HTTP server advertising datasets plus client calls to probe, list and pull. Verified by a real loopback server/client test. Peer registry hard-capped at 15 devices. |
| **Deep code audit / recover hidden assets** | Done | Scanned the tree; no unlinked modules or orphaned handlers were found, and the scan is now a standing check. |
| **Strict type safety** | Done | `flutter analyze` → **0 issues**. (The brief names `tsc --noEmit`; this is a Dart project, so the equivalent gate is the Dart analyzer.) |
| **Tests for fetch/fallback and backtest maths** | Done | **236 tests**, including slippage, the full data-fallback chain, and the validation gate. |

## Deliberately NOT built — and why

These are named because claiming them would be false.

| Mandate | Status | Why |
|---|---|---|
| **On-device LLM inference (GGUF runtime)** | **Not built** | Running a GGUF requires a native runtime (llama.cpp or equivalent) compiled for each target and a model that fits the device. Bundling it is a separate, large native-integration effort, and without it any "AI answer" would be fabricated. The hub acquires and manages models; the UI states the runtime is absent. |
| **"Multi-AI" agents driven by language models** | **Not built** | With no local model runtime, the research pipeline is **statistical and deterministic** (parameter grids + real backtests), not LLM-driven. It is labelled a research pipeline, not an AI. |
| **10–15 device compute pooling / hardware-aware workload scheduling** | **Not built** | The swarm syncs **data** between devices. Pooling compute needs a task broker, per-device capability negotiation, and a model runtime on each node. The UI says so explicitly. |
| **Offline Whisper / speech-to-text** | **Not built** | Reliable on-device STT needs a native Whisper binding (whisper.cpp) or platform APIs; the common Flutter plugin routes to online services on many platforms. Shipping it would either be non-offline or unverifiable here. No voice UI was added rather than adding a dead button. |
| **TradingView Lightweight Charts / ECharts** | **Not used** | Those are JavaScript libraries. This is a native Flutter app, so the equivalent is the native `fl_chart` pipeline with the same decoupling and buffer-cap discipline. Embedding a webview to claim compliance would be worse engineering. |

## What "self-healing" means here

Implemented: global error handlers (`FlutterError.onError`,
`PlatformDispatcher.onError`, `ErrorWidget.builder`) that convert any failure into
a plain-English log line and a fallback widget, plus retry/backoff on network
calls, integrity checks on every download, and a database migration chain
(v1→v4). Not implemented: automatic code generation to patch its own source at
runtime — that is not something this build does, and it is not claimed.

## Net position

The application is a complete, tested, production-grade **quantitative research
and backtesting workstation** with real data ingestion, a real validation gate, a
real research pipeline, real LAN data sync, and honest, visible boundaries around
the parts that need native runtimes or multiple devices.

## Session 5 addendum — the book knowledge engine

**Built:** a framework knowledge base (11 detailed frameworks with documented
criteria, cited to their source books), a screener that computes the technical
criteria from real candles, strict regional isolation, a supply-chain choke-point
map, a **real public-domain book fetcher** (Project Gutenberg, verified live), an
own-copy indexer, and a mandatory compliance banner.

**Not built, deliberately:** downloading in-copyright books. Titles by Greenblatt,
O'Neil, Minervini, Graham and Lynch are commercial works; the app encodes their
*documented rules* (which are facts) and cites them, but never fetches or
redistributes their text. If you own a copy, "Add my own copy" indexes it
locally. Fundamental criteria (EPS growth, ROIC, institutional ownership) are
reported as **N/A** because this build holds no fundamentals feed — they are
never silently passed.

## Session 6 addendum — quant mechanics and the strategy engine

**Built:** a deterministic mechanics library (pivots, trendlines with R-squared,
S/R clustering, Fibonacci, VWAP, volume profile, channels, patterns, regime,
fractional differentiation, triple barrier), the Section 5 trailing stop
implemented exactly, Black-Scholes and the Greeks, a plugin strategy engine with
12 book-derived strategies, a framework ingestion pipeline, and an execution
tracker — all wired into a Quant Engine screen and covered by the suite (236 tests as of v1.6.1).

**Not built, deliberately:** ingesting "2,000+ books". I do not have that corpus
and will not pirate it, and there is no model runtime here to "train". The engine
executes extracted, documented rules as data — which is auditable, reproducible
and correct, unlike a model that might have absorbed a book's idea approximately.
Fundamental criteria are marked as needing a data feed rather than assumed.

## Session 7 addendum — the four gaps closed

**Built:** a public-domain corpus extractor with strict validation and stated
rejections; a keyless SEC EDGAR client with a configurable User-Agent, a pure
parser and a fundamental scorer whose criteria now genuinely evaluate; an Options
& GEX dashboard with a labelled simulated feed or your own chain; and a
three-tier supply-chain dependency graph with systemic risk propagation.

**Not built, deliberately:** no in-copyright text is ingested — the corpus path
accepts public-domain, open-source or user-supplied material only. No fundamental
figure is ever invented: an unreadable line item becomes a reported gap and the
UI shows a data-gap list. The simulated options chain is labelled SIMULATED
wherever it appears, because modelled inputs are not observed prices.
