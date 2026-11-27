# Manners -- release

The release steps and versions; the manual steps are in `RELEASING.md`. Moved
out of `CLAUDE.md`, word for word; `CLAUDE.md` is the index, read first.

## Release

1. Documentation first, in the same change as the code: notes under
   `## Unreleased` at the top of `CHANGELOG.md`, for players, with the date in
   italics on a line of its own under the heading, `### Highlights` first
   (the few things that matter most, a line or two each) and `### Fixes` last,
   then `python tools/make_whatsnew.py`; the README's
   player sections for every new or changed setting; `STATUS.md` (version,
   open items, what only the live game can say); the three listing files in
   `.github/` where a feature is new; `CLAUDE.md`, `.claude/docs/`, `tools/README.md` and
   `tests/README.md` where a file, tool or rule changed.
2. The full selftest is `selftest.yml` on GitHub; `release.py` reads its last
   green run of master and runs only the mutations changed since. Nothing by
   hand unless GitHub cannot run it (then the full run and `--skip-selftest`).
3. `python tools/release.py X.Y.Z` (`--dry-run` prints the steps). It checks
   master, a clean tree, the notes and `tools/check.py`; runs
   `tests/setversion.py`; commits "Manners X.Y.Z" with the Co-Authored-By line
   from `--coauthor` or `MANNERS_COAUTHOR`; pushes master and waits for CI;
   tags `vX.Y.Z` (annotated) and pushes it; waits for `release.yml`; prints
   the packager's "Game version:" line and the upload results.

## Discord

The Manners Discord (invite `https://discord.gg/JHc8YSDvur`, never expires;
server id 1575227984262988058) is fed one way from GitHub by
`.github/workflows/discord.yml`: a release goes to #releases with its body
when the Release workflow's tag build succeeds (`workflow_run`; a release made
with GITHUB_TOKEN never fires `release: published` for other workflows) (so the GitHub release notes are what players read there too); a new
issue goes to #bug-reports, or #suggestions when it carries `enhancement`; an
issue labelled `enhancement` later goes to #suggestions. The three webhook URLs
are the secrets `DISCORD_RELEASES_WEBHOOK`, `DISCORD_BUGS_WEBHOOK`,
`DISCORD_SUGGESTIONS_WEBHOOK`; never print or commit them. A missing secret
skips its post. "Run workflow" on the Discord workflow posts the latest release
again, or the one named in its *tag* input (`gh workflow run discord.yml -f
tag=vX.Y.Z`). Renaming the `enhancement` label, or deleting a webhook in Discord,
breaks the pipe silently. Player questions arrive in the #help forum; the
nightly pass reads it (see the nightly task's prompt).

Versions: `X.Y.Z`, `X.Y.Z-alpha.N`, `X.Y.Z-beta.N` only. Never edit a version
by hand: `tests/setversion.py` writes every toc, `ns.BUILD` in
`Prompt/Prompt.lua` and the changelog heading. The manual steps, and how to take
back a failed tag, are in `RELEASING.md`.
