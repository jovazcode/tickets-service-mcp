import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/domain/impact.dart';
import 'package:tickets_service_mcp/src/domain/incident_status.dart';
import 'package:tickets_service_mcp/src/mcp/schemas.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/services/triage.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// {@template desk_summary_tool}
/// `resumen_mesa`: totales de la mesa.
/// {@endtemplate}
class DeskSummaryTool extends BaseTool {
  /// {@macro desk_summary_tool}
  new(this._repository);

  final IncidentRepository _repository;

  @override
  String get name => 'resumen_mesa';

  @override
  String get title => 'Resumen de la mesa';

  @override
  String get description =>
      'Totales de la mesa: incidencias totales y activas, críticas (activas '
      'de impacto alto sin alternativa temporal), recuentos por estado, '
      'impacto y alternativa temporal, y la activa más antigua.';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(properties: {});

  @override
  ToolOutputSchema get outputSchema {
    JsonObject counts(List<String> keys) => JsonSchema.object(
      properties: {for (final k in keys) k: JsonSchema.integer(minimum: 0)},
      required: keys,
    );
    return JsonSchema.object(
      properties: {
        'total': JsonSchema.integer(minimum: 0),
        'active': JsonSchema.integer(minimum: 0),
        'critical': JsonSchema.integer(
          minimum: 0,
          description: 'Activas de impacto alto sin alternativa temporal',
        ),
        'byStatus': counts(IncidentStatus.wireValues),
        'byImpact': counts(Impact.wireValues),
        'byWorkaround': counts(['con', 'sin']),
        'oldestActive': JsonSchema.object(
          properties: {
            'id': incidentIdSchema(),
            'created': JsonSchema.string(),
          },
          required: ['id', 'created'],
        ),
      },
      required: [
        'total',
        'active',
        'critical',
        'byStatus',
        'byImpact',
        'byWorkaround',
      ],
    );
  }

  @override
  ToolAnnotations get annotations => readOnlyAnnotations;

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> args) async =>
      summarize(_repository.all).toJson();
}
