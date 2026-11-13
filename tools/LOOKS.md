# Building a look

A look is how the prompt is drawn: `Looks/<Name>.lua`, its art in
`Textures/<Name>/`, and the generator that writes that art,
`tools/make_<name>_textures.py`. `Looks/Looks.lua` documents the interface a
look answers (Build, Apply, Hide, PaintReason, Attention, Flourish, ...) and
the kit it is handed. This file is the recipe and the rules of taste.

## What the author asks of a look

- **It comes from Warcraft.** Name the source in the file's header and in the
  changelog: a class, a people, a place, a piece of the game's own interface.
  A player should recognise it. Lightbringer is the Silver Hand's plate and
  the paladin's sun; Glass is the action bar of 2004, gryphons and all.
- **It is bold.** Art with relief and material, light that moves, a prompt
  that is alive at rest. "Careful" was judged "pretty good, can you make it
  better". When one of the project's own rules for looks is in the way, lift
  it for that look by name (below) rather than ship the tamer version.
- **It is its own.** Not another dark card, not another medallion on a
  banner. Look at the picker (`python tools/render_options.py --pages
  appearance`) before deciding a shape.
- **It reads.** Words in a display face only where they are large: Morpheus
  draws its small letters as hair-thin capitals, and a reason line set in it
  could not be read in the game (1.11.18, Ribbon). The renderer's stand-in
  fonts are bolder than the game's, so a picture is no proof of legibility.

## The tools

| Tool | For |
|---|---|
| `tools/materials.py` | height field to lit material: `shade(material, height, alpha, seed, tpu)`, the SDF helpers, `save` (32-bit TGA, powers of two up to 256) |
| `tools/figures.py` | a hero piece from drawn outlines: `curve`, `blade`, `Figure.part` (rolled relief), `Figure.facet` (cut relief, a ridge down a feather; needs scipy), `cut`, `line` |
| `Looks/Flow.lua` | art that moves by its texture coordinates: `flow:Scroll(tex, du, dv, uSpan, vSpan, turn)` for a REPEAT texture (lava, caustics, a border run round a box with `turn`), `flow:Sheet(tex, cols, rows, frames, fps, loop)` for a drawn animation. The one OnUpdate a look may run |
| `tools/render_prompt.py` | the prompt as a picture: `--style KEY --states owed,stranger,queue,success,refused --at T --size large --out DIR` |
| `tools/look_gif.py` | an animation as a GIF: `STYLE STATE OUT.gif [--start --end --step --box]`, or `--all STYLE DIR`. Look at the frames: a GIF you have not looked at proves nothing |
| `tools/make_look_previews.py` | the picker's cards; run it after any change to a look or to a shipped texture |

The renderer understates additive light: the game draws ADD far brighter. Keep
ADD for flashes under 0.6 s; draw what rests BLEND.

## Named exemptions

Shared scenarios hold every look to rules written for quieter looks. A look
that breaks one on purpose says so in a field the scenario reads:

- `look.idle` (or a dressing's `dress.idle`): the animation groups that loop
  with nobody owed. `hunt35-effects.lua` and `look.lua` let these through.
- `look.skyward`: scaled lights allowed to leave the panel or cross the text
  (`hunt37-effects.lua`).
- A dressing's `outside`: art that stands outside the panel (Glass's gryphons).

Stop every loop on Calm (`kit.FullEffects()` false), in a fight, and when the
prompt is down. Flow handles are not animation groups: stop them yourself.

## The checklist for a new look `<key>`

1. `tools/make_<key>_textures.py` (model: `make_lightbringer_textures.py`,
   `make_glass_textures.py`), writing `Textures/<Key>/`. Deterministic seeds.
2. `Looks/<Key>.lua` (model: `Lightbringer.lua` for a look, `Glass.lua` for a
   dressing over a built-in one), registered with `ns.Looks.Register`, with
   `name`, `title`, `description` (all `L["..."]`), `order`.
3. `Manners.toc`: the file after the other looks, then `python
   tools/maketocs.py`.
4. The strings in all eight locales: `python tools/locale_todo.py --out DIR`,
   translate, `python tools/locale_add.py <code> <file>` (CLAUDE.md,
   "Translations").
5. `tests/scenarios/look-<key>.lua` and `tests/mutations/look-<key>.py` (model:
   `look-lightbringer.*`, `look-glass.*`): what this look promises beyond what
   every look does. Every scenario name starts `look-<key>:`.
6. The shared lists that name every look: `tests/scenarios/looks.lua`,
   `hunt35-effects.lua`, `hunt37-effects.lua`, `hunt38-picker.lua`,
   `hunt38-shared.lua`, `hunt40-layout.lua`, `perf-budget.lua`,
   `options-appearance.lua`, `selftest-launch.lua` (its count of cards),
   `tools/make-screenshots.py`; `Looks.roundAlways` in `Looks/Looks.lua` when
   the look cuts its icon round whatever the switch says.
7. `python tools/make_look_previews.py`.
8. Docs: `CHANGELOG.md` under `## Unreleased` (for players, naming the Warcraft
   source), the README's list of looks, `STATUS.md` (what only the game can
   say), `CLAUDE.md`'s file map, `tools/README.md` (the generator), the
   listings in `.github/` (the count of looks and the new one's line).
9. Checks, sparing the machine (`--jobs 2`, one suite at a time): the look's
   own scenario file, then `python tools/check.py --lint --flavours --anchors
   --jobs 2`, then `python tests/selftest.py --only "look-<key>" --jobs 2`.
10. GIFs of the five moments for the author: `python tools/look_gif.py --all
    <key> DIR`.

Removing a look: give it `fallback = "<another key>"` in the registry rather
than deleting its key (a saved `style` must still draw something), take its
file and textures out, and its card goes with it.
