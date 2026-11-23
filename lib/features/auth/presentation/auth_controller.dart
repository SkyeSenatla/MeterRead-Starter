import 'dart:async';

import 'package:dio/dio.dart';
import 'package:meterread/app/database/app_database.dart';
import 'package:meterread/app/network/dio_provider.dart';
import 'package:meterread/core/error/failure.dart';
import 'package:meterread/core/network/access_token.dart';
import 'package:meterread/core/network/session_interceptor.dart';
import 'package:meterread/core/network/token_store.dart';
import 'package:meterread/features/auth/data/auth_api.dart';
import 'package:meterread/features/auth/domain/reader.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_controller.g.dart';

/// Who is signed in. keepAlive: the session outlives every screen.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  AuthState build() {
    // After build returns: build itself must not change the state.
    unawaited(Future.microtask(_restore));
    return const Restoring();
  }

  // On launch: one refresh with the stored token, if there is one. Only the
  // API turning it down signs the reader out: with no signal (or a server
  // problem) the saved session is still good, so the reader goes on to the
  // round saved on the phone.
  Future<void> _restore() async {
    final store = ref.read(tokenStoreProvider);
    final stored = await store.read();
    if (stored == null) {
      state = const SignedOut();
      return;
    }
    try {
      final pair = await ref.read(authApiProvider).refresh(stored);
      await _keep(pair);
      state = SignedIn(pair.reader);
    } on DioException catch (error) {
      if (SessionInterceptor.refused(error)) {
        await sessionEnded();
      } else {
        state = const SignedIn(Reader.unknown);
      }
    } on Object {
      await sessionEnded();
    }
  }

  /// Signs in. Throws a [Failure]: [InvalidInput] when the email and
  /// password don't match.
  Future<void> signIn(String email, String password) async {
    final TokenPair pair;
    try {
      pair = await ref
          .read(authApiProvider)
          .signIn(email.trim().toLowerCase(), password);
    } on DioException catch (error) {
      final failure = failureFrom(error);
      // Here a 401 is a wrong password, not a session that ended.
      throw switch (failure) {
        SessionEnded() => InvalidInput(
          message: switch (error.response?.data) {
            {'detail': final String detail} => detail,
            _ => null,
          },
        ),
        _ => failure,
      };
    }
    await _keep(pair);
    state = SignedIn(pair.reader);
  }

  /// Signs out: tells the API, then forgets everything on the phone: the
  /// tokens and every row in the database.
  Future<void> signOut() async {
    final store = ref.read(tokenStoreProvider);
    final stored = await store.read();
    if (stored != null) {
      try {
        await ref.read(authApiProvider).signOut(stored);
      } on Object {
        // Signed out on the phone even if the API didn't hear.
      }
    }
    await _forgetEverything();
  }

  /// The API refused a refresh: the session is over, sign in again. Forgets
  /// everything on the phone, as signing out does.
  Future<void> sessionEnded() => _forgetEverything();

  Future<void> _forgetEverything() async {
    ref.read(accessTokenProvider.notifier).clear();
    await ref.read(tokenStoreProvider).delete();
    await ref.read(appDatabaseProvider).wipe();
    state = const SignedOut();
  }

  Future<void> _keep(TokenPair pair) async {
    await ref.read(tokenStoreProvider).write(pair.refreshToken);
    ref
        .read(accessTokenProvider.notifier)
        .save(pair.accessToken, expiresAt: pair.expiresAt);
  }
}
