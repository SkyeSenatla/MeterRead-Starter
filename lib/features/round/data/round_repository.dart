import 'package:dio/dio.dart';
import 'package:meterread/app/network/dio_provider.dart';
import 'package:meterread/features/round/domain/meter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'round_repository.g.dart';

/// The round and meter endpoints.
final class RoundRepository {
  /// Creates the repository over the app's Dio client.
  const new(this._dio);

  final Dio _dio;

  /// GET /round/today: today's round.
  Future<Round> fetchRound() async {
    final response = await _dio.get<Map<String, Object?>>('/round/today');
    final json = response.data!;
    return Round(
      name: json['roundName']! as String,
      totalMeters: json['totalMeters']! as int,
      metersLeft: json['metersLeft']! as int,
      meters: [
        for (final meter in json['meters']! as List<Object?>)
          MeterSummary.fromJson(meter! as Map<String, Object?>),
      ],
    );
  }

  /// GET /meters/{id} and GET /meters/{id}/readings, together.
  Future<Meter> fetchMeter(String id) async {
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
  }

  /// POST /meters/{id}/readings, with the Idempotency-Key the API asks for.
  Future<AcceptedReading> submitReading(
    String meterId, {
    required int value,
    required bool meterReplaced,
    required String idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/meters/$meterId/readings',
      data: {'value': value, 'meterReplaced': meterReplaced},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return AcceptedReading.fromJson(response.data!);
  }
}

/// The repository.
@riverpod
RoundRepository roundRepository(Ref ref) =>
    RoundRepository(ref.watch(dioProvider));
