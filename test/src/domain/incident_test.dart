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

    final invalid = <String, void Function(Map<String, dynamic>)>{
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
