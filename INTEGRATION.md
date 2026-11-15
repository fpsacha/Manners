# Wiring a painted look

Not shipped (`.pkgmeta` ignores it). How to give a look the painted frame Frost
wears, in one sitting. Two kinds:

- **A plain look** (firemage, priest, rogue, monk, demonhunter, evoker, ghost,
  hairline, pill, slate) has no Lua of its own: one row in `Looks/Plain.lua`'s
  `PLAIN` and its painting are all it is. They are wired already.
- **An existing look** (glass, framed, luxe, toast, arcane, ribbon, letter,
  leather, forge, archmage, lightbringer, fel, wild, stormcaller, ebon,
  warchief, gearworks) keeps its own Lua, its animations and its meanings and
  wears the painting over them. Frost is the worked example: its
  `paintedHides`, `paintedIconFill`, `PaintedPlace`, `PaintedStyled`, the one
  `Painted.Tone` line in its `Dress` and the `KeyWanted` line in its
  `KeyLabel`. **The recipe below is for these.**

## What the engine does and what stays the look's

- **Opting in is data.** A look is painted when `Looks/PaintedData.lua` has an
  entry under its key. `Looks/Painted.lua` (loaded after every look, before
  `Prompt/`) wraps that look's `Build`, `Apply`, `Styled`, `Hide` and `Chip` at
  load; the look's own code runs as it did, then the painting is laid.
