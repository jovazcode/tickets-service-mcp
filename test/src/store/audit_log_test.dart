import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

AuditEvent event(String id, String timestamp) => AuditEvent(
  timestamp: timestamp,
  operation: AuditOperation.eliminar,
  id: id,
  reason: 'r',
);

void main() {
  late Directory tempDir;
  late AuditLog log;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audit_test');
    log = AuditLog(p.join(tempDir.path, 'sub', 'audit.jsonl'));
  });

  tearDown(() => tempDir.delete(recursive: true));

  test('sin fichero no hay eventos', () async {
    expect(await log.eventsFor('INC-101'), isEmpty);
  });

  test('añade al final y filtra por incidencia en orden', () async {
    await log.append(event('INC-101', '1'));
    await log.append(event('INC-102', '2'));
    await log.append(event('INC-101', '3'));
    final events = await log.eventsFor('INC-101');
    expect(events.map((e) => e.timestamp), ['1', '3']);
    expect(File(log.path).readAsLinesSync(), hasLength(3));
  });

  test('ignora líneas vacías o ilegibles', () async {
    await log.append(event('INC-101', '1'));
    await File(
      log.path,
    ).writeAsString('\n[1]\n{"roto"\n{"timestamp":1}\n', mode: FileMode.append);
    await log.append(event('INC-101', '2'));
    expect((await log.eventsFor('INC-101')).map((e) => e.timestamp), [
      '1',
      '2',
    ]);
  });
}
