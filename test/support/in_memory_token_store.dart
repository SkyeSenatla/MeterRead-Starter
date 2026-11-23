import 'package:meterread/core/network/token_store.dart';

/// A token store in memory: there is no Keystore in a test. Don't change
/// this file: your instructor's checks use it too.
final class InMemoryTokenStore implements TokenStore {
  /// Creates the store, optionally holding [refreshToken] already.
  new([this.refreshToken]);

  /// What's stored now. Tests may look.
  String? refreshToken;

  @override
  Future<String?> read() async => refreshToken;

  @override
  Future<void> write(String refreshToken) async =>
      this.refreshToken = refreshToken;

  @override
  Future<void> delete() async => refreshToken = null;
}
