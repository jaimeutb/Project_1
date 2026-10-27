import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as flutter show Material;

import '../models/asignatura.dart';
import '../models/material.dart';
import '../services/api_client.dart';
import '../services/material_service.dart';
import '../theme/utb_theme.dart';
import 'material_card.dart' show MiniaturaMaterial;

/// R-02: tipos y tamaño de archivo que acepta el servidor.
const extensionesPermitidas = {'pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx', 'zip'};
const tamanoMaximoArchivo = 25 * 1024 * 1024; // 25 MB
const textoArchivosPermitidos = 'PDF, imagen (PNG o JPG), Word o ZIP; máx. 25 MB.';

/// Revisa el archivo elegido antes de subirlo, para avisar de inmediato (H-06).
/// Devuelve el mensaje de error, o null si el archivo se puede subir.
String? validarArchivo(String nombre, int bytes) {
  final punto = nombre.lastIndexOf('.');
  final extension = punto < 0 ? '' : nombre.substring(punto + 1).toLowerCase();
  if (!extensionesPermitidas.contains(extension)) {
    return 'Tipo de archivo no permitido: use PDF, imagen (PNG o JPG), Word o ZIP.';
  }
  if (bytes > tamanoMaximoArchivo) return 'El archivo supera el máximo de 25 MB.';
  return null;
}

enum _Paso { formulario, revisando, resultado }

/// Formulario de carga de material (RF-06/RF-07/RF-11). Al subirlo, la IA lo
/// revisa (RF-17) y el diálogo muestra el resultado: publicado, pendiente de un
/// administrador o rechazado con el motivo. Devuelve el material creado, o null
/// si se cancela o se rechaza.
class DialogoSubirMaterial extends StatefulWidget {
  final List<Asignatura> asignaturas;
  final String? token;
  const DialogoSubirMaterial({super.key, required this.asignaturas, required this.token});

  @override
  State<DialogoSubirMaterial> createState() => _DialogoSubirMaterialState();
}

