import 'dart:convert';
import 'dart:io';

import 'package:tickets_service_mcp/src/domain/audit_event.dart';

/// {@template audit_log}
/// Registro de auditoría append-only en formato JSON Lines: un evento por
/// línea. Nunca se reescriben ni borran líneas.
/// {@endtemplate}
class AuditLog {
  /// {@macro audit_log}
  const new(this.path);

  /// Ruta del fichero `.jsonl`.
  final String path;

  /// Añade [event] al final del fichero, creándolo si no existe.
  ///
  /// Lanza [FileSystemException] si no se puede escribir.
  Future<void> append(AuditEvent event) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(event.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  /// Eventos de la incidencia [id], del más antiguo al más reciente.
  ///
  /// Las líneas que no se pueden leer se ignoran (por ejemplo, una última
  /// línea a medias), para que un fallo puntual no oculte el resto.
  Future<List<AuditEvent>> eventsFor(String id) async {
    final file = File(path);
    if (!file.existsSync()) return const [];
    final events = <AuditEvent>[];
    for (final line in await file.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map<String, dynamic>) continue;
        final event = AuditEvent.fromJson(decoded);
        if (event.id == id) events.add(event);
      } on FormatException {
        continue;
      }
    }
    return events;
  }
}
