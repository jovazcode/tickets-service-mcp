import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/mcp/prompts/open_incident_prompt.dart';
import 'package:tickets_service_mcp/src/mcp/resources/process_documents.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/change_status_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/create_incident_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/delete_incident_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/desk_summary_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/find_duplicates_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/get_incident_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/history_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/next_priority_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/search_incidents_tool.dart';
import 'package:tickets_service_mcp/src/mcp/tools/update_incident_tool.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// Nombre con el que el servidor se presenta a los clientes.
const serverName = 'mesa-incidencias';

/// Versión del servidor.
const serverVersion = '0.5.0';

/// Herramientas que expone el servidor.
///
/// Las de escritura se anuncian siempre; si la escritura no está habilitada
/// responden `WRITE_DISABLED` (o `DELETE_DISABLED` al borrar).
List<BaseTool> createAllTools(IncidentRepository repository) => [
  SearchIncidentsTool(repository),
  GetIncidentTool(repository),
  FindDuplicatesTool(repository),
  HistoryTool(repository),
  NextPriorityTool(repository),
  DeskSummaryTool(repository),
  CreateIncidentTool(repository),
  UpdateIncidentTool(repository),
  ChangeStatusTool(repository),
  DeleteIncidentTool(repository),
];

/// Instrucciones para el modelo, según los permisos activos.
String serverInstructions({
  required bool writeEnabled,
  required bool deleteEnabled,
}) {
  const readOnly =
      'El servidor está en modo solo lectura: crear_incidencia, '
      'actualizar_incidencia, cambiar_estado y eliminar_incidencia '
      'responderán WRITE_DISABLED.';
  const write =
      'La escritura está habilitada: crear_incidencia, '
      'actualizar_incidencia y cambiar_estado guardan cambios reales en el '
      'almacén local, así que confirma con el usuario antes de usarlas.';
  const delete =
      'El borrado está habilitado: usa eliminar_incidencia solo si el '
      'usuario lo pide expresamente, tras mostrarle la ficha.';
  const noDelete =
      'El borrado está desactivado: eliminar_incidencia responderá '
      'DELETE_DISABLED.';
  final mode = !writeEnabled
      ? readOnly
      : '$write ${deleteEnabled ? delete : noDelete}';
  return 'Mesa de incidencias local con datos ficticios. Usa '
      'buscar_incidencias para localizar incidencias y obtener_incidencia '
      'para ver una ficha y su revisión, necesaria para actualizarla o '
      'cambiar su estado, e historial_incidencia para ver sus cambios. '
      'Antes de crear una incidencia usa buscar_duplicadas. Para decidir qué '
      'atender usa siguiente_incidencia_prioritaria y resumen_mesa. Los '
      'procesos de la mesa están en los recursos docs://proceso_apertura y '
      'docs://proceso_triaje; síguelos antes de crear incidencias. $mode';
}

/// Crea un [McpServer] con todas las herramientas, recursos y prompts
/// registrados, listo para conectarse a un transporte.
McpServer createMcpServer({
  required IncidentRepository repository,
  required String docsDirectory,
}) {
  final server = McpServer(
    const Implementation(name: serverName, version: serverVersion),
    options: McpServerOptions(
      instructions: serverInstructions(
        writeEnabled: repository.writeEnabled,
        deleteEnabled: repository.deleteEnabled,
      ),
    ),
  );
  createAllTools(repository).forEach(server.registerBaseTool);
  registerProcessDocuments(server, docsDirectory);
  registerOpenIncidentPrompt(server, docsDirectory);
  return server;
}
