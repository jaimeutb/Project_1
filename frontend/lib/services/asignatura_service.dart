import '../config/api_config.dart';
import '../models/asignatura.dart';
import 'api_client.dart';

/// RF-03/RF-13: consulta y gestión de asignaturas.
class AsignaturaService {
  final String? token;
  AsignaturaService(this.token);

  ApiClient get _client => ApiClient(token: token);

  Future<List<Asignatura>> listar() async {
    final data = await _client.get(ApiConfig.api('/asignaturas')) as List;
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
}
