import 'package:drift/drift.dart';
import 'package:meterread/app/database/app_database.dart';
import 'package:meterread/core/cache/snapshot.dart';
import 'package:meterread/features/round/data/round_tables.dart';
import 'package:meterread/features/round/domain/meter.dart';

part 'round_dao.g.dart';

/// The phone's copy of today's round. Nothing uses it yet.
@DriftAccessor(tables: [CachedRounds, CachedMeters])
class RoundDao extends DatabaseAccessor<AppDatabase> with _$RoundDaoMixin {
  /// Creates the DAO.
  new(super.attachedDatabase);

  /// Replaces the cached round with [round], fetched at [fetchedAt].
  Future<void> save(Round round, {required DateTime fetchedAt}) =>
      transaction(() async {
        await delete(cachedMeters).go();
        await into(cachedRounds).insertOnConflictUpdate(
          CachedRoundsCompanion.insert(
            id: const Value(1),
            name: round.name,
            totalMeters: round.totalMeters,
            metersLeft: round.metersLeft,
            fetchedAt: fetchedAt,
          ),
        );
        for (final (position, meter) in round.meters.indexed) {
          await into(cachedMeters).insert(
            CachedMetersCompanion.insert(
              id: meter.id,
              position: position,
              address: meter.address,
              meterNumber: meter.meterNumber,
              status: meter.status.wireName,
            ),
          );
        }
      });

  /// The cached round, and again whenever it's saved. Null until the first
  /// round has been saved on this phone.
  Stream<Snapshot<Round>?> watch() {
    final header = select(cachedRounds)..where((r) => r.id.equals(1));
    return header.watchSingleOrNull().asyncMap((row) async {
      if (row == null) return null;
      final meters = await (select(
        cachedMeters,
      )..orderBy([(m) => OrderingTerm(expression: m.position)])).get();
      return Snapshot(
        Round(
          name: row.name,
          totalMeters: row.totalMeters,
          metersLeft: row.metersLeft,
          meters: [
            for (final meter in meters)
              MeterSummary(
                id: meter.id,
                address: meter.address,
                meterNumber: meter.meterNumber,
                status: MeterStatus.fromWire(meter.status),
              ),
          ],
        ),
        fetchedAt: row.fetchedAt,
      );
    });
  }
}
