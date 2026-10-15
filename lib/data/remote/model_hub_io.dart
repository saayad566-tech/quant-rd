/// dart:io model hub: streams models to disk, verifies SHA-256, and keeps an
/// on-device index.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/local_model.dart';
import 'model_hub.dart';

class IoModelHub implements ModelHub {
  final Dio _dio;
  IoModelHub({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(minutes: 30)));

  @override
  bool get supported => true;

  @override
  bool get runtimeAvailable => false;

  Future<Directory> _modelsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'models'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _indexFile() async => File(p.join((await _modelsDir()).path, 'index.json'));

  @override
  Future<ModelManifest?> fetchManifest(String baseUrl) async {
    final url = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/manifest.json';
    try {
      final res = await _dio.get<dynamic>(url);
      final data = res.data;
      if (data is Map) return ModelManifest.fromJson(data.cast<String, dynamic>());
      if (data is String) return ModelManifest.fromJson(jsonDecode(data) as Map<String, dynamic>);
      return null;
    } on DioException {
      return null;
    }
  }

  @override
  Future<List<InstalledModel>> installed() async {
    final f = await _indexFile();
    if (!await f.exists()) return const [];
    try {
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final out = <InstalledModel>[];
      for (final entry in raw.entries) {
        final m = entry.value as Map<String, dynamic>;
        final path = m['path'] as String;
        final exists = await File(path).exists();
        if (!exists) continue; // prune records whose file vanished
        out.add(InstalledModel(
          info: ModelInfo.fromMap((m['info'] as Map).cast<String, dynamic>()),
          path: path,
          bytesOnDisk: (m['bytes'] as num?)?.toInt() ?? 0,
          installedAt: DateTime.fromMillisecondsSinceEpoch((m['at'] as num?)?.toInt() ?? 0),
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveIndex(List<InstalledModel> models) async {
    final f = await _indexFile();
    final map = <String, dynamic>{
      for (final m in models)
        m.info.id: {
          'info': m.info.toMap(),
          'path': m.path,
          'bytes': m.bytesOnDisk,
          'at': m.installedAt.millisecondsSinceEpoch,
        },
    };
    await f.writeAsString(jsonEncode(map), flush: true);
  }

  @override
  Future<InstalledModel> download(
    ModelInfo model, {
    void Function(ModelDownloadProgress progress)? onProgress,
  }) async {
    if (model.url.isEmpty) {
      throw StateError('Model "${model.name}" has no download URL.');
    }
    final dir = await _modelsDir();
    final target = p.join(dir.path, '${model.id}.gguf');
    final part = '$target.part';

    await _dio.download(
      model.url,
      part,
      onReceiveProgress: (received, total) {
        onProgress?.call(ModelDownloadProgress(
          modelId: model.id,
          receivedBytes: received,
          totalBytes: total > 0 ? total : model.sizeBytes,
        ));
      },
    );

    // Verify integrity before accepting the file.
    if (model.sha256.isNotEmpty) {
      final digest = await sha256.bind(File(part).openRead()).first;
      if (digest.toString().toLowerCase() != model.sha256.toLowerCase()) {
        await File(part).delete();
        throw StateError('Checksum mismatch for "${model.name}" — download discarded.');
      }
    }

    final file = File(part);
    if (await File(target).exists()) await File(target).delete();
    await file.rename(target);

    final record = InstalledModel(
      info: model,
      path: target,
      bytesOnDisk: await File(target).length(),
      installedAt: DateTime.now(),
    );

    final current = await installed();
    final merged = [...current.where((m) => m.info.id != model.id), record];
    await _saveIndex(merged);
    onProgress?.call(ModelDownloadProgress(modelId: model.id, receivedBytes: record.bytesOnDisk, totalBytes: record.bytesOnDisk, done: true));
    return record;
  }

  @override
  Future<void> remove(String modelId) async {
    final current = await installed();
    for (final m in current.where((m) => m.info.id == modelId)) {
      final f = File(m.path);
      if (await f.exists()) await f.delete();
    }
    await _saveIndex(current.where((m) => m.info.id != modelId).toList());
  }
}
