import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/domain/audit_event.dart';
import 'package:tickets_service_mcp/src/mcp/schemas.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// {@template history_tool}
/// `historial_incidencia`: cambios registrados de una incidencia.
/// {@endtemplate}
class HistoryTool extends BaseTool {
  /// {@macro history_tool}
  new(this._repository);

  final IncidentRepository _repository;

  @override
  String get name => 'historial_incidencia';

  @override
  String get title => 'Historial de incidencia';

  @override
  String get description =>
      'Devuelve los cambios registrados en la auditoría de una incidencia, '
      'del más antiguo al más reciente: alta, ediciones (campos con valor '
      'anterior y nuevo), cambios de estado y borrado, con su fecha y motivo. '
      'Funciona también con incidencias borradas. Las incidencias iniciales '
      'que nunca han cambiado no tienen eventos.';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
    properties: {'id': incidentIdSchema()},
    required: ['id'],
  );

  @override
  ToolOutputSchema get outputSchema => JsonSchema.object(
    properties: {
      'events': JsonSchema.array(
        items: JsonSchema.object(
          properties: {
            'timestamp': JsonSchema.string(description: 'ISO 8601 UTC'),
            'operation': JsonSchema.string(
              enumValues: AuditOperation.wireValues,
            ),
            'id': incidentIdSchema(),
            'reason': JsonSchema.string(),
            'changes': JsonSchema.object(
              description: 'Campos cambiados: {campo: {from, to}}',
            ),
            'snapshot': incidentSchema,
          },
          required: ['timestamp', 'operation', 'id'],
        ),
      ),
    },
    required: ['events'],
  );

  @override
  ToolAnnotations get annotations => readOnlyAnnotations;

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> args) async {
    final events = await _repository.history(args['id'] as String);
    return {
      'events': [for (final event in events) event.toJson()],
    };
  }
}
