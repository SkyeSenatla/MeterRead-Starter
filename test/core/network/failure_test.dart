import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterread/core/network/failure.dart';

final _options = RequestOptions(path: '/x');

DioException _answer(int status, [Object? data]) => DioException.badResponse(
  statusCode: status,
  requestOptions: _options,
  response: Response<Object?>(
    requestOptions: _options,
    statusCode: status,
    data: data,
  ),
);

void main() {
  final cases = <(String, Object, Matcher)>[
    (
      'connection error is no signal',
      DioException.connectionError(requestOptions: _options, reason: 'x'),
      isA<NoSignal>(),
    ),
    (
      'connect timeout is no signal',
      DioException.connectionTimeout(
        timeout: const Duration(seconds: 10),
        requestOptions: _options,
      ),
      isA<NoSignal>(),
    ),
    (
      'send timeout is no signal',
      DioException.sendTimeout(
        timeout: const Duration(seconds: 10),
        requestOptions: _options,
      ),
      isA<NoSignal>(),
    ),
    (
      'receive timeout is no signal',
      DioException.receiveTimeout(
        timeout: const Duration(seconds: 20),
        requestOptions: _options,
      ),
      isA<NoSignal>(),
    ),
    ('401 is session ended', _answer(401), isA<SessionEnded>()),
    ('404 is not found', _answer(404), isA<NotFound>()),
    (
      '400 with errors carries the API field errors',
      _answer(400, {
        'title': 'Bad request',
        'errors': {
          'value': ['Too low.', 'Check it.'],
        },
      }),
      isA<FieldErrors>().having((f) => f.errors, 'errors', {
        'value': ['Too low.', 'Check it.'],
      }),
    ),
    (
      '400 without errors is the server fault',
      _answer(400, {'traceId': '00-aa'}),
      isA<ServerFault>().having((f) => f.reference, 'reference', '00-aa'),
    ),
    (
      '500 carries the traceId as the reference',
      _answer(500, {'traceId': '00-4bf92f35'}),
      isA<ServerFault>().having((f) => f.reference, 'reference', '00-4bf92f35'),
    ),
    (
      '500 with no body has no reference',
      _answer(500),
      isA<ServerFault>().having((f) => f.reference, 'reference', isNull),
    ),
    ('a Failure stays as it is', const NotFound(), isA<NotFound>()),
    (
      'something unexpected is the server fault',
      StateError('boom'),
      isA<ServerFault>(),
    ),
    (
      'a ParallelWaitError list gives the first failure',
      ParallelWaitError<List<int?>, List<AsyncError?>>(
        [1, null],
        [null, AsyncError(_answer(404), StackTrace.empty)],
      ),
      isA<NotFound>(),
    ),
    (
      'a ParallelWaitError record gives the first failure',
      ParallelWaitError<(int?, int?), (AsyncError?, AsyncError?)>(
        (null, null),
        (
          AsyncError(
            DioException.connectionError(requestOptions: _options, reason: 'x'),
            StackTrace.empty,
          ),
          null,
        ),
      ),
      isA<NoSignal>(),
    ),
  ];

  group('toFailure', () {
    for (final (name, error, matcher) in cases) {
      test(name, () => expect(toFailure(error), matcher));
    }
  });
}
