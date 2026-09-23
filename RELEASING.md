# Releasing

`Libs/` is not in this repository. `.pkgmeta` declares all 14 libraries as
build-time externals, so the packager fetches current upstream copies under
their own licences.

**A zip built from a clone has no libraries and the addon will not load.**
Build through the workflow.

## Each release

In this order. The tag goes last and on its own, because the moment it reaches
origin the release workflow starts, and a tag whose build fails is still there
afterwards — pushing it again only says it already exists.

1. **Write the notes.** Put them under `## Unreleased` at the top of
   `CHANGELOG.md`, written for the people who play the game: this section is
   exactly what CurseForge, Wago and the GitHub release show.
2. **Set the version** with `python tests/setversion.py X.Y.Z-beta.N`. It
   renames `## Unreleased` to the version. If the top heading is anything else
   it adds a new, empty section instead and says so — the notes then go under
   that before you go on.
3. **Run the four suites.** `validate` fails with "no notes under" if step 1
   was skipped, which is the same check the release makes.
4. **Commit.**
5. **Push master and wait for CI to go green.**
6. **Tag, and push the tag.**

```
python tests/setversion.py X.Y.Z-beta.N
python tests/validate.py
python tests/runharness.py
python tests/runscenarios.py
python tests/selftest.py
git commit -am "Manners X.Y.Z-beta.N"
git push origin master
git tag vX.Y.Z-beta.N
git push origin vX.Y.Z-beta.N
```

The last two lines only once CI has passed on the pushed commit.

`setversion.py` writes the version into every toc (`Manners.toc` and the
generated `Manners_Camelot.toc`), into `ns.BUILD` in `Prompt.lua`, and onto the
changelog heading. Never edit those by hand: doing it that way produced a
mismatch twice, each time by correcting a value that was already the wrong one.

It takes `X.Y.Z`, `X.Y.Z-alpha.N` and `X.Y.Z-beta.N`, and nothing else. The
packager reads "alpha" or "beta" out of the tag to mark a pre-release, and
anything without one of them — `-rc.1` included — goes out as a full release on
every site. A release candidate is spelled as the next beta.

Pushing the tag runs `.github/workflows/release.yml`, which:

1. runs all four suites — `validate`, `runharness`, `runscenarios`, `selftest`
2. fails the build if any check has stopped being able to detect the fault it
   exists for
3. reports which upload destinations have tokens configured
4. builds `RELEASE_NOTES.md` from this version's changelog section, and stops
   if that section is missing or empty
5. packages with the libraries fetched as externals
6. makes a GitHub release and uploads to CurseForge and Wago (and WoWInterface,
   if it is ever given a token and an id)

Every ordinary push runs the same four suites through `.github/workflows/ci.yml`,
so a tag should never be the first time a problem is heard about.

## When a tag's build fails

The tag is on origin and has to come off before the same version can be tagged
again. Delete it in both places, fix, and tag the fixed commit:

```
git push origin :refs/tags/vX.Y.Z-beta.N
git tag -d vX.Y.Z-beta.N
git commit -am "..."
git push origin master
git tag vX.Y.Z-beta.N
git push origin vX.Y.Z-beta.N
```

That is only safe when nothing was published: the suites and the notes run
before the packager, so a failure there uploaded nothing. If the packager had
already put a file on any site, use the next version number instead.

## Setup, already done

Kept as a record of how it was wired, and for anyone forking this.

| | |
|---|---|
| Repository | <https://github.com/fpsacha/Manners>, default branch `master` |
| CurseForge project | 1705364, id set in `Manners.toc` as `X-Curse-Project-ID` |
| Wago project | `rNkgzlNa`, id set in `Manners.toc` as `X-Wago-ID` |
| Upload tokens | `CF_API_KEY` and `WAGO_API_TOKEN`, GitHub Actions secrets |

`WOWI_API_TOKEN` and an `X-WoWI-ID` in the toc would add WoWInterface the same
way. Any destination without a token is skipped rather than failing the build,
which looks identical to a successful upload in the log — hence step 3 of the
workflow above.

Tokens are created at <https://legacy.curseforge.com/account/api-tokens> and on
Wago's account page, and added under Settings → Secrets and variables → Actions.
Set them with `gh secret set CF_API_KEY`, which prompts for the value rather
than taking it on the command line where it would land in your shell history.

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
- [ ] Only Mage has cast in game. The listing and the toc both say so, and they
      should keep saying so until somebody reports otherwise
