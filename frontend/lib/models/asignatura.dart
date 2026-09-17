class Asignatura {
  final int id;
  final String nombre;
  final String codigo;
  final String semestre;

  const Asignatura({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.semestre,
  });

  factory Asignatura.fromJson(Map<String, dynamic> json) {
    return Asignatura(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      codigo: json['codigo'] as String,
      semestre: json['semestre'] as String,
    );
  }

  @override
  String toString() => '$nombre ($codigo · $semestre)';
}
