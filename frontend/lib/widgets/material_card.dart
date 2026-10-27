import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as flutter show Material;

import '../models/material.dart' as modelo;
import '../theme/utb_theme.dart';

/// Tarjeta de resumen de un material en los resultados de búsqueda (RF-03/RF-04).
class MaterialCard extends StatelessWidget {
  final modelo.Material material;
  final VoidCallback onTap;

  const MaterialCard({super.key, required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reportado = material.estado != 'publicado';
    // Solo el administrador recibe material retirado (RF-12).
    final retirado = material.estado == 'retirado';
    final (iconoArchivo, tipoArchivo) = tipoDeArchivo(material.archivoUrl);

    return flutter.Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: UtbColores.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: UtbColores.verde10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(iconoArchivo, color: UtbColores.verde),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.asignaturaNombre,
                          style: const TextStyle(
                            color: UtbColores.azul,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          material.titulo,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: UtbColores.texto,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (reportado)
                    Chip(
                      label: Text(material.estadoVisible),
                      backgroundColor:
                          retirado ? const Color(0xFFECECEC) : const Color(0xFFFDF3D6),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (material.profesor != null || material.periodoAcademico != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    [
                      if (material.profesor != null) 'Prof. ${material.profesor}',
                      if (material.periodoAcademico != null) material.periodoAcademico!,
                    ].join(' · '),
                    style: const TextStyle(color: UtbColores.textoSecundario, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 18, color: UtbColores.ambar),
                      const SizedBox(width: 3),
                      Text(
                        material.totalValoraciones > 0
                            ? '${material.calificacionPromedio.toStringAsFixed(1)} (${material.totalValoraciones})'
                            : 'Sin valoraciones',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline,
                          size: 16, color: UtbColores.textoSecundario),
                      const SizedBox(width: 3),
                      Text(material.autorVisible, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  Text(tipoArchivo,
                      style: const TextStyle(fontSize: 12, color: UtbColores.textoSecundario)),
                  const _EtiquetaTutor(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ícono y nombre del tipo de archivo del material, según su extensión (R-02).
(IconData, String) tipoDeArchivo(String archivoUrl) {
  final extension = archivoUrl.split('.').last.toLowerCase();
  return switch (extension) {
    'pdf' => (Icons.picture_as_pdf_outlined, 'PDF'),
    'png' || 'jpg' || 'jpeg' => (Icons.image_outlined, 'Imagen'),
    'doc' || 'docx' => (Icons.description_outlined, 'Word'),
    'zip' => (Icons.folder_zip_outlined, 'ZIP'),
    _ => (Icons.insert_drive_file_outlined, 'Archivo'),
  };
}

class _EtiquetaTutor extends StatelessWidget {
  const _EtiquetaTutor();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: UtbColores.azul10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 13, color: UtbColores.azul),
          SizedBox(width: 4),
          Text('Tutor IA',
              style: TextStyle(fontSize: 11, color: UtbColores.azul, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
