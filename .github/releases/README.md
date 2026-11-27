# Release notes

Write each version's notes in its own Markdown file, matching the tag exactly:
`v1.0.0` uses `.github/releases/v1.0.0.md`.

Commit the notes before creating and pushing the tag. Write the Markdown as you
want it to appear in the GitHub release description.

After all platform jobs pass, CI uploads the three packages and
`SHA256SUMS.txt` as workflow artifacts. Create the GitHub release manually with
those files and this Markdown as its description. Verify checksums before
publishing. See `ELECTRON-TEMPLATE.md` for a starting point.
