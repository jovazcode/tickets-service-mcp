import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

const fixturePath = 'data/tickets.json';

Matcher throwsDomain(String code) =>
    throwsA(isA<DomainException>().having((e) => e.code, 'code', code));

Incident incident(String id) => Incident(
  id: id,
  title: 't',
  status: IncidentStatus.abierta,
  impact: Impact.bajo,
  workaround: false,
  created: '2026-09-01',
  detail: 'd',
);

const draft = NewIncident(
  title: '  Falla la impresión  ',
  detail: '  Ninguna cuenta puede imprimir  ',
  impact: Impact.alto,
);

void main() {
  late Directory tempDir;
  late String storePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('repo_test');
    storePath = p.join(tempDir.path, 'store', 'tickets.local.json');
  });

  tearDown(() => tempDir.delete(recursive: true));

  Future<IncidentRepository> openRepo({bool writeEnabled = true}) =>
      IncidentRepository.open(
        fixturePath: fixturePath,
        storePath: storePath,
        writeEnabled: writeEnabled,
        clock: () => DateTime(2026, 11, 22, 10),
      );

  Future<String> writeFile(String name, String content) async {
    final file = File(p.join(tempDir.path, name));
    await file.writeAsString(content);
    return file.path;
  }

  group('open', () {
    test('sin almacén lee la fixture', () async {
      final repository = await openRepo();
      expect(repository.all.map((i) => i.id), [
        'INC-101',
        'INC-102',
        'INC-103',
        'INC-104',
      ]);
      expect(File(storePath).existsSync(), isFalse);
    });

    test(
      'con almacén lo prefiere a la fixture, incluso en solo lectura',
      () async {
        await File(storePath).parent.create(recursive: true);
        await File(storePath).writeAsString(
          jsonEncode({
            'nextId': 120,
            'incidents': [incident('INC-110').toJson()],
          }),
        );
        final repository = await openRepo(writeEnabled: false);
        expect(repository.all.single.id, 'INC-110');
        expect(repository.writeEnabled, isFalse);
      },
    );

    test('rechaza una fixture que no es un array', () async {
      final path = await writeFile('bad.json', '{}');
      expect(
        IncidentRepository.open(fixturePath: path, storePath: storePath),
        throwsFormatException,
      );
    });

    test('rechaza elementos que no son objetos', () async {
      final path = await writeFile('bad.json', '[1]');
      expect(
        IncidentRepository.open(fixturePath: path, storePath: storePath),
        throwsFormatException,
      );
    });

    test('rechaza un almacén con formato inválido', () async {
      final path = await writeFile('store.json', '[]');
      expect(
        IncidentRepository.open(fixturePath: fixturePath, storePath: path),
        throwsFormatException,
      );
    });

    test('falla si la fixture no existe', () {
      expect(
        IncidentRepository.open(
          fixturePath: p.join(tempDir.path, 'no_existe.json'),
          storePath: storePath,
        ),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('constructor', () {
    test('rechaza IDs duplicados', () {
      expect(
        () => IncidentRepository([incident('INC-101'), incident('INC-101')]),
        throwsFormatException,
      );
    });

    test('rechaza un nextId que no supera los IDs existentes', () {
      expect(
        () => IncidentRepository([incident('INC-105')], nextId: 105),
        throwsFormatException,
      );
    });
  });

  test('getById devuelve la incidencia o NOT_FOUND', () async {
    final repository = await openRepo();
    expect(repository.getById('INC-104').title, 'La exportación se interrumpe');
    expect(() => repository.getById('INC-999'), throwsDomain('NOT_FOUND'));
  });

  group('create', () {
    test('asigna ID, fecha y estado y recorta el texto', () async {
      final repository = await openRepo();
      final created = await repository.create(draft);
      expect(created.toJson(), {
        'id': 'INC-105',
        'title': 'Falla la impresión',
        'status': 'abierta',
        'impact': 'alto',
        'workaround': false,
        'created': '2026-11-22',
        'detail': 'Ninguna cuenta puede imprimir',
      });
      expect(repository.getById('INC-105').title, 'Falla la impresión');
    });

    test('persiste en el almacén y no toca la fixture', () async {
      final fixtureBefore = File(fixturePath).readAsStringSync();
      await (await openRepo()).create(draft);

      final reopened = await openRepo(writeEnabled: false);
      expect(reopened.all.last.id, 'INC-105');
      final stored = jsonDecode(
        File(storePath).readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(stored['nextId'], 106);
      expect(File('$storePath.tmp').existsSync(), isFalse);
      expect(File(fixturePath).readAsStringSync(), fixtureBefore);
    });

    test('las creaciones concurrentes reciben IDs distintos', () async {
      final repository = await openRepo();
      final created = await Future.wait([
        repository.create(draft),
        repository.create(draft),
        repository.create(draft),
      ]);
      expect(created.map((i) => i.id), ['INC-105', 'INC-106', 'INC-107']);
      expect((await openRepo()).all, hasLength(7));
    });

    test('respeta el nextId del almacén', () async {
      await File(storePath).parent.create(recursive: true);
      await File(storePath).writeAsString(
        jsonEncode({
          'nextId': 1000,
          'incidents': [incident('INC-101').toJson()],
        }),
      );
      expect((await (await openRepo()).create(draft)).id, 'INC-1000');
    });

    test('en solo lectura responde WRITE_DISABLED', () async {
      final repository = await openRepo(writeEnabled: false);
      await expectLater(
        repository.create(draft),
        throwsDomain('WRITE_DISABLED'),
      );
      expect(repository.all, hasLength(4));
    });

    test('valida el borrador antes de guardar', () async {
      final repository = await openRepo();
      await expectLater(
        repository.create(
          const NewIncident(title: ' ', detail: 'd', impact: Impact.bajo),
        ),
        throwsDomain('VALIDATION_ERROR'),
      );
      expect(File(storePath).existsSync(), isFalse);
    });

    test('si no puede guardar no cambia nada y sigue funcionando', () async {
      // La carpeta del almacén es un fichero: no se puede crear.
      final blocker = await writeFile('bloqueo', '');
      final repository = await IncidentRepository.open(
        fixturePath: fixturePath,
        storePath: p.join(blocker, 'tickets.local.json'),
        writeEnabled: true,
      );
      await expectLater(
        repository.create(draft),
        throwsDomain('PERSISTENCE_ERROR'),
      );
      expect(repository.all, hasLength(4));
      // Un fallo no bloquea la cola de escrituras.
      await expectLater(
        repository.create(draft),
        throwsDomain('PERSISTENCE_ERROR'),
      );
    });
  });
}
