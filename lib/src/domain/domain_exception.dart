/// {@template domain_exception}
/// Error de negocio esperado, con un [code] estable que el cliente puede
/// interpretar (por ejemplo `NOT_FOUND`).
/// {@endtemplate}
class DomainException implements Exception {
  /// {@macro domain_exception}
  const new(this.code, this.message);

  /// Código estable del error, en mayúsculas.
  final String code;

  /// Explicación legible del error.
  final String message;

  @override
  String toString() => '$code: $message';
}
