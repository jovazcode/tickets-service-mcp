import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/mcp/schemas.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// {@template get_incident_tool}
/// `obtener_incidencia`: devuelve la ficha completa de una incidencia.
/// {@endtemplate}
class GetIncidentTool extends BaseTool {
  /// {@macro get_incident_tool}
  new(this._repository);

  final IncidentRepository _repository;

  @override
  String get name => 'obtener_incidencia';

  @override
  String get title => 'Obtener incidencia';

  @override
  String get description =>
      'Devuelve la ficha completa de una incidencia por su ID. Si no existe, '
      'responde con el error NOT_FOUND.';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
    properties: {'id': incidentIdSchema()},
    required: ['id'],
  );

  @override
  ToolOutputSchema get outputSchema => JsonSchema.object(
    properties: {'incident': incidentSchema},
    required: ['incident'],
  );

  @override
  ToolAnnotations get annotations => readOnlyAnnotations;

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> args) async => {
    'incident': _repository.getById(args['id'] as String).toJson(),
  };
}
