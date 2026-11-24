import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterread/app/retry_policy.dart';
import 'package:meterread/core/failure/failure.dart';

void main() {
  final request = RequestOptions(path: '/v1/meters/M-1001');

  DioException responseError(int status, Map<String, Object?> body) =>
      DioException(
        requestOptions: request,
        response: Response<Map<String, Object?>>(
          requestOptions: request,
          statusCode: status,
          data: body,
        ),
        type: DioExceptionType.badResponse,
      );

  test('maps connection errors and every API error family', () {
    final entries = <(Object, Type)>[
      (
        DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
        ),
        NoSignalFailure,
      ),
      (
        responseError(400, {
          'errors': <String, Object>{
            'value': <String>['Lower than last month.'],
          },
        }),
        FieldFailure,
      ),
      (responseError(401, {}), SignedOutFailure),
      (responseError(404, {}), NotFoundFailure),
      (responseError(500, {'traceId': 'support-reference'}), ServerFailure),
      (StateError('unexpected'), UnexpectedFailure),
    ];
    for (final (error, expectedType) in entries) {
      expect(failureFrom(error).runtimeType, expectedType);
    }
    final field = failureFrom(
      responseError(400, {
        'errors': <String, Object>{
          'value': <String>['Lower than last month.'],
        },
      }),
    ) as FieldFailure;
    expect(field.errors['value'], ['Lower than last month.']);
    final server = failureFrom(
      responseError(500, {'traceId': 'support-reference'}),
    ) as ServerFailure;
    expect(server.traceId, 'support-reference');
  });

  test('only no-answer failures are retried', () {
    for (var attempt = 0; attempt < 3; attempt++) {
      expect(
        appRetryPolicy(attempt, const NoSignalFailure()),
        Duration(milliseconds: 200 * (1 << attempt)),
      );
    }
    expect(appRetryPolicy(3, const NoSignalFailure()), isNull);
    for (final failure in <Failure>[
      const SignedOutFailure(),
      const NotFoundFailure(),
      const ServerFailure('abc'),
      const FieldFailure({}),
      const UnexpectedFailure(),
    ]) {
      expect(appRetryPolicy(0, failure), isNull);
    }
  });
}
