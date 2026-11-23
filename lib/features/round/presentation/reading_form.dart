import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meterread/app/format.dart';
import 'package:meterread/core/error/failure.dart';
import 'package:meterread/core/error/failure_view.dart';
import 'package:meterread/features/round/presentation/round_providers.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// The reading form: the number on the meter, in whole kWh. It takes digits
/// and spaces, "48 590" as the worker reads it off the dial.
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

  // Under the field: the form's own complaint, or the server's.
  String? _error;

  @override
  void dispose() {
    _reading.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // The form goes once the reading is in the outbox: keep the container.
    final container = ProviderScope.containerOf(context, listen: false);
    final text = _reading.text;
    final value = parseReading(text);
    if (value == null) {
      setState(() => _error = _whyNotAReading(l10n, text));
      return;
    }
    setState(() => _error = null);
    final saving = container.read(
      savingReadingProvider(widget.meterId).notifier,
    )..markBusy(busy: true);
    try {
      final accepted = await container
          .read(readingOutboxProvider)
          .capture(widget.meterId, value: value, meterReplaced: _meterReplaced);
      // Saved on the phone either way. Accepted: the field has done its job
      // and the meter is read. Not sent (no signal, a server problem): the
      // reading waits in the outbox, and the screen says so.
      if (accepted != null) {
        if (mounted) _reading.clear();
        container.invalidate(meterDetailProvider(widget.meterId));
        unawaited(container.read(roundSyncProvider.notifier).refresh());
      } else if (mounted) {
        _reading.clear();
      }
    } on InvalidInput catch (refused) {
      // The server said no: say why under the field, and keep what was typed.
      if (mounted) {
        setState(
          () => _error =
              refused.forField('value') ?? refused.message ?? l10n.failureInput,
        );
      }
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureFrom(error).words(l10n))),
      );
    } finally {
      saving.markBusy(busy: false);
    }
  }

  static String _whyNotAReading(AppLocalizations l10n, String text) {
    if (text.trim().isEmpty) return l10n.readingRequired;
    if (RegExp(r'[^0-9\s]').hasMatch(text)) return l10n.readingDigitsOnly;
    return l10n.readingTooLong;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saving = ref.watch(savingReadingProvider(widget.meterId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _reading,
          keyboardType: TextInputType.number,
          // Digits and spaces: "48 590". The no-break spaces are what
          // formatKwh writes, and what a paste may carry.
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 \u00a0\u202f]')),
          ],
          decoration: InputDecoration(
            labelText: l10n.readingLabel,
            hintText: '48 590',
            errorText: _error,
            errorMaxLines: 3,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.meterReplaced),
          value: _meterReplaced,
          onChanged: (value) => setState(() => _meterReplaced = value ?? false),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(l10n.saveReading),
        ),
      ],
    );
  }
}
