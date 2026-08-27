import 'package:flutter/material.dart';
import '../models/product.dart' show hexDaColore;

/// Tavolozza di colori pensata per essere leggibile sia a schermo che stampata in PDF.
const List<Color> tavolozzaColori = [
  Color(0xFF38BDF8), // azzurro
  Color(0xFF0EA5E9), // blu
  Color(0xFF3B82F6), // blu scuro
  Color(0xFF6366F1), // indaco
  Color(0xFF9333EA), // viola
  Color(0xFFEC4899), // rosa
  Color(0xFFEF4444), // rosso
  Color(0xFFF97316), // arancione
  Color(0xFFEAB308), // giallo
  Color(0xFF84CC16), // lime
  Color(0xFF22C55E), // verde
  Color(0xFF14B8A6), // verde acqua
  Color(0xFF78716C), // marrone
  Color(0xFF64748B), // grigio
];

/// Indice, nella [tavolozzaColori], del colore più vicino a [hex] ("#RRGGBB").
///
/// Serve per raggruppare e ordinare i prodotti per colore: prodotti con lo
/// stesso colore (o un colore molto simile) finiscono vicini, nell'ordine in
/// cui i colori compaiono nella tavolozza (azzurro, blu, ... rosso, arancione, ...).
int indiceColoreTavolozza(String hex) {
  final rgb = _hexInRgb(hex);
  final r = (rgb >> 16) & 0xFF, g = (rgb >> 8) & 0xFF, b = rgb & 0xFF;
  var migliore = 0;
  var minDist = 1 << 30;
  for (var i = 0; i < tavolozzaColori.length; i++) {
    final t = tavolozzaColori[i].value & 0xFFFFFF;
    final dr = r - ((t >> 16) & 0xFF);
    final dg = g - ((t >> 8) & 0xFF);
    final db = b - (t & 0xFF);
    final dist = dr * dr + dg * dg + db * db;
    if (dist < minDist) {
      minDist = dist;
      migliore = i;
    }
  }
  return migliore;
}

int _hexInRgb(String hex) {
  final pulito = hex.replaceFirst('#', '');
  if (pulito.length != 6) return 0x64748B;
  return int.tryParse(pulito, radix: 16) ?? 0x64748B;
}

/// Griglia di colori selezionabili, usata nel form dei prodotti.
class SelettoreColore extends StatelessWidget {
  final String coloreSelezionato; // formato "#RRGGBB"
  final ValueChanged<String> onCambiato;
  final String etichetta;

  const SelettoreColore({
    super.key,
    required this.coloreSelezionato,
    required this.onCambiato,
    this.etichetta = 'Colore identificativo',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etichetta, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tavolozzaColori.map((colore) {
            final hex = hexDaColore(colore);
            final selezionato = hex.toUpperCase() == coloreSelezionato.toUpperCase();
            return GestureDetector(
              onTap: () => onCambiato(hex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colore,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selezionato ? Colors.black87 : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: selezionato ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
