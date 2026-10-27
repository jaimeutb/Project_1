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
  final String? miniaturaUrl; // RF-19: vista previa (primera página o la imagen)
  final RevisionIa? revisionIa; // RF-17: revisión automática al subirlo
  final bool esMio;

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
    this.miniaturaUrl,
    this.revisionIa,
    this.esMio = false,
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
      miniaturaUrl: json['miniatura_url'] as String?,
      revisionIa: json['revision_ia'] is Map<String, dynamic>
          ? RevisionIa.fromJson(json['revision_ia'] as Map<String, dynamic>)
          : null,
      esMio: json['es_mio'] as bool? ?? false,
    );
  }

  String get autorVisible => esAnonimo || autorNombre == null
      ? 'Anónimo'
      : autorNombre!;

  /// Nombre del estado que se muestra en la lista y en la ficha. «reportado» y
  /// «en_revision» se muestran igual en los dos lugares (H-07).
  String get estadoVisible => switch (estado) {
        'publicado' => 'Publicado',
        'retirado' => 'Retirado',
        'pendiente' => 'Pendiente de revisión',
        _ => 'En revisión',
      };
}

/// RF-17: resultado de la revisión automática del material al subirlo.
class RevisionIa {
  final String veredicto; // aprobado | dudoso | rechazado
  final String motivo;
  final String tipo; // parcial | quiz | taller | guia | apuntes | otro
  final List<String> temas;
  final String? dificultad; // basica | media | avanzada
  final String? resumen;
  final Map<String, bool> criterios;

  const RevisionIa({
    required this.veredicto,
    required this.motivo,
    required this.tipo,
    required this.temas,
    this.dificultad,
    this.resumen,
    this.criterios = const {},
  });

  factory RevisionIa.fromJson(Map<String, dynamic> json) => RevisionIa(
        veredicto: json['veredicto'] as String? ?? 'dudoso',
        motivo: json['motivo'] as String? ?? '',
        tipo: json['tipo'] as String? ?? 'otro',
        temas: [for (final t in json['temas'] as List? ?? []) '$t'],
        dificultad: json['dificultad'] as String?,
        resumen: json['resumen'] as String?,
        criterios: {
          for (final e in (json['criterios'] as Map<String, dynamic>? ?? {}).entries)
            e.key: e.value == true,
        },
      );

  bool get aprobado => veredicto == 'aprobado';

  String get tipoVisible => nombreDeTipo(tipo);

  String? get dificultadVisible => switch (dificultad) {
        'basica' => 'Básica',
        'media' => 'Media',
        'avanzada' => 'Avanzada',
        _ => null,
      };
}

/// Nombre visible de cada tipo de material que identifica la IA.
String nombreDeTipo(String tipo) => switch (tipo) {
      'parcial' => 'Parcial',
      'quiz' => 'Quiz',
      'taller' => 'Taller',
      'guia' => 'Guía',
      'apuntes' => 'Apuntes',
      _ => 'Otro',
    };
