import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/domain/text_rules.dart';
import 'package:tickets_service_mcp/src/mcp/schemas.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/services/duplicates.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// {@template find_duplicates_tool}
/// `buscar_duplicadas`: incidencias parecidas a un problema descrito.
/// {@endtemplate}
class FindDuplicatesTool extends BaseTool {
  /// {@macro find_duplicates_tool}
  new(this._repository);

  final IncidentRepository _repository;

  @override
  String get name => 'buscar_duplicadas';

  @override
  String get title => 'Buscar duplicadas';

  @override
  String get description =>
      'Busca incidencias parecidas a un problema (por palabras significativas '
      'del título y el detalle, sin tildes ni palabras vacías) y las devuelve '
      'con una puntuación de 0 a 1 y los términos en común. Úsala antes de '
      'crear_incidencia, como pide docs://proceso_apertura. Es una '
      'heurística: revisa las candidatas antes de concluir que son la misma.';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
    properties: {
      'title': JsonSchema.string(
        minLength: 1,
        maxLength: maxTitleLength,
        description: 'Síntoma del problema',
      ),
      'detail': JsonSchema.string(
        maxLength: maxDetailLength,
        description: 'Descripción adicional (opcional)',
      ),
      'includeResolved': JsonSchema.boolean(
        description: 'Incluir incidencias resueltas (por defecto true)',
      ),
      'minScore': JsonSchema.number(
        minimum: 0,
        maximum: 1,
        description: 'Puntuación mínima (por defecto $defaultDuplicateScore)',
      ),
    },
    required: ['title'],
  );

  @override
  ToolOutputSchema get outputSchema => JsonSchema.object(
    properties: {
      'candidates': JsonSchema.array(items: duplicateCandidateSchema),
    },
    required: ['candidates'],
  );

  @override
  ToolAnnotations get annotations => readOnlyAnnotations;

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> args) async {
    final includeResolved = args['includeResolved'] as bool? ?? true;
    final candidates = findDuplicates(
      _repository.all.where((i) => includeResolved || i.status.isActive),
      title: args['title'] as String,
      detail: args['detail'] as String? ?? '',
      minScore: (args['minScore'] as num?)?.toDouble() ?? defaultDuplicateScore,
    );
    return {
      'candidates': [for (final c in candidates) duplicateCandidateJson(c)],
    };
  }
}
