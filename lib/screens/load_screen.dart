import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../models/load.dart';
import '../models/product.dart';
import '../services/api_client.dart';
import '../services/app_data_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_load_item_dialog.dart';
import 'home_shell.dart' show AccountMenuButton;


class LoadScreen extends StatefulWidget {
  const LoadScreen({super.key});

  @override
  State<LoadScreen> createState() => _LoadScreenState();
}

class _LoadScreenState extends State<LoadScreen> {
  DateTime _dataSelezionata = DateTime.now();
  Load? _carico;
  List<Product> _prodotti = [];
  bool _caricamento = true;
  String? _errore;
  bool _vistaRidotta = false;

  String get _dataIso => DateFormat('yyyy-MM-dd').format(_dataSelezionata);

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
      final risultati = await Future.wait([
        AppDataService.getCaricoPerData(_dataIso),
        AppDataService.getProdotti(),
      ]);
      setState(() {
        _carico = risultati[0] as Load;
        _prodotti = risultati[1] as List<Product>;
      });
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

  Future<void> _selezionaData() async {
    final scelta = await showDatePicker(
      context: context,
      initialDate: _dataSelezionata,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('it', 'IT'),
    );
    if (scelta != null) {
      setState(() => _dataSelezionata = scelta);
      _carica();
    }
  }

  Future<void> _aggiungiProdotto() async {
    if (_prodotti.isEmpty) {
      _mostraErrore('Nessun prodotto disponibile, aggiungine uno dalla sezione Prodotti');
      return;
    }
    final risultato = await mostraLoadItemDialog(context, _prodotti);
    if (risultato == null || _carico == null) return;
    try {
      await AppDataService.aggiungiAlCarico(
        _carico!.id,
        risultato.productId,
        risultato.casse,
        clienteNome: risultato.clienteNome,
        note: risultato.note,
        periodo: risultato.periodo,
      );
      _carica();
    } on ApiException catch (e) {
      _mostraErrore(e.message);
    }
  }

  Future<void> _modificaRiga(LoadItem item) async {
    final risultato = await mostraLoadItemDialog(context, _prodotti, esistente: item);
    if (risultato == null || _carico == null) return;
    try {
      await AppDataService.aggiornaRigaCarico(
        _carico!.id,
        item.id,
        casse: risultato.casse,
        clienteNome: risultato.clienteNome,
        note: risultato.note,
        periodo: risultato.periodo,
      );
      _carica();
    } on ApiException catch (e) {
      _mostraErrore(e.message);
    }
  }

  Future<void> _rimuoviRiga(LoadItem item) async {
    if (_carico == null) return;
    try {
      await AppDataService.rimuoviRigaCarico(_carico!.id, item.id);
      _carica();
    } on ApiException catch (e) {
      _mostraErrore(e.message);
    }
  }

  Future<void> _stampaPdf() async {
    if (_carico == null) return;
    if (_carico!.items.isEmpty) {
      _mostraErrore('Il carico è vuoto, non c\'è niente da stampare');
      return;
    }
    try {
      await PdfService.stampaCarico(_carico!, totaliOnly: _vistaRidotta);
    } catch (_) {
      _mostraErrore('Impossibile generare il PDF');
    }
  }

