import 'package:dio/dio.dart';
import 'package:meterread/core/network/access_token.dart';
import 'package:meterread/core/network/token_store.dart';
import 'package:meterread/features/auth/data/auth_api.dart';

/// Puts the access token on every request. On a 401 it refreshes the
/// tokens and sends the request again.
///
/// Requests that fail together share one refresh: each refresh token works
/// once, so a second refresh with the same token would end the session.
/// And only the API refusing the refresh ends the session: no signal, a
/// timeout or a server error leaves the reader signed in.
class SessionInterceptor extends Interceptor {
  /// Creates the interceptor. retryWith is a Dio without this interceptor.
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

  // The refresh in flight, shared by every request that fails meanwhile.
  Future<TokenPair?>? _refreshing;

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

    // A request that went out with the old token, and failed after another
    // request already refreshed: no new refresh, just send it again.
    final current = _readAccess();
    final sentWith = err.requestOptions.headers['Authorization'];
    var accessToken = current?.value;
    if (current == null || sentWith == 'Bearer ${current.value}') {
      final TokenPair? pair;
      try {
        pair = await (_refreshing ??= _refresh().whenComplete(
          () => _refreshing = null,
        ));
      } on DioException catch (refreshError) {
        // No signal, a timeout or a 5xx: the session is fine, the answer
        // just didn't come. _refresh ends the session on a refusal.
        handler.next(refreshError);
        return;
      }
      if (pair == null) {
        handler.next(err);
        return;
      }
      accessToken = pair.accessToken;
    }

    final options = err.requestOptions
      ..headers['Authorization'] = 'Bearer $accessToken';
    try {
      handler.resolve(await _retryWith.fetch<Object?>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  // One refresh. Null: there is no stored token, so nobody is signed in.
  Future<TokenPair?> _refresh() async {
    final stored = await _store.read();
    if (stored == null) {
      _onSessionEnded();
      return null;
    }
    try {
      final pair = await _api.refresh(stored);
      await _store.write(pair.refreshToken);
      _writeAccess((value: pair.accessToken, expiresAt: pair.expiresAt));
      return pair;
    } on DioException catch (error) {
      if (refused(error)) _onSessionEnded();
      rethrow;
    }
  }

  /// Whether the API itself turned a refresh down: the only thing that
  /// ends a session.
  static bool refused(DioException error) =>
      switch (error.response?.statusCode) {
        401 || 403 => true,
        _ => false,
      };
}
