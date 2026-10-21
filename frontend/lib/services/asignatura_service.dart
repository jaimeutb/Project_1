import '../config/api_config.dart';
import '../models/asignatura.dart';
import 'api_client.dart';

/// RF-03/RF-13: consulta y gestión de asignaturas.
class AsignaturaService {
  final String? token;
  AsignaturaService(this.token);

  ApiClient get _client => ApiClient(token: token);

  /// Por defecto solo trae las asignaturas activas. El administrador puede
  /// pedir también las desactivadas ([incluirInactivas]).
  Future<List<Asignatura>> listar({bool incluirInactivas = false}) async {
    final query = incluirInactivas ? {'incluir_inactivas': 'true'} : null;
    final data = await _client.get(ApiConfig.api('/asignaturas', query)) as List;
    return data.map((e) => Asignatura.fromJson(e)).toList();
  }

  Future<Asignatura> crear({
    required String nombre,
    required String codigo,
    required String semestre,
  }) async {
    final data = await _client.post(ApiConfig.api('/asignaturas'), {
      'nombre': nombre,
      'codigo': codigo,
      'semestre': semestre,
    });
    return Asignatura.fromJson(data);
  }

  /// RF-13: editar (nombre, codigo, semestre) o desactivar/reactivar (activo).
  Future<Asignatura> actualizar(int id, Map<String, dynamic> cambios) async {
    final data = await _client.put(ApiConfig.api('/asignaturas/$id'), cambios);
    return Asignatura.fromJson(data);
  }
}
