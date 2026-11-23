import 'package:test/test.dart';

import '../../helpers/harness.dart';

const Map<String, Object> deleteArgs = {
  'id': 'INC-102',
  'confirm': true,
  'reason': 'Era una prueba',
};

ElicitResult accept({required bool confirmed}) => ElicitResult(
  action: 'accept',
  content: {deleteConfirmationField: confirmed},
);

void main() {
  setUpAll(silenceMcpLogs);

  test('deleteConfirmationRequest describe la incidencia y el motivo', () {
    const incident = Incident(
      id: 'INC-101',
      title: 'No arranca',
      status: IncidentStatus.abierta,
      impact: Impact.alto,
      workaround: false,
      created: '2026-09-01',
      detail: 'Detalle',
    );
    final request = deleteConfirmationRequest(incident, 'Duplicada');
    expect(request.isFormMode, isTrue);
    expect(
      request.message,
      allOf(
        contains('INC-101 «No arranca»'),
        contains('estado abierta, impacto alto'),
        contains('Motivo: Duplicada'),
      ),
    );
    expect(request.requestedSchema?.toJson(), {
      'type': 'object',
      'properties': {
        deleteConfirmationField: {
          'type': 'boolean',
          'title': 'Borrar definitivamente',
          'description': 'Marca la casilla para confirmar el borrado',
          'default': false,
        },
      },
      'required': [deleteConfirmationField],
    });
  });

  for (final (protocol, label) in [
    (McpProtocol.legacy, 'MCP 2025-11-25 (elicitation/create)'),
    (McpProtocol.stable, 'MCP 2026-07-28 (input_required)'),
  ]) {
    group(label, () {
      late List<ElicitRequest> asked;

      Future<Harness> start(ElicitResult answer) async {
        asked = [];
        final harness = await Harness.start(
          writeEnabled: true,
          deleteEnabled: true,
          protocol: protocol,
          onElicit: (request) async {
            asked.add(request);
            return answer;
          },
        );
        addTearDown(harness.stop);
        return harness;
      }

      test('borra si el usuario confirma', () async {
        final harness = await start(accept(confirmed: true));
        final result = await harness.call('eliminar_incidencia', deleteArgs);
        expect(result.isError, isNot(true), reason: errorText(result));
        expect((structured(result)['deleted'] as Map)['id'], 'INC-102');
        expect(asked.single.message, contains('INC-102'));
        expect(
          harness.repository.all.map((i) => i.id),
          isNot(contains('INC-102')),
        );
      });

      for (final (name, answer, code) in [
        ('acepta sin marcar', accept(confirmed: false), 'DELETE_DECLINED'),
        ('rechaza', const ElicitResult(action: 'decline'), 'DELETE_DECLINED'),
        ('cancela', const ElicitResult(action: 'cancel'), 'DELETE_CANCELLED'),
      ]) {
        test('si el usuario $name responde $code y no borra', () async {
          final harness = await start(answer);
          final result = await harness.call('eliminar_incidencia', deleteArgs);
          expect(errorText(result), startsWith(code));
          expect(asked, hasLength(1));
          expect(harness.repository.getById('INC-102').id, 'INC-102');
        });
      }

      test('no pregunta si el borrado fallaría de todos modos', () async {
        final harness = await start(accept(confirmed: true));
        final missing = await harness.call('eliminar_incidencia', {
          ...deleteArgs,
          'id': 'INC-999',
        });
        expect(errorText(missing), startsWith('NOT_FOUND'));
        final unconfirmed = await harness.call('eliminar_incidencia', {
          ...deleteArgs,
          'confirm': false,
        });
        expect(errorText(unconfirmed), startsWith('CONFIRMATION_REQUIRED'));
        expect(asked, isEmpty);
      });

      test('sin elicitación en el cliente basta confirm: true', () async {
        final harness = await Harness.start(
          writeEnabled: true,
          deleteEnabled: true,
          protocol: protocol,
        );
        addTearDown(harness.stop);
        final result = await harness.call('eliminar_incidencia', deleteArgs);
        expect(result.isError, isNot(true), reason: errorText(result));
      });
    });
  }

  test('no pregunta si el borrado está desactivado', () async {
    var asked = 0;
    final harness = await Harness.start(
      writeEnabled: true,
      onElicit: (_) async {
        asked++;
        return accept(confirmed: true);
      },
    );
    addTearDown(harness.stop);
    final result = await harness.call('eliminar_incidencia', deleteArgs);
    expect(errorText(result), startsWith('DELETE_DISABLED'));
    expect(asked, 0);
  });
}
