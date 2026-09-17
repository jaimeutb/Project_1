import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reporte.dart';
import '../services/api_client.dart';
import '../services/reporte_service.dart';
import '../state/session.dart';

/// RF-10: el administrador revisa los reportes generados por los estudiantes
/// (RF-09) y actualiza su estado.
class AdminReportesScreen extends StatefulWidget {
  const AdminReportesScreen({super.key});

  @override
  State<AdminReportesScreen> createState() => _AdminReportesScreenState();
}

class _AdminReportesScreenState extends State<AdminReportesScreen> {
  List<Reporte> _reportes = [];
  bool _cargando = true;
  String? _error;
  String _filtro = 'pendiente';

  String? get _token => context.read<Session>().token;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final reportes = await ReporteService(_token).listar(estado: _filtro);
      setState(() => _reportes = reportes);
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _actualizarEstado(Reporte r, String estado) async {
    try {
      await ReporteService(_token).actualizarEstado(r.id, estado);
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de material'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final estado in ['pendiente', 'resuelto', 'descartado'])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(estado),
                      selected: _filtro == estado,
                      onSelected: (_) {
                        setState(() => _filtro = estado);
                        _cargar();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _reportes.isEmpty
                  ? Center(child: Text('No hay reportes en estado "$_filtro".'))
                  : ListView.builder(
                      itemCount: _reportes.length,
                      itemBuilder: (context, i) {
                        final r = _reportes[i];
                        return ListTile(
                          title: Text(r.materialTitulo),
                          subtitle: Text('${r.motivo}\nReportado por: ${r.reportadoPor}'),
                          isThreeLine: true,
                          trailing: r.estado == 'pendiente'
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Marcar como resuelto',
                                      icon: const Icon(Icons.check_circle_outline,
                                          color: Colors.green),
                                      onPressed: () => _actualizarEstado(r, 'resuelto'),
                                    ),
                                    IconButton(
                                      tooltip: 'Descartar',
                                      icon: const Icon(Icons.close, color: Colors.redAccent),
                                      onPressed: () => _actualizarEstado(r, 'descartado'),
                                    ),
                                  ],
                                )
                              : Text(r.estado),
                        );
                      },
                    ),
    );
  }
}
