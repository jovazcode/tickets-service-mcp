import 'package:tickets_service_mcp/src/domain/impact.dart';
import 'package:tickets_service_mcp/src/domain/incident.dart';
import 'package:tickets_service_mcp/src/domain/incident_status.dart';

/// Criterios de orden del proceso de triaje (`docs://proceso_triaje`), en
/// el orden en que se aplican.
const triageCriteria = [
  'Solo incidencias activas (abierta o en_progreso)',
  'Impacto alto antes que bajo',
  'Sin alternativa temporal antes que con ella',
  'Más antigua primero (created)',
  'ID más bajo como último desempate',
];

/// Compara dos incidencias según [triageCriteria] (sin el filtro de
/// activas): negativo si [a] debe atenderse antes que [b].
int comparePriority(Incident a, Incident b) {
  int rank(bool first) => first ? 0 : 1;
  final byImpact = rank(a.impact == Impact.alto)
      .compareTo(rank(b.impact == Impact.alto));
  if (byImpact != 0) return byImpact;
  final byWorkaround = rank(!a.workaround).compareTo(rank(!b.workaround));
  if (byWorkaround != 0) return byWorkaround;
  final byCreated = a.created.compareTo(b.created);
  if (byCreated != 0) return byCreated;
  return _idNumber(a.id).compareTo(_idNumber(b.id));
}

int _idNumber(String id) => int.parse(id.substring(4));

/// Incidencias activas de [incidents], en el orden en que deben atenderse.
List<Incident> priorityQueue(Iterable<Incident> incidents) =>
    incidents.where((i) => i.status.isActive).toList()..sort(comparePriority);

/// {@template desk_summary}
/// Totales de la mesa.
/// {@endtemplate}
class DeskSummary {
  /// {@macro desk_summary}
  const new({
    required this.total,
    required this.active,
    required this.critical,
    required this.byStatus,
    required this.byImpact,
    required this.withWorkaround,
    this.oldestActive,
  });

  /// Número total de incidencias.
  final int total;

  /// Incidencias activas (`abierta` o `en_progreso`).
  final int active;

  /// Activas con impacto alto y sin alternativa temporal.
  final int critical;

  /// Recuento por estado, con todos los estados (aunque sea 0).
  final Map<IncidentStatus, int> byStatus;

  /// Recuento por impacto, con todos los impactos (aunque sea 0).
  final Map<Impact, int> byImpact;

  /// Incidencias con alternativa temporal.
  final int withWorkaround;

  /// La incidencia activa más antigua, si hay alguna.
  final Incident? oldestActive;

  /// Representación JSON.
  Map<String, dynamic> toJson() => {
    'total': total,
    'active': active,
    'critical': critical,
    'byStatus': {for (final e in byStatus.entries) e.key.value: e.value},
    'byImpact': {for (final e in byImpact.entries) e.key.value: e.value},
    'byWorkaround': {'con': withWorkaround, 'sin': total - withWorkaround},
    if (oldestActive case final oldest?)
      'oldestActive': {'id': oldest.id, 'created': oldest.created},
  };
}

/// Calcula los totales de [incidents].
DeskSummary summarize(Iterable<Incident> incidents) {
  final list = incidents.toList();
  final active = list.where((i) => i.status.isActive).toList();
  Incident? oldest;
  for (final incident in active) {
    if (oldest == null ||
        incident.created.compareTo(oldest.created) < 0 ||
        (incident.created == oldest.created &&
            _idNumber(incident.id) < _idNumber(oldest.id))) {
      oldest = incident;
    }
  }
  return DeskSummary(
    total: list.length,
    active: active.length,
    critical: active
        .where((i) => i.impact == Impact.alto && !i.workaround)
        .length,
    byStatus: {
      for (final status in IncidentStatus.values)
        status: list.where((i) => i.status == status).length,
    },
    byImpact: {
      for (final impact in Impact.values)
        impact: list.where((i) => i.impact == impact).length,
    },
    withWorkaround: list.where((i) => i.workaround).length,
    oldestActive: oldest,
  );
}
