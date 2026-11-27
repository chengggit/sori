# Release notes

Write each version's notes in its own Markdown file, matching the tag exactly:
`v1.0.0` uses `.github/releases/v1.0.0.md`.

Commit the notes before creating and pushing the tag. Write the Markdown as you
want it to appear in the GitHub release description.

After all platform packages pass, CI creates a draft release with these notes
and the three packages. Checksums are verified in CI and kept in workflow
artifacts. Review the draft and publish it when ready.
Rerunning the workflow refreshes an existing draft's notes and assets; published
releases are left untouched.
