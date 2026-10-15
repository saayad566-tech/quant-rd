/// A downloadable resource bundle (e.g. a sample market-data pack) that lives
/// in a separate assets repository and is fetched at runtime.
///
/// This is how the app keeps its own binary small while still shipping rich
/// offline content: large files are chunked in the assets repo and reassembled
/// on the device, verified by SHA-256.
library;

class AssetPack {
  final String id;
  final String name;
  final String description;
  final String version;
  final String category;
  final int sizeBytes;
  final String sha256;

  /// Ordered list of chunk URLs that, concatenated, form the pack file.
  final List<String> chunkUrls;

  /// Relative filename to store the assembled pack under (e.g. `nifty50_1d.csv`).
  final String fileName;

  const AssetPack({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.category,
    required this.sizeBytes,
    required this.sha256,
    required this.chunkUrls,
    required this.fileName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'version': version,
        'category': category,
        'size_bytes': sizeBytes,
        'sha256': sha256,
        'chunk_urls': chunkUrls,
        'file_name': fileName,
      };

  factory AssetPack.fromMap(Map<String, dynamic> m) => AssetPack(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? m['id'] as String,
        description: (m['description'] as String?) ?? '',
        version: (m['version'] as String?) ?? '1.0.0',
        category: (m['category'] as String?) ?? 'data',
        sizeBytes: (m['size_bytes'] as num?)?.toInt() ?? 0,
        sha256: (m['sha256'] as String?) ?? '',
        chunkUrls: ((m['chunk_urls'] as List?) ?? const []).map((e) => e.toString()).toList(),
        fileName: (m['file_name'] as String?) ?? '${m['id']}.csv',
      );
}

class AssetPackManifest {
  final String version;
  final DateTime generatedAt;
  final List<AssetPack> packs;

  const AssetPackManifest({required this.version, required this.generatedAt, required this.packs});

  factory AssetPackManifest.fromJson(Map<String, dynamic> m) => AssetPackManifest(
        version: (m['version'] as String?) ?? '1.0.0',
        generatedAt: DateTime.tryParse((m['generated_at'] as String?) ?? '') ?? DateTime.now(),
        packs: ((m['packs'] as List?) ?? const [])
            .map((e) => AssetPack.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Runtime state of a pack on this device.
class AssetPackStatus {
  final String packId;
  final bool installed;
  final String installedVersion;
  final int downloadedBytes;
  final bool downloading;
  final String? error;

  const AssetPackStatus({
    required this.packId,
    this.installed = false,
    this.installedVersion = '',
    this.downloadedBytes = 0,
    this.downloading = false,
    this.error,
  });

  AssetPackStatus copyWith({
    bool? installed,
    String? installedVersion,
    int? downloadedBytes,
    bool? downloading,
    String? error,
    bool clearError = false,
  }) =>
      AssetPackStatus(
        packId: packId,
        installed: installed ?? this.installed,
        installedVersion: installedVersion ?? this.installedVersion,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        downloading: downloading ?? this.downloading,
        error: clearError ? null : (error ?? this.error),
      );
}
