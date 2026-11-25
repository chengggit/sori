# Sori

Local-first Korean immersion desktop app built with Qt Quick and Rust. Users
learn through their own media, analyze Korean text, and collect vocabulary.
Core features must work offline without AI, an account, or a remote server.

## Read before changing code

- `docs/PRODUCT.md` — scope and user workflows.
- `docs/ARCHITECTURE.md` — ownership, data flow, and technical constraints.
- `docs/DESIGN.md` — UI principles and shared interaction practices.
- `DEVELOPING.md` — setup, build commands, and testing.
- `CONTRIBUTING.md` — contribution workflow and conventions.
- `docs/USAGE.md` — user controls and optional online features.
- `docs/RELEASING.md` — CI artifacts and release packaging.

Read relevant existing files; do not assume missing documentation exists.

## Ownership

| Layer  | Responsibility                                                  |
| ------ | --------------------------------------------------------------- |
| QML    | Presentation and interaction                                    |
| C++    | Qt startup, mpv framebuffer integration, QtPdf geometry         |
| Rust   | Application logic, persistence, media, and text processing      |
| Kiwi   | Korean morphological analysis and tokenization                  |
| Python | Optional helpers and AI processing, isolated from core features |
| SQLite | Local application data                                          |

## Working rules

- Ship the simplest complete solution; work on one feature at a time.
- Inspect affected code and follow established patterns.
- Reuse components, utilities, and dependencies. Keep logic out of presentation.
- Keep scope focused; avoid unrelated refactoring and speculative abstractions.
- Decide low-risk details independently; ask before major product or architecture changes.
- Never present placeholders as finished functionality.
- Run relevant checks; report changes, validation, and known limitations.
- Update documentation when significant decisions change.
