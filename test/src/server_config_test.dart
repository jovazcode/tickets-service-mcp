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
      expect(config.storePath, '/proyecto/data/tickets.local.json');
      expect(config.docsDirectory, '/proyecto/docs');
      expect(config.writeEnabled, isFalse);
    });

    test('lee la ruta del almacén del entorno', () {
      final config = ServerConfig.fromEnvironment(const {
        'MESA_INCIDENCIAS_STORE': '/tmp/mesa.json',
      }, baseDirectory: '/proyecto');
      expect(config.storePath, '/tmp/mesa.json');
    });

    for (final value in ['1', 'true', 'YES', ' on ']) {
      test('habilita la escritura con "$value"', () {
        final config = ServerConfig.fromEnvironment({
          'MESA_INCIDENCIAS_WRITE_ENABLED': value,
        }, baseDirectory: '/proyecto');
        expect(config.writeEnabled, isTrue);
      });
    }

    for (final value in ['0', 'false', 'no', '']) {
      test('mantiene solo lectura con "$value"', () {
        final config = ServerConfig.fromEnvironment({
          'MESA_INCIDENCIAS_WRITE_ENABLED': value,
        }, baseDirectory: '/proyecto');
        expect(config.writeEnabled, isFalse);
      });
    }

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
