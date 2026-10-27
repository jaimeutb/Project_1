// Respuestas del Tutor IA (RF-14, RF-15, RF-16). Ver
// backend/src/services/tutorIa.js para los esquemas que devuelve la API.

/// Estado del Tutor IA en el servidor: si tiene la clave de la API configurada.
class EstadoTutorIa {
  final bool disponible;
  final int limitePorHora;

  const EstadoTutorIa({required this.disponible, required this.limitePorHora});

  factory EstadoTutorIa.fromJson(Map<String, dynamic> json) => EstadoTutorIa(
        disponible: json['disponible'] as bool? ?? false,
        limitePorHora: json['limite_por_hora'] as int? ?? 0,
      );
}

/// 'archivo' si la IA leyó el archivo del material; 'metadatos' si solo
/// conoció su título y descripción (Word, ZIP o archivo muy grande, regla R-12).
bool leyoElArchivo(String? fuente) => fuente != 'metadatos';

class TemaIa {
  final String nombre;
  final String explicacion;
  final String ejemplo;

  const TemaIa({required this.nombre, required this.explicacion, required this.ejemplo});

  factory TemaIa.fromJson(Map<String, dynamic> json) => TemaIa(
        nombre: json['nombre'] as String? ?? '',
        explicacion: json['explicacion'] as String? ?? '',
        ejemplo: json['ejemplo'] as String? ?? '',
      );
}

class EjercicioIa {
  final String enunciado;
  final String pista;
  final String solucion;

  const EjercicioIa({required this.enunciado, required this.pista, required this.solucion});

  factory EjercicioIa.fromJson(Map<String, dynamic> json) => EjercicioIa(
        enunciado: json['enunciado'] as String? ?? '',
        pista: json['pista'] as String? ?? '',
        solucion: json['solucion'] as String? ?? '',
      );
}

/// RF-14: explicación del material.
class ExplicacionIa {
  final String resumen;
  final List<TemaIa> temas;
  final List<EjercicioIa> ejercicios;
  final List<String> consejos;
  final bool leyoArchivo;

  const ExplicacionIa({
    required this.resumen,
    required this.temas,
    required this.ejercicios,
    required this.consejos,
    required this.leyoArchivo,
  });

  factory ExplicacionIa.fromJson(Map<String, dynamic> json) {
    final c = json['contenido'] as Map<String, dynamic>;
    return ExplicacionIa(
      resumen: c['resumen'] as String? ?? '',
      temas: [for (final t in c['temas'] as List? ?? []) TemaIa.fromJson(t)],
      ejercicios: [for (final e in c['ejercicios'] as List? ?? []) EjercicioIa.fromJson(e)],
      consejos: [for (final s in c['consejos'] as List? ?? []) '$s'],
      leyoArchivo: leyoElArchivo(json['fuente'] as String?),
    );
  }
}

class PreguntaPractica {
  final String enunciado;
  final List<String> opciones;
  final int correcta;
  final String explicacion;

  const PreguntaPractica({
    required this.enunciado,
    required this.opciones,
    required this.correcta,
    required this.explicacion,
  });

  factory PreguntaPractica.fromJson(Map<String, dynamic> json) => PreguntaPractica(
        enunciado: json['enunciado'] as String? ?? '',
        opciones: [for (final o in json['opciones'] as List? ?? []) '$o'],
        correcta: json['correcta'] as int? ?? 0,
        explicacion: json['explicacion'] as String? ?? '',
      );
}

/// RF-15: preguntas de práctica.
class PracticaIa {
  final List<PreguntaPractica> preguntas;
  final bool leyoArchivo;

  const PracticaIa({required this.preguntas, required this.leyoArchivo});

  factory PracticaIa.fromJson(Map<String, dynamic> json) {
    final c = json['contenido'] as Map<String, dynamic>;
    return PracticaIa(
      preguntas: [for (final p in c['preguntas'] as List? ?? []) PreguntaPractica.fromJson(p)],
      leyoArchivo: leyoElArchivo(json['fuente'] as String?),
    );
  }
}

/// RF-16: un mensaje de la conversación con el tutor.
class TurnoChat {
  final bool esDelTutor;
  final String texto;

  const TurnoChat({required this.esDelTutor, required this.texto});

  Map<String, dynamic> toJson() => {'rol': esDelTutor ? 'tutor' : 'estudiante', 'texto': texto};
}
