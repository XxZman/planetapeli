import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/movie_card.dart';
import 'movie_detail_screen.dart';

class MyListScreen extends StatelessWidget {
  const MyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final history = context.watch<HistoryProvider>();
    final isTV = MediaQuery.of(context).size.width > 900;
    final crossCount = isTV ? 5 : 3;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Mi Lista', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.red,
              tabs: [
                Tab(text: 'Guardados'),
                Tab(text: 'Continuar viendo'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Favorites
                  favorites.favorites.isEmpty
                      ? const _Empty(
                          icon: Icons.bookmark_border,
                          message: 'Aún no tienes películas en tu lista',
                          sub: 'Toca el ícono de marcador en cualquier película',
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossCount,
                            childAspectRatio: 0.67,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: favorites.favorites.length,
                          itemBuilder: (_, i) {
                            final movie = favorites.favorites[i];
                            return Stack(
                              children: [
                                MovieCard(
                                  movie: movie,
                                  width: double.infinity,
                                  height: double.infinity,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MovieDetailScreen(movieId: movie.id, movie: movie),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => favorites.toggle(movie),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                  // History
                  history.history.isEmpty
                      ? const _Empty(
                          icon: Icons.history,
                          message: 'No hay historial de reproducción',
                          sub: 'Las películas que veas aparecerán aquí',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: history.history.length,
                          itemBuilder: (_, i) {
                            final item = history.history[i];
                            final pct = item.movie.duracion != null
                                ? (item.position.inSeconds / (int.tryParse(item.movie.duracion ?? '0') ?? 1)).clamp(0.0, 1.0)
                                : 0.0;
                            return Card(
                              color: const Color(0xFF1a1a1a),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: SizedBox(
                                    width: 60,
                                    height: 80,
                                    child: MovieCard(movie: item.movie, width: 60, height: 80),
                                  ),
                                ),
                                title: Text(
                                  item.movie.titulo,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatDuration(item.position),
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: pct,
                                      backgroundColor: Colors.grey.shade800,
                                      valueColor: const AlwaysStoppedAnimation(Colors.red),
                                    ),
                                  ],
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MovieDetailScreen(
                                      movieId: item.movie.id,
                                      movie: item.movie,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m visto';
    if (m > 0) return '${m}m ${s}s visto';
    return '${s}s visto';
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;
  const _Empty({required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey, size: 64),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
