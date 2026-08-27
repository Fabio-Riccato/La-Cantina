import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');
  runApp(const BevandeApp());
}

class BevandeApp extends StatelessWidget {
  const BevandeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'La Cantina',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // Interfaccia in italiano: nomi dei mesi, dei giorni e testi del date picker
        locale: const Locale('it', 'IT'),
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AvvioApp(),
      ),
    );
  }
}

/// Controlla se esiste già una sessione salvata e porta l'utente
/// direttamente alla home, altrimenti mostra il login.
class AvvioApp extends StatefulWidget {
  const AvvioApp({super.key});

  @override
  State<AvvioApp> createState() => _AvvioAppState();
}

class _AvvioAppState extends State<AvvioApp> {
  bool _pronto = false;

  @override
  void initState() {
    super.initState();
    _inizializza();
  }

  Future<void> _inizializza() async {
    await context.read<AuthProvider>().ripristinaSessione();
    if (mounted) setState(() => _pronto = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_pronto) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final auth = context.watch<AuthProvider>();
    return auth.isAuthenticated ? const HomeShell() : const LoginScreen();
  }
}
