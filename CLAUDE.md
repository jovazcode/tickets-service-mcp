# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Local MCP server (stdio transport) in Dart for a fictitious incident desk ("mesa de incidencias"), built with the community SDK **`mcp_dart`** (leehack) — not Google's `dart_mcp`, which was dropped because it ships no agent skills. Scaffolded with Very Good CLI (`dart_package` template) and following Very Good Ventures conventions.

Current state: skeleton only. `bin/tickets_service_mcp.dart` has an empty `main`; no MCP server code yet.

The sibling folder `../resultado/` holds a TypeScript reference implementation of the same incident desk (CRUD tools, resources, prompt, write/hard-delete permissions disabled by default via env vars, separate working store and audit log, immutable fixture). See `../README.md` for its contract.

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

## Data

`data/tickets.json` is the fixture: array of incidents with `id` (`INC-1xx`), `title`, `status` (`abierta`/`resuelta`…), `impact` (`bajo`/`alto`), `workaround` (bool), `created` (ISO date), `detail`. Treat it as read-only input.

## Agent skills

`.claude/skills/` is managed by the `skills` CLI (state in `.config/dart_skills/skills_config.json`); don't edit by hand. Installed: 8 `dart-*` skills from `dart-lang/skills` and 3 from `mcp_dart` (`mcp-dart-server`, `mcp-dart-client`, `mcp-dart-streamable-http`). Use `mcp-dart-server` when implementing the server. To refresh, run `dart run skills@ get --agent claude` without `--all`, which would reinstall every `dart-lang/skills` skill.
