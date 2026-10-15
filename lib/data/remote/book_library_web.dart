/// Web book library: no filesystem, so stored books are unavailable.
library;

import '../../domain/knowledge/book_framework.dart';
import 'book_library.dart';

class WebBookLibrary implements BookLibrary {
  @override
  bool get supported => false;

  @override
  Future<List<LibraryEntry>> installed() async => const [];

  @override
  Future<LibraryEntry> fetchPublicDomain(BookRef book, {void Function(BookFetchProgress progress)? onProgress}) async =>
      throw UnsupportedError('The book library is only available in the Android and Windows builds.');

  @override
  Future<LibraryEntry> addOwnCopy({required String title, required String author, required String text}) async =>
      throw UnsupportedError('The book library is only available in the Android and Windows builds.');

  @override
  Future<void> remove(String id) async {}

  @override
  Future<String?> readText(String id) async => null;

  @override
  Future<List<BookPassage>> search(String query, {int maxPerBook = 3}) async => const [];
}
