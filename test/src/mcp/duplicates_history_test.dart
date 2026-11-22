import 'package:test/test.dart';

import '../../helpers/harness.dart';

List<Map<String, dynamic>> listOf(CallToolResult result, String key) => [
  for (final item in structured(result)[key] as List)
    item as Map<String, dynamic>,
];

void main() {
  setUpAll(silenceMcpLogs);

  late Harness harness;

  setUp(
    () async =>
        harness = await Harness.start(writeEnabled: true, deleteEnabled: true),
  );
  tearDown(() => harness.stop());

  group('buscar_duplicadas', () {
    test('devuelve candidatas con puntuación y términos', () async {
      final candidates = listOf(
        await harness.call('buscar_duplicadas', {
          'title': 'No se pueden guardar incidencias',
        }),
        'candidates',
      );
      expect(candidates.single['id'], 'INC-103');
      expect(candidates.single['status'], 'resuelta');
      expect(candidates.single['score'], 1.0);
      expect(candidates.single['sharedTerms'], ['guarda', 'incide']);
    });

    test('puede excluir resueltas y ajustar la puntuación', () async {
      expect(
        listOf(
          await harness.call('buscar_duplicadas', {
            'title': 'No se pueden guardar incidencias',
            'includeResolved': false,
          }),
          'candidates',
        ),
        isEmpty,
      );
      expect(
        listOf(
          await harness.call('buscar_duplicadas', {
            'title': 'La exportación falla',
            'detail': 'No sale el informe',
            'minScore': 0.9,
          }),
          'candidates',
        ),
        isEmpty,
      );
    });
  });

  group('crear_incidencia', () {
    test('avisa de activas muy parecidas sin impedir la creación', () async {
      final result = await harness.call('crear_incidencia', {
        'title': 'La exportación se interrumpe otra vez',
        'detail': 'El informe no se puede obtener.',
        'impact': 'alto',
      });
      expect(result.isError, isNot(true));
      final duplicates = listOf(result, 'possibleDuplicates');
      expect(duplicates.single['id'], 'INC-104');
      expect(harness.repository.all, hasLength(5));
    });

    test('avisa también con parecidos moderados (2 de 5 términos)', () async {
      final result = await harness.call('crear_incidencia', {
        'title': 'La exportación vuelve a fallar',
        'detail': 'El informe no se genera.',
        'impact': 'alto',
      });
      expect(listOf(result, 'possibleDuplicates').single['score'], 0.4);
    });

    test('sin parecidos devuelve la lista vacía', () async {
      final result = await harness.call('crear_incidencia', {
        'title': 'La impresora no funciona',
        'detail': 'Nadie puede imprimir desde esta mañana.',
        'impact': 'bajo',
      });
      expect(listOf(result, 'possibleDuplicates'), isEmpty);
    });
  });

  group('historial_incidencia', () {
    test('muestra el ciclo de vida completo, incluso tras borrar', () async {
      await harness.call('cambiar_estado', {
        'id': 'INC-102',
        'expectedRevision': 1,
        'status': 'en_progreso',
      });
      await harness.call('eliminar_incidencia', {
        'id': 'INC-102',
        'confirm': true,
        'reason': 'Ya no aplica',
      });

      final events = listOf(
        await harness.call('historial_incidencia', {'id': 'INC-102'}),
        'events',
      );
      expect(events.map((e) => e['operation']), ['cambiar_estado', 'eliminar']);
      expect(events.first['changes'], {
        'status': {'from': 'abierta', 'to': 'en_progreso'},
      });
      expect(events.last['reason'], 'Ya no aplica');
      expect((events.last['snapshot'] as Map)['status'], 'en_progreso');
    });

    test('sin cambios devuelve lista vacía; inexistente, NOT_FOUND', () async {
      expect(
        listOf(
          await harness.call('historial_incidencia', {'id': 'INC-101'}),
          'events',
        ),
        isEmpty,
      );
      final missing = await harness.call('historial_incidencia', {
        'id': 'INC-999',
      });
      expect(errorText(missing), startsWith('NOT_FOUND'));
    });
  });
}
