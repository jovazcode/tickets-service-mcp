import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/domain/impact.dart';
import 'package:tickets_service_mcp/src/domain/incident_patch.dart';
import 'package:tickets_service_mcp/src/domain/text_rules.dart';
import 'package:tickets_service_mcp/src/mcp/schemas.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// {@template update_incident_tool}
/// `actualizar_incidencia`: cambia campos de una incidencia con control de
/// revisión.
/// {@endtemplate}
class UpdateIncidentTool extends BaseTool {
  /// {@macro update_incident_tool}
  new(this._repository);

  final IncidentRepository _repository;

  @override
  String get name => 'actualizar_incidencia';

  @override
  String get title => 'Actualizar incidencia';

  @override
  String get description =>
      'Cambia uno o varios campos de una incidencia (title, detail, impact, '
      'workaround); los que no se indiquen no cambian. El estado se cambia '
      'con cambiar_estado. Exige '
      'expectedRevision, la revisión leída con obtener_incidencia: si la '
      'incidencia ha cambiado desde entonces responde REVISION_CONFLICT y no '
      'aplica nada; vuelve a consultarla y confirma con el usuario. Requiere '
      'escritura habilitada (WRITE_DISABLED si no).';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
    properties: {
      'id': incidentIdSchema(),
      'expectedRevision': JsonSchema.integer(
        minimum: 1,
        description: 'Revisión actual de la incidencia, tal como se leyó',
      ),
      'title': JsonSchema.string(
        minLength: 1,
        maxLength: maxTitleLength,
        description: 'Nuevo título',
      ),
      'detail': JsonSchema.string(
        minLength: 1,
        maxLength: maxDetailLength,
        description: 'Nuevo detalle',
      ),
      'impact': impactSchema(description: 'Nuevo impacto'),
      'workaround': JsonSchema.boolean(
        description: 'Si ahora existe una alternativa temporal',
      ),
    },
    required: ['id', 'expectedRevision'],
  );

  @override
  ToolOutputSchema get outputSchema => JsonSchema.object(
    properties: {'incident': incidentSchema},
    required: ['incident'],
  );

  @override
  ToolAnnotations get annotations =>
      const ToolAnnotations(destructiveHint: false, openWorldHint: false);

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> args) async {
    final impact = args['impact'];
    final incident = await _repository.update(
      args['id'] as String,
      expectedRevision: args['expectedRevision'] as int,
      patch: IncidentPatch(
        title: args['title'] as String?,
        detail: args['detail'] as String?,
        impact: impact == null ? null : Impact.parse(impact),
        workaround: args['workaround'] as bool?,
      ),
    );
    return {'incident': incident.toJson()};
  }
}
