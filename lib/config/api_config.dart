// Modifica questo indirizzo con quello del tuo server.
// - In sviluppo locale su emulatore Android: usa http://10.0.2.2:3000/api
// - In sviluppo locale su web/desktop: usa http://localhost:3000/api
// - In produzione: usa il dominio pubblico del server + /api
// Le rotte del backend sono tutte sotto /api (vedi backend/src/index.ts),
// quindi baseUrl deve terminare con /api e SENZA slash finale.
class ApiConfig {
  static const String baseUrl = 'https://bev-api.michieletto.it/api';
}
