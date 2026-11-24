import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meterread/app/format.dart';
import 'package:meterread/core/failure/failure.dart';
import 'package:meterread/features/round/presentation/round_providers.dart';
import 'package:meterread/features/round/presentation/widgets/failure_message.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// A single stateful form stays mounted during a pending send, preserving
/// entered text when the server refuses the reading.
class ReadingForm extends ConsumerStatefulWidget {
  const new({required this.meterId, super.key});
  final String meterId;

  @override
  ConsumerState<ReadingForm> createState() => _ReadingFormState();
}

class _ReadingFormState extends ConsumerState<ReadingForm> {
  final _reading = TextEditingController();
  bool _meterReplaced = false;
  bool _busy = false;
  String? _fieldError;
  Failure? _sendError;

  @override
  void dispose() {
    _reading.dispose();
    super.dispose();
  }

  void _refresh() {
    ref
      ..invalidate(meterDetailProvider(widget.meterId))
      ..invalidate(roundProvider);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final raw = _reading.text.trim();
    if (raw.isEmpty) {
      setState(() => _fieldError = l10n.enterReading);
      return;
    }
    if (!RegExp(r'^[0-9 ]+$').hasMatch(raw)) {
      setState(() => _fieldError = l10n.digitsOnly);
      return;
    }
    final value = int.tryParse(raw.replaceAll(' ', ''));
    if (value == null) {
      setState(() => _fieldError = l10n.digitsOnly);
      return;
    }
    setState(() {
      _busy = true;
      _fieldError = null;
      _sendError = null;
    });
    try {
      final result = await ref
          .read(readingOutboxProvider)
          .capture(widget.meterId, value: value, meterReplaced: _meterReplaced);
      if (result != null && mounted) _refresh();
    } on Object catch (error) {
      final failure = failureFrom(error);
      if (!mounted) return;
      setState(() {
        if (failure is FieldFailure &&
            failure.errors['value']?.isNotEmpty == true) {
          _fieldError = failure.errors['value']!.first;
        } else {
          _sendError = failure;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendNow() async {
    setState(() {
      _busy = true;
      _sendError = null;
    });
    try {
      final result = await ref.read(readingOutboxProvider).send(widget.meterId);
      if (result != null && mounted) _refresh();
    } on Object catch (error) {
      if (mounted) setState(() => _sendError = failureFrom(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pending = ref.watch(pendingReadingProvider(widget.meterId)).value;
    if (pending != null) {
      final pendingFailure = switch (pending.lastError) {
        'noSignal' => const NoSignalFailure(),
        final String error when error.startsWith('server:') => ServerFailure(
          error.substring(7),
        ),
        _ => null,
      };
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.notSentYet(formatKwh(pending.value))),
              if (pendingFailure != null)
                Text(failureMessage(l10n, pendingFailure)),
              if (pendingFailure case ServerFailure(:final traceId?))
                Text(l10n.errorReference(traceId)),
              if (_sendError != null) Text(failureMessage(l10n, _sendError!)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _sendNow,
                    icon: const Icon(Icons.send),
                    label: Text(l10n.sendNow),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await ref
                                .read(readingOutboxProvider)
                                .discard(widget.meterId);
                            if (mounted) setState(() => _sendError = null);
                          },
                    child: Text(l10n.discard),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _reading,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.readingLabel,
            hintText: l10n.readingExample,
            errorText: _fieldError,
          ),
          onChanged: (_) {
            if (_fieldError != null) setState(() => _fieldError = null);
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.meterReplaced),
          value: _meterReplaced,
          onChanged: _busy
              ? null
              : (value) => setState(() => _meterReplaced = value ?? false),
        ),
        if (_sendError != null) ...[
          Text(failureMessage(l10n, _sendError!)),
          if (_sendError case ServerFailure(:final traceId?))
            Text(l10n.errorReference(traceId)),
          TextButton(
            onPressed: _busy ? null : _save,
            child: Text(l10n.tryAgain),
          ),
        ],
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(l10n.saveReading),
        ),
      ],
    );
  }
}
