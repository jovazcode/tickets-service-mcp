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

/// Documentos de proceso que publica el servidor.
const processDocuments = [
  ProcessDocument(
    name: 'proceso_apertura',
    title: 'Proceso de apertura',
    description:
        'Cómo abrir una incidencia: datos obligatorios, redacción y '
        'comprobaciones previas.',
  ),
  ProcessDocument(
    name: 'proceso_triaje',
    title: 'Proceso de triaje',
    description:
        'Cómo clasificar el impacto de una incidencia y en qué orden '
        'atender las activas.',
  ),
];

/// Registra cada documento de [processDocuments] como recurso, leyendo el
/// fichero `<name>.md` de [docsDirectory] en cada lectura.
void registerProcessDocuments(McpServer server, String docsDirectory) {
  for (final document in processDocuments) {
    server.registerResource(
      document.name,
      document.uri,
      (description: document.description, mimeType: 'text/markdown'),
      title: document.title,
      (uri, extra) async {
        final file = File(p.join(docsDirectory, '${document.name}.md'));
        final String text;
        try {
          text = await file.readAsString();
        } on FileSystemException {
          throw McpError(
            ErrorCode.internalError.value,
            'No se pudo leer el documento ${document.uri}',
          );
        }
        return ReadResourceResult(
          contents: [
            TextResourceContents(
              uri: uri.toString(),
              mimeType: 'text/markdown',
              text: text,
            ),
          ],
        );
      },
    );
  }
}
