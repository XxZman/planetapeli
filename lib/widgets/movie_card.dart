import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';

const _purple = Color(0xFF7B2FBE);
const _blue = Color(0xFF2F86BE);

class MovieCard extends StatelessWidget {
  final Movie movie;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final double? progress;

  const MovieCard({
    super.key,
    required this.movie,
    this.width = 120,
    this.height = 180,
    this.onTap,
    this.progress,
  });

  void _showQuickInfo(BuildContext context, Offset position) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final renderBox = context.findRenderObject() as RenderBox;
    final cardOffset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);

    showMenu(
      context: context,
      color: const Color(0xFF1e1e2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(cardOffset.dx, cardOffset.dy, width, height),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movie.titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (movie.anio != null) ...[
                    const Icon(Icons.calendar_today, color: Colors.grey, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${movie.anio}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Icon(Icons.star, color: Colors.amber, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    movie.rating.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (details) => _showQuickInfo(context, details.globalPosition),
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a1a),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _purple.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              movie.poster.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: movie.poster,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const _Placeholder(),
                      errorWidget: (_, __, ___) => _FallbackCard(titulo: movie.titulo),
                    )
                  : _FallbackCard(titulo: movie.titulo),
              if (progress != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(_purple),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1a1a1a),
      child: const Center(
        child: CircularProgressIndicator(color: _purple, strokeWidth: 2),
      ),
    );
  }
}

class _FallbackCard extends StatelessWidget {
  final String titulo;
  const _FallbackCard({required this.titulo});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF2a1a3e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_purple, _blue],
            ).createShader(bounds),
            child: const Icon(Icons.movie, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              titulo,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
