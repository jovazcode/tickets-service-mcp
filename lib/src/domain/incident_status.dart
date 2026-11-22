/// Estado del ciclo de vida de una incidencia.
enum IncidentStatus {
  /// Registrada y pendiente de atender.
  abierta('abierta'),

  /// Alguien está trabajando en ella.
  enProgreso('en_progreso'),

  /// Solucionada.
  resuelta('resuelta');

  new(this.value);

  /// Valor serializado en JSON.
  final String value;

  /// Todos los valores serializados, en orden de declaración.
  static List<String> get wireValues => [for (final s in values) s.value];

  /// Devuelve el [IncidentStatus] cuyo [value] es [raw].
  ///
  /// Lanza [FormatException] si [raw] no es un estado conocido.
  static IncidentStatus parse(Object? raw) => values.firstWhere(
    (status) => status.value == raw,
    orElse: () => throw FormatException('Estado desconocido: $raw'),
  );
}
