import '../config/api_config.dart';
import '../models/usuario.dart';
import 'api_client.dart';

/// RF-13: gestión de usuarios por parte del administrador.
class UsuarioService {
  final String? token;
  UsuarioService(this.token);

  ApiClient get _client => ApiClient(token: token);

  Future<List<Usuario>> listar() async {
    final data = await _client.get(ApiConfig.api('/usuarios')) as List;
    return data.map((e) => Usuario.fromJson(e)).toList();
  }

  Future<Usuario> crear({
    required String nombre,
    required String correo,
    required String contrasena,
    required String rol,
  }) async {
    final data = await _client.post(ApiConfig.api('/usuarios'), {
      'nombre': nombre,
      'correo': correo,
      'contrasena': contrasena,
      'rol': rol,
    });
    return Usuario.fromJson(data);
  }

  /// Editar (nombre, correo, rol) o desactivar/reactivar (activo).
  Future<Usuario> actualizar(int id, Map<String, dynamic> cambios) async {
    final data = await _client.put(ApiConfig.api('/usuarios/$id'), cambios);
    return Usuario.fromJson(data);
  }
}
