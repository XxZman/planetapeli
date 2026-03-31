import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';

const _kPurple = Color(0xFF7B2FBE);
const _kBlue = Color(0xFF2F86BE);

class HeroBanner extends StatefulWidget {
  final List<Movie> movies;
  final void Function(Movie) onPlay;
  final void Function(Movie) onInfo;

  const HeroBanner({
    super.key,
    required this.movies,
    required this.onPlay,
    required this.onInfo,
  });

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.movies.length > 1) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.movies.isEmpty) return;
      final next = (_currentIndex + 1) % widget.movies.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final bannerH = size.width > 900 ? size.height * 0.6 : size.height * 0.5;

    return SizedBox(
      height: bannerH,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemCount: widget.movies.length,
            itemBuilder: (_, i) {
              final movie = widget.movies[i];
              return _BannerPage(
                movie: movie,
                onPlay: () => widget.onPlay(movie),
                onInfo: () => widget.onInfo(movie),
              );
            },
          ),
          // Dot indicators
          if (widget.movies.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.movies.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _currentIndex == i ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: _currentIndex == i ? _kPurple : Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerPage extends StatelessWidget {
  final Movie movie;
  final VoidCallback onPlay;
  final VoidCallback onInfo;

  const _BannerPage({
    required this.movie,
    required this.onPlay,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
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

        // Bottom gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0x99000000), Colors.black],
              stops: [0.4, 0.7, 1.0],
            ),
          ),
        ),

        // Left gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.black, Colors.transparent],
              stops: [0.0, 0.5],
            ),
          ),
        ),

        // Content
        Positioned(
          bottom: 48,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movie.titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
              const SizedBox(height: 8),
              if (movie.generos.isNotEmpty)
                Text(
                  movie.generos.take(3).join(' • '),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _BannerButton(
                    icon: Icons.play_arrow,
                    label: 'Reproducir',
                    onTap: onPlay,
                    filled: true,
                  ),
                  const SizedBox(width: 12),
                  _BannerButton(
                    icon: Icons.info_outline,
                    label: 'Más info',
                    onTap: onInfo,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BannerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _BannerButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: filled
              ? const LinearGradient(colors: [_kPurple, _kBlue])
              : null,
          color: filled ? null : Colors.white24,
          borderRadius: BorderRadius.circular(10),
          boxShadow: filled
              ? [BoxShadow(color: _kPurple.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
