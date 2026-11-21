# Manners -- In character phrases

The In character pools, the rules a line keeps, and the examples caveat. Moved
out of `CLAUDE.md`, word for word; `CLAUDE.md` is the index, read first.

## In character phrases

`Phrases.lua` holds the pools; `RP.Pick` chooses one line at the click from the
pools that fit the moment. Pools: `RP.RACE.<family>.<kind>` (kinds `thanks`,
`asked`, `offer`, `group`, `kin`, and `night`/`morning`/`city`/`outsider`
where a people has them; `pet`, `petpraise` and `petcomfort` for every people,
a hunter's words to the pet, read only by HunterPet.lua, `{name}` the pet's
name), `RP.FACTION`, `RP.GENERAL`, `RP.KIN`,
`RP.CLASS.<CLASS>.<kind>`, `RP.SPELL.<buff key>`, `RP.GIFT.<buff key>` (thanks
only; `{gift}` is the spell they gave you), `RP.TRADE`, `RP.HISTORY`,
`RP.PLACE`, `RP.TIME`, `RP.TARGET`, `RP.SAME.<CLASS>`, `RP.ONTO`.
`<family>` comes from `RP.FAMILY`, keyed by `UnitRace`'s second return.

- Add lines with `python tools/add_phrases.py pools.json`: a list of
  `{"pool": "RACE.<family>.<kind>" | "CLASS.<CLASS>.<kind>" | "SPELL.<key>" |
  "GIFT.<key>" | "SAME.<CLASS>", "lines": [...]}`. It appends to the pool (or
  creates it at the end of its table), escapes, and refuses what
  `tests/scenarios/rp.lua` would.
- The rules (`rp: the lines are short and safe in a macro`): at most 85
  bytes (UTF-8: an accented letter or a curly apostrophe counts 2 or 3) with
  `{name}` -> "Bartholomewz" and `{buff}`/`{gift}` ->
  "Power Word: Fortitude"; no `|`, `[`, `]` or line break, no leading `/`; no
  line equal to another once reduced to its letters; only the `{name}`,
  `{buff}`, `{gift}` tokens, `{gift}` only in TRADE and GIFT; never the word
  "buff" (the set is in character). A buff key only another client has goes
  in `rp.lua`'s `elsewhere` list.
- Pool sizes (`rp: every moment the set knows has lines`): at least
  `RP.SPREAD` (three) lines in every race kind, FACTION, GENERAL, CLASS kind,
  SPELL, SAME, TRADE, HISTORY, PLACE, TIME and TARGET pool; two in a GIFT
  pool, a people's `outsider` pools and an ONTO pool. A new pool below that
  turns `rp.lua` red, and `add_phrases.py` refuses it.
- Each line is a player-facing string: all eight translations before it lands.
  On other languages an untranslated line is dropped at load.
- **Examples caveat**: the first lines of the pools are the phrase box's
  examples, and a player's saved box is recognised by matching them exactly.
  Never reword or reorder the first lines of a pool; append. A reworded
  example goes into `RP.LEGACY.reworded` as it read before (the second
  rewording, every line tied to the spell, into `reworded2`: `RP.BETWEEN` is the
  box saved between the two, `RP.BEFORE` goes back through both; a third
  rewording needs a third list, since a box saved between holds the last
  one's old lines). `tools/legacy_lines.py --write-other` hashes those old
  lines too, so such a box opens in another language. Giving a people
  its first pool changes its examples (as for the Haranir in 1.7.2). The same
  holds for TRANSLATIONS: rewording a translation of one of a pool's first lines
  in `Locales/<code>.lua` makes every box saved before it read as the player's
  own, and In character stops for that player (1.6.6's 750 translation fixes did
  this until 1.7.6). The earlier translations are kept in `RP.LEGACY_TRANSLATED`
  (`tools/legacy_lines.py` builds and checks it): record the old text there
  whenever such a translation changes. `python tools/audit_saved_boxes.py` saves
  a box with every released tag in every language and checks the current
  addon still recognises it (its tag list is read from the repository's own
  tags). A box filled in one language and opened by a client in another is
  recognised through `RP.OTHER_KEYS` and `RP.OTHER_HASH` in `Phrases.lua`, every
  set and example line in every language by the hash of its text (the locale
  files load one per client, so the other languages' text is not there to ask):
  after any change to a set, an example or a translation of one, run `python
  tools/legacy_lines.py --write-other` (`--check-other` says whether it is
  current; `--check` runs it too), and `python tools/audit_saved_boxes.py --tags
  HEAD --saved-as deDE` (any language) reads the current boxes on every client.
- Race file names are the client's `ChrRaces.ClientFileString`, not the race's
  name: `Scourge` (Forsaken), `EarthenDwarf`, `Harronir` (the Haranir). 1.7.2's
  Haranir lines never played because the key was guessed. Look it up.
