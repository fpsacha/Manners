# Releasing

`Libs/` is not in this repository. `.pkgmeta` declares all thirteen libraries
as build-time externals, so the packager fetches current upstream copies under
their own licences.

**A zip built from a clone has no libraries and the addon will not load.**
Build through the workflow.

## Each release

```
python tests/setversion.py 0.9.7
git commit -am "Manners 0.9.7"
git tag v0.9.7
git push origin master --tags
```

`setversion.py` writes the version into all three files that carry it — the
toc, `ns.BUILD` in `Prompt.lua`, and the changelog heading. Never edit those by
hand: doing it that way produced a mismatch twice, each time by correcting a
value that was already the wrong one.

Pushing the tag runs `.github/workflows/release.yml`, which:

1. runs all four suites — `validate`, `runharness`, `runscenarios`, `selftest`
2. fails the build if any check has stopped being able to detect the fault it
   exists for
3. reports which upload destinations have tokens configured
4. packages with the libraries fetched as externals
5. makes a GitHub release and uploads to CurseForge

Every ordinary push runs the same four suites through `.github/workflows/ci.yml`,
so a tag should never be the first time a problem is heard about.

## Setup, already done

Kept as a record of how it was wired, and for anyone forking this.

| | |
|---|---|
| Repository | <https://github.com/fpsacha/Manners>, default branch `master` |
| CurseForge project | 1705364, id set in `Manners.toc` as `X-Curse-Project-ID` |
| Upload token | `CF_API_KEY`, a GitHub Actions secret |

`WOWI_API_TOKEN` and `WAGO_API_TOKEN` would work the same way for those sites.
Any destination without a token is skipped rather than failing the build, which
looks identical to a successful upload in the log — hence step 3 above.

Tokens are created at <https://legacy.curseforge.com/account/api-tokens> and
added under Settings → Secrets and variables → Actions. Set them with
`gh secret set CF_API_KEY`, which prompts for the value rather than taking it
on the command line where it would land in your shell history.

## The listing

The project page body is `.github/curseforge-description.md`, pasted whole into
CurseForge's editor — not the README, which is written for people reading the
source. `.github/DESCRIPTION.md` holds the summary-field options.

The images are generated rather than captured: `python tools/make-icon.py` and
`python tools/make-screenshots.py`. See `tools/README.md`.

## Moderation

A new CurseForge project is not publicly visible until a moderator approves it,
and new files are scanned on upload. Automated analysis runs first; anything it
flags goes to a person. Their published figures are around 2,000 new projects a
week and "several hours to several days" for a manual review — there is no
committed turnaround.

Uploads succeed and are downloadable by direct link during this; it is
visibility in search and in WowUp that waits. If nothing has moved after about
three days it has probably been flagged for manual review, and a support ticket
is faster than waiting longer.

## Game version

The toc declares `## Interface: 16001`, which is WoW Forever (internally
"Camelot"). If the packager cannot map a brand-new interface number to a
CurseForge game version, the upload still succeeds and the version is set by
hand on the file page. Check it after a release.

## Still open

- [ ] Decide whether `verbose` should default on — every user gets a chat line
      each time somebody buffs them
- [ ] Real player names remain in git history from before the v0.9.5 scrub.
      The repository has no forks, so a rewrite is still cheap
- [ ] Only Mage has cast in game. The listing and the toc both say so, and they
      should keep saying so until somebody reports otherwise
