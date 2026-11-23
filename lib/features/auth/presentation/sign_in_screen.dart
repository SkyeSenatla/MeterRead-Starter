import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meterread/app/failure_text.dart';
import 'package:meterread/core/fakes/test_tools.dart';
import 'package:meterread/core/network/failure.dart';
import 'package:meterread/features/auth/presentation/auth_controller.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// Sign in with an email and password. The router moves on once signed in.
class SignInScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  Failure? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(_email.text, _password.text);
    } on Object catch (error) {
      if (mounted) setState(() => _failure = toFailure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.signInTitle),
        actions: const [TestToolsButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: l10n.emailLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(labelText: l10n.passwordLabel),
            onSubmitted: (_) => _signIn(),
          ),
          const SizedBox(height: 16),
          if (_failure case final failure?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    failure is SessionEnded
                        ? l10n.failureSignIn
                        : failure.message(l10n),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (failure.reference case final reference?)
                    Text(l10n.failureReference(reference)),
                  if (failure is NoSignal || failure is ServerFault)
                    TextButton(
                      onPressed: _busy ? null : _signIn,
                      child: Text(l10n.tryAgain),
                    ),
                ],
              ),
            ),
          FilledButton(
            onPressed: _busy ? null : _signIn,
            child: Text(l10n.signInButton),
          ),
        ],
      ),
    );
  }
}
