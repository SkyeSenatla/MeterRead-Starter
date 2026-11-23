import 'token_store.dart';

class SessionWiper {
  SessionWiper(this._db, this._tokens);
  final AppDatabase _db;
  final TokenStore _tokens;

  Future<void> wipe() async {
    await _db.transaction(() async {
      for (final table in _db.allTables) {
        await _db.delete(table).go(); // every table: round, meters, outbox...
      }
    });
    await _tokens.clear(); // refresh token (secure storage) and access token
  }
}
