import 'dart:convert';
import 'dart:io';

import 'package:tickets_service_mcp/src/domain/audit_event.dart';
import 'package:tickets_service_mcp/src/domain/domain_exception.dart';
import 'package:tickets_service_mcp/src/domain/incident.dart';
import 'package:tickets_service_mcp/src/domain/incident_patch.dart';
import 'package:tickets_service_mcp/src/domain/incident_status.dart';
import 'package:tickets_service_mcp/src/domain/new_incident.dart';
import 'package:tickets_service_mcp/src/domain/text_rules.dart';
import 'package:tickets_service_mcp/src/store/audit_log.dart';

/// {@template incident_repository}
/// Acceso a las incidencias de la mesa.
///
/// Las incidencias viven en memoria. Si la escritura está habilitada, cada
/// cambio se guarda de forma atómica en el almacén de trabajo y se registra
/// en la auditoría; la fixture original nunca se modifica.
/// {@endtemplate}
class IncidentRepository {
  /// {@macro incident_repository}
  ///
  /// [nextId] es el número del siguiente ID; por defecto, el mayor existente
  /// más uno. Si [writeEnabled] es `true`, [storePath] y [audit] son
  /// obligatorios.
  /// Borrar exige además [_deleteEnabled].
  ///
  /// Lanza [FormatException] si hay IDs duplicados o si [nextId] no es mayor
  /// que todos los existentes.
  new(
    Iterable<Incident> incidents, {
    int? nextId,
    String? storePath,
    AuditLog? audit,
    bool writeEnabled = false,
    this._deleteEnabled = false,
    DateTime Function()? clock,
  }) : assert(
         !writeEnabled || (storePath != null && audit != null),
         'storePath y audit son obligatorios con escritura',
       ),
       _incidents = List.unmodifiable(incidents),
       _storePath = storePath,
       _audit = audit,
       _writeEnabled = writeEnabled,
       _clock = clock ?? DateTime.now,
       _nextId = 0 {
    final ids = <String>{};
    var maxNumber = 0;
    for (final incident in _incidents) {
      if (!ids.add(incident.id)) {
        throw FormatException('ID duplicado: ${incident.id}');
      }
      final number = _idNumber(incident.id);
      if (number > maxNumber) maxNumber = number;
    }
    if (nextId != null && nextId <= maxNumber) {
      throw FormatException('nextId ($nextId) debe ser mayor que $maxNumber');
    }
    _nextId = nextId ?? maxNumber + 1;
  }

  /// Abre el repositorio.
  ///
  /// Si existe el almacén de trabajo en [storePath], se carga de ahí (aunque
  /// la escritura esté deshabilitada, para no perder lo creado antes); si no,
  /// se parte de la fixture en [fixturePath]. Los cambios se registran en el
  /// fichero de auditoría [auditPath].
  ///
  /// Lanza [FileSystemException] si no se puede leer el fichero elegido y
  /// [FormatException] si su contenido no es válido.
  static Future<IncidentRepository> open({
    required String fixturePath,
    required String storePath,
    required String auditPath,
    bool writeEnabled = false,
    bool deleteEnabled = false,
    DateTime Function()? clock,
  }) async {
    final audit = AuditLog(auditPath);
    final store = File(storePath);
    if (store.existsSync()) {
      final decoded = jsonDecode(await store.readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded['nextId'] is! int ||
          decoded['incidents'] is! List) {
        throw const FormatException(
          'El almacén debe ser un objeto con nextId e incidents',
        );
      }
      return IncidentRepository(
        _parseIncidents(decoded['incidents'] as List),
        nextId: decoded['nextId'] as int,
        storePath: storePath,
        audit: audit,
        writeEnabled: writeEnabled,
        deleteEnabled: deleteEnabled,
        clock: clock,
      );
    }

    final decoded = jsonDecode(await File(fixturePath).readAsString());
    if (decoded is! List) {
      throw const FormatException('Se esperaba un array de incidencias');
    }
    return IncidentRepository(
      _parseIncidents(decoded),
      storePath: storePath,
      audit: audit,
      writeEnabled: writeEnabled,
      deleteEnabled: deleteEnabled,
      clock: clock,
    );
  }

  static List<Incident> _parseIncidents(List<dynamic> items) => [
    for (final item in items)
      if (item is Map<String, dynamic>)
        Incident.fromJson(item)
      else
        throw FormatException('Elemento no válido: $item'),
  ];

  static int _idNumber(String id) => int.parse(id.substring(4));

