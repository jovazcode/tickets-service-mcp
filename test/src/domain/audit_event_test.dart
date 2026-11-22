import 'package:test/test.dart';
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

const incident = Incident(
  id: 'INC-101',
  title: 'Título',
  status: IncidentStatus.abierta,
  impact: Impact.bajo,
  workaround: false,
  created: '2026-09-01',
  detail: 'Detalle',
);

void main() {
  group('AuditEvent.between', () {
    test('en un alta guarda la ficha y no cambios', () {
      final event = AuditEvent.between(
        timestamp: 't',
        operation: AuditOperation.crear,
        before: null,
        after: incident,
      );
      expect(event.id, 'INC-101');
      expect(event.snapshot?.toJson(), incident.toJson());
      expect(event.changes, isEmpty);
      expect(event.toJson().containsKey('changes'), isFalse);
      expect(event.toJson().containsKey('reason'), isFalse);
    });

    test('en una edición guarda solo los campos cambiados', () {
      final event = AuditEvent.between(
        timestamp: 't',
        operation: AuditOperation.cambiarEstado,
        before: incident,
        after: incident.copyWith(
          status: IncidentStatus.enProgreso,
          revision: 2,
        ),
        reason: 'Empiezo',
      );
      expect(event.snapshot, isNull);
      expect(event.changes, {
        'status': {'from': 'abierta', 'to': 'en_progreso'},
      });
      expect(event.toJson(), {
        'timestamp': 't',
        'operation': 'cambiar_estado',
        'id': 'INC-101',
        'reason': 'Empiezo',
        'changes': {
          'status': {'from': 'abierta', 'to': 'en_progreso'},
        },
      });
    });

    test('en un borrado guarda la ficha anterior', () {
      final event = AuditEvent.between(
        timestamp: 't',
        operation: AuditOperation.eliminar,
        before: incident,
        after: null,
        reason: 'Duplicada',
      );
      expect(event.snapshot?.id, 'INC-101');
      expect(event.reason, 'Duplicada');
    });
  });

  group('AuditEvent.fromJson', () {
    test('es simétrico con toJson', () {
      final events = [
        AuditEvent.between(
          timestamp: 't',
          operation: AuditOperation.crear,
          before: null,
          after: incident,
        ),
        AuditEvent.between(
          timestamp: 't',
          operation: AuditOperation.actualizar,
          before: incident,
          after: incident.copyWith(title: 'Otro', revision: 2),
        ),
      ];
      for (final event in events) {
        expect(AuditEvent.fromJson(event.toJson()).toJson(), event.toJson());
      }
    });

    final invalid = <String, Map<String, dynamic>>{
      'sin timestamp': {'operation': 'crear', 'id': 'INC-101'},
      'operación desconocida': {
        'timestamp': 't',
        'operation': 'mover',
        'id': 'INC-101',
      },
      'reason no texto': {
        'timestamp': 't',
        'operation': 'crear',
        'id': 'INC-101',
        'reason': 3,
      },
      'cambio que no es objeto': {
        'timestamp': 't',
        'operation': 'actualizar',
        'id': 'INC-101',
        'changes': {'title': 'x'},
      },
      'snapshot que no es objeto': {
        'timestamp': 't',
        'operation': 'crear',
        'id': 'INC-101',
        'snapshot': 'x',
      },
    };
    for (final MapEntry(key: name, value: json) in invalid.entries) {
      test('rechaza $name', () {
        expect(() => AuditEvent.fromJson(json), throwsFormatException);
      });
    }
  });

  test('AuditOperation.wireValues', () {
    expect(AuditOperation.wireValues, [
      'crear',
      'actualizar',
      'cambiar_estado',
      'eliminar',
    ]);
  });
}
