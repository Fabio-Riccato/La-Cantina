import 'package:flutter/material.dart';
import 'product.dart' show coloreDaHex;

/// Momento del giro in cui va effettuata la consegna.
enum PeriodoConsegna { subito, medio, fine }

extension PeriodoConsegnaX on PeriodoConsegna {
  /// Valore inviato al backend
  String get valore => switch (this) {
        PeriodoConsegna.subito => 'subito',
        PeriodoConsegna.medio => 'medio',
        PeriodoConsegna.fine => 'fine',
      };

  /// Etichetta mostrata nell'interfaccia e nei PDF
  String get etichetta => switch (this) {
        PeriodoConsegna.subito => 'Subito',
        PeriodoConsegna.medio => 'A metà giro',
        PeriodoConsegna.fine => 'Alla fine',
      };

  Color get colore => switch (this) {
        PeriodoConsegna.subito => const Color(0xFFD64545),
        PeriodoConsegna.medio => const Color(0xFFE8A33D),
        PeriodoConsegna.fine => const Color(0xFF2E9E5B),
      };

  IconData get icona => switch (this) {
        PeriodoConsegna.subito => Icons.bolt_rounded,
        PeriodoConsegna.medio => Icons.schedule_rounded,
        PeriodoConsegna.fine => Icons.flag_rounded,
      };

  static PeriodoConsegna daValore(String? v) {
    switch (v) {
      case 'subito':
        return PeriodoConsegna.subito;
      case 'fine':
        return PeriodoConsegna.fine;
      default:
        return PeriodoConsegna.medio;
    }
  }
}

class LoadItem {
  final int id;
  final int productId;
  final String marca;
  final String tipo;
  final String taglia;
  final double casse;
  final String? clienteNome;
  final String? note;
  final PeriodoConsegna periodoConsegna;
  final String prodottoColore;

  LoadItem({
    required this.id,
    required this.productId,
    required this.marca,
    required this.tipo,
    required this.taglia,
    required this.casse,
    this.clienteNome,
    this.note,
    required this.periodoConsegna,
    required this.prodottoColore,
  });

  String get nomeCompleto => '$marca $tipo $taglia';
  Color get coloreFlutter => coloreDaHex(prodottoColore);

  /// Mostra "3" invece di "3.0" quando la quantità è intera
  String get casseFormattate =>
      casse.truncateToDouble() == casse ? casse.toStringAsFixed(0) : casse.toStringAsFixed(1);

  factory LoadItem.fromJson(Map<String, dynamic> json) {
    return LoadItem(
      id: json['id'] as int,
      productId: json['product_id'] as int,
      marca: json['marca'] as String,
      tipo: json['tipo'] as String,
      taglia: json['taglia'] as String,
      casse: double.parse(json['casse'].toString()),
      clienteNome: json['cliente_nome'] as String?,
      note: json['note'] as String?,
      periodoConsegna: PeriodoConsegnaX.daValore(json['periodo_consegna'] as String?),
      prodottoColore: json['prodotto_colore'] as String? ?? '#64748B',
    );
  }
}

class Load {
  final int id;
  final String data;
  final int userId;
  final String socioNome;
  final String socioColore;
  final String stato; // 'in_corso' | 'completato'
  final List<LoadItem> items;

  Load({
    required this.id,
    required this.data,
    required this.userId,
    required this.socioNome,
    required this.socioColore,
    required this.stato,
    required this.items,
  });

  double get totaleCasse => items.fold(0, (tot, item) => tot + item.casse);
  Color get coloreFlutter => coloreDaHex(socioColore);
  bool get completato => stato == 'completato';

  /// Righe raggruppate per periodo di consegna, nell'ordine reale del giro
  Map<PeriodoConsegna, List<LoadItem>> get perPeriodo {
    final mappa = <PeriodoConsegna, List<LoadItem>>{};
    for (final periodo in PeriodoConsegna.values) {
      final righe = items.where((i) => i.periodoConsegna == periodo).toList();
      if (righe.isNotEmpty) mappa[periodo] = righe;
    }
    return mappa;
  }

  factory Load.fromJson(Map<String, dynamic> json) {
    return Load(
      id: json['id'] as int,
      data: json['data'].toString().substring(0, 10),
      userId: json['user_id'] as int,
      socioNome: json['socio_nome'] as String? ?? '',
      socioColore: json['socio_colore'] as String? ?? '#3B82F6',
      stato: json['stato'] as String,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => LoadItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
