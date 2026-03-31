import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/movie.dart';
import '../providers/movies_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/history_provider.dart';
import '../services/api_service.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

const _purple = Color(0xFF7B2FBE);
const _blue = Color(0xFF2F86BE);

class MovieDetailScreen extends StatefulWidget {
  final String movieId;
  final Movie? movie;

  const MovieDetailScreen({super.key, required this.movieId, this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Movie? _movie;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.movie != null) {
      _movie = widget.movie;
      // Si ya sabemos que es serie, redirigir de inmediato
      if (widget.movie!.tipo == 'serie') {
        WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToSeries());
        return;
      }
    }
    _loadDetail();
  }

  void _navigateToSeries() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SeriesDetailScreen(movieId: widget.movieId, movie: _movie),
      ),
    );
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    final detail = await context.read<MoviesProvider>().getDetalle(widget.movieId);
    if (!mounted) return;
    // Si resulta ser una serie, redirigir a SeriesDetailScreen
    if (detail?.tipo == 'serie') {
      _movie = detail;
      _navigateToSeries();
      return;
    }
    setState(() {
      if (detail != null) _movie = detail;
      _loading = false;
    });
  }

  void _play(BuildContext ctx) {
    if (_movie == null) return;
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => PlayerScreen(movie: _movie!)));
  }

  Future<void> _solicitarLink(BuildContext ctx) async {
    final movie = _movie;
    if (movie == null) return;
    final mensajeCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Solicitar link 🔗', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              movie.titulo,
              style: const TextStyle(color: _purple, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mensajeCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Mensaje opcional (ej: necesito en 1080p latino)',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF2a2a2a),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_purple, _blue]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Enviar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );

    if (result != true) return;
    if (!ctx.mounted) return;

    try {
      final api = ctx.read<ApiService>();
      await api.solicitar(
        peliculaId: movie.id,
        peliculaTitulo: movie.titulo,
        mensaje: mensajeCtrl.text.trim(),
      );
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: const Text('✅ Solicitud enviada correctamente'),
            backgroundColor: _purple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final movie = _movie;
    final favorites = context.watch<FavoritesProvider>();
    final history = context.watch<HistoryProvider>();
    final isTV = MediaQuery.of(context).size.width > 900;

    if (movie == null && _loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: _purple)),
      );
    }
    if (movie == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
        body: const Center(child: Text('Película no encontrada', style: TextStyle(color: Colors.white))),
      );
    }

    final isFav = favorites.isFavorite(movie.id);
    final historyPos = history.getPosition(movie.id);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: isTV ? 400 : 280,
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (movie.backdrop.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: movie.backdrop,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: const Color(0xFF1a1a1a)),
                    )
                  else
                    Container(color: const Color(0xFF1a1a1a)),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isTV ? 48 : 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                Text(
                  movie.titulo,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTV ? 36 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (movie.anio != null) ...[
                      Text('${movie.anio}', style: const TextStyle(color: Colors.grey)),
                      const Text('  •  ', style: TextStyle(color: Colors.grey)),
                    ],
                    if (movie.duracion != null) ...[
                      Text(movie.duracion!, style: const TextStyle(color: Colors.grey)),
                      const Text('  •  ', style: TextStyle(color: Colors.grey)),
                    ],
                    _RatingBadge(rating: movie.rating),
                  ],
                ),
                const SizedBox(height: 8),
                if (movie.generos.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: movie.generos
                        .map((g) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: _purple.withOpacity(0.6)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(g, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 20),

                // Play button with gradient
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_purple, _blue]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _play(context),
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: Text(
                          historyPos != null ? 'Continuar' : 'Reproducir',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // My list + Solicitar
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => favorites.toggle(movie),
                        icon: Icon(
                          isFav ? Icons.bookmark : Icons.bookmark_border,
                          color: Colors.white,
                        ),
                        label: Text(
                          isFav ? 'En mi lista' : 'Mi lista',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _solicitarLink(context),
                        icon: const Text('🔗', style: TextStyle(fontSize: 16)),
                        label: const Text(
                          'Solicitar link',
                          style: TextStyle(color: _purple),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _purple),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const Text(
                  'Descripción',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  movie.descripcion.isNotEmpty ? movie.descripcion : 'Sin descripción disponible.',
                  style: const TextStyle(color: Color(0xFFcccccc), height: 1.5),
                ),
                const SizedBox(height: 24),

                if (movie.actores.isNotEmpty) ...[
                  const Text(
                    'Reparto',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.actores.join(', '),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                ],

                if (movie.servidores.isNotEmpty) ...[
                  Text(
                    '${movie.servidores.length} servidor(es) disponible(s)',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final double rating;
  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.star, color: Colors.amber, size: 16),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(color: Colors.amber),
        ),
      ],
    );
  }
}
