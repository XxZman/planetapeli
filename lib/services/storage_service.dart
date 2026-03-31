import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';

class StorageService {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _favoritesKey = 'favorites';
  static const _historialKey = 'historial';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_userKey);
    if (str == null) return null;
    return jsonDecode(str);
  }

  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // Favorites
  Future<List<Movie>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_favoritesKey) ?? '[]';
    final List data = jsonDecode(str);
    return data.map((e) => Movie.fromJson(e)).toList();
  }

  Future<void> saveFavorites(List<Movie> movies) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoritesKey, jsonEncode(movies.map((m) => m.toJson()).toList()));
  }

  // History
  Future<List<Map<String, dynamic>>> getHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_historialKey) ?? '[]';
    final List data = jsonDecode(str);
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> saveHistorial(List<Map<String, dynamic>> historial) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historialKey, jsonEncode(historial));
  }
}
