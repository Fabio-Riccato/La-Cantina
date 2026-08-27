import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/load.dart';
import '../models/product.dart' show coloreDaHex;

/// Genera i PDF stampabili delle liste di carico e apre la finestra di stampa/condivisione.
///
/// Funziona allo stesso modo su Android, iOS e Web: su mobile apre il pannello nativo
/// di stampa/condivisione (da cui puoi stampare, salvare o inviare su WhatsApp),
/// sul web apre la finestra di stampa del browser (da cui puoi anche salvare come PDF).
class PdfService {
  static PdfColor _pdfColor(String hex) {
    final c = coloreDaHex(hex);
    return PdfColor(c.red / 255, c.green / 255, c.blue / 255);
  }

  static String _dataEstesa(String dataIso) {
    return DateFormat('EEEE d MMMM yyyy', 'it_IT').format(DateTime.parse(dataIso));
  }

  static String _capitalizza(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  // ---------------------------------------------------------------
  // PDF di UN SINGOLO carico (usato nella sezione Carico e nel dettaglio dello Storico)
  // ---------------------------------------------------------------

  static Future<void> stampaCarico(Load carico, {bool totaliOnly = false}) async {
    final doc = pw.Document();
    final theme = await _tema();

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
        footer: _footer,
        build: (context) => [
          _intestazione(
            titolo: 'Lista di carico',
            sottotitolo: _capitalizza(_dataEstesa(carico.data)),
            etichettaDestra: carico.socioNome,
            coloreDestra: _pdfColor(carico.socioColore),
            stato: carico.completato ? 'Completato' : 'Da caricare',
          ),
          pw.SizedBox(height: 18),
          ..._sezioniCarico(carico, totaliOnly: totaliOnly),
          pw.SizedBox(height: 16),
          _totale(carico),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'carico_${carico.socioNome}_${carico.data}.pdf',
    );
  }

  // ---------------------------------------------------------------
  // PDF di TUTTA L'AZIENDA per una giornata, diviso per socio
  // (usato nello Storico: giorni passati e futuri)
  // ---------------------------------------------------------------

  static Future<void> stampaGiornata(String dataIso, List<Load> carichi, {bool totaliOnly = false}) async {
    final doc = pw.Document();
    final theme = await _tema();
    final totaleGenerale = carichi.fold<double>(0, (t, c) => t + c.totaleCasse);

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
        footer: _footer,
        build: (context) => [
          _intestazione(
            titolo: 'Carichi della giornata',
            sottotitolo: _capitalizza(_dataEstesa(dataIso)),
            etichettaDestra: '${carichi.length} ${carichi.length == 1 ? "socio" : "soci"}',
            coloreDestra: PdfColors.blueGrey700,
            stato: '${totaleGenerale.toStringAsFixed(0)} casse in totale',
          ),
          pw.SizedBox(height: 20),
          if (carichi.isEmpty)
            pw.Text('Nessun carico registrato per questa giornata.',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600))
          else
            for (final carico in carichi) ...[
              _bandaSocio(carico),
              pw.SizedBox(height: 8),
              ..._sezioniCarico(carico, totaliOnly: totaliOnly),
              pw.SizedBox(height: 6),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Totale ${carico.socioNome}: ${carico.totaleCasse.toStringAsFixed(0)} casse',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 22),
            ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'carichi_giornata_$dataIso.pdf',
    );
  }

  // ---------------------------------------------------------------
  // Componenti riutilizzabili
  // ---------------------------------------------------------------

  static Future<pw.ThemeData> _tema() async {
    // Usa i font Google integrati nel pacchetto printing: supportano gli accenti italiani
    return pw.ThemeData.withFont(
      base: await PdfGoogleFonts.interRegular(),
      bold: await PdfGoogleFonts.interSemiBold(),
    );
  }

  static pw.Widget _intestazione({
    required String titolo,
    required String sottotitolo,
    required String etichettaDestra,
    required PdfColor coloreDestra,
    required String stato,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(titolo, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(sottotitolo, style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: PdfColors.black, width: 1),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                etichettaDestra,
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(stato, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1.4, color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _bandaSocio(Load carico) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border(left: const pw.BorderSide(color: PdfColors.grey800, width: 4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(carico.socioNome, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.Text(
            carico.completato ? 'Completato' : 'Da caricare',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  /// Costruisce una tabella per ogni periodo di consegna (Subito / A metà giro / Alla fine)
  static List<pw.Widget> _sezioniCarico(Load carico, {bool totaliOnly = false}) {
    if (carico.items.isEmpty) {
      return [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          child: pw.Text('Nessun prodotto in questo carico.',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        ),
      ];
    }

    final widgets = <pw.Widget>[];
    carico.perPeriodo.forEach((periodo, righe) {
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
        child: pw.Row(children: [
          pw.Text('●',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(width: 7),
          pw.Text(periodo.etichetta.toUpperCase(),
              style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.6)),
        ]),
      ));
      widgets.add(totaliOnly ? _tabellaRidotta(righe) : _tabellaRighe(righe));
    });
    return widgets;
  }

  static pw.Widget _tabellaRighe(List<LoadItem> righe) {
    return pw.TableHelper.fromTextArray(
      headers: ['Casse', 'Prodotto', 'Cliente', 'Note', 'Fatto'],
      data: righe
          .map((r) => [
                r.casseFormattate,
                r.nomeCompleto,
                r.clienteNome ?? '-',
                (r.note == null || r.note!.isEmpty) ? '-' : r.note!,
                '', // casella vuota da spuntare a penna durante il carico
              ])
          .toList(),
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      headerStyle: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellHeight: 22,
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.center,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(42),
        1: const pw.FlexColumnWidth(3.1),
        2: const pw.FlexColumnWidth(2.0),
        3: const pw.FlexColumnWidth(2.4),
        4: const pw.FixedColumnWidth(38),
      },
    );
  }

  static pw.Widget _tabellaRidotta(List<LoadItem> righe) {
    final aggregata = <String, double>{};
    for (final r in righe) {
      aggregata[r.nomeCompleto] = (aggregata[r.nomeCompleto] ?? 0) + r.casse;
    }
    final dati = aggregata.entries.map((e) {
      final casse = e.value;
      final casseStr = casse.truncateToDouble() == casse
          ? casse.toStringAsFixed(0)
          : casse.toStringAsFixed(1);
      return [casseStr, e.key, ''];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: ['Casse', 'Prodotto', 'Fatto'],
      data: dati,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      headerStyle: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellHeight: 22,
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(42),
        1: const pw.FlexColumnWidth(5.0),
        2: const pw.FixedColumnWidth(38),
      },
    );
  }

  static pw.Widget _totale(Load carico) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Totale colli da caricare', style: const pw.TextStyle(fontSize: 12)),
          pw.Text('${carico.totaleCasse.toStringAsFixed(0)} casse',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 12),
      child: pw.Text(
        'Stampato il ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}  ·  Pagina ${context.pageNumber} di ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
      ),
    );
  }
}
