import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_data_service.dart';
import '../services/auth_provider.dart';
import 'products_screen.dart';
import 'load_screen.dart';
import 'assistant_screen.dart';
import 'warehouse_screen.dart';
import 'history_screen.dart';
import 'admin_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;

  // Su web non mostriamo la sezione di interazione vocale/testuale con l'AI,
  // come richiesto: il sito serve per il lavoro manuale, l'assistente resta sull'app mobile.
  late final List<_Sezione> _sezioni = [
    _Sezione('Prodotti', Icons.inventory_2_outlined, Icons.inventory_2, const ProductsScreen()),
    _Sezione('Carico', Icons.local_shipping_outlined, Icons.local_shipping, const LoadScreen()),
    if (!kIsWeb)
      _Sezione('Assistente', Icons.mic_none_outlined, Icons.mic, const AssistantScreen()),
    _Sezione('Magazzino', Icons.warehouse_outlined, Icons.warehouse, const WarehouseScreen()),
    _Sezione('Storico', Icons.history_outlined, Icons.history, const HistoryScreen()),
  ];

  void _apriMenuAccount(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final larghezza = MediaQuery.of(context).size.width;
    final layoutAmpio = larghezza >= 800;

    if (layoutAmpio) {
      showDialog(
        context: context,
        builder: (_) => _DialogAccount(auth: auth),
      );
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        isScrollControlled: true,
        builder: (_) => _BottomSheetAccount(auth: auth),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final larghezza = MediaQuery.of(context).size.width;
    final layoutAmpio = larghezza >= 800;

    final corpo = IndexedStack(
      index: _indice,
      children: _sezioni.map((s) => s.schermata).toList(),
    );

    final iniziale = (auth.userNome ?? '?').substring(0, 1).toUpperCase();
    final avatarWidget = CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(iniziale, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );

    if (layoutAmpio) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _indice,
              onDestinationSelected: (i) => setState(() => _indice = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _apriMenuAccount(context),
                      child: Tooltip(
                        message: auth.userNome ?? '',
                        child: avatarWidget,
                      ),
                    ),
                    const SizedBox(height: 6),
                    IconButton(
                      tooltip: 'Esci',
                      icon: const Icon(Icons.logout, size: 18),
                      onPressed: () => auth.logout(),
                    ),
                  ],
                ),
              ),
              destinations: _sezioni
                  .map((s) => NavigationRailDestination(
                        icon: Icon(s.icona),
                        selectedIcon: Icon(s.iconaAttiva),
                        label: Text(s.titolo),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: corpo),
          ],
        ),
      );
    }

    return Scaffold(
      body: corpo,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: _sezioni
            .map((s) => NavigationDestination(icon: Icon(s.icona), selectedIcon: Icon(s.iconaAttiva), label: s.titolo))
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Pulsante account da inserire nell'AppBar di ogni sezione
// (su layout ampio l'account si apre dalla NavigationRail, quindi qui non mostriamo nulla)
// ---------------------------------------------------------------

class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final larghezza = MediaQuery.of(context).size.width;
    if (larghezza >= 800) return const SizedBox.shrink();

    final auth = context.watch<AuthProvider>();
    final iniziale = (auth.userNome ?? '?').substring(0, 1).toUpperCase();

    return IconButton(
      tooltip: 'Account',
      icon: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(iniziale, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      onPressed: () => showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        isScrollControlled: true,
        builder: (_) => _BottomSheetAccount(auth: context.read<AuthProvider>()),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Widget condivisi per il menu account
// ---------------------------------------------------------------

class _VociAccount extends StatelessWidget {
  final AuthProvider auth;
  final VoidCallback onChiudi;

  const _VociAccount({required this.auth, required this.onChiudi});

  void _modificaProfilo(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => _DialogModificaProfilo(auth: auth),
    );
  }

  void _apriAdmin(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              (auth.userNome ?? '?').substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(auth.userNome ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(auth.userEmail ?? '', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.manage_accounts_outlined),
          title: const Text('Modifica profilo'),
          onTap: () => _modificaProfilo(context),
        ),
        if (auth.isAdmin == true)
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Pannello admin'),
            onTap: () => _apriAdmin(context),
          ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Esci', style: TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(context);
            auth.logout();
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _DialogAccount extends StatelessWidget {
  final AuthProvider auth;
  const _DialogAccount({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: _VociAccount(auth: auth, onChiudi: () => Navigator.pop(context)),
      ),
    );
  }
}

class _BottomSheetAccount extends StatelessWidget {
  final AuthProvider auth;
  const _BottomSheetAccount({required this.auth});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _VociAccount(auth: auth, onChiudi: () => Navigator.pop(context)),
    );
  }
}

// ---------------------------------------------------------------
// Dialog modifica profilo
// ---------------------------------------------------------------

class _DialogModificaProfilo extends StatefulWidget {
  final AuthProvider auth;
  const _DialogModificaProfilo({required this.auth});

  @override
  State<_DialogModificaProfilo> createState() => _DialogModificaProfiloState();
}

class _DialogModificaProfiloState extends State<_DialogModificaProfilo> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _emailCtrl;
  final _passwordCtrl = TextEditingController();
  bool _caricamento = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.auth.userNome ?? '');
    _emailCtrl = TextEditingController(text: widget.auth.userEmail ?? '');
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _caricamento = true; _errore = null; });
    try {
      await AppDataService.aggiornaProfilo(
        nome: _nomeCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.isEmpty ? null : _passwordCtrl.text,
      );
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo aggiornato')),
      );
    } catch (e) {
      setState(() => _errore = e.toString());
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifica profilo'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (v) => (v == null || v.isEmpty) ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v == null || !v.contains('@')) ? 'Email non valida' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nuova password (opzionale)',
                helperText: 'Lascia vuoto per non cambiare',
              ),
            ),
            if (_errore != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_errore!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(
          onPressed: _caricamento ? null : _salva,
          child: _caricamento
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salva'),
        ),
      ],
    );
  }
}

class _Sezione {
  final String titolo;
  final IconData icona;
  final IconData iconaAttiva;
  final Widget schermata;
  _Sezione(this.titolo, this.icona, this.iconaAttiva, this.schermata);
}