class _DialogoSubirMaterialState extends State<DialogoSubirMaterial> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _profesorCtrl = TextEditingController();
  final _periodoCtrl = TextEditingController();
  Asignatura? _asignatura;
  bool _anonimo = false;
  PlatformFile? _archivo;
  String? _error;

  _Paso _paso = _Paso.formulario;
  Material? _publicado;
  RevisionIa? _revision; // la del material publicado o la del rechazo

  bool get _esImagen =>
      ['png', 'jpg', 'jpeg'].contains(_archivo?.extension?.toLowerCase());

  Future<void> _elegirArchivo() async {
    final resultado = await FilePicker.platform.pickFiles(withData: true);
    if (resultado == null || resultado.files.isEmpty) return;
    final archivo = resultado.files.first;
    final error = validarArchivo(archivo.name, archivo.size);
    setState(() {
      _archivo = error == null ? archivo : null;
      _error = error;
    });
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate() || _asignatura == null) return;
    if (_archivo == null || _archivo!.bytes == null) {
      setState(() => _error = 'Seleccione un archivo.');
      return;
    }
    setState(() {
      _paso = _Paso.revisando;
      _error = null;
    });

    try {
      final nuevo = await MaterialService(widget.token).subir(
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        asignaturaId: _asignatura!.id,
        profesor: _profesorCtrl.text.trim(),
        periodoAcademico: _periodoCtrl.text.trim(),
        esAnonimo: _anonimo,
        archivoBytes: _archivo!.bytes!,
        nombreArchivo: _archivo!.name,
      );
      if (!mounted) return;
      // Sin IA configurada no hay revisión que mostrar: se cierra directamente.
      if (nuevo.revisionIa == null) {
        Navigator.of(context).pop(nuevo);
        return;
      }
      setState(() {
        _publicado = nuevo;
        _revision = nuevo.revisionIa;
        _paso = _Paso.resultado;
      });
    } on ApiException catch (e) {
      final revision = e.datos['revision'];
      setState(() {
        if (e.statusCode == 422 && revision is Map<String, dynamic>) {
          _revision = RevisionIa.fromJson(revision);
          _publicado = null;
          _paso = _Paso.resultado;
        } else {
          _error = e.mensaje;
          _paso = _Paso.formulario;
        }
      });
    } catch (_) {
      setState(() {
        _error = 'No fue posible conectar con el servidor.';
        _paso = _Paso.formulario;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_paso) {
      _Paso.formulario => _formulario(),
      _Paso.revisando => const _Revisando(),
      _Paso.resultado => _resultado(),
    };
  }

  // ---------------------------------------------------------------- formulario
  Widget _formulario() {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.upload_file, color: UtbColores.verde),
          SizedBox(width: 10),
          Flexible(child: Text('Subir material', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // H-05: el interruptor va primero para que el teclado del celular
                // no lo tape mientras se completan los campos de texto.
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Subir de forma anónima'),
                  subtitle: const Text('Su nombre no se mostrará en el material.'),
                  value: _anonimo,
                  onChanged: (v) => setState(() => _anonimo = v),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tituloCtrl,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<Asignatura>(
                  isExpanded: true,
                  // ignore: deprecated_member_use
                  value: _asignatura,
                  decoration: const InputDecoration(labelText: 'Asignatura'),
                  items: widget.asignaturas
                      .map((a) => DropdownMenuItem(value: a, child: Text(a.toString())))
                      .toList(),
                  onChanged: (v) => setState(() => _asignatura = v),
                  validator: (v) => v == null ? 'Requerido.' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _profesorCtrl,
                        decoration: const InputDecoration(labelText: 'Profesor (opcional)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _periodoCtrl,
                        decoration: const InputDecoration(labelText: 'Periodo (ej. 2026-2)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SelectorDeArchivo(
                  archivo: _archivo,
                  esImagen: _esImagen,
                  onElegir: _elegirArchivo,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    textoArchivosPermitidos,
                    style: TextStyle(fontSize: 12, color: UtbColores.textoSecundario),
                  ),
                ),
                const SizedBox(height: 10),
                const _AvisoRevision(),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: UtbColores.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _enviar, child: const Text('Subir')),
      ],
    );
  }

  // ---------------------------------------------------------------- resultado
  Widget _resultado() {
    final r = _revision!;
    final publicado = _publicado;
    final rechazado = publicado == null;
    final pendiente = publicado?.estado == 'pendiente';
    final (icono, color, fondo, titulo) = rechazado
        ? (Icons.block, UtbColores.error, UtbColores.error10, 'La IA no aprobó el material')
        : pendiente
            ? (Icons.hourglass_top, const Color(0xFF8A5A00), UtbColores.ambar10,
                'Quedó pendiente de revisión')
            : (Icons.verified, UtbColores.verde, UtbColores.verde10, '¡Material publicado!');

    return AlertDialog(
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icono, color: color, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16, color: color)),
                          const SizedBox(height: 4),
                          Text(
                            pendiente
                                ? '${r.motivo} Mientras tanto, solo usted y el administrador lo ven.'
                                : r.motivo,
                            style: const TextStyle(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (publicado != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: MiniaturaMaterial(material: publicado),
                  ),
                ),
              ],
              if (r.criterios.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Lo que revisó la IA',
                    style: TextStyle(fontWeight: FontWeight.w800, color: UtbColores.azulOscuro)),
                const SizedBox(height: 6),
                for (final (clave, texto, esperado) in const [
                  ('es_material_academico', 'Es material académico', true),
                  ('coincide_con_asignatura', 'Corresponde a la asignatura', true),
                  ('coincide_con_titulo', 'El título describe el contenido', true),
                  ('legible', 'Se puede leer', true),
                  ('contenido_inapropiado', 'Sin contenido inapropiado', false),
                  ('datos_personales', 'Sin datos personales de otras personas', false),
                ])
                  if (r.criterios.containsKey(clave))
                    _Criterio(texto, cumple: r.criterios[clave] == esperado),
              ],
              if (!rechazado && (r.temas.isNotEmpty || r.tipo != 'otro')) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (r.tipo != 'otro')
                    Etiqueta(r.tipoVisible, color: Colors.white, fondo: UtbColores.azul),
                  if (r.dificultadVisible != null)
                    Etiqueta('Dificultad ${r.dificultadVisible!.toLowerCase()}',
                        color: UtbColores.azulOscuro, fondo: UtbColores.azul10),
                  for (final t in r.temas)
                    Etiqueta(t, color: UtbColores.verdeOscuro, fondo: UtbColores.verde10),
                ]),
              ],
            ],
          ),
        ),
      ),
      actions: rechazado
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
              FilledButton.icon(
                onPressed: () => setState(() => _paso = _Paso.formulario),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Corregir y reintentar'),
              ),
            ]
          : [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(publicado),
                child: const Text('Listo'),
              ),
            ],
    );
  }
}

