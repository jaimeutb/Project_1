class Valoracion {
  final int id;
  final int puntuacion;
  final String? comentario;
  final String autor;
  final DateTime creadoEn;

  const Valoracion({
    required this.id,
    required this.puntuacion,
    required this.comentario,
    required this.autor,
    required this.creadoEn,
  });

  factory Valoracion.fromJson(Map<String, dynamic> json) {
    return Valoracion(
      id: json['id'] as int,
      puntuacion: json['puntuacion'] as int,
      comentario: json['comentario'] as String?,
      autor: json['autor'] as String? ?? 'Estudiante',
      creadoEn: DateTime.parse(json['creado_en'] as String),
    );
  }
}
