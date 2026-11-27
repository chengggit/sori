# Contributing

Thanks for taking an interest in Sori! Whether it's an idea, a bug you noticed,
or a fix you'd like to send, contributions are welcome. You don't need to know
the whole codebase to get started.

## Before you start

Check existing issues and open PRs first. For larger changes, open an issue so
we can confirm the direction. Keep PRs small and focused.

- [AGENTS.md](AGENTS.md) covers project conventions.
- [docs/](docs/) explains the product, architecture, and UI principles.
- [DEVELOPING.md](DEVELOPING.md) covers setup and checks.

Sori is local-first: reading, playback, Korean analysis and vocabulary should
keep working without an account, AI service, or remote server.

## Working on the code

Follow the surrounding code. Keep UI work in Svelte, application logic in Rust,
and Electron/native integration in main-process modules and the preload bridge.
UI code calls `platform` rather than Electron directly, and fallible operations
keep the `{ ok, data, error }` envelope.

Add a regression test when fixing a bug or changing behavior, and update the
relevant docs if behavior changes. Keep keys, personal media, local databases
and generated files out of commits.

Formatting and checks:

```sh
npm run format:check
npm run desktop:test:core
npm run desktop:test:unit
npm run desktop:test:e2e
```

For commit messages, use `type(scope): description`, for example
`fix(reader): preserve PDF sharpness` or `docs: clarify setup`. For branches,
use `type/description`, such as `fix/reader-zoom`.

## Pull requests

Describe what changed and why, link the related issue, and list what you
tested. Screenshots or a short recording help for UI changes. Keep unrelated
formatting or dependency updates separate. Draft PRs are welcome for feedback.

## Bug reports

Include what you tried, what you expected, what happened, steps to reproduce,
your OS and app version, and whether you used a package or a source build.
Screenshots, recordings and logs help. For media issues, include the format and
subtitle type. Please remove API keys and personal information, and don't share
your full library database.
