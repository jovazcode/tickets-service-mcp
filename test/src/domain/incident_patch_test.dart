import 'package:test/test.dart';
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

const base = Incident(
  id: 'INC-101',
  title: 'Título',
  status: IncidentStatus.abierta,
  impact: Impact.bajo,
  workaround: true,
  created: '2026-09-01',
  detail: 'Detalle',
);

Matcher throwsValidation() => throwsA(
  isA<DomainException>().having((e) => e.code, 'code', 'VALIDATION_ERROR'),
);

void main() {
  group('IncidentPatch', () {
    test('isEmpty sin campos', () {
      expect(const IncidentPatch().isEmpty, isTrue);
      expect(const IncidentPatch(workaround: false).isEmpty, isFalse);
    });

    test('applyTo cambia solo lo indicado y sube la revisión', () {
      final updated = const IncidentPatch(
        detail: '  Nuevo detalle ',
        status: IncidentStatus.resuelta,
      ).applyTo(base);
      expect(updated.detail, 'Nuevo detalle');
      expect(updated.status, IncidentStatus.resuelta);
      expect(updated.title, base.title);
      expect(updated.impact, base.impact);
      expect(updated.revision, 2);
    });

    test('applyTo rechaza un patch vacío', () {
      expect(() => const IncidentPatch().applyTo(base), throwsValidation());
    });

    test('applyTo rechaza texto vacío o demasiado largo', () {
      expect(
        () => const IncidentPatch(title: ' ').applyTo(base),
        throwsValidation(),
      );
      expect(
        () => IncidentPatch(detail: 'x' * (maxDetailLength + 1)).applyTo(base),
        throwsValidation(),
      );
    });
  });
}
