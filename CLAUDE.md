# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Local MCP server (stdio transport) in Dart for a fictitious incident desk ("mesa de incidencias"), built with the community SDK **`mcp_dart`** (leehack) — not Google's `dart_mcp`, which was dropped because it ships no agent skills. Scaffolded with Very Good CLI (`dart_package` template) and following Very Good Ventures conventions.

This is an independent project designed from scratch; do not use sibling folders (`../resultado/`, `../inicio/`) as a reference.

Current state (phase 4, first block): tools `buscar_incidencias`, `obtener_incidencia`, `siguiente_incidencia_prioritaria` and `resumen_mesa` (pure functions in `lib/src/services/triage.dart`, criteria from `docs/proceso_triaje.md`), `crear_incidencia`, `actualizar_incidencia` (no `status`; optimistic concurrency via `expectedRevision` → `REVISION_CONFLICT`), `cambiar_estado` (transitions in `IncidentStatus.allowedNext`; reopening needs `reason`), `eliminar_incidencia` (`confirm: true` + `reason`); resources `docs://proceso_apertura` and `docs://proceso_triaje`; prompt `abrir_incidencia`. Writes are rejected with `WRITE_DISABLED` unless `MESA_INCIDENCIAS_WRITE_ENABLED=1`; deletes additionally need `MESA_INCIDENCIAS_DELETE_ENABLED=1` (`DELETE_DISABLED`). Changes go to the working store `data/tickets.local.json` (`{nextId, incidents}`, atomic write, serialized queue; deleted IDs are never reused), never to the fixture. Each incident has `revision` (missing → 1). Next phase 4 blocks: duplicate detection, audit history, `incidencia://{id}` resource template with completion.

## Architecture

- `lib/src/domain/`, `lib/src/store/`, `lib/src/services/`: pure domain, no `mcp_dart` imports. Business failures throw `DomainException(code, message)`.
- `lib/src/mcp/`: thin adapters. `createMcpServer` registers everything; one `BaseTool` subclass per tool (`run` returns the structured result, `execute` maps `DomainException` to `CallToolResult(isError: true)`).
- `bin/` only reads config (`ServerConfig.fromEnvironment`, paths relative to the project root, overridable with `MESA_INCIDENCIAS_DATA` / `MESA_INCIDENCIAS_DOCS`) and connects `StdioServerTransport`; it is not covered by tests, so keep logic out of it.
- Clients must launch the AOT binary `build/tickets_service_mcp` (`dart compile exe bin/tickets_service_mcp.dart -o build/tickets_service_mcp`; recompile after changes). While Claude Code runs it the file is busy: compile to `build/tickets_service_mcp.new` and `mv` it over, then reconnect in `/mcp`. `dart run` takes ~3 s to start, Claude Code's protocol probe times out and `/mcp` stays at "Connecting...".
- Tests drive the server end to end with an in-process `McpClient` over `IOStreamTransport`; reuse `test/helpers/harness.dart` (temporary working store, `writeEnabled` option).
- Dart 3.14 lints require the new constructor syntax (`const new(...)`, `factory fromJson(...)`, enum `new(...)`); `dart fix --apply` converts it.

## Commands

Requires `~/.pub-cache/bin` on `PATH` for `very_good`.

```sh
dart pub get
dart format --set-exit-if-changed .
dart analyze --fatal-infos
very_good dart test --coverage --min-coverage 100   # what CI enforces
dart test test/src/tickets_service_mcp_test.dart     # single file
dart test --name "can be instantiated"                # single test by name
dart run bin/tickets_service_mcp.dart                 # run the server
```

Use `very_good dart test`, not `very_good test`: the latter targets Flutter and silently exits 0 without running anything in this pure Dart package.

## Conventions

- Lints: `very_good_analysis` (strict; public API needs `///` docs). Keep `analyze --fatal-infos` clean.
- Layout: public API exported from the barrel `lib/tickets_service_mcp.dart`; implementation in `lib/src/`; tests mirror `lib/` under `test/`.
- Coverage: the VGV CI workflow (`.github/workflows/main.yaml`) requires 100% coverage, plus spell check (`.github/cspell.json` — add project words there) and semantic PR titles. Use Conventional Commits.
- `pubspec.lock` is versioned (executable package); `dependencies` go before `dev_dependencies` in `pubspec.yaml`.
- stdio server: stdout is reserved for JSON-RPC; send logs/diagnostics to stderr.

## Git workflow

`main` is protected by a GitHub ruleset: no direct pushes, force pushes or deletion. Every change goes through a pull request:

1. Branch off `main` and commit there.
2. Push and open a PR whose title is a Conventional Commit (`gh pr create --fill`); it becomes the squash commit title on `main`.
3. Merge only when the required checks pass: `build / build`, `spell-check / build`, `semantic_pull_request / build`. No approvals are needed.
4. Squash is the only merge method (`gh pr merge --squash --delete-branch`); the remote branch is deleted automatically.

## Data

`data/tickets.json` is the fixture: array of incidents with `id` (`INC-1xx`), `title`, `status` (`abierta`/`resuelta`…), `impact` (`bajo`/`alto`), `workaround` (bool), `created` (ISO date), `detail` (no `revision`: it defaults to 1). Treat it as read-only input; the server never writes it.

## Agent skills

`.claude/skills/` is managed by the `skills` CLI (state in `.config/dart_skills/skills_config.json`); don't edit by hand. Installed: 8 `dart-*` skills from `dart-lang/skills` and 3 from `mcp_dart` (`mcp-dart-server`, `mcp-dart-client`, `mcp-dart-streamable-http`). Use `mcp-dart-server` when implementing the server. To refresh, run `dart run skills@ get --agent claude` without `--all`, which would reinstall every `dart-lang/skills` skill.
