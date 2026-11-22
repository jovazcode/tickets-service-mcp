import 'package:tickets_service_mcp/src/domain/impact.dart';
import 'package:tickets_service_mcp/src/domain/incident_status.dart';

/// Formato válido de un identificador de incidencia (`INC-` y 3+ dígitos).
final incidentIdPattern = RegExp(r'^INC-\d{3,}$');

/// {@template incident}
/// Incidencia de la mesa.
/// {@endtemplate}
class Incident {
  /// {@macro incident}
  const new({
    required this.id,
    required this.title,
    required this.status,
    required this.impact,
    required this.workaround,
    required this.created,
    required this.detail,
    this.revision = 1,
  });

  /// Crea una incidencia a partir de su representación JSON.
  ///
  /// Lanza [FormatException] si falta un campo o tiene un tipo o valor
  /// inválido.
  factory fromJson(Map<String, dynamic> json) {
    T field<T>(String name) {
      final value = json[name];
      if (value is! T) {
        throw FormatException('Campo "$name" ausente o inválido: $value');
      }
      return value;
    }

    final id = field<String>('id');
    if (!incidentIdPattern.hasMatch(id)) {
      throw FormatException('ID con formato inválido: $id');
    }
    final created = field<String>('created');
    if (DateTime.tryParse(created) == null) {
      throw FormatException('Fecha "created" inválida: $created');
    }
    final revision = json['revision'] ?? 1;
    if (revision is! int || revision < 1) {
      throw FormatException('Revisión inválida: $revision');
    }
    return Incident(
      id: id,
      title: field<String>('title'),
      status: IncidentStatus.parse(json['status']),
      impact: Impact.parse(json['impact']),
      workaround: field<bool>('workaround'),
      created: created,
      detail: field<String>('detail'),
      revision: revision,
    );
  }

  /// Identificador único, con formato `INC-123`.
  final String id;

  /// Resumen breve del problema.
  final String title;

  /// Estado actual.
  final IncidentStatus status;

  /// Impacto operativo evaluado.
  final Impact impact;

  /// Si existe una alternativa temporal para seguir trabajando.
  final bool workaround;

  /// Fecha de apertura en formato ISO `YYYY-MM-DD`.
  final String created;

  /// Descripción completa.
  final String detail;

  /// Número de versión: empieza en 1 y sube con cada cambio. Sirve para
  /// detectar ediciones concurrentes.
  final int revision;

  /// Devuelve una copia con los campos indicados cambiados.
  Incident copyWith({
    String? title,
    IncidentStatus? status,
    Impact? impact,
    bool? workaround,
    String? detail,
    int? revision,
  }) => Incident(
    id: id,
    title: title ?? this.title,
    status: status ?? this.status,
    impact: impact ?? this.impact,
    workaround: workaround ?? this.workaround,
    created: created,
    detail: detail ?? this.detail,
    revision: revision ?? this.revision,
  );

  /// Representación JSON: los campos de la fixture más `revision`.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status.value,
    'impact': impact.value,
    'workaround': workaround,
    'created': created,
    'detail': detail,
    'revision': revision,
  };
}
