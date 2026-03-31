import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/history_provider.dart';
import 'auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final favorites = context.watch<FavoritesProvider>();
    final history = context.watch<HistoryProvider>();

    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, color: Colors.grey, size: 80),
              const SizedBox(height: 16),
              const Text('Inicia sesión para ver tu perfil',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Iniciar sesión', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final user = auth.user!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          // Avatar header
          Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.red,
                  child: Text(
                    user.nombre.isNotEmpty ? user.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user.nombre,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF333333)),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(label: 'En mi lista', value: '${favorites.favorites.length}'),
                _Stat(label: 'Vistos', value: '${history.history.length}'),
              ],
            ),
          ),

          const Divider(color: Color(0xFF333333)),

          // Menu items
          _MenuItem(
            icon: Icons.bookmark_border,
            label: 'Mi Lista',
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.history,
            label: 'Historial',
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.settings,
            label: 'Configuración',
            onTap: () {},
          ),

          const Divider(color: Color(0xFF333333)),

          _MenuItem(
            icon: Icons.logout,
            label: 'Cerrar sesión',
            color: Colors.red,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1a1a1a),
                  title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
                  content: const Text('¿Estás seguro que quieres cerrar sesión?',
                      style: TextStyle(color: Colors.grey)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Salir', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.read<AuthProvider>().logout();
              }
            },
          ),

          const SizedBox(height: 32),
          const Center(
            child: Text(
              'PlanetaPeli v1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _MenuItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(label, style: TextStyle(color: c)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
