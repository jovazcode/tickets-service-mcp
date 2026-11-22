import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/mcp/resources/process_documents.dart';

/// Registra el prompt `abrir_incidencia`, que guía al modelo para abrir una
/// incidencia siguiendo `docs://proceso_apertura`.
///
/// El documento se incrusta en el mensaje para que el modelo lo tenga aunque
/// el cliente no lea recursos por su cuenta.
void registerOpenIncidentPrompt(McpServer server, String docsDirectory) {
  server.registerPrompt(
    'abrir_incidencia',
    title: 'Abrir incidencia',
    description:
        'Guía para registrar una incidencia nueva siguiendo el proceso de '
        'apertura: comprobar duplicados, completar datos y confirmar antes '
        'de crear.',
    argsSchema: const {
      'problema': PromptArgumentDefinition(
        description: 'Descripción libre del problema a registrar',
      ),
    },
    callback: (args, extra) async {
      final problem = (args?['problema'] as String?)?.trim() ?? '';
      final document = await readProcessDocument(
        docsDirectory,
        aperturaDocument,
      );
      return GetPromptResult(
        description: 'Apertura de incidencia según el proceso de la mesa',
        messages: [
          PromptMessage(
            role: PromptMessageRole.user,
            content: EmbeddedResource(resource: document),
          ),
          PromptMessage(
            role: PromptMessageRole.user,
            content: TextContent(
              text:
                  '''
Quiero abrir una incidencia siguiendo el proceso de apertura adjunto.
${problem.isEmpty ? 'Pregúntame primero qué problema quiero registrar.' : 'Problema: $problem'}

Pasos:
1. Usa buscar_incidencias con palabras clave del problema. Si hay una activa equivalente, enséñamela y no crees otra.
2. Completa title, detail, impact y workaround. Si falta información imprescindible, pregúntamela; no la inventes. Para el impacto aplica docs://proceso_triaje.
3. Muéstrame la incidencia propuesta y espera mi confirmación.
4. Solo entonces llama a crear_incidencia y dime el ID asignado.''',
            ),
          ),
        ],
      );
    },
  );
}
