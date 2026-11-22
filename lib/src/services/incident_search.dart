import 'package:tickets_service_mcp/src/domain/impact.dart';
import 'package:tickets_service_mcp/src/domain/incident.dart';
import 'package:tickets_service_mcp/src/domain/incident_status.dart';

/// {@template search_criteria}
/// Criterios de búsqueda de incidencias. Todos los filtros son opcionales y
/// se combinan con Y lógico.
/// {@endtemplate}
class SearchCriteria {
  /// {@macro search_criteria}
  const new({
    this.text,
    this.status,
    this.impact,
    this.workaround,
    this.limit = defaultLimit,
    this.offset = 0,
  });

  /// Número de resultados por página si no se indica otro.
  static const defaultLimit = 20;

  /// Máximo número de resultados por página.
  static const maxLimit = 100;

  /// Texto libre buscado en ID, título y detalle, sin distinguir mayúsculas
  /// ni tildes.
  final String? text;

  /// Solo incidencias con este estado.
  final IncidentStatus? status;

  /// Solo incidencias con este impacto.
  final Impact? impact;

  /// Solo incidencias con (o sin) alternativa temporal.
  final bool? workaround;

  /// Tamaño de página.
  final int limit;

  /// Número de resultados que se saltan desde el principio.
  final int offset;
}

/// {@template search_result}
/// Página de resultados de una búsqueda.
/// {@endtemplate}
class SearchResult {
  /// {@macro search_result}
  const new({required this.items, required this.total});

  /// Incidencias de la página pedida.
  final List<Incident> items;

  /// Total de incidencias que cumplen los criterios, sin paginar.
  final int total;
}

/// Filtra [incidents] según [criteria] y devuelve la página pedida.
///
/// El orden de los resultados es el de [incidents].
SearchResult searchIncidents(
  Iterable<Incident> incidents,
  SearchCriteria criteria,
) {
  final text = criteria.text?.trim();
  final needle = text == null || text.isEmpty ? null : normalizeText(text);

  final matches = incidents.where((incident) {
    if (criteria.status != null && incident.status != criteria.status) {
      return false;
    }
    if (criteria.impact != null && incident.impact != criteria.impact) {
      return false;
    }
    if (criteria.workaround != null &&
        incident.workaround != criteria.workaround) {
      return false;
    }
    if (needle != null) {
      final haystack = normalizeText(
        '${incident.id} ${incident.title} ${incident.detail}',
      );
      if (!haystack.contains(needle)) return false;
    }
    return true;
  }).toList();

  return SearchResult(
    items: matches.skip(criteria.offset).take(criteria.limit).toList(),
    total: matches.length,
  );
}

const _accented = 'áàäâéèëêíìïîóòöôúùüûñç';
const _plain = 'aaaaeeeeiiiioooouuuunc';

/// Pasa [text] a minúsculas y le quita las tildes, para comparar búsquedas.
String normalizeText(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    final index = _accented.indexOf(char);
    buffer.write(index < 0 ? char : _plain[index]);
  }
  return buffer.toString();
}
