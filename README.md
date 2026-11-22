# Tickets Service MCP

[![ci][ci_badge]][ci_link]
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)][mason_link]
[![License: MIT][license_badge]][license_link]

Servidor [Model Context Protocol (MCP)][mcp_link] local, escrito en Dart, que expone una mesa de incidencias ficticia a clientes MCP (Claude Code, Claude Desktop, MCP Inspector…) a través de **stdio**.

> [!NOTE]
> Proyecto en fase inicial: el esqueleto, las dependencias y la CI están listos, pero el servidor aún no expone herramientas.

## Índice

- [Características](#características-)
- [Requisitos](#requisitos-)
- [Instalación](#instalación-)
- [Uso](#uso-)
- [Datos](#datos-)
- [Desarrollo](#desarrollo-)
- [Integración continua](#integración-continua-)
- [Contribuir](#contribuir-)
- [Licencia](#licencia-)

## Características ✨

- Transporte **stdio**: sin servidor web ni puertos abiertos.
- Basado en el SDK [`mcp_dart`][mcp_dart_link].
- Convenciones de [Very Good Ventures][very_good_ventures_link]: análisis estático estricto, 100 % de cobertura de tests y CI con [Very Good Workflows][very_good_workflows_link].

## Requisitos 📋

- [Dart SDK][dart_install_link] `^3.13.0`.
- Opcional: [Very Good CLI][very_good_cli_link] para ejecutar los tests con control de cobertura:

  ```sh
  dart pub global activate very_good_cli
  ```

## Instalación 💻

```sh
git clone https://github.com/jovazcode/tickets-service-mcp.git
cd tickets-service-mcp
dart pub get
```

## Uso 🚀

Un servidor MCP por stdio no tiene interfaz propia: lo arranca un cliente MCP y se comunica con él mediante JSON-RPC por `stdin`/`stdout`.

Para que la salida de compilación de `dart run` no se mezcle con el protocolo, compila primero un ejecutable nativo:

```sh
dart compile exe bin/tickets_service_mcp.dart -o build/tickets_service_mcp
```

### Claude Code

```sh
claude mcp add tickets-service -- /ruta/absoluta/a/build/tickets_service_mcp
```

### Otros clientes (configuración JSON)

```json
{
  "mcpServers": {
    "tickets-service": {
      "command": "/ruta/absoluta/a/build/tickets_service_mcp"
    }
  }
}
```

### MCP Inspector

```sh
npx @modelcontextprotocol/inspector build/tickets_service_mcp
```

## Datos 🗂️

[`data/tickets.json`](data/tickets.json) contiene las incidencias ficticias de partida (`id`, `title`, `status`, `impact`, `workaround`, `created`, `detail`). Úsalo como fixture de solo lectura.

## Desarrollo 🛠️

| Tarea | Comando |
| --- | --- |
| Formatear | `dart format .` |
| Analizar | `dart analyze --fatal-infos` |
| Tests con cobertura (igual que la CI) | `very_good dart test --coverage --min-coverage 100` |
| Un solo test | `dart test --name "<nombre del test>"` |
| Ejecutar | `dart run bin/tickets_service_mcp.dart` |

> [!IMPORTANT]
> En este paquete Dart usa `very_good dart test`. `very_good test` es para Flutter y termina sin ejecutar ningún test.

Para generar un informe HTML de cobertura con [lcov](https://github.com/linux-test-project/lcov):

```sh
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Estructura

```text
bin/     Punto de entrada del servidor (stdio)
lib/     API pública (barrel) e implementación en lib/src/
test/    Tests, con la misma estructura que lib/
data/    Fixture de incidencias
```

## Integración continua 🤖

El workflow de [GitHub Actions][github_actions_link], basado en [Very Good Workflows][very_good_workflows_link], se ejecuta en cada push y pull request a `main` y comprueba:

- formato, análisis estático y tests con un mínimo de 100 % de cobertura;
- ortografía de los ficheros Markdown (palabras admitidas en [`.github/cspell.json`](.github/cspell.json));
- títulos de pull request semánticos;
- licencias compatibles en las dependencias.

## Contribuir 🤝

1. Crea una rama desde `main`.
2. Asegúrate de que formato, análisis y tests pasan en local.
3. Usa [Conventional Commits][conventional_commits_link] en los commits y en el título del pull request (`feat:`, `fix:`, `chore:`…).

## Licencia 📄

Distribuido bajo la licencia MIT. Consulta [LICENSE](LICENSE).

[ci_badge]: https://github.com/jovazcode/tickets-service-mcp/actions/workflows/main.yaml/badge.svg
[ci_link]: https://github.com/jovazcode/tickets-service-mcp/actions/workflows/main.yaml
[conventional_commits_link]: https://www.conventionalcommits.org/es/v1.0.0/
[dart_install_link]: https://dart.dev/get-dart
[github_actions_link]: https://docs.github.com/en/actions/learn-github-actions
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[mason_link]: https://github.com/felangel/mason
[mcp_dart_link]: https://pub.dev/packages/mcp_dart
[mcp_link]: https://modelcontextprotocol.io
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[very_good_cli_link]: https://pub.dev/packages/very_good_cli
[very_good_ventures_link]: https://verygood.ventures
[very_good_workflows_link]: https://github.com/VeryGoodOpenSource/very_good_workflows
