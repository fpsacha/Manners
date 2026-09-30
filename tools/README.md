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
python tools/render_prompt.py --compare before after compare.png
```

`--locale` loads the addon as a client in that language (the mock's
`Mock.locale`), which is how a German or Russian line that runs off the panel
is found without the game. The addon measures its lines to fit them, and the
renderer answers those measurements with the font it draws in, so a line the
addon shrank to fit is drawn fitting. A state can ask for a bright world
behind it (`backdrop = "bright"` in `render_prompt.lua`) where dusk would flatter
the text.

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

## perf_probe.py

How many protected calls a scan makes, where from, and what they cost. Written
after a player said on CurseForge that the addon (ab)uses `pcall` on busy code
paths, so that the answer is a count rather than an opinion either way.

It loads the addon on the mock client the way the test runners do (Lua 5.1
through lupa, `tests/mockapi.lua`, the files `tests/addonfiles.lua` reads from
`Manners.toc`), with `pcall` and `xpcall` replaced by counting versions before
the first file loads, and stands the player in six places, each in a fresh
Lua state:

- **idle** — alone out in the world, nobody targeted, no nameplates
- **city** — a capital: twenty strangers' nameplates, a target, a mouseover
- **dungeon** — a five-player party between pulls, three mobs' nameplates
- **raid** — forty players, ten nameplates, a ready check running
- **citynever** — the city with a never-offer list of `--never` names (fifty)
  that match nobody there, while the city's passers-by are remembered; the run
  fails if nobody is
- **raidgc** — the raid for a mage who has learned Arcane Brilliance (the
  probe's `PROBE_KNOWN`) and carries Arcane Powder, group casts on for two of a
  party missing the buff; the run fails if no group cast forms

Every scan there describes the same crowd: a favour owed arrives once and is
kept inside its window (and the "Let them go after" grace) for the whole run,
and the first login's twenty-second preview of the prompt is ended before the
warm-up. A favour arriving afresh every scan would replay the prompt's shine
on every repaint, which is not what standing in a city costs.

In each it runs a hundred scans (`addon:Tick`, which ends in the prompt's one
repaint, which builds the queue), then a hundred more with `UNIT_AURA` arriving
between them: two hundred for the other people there — in the raid, its forty
group tokens — and fifty for the player. It reports per scan and per event the
`pcall` count, each one charged to the line that made it
(`debug.getinfo(2, "Sl")`) and again, for a `pcall` made inside `ns.safecall`
or `ns.Guard`, to the line that asked for it; the `ns.safecall` and `ns.Guard`
calls; the client's own functions, by name, called from outside the mock
(`GetRaidRosterInfo` given on its own; `issecretvalue` listed but kept out of
the total, since `ns.plain` asks it of every value); the kilobytes allocated
(collector held off, a full collection first) and kept; and `os.clock` time. A
bench of one `pcall`, `safecall` and `Guard` against a direct call turns the
counts into the most that removing them could save.

And the queue each situation builds, as a fingerprint: per entry, in order, the
name, the buff's key, the reason, whether it was measured in range, and the
party a group cast lands on, taken after the warm-up and again after the
counted run. `--compare` prints any difference from the earlier run's and exits
1 on one, so a change that is meant to cost less and do the same is shown
doing the same.

```
python tools/perf_probe.py                                  # this tree
python tools/perf_probe.py --json before.json --text before.txt
python tools/perf_probe.py --addon ../Manners-1.4.0         # another checkout
python tools/perf_probe.py --compare before.json            # before -> after
python tools/perf_probe.py --situations raid,city --top 40
python tools/perf_probe.py --situations citynever --never 200
PROBE_KNOWN=1459,23028 python tools/perf_probe.py --situations dungeon   # spells known, by id
```

`--addon` runs the probe in this tree against the addon and the mock in that
one, so an old version is measured by `git worktree add` or `git archive` into
a scratch folder and nothing copied. It exits non-zero if any of the addon's
guards caught an error, if raidgc formed no group cast or citynever remembered
nobody, or if the count run and the time run built different queues, since a
situation like that is not the one it claims to be.

The situations are in `perf_world.lua`, which the probe takes from its own
tree (never the measured one's) and the budget scenario below loads too. The
unit API is answered from a table of distinct people there, because the shared
mock names every unit the same stranger and says every unit exists; and the
few client globals the mock lacks and the scan reads are added there, each
listed by the report when read ("read but not in the mock"). Every global it
replaces is kept and put back by `world.restore()`, since a scenario shares
its Lua state with the ones after it.

The times are the mock's, whose API is Lua where the game's is C (its
`issecretvalue` too, so `ns.plain` and `ns.safecall` read high), and are for
comparing two versions on one machine. The counts and allocations are the
addon's own. `profile_scan.py` is the other half: time and client API calls
per function, in one worst crowd.

### The pcall budget

`tests/scenarios/perf-budget.lua` holds a scan to what the protection policy
at the top of `Core.lua`'s secret-safe section leaves standing. It stands a
mage in four of the probe's situations through `perf_world.lua`, runs ten
scans to fill the caches and counts fifty, with `pcall` (and `xpcall`)
swapped for a counter around each `addon:Tick`. No addon file keeps a copy of
`pcall` of its own, or the counter could not see it; the first scenario there
checks that. A count under three per scan (the Guards alone make three) fails
as a counter that is not counting, and a count over the ceiling fails with the
measured figure and the five lines charged most.

| situation | before the refactor | after | ceiling |
|---|---:|---:|---:|
| city | 89.3 | 9.3 | 12 |
| raid | 160.9 | 22.2 | 30 |
| citynever (fifty names) | 189.3 | 9.3 | 12 |
| raidgc | 422.9 | 24.2 | 30 |

Each ceiling is about a quarter above what was measured once the refactor
landed, so ordinary work passes and one hot-path safecall put back does not:
`tests/mutations/perf.py` puts the PvP flags back on `safecall` (80 more per
raid scan) and `tests/mutations/perf-budget.py` the proximity ladder's rungs
(18 more per city scan), and both are caught. What is left after the refactor
is the aura reads the client restricts per spell (about two per city scan and
fourteen per raid scan, behind the aura cache), the three Guards, the walk's
own pcall, and a handful of once-per-scan calls (IsResting,
UnitAffectingCombat, IsSpellUsable, the group spell's reagent).

The same file checks that a cast by anybody else costs no Lua at all: the six
`UNIT_SPELLCAST_*` events are registered on a frame of the addon's own for the
player alone (`RegisterUnitEvent`), not through AceEvent.

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
