import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/storage_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final StorageService _storage;
  List<Movie> _favorites = [];

  FavoritesProvider(this._storage);

  List<Movie> get favorites => _favorites;

  Future<void> init() async {
    _favorites = await _storage.getFavorites();
    notifyListeners();
  }

  bool isFavorite(String movieId) => _favorites.any((m) => m.id == movieId);

  Future<void> toggle(Movie movie) async {
    if (isFavorite(movie.id)) {
      _favorites.removeWhere((m) => m.id == movie.id);
    } else {
      _favorites.insert(0, movie);
    }
    await _storage.saveFavorites(_favorites);
    notifyListeners();
  }
}
