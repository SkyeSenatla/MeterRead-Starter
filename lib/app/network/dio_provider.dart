import 'dart:async';

import 'package:dio/dio.dart';
import 'package:meterread/core/fakes/meter_server_provider.dart';
import 'package:meterread/core/network/access_token.dart';
import 'package:meterread/core/network/session_interceptor.dart';
import 'package:meterread/core/network/token_store.dart';
import 'package:meterread/features/auth/data/auth_api.dart';
import 'package:meterread/features/auth/presentation/auth_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio_provider.g.dart';

Dio _client(Ref ref) => Dio(
  BaseOptions(
    baseUrl: 'https://api.kwanele.test/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
  ),
)..httpClientAdapter = ref.watch(meterServerProvider);

/// The app's HTTP client, with the session interceptor. Repositories use
/// it; no widget ever sees it.
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = _client(ref);
  dio.interceptors.add(
    SessionInterceptor(
      api: ref.watch(authApiProvider),
      store: ref.watch(tokenStoreProvider),
      readAccess: () => ref.read(accessTokenProvider),
      writeAccess: (token) => ref
          .read(accessTokenProvider.notifier)
          .save(token.value, expiresAt: token.expiresAt),
      retryWith: ref.watch(bareDioProvider),
      onSessionEnded: () =>
          unawaited(ref.read(authControllerProvider.notifier).sessionEnded()),
    ),
  );
  return dio;
}

/// The same client WITHOUT the session interceptor: for the auth calls,
/// and for sending a request again after a refresh.
@Riverpod(keepAlive: true)
Dio bareDio(Ref ref) => _client(ref);

/// The auth endpoints.
@Riverpod(keepAlive: true)
AuthApi authApi(Ref ref) => AuthApi(ref.watch(bareDioProvider));
