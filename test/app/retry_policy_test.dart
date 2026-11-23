import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterread/app/retry_policy.dart';
import 'package:meterread/core/network/failure.dart';

void main() {
  group('appRetryPolicy', () {
    test('retries no answer three times, waiting longer each time', () {
      expect(
        appRetryPolicy(0, const NoSignal()),
        const Duration(milliseconds: 200),
      );
      expect(
        appRetryPolicy(1, const NoSignal()),
        const Duration(milliseconds: 400),
      );
      expect(
        appRetryPolicy(2, const NoSignal()),
        const Duration(milliseconds: 800),
      );
      expect(appRetryPolicy(3, const NoSignal()), isNull);
    });

    test('also retries a raw connection error', () {
      final error = DioException.connectionError(
        requestOptions: RequestOptions(path: '/x'),
        reason: 'x',
      );
      expect(appRetryPolicy(0, error), isNotNull);
    });

    test('never retries an answer from the server', () {
      final answers = <Failure>[
        const NotFound(),
        const SessionEnded(),
        const FieldErrors({
          'value': ['x'],
        }),
        const ServerFault(reference: '00-aa'),
      ];
      for (final failure in answers) {
        expect(appRetryPolicy(0, failure), isNull, reason: '$failure');
      }
    });
  });
}
