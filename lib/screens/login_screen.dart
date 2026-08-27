import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _caricamento = false;
  String? _errore;
  bool _mostraPassword = false;
  bool _ricordami = false;

  Future<void> _entra() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      await context.read<AuthProvider>().login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        ricordami: _ricordami,
      );
    } on ApiException catch (e) {
      setState(() => _errore = e.message);
    } catch (_) {
      setState(() => _errore = 'Impossibile contattare il server. Controlla la connessione.');
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primario,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 36),
                    ),
                    const Gap(24),
                    Text(
                      'La Cantina',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Gap(4),
                    Text(
                      'Accedi con il tuo account socio',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    const Gap(32),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                      validator: (v) => (v == null || !v.contains('@')) ? 'Inserisci un\'email valida' : null,
                    ),
                    const Gap(14),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_mostraPassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_mostraPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() => _mostraPassword = !_mostraPassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Inserisci la password' : null,
                      onFieldSubmitted: (_) => _entra(),
                    ),
                    const Gap(8),
                    Row(
                      children: [
                        Checkbox(
                          value: _ricordami,
                          onChanged: (v) => setState(() => _ricordami = v ?? false),
                          visualDensity: VisualDensity.compact,
                        ),
                        const Text('Ricordami'),
                      ],
                    ),
                    if (_errore != null) ...[
                      const Gap(14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errore.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_errore!, style: const TextStyle(color: AppTheme.errore)),
                      ),
                    ],
                    const Gap(24),
                    ElevatedButton(
                      onPressed: _caricamento ? null : _entra,
                      child: _caricamento
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Accedi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
