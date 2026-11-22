import 'package:tickets_service_mcp/src/domain/domain_exception.dart';
import 'package:tickets_service_mcp/src/domain/impact.dart';

/// {@template new_incident}
/// Datos que aporta quien abre una incidencia. El ID, la fecha y el estado
/// inicial los asigna el repositorio.
/// {@endtemplate}
class NewIncident {
  /// {@macro new_incident}
  const new({
    required this.title,
    required this.detail,
    required this.impact,
    this.workaround = false,
  });

  /// Longitud máxima del título.
  static const maxTitleLength = 200;

  /// Longitud máxima del detalle.
  static const maxDetailLength = 5000;

  /// Resumen breve del problema.
  final String title;

  /// Descripción completa.
  final String detail;

  /// Impacto operativo evaluado.
  final Impact impact;

  /// Si existe una alternativa temporal para seguir trabajando.
  final bool workaround;

  /// Devuelve una copia con el texto recortado y comprobado.
  ///
  /// Lanza [DomainException] con código `VALIDATION_ERROR` si el título o el
  /// detalle están vacíos o superan su longitud máxima.
  NewIncident validated() {
    String check(String field, String value, int max) {
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

    return NewIncident(
      title: check('title', title, maxTitleLength),
      detail: check('detail', detail, maxDetailLength),
      impact: impact,
      workaround: workaround,
    );
  }
}
