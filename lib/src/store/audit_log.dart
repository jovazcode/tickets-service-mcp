import 'dart:convert';
import 'dart:io';

import 'package:tickets_service_mcp/src/domain/audit_event.dart';

/// {@template audit_log}
/// Registro de auditoría append-only en formato JSON Lines: un evento por
/// línea. Nunca se reescriben ni borran líneas.
/// {@endtemplate}
class AuditLog {
  /// {@macro audit_log}
  ///
  /// Los avisos sobre líneas ilegibles se escriben en [warnings] (por
  /// defecto, [stderr]: stdout queda reservado para JSON-RPC).
  const new(this.path, {this.warnings});

  /// Ruta del fichero `.jsonl`.
  final String path;

  /// Destino de los avisos; si es `null`, se usa [stderr].
  final StringSink? warnings;

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
  /// Las líneas que no se pueden leer (por ejemplo, una última línea a
  /// medias o un fichero formateado de nuevo con sangría) se ignoran, para
  /// que un fallo puntual no oculte el resto, pero cada una genera un aviso
  /// con su número de línea.
  Future<List<AuditEvent>> eventsFor(String id) async {
    final file = File(path);
    if (!file.existsSync()) return const [];
    final events = <AuditEvent>[];
    final lines = await file.readAsLines();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('no es un objeto JSON');
        }
        final event = AuditEvent.fromJson(decoded);
        if (event.id == id) events.add(event);
      } on FormatException catch (error) {
        (warnings ?? stderr).writeln(
          '[audit] Línea ${index + 1} ilegible en $path, ignorada: '
          '${error.message}',
        );
      }
    }
    return events;
  }
}
