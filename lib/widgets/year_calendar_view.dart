import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/warehouse_item.dart';
import '../models/product.dart' show coloreDaHex;

/// Vista "anno" del calendario: 12 mini-mesi affiancati, con i giorni colorati
/// in base ai soci che hanno un carico quel giorno.
class VistaAnno extends StatelessWidget {
  final int anno;
  final DateTime? giornoSelezionato;
  final Map<DateTime, List<HistoryEntry>> carichiPerGiorno;
  final ValueChanged<DateTime> onGiornoSelezionato;
  final ValueChanged<DateTime> onMeseAperto;

  const VistaAnno({
    super.key,
    required this.anno,
    required this.giornoSelezionato,
    required this.carichiPerGiorno,
    required this.onGiornoSelezionato,
    required this.onMeseAperto,
  });

  @override
  Widget build(BuildContext context) {
    final larghezza = MediaQuery.of(context).size.width;
    final colonne = larghezza >= 1100
        ? 4
        : larghezza >= 800
            ? 3
            : larghezza >= 520
                ? 2
                : 1;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: colonne,
        childAspectRatio: 0.92,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 12,
      itemBuilder: (context, i) => _MiniMese(
        mese: DateTime(anno, i + 1, 1),
        giornoSelezionato: giornoSelezionato,
        carichiPerGiorno: carichiPerGiorno,
        onGiornoSelezionato: onGiornoSelezionato,
        onMeseAperto: onMeseAperto,
      ),
    );
  }
}

class _MiniMese extends StatelessWidget {
  final DateTime mese;
  final DateTime? giornoSelezionato;
  final Map<DateTime, List<HistoryEntry>> carichiPerGiorno;
  final ValueChanged<DateTime> onGiornoSelezionato;
  final ValueChanged<DateTime> onMeseAperto;

  const _MiniMese({
    required this.mese,
    required this.giornoSelezionato,
    required this.carichiPerGiorno,
    required this.onGiornoSelezionato,
    required this.onMeseAperto,
  });

  static DateTime _chiave(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _stessoGiorno(DateTime a, DateTime? b) =>
      b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final giorniNelMese = DateTime(mese.year, mese.month + 1, 0).day;
    // In Italia la settimana inizia di lunedì: weekday va da 1 (lun) a 7 (dom)
    final offsetIniziale = DateTime(mese.year, mese.month, 1).weekday - 1;
    final oggi = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => onMeseAperto(mese),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  DateFormat('MMMM', 'it_IT').format(mese).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: ['L', 'M', 'M', 'G', 'V', 'S', 'D']
                  .map((g) => Expanded(
                        child: Center(
                          child: Text(g,
                              style: const TextStyle(
                                  fontSize: 9.5, color: Colors.black38, fontWeight: FontWeight.w600)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                ),
                itemCount: offsetIniziale + giorniNelMese,
                itemBuilder: (context, i) {
                  if (i < offsetIniziale) return const SizedBox.shrink();

                  final giorno = DateTime(mese.year, mese.month, i - offsetIniziale + 1);
                  final carichi = carichiPerGiorno[_chiave(giorno)] ?? const [];
                  final selezionato = _stessoGiorno(giorno, giornoSelezionato);
                  final isOggi = _stessoGiorno(giorno, oggi);

                  // Se c'è un solo socio uso il suo colore pieno, altrimenti un gradiente dei colori
                  final colori = carichi.map((c) => coloreDaHex(c.socioColore)).toList();

                  return GestureDetector(
                    onTap: () => onGiornoSelezionato(giorno),
                    child: Container(
                      margin: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: colori.length > 1
                            ? LinearGradient(colors: colori, begin: Alignment.topLeft, end: Alignment.bottomRight)
                            : null,
                        color: colori.length == 1 ? colori.first : null,
                        border: selezionato
                            ? Border.all(color: Colors.black87, width: 1.6)
                            : (isOggi ? Border.all(color: Colors.black38, width: 1.2) : null),
                      ),
                      child: Center(
                        child: Text(
                          '${giorno.day}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: carichi.isNotEmpty || isOggi ? FontWeight.w700 : FontWeight.normal,
                            color: carichi.isNotEmpty ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