  List<Incident> _incidents;
  int _nextId;
  final String? _storePath;
  final AuditLog? _audit;
  final bool _writeEnabled;
  final bool _deleteEnabled;
  final DateTime Function() _clock;
  Future<void> _writeQueue = Future.value();

  /// Todas las incidencias, en orden de creación.
  List<Incident> get all => _incidents;

  /// Si se permiten operaciones de escritura.
  bool get writeEnabled => _writeEnabled;

  /// Si se permite borrar (requiere también [writeEnabled]).
  bool get deleteEnabled => _writeEnabled && _deleteEnabled;

  /// Devuelve la incidencia con [id].
  ///
  /// Lanza [DomainException] con código `NOT_FOUND` si no existe.
  Incident getById(String id) => _incidents.firstWhere(
    (incident) => incident.id == id,
    orElse: () =>
        throw DomainException('NOT_FOUND', 'No existe la incidencia $id'),
  );

  /// Crea una incidencia `abierta` con fecha de hoy y la guarda.
  ///
  /// Lanza [DomainException] con código `WRITE_DISABLED` si la escritura no
  /// está habilitada, `VALIDATION_ERROR` si [draft] no es válido o
  /// `PERSISTENCE_ERROR` si no se pudo guardar (en ese caso no cambia nada).
  Future<Incident> create(NewIncident draft) async {
    _ensureWritable();
    final valid = draft.validated();
    return await _serialized(() async {
      final incident = Incident(
        id: 'INC-${_nextId.toString().padLeft(3, '0')}',
        title: valid.title,
        status: IncidentStatus.abierta,
        impact: valid.impact,
        workaround: valid.workaround,
        created: _clock().toIso8601String().substring(0, 10),
        detail: valid.detail,
      );
      await _commit(
        [..._incidents, incident],
        _nextId + 1,
        _event(AuditOperation.crear, before: null, after: incident),
      );
      return incident;
    });
  }

  /// Aplica [patch] a la incidencia [id] y la guarda con la revisión
  /// siguiente. El estado no se cambia aquí, sino con [changeStatus].
  ///
  /// [expectedRevision] es la revisión que se leyó antes de editar; si la
  /// incidencia ha cambiado desde entonces, no se aplica nada.
  ///
  /// Lanza [DomainException] con código `WRITE_DISABLED`, `NOT_FOUND`,
  /// `REVISION_CONFLICT`, `VALIDATION_ERROR` o `PERSISTENCE_ERROR`.
  Future<Incident> update(
    String id, {
    required int expectedRevision,
    required IncidentPatch patch,
  }) => _mutate(id, expectedRevision, AuditOperation.actualizar, patch.applyTo);

  /// Cambia el estado de la incidencia [id] a [status], respetando las
  /// transiciones de [IncidentStatus.allowedNext].
  ///
  /// Reabrir una incidencia resuelta exige [reason].
  ///
  /// Lanza [DomainException] con código `WRITE_DISABLED`, `NOT_FOUND`,
  /// `REVISION_CONFLICT`, `INVALID_TRANSITION`, `REASON_REQUIRED`,
  /// `VALIDATION_ERROR` o `PERSISTENCE_ERROR`.
  Future<Incident> changeStatus(
    String id, {
    required int expectedRevision,
    required IncidentStatus status,
    String? reason,
  }) async {
    if (reason != null) checkText('reason', reason, maxReasonLength);
    return await _mutate(id, expectedRevision, AuditOperation.cambiarEstado, (
      current,
    ) {
      if (current.status == status) {
        throw DomainException(
          'INVALID_TRANSITION',
          '$id ya está en estado ${status.value}',
        );
      }
      if (!current.status.allowedNext.contains(status)) {
        final allowed = current.status.allowedNext.map((s) => s.value);
        throw DomainException(
          'INVALID_TRANSITION',
          'No se puede pasar de ${current.status.value} a ${status.value}. '
              'Desde ${current.status.value} se permite: '
              '${allowed.join(', ')}.',
        );
      }
      if (current.status.isReopening(status) && reason == null) {
        throw DomainException(
          'REASON_REQUIRED',
          'Para reabrir $id indica el motivo (reason)',
        );
      }
      return current.copyWith(status: status, revision: current.revision + 1);
    }, reason: reason);
  }

