/// dart:io book library: fetches public-domain texts and stores them on disk.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/knowledge/book_framework.dart';
import 'book_library.dart';

class IoBookLibrary implements BookLibrary {
  final Dio _dio;
  IoBookLibrary({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 5),
            ));

  @override
  bool get supported => true;

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'library'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _indexFile() async => File(p.join((await _dir()).path, 'index.json'));

  @override
  Future<List<LibraryEntry>> installed() async {
    final f = await _indexFile();
    if (!await f.exists()) return const [];
    try {
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final out = <LibraryEntry>[];
      for (final v in raw.values) {
        final m = v as Map<String, dynamic>;
        final path = m['path'] as String;
        if (!await File(path).exists()) continue;
        out.add(LibraryEntry(
          id: m['id'] as String,
          title: m['title'] as String,
          author: (m['author'] as String?) ?? '',
          gutenbergId: (m['gid'] as num?)?.toInt(),
          bytes: (m['bytes'] as num?)?.toInt() ?? 0,
          words: (m['words'] as num?)?.toInt() ?? 0,
          fetchedAt: DateTime.fromMillisecondsSinceEpoch((m['at'] as num?)?.toInt() ?? 0),
          userSupplied: ((m['own'] as num?)?.toInt() ?? 0) == 1,
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveIndex(Map<String, Map<String, dynamic>> map) async {
    final f = await _indexFile();
    await f.writeAsString(jsonEncode(map), flush: true);
  }

  Future<Map<String, Map<String, dynamic>>> _loadIndex() async {
    final f = await _indexFile();
    if (!await f.exists()) return {};
    try {
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return raw.map((k, v) => MapEntry(k, (v as Map).cast<String, dynamic>()));
    } catch (_) {
      return {};
    }
  }

  @override
  Future<LibraryEntry> fetchPublicDomain(
    BookRef book, {
    void Function(BookFetchProgress progress)? onProgress,
  }) async {
    final gid = book.gutenbergId;
    if (gid == null) {
      throw StateError('"${book.title}" is not public domain, so it cannot be downloaded. Add your own copy instead.');
    }
    final dir = await _dir();
    final id = 'gutenberg-$gid';
    final target = p.join(dir.path, '$id.txt');

    await _dio.download(
      'https://www.gutenberg.org/cache/epub/$gid/pg$gid.txt',
      target,
      onReceiveProgress: (received, total) =>
          onProgress?.call(BookFetchProgress(title: book.title, received: received, total: total)),
    );

    final text = await File(target).readAsString();
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    final index = await _loadIndex();
    index[id] = {
      'id': id,
      'title': book.title,
      'author': book.author,
      'gid': gid,
      'path': target,
      'bytes': await File(target).length(),
      'words': words,
      'at': DateTime.now().millisecondsSinceEpoch,
      'own': 0,
    };
    await _saveIndex(index);

    return LibraryEntry(
      id: id,
      title: book.title,
      author: book.author,
      gutenbergId: gid,
      bytes: await File(target).length(),
      words: words,
      fetchedAt: DateTime.now(),
      userSupplied: false,
    );
  }

  @override
  Future<LibraryEntry> addOwnCopy({
    required String title,
    required String author,
    required String text,
  }) async {
    final dir = await _dir();
    final id = 'own-${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
    final target = p.join(dir.path, '$id.txt');
    await File(target).writeAsString(text, flush: true);
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    final index = await _loadIndex();
    index[id] = {
      'id': id,
      'title': title,
      'author': author,
      'path': target,
      'bytes': await File(target).length(),
      'words': words,
      'at': DateTime.now().millisecondsSinceEpoch,
      'own': 1,
    };
    await _saveIndex(index);

    return LibraryEntry(
      id: id,
      title: title,
      author: author,
      gutenbergId: null,
      bytes: await File(target).length(),
      words: words,
      fetchedAt: DateTime.now(),
      userSupplied: true,
    );
  }

  @override
  Future<void> remove(String id) async {
    final index = await _loadIndex();
    final rec = index.remove(id);
    if (rec != null) {
      final f = File(rec['path'] as String);
      if (await f.exists()) await f.delete();
    }
    await _saveIndex(index);
  }

  @override
  Future<String?> readText(String id) async {
    final index = await _loadIndex();
    final rec = index[id];
    if (rec == null) return null;
    final f = File(rec['path'] as String);
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  @override
  Future<List<BookPassage>> search(String query, {int maxPerBook = 3}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final entries = await installed();
    final out = <BookPassage>[];
    for (final e in entries) {
      final text = await readText(e.id);
      if (text == null) continue;
      var found = 0;
      var from = 0;
      final lower = text.toLowerCase();
      while (found < maxPerBook) {
        final at = lower.indexOf(q, from);
        if (at < 0) break;
        final start = at - 90 < 0 ? 0 : at - 90;
        final end = at + q.length + 110 > text.length ? text.length : at + q.length + 110;
        out.add(BookPassage(
          bookTitle: e.title,
          snippet: text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim(),
        ));
        found++;
        from = at + q.length;
      }
    }
    return out;
  }
}
