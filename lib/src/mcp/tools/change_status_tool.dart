import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/domain/incident_status.dart';
import 'package:tickets_service_mcp/src/domain/text_rules.dart';
import 'package:tickets_service_mcp/src/mcp/schemas.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// {@template change_status_tool}
/// `cambiar_estado`: mueve una incidencia por su ciclo de vida.
/// {@endtemplate}
class ChangeStatusTool extends BaseTool {
  /// {@macro change_status_tool}
  new(this._repository);

  final IncidentRepository _repository;

  @override
  String get name => 'cambiar_estado';

  @override
  String get title => 'Cambiar estado';

  @override
  String get description =>
      'Cambia el estado de una incidencia respetando las transiciones '
      'permitidas: abierta → en_progreso o resuelta; en_progreso → resuelta '
      'o abierta; resuelta → abierta (reabrir, exige reason). Otras '
      'responden INVALID_TRANSITION. Exige expectedRevision, la revisión '
      'leída con obtener_incidencia (REVISION_CONFLICT si ha cambiado). '
      'Requiere escritura habilitada (WRITE_DISABLED si no).';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
    properties: {
      'id': incidentIdSchema(),
      'expectedRevision': JsonSchema.integer(
        minimum: 1,
        description: 'Revisión actual de la incidencia, tal como se leyó',
      ),
      'status': statusSchema(description: 'Estado de destino'),
      'reason': JsonSchema.string(
        minLength: 1,
        maxLength: maxReasonLength,
        description: 'Motivo del cambio; obligatorio para reabrir',
      ),
    },
    required: ['id', 'expectedRevision', 'status'],
  );

  @override
  ToolOutputSchema get outputSchema => JsonSchema.object(
    properties: {'incident': incidentSchema, 'previousStatus': statusSchema()},
    required: ['incident', 'previousStatus'],
  );

  @override
  ToolAnnotations get annotations =>
      const ToolAnnotations(destructiveHint: false, openWorldHint: false);

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final previous = _repository.getById(id).status;
    final incident = await _repository.changeStatus(
      id,
      expectedRevision: args['expectedRevision'] as int,
      status: IncidentStatus.parse(args['status']),
      reason: args['reason'] as String?,
    );
    return {'incident': incident.toJson(), 'previousStatus': previous.value};
  }
}
