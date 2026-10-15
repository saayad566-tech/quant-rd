/// Shared export helper: saves to disk where possible and always copies to the
/// clipboard, with a plain-English confirmation and a log entry.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/logging/activity_log.dart';
import '../../data/export/file_saver.dart';

Future<void> exportText(
  BuildContext context, {
  required String fileName,
  required String content,
  required ActivityLog log,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  String? path;
  if (canSaveToDisk) {
    try {
      path = await saveTextFile(fileName, content);
    } catch (_) {
      path = null;
    }
  }
  await Clipboard.setData(ClipboardData(text: content));
  if (path != null) {
    log.success('Exported $fileName to $path (also copied to clipboard).');
    messenger.showSnackBar(SnackBar(content: Text('Saved $fileName and copied to clipboard.')));
  } else {
    log.success('Copied $fileName to the clipboard.');
    messenger.showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
  }
}
