/// Platform-selected text file saver. On web there is no filesystem, so the
/// caller falls back to the clipboard.
library;

export 'file_saver_web.dart' if (dart.library.io) 'file_saver_io.dart';
