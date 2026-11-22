import 'package:tickets_service_mcp/src/domain/incident.dart';

/// Tipo de operación registrada en la auditoría.
enum AuditOperation {
  /// Alta de una incidencia.
  crear('crear'),

  /// Cambio de campos con `actualizar_incidencia`.
  actualizar('actualizar'),

  /// Cambio de estado.
  cambiarEstado('cambiar_estado'),

  /// Borrado físico.
  eliminar('eliminar');

  new(this.value);

  /// Valor serializado en JSON.
  final String value;

  /// Todos los valores serializados, en orden de declaración.
  static List<String> get wireValues => [for (final o in values) o.value];

  /// Devuelve la [AuditOperation] cuyo [value] es [raw].
  ///
  /// Lanza [FormatException] si [raw] no es una operación conocida.
  static AuditOperation parse(Object? raw) => values.firstWhere(
    (operation) => operation.value == raw,
    orElse: () => throw FormatException('Operación desconocida: $raw'),
  );
}

/// {@template audit_event}
/// Registro inmutable de un cambio en una incidencia.
/// {@endtemplate}
class AuditEvent {
  /// {@macro audit_event}
  const new({
    required this.timestamp,
    required this.operation,
    required this.id,
    this.reason,
    this.changes = const {},
    this.snapshot,
  });

  /// Crea el evento que describe el paso de [before] a [after].
  ///
  /// En altas [before] es `null` y en borrados [after] es `null`; en ambos
  /// casos se guarda la ficha completa en [snapshot]. En el resto se guardan
  /// solo los campos que cambian (sin contar `revision`).
  factory between({
    required String timestamp,
    required AuditOperation operation,
    required Incident? before,
    required Incident? after,
    String? reason,
  }) {
    final incident = (after ?? before)!;
    final changes = <String, Map<String, Object?>>{};
    if (before != null && after != null) {
      final from = before.toJson();
      final to = after.toJson();
      for (final key in to.keys) {
        if (key != 'revision' && from[key] != to[key]) {
          changes[key] = {'from': from[key], 'to': to[key]};
        }
      }
    }
    return AuditEvent(
      timestamp: timestamp,
      operation: operation,
      id: incident.id,
      reason: reason,
      changes: changes,
      snapshot: before == null || after == null ? incident : null,
    );
  }

  /// Lee un evento de su representación JSON.
  ///
  /// Lanza [FormatException] si no es válido.
  factory fromJson(Map<String, dynamic> json) {
    final timestamp = json['timestamp'];
    final id = json['id'];
    final reason = json['reason'];
    final changes = json['changes'] ?? const <String, dynamic>{};
    final snapshot = json['snapshot'];
    if (timestamp is! String ||
        id is! String ||
        (reason != null && reason is! String) ||
        changes is! Map<String, dynamic> ||
        changes.values.any((change) => change is! Map<String, dynamic>) ||
        (snapshot != null && snapshot is! Map<String, dynamic>)) {
      throw FormatException('Evento de auditoría inválido: $json');
    }
    return AuditEvent(
      timestamp: timestamp,
      operation: AuditOperation.parse(json['operation']),
      id: id,
      reason: reason as String?,
      changes: {
        for (final entry in changes.entries)
          entry.key: Map<String, Object?>.from(
            entry.value as Map<String, dynamic>,
          ),
      },
      snapshot: snapshot == null
          ? null
          : Incident.fromJson(snapshot as Map<String, dynamic>),
    );
  }

  /// Momento del cambio, en ISO 8601 UTC.
  final String timestamp;

  /// Qué se hizo.
  final AuditOperation operation;

  /// ID de la incidencia afectada.
  final String id;

  /// Motivo indicado, si lo hay (borrados y reaperturas).
  final String? reason;

  /// Campos cambiados: `{campo: {from, to}}`.
  final Map<String, Map<String, Object?>> changes;

  /// Ficha completa tras el alta o antes del borrado.
  final Incident? snapshot;

  /// Representación JSON (una línea del fichero de auditoría).
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'operation': operation.value,
    'id': id,
    if (reason != null) 'reason': reason,
    if (changes.isNotEmpty) 'changes': changes,
    if (snapshot case final incident?) 'snapshot': incident.toJson(),
  };
}
