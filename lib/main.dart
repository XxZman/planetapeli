import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/version_service.dart';
import 'providers/auth_provider.dart';
import 'providers/movies_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/history_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';

const kPurple = Color(0xFF7B2FBE);
const kBlue = Color(0xFF2F86BE);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  final api = ApiService();

  final token = await storage.getToken();
  if (token != null) api.setToken(token);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: api),
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider(create: (_) => AuthProvider(api, storage)),
        ChangeNotifierProvider(create: (_) => MoviesProvider(api)),
        ChangeNotifierProvider(create: (_) => FavoritesProvider(storage)),
        ChangeNotifierProvider(create: (_) => HistoryProvider(storage)),
      ],
      child: const PlanetaPeliApp(),
    ),
  );
}

class PlanetaPeliApp extends StatefulWidget {
  const PlanetaPeliApp({super.key});

  @override
  State<PlanetaPeliApp> createState() => _PlanetaPeliAppState();
}

class _PlanetaPeliAppState extends State<PlanetaPeliApp> {
  bool _ready = false;
  bool _loggedIn = false;
  VersionInfo? _pendingUpdate;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    final results = await Future.wait([
      auth.init(),
      VersionService().checkForUpdate(),
    ]);
    final update = results[1] as VersionInfo?;
    setState(() {
      _ready = true;
      _loggedIn = auth.isLoggedIn;
      _pendingUpdate = update;
    });
    if (update != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showUpdateDialog(update);
      });
    }
  }

  void _showUpdateDialog(VersionInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(info: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlanetaPeli',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: kPurple,
          secondary: kBlue,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          selectedItemColor: kPurple,
          unselectedItemColor: Colors.grey,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: kPurple),
      ),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/login': (_) => const LoginScreen(),
      },
      home: !_ready
          ? const _SplashScreen()
          : _loggedIn
              ? const HomeScreen()
              : const LoginScreen(),
    );
  }
}

class _UpdateDialog extends StatelessWidget {
  final VersionInfo info;
  const _UpdateDialog({required this.info});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !info.obligatoria,
      child: AlertDialog(
        backgroundColor: const Color(0xFF242424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: kPurple),
            const SizedBox(width: 10),
            Text('Nueva versión v${info.version}',
                style: const TextStyle(color: Colors.white, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.obligatoria)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Actualización obligatoria',
                          style: TextStyle(color: Colors.orange, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            const Text('Novedades:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                    fontSize: 13)),
            const SizedBox(height: 6),
            Text(info.novedades,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        actions: [
          if (!info.obligatoria)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ahora no',
                  style: TextStyle(color: Colors.grey)),
            ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Actualizar'),
            style: ElevatedButton.styleFrom(backgroundColor: kPurple),
            onPressed: () async {
              final uri = Uri.parse(info.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              if (!info.obligatoria && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo de la app
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kPurple.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'PLANETAPELI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [kPurple, kBlue],
                ).createShader(bounds),
                child: const Text(
                  'Tu universo de películas',
                  style: TextStyle(color: Colors.white, fontSize: 13, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: kPurple),
            ],
          ),
        ),
      ),
    );
  }
}
