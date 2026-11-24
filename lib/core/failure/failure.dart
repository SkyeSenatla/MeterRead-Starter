import 'dart:async';

import 'package:dio/dio.dart';

/// Errors crossing into the UI are domain failures, never Dio exceptions.
sealed class Failure implements Exception {
  const Failure();
}

/// The request received no usable HTTP response (including a lost reply).
final class NoSignalFailure extends Failure {
  const NoSignalFailure();
}

/// The server rejected values in a form.
final class FieldFailure extends Failure {
  const FieldFailure(this.errors);

  final Map<String, List<String>> errors;
}

/// Credentials or the current session were rejected.
final class SignedOutFailure extends Failure {
  const SignedOutFailure();
}

/// The resource is not on this reader's round.
final class NotFoundFailure extends Failure {
  const NotFoundFailure();
}

/// The server failed; support can use [traceId] to find the request.
final class ServerFailure extends Failure {
  const ServerFailure(this.traceId);

  final String? traceId;
}

/// An error not covered by the public API contract.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure();
}

/// One mapping function for repositories, authentication and parallel calls.
Failure failureFrom(Object error) {
  if (error is Failure) return error;
  if (error is ParallelWaitError) {
    // Record.wait wraps both requests' failures in ParallelWaitError.
    // Prefer a useful HTTP failure over the generic wrapper.
    final errors = error.errors;
    if (errors is (Object?, Object?)) {
      final first = errors.$1;
      final second = errors.$2;
      if (first != null) return failureFrom(first);
      if (second != null) return failureFrom(second);
    }
    return const UnexpectedFailure();
  }
  if (error is! DioException) return const UnexpectedFailure();
  if (error.error is Failure) return error.error! as Failure;

  final response = error.response;
  if (response == null) return const NoSignalFailure();
  final status = response.statusCode;
  final json = response.data;
  final problem = json is Map ? json : const <String, Object?>{};
  if (status == 400 || status == 422) {
    final fields = <String, List<String>>{};
    final raw = problem['errors'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String && entry.value is List) {
          fields[entry.key as String] = [
            for (final message in entry.value as List) '$message',
          ];
        }
      }
    }
    return FieldFailure(fields);
  }
  if (status == 401 || status == 403) return const SignedOutFailure();
  if (status == 404) return const NotFoundFailure();
  if (status != null && status >= 500) {
    return ServerFailure(
      problem['traceId'] is String ? problem['traceId'] as String : null,
    );
  }
  return const UnexpectedFailure();
}
