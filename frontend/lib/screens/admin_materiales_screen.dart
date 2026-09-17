import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/material.dart';
import '../services/api_client.dart';
import '../services/material_service.dart';
import '../state/session.dart';

/// RF-12: el administrador gestiona (edita el estado / elimina) el material
/// publicado por los estudiantes.
class AdminMaterialesScreen extends StatefulWidget {
  const AdminMaterialesScreen({super.key});

  @override
  State<AdminMaterialesScreen> createState() => _AdminMaterialesScreenState();
}

class _AdminMaterialesScreenState extends State<AdminMaterialesScreen> {
  List<Material> _materiales = [];
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
      setState(() => _materiales = materiales);
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarEstado(Material m, String nuevoEstado) async {
    try {
      await MaterialService(_token).actualizar(m.id, {'estado': nuevoEstado});
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  Future<void> _eliminar(Material m) async {
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
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  itemCount: _materiales.length,
                  itemBuilder: (context, i) {
                    final m = _materiales[i];
                    return ListTile(
                      title: Text(m.titulo),
                      subtitle: Text('${m.asignaturaNombre} · estado: ${m.estado}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopupMenuButton<String>(
                            onSelected: (estado) => _cambiarEstado(m, estado),
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'publicado', child: Text('Publicado')),
                              PopupMenuItem(value: 'en_revision', child: Text('En revisión')),
                              PopupMenuItem(value: 'retirado', child: Text('Retirado')),
                            ],
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
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
