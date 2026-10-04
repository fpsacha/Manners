# Tests

No part of this can talk to a running client, so these check the things that
can be checked from outside it. Between them they catch every fault class that
actually cost time building this addon — none of which a syntax check can see.

Run them from the project root. Every path is resolved relative to the test
file rather than named outright — hardcoded ones passed here and failed the
first time CI ran them on a machine that was not this one.

## `runharness.py` — load the addon for real

Loads `harness.lua`, a mock WoW API, then loads every addon file `Manners.toc`
names, in its order (`tests/addonfiles.lua` reads the list), and drives
the main paths: `OnInitialize`, `OnEnable`, `PLAYER_ENTERING_WORLD`,
`BuildQueue`, `Tick`, the aura handler that stands in for the combat log this
client does not have, `ScanOwnBuffs`, `ApplyStyle`, `Refresh`, and the slash
commands.

Catches:

- **calls to names that do not exist** — a function local to one file
  (`Queue.lua`, say) called from another that took no copy of it off `ns` is
  a nil global, and throws only when that line runs
- **handlers registered for events this client lacks** — the mock knows which
  events exist, and registering anything else fails. This is what stopped the
  scanner from ever starting.
- **misspelled API calls**
- anything the addon's own guards caught while running

```
python tests/runharness.py
```

## `selftest.py` — check the suites can still fail

Reintroduces each fault the suites exist to catch — over six hundred of them,
in `selftest.py` and `tests/mutations/<topic>.py` — confirms the check each one
names is among what fails, and restores the file. A test that passes vacuously
is worse than no test.

```
python tests/selftest.py            # the full run: about two minutes
python tests/selftest.py --anchors  # only that every mutation still finds its text: seconds
python tests/selftest.py --plan     # which scenarios would judge each mutation, then stop
python tests/selftest.py --whole    # every mutation on the whole suite, as it used to be
python tests/selftest.py --jobs 4   # fewer at once (default: one per core)
python tests/selftest.py --changed  # only the mutations of files that differ from master
python tests/selftest.py --changed v1.5.4  # ... or from any commit or tag
```

It used to take 25 minutes here and over two hours on GitHub's runner. What
makes it fast, and why none of it loosens the rule:

- **Parallel, in copies.** Mutations edit files in place, so each worker gets
  its own copy of the tree in a temporary folder, and never two mutations run
  in one directory. After each one, its file must come back byte for byte, or
  it is reported NOT RESTORED. The real tree is never edited; the "after
  restore" line checks it is still what the baseline ran.
