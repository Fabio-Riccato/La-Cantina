import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../models/load.dart';
import '../services/api_client.dart';
import '../services/app_data_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';

class LoadDetailScreen extends StatefulWidget {
  final int loadId;
  const LoadDetailScreen({super.key, required this.loadId});

  @override
  State<LoadDetailScreen> createState() => _LoadDetailScreenState();
}

class _LoadDetailScreenState extends State<LoadDetailScreen> {
  Load? _carico;
  bool _caricamento = true;
  String? _errore;
  bool _vistaRidotta = false;

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
      final carico = await AppDataService.getCaricoById(widget.loadId);
      setState(() => _carico = carico);
    } on ApiException catch (e) {
      setState(() => _errore = e.message);
    } catch (_) {
      setState(() => _errore = 'Errore di connessione al server');
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  Future<void> _stampaPdf() async {
    if (_carico == null) return;
    try {
      await PdfService.stampaCarico(_carico!, totaliOnly: _vistaRidotta);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Impossibile generare il PDF')));
      }
    }
  }

  Map<String, double> _aggregaPerProdotto(List<LoadItem> righe) {
    final mappa = <String, double>{};
    for (final r in righe) {
      mappa[r.nomeCompleto] = (mappa[r.nomeCompleto] ?? 0) + r.casse;
    }
    return mappa;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio carico'),
        actions: [
          IconButton(
            tooltip: 'Stampa questo carico (PDF)',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _carico == null ? null : _stampaPdf,
          ),
        ],
      ),
      body: _buildContenuto(),
    );
  }

  Widget _buildContenuto() {
    if (_caricamento) return const Center(child: CircularProgressIndicator());
    if (_errore != null) {
      return Center(child: Text(_errore!, style: const TextStyle(color: AppTheme.errore)));
    }

    final carico = _carico!;
    final colore = carico.coloreFlutter;

    return RefreshIndicator(
      onRefresh: _carica,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colore,
                    child: Text(
                      carico.socioNome.isNotEmpty ? carico.socioNome.substring(0, 1).toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(carico.socioNome,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(
                          DateFormat('EEEE d MMMM yyyy', 'it_IT').format(DateTime.parse(carico.data)),
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(carico.completato ? 'Completato' : 'In corso'),
                    backgroundColor:
                        (carico.completato ? AppTheme.successo : AppTheme.accento).withOpacity(0.15),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: carico.completato ? AppTheme.successo : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),
          ),
          const Gap(20),
          if (carico.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Nessun prodotto in questo carico')),
            )
          else ...[
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
            const Gap(12),
            if (_vistaRidotta) ...[
              for (final entry in carico.perPeriodo.entries) ...[
                Row(children: [
                  Icon(entry.key.icona, size: 16, color: entry.key.colore),
                  const Gap(8),
                  Text(
                    entry.key.etichetta.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: entry.key.colore,
                    ),
                  ),
                  const Gap(8),
                  Expanded(child: Divider(color: entry.key.colore.withOpacity(0.3))),
                ]),
                const Gap(10),
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
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                const Gap(14),
              ],
            ] else ...[
            for (final entry in carico.perPeriodo.entries) ...[
              Row(children: [
                Icon(entry.key.icona, size: 16, color: entry.key.colore),
                const Gap(8),
                Text(
                  entry.key.etichetta.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: entry.key.colore,
                  ),
                ),
                const Gap(8),
                Expanded(child: Divider(color: entry.key.colore.withOpacity(0.3))),
              ]),
              const Gap(10),
              ...entry.value.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 36,
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
                                  child: Text('Per: ${item.clienteNome}',
                                      style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                                ),
                              if (item.note != null && item.note!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    item.note!,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.black54,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Gap(8),
                        Text('${item.casseFormattate} casse',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const Gap(14),
            ],
            ],
            const Gap(4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primario.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Totale colli', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('${carico.totaleCasse.toStringAsFixed(0)} casse',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
            ),
            const Gap(16),
            OutlinedButton.icon(
              onPressed: _stampaPdf,
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Stampa lista (PDF)'),
            ),
          ],
        ],
      ),
    );
  }
}
