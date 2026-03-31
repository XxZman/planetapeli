import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/api_service.dart';

class MoviesProvider extends ChangeNotifier {
  final ApiService _api;

  MoviesProvider(this._api);

  final Map<String, List<Movie>> _byGenero = {};
  List<Movie> _tendencias = [];
  List<Movie> _destacadas = [];
  List<Movie> _recentlyAdded = [];
  List<Movie> _searchResults = [];
  bool _loadingHome = false;
  bool _loadingSearch = false;
  String? _error;

  Map<String, List<Movie>> get byGenero => _byGenero;
  List<Movie> get tendencias => _tendencias;
  List<Movie> get destacadas => _destacadas;
  List<Movie> get recentlyAdded => _recentlyAdded;
  List<Movie> get searchResults => _searchResults;
  bool get loadingHome => _loadingHome;
  bool get loadingSearch => _loadingSearch;
  String? get error => _error;

  Future<void> loadHome() async {
    if (_loadingHome) return;
    _loadingHome = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getPeliculas(tendencia: true),
        _api.getPeliculas(destacada: true),
        _api.getPeliculas(), // all movies
      ]);

      _tendencias = results[0];
      _destacadas = results[1];
      final allMovies = results[2];

      // Group all movies by their genre array
      _byGenero.clear();
      for (final movie in allMovies) {
        for (final genero in movie.generos) {
          final key = genero.toLowerCase().trim();
          if (key.isNotEmpty) {
            _byGenero.putIfAbsent(key, () => []).add(movie);
          }
        }
      }

      // Recently added: sorted by fechaAgregada descending, top 20
      _recentlyAdded = [...allMovies];
      _recentlyAdded.sort((a, b) {
        final dateA = DateTime.tryParse(a.fechaAgregada) ?? DateTime(0);
        final dateB = DateTime.tryParse(b.fechaAgregada) ?? DateTime(0);
        return dateB.compareTo(dateA);
      });
      if (_recentlyAdded.length > 20) {
        _recentlyAdded = _recentlyAdded.sublist(0, 20);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingHome = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _loadingSearch = true;
    notifyListeners();
    try {
      _searchResults = await _api.getPeliculas(buscar: query);
    } catch (_) {
      _searchResults = [];
    } finally {
      _loadingSearch = false;
      notifyListeners();
    }
  }

  Future<Movie?> getDetalle(String id) async {
    try {
      return await _api.getPelicula(id);
    } catch (_) {
      return null;
    }
  }

  List<Movie> get allMovies {
    final all = <Movie>[];
    all.addAll(_tendencias);
    for (final list in _byGenero.values) {
      all.addAll(list);
    }
    return all.toSet().toList();
  }
}