- **The engine draws** three textures on `kit.art` (BACKGROUND, sublevel -5):
  LEFT (the socket's end), MIDDLE (stretched), RIGHT (the end ornament), and a
  fourth, the **keycap** (sublevel -4) over the right end, whose frame is whole
  under it. They are sized from the prompt's real width and height
  (`Painted.Layout`: the bar's core is the prompt's height; a well too short
  for 9.5 of the font's size has the ends hang past the prompt as far as
  `hangLeft`/`hangRight` allow; a prompt too short for the whole painting has
  the ends cut back, then the bar drawn smaller). It puts `kit.icon` in the
  socket, sets `kit.ink.light/lo/hi` to the ground under the words (`Legible`
  holds the words to it), keeps the regions the look names in `paintedHides`
  hidden, and shows the keycap only while a key is bound and *Show my key on
  the prompt* asks for it (`Painted.KeyShown`), never over an outcome.
- **Dark ink.** A painting whose words are dark on a light ground (Letter's
  parchment: `text_colour_ok: false`, or an `ink` in meta.json) has
  `ink.light = false`, `ink.name` and `ink.reason` in its data. The engine
  writes the name and the reason line in them (held to the ground, no shadow;
  `kit.ink.sub` is the reason's ink, for the look's own `PaintReason`), and
  gives the look `classContrast`/`codeContrast` 5 and `classInk` (the name's
  ink, 0.55) unless the look sets its own (Letter does).
- **See-through panes** (meta.json `see_through` and `pane`): the tool draws the
  pane's inside at `PANE_ALPHA` **0.80**, rims, frames and highlights solid.
  Why 0.80: the palest pane (Pill's, about 40 of 255) over a white world is 83
  of 255, white words 7.7:1 and the gold reason 5:1 on it; the data's ink
  `hi` is that pane over white, so `Legible` holds every line to the bright
  case. `tools/audit_look_contrast.py` measures the see-through and bare looks
  over its bright world and its cave as well as dusk.
- **Words on nothing** (meta.json `pane: null`: Hairline): the look lays a soft
  dark backing (black at **0.70**, soft top, bottom and end) under the two lines,
  from the socket's frame to just past the longer line, and gives the words a
  full dark shadow. Over a white world that ground is 76 of 255: white 8.7:1,
  gold 5.8:1.
- **The look keeps** everything else: its Attention, Flourish, outcome wash,
  reason colouring, count chip, list, fight, hover, its icon mask (by its own
  round rule) and its moving layers. Its `PaintedPlace(g, p, above)` moves
  what it keeps onto the painting.
- **Earlier art** (`prompt.classicArt`, Look page, off by default): every
  wrapper falls through to the look's own method and nothing of the painting
  shows (a plain look, which has no earlier art, stays painted).
- **Show my key on the prompt** (`prompt.keycap`: `look`, `show`, `hide`):
  `Looks.KeyWanted(look)`. "As the look has it" is the data's `keycap.shown`
  (the tool's `KEYCAP_HIDDEN`: hidden on glass, framed, toast, arcane, luxe,
  minimal, ghost, hairline, pill, slate; a meta.json may say `keycap_shown`).
  Every look's own `KeyLabel` already asks it.
- **Categories** (the picker's shelves) are filed by key in `Looks/Looks.lua`
  (`SHELVES`); a look needs no line for it. The class looks' titles are the
  class names; their keys (and so saved settings) are unchanged.

## The recipe (one existing look, one sitting)

Touch only: `Looks/<Name>.lua` (and `Looks/Glass.lua`/`Prompt/Panel.lua` for
glass and framed), `art/looks/<key>/`, `Textures/Painted/<Key>/`,
`tests/scenarios/painted-<key>.lua`, `tests/mutations/painted-<key>.py`, and the
look's existing scenario files where they must set `p.classicArt = true`.

**Do NOT commit** these shared, generated files (run the tools locally to test,
then `git checkout -- <file>` before committing): `Looks/PaintedData.lua`,
`Looks/Previews.lua`, `Textures/Previews/`, `Textures/Painted/Mask.tga` and the
tocs. They are regenerated once after all the looks are merged
(`python tools/make_painted_look.py --all`, `python tools/make_look_previews.py`).
One data file per look was weighed and not chosen: each would need a toc line,
and the toc is the one file every branch would then change.

1. **Copy the art in.** From `.manners-selftest-tmp/looks-gemini/<key>/` copy
   `final-empty.jpg` and `meta.json` (never `final-*-v1/-v2` or `meta-v*.json`)
   to `art/looks/<key>/`. The tool reads the painters' variants (`r` or `half`,
   `half_w`, `end` or `endcap`, `pane`, `see_through`, `contrast` ignored) and
   stops with the look's key on anything it cannot read.
2. **Run the tool:** `python tools/make_painted_look.py <key> --debug <tmpdir>`
   and Read `<tmpdir>/<key>-measured.png`: red the core (the bar's own top and
   bottom in the stretch run), yellow the two cuts, green the socket, cyan where
   the text starts and centres, magenta the keycap (the frame under it must be
   the well, filled level), orange the ornament, blue the well's top and bottom.
   Checker must show through everywhere outside the bar and nowhere inside it.
   If the slate eats a soft rim or leaves a shadow's flecks: meta.json
   `"keying": {"lo": .., "ramp": ..}` (the edge's tolerance) or `"clip": true`
   (nothing outside `bar`); a wrong keycap default: `"keycap_shown"`; a well
   the look's own fight dims the words too far on: `"well_hi"` (under 0.10
   darkens it further; Frost's is 0.035). The key's letter is pale or dark,
   whichever reads better on the keycap, and outlined (`keyOutline`) where
   neither reaches 4.5:1. Run again
   until every mark sits right. The printed line says whether the well was
   darkened, the ink and the key's letter colour.
3. **The look's Lua**, at its `Register` table:
   ```lua
   paintedHides = { "body", "shadow", ... },   -- fields of the look the painting replaces
   paintedIconFill = 0.98,                       -- of the socket's width; less to leave a ring
   ```
   Name the frame's material (plate, ends, shadow, bezel or socket, end
   ornament, the key tag) and whatever of the ornament would stand on the
   painting's. Not what carries a meaning (the reason's marks, the lights, the
   outcome's glyph, the count chip, the list's sheet and markers) nor what
   moves, unless it clashes.
4. **`PaintedPlace(g, p, above)`** on the look (after its `Hide`). `g`, in units
   from art's top left, y down: `unit`, `top`, `y0`/`y1`, `left`/`right`,
   `x1`/`x2`, `socketX`, `socketY`, `socketR`, `iconSize`, `round`, `square`,
   `textX`, `textY`, `keyX`, `keyY`, `keyW`, `keyH`, `endX`, `endY`, `wellTop`,
   `wellBottom`, `keyInk`. The usual lines:
   - its own geometry fields from `g` and its own placing helpers again (Frost:
     `PlaceCrystal`, `PlaceGrowth`, `PlaceMotion`);
   - its name and reason lines shifted by `H / 2 - g.textY`;
   - its key's text CENTER at `g.keyX, g.keyY` (`keyBox`, `g.keyW` x
     `g.keyH`), reparented onto a frame of its own (Frost: `chipFrame`; back
     onto `textLayer` in its own Apply); its right inset (`chipInset`) to
     `W - (g.keyX - g.keyW / 2) + 3`, `roomBase` from it;
   - its list from the socket to the keycap's far side, and `listGap` so the
     rows clear what hangs below;
   - any motion from a hidden region off;
   - `return g.textX, self.roomBase`.
   In its `Chip`, give the key no room of the lines' own while
   `ns.Looks.Painted.On(self)`, and show the letter whenever `KeyLabel` gives
   one (it already asks `ns.Looks.KeyWanted`).
