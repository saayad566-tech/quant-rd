/// Providers for the book-framework knowledge engine.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/candle.dart';
import '../../data/remote/book_library.dart';
import '../../data/remote/book_library_factory.dart';
import '../knowledge/book_catalogue.dart';
import '../knowledge/book_framework.dart';
import '../knowledge/framework_screener.dart';
import '../knowledge/market_region.dart';
import 'core_providers.dart';

/// The active market region. Every listing in the app is filtered through it.
final marketRegionProvider = Provider<MarketRegion>((ref) {
  return ref.watch(settingsProvider).value?.marketRegion ?? MarketRegion.india;
});

// --- Book library ----------------------------------------------------------

final bookLibraryProvider = Provider<BookLibrary>((ref) => createBookLibrary());

final installedBooksProvider = FutureProvider<List<LibraryEntry>>((ref) async {
  final lib = ref.watch(bookLibraryProvider);
  if (!lib.supported) return const [];
  return lib.installed();
});

class LibraryState {
  final bool busy;
  final double progress;
  final String? message;
  final String? error;
  final List<BookPassage> passages;

  const LibraryState({this.busy = false, this.progress = 0, this.message, this.error, this.passages = const []});

  LibraryState copyWith({
    bool? busy,
    double? progress,
    String? message,
    String? error,
    List<BookPassage>? passages,
    bool clearError = false,
  }) =>
      LibraryState(
        busy: busy ?? this.busy,
        progress: progress ?? this.progress,
        message: message ?? this.message,
        error: clearError ? null : (error ?? this.error),
        passages: passages ?? this.passages,
      );
}

class BookLibraryController extends Notifier<LibraryState> {
  @override
  LibraryState build() => const LibraryState();

  /// Fetches a public-domain title from Project Gutenberg.
  Future<void> fetchPublicDomain(BookRef book) async {
    final lib = ref.read(bookLibraryProvider);
    if (!lib.supported) {
      state = state.copyWith(error: 'The book library is only available in the Android and Windows builds.');
      return;
    }
    if (!book.isPublicDomain) {
      state = state.copyWith(error: '"${book.title}" is in copyright — the app will not download it. Add your own copy instead.');
      return;
    }
    state = state.copyWith(busy: true, progress: 0, clearError: true, message: 'Downloading "${book.title}"…');
    try {
      final entry = await lib.fetchPublicDomain(book, onProgress: (p) => state = state.copyWith(progress: p.fraction));
      ref.invalidate(installedBooksProvider);
      ref.read(activityLogProvider).success('Fetched public-domain book "${entry.title}" (${entry.words} words).');
      state = state.copyWith(busy: false, message: 'Added "${entry.title}" — ${entry.words} words.');
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Download failed — $e');
    }
  }

  /// Stores a text file the user supplies for a book they own.
  Future<void> addOwnCopy({required String title, required String author, required String text}) async {
    final lib = ref.read(bookLibraryProvider);
    if (!lib.supported) {
      state = state.copyWith(error: 'The book library is only available in the Android and Windows builds.');
      return;
    }
    state = state.copyWith(busy: true, clearError: true, message: 'Indexing "$title"…');
    try {
      final entry = await lib.addOwnCopy(title: title, author: author, text: text);
      ref.invalidate(installedBooksProvider);
      ref.read(activityLogProvider).success('Indexed your copy of "${entry.title}" (${entry.words} words).');
      state = state.copyWith(busy: false, message: 'Indexed "${entry.title}".');
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Could not index that file — $e');
    }
  }

  Future<void> remove(String id) async {
    await ref.read(bookLibraryProvider).remove(id);
    ref.invalidate(installedBooksProvider);
  }

  Future<void> search(String query) async {
    state = state.copyWith(busy: true, clearError: true);
    final hits = await ref.read(bookLibraryProvider).search(query);
    state = state.copyWith(busy: false, passages: hits, message: hits.isEmpty ? 'No passages matched "$query".' : '${hits.length} passages matched.');
  }
}

final bookLibraryControllerProvider = NotifierProvider<BookLibraryController, LibraryState>(BookLibraryController.new);

// --- Framework screener ----------------------------------------------------

class ScreenState {
  final bool running;
  final String? frameworkId;
  final ScreenReport? report;
  final String? error;

  const ScreenState({this.running = false, this.frameworkId, this.report, this.error});

  ScreenState copyWith({bool? running, String? frameworkId, ScreenReport? report, String? error, bool clearError = false}) =>
      ScreenState(
        running: running ?? this.running,
        frameworkId: frameworkId ?? this.frameworkId,
        report: report ?? this.report,
        error: clearError ? null : (error ?? this.error),
      );
}

class ScreenerController extends Notifier<ScreenState> {
  @override
  ScreenState build() => const ScreenState();

  /// Screens the active workspace's datasets — already filtered to the active
  /// market region, so a US ticker can never appear in an Indian run.
  Future<void> run(String frameworkId, {int maxSymbols = 25}) async {
    final framework = frameworkById(frameworkId);
    if (framework == null) {
      state = state.copyWith(error: 'Unknown framework.');
      return;
    }
    state = ScreenState(running: true, frameworkId: frameworkId);
    try {
      final region = ref.read(marketRegionProvider);
      final wsId = await ref.read(workspaceRepositoryProvider).activeId();
      final datasets = await ref.read(datasetRepositoryProvider).all(wsId);
      final inRegion = datasets.where((d) => region.allows(d.symbol)).take(maxSymbols).toList();
      if (inRegion.isEmpty) {
        state = ScreenState(
          frameworkId: frameworkId,
          error: 'No datasets for the ${region.label} region yet. Fetch or import data for this market first.',
        );
        return;
      }
      final universe = <String, List<Candle>>{};
      for (final d in inRegion) {
        final candles = await ref.read(datasetRepositoryProvider).candles(d.id);
        if (candles.length >= 210) universe[d.symbol] = candles;
      }
      if (universe.isEmpty) {
        state = ScreenState(frameworkId: frameworkId, error: 'Every dataset is shorter than 210 bars; the framework needs at least that much history.');
        return;
      }
      final report = const FrameworkScreener().screen(framework, universe);
      state = ScreenState(frameworkId: frameworkId, report: report);
      ref.read(activityLogProvider).info(
            'Screened ${report.universeSize} ${region.label} symbols against "${framework.name}" — ${report.passing.length} passed.',
          );
    } catch (e) {
      state = ScreenState(frameworkId: frameworkId, error: 'Screen failed — $e');
    }
  }
}

final screenerControllerProvider = NotifierProvider<ScreenerController, ScreenState>(ScreenerController.new);
