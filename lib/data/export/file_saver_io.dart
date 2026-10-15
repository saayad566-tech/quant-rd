import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Writes [content] to `<documents>/exports/<fileName>` and returns the full
/// path so the UI can show the user exactly where the file landed.
Future<String?> saveTextFile(String fileName, String content) async {
  final dir = await getApplicationDocumentsDirectory();
  final out = Directory(p.join(dir.path, 'exports'));
  if (!await out.exists()) {
    await out.create(recursive: true);
  }
  final file = File(p.join(out.path, fileName));
  await file.writeAsString(content, flush: true);
  return file.path;
}

/// Whether this platform can write files to disk.
const bool canSaveToDisk = true;
