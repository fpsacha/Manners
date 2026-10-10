# tools

Two kinds of thing. First the tools for working on the addon: running the
suites (`check.py`), making a release (`release.py`), keeping the translations
whole (`locale_todo.py`, `locale_add.py`, with `build_locale.py`,
`check_translation.py` and `locale_keys.py` under them) and adding In character
lines (`add_phrases.py`). Then the generators for the addon's per-flavour
`.toc` files, for the images on the CurseForge listing and in the README, and
for the addon's own icon, and the probes that measure it. Nothing in here
ships: `.pkgmeta` ignores this folder, and the game never loads it. The five
working tools are run by hand; nothing in `tests/` imports them.

They live in the repository rather than on somebody's desktop so the listing can
be rebuilt when the addon changes. The first versions were one-off scripts, which
meant the published images could only ever drift away from the addon.

## check.py

The suites in one command, one line each.

```
python tools/check.py                              # validate, harness, scenarios
python tools/check.py --flavours                   # and each client's own files as that client
python tools/check.py --anchors                    # and every mutation still finds its code
python tools/check.py --flavours --anchors --jobs 3
```

Each step is the existing script, run as it is:

| Step | Runs |
|---|---|
| `validate` | `tests/validate.py` |
| `harness` | `tests/runharness.py` |
| `scenarios` | `tests/runscenarios.py --jobs N`: every scenario, as WoW Forever (camelot), the default client |
| `--flavours` | `tests/runscenarios.py --flavour X --file F`, one step per pair: `era.lua` as vanilla, `tbc.lua` as tbc, `mists.lua` as mists, `mainline.lua` as mainline, and every `tests/scenarios/*-fixes.lua` as each of those four (the `scenarios` step has run them as camelot) |
| `--anchors` | `tests/selftest.py --anchors --jobs N` |

As each step ends it prints `PASS` or `FAIL`, its seconds and its own verdict
line (`RESULT: all checks passed`, `failures: 0`, `errors: 0`). Then, for each
step that failed, the lines of its output that say why (at most 25), and a
last line: `check: all 32 step(s) passed in 432s`, or which failed. For
`validate` the lines are each `== x ==` section that holds a failure, under its
heading; the tables and counts it prints on every run (the five tightest
functions, the version table, the translation counts) are shown only in a
section that failed. It exits 1 if any did. A failed step does not stop the
others. Every step's whole output
is kept in `%TEMP%/manners-check/<checkout>/<step>.txt`, a folder per checkout
so that worktrees checked side by side keep their own (it is emptied at the
start of each run and named on the first line), so a red step can be read
without running it again.

`--jobs N` is how many processes run at once, all steps together; the default
is the cores less two, which stay free. It is passed on as `--jobs`, so
`MANNERS_SCENARIO_JOBS` (which `runscenarios.py` reads when it gets no
`--jobs`) does not change it. `validate` and `harness` go first, then
`scenarios` on all N, then the rest N at a time. Pass `--jobs 3` when other
work is running on the machine. With `--flavours
--anchors --jobs 3`, while three other suites ran on the same 16 cores, the
whole thing took a little over seven minutes, six of them the `scenarios`
step; the 28 flavour steps take 1 to 26 seconds each, and `--anchors` under one.

Two things it is not. It is not the full mutation run: `python
tests/selftest.py` is still what a change is finished against and what is run
before a release (RELEASING.md); `--anchors` only proves every mutation still
finds the text it changes. And `--flavours` is not the whole suite as another
client: that is `python tests/runscenarios.py --flavour X`, a diagnostic whose
reds are mostly fixtures written for Camelot, and `--baseline` there prints
only the reds that are not in `tests/baselines/X.txt` (`tests/README.md`). The
files `--flavours` runs are the ones written for each client, and they are
green.

## release.py

RELEASING.md's "Each release", run in order, waiting where it says to wait.

```
python tools/release.py 1.7.4 --dry-run    # every check, every command it would run; changes nothing
python tools/release.py 1.7.4
python tools/release.py 1.8.0-beta.1 --coauthor "Claude Opus 5.5 <noreply@anthropic.com>"
```

Before it: write the notes under `## Unreleased` at the top of `CHANGELOG.md`,
and run the full `python tests/selftest.py` by hand. This never runs the full
mutation selftest -- it is long, and its verdict is read by a person -- and
says so when it starts.

