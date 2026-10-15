# Full application audit — Quant RD

**Audited revision:** v1.6.0 → remediated in **v1.6.1**
**Scope:** the entire Flutter/Dart codebase — 116 source files (~22,100 lines) and
24 test files (~3,200 lines), across data, domain, presentation and platform
layers, plus configuration, CI and documentation.

Every finding below is backed by a command you can re-run. Nothing here is an
impression.

---

## 1. Verdict

The application is structurally sound: **no stubs, no fabricated data, no leaked
secrets, no orphaned modules, and every screen is reachable and wired.** The audit
found **five issues**, of which two were substantive and are now fixed. The most
important was that the project was **not running strict type checking** — which in
a financial engine is exactly where a silent cast does the most damage.

| # | Severity | Finding | Status |
|---|---|---|---|
| A1 | **High** | Strict type checking was **not enabled**; the project ran the default lint set only | **Fixed** — strict casts/inference/raw-types on, 24 extra rules enabled, 63 issues surfaced and resolved |
| A2 | **Medium** | Documentation drift — README and SCOPE claimed 38/110/187 tests; the real figure was 236 | **Fixed** |
| A3 | **Low** | `newIdProvider` was dead code (`Ids.newId` was called directly everywhere) | **Fixed** — removed |
| A4 | Low | Two of my own proposed lint rules were wrong for this codebase | **Corrected** — documented why |
| A5 | Info | 18 force-unwraps (`!`) and 3 `Random()` sites reviewed | **Verified safe** — no change needed |

---

## 2. What was checked, and what it showed

### 2.1 Stubs, placeholders and mock data

```
grep -rn --include=*.dart -E "TODO|FIXME|placeholder|not implemented" lib/
```
**Result: zero.** The only `UnimplementedError` is a deliberate guard in
`core_providers.dart` (`databaseProvider must be overridden in ProviderScope`),
and the five `UnsupportedError`s are the intentional **web-platform fallbacks**
that report "only available in the Android and Windows builds" instead of
pretending to work. Both are correct behaviour, not stubs.

### 2.2 Secrets and credentials

```
grep -rniE "api[_-]?key|secret|token|password|bearer\s*[:=]\s*['\"][A-Za-z0-9_\-]{12,}" lib/
```
**Result: zero hardcoded secrets.** The high-entropy string hits were XBRL tag
names (`RevenueFromContractWithCustomerExcludingAssessedTax`) — long, but not
credentials. Keys are stored through `flutter_secure_storage`, never in source.

### 2.3 Structural wiring

| Check | Result |
|---|---|
| Nav destinations with a shell case | **12 / 12** |
| Nav destinations with a sidebar icon + description | **12 / 12** |
| Screens present in the barrel export | **all** |
| Orphaned source files | **none** (only `main.dart`, the entrypoint — expected) |
| Providers defined but never consumed | **1** — `newIdProvider` (finding A3) |

### 2.4 Error handling and resilience

| Check | Result |
|---|---|
| Empty `catch` blocks | **0** |
| Catch blocks that swallow silently | **0** |
| Catch sites vs. logging sites | 39 catches / 55 log-or-report sites |
| Global handlers installed | `FlutterError.onError`, `PlatformDispatcher.onError`, `ErrorWidget.builder` |

### 2.5 Data integrity — the guardrail that matters most

| Check | Result |
|---|---|
| `Random()` in financial calculations | **0** |
| — the 3 `Random()` sites are: | ID generation; **retry backoff jitter** (`base * 2^attempt + jitter`, verified at `market_data_client.dart:501`); **seeded** sample data |
| Fabricated fallbacks in `domain/` | **none** — missing fundamentals report a *gap*, missing price data reports *unavailable* |

### 2.6 Memory and performance

| Check | Result |
|---|---|
| Rolling candle buffer cap | **present** — `AppLimits.rollingCandleCap = 5000`, evicts oldest |
| Chart downsampling | **present** — `_downsample()` caps series at 600 points |
| `RepaintBoundary` on chart widgets | **present** |
| Unbounded list growth on the hot path | **none found** — the research pipeline releases each candidate's equity curve after reading its metrics |

