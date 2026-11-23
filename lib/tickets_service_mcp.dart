/// Servidor MCP local (stdio) para la mesa de incidencias
library;

export 'src/domain/audit_event.dart';
export 'src/domain/domain_exception.dart';
export 'src/domain/impact.dart';
export 'src/domain/incident.dart';
export 'src/domain/incident_patch.dart';
export 'src/domain/incident_status.dart';
export 'src/domain/new_incident.dart';
export 'src/domain/text_rules.dart';
export 'src/mcp/resources/incident_resource.dart';
export 'src/mcp/server.dart';
export 'src/mcp/tools/delete_incident_tool.dart'
    show
        deleteConfirmationField,
        deleteConfirmationKey,
        deleteConfirmationRequest;
export 'src/mcp/user_confirmation.dart';
export 'src/server_config.dart';
export 'src/services/duplicates.dart';
export 'src/services/incident_search.dart';
export 'src/services/triage.dart';
export 'src/store/audit_log.dart';
export 'src/store/incident_repository.dart';