Preflight, read-only; nothing changes unless every check passes:

- the version is `X.Y.Z`, `X.Y.Z-alpha.N` or `X.Y.Z-beta.N` (what
  `tests/setversion.py` takes) and newer than `Manners.toc`'s;
- `CHANGELOG.md`'s top section is `## Unreleased`, with notes under it;
- `gh` is installed and logged in;
- on master, with a clean tree: nothing modified and nothing untracked;
- origin's master is already in this branch (`git ls-remote`, no fetch);
- the tag `vX.Y.Z` exists neither here nor on origin;
- `python tools/check.py --anchors` passes (its lines are shown as it runs; it
  takes all but two cores, its default).

Then, stopping at the first thing that fails:

1. `python tests/setversion.py X.Y.Z`, then `python tests/validate.py`;
2. `git commit -a -m "Manners X.Y.Z"`, with `-m "Co-Authored-By: ..."` when
   `--coauthor` or the `MANNERS_COAUTHOR` environment variable gives one (the
   whole line, or just the name and address);
3. `git push origin master`;
4. waits for `ci.yml`'s run of that commit (`gh run watch --exit-status`);
5. `git tag -a vX.Y.Z -m "Manners X.Y.Z"`;
6. `git push origin vX.Y.Z`;
7. waits for `release.yml`'s run of the tag;
8. prints, from that run's log (`gh run view --log`, where the secrets are
   masked), which destinations were configured, the packager's
   `Game version:` line, and what each upload answered:

```
    CurseForge: id 1705364, token set
    Wago: id rNkgzlNa, token set
    warning: WoWInterface: no token and no X-WoWI-ID -- skipped
    Build type: multi-version non-alpha non-debug
    Game version: 12.1.0, 5.5.4, 2.5.6, 1.60.1, 1.15.9
    ...
    Uploading Manners-v1.7.3.zip (12.1.0,5.5.4,2.5.6,1.60.1,1.15.9 release) to https://wow.curseforge.com/projects/1705364 -> Success!
    Uploading Manners-v1.7.3.zip (12.1.0,5.5.4,2.5.6,1.60.1,1.15.9 release) to https://addons.wago.io/addons/rNkgzlNa -> Success!
    Creating GitHub release: https://github.com/fpsacha/Manners/releases/tag/v1.7.3
```

The `Game version:` line should name all five clients; see RELEASING.md's
"Game version" for what to do on the file page when it does not. A release run
that stopped before the packager (in its test job, say) has none of the
packager's lines, and the tool says so: the log has no `Package and publish`
step, so nothing was uploaded.

`gh run watch` redraws its table every few seconds, so its output goes to
`%TEMP%/manners-release-watch-<run>.txt` and the tool prints one line a
minute; on a red run it prints the end of that file, each job and step that
did not pass (`failed: images / The listing images still draw from the addon`)
and how to read its log (`gh run view <run> --log-failed`). CI's run is the
whole of `ci.yml`, so a red `images` job stops a release as a red `tests` job
does.

When it stops, it says where that leaves the release and what to do next. It
never deletes a tag or undoes a commit: a red CI run leaves master pushed and
nothing tagged -- fix, commit, push, and run it again with the same version,
which now finds the top section already named `X.Y.Z` (that counts as the
notes), sets nothing new, has nothing to commit, and goes on from the wait. A
red release build prints RELEASING.md's two commands for taking the tag off,
for you to run if nothing was uploaded.

`--dry-run` makes every preflight check -- all of them, rather than stopping at
the first -- prints each step's commands as `would run: ...`, changes nothing
(no file, commit, push or tag; `git status` stays clean), and exits 1 if a
real run would stop at a check.

## locale_todo.py

What every language still lacks, as files ready for a translator.

```
python tools/locale_todo.py               # into %TEMP%/manners-locale-todo/<checkout>
python tools/locale_todo.py --out todo
```

For each locale (`Locales/<code>.lua`, and any language `build_locale.py`
knows that has no file yet) it writes `DIR/<code>.todo.json`: a JSON object
of every English key the code asks for (`locale_keys.py`) that the locale does
not translate, each mapped to `""`, in the order the keys first appear in the
code. A translation set to an empty string counts as missing. A locale with
nothing missing gets no file, and one left from an earlier run is removed, so
the folder always says what is left. It prints one line per locale with its
count, and the total:

