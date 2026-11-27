# Sori

Local-first Korean immersion desktop app built with Electron, Svelte and Rust.
Users learn through their own media, analyze Korean text, and collect
vocabulary. Core features work offline without AI, an account, or a remote
server.

## Read before changing code

- `DEVELOPING.md` — setup, build commands, and testing.
- `CONTRIBUTING.md` — contribution workflow and conventions.
- `docs/PRODUCT.md` — scope and user workflows (product source of truth).
- `docs/ARCHITECTURE.md` — ownership, data flow, and constraints.
- `docs/DESIGN.md` — UI principles and shared practices.
- `docs/USAGE.md` — user controls and optional online features.
- `docs/RELEASING.md` — CI artifacts and release packaging.
- `MIGRATION.md` — history and status of the Qt → Electron migration.

Read relevant existing files; do not assume missing documentation exists.

## Ownership

| Layer    | Responsibility                                                    |
| -------- | ----------------------------------------------------------------- |
| Svelte   | Presentation and interaction (`src`)                              |
| Electron | Window lifecycle, protocol handlers, native dialogs, preload IPC  |
| Rust     | Application logic, persistence, media/dictionary/YouTube services |
| napi-rs  | JSON command bridge between Electron main and the Rust core       |
| Kiwi     | Korean morphological analysis and tokenization                    |
| SQLite   | Local application data                                            |

## Working rules

- Ship the simplest complete solution; work on one feature at a time.
- Inspect affected code and follow established patterns.
- Reuse components, utilities, and dependencies. Keep logic out of presentation.
- UI code calls `platform` (`src/platform.ts`), never Electron or Node directly.
- Keep fallible operations in the `{ ok, data, error }` envelope.
- One owner per data store: SQLite lives only in Rust.
- Keep long filesystem, network, analysis and media jobs off the UI path.
- Imported files and local SQLite data remain authoritative.
- Never silently reset a library; tests use temporary databases only.
- Never present placeholders as finished functionality.
- Run relevant checks; report changes, validation, and known limitations.
- Update documentation when significant decisions change.
