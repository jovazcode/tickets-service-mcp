import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/domain/domain_exception.dart';
import 'package:tickets_service_mcp/src/domain/incident.dart';
import 'package:tickets_service_mcp/src/domain/text_rules.dart';
import 'package:tickets_service_mcp/src/mcp/schemas.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/mcp/user_confirmation.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// Clave de la pregunta de confirmación en `inputRequests`/`inputResponses`.
const deleteConfirmationKey = 'confirmar_borrado';

/// Campo booleano del formulario de confirmación.
const deleteConfirmationField = 'confirmar';

/// Formulario de elicitación que pide al usuario confirmar el borrado de
/// [incident] con el motivo [reason].
ElicitRequest deleteConfirmationRequest(Incident incident, String reason) =>
    ElicitRequest.form(
      message:
          'Vas a borrar definitivamente ${incident.id} «${incident.title}» '
          '(estado ${incident.status.value}, impacto '
          '${incident.impact.value}). Motivo: $reason. No se puede deshacer. '
          '¿Confirmas el borrado?',
      requestedSchema: JsonSchema.object(
        properties: {
          deleteConfirmationField: JsonSchema.boolean(
            title: 'Borrar definitivamente',
            description: 'Marca la casilla para confirmar el borrado',
            defaultValue: false,
          ),
        },
        required: [deleteConfirmationField],
      ),
    );

/// {@template delete_incident_tool}
/// `eliminar_incidencia`: borra físicamente una incidencia.
/// {@endtemplate}
class DeleteIncidentTool extends BaseTool {
  /// {@macro delete_incident_tool}
  ///
  /// El servidor se usa para pedir confirmación al usuario (elicitación).
  new(this._repository, this._server);

  final IncidentRepository _repository;
  final McpServer _server;

  @override
  String get name => 'eliminar_incidencia';

  @override
  String get title => 'Eliminar incidencia';

  @override
  String get description =>
      'Borra físicamente una incidencia. No se puede deshacer y su ID no se '
      'reutiliza. Úsala solo si el usuario lo pide expresamente para esa '
      'incidencia: muéstrale antes la ficha y pide confirmación. Exige '
      'confirm: true y un motivo. Si el cliente admite elicitación, el '
      'servidor pide además confirmación directamente al usuario y responde '
      'DELETE_DECLINED o DELETE_CANCELLED si no la da. Requiere escritura y '
      'borrado habilitados (WRITE_DISABLED o DELETE_DISABLED si no).';

  @override
  ToolInputSchema get inputSchema => JsonSchema.object(
    properties: {
      'id': incidentIdSchema(),
      'confirm': JsonSchema.boolean(
        description: 'Debe ser true: confirma que el usuario lo ha pedido',
      ),
      'reason': JsonSchema.string(
        minLength: 1,
        maxLength: maxReasonLength,
        description: 'Por qué se borra',
      ),
    },
    required: ['id', 'confirm', 'reason'],
  );

  @override
  ToolOutputSchema get outputSchema => JsonSchema.object(
    properties: {'deleted': incidentSchema, 'reason': JsonSchema.string()},
    required: ['deleted', 'reason'],
  );

  @override
  ToolAnnotations get annotations =>
      const ToolAnnotations(idempotentHint: true, openWorldHint: false);

  /// Valida, pide confirmación al usuario si el cliente lo admite y, si la
  /// da, borra con [run].
  @override
  Future<BaseResultData> execute(
    Map<String, dynamic> args,
    RequestHandlerExtra extra,
  ) => guard(() async {
    _ensureConfirmFlag(args);
    final reason = (args['reason'] as String).trim();
    final incident = _repository.checkDeletable(
      args['id'] as String,
      reason: reason,
    );
    final confirmation = await askUser(
      _server,
      extra,
      key: deleteConfirmationKey,
      request: deleteConfirmationRequest(incident, reason),
    );
    switch (confirmation) {
      case ConfirmationPending(:final result):
        return result;
      case ConfirmationAnswered(:final answer):
        _ensureAccepted(answer, incident.id);
      case ConfirmationUnsupported():
        // Sin elicitación, confirm: true es la única confirmación.
        break;
    }
    return CallToolResult.fromStructuredContent(await run(args));
  });

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> args) async {
    _ensureConfirmFlag(args);
    final reason = (args['reason'] as String).trim();
    final deleted = await _repository.delete(
      args['id'] as String,
      reason: reason,
    );
    return {'deleted': deleted.toJson(), 'reason': reason};
  }

  void _ensureConfirmFlag(Map<String, dynamic> args) {
    if (args['confirm'] != true) {
      throw const DomainException(
        'CONFIRMATION_REQUIRED',
        'Para borrar hay que enviar confirm: true tras confirmarlo con el '
            'usuario',
      );
    }
  }

  /// Lanza `DELETE_DECLINED` si el usuario rechaza o no marca la casilla, y
  /// `DELETE_CANCELLED` si cierra el formulario sin responder.
  void _ensureAccepted(ElicitResult answer, String id) {
    if (answer.cancelled) {
      throw DomainException(
        'DELETE_CANCELLED',
        'El usuario cerró la confirmación sin responder; no se ha borrado '
            '$id. Pregúntale si quiere intentarlo de nuevo.',
      );
    }
    if (!answer.accepted || answer.content?[deleteConfirmationField] != true) {
      throw DomainException(
        'DELETE_DECLINED',
        'El usuario ha rechazado el borrado de $id; no se ha borrado nada.',
      );
    }
  }
}
