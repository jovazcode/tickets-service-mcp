import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/domain/domain_exception.dart';
import 'package:tickets_service_mcp/src/domain/text_rules.dart';
import 'package:tickets_service_mcp/src/mcp/schemas.dart';
import 'package:tickets_service_mcp/src/mcp/tools/base_tool.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// {@template delete_incident_tool}
/// `eliminar_incidencia`: borra físicamente una incidencia.
/// {@endtemplate}
class DeleteIncidentTool extends BaseTool {
  /// {@macro delete_incident_tool}
  new(this._repository);

  final IncidentRepository _repository;

  @override
  String get name => 'eliminar_incidencia';

  @override
  String get title => 'Eliminar incidencia';

  @override
  String get description =>
      'Borra físicamente una incidencia. No se puede deshacer y su ID no se '
      'reutiliza. Úsala solo si el usuario lo pide expresamente para esa '
      'incidencia: muéstrale antes la ficha y pide confirmación. Exige '
      'confirm: true y un motivo. Requiere escritura y borrado habilitados '
      '(WRITE_DISABLED o DELETE_DISABLED si no).';

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

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> args) async {
    if (args['confirm'] != true) {
      throw const DomainException(
        'CONFIRMATION_REQUIRED',
        'Para borrar hay que enviar confirm: true tras confirmarlo con el '
            'usuario',
      );
    }
    final reason = (args['reason'] as String).trim();
    final deleted = await _repository.delete(
      args['id'] as String,
      reason: reason,
    );
    return {'deleted': deleted.toJson(), 'reason': reason};
  }
}