  Future<void> _completaCarico() async {
    if (_carico == null) return;
    final conferma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Completa carico'),
        content: Text(
          'Confermi di aver caricato tutto il camion per il ${DateFormat('dd/MM/yyyy').format(_dataSelezionata)}?\n\n'
          'Le quantità caricate verranno scalate automaticamente dal magazzino.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Conferma')),
        ],
      ),
    );
    if (conferma != true) return;
    try {
      await AppDataService.completaCarico(_carico!.id);
      _carica();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Carico completato, magazzino aggiornato')));
      }
    } on ApiException catch (e) {
      _mostraErrore(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completato = _carico?.completato ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carico'),
        actions: const [AccountMenuButton()],
      ),
      body: RefreshIndicator(
        onRefresh: _carica,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: AppTheme.primario, size: 20),
                      const Gap(12),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE d MMMM yyyy', 'it_IT').format(_dataSelezionata),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(onPressed: _selezionaData, child: const Text('Cambia data')),
                    ],
                  ),
                ),
              ),
              const Gap(16),
              Expanded(child: _buildContenuto(completato)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContenuto(bool completato) {
    if (_caricamento) return const Center(child: CircularProgressIndicator());
    if (_errore != null) {
      return Center(child: Text(_errore!, style: const TextStyle(color: AppTheme.errore)));
    }

    final carico = _carico!;
    final gruppi = carico.perPeriodo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (completato)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.successo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle, color: AppTheme.successo, size: 20),
              Gap(8),
              Expanded(
                child: Text('Carico già completato per questa data',
                    style: TextStyle(color: AppTheme.successo, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        if (carico.items.isNotEmpty) ...[
          Row(
            children: [
              const Text('Vista:', style: TextStyle(fontSize: 13, color: Colors.black54)),
              const Gap(8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Per cliente')),
                  ButtonSegment(value: true, label: Text('Totali')),
                ],
                selected: {_vistaRidotta},
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: (s) => setState(() => _vistaRidotta = s.first),
              ),
            ],
          ),
          const Gap(8),
        ],
        Expanded(
          child: carico.items.isEmpty
              ? const Center(child: Text('Nessun prodotto nel carico'))
              : _vistaRidotta
                  ? _listaAggregata(gruppi)
                  : ListView(
                      children: [
                        for (final entry in gruppi.entries) ...[
                          _intestazionePeriodo(entry.key, entry.value),
                          const Gap(8),
                          ...entry.value.map((item) => _rigaCarico(item, completato)),
                          const Gap(18),
                        ],
                      ],
                    ),
        ),
        if (carico.items.isNotEmpty) ...[
          const Gap(8),
          Text('Totale: ${carico.totaleCasse.toStringAsFixed(0)} casse',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Gap(8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!completato)
                OutlinedButton.icon(
                  onPressed: _aggiungiProdotto,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Aggiungi'),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              OutlinedButton.icon(
                onPressed: _stampaPdf,
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('PDF'),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              if (!completato)
                FilledButton.icon(
                  onPressed: _completaCarico,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Completa'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.successo,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
        if (carico.items.isEmpty && !completato) ...[
          const Gap(8),
          FilledButton.icon(
            onPressed: _aggiungiProdotto,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Aggiungi prodotto'),
          ),
        ],
      ],
    );
  }

  Widget _listaAggregata(Map<PeriodoConsegna, List<LoadItem>> gruppi) {
    return ListView(
      children: [
        for (final entry in gruppi.entries) ...[
          _intestazionePeriodo(entry.key, entry.value),
          const Gap(8),
          ..._aggregaPerProdotto(entry.value).entries.map(
                (e) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Text(
                          '${e.value.truncateToDouble() == e.value ? e.value.toStringAsFixed(0) : e.value.toStringAsFixed(1)} casse',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const Gap(18),
        ],
      ],
    );
  }

  Map<String, double> _aggregaPerProdotto(List<LoadItem> righe) {
    final mappa = <String, double>{};
    for (final r in righe) {
      mappa[r.nomeCompleto] = (mappa[r.nomeCompleto] ?? 0) + r.casse;
    }
    return mappa;
  }

  Widget _intestazionePeriodo(PeriodoConsegna periodo, List<LoadItem> righe) {
    final totale = righe.fold<double>(0, (t, r) => t + r.casse);
    return Row(
      children: [
        Icon(periodo.icona, size: 16, color: periodo.colore),
        const Gap(8),
        Text(
          periodo.etichetta.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: periodo.colore,
          ),
        ),
        const Gap(8),
        Expanded(child: Divider(color: periodo.colore.withOpacity(0.3))),
        const Gap(8),
        Text('${totale.toStringAsFixed(0)} casse',
            style: TextStyle(fontSize: 12, color: periodo.colore, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _rigaCarico(LoadItem item, bool completato) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: completato ? null : () => _modificaRiga(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: item.coloreFlutter,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (item.clienteNome != null && item.clienteNome!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(children: [
                          const Icon(Icons.storefront_outlined, size: 13, color: Colors.black45),
                          const Gap(4),
                          Expanded(
                            child: Text(item.clienteNome!,
                                style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                          ),
                        ]),
                      ),
                    if (item.note != null && item.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.sticky_note_2_outlined, size: 13, color: Colors.black45),
                          const Gap(4),
                          Expanded(
                            child: Text(
                              item.note!,
                              style: const TextStyle(
                                  fontSize: 12.5, color: Colors.black54, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ]),
                      ),
                  ],
                ),
              ),
              const Gap(8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${item.casseFormattate} casse',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (!completato)
                    SizedBox(
                      height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: const Icon(Icons.delete_outline, color: AppTheme.errore),
                        onPressed: () => _rimuoviRiga(item),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
