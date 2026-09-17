import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as flutter show Material;

import '../models/material.dart' as modelo;

/// Tarjeta de resumen de un material en los resultados de búsqueda (RF-03/RF-04).
class MaterialCard extends StatelessWidget {
  final modelo.Material material;
  final VoidCallback onTap;

  const MaterialCard({super.key, required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reportado = material.estado != 'publicado';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      child: flutter.Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        material.titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    if (reportado)
                      const Chip(
                        label: Text('En revisión'),
                        backgroundColor: Color(0xFFFDF3D6),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(material.asignaturaNombre,
                    style: const TextStyle(color: Colors.black54)),
                if (material.profesor != null || material.periodoAcademico != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        if (material.profesor != null) 'Prof. ${material.profesor}',
                        if (material.periodoAcademico != null) material.periodoAcademico!,
                      ].join(' · '),
                      style: const TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      material.totalValoraciones > 0
                          ? '${material.calificacionPromedio.toStringAsFixed(1)} (${material.totalValoraciones})'
                          : 'Sin valoraciones',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.person_outline, size: 16, color: Colors.black45),
                    const SizedBox(width: 4),
                    Text(material.autorVisible, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
