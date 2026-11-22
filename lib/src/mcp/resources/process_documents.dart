import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:path/path.dart' as p;

/// {@template process_document}
/// Documento Markdown de un proceso de la mesa, expuesto como recurso
/// `docs://<name>`.
/// {@endtemplate}
class ProcessDocument {
  /// {@macro process_document}
  const new({
    required this.name,
    required this.title,
    required this.description,
  });

  /// Nombre del recurso; también nombre del fichero `<name>.md`.
  final String name;

  /// Título legible.
  final String title;

  /// Para qué sirve el documento.
  final String description;

  /// URI del recurso.
  String get uri => 'docs://$name';
}

/// Proceso para abrir una incidencia.
const aperturaDocument = ProcessDocument(
  name: 'proceso_apertura',
  title: 'Proceso de apertura',
  description:
      'Cómo abrir una incidencia: datos obligatorios, redacción y '
      'comprobaciones previas.',
);

/// Proceso para clasificar y priorizar incidencias.
const triajeDocument = ProcessDocument(
  name: 'proceso_triaje',
  title: 'Proceso de triaje',
  description:
      'Cómo clasificar el impacto de una incidencia y en qué orden '
      'atender las activas.',
);

/// Documentos de proceso que publica el servidor.
const List<ProcessDocument> processDocuments = [
  aperturaDocument,
  triajeDocument,
];

/// Lee el fichero `<name>.md` de [document] en [docsDirectory].
///
/// Lanza [McpError] (`internalError`) si no se puede leer.
Future<TextResourceContents> readProcessDocument(
  String docsDirectory,
  ProcessDocument document,
) async {
  final file = File(p.join(docsDirectory, '${document.name}.md'));
  try {
    return TextResourceContents(
      uri: document.uri,
      mimeType: 'text/markdown',
      text: await file.readAsString(),
    );
  } on FileSystemException {
    throw McpError(
      ErrorCode.internalError.value,
      'No se pudo leer el documento ${document.uri}',
    );
  }
}

/// Registra cada documento de [processDocuments] como recurso, leyendo su
/// fichero de [docsDirectory] en cada lectura.
void registerProcessDocuments(McpServer server, String docsDirectory) {
  for (final document in processDocuments) {
    server.registerResource(
      document.name,
      document.uri,
      (description: document.description, mimeType: 'text/markdown'),
      title: document.title,
      (uri, extra) async => ReadResourceResult(
        contents: [await readProcessDocument(docsDirectory, document)],
      ),
    );
  }
}
