import '../config/api_config.dart';
import '../models/usuario.dart';
import 'api_client.dart';

class AuthResultado {
  final Usuario usuario;
  final String token;
  AuthResultado(this.usuario, this.token);
}

/// RF-01/RF-02: registro e inicio de sesión.
class AuthService {
  final ApiClient _client = ApiClient();

  Future<AuthResultado> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    final data = await _client.post(ApiConfig.api('/auth/registro'), {
      'nombre': nombre,
      'correo': correo,
      'contrasena': contrasena,
    });
    return AuthResultado(Usuario.fromJson(data['usuario']), data['token'] as String);
  }

  Future<AuthResultado> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final data = await _client.post(ApiConfig.api('/auth/login'), {
      'correo': correo,
      'contrasena': contrasena,
    });
    return AuthResultado(Usuario.fromJson(data['usuario']), data['token'] as String);
  }

  Future<Usuario> perfil(String token) async {
    final client = ApiClient(token: token);
    final data = await client.get(ApiConfig.api('/auth/perfil'));
    return Usuario.fromJson(data);
  }
}
