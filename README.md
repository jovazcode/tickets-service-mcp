# Tickets Service MCP

[![ci][ci_badge]][ci_link]
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)][mason_link]
[![License: MIT][license_badge]][license_link]

Servidor [Model Context Protocol (MCP)][mcp_link] local, escrito en Dart, que expone una mesa de incidencias ficticia a clientes MCP (Claude Code, Claude Desktop, MCP Inspector…) a través de **stdio**.

> [!NOTE]
> Fase 4 (en curso): CRUD completo, triaje (siguiente incidencia prioritaria, resumen de la mesa y cambios de estado con transiciones permitidas), detección de duplicados, historial con auditoría, documentos de proceso y prompt de apertura.

## Índice

- [Características](#características-)
- [Requisitos](#requisitos-)
- [Instalación](#instalación-)
- [Herramientas y recursos](#herramientas-y-recursos-)
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

## Herramientas y recursos 🧰

| Tipo | Nombre | Qué hace |
| --- | --- | --- |
| Tool | `buscar_incidencias` | Busca por texto libre (ID, título y detalle, sin distinguir mayúsculas ni tildes) y filtra por `status`, `impact` y `workaround`. Paginación con `limit` (1-100, por defecto 20) y `offset`. Devuelve `{items, total}`. |
| Tool | `obtener_incidencia` | Devuelve la ficha completa de una incidencia por `id` (`INC-104`). Si no existe, error `NOT_FOUND`. |
| Tool | `buscar_duplicadas` | Incidencias parecidas a un problema (`title`, `detail` opcional), con puntuación de 0 a 1 y términos en común. Compara palabras significativas (sin tildes ni palabras vacías, recortadas a su raíz) con el coeficiente de solapamiento y exige 2 términos comunes. Opcionales: `includeResolved` (por defecto `true`) y `minScore` (por defecto 0,4). Es una heurística para avisar, no para decidir. |
| Tool | `historial_incidencia` | Cambios registrados de una incidencia, del más antiguo al más reciente: alta (con la ficha), ediciones y cambios de estado (campos con valor anterior y nuevo), y borrado (con la ficha y el motivo). Funciona también con incidencias borradas. |
| Tool | `siguiente_incidencia_prioritaria` | La incidencia activa que hay que atender primero según `docs://proceso_triaje` (impacto alto, sin alternativa temporal, más antigua, ID menor), con los criterios aplicados y la cola de IDs activos en orden. |
| Tool | `resumen_mesa` | Totales: incidencias y activas, críticas (activas de impacto alto sin alternativa temporal), recuentos por estado, impacto y alternativa temporal, y la activa más antigua. |
| Tool | `crear_incidencia` | Abre una incidencia (`title`, `detail`, `impact`, `workaround` opcional) en estado `abierta` con la fecha de hoy y el siguiente ID. Si hay incidencias activas parecidas las devuelve en `possibleDuplicates`, sin impedir la creación. Requiere escritura habilitada; si no, `WRITE_DISABLED`. Valida el texto (`VALIDATION_ERROR`). |
| Tool | `actualizar_incidencia` | Cambia uno o varios campos (`title`, `detail`, `impact`, `workaround`; el estado, con `cambiar_estado`). Exige `expectedRevision`, la revisión leída antes de editar: si la incidencia ha cambiado entretanto responde `REVISION_CONFLICT` y no aplica nada. Requiere escritura. |
| Tool | `cambiar_estado` | Mueve una incidencia por su ciclo de vida: `abierta` → `en_progreso`/`resuelta`; `en_progreso` → `resuelta`/`abierta`; `resuelta` → `abierta` (reabrir exige `reason`, si no `REASON_REQUIRED`). Otras transiciones → `INVALID_TRANSITION`. Exige `expectedRevision`. Requiere escritura. |
| Tool | `eliminar_incidencia` | Borra físicamente una incidencia (no se puede deshacer; su ID no se reutiliza). Exige `confirm: true` (`CONFIRMATION_REQUIRED`) y `reason`. Requiere escritura y además borrado (`DELETE_DISABLED`). |
| Resource | `docs://proceso_apertura` | Cómo abrir una incidencia ([`docs/proceso_apertura.md`](docs/proceso_apertura.md)). |
| Resource | `docs://proceso_triaje` | Cómo clasificar y priorizar ([`docs/proceso_triaje.md`](docs/proceso_triaje.md)). |
| Prompt | `abrir_incidencia` | Guía al modelo por el proceso de apertura (incrusta `docs://proceso_apertura`): buscar duplicados, completar datos, confirmar contigo y crear. Argumento opcional `problema`. |

Cada incidencia lleva un campo `revision` que empieza en 1 y sube con cada cambio; las que no lo tienen (como las de la fixture) se leen con revisión 1.

Las herramientas de escritura aparecen siempre en el catálogo, pero el servidor las rechaza salvo que se arranque con `MESA_INCIDENCIAS_WRITE_ENABLED=1` (y, para borrar, también `MESA_INCIDENCIAS_DELETE_ENABLED=1`): el control está en el servidor, no en que el modelo se porte bien. Las instrucciones que el servidor envía al cliente indican el modo activo.

Las herramientas devuelven resultados estructurados (`structuredContent`) y los errores de negocio como resultado con `isError: true` y el texto `CODIGO: mensaje`, para que el modelo pueda corregirse.

## Uso 🚀

Un servidor MCP por stdio no tiene interfaz propia: lo arranca un cliente MCP y se comunica con él mediante JSON-RPC por `stdin`/`stdout`.

Para que la salida de compilación de `dart run` no se mezcle con el protocolo, compila primero un ejecutable nativo:

```sh
dart compile exe bin/tickets_service_mcp.dart -o build/tickets_service_mcp
```

### Claude Code

Este repositorio ya declara el servidor `mesa-incidencias` en [`.mcp.json`](.mcp.json), apuntando a `build/tickets_service_mcp`. Compila el ejecutable (y vuelve a compilarlo tras cada cambio en el código), abre el proyecto en Claude Code, aprueba el servidor y compruébalo con `/mcp`.

Si Claude Code tiene el servidor en marcha, el ejecutable está en uso (`Text file busy`). Compila a un fichero aparte, sustitúyelo y vuelve a conectar el servidor en `/mcp`:

```sh
dart compile exe bin/tickets_service_mcp.dart -o build/tickets_service_mcp.new \
  && mv build/tickets_service_mcp.new build/tickets_service_mcp
```

> [!WARNING]
> No uses `dart run` como comando del cliente: compilar en cada arranque tarda unos 3 s, la sonda de versión del cliente caduca y la conexión puede quedarse en "Connecting...". El ejecutable nativo arranca casi al instante.

Para usarlo desde otros proyectos, registra el ejecutable compilado:

```sh
claude mcp add mesa-incidencias -- /ruta/absoluta/a/build/tickets_service_mcp
```

### Otros clientes (configuración JSON)

```json
{
  "mcpServers": {
    "mesa-incidencias": {
      "command": "/ruta/absoluta/a/build/tickets_service_mcp"
    }
  }
}
```

### Configuración

El servidor busca los datos y documentos relativos a la raíz del proyecto (carpeta padre de `bin/` o `build/`), sea cual sea el directorio desde el que se lance. Se pueden sobrescribir con variables de entorno:

| Variable | Por defecto |
| --- | --- |
| `MESA_INCIDENCIAS_DATA` | `data/tickets.json` (fixture, nunca se modifica) |
| `MESA_INCIDENCIAS_STORE` | `data/tickets.local.json` (almacén de trabajo) |
| `MESA_INCIDENCIAS_AUDIT` | `data/tickets.audit.jsonl` (auditoría append-only) |
| `MESA_INCIDENCIAS_DOCS` | `docs` |
| `MESA_INCIDENCIAS_WRITE_ENABLED` | vacío: solo lectura. `1`, `true`, `yes` u `on` habilitan la escritura |
| `MESA_INCIDENCIAS_DELETE_ENABLED` | vacío: sin borrado. Con los mismos valores lo habilita (requiere también escritura) |

### Escritura y almacén de trabajo

Con la escritura habilitada, el primer cambio copia la fixture al almacén de trabajo (`{nextId, incidents}`), que se guarda de forma atómica (fichero temporal + renombrado). Al arrancar, si el almacén existe se usa en lugar de la fixture, también en solo lectura, para no perder lo creado. Para volver al estado inicial, borra `data/tickets.local.json` (y `data/tickets.audit.jsonl` si quieres empezar también sin historial).

Cada cambio se añade además como una línea JSON a la auditoría (`data/tickets.audit.jsonl`), que nunca se reescribe: fecha UTC, operación, motivo y campos cambiados (o la ficha completa en altas y borrados). Primero se guarda el almacén y después la auditoría; si esta falla, el almacén se restaura y el cambio no se aplica, para que nunca quede un cambio sin registrar.

En Claude Code, `.mcp.json` pasa al servidor los valores de `MESA_INCIDENCIAS_WRITE_ENABLED` y `MESA_INCIDENCIAS_DELETE_ENABLED` del entorno en el que arrancas Claude Code (por defecto `0`):

```sh
MESA_INCIDENCIAS_WRITE_ENABLED=1 claude    # o arranca VS Code con esa variable
```

Para habilitarlos solo para ti y de forma permanente, registra el servidor en ámbito local (tiene prioridad sobre `.mcp.json` y no se versiona):

```sh
claude mcp add --scope local mesa-incidencias \
  -e MESA_INCIDENCIAS_WRITE_ENABLED=1 -e MESA_INCIDENCIAS_DELETE_ENABLED=1 \
  -- "$PWD/build/tickets_service_mcp"
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
bin/                 Punto de entrada: lee la configuración y conecta stdio
lib/src/domain/      Modelo de incidencia, enums y errores de negocio
lib/src/store/       Carga y acceso a las incidencias
lib/src/services/    Búsqueda y triaje (funciones puras)
lib/src/mcp/         Adaptadores MCP: servidor, tools, resources y prompts
test/                Tests, con la misma estructura que lib/
data/                Fixture de incidencias
docs/                Documentos de proceso publicados como recursos
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
