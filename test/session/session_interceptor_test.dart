import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterread/core/network/access_token.dart';
import 'package:meterread/core/network/session_interceptor.dart';
import 'package:meterread/features/auth/data/auth_api.dart';

import '../support/in_memory_token_store.dart';

typedef _Answer = Future<ResponseBody> Function(RequestOptions options);

class _Adapter implements HttpClientAdapter {
  new(this._answer);

  final _Answer _answer;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    return _answer(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody _newPair() => _json(200, {
  'accessToken': 'new-access',
  'refreshToken': 'new-refresh',
  'expiresIn': 300,
  'readerName': 'Thandeka',
  'email': 'thandeka@kwanele.test',
});

/// A phone whose access token has run out: only 'new-access' works.
class _Rig {
  new(_Answer refreshAnswer) {
    api = _Adapter((options) async {
      final ok = options.headers['Authorization'] == 'Bearer new-access';
      return ok ? _json(200, {'ok': true}) : _json(401, {'title': 'No'});
    });
    refresh = _Adapter(refreshAnswer);
    final plain = Dio(BaseOptions(baseUrl: 'https://x.test'))
      ..httpClientAdapter = api;
    dio = Dio(BaseOptions(baseUrl: 'https://x.test'))
      ..httpClientAdapter = api
      ..interceptors.add(
        SessionInterceptor(
          api: AuthApi(
            Dio(BaseOptions(baseUrl: 'https://x.test'))
              ..httpClientAdapter = refresh,
          ),
          store: store,
          readAccess: () => access,
          writeAccess: (token) => access = token,
          retryWith: plain,
          onSessionEnded: () => sessionsEnded++,
        ),
      );
  }

  late final _Adapter api;
  late final _Adapter refresh;
  late final Dio dio;
  final store = InMemoryTokenStore('old-refresh');
  SessionToken? access = (value: 'old-access', expiresAt: DateTime(2100));
  int sessionsEnded = 0;
}

void main() {
  test('requests that fail together share one refresh', () async {
    final rig = _Rig((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _newPair();
    });

    final answers = await Future.wait([
      for (var i = 0; i < 5; i++) rig.dio.get<Object?>('/meters/$i'),
    ]);

    expect(answers.map((a) => a.statusCode), everyElement(200));
    expect(rig.refresh.calls, 1);
    expect(rig.store.refreshToken, 'new-refresh');
    expect(rig.sessionsEnded, 0);
  });

  test('a late failure with the old token does not refresh again', () async {
    final rig = _Rig((_) async => _newPair());
    await rig.dio.get<Object?>('/first');
    expect(rig.refresh.calls, 1);

    // This request went out with the old token and failed after the refresh.
    final late = await rig.dio.get<Object?>(
      '/late',
      options: Options(headers: {'Authorization': 'Bearer old-access'}),
    );

    expect(late.statusCode, 200);
    expect(rig.refresh.calls, 1);
  });

  test('no signal during the refresh does not sign the reader out', () async {
    final rig = _Rig(
      (options) async => throw DioException.connectionError(
        requestOptions: options,
        reason: 'no signal',
      ),
    );

    await expectLater(
      rig.dio.get<Object?>('/meters/1'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.connectionError,
        ),
      ),
    );

    expect(rig.sessionsEnded, 0);
    expect(rig.store.refreshToken, 'old-refresh');
  });

  test('a server error during the refresh does not sign out either', () async {
    final rig = _Rig((_) async => _json(500, {'title': 'Oops'}));

    await expectLater(
      rig.dio.get<Object?>('/meters/1'),
      throwsA(isA<DioException>()),
    );

    expect(rig.sessionsEnded, 0);
    expect(rig.store.refreshToken, 'old-refresh');
  });

  test('the API refusing the refresh ends the session once', () async {
    final rig = _Rig((_) async => _json(401, {'title': 'Sign in again.'}));

    final results = await Future.wait([
      for (var i = 0; i < 3; i++)
        rig.dio
            .get<Object?>('/meters/$i')
            .then<Object?>((_) => null)
            .onError((error, _) => error),
    ]);

    expect(results, everyElement(isA<DioException>()));
    expect(rig.refresh.calls, 1);
    expect(rig.sessionsEnded, 1);
  });
}
