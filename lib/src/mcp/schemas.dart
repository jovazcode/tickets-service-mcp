import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/domain/impact.dart';
import 'package:tickets_service_mcp/src/domain/incident.dart';
import 'package:tickets_service_mcp/src/domain/incident_status.dart';

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
  },
  required: [
    'id',
    'title',
    'status',
    'impact',
    'workaround',
    'created',
    'detail',
  ],
);
