import 'package:meterread/app/database/app_database.dart';
import 'package:meterread/core/network/failure.dart';
import 'package:meterread/features/round/data/round_repository.dart';
import 'package:meterread/features/round/domain/meter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'round_providers.g.dart';

/// Today's round, from the server.
@riverpod
Future<Round> round(Ref ref) => ref.watch(roundRepositoryProvider).fetchRound();

/// One meter, from the server.
@riverpod
Future<Meter> meterDetail(Ref ref, String meterId) =>
    ref.watch(roundRepositoryProvider).fetchMeter(meterId);

/// The reading waiting to be sent for one meter, if any.
@riverpod
Stream<WaitingReading?> pendingReading(Ref ref, String meterId) =>
    ref.watch(appDatabaseProvider).outboxDao.watchFor(meterId);

/// Readings go through the outbox: kept on the phone first, then sent, so
/// a reading taken with no signal isn't lost.
final class ReadingOutbox {
  /// Creates the outbox.
  const new(this._database, this._repository);

  final AppDatabase _database;
  final RoundRepository _repository;

  /// Keeps the reading on the phone, then tries to send it.
  Future<AcceptedReading?> capture(
    String meterId, {
    required int value,
    required bool meterReplaced,
  }) async {
    await _database.outboxDao.capture(
      meterId,
      value: value,
      meterReplaced: meterReplaced,
    );
    return await send(meterId);
  }

  /// Sends the reading waiting for [meterId]. Null when it couldn't be
  /// sent (no signal): it stays in the outbox for "Send now". Throws a
  /// [Failure] when the server refuses it.
  Future<AcceptedReading?> send(String meterId) async {
    final outbox = _database.outboxDao;
    final pending = await outbox.readFor(meterId);
    if (pending == null) return null;
    // A fresh key for every request, so the server never mixes two up.
    final key = const Uuid().v4();
    await outbox.setKey(meterId, key);
    try {
      final accepted = await _repository.submitReading(
        meterId,
        value: pending.value,
        meterReplaced: pending.meterReplaced,
        idempotencyKey: key,
      );
      await outbox.remove(meterId);
      return accepted;
    } on NoSignal {
      await outbox.setError(meterId, 'No answer from the server.');
      return null;
    } on Failure {
      await outbox.remove(meterId);
      rethrow;
    }
  }

  /// Throws the waiting reading away.
  Future<void> discard(String meterId) => _database.outboxDao.remove(meterId);
}

/// The outbox.
@riverpod
ReadingOutbox readingOutbox(Ref ref) => ReadingOutbox(
  ref.watch(appDatabaseProvider),
  ref.watch(roundRepositoryProvider),
);
