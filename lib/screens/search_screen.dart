import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/movies_provider.dart';
import '../models/movie.dart';
import '../widgets/movie_card.dart';
import 'movie_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<MoviesProvider>().search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final moviesProvider = context.watch<MoviesProvider>();
    final isTV = MediaQuery.of(context).size.width > 900;
    final crossCount = isTV ? 6 : 3;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _ctrl,
                onChanged: _onChanged,
                autofocus: false,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar películas...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _ctrl.clear();
                            context.read<MoviesProvider>().search('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF333333),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: moviesProvider.loadingSearch
                  ? const Center(child: CircularProgressIndicator(color: Colors.red))
                  : moviesProvider.searchResults.isEmpty && _ctrl.text.isNotEmpty
                      ? const Center(
                          child: Text('No se encontraron resultados',
                              style: TextStyle(color: Colors.grey)),
                        )
                      : moviesProvider.searchResults.isEmpty
                          ? _BrowseAll(isTV: isTV, crossCount: crossCount)
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossCount,
                                childAspectRatio: 0.67,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: moviesProvider.searchResults.length,
                              itemBuilder: (_, i) {
                                final movie = moviesProvider.searchResults[i];
                                return MovieCard(
                                  movie: movie,
                                  width: double.infinity,
                                  height: double.infinity,
                                  onTap: () => _openDetail(context, movie),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => MovieDetailScreen(movieId: movie.id, movie: movie)),
    );
  }
}

class _BrowseAll extends StatelessWidget {
  final bool isTV;
  final int crossCount;
  const _BrowseAll({required this.isTV, required this.crossCount});

  @override
  Widget build(BuildContext context) {
    final movies = context.watch<MoviesProvider>().allMovies;
    if (movies.isEmpty) {
      return const Center(
        child: Text('Busca tus películas favoritas',
            style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        childAspectRatio: 0.67,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: movies.length,
      itemBuilder: (_, i) {
        final movie = movies[i];
        return MovieCard(
          movie: movie,
          width: double.infinity,
          height: double.infinity,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => MovieDetailScreen(movieId: movie.id, movie: movie)),
          ),
        );
      },
    );
  }
}
