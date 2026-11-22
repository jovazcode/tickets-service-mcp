import 'package:tickets_service_mcp/src/domain/domain_exception.dart';
import 'package:tickets_service_mcp/src/domain/impact.dart';
import 'package:tickets_service_mcp/src/domain/incident.dart';
import 'package:tickets_service_mcp/src/domain/incident_status.dart';
import 'package:tickets_service_mcp/src/domain/text_rules.dart';

/// {@template incident_patch}
/// Cambios a aplicar sobre una incidencia. Los campos `null` no cambian.
/// {@endtemplate}
class IncidentPatch {
  /// {@macro incident_patch}
  const new({
    this.title,
    this.detail,
    this.status,
    this.impact,
    this.workaround,
  });

  /// Nuevo título.
  final String? title;

  /// Nuevo detalle.
  final String? detail;

  /// Nuevo estado.
  final IncidentStatus? status;

  /// Nuevo impacto.
  final Impact? impact;

  /// Nuevo valor de alternativa temporal.
  final bool? workaround;

  /// Si no cambia ningún campo.
  bool get isEmpty =>
      title == null &&
      detail == null &&
      status == null &&
      impact == null &&
      workaround == null;

  /// Aplica los cambios a [incident] y sube su revisión.
  ///
  /// Lanza [DomainException] con código `VALIDATION_ERROR` si no hay cambios
  /// o si el título o el detalle no son válidos.
  Incident applyTo(Incident incident) {
    if (isEmpty) {
      throw const DomainException(
        'VALIDATION_ERROR',
        'Indica al menos un campo a cambiar',
      );
    }
    final title = this.title;
    final detail = this.detail;
    return incident.copyWith(
      title: title == null ? null : checkText('title', title, maxTitleLength),
      detail: detail == null
          ? null
          : checkText('detail', detail, maxDetailLength),
      status: status,
      impact: impact,
      workaround: workaround,
      revision: incident.revision + 1,
    );
  }
}
