// Modifica questo indirizzo con quello del tuo server.
// - In sviluppo locale su emulatore Android: usa 10.0.2.2 al posto di localhost.
// - In produzione: usa il dominio/IP pubblico del tuo server (es. https://bevande.tuodominio.it).
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.178.29:3000/api',
  );
}
