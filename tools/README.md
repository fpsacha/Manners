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

`make-icon.py` needs [Pillow](https://pypi.org/project/Pillow/).
`make-screenshots.py` draws with the renderers below, so it needs what they
need -- lupa, Pillow and numpy -- and a face with Chinese in it for the
Chinese panel: Microsoft YaHei on Windows, `fonts-noto-cjk` on Linux.

```
python -m pip install Pillow numpy lupa
python tools/make-screenshots.py
python tools/make-icon.py
```

Output lands in `.github/media/`. Both are deterministic: running them without
changing anything rewrites the same bytes, so `git status` staying clean is the
check that nothing drifted.

## make-screenshots.py

The listing images for CurseForge, Wago and the README, all 1280 wide:

| File | Shows |
|---|---|
| `manners-prompt.png` | the prompt for somebody who buffed you, glowing |
| `manners-reasons.png` | the five reasons somebody is offered, each in its colour, in the order they rank |
| `manners-ledger.png` | the favour ledger with a day of ordinary play in it |
| `manners-languages.png` | the prompt and its list in German, French and Simplified Chinese |
| `manners-palette.png` | the standard reason colours beside the colour-blind set |

These are **renders of the addon, not captures from the game**, and nothing
about the prompt or the ledger is drawn in this script. It adds listing states
to the lists in `render_prompt.lua` and `render_ledger.lua` at run time, which
put the addon into each scene through its own entry points (a debt, a line in
/say, a party token, the ledger's Received and Settled), draws them with
`render_prompt.py` and `render_ledger.py`, and lays the result over a painted
dusk. When the addon's look changes, re-run this and commit the images.

Two things are its own. The spell icons are painted emblems rather than the
renderers' initials -- Blizzard's icons are not ours to ship, and Arcane
Intellect's initials read as "AI" -- and the backdrop and captions are painted
here.

`--strict` writes nothing if any picture would show something other than what
it claims:

- a state the addon cannot build, or one that raised a guarded error;
- the wrong person or the wrong reason on top of the prompt;
- a ledger row the queue disagrees with -- a buff given to a class it would
  never offer one to, or a favour called beyond anything you cast when it is
  not;
- a line the client would cut with an ellipsis;
- a translated line still in English;
- a character the face would draw as a box, or no TrueType face at all.

Without `--strict` the same problems are printed and the images are written
anyway, so a local run still shows what went wrong. CI runs it strictly, and
shows it refusing an addon whose German was emptied.

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
python tools/render_prompt.py --locale deDE --out de         # as a German client
python tools/render_prompt.py --style arcane --key F --out arcane   # every state in a look
python tools/render_prompt.py --compare before after compare.png
```

`--style` draws every state in that look (a state that names its own look,
such as `framed`, keeps it), and `--key` binds that key to the prompt first,
which the looks that show the key on the panel need. The `arcane-*` states
draw Arcane as a player who picks it sees it, with a key bound and the
favour's clock part-run. Each picture is taken `at` seconds after its state
settles, with the one-shot animations that have run out by then finished the
way the client finishes them, so a fight's dim is drawn as dim as it is.

`--locale` loads the addon as a client in that language (the mock's
`Mock.locale`), which is how a German or Russian line that runs off the panel
is found without the game. The addon measures its lines to fit them, and the
renderer answers those measurements with the font it draws in, so a line the
addon shrank to fit is drawn fitting. A state can ask for a bright world
behind it (`backdrop = "bright"` in `render_prompt.lua`) where dusk would flatter
the text, and a view lifted (`lift`) when something tall hangs over the panel.
Each picture is taken `at` seconds after the state's last step: the mock clock
is moved there and every one-shot animation that has finished by then is
finished, so a fade that ended shows what it left, not its last frame.

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

## render_ledger.py

The same for the favour ledger window (`/manners ledger`), importing
`render_prompt.py`'s drawing code. `render_ledger.lua` fills the ledger through
`Ledger.lua`'s own entry points with days of play -- favours owed, returned and
let go for each reason, gifts to the group and to strangers, a long name, a name
with a realm, enough rows to scroll -- and opens the window on each tab, empty
and switched off too. Every state is drawn in English, German and Russian, and
the addon measures its text with the renderer's font, so a label sized to its
text is sized to what the picture draws. Strings the window cuts are listed on
stdout.

```
python tools/render_ledger.py --out renders                       # every state, en/de/ru
python tools/render_ledger.py --states all,empty --locales deDE
python tools/render_ledger.py --compare before after compare.png
```

Where a region is hung by an edge and a centre on one axis, this one sizes it
from both points rather than drawing it from the edge. That is the reading
`render_prompt.py` leaves open, and it is not known to be the client's: the
prompt and addons known to work on this client use the pairing without
trouble. It is taken on purpose, so that a ledger string leaning on the
unsettled case shows as out of place; the window hangs every string by two
points on one edge, which lands the same either way.

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

## profile_scan.py

What the scan costs in a crowd. It loads the addon on the mock client from
`tests/` (Lua 5.1, through lupa), stands the player in the worst place there is
— forty nameplates, a forty-player raid, forty buffs on the player, a hundred
favours outstanding, a two-hundred-name never-offer list, a hundred friends —
and reports, per call of `BuildQueue`, `Tick`, the prompt's repaint, the
player's own aura scan and another unit's `UNIT_AURA`: microseconds, and
kilobytes allocated. Then, per tick, how often each client API was asked and
which of the addon's functions ran most often, by file.

```
python tools/profile_scan.py
python tools/profile_scan.py --class PRIEST --owed 5 --friends isfriend
python tools/profile_scan.py --owed 5 --never 0   # what most players stand in
```

The never-offer list is most of what the worst case costs, and most players
have none, so measure `--never 0` as well before claiming a gain for everybody.

The times are the mock's, whose API is Lua where the game's is C, so they are
for comparing two versions of the addon on one machine; the call counts and the
allocations carry over. The crowd itself is in `profile_scan.lua`. To compare
against an older version, `git archive` it into a scratch folder, copy both
`profile_scan` files into its `tools/`, and run it there.

## lua51_limits.py

How full each function is against Lua 5.1's two limits: 60 upvalues, and 200
locals active at once. The game runs 5.1, and a file with one function past
either does not compile, so the addon does not load -- 1.0.0-beta.6 shipped
that way with `Prompt:Create()` at 69 upvalues. It compiles each file with
`lupa.lua51`, reads the chunk `string.dump` produces, and takes every
function's upvalue count and the deepest overlap of its locals' live ranges
straight from the compiler's own bookkeeping.

```
python tools/lua51_limits.py Core.lua Queue.lua Prompt.lua Options.lua   # the twenty tightest
```

`tests/validate.py` uses it to fail any function in a shipped file over 55
upvalues or 190 active locals, and `tests/selftest.py` uses the same parse to
find which function a line of a scenario file sits in.
