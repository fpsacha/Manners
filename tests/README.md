# Tests

No part of this can talk to a running client, so these check the things that
can be checked from outside it. Between them they catch every fault class that
actually cost time building this addon — none of which a syntax check can see.

Run them from the project root. Every path is resolved relative to the test
file rather than named outright — hardcoded ones passed here and failed the
first time CI ran them on a machine that was not this one.

## `runharness.py` — load the addon for real

Loads `harness.lua`, a mock WoW API, then loads all four addon files and drives
the main paths: `OnInitialize`, `OnEnable`, `PLAYER_ENTERING_WORLD`,
`BuildQueue`, `Tick`, the aura handler that stands in for the combat log this
client does not have, `ScanOwnBuffs`, `ApplyStyle`, `Refresh`, and the slash
commands.

Catches:

- **calls to names that do not exist** — a function local to `Core.lua` called
  from `Prompt.lua` is a nil global, and throws only when that line runs
- **handlers registered for events this client lacks** — the mock knows which
  events exist, and registering anything else fails. This is what stopped the
  scanner from ever starting.
- **misspelled API calls**
- anything the addon's own guards caught while running

```
python tests/runharness.py
```

## `selftest.py` — check the harness still works

Reintroduces each of those three faults one at a time, confirms the harness
catches it, and restores the file. A test that passes vacuously is worse than
no test.

```
python tests/selftest.py
```

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
python tests/runscenarios.py
```

## `validate.py` — structure

Lua syntax for every file including bundled libraries, XML well-formedness,
that every path in `embeds.xml` and the `.toc` resolves, and that no stale name
survives a rename.

## `bughunt.py` — patterns

Greps for fault shapes seen here: `a and b or c` where `b` can legitimately be
false, cross-file local calls, event handlers whose first parameter is not the
event name, registered events with no handler and vice versa, unit APIs
compared without passing through `plain()`, and arithmetic on settings with no
default.

It reports some known false positives — `0` and `28` are truthy in Lua, so
those collapses are correct, and `UnitInParty and UnitInParty(unit)` is an
existence check rather than an unguarded compare.

## Requirements

`pip install lupa` for the Lua runtime. The Lua it provides is newer than the
5.1 the game runs, which is fine — nothing here uses syntax that differs.
