# Wiring a painted look

Not shipped (`.pkgmeta` ignores it). How to give one more look the painted frame
Frost wears, in one sitting. Frost is the worked example: read `Looks/Painted.lua`
(the engine, its header is the interface), Frost's `paintedHides`,
`paintedIconFill`, `PaintedPlace`, `PaintedStyled` and the one `Painted.Tone` line
in its `Dress`, and `tests/scenarios/painted.lua`.

## What the engine does and what stays the look's

- **Opting in is data.** A look is painted when `Looks/PaintedData.lua` has an
  entry under its key. `Looks/Painted.lua` (loaded after every look, before
  `Prompt/`) wraps that look's `Build`, `Apply`, `Styled` and `Hide` at load. The
  look's own code is not called differently: the wrappers run it, then lay the
  painting.
- **The engine draws** three textures on `kit.art` (BACKGROUND, sublevel -5):
  LEFT (the socket's end), MIDDLE (stretched), RIGHT (keycap and ornament), sized
  from the prompt's real width and height (`Painted.Layout`: the bar's core is the
  prompt's height; a well too short for 9.5 of the font's size between the text's
  start and the keycap has the two ends hang past the prompt's edges, as far as
  `hangLeft`/`hangRight` allow; a prompt too short for the whole painting has the
  ends cut back from their inner sides, never past the text's start or the
  keycap, and only then is the bar drawn smaller). It puts `kit.icon` in the socket, sets
  `kit.ink.light/lo/hi` to the painted well's own luminance (so `Legible` holds
  the words to it), and keeps the regions the look names in `paintedHides` hidden
  whatever the look's code shows (their `Show`/`SetShown` muffled, given back
  when the painting goes).
- **The look keeps** everything else: its Attention, Flourish, outcome wash,
  reason colouring, count chip, list, fight, hover, its icon mask (by its own
  round rule) and its moving layers. Its `PaintedPlace(g, p, above)` moves what it
  keeps onto the painting.
- **Earlier art** (`prompt.classicArt`, Look page, off by default): every wrapper
  falls through to the look's own method and nothing of the painting shows.

## The recipe

1. **Copy the art in.** From the art agent's folder
   (`.manners-selftest-tmp/looks-gemini/<key>/`) copy `final-empty.jpg` and
   `meta.json` to `art/looks/<key>/`. Open the picture and check `meta.json`
   against it: `socket` (shape, `cx`, `cy`, `r` the radius of the dark hole; a
   square one gives `half`), `name_xy` and `reason_xy` (top left of each line),
   `keycap` (`cx`, `cy`, `w`, `h`), `stretch` ([x0, x1], a run with no one-off
   ornament), optionally `end` (`cx`, `cy` of the end ornament). `bar` is not read
   (the tool finds the bar itself).
2. **Run the tool:** `python tools/make_painted_look.py <key> --debug <tmpdir>`.
   Read `<tmpdir>/<key>-measured.png`: the red lines are the core (it must be the
   bar's own top and bottom in the stretch run), yellow the two cuts, green the
   socket, cyan where the text starts and centres, magenta the keycap, orange the
   ornament, blue the well's top and bottom. Fix `meta.json` and run again until
   every mark sits where it should. The line it prints says whether the well was
   darkened, and the ink and the key's letter colour it found. It writes
   `Textures/Painted/<Key>/{Left,Middle,Right}.tga` and regenerates
   `Looks/PaintedData.lua` (never edit it). `--check` says whether both are current.
3. **The look's Lua** (`Looks/<Name>.lua`), at its `Register` table:
   ```lua
   paintedHides = { "body", "shadow", ... },   -- fields of the look the painting replaces
   paintedIconFill = 0.98,                       -- of the socket's width; less to leave a ring round it
   ```
   `paintedHides` names the look's own fields: a region, or a list of regions (a
   three-slice, a nine-slice, a list of icicles). Name the frame's material (the
   plate, its ends, its shadow, the bezel or socket, the end ornament, the key tag)
   and whatever of the ornament would stand on the painting's ornament. Do NOT
   name what carries a meaning (the reason's colour marks, the lights, the
   outcome's glyph, the count chip, the list's sheet and markers) nor what moves,
   unless it would clash with the painting.
