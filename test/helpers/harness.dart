import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

export 'package:mcp_dart/mcp_dart.dart';
export 'package:tickets_service_mcp/tickets_service_mcp.dart';

/// Servidor y cliente MCP conectados en memoria.
class Harness {
  new _(this.server, this.client, this.repository, this._storeDir, this._pipes);

  /// Arranca un servidor sobre la fixture del proyecto, con un almacén de
  /// trabajo en una carpeta temporal que se borra en [stop].
  ///
  /// Por defecto el cliente negocia MCP 2026-07-28 (sin estado); con
  /// [McpProtocol.legacy] usa la sesión de MCP 2025-11-25.
  ///
  /// Con [onElicit], el cliente declara la capacidad `elicitation` (modo
  /// formulario) y responde con esa función a las preguntas del servidor.
  static Future<Harness> start({
    String docsDirectory = 'docs',
    bool writeEnabled = false,
    bool deleteEnabled = false,
    McpProtocol protocol = McpProtocol.stable,
    Future<ElicitResult> Function(ElicitRequest request)? onElicit,
  }) async {
    final storeDir = await Directory.systemTemp.createTemp('harness');
    final repository = await IncidentRepository.open(
      fixturePath: 'data/tickets.json',
      storePath: p.join(storeDir.path, 'tickets.local.json'),
      auditPath: p.join(storeDir.path, 'tickets.audit.jsonl'),
      writeEnabled: writeEnabled,
      deleteEnabled: deleteEnabled,
    );
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
      options: McpClientOptions(
        protocol: protocol,
        capabilities: ClientCapabilities(
          elicitation: onElicit == null
              ? null
              : const ClientElicitation.formOnly(),
        ),
      ),
    )..onElicitRequest = onElicit;
    await client.connect(
      IOStreamTransport(stream: toClient.stream, sink: toServer.sink),
    );
    return Harness._(server, client, repository, storeDir, [
      toServer,
      toClient,
    ]);
  }

  final McpServer server;
  final McpClient client;
  final IncidentRepository repository;
  final Directory _storeDir;
  final List<StreamController<List<int>>> _pipes;

  Future<CallToolResult> call(String tool, [Map<String, dynamic>? args]) =>
      client.callTool(CallToolRequest(name: tool, arguments: args ?? {}));

  Future<void> stop() async {
    await client.close();
    await server.close();
    for (final pipe in _pipes) {
      await pipe.close();
    }
    await _storeDir.delete(recursive: true);
  }
}

Map<String, dynamic> structured(CallToolResult result) =>
    jsonDecode((result.content.single as TextContent).text)
        as Map<String, dynamic>;

String firstId(Map<String, dynamic> data) =>
    ((data['items'] as List).first as Map<String, dynamic>)['id'] as String;

String errorText(CallToolResult result) =>
    (result.content.single as TextContent).text;
