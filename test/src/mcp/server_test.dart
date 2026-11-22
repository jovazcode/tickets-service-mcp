import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:test/test.dart';
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

/// Servidor y cliente MCP conectados en memoria.
class Harness {
  new _(this.server, this.client, this._pipes);

  static Future<Harness> start({String docsDirectory = 'docs'}) async {
    final repository = await IncidentRepository.load('data/tickets.json');
    final server = createMcpServer(
      repository: repository,
      docsDirectory: docsDirectory,
    );
    final toServer = StreamController<List<int>>();
    final toClient = StreamController<List<int>>();
    await server.connect(
      IOStreamTransport(stream: toServer.stream, sink: toClient.sink),
    );
    final client = McpClient(
      const Implementation(name: 'test', version: '1.0.0'),
    );
    await client.connect(
      IOStreamTransport(stream: toClient.stream, sink: toServer.sink),
    );
    return Harness._(server, client, [toServer, toClient]);
  }

  final McpServer server;
  final McpClient client;
  final List<StreamController<List<int>>> _pipes;

  Future<CallToolResult> call(String tool, [Map<String, dynamic>? args]) =>
      client.callTool(CallToolRequest(name: tool, arguments: args ?? {}));

  Future<void> stop() async {
    await client.close();
    await server.close();
    for (final pipe in _pipes) {
      await pipe.close();
    }
  }
}

Map<String, dynamic> structured(CallToolResult result) =>
    jsonDecode((result.content.single as TextContent).text)
        as Map<String, dynamic>;

String firstId(Map<String, dynamic> data) =>
    ((data['items'] as List).first as Map<String, dynamic>)['id'] as String;

String errorText(CallToolResult result) =>
    (result.content.single as TextContent).text;

void main() {
  late Harness harness;

  setUpAll(silenceMcpLogs);

  setUp(() async => harness = await Harness.start());
  tearDown(() => harness.stop());

  test('anuncia las herramientas con sus pistas de solo lectura', () async {
    final tools = (await harness.client.listTools()).tools;
    expect(
      tools.map((t) => t.name),
      unorderedEquals(['buscar_incidencias', 'obtener_incidencia']),
    );
    for (final tool in tools) {
      expect(tool.annotations?.readOnlyHint, isTrue);
      expect(tool.title, isNotEmpty);
    }
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
      final resources = (await harness.client.listResources()).resources;
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
