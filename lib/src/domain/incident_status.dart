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

  /// Si la incidencia sigue pendiente (`abierta` o `en_progreso`).
  bool get isActive => this != resuelta;

  /// Estados a los que se puede pasar desde este.
  ///
  /// - `abierta` → `en_progreso` o `resuelta`.
  /// - `en_progreso` → `resuelta`, o de vuelta a `abierta`.
  /// - `resuelta` → `abierta` (reabrir; exige motivo).
  Set<IncidentStatus> get allowedNext => switch (this) {
    abierta => const {enProgreso, resuelta},
    enProgreso => const {abierta, resuelta},
    resuelta => const {abierta},
  };

  /// Si pasar de este estado a [next] es reabrir una incidencia resuelta.
  bool isReopening(IncidentStatus next) => this == resuelta && next.isActive;

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
