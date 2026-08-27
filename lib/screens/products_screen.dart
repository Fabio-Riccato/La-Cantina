import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../models/product.dart';
import '../services/api_client.dart';
import '../services/app_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_form_dialog.dart';
import 'home_shell.dart' show AccountMenuButton;

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _prodotti = [];
  bool _caricamento = true;
  String? _errore;
  String _ricerca = '';
  bool _mostraDisattivati = false;

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
      final prodotti = await AppDataService.getProdotti(soloAttivi: !_mostraDisattivati);
      setState(() => _prodotti = prodotti);
    } on ApiException catch (e) {
      setState(() => _errore = e.message);
    } catch (_) {
      setState(() => _errore = 'Errore di connessione al server');
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  void _mostraErrore(String messaggio) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messaggio)));
  }

  List<Product> get _filtrati {
    if (_ricerca.isEmpty) return _prodotti;
    final q = _ricerca.toLowerCase();
    return _prodotti.where((p) => p.nomeCompleto.toLowerCase().contains(q)).toList();
  }

  Future<void> _nuovoProdotto() async {
    final risultato = await mostraProductFormDialog(context);
    if (risultato == null) return;
    try {
      await AppDataService.creaProdotto(
        marca: risultato.marca,
        tipo: risultato.tipo,
        taglia: risultato.taglia,
        prezzo: risultato.prezzo,
        bottigliePerCassa: risultato.bottigliePerCassa,
        colore: risultato.colore,
      );
      _carica();
    } on ApiException catch (e) {
      _mostraErrore(e.message);
    }
  }

  Future<void> _modificaProdotto(Product p) async {
    final risultato = await mostraProductFormDialog(context, esistente: p);
    if (risultato == null) return;
    try {
      await AppDataService.modificaProdotto(p.id, {
        'marca': risultato.marca,
        'tipo': risultato.tipo,
        'taglia': risultato.taglia,
        'prezzo': risultato.prezzo,
        'bottiglie_per_cassa': risultato.bottigliePerCassa,
        'colore': risultato.colore,
      });
      _carica();
    } on ApiException catch (e) {
      _mostraErrore(e.message);
    }
  }

  Future<void> _cambiaStato(Product p) async {
    try {
      if (p.attivo) {
        await AppDataService.disattivaProdotto(p.id);
      } else {
        await AppDataService.riattivaProdotto(p.id);
      }
      _carica();
    } on ApiException catch (e) {
      _mostraErrore(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prodotti'),
        actions: [
          IconButton(
            tooltip: _mostraDisattivati ? 'Mostra solo attivi' : 'Mostra anche disattivati',
            icon: Icon(_mostraDisattivati ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () {
              setState(() => _mostraDisattivati = !_mostraDisattivati);
              _carica();
            },
          ),
          const AccountMenuButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuovoProdotto,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo prodotto'),
      ),
      body: RefreshIndicator(
        onRefresh: _carica,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Cerca per marca, tipo o taglia...',
                  prefixIcon: Icon(Icons.search),
                ),
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
    if (_errore != null) {
      return Center(child: Text(_errore!, style: const TextStyle(color: AppTheme.errore)));
    }
    if (_filtrati.isEmpty) return const Center(child: Text('Nessun prodotto trovato'));

    return ListView.separated(
      itemCount: _filtrati.length,
      separatorBuilder: (_, __) => const Gap(10),
      itemBuilder: (context, i) {
        final p = _filtrati[i];
        return Card(
          child: Opacity(
            opacity: p.attivo ? 1 : 0.55,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.coloreFlutter,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const Gap(12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: p.coloreFlutter.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${p.bottigliePerCassa}×',
                      style: TextStyle(
                        color: p.coloreFlutter,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Gap(2),
                        Text(
                          '€ ${p.prezzo.toStringAsFixed(2)} / cassa  ·  ${p.casseDisponibili.toStringAsFixed(0)} in magazzino',
                          style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Modifica',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _modificaProdotto(p),
                  ),
                  IconButton(
                    tooltip: p.attivo ? 'Non vendo più questo prodotto' : 'Riattiva',
                    icon: Icon(
                      p.attivo ? Icons.remove_circle_outline : Icons.restore,
                      size: 20,
                      color: p.attivo ? AppTheme.errore : AppTheme.successo,
                    ),
                    onPressed: () => _cambiaStato(p),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
