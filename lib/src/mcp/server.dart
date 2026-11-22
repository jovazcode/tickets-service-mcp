import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/mcp/resources/process_documents.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/get_incident_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/search_incidents_tool.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// Nombre con el que el servidor se presenta a los clientes.
const serverName = 'mesa-incidencias';

/// Versión del servidor.
const serverVersion = '0.1.0';

/// Herramientas que expone el servidor.
List<BaseTool> createAllTools(IncidentRepository repository) => [
  SearchIncidentsTool(repository),
  GetIncidentTool(repository),
];

/// Crea un [McpServer] con todas las herramientas y recursos registrados,
/// listo para conectarse a un transporte.
McpServer createMcpServer({
  required IncidentRepository repository,
  required String docsDirectory,
}) {
  final server = McpServer(
    const Implementation(name: serverName, version: serverVersion),
    options: const McpServerOptions(
      instructions:
          'Mesa de incidencias local con datos ficticios. Usa '
          'buscar_incidencias para localizar incidencias y '
          'obtener_incidencia para ver una ficha. Los procesos de la mesa '
          'están en los recursos docs://proceso_apertura y '
          'docs://proceso_triaje.',
    ),
  );
  createAllTools(repository).forEach(server.registerBaseTool);
  registerProcessDocuments(server, docsDirectory);
  return server;
}
