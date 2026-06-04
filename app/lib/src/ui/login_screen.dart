import 'package:flutter/material.dart';
import 'package:lsf_client/lsf_client.dart';

import '../services/background_refresh.dart';
import '../services/credential_store.dart';
import '../services/lsf_repository.dart';
import '../theme/theme_controller.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _store    = CredentialStore();
  final _repo     = LsfRepository();

  bool    _busy  = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy  = true;
      _error = null;
    });
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    try {
      await _repo.verifyLogin(username, password);
      await _store.save(Credentials(username, password));
      await BackgroundRefresh.schedule();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeShell(themeController: widget.themeController),
        ),
      );
    } on LoginFailedException {
      setState(() => _error = 'Benutzername oder Passwort falsch.');
    } on LsfException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Fehler: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('HTW Berlin – Anmeldung')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // HTW-Logo-Platzhalter: Icon in Surface-Container
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      size: 40,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    'Melde dich mit deinem HTW-LSF-Login an. '
                    'Deine Daten bleiben verschlüsselt auf dem Gerät.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Benutzername',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    autofillHints: const [AutofillHints.username],
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Passwort',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Pflichtfeld' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: cs.onErrorContainer, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: cs.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : const Text('Anmelden'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
