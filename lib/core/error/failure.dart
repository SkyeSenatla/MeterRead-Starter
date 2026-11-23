import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Everything that can go wrong, as one type. Repositories turn Dio's
/// errors into a [Failure]; screens turn a [Failure] into words. Nothing
/// above the data layer ever sees a `DioException`.
sealed class Failure implements Exception {
  const new();

  /// Whether asking again by itself can help: only when there was no answer
  /// at all. A 400, 404 or 500 gets the same answer next time.
  bool get retryable => false;

  /// A short code the phone can keep, for [Failure.decode].
  String get code;

  /// The failure whose [code] was kept earlier, or null for text this app
  /// didn't write.
  static Failure? decode(String? code) => switch (code) {
    'noSignal' => const NoSignal(),
    'notFound' => const NotFound(),
    'signedOut' => const SessionEnded(),
    'unexpected' => const Unexpected(),
    final text? when text.startsWith('server:') => ServerCrash(
      reference: text.length > 7 ? text.substring(7) : null,
    ),
    final text? when text.startsWith('input:') => InvalidInput(
      message: text.substring(6),
    ),
    _ => null,
  };
}

/// No answer at all: no signal, or the connection dropped or timed out.
final class NoSignal extends Failure {
  /// Creates the failure.
  const new();

  @override
  bool get retryable => true;

  @override
  String get code => 'noSignal';
}

/// The server answered 404: there is no such thing.
final class NotFound extends Failure {
  /// Creates the failure.
  const new();

  @override
  String get code => 'notFound';
}

/// The server answered 5xx: its fault, not the reader's.
final class ServerCrash extends Failure {
  /// Creates the failure. [reference] is the ProblemDetails `traceId`.
  const new({this.reference});

  /// What support asks for, or null if the server didn't send one.
  final String? reference;

  @override
  String get code => reference == null ? 'server:' : 'server:$reference';
}

/// The server answered 400: what was sent isn't acceptable.
final class InvalidInput extends Failure {
  /// Creates the failure.
  const new({this.message, this.fields = const {}});

  /// The server's own words for the whole request, if it had any.
  final String? message;

  /// The server's words per field: `{'value': ['That's lower than …']}`.
  final Map<String, List<String>> fields;

  /// The server's words for [field], joined, or null.
  String? forField(String field) {
    final messages = fields[field];
    return messages == null || messages.isEmpty ? null : messages.join(' ');
  }

  @override
  String get code => 'input:${message ?? ''}';
}

/// The session is over (a 401 that a refresh couldn't fix): sign in again.
final class SessionEnded extends Failure {
  /// Creates the failure.
  const new();

  @override
  String get code => 'signedOut';
}

/// Anything else: a bug, or an answer this app doesn't understand.
final class Unexpected extends Failure {
  /// Creates the failure.
  const new();

  @override
  String get code => 'unexpected';
}

/// The one place every error becomes a [Failure].
Failure failureFrom(Object error) {
  if (error is Failure) return error;
  // `(a, b).wait` throws this, wrapping whatever its futures threw.
  if (error is ParallelWaitError<Object?, Object?>) {
    final cause = switch (error.errors) {
      (final AsyncError? first, final AsyncError? second) =>
        first?.error ?? second?.error,
      _ => null,
    };
    return cause == null ? const Unexpected() : failureFrom(cause);
  }
  if (error is! DioException) return const Unexpected();

  final response = error.response;
  if (response == null) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const NoSignal(),
      _ => const Unexpected(),
    };
  }
  final problem = _problemOf(response.data);
  final status = response.statusCode ?? 0;
  return switch (status) {
    401 => const SessionEnded(),
    404 => const NotFound(),
    400 || 422 => InvalidInput(
      message: problem['detail'] as String?,
      fields: _fieldsOf(problem['errors']),
    ),
    >= 500 => ServerCrash(reference: problem['traceId'] as String?),
    _ => const Unexpected(),
  };
}

Map<String, Object?> _problemOf(Object? data) {
  if (data is Map<String, Object?>) return data;
  if (data is String && data.isNotEmpty) {
    try {
      if (jsonDecode(data) case final Map<String, Object?> decoded) {
        return decoded;
      }
    } on FormatException {
      // Not JSON: no ProblemDetails to read.
    }
  }
  return const {};
}

Map<String, List<String>> _fieldsOf(Object? errors) => switch (errors) {
  final Map<Object?, Object?> map => {
    for (final entry in map.entries)
      '${entry.key}': [
        if (entry.value case final List<Object?> messages)
          for (final message in messages) '$message',
      ],
  },
  _ => const {},
};
