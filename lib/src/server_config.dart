import 'package:path/path.dart' as p;

/// {@template server_config}
/// Configuración del servidor, resuelta al arrancar a partir del entorno.
/// {@endtemplate}
class ServerConfig {
  /// {@macro server_config}
  const new({required this.dataPath, required this.docsDirectory});

  /// Construye la configuración a partir de [environment].
  ///
  /// Las rutas relativas se resuelven contra [baseDirectory]. Variables:
  /// - `MESA_INCIDENCIAS_DATA`: fichero JSON de incidencias
  ///   (por defecto `data/tickets.json`).
  /// - `MESA_INCIDENCIAS_DOCS`: carpeta de documentos de proceso
  ///   (por defecto `docs`).
  factory fromEnvironment(
    Map<String, String> environment, {
    required String baseDirectory,
  }) {
    String resolve(String variable, String fallback) {
      final value = environment[variable]?.trim();
      final path = value == null || value.isEmpty ? fallback : value;
      return p.normalize(p.join(baseDirectory, path));
    }

    return ServerConfig(
      dataPath: resolve(
        'MESA_INCIDENCIAS_DATA',
        p.join('data', 'tickets.json'),
      ),
      docsDirectory: resolve('MESA_INCIDENCIAS_DOCS', 'docs'),
    );
  }

  /// Ruta absoluta del fichero JSON de incidencias.
  final String dataPath;

  /// Ruta absoluta de la carpeta con los documentos de proceso.
  final String docsDirectory;
}
