import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'access_token.g.dart';

/// An access token and when it stops working.
typedef SessionToken = ({String value, DateTime expiresAt});

/// The signed-in reader's access token, in memory only: a five-minute
/// token isn't worth writing to disk.
@Riverpod(keepAlive: true)
class AccessToken extends _$AccessToken {
  @override
  SessionToken? build() => null;

  /// Keeps the token [value] for every request until [expiresAt].
  void save(String value, {required DateTime expiresAt}) =>
      state = (value: value, expiresAt: expiresAt);

  /// Forgets the token: signed out.
  void clear() => state = null;
}
