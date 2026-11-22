import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/domain/impact.dart';
import 'package:tickets_service_mcp/src/domain/incident.dart';
import 'package:tickets_service_mcp/src/domain/incident_status.dart';
import 'package:tickets_service_mcp/src/services/duplicates.dart';

/// Esquema JSON del identificador de incidencia.
JsonString incidentIdSchema({String? description}) => JsonSchema.string(
  pattern: incidentIdPattern.pattern,
  description: description ?? 'ID de la incidencia, por ejemplo INC-104',
);

/// Esquema JSON del estado de una incidencia.
JsonString statusSchema({String? description}) => JsonSchema.string(
  enumValues: IncidentStatus.wireValues,
  description: description,
);

/// Esquema JSON del impacto de una incidencia.
JsonString impactSchema({String? description}) =>
    JsonSchema.string(enumValues: Impact.wireValues, description: description);

/// Esquema JSON de una incidencia completa, tal como la devuelve
/// `Incident.toJson`.
final JsonObject incidentSchema = JsonSchema.object(
  properties: {
    'id': incidentIdSchema(),
    'title': JsonSchema.string(),
    'status': statusSchema(),
    'impact': impactSchema(),
    'workaround': JsonSchema.boolean(),
    'created': JsonSchema.string(description: 'Fecha ISO YYYY-MM-DD'),
    'detail': JsonSchema.string(),
    'revision': JsonSchema.integer(
      minimum: 1,
      description: 'Versión actual; necesaria para actualizar',
    ),
  },
  required: [
    'id',
    'title',
    'status',
    'impact',
    'workaround',
    'created',
    'detail',
    'revision',
  ],
);

/// Esquema JSON de una incidencia parecida a otra.
final JsonObject duplicateCandidateSchema = JsonSchema.object(
  properties: {
    'id': incidentIdSchema(),
    'title': JsonSchema.string(),
    'status': statusSchema(),
    'score': JsonSchema.number(
      minimum: 0,
      maximum: 1,
      description: 'Similitud entre 0 y 1',
    ),
    'sharedTerms': JsonSchema.array(
      items: JsonSchema.string(),
      description: 'Raíces de palabra en común',
    ),
  },
  required: ['id', 'title', 'status', 'score', 'sharedTerms'],
);

/// Representación JSON de un [DuplicateCandidate].
Map<String, dynamic> duplicateCandidateJson(DuplicateCandidate candidate) => {
  'id': candidate.incident.id,
  'title': candidate.incident.title,
  'status': candidate.incident.status.value,
  'score': candidate.score,
  'sharedTerms': candidate.sharedTerms,
};
