---
description: Release flow: changelog check, full selftest, tools/release.py with the Co-Authored-By line
argument-hint: "X.Y.Z[-alpha.N|-beta.N]"
---
Release `$ARGUMENTS` (only `X.Y.Z`, `X.Y.Z-alpha.N`, `X.Y.Z-beta.N`; a release
candidate is the next beta). RELEASING.md has the reasons. In order, stopping
at the first red:

1. On `master`, clean tree (`git status`), every worktree branch merged.
   `python tools/clients_watch.py`: a drifted interface number is changed first
   (`tools/maketocs.py` FLAVOURS and `Manners.toc`, then `python tools/maketocs.py`).
2. Top of `CHANGELOG.md` is `## Unreleased` with notes written for players (they
   are the CurseForge, Wago and GitHub text): no "untested", "mock client" or
   "not tried in game". `release.py` refuses an empty section.
3. The full selftest, by hand; the release tool never runs it:
   `python tests/selftest.py --jobs N` (20 to 40 minutes, leave 2 cores free;
   run it in the background). It must end `RESULT: every mutation was caught`.
   Any MISSED, WRONG CHECK, ANCHOR GONE or NOT RESTORED stops the release.
4. `python tools/check.py --lint --flavours --anchors`.
5. Dry run, and show the user its output: `python tools/release.py $ARGUMENTS --dry-run`
6. Ask the user to confirm the version. Only on a clear yes, run it with the
   Co-Authored-By line (`--coauthor` reads the same in bash and in PowerShell;
   an environment prefix does not):
   `python tools/release.py $ARGUMENTS --coauthor "Claude Sonnet 5.5 <noreply@anthropic.com>"`
   It sets the version (`tests/setversion.py`), commits "Manners X.Y.Z", pushes
   master, waits for CI, tags `vX.Y.Z`, pushes the tag, waits for `release.yml`
   and prints the packager's `Game version:` line (all five clients) and the
   uploads. Never edit a version by hand.
7. If it stops, read what it says about where that leaves the release. A red CI
   run: fix, commit, push, run it again with the same version. A red release
   build: RELEASING.md's "When a tag's build fails", only when nothing uploaded.
8. The listing text (`.github/curseforge-summary.txt`, `curseforge-description.md`,
   `wago-description.md`, `gallery.md`) is pasted by the user: no API exists for it.

Never take, type or store an API key (`CF_API_KEY`, `WAGO_API_TOKEN` are set by
the user with `gh secret set`).
