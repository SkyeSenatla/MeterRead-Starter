import 'package:drift/drift.dart';

/// The cached round's header: one row, the round last fetched.
class CachedRounds extends Table {
  /// Always 1: there is only ever one round on the phone.
  IntColumn get id => integer()();

  /// `Round 7 · Kwanele Ext 4`.
  TextColumn get name => text()();

  /// As the server counted them.
  IntColumn get totalMeters => integer()();

  /// As the server counted them.
  IntColumn get metersLeft => integer()();

  /// When the server sent it.
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The cached round's meters, in walking order.
class CachedMeters extends Table {
  /// `M-1001`.
  TextColumn get id => text()();

  /// 0 is the first meter on the round.
  IntColumn get position => integer()();

  /// `2 Lwandle Street`.
  TextColumn get address => text()();

  /// `KW-58210431`.
  TextColumn get meterNumber => text()();

  /// The server's word for the status: `Due`, `Read`, `Query`.
  TextColumn get status => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
