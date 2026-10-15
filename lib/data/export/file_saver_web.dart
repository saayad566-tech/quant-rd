/// Web has no filesystem; the UI falls back to the clipboard.
Future<String?> saveTextFile(String fileName, String content) async => null;

const bool canSaveToDisk = false;
