import '../config/api_config.dart';
import '../models/tutor_ia.dart';
import 'api_client.dart';

/// RF-14/RF-15/RF-16: consultas al Tutor IA sobre un material.
class TutorIaService {
  final String? token;
  TutorIaService(this.token);

  ApiClient get _client => ApiClient(token: token);

  Future<EstadoTutorIa> estado() async {
    final data = await _client.get(ApiConfig.api('/ia/estado'));
    return EstadoTutorIa.fromJson(data);
  }

  /// RF-14. Con [nueva] se pide otra explicación en vez de la guardada (R-10).
  Future<ExplicacionIa> explicar(int materialId, {bool nueva = false}) async {
    final data = await _client.post(
      ApiConfig.api('/materiales/$materialId/ia/explicacion'),
      {if (nueva) 'nueva': true},
    );
    return ExplicacionIa.fromJson(data);
  }

  /// RF-15. Con [nueva] se generan otras preguntas.
  Future<PracticaIa> practicar(int materialId, {bool nueva = false}) async {
    final data = await _client.post(
      ApiConfig.api('/materiales/$materialId/ia/practica'),
      {if (nueva) 'nueva': true},
    );
    return PracticaIa.fromJson(data);
  }

  /// RF-16. El historial viaja en cada pregunta: el servidor no guarda la
  /// conversación (R-11).
  Future<String> preguntar(int materialId, List<TurnoChat> historial, String pregunta) async {
    final data = await _client.post(
      ApiConfig.api('/materiales/$materialId/ia/preguntas'),
      {
        'pregunta': pregunta,
        'historial': [for (final t in historial) t.toJson()],
      },
    );
    return data['respuesta'] as String;
  }
}
