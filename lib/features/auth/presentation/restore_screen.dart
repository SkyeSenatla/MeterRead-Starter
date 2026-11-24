import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meterread/features/auth/domain/reader.dart';
import 'package:meterread/features/auth/presentation/auth_controller.dart';
import 'package:meterread/features/round/presentation/widgets/failure_message.dart';

/// A recoverable launch when refresh could not contact the API.
class RestoreScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth case RestoreFailed(:final failure)) {
      return Scaffold(
        body: FailureMessage(
          failure: failure,
          onRetry: () => ref.read(authControllerProvider.notifier).restore(),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
