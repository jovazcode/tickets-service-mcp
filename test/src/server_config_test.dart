import 'package:test/test.dart';
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

void main() {
  group('ServerConfig.fromEnvironment', () {
    test('usa las rutas por defecto relativas al directorio de trabajo', () {
      final config = ServerConfig.fromEnvironment(
        const {},
        baseDirectory: '/proyecto',
      );
      expect(config.dataPath, '/proyecto/data/tickets.json');
      expect(config.docsDirectory, '/proyecto/docs');
    });

    test('ignora variables vacías', () {
      final config = ServerConfig.fromEnvironment(const {
        'MESA_INCIDENCIAS_DATA': '  ',
      }, baseDirectory: '/proyecto');
      expect(config.dataPath, '/proyecto/data/tickets.json');
    });

    test('acepta rutas relativas y absolutas en el entorno', () {
      final config = ServerConfig.fromEnvironment(const {
        'MESA_INCIDENCIAS_DATA': 'otros/datos.json',
        'MESA_INCIDENCIAS_DOCS': '/abs/docs',
      }, baseDirectory: '/proyecto');
      expect(config.dataPath, '/proyecto/otros/datos.json');
      expect(config.docsDirectory, '/abs/docs');
    });
  });
}
