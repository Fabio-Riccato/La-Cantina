class WarehouseItem {
  final int productId;
  final String marca;
  final String tipo;
  final String taglia;
  final int bottigliePerCassa;
  final double casseDisponibili;

  WarehouseItem({
    required this.productId,
    required this.marca,
    required this.tipo,
    required this.taglia,
    required this.bottigliePerCassa,
    required this.casseDisponibili,
  });

  String get nomeCompleto => '$marca $tipo $taglia';

  factory WarehouseItem.fromJson(Map<String, dynamic> json) {
    return WarehouseItem(
      productId: json['product_id'] as int,
      marca: json['marca'] as String,
      tipo: json['tipo'] as String,
      taglia: json['taglia'] as String,
      bottigliePerCassa: json['bottiglie_per_cassa'] as int,
      casseDisponibili: double.parse((json['casse_disponibili'] ?? 0).toString()),
    );
  }
}

class HistoryEntry {
  final int id;
  final String data;
  final String stato;
  final int userId;
  final String socioNome;
  final String socioColore;
  final double totaleCasse;
  final int numeroProdotti;

  HistoryEntry({
    required this.id,
    required this.data,
    required this.stato,
    required this.userId,
    required this.socioNome,
    required this.socioColore,
    required this.totaleCasse,
    required this.numeroProdotti,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as int,
      data: json['data'].toString().substring(0, 10),
      stato: json['stato'] as String,
      userId: json['user_id'] as int,
      socioNome: json['socio_nome'] as String,
      socioColore: json['socio_colore'] as String? ?? '#3B82F6',
      totaleCasse: double.parse((json['totale_casse'] ?? 0).toString()),
      numeroProdotti: int.parse((json['numero_prodotti'] ?? 0).toString()),
    );
  }
}
