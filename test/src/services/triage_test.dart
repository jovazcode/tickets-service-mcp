import 'package:test/test.dart';
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

Incident inc(
  String id, {
  IncidentStatus status = IncidentStatus.abierta,
  Impact impact = Impact.bajo,
  bool workaround = false,
  String created = '2026-09-01',
}) => Incident(
  id: id,
  title: 't',
  status: status,
  impact: impact,
  workaround: workaround,
  created: created,
  detail: 'd',
);

List<String> ids(Iterable<Incident> incidents) => [
  for (final i in incidents) i.id,
];

void main() {
  group('IncidentStatus', () {
    test('isActive y transiciones', () {
      expect(IncidentStatus.abierta.isActive, isTrue);
      expect(IncidentStatus.enProgreso.isActive, isTrue);
      expect(IncidentStatus.resuelta.isActive, isFalse);
      expect(IncidentStatus.abierta.allowedNext, {
        IncidentStatus.enProgreso,
        IncidentStatus.resuelta,
      });
      expect(IncidentStatus.enProgreso.allowedNext, {
        IncidentStatus.abierta,
        IncidentStatus.resuelta,
      });
      expect(IncidentStatus.resuelta.allowedNext, {IncidentStatus.abierta});
      expect(
        IncidentStatus.resuelta.isReopening(IncidentStatus.abierta),
        isTrue,
      );
      expect(
        IncidentStatus.enProgreso.isReopening(IncidentStatus.abierta),
        isFalse,
      );
    });
  });

  group('priorityQueue', () {
    test('con la fixture la primera es INC-104', () async {
      final repository = await IncidentRepository.open(
        fixturePath: 'data/tickets.json',
        storePath: 'no_existe/tickets.local.json',
        auditPath: 'no_existe/tickets.audit.jsonl',
      );
      expect(ids(priorityQueue(repository.all)), [
        'INC-104',
        'INC-102',
        'INC-101',
      ]);
    });

    test('aplica los criterios en orden y excluye resueltas', () {
      final queue = priorityQueue([
        inc('INC-110', created: '2026-01-01'),
        inc('INC-111', impact: Impact.alto, workaround: true),
        inc('INC-112', impact: Impact.alto, created: '2026-09-02'),
        inc('INC-113', impact: Impact.alto),
        inc('INC-109', impact: Impact.alto),
        inc('INC-114', status: IncidentStatus.resuelta, impact: Impact.alto),
        inc('INC-115', status: IncidentStatus.enProgreso, workaround: true),
      ]);
      expect(ids(queue), [
        'INC-109', // alto, sin workaround, misma fecha que 113: ID menor
        'INC-113',
        'INC-112', // alto, sin workaround, más reciente
        'INC-111', // alto con workaround
        'INC-110', // bajo sin workaround
        'INC-115', // bajo con workaround (en_progreso cuenta como activa)
      ]);
    });

    test('vacía si no hay activas', () {
      expect(
        priorityQueue([inc('INC-101', status: IncidentStatus.resuelta)]),
        isEmpty,
      );
    });
  });

  group('summarize', () {
    test('cuenta por estado, impacto y workaround', () {
      final summary = summarize([
        inc('INC-103', impact: Impact.alto, created: '2026-09-03'),
        inc('INC-101', created: '2026-09-03', workaround: true),
        inc(
          'INC-102',
          status: IncidentStatus.enProgreso,
          created: '2026-09-05',
        ),
        inc('INC-100', status: IncidentStatus.resuelta, created: '2026-01-01'),
      ]);
      expect(summary.toJson(), {
        'total': 4,
        'active': 3,
        'critical': 1,
        'byStatus': {'abierta': 2, 'en_progreso': 1, 'resuelta': 1},
        'byImpact': {'alto': 1, 'bajo': 3},
        'byWorkaround': {'con': 1, 'sin': 3},
        'oldestActive': {'id': 'INC-101', 'created': '2026-09-03'},
      });
    });

    test('sin activas no incluye oldestActive', () {
      final json = summarize([inc('INC-100', status: IncidentStatus.resuelta)])
          .toJson();
      expect(json.containsKey('oldestActive'), isFalse);
      expect(summarize(const []).toJson()['total'], 0);
    });
  });
}
