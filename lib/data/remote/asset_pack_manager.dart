/// Runtime asset-pack manager.
///
/// Large resources live in a separate assets repository, split into chunks. At
/// runtime the app downloads the chunks, reassembles the file, verifies its
/// SHA-256 and stores it locally for offline use. This keeps the app binary
/// small while still allowing rich, fully-offline content.
library;

import '../models/asset_pack.dart';

class AssetPackProgress {
  final String packId;
  final int receivedBytes;
  final int totalBytes;
  final bool done;
  final String? error;

  const AssetPackProgress({
    required this.packId,
    required this.receivedBytes,
    required this.totalBytes,
    this.done = false,
    this.error,
  });

  double get fraction => totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0, 1);
}

abstract class AssetPackManager {
  /// True when this platform can persist downloaded packs.
  bool get supported;

  /// Path (or identifier) where a pack file lives once installed.
  Future<String?> installedPath(String packId);

  /// Reads the installed version map (packId -> version).
  Future<Map<String, String>> installedVersions();

  /// Fetches and parses the manifest at `baseUrl/manifest.json`.
  Future<AssetPackManifest?> fetchManifest(String baseUrl);

  /// Fetches and installs the manifest's packs that are missing or outdated.
  /// Emits progress through [onProgress].
  Future<void> sync(
    AssetPackManifest manifest, {
    void Function(AssetPackProgress progress)? onProgress,
  });

  /// Removes an installed pack.
  Future<void> remove(String packId);
}

class AssetPackException implements Exception {
  final String message;
  const AssetPackException(this.message);
  @override
  String toString() => message;
}
