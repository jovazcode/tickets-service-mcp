import 'package:test/test.dart';
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

void main() {
  group('NewIncident.validated', () {
    test('recorta espacios y conserva el resto', () {
      final valid = const NewIncident(
        title: ' Título ',
        detail: ' Detalle ',
        impact: Impact.alto,
        workaround: true,
      ).validated();
      expect(valid.title, 'Título');
      expect(valid.detail, 'Detalle');
      expect(valid.impact, Impact.alto);
      expect(valid.workaround, isTrue);
    });

    final invalid = {
      'título vacío': const NewIncident(
        title: '   ',
        detail: 'd',
        impact: Impact.bajo,
      ),
      'detalle vacío': const NewIncident(
        title: 't',
        detail: '',
        impact: Impact.bajo,
      ),
      'título demasiado largo': NewIncident(
        title: 'x' * (NewIncident.maxTitleLength + 1),
        detail: 'd',
        impact: Impact.bajo,
      ),
    };
    for (final MapEntry(key: name, value: draft) in invalid.entries) {
      test('rechaza $name', () {
        expect(
          draft.validated,
          throwsA(
            isA<DomainException>().having(
              (e) => e.code,
              'code',
              'VALIDATION_ERROR',
            ),
          ),
        );
      });
    }
  });
}
