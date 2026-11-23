import 'package:dio/dio.dart';
import 'package:meterread/core/failures/failure.dart';
import 'package:meterread/core/network/access_token.dart';
import 'package:meterread/core/network/failure_from.dart';
import 'package:meterread/core/network/token_store.dart';
import 'package:meterread/features/auth/data/auth_api.dart';

class SessionInterceptor extends Interceptor {
  new({
    required this._api,
    required this._store,
    required this._readAccess,
    required this._writeAccess,
    required this._retryWith,
    required this._onSessionEnded,
  });

  final AuthApi _api;
  final TokenStore _store;
  final SessionToken? Function() _readAccess;
  final void Function(SessionToken token) _writeAccess;
  final Dio _retryWith;
  final void Function() _onSessionEnded;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_readAccess() case final token?) {
      options.headers['Authorization'] = 'Bearer ${token.value}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }
    final refreshToken = await _store.read();
    if (refreshToken == null) {
      _onSessionEnded();
      handler.next(err);
      return;
    }
    try {
      final pair = await _api.refresh(refreshToken);
      await _store.write(pair.refreshToken);
      _writeAccess((value: pair.accessToken, expiresAt: pair.expiresAt));
      final options = err.requestOptions
        ..headers['Authorization'] = 'Bearer ${pair.accessToken}';
      handler.resolve(await _retryWith.fetch<Object?>(options));
    } on Object catch (error, stack) {
      final failure = failureFrom(error);
      if (failure is SignedOutFailure) _onSessionEnded();

      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          error: failure,
          stackTrace: stack,
        ),
      );
    }
  }
}
