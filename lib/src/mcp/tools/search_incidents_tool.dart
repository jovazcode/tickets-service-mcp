import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/domain/impact.dart';
import 'package:tickets_service_mcp/src/domain/incident_status.dart';
import 'package:tickets_service_mcp/src/mcp/schemas.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/services/incident_search.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// {@template search_incidents_tool}
/// `buscar_incidencias`: busca por texto libre y filtros combinados.
/// {@endtemplate}
class SearchIncidentsTool extends BaseTool {
  /// {@macro search_incidents_tool}
  new(this._repository);

  final IncidentRepository _repository;

  @override
  String get name => 'buscar_incidencias';

  @override
  String get title => 'Buscar incidencias';

  @override
  String get description =>
      'Busca incidencias por texto libre (en ID, título y detalle, sin '
      'distinguir mayúsculas ni tildes) y por estado, impacto o existencia de '
      'alternativa temporal. Sin argumentos devuelve todas, paginadas.';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
    properties: {
      'q': JsonSchema.string(
        maxLength: 200,
        description: 'Texto a buscar, por ejemplo "exportación"',
      ),
      'status': statusSchema(description: 'Filtra por estado'),
      'impact': impactSchema(description: 'Filtra por impacto'),
      'workaround': JsonSchema.boolean(
        description: 'true: solo con alternativa temporal; false: solo sin',
      ),
      'limit': JsonSchema.integer(
        minimum: 1,
        maximum: SearchCriteria.maxLimit,
        description:
            'Resultados por página (por defecto '
            '${SearchCriteria.defaultLimit})',
      ),
      'offset': JsonSchema.integer(
        minimum: 0,
        description: 'Resultados que se saltan (por defecto 0)',
      ),
    },
  );

  @override
  ToolOutputSchema get outputSchema => JsonSchema.object(
    properties: {
      'items': JsonSchema.array(items: incidentSchema),
      'total': JsonSchema.integer(
        minimum: 0,
        description: 'Total de coincidencias antes de paginar',
      ),
    },
    required: ['items', 'total'],
  );

  @override
  ToolAnnotations get annotations => readOnlyAnnotations;

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> args) async {
    final status = args['status'];
    final impact = args['impact'];
    final result = searchIncidents(
      _repository.all,
      SearchCriteria(
        text: args['q'] as String?,
        status: status == null ? null : IncidentStatus.parse(status),
        impact: impact == null ? null : Impact.parse(impact),
        workaround: args['workaround'] as bool?,
        limit: args['limit'] as int? ?? SearchCriteria.defaultLimit,
        offset: args['offset'] as int? ?? 0,
      ),
    );
    return {
      'items': [for (final incident in result.items) incident.toJson()],
      'total': result.total,
    };
  }
}
