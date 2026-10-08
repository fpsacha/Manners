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
2. **Run the full mutation suite** by hand: `python tests/selftest.py` (about
   20 to 40 minutes; its docstring says what it does). Nothing after this step
   runs it: CI and the release workflow run only `--anchors`.
3. **Release with `python tools/release.py X.Y.Z`.** Try it with `--dry-run`
   first, which prints every step and changes nothing. It:
   - checks it is on `master` with a clean tree, that `## Unreleased` has
     notes, and that `python tools/check.py` passes;
   - sets the version with `tests/setversion.py`, which renames
     `## Unreleased` to the version;
   - commits "Manners X.Y.Z", with the Co-Authored-By line given by
     `--coauthor` or the `MANNERS_COAUTHOR` environment variable;
   - pushes master and waits for CI on that commit (`gh run watch`);
   - tags `vX.Y.Z`, annotated "Manners X.Y.Z", and pushes the tag;
   - waits for `release.yml` and prints the packager's "Game version:" line
     and the upload results.

The same steps by hand, if the tool cannot be used. `validate` fails with "no
notes under" if step 1 was skipped, which is the same check the release makes.
Push the tag only once CI has passed on the pushed commit:

```
python tests/setversion.py X.Y.Z-beta.N
python tools/check.py
git commit -am "Manners X.Y.Z-beta.N"
git push origin master
git tag vX.Y.Z-beta.N
git push origin vX.Y.Z-beta.N
```

`setversion.py` writes the version into every toc (`Manners.toc` and the five
generated `Manners_<Flavour>.toc`), into `ns.BUILD` in `Prompt/Prompt.lua`, and
onto the changelog heading. Never edit those by hand: doing it that way produced
a mismatch twice, each time by correcting a value that was already the wrong
one. If the top heading is not `## Unreleased` it adds a new, empty section
instead and says so; the notes then go under that before you go on.

It takes `X.Y.Z`, `X.Y.Z-alpha.N` and `X.Y.Z-beta.N`, and nothing else. The
packager reads "alpha" or "beta" out of the tag to mark a pre-release, and
anything without one of them — `-rc.1` included — goes out as a full release on
every site. A release candidate is spelled as the next beta.

Pushing the tag runs `.github/workflows/release.yml`, which:

1. runs `validate`, `runharness`, `runscenarios` and `selftest --anchors`
2. reports which upload destinations have tokens configured
3. builds `RELEASE_NOTES.md` from this version's changelog section, and stops
   if that section is missing or empty
4. packages with the libraries fetched as externals
5. makes a GitHub release and uploads to CurseForge and Wago (and WoWInterface,
   if it is ever given a token and an id)

Every ordinary push runs the same suites through `.github/workflows/ci.yml`,
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

## Game versions

Each generated toc carries one client's interface number, and the packager tags
the upload with every client it finds a `Manners_<Flavour>.toc` for in the
checkout's top folder:

| toc | Interface | Client |
|---|---|---|
| `Manners_Camelot.toc` | 16001 | WoW Forever 1.60.1 |
| `Manners_Vanilla.toc` | 11509 | Classic Era 1.15.9 |
| `Manners_TBC.toc` | 20506 | Burning Crusade Classic Anniversary 2.5.6 |
| `Manners_Mists.toc` | 50504 | Mists of Pandaria Classic 5.5.4 |
| `Manners_Mainline.toc` | 120100 | retail 12.1.0 |

`tools/release.py` prints the packager's "Game version:" line. If the packager
cannot map a new interface number to a CurseForge game version, the upload
still succeeds and the version is set by hand on the file page.

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
which looks identical to a successful upload in the log — hence step 2 of the
workflow above.

Tokens are created at <https://legacy.curseforge.com/account/api-tokens> and on
Wago's account page, and added under Settings → Secrets and variables → Actions.
Set them with `gh secret set CF_API_KEY`, which prompts for the value rather
than taking it on the command line where it would land in your shell history.
Nobody else types or keeps a token.

## The listing

Neither CurseForge nor Wago has an API for the project page's text (only for
uploads), so the page is pasted by hand. Each listing file holds only what goes
on the page, so it can be pasted whole and nothing meant for us ends up in
public:

| Site | Field | File |
|---|---|---|
| CurseForge | Summary | `.github/curseforge-summary.txt` |
| CurseForge | Description (Markdown) | `.github/curseforge-description.md` |
| Wago | Description (Markdown, shorter) | `.github/wago-description.md` |
| Both | Gallery titles and descriptions | `.github/gallery.md` |

The README is written for people reading the source, not for the listings. No
listing carries a testing disclaimer ("untested", "mock client", "not tried in
game"), and none claims more than the addon does. The descriptions embed the
images from `https://raw.githubusercontent.com/fpsacha/Manners/master/.github/media/`,
so they show inline only once `master` holds them.

The images are generated rather than captured: `python tools/make-icon.py` and
`python tools/make-screenshots.py`. See `tools/README.md`.

The six screenshots -- `manners-prompt.png`, `manners-reasons.png`,
`manners-looks.png`, `manners-ledger.png`, `manners-languages.png` and
`manners-palette.png` in `.github/media/` -- go into the CurseForge and Wago
galleries by hand; neither upload in the release workflow carries images. Their
order, titles and descriptions are in `.github/gallery.md`. When they are
regenerated, replace the gallery copies too.

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
