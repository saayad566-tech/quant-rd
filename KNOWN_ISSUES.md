# KNOWN_ISSUES — Quant RD

## Open

| # | Severity | Issue | Plan |
|---|---|---|---|
| 1 | Low | Live provider fetch paths (Alpha Vantage, Twelve Data, Polygon, Finnhub, custom) are implemented to their documented JSON shapes but were not exercised end-to-end, because no API key was available in the build environment. | First run with a real key confirms; error mapping and retry logic are structurally covered by tests. Documented in-app. |
| 2 | Low | Web build stores data in memory only (session-scoped). | Web is a demo target; Android/Windows use SQLite. IndexedDB persistence is a future enhancement. |
| 3 | Low | Runtime asset-pack download is IO-only; on web it reports "only available in the Android and Windows builds". | Intended — large packs target the shipping platforms. |
| 4 | Low | `flutter_secure_storage` on Linux desktop may need a system keyring. | Linux desktop is not a shipping target (Android/Windows only). |
| 5 | Low | The Android APKs are signed with the **debug** key (the CI has no release keystore configured). | Fine for direct installation and testing. For Play Store distribution, add the `KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD` repository secrets; `release.yml` then signs with the release key automatically. |

## Closed
- **Android `.apk` could not be built in the local sandbox** (the egress proxy blocked the Gradle Plugin Portal host). Resolved by building in CI, which has full network access — the APKs now exist.
- **Windows `.exe` could not be built locally** (no Windows toolchain). Resolved via the `windows-latest` CI runner.
- Android/Windows CI builds failed because binary assets (launcher icons, `app_icon.ico`) were not committed. Fixed by committing binaries as base64.
- Web CI upload failed on the artifact storage quota. Fixed by publishing to GitHub Releases instead.
- `release.yml` was invalid (`secrets` used in a step `if:`). Fixed with a shell check.
- Backtest pending-exit ambiguity → loop rewritten.
- Warm-up over-skipping → corrected to count only referenced periods.
- `MetricTile` overflow → made overflow-proof; grid aspect relaxed.
- `csv` 8.x API change → parser migrated to `Csv` codec.
- Timezone-dependent CSV parsing → timestamps normalised to UTC.

## Non-issues (by design)
- No live trading / broker execution — research tool by design.
- No cloud sync / accounts — offline-first by design.
- No iOS artifact — no macOS available.
