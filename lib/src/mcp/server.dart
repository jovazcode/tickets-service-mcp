import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/mcp/prompts/open_incident_prompt.dart';
import 'package:tickets_service_mcp/src/mcp/resources/process_documents.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/create_incident_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/get_incident_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/search_incidents_tool.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// Nombre con el que el servidor se presenta a los clientes.
const serverName = 'mesa-incidencias';

/// Versión del servidor.
const serverVersion = '0.2.0';

/// Herramientas que expone el servidor.
///
/// Las de escritura se anuncian siempre; si la escritura no está habilitada
/// responden `WRITE_DISABLED`.
List<BaseTool> createAllTools(IncidentRepository repository) => [
  SearchIncidentsTool(repository),
  GetIncidentTool(repository),
  CreateIncidentTool(repository),
];

/// Instrucciones para el modelo, según el modo de escritura.
String serverInstructions({required bool writeEnabled}) =>
    'Mesa de incidencias local con datos ficticios. Usa buscar_incidencias '
    'para localizar incidencias y obtener_incidencia para ver una ficha. '
    'Los procesos de la mesa están en los recursos docs://proceso_apertura y '
    'docs://proceso_triaje; síguelos antes de crear incidencias. '
    '${writeEnabled ? 'La escritura está habilitada: crear_incidencia guarda '
              'cambios reales en el almacén local, así que confirma con el '
              'usuario antes de usarla.' : 'El servidor está en modo solo '
              'lectura: crear_incidencia responderá WRITE_DISABLED.'}';

/// Crea un [McpServer] con todas las herramientas, recursos y prompts
/// registrados, listo para conectarse a un transporte.
McpServer createMcpServer({
  required IncidentRepository repository,
  required String docsDirectory,
}) {
  final server = McpServer(
    const Implementation(name: serverName, version: serverVersion),
    options: McpServerOptions(
      instructions: serverInstructions(writeEnabled: repository.writeEnabled),
    ),
  );
  createAllTools(repository).forEach(server.registerBaseTool);
  registerProcessDocuments(server, docsDirectory);
  registerOpenIncidentPrompt(server, docsDirectory);
  return server;
}
