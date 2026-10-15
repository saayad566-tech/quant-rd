/// The on-device book library.
///
/// Two legitimate sources only:
///  1. **Public-domain titles**, fetched in full from Project Gutenberg, which
///     hosts them for anyone to copy and reuse at no cost.
///  2. **Your own copies** — you supply the text file for a book you own.
///
/// The app never downloads an in-copyright title and never redistributes one.
library;

import '../../domain/knowledge/book_framework.dart';

class LibraryEntry {
  final String id;
  final String title;
  final String author;
  final int? gutenbergId;
  final int bytes;
  final int words;
  final DateTime fetchedAt;
  final bool userSupplied;

  const LibraryEntry({
    required this.id,
    required this.title,
    required this.author,
    required this.gutenbergId,
    required this.bytes,
    required this.words,
    required this.fetchedAt,
    required this.userSupplied,
  });

  double get sizeKb => bytes / 1024;
}

class BookFetchProgress {
  final String title;
  final int received;
  final int total;

  const BookFetchProgress({required this.title, required this.received, required this.total});

  double get fraction => total <= 0 ? 0 : (received / total).clamp(0.0, 1.0);
}

/// A search hit inside a stored book.
class BookPassage {
  final String bookTitle;
  final String snippet;

  const BookPassage({required this.bookTitle, required this.snippet});
}

abstract class BookLibrary {
  bool get supported;

  Future<List<LibraryEntry>> installed();

  /// Fetches a public-domain title from Project Gutenberg. Throws for titles
  /// that are not public domain.
  Future<LibraryEntry> fetchPublicDomain(
    BookRef book, {
    void Function(BookFetchProgress progress)? onProgress,
  });

  /// Stores a text file **you** supply for a book you own.
  Future<LibraryEntry> addOwnCopy({
    required String title,
    required String author,
    required String text,
  });

  Future<void> remove(String id);

  /// Reads a stored book's text, or null when absent.
  Future<String?> readText(String id);

  /// Case-insensitive search across the stored books, returning short snippets.
  Future<List<BookPassage>> search(String query, {int maxPerBook = 3});
}
