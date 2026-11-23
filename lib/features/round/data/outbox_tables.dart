import 'package:drift/drift.dart';

/// Readings captured on the phone that the server hasn't accepted yet: at
/// most one per meter.
class PendingReadings extends Table {
  /// The meter it's for.
  TextColumn get meterId => text()();

  /// The reading, in whole kWh.
  IntColumn get value => integer()();

  /// The reader ticked "Meter replaced".
  BoolColumn get meterReplaced => boolean()();

  /// The Idempotency-Key the last attempt was sent with.
  TextColumn get idempotencyKey => text().nullable()();

  /// When the reader saved it.
  DateTimeColumn get capturedAt => dateTime()();

  /// Why the last attempt didn't get through, in the reader's words.
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {meterId};
}
