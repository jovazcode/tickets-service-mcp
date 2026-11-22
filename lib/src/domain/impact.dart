/// Impacto operativo de una incidencia.
enum Impact {
  /// Afecta a muchas personas o bloquea un proceso crítico.
  alto('alto'),

  /// Afecta a pocas personas o tiene un efecto menor.
  bajo('bajo');

  new(this.value);

  /// Valor serializado en JSON.
  final String value;

  /// Todos los valores serializados, en orden de declaración.
  static List<String> get wireValues => [for (final i in values) i.value];

  /// Devuelve el [Impact] cuyo [value] es [raw].
  ///
  /// Lanza [FormatException] si [raw] no es un impacto conocido.
  static Impact parse(Object? raw) => values.firstWhere(
    (impact) => impact.value == raw,
    orElse: () => throw FormatException('Impacto desconocido: $raw'),
  );
}
