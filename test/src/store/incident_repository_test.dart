import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

void main() {
  group('IncidentRepository', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('repo_test');
    });

    tearDown(() => tempDir.delete(recursive: true));

    Future<String> writeData(String content) async {
      final file = File(p.join(tempDir.path, 'tickets.json'));
      await file.writeAsString(content);
      return file.path;
    }

    test('load lee la fixture del proyecto', () async {
      final repository = await IncidentRepository.load('data/tickets.json');
      expect(repository.all.map((i) => i.id), [
        'INC-101',
        'INC-102',
        'INC-103',
        'INC-104',
      ]);
    });

    test('load rechaza un JSON que no es un array', () async {
      final path = await writeData('{}');
      expect(IncidentRepository.load(path), throwsFormatException);
    });

    test('load rechaza elementos que no son objetos', () async {
      final path = await writeData('[1]');
      expect(IncidentRepository.load(path), throwsFormatException);
    });

    test('load falla si el fichero no existe', () {
      expect(
        IncidentRepository.load(p.join(tempDir.path, 'no_existe.json')),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('rechaza IDs duplicados', () {
      const incident = Incident(
        id: 'INC-101',
        title: 't',
        status: IncidentStatus.abierta,
        impact: Impact.bajo,
        workaround: false,
        created: '2026-09-01',
        detail: 'd',
      );
      expect(
        () => IncidentRepository([incident, incident]),
        throwsFormatException,
      );
    });

    test('getById devuelve la incidencia o NOT_FOUND', () async {
      final repository = await IncidentRepository.load('data/tickets.json');
      expect(
        repository.getById('INC-104').title,
        'La exportación se interrumpe',
      );
      expect(
        () => repository.getById('INC-999'),
        throwsA(
          isA<DomainException>().having((e) => e.code, 'code', 'NOT_FOUND'),
        ),
      );
    });
  });
}
