import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/movies_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/history_provider.dart';
import '../models/movie.dart';
import '../widgets/hero_banner.dart';
import '../widgets/movie_row.dart';
import 'movie_detail_screen.dart';
import 'search_screen.dart';
import 'my_list_screen.dart';
import 'profile_screen.dart';

const _purple = Color(0xFF7B2FBE);
const _blue = Color(0xFF2F86BE);

// ── Helpers (top-level) ────────────────────────────────────────────────────────

const Map<String, String> _generoLabels = {
  'accion': 'Acción',
  'terror': 'Terror',
  'comedia': 'Comedia',
  'drama': 'Drama',
  'romance': 'Romance',
  'ciencia ficcion': 'Ciencia Ficción',
  'animacion': 'Animación',
  'thriller': 'Thriller',
  'aventura': 'Aventura',
  'fantasia': 'Fantasía',
};

String _genreLabel(String key) => _generoLabels[key] ?? key;

int _parseDurationSecs(String? duracion) {
  if (duracion == null || duracion.isEmpty) return 7200;
  final secs = int.tryParse(duracion);
  if (secs != null && secs > 60) return secs;
  final minMatch =
      RegExp(r'(\d+)\s*min', caseSensitive: false).firstMatch(duracion);
  if (minMatch != null) return int.parse(minMatch.group(1)!) * 60;
  final hMatch =
      RegExp(r'(\d+)\s*h', caseSensitive: false).firstMatch(duracion);
  final mMatch =
      RegExp(r'(\d+)\s*m(?!in)', caseSensitive: false).firstMatch(duracion);
  if (hMatch != null) {
    final hours = int.parse(hMatch.group(1)!);
    final mins = mMatch != null ? int.parse(mMatch.group(1)!) : 0;
    return hours * 3600 + mins * 60;
  }
  return 7200;
}

Map<String, double> _buildProgressMap(List<HistoryItem> history) {
  final map = <String, double>{};
  for (final item in history) {
    final total = _parseDurationSecs(item.movie.duracion);
    if (total > 0) {
      map[item.movie.id] =
          (item.position.inSeconds / total).clamp(0.0, 1.0);
    }
  }
  return map;
}

// ── HomeScreen ─────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MoviesProvider>().loadHome();
      context.read<FavoritesProvider>().init();
      context.read<HistoryProvider>().init();
    });
  }

  void _openDetail(BuildContext context, Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => MovieDetailScreen(movieId: movie.id, movie: movie)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(onMovieTap: _openDetail),
      const SearchScreen(),
      const MyListScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _BlurNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Bottom nav bar ─────────────────────────────────────────────────────────────

class _BlurNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BlurNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            border: const Border(top: BorderSide(color: Color(0xFF2a2a2a))),
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTap,
            backgroundColor: Colors.transparent,
            selectedItemColor: _purple,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.search), label: 'Buscar'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.bookmark), label: 'Mi Lista'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person), label: 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── TabBar sticky delegate ─────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(color: Colors.black, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => tabBar != old.tabBar;
}

// ── HomePage with Películas / Series tabs ─────────────────────────────────────

class _HomePage extends StatefulWidget {
  final void Function(BuildContext, Movie) onMovieTap;
  const _HomePage({required this.onMovieTap});

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MoviesProvider>();

    if (prov.loadingHome) {
      return const Center(child: CircularProgressIndicator(color: _purple));
    }

    if (prov.error != null &&
        prov.tendencias.isEmpty &&
        prov.byGenero.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: _purple, size: 64),
            const SizedBox(height: 16),
            Text(prov.error!,
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, _blue]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                onPressed: () => context.read<MoviesProvider>().loadHome(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      );
    }

    final tabBar = TabBar(
      controller: _tabCtrl,
      indicatorColor: _purple,
      indicatorWeight: 3,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.grey,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      tabs: const [
        Tab(text: 'Películas'),
        Tab(text: 'Series'),
      ],
    );

    return NestedScrollView(
      headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
        // AppBar con logo real
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: Colors.black,
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/logo.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_purple, _blue],
                ).createShader(bounds),
                child: const Text(
                  'PLANETAPELI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Consumer<AuthProvider>(
              builder: (_, auth, __) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    auth.user?.nombre ?? '',
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
        // TabBar pegada debajo del AppBar
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(tabBar),
        ),
      ],
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ContentTab(tipo: 'pelicula', onMovieTap: widget.onMovieTap),
          _ContentTab(tipo: 'serie', onMovieTap: widget.onMovieTap),
        ],
      ),
    );
  }
}

// ── Content tab (Películas o Series) ──────────────────────────────────────────

class _ContentTab extends StatelessWidget {
  final String tipo;
  final void Function(BuildContext, Movie) onMovieTap;

  const _ContentTab({required this.tipo, required this.onMovieTap});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MoviesProvider>();
    final histProv = context.watch<HistoryProvider>();

    // Filtrar todo por tipo
    final tendencias =
        prov.tendencias.where((m) => m.tipo == tipo).toList();
    final destacadas =
        prov.destacadas.where((m) => m.tipo == tipo).toList();
    final recentlyAdded =
        prov.recentlyAdded.where((m) => m.tipo == tipo).toList();
    final byGenero = Map.fromEntries(
      prov.byGenero.entries
          .map((e) => MapEntry(
              e.key, e.value.where((m) => m.tipo == tipo).toList()))
          .where((e) => e.value.isNotEmpty),
    );

    final heroMovies =
        tendencias.isNotEmpty ? tendencias : destacadas;
    final histFiltered =
        histProv.history.where((h) => h.movie.tipo == tipo).toList();
    final progressMap = _buildProgressMap(histFiltered);

    final sortedGenreEntries = byGenero.entries.toList()
      ..sort((a, b) => _genreLabel(a.key).compareTo(_genreLabel(b.key)));

    if (heroMovies.isEmpty &&
        recentlyAdded.isEmpty &&
        byGenero.isEmpty) {
      return Center(
        child: Text(
          tipo == 'pelicula'
              ? 'No hay películas disponibles'
              : 'No hay series disponibles',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return CustomScrollView(
      key: PageStorageKey<String>(tipo),
      slivers: [
        if (heroMovies.isNotEmpty)
          SliverToBoxAdapter(
            child: HeroBanner(
              movies: heroMovies,
              onPlay: (m) => onMovieTap(context, m),
              onInfo: (m) => onMovieTap(context, m),
            ),
          ),

        if (recentlyAdded.isNotEmpty)
          SliverToBoxAdapter(
            child: MovieRow(
              titulo: tipo == 'pelicula'
                  ? 'Películas recientes'
                  : 'Series recientes',
              movies: recentlyAdded,
              onTap: (m) => onMovieTap(context, m),
            ),
          ),

        if (histFiltered.isNotEmpty)
          SliverToBoxAdapter(
            child: MovieRow(
              titulo: 'Continuar viendo',
              movies: histFiltered.map((h) => h.movie).toList(),
              onTap: (m) => onMovieTap(context, m),
              progressMap: progressMap,
            ),
          ),

        if (tendencias.isNotEmpty)
          SliverToBoxAdapter(
            child: MovieRow(
              titulo: 'Tendencias',
              movies: tendencias,
              onTap: (m) => onMovieTap(context, m),
            ),
          ),

        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final entry = sortedGenreEntries[i];
              return MovieRow(
                titulo: _genreLabel(entry.key),
                movies: entry.value,
                onTap: (m) => onMovieTap(context, m),
              );
            },
            childCount: sortedGenreEntries.length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}
