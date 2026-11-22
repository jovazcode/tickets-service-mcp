import 'package:test/test.dart';
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

Map<String, dynamic> validJson() => {
  'id': 'INC-101',
  'title': 'El acceso falla',
  'status': 'abierta',
  'impact': 'bajo',
  'workaround': true,
  'created': '2026-09-01',
  'detail': 'Detalle',
  'revision': 3,
};

void main() {
  group('Incident', () {
    test('fromJson y toJson son simétricos', () {
      final json = validJson();
      expect(Incident.fromJson(json).toJson(), json);
    });

    test('fromJson lee todos los campos', () {
      final incident = Incident.fromJson(
        validJson()..['status'] = 'en_progreso',
      );
      expect(incident.id, 'INC-101');
      expect(incident.status, IncidentStatus.enProgreso);
      expect(incident.impact, Impact.bajo);
      expect(incident.workaround, isTrue);
    });

    test('sin revision (como en la fixture) empieza en 1', () {
      expect(Incident.fromJson(validJson()..remove('revision')).revision, 1);
    });

    test('copyWith cambia solo lo indicado', () {
      final original = Incident.fromJson(validJson());
      final copy = original.copyWith(
        title: 'Nuevo',
        status: IncidentStatus.resuelta,
        impact: Impact.alto,
        workaround: false,
        detail: 'Otro',
        revision: 4,
      );
      expect(copy.toJson(), {
        ...validJson(),
        'title': 'Nuevo',
        'status': 'resuelta',
        'impact': 'alto',
        'workaround': false,
        'detail': 'Otro',
        'revision': 4,
      });
      expect(original.copyWith().toJson(), original.toJson());
    });

    final invalid = <String, void Function(Map<String, dynamic>)>{
      'revisión no entera': (json) => json['revision'] = '2',
      'revisión menor que 1': (json) => json['revision'] = 0,
      'falta un campo': (json) => json.remove('title'),
      'tipo incorrecto': (json) => json['workaround'] = 'si',
      'ID con formato inválido': (json) => json['id'] = 'TCK-1',
      'fecha inválida': (json) => json['created'] = 'ayer',
      'estado desconocido': (json) => json['status'] = 'cerrada',
      'impacto desconocido': (json) => json['impact'] = 'medio',
    };
    for (final MapEntry(key: name, value: mutate) in invalid.entries) {
      test('fromJson rechaza $name', () {
        final json = validJson();
        mutate(json);
        expect(() => Incident.fromJson(json), throwsFormatException);
      });
    }
  });

  group('enums', () {
    test('wireValues expone los valores serializados', () {
      expect(IncidentStatus.wireValues, ['abierta', 'en_progreso', 'resuelta']);
      expect(Impact.wireValues, ['alto', 'bajo']);
    });

    test('parse reconoce valores válidos', () {
      expect(IncidentStatus.parse('resuelta'), IncidentStatus.resuelta);
      expect(Impact.parse('alto'), Impact.alto);
    });
  });

  group('DomainException', () {
    test('toString incluye código y mensaje', () {
      expect(
        const DomainException('NOT_FOUND', 'No existe').toString(),
        'NOT_FOUND: No existe',
      );
    });
  });
}
