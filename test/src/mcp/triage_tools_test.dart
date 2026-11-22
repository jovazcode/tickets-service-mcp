import 'package:test/test.dart';

import '../../helpers/harness.dart';

void main() {
  setUpAll(silenceMcpLogs);

  late Harness harness;

  setUp(() async => harness = await Harness.start(writeEnabled: true));
  tearDown(() => harness.stop());

  group('siguiente_incidencia_prioritaria', () {
    test('devuelve INC-104, la cola y los criterios', () async {
      final data = structured(
        await harness.call('siguiente_incidencia_prioritaria'),
      );
      expect((data['incident'] as Map)['id'], 'INC-104');
      expect(data['queue'], ['INC-104', 'INC-102', 'INC-101']);
      expect(data['criteria'], triageCriteria);
    });

    test('sin activas no incluye incident', () async {
      for (final id in ['INC-101', 'INC-102', 'INC-104']) {
        await harness.call('cambiar_estado', {
          'id': id,
          'expectedRevision': 1,
          'status': 'resuelta',
        });
      }
      final data = structured(
        await harness.call('siguiente_incidencia_prioritaria'),
      );
      expect(data.containsKey('incident'), isFalse);
      expect(data['queue'], isEmpty);
    });
  });

  test('resumen_mesa con la fixture', () async {
    final data = structured(await harness.call('resumen_mesa'));
    expect(data, {
      'total': 4,
      'active': 3,
      'critical': 1,
      'byStatus': {'abierta': 3, 'en_progreso': 0, 'resuelta': 1},
      'byImpact': {'alto': 2, 'bajo': 2},
      'byWorkaround': {'con': 1, 'sin': 3},
      'oldestActive': {'id': 'INC-101', 'created': '2026-09-01'},
    });
  });

  group('cambiar_estado', () {
    test('cambia el estado e informa del anterior', () async {
      final result = await harness.call('cambiar_estado', {
        'id': 'INC-104',
        'expectedRevision': 1,
        'status': 'en_progreso',
      });
      expect(result.isError, isNot(true));
      final data = structured(result);
      expect(data['previousStatus'], 'abierta');
      expect((data['incident'] as Map)['status'], 'en_progreso');
      expect((data['incident'] as Map)['revision'], 2);
    });

    test('reabrir sin motivo responde REASON_REQUIRED', () async {
      final result = await harness.call('cambiar_estado', {
        'id': 'INC-103',
        'expectedRevision': 1,
        'status': 'abierta',
      });
      expect(errorText(result), startsWith('REASON_REQUIRED'));

      final reopened = await harness.call('cambiar_estado', {
        'id': 'INC-103',
        'expectedRevision': 1,
        'status': 'abierta',
        'reason': 'Ha vuelto a fallar',
      });
      expect(reopened.isError, isNot(true));
    });

    test('transición no permitida responde INVALID_TRANSITION', () async {
      final result = await harness.call('cambiar_estado', {
        'id': 'INC-103',
        'expectedRevision': 1,
        'status': 'en_progreso',
      });
      expect(errorText(result), startsWith('INVALID_TRANSITION'));
    });

    test('ID inexistente responde NOT_FOUND', () async {
      final result = await harness.call('cambiar_estado', {
        'id': 'INC-999',
        'expectedRevision': 1,
        'status': 'resuelta',
      });
      expect(errorText(result), startsWith('NOT_FOUND'));
    });
  });

  test('en solo lectura cambiar_estado responde WRITE_DISABLED', () async {
    final readOnly = await Harness.start();
    addTearDown(readOnly.stop);
    final result = await readOnly.call('cambiar_estado', {
      'id': 'INC-104',
      'expectedRevision': 1,
      'status': 'en_progreso',
    });
    expect(errorText(result), startsWith('WRITE_DISABLED'));
  });
}
