---
description: Add In character lines (research, write, review, add_phrases.py, translate)
argument-hint: "[pool or people, e.g. RACE.dwarf.thanks | CLASS.MONK.offer | SPELL.skyfury]"
---
Target: `$ARGUMENTS`. The pools, rules and examples caveat are in CLAUDE.md's "In
character phrases"; `Phrases.lua` holds them. Work in your worktree.

1. **Research.** Find what the people, class or spell sounds like in the game
   itself (Wowhead per client, the game's own voice lines). Look up every key:
   a race's file name is `ChrRaces.ClientFileString` (`Scourge`, `Harronir`,
   `EarthenDwarf`), never guessed; a buff key must be in some client's set in
   `Buffs.lua`. Read the pool's existing lines first: do not repeat them.
2. **Write** `pools.json`: `[{"pool": "RACE.<family>.<kind>", "lines": [...]}]`
   (`CLASS.<CLASS>.<kind>`, `SPELL.<key>`, `GIFT.<key>`, `SAME.<CLASS>`). At most
   85 characters with `{name}` as "Bartholomewz" and `{buff}`/`{gift}` as "Power
   Word: Fortitude"; no `|`, `[`, `]`, line break or leading `/`; only the tokens
   `{name}` `{buff}` `{gift}` (`{gift}` only in TRADE and GIFT); never the word
   "buff". At least three lines per new pool (two for GIFT and `outsider`).
3. **Review**, a second agent that did not write them: in character and in the
   people's voice, natural English, nothing that reads as an instruction or a
   disclaimer, no two lines that say the same, nothing a macro cannot carry.
   Append only: never reword or reorder a pool's first lines (they are the
   phrase box's examples; a reworded one goes into `RP.LEGACY.reworded`).
4. `python tools/anchors_for.py Phrases.lua` before, and
   `python tools/anchors_for.py --check-after` after: mutations in
   `tests/mutations/rp*.py` can sit on lines you touch.
5. `python tools/add_phrases.py pools.json`. It writes nothing if any line
   breaks a rule and lists each with its reason.
6. Every line is a new key: `python tools/locale_todo.py --out <dir>`, translate,
   `python tools/locale_add.py <code> <file>` per locale (the `/translate` command).
7. `python tests/runscenarios.py --file rp.lua --jobs 2`, then
   `python tools/check.py --lint --flavours --anchors --jobs 2`. A note for
   players goes under `## Unreleased` in `CHANGELOG.md`.
