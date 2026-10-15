/// Web asset-pack manager: packs are not persisted in the browser demo build.
library;

import '../models/asset_pack.dart';
import 'asset_pack_manager.dart';

class WebAssetPackManager implements AssetPackManager {
  @override
  bool get supported => false;

  @override
  Future<String?> installedPath(String packId) async => null;

  @override
  Future<Map<String, String>> installedVersions() async => {};

  @override
  Future<AssetPackManifest?> fetchManifest(String baseUrl) async => null;

  @override
  Future<void> sync(
    AssetPackManifest manifest, {
    void Function(AssetPackProgress progress)? onProgress,
  }) async {
    throw const AssetPackException('Asset packs are only available in the Android and Windows builds.');
  }

  @override
  Future<void> remove(String packId) async {}
}
