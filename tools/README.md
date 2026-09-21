# tools

The generators for the addon's five per-flavour `.toc` files, and for the images
on the CurseForge listing and in the README.
Nothing in here ships: `.pkgmeta` ignores this folder, and the game never loads it.

They live in the repository rather than on somebody's desktop so the listing can
be rebuilt when the addon changes. The first versions were one-off scripts, which
meant the published images could only ever drift away from the addon.

## maketocs.py

Writes `Manners_Mainline.toc`, `Manners_Camelot.toc`, `Manners_Mists.toc`,
`Manners_TBC.toc` and `Manners_Vanilla.toc` from `Manners.toc`.

```
python tools/maketocs.py           # write them
python tools/maketocs.py --check   # say whether they are up to date
```

Needs nothing but the standard library, unlike the image tools below.

`Manners.toc` is the only one anybody edits, and it stays in the tree as the
fallback for a client that does not honour a suffixed name. The five copies
differ from it in exactly one line — the interface number — which is why they
are generated: five hand-maintained copies of the same file list drift, and a
toc that has lost a line from its file list produces an addon that loads four
files instead of five, defines nothing, says nothing, and looks precisely like
not having been installed.

`tests/validate.py` re-runs the render in memory and fails if what is on disk
differs, so a hand edit to a generated file cannot survive a test run unnoticed.
`tests/setversion.py` writes the version into `Manners.toc` and then re-runs
this, which is what keeps all six agreeing.

## Running the image tools

Both need [Pillow](https://pypi.org/project/Pillow/):

```
python -m pip install Pillow
python tools/make-screenshots.py
python tools/make-icon.py
```

Output lands in `.github/media/`. Both are deterministic: running them without
changing anything rewrites the same bytes, so `git status` staying clean is the
check that nothing drifted.

## make-screenshots.py

`screenshot-reasons.png` and `screenshot-prompt.png`.

These are **renders of the prompt, not captures from the game**. The panel
geometry is read out of `Core.lua`'s defaults at run time — width, height, icon
size, font size — so the images cannot claim a layout the addon does not draw.
When a default changes, re-run this and commit the result.

What it does not read is the colours and the drawing itself, which are restated
here. If `Prompt.lua` changes how the panel is painted, this has to be updated by
hand to match, or the images become a nice picture of something that no longer
exists.

Every player name in the output is invented. Real names from a live session
ended up in an earlier draft; they belong to real people and were scrubbed.
Keep it that way.

## make-icon.py

`icon-512.png` (the CurseForge avatar), `icon-64.png`, and `icon-check.png`,
which is just the two sizes side by side so the small one can be judged at the
size it is actually seen.

Drawn to sit next to real WoW spell icons: bevelled gold frame lit from the
top-left, dark saturated interior, one glowing subject, plenty of bloom.

## fonts.py

Resolves a weight to whatever face is installed, preferring the Segoe UI the
images were designed against and falling back through DejaVu and Arial. It says
so on stderr when it falls back, because an image that silently rendered in the
bitmap default would look broken for a reason nobody could guess from looking
at it.