class _SelectorDeArchivo extends StatelessWidget {
  final PlatformFile? archivo;
  final bool esImagen;
  final VoidCallback onElegir;

  const _SelectorDeArchivo({required this.archivo, required this.esImagen, required this.onElegir});

  @override
  Widget build(BuildContext context) {
    final a = archivo;
    if (a == null) {
      return OutlinedButton.icon(
        onPressed: onElegir,
        icon: const Icon(Icons.attach_file),
        label: const Text('Elegir archivo'),
      );
    }
    final kb = a.size / 1024;
    final tamano = kb > 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '${kb.toStringAsFixed(0)} KB';
    return flutter.Material(
      color: UtbColores.fondo,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onElegir,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vista previa inmediata de las imágenes; los PDF la tienen al publicarse.
            if (esImagen && a.bytes != null)
              SizedBox(height: 150, child: Image.memory(a.bytes!, fit: BoxFit.cover)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(esImagen ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
                      color: UtbColores.azul),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(tamano,
                            style: const TextStyle(
                                fontSize: 12, color: UtbColores.textoSecundario)),
                      ],
                    ),
                  ),
                  const Text('Cambiar',
                      style: TextStyle(color: UtbColores.verde, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explica, antes de subir, que la IA revisará el material (RF-17).
class _AvisoRevision extends StatelessWidget {
  const _AvisoRevision();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UtbColores.azul10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: UtbColores.azul),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'La IA revisa que el archivo sea material académico de la asignatura elegida '
              'antes de publicarlo. Si tiene dudas, lo revisa un administrador.',
              style: TextStyle(fontSize: 12.5, color: UtbColores.azulOscuro, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _Revisando extends StatelessWidget {
  const _Revisando();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: CircularProgressIndicator()),
            SizedBox(height: 18),
            Center(
              child: Text('Subiendo y revisando tu material…',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            SizedBox(height: 14),
            _Paso1(Icons.school_outlined, '¿Es material académico?'),
            _Paso1(Icons.menu_book_outlined, '¿Corresponde a la asignatura y al título?'),
            _Paso1(Icons.visibility_outlined, '¿Se puede leer bien?'),
            _Paso1(Icons.image_outlined, 'Creando la vista previa'),
          ],
        ),
      ),
    );
  }
}

class _Paso1 extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Paso1(this.icono, this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icono, size: 18, color: UtbColores.azul),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(color: UtbColores.textoSecundario))),
        ],
      ),
    );
  }
}

class _Criterio extends StatelessWidget {
  final String texto;
  final bool cumple;
  const _Criterio(this.texto, {required this.cumple});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(cumple ? Icons.check_circle : Icons.cancel,
              size: 18, color: cumple ? UtbColores.verde : UtbColores.error),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
