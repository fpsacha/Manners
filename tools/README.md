# tools

The generators for the addon's per-flavour `.toc` files, for the images on the
CurseForge listing and in the README, and for the addon's own icon.
Nothing in here ships: `.pkgmeta` ignores this folder, and the game never loads it.

They live in the repository rather than on somebody's desktop so the listing can
be rebuilt when the addon changes. The first versions were one-off scripts, which
meant the published images could only ever drift away from the addon.

## maketocs.py

Writes one `Manners_<Flavour>.toc` from `Manners.toc` for each entry in its
`FLAVOURS` table. 1.0 ships for WoW Forever alone, so that is one file today,
`Manners_Camelot.toc`. `Mainline`, `Mists` and `Vanilla` are commented out until
somebody runs the addon on those clients; there will be no `Manners_TBC.toc`
until the Burning Crusade spell ids are in the tables.

```
python tools/maketocs.py           # write them
python tools/maketocs.py --check   # say whether they are up to date
```

Needs nothing but the standard library, unlike the image tools below.

`Manners.toc` is the only one anybody edits, and it stays in the tree as the
fallback for a client that does not honour a suffixed name. The generated
copies differ from it in exactly one line — the interface number — which is why
they are generated: hand-maintained copies of the same file list drift, and a
toc that has lost a line from its file list produces an addon that loads four
files instead of five, defines nothing, says nothing, and looks precisely like
not having been installed.

`tests/validate.py` re-runs the render in memory and fails if what is on disk
differs, so a hand edit to a generated file cannot survive a test run unnoticed.
`tests/setversion.py` writes the version into `Manners.toc` and then re-runs
this, which is what keeps them all agreeing.

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
size, font size — and the four reason colours out of `Prompt.lua`'s
`REASON_COLOR`. When a default changes, re-run this and commit the result.

A value it cannot find falls back to the one restated in the script, with a
note on stderr, and the last line says which were not read. `--strict` refuses
to draw instead; CI runs it that way, so a renamed setting fails the build
rather than producing images of a layout the addon no longer has.

What it does not read is the drawing itself, which is restated here. If
`Prompt.lua` changes how the panel is painted, this has to be updated by hand
to match, or the images become a nice picture of something that no longer
exists.

Every player name in the output is invented. Real names from a live session
ended up in an earlier draft; they belong to real people and were scrubbed.
Keep it that way.

## render_prompt.py

Draws the prompt the way the addon builds it, with no game running. It loads
the addon on the mock client from `tests/`, puts the prompt into each of the
states listed in `render_prompt.lua` (somebody who buffed you, a refused buff,
held in combat, each look and accent mode, two scales, and more), and draws
what the frames were told: anchors, sizes, colours, gradients, blend modes,
masks, text, and where each animation is in its run. The frame tree comes from
`tests/frametree.lua`, which records every frame, texture, font string,
animation group and cooldown the addon makes.

```
python tools/render_prompt.py --out renders          # every state, plus sheet.png
python tools/render_prompt.py --states owed,refused  # just those
python tools/render_prompt.py --addon ../old --out before   # an older build
python tools/render_prompt.py --compare before after compare.png
```

`--addon` draws another checkout of the addon with today's renderer, which is
the fair way to put a before and an after side by side. Needs lupa, Pillow and
numpy.

It is not pixel-true. The font is Candara standing in for Friz Quadrata, spell
icons are drawn tiles with the spell's initials, and Blizzard art files are
flat tiles with a note on stdout. It is faithful about layout, colour, text,
size and what is shown or hidden, because all of those are read from the addon
rather than restated here. Where a region is anchored by an edge and a centre
on the same axis, it is drawn from the edge and a note says so: which of the
two the client uses is not settled here.

## make-glow.py

`Textures/Glow.tga` and `Textures/GlowRound.tga`, the soft glows the prompt
draws round its spell icon. Like `Manners64.tga` they ship in the zip. Needs
Pillow; deterministic.

`Glow.tga` is light falling off in every direction from its centre, and
`Prompt.lua` cuts it into eight pieces round a square icon: the quarters are
the corners and a line through the middle is each side, so every join has the
same brightness on both sides of it. `GlowRound.tga` is a ring for the rounded
icon; `RING_AT` in the script and `GLOW_RING_AT` in `Prompt.lua` say where its
rim is and have to agree. Both are white with the shape in the alpha, and the
prompt colours them.

## make-icon.py

`icon-512.png` (the CurseForge avatar), `icon-64.png`, and `icon-check.png`,
which is just the two sizes side by side so the small one can be judged at the
size it is actually seen.

It also writes `Textures/Manners64.tga`, which lives outside this folder because
it is the one thing these tools make that ships in the zip: the
game cannot load a PNG, and this is the icon in the addon list (`IconTexture` in
`Manners.toc`) and on the minimap button (`ICON` in `Options.lua`).

Drawn to sit next to real WoW spell icons: bevelled gold frame lit from the
top-left, dark saturated interior, one glowing subject, plenty of bloom.

## fonts.py

Resolves a weight to whatever face is installed, preferring the Segoe UI the
images were designed against and falling back through DejaVu and Arial. It says
so on stderr when it falls back, because an image that silently rendered in the
bitmap default would look broken for a reason nobody could guess from looking
at it.
