/// A minimal, typed result type used across the data and domain layers.
/// Errors are values, never silently swallowed.
library;

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  /// Returns the value or throws the [Failure] as an [AppException].
  T get valueOrThrow => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>(:final message) => throw AppException(message),
      };

  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>() => null,
      };

  R when<R>({
    required R Function(T value) success,
    required R Function(String message) failure,
  }) =>
      switch (this) {
        Success<T>(:final value) => success(value),
        Failure<T>(:final message) => failure(message),
      };
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends Result<T> {
  final String message;
  final Object? cause;
  const Failure(this.message, [this.cause]);
}

class AppException implements Exception {
  final String message;
  const AppException(this.message);
  @override
  String toString() => message;
}

/// Typed, user-facing error categories. Each maps to a friendly message and a
/// suggested recovery action in the UI.
enum ErrorKind {
  network('Network unavailable. Check your connection and try again.'),
  timeout('The request timed out. Please try again.'),
  auth('Your API key was rejected. Verify it in Settings \u2192 API Keys.'),
  rateLimit('Rate limit reached. Wait a moment before retrying.'),
  parse('The file or response could not be parsed.'),
  notFound('The requested item no longer exists.'),
  storage('Local storage error. Check available disk space.'),
  validation('Some inputs are invalid. Please review the highlighted fields.'),
  permission('Permission denied. Grant access and try again.'),
  unknown('Something went wrong. Please try again.');

  const ErrorKind(this.message);
  final String message;
}
