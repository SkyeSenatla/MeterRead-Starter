import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'token_store.g.dart';

/// Refresh tokens survive app restarts, never in ordinary preferences.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String refreshToken);
  Future<void> delete();
}

final class SecureTokenStore implements TokenStore {
  const new([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _key = 'refresh_token';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String refreshToken) =>
      _storage.write(key: _key, value: refreshToken);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

@Riverpod(keepAlive: true)
TokenStore tokenStore(Ref ref) => const SecureTokenStore();
