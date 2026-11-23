import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meterread/core/failures/failure.dart';
import 'package:meterread/core/widgets/failure_message.dart';
import 'package:meterread/features/round/presentation/round_providers.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// The reading form: the number on the meter, in whole kWh.
class ReadingForm extends ConsumerStatefulWidget {
  /// Creates the form for [meterId].
  const ReadingForm({required this.meterId, super.key});

  /// The meter being read.
  final String meterId;

  @override
  ConsumerState<ReadingForm> createState() => _ReadingFormState();
}

class _ReadingFormState extends ConsumerState<ReadingForm> {
  final _reading = TextEditingController();
  bool _meterReplaced = false;
  bool _busy = false;
  String? _fieldError;
  Object? _error;

  @override
  void dispose() {
    _reading.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;

    final l10n = AppLocalizations.of(context);
    final text = _reading.text;
    final digits = text.replaceAll(' ', '');
    final value = int.tryParse(digits);
    String? message;

    if (text.trim().isEmpty) {
      message = l10n.readingEmpty;
    } else if (!RegExp(r'^[0-9 ]+$').hasMatch(text)) {
      message = l10n.readingInvalid;
    } else if (value == null || value > 9999999) {
      message = l10n.readingRange;
    }

    setState(() {
      _fieldError = message;
      _error = null;
    });
    if (message != null || value == null) return;

    final meterId = widget.meterId;
    final container = ProviderScope.containerOf(context, listen: false);
    final outbox = ref.read(readingOutboxProvider);
    setState(() => _busy = true);

    try {
      final accepted = await outbox.capture(
        meterId,
        value: value,
        meterReplaced: _meterReplaced,
      );
      if (accepted != null) {
        container
          ..invalidate(meterDetailProvider(meterId))
          ..invalidate(roundProvider);
      }
    } on Object catch (error) {
      if (!mounted) return;
      final fieldMessage = error is ValidationFailure
          ? error.errors['value']?.firstOrNull
          : null;
      setState(() {
        _fieldError = fieldMessage;
        _error = fieldMessage == null ? error : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
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
          readOnly: _busy,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.readingLabel,
            hintText: l10n.readingHint,
            errorText: _fieldError,
            errorMaxLines: 4,
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.meterReplaced),
          value: _meterReplaced,
          onChanged: _busy
              ? null
              : (value) => setState(() => _meterReplaced = value ?? false),
        ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FailureMessage(error: error, onRetry: _busy ? null : _save),
          ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(l10n.saveReading),
        ),
      ],
    );
  }
}
