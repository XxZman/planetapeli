import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/movie.dart';
import '../providers/movies_provider.dart';
import '../providers/favorites_provider.dart';
import 'player_screen.dart';

const _purple = Color(0xFF7B2FBE);
const _blue = Color(0xFF2F86BE);

class SeriesDetailScreen extends StatefulWidget {
  final String movieId;
  final Movie? movie;

  const SeriesDetailScreen({super.key, required this.movieId, this.movie});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  Movie? _movie;
  bool _loading = false;
  int _selectedTemporada = 0;

  @override
  void initState() {
    super.initState();
    if (widget.movie != null) _movie = widget.movie;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    final detail = await context.read<MoviesProvider>().getDetalle(widget.movieId);
    if (mounted) {
      setState(() {
        if (detail != null) _movie = detail;
        _loading = false;
      });
    }
  }

  void _playEpisodio(Episodio ep) {
    final movie = _movie;
    if (movie == null) return;

    if (ep.servidores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay servidores disponibles para este episodio'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final episodioMovie = movie.copyWith(
      titulo: '${movie.titulo} · ${ep.titulo}',
      descripcion: ep.descripcion,
      poster: ep.imagen.isNotEmpty ? ep.imagen : null,
      backdrop: ep.imagen.isNotEmpty ? ep.imagen : null,
      servidores: ep.servidores,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(movie: episodioMovie)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = _movie;
    final favorites = context.watch<FavoritesProvider>();
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text('Serie no encontrada', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final isFav = favorites.isFavorite(movie.id);
    final temporadas = movie.temporadas;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // ── Backdrop ────────────────────────────────────────────────────────
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
                      errorWidget: (_, __, ___) =>
                          Container(color: const Color(0xFF1a1a1a)),
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

          // ── Contenido ───────────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isTV ? 48 : 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // Título
                Text(
                  movie.titulo,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTV ? 36 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Metadata
                Row(
                  children: [
                    if (movie.anio != null) ...[
                      Text('${movie.anio}',
                          style: const TextStyle(color: Colors.grey)),
                      const Text('  •  ',
                          style: TextStyle(color: Colors.grey)),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: _purple),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SERIE',
                        style: TextStyle(
                          color: _purple,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (movie.rating > 0) ...[
                      const Text('  •  ',
                          style: TextStyle(color: Colors.grey)),
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        movie.rating.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.amber),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Géneros
                if (movie.generos.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: movie.generos
                        .map((g) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: _purple.withOpacity(0.6)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(g,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 16),

                // Botón Mi Lista
                SizedBox(
                  width: double.infinity,
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Descripción
                if (movie.descripcion.isNotEmpty) ...[
                  const Text(
                    'Descripción',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.descripcion,
                    style: const TextStyle(
                        color: Color(0xFFcccccc), height: 1.5),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── TEMPORADAS ───────────────────────────────────────────────
                if (temporadas.isEmpty) ...[
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: _purple),
                      ),
                    )
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No hay temporadas disponibles aún.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                ] else ...[
                  Row(
                    children: [
                      const Text(
                        'Temporadas',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${temporadas.length} temp · ${temporadas.fold(0, (s, t) => s + t.episodios.length)} ep',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Selector de temporadas (chips horizontales)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: temporadas.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final selected = _selectedTemporada == i;
                        final t = temporadas[i];
                        final label = t.nombre.isNotEmpty
                            ? t.nombre
                            : 'Temporada ${t.numero}';
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedTemporada = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? const LinearGradient(
                                      colors: [_purple, _blue])
                                  : null,
                              color: selected
                                  ? null
                                  : const Color(0xFF2a2a2a),
                              borderRadius: BorderRadius.circular(20),
                              border: selected
                                  ? null
                                  : Border.all(
                                      color:
                                          Colors.grey.withOpacity(0.3)),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Episodios de la temporada seleccionada
                  if (temporadas[_selectedTemporada].episodios.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Sin episodios en esta temporada.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...temporadas[_selectedTemporada]
                        .episodios
                        .map((ep) => _EpisodioCard(
                              episodio: ep,
                              onPlay: () => _playEpisodio(ep),
                            )),
                ],

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de episodio ────────────────────────────────────────────────────────

class _EpisodioCard extends StatelessWidget {
  final Episodio episodio;
  final VoidCallback onPlay;

  const _EpisodioCard({required this.episodio, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPlay,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Miniatura del episodio
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: episodio.imagen.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: episodio.imagen,
                        width: 120,
                        height: 68,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _Thumbnail(episodio.numero),
                      )
                    : _Thumbnail(episodio.numero),
              ),
              const SizedBox(width: 12),

              // Info del episodio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${episodio.numero}. ',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                        Expanded(
                          child: Text(
                            episodio.titulo,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (episodio.descripcion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        episodio.descripcion,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          episodio.servidores.isEmpty
                              ? 'Sin servidores'
                              : '${episodio.servidores.length} servidor(es)',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                        ),
                        const Spacer(),
                        // Botón reproducir
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: episodio.servidores.isEmpty
                                ? null
                                : const LinearGradient(
                                    colors: [_purple, _blue]),
                            color: episodio.servidores.isEmpty
                                ? const Color(0xFF333333)
                                : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow,
                                color: episodio.servidores.isEmpty
                                    ? Colors.grey
                                    : Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Ver',
                                style: TextStyle(
                                  color: episodio.servidores.isEmpty
                                      ? Colors.grey
                                      : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final int numero;
  const _Thumbnail(this.numero);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 68,
      decoration: const BoxDecoration(color: Color(0xFF2a2a2a)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_outline, color: Colors.grey, size: 24),
          const SizedBox(height: 4),
          Text(
            'Ep. $numero',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
