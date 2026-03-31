import 'dart:convert';
import 'package:http/http.dart' as http;

class VersionInfo {
  final String version;
  final String url;
  final String novedades;
  final bool obligatoria;

  VersionInfo({
    required this.version,
    required this.url,
    required this.novedades,
    required this.obligatoria,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) => VersionInfo(
        version: json['version']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        novedades: json['novedades']?.toString() ?? '',
        obligatoria: json['obligatoria'] == true,
      );
}

class VersionService {
  // Debe coincidir con la version en pubspec.yaml (sin el build number)
  static const String currentVersion = '1.0.0';
  static const String _baseUrl =
      'https://streamflix-backend-production-8c61.up.railway.app';

  Future<VersionInfo?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/version'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final info = VersionInfo.fromJson(data);
        if (info.url.isNotEmpty && _isNewer(info.version, currentVersion)) {
          return info;
        }
      }
    } catch (_) {
      // Error de red — se ignora para no bloquear el inicio
    }
    return null;
  }

  bool _isNewer(String remote, String current) {
    List<int> parse(String v) =>
        v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final r = parse(remote);
    final c = parse(current);
    for (int i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv > cv) return true;
      if (rv < cv) return false;
    }
    return false;
  }
}
