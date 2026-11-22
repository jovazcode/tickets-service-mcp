import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/mcp/schemas.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/services/triage.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// {@template next_priority_tool}
/// `siguiente_incidencia_prioritaria`: la incidencia activa que hay que
/// atender primero según el proceso de triaje.
/// {@endtemplate}
class NextPriorityTool extends BaseTool {
  /// {@macro next_priority_tool}
  new(this._repository);

  final IncidentRepository _repository;

  @override
  String get name => 'siguiente_incidencia_prioritaria';

  @override
  String get title => 'Siguiente incidencia prioritaria';

  @override
  String get description =>
      'Devuelve la incidencia activa que debe atenderse primero según '
      'docs://proceso_triaje (impacto alto, sin alternativa temporal, más '
      'antigua), los criterios aplicados y la cola completa de IDs activos '
      'en orden. Si no hay activas, no incluye "incident".';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(properties: {});

  @override
  ToolOutputSchema get outputSchema => JsonSchema.object(
    properties: {
      'incident': incidentSchema,
      'queue': JsonSchema.array(
        items: incidentIdSchema(),
        description: 'IDs activos en orden de atención',
      ),
      'criteria': JsonSchema.array(items: JsonSchema.string()),
    },
    required: ['queue', 'criteria'],
  );

  @override
  ToolAnnotations get annotations => readOnlyAnnotations;

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> args) async {
    final queue = priorityQueue(_repository.all);
    return {
      if (queue.isNotEmpty) 'incident': queue.first.toJson(),
      'queue': [for (final incident in queue) incident.id],
      'criteria': triageCriteria,
    };
  }
}
