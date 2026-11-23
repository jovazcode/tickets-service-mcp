import 'dart:convert';

import 'package:test/test.dart';

import '../../helpers/harness.dart';

Incident incidentNumber(int number) => Incident(
  id: 'INC-$number',
  title: 'Incidencia $number',
  status: IncidentStatus.abierta,
  impact: Impact.bajo,
  workaround: false,
  created: '2026-09-01',
  detail: 'Detalle',
);

AuditEvent eventFor(
  AuditOperation operation, [
  Map<String, Object?> changes = const {},
]) => AuditEvent(
  timestamp: 't',
  operation: operation,
  id: 'INC-101',
  changes: {
    for (final MapEntry(:key, :value) in changes.entries)
      key: {'from': null, 'to': value},
  },
);

void main() {
  setUpAll(silenceMcpLogs);

  group('completeIncidentIds', () {
    final incidents = [for (var n = 101; n <= 260; n++) incidentNumber(n)];

    test('sugiere por prefijo del ID o del número, sin mayúsculas', () {
      expect(completeIncidentIds(incidents.take(20), 'inc-11'), [
        for (var n = 110; n <= 119; n++) 'INC-$n',
      ]);
      expect(completeIncidentIds(incidents, ' 25 '), [
        for (var n = 250; n <= 259; n++) 'INC-$n',
      ]);
      expect(completeIncidentIds(incidents, 'XYZ'), isEmpty);
    });

    test('devuelve como mucho $maxCompletions sugerencias', () {
      expect(completeIncidentIds(incidents, ''), hasLength(maxCompletions));
    });
  });

  test('changesIncidentList: altas, borrados y cambios de título', () {
    expect(changesIncidentList(eventFor(AuditOperation.crear)), isTrue);
    expect(changesIncidentList(eventFor(AuditOperation.eliminar)), isTrue);
    expect(
      changesIncidentList(eventFor(AuditOperation.actualizar, {'title': 'x'})),
      isTrue,
    );
    expect(
      changesIncidentList(
        eventFor(AuditOperation.actualizar, {'workaround': true}),
      ),
      isFalse,
    );
    expect(
      changesIncidentList(
        eventFor(AuditOperation.cambiarEstado, {'status': 'resuelta'}),
      ),
      isFalse,
    );
  });

  group('recurso incidencia://{id}', () {
    late Harness harness;

    setUp(() async => harness = await Harness.start());
    tearDown(() => harness.stop());

    test('declara la plantilla y la capacidad listChanged', () async {
      final templates =
          (await harness.client.listResourceTemplates()).resourceTemplates;
      final template = templates.singleWhere(
        (t) => t.uriTemplate == incidentUriTemplate,
      );
      expect(template.title, 'Ficha de incidencia');
      expect(template.mimeType, 'application/json');
      expect(
        harness.client.getServerCapabilities()?.resources?.listChanged,
        isTrue,
      );
    });

    test('lista una ficha por incidencia junto a los documentos', () async {
      final resources = (await harness.client.listResources()).resources;
      final incidents = [
        for (final r in resources)
          if (r.uri.startsWith('incidencia://')) r,
      ];
      expect(incidents.map((r) => r.uri), [
        'incidencia://INC-101',
        'incidencia://INC-102',
        'incidencia://INC-103',
        'incidencia://INC-104',
      ]);
      expect(incidents.last.name, startsWith('INC-104 · '));
      expect(incidents.last.mimeType, 'application/json');
      expect(resources.map((r) => r.uri), contains('docs://proceso_triaje'));
    });

    test('lee la ficha en JSON, también con el ID en minúsculas', () async {
      final result = await harness.client.readResource(
        const ReadResourceRequest(uri: 'incidencia://inc-104'),
      );
      final contents = result.contents.single as TextResourceContents;
      expect(contents.uri, 'incidencia://INC-104');
      expect(contents.mimeType, 'application/json');
      expect(
        jsonDecode(contents.text),
        harness.repository.getById('INC-104').toJson(),
      );
    });

    test('autocompleta el ID', () async {
      final result = await harness.client.complete(
        const CompleteRequest(
          ref: ResourceReference(uri: incidentUriTemplate),
          argument: ArgumentCompletionInfo(name: 'id', value: 'INC-10'),
        ),
      );
      expect(result.completion.values, [
        'INC-101',
        'INC-102',
        'INC-103',
        'INC-104',
      ]);
    });
  });

  /// Crea, cambia de estado, edita sin y con título y borra una incidencia;
  /// devuelve cuántos avisos recibió [notifications] tras cada operación.
  Future<List<int>> noticesPerOperation(
    Harness harness,
    int Function() notifications,
  ) async {
    final counts = <int>[];
    Future<void> run(String tool, Map<String, dynamic> args) async {
      final before = notifications();
      final result = await harness.call(tool, args);
      expect(result.isError, isNot(true), reason: errorText(result));
      await pumpEventQueue();
      counts.add(notifications() - before);
    }

    await run('crear_incidencia', {
      'title': 'La impresora no funciona',
      'detail': 'Nadie puede imprimir.',
      'impact': 'bajo',
    });
    await run('cambiar_estado', {
      'id': 'INC-105',
      'expectedRevision': 1,
      'status': 'en_progreso',
    });
    await run('actualizar_incidencia', {
      'id': 'INC-105',
      'expectedRevision': 2,
      'workaround': true,
    });
    await run('actualizar_incidencia', {
      'id': 'INC-105',
      'expectedRevision': 3,
      'title': 'La impresora de la planta 2 no funciona',
    });
    await run('eliminar_incidencia', {
      'id': 'INC-105',
      'confirm': true,
      'reason': 'Era una prueba',
    });
    return counts;
  }

  /// Avisos esperados: alta, estado, workaround, título y borrado.
  const expectedNotices = [1, 0, 0, 1, 1];

  group('incidencia inexistente', () {
    test('resourceNotFoundCode según la versión del protocolo', () {
      expect(resourceNotFoundCode(null), -32002);
      expect(resourceNotFoundCode('2025-11-25'), -32002);
      expect(resourceNotFoundCode('2026-07-28'), -32602);
    });

    for (final (protocol, code) in [
      (McpProtocol.legacy, -32002),
      (McpProtocol.stable, -32602),
    ]) {
      test('${protocol.name}: responde $code', () async {
        final harness = await Harness.start(protocol: protocol);
        addTearDown(harness.stop);
        await expectLater(
          harness.client.readResource(
            const ReadResourceRequest(uri: 'incidencia://INC-999'),
          ),
          throwsA(isA<McpError>().having((e) => e.code, 'code', code)),
        );
      });
    }
  });

  group('list_changed', () {
    test('MCP 2025-11-25: aviso global en la sesión', () async {
      final harness = await Harness.start(
        writeEnabled: true,
        deleteEnabled: true,
        protocol: McpProtocol.legacy,
      );
      addTearDown(harness.stop);
      var notifications = 0;
      harness.client
          .setNotificationHandler<JsonRpcResourceListChangedNotification>(
            Method.notificationsResourcesListChanged,
            (_) async => notifications++,
            (params, meta) => const JsonRpcResourceListChangedNotification(),
          );
      expect(
        await noticesPerOperation(harness, () => notifications),
        expectedNotices,
      );
    });

    test('MCP 2026-07-28: aviso por subscriptions/listen', () async {
      final harness = await Harness.start(
        writeEnabled: true,
        deleteEnabled: true,
      );
      addTearDown(harness.stop);
      final subscription = harness.client.listenSubscriptions(
        const SubscriptionsListenRequest(
          notifications: SubscriptionFilter(
            resourcesListChanged: true,
            toolsListChanged: true,
          ),
        ),
      );
      final acknowledged = await subscription.acknowledged;
      expect(acknowledged.notifications.resourcesListChanged, isTrue);
      expect(acknowledged.notifications.toolsListChanged, isNull);
      var notifications = 0;
      final listener = subscription.notifications.listen((notification) {
        expect(notification, isA<JsonRpcResourceListChangedNotification>());
        notifications++;
      });
      expect(
        await noticesPerOperation(harness, () => notifications),
        expectedNotices,
      );
      subscription.cancel();
      await listener.cancel();
    });

    test('MCP 2026-07-28: sin resourcesListChanged cierra el flujo', () async {
      final harness = await Harness.start();
      addTearDown(harness.stop);
      final subscription = harness.client.listenSubscriptions(
        const SubscriptionsListenRequest(
          notifications: SubscriptionFilter(toolsListChanged: true),
        ),
      );
      final acknowledged = await subscription.acknowledged;
      expect(acknowledged.notifications.resourcesListChanged, isNull);
      await subscription.done;
    });
  });
}
