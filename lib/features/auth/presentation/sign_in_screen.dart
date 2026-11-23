import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meterread/core/fakes/test_tools.dart';
import 'package:meterread/core/widgets/failure_message.dart';
import 'package:meterread/features/auth/presentation/auth_controller.dart';
import 'package:meterread/l10n/app_localizations.dart';

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
  Object? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(_email.text, _password.text);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
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
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FailureMessage(
                error: error,
                signingIn: true,
                onRetry: _busy ? null : _signIn,
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
