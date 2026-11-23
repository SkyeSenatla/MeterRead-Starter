import 'package:drift/drift.dart';
import 'package:meterread/app/database/app_database.dart';
import 'package:meterread/features/round/data/outbox_tables.dart';
import 'package:meterread/features/round/domain/meter.dart';
import 'package:uuid/uuid.dart';

part 'outbox_dao.g.dart';

/// The outbox: readings waiting for the server.
@DriftAccessor(tables: [PendingReadings])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  /// Creates the DAO.
  new(super.attachedDatabase);

  /// Keeps a reading for [meterId], replacing any earlier one, and gives it
  /// its Idempotency-Key. The key is made here, once, when the reader taps
  /// Save: every attempt to send this reading uses it, so the server stores
  /// the reading once however many times it hears it.
  Future<void> capture(
    String meterId, {
    required int value,
    required bool meterReplaced,
  }) => into(pendingReadings).insertOnConflictUpdate(
    PendingReadingsCompanion.insert(
      meterId: meterId,
      value: value,
      meterReplaced: meterReplaced,
      idempotencyKey: Value(const Uuid().v4()),
      capturedAt: DateTime.now(),
      lastError: const Value(null),
    ),
  );

  /// The reading waiting for [meterId], if any.
  Future<WaitingReading?> readFor(String meterId) async =>
      _waiting(await _one(meterId).getSingleOrNull());

  /// The reading waiting for [meterId], and again whenever it changes.
  Stream<WaitingReading?> watchFor(String meterId) =>
      _one(meterId).watchSingleOrNull().map(_waiting);

  /// The key for the reading waiting for [meterId]. Made at capture; a row
  /// without one (from an older version of the app) gets one now, once.
  Future<String?> keyFor(String meterId) async {
    final row = await _one(meterId).getSingleOrNull();
    if (row == null) return null;
    if (row.idempotencyKey case final key?) return key;
    final key = const Uuid().v4();
    await (update(pendingReadings)..where((p) => p.meterId.equals(meterId)))
        .write(PendingReadingsCompanion(idempotencyKey: Value(key)));
    return key;
  }

  /// Notes why the last attempt didn't get through.
  Future<void> setError(String meterId, String message) =>
      (update(pendingReadings)..where((p) => p.meterId.equals(meterId))).write(
        PendingReadingsCompanion(lastError: Value(message)),
      );

  /// The server has it, or the reader discarded it.
  Future<void> remove(String meterId) =>
      (delete(pendingReadings)..where((p) => p.meterId.equals(meterId))).go();

  SimpleSelectStatement<$PendingReadingsTable, PendingReading> _one(
    String meterId,
  ) => select(pendingReadings)..where((p) => p.meterId.equals(meterId));

  static WaitingReading? _waiting(PendingReading? row) => switch (row) {
    null => null,
    final row => (
      meterId: row.meterId,
      value: row.value,
      meterReplaced: row.meterReplaced,
      idempotencyKey: row.idempotencyKey,
      lastError: row.lastError,
    ),
  };
}
