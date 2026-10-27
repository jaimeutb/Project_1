import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as flutter show Material;

import '../models/material.dart';
import '../services/api_client.dart';
import '../services/material_service.dart';
import '../theme/utb_theme.dart';
import '../widgets/material_card.dart' show MiniaturaMaterial;

/// «Mis aportes»: el material que subió el estudiante, con el estado de su
/// publicación y lo que dijo la IA al revisarlo (RF-17).
class MisAportesPagina extends StatefulWidget {
  final String? token;
  final ValueChanged<Material> onAbrir;
  final VoidCallback onSubir;

  const MisAportesPagina({
    super.key,
    required this.token,
    required this.onAbrir,
    required this.onSubir,
  });

  @override
  State<MisAportesPagina> createState() => MisAportesPaginaState();
}

class MisAportesPaginaState extends State<MisAportesPagina> {
  List<Material> _materiales = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    recargar();
  }

  Future<void> recargar() async {
    setState(() => _cargando = true);
    try {
      final m = await MaterialService(widget.token).buscar(soloMios: true);
      if (mounted) setState(() => _materiales = m);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No fue posible conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion(
          'Mis aportes',
          subtitulo: 'El material que has compartido con la comunidad UTB y su revisión.',
          accion: FilledButton.icon(
            onPressed: widget.onSubir,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo aporte'),
          ),
        ),
        if (_cargando)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: UtbColores.error))
        else if (_materiales.isEmpty)
          const TarjetaUtb(
            child: Column(
              children: [
                Icon(Icons.volunteer_activism_outlined, size: 44, color: UtbColores.verde),
                SizedBox(height: 10),
                Text('Todavía no has subido material',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 4),
                Text('Comparte un parcial o taller resuelto: la IA lo revisa y ayuda a otros a estudiar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: UtbColores.textoSecundario)),
              ],
            ),
          )
        else
          for (final m in _materiales)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FilaAporte(material: m, onTap: () => widget.onAbrir(m)),
            ),
      ],
    );
  }
}

class _FilaAporte extends StatelessWidget {
  final Material material;
  final VoidCallback onTap;
  const _FilaAporte({required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = material.revisionIa;
    final (texto, color, fondo, icono) = switch (material.estado) {
      'publicado' => ('Publicado', UtbColores.verdeOscuro, UtbColores.verde10, Icons.check_circle),
      'pendiente' => ('Pendiente de revisión', const Color(0xFF8A5A00), UtbColores.ambar10,
          Icons.hourglass_top),
      'retirado' => ('Retirado', UtbColores.textoSecundario, const Color(0xFFECECEC), Icons.block),
      _ => ('En revisión', const Color(0xFF8A5A00), UtbColores.ambar10, Icons.flag_outlined),
    };
    return flutter.Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: UtbColores.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 104, height: 76, child: MiniaturaMaterial(material: material)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(material.asignaturaNombre,
                        style: const TextStyle(
                            color: UtbColores.azul, fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(material.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 6),
                    Etiqueta(texto, color: color, fondo: fondo, icono: icono),
                    if (r != null && r.motivo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('IA: ${r.motivo}',
                          style: const TextStyle(
                              fontSize: 12.5, color: UtbColores.textoSecundario, height: 1.35)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
