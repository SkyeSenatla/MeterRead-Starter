import 'package:meterread/app/database/app_database.dart';
import 'package:meterread/core/cache/snapshot.dart';
import 'package:meterread/core/failure/failure.dart';
import 'package:meterread/features/round/data/round_repository.dart';
import 'package:meterread/features/round/domain/meter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'round_providers.g.dart';

/// Cached round emits before the background network request finishes.
@riverpod
Stream<Snapshot<Round>?> cachedRound(Ref ref) =>
    ref.watch(appDatabaseProvider).roundDao.watch();

/// Network refresh updates the cache; its failure leaves the cache intact.
@riverpod
Future<Round> round(Ref ref) async {
  final result = await ref.watch(roundRepositoryProvider).fetchRound();
  await ref
      .read(appDatabaseProvider)
      .roundDao
      .save(result, fetchedAt: DateTime.now().toUtc());
  return result;
}

@riverpod
Future<Meter> meterDetail(Ref ref, String meterId) =>
    ref.watch(roundRepositoryProvider).fetchMeter(meterId);

@riverpod
Stream<WaitingReading?> pendingReading(Ref ref, String meterId) =>
    ref.watch(appDatabaseProvider).outboxDao.watchFor(meterId);

final class ReadingOutbox {
  const new(this._database, this._repository);
  final AppDatabase _database;
  final RoundRepository _repository;

  /// Capture a distinct reading once, including its persistent retry key.
  Future<AcceptedReading?> capture(
    String meterId, {
    required int value,
    required bool meterReplaced,
  }) async {
    await _database.outboxDao.capture(
      meterId,
      value: value,
      meterReplaced: meterReplaced,
      idempotencyKey: const Uuid().v4(),
    );
    return send(meterId);
  }

  /// Retry the exact same reading and key until the server accepts it.
  Future<AcceptedReading?> send(String meterId) async {
    final outbox = _database.outboxDao;
    final pending = await outbox.readFor(meterId);
    if (pending == null) return null;
    try {
      final accepted = await _repository.submitReading(
        meterId,
        value: pending.value,
        meterReplaced: pending.meterReplaced,
        idempotencyKey: pending.idempotencyKey!,
      );
      await outbox.remove(meterId);
      return accepted;
    } on Object catch (error) {
      final failure = failureFrom(error);
      if (failure is FieldFailure) {
        await outbox.remove(meterId);
        throw failure;
      }
      if (failure is NoSignalFailure) {
        await outbox.setError(meterId, 'noSignal');
        return null;
      }
      if (failure is ServerFailure) {
        await outbox.setError(meterId, 'server:${failure.traceId ?? ''}');
      }
      throw failure;
    }
  }

  Future<void> discard(String meterId) => _database.outboxDao.remove(meterId);
}

@riverpod
ReadingOutbox readingOutbox(Ref ref) => ReadingOutbox(
  ref.watch(appDatabaseProvider),
  ref.watch(roundRepositoryProvider),
);