```
4232 strings to translate; writing to C:\...\Temp\manners-locale-todo\71b3f5e0
  deDE     16 missing -> deDE.todo.json
  ...
128 missing in all, across 8 of 8 locales
```

Fill in the values -- a translator writes the language, never Lua -- and give
the file to `locale_add.py`. The `{name}`, `%s` and `|cff...|r` in a key have
to come through unchanged, as `check_translation.py` requires.

## locale_add.py

Merges translations into `Locales/<code>.lua` without losing a line.

```
python tools/locale_add.py deDE todo/deDE.todo.json [more.json ...]
```

Each file maps English keys to their translation; later files win where two
translate the same key. A value left empty is skipped: it never takes the
place of a translation, whether an earlier file gives one or the locale has
one, so a todo file translated in part can be given as it is, in any order
with other files, and the keys no file translates are counted (`left empty`).
A file that cannot be read or is not a JSON object is named, with why, and
nothing is written. In order, and if any step objects the files are left as
they were:

1. the current file is read back as the game reads it
   (`locale_keys.load_locale`);
2. the new translations go through `check_translation.py`'s check -- a key the
   code does not ask for, a value that is not a string, or a `%s`, `{token}` or
   `|escape` that differs from the English stops it, with each one listed under
   the file it came from;
3. old and new are merged, the new winning, and the file is rebuilt by
   `build_locale.py` (so the escaping is done there, once);
4. every line of the old file has to be in the new one, except the lines of the
   keys it changed. A rebuild drops a translation the code no longer asks for,
   a comment written by hand and a line escaped some other way; if it would,
   the old file and `Locales/Locales.xml` are put back and the lines are listed,
   to be dealt with by hand;
5. the new file is read back and has to hold exactly what was merged.

```
deDE: 16 added, 0 changed, 0 already so; 4232 of 4232 keys translated
```

The count after the semicolon is the keys the file now translates against the
keys the code asks for; `still missing` follows when they differ. Run
`tools/check.py` after, as after any change.

## add_phrases.py

Adds In character lines to `Phrases.lua`, pool by pool.

```
python tools/add_phrases.py pools.json
```

`pools.json` is a list of `{"pool": ..., "lines": [...]}`, the pool named by its
path in Phrases.lua's tables:

```json
[
 {"pool": "RACE.dwarf.thanks", "lines": ["Much obliged, {name}. Ale's on me."]},
 {"pool": "CLASS.MONK.offer", "lines": ["...", "...", "..."]},
 {"pool": "SPELL.skyfury", "lines": ["...", "...", "..."]},
 {"pool": "GIFT.skyfury", "lines": ["...", "..."]},
 {"pool": "SAME.EVOKER", "lines": ["...", "...", "..."]}
]
```

`RACE.<family>.<kind>`, `CLASS.<CLASS>.<kind>`, `SPELL.<key>`, `GIFT.<key>`
and `SAME.<CLASS>` (and `RACE.<family>.outsider.<moment>` for a people with a
city in `RP.HOME`) are the shapes it creates. Any other pool that exists
already -- `TRADE`, `KIN`, `FACTION.Horde.offer`, `GENERAL.thanks`,
`PLACE.city`, `TARGET.MAGE`, `ONTO.intellect.ROGUE` -- can be added to;
`RP.LEGACY` never is.

A pool that exists gets the lines after its last one, so its first lines, the
phrase box's examples, stay first. One that does not is made at the end of the
table it belongs in, a new class's table with it, and needs as many lines as
`tests/scenarios/rp.lua` asks: `RP.SPREAD` (three) for most, two for a `GIFT`
pool or a people's outsider lines. Its name is checked the way rp.lua checks
where lines are filed: a family `RP.FAMILY` maps a race to, a class token, the
key of a buff some client's set in `Buffs.lua` gives to others (or, for
`GIFT`, a favour in `FAVOUR_KEY`), and a kind the picking reads. City and
outsider lines, in a new pool or an old one, are taken only for a people
`RP.HOME` gives a city, as the comment above `RP.RACE` says: a city's lines are
said only there, and the picking adds outsider lines for anybody who is not
kin and not at home -- for a people with no home, everybody, everywhere, which
rp.lua catches as a dwarf thanking in lines that are not a dwarf's thanks.

