class User {
  final String id;
  final String nombre;
  final String email;

  User({required this.id, required this.nombre, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
    );
  }
}
