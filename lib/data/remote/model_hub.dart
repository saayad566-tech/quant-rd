/// Local model hub: discover, download, verify, list and remove on-device
/// models (GGUF format).
///
/// This backend is fully real — it fetches a manifest, streams a model to disk
/// with progress, verifies the SHA-256, and manages an on-device index.
///
/// **Important and deliberate:** this hub acquires and manages models. It does
/// *not* claim to run inference. Executing a GGUF requires a native runtime
/// (llama.cpp or equivalent) that is not bundled with this app; the UI states
/// that plainly rather than pretending to answer questions it cannot.
library;

import '../models/local_model.dart';

class ModelDownloadProgress {
  final String modelId;
  final int receivedBytes;
  final int totalBytes;
  final bool done;

  const ModelDownloadProgress({
    required this.modelId,
    required this.receivedBytes,
    required this.totalBytes,
    this.done = false,
  });

  double get fraction => totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0.0, 1.0);
}

abstract class ModelHub {
  /// Whether on-disk model storage is available on this platform.
  bool get supported;

  /// Whether an inference runtime is present. Always false in this build; kept
  /// explicit so the UI never implies otherwise.
  bool get runtimeAvailable;

  /// Fetches and parses `baseUrl/manifest.json`.
  Future<ModelManifest?> fetchManifest(String baseUrl);

  /// Models already present on this device.
  Future<List<InstalledModel>> installed();

  /// Downloads a model, verifying its hash, and returns its on-disk record.
  Future<InstalledModel> download(
    ModelInfo model, {
    void Function(ModelDownloadProgress progress)? onProgress,
  });

  /// Deletes a model from the device.
  Future<void> remove(String modelId);
}
