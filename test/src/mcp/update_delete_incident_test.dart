import 'package:test/test.dart';

import '../../helpers/harness.dart';

Map<String, dynamic> incidentOf(
  CallToolResult result, [
  String key = 'incident',
]) => structured(result)[key] as Map<String, dynamic>;

void main() {
  setUpAll(silenceMcpLogs);

  group('actualizar_incidencia', () {
    late Harness harness;

    setUp(() async => harness = await Harness.start(writeEnabled: true));
    tearDown(() => harness.stop());

    test('lee la revisión, actualiza y la sube', () async {
      final before = incidentOf(
        await harness.call('obtener_incidencia', {'id': 'INC-104'}),
      );
      expect(before['revision'], 1);

      final result = await harness.call('actualizar_incidencia', {
        'id': 'INC-104',
        'expectedRevision': before['revision'],
        'impact': 'bajo',
        'workaround': true,
        'title': 'La exportación se interrumpe a veces',
        'detail': 'Se puede reintentar.',
      });
      expect(result.isError, isNot(true));
      final after = incidentOf(result);
      expect(after['revision'], 2);
      expect(after['impact'], 'bajo');
      expect(after['status'], 'abierta');
      expect(after['workaround'], isTrue);
      expect(after['detail'], 'Se puede reintentar.');
    });

    test('con revisión antigua responde REVISION_CONFLICT', () async {
      final args = {'id': 'INC-101', 'expectedRevision': 1, 'impact': 'alto'};
      await harness.call('actualizar_incidencia', args);
      final result = await harness.call('actualizar_incidencia', {
        ...args,
        'impact': 'bajo',
      });
      expect(result.isError, isTrue);
      expect(errorText(result), startsWith('REVISION_CONFLICT'));
      expect(errorText(result), contains('revisión actual es 2'));
    });

    test('sin campos que cambiar responde VALIDATION_ERROR', () async {
      final result = await harness.call('actualizar_incidencia', {
        'id': 'INC-101',
        'expectedRevision': 1,
      });
      expect(result.isError, isTrue);
      expect(errorText(result), startsWith('VALIDATION_ERROR'));
    });

    test('rechaza valores fuera del esquema', () async {
      final result = await harness.call('actualizar_incidencia', {
        'id': 'INC-101',
        'expectedRevision': 1,
        'impact': 'medio',
      });
      expect(result.isError, isTrue);
      expect(harness.repository.getById('INC-101').revision, 1);
    });
  });

  group('eliminar_incidencia', () {
    test('con borrado habilitado elimina y devuelve la ficha', () async {
      final harness = await Harness.start(
        writeEnabled: true,
        deleteEnabled: true,
      );
      addTearDown(harness.stop);

      final result = await harness.call('eliminar_incidencia', {
        'id': 'INC-102',
        'confirm': true,
        'reason': '  Duplicada  ',
      });
      expect(result.isError, isNot(true));
      expect(incidentOf(result, 'deleted')['id'], 'INC-102');
      expect(structured(result)['reason'], 'Duplicada');

      final get = await harness.call('obtener_incidencia', {'id': 'INC-102'});
      expect(errorText(get), startsWith('NOT_FOUND'));
    });

    test('sin confirm: true responde CONFIRMATION_REQUIRED', () async {
      final harness = await Harness.start(
        writeEnabled: true,
        deleteEnabled: true,
      );
      addTearDown(harness.stop);

      final result = await harness.call('eliminar_incidencia', {
        'id': 'INC-102',
        'confirm': false,
        'reason': 'Duplicada',
      });
      expect(errorText(result), startsWith('CONFIRMATION_REQUIRED'));
      expect(harness.repository.all, hasLength(4));
    });

    test('solo con escritura responde DELETE_DISABLED', () async {
      final harness = await Harness.start(writeEnabled: true);
      addTearDown(harness.stop);

      final result = await harness.call('eliminar_incidencia', {
        'id': 'INC-102',
        'confirm': true,
        'reason': 'Duplicada',
      });
      expect(errorText(result), startsWith('DELETE_DISABLED'));
      expect(harness.repository.all, hasLength(4));
    });
  });
}
