# BUILD.md — building Quant RD

All commands assume you are in the repository root.

## 1. Prerequisites

| Target  | Requires |
|---------|----------|
| All     | Flutter **3.47.7** (stable) or newer, Dart 3.13+ |
| Android | JDK 17, Android SDK (platform 36, build-tools 36.0.0) |
| Windows | Windows 10/11, Visual Studio 2022 with "Desktop development with C++" |
| Web     | Nothing beyond Flutter |

Verify your toolchain:

```bash
flutter --version
flutter doctor -v
```

## 2. First-time setup

```bash
flutter pub get
```

## 3. Verify before you build

```bash
flutter analyze     # expected: "No issues found!"
flutter test        # expected: "All tests passed!"
```

## 4. Android — APK / AAB

```bash
# Split APKs, one per ABI (smaller downloads)
flutter build apk --release --split-per-abi
# -> build/app/outputs/flutter-apk/app-arm64-v8a-release.apk  (and others)

# Universal APK
flutter build apk --release

# Google Play app bundle
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab
```

### Signing a release build

Generate a keystore **once** (never commit it):

```bash
keytool -genkeypair -v -keystore release.keystore -alias quantrd \
  -keyalg RSA -keysize 2048 -validity 10000
```

Then build with the signing environment variables set — `android/app/build.gradle.kts`
picks them up automatically and falls back to debug signing when they are absent:

```bash
export KEYSTORE_PATH=/absolute/path/release.keystore
export KEYSTORE_PASSWORD=...
export KEY_ALIAS=quantrd
export KEY_PASSWORD=...
flutter build apk --release
```

Install on a connected device / emulator:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 5. Windows — .exe

On a **Windows** machine (or the `windows-latest` CI runner):

```powershell
flutter build windows --release
# -> build\windows\x64\runner\Release\quant_rd.exe
```

Ship the entire `Release\` folder (the `.exe` needs its sibling DLLs and the
`data\` directory). The CI workflow zips it for you.

## 6. Web (offline demo)

```bash
flutter build web --release --no-wasm-dry-run
# -> build/web/   (serve with any static server)
```

## 7. Continuous integration

`.github/workflows/build.yml` runs on every push and produces downloadable
artifacts:

- `quant-rd-android-apks` — split release APKs
- `quant-rd-android-aab` — Play Store bundle
- `quant-rd-windows` — zipped Windows release folder
- `quant-rd-web` — static web build

`.github/workflows/release.yml` builds **signed** artifacts on a `v*` tag and
attaches them to a GitHub Release. Set these repository secrets for signing:
`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.

## 8. Runtime asset packs (separate repository)

Large datasets are kept out of this repo. Put them in a second repository
alongside a `manifest.json` (see `assets-repo/`), then paste that repository's
raw/release base URL into **Configs → Assets base URL** in the app and press
**Check & download packs**. Packs are chunked and SHA-256 verified.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Gradle task assembleRelease failed` downloading from `plugins.gradle.org` | Restricted network / proxy blocking the Gradle Plugin Portal | Build on a network that can reach `plugins.gradle.org`, or use the GitHub Actions workflow |
| `Could not allocate compressed class space` (JVM) | Low virtual-memory ulimit | `ulimit -v unlimited` before running Gradle |
| `Could not resolve org.jetbrains.kotlin:kotlin-gradle-plugin` | Gradle cannot reach Maven Central / Plugin Portal | Check proxy settings; Gradle honours `-Dhttps.proxyHost` / `-Dhttps.proxyPort` |
| `No issues found!` passes but app blank on web | CanvasKit needs WebGL | Use a GPU-capable browser, or run the Android/Windows build |
| Windows build fails with `MSB8020`/`MSB6006` | Visual Studio C++ workload missing | Install "Desktop development with C++" in the VS installer |
| APK installs but shows old version | ABI mismatch | Use `--split-per-abi` and install the matching `arm64-v8a` APK, or build the universal APK |
| `flutter_secure_storage` key not persisting | Linux desktop needs a keyring | Use Android/Windows for secrets; Linux desktop is not a shipping target |
