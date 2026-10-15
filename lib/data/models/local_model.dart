/// A downloadable local model (GGUF) and its on-disk state.
library;

class ModelInfo {
  final String id;
  final String name;
  final String family;
  final String quantization;
  final String parameters;
  final int sizeBytes;
  final String sha256;
  final String url;
  final String license;
  final String note;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.family,
    required this.quantization,
    required this.parameters,
    required this.sizeBytes,
    required this.sha256,
    required this.url,
    required this.license,
    this.note = '',
  });

  double get sizeMb => sizeBytes / (1024 * 1024);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'family': family,
        'quantization': quantization,
        'parameters': parameters,
        'size_bytes': sizeBytes,
        'sha256': sha256,
        'url': url,
        'license': license,
        'note': note,
      };

  factory ModelInfo.fromMap(Map<String, dynamic> m) => ModelInfo(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? m['id'] as String,
        family: (m['family'] as String?) ?? '',
        quantization: (m['quantization'] as String?) ?? '',
        parameters: (m['parameters'] as String?) ?? '',
        sizeBytes: (m['size_bytes'] as num?)?.toInt() ?? 0,
        sha256: (m['sha256'] as String?) ?? '',
        url: (m['url'] as String?) ?? '',
        license: (m['license'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
      );
}

class ModelManifest {
  final String version;
  final List<ModelInfo> models;

  const ModelManifest({required this.version, required this.models});

  Map<String, dynamic> toMap() => {'version': version, 'models': models.map((m) => m.toMap()).toList()};

  factory ModelManifest.fromJson(Map<String, dynamic> m) => ModelManifest(
        version: (m['version'] as String?) ?? '1',
        models: ((m['models'] as List?) ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => ModelInfo.fromMap(e.cast<String, dynamic>()))
            .toList(),
      );
}

/// A model that is present on this device.
class InstalledModel {
  final ModelInfo info;
  final String path;
  final int bytesOnDisk;
  final DateTime installedAt;

  const InstalledModel({
    required this.info,
    required this.path,
    required this.bytesOnDisk,
    required this.installedAt,
  });

  double get sizeMb => bytesOnDisk / (1024 * 1024);
}