- **Only the scenarios the check lives in.** A mutation judged by
  `runscenarios.py` runs only the scenarios its `expect` can come from. The
  scenario files are run once under a line trace (`runscenarios.py --trace`,
  split across the cores), which records the scenario running on each line.
  `expect` is found in the scenario files — as written, joined across `..`,
  as the tail of a scenario's name before its colon, or failing those as the
  string literal sharing the most words with it — and the lines around each
  place it is found name the scenarios. Text that cannot be found anywhere (the
  addon's own error text, say) is judged on the whole suite.
- **Checked both ways.** A narrowed selection is first run on the clean tree
  and must come back green, or a failure of its own would count as the
  mutation caught; if it is red, every scenario in its files is tried, then
  the whole suite. A narrowed run that comes back MISSED or WRONG CHECK is
  judged again on the whole suite before anything is reported. The summary
  lists both, since each is a mutation the trace sent to the wrong place.
- **The locales once.** `tests/scenarios/locales.lua` drives the addon in nine
  client locales. The baseline runs it; a mutation runs it only when the
  mutation is in `Locales/` or its text is traced there.

The judging itself is unchanged: MISSED (nothing went red), WRONG CHECK
(something went red, but not the named check), ANCHOR GONE and NOT RESTORED
fail the run, and CI greps for those words at the start of a line.

## `runscenarios.py` — the states it has to survive

Twelve scenarios through `mockapi.lua`, whose behaviour is configurable so the
client can be made to misbehave on purpose: withhold every value as a secret,
remove every API, put the player in the graveyard or in combat.

Covers a class with no buffs to give, a dead player, combat lockdown, all
values secret, a stripped client, a profile full of nonsense, the modes that
must never arm the button, speech that could break the macro, a buff pinned
from another class, and odd names.

Each drives the whole lifecycle including `PreClick` and `PostClick`, and fails
on anything thrown — in game that would be a timer that silently stops, or a
prompt sitting there doing nothing.

```
python tests/runscenarios.py           # spread over one process per core
python tests/runscenarios.py --jobs 1  # in one process, as it used to run
```

Scenarios can also live in `tests/scenarios/<topic>.lua`, one file per topic,
so that two pieces of work do not both append to the end of `scenarios.lua`.
They run after the main file, in name order. Each is called with the addon
directory and a table of the main file's helpers:

```lua
local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
```

Their mutations go in `tests/mutations/<topic>.py`, which `selftest.py` runs
with `mutate()` in scope.

A run can be narrowed, which is how `selftest.py` judges a mutation by the
scenarios its check lives in:

```
python tests/runscenarios.py --scenario "emptied queue disarms"
python tests/runscenarios.py --file look.lua          # one file's scenarios
python tests/runscenarios.py --file scenarios.lua     # the main file's only
python tests/runscenarios.py --select pick.json       # {"scenarios": [...], "files": [...]}
python tests/runscenarios.py --trace lines.json       # which scenario ran each line
```

A scenario left out gets `nil` from `load()`, which every scenario reads as
"skip"; the few that report an empty load as a failure of their own
("SKIPPED -- the session would not start") are excused only for a name that
was left out on purpose. A narrowed run that lets nothing through fails, so a
selection that no longer names anything cannot pass for a green one.

### `frametree.lua` — what the frames were told

The mock's frames remember only what a scenario has needed to read back. A
scenario about how the prompt looks or moves can load this first and call
`FrameTree.install()` before loading the addon: every frame, texture, font
string, animation group and cooldown is then recorded with its parent, its
anchors and every Play and Stop, while the mock underneath still sees every
call (so a protected call in combat is still written down).
`FrameTree.playing()` says what is animating, `FrameTree.settle()` finishes the
one-shot animations the clock has reached, and `FrameTree.uninstall()` puts the
mock's own `CreateFrame` back. `tests/scenarios/look.lua` uses it, and so does
`tools/render_prompt.py`.

## `validate.py` — structure

Lua syntax for every file including bundled libraries, XML well-formedness,
that every path in `embeds.xml` and the `.toc` resolves, and that no stale name
survives a rename. Our own files are the `.lua` files `Manners.toc` names,
read from it, so a file split out of another is checked the moment it is
listed; each has to keep 10 of the 200 file-level locals Lua 5.1 allows free.

It also reads Lua 5.1's two per-function limits out of the bytecode
(`tools/lua51_limits.py`, from `string.dump` in `lupa.lua51`): the game allows
a function 60 upvalues and 200 locals active at once, and a file past either
does not load. beta.6 shipped with `Prompt:Create()` at 69 upvalues. Any
function in a shipped file over 55 upvalues or 190 active locals fails, named
by file and line, and the five tightest are printed every run so the next
merge to cross can be seen coming.

It also audits the translations (`tools/locale_keys.py`): every `Locales/*.lua`
has to load, keep each line's `%s`, `{tokens}` and `|c` codes as the English
has them, set no key the code no longer asks for, and translate every key the
code does ask for. A missing key fails the run (`MISSING deDE: ...`), so no
release ships with a line that shows in English on a translated client;
`python tools/locale_keys.py --missing <code>` lists what to translate.

## `bughunt.py` — patterns

Greps for fault shapes seen here: `a and b or c` where `b` can legitimately be
false, cross-file local calls (a name local to one of the toc's files, called
from another without a copy of its own), event handlers whose first parameter
is not the event name, registered events with no handler and vice versa, unit
APIs compared without passing through `plain()`, and arithmetic on settings
with no default.

It reports some known false positives — `0` and `28` are truthy in Lua, so
those collapses are correct, and `UnitInParty and UnitInParty(unit)` is an
existence check rather than an unguarded compare.

## Requirements

`pip install lupa` for the Lua runtime. Every suite loads `lupa.lua51`, the
same Lua the game runs: on a newer one the suites passed a build that could not
load in game, because 5.1 allows a function 60 upvalues where 5.4 allows 255.
Test code has to stay 5.1-clean for the same reason.
