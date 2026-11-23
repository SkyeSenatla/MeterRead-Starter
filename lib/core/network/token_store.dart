import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'token_store.g.dart';

/// Where the refresh token is kept between launches. Keep this interface
/// and its three methods: the test harness gives the app its own store.
abstract interface class TokenStore {
  /// The stored refresh token, or null when nobody is signed in.
  Future<String?> read();

  /// Keeps [refreshToken], replacing any earlier one.
  Future<void> write(String refreshToken);

  /// Forgets the token.
  Future<void> delete();
}

/// Keeps the refresh token in the app's preferences.
final class PrefsTokenStore implements TokenStore {
  /// Creates the store.
  new([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _key = 'refresh_token';

  @override
  Future<String?> read() => _prefs.getString(_key);

  @override
  Future<void> write(String refreshToken) =>
      _prefs.setString(_key, refreshToken);

  @override
  Future<void> delete() => _prefs.remove(_key);
}

/// The app's token store. Keep this name: the test harness overrides it.
@Riverpod(keepAlive: true)
TokenStore tokenStore(Ref ref) => PrefsTokenStore();
