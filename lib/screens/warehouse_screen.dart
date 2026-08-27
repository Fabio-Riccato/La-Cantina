import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../models/warehouse_item.dart';
import '../services/api_client.dart';
import '../services/app_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/warehouse_movement_dialog.dart';
import 'home_shell.dart' show AccountMenuButton;

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  List<WarehouseItem> _magazzino = [];
  bool _caricamento = true;
  String? _errore;
  String _ricerca = '';

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final dati = await AppDataService.getMagazzino();
      setState(() => _magazzino = dati);
    } on ApiException catch (e) {
      setState(() => _errore = e.message);
    } catch (_) {
      setState(() => _errore = 'Errore di connessione al server');
    } finally {
      setState(() => _caricamento = false);
    }
  }

  List<WarehouseItem> get _filtrati {
    if (_ricerca.isEmpty) return _magazzino;
    final q = _ricerca.toLowerCase();
    return _magazzino.where((p) => p.nomeCompleto.toLowerCase().contains(q)).toList();
  }

  Future<void> _registraArrivo(WarehouseItem item) async {
    final casse = await mostraWarehouseMovementDialog(context, item: item, tipo: TipoMovimento.arrivo);
    if (casse == null) return;
    try {
      await AppDataService.registraArrivoFornitore(item.productId, casse);
      _carica();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _rettifica(WarehouseItem item) async {
    final nuovoValore = await mostraWarehouseMovementDialog(context, item: item, tipo: TipoMovimento.rettifica);
    if (nuovoValore == null) return;
    try {
      await AppDataService.rettificaGiacenza(item.productId, nuovoValore);
      _carica();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Magazzino'), actions: const [AccountMenuButton()]),
      body: RefreshIndicator(
        onRefresh: _carica,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: const InputDecoration(hintText: 'Cerca prodotto...', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _ricerca = v),
              ),
              const Gap(16),
              Expanded(child: _buildContenuto()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContenuto() {
    if (_caricamento) return const Center(child: CircularProgressIndicator());
    if (_errore != null) return Center(child: Text(_errore!, style: const TextStyle(color: AppTheme.errore)));
    if (_filtrati.isEmpty) return const Center(child: Text('Nessun prodotto in magazzino'));

    return ListView.separated(
      itemCount: _filtrati.length,
      separatorBuilder: (_, __) => const Gap(10),
      itemBuilder: (context, i) {
        final item = _filtrati[i];
        final scorteBasse = item.casseDisponibili <= 5;
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(item.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${item.casseDisponibili.toStringAsFixed(0)} casse disponibili',
              style: TextStyle(color: scorteBasse ? AppTheme.errore : Colors.black54, fontWeight: scorteBasse ? FontWeight.w600 : null),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Arrivo fornitore',
                  icon: const Icon(Icons.add_box_outlined, color: AppTheme.successo),
                  onPressed: () => _registraArrivo(item),
                ),
                IconButton(
                  tooltip: 'Rettifica manuale',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _rettifica(item),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
