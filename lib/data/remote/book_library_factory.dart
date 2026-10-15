/// Selects the book library for the current platform.
library;

export 'book_library_factory_web.dart' if (dart.library.io) 'book_library_factory_io.dart';
