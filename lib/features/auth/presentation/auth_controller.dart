import 'dart:async';

import 'package:meterread/app/database/app_database.dart';
import 'package:meterread/app/network/dio_provider.dart';
import 'package:meterread/core/failure/failure.dart';
import 'package:meterread/core/network/access_token.dart';
import 'package:meterread/core/network/token_store.dart';
import 'package:meterread/features/auth/data/auth_api.dart';
import 'package:meterread/features/auth/domain/reader.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_controller.g.dart';

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  AuthState build() {
    unawaited(Future.microtask(restore));
    return const Restoring();
  }

  /// Keep the local round during temporary connection loss at startup.
  Future<void> restore() async {
    state = const Restoring();
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
    } on Object catch (error) {
      final failure = failureFrom(error);
      if (failure is SignedOutFailure) {
        await sessionEnded();
      } else {
        state = RestoreFailed(failure);
      }
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      final pair = await ref
          .read(authApiProvider)
          .signIn(email.trim().toLowerCase(), password);
      await _clearData(); // Never show a previous reader's cached round.
      await _keep(pair);
      state = SignedIn(pair.reader);
    } on Object catch (error) {
      throw failureFrom(error);
    }
  }

  Future<void> signOut() async {
    final store = ref.read(tokenStoreProvider);
    final stored = await store.read();
    if (stored != null) {
      try {
        await ref.read(authApiProvider).signOut(stored);
      } on Object {
        // Always clear local credentials and personal data, even offline.
      }
    }
    await sessionEnded();
  }

  Future<void> sessionEnded() async {
    await ref.read(tokenStoreProvider).delete();
    ref.read(accessTokenProvider.notifier).clear();
    await _clearData();
    state = const SignedOut();
  }

  Future<void> _clearData() async {
    final db = ref.read(appDatabaseProvider);
    await db.transaction(() async {
      for (final table in db.allTables) {
        await db.delete(table).go();
      }
    });
  }

  Future<void> _keep(TokenPair pair) async {
    await ref.read(tokenStoreProvider).write(pair.refreshToken);
    ref
        .read(accessTokenProvider.notifier)
        .save(pair.accessToken, expiresAt: pair.expiresAt);
  }
}
