import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meterread/features/round/presentation/round_providers.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// The reading form: the number on the meter, in whole kWh.
class ReadingForm extends ConsumerStatefulWidget {
  /// Creates the form for [meterId].
  const new({required this.meterId, super.key});

  /// The meter being read.
  final String meterId;

  @override
  ConsumerState<ReadingForm> createState() => _ReadingFormState();
}

class _ReadingFormState extends ConsumerState<ReadingForm> {
  final _reading = TextEditingController();
  bool _meterReplaced = false;

  @override
  void dispose() {
    _reading.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    // The form goes once the reading is in the outbox: keep the container.
    final container = ProviderScope.containerOf(context, listen: false);
    final value = int.parse(_reading.text);
    _reading.clear();
    try {
      await ref
          .read(readingOutboxProvider)
          .capture(widget.meterId, value: value, meterReplaced: _meterReplaced);
      container
        ..invalidate(meterDetailProvider(widget.meterId))
        ..invalidate(roundProvider);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _reading,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 48 590'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.meterReplaced),
          value: _meterReplaced,
          onChanged: (value) => setState(() => _meterReplaced = value ?? false),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.saveReading)),
      ],
    );
  }
}
