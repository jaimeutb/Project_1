class Asignatura {
  final int id;
  final String nombre;
  final String codigo;
  final String semestre;
  final bool activo; // RF-13: el administrador puede desactivarla
  final int totalMateriales;

  const Asignatura({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.semestre,
    this.activo = true,
    this.totalMateriales = 0,
  });

  factory Asignatura.fromJson(Map<String, dynamic> json) {
    return Asignatura(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      codigo: json['codigo'] as String,
      semestre: json['semestre'] as String,
      activo: json['activo'] as bool? ?? true,
      totalMateriales: json['total_materiales'] as int? ?? 0,
    );
  }

  // Dos asignaturas son la misma si tienen el mismo id (necesario para los
  // DropdownButton cuando la lista se vuelve a cargar desde el backend).
  @override
  bool operator ==(Object other) => other is Asignatura && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$nombre ($codigo · $semestre)';
}
