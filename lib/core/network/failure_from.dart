import 'dart:async';

import 'package:dio/dio.dart';
import 'package:meterread/core/failures/failure.dart';

Failure failureFrom(Object error) {
  if (error is Failure) return error;

  if (error is ParallelWaitError<Object?, Object?>) {
    final causes = switch (error.errors) {
      (final AsyncError? first, final AsyncError? second) => [
        if (first != null) first.error,
        if (second != null) second.error,
      ],
      final Iterable<Object?> errors => [
        for (final cause in errors)
          if (cause is AsyncError) cause.error,
      ],
      _ => const <Object>[],
    };
    return causes.isEmpty
        ? const UnexpectedFailure()
        : failureFrom(causes.first);
  }

  if (error is! DioException) return const UnexpectedFailure();
  if (error.error case final Failure failure) return failure;

  final response = error.response;
  if (response == null) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const NoSignalFailure(),
      _ => const UnexpectedFailure(),
    };
  }

  final json = switch (response.data) {
    final Map<String, Object?> data => data,
    _ => const <String, Object?>{},
  };
  final reference = json['traceId'] is String
      ? json['traceId']! as String
      : null;

  switch (response.statusCode) {
    case 400 || 422:
      final fields = <String, List<String>>{};
      if (json['errors'] case final Map<Object?, Object?> errors) {
        for (final MapEntry(:key, :value) in errors.entries) {
          if (key is String && value is List<Object?>) {
            fields[key] = List<String>.unmodifiable(value.whereType<String>());
          }
        }
      }
      return ValidationFailure(
        Map<String, List<String>>.unmodifiable(fields),
        reference: reference,
      );
    case 401:
      return SignedOutFailure(reference: reference);
    case 404:
      return NotFoundFailure(reference: reference);
    case final int status when status >= 500:
      return ServerFailure(reference: reference);
    default:
      return UnexpectedFailure(reference: reference);
  }
}

Future<T> withFailures<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on Object catch (error, stack) {
    Error.throwWithStackTrace(failureFrom(error), stack);
  }
}
