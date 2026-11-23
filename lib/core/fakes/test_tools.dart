// Don't edit this file. It's the class's remote control for the pretend
// server: no signal, and access tokens that run out now instead of in five
// minutes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meterread/core/fakes/meter_server_provider.dart';

/// An app-bar button that opens the Test tools sheet.
class TestToolsButton extends StatelessWidget {
  /// Creates the button.
  const new({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Test tools',
    icon: const Icon(Icons.science_outlined),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      builder: (_) => const _TestToolsSheet(),
    ),
  );
}

class _TestToolsSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_TestToolsSheet> createState() => _TestToolsSheetState();
}

class _TestToolsSheetState extends ConsumerState<_TestToolsSheet> {
  @override
  Widget build(BuildContext context) {
    final server = ref.watch(meterServerProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              'Test tools',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: const Text(
              'They change the pretend server, not the app.',
            ),
          ),
          SwitchListTile(
            title: const Text('No signal'),
            subtitle: const Text('Every request fails before it leaves.'),
            value: !server.online,
            onChanged: (noSignal) => setState(() => server.online = !noSignal),
          ),
          ListTile(
            leading: const Icon(Icons.timer_off_outlined),
            title: const Text('Expire access tokens'),
            subtitle: const Text('As if five minutes had passed.'),
            onTap: () {
              server.expireAccessTokens();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
