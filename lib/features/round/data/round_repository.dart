import 'package:dio/dio.dart';
import 'package:meterread/app/network/dio_provider.dart';
import 'package:meterread/core/failure/failure.dart';
import 'package:meterread/features/round/domain/meter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'round_repository.g.dart';

final class RoundRepository {
  const new(this._dio);
  final Dio _dio;

  /// Fetch every page, respecting the server's order and counts.
  Future<Round> fetchRound() async {
    try {
      String? pageToken;
      String? name;
      int? total;
      int? left;
      final meters = <MeterSummary>[];
      do {
        final response = await _dio.get<Map<String, Object?>>(
          '/round/today',
          queryParameters: pageToken == null ? null : {'pageToken': pageToken},
        );
        final json = response.data!;
        name = json['roundName']! as String;
        total = json['totalMeters']! as int;
        left = json['metersLeft']! as int;
        for (final row in json['meters']! as List<Object?>) {
          meters.add(MeterSummary.fromJson(row! as Map<String, Object?>));
        }
        pageToken = json['nextPageToken'] as String?;
      } while (pageToken != null);
      return Round(
        name: name!,
        totalMeters: total!,
        metersLeft: left!,
        meters: meters,
      );
    } on Object catch (error) {
      throw failureFrom(error);
    }
  }

  Future<Meter> fetchMeter(String id) async {
    try {
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
          final Map<String, Object?> reading => AcceptedReading.fromJson(
            reading,
          ),
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
    } on Object catch (error) {
      throw failureFrom(error);
    }
  }

  Future<AcceptedReading> submitReading(
    String meterId, {
    required int value,
    required bool meterReplaced,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post<Map<String, Object?>>(
        '/meters/$meterId/readings',
        data: {'value': value, 'meterReplaced': meterReplaced},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return AcceptedReading.fromJson(response.data!);
    } on Object catch (error) {
      throw failureFrom(error);
    }
  }
}

@riverpod
RoundRepository roundRepository(Ref ref) =>
    RoundRepository(ref.watch(dioProvider));