4. **`PaintedPlace(g, p, above)`** on the look (after its `Hide`): move what it
   keeps. `g` holds, in units from art's top left, y down: `unit` (core height),
   `top`, `y0`/`y1` (the art's full height), `left`/`right` (the bar's ends: less
   than 0 and more than W when they hang past the prompt), `x1`/`x2` (the cuts), `socketX`,
   `socketY`, `socketR`, `iconSize`, `round` (roundAlways or the switch),
   `square`, `textX`, `textY` (centre of the two lines), `keyX`, `keyY`, `keyW`,
   `keyH`, `endX`, `endY`, `wellTop`, `wellBottom`, `keyInk`. The usual lines:
   - set the look's own geometry fields from `g` (its icon centre and size, where
     its text starts, its plate's top and height) and call the look's own placing
     helpers again (Frost: `PlaceCrystal`, `PlaceGrowth`, `PlaceMotion`) so its
     lights, motion and rings follow;
   - shift its name and reason lines by `H / 2 - g.textY`;
   - put its key's text on the keycap (`keyBox` CENTER at `g.keyX, g.keyY`,
     sized `g.keyW` x `g.keyH`), reparented off `textLayer` onto a frame of the
     look's own (Frost: `chipFrame`) so a fight's dim of the words does not grey
     the dark letter (and back onto `textLayer` in the look's own Apply), and
     set its right inset (`chipInset`) to `W - (g.keyX - g.keyW / 2) + 3`, its
     `roomBase` from it;
   - its list from the socket to the keycap's far side, and `listGap` (or the
     look's own equivalent) so the rows clear what the painting hangs below;
   - switch off any of its motion that came from a hidden region (Frost: no
     icicle hangs, drips or falls);
   - return `g.textX, self.roomBase`.
   Where the look's `Chip` sizes room for the key tag, give it none while
   `ns.Looks.Painted.On(self)` (the keycap is already outside the lines), and show
   the key whenever one is bound.
5. **`PaintedStyled(g)`**: colours read against the painting, at least the key's
   letter: `self.keyText:SetTextColor(g.keyInk[1], g.keyInk[2], g.keyInk[3], 1)`,
   no shadow, and its font no larger than 0.7 of `g.keyH`.
6. **Its dressing**: where the look colours its plate for a fight or a refusal,
   one line more: `ns.Looks.Painted.Tone(self, r, g, b, grey)`. Dim the painting
   less than the old plate in a fight (Frost: `PAINT_COMBAT`, 0.86): a light
   keycap must keep its dark letter at 4.5:1.
7. **Earlier art for its own scenarios**: the look's own scenario file
   (`tests/scenarios/look-<key>.lua`) holds its own art; in its helpers that put
   the prompt up in the look, add `p.classicArt = true`, as `look-frost.lua` does.
8. **Previews and contrast**: `python tools/make_look_previews.py` (the card
   shows the painting), then `python tools/audit_look_contrast.py --looks <key>
   --check`. Under 4.5:1 on the well, lower `WELL_HI` in the tool or darken the
   well in the painting, never the check. The painting hangs past the panel
   (its socket's crystal, its icicles, its ends): give the look a view in the
   preview tool's `FRAMES` (height, right, up) and the same room in
   `tests/scenarios/theme-picker.lua`'s `ROOM`, measured on the picture, then
   `python tools/make_look_previews.py --check`.
9. **Docs**: the look's own line in CLAUDE.md's file map if what it draws changed.
   Add nothing to CHANGELOG.md in the pilot branch.

## What to check in the renders

`python tools/render_prompt.py --out <dir> --style <key> --key F --size large`,
then Read: `owed`, `calm-owed`, `queue`, `list-above`, `combat`, `success`,
`refused`, `small-size`, `large-size`, `round`, `no-icon`, `tall-narrow`. Look for:
the icon centred in the socket and as large as the look wants; the name starting
inside the well and never under the keycap; the key's letter centred on the
keycap and readable; no step of light or a cut ornament where the end meets the
middle (`zoom` the seam); the ends never stretched (only the middle); the lights
and the moving layers on the painting, not where the old frame had them; the
list's rows clear of what hangs under the bar; a fight greying the painting.
Compare with the old look: `--addon` an export of the commit before
(`git archive HEAD | tar -x -C <dir>`), same arguments.

## The tests to add

In `tests/scenarios/painted.lua`, a copy of scenarios 1, 3, 4 and 6 for the new
look (or turn them into loops over `{ "frost", "<key>" }`): it wears its painting
and none of `paintedHides`; the pieces meet and follow the size; the icon in the
socket, the name in the well, the key on the keycap; a fight and a change of look.
In `tests/mutations/painted.py`, one mutation each that undoes the new look's
`paintedHides` entry for its plate, its `PaintedPlace`'s text start and its
`Tone` line, each proven CAUGHT with `python tools/prove.py --file
tests/mutations/painted.py --jobs 2`. Then the look's own scenario file, the
`painted.lua` file, `hunt38-picker.lua`, `layout.lua` and `menu.lua`, all
`failures: 0`.
