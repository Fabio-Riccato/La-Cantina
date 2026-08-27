import 'package:flutter/material.dart';

/// Converte un colore in formato "#RRGGBB" in un Color di Flutter.
Color coloreDaHex(String hex, {Color fallback = const Color(0xFF64748B)}) {
  try {
    final pulito = hex.replaceFirst('#', '');
    if (pulito.length != 6) return fallback;
    return Color(int.parse('FF$pulito', radix: 16));
  } catch (_) {
    return fallback;
  }
}

/// Converte un Color di Flutter in stringa "#RRGGBB".
String hexDaColore(Color colore) {
  final valore = colore.value & 0xFFFFFF;
  return '#${valore.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class Product {
  final int id;
  final String marca;
  final String tipo;
  final String taglia;
  final double prezzo;
  final int bottigliePerCassa;
  final String colore;
  final bool attivo;
  final double casseDisponibili;

  Product({
    required this.id,
    required this.marca,
    required this.tipo,
    required this.taglia,
    required this.prezzo,
    required this.bottigliePerCassa,
    required this.colore,
    required this.attivo,
    required this.casseDisponibili,
  });

  String get nomeCompleto => '$marca $tipo $taglia';
  Color get coloreFlutter => coloreDaHex(colore);

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      marca: json['marca'] as String,
      tipo: json['tipo'] as String,
      taglia: json['taglia'] as String,
      prezzo: double.parse(json['prezzo'].toString()),
      bottigliePerCassa: json['bottiglie_per_cassa'] as int,
      colore: json['colore'] as String? ?? '#64748B',
      attivo: json['attivo'] as bool? ?? true,
      casseDisponibili: double.parse((json['casse_disponibili'] ?? 0).toString()),
    );
  }
}
