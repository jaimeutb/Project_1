import '../config/api_config.dart';
import '../models/material.dart';
import '../models/valoracion.dart';
import 'api_client.dart';

/// RF-03/04/05/06/07/08/09/11/12: todas las operaciones sobre materiales,
/// sus valoraciones y sus reportes.
class MaterialService {
  final String? token;
  MaterialService(this.token);

  ApiClient get _client => ApiClient(token: token);

  /// RF-03/RF-04: búsqueda por asignatura, semestre o texto libre (tema).
  Future<List<Material>> buscar({
    int? asignaturaId,
    String? semestre,
    String? texto,
  }) async {
    final query = <String, String>{};
    if (asignaturaId != null) query['asignatura_id'] = '$asignaturaId';
    if (semestre != null && semestre.isNotEmpty) query['semestre'] = semestre;
    if (texto != null && texto.isNotEmpty) query['q'] = texto;

    final data = await _client.get(ApiConfig.api('/materiales', query)) as List;
    return data.map((e) => Material.fromJson(e)).toList();
  }

  /// RF-05: detalle de un material.
  Future<Material> obtener(int id) async {
    final data = await _client.get(ApiConfig.api('/materiales/$id'));
    return Material.fromJson(data);
  }

  /// RF-06/RF-07/RF-11: subir material (opcionalmente anónimo, con metadatos
  /// de vigencia).
  Future<Material> subir({
    required String titulo,
    String? descripcion,
    required int asignaturaId,
    String? profesor,
    String? periodoAcademico,
    required bool esAnonimo,
    required List<int> archivoBytes,
    required String nombreArchivo,
  }) async {
    final data = await _client.postMultipart(
      ApiConfig.api('/materiales'),
      campos: {
        'titulo': titulo,
        if (descripcion != null) 'descripcion': descripcion,
        'asignatura_id': '$asignaturaId',
        if (profesor != null) 'profesor': profesor,
        if (periodoAcademico != null) 'periodo_academico': periodoAcademico,
        'es_anonimo': '$esAnonimo',
      },
      archivoBytes: archivoBytes,
      nombreArchivo: nombreArchivo,
    );
    return Material.fromJson(data);
  }

  /// RF-12: el administrador edita un material (incluye cambiar su estado).
  Future<Material> actualizar(int id, Map<String, dynamic> cambios) async {
    final data = await _client.put(ApiConfig.api('/materiales/$id'), cambios);
    return Material.fromJson(data);
  }

  /// RF-12: el administrador elimina un material.
  Future<void> eliminar(int id) async {
    await _client.delete(ApiConfig.api('/materiales/$id'));
  }

  /// RF-08: valorar (calificar y comentar) un material.
  Future<void> valorar(int materialId, {required int puntuacion, String? comentario}) async {
    await _client.post(ApiConfig.api('/materiales/$materialId/valoraciones'), {
      'puntuacion': puntuacion,
      if (comentario != null) 'comentario': comentario,
    });
  }

  Future<List<Valoracion>> listarValoraciones(int materialId) async {
    final data =
        await _client.get(ApiConfig.api('/materiales/$materialId/valoraciones')) as List;
    return data.map((e) => Valoracion.fromJson(e)).toList();
  }

  /// RF-09: reportar un material (contenido incorrecto o desactualizado).
  Future<void> reportar(int materialId, {required String motivo}) async {
    await _client.post(ApiConfig.api('/materiales/$materialId/reportes'), {
      'motivo': motivo,
    });
  }
}