### 2.7 Null safety

18 force-unwraps (`!`) were reviewed individually. Every one is guarded:

- `indicators.dart:111` — behind explicit `!= null` checks on the preceding line
- `strategy_spec.dart:144/148` — inside an `isConstant ? … : ref!` ternary
- `strategy_spec.dart:297`, `app_database_io.dart:352` — behind `== null ? null : …`
- `swarm_io.dart:51/52` — after the server-start lifecycle guarantees a server
- `supply_chain_graph.dart` — map entries created by `addNode` before any edge

**No unsafe dereference found.**

### 2.8 Build health

```
flutter analyze   → No issues found!
flutter test      → All tests passed! (236)
```

---

## 3. Remediation detail

### A1 — Strict type checking enabled (High)

The project was including only `package:flutter_lints/flutter.yaml`, which is a
*recommended* set, not a strict one. For a quantitative engine that is the wrong
default: a `dynamic` that flows into a price, or a raw `Map` whose contents are
never type-checked, is a correctness bug waiting to happen.

`analysis_options.yaml` now sets:

```yaml
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
```

plus 24 additional rules covering correctness, async discipline, immutability and
robustness.

**This surfaced 63 issues.** All were resolved:

- **34** auto-fixed with `dart fix --apply` (`const`/`final` trivia).
- **5 `strict_raw_type`** — real: untyped `Map`/`List` in the JSON and swarm
  parsers. Now `Map<dynamic, dynamic>` / `List<dynamic>?`.
- **5 `discarded_futures`** — real: fire-and-forget calls (log persistence, UI
  actions). Each is now wrapped in an explicit `unawaited(...)`, so the intent is
  stated in the code rather than implied.
- **3 `inference_failure_on_collection_literal`** — untyped empty literals, now
  `const <dynamic>[]` / `<dynamic>[]`.

### A2 — Documentation drift (Medium)

`README.md` claimed "38 tests" in its command block and "110 tests across" in its
testing section; `SCOPE.md` claimed 110 and 187. The real figure was 236. Stale
numbers in a handoff document are a small lie that erodes trust in the large
claims, so they are corrected.

### A3 — Dead provider (Low)

`newIdProvider` was defined in `core_providers.dart` and referenced nowhere;
`Ids.newId` is called directly at every site. Removed, along with the now-unused
`core/ids.dart` import.

### A4 — Two lint rules I proposed were wrong (Low)

- `avoid_slow_async_io` pushes you toward the **synchronous** `dart:io` calls,
  which block the UI thread. Async IO is correct in a Flutter app, so this rule
  would make the app worse. Disabled, with the reason recorded in the config.
- `unnecessary_await_in_return` is deprecated. Removed.

Recording *why* a rule is off is the point: a future reader sees a decision, not
an omission.

---

## 4. Residual risk — stated, not hidden

1. **CI has not yet re-run at v1.6.1.** The fixes pass `flutter analyze` and the
   full 236-test suite locally; the CI pipeline is the confirmation step.
2. **Fundamental data depends on SEC EDGAR availability.** Rate limits surface as
   a "Data Feed Unavailable" state; they never fabricate a figure.
3. **Options and GEX run on a labelled simulated chain or your own data** — there
   is no live options feed, and the UI says so.
4. **Binance and the keyed market-data providers remain unverified end-to-end**
   from the build sandbox (egress blocked / no key). Carried forward in
   `KNOWN_ISSUES.md`.
5. **The APKs are debug-key signed.** Fine for installation and testing; a release
   keystore is needed for store distribution.

---

## 5. How to reproduce this audit

```bash
# static integrity
grep -rn --include=*.dart -E "TODO|FIXME|placeholder" lib/            # expect: none
grep -rniE "api[_-]?key|secret|token|password" lib/ | grep "['\"][A-Za-z0-9]{12,}"   # expect: none
grep -rn --include=*.dart "Random(" lib/                              # expect: 3, all benign

# structure
#   compare NavDestination values against app_shell cases and sidebar icons
#   compare *_screen.dart files against screens.dart exports

# health
flutter analyze     # expect: No issues found!
flutter test        # expect: All tests passed! (236)
```
