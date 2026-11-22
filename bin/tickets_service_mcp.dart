import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

/// Punto de entrada del servidor MCP local (stdio).
///
/// stdout queda reservado para JSON-RPC; los diagnósticos van a stderr.
Future<void> main(List<String> arguments) async {
  final config = ServerConfig.fromEnvironment(
    Platform.environment,
    baseDirectory: _projectRoot(),
  );

  final IncidentRepository repository;
  try {
    repository = await IncidentRepository.open(
      fixturePath: config.dataPath,
      storePath: config.storePath,
      writeEnabled: config.writeEnabled,
      deleteEnabled: config.deleteEnabled,
    );
  } on Exception catch (error) {
    stderr.writeln('[$serverName] No se pudieron cargar los datos: $error');
    exitCode = 1;
    return;
  }

  final server = createMcpServer(
    repository: repository,
    docsDirectory: config.docsDirectory,
  );
  await server.connect(StdioServerTransport());
  stderr.writeln(
    '[$serverName] listo por stdio con ${repository.all.length} incidencias '
    '(${repository.deleteEnabled
        ? 'escritura y borrado habilitados'
        : repository.writeEnabled
        ? 'escritura habilitada'
        : 'solo lectura'})',
  );
}

/// Raíz del proyecto: la carpeta padre de `bin/` (con `dart run`) o de
/// `build/` (con el ejecutable compilado). En otro caso, el directorio actual.
String _projectRoot() {
  final scriptDir = p.dirname(Platform.script.toFilePath());
  return switch (p.basename(scriptDir)) {
    'bin' || 'build' => p.dirname(scriptDir),
    _ => Directory.current.path,
  };
}
