import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as flutter show Material;

import '../config/api_config.dart';
import '../models/material.dart' as modelo;
import '../theme/utb_theme.dart';

/// Tarjeta de un material en los resultados de búsqueda (RF-03/RF-04), con su
/// vista previa (RF-19) y lo que identificó la IA al revisarlo (RF-17).
class MaterialCard extends StatelessWidget {
  final modelo.Material material;
  final VoidCallback onTap;

  const MaterialCard({super.key, required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reportado = material.estado != 'publicado';
    // Solo el administrador (y el autor, si está pendiente) recibe este material.
    final retirado = material.estado == 'retirado';
    final revision = material.revisionIa;

    return flutter.Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: UtbColores.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MiniaturaMaterial(material: material),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Wrap(spacing: 6, children: [
                      if (revision != null && revision.tipo != 'otro')
                        Etiqueta(revision.tipoVisible,
                            color: Colors.white, fondo: const Color(0xCC1F2566)),
                      if (revision != null && revision.aprobado)
                        const Etiqueta('Verificado por IA',
                            color: Colors.white,
                            fondo: Color(0xE6187943),
                            icono: Icons.verified_outlined),
                    ]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          material.asignaturaNombre,
                          style: const TextStyle(
                            color: UtbColores.azul,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (reportado)
                        Chip(
                          label: Text(material.estadoVisible),
                          labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          backgroundColor: retirado
                              ? const Color(0xFFECECEC)
                              : UtbColores.ambar10,
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    material.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.3,
                      color: UtbColores.texto,
                    ),
                  ),
                  if (material.profesor != null || material.periodoAcademico != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [
                          if (material.profesor != null) 'Prof. ${material.profesor}',
                          if (material.periodoAcademico != null) material.periodoAcademico!,
                        ].join(' · '),
                        style: const TextStyle(color: UtbColores.textoSecundario, fontSize: 12),
                      ),
                    ),
                  if (revision != null && revision.temas.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tema in revision.temas.take(3))
                            Etiqueta(tema, color: UtbColores.verdeOscuro, fondo: UtbColores.verde10),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 18, color: UtbColores.ambar),
                      const SizedBox(width: 3),
                      Text(
                        material.totalValoraciones > 0
                            ? '${material.calificacionPromedio.toStringAsFixed(1)} (${material.totalValoraciones})'
                            : 'Sin valoraciones',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 14),
                      const Icon(Icons.person_outline, size: 16, color: UtbColores.textoSecundario),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(material.autorVisible,
                            overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vista previa del material (RF-19): la miniatura del servidor o, si no tiene
/// (Word, ZIP o material anterior a esta función), un fondo con el ícono del tipo
/// de archivo.
class MiniaturaMaterial extends StatelessWidget {
  final modelo.Material material;
  const MiniaturaMaterial({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    final (icono, tipo) = tipoDeArchivo(material.archivoUrl);
    final respaldo = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [UtbColores.azul10, UtbColores.verde10],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 38, color: UtbColores.azul),
          const SizedBox(height: 4),
          Text(tipo,
              style: const TextStyle(
                  color: UtbColores.azul, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
    final url = material.miniaturaUrl;
    if (url == null) return respaldo;
    return Container(
      color: const Color(0xFFF0F1F6),
      child: Image.network(
        ApiConfig.archivo(url).toString(),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        semanticLabel: 'Vista previa de ${material.titulo}',
        errorBuilder: (_, __, ___) => respaldo,
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
