import '../config/api_config.dart';
import '../models/reporte.dart';
import 'api_client.dart';

/// RF-10: revisión y gestión de reportes por parte del administrador.
class ReporteService {
  final String? token;
  ReporteService(this.token);

  ApiClient get _client => ApiClient(token: token);

  Future<List<Reporte>> listar({String? estado}) async {
    final query = <String, String>{};
    if (estado != null) query['estado'] = estado;
    final data = await _client.get(ApiConfig.api('/reportes', query)) as List;
    return data.map((e) => Reporte.fromJson(e)).toList();
  }

  Future<void> actualizarEstado(int id, String estado) async {
    await _client.patch(ApiConfig.api('/reportes/$id'), {'estado': estado});
  }
}
