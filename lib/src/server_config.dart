import 'package:path/path.dart' as p;

/// {@template server_config}
/// Configuración del servidor, resuelta al arrancar a partir del entorno.
/// {@endtemplate}
class ServerConfig {
  /// {@macro server_config}
  const new({
    required this.dataPath,
    required this.storePath,
    required this.auditPath,
    required this.docsDirectory,
    this.writeEnabled = false,
    this.deleteEnabled = false,
  });

  /// Construye la configuración a partir de [environment].
  ///
  /// Las rutas relativas se resuelven contra [baseDirectory]. Variables:
  /// - `MESA_INCIDENCIAS_DATA`: fixture de solo lectura
  ///   (por defecto `data/tickets.json`).
  /// - `MESA_INCIDENCIAS_STORE`: almacén de trabajo donde se guardan los
  ///   cambios (por defecto `data/tickets.local.json`).
  /// - `MESA_INCIDENCIAS_AUDIT`: registro de auditoría append-only
  ///   (por defecto `data/tickets.audit.jsonl`).
  /// - `MESA_INCIDENCIAS_DOCS`: carpeta de documentos de proceso
  ///   (por defecto `docs`).
  /// - `MESA_INCIDENCIAS_WRITE_ENABLED`: `1`, `true`, `yes` u `on` para
  ///   permitir cambios (por defecto, solo lectura).
  /// - `MESA_INCIDENCIAS_DELETE_ENABLED`: igual, para permitir además el
  ///   borrado (por defecto desactivado).
  factory fromEnvironment(
    Map<String, String> environment, {
    required String baseDirectory,
  }) {
    String? read(String variable) {
      final value = environment[variable]?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    bool flag(String variable) => const {
      '1',
      'true',
      'yes',
      'on',
    }.contains(read(variable)?.toLowerCase());

    String resolve(String variable, String fallback) =>
        p.normalize(p.join(baseDirectory, read(variable) ?? fallback));

    return ServerConfig(
      dataPath: resolve(
        'MESA_INCIDENCIAS_DATA',
        p.join('data', 'tickets.json'),
      ),
      storePath: resolve(
        'MESA_INCIDENCIAS_STORE',
        p.join('data', 'tickets.local.json'),
      ),
      auditPath: resolve(
        'MESA_INCIDENCIAS_AUDIT',
        p.join('data', 'tickets.audit.jsonl'),
      ),
      docsDirectory: resolve('MESA_INCIDENCIAS_DOCS', 'docs'),
      writeEnabled: flag('MESA_INCIDENCIAS_WRITE_ENABLED'),
      deleteEnabled: flag('MESA_INCIDENCIAS_DELETE_ENABLED'),
    );
  }

  /// Ruta absoluta de la fixture de incidencias (solo lectura).
  final String dataPath;

  /// Ruta absoluta del almacén de trabajo.
  final String storePath;

  /// Ruta absoluta del registro de auditoría.
  final String auditPath;

  /// Ruta absoluta de la carpeta con los documentos de proceso.
  final String docsDirectory;

  /// Si se permiten operaciones de escritura.
  final bool writeEnabled;

  /// Si se permite borrar incidencias (requiere también [writeEnabled]).
  final bool deleteEnabled;
}
