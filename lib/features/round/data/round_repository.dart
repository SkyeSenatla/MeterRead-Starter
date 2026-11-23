import 'package:dio/dio.dart';
import 'package:meterread/app/network/dio_provider.dart';
import 'package:meterread/core/error/failure.dart';
import 'package:meterread/features/round/domain/meter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'round_repository.g.dart';

/// The round and meter endpoints.
final class RoundRepository {
  /// Creates the repository over the app's Dio client.
  const new(this._dio);

  final Dio _dio;

  /// GET /round/today: today's round, every page of it (10 meters a page).
  /// Throws a [Failure].
  Future<Round> fetchRound() => _guard(() async {
    String? name;
    var totalMeters = 0;
    var metersLeft = 0;
    final meters = <MeterSummary>[];
    String? pageToken;
    // The last page leaves nextPageToken out. The cap is only a seat belt
    // against a server that never does.
    for (var page = 0; page < _maxPages; page++) {
      final response = await _dio.get<Map<String, Object?>>(
        '/round/today',
        queryParameters: {'pageToken': ?pageToken},
      );
      final json = response.data!;
      name ??= json['roundName']! as String;
      totalMeters = json['totalMeters']! as int;
      metersLeft = json['metersLeft']! as int;
      meters.addAll([
        for (final meter in json['meters']! as List<Object?>)
          MeterSummary.fromJson(meter! as Map<String, Object?>),
      ]);
      pageToken = json['nextPageToken'] as String?;
      if (pageToken == null || pageToken.isEmpty) break;
    }
    return Round(
      name: name!,
      totalMeters: totalMeters,
      metersLeft: metersLeft,
      meters: meters,
    );
  });

  static const _maxPages = 100;

  /// GET /meters/{id} and GET /meters/{id}/readings, together. Throws a
  /// [Failure].
  Future<Meter> fetchMeter(String id) => _guard(() async {
    final (detail, history) = await (
      _dio.get<Map<String, Object?>>('/meters/$id'),
      _dio.get<Map<String, Object?>>('/meters/$id/readings'),
    ).wait;
    final json = detail.data!;
    return Meter(
      id: json['id']! as String,
      address: json['address']! as String,
      meterNumber: json['meterNumber']! as String,
      accountNumber: json['accountNumber']! as String,
      status: MeterStatus.fromWire(json['status']),
      lastReading: json['lastReading']! as int,
      lastReadOn: DateTime.parse(json['lastReadOn']! as String),
      thisCycle: switch (json['thisCycle']) {
        final Map<String, Object?> reading => AcceptedReading.fromJson(reading),
        _ => null,
      },
      history: [
        for (final past in history.data!['readings']! as List<Object?>)
          if (past case {
            'value': final int value,
            'readOn': final String readOn,
          })
            (value: value, readOn: DateTime.parse(readOn)),
      ],
    );
  });

  /// POST /meters/{id}/readings, with the Idempotency-Key the API asks for.
  /// Never retried here: the same key makes sending again safe, but only
  /// the reader decides to. Throws a [Failure].
  Future<AcceptedReading> submitReading(
    String meterId, {
    required int value,
    required bool meterReplaced,
    required String idempotencyKey,
  }) => _guard(() async {
    final response = await _dio.post<Map<String, Object?>>(
      '/meters/$meterId/readings',
      data: {'value': value, 'meterReplaced': meterReplaced},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return AcceptedReading.fromJson(response.data!);
  });

  /// Runs [call], and turns anything Dio or `.wait` throws into a [Failure].
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on Object catch (error) {
      // The data layer's edge: whatever went wrong leaves as a Failure.
      throw failureFrom(error);
    }
  }
}

/// The repository.
@riverpod
RoundRepository roundRepository(Ref ref) =>
    RoundRepository(ref.watch(dioProvider));
