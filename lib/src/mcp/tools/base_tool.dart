import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/domain/domain_exception.dart';

/// Herramienta MCP: adapta argumentos JSON a una llamada al dominio.
abstract class BaseTool {
  /// Nombre con el que el cliente invoca la herramienta.
  String get name;

  /// Título legible para la interfaz del cliente.
  String get title;

  /// Qué hace la herramienta y cuándo usarla; lo lee el modelo.
  String get description;

  /// Esquema de los argumentos.
  ToolInputSchema get inputSchema;

  /// Esquema del resultado estructurado.
  ToolOutputSchema get outputSchema;

  /// Pistas de comportamiento para el cliente.
  ToolAnnotations get annotations;

  /// Ejecuta la herramienta. Puede lanzar [DomainException], que se
  /// convierte en un resultado de error para el modelo.
  Future<Map<String, dynamic>> run(Map<String, dynamic> args);

  /// Ejecuta [run] y traduce su resultado o error a un [CallToolResult].
  Future<CallToolResult> execute(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) async {
    try {
      return CallToolResult.fromStructuredContent(await run(args));
    } on DomainException catch (error) {
      return CallToolResult(
        isError: true,
        content: [TextContent(text: error.toString())],
      );
    }
  }
}

/// Registro de [BaseTool] en un [McpServer].
extension ToolRegistration on McpServer {
  /// Registra [tool] con todos sus metadatos.
  void registerBaseTool(BaseTool tool) {
    registerTool(
      tool.name,
      title: tool.title,
      description: tool.description,
      inputSchema: tool.inputSchema,
      outputSchema: tool.outputSchema,
      annotations: tool.annotations,
      callback: tool.execute,
    );
  }
}

/// Pistas para herramientas de solo lectura sobre datos locales.
const readOnlyAnnotations = ToolAnnotations(
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
);