A file of pools that cannot be read or is not JSON is named, with why, and
nothing is written.

Every line is checked by rp.lua's rules before anything is written, and if any
breaks one, nothing is, and each is listed with its reason:

- over 85 bytes once `{name}` is "Bartholomewz" and `{buff}` and `{gift}` are
  "Power Word: Fortitude";
- `|`, `[`, `]`, a newline or another control character, a leading `/`, or
  nothing at all (not safe in a macro);
- a token other than `{name}`, `{buff}` and `{gift}`, or `{gift}` outside
  `TRADE` and `GIFT`, the only pools it is filled in;
- the word "buff" outside a token;
- the same as a line already in the file (outside `RP.LEGACY`) or another new
  line -- or the same letters, once tokens, spaces and punctuation are out and
  case is ignored.

Quotes and backslashes are escaped, and each line is written `L["..."],`. The
file is not searched for fixed anchors: its comments and strings are masked,
the `RP.<NAME> = { ... }` tables are walked brace by brace, and each nested
table is known by its key. The result is read back -- every new line in its
pool -- and compiled with Lua 5.1 before it is written.

Every new line is a new translation key, so afterwards `tests/validate.py`
reports it `MISSING` in every locale, and a new pool fails rp.lua's "every
language keeps a line for every moment" until its lines are translated. Start
to finish:

```
python tools/add_phrases.py pools.json
python tools/locale_todo.py --out todo
    (translate todo/<code>.todo.json, one per language)
python tools/locale_add.py deDE todo/deDE.todo.json      # and each other language
python tests/runscenarios.py --file rp.lua
python tools/check.py
```

What rp.lua checks and this cannot is left to it: a class that gives buffs
needs all four kinds, thanks, asked, offer and group.

## maketocs.py

Writes one `Manners_<Flavour>.toc` from `Manners.toc` for each entry in its
`FLAVOURS` table. Every live client ships since 1.7.0, so that is five files:
`Manners_Camelot.toc` (WoW Forever), `Manners_Vanilla.toc` (Classic Era),
`Manners_TBC.toc` (Burning Crusade Anniversary), `Manners_Mists.toc` (Mists
Classic) and `Manners_Mainline.toc` (retail).

Its `STAGED` table is the step before shipping, empty while every client
ships: a flavour listed there is written to `tools/tocs/`, kept current and
checked like the shipped ones, and goes nowhere. Not beside `Manners.toc`,
because the BigWigs packager reads every `Manners_<Flavour>.toc` in the
checkout's top folder -- whatever `.pkgmeta` leaves out of the zip -- and tags
the upload with that client's game version; `tools/` is ignored by `.pkgmeta`,
and the packager never looks in it. To try a staged client, copy its file next
to `Manners.toc` in your own `Interface/AddOns/Manners`. `tests/validate.py`
fails if a toc in the top folder is not in `FLAVOURS`, or if `.pkgmeta` stops
ignoring the staging folder.

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
Chinese panel: Microsoft YaHei on Windows, `fonts-noto-cjk` on Linux. The
renderers (`render_prompt.py`, `render_ledger.py`, `render_options.py`) need
lupa, Pillow and numpy and nothing else.

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
`Mock.locale`), which is how a German or French line that runs off the panel
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
and switched off too. Every state is drawn in English, German and French, and
the addon measures its text with the renderer's font, so a label sized to its
text is sized to what the picture draws. Strings the window cuts are listed on
stdout.

