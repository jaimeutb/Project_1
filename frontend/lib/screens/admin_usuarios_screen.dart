import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/usuario.dart';
import '../services/api_client.dart';
import '../services/usuario_service.dart';
import '../state/session.dart';

/// RF-13: el administrador crea, edita, cambia el rol y desactiva usuarios.
/// Una cuenta desactivada no puede iniciar sesión.
class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  List<Usuario> _usuarios = [];
  bool _cargando = true;
  String? _error;

  String? get _token => context.read<Session>().token;
  int? get _miId => context.read<Session>().usuario?.id;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final usuarios = await UsuarioService(_token).listar();
      setState(() => _usuarios = usuarios);
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    try {
      await accion();
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  Future<void> _abrirFormulario([Usuario? usuario]) async {
    final datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _DialogoUsuario(usuario: usuario),
    );
    if (datos == null) return;
    final service = UsuarioService(_token);
    await _ejecutar(() async {
      if (usuario == null) {
        await service.crear(
          nombre: datos['nombre']!,
          correo: datos['correo']!,
          contrasena: datos['contrasena']!,
          rol: datos['rol']!,
        );
      } else {
        await service.actualizar(usuario.id, {'nombre': datos['nombre'], 'correo': datos['correo']});
      }
    });
  }

  void _accion(Usuario u, String accion) {
    final service = UsuarioService(_token);
    switch (accion) {
      case 'editar':
        _abrirFormulario(u);
      case 'rol':
        _ejecutar(() => service.actualizar(
            u.id, {'rol': u.esAdministrador ? 'estudiante' : 'administrador'}));
      case 'activo':
        _ejecutar(() => service.actualizar(u.id, {'activo': !u.activo}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar usuarios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuevo usuario'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _usuarios.length,
                  itemBuilder: (context, i) {
                    final u = _usuarios[i];
                    final soyYo = u.id == _miId;
                    return ListTile(
                      leading: Icon(
                        u.esAdministrador ? Icons.admin_panel_settings_outlined : Icons.person_outline,
                        color: u.activo ? null : Colors.black26,
                      ),
                      title: Text(soyYo ? '${u.nombre} (usted)' : u.nombre),
                      subtitle: Text('${u.correo} · ${u.rol}${u.activo ? '' : ' · Desactivado'}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (accion) => _accion(u, accion),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'editar', child: Text('Editar')),
                          // El administrador no puede quitarse el rol ni desactivarse a sí mismo.
                          if (!soyYo)
                            PopupMenuItem(
                              value: 'rol',
                              child: Text(u.esAdministrador
                                  ? 'Cambiar a estudiante'
                                  : 'Hacer administrador'),
                            ),
                          if (!soyYo)
                            PopupMenuItem(
                              value: 'activo',
                              child: Text(u.activo ? 'Desactivar' : 'Reactivar'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

/// Formulario para crear un usuario (con contraseña y rol) o editar su nombre
/// y correo. Devuelve los campos o null.
class _DialogoUsuario extends StatefulWidget {
  final Usuario? usuario;
  const _DialogoUsuario({this.usuario});

  @override
  State<_DialogoUsuario> createState() => _DialogoUsuarioState();
}

class _DialogoUsuarioState extends State<_DialogoUsuario> {
  final _formKey = GlobalKey<FormState>();
  late final _nombreCtrl = TextEditingController(text: widget.usuario?.nombre);
  late final _correoCtrl = TextEditingController(text: widget.usuario?.correo);
  final _contrasenaCtrl = TextEditingController();
  String _rol = 'estudiante';

  bool get _esNuevo => widget.usuario == null;

  String? _requerido(String? v) => (v == null || v.trim().isEmpty) ? 'Requerido.' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esNuevo ? 'Nuevo usuario' : 'Editar usuario'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: _requerido,
              ),
              TextFormField(
                controller: _correoCtrl,
                decoration: const InputDecoration(labelText: 'Correo'),
                keyboardType: TextInputType.emailAddress,
                validator: _requerido,
              ),
              if (_esNuevo) ...[
                TextFormField(
                  controller: _contrasenaCtrl,
                  decoration: const InputDecoration(labelText: 'Contraseña inicial'),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'Mínimo 8 caracteres.' : null,
                ),
                DropdownButtonFormField<String>(
                  // `initialValue` reemplaza a `value` desde Flutter 3.35, pero no
                  // existe en Flutter 3.24, con el que el proyecto también compila.
                  // ignore: deprecated_member_use
                  value: _rol,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: const [
                    DropdownMenuItem(value: 'estudiante', child: Text('Estudiante')),
                    DropdownMenuItem(value: 'administrador', child: Text('Administrador')),
                  ],
                  onChanged: (v) => setState(() => _rol = v ?? 'estudiante'),
                ),
              ],
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
              'nombre': _nombreCtrl.text.trim(),
              'correo': _correoCtrl.text.trim(),
              if (_esNuevo) 'contrasena': _contrasenaCtrl.text,
              if (_esNuevo) 'rol': _rol,
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
