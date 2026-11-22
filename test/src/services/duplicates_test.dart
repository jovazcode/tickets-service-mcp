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

  List<String> ids(List<DuplicateCandidate> candidates) => [
    for (final c in candidates) c.incident.id,
  ];

  group('significantTerms', () {
    test('quita tildes, palabras vacías y cortas, y recorta raíces', () {
      expect(significantTerms('La exportación de las cuentas NO va'), {
        'export',
        'cuenta',
      });
    });
  });

  group('findDuplicates', () {
    test('encuentra la incidencia parecida con sus términos comunes', () {
      final result = findDuplicates(
        incidents,
        title: 'La exportación falla',
        detail: 'No sale el informe',
      );
      expect(ids(result), ['INC-104']);
      expect(result.single.sharedTerms, ['export', 'inform']);
      expect(result.single.score, 0.5);
    });

    test('ordena de más a menos parecida y respeta el límite', () {
      final result = findDuplicates(
        incidents,
        title: 'cuenta prueba acceso guardar incidencias exportación informe',
        minScore: 0,
      );
      expect(result.first.score >= result.last.score, isTrue);
      expect(
        findDuplicates(
          incidents,
          title: 'cuenta prueba acceso exportación',
          minScore: 0,
          limit: 1,
        ),
        hasLength(1),
      );
    });

    test('sin términos significativos o sin parecido no devuelve nada', () {
      expect(findDuplicates(incidents, title: 'de la el'), isEmpty);
      expect(
        findDuplicates(incidents, title: 'La impresora no funciona'),
        isEmpty,
      );
    });

    test('con un solo término basta una coincidencia', () {
      expect(ids(findDuplicates(incidents, title: 'exportación')), ['INC-104']);
    });

    test('exige dos términos comunes si se buscan varios', () {
      expect(
        findDuplicates(incidents, title: 'exportación impresora escáner'),
        isEmpty,
      );
    });

    test('filtra por puntuación mínima', () {
      expect(
        findDuplicates(
          incidents,
          title: 'La exportación falla',
          detail: 'No sale el informe',
          minScore: 0.9,
        ),
        isEmpty,
      );
    });
  });
}
