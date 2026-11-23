import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:tickets_service_mcp/src/domain/audit_event.dart';
import 'package:tickets_service_mcp/src/domain/domain_exception.dart';
import 'package:tickets_service_mcp/src/domain/incident.dart';
import 'package:tickets_service_mcp/src/store/incident_repository.dart';

/// Plantilla de URI de la ficha de una incidencia.
const incidentUriTemplate = 'incidencia://{id}';

/// URI de la ficha de la incidencia [id].
String incidentUri(String id) => 'incidencia://$id';

/// Máximo de sugerencias que admite MCP en una respuesta de autocompletado.
const maxCompletions = 100;

/// IDs de [incidents] que empiezan por [value], sin distinguir mayúsculas;
/// también acepta solo el número (`"10"` sugiere `INC-101`, `INC-102`…).
List<String> completeIncidentIds(Iterable<Incident> incidents, String value) {
  final prefix = value.trim().toUpperCase();
  return [
    for (final incident in incidents)
      if (incident.id.startsWith(prefix) ||
          incident.id.substring(4).startsWith(prefix))
        incident.id,
  ].take(maxCompletions).toList();
}

/// Si [event] cambia la lista de recursos `incidencia://`: altas, borrados y
/// cambios de título (que forma parte del nombre del recurso).
bool changesIncidentList(AuditEvent event) => switch (event.operation) {
  AuditOperation.crear || AuditOperation.eliminar => true,
  AuditOperation.actualizar => event.changes.containsKey('title'),
  AuditOperation.cambiarEstado => false,
};

/// Registra la plantilla [incidentUriTemplate] sobre [repository]: lista una
/// ficha por incidencia, autocompleta el ID y envía
/// `notifications/resources/list_changed` cuando cambia la lista.
///
/// El aviso llega de dos formas según el protocolo del cliente: en sesiones
/// MCP 2025-11-25 (con `initialize`) se envía globalmente; en MCP 2026-07-28
/// (sin estado) solo por las suscripciones `subscriptions/listen` que lo
/// pidan, como exige esa versión.
///
/// El servidor debe declarar la capacidad `resources.listChanged`.
void registerIncidentResource(McpServer server, IncidentRepository repository) {
  server.registerResourceTemplate(
    'incidencia',
    ResourceTemplateRegistration(
      incidentUriTemplate,
      listCallback: (extra) => ListResourcesResult(
        resources: [
          for (final incident in repository.all)
            Resource(
              uri: incidentUri(incident.id),
              name: '${incident.id} · ${incident.title}',
            ),
        ],
      ),
      completeCallbacks: {
        'id': (value) => completeIncidentIds(repository.all, value),
      },
    ),
    (
      description:
          'Ficha de una incidencia en JSON, con su estado actual y su '
          'revisión.',
      mimeType: 'application/json',
    ),
    title: 'Ficha de incidencia',
    (uri, variables, extra) {
      final id = '${variables['id']}'.toUpperCase();
      final Incident incident;
      try {
        incident = repository.getById(id);
      } on DomainException catch (error) {
        throw McpError(ErrorCode.resourceNotFound.value, error.message, {
          'uri': uri.toString(),
        });
      }
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: incidentUri(id),
            mimeType: 'application/json',
            text: const JsonEncoder.withIndent('  ').convert(incident.toJson()),
          ),
        ],
      );
    },
  );
  final listChanges = repository.changes.where(changesIncidentList)
    ..listen((_) {
      // Solo las sesiones con `initialize` conocen al cliente; en las sin
      // estado el SDK descartaría el aviso global con un warning.
      if (server.server.getClientVersion() != null) {
        server.sendResourceListChanged();
      }
    });
  _handleListenSubscriptions(server, listChanges);
}

/// Atiende `subscriptions/listen` (MCP 2026-07-28): confirma lo que el
/// servidor admite de lo pedido y, si incluye `resourcesListChanged`, mantiene
/// el flujo abierto reenviando cada aviso de [listChanges] hasta que el
/// cliente cancela la suscripción.
void _handleListenSubscriptions(McpServer server, Stream<void> listChanges) {
  server.server.setRequestHandler<JsonRpcSubscriptionsListenRequest>(
    Method.subscriptionsListen,
    (request, extra) async {
      final acknowledged = request.listenParams.notifications.acknowledgedBy(
        server.server.getCapabilities(),
      );
      await extra.sendSubscriptionAcknowledged(acknowledged);
      if (acknowledged.resourcesListChanged != true || extra.signal.aborted) {
        return const EmptyResult();
      }
      final subscription = listChanges.listen(
        (_) => extra.sendSubscriptionNotification(
          const JsonRpcResourceListChangedNotification(),
        ),
      );
      await extra.signal.onAbort.first;
      await subscription.cancel();
      return const EmptyResult();
    },
    (id, params, meta) => JsonRpcSubscriptionsListenRequest(
      id: id,
      listenParams: SubscriptionsListenRequest.fromJson(params!),
      meta: meta,
    ),
  );
}