```
python tools/render_ledger.py --out renders                       # every state, en/de/fr
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

## render_options.py

The same for the options window, one picture a page, and a check of what it
draws. `render_options.lua` loads the addon as a class in a language, opens the
window on each page with `ns.OpenOptions(pageId)` and draws `ns.OptionsWindow`
(820 x 600) with a margin of screen round it, framed wider if anything of the
window strays off it. The pages come in sidebar order from
`ns.WindowLayout.groups`.

```
python tools/render_options.py --out renders                     # every page, a mage, English
python tools/render_options.py --class PRIEST --locale deDE --pages who,when
python tools/render_options.py --state combat --state search whisper --pages who
python tools/render_options.py --check                           # exit 1 on any fault
python tools/render_options.py --demo                            # prove the drawing and the checks
```

Each class is drawn knowing what `tests/scenarios/window-classes.lua` gives it
for IA 1.11's table (a priest its three buffs, a hunter two aspects, a mage
Arcane Intellect and Frost Armor), and the buffs of its own IA 1.11 lists
under Myself (a priest's Inner Fire, a paladin's Devotion Aura and Righteous
Fury, a hunter's Trueshot Aura, and Track Beasts on the hunter's minimap
tracking list), since the mock on its own knows Arcane Intellect and nothing
else. The client's key bindings page is there (`Settings.OpenToCategory` and
`Settings.KEYBINDINGS_CATEGORY_ID`), so Start here shows Open key bindings, and
the clock answers `date("%H:%M")` in hours and minutes, as a snooze's end is
shown. The Profiles page gets AceDBOptions' own controls, built as the library
builds them, in English, over the mock's database: the mock's stand-in for the
library has only its opening paragraph.

`--state` puts the window into a state through the addon's own entry points,
and can be given more than once:

| State | How |
|---|---|
| `unlocked` | the prompt unlocked before the window opens |
| `snoozed` | `ns.StartSnooze(15)` before it opens |
| `combat` | a fight starts once it is open, in the client's order: `PLAYER_REGEN_DISABLED` to Core and to every frame registered for it while lockdown has not begun, then lockdown and the next frame's timers |
| `folds-open` | every folded section in the layout written open in `ns.db.global.window.open`, the window shut and opened again |
| `scrolled` | the page scrolled to its end (`ns.WindowUI.ScrollTo`), for what a long page holds below the first screen |
| `modal` | the footer's "Put these back to default" pressed; on a page without one, `ns.WindowWidgets.Modal` opened with its words |
| `search WORDS` | the words typed into the sidebar's search box (`window.search`, else the topmost edit box in the sidebar), with the 0.15 s wait let run |

Before the picture is taken, every shown frame of the window gets a second of
`OnUpdate` with the clock and the timers moving, as the client would give it,
so a fade the window drives itself has finished, and one-shot animations are
settled as in `render_prompt.py`.

On top of what the prompt needs, this draws an edit box's own text (its font,
insets and justification, wrapped when it is multi-line, cut at its box), a
slider's thumb where its value puts it, a scroll frame's child moved by its
scroll and cut at its edges, `SetClipsChildren`, the game's font objects by
name (`GameFontNormal` gold, `GameFontHighlight` white, `GameFontDisable` grey;
12, with `Large` 16 and `Small` 10; each with its one-pixel shadow), alpha
passed down the tree, hidden frames left out, and text that wraps. The client's
own art files are drawn as stand-ins rather than flat tiles: an icon from
`Interface\Icons` as a tile with the initials of its name, a check box's tick,
arrows, plus and minus, the close X (a `UIPanelCloseButton` is 24 square), the
loot window's Pass cross and the round portrait mask (white, for its colour),
each seen through its `SetTexCoord`, so a fold's arrow turned to point down
while it is open is drawn pointing down.

The addon is told how its text measures by the same font and the same line
breaking the picture is drawn with: `tests/frametree.lua` answers
`GetStringWidth`, `GetStringHeight` and `GetNumLines` through `FT.measure` and
`FT.wrap`, which this installs, and works out the width a string wraps at from
its anchors as the renderer does. So a row the window laid out to fit is drawn
fitting, and one that does not fit shows. A multi-line edit box grows to hold
its text, as the client's does, so the scroll frame round it has something to
scroll.

Chinese and Korean (`--locale zhCN`, `zhTW`, `koKR`) are drawn and measured in
a face that has their script (Microsoft YaHei, JhengHei, Malgun Gothic, or
Noto Sans CJK), set before anything is measured: Candara has none of it, and a
page measured in boxes is laid out wrong.

`--check` reads the drawn tree of the window for five faults, lists each with
the text it concerns, and exits 1 if there is any (2 if a page could not be
drawn at all):

- **(a) text cut short**: wider than its width with word wrap off; a single
  word wider than its width when it wraps; or more wrapped lines than its
  height or `SetMaxLines` leaves room for.
- **(b) rows overlapping**: in every frame of the window, the strings and
  child frames it holds compared two by two, each child frame by what it shows
  that can collide (its text and its controls, not its backgrounds, and only
  as much of a scroll frame as is inside it). A frame lifted above its
  siblings -- another strata, or a frame level set higher -- is meant to cover
  them (a menu, the search results, the confirm box), so it is left out of its
  parent's comparison, and checked within.
- **(c) outside**: a control (button, edit box, slider) or a line of text
  outside the window; inside a scroll frame, one cut by its left or right edge
  or lying past the end of the scroll child, where no scrolling reaches it;
  inside a `SetClipsChildren` frame, one not wholly inside it.
- **(d) contrast** under 4.5:1 against what is drawn under the text, worked out
  as in `tests/scenarios/readable-*.lua`. The window is drawn once over a dusky
  world and once over snow, each colour the text carries is laid over each
  pixel under its lines at its alpha, and the ratio below which the worst
  twentieth of those pixels fall is the one held to 4.5. Greyed-out controls
  are held to it too: the game's grey passes on a dark panel.
- **(e) text the picture cannot be trusted for**: a character the face it is
  drawn in does not have (read from the face's own character map, with
  fontTools), or bytes that are not UTF-8. Those would stop the run at the
  first page that had one; instead they are drawn as U+FFFD, the region is
  named, and the run goes on to the next page.

`--demo` does not load the addon. `render_options.lua` builds a window of every
kind of frame the options window may use -- the frame types, font objects,
colour textures, gradients, art, an edit box, a multi-line edit box scrolled in
its own scroll frame, a slider, a number box, a clipping frame, a hidden row
and a faded one -- and draws it three ways: clean, clean with its content
scrolled to the end, and with one fault planted for each check, tagged `[a1]`,
`[b1]` and so on in its text (`[e1]` is Chinese in a Latin face, `[e2]` a
character cut in half). It exits 1 unless the clean ones pass every check
and the faults are found exactly. Run it after changing the renderer or
`tests/frametree.lua`.

Where the client's behaviour is not known for certain, these are the readings
taken, the same in the recorder and the renderer: a scroll child hangs from its
scroll frame's top left whatever it is anchored to, as wide as it is set (else
as the scroll frame) and as tall as it is set; a thumb is 16 along the slider
unless sized, and as thick as the slider; a vertical slider's minimum is at the
top; of `SetFontObject` and `SetTextColor`, the later decides the colour; a
frame moved to a new parent sits one level above it; a single-line edit box
shows its text from the start. A region hung by an edge and a centre on one
axis is drawn from the edge, as `render_prompt.py` draws it, and a note says
so.

## make-glow.py

`Textures/Glow.tga` and `Textures/GlowRound.tga`, the soft glows the prompt
draws round its spell icon. Like `Manners64.tga` they ship in the zip. Needs
Pillow; deterministic.

`Glow.tga` is light falling off in every direction from its centre, and
`Prompt/Prompt.lua` cuts it into eight pieces round a square icon: the quarters are
the corners and a line through the middle is each side, so every join has the
same brightness on both sides of it. `GlowRound.tga` is a ring for the rounded
icon; `RING_AT` in the script and `GLOW_RING_AT` in `Prompt/Prompt.lua` say where its
rim is and have to agree. Both are white with the shape in the alpha, and the
prompt colours them.

## make-icon.py

`icon-512.png` (the CurseForge avatar), `icon-64.png`, and `icon-check.png`,
which is just the two sizes side by side so the small one can be judged at the
size it is actually seen.

It also writes `Textures/Manners64.tga`, which lives outside this folder because
it is the one thing these tools make that ships in the zip: the
game cannot load a PNG, and this is the icon in the addon list (`IconTexture` in
`Manners.toc`) and on the minimap button (`ICON` in `Options/Launcher.lua`).

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
- **raidgc** — the raid for a mage who has learned Arcane Brilliance (spells
  1459 and 23028, as `PROBE_KNOWN` would name them) and carries Arcane Powder,
  group casts on for two of a party missing the buff; the run fails if no group
  cast forms

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
python tools/lua51_limits.py Core.lua Queue.lua Prompt/*.lua Options/*.lua   # the twenty tightest
```

`tests/validate.py` uses it to fail any function in a shipped file over 55
upvalues or 190 active locals, and `tests/selftest.py` uses the same parse to
find which function a line of a scenario file sits in.
