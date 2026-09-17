/// Corresponde a la clase Reporte, incorporada en la validación del modelado
/// (sección 8.4 del "Avance de proyecto de aula") para soportar RF-09/RF-10.
class Reporte {
  final int id;
  final String motivo;
  final String estado; // pendiente | resuelto | descartado
  final int materialId;
  final String materialTitulo;
  final String reportadoPor;
  final DateTime creadoEn;

  const Reporte({
    required this.id,
    required this.motivo,
    required this.estado,
    required this.materialId,
    required this.materialTitulo,
    required this.reportadoPor,
    required this.creadoEn,
  });

  factory Reporte.fromJson(Map<String, dynamic> json) {
    return Reporte(
      id: json['id'] as int,
      motivo: json['motivo'] as String,
      estado: json['estado'] as String,
      materialId: json['material_id'] as int,
      materialTitulo: json['material_titulo'] as String? ?? '',
      reportadoPor: json['reportado_por'] as String? ?? '',
      creadoEn: DateTime.parse(json['creado_en'] as String),
    );
  }
}
