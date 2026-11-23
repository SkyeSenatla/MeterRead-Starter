import 'dart:async';

import 'package:dio/dio.dart';

/// Everything that can go wrong between the app and the API. Nothing above
/// the data layer sees Dio: it sees one of these.
sealed class Failure implements Exception {
  /// Creates the failure.
  const new();
}

/// No answer at all: no signal, or a timeout. The only failure worth
/// retrying.
final class NoSignal extends Failure {
  /// Creates the failure.
  const new();
}

/// The API refused the input: [errors] is its field name to messages.
final class FieldErrors extends Failure {
  /// Creates the failure.
  const new(this.errors);

  /// The API's `errors`, such as `{"value": ["That's lower than ..."]}`.
  final Map<String, List<String>> errors;
}

/// A 401: the reader isn't signed in, or the session is over.
final class SessionEnded extends Failure {
  /// Creates the failure.
  const new();
}

/// A 404: there's no such thing, or it isn't on this reader's round.
final class NotFound extends Failure {
  /// Creates the failure.
  const new();
}

/// The server's fault (a 5xx, or an answer the app can't read).
final class ServerFault extends Failure {
  /// Creates the failure.
  const new({this.reference});

  /// The server's `traceId`, the reference support asks for, if it sent one.
  final String? reference;
}

/// Runs [body]; whatever it throws comes out as a [Failure].
Future<T> guarded<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on Object catch (error, stackTrace) {
    Error.throwWithStackTrace(toFailure(error), stackTrace);
  }
}

/// Turns anything the data layer catches into a [Failure]: a DioException,
/// a ParallelWaitError from waiting on several requests, or a Failure that
/// is already one.
Failure toFailure(Object error) => switch (error) {
  final Failure failure => failure,
  final DioException dio => _fromDio(dio),
  final ParallelWaitError<Object?, Object?> parallel => _fromParallel(parallel),
  _ => const ServerFault(),
};

Failure _fromDio(DioException error) {
  if (error.error case final Failure failure) return failure;
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NoSignal(),
    DioExceptionType.badResponse => _fromResponse(error.response),
    DioExceptionType.badCertificate ||
    DioExceptionType.cancel ||
    DioExceptionType.transformTimeout ||
    DioExceptionType.unknown => const ServerFault(),
  };
}

Failure _fromResponse(Response<Object?>? response) {
  final data = response?.data;
  final problem = data is Map<Object?, Object?>
      ? data
      : const <Object?, Object?>{};
  final status = response?.statusCode;
  if (status == 401) return const SessionEnded();
  if (status == 404) return const NotFound();
  if (status == 400) {
    final errors = _fieldErrors(problem);
    if (errors != null) return FieldErrors(errors);
  }
  final reference = problem['traceId'];
  return ServerFault(reference: reference is String ? reference : null);
}

Map<String, List<String>>? _fieldErrors(Map<Object?, Object?> problem) {
  final raw = problem['errors'];
  if (raw is! Map<Object?, Object?> || raw.isEmpty) return null;
  return {
    for (final entry in raw.entries)
      '${entry.key}': [
        if (entry.value case final List<Object?> messages)
          for (final message in messages) '$message'
        else
          '${entry.value}',
      ],
  };
}

Failure _fromParallel(ParallelWaitError<Object?, Object?> error) {
  final parts = switch (error.errors) {
    final Iterable<Object?> list => list,
    (final a, final b) => [a, b],
    (final a, final b, final c) => [a, b, c],
    _ => const <Object?>[],
  };
  final first = parts.nonNulls.firstOrNull;
  if (first == null) return const ServerFault();
  return toFailure(first is AsyncError ? first.error : first);
}
