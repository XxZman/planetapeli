import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final StorageService _storage;

  User? _user;
  bool _loading = false;
  String? _error;

  AuthProvider(this._api, this._storage);

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  Future<void> init() async {
    final token = await _storage.getToken();
    final userData = await _storage.getUser();
    if (token != null && userData != null) {
      _api.setToken(token);
      _user = User.fromJson(userData);
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.login(email, password);
      _user = result.user;
      _api.setToken(result.token);
      await _storage.saveToken(result.token);
      await _storage.saveUser({'id': result.user.id, 'nombre': result.user.nombre, 'email': result.user.email});
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> registro(String nombre, String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.registro(nombre, email, password);
      _user = result.user;
      _api.setToken(result.token);
      await _storage.saveToken(result.token);
      await _storage.saveUser({'id': result.user.id, 'nombre': result.user.nombre, 'email': result.user.email});
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;
    _api.setToken(null);
    await _storage.clearAuth();
    notifyListeners();
  }
}
