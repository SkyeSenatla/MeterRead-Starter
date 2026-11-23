import 'package:meterread/core/fakes/meter_server.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'meter_server_provider.g.dart';

/// The one meter server for the whole app: Dio's adapter. Tests override it
/// with their own. Don't edit this file.
@Riverpod(keepAlive: true)
MeterServer meterServer(Ref ref) => MeterServer();
