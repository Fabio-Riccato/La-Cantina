import '../models/product.dart';
import '../models/load.dart';
import '../models/warehouse_item.dart';
import '../models/socio.dart';
import 'api_client.dart';

class AppDataService {
  // ---- Prodotti ----

  static Future<List<Product>> getProdotti({bool soloAttivi = true}) async {
    final data = await apiClient.get('/products', query: {'attivo': soloAttivi.toString()});
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  static Future<void> creaProdotto({
    required String marca,
    required String tipo,
    required String taglia,
    required double prezzo,
    required int bottigliePerCassa,
    required String colore,
  }) {
    return apiClient.post('/products', body: {
      'marca': marca,
      'tipo': tipo,
      'taglia': taglia,
      'prezzo': prezzo,
      'bottiglie_per_cassa': bottigliePerCassa,
      'colore': colore,
    });
  }

  static Future<void> modificaProdotto(int id, Map<String, dynamic> campi) {
    return apiClient.put('/products/$id', body: campi);
  }

  static Future<void> disattivaProdotto(int id) {
    return apiClient.delete('/products/$id');
  }

  static Future<void> riattivaProdotto(int id) {
    return apiClient.post('/products/$id/riattiva');
  }

  // ---- Magazzino ----

  static Future<List<WarehouseItem>> getMagazzino() async {
    final data = await apiClient.get('/warehouse');
    return (data as List).map((e) => WarehouseItem.fromJson(e)).toList();
  }

  static Future<void> registraArrivoFornitore(int productId, double casse) {
    return apiClient.post('/warehouse/arrivo', body: {'product_id': productId, 'casse': casse});
  }

  static Future<void> rettificaGiacenza(int productId, double nuovoValore) {
    return apiClient.post('/warehouse/rettifica', body: {'product_id': productId, 'casse': nuovoValore});
  }

  // ---- Carico ----

  static Future<Load> getCaricoOggi() async {
    final data = await apiClient.get('/loads/oggi');
    return Load.fromJson(data);
  }

  static Future<Load> getCaricoPerData(String data) async {
    final result = await apiClient.get('/loads/data/$data');
    return Load.fromJson(result);
  }

  static Future<Load> getCaricoById(int id) async {
    final result = await apiClient.get('/loads/$id');
    return Load.fromJson(result);
  }

  static Future<void> aggiungiAlCarico(
    int loadId,
    int productId,
    double casse, {
    String? clienteNome,
    String? note,
    PeriodoConsegna periodo = PeriodoConsegna.medio,
  }) {
    return apiClient.post('/loads/$loadId/items', body: {
      'product_id': productId,
      'casse': casse,
      'periodo_consegna': periodo.valore,
      if (clienteNome != null && clienteNome.isNotEmpty) 'cliente_nome': clienteNome,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  static Future<void> aggiornaRigaCarico(
    int loadId,
    int itemId, {
    double? casse,
    String? clienteNome,
    String? note,
    PeriodoConsegna? periodo,
  }) {
    return apiClient.put('/loads/$loadId/items/$itemId', body: {
      if (casse != null) 'casse': casse,
      if (clienteNome != null) 'cliente_nome': clienteNome.isEmpty ? null : clienteNome,
      if (note != null) 'note': note.isEmpty ? null : note,
      if (periodo != null) 'periodo_consegna': periodo.valore,
    });
  }

  /// Tutti i carichi di tutti i soci per una data: serve per il PDF della giornata
  static Future<List<Load>> getCarichiGiornata(String dataIso) async {
    final data = await apiClient.get('/loads/giorno/$dataIso');
    return (data as List).map((e) => Load.fromJson(e)).toList();
  }

  static Future<void> rimuoviRigaCarico(int loadId, int itemId) {
    return apiClient.delete('/loads/$loadId/items/$itemId');
  }

  static Future<void> completaCarico(int loadId) {
    return apiClient.post('/loads/$loadId/completa');
  }

  // ---- Storico ----

  static Future<List<HistoryEntry>> getStorico({String? da, String? a, int? userId}) async {
    final query = <String, String>{};
    if (da != null) query['da'] = da;
    if (a != null) query['a'] = a;
    if (userId != null) query['user_id'] = userId.toString();
    final data = await apiClient.get('/history', query: query);
    return (data as List).map((e) => HistoryEntry.fromJson(e)).toList();
  }

  static Future<void> cancellaStorico({String? da, String? a, int? userId, bool tutto = false}) async {
    final query = <String, String>{};
    if (da != null) query['da'] = da;
    if (a != null) query['a'] = a;
    if (userId != null) query['user_id'] = userId.toString();
    if (tutto) query['tutto'] = 'true';
    await apiClient.delete('/history', query: query);
  }

  // ---- Soci ----

  static Future<List<Socio>> getSoci() async {
    final data = await apiClient.get('/users');
    return (data as List).map((e) => Socio.fromJson(e)).toList();
  }

  static Future<void> aggiornaProfilo({
    String? nome,
    String? email,
    String? password,
  }) {
    final body = <String, dynamic>{};
    if (nome != null) body['nome'] = nome;
    if (email != null) body['email'] = email;
    if (password != null && password.isNotEmpty) body['password'] = password;
    return apiClient.put('/auth/me', body: body);
  }

  static Future<List<Map<String, dynamic>>> getAttivita() async {
    final data = await apiClient.get('/users/activity');
    return (data as List).cast<Map<String, dynamic>>();
  }

  static Future<Socio> creaSocio({
    required String nome,
    required String email,
    required String password,
    String colore = '#3B82F6',
    bool isAdmin = false,
  }) async {
    final data = await apiClient.post('/users', body: {
      'nome': nome,
      'email': email,
      'password': password,
      'colore': colore,
      'isAdmin': isAdmin,
    });
    return Socio.fromJson(data as Map<String, dynamic>);
  }

  static Future<Socio> modificaSocio(
    int id, {
    String? nome,
    String? email,
    String? password,
    String? colore,
    bool? isAdmin,
  }) async {
    final body = <String, dynamic>{};
    if (nome != null) body['nome'] = nome;
    if (email != null) body['email'] = email;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (colore != null) body['colore'] = colore;
    if (isAdmin != null) body['isAdmin'] = isAdmin;
    final data = await apiClient.put('/users/$id', body: body);
    return Socio.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> eliminaSocio(int id) {
    return apiClient.delete('/users/$id');
  }

  // ---- Assistente AI ----

  static Future<Map<String, dynamic>> chiediAssistente(String messaggio) async {
    final data = await apiClient.post('/assistant/message', body: {'message': messaggio});
    return data as Map<String, dynamic>;
  }
}
