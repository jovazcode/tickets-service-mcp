import 'package:tickets_service_mcp/src/domain/domain_exception.dart';

/// Longitud máxima del título de una incidencia.
const maxTitleLength = 200;

/// Longitud máxima del detalle de una incidencia.
const maxDetailLength = 5000;

/// Longitud máxima del motivo de un borrado.
const maxReasonLength = 500;

/// Recorta [value] y comprueba que no esté vacío ni supere [max] caracteres.
///
/// Lanza [DomainException] con código `VALIDATION_ERROR` en otro caso.
String checkText(String field, String value, int max) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw DomainException('VALIDATION_ERROR', 'El campo $field está vacío');
  }
  if (trimmed.length > max) {
    throw DomainException(
      'VALIDATION_ERROR',
      'El campo $field supera $max caracteres',
    );
  }
  return trimmed;
}
