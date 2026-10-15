/// Selects the database implementation for the current platform.
///
/// Defaults to the web (in-memory) backend and switches to the SQLite backend
/// when `dart:io` is available (Android, Windows, desktop).
library;

export 'database_factory_web.dart' if (dart.library.io) 'database_factory_io.dart';
