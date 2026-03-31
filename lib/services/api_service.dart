import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';
import '../models/user.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class AuthResult {
  final String token;
  final User user;
  AuthResult({required this.token, required this.user});
}

class ApiService {
  static const String baseUrl =
      'https://streamflix-backend-production-8c61.up.railway.app';

  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<List<Movie>> getPeliculas({
    String? genero,
    bool? tendencia,
    bool? destacada,
    String? buscar,
  }) async {
    final params = <String, String>{};
    if (genero != null) params['genero'] = genero;
    if (tendencia == true) params['tendencia'] = 'true';
    if (destacada == true) params['destacada'] = 'true';
    if (buscar != null && buscar.isNotEmpty) params['buscar'] = buscar;

    final uri = Uri.parse('$baseUrl/api/peliculas').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Movie.fromJson(e)).toList();
    }
    throw ApiException('Error cargando películas');
  }

  Future<Movie> getPelicula(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/peliculas/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return Movie.fromJson(jsonDecode(response.body));
    }
    throw ApiException('Película no encontrada');
  }

  Future<List<String>> getCategorias() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/categorias'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<AuthResult> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/usuarios/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(response.body);
    if (body['error'] != null) throw ApiException(body['error']);
    if (body['token'] == null) throw ApiException('Credenciales incorrectas');
    return AuthResult(
      token: body['token'],
      user: User.fromJson(body['usuario']),
    );
  }

  Future<void> solicitar({
    required String peliculaId,
    required String peliculaTitulo,
    String? mensaje,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/solicitudes'),
      headers: _headers,
      body: jsonEncode({
        'peliculaId': peliculaId,
        'peliculaTitulo': peliculaTitulo,
        if (mensaje != null && mensaje.isNotEmpty) 'mensaje': mensaje,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw ApiException(body['error'] ?? 'Error al enviar solicitud');
    }
  }

  Future<List<Temporada>> getTemporadas(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/peliculas/$id/temporadas'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((t) => Temporada.fromJson(t as Map<String, dynamic>)).toList();
    }
    throw ApiException('Error cargando temporadas');
  }

  Future<List<Episodio>> getEpisodios(String id, int num) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/peliculas/$id/temporadas/$num/episodios'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Episodio.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException('Error cargando episodios');
  }

  Future<AuthResult> registro(String nombre, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/usuarios/registro'),
      headers: _headers,
      body: jsonEncode({'nombre': nombre, 'email': email, 'password': password}),
    );
    final body = jsonDecode(response.body);
    if (body['error'] != null) throw ApiException(body['error']);
    if (body['token'] == null) throw ApiException('Error en el registro');
    return AuthResult(
      token: body['token'],
      user: User.fromJson(body['usuario']),
    );
  }
}
