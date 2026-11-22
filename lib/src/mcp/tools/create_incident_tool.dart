import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/domain/impact.dart';
import 'package:tickets_service_mcp/src/domain/new_incident.dart';
import 'package:tickets_service_mcp/src/domain/text_rules.dart';
import 'package:tickets_service_mcp/src/mcp/schemas.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// {@template create_incident_tool}
/// `crear_incidencia`: abre una incidencia nueva.
/// {@endtemplate}
class CreateIncidentTool extends BaseTool {
  /// {@macro create_incident_tool}
  new(this._repository);

  final IncidentRepository _repository;

  @override
  String get name => 'crear_incidencia';

  @override
  String get title => 'Crear incidencia';

  @override
  String get description =>
      'Abre una incidencia nueva en estado "abierta" con la fecha de hoy; el '
      'servidor asigna el ID. Antes, sigue docs://proceso_apertura: busca '
      'con buscar_incidencias si ya existe una parecida y pide los datos que '
      'falten en lugar de inventarlos. Requiere que el servidor tenga la '
      'escritura habilitada; si no, responde WRITE_DISABLED.';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
    properties: {
      'title': JsonSchema.string(
        minLength: 1,
        maxLength: maxTitleLength,
        description: 'Síntoma en una frase corta',
      ),
      'detail': JsonSchema.string(
        minLength: 1,
        maxLength: maxDetailLength,
        description:
            'A quién afecta, desde cuándo, cómo reproducirlo y qué se ha '
            'intentado',
      ),
      'impact': impactSchema(
        description: 'Impacto según docs://proceso_triaje',
      ),
      'workaround': JsonSchema.boolean(
        description:
            'Si existe una alternativa temporal (por defecto false); '
            'descríbela en el detalle',
      ),
    },
    required: ['title', 'detail', 'impact'],
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
    final incident = await _repository.create(
      NewIncident(
        title: args['title'] as String,
        detail: args['detail'] as String,
        impact: Impact.parse(args['impact']),
        workaround: args['workaround'] as bool? ?? false,
      ),
    );
    return {'incident': incident.toJson()};
  }
}
