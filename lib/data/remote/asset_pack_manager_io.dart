/// dart:io asset-pack manager: downloads, reassembles, verifies and stores
/// chunked packs under the app support directory.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../models/asset_pack.dart';
import 'asset_pack_manager.dart';

class IoAssetPackManager implements AssetPackManager {
  final Dio _dio;
  Directory? _packsDir;

  IoAssetPackManager({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: AppLimits.networkTimeout,
              receiveTimeout: const Duration(minutes: 5),
            ));

  @override
  bool get supported => true;

  Future<Directory> _dir() async {
    if (_packsDir != null) return _packsDir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'packs'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _packsDir = dir;
    return dir;
  }

  Future<File> _indexFile() async => File(p.join((await _dir()).path, 'installed.json'));

  @override
  Future<Map<String, String>> installedVersions() async {
    final f = await _indexFile();
    if (!await f.exists()) return {};
    try {
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeIndex(Map<String, String> index) async {
    final f = await _indexFile();
    await f.writeAsString(jsonEncode(index));
  }

  @override
  Future<String?> installedPath(String packId) async {
    final f = await _indexFile();
    if (!await f.exists()) return null;
    final index = await installedVersions();
    if (!index.containsKey(packId)) return null;
    // The pack file name is recorded alongside; fall back to a directory scan.
    final dir = await _dir();
    await for (final entity in dir.list()) {
      if (entity is File && p.basename(entity.path).startsWith('$packId.') && p.extension(entity.path) != '.json') {
        return entity.path;
      }
    }
    return null;
  }

  @override
  Future<AssetPackManifest?> fetchManifest(String baseUrl) async {
    final url = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/manifest.json';
    try {
      final res = await _dio.get<dynamic>(url);
      final data = res.data;
      if (data is Map) {
        return AssetPackManifest.fromJson(data.cast<String, dynamic>());
      }
      if (data is String) {
        return AssetPackManifest.fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      throw AssetPackException('Could not load the asset manifest (${e.response?.statusCode ?? 'network error'}).');
    }
  }

  @override
  Future<void> sync(
    AssetPackManifest manifest, {
    void Function(AssetPackProgress progress)? onProgress,
  }) async {
    final installed = await installedVersions();
    for (final pack in manifest.packs) {
      if (installed[pack.id] == pack.version) {
        onProgress?.call(AssetPackProgress(
          packId: pack.id,
          receivedBytes: pack.sizeBytes,
          totalBytes: pack.sizeBytes,
          done: true,
        ));
        continue;
      }
      await _install(pack, onProgress);
      installed[pack.id] = pack.version;
      await _writeIndex(installed);
    }
  }

  Future<void> _install(AssetPack pack, void Function(AssetPackProgress)? onProgress) async {
    final dir = await _dir();
    final target = File(p.join(dir.path, '${pack.id}.${_ext(pack.fileName)}'));
    final builder = BytesBuilder(copy: false);
    var received = 0;

    try {
      for (final url in pack.chunkUrls) {
        final res = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = res.data ?? const <int>[];
        builder.add(bytes);
        received += bytes.length;
        onProgress?.call(AssetPackProgress(
          packId: pack.id,
          receivedBytes: received,
          totalBytes: pack.sizeBytes,
        ));
      }
      final assembled = builder.takeBytes();

      if (pack.sha256.isNotEmpty) {
        final digest = sha256.convert(assembled).toString();
        if (digest.toLowerCase() != pack.sha256.toLowerCase()) {
          throw AssetPackException('Checksum mismatch for ${pack.name}. The download may be corrupt.');
        }
      }

      await target.writeAsBytes(assembled, flush: true);
      onProgress?.call(AssetPackProgress(
        packId: pack.id,
        receivedBytes: assembled.length,
        totalBytes: assembled.length,
        done: true,
      ));
    } on AssetPackException catch (e) {
      onProgress?.call(AssetPackProgress(packId: pack.id, receivedBytes: received, totalBytes: pack.sizeBytes, error: e.message));
      rethrow;
    } catch (e) {
      onProgress?.call(AssetPackProgress(packId: pack.id, receivedBytes: received, totalBytes: pack.sizeBytes, error: 'Download failed.'));
      throw AssetPackException('Could not download ${pack.name}.');
    }
  }

  @override
  Future<void> remove(String packId) async {
    final installed = await installedVersions();
    installed.remove(packId);
    await _writeIndex(installed);
    final dir = await _dir();
    await for (final entity in dir.list()) {
      if (entity is File && p.basename(entity.path).startsWith('$packId.')) {
        await entity.delete();
      }
    }
  }

  String _ext(String fileName) {
    final e = p.extension(fileName);
    return e.isEmpty ? 'bin' : e.replaceFirst('.', '');
  }
}
