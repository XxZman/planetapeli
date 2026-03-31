class VideoServer {
  final String nombre;
  final String url;
  final String idioma;
  final String calidad;
  final Map<String, String> headers;

  VideoServer({
    required this.nombre,
    required this.url,
    required this.idioma,
    required this.calidad,
    this.headers = const {},
  });

  factory VideoServer.fromJson(Map<String, dynamic> json) {
    return VideoServer(
      nombre: json['nombre'] ?? 'Servidor 1',
      url: json['url'] ?? '',
      idioma: json['idioma'] ?? 'Español',
      calidad: json['calidad'] ?? 'HD',
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'] as Map)
          : const {},
    );
  }
}

class Episodio {
  final int numero;
  final String titulo;
  final String descripcion;
  final String imagen;
  final List<VideoServer> servidores;

  Episodio({
    required this.numero,
    required this.titulo,
    required this.descripcion,
    required this.imagen,
    required this.servidores,
  });

  factory Episodio.fromJson(Map<String, dynamic> json) {
    List<VideoServer> servers = [];
    if (json['servidores'] != null) {
      servers = (json['servidores'] as List)
          .map((s) => VideoServer.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    return Episodio(
      numero: (json['numero'] ?? 0) as int,
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      imagen: json['imagen'] ?? '',
      servidores: servers,
    );
  }
}

class Temporada {
  final int numero;
  final String nombre;
  final List<Episodio> episodios;

  Temporada({
    required this.numero,
    required this.nombre,
    required this.episodios,
  });

  factory Temporada.fromJson(Map<String, dynamic> json) {
    List<Episodio> eps = [];
    if (json['episodios'] != null) {
      eps = (json['episodios'] as List)
          .map((e) => Episodio.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return Temporada(
      numero: (json['numero'] ?? 0) as int,
      nombre: json['nombre'] ?? '',
      episodios: eps,
    );
  }
}

class Movie {
  final String id;
  final String titulo;
  final String descripcion;
  final String poster;
  final String backdrop;
  final List<String> generos;
  final List<String> categorias;
  final double rating;
  final int? anio;
  final String tipo;
  final bool destacada;
  final bool tendencia;
  final List<VideoServer> servidores;
  final List<Temporada> temporadas;
  final String? duracion;
  final List<String> actores;
  final String fechaAgregada;

  Movie({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.poster,
    required this.backdrop,
    required this.generos,
    required this.categorias,
    required this.rating,
    this.anio,
    required this.tipo,
    required this.destacada,
    required this.tendencia,
    required this.servidores,
    required this.temporadas,
    this.duracion,
    required this.actores,
    required this.fechaAgregada,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    List<VideoServer> servers = [];
    if (json['servidores'] != null) {
      servers = (json['servidores'] as List)
          .map((s) => VideoServer.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    List<Temporada> temporadas = [];
    if (json['temporadas'] != null) {
      temporadas = (json['temporadas'] as List)
          .map((t) => Temporada.fromJson(t as Map<String, dynamic>))
          .toList();
    }

    return Movie(
      id: json['_id'] ?? '',
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      poster: json['poster'] ?? json['imagen'] ?? '',
      backdrop: json['backdrop'] ?? json['poster'] ?? json['imagen'] ?? '',
      generos: List<String>.from(json['generos'] ?? []),
      categorias: List<String>.from(json['categorias'] ?? []),
      rating: (json['rating'] ?? 0).toDouble(),
      anio: json['anio'] ?? json['year'],
      tipo: json['tipo'] ?? 'pelicula',
      destacada: json['destacada'] ?? false,
      tendencia: json['tendencia'] ?? false,
      servidores: servers,
      temporadas: temporadas,
      duracion: json['duracion']?.toString(),
      actores: List<String>.from(json['actores'] ?? []),
      fechaAgregada: json['fechaAgregada'] ?? '',
    );
  }

  Movie copyWith({
    List<VideoServer>? servidores,
    String? titulo,
    String? descripcion,
    String? poster,
    String? backdrop,
  }) {
    return Movie(
      id: id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      poster: poster ?? this.poster,
      backdrop: backdrop ?? this.backdrop,
      generos: generos,
      categorias: categorias,
      rating: rating,
      anio: anio,
      tipo: tipo,
      destacada: destacada,
      tendencia: tendencia,
      servidores: servidores ?? this.servidores,
      temporadas: temporadas,
      duracion: duracion,
      actores: actores,
      fechaAgregada: fechaAgregada,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'titulo': titulo,
        'poster': poster,
        'rating': rating,
        'anio': anio,
        'generos': generos,
      };
}
