import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/load.dart';
import '../models/warehouse_item.dart';
import '../models/socio.dart';
import '../models/product.dart' show coloreDaHex;
import '../services/api_client.dart';
import '../services/app_data_service.dart';
import '../services/auth_provider.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/year_calendar_view.dart';
import 'home_shell.dart' show AccountMenuButton;
import 'load_detail_screen.dart';

enum VistaCalendario { anno, mese, settimana }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  VistaCalendario _vista = VistaCalendario.mese;
  DateTime _focus = DateTime.now();
  DateTime _selezionato = DateTime.now();

  Map<DateTime, List<HistoryEntry>> _carichiPerGiorno = {};
  List<Socio> _soci = [];
  Set<int> _sociVisibili = {}; // vuoto = tutti visibili

  bool _caricamento = true;
  String? _errore;
  bool _vistaRidottaStorico = false;
  // Cache dei carichi completi (con items) per la vista aggregata
  final Map<int, Load> _carichiCompleti = {};

  static DateTime _chiave(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _carica();
  }

  /// Intervallo di date da scaricare in base alla vista corrente (con un margine
  /// per rendere fluido lo scorrimento avanti/indietro senza ricaricare ogni volta).
  (DateTime, DateTime) get _intervallo {
    switch (_vista) {
      case VistaCalendario.anno:
        return (DateTime(_focus.year, 1, 1), DateTime(_focus.year, 12, 31));
      case VistaCalendario.mese:
        return (DateTime(_focus.year, _focus.month - 1, 1), DateTime(_focus.year, _focus.month + 2, 0));
      case VistaCalendario.settimana:
        return (_focus.subtract(const Duration(days: 21)), _focus.add(const Duration(days: 21)));
    }
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final (da, a) = _intervallo;
      final risultati = await Future.wait([
        AppDataService.getStorico(
          da: DateFormat('yyyy-MM-dd').format(da),
          a: DateFormat('yyyy-MM-dd').format(a),
        ),
        AppDataService.getSoci(),
      ]);

      final voci = risultati[0] as List<HistoryEntry>;
      final mappa = <DateTime, List<HistoryEntry>>{};
      for (final v in voci) {
        final k = _chiave(DateTime.parse(v.data));
        mappa.putIfAbsent(k, () => []).add(v);
      }

      setState(() {
        _carichiPerGiorno = mappa;
        _soci = risultati[1] as List<Socio>;
      });
    } on ApiException catch (e) {
      setState(() => _errore = e.message);
    } catch (_) {
      setState(() => _errore = 'Errore di connessione al server');
    } finally {
      if (mounted) setState(() => _caricamento = false);
    }
  }

  void _mostraMessaggio(String testo) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }

  /// Carichi di un giorno, filtrati per i soci selezionati
  List<HistoryEntry> _carichiDi(DateTime giorno) {
    final tutti = _carichiPerGiorno[_chiave(giorno)] ?? const <HistoryEntry>[];
    if (_sociVisibili.isEmpty) return tutti;
    return tutti.where((c) => _sociVisibili.contains(c.userId)).toList();
  }

  // ---------------------------------------------------------------
  // Stampa PDF
  // ---------------------------------------------------------------

  /// PDF di tutta l'azienda per il giorno selezionato, diviso per socio
  Future<void> _stampaGiornata() async {
    final dataIso = DateFormat('yyyy-MM-dd').format(_selezionato);
    try {
      var carichi = await AppDataService.getCarichiGiornata(dataIso);
      if (_sociVisibili.isNotEmpty) {
        carichi = carichi.where((c) => _sociVisibili.contains(c.userId)).toList();
      }
      if (carichi.isEmpty) {
        _mostraMessaggio('Nessun carico da stampare per questa giornata');
        return;
      }
      await PdfService.stampaGiornata(dataIso, carichi, totaliOnly: _vistaRidottaStorico);
    } on ApiException catch (e) {
      _mostraMessaggio(e.message);
    } catch (_) {
      _mostraMessaggio('Impossibile generare il PDF');
    }
  }

  /// PDF del carico di un solo socio
  Future<void> _stampaCaricoSingolo(HistoryEntry voce) async {
    try {
      final carico = await AppDataService.getCaricoById(voce.id);
      await PdfService.stampaCarico(carico);
    } on ApiException catch (e) {
      _mostraMessaggio(e.message);
    } catch (_) {
      _mostraMessaggio('Impossibile generare il PDF');
    }
  }

  // ---------------------------------------------------------------
  // Cancellazione storico
  // ---------------------------------------------------------------

  Future<void> _apriCancellazione() async {
    String modalita = 'giorno';
    DateTime giorno = _selezionato;
    DateTime meseAnno = _focus;
    int annoSelezionato = _focus.year;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cancella storico'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: modalita,
                  decoration: const InputDecoration(labelText: 'Cosa vuoi cancellare?'),
                  items: const [
                    DropdownMenuItem(value: 'giorno', child: Text('Un giorno specifico')),
                    DropdownMenuItem(value: 'settimana', child: Text('Una settimana')),
                    DropdownMenuItem(value: 'mese', child: Text('Un mese')),
                    DropdownMenuItem(value: 'anno', child: Text('Un anno')),
                    DropdownMenuItem(value: 'tutto', child: Text('Tutto lo storico')),
                  ],
                  onChanged: (v) => setDialogState(() => modalita = v!),
                ),
                const Gap(16),
                if (modalita == 'giorno' || modalita == 'settimana')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    onPressed: () async {
                      final scelta = await showDatePicker(
                        context: ctx,
                        initialDate: giorno,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        locale: const Locale('it', 'IT'),
                      );
                      if (scelta != null) setDialogState(() => giorno = scelta);
                    },
                    label: Text(
                      modalita == 'settimana'
                          ? 'Settimana del ${DateFormat('dd/MM/yyyy').format(giorno)}'
                          : DateFormat('dd/MM/yyyy').format(giorno),
                    ),
                  ),
                if (modalita == 'mese')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month_outlined, size: 16),
                    onPressed: () async {
                      final scelta = await showDatePicker(
                        context: ctx,
                        initialDate: meseAnno,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        locale: const Locale('it', 'IT'),
                      );
                      if (scelta != null) setDialogState(() => meseAnno = scelta);
                    },
                    label: Text(DateFormat('MMMM yyyy', 'it_IT').format(meseAnno)),
                  ),
                if (modalita == 'anno')
                  DropdownButtonFormField<int>(
                    value: annoSelezionato,
                    decoration: const InputDecoration(labelText: 'Anno'),
                    items: List.generate(8, (i) => DateTime.now().year - i)
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) => setDialogState(() => annoSelezionato = v!),
                  ),
                if (modalita == 'tutto')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errore.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Verrà cancellato TUTTO lo storico dei carichi di TUTTI i soci. '
                      'L\'operazione non è reversibile.',
                      style: TextStyle(color: AppTheme.errore, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.errore),
              onPressed: () async {
                Navigator.pop(ctx);
                final fmt = DateFormat('yyyy-MM-dd');
                try {
                  switch (modalita) {
                    case 'tutto':
                      await AppDataService.cancellaStorico(tutto: true);
                    case 'giorno':
                      final iso = fmt.format(giorno);
                      await AppDataService.cancellaStorico(da: iso, a: iso);
                    case 'settimana':
                      final lunedi = giorno.subtract(Duration(days: giorno.weekday - 1));
                      await AppDataService.cancellaStorico(
                        da: fmt.format(lunedi),
                        a: fmt.format(lunedi.add(const Duration(days: 6))),
                      );
                    case 'mese':
                      await AppDataService.cancellaStorico(
                        da: fmt.format(DateTime(meseAnno.year, meseAnno.month, 1)),
                        a: fmt.format(DateTime(meseAnno.year, meseAnno.month + 1, 0)),
                      );
                    case 'anno':
                      await AppDataService.cancellaStorico(
                        da: '$annoSelezionato-01-01',
                        a: '$annoSelezionato-12-31',
                      );
                  }
                  _carica();
                  _mostraMessaggio('Storico cancellato');
                } on ApiException catch (e) {
                  _mostraMessaggio(e.message);
                }
              },
              child: const Text('Cancella'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storico'),
        actions: [
          IconButton(
            tooltip: 'Vai a oggi',
            icon: const Icon(Icons.today_outlined),
            onPressed: () {
              setState(() {
                _focus = DateTime.now();
                _selezionato = DateTime.now();
              });
              _carica();
            },
          ),
          IconButton(
            tooltip: 'Cancella storico',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _apriCancellazione,
          ),
          const AccountMenuButton(),
        ],
      ),
      body: Column(
        children: [
          _selettoreVista(),
          if (_soci.isNotEmpty) _legendaSoci(auth.userId),
          const Divider(height: 1),
          Expanded(child: _buildCalendarioEDettaglio(auth.userId)),
        ],
      ),
    );
  }

  Widget _selettoreVista() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<VistaCalendario>(
              segments: const [
                ButtonSegment(value: VistaCalendario.anno, label: Text('Anno'), icon: Icon(Icons.grid_view, size: 16)),
                ButtonSegment(
                    value: VistaCalendario.mese, label: Text('Mese'), icon: Icon(Icons.calendar_view_month, size: 16)),
                ButtonSegment(
                    value: VistaCalendario.settimana,
                    label: Text('Settimana'),
                    icon: Icon(Icons.calendar_view_week, size: 16)),
              ],
              selected: {_vista},
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (s) {
                setState(() => _vista = s.first);
                _carica();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Legenda con i colori dei soci: toccando un nome si filtra la vista
  Widget _legendaSoci(int? mioId) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _soci.map((s) {
          final colore = coloreDaHex(s.colore);
          final attivo = _sociVisibili.isEmpty || _sociVisibili.contains(s.id);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: attivo,
              showCheckmark: false,
              avatar: CircleAvatar(backgroundColor: colore, radius: 8),
              label: Text(
                s.id == mioId ? '${s.nome} (io)' : s.nome,
                style: TextStyle(fontSize: 12.5, fontWeight: s.id == mioId ? FontWeight.w700 : FontWeight.w500),
              ),
              selectedColor: colore.withOpacity(0.15),
              side: BorderSide(color: attivo ? colore : Colors.black26),
              onSelected: (_) {
                setState(() {
                  // Il set vuoto significa "tutti visibili": al primo tocco isolo gli altri
                  if (_sociVisibili.isEmpty) {
                    _sociVisibili = _soci.map((x) => x.id).toSet()..remove(s.id);
                  } else if (_sociVisibili.contains(s.id)) {
                    _sociVisibili.remove(s.id);
                  } else {
                    _sociVisibili.add(s.id);
                  }
                  if (_sociVisibili.length == _soci.length) _sociVisibili = {};
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarioEDettaglio(int? mioId) {
    if (_caricamento && _carichiPerGiorno.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errore != null) {
      return Center(child: Text(_errore!, style: const TextStyle(color: AppTheme.errore)));
    }

    if (_vista == VistaCalendario.anno) {
      return Column(
        children: [
          _navigazioneAnno(),
          Expanded(
            child: VistaAnno(
              anno: _focus.year,
              giornoSelezionato: _selezionato,
              carichiPerGiorno: _carichiPerGiorno,
              onGiornoSelezionato: (g) => setState(() {
                _selezionato = g;
                _focus = g;
              }),
              onMeseAperto: (m) {
                setState(() {
                  _vista = VistaCalendario.mese;
                  _focus = m;
                });
                _carica();
              },
            ),
          ),
          _pannelloGiorno(mioId, compatto: true),
        ],
      );
    }

    return Column(
      children: [
        _calendarioTabellare(),
        const Divider(height: 1),
        Expanded(child: _pannelloGiorno(mioId)),
      ],
    );
  }

  Widget _navigazioneAnno() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() => _focus = DateTime(_focus.year - 1, _focus.month, 1));
              _carica();
            },
          ),
          const Gap(12),
          Text('${_focus.year}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Gap(12),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _focus = DateTime(_focus.year + 1, _focus.month, 1));
              _carica();
            },
          ),
        ],
      ),
    );
  }

  Widget _calendarioTabellare() {
    return TableCalendar<HistoryEntry>(
      locale: 'it_IT',
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime(2100, 12, 31),
      focusedDay: _focus,
      currentDay: DateTime.now(),
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarFormat: _vista == VistaCalendario.mese ? CalendarFormat.month : CalendarFormat.week,
      availableGestures: AvailableGestures.horizontalSwipe,
      selectedDayPredicate: (d) => isSameDay(d, _selezionato),
      eventLoader: _carichiDi,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
        weekendStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black38),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        todayDecoration: BoxDecoration(
          color: AppTheme.primario.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(color: AppTheme.primario, fontWeight: FontWeight.w700),
        selectedDecoration: const BoxDecoration(color: AppTheme.primario, shape: BoxShape.circle),
        markersMaxCount: 4,
        cellMargin: const EdgeInsets.all(5),
      ),
      onDaySelected: (selezionato, focus) {
        setState(() {
          _selezionato = selezionato;
          _focus = focus;
        });
      },
      onPageChanged: (focus) {
        setState(() => _focus = focus);
        _carica();
      },
      calendarBuilders: CalendarBuilders<HistoryEntry>(
        // Un pallino per socio, con il colore del socio
        markerBuilder: (context, giorno, carichi) {
          if (carichi.isEmpty) return null;
          return Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: carichi
                  .take(4)
                  .map((c) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: coloreDaHex(c.socioColore),
                          shape: BoxShape.circle,
                        ),
                      ))
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _caricaDettagliPerVista() async {
    final carichi = _carichiDi(_selezionato);
    for (final voce in carichi) {
      if (!_carichiCompleti.containsKey(voce.id)) {
        try {
          final carico = await AppDataService.getCaricoById(voce.id);
          if (mounted) setState(() => _carichiCompleti[voce.id] = carico);
        } catch (_) {}
      }
    }
  }

  Map<String, double> _aggregaPerProdottoStorico(Load carico) {
    final mappa = <String, double>{};
    for (final r in carico.items) {
      mappa[r.nomeCompleto] = (mappa[r.nomeCompleto] ?? 0) + r.casse;
    }
    return mappa;
  }

  /// Pannello sotto al calendario con i carichi del giorno selezionato
  Widget _pannelloGiorno(int? mioId, {bool compatto = false}) {
    final carichi = _carichiDi(_selezionato);
    final totale = carichi.fold<double>(0, (t, c) => t + c.totaleCasse);

    final contenuto = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE d MMMM yyyy', 'it_IT').format(_selezionato),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    if (carichi.isNotEmpty)
                      Text(
                        '${carichi.length} ${carichi.length == 1 ? "carico" : "carichi"}  ·  ${totale.toStringAsFixed(0)} casse',
                        style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                      ),
                  ],
                ),
              ),
              if (carichi.isNotEmpty)
                TextButton.icon(
                  onPressed: _stampaGiornata,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF giornata'),
                ),
            ],
          ),
        ),
        if (carichi.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Text('Vista:', style: TextStyle(fontSize: 13, color: Colors.black54)),
                const Gap(8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Per cliente')),
                    ButtonSegment(value: true, label: Text('Totali')),
                  ],
                  selected: {_vistaRidottaStorico},
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  onSelectionChanged: (s) {
                    setState(() => _vistaRidottaStorico = s.first);
                    if (s.first) _caricaDettagliPerVista();
                  },
                ),
              ],
            ),
          ),
        ],
        if (carichi.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text('Nessun carico in questa giornata', style: TextStyle(color: Colors.black45)),
            ),
          )
        else if (_vistaRidottaStorico)
          ...carichi.map((v) => _cardCaricoAggregata(v, mioId))
        else
          ...carichi.map((v) => _cardCarico(v, mioId)),
        const Gap(12),
      ],
    );

    if (compatto) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black.withOpacity(0.08))),
        ),
        child: SingleChildScrollView(child: contenuto),
      );
    }

    return RefreshIndicator(
      onRefresh: _carica,
      child: ListView(children: [contenuto]),
    );
  }

  Widget _cardCaricoAggregata(HistoryEntry v, int? mioId) {
    final colore = coloreDaHex(v.socioColore);
    final carico = _carichiCompleti[v.id];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colore.withOpacity(0.4), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 5,
                  height: 24,
                  decoration: BoxDecoration(color: colore, borderRadius: BorderRadius.circular(3)),
                ),
                const Gap(10),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colore,
                  child: Text(
                    v.socioNome.isNotEmpty ? v.socioNome.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const Gap(8),
                Text(v.socioNome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const Spacer(),
                Text('${v.totaleCasse.toStringAsFixed(0)} casse',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13)),
              ]),
              if (carico == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              else ...[
                const Gap(8),
                ..._aggregaPerProdottoStorico(carico).entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          const Gap(4),
                          Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                          Text(
                            '${e.value.truncateToDouble() == e.value ? e.value.toStringAsFixed(0) : e.value.toStringAsFixed(1)} casse',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardCarico(HistoryEntry v, int? mioId) {
    final colore = coloreDaHex(v.socioColore);
    final mio = v.userId == mioId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: mio ? colore : Colors.black.withOpacity(0.06), width: mio ? 1.8 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LoadDetailScreen(loadId: v.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 42,
                  decoration: BoxDecoration(color: colore, borderRadius: BorderRadius.circular(3)),
                ),
                const Gap(12),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colore,
                  child: Text(
                    v.socioNome.isNotEmpty ? v.socioNome.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                            v.socioNome,
                            style: TextStyle(fontWeight: mio ? FontWeight.w800 : FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (mio)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: colore.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text('io',
                                  style: TextStyle(fontSize: 10, color: colore, fontWeight: FontWeight.w700)),
                            ),
                          ),
                      ]),
                      const Gap(2),
                      Text(
                        '${v.numeroProdotti} prodotti  ·  ${v.totaleCasse.toStringAsFixed(0)} casse  ·  ${v.stato == "completato" ? "completato" : "in corso"}',
                        style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Stampa il carico di ${v.socioNome}',
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  onPressed: () => _stampaCaricoSingolo(v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
