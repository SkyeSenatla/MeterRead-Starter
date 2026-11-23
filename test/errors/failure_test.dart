import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterread/app/retry_policy.dart';
import 'package:meterread/core/error/failure.dart';

DioException _answered(int status, [Object? data]) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response<Object?>(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: data,
  ),
  type: DioExceptionType.badResponse,
);

DioException _unanswered(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
);

void main() {
  group('failureFrom', () {
    test('no answer at all is NoSignal', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          failureFrom(_unanswered(type)),
          isA<NoSignal>(),
          reason: '$type',
        );
      }
    });

    test('404 is NotFound', () {
      expect(failureFrom(_answered(404)), isA<NotFound>());
    });

    test('500 is a ServerCrash that carries the reference', () {
      final failure = failureFrom(_answered(500, {'traceId': '00-abc-01'}));
      expect(failure, isA<ServerCrash>());
      expect((failure as ServerCrash).reference, '00-abc-01');
    });

    test("400 is InvalidInput with the server's words per field", () {
      final failure = failureFrom(
        _answered(400, {
          'errors': {
            'value': ['Too low.'],
          },
        }),
      );
      expect(failure, isA<InvalidInput>());
      expect((failure as InvalidInput).forField('value'), 'Too low.');
    });

    test('401 is SessionEnded', () {
      expect(failureFrom(_answered(401)), isA<SessionEnded>());
    });

    test('something else is Unexpected, never raw text', () {
      expect(failureFrom(StateError('boom')), isA<Unexpected>());
    });

    test('a failed (a, b).wait gives the failure inside it', () async {
      final wait = (
        Future<int>.error(_answered(404)),
        Future<int>.value(1),
      ).wait;
      try {
        await wait;
        fail('should throw');
      } on Object catch (error) {
        expect(failureFrom(error), isA<NotFound>());
      }
    });

    test('a failure survives being kept on the phone', () {
      for (final failure in const [
        NoSignal(),
        NotFound(),
        ServerCrash(reference: 'r-1'),
        SessionEnded(),
      ]) {
        expect(Failure.decode(failure.code)?.code, failure.code);
      }
    });
  });

  group('appRetryPolicy', () {
    test('retries only when there was no answer, three times', () {
      const noSignal = NoSignal();
      expect(appRetryPolicy(0, noSignal), const Duration(milliseconds: 200));
      expect(appRetryPolicy(1, noSignal), const Duration(milliseconds: 400));
      expect(appRetryPolicy(2, noSignal), const Duration(milliseconds: 800));
      expect(appRetryPolicy(3, noSignal), isNull);
    });

    test('a raw Dio timeout counts as no answer too', () {
      expect(
        appRetryPolicy(0, _unanswered(DioExceptionType.receiveTimeout)),
        isNotNull,
      );
    });

    test('never retries a 400, 404 or 500', () {
      for (final status in [400, 404, 500]) {
        expect(appRetryPolicy(0, _answered(status)), isNull, reason: '$status');
      }
    });

    test('never retries a failure that is not "no answer"', () {
      expect(appRetryPolicy(0, const ServerCrash()), isNull);
      expect(appRetryPolicy(0, const NotFound()), isNull);
      expect(appRetryPolicy(0, const InvalidInput()), isNull);
    });
  });
}
