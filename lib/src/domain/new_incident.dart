import 'package:tickets_service_mcp/src/domain/impact.dart';
import 'package:tickets_service_mcp/src/domain/text_rules.dart';

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
  /// Lanza `DomainException` con código `VALIDATION_ERROR` si el título o el
  /// detalle están vacíos o superan su longitud máxima.
  NewIncident validated() => NewIncident(
    title: checkText('title', title, maxTitleLength),
    detail: checkText('detail', detail, maxDetailLength),
    impact: impact,
    workaround: workaround,
  );
}
