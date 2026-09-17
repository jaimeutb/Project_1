/// Corresponde a la clase Material del diagrama de clases actualizado
/// (docs/diagramas/02-clases.png), incluyendo los campos agregados en la
/// validación del modelado: profesor, periodoAcademico, esAnonimo y estado.
class Material {
  final int id;
  final String titulo;
  final String? descripcion;
  final String archivoUrl;
  final DateTime fechaPublicacion;
  final String? profesor;
  final String? periodoAcademico;
  final bool esAnonimo;
  final String estado; // publicado | reportado | en_revision | retirado
  final int asignaturaId;
  final String asignaturaNombre;
  final String? autorNombre; // null si es_anonimo = true (RF-07)
  final double calificacionPromedio;
  final int totalValoraciones;
  final int reportesPendientes;

  const Material({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.archivoUrl,
    required this.fechaPublicacion,
    required this.profesor,
    required this.periodoAcademico,
    required this.esAnonimo,
    required this.estado,
    required this.asignaturaId,
    required this.asignaturaNombre,
    required this.autorNombre,
    required this.calificacionPromedio,
    required this.totalValoraciones,
    required this.reportesPendientes,
  });

  factory Material.fromJson(Map<String, dynamic> json) {
    return Material(
      id: json['id'] as int,
      titulo: json['titulo'] as String,
      descripcion: json['descripcion'] as String?,
      archivoUrl: json['archivo_url'] as String,
      fechaPublicacion: DateTime.parse(json['fecha_publicacion'] as String),
      profesor: json['profesor'] as String?,
      periodoAcademico: json['periodo_academico'] as String?,
      esAnonimo: json['es_anonimo'] as bool,
      estado: json['estado'] as String,
      asignaturaId: json['asignatura_id'] as int,
      asignaturaNombre: json['asignatura_nombre'] as String? ?? '',
      autorNombre: json['autor_nombre'] as String?,
      calificacionPromedio:
          double.tryParse('${json['calificacion_promedio']}') ?? 0,
      totalValoraciones: int.tryParse('${json['total_valoraciones']}') ?? 0,
      reportesPendientes:
          int.tryParse('${json['reportes_pendientes']}') ?? 0,
    );
  }

  String get autorVisible => esAnonimo || autorNombre == null
      ? 'Anónimo'
      : autorNombre!;
}
