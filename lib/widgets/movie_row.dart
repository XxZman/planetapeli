import 'package:flutter/material.dart';
import '../models/movie.dart';
import 'movie_card.dart';

class MovieRow extends StatelessWidget {
  final String titulo;
  final List<Movie> movies;
  final void Function(Movie) onTap;
  // Optional: map of movieId -> progress (0.0-1.0) for "Continuar viendo"
  final Map<String, double>? progressMap;

  const MovieRow({
    super.key,
    required this.titulo,
    required this.movies,
    required this.onTap,
    this.progressMap,
  });

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    final isTV = MediaQuery.of(context).size.width > 900;
    final cardW = isTV ? 180.0 : 120.0;
    final cardH = isTV ? 270.0 : 180.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: cardH,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: movies.length,
            itemBuilder: (_, i) {
              final movie = movies[i];
              return MovieCard(
                movie: movie,
                width: cardW,
                height: cardH,
                onTap: () => onTap(movie),
                progress: progressMap?[movie.id],
              );
            },
          ),
        ),
      ],
    );
  }
}
