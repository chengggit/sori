# Contributing

Thanks for taking an interest in Sori! Whether it's a small fix, a clearer
explanation, or a bug you noticed while using the app, your help is welcome.
You don't need to know the whole codebase to get started.

## Before you start

Have a look through the issues and open PRs to see if someone is already working
on something similar. If your idea isn't there yet, please open an issue first to make sure it aligns with the project's direction.

Small, focused PRs are easier to review and get merged. For a little context,
[AGENTS.md](AGENTS.md) covers the project conventions, and [docs/](docs/) explains
the product, architecture, and UI principles.

One thing to keep in mind: Sori is local-first. Reading, playback, Korean
analysis, and vocabulary should keep working without an account, AI service,
or remote server.

If you're unsure where to start or get stuck setting things up, feel free to
open an issue and ask.

## Working on the code

Ready to get set up? [DEVELOPING.md](DEVELOPING.md) covers dependencies,
build commands, and tests. If anything is unclear, feel free to ask in an issue.

## Standards

A few shared conventions help keep the project easy to work on:

- Follow the surrounding code and reuse existing components and theme tokens.
- Keep UI work in QML, application logic in Rust, and Qt/native integration in C++.
- A regression test is helpful when fixing a bug or changing behavior.
- Update the relevant docs if your change affects how something works.
- Keep API keys, personal media, local databases, and generated files out of commits.
- For commit messages, use a conventional commit prefix `type(scope): description`, like
  `fix(reader): preserve PDF sharpness` or `docs: clarify setup`.
- For branches, use `type/description`, like `fix/reader-zoom` or `feat/vocabulary-search`.

## Pull requests

A short description of what you changed and why is a great start. Link the
related issue and let us know what you tested. Screenshots or a short recording
are especially helpful for UI changes.

Try to keep unrelated formatting or dependency updates separate so the change
is easy to follow. Draft PRs are welcome if you'd like feedback along the way;
you don't have to wait until everything is finished to share your work.

## Bug reports

Found something that doesn't work quite right? That counts as contributing too!
You don't need to have a fix ready to report it.

A few details make it easier to investigate:

- What you were trying to do, what you expected, and what happened instead.
- Steps to reproduce it, if you have them.
- Your OS and Sori version or commit, and whether you're using a packaged or source build.
- A screenshot, recording, or relevant logs, if they help show the problem.
- For media issues, the format and subtitle type, or a small sample you can share.

It's fine if you don't have all of that. Share what you can, and we can work
through the rest. Please remove API keys and personal information from logs,
and keep private media and your full library database to yourself.
