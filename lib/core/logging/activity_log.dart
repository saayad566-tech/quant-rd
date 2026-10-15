/// A plain-English activity log.
///
/// Every meaningful action (import, fetch, backtest, error) is recorded as a
/// human-readable line, newest first, so users can see exactly what the app did
/// without reading code or stack traces. Persisted across sessions and viewable
/// in Settings → Activity Log.
library;

import 'dart:async';
import 'dart:convert';

enum LogLevel {
  info('Info'),
  success('Done'),
  warning('Warning'),
  error('Error');

  const LogLevel(this.label);
  final String label;
}

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String message;

  const LogEntry({required this.time, required this.level, required this.message});

  Map<String, dynamic> toMap() => {'t': time.millisecondsSinceEpoch, 'l': level.name, 'm': message};

  factory LogEntry.fromMap(Map<String, dynamic> m) => LogEntry(
        time: DateTime.fromMillisecondsSinceEpoch((m['t'] as num).toInt()),
        level: LogLevel.values.firstWhere((e) => e.name == m['l'], orElse: () => LogLevel.info),
        message: m['m'] as String,
      );

  String toLine() => '[${time.toIso8601String()}] ${level.label.toUpperCase()}: $message';
}

class ActivityLog {
  final int capacity;
  final void Function(String json)? onChanged;
  final List<LogEntry> _entries = [];
  final StreamController<List<LogEntry>> _controller = StreamController<List<LogEntry>>.broadcast();

  ActivityLog({this.capacity = 300, this.onChanged});

  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Emits the current list immediately, then every change.
  Stream<List<LogEntry>> watch() async* {
    yield entries;
    yield* _controller.stream;
  }

  void add(LogLevel level, String message) {
    _entries.insert(0, LogEntry(time: DateTime.now(), level: level, message: message.trim()));
    if (_entries.length > capacity) {
      _entries.removeRange(capacity, _entries.length);
    }
    _controller.add(entries);
    onChanged?.call(toJson());
  }

  void info(String message) => add(LogLevel.info, message);
  void success(String message) => add(LogLevel.success, message);
  void warn(String message) => add(LogLevel.warning, message);
  void error(String message) => add(LogLevel.error, message);

  void clear() {
    _entries.clear();
    _controller.add(entries);
    onChanged?.call(toJson());
  }

  String toJson() => jsonEncode(_entries.map((e) => e.toMap()).toList());

  void loadFrom(String? raw) {
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      _entries
        ..clear()
        ..addAll(list.map((e) => LogEntry.fromMap(e as Map<String, dynamic>)));
      if (_entries.length > capacity) {
        _entries.removeRange(capacity, _entries.length);
      }
    } catch (_) {
      // Corrupt log — start fresh rather than crash.
      _entries.clear();
    }
  }

  /// Plain-text export of the whole log, oldest first.
  String exportText() {
    final buffer = StringBuffer();
    buffer.writeln('Quant RD activity log');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Entries: ${_entries.length}');
    buffer.writeln('-' * 60);
    for (final e in _entries.reversed) {
      buffer.writeln(e.toLine());
    }
    return buffer.toString();
  }

  void dispose() {
    _controller.close();
  }
}
