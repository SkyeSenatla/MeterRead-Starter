import 'package:dio/dio.dart';
import 'package:meterread/core/failure/failure.dart';
import 'package:meterread/core/network/access_token.dart';
import 'package:meterread/core/network/token_store.dart';
import 'package:meterread/features/auth/data/auth_api.dart';

/// The error queue serializes simultaneous 401s. Each failed request carries
/// its original access token so later requests reuse the first refresh.
class SessionInterceptor extends QueuedInterceptor {
  new({
    required this.api,
    required this.store,
    required this.readAccess,
    required this.writeAccess,
    required this.retryWith,
    required this.onSessionEnded,
  });

  final AuthApi api;
  final TokenStore store;
  final SessionToken? Function() readAccess;
  final void Function(SessionToken token) writeAccess;
  final Dio retryWith;
  final void Function() onSessionEnded;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (readAccess() case final token?) {
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
    // Do not refresh a retry or a request that wasn't authenticated.
    final oldAuthorization = err.requestOptions.headers['Authorization'];
    if (oldAuthorization == null) {
      handler.next(err);
      return;
    }
    try {
      var access = readAccess();
      if (access == null || oldAuthorization == 'Bearer ${access.value}') {
        final refreshToken = await store.read();
        if (refreshToken == null) {
          onSessionEnded();
          handler.next(err);
          return;
        }
        final pair = await api.refresh(refreshToken);
        await store.write(pair.refreshToken);
        access = (value: pair.accessToken, expiresAt: pair.expiresAt);
        writeAccess(access);
      }
      final options = err.requestOptions;
      options.headers['Authorization'] = 'Bearer ${access.value}';
      final response = await retryWith.fetch<Object?>(options);
      handler.resolve(response);
    } on DioException catch (refreshError) {
      // Only an explicit refusal of refresh revokes the local session.
      if (refreshError.response?.statusCode == 401 ||
          refreshError.response?.statusCode == 403) {
        onSessionEnded();
      }
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: failureFrom(refreshError),
          type: DioExceptionType.unknown,
        ),
      );
    } on Object catch (error) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: failureFrom(error),
          type: DioExceptionType.unknown,
        ),
      );
    }
  }
}
