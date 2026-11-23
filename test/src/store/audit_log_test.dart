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
  late StringBuffer warnings;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audit_test');
    warnings = StringBuffer();
    log = AuditLog(
      p.join(tempDir.path, 'sub', 'audit.jsonl'),
      warnings: warnings,
    );
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

  test('ignora líneas vacías o ilegibles y avisa de las ilegibles', () async {
    await log.append(event('INC-101', '1'));
    await File(
      log.path,
    ).writeAsString('\n[1]\n{"roto"\n{"timestamp":1}\n', mode: FileMode.append);
    await log.append(event('INC-101', '2'));
    expect((await log.eventsFor('INC-101')).map((e) => e.timestamp), [
      '1',
      '2',
    ]);
    final lines = warnings.toString().trim().split('\n');
    expect(lines, hasLength(3));
    expect(lines[0], allOf(startsWith('[audit] Línea 3 '), contains(log.path)));
    expect(lines[0], endsWith('no es un objeto JSON'));
    expect(lines[1], startsWith('[audit] Línea 4 '));
    expect(lines[2], allOf(startsWith('[audit] Línea 5 '), contains('{')));
  });

  test('sin warnings explícito avisa por stderr', () async {
    final stderrBuffer = _BufferStdout();
    final defaultLog = AuditLog(log.path);
    await log.append(event('INC-101', '1'));
    await File(log.path).writeAsString('{\n', mode: FileMode.append);
    final events = await IOOverrides.runZoned(
      () => defaultLog.eventsFor('INC-101'),
      stderr: () => stderrBuffer,
    );
    expect(events, hasLength(1));
    expect(stderrBuffer.text, startsWith('[audit] Línea 2 '));
  });
}

class _BufferStdout implements Stdout {
  final _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
