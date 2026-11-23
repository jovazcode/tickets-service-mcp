import 'package:test/test.dart';
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

void main() {
  late List<Incident> incidents;

  setUpAll(() async {
    incidents = (await IncidentRepository.open(
      fixturePath: 'data/tickets.json',
      storePath: 'no_existe/tickets.local.json',
      auditPath: 'no_existe/tickets.audit.jsonl',
    )).all;
  });

  List<String> ids(SearchResult result) => [
    for (final incident in result.items) incident.id,
  ];

  group('searchIncidents', () {
    test('sin criterios devuelve todas', () {
      final result = searchIncidents(incidents, const SearchCriteria());
      expect(result.total, 4);
      expect(ids(result), ['INC-101', 'INC-102', 'INC-103', 'INC-104']);
    });

    test('el texto ignora mayúsculas y tildes', () {
      final result = searchIncidents(
        incidents,
        const SearchCriteria(text: 'EXPORTACION'),
      );
      expect(ids(result), ['INC-104']);
    });

    test('el texto también busca en el detalle y el ID', () {
      expect(
        ids(searchIncidents(incidents, const SearchCriteria(text: 'visual'))),
        ['INC-102'],
      );
      expect(
        ids(searchIncidents(incidents, const SearchCriteria(text: 'inc-103'))),
        ['INC-103'],
      );
    });

    test('un texto en blanco no filtra', () {
      final result = searchIncidents(
        incidents,
        const SearchCriteria(text: '   '),
      );
      expect(result.total, 4);
    });

    test('combina filtros de estado, impacto y workaround', () {
      expect(
        ids(
          searchIncidents(
            incidents,
            const SearchCriteria(status: IncidentStatus.abierta),
          ),
        ),
        ['INC-101', 'INC-102', 'INC-104'],
      );
      expect(
        ids(
          searchIncidents(incidents, const SearchCriteria(impact: Impact.alto)),
        ),
        ['INC-103', 'INC-104'],
      );
      expect(
        ids(searchIncidents(incidents, const SearchCriteria(workaround: true))),
        ['INC-101'],
      );
      expect(
        ids(
          searchIncidents(
            incidents,
            const SearchCriteria(
              status: IncidentStatus.abierta,
              impact: Impact.alto,
              workaround: false,
            ),
          ),
        ),
        ['INC-104'],
      );
    });

    test('pagina con limit y offset sin alterar el total', () {
      final result = searchIncidents(
        incidents,
        const SearchCriteria(limit: 2, offset: 1),
      );
      expect(ids(result), ['INC-102', 'INC-103']);
      expect(result.total, 4);
    });
  });

  test('normalizeText quita tildes y pasa a minúsculas', () {
    expect(normalizeText('Exportación ÑANDÚ Ç'), 'exportacion nandu c');
  });
}
