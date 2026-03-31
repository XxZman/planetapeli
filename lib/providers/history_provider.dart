import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/storage_service.dart';

class HistoryItem {
  final Movie movie;
  final Duration position;
  final DateTime watchedAt;

  HistoryItem({
    required this.movie,
    required this.position,
    required this.watchedAt,
  });
}

class HistoryProvider extends ChangeNotifier {
  final StorageService _storage;
  List<HistoryItem> _history = [];

  HistoryProvider(this._storage);

  List<HistoryItem> get history => _history;

  Future<void> init() async {
    final data = await _storage.getHistorial();
    _history = data.map((e) {
      return HistoryItem(
        movie: Movie.fromJson(e['movie']),
        position: Duration(seconds: e['position'] ?? 0),
        watchedAt: DateTime.tryParse(e['watchedAt'] ?? '') ?? DateTime.now(),
      );
    }).toList();
    notifyListeners();
  }

  Future<void> addOrUpdate(Movie movie, Duration position) async {
    _history.removeWhere((h) => h.movie.id == movie.id);
    _history.insert(0, HistoryItem(
      movie: movie,
      position: position,
      watchedAt: DateTime.now(),
    ));
    // Keep last 50
    if (_history.length > 50) _history = _history.sublist(0, 50);
    await _save();
    notifyListeners();
  }

  Duration? getPosition(String movieId) {
    try {
      return _history.firstWhere((h) => h.movie.id == movieId).position;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final data = _history.map((h) => {
      'movie': h.movie.toJson(),
      'position': h.position.inSeconds,
      'watchedAt': h.watchedAt.toIso8601String(),
    }).toList();
    await _storage.saveHistorial(data);
  }
}
