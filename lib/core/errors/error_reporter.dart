/// Self-healing error reporting framework.
///
/// Installs global handlers so no error is ever silently lost: framework errors,
/// platform errors and build errors are all converted into plain-English log
/// lines, and a friendly fallback widget replaces the red error screen. The app
/// keeps running wherever possible.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logging/activity_log.dart';

class ErrorReporter {
  final ActivityLog log;
  ErrorReporter(this.log);

  /// Installs the global handlers. Call once, right after the bindings are
  /// initialised and before `runApp`.
  void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      log.error(describeError(details.exception, details.stack, context: 'UI'));
      // Preserve the default console behaviour in debug builds.
      (previous ?? FlutterError.presentError)(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      log.error(describeError(error, stack, context: 'Background'));
      return true; // handled — do not crash the isolate
    };

    // Replace the red error screen with a calm, self-explanatory fallback.
    ErrorWidget.builder = (FlutterErrorDetails details) => _FallbackErrorWidget(
          message: describeError(details.exception, details.stack),
        );
  }

  /// Turns any error into a short, human sentence. Never leaks stack traces to
  /// the user; the raw detail goes to the debug console only.
  static String describeError(Object error, StackTrace? stack, {String context = ''}) {
    final prefix = context.isEmpty ? '' : '$context error: ';
    final raw = error.toString();

    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return '${prefix}No internet connection. Your saved data is still available offline.';
    }
    if (raw.contains('TimeoutException') || raw.contains('timed out')) {
      return '${prefix}The request took too long. Please try again.';
    }
    if (raw.contains('MissingPluginException')) {
      return '${prefix}This feature is not available on this platform.';
    }
    if (raw.contains('PathAccessException') || raw.contains('Permission denied')) {
      return '${prefix}The app could not access storage. Check available space and permissions.';
    }
    if (raw.contains('FormatException') || raw.contains('Format error')) {
      return '${prefix}Some data could not be read. Check the file format and try again.';
    }
    if (raw.contains('DatabaseException')) {
      return '${prefix}Local storage reported a problem. Try restarting the app.';
    }

    // Generic, still human: strip the noisy "Exception:" prefix.
    final clean = raw.replaceFirst(RegExp(r'^[A-Za-z]*Exception:?\s*'), '').trim();
    final short = clean.length > 160 ? '${clean.substring(0, 160)}\u2026' : clean;
    return '${prefix}Something went wrong: ${short.isEmpty ? 'unknown error' : short}';
  }
}

class _FallbackErrorWidget extends StatelessWidget {
  final String message;
  const _FallbackErrorWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E1630),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24), size: 34),
          const SizedBox(height: 12),
          const Text(
            'This section hit a problem',
            style: TextStyle(color: Color(0xFFE6EDF7), fontSize: 15, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'The rest of the app keeps working. See Settings \u2192 Activity Log for details.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