5. **`PaintedStyled(g)`**: the key's letter
   `self.keyText:SetTextColor(g.keyInk[1], g.keyInk[2], g.keyInk[3], 1)`, no
   shadow, font no larger than 0.7 of `g.keyH`; and whatever else must read
   against the painting. For a dark-ink painting (Letter) the engine has set
   the name and the reason already: do not write them light again.
6. **Its dressing**: where it colours its plate for a fight or a refusal, one
   line: `ns.Looks.Painted.Tone(self, r, g, b, grey)`, dimmed less than the old
   plate in a fight (Frost: 0.86) so a light keycap keeps its dark letter.
7. **Its own scenarios keep the earlier art**: in its helpers that put the
   prompt up (`tests/scenarios/look-<key>.lua`, `readable-<key>.lua`, ...), add
   `p.classicArt = true`, as `look-frost.lua` does.
8. **Its tests**, in files of its own: `tests/scenarios/painted-<key>.lua`
   (copy `painted.lua`'s first, third, fourth and sixth scenarios with the key
   changed: it wears its painting and none of `paintedHides`; the pieces meet
   and follow the size; the icon in the socket, the name in the well, the key
   on the keycap; a fight and a change of look) and
   `tests/mutations/painted-<key>.py` (one mutation each undoing its
   `paintedHides` entry for the plate, its `PaintedPlace`'s text start and its
   `Tone` line), each proven CAUGHT with
   `python tools/prove.py --file tests/mutations/painted-<key>.py --jobs 2`.
9. **Previews and contrast, locally**: `python tools/make_look_previews.py`
   (a painted look's view is worked out from its painting: no `FRAMES` entry,
   no `ROOM` in theme-picker.lua), then
   `python tools/audit_look_contrast.py --looks <key> --check`. Under 4.5:1,
   lower `WELL_HI` for that painting or darken its well, never the check. Then
   `git checkout -- Looks/PaintedData.lua Looks/Previews.lua Textures/Previews`.
10. **Docs**: the look's own line in CLAUDE.md's file map if what it draws
    changed. Nothing in CHANGELOG.md (the merge writes it once).

Then: its scenario files, `painted-<key>.lua`, `painted.lua`,
`hunt38-picker.lua`, `theme-picker.lua`, `layout.lua` and `menu.lua`, all
`failures: 0` with the data regenerated locally.

## What to check in the renders

`python tools/render_prompt.py --out <dir> --style <key> --key F --size large`,
then Read `owed`, `calm-owed`, `queue`, `list-above`, `combat`, `success`,
`refused`, `small-size`, `large-size`, `round`, `no-icon`, `tall-narrow`: the
icon centred in the socket; the name inside the well, never under the keycap;
the key's letter centred on the keycap and readable (and with
`prompt.keycap = "hide"` the frame whole under it); no step of light or a cut
ornament where an end meets the middle (`zoom` the seam); the ends never
stretched; the lights and moving layers on the painting; the list's rows clear
of what hangs under the bar; a fight greying the painting. Compare with the old
look: `--addon` an export of the commit before, same arguments.

## Adding a plain look

Its painting in `art/looks/<key>/`, the tool run, a row in `Looks/Plain.lua`'s
`PLAIN` (key, title, description, order, category), its key on a shelf in
`Looks/Looks.lua`'s `SHELVES`, the title and line in all eight languages.
Nothing else: `Looks/Plain.lua` answers the whole look interface for it.
