/// Web model hub: no filesystem, so model storage is unavailable.
library;

import '../models/local_model.dart';
import 'model_hub.dart';

class WebModelHub implements ModelHub {
  @override
  bool get supported => false;

  @override
  bool get runtimeAvailable => false;

  @override
  Future<ModelManifest?> fetchManifest(String baseUrl) async => null;

  @override
  Future<List<InstalledModel>> installed() async => const [];

  @override
  Future<InstalledModel> download(
    ModelInfo model, {
    void Function(ModelDownloadProgress progress)? onProgress,
  }) async =>
      throw UnsupportedError('Model storage is only available in the Android and Windows builds.');

  @override
  Future<void> remove(String modelId) async {}
}
