import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../models/socio.dart';
import '../models/product.dart' show coloreDaHex;
import '../services/api_client.dart';
import '../services/app_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/color_picker.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pannello admin'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.group_outlined), text: 'Soci'),
            Tab(icon: Icon(Icons.history_edu_outlined), text: 'Attività'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TabSoci(),
          _TabAttivita(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// Tab Soci
// ---------------------------------------------------------------

class _TabSoci extends StatefulWidget {
  const _TabSoci();

  @override
  State<_TabSoci> createState() => _TabSociState();
}

class _TabSociState extends State<_TabSoci> {
  List<Socio> _soci = [];
  bool _caricamento = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() { _caricamento = true; _errore = null; });
    try {
      final soci = await AppDataService.getSoci();
      setState(() => _soci = soci);
    } on ApiException catch (e) {
      setState(() => _errore = e.message);
    } catch (_) {
      setState(() => _errore = 'Errore di connessione');
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  void _mostraMessaggio(String testo) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
    }
  }

  Future<void> _apriFormSocio([Socio? socio]) async {
    final aggiornato = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogSocio(socio: socio),
    );
    if (aggiornato == true) _carica();
  }

  Future<void> _eliminaSocio(Socio socio) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina socio'),
        content: Text('Vuoi eliminare definitivamente ${socio.nome}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errore),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (conferma != true) return;
    try {
      await AppDataService.eliminaSocio(socio.id);
      _mostraMessaggio('Socio eliminato');
      _carica();
    } on ApiException catch (e) {
      _mostraMessaggio(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_caricamento) return const Center(child: CircularProgressIndicator());
    if (_errore != null) {
      return Center(child: Text(_errore!, style: const TextStyle(color: AppTheme.errore)));
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _carica,
        child: _soci.isEmpty
            ? const Center(child: Text('Nessun socio registrato'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _soci.length,
                itemBuilder: (context, i) {
                  final socio = _soci[i];
                  final colore = coloreDaHex(socio.colore);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colore,
                        child: Text(
                          socio.nome.isNotEmpty ? socio.nome.substring(0, 1).toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Row(children: [
                        Text(socio.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (socio.isAdmin) ...[
                          const Gap(8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primario.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text('admin',
                                style: TextStyle(fontSize: 10, color: AppTheme.primario, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ]),
                      subtitle: socio.email != null ? Text(socio.email!) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _apriFormSocio(socio),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.errore),
                            onPressed: () => _eliminaSocio(socio),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _apriFormSocio(),
        tooltip: 'Aggiungi socio',
        child: const Icon(Icons.person_add_outlined),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Dialog crea/modifica socio
// ---------------------------------------------------------------

class _DialogSocio extends StatefulWidget {
  final Socio? socio;
  const _DialogSocio({this.socio});

  @override
  State<_DialogSocio> createState() => _DialogSocioState();
}

class _DialogSocioState extends State<_DialogSocio> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _emailCtrl;
  final _passwordCtrl = TextEditingController();
  late String _colore;
  late bool _isAdmin;
  bool _caricamento = false;
  String? _errore;

  bool get _isModifica => widget.socio != null;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.socio?.nome ?? '');
    _emailCtrl = TextEditingController(text: widget.socio?.email ?? '');
    _colore = widget.socio?.colore ?? '#3B82F6';
    _isAdmin = widget.socio?.isAdmin ?? false;
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
      if (_isModifica) {
        await AppDataService.modificaSocio(
          widget.socio!.id,
          nome: _nomeCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.isEmpty ? null : _passwordCtrl.text,
          colore: _colore,
          isAdmin: _isAdmin,
        );
      } else {
        await AppDataService.creaSocio(
          nome: _nomeCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          colore: _colore,
          isAdmin: _isAdmin,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _errore = e.message);
    } catch (e) {
      setState(() => _errore = e.toString());
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isModifica ? 'Modifica socio' : 'Nuovo socio'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => (v == null || v.isEmpty) ? 'Campo obbligatorio' : null,
              ),
              const Gap(12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                validator: (v) => (v == null || !v.contains('@')) ? 'Email non valida' : null,
              ),
              const Gap(12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _isModifica ? 'Nuova password (opzionale)' : 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  helperText: _isModifica ? 'Lascia vuoto per non cambiare' : null,
                ),
                validator: (v) {
                  if (!_isModifica && (v == null || v.length < 6)) {
                    return 'Minimo 6 caratteri';
                  }
                  return null;
                },
              ),
              const Gap(16),
              SelettoreColore(
                coloreSelezionato: _colore,
                onCambiato: (c) => setState(() => _colore = c),
              ),
              const Gap(12),
              CheckboxListTile(
                value: _isAdmin,
                onChanged: (v) => setState(() => _isAdmin = v ?? false),
                title: const Text('Amministratore'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_errore != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_errore!, style: const TextStyle(color: AppTheme.errore)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
        FilledButton(
          onPressed: _caricamento ? null : _salva,
          child: _caricamento
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isModifica ? 'Salva' : 'Crea'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// Tab Attività
// ---------------------------------------------------------------

class _TabAttivita extends StatefulWidget {
  const _TabAttivita();

  @override
  State<_TabAttivita> createState() => _TabAttivitaState();
}

class _TabAttivitaState extends State<_TabAttivita> {
  List<Map<String, dynamic>> _attivita = [];
  bool _caricamento = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() { _caricamento = true; _errore = null; });
    try {
      final data = await AppDataService.getAttivita();
      setState(() => _attivita = data);
    } on ApiException catch (e) {
      setState(() => _errore = e.message);
    } catch (_) {
      setState(() => _errore = 'Errore di connessione');
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_caricamento) return const Center(child: CircularProgressIndicator());
    if (_errore != null) {
      return Center(child: Text(_errore!, style: const TextStyle(color: AppTheme.errore)));
    }
    if (_attivita.isEmpty) {
      return const Center(child: Text('Nessuna attività registrata'));
    }

    return RefreshIndicator(
      onRefresh: _carica,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _attivita.length,
        itemBuilder: (context, i) {
          final a = _attivita[i];
          final tipo = a['tipo'] as String? ?? '';
          final userName = a['userName'] as String? ?? '?';
          final descrizione = a['descrizione'] as String? ?? '';
          final createdAt = a['createdAt'];
          DateTime? data;
          if (createdAt != null) {
            try { data = DateTime.parse(createdAt.toString()); } catch (_) {}
          }

          final isMagazzino = tipo == 'magazzino';
          final icona = isMagazzino ? Icons.warehouse_outlined : Icons.local_shipping_outlined;
          final coloreIcona = isMagazzino ? AppTheme.accento : AppTheme.primario;
          final iniziale = userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : '?';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: coloreIcona.withOpacity(0.15),
                child: Icon(icona, color: coloreIcona, size: 20),
              ),
              title: Row(children: [
                Text(userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Gap(6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: coloreIcona.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(tipo, style: TextStyle(fontSize: 10, color: coloreIcona, fontWeight: FontWeight.w700)),
                ),
              ]),
              subtitle: Text(descrizione, style: const TextStyle(fontSize: 12.5)),
              trailing: data != null
                  ? Text(
                      DateFormat('dd/MM\nHH:mm', 'it_IT').format(data.toLocal()),
                      style: const TextStyle(fontSize: 11, color: Colors.black45),
                      textAlign: TextAlign.right,
                    )
                  : null,
              isThreeLine: false,
            ),
          );
        },
      ),
    );
  }
}
