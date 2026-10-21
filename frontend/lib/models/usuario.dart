/// Corresponde a la clase Usuario (y sus subtipos Estudiante/Administrador)
/// del diagrama de clases — ver docs/diagramas/02-clases.png.
class Usuario {
  final int id;
  final String nombre;
  final String correo;
  final String rol; // 'estudiante' | 'administrador'
  final bool activo; // RF-13: el administrador puede desactivar la cuenta

  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.activo = true,
  });

  bool get esAdministrador => rol == 'administrador';

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      correo: json['correo'] as String,
      rol: json['rol'] as String,
      activo: json['activo'] as bool? ?? true,
    );
  }
}
