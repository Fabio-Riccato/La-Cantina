class Socio {
  final int id;
  final String nome;
  final String colore;
  final String? email;
  final bool isAdmin;

  Socio({
    required this.id,
    required this.nome,
    required this.colore,
    this.email,
    this.isAdmin = false,
  });

  factory Socio.fromJson(Map<String, dynamic> json) {
    return Socio(
      id: json['id'] as int,
      nome: json['nome'] as String,
      colore: json['colore'] as String? ?? '#3B82F6',
      email: json['email'] as String?,
      isAdmin: json['isAdmin'] as bool? ?? false,
    );
  }
}
