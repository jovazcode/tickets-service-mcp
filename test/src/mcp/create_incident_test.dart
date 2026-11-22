import 'package:test/test.dart';

import '../../helpers/harness.dart';

const args = {
  'title': 'Falla la impresión',
  'detail': 'Ninguna cuenta de prueba puede imprimir informes.',
  'impact': 'alto',
};

void main() {
  setUpAll(silenceMcpLogs);

  group('crear_incidencia con escritura habilitada', () {
    late Harness harness;

    setUp(() async => harness = await Harness.start(writeEnabled: true));
    tearDown(() => harness.stop());

    test('crea la incidencia y queda disponible para búsquedas', () async {
      final result = await harness.call('crear_incidencia', args);
      expect(result.isError, isNot(true));
      final incident = structured(result)['incident'] as Map<String, dynamic>;
      expect(incident['id'], 'INC-105');
      expect(incident['status'], 'abierta');
      expect(incident['workaround'], isFalse);

      final search = structured(
        await harness.call('buscar_incidencias', {'q': 'impresion'}),
      );
      expect(firstId(search), 'INC-105');
    });

    test('acepta workaround', () async {
      final result = await harness.call('crear_incidencia', {
        ...args,
        'workaround': true,
      });
      final incident = structured(result)['incident'] as Map<String, dynamic>;
      expect(incident['workaround'], isTrue);
    });

    test('rechaza un título solo con espacios', () async {
      final result = await harness.call('crear_incidencia', {
        ...args,
        'title': '   ',
      });
      expect(result.isError, isTrue);
      expect(errorText(result), startsWith('VALIDATION_ERROR'));
      expect(harness.repository.all, hasLength(4));
    });

    test('rechaza argumentos que no cumplen el esquema', () async {
      final result = await harness.call('crear_incidencia', {
        'title': 'Sin detalle ni impacto',
      });
      expect(result.isError, isTrue);
      expect(harness.repository.all, hasLength(4));
    });
  });

  test('en solo lectura responde WRITE_DISABLED', () async {
    final harness = await Harness.start();
    addTearDown(harness.stop);

    final result = await harness.call('crear_incidencia', args);
    expect(result.isError, isTrue);
    expect(errorText(result), startsWith('WRITE_DISABLED'));
    expect(harness.repository.all, hasLength(4));
  });
}
