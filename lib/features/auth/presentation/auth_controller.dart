import 'dart:async';

import 'package:meterread/app/network/dio_provider.dart';
import 'package:meterread/core/network/access_token.dart';
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

  // On launch: one refresh with the stored token, if there is one.
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
    } on Object {
      await store.delete();
      state = const SignedOut();
    }
  }

  /// Signs in. Throws whatever the API call throws.
  Future<void> signIn(String email, String password) async {
    final pair = await ref
        .read(authApiProvider)
        .signIn(email.trim().toLowerCase(), password);
    await _keep(pair);
    state = SignedIn(pair.reader);
  }

  /// Signs out: tells the API, then forgets the tokens.
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
    await store.delete();
    ref.read(accessTokenProvider.notifier).clear();
    state = const SignedOut();
  }

  /// The API refused a refresh: sign in again.
  Future<void> sessionEnded() async {
    await ref.read(tokenStoreProvider).delete();
    ref.read(accessTokenProvider.notifier).clear();
    state = const SignedOut();
  }

  Future<void> _keep(TokenPair pair) async {
    await ref.read(tokenStoreProvider).write(pair.refreshToken);
    ref
        .read(accessTokenProvider.notifier)
        .save(pair.accessToken, expiresAt: pair.expiresAt);
  }
}
