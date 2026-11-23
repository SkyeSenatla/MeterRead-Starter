import 'dart:async';

import 'package:meterread/app/database/app_database.dart';
import 'package:meterread/app/retry_policy.dart';
import 'package:meterread/core/cache/snapshot.dart';
import 'package:meterread/core/error/failure.dart';
import 'package:meterread/features/round/data/round_repository.dart';
import 'package:meterread/features/round/domain/meter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'round_providers.g.dart';

/// What the round screen shows: the copy on the phone, and how the latest
/// attempt to update it went.
final class RoundView {
  /// Creates the view.
  const new({this.snapshot, this.failure, this.refreshing = false});

  /// The round saved on the phone, and when the server last said so. Null
  /// until a round has been saved on this phone.
  final Snapshot<Round>? snapshot;

  /// Why the last update failed, or null if it didn't.
  final Failure? failure;

  /// An update is under way.
  final bool refreshing;

  /// The same view with some parts changed. [failure] is set even to null.
  RoundView copyWith({
    Snapshot<Round>? snapshot,
    bool? refreshing,
    Failure? Function()? failure,
  }) => RoundView(
    snapshot: snapshot ?? this.snapshot,
    refreshing: refreshing ?? this.refreshing,
    failure: failure == null ? this.failure : failure(),
  );
}

/// Today's round, phone first: the saved list shows straight away, and is
/// updated from the server in the background.
@riverpod
class RoundSync extends _$RoundSync {
  Future<void>? _inFlight;

  @override
  RoundView build() {
    final dao = ref.watch(appDatabaseProvider).roundDao;
    final saved = dao.watch().listen((snapshot) {
      // A null snapshot is "nothing saved yet" (or signed out and wiped).
      state = RoundView(
        snapshot: snapshot,
        failure: state.failure,
        refreshing: state.refreshing,
      );
    });
    ref.onDispose(saved.cancel);
    // After build returns: build itself must not change the state.
    unawaited(Future.microtask(refresh));
    return const RoundView(refreshing: true);
  }

  /// Asks the server for the round and saves it. A failure doesn't touch
  /// the saved list: it becomes [RoundView.failure].
  Future<void> refresh() => _inFlight ??= _refresh().whenComplete(() {
    _inFlight = null;
  });

  Future<void> _refresh() async {
    state = state.copyWith(refreshing: true);
    try {
      final round = await _withRetry(
        ref.read(roundRepositoryProvider).fetchRound,
      );
      await ref
          .read(appDatabaseProvider)
          .roundDao
          .save(round, fetchedAt: DateTime.now().toUtc());
      if (ref.mounted) {
        state = state.copyWith(refreshing: false, failure: () => null);
      }
    } on Failure catch (failure) {
      if (ref.mounted) {
        state = state.copyWith(refreshing: false, failure: () => failure);
      }
    }
  }
}

/// Reads, sending again only when there was no answer at all (the same
/// rule as [appRetryPolicy]).
Future<T> _withRetry<T>(Future<T> Function() read) async {
  for (var tries = 0; ; tries++) {
    try {
      return await read();
    } on Failure catch (failure) {
      final wait = appRetryPolicy(tries, failure);
      if (wait == null) rethrow;
      await Future<void>.delayed(wait);
    }
  }
}

/// One meter, from the server.
@riverpod
Future<Meter> meterDetail(Ref ref, String meterId) =>
    ref.watch(roundRepositoryProvider).fetchMeter(meterId);

/// The reading waiting to be sent for one meter, if any.
@riverpod
Stream<WaitingReading?> pendingReading(Ref ref, String meterId) =>
    ref.watch(appDatabaseProvider).outboxDao.watchFor(meterId);

/// Whether the form for [meterId] is saving a reading right now. While it
/// is, the form stays on screen, so a refusal can show under its field.
@Riverpod(keepAlive: true)
class SavingReading extends _$SavingReading {
  @override
  bool build(String meterId) => false;

  /// Marks the form busy, or not.
  // A method, not a setter: riverpod_lint forbids public notifier properties.
  // ignore: use_setters_to_change_properties
  void markBusy({required bool busy}) => state = busy;
}

/// Readings go through the outbox: kept on the phone first, then sent, so
/// a reading taken with no signal isn't lost.
final class ReadingOutbox {
  /// Creates the outbox.
  const new(this._database, this._repository);

  final AppDatabase _database;
  final RoundRepository _repository;

  /// Keeps the reading on the phone, then tries to send it. This is where
  /// the reading gets its Idempotency-Key, once.
  ///
  /// Returns what [send] returns, and throws what it throws.
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

  /// Sends the reading waiting for [meterId], with the key it got when it
  /// was captured: the same one on every attempt, so the server never
  /// stores it twice.
  ///
  /// Null when it couldn't be sent: no signal, a server problem, or the
  /// session ended. It stays in the outbox, with the reason, for "Send now".
  /// Throws a [Failure] when the server refuses it ([InvalidInput],
  /// [NotFound]): it's taken out of the outbox, because sending it again
  /// would get the same answer.
  Future<AcceptedReading?> send(String meterId) async {
    final outbox = _database.outboxDao;
    final key = await outbox.keyFor(meterId);
    final pending = await outbox.readFor(meterId);
    if (key == null || pending == null) return null;
    try {
      final accepted = await _repository.submitReading(
        meterId,
        value: pending.value,
        meterReplaced: pending.meterReplaced,
        idempotencyKey: key,
      );
      await outbox.remove(meterId);
      return accepted;
    } on Failure catch (failure) {
      switch (failure) {
        case InvalidInput() || NotFound():
          await outbox.remove(meterId);
          rethrow;
        case NoSignal() || ServerCrash() || SessionEnded() || Unexpected():
          await outbox.setError(meterId, failure.code);
          return null;
      }
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