  /// Aplica [change] a la incidencia [id] si su revisión es
  /// [expectedRevision], y guarda el resultado.
  Future<Incident> _mutate(
    String id,
    int expectedRevision,
    AuditOperation operation,
    Incident Function(Incident current) change, {
    String? reason,
  }) async {
    _ensureWritable();
    return await _serialized(() async {
      final current = getById(id);
      if (current.revision != expectedRevision) {
        throw DomainException(
          'REVISION_CONFLICT',
          '$id ha cambiado: su revisión actual es ${current.revision}, no '
              '$expectedRevision. Vuelve a consultarla antes de editar.',
        );
      }
      final updated = change(current);
      await _commit(
        [
          for (final incident in _incidents)
            if (incident.id == id) updated else incident,
        ],
        _nextId,
        _event(operation, before: current, after: updated, reason: reason),
      );
      return updated;
    });
  }

  /// Borra físicamente la incidencia [id] y devuelve cómo estaba.
  ///
  /// Su ID no se reutiliza. [reason] explica el motivo y no puede estar
  /// vacío.
  ///
  /// Lanza [DomainException] con código `WRITE_DISABLED`, `DELETE_DISABLED`,
  /// `VALIDATION_ERROR`, `NOT_FOUND` o `PERSISTENCE_ERROR`.
  Future<Incident> delete(String id, {required String reason}) async {
    _ensureWritable();
    if (!_deleteEnabled) {
      throw const DomainException(
        'DELETE_DISABLED',
        'El borrado está desactivado. Arranca el servidor con '
            'MESA_INCIDENCIAS_DELETE_ENABLED=1 para permitirlo.',
      );
    }
    checkText('reason', reason, maxReasonLength);
    return await _serialized(() async {
      final deleted = getById(id);
      await _commit(
        [
          for (final incident in _incidents)
            if (incident.id != id) incident,
        ],
        _nextId,
        _event(
          AuditOperation.eliminar,
          before: deleted,
          after: null,
          reason: reason.trim(),
        ),
      );
      return deleted;
    });
  }

  /// Historial de cambios de la incidencia [id], del más antiguo al más
  /// reciente. Funciona también con incidencias ya borradas.
  ///
  /// Lanza [DomainException] con código `NOT_FOUND` si la incidencia no
  /// existe ni tiene historial.
  Future<List<AuditEvent>> history(String id) async {
    final audit = _audit;
    final events = audit == null ? <AuditEvent>[] : await audit.eventsFor(id);
    if (events.isEmpty) getById(id);
    return events;
  }

  AuditEvent _event(
    AuditOperation operation, {
    required Incident? before,
    required Incident? after,
    String? reason,
  }) => AuditEvent.between(
    timestamp: _clock().toUtc().toIso8601String(),
    operation: operation,
    before: before,
    after: after,
    reason: reason?.trim(),
  );

  /// Guarda el nuevo estado y registra [event]. Si no se puede registrar la
  /// auditoría, restaura el almacén anterior: nunca queda un cambio sin
  /// registrar.
  Future<void> _commit(
    List<Incident> incidents,
    int nextId,
    AuditEvent event,
  ) async {
    await _persist(incidents, nextId);
    try {
      await _audit!.append(event);
    } on FileSystemException catch (error) {
      await _persist(_incidents, _nextId);
      throw DomainException(
        'PERSISTENCE_ERROR',
        'No se pudo registrar la auditoría (${error.message}); no se ha '
            'aplicado el cambio',
      );
    }
    _incidents = List.unmodifiable(incidents);
    _nextId = nextId;
  }

  void _ensureWritable() {
    if (!_writeEnabled) {
      throw const DomainException(
        'WRITE_DISABLED',
        'El servidor está en modo solo lectura. Arráncalo con '
            'MESA_INCIDENCIAS_WRITE_ENABLED=1 para permitir cambios.',
      );
    }
  }

  /// Ejecuta [operation] cuando hayan terminado las escrituras anteriores.
  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  /// Escribe el almacén en un fichero temporal y lo renombra, para que un
  /// fallo a mitad no deje el almacén corrupto.
  Future<void> _persist(List<Incident> incidents, int nextId) async {
    final store = File(_storePath!);
    final temp = File('${store.path}.tmp');
    final content = const JsonEncoder.withIndent('  ').convert({
      'nextId': nextId,
      'incidents': [for (final incident in incidents) incident.toJson()],
    });
    try {
      await store.parent.create(recursive: true);
      await temp.writeAsString('$content\n', flush: true);
      await temp.rename(store.path);
    } on FileSystemException catch (error) {
      if (temp.existsSync()) temp.deleteSync();
      throw DomainException(
        'PERSISTENCE_ERROR',
        'No se pudo guardar el almacén: ${error.message}',
      );
    }
  }
}
