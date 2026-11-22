import 'dart:convert';
import 'dart:io';

import 'package:tickets_service_mcp/src/domain/domain_exception.dart';
import 'package:tickets_service_mcp/src/domain/incident.dart';

/// {@template incident_repository}
/// Acceso a las incidencias de la mesa.
///
/// En esta fase es de solo lectura: carga las incidencias de un fichero JSON
/// (la fixture) y las mantiene en memoria.
/// {@endtemplate}
class IncidentRepository {
  /// {@macro incident_repository}
  ///
  /// Lanza [FormatException] si hay IDs duplicados.
  new(Iterable<Incident> incidents)
    : _incidents = List.unmodifiable(incidents) {
    final ids = <String>{};
    for (final incident in _incidents) {
      if (!ids.add(incident.id)) {
        throw FormatException('ID duplicado: ${incident.id}');
      }
    }
  }

  /// Carga las incidencias del fichero JSON en [path].
  ///
  /// El fichero debe contener un array de incidencias. Lanza
  /// [FileSystemException] si no se puede leer y [FormatException] si su
  /// contenido no es válido.
  static Future<IncidentRepository> load(String path) async {
    final decoded = jsonDecode(await File(path).readAsString());
    if (decoded is! List) {
      throw const FormatException('Se esperaba un array de incidencias');
    }
    return IncidentRepository([
      for (final item in decoded)
        if (item is Map<String, dynamic>)
          Incident.fromJson(item)
        else
          throw FormatException('Elemento no válido: $item'),
    ]);
  }

  final List<Incident> _incidents;

  /// Todas las incidencias, en el orden del fichero.
  List<Incident> get all => _incidents;

  /// Devuelve la incidencia con [id].
  ///
  /// Lanza [DomainException] con código `NOT_FOUND` si no existe.
  Incident getById(String id) => _incidents.firstWhere(
    (incident) => incident.id == id,
    orElse: () =>
        throw DomainException('NOT_FOUND', 'No existe la incidencia $id'),
  );
}
