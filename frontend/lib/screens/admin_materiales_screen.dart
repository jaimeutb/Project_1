import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/material.dart' as modelo;
import '../services/api_client.dart';
import '../services/material_service.dart';
import '../state/session.dart';
import '../theme/utb_theme.dart';
import '../widgets/material_card.dart' show MiniaturaMaterial;

/// RF-12: el administrador gestiona (edita el estado / elimina) el material
/// publicado por los estudiantes. RF-17: lo que la IA dejó pendiente aparece
/// primero, con su motivo, para aprobarlo o retirarlo con un clic.
class AdminMaterialesScreen extends StatefulWidget {
  const AdminMaterialesScreen({super.key});

  @override
  State<AdminMaterialesScreen> createState() => _AdminMaterialesScreenState();
}

class _AdminMaterialesScreenState extends State<AdminMaterialesScreen> {
  List<modelo.Material> _materiales = [];
  bool _cargando = true;
  String? _error;

  String? get _token => context.read<Session>().token;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      // Sin filtro de estado: el administrador ve todo el material, incluido
      // el reportado o retirado.
      final materiales = await MaterialService(_token).buscar();
      // Lo pendiente de revisión primero (orden estable: sigue por fecha).
      final pendientes = materiales.where((m) => m.estado == 'pendiente');
      final resto = materiales.where((m) => m.estado != 'pendiente');
      setState(() => _materiales = [...pendientes, ...resto]);
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarEstado(modelo.Material m, String nuevoEstado) async {
    try {
      await MaterialService(_token).actualizar(m.id, {'estado': nuevoEstado});
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  /// RF-12: corregir los datos del material (título, descripción y metadatos
  /// de vigencia, RF-11). El cambio se ve de inmediato en la ficha.
  Future<void> _editar(modelo.Material m) async {
    final cambios = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _DialogoEditarMaterial(material: m),
    );
    if (cambios == null) return;
    try {
      await MaterialService(_token).actualizar(m.id, cambios);
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  Future<void> _eliminar(modelo.Material m) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar material'),
        content: Text('¿Eliminar "${m.titulo}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await MaterialService(_token).eliminar(m.id);
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar material')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: UtbColores.error)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _materiales.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) return _ResumenPendientes(_materiales);
                    final m = _materiales[i - 1];
                    final pendiente = m.estado == 'pendiente';
                    return ListTile(
                      tileColor: pendiente ? UtbColores.ambar10 : null,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(width: 56, height: 42, child: MiniaturaMaterial(material: m)),
                      ),
                      title: Text(m.titulo),
                      subtitle: Text([
                        m.asignaturaNombre,
                        'estado: ${m.estadoVisible}',
                        if (m.reportesPendientes > 0)
                          '${m.reportesPendientes} reporte(s) pendiente(s)',
                        if (pendiente && m.revisionIa != null) 'IA: ${m.revisionIa!.motivo}',
                      ].join(' · ')),
                      isThreeLine: pendiente,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (pendiente) ...[
                            IconButton(
                              tooltip: 'Aprobar y publicar',
                              icon: const Icon(Icons.check_circle_outline, color: UtbColores.verde),
                              onPressed: () => _cambiarEstado(m, 'publicado'),
                            ),
                            IconButton(
                              tooltip: 'Rechazar (retirar)',
                              icon: const Icon(Icons.block, color: UtbColores.error),
                              onPressed: () => _cambiarEstado(m, 'retirado'),
                            ),
                          ],
                          IconButton(
                            tooltip: 'Editar datos',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editar(m),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Cambiar estado',
                            onSelected: (estado) => _cambiarEstado(m, estado),
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'publicado', child: Text('Publicado')),
                              PopupMenuItem(value: 'en_revision', child: Text('En revisión')),
                              PopupMenuItem(value: 'retirado', child: Text('Retirado')),
                              PopupMenuItem(value: 'pendiente', child: Text('Pendiente de revisión')),
                            ],
                            icon: const Icon(Icons.swap_horiz),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _eliminar(m),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

/// Aviso con la cantidad de material que la IA dejó pendiente (RF-17).
class _ResumenPendientes extends StatelessWidget {
  final List<modelo.Material> materiales;
  const _ResumenPendientes(this.materiales);

  @override
  Widget build(BuildContext context) {
    final pendientes = materiales.where((m) => m.estado == 'pendiente').length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pendientes > 0 ? UtbColores.ambar10 : UtbColores.verde10,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(pendientes > 0 ? Icons.pending_actions : Icons.verified_user_outlined,
              color: pendientes > 0 ? const Color(0xFF8A5A00) : UtbColores.verde),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pendientes > 0
                  ? '$pendientes material(es) esperan su revisión: la IA tuvo dudas al revisarlos.'
                  : 'No hay material pendiente: la IA revisa cada archivo al subirlo.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formulario de edición de un material. Devuelve los campos o null.
class _DialogoEditarMaterial extends StatefulWidget {
  final modelo.Material material;
  const _DialogoEditarMaterial({required this.material});

  @override
  State<_DialogoEditarMaterial> createState() => _DialogoEditarMaterialState();
}

class _DialogoEditarMaterialState extends State<_DialogoEditarMaterial> {
  final _formKey = GlobalKey<FormState>();
  late final _tituloCtrl = TextEditingController(text: widget.material.titulo);
  late final _descripcionCtrl = TextEditingController(text: widget.material.descripcion);
  late final _profesorCtrl = TextEditingController(text: widget.material.profesor);
  late final _periodoCtrl = TextEditingController(text: widget.material.periodoAcademico);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar material'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido.' : null,
              ),
              TextFormField(
                controller: _descripcionCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              TextFormField(
                controller: _profesorCtrl,
                decoration: const InputDecoration(labelText: 'Profesor'),
              ),
              TextFormField(
                controller: _periodoCtrl,
                decoration: const InputDecoration(labelText: 'Periodo académico'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop({
              'titulo': _tituloCtrl.text.trim(),
              'descripcion': _descripcionCtrl.text.trim(),
              'profesor': _profesorCtrl.text.trim(),
              'periodo_academico': _periodoCtrl.text.trim(),
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
