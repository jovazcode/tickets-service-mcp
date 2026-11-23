import 'package:tickets_service_mcp/src/domain/incident.dart';
import 'package:tickets_service_mcp/src/services/incident_search.dart';

/// Palabras demasiado comunes para distinguir incidencias.
final Set<String> _stopWords = {
  ...'al como con cuando del desde el en es esta este hay la las'.split(' '),
  ...'lo los mas muy no para pero por que se si sin sobre su sus'.split(' '),
  ...'un una unos unas ya puede pueden todas todos'.split(' '),
};

/// Longitud a la que se recortan las palabras para que variantes como
/// "cuenta" y "cuentas" coincidan.
const _stemLength = 6;

/// Palabras significativas de [text]: sin tildes, en minúsculas, sin
/// palabras vacías ni de menos de 3 letras y recortadas a una raíz.
Set<String> significantTerms(String text) => {
  for (final word in normalizeText(text).split(RegExp('[^a-z0-9]+')))
    if (word.length >= 3 && !_stopWords.contains(word))
      word.substring(0, word.length.clamp(0, _stemLength)),
};

/// {@template duplicate_candidate}
/// Incidencia parecida a otra, con su puntuación de similitud.
/// {@endtemplate}
class DuplicateCandidate {
  /// {@macro duplicate_candidate}
  const new({
    required this.incident,
    required this.score,
    required this.sharedTerms,
  });

  /// La incidencia existente.
  final Incident incident;

  /// Similitud entre 0 y 1: proporción de términos del texto más corto que
  /// aparecen en el otro.
  final double score;

  /// Raíces de palabra en común.
  final List<String> sharedTerms;
}

/// Puntuación mínima por defecto para considerar dos textos parecidos.
const defaultDuplicateScore = 0.4;

/// Incidencias de [incidents] parecidas a [title] y [detail], de más a menos
/// parecida.
///
/// Compara las palabras significativas del título y el detalle con el
/// coeficiente de solapamiento (términos comunes entre los del texto más
/// corto), que funciona bien aunque una descripción sea mucho más breve que
/// la otra. Exige al menos 2 términos comunes, salvo que el texto buscado
/// tenga solo uno. Es una heurística: sirve para avisar, no para decidir.
List<DuplicateCandidate> findDuplicates(
  Iterable<Incident> incidents, {
  required String title,
  String detail = '',
  double minScore = defaultDuplicateScore,
  int limit = 5,
}) {
  final query = significantTerms('$title $detail');
  if (query.isEmpty) return const [];
  final minShared = query.length == 1 ? 1 : 2;

  final candidates = <DuplicateCandidate>[];
  for (final incident in incidents) {
    final terms = significantTerms('${incident.title} ${incident.detail}');
    final shared = query.intersection(terms);
    if (shared.length < minShared) continue;
    final smaller = query.length < terms.length ? query.length : terms.length;
    final score = shared.length / smaller;
    if (score < minScore) continue;
    candidates.add(
      DuplicateCandidate(
        incident: incident,
        score: double.parse(score.toStringAsFixed(2)),
        sharedTerms: shared.toList()..sort(),
      ),
    );
  }
  candidates.sort((a, b) => b.score.compareTo(a.score));
  return candidates.take(limit).toList();
}
