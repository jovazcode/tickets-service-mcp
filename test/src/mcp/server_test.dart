import 'dart:io';

import 'package:test/test.dart';

import '../../helpers/harness.dart';

void main() {
  late Harness harness;

  setUpAll(silenceMcpLogs);

  setUp(() async => harness = await Harness.start());
  tearDown(() => harness.stop());

  test('anuncia todas las herramientas, también en solo lectura', () async {
    final tools = {
      for (final tool in (await harness.client.listTools()).tools)
        tool.name: tool,
    };
    expect(
      tools.keys,
      unorderedEquals([
        'buscar_incidencias',
        'obtener_incidencia',
        'buscar_duplicadas',
        'historial_incidencia',
        'siguiente_incidencia_prioritaria',
        'resumen_mesa',
        'crear_incidencia',
        'actualizar_incidencia',
        'cambiar_estado',
        'eliminar_incidencia',
      ]),
    );
    expect(tools.values.every((t) => t.title!.isNotEmpty), isTrue);
    expect(tools['buscar_incidencias']!.annotations?.readOnlyHint, isTrue);
    expect(tools['obtener_incidencia']!.annotations?.readOnlyHint, isTrue);
    expect(
      tools['siguiente_incidencia_prioritaria']!.annotations?.readOnlyHint,
      isTrue,
    );
    expect(tools['resumen_mesa']!.annotations?.readOnlyHint, isTrue);
    expect(tools['buscar_duplicadas']!.annotations?.readOnlyHint, isTrue);
    expect(tools['historial_incidencia']!.annotations?.readOnlyHint, isTrue);
    expect(tools['cambiar_estado']!.annotations?.readOnlyHint, isFalse);
    expect(tools['crear_incidencia']!.annotations?.readOnlyHint, isFalse);
    expect(tools['crear_incidencia']!.annotations?.destructiveHint, isFalse);
    expect(
      tools['actualizar_incidencia']!.annotations?.destructiveHint,
      isFalse,
    );
    expect(tools['eliminar_incidencia']!.annotations?.destructiveHint, isTrue);
  });

  test('las instrucciones indican el modo de escritura', () async {
    expect(harness.client.getInstructions(), contains('solo lectura'));
    expect(
      serverInstructions(writeEnabled: true, deleteEnabled: false),
      allOf(contains('escritura está habilitada'), contains('DELETE_DISABLED')),
    );
    expect(
      serverInstructions(writeEnabled: true, deleteEnabled: true),
      contains('borrado está habilitado'),
    );
  });

  group('buscar_incidencias', () {
    test('encuentra por texto sin tildes', () async {
      final result = await harness.call('buscar_incidencias', {
        'q': 'exportacion',
      });
      expect(result.isError, isNot(true));
      final data = structured(result);
      expect(data['total'], 1);
      expect(firstId(data), 'INC-104');
    });

    test('sin argumentos devuelve todas', () async {
      final data = structured(await harness.call('buscar_incidencias'));
      expect(data['total'], 4);
    });

    test('aplica filtros y paginación', () async {
      final data = structured(
        await harness.call('buscar_incidencias', {
          'status': 'abierta',
          'impact': 'bajo',
          'workaround': false,
          'limit': 1,
          'offset': 0,
        }),
      );
      expect(data['total'], 1);
      expect(firstId(data), 'INC-102');
    });

    test('rechaza argumentos fuera del esquema', () async {
      final result = await harness.call('buscar_incidencias', {
        'impact': 'medio',
      });
      expect(result.isError, isTrue);
    });
  });

  group('obtener_incidencia', () {
    test('devuelve la ficha', () async {
      final data = structured(
        await harness.call('obtener_incidencia', {'id': 'INC-101'}),
      );
      expect(
        (data['incident'] as Map)['title'],
        'El acceso falla para una cuenta',
      );
    });

    test('responde NOT_FOUND como error de herramienta', () async {
      final result = await harness.call('obtener_incidencia', {
        'id': 'INC-999',
      });
      expect(result.isError, isTrue);
      expect(errorText(result), startsWith('NOT_FOUND'));
    });
  });

  group('documentos de proceso', () {
    test('se listan como recursos Markdown', () async {
      final resources = [
        for (final r in (await harness.client.listResources()).resources)
          if (r.uri.startsWith('docs://')) r,
      ];
      expect(
        resources.map((r) => r.uri),
        unorderedEquals(['docs://proceso_apertura', 'docs://proceso_triaje']),
      );
      expect(resources.every((r) => r.mimeType == 'text/markdown'), isTrue);
    });

    for (final name in ['proceso_apertura', 'proceso_triaje']) {
      test('docs://$name devuelve el contenido del fichero', () async {
        final result = await harness.client.readResource(
          ReadResourceRequest(uri: 'docs://$name'),
        );
        final contents = result.contents.single as TextResourceContents;
        expect(contents.uri, 'docs://$name');
        expect(contents.text, File('docs/$name.md').readAsStringSync());
      });
    }

    test('falla con error de protocolo si falta el fichero', () async {
      await harness.stop();
      final tempDir = await Directory.systemTemp.createTemp('docs_test');
      addTearDown(() => tempDir.delete(recursive: true));
      harness = await Harness.start(docsDirectory: tempDir.path);

      expect(
        harness.client.readResource(
          const ReadResourceRequest(uri: 'docs://proceso_triaje'),
        ),
        throwsA(isA<McpError>()),
      );
    });
  });
}
