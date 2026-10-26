# Where this stands

Working notes. Not part of the shipped addon — `.pkgmeta` leaves it out. How to
work on the project: `CLAUDE.md`. How to release: `RELEASING.md`.

## State

1.10.1 is released, for all five live clients: WoW Forever, Classic Era, Burning
Crusade Classic Anniversary, Mists of Pandaria Classic and retail (a toc per
client from `tools/maketocs.py`, a buff set per client in `Buffs.lua`, each
checked against that client's DB2 on wago.tools, and a scenario file and
mutations per client). Every buff on every client has In character lines of
its own, and every people has lines (the Haranir since 1.7.2, speaking since
1.7.3).

Working here is quicker and safer for an agent since round 33 (`CLAUDE.md`,
"Dev tools"). `tools/lint.py` says in under a second whether every Lua and
Python file compiles and the generated tocs are current (`check.py --lint` runs
it first and stops there on a problem). `tools/anchors_for.py` lists the
mutations on a line before it is edited and, after, the anchors that are gone.
`tools/clients_watch.py` compares each client's interface number and build with
Blizzard's UI source and lists the PTR numbers. A `.claude/` folder holds a
permissions list, a hook that lints each edited file, and the commands
`/check`, `/release`, `/bughunt`, `/translate` and `/phrases`.

## Open

**The action bar slot in the game (1.10.1).** SetMacroSpell/SetMacroItem on
the "Manners" macro, cleared with an empty string, and PickupMacro from the
options button are untested in a real client: check the slot shows the spell's
icon, cooldown and range, goes back to the note icon with nobody to buff, and
that a controller button bound to the prompt shows its glyph on the chip.

**The new looks in the game.** Ribbon, Letter and Leather (1.10.0) and the
picker's cards (the player's own buff icon laid over each picture) have only
been seen in the renderer: the real Morpheus face, masks, the scroll's unroll
clip and the tiled leather want a look in the client.

**Forever's group casts and the cast event.** The mage's, priest's and druid's
group casts have no unit target in the client's spell data, so
`UNIT_SPELLCAST_SENT` is taken to name nobody and the cast is settled as "would
not say" (1.7.6). That is an inference from the data and Blizzard's
documentation, not an observation: `/manners clicks` after one such cast shows
the sent line (`CAST SENT 23028 -> ` with nothing after the arrow if it is
right).

**Only Mage has ever cast in the live client, and only on WoW Forever.** No
review substitutes for it. Warrior first: Battle Shout is `selfCast`, its macro
has no `/target` line, and `pending.selfCast` in `SettlePendingClick` is the
branch deciding whether a warrior can ever repay anybody. It has never run
against the real game. The other four clients have run only on the mock.

**Weapon enhancements were written against the data and the mock, and the
first word from the live game is a shaman on Forever saying the oil macro
"doesn't apply oils properly".** Nothing in the data says why: an
oil's use spell is the same shape as a scroll's (SpellTargetRestrictions target
16, a three-second cast, SpellEquippedItems asking a weapon class), the ids and
enchants audit clean at both Forever builds, and the macro is the scroll's
(`/use item:<id>`, `/use 16`). What the game does with it is not known. Ask the
player which oil, what the press did (nothing, an error line, the replace popup,
the wrong hand), and for `/manners debug` and the lines `/manners dev clicks`
prints on one press (`CLICK build=... macro=...`, `CAST SENT <spell> -> ...`,
`CAST OK`, `after our cast: ...`). A macro of the player's own with those two
lines (`/use item:20750`, `/use 16` for a Wizard Oil), clicked from a bar with
the oil in the bags, says whether the game takes the form at all. Forever
lists an Imbue (Rockbiter Weapon, a poison, a scroll) and a Temporary enchant (a
stone, an oil, a lure) on a hand together; `enchantKind` in `Buffs.lua` and
`ReadImbue` in `Core.lua` sort by it.

**One assumption is untested.** A late refusal is matched to the press it
answers using the cast guid the client sends with both cast events, and only
the guid: a refusal undoes nothing unless both events carry the same one,
because without it a new attempt being turned away cannot be told from the
answer to a press that landed. If the client does not fill the guid in, a real
late refusal goes unnoticed and the favour stays marked repaid, which is safe
but quieter. Confirm with `/manners clicks` in game.

**`runscenarios.py --flavour X` is red off Forever by design**: most of its
failures are fixtures written for Forever (two-part names, Forever's scrolls
and raid-wide group casts, a raid pcall ceiling set for Forever's data). Run it
with `--baseline` to see only failures that are not already in
`tests/baselines/<X>.txt`.

**Client builds move.** `python tools/clients_watch.py` says when one has (its
row reads DRIFT); the toc then needs the number (`tools/maketocs.py`'s
`FLAVOURS` and `Manners.toc`'s Interface line). Retail moved to 12.1.5
(interface 120105) in 1.7.7.

**What 1.8.0 needs the live game for.** The clickable names in the list
(`Prompt/Rows.lua`): a left click on a name targets, casts and hands back with
the spoken line, and the favour is filed; the row's attributes written in its
PreClick are read on that same press (the prompt relies on the same); in a
fight a name does nothing and no "action blocked" error appears; the click
areas line up with the text in all six looks, above and below the prompt;
right-click skips, shift-right-click lists. The weapon enhancements
(`ENHANCEMENTS` in `Buffs.lua`): `/use 16` and `/use 17` aim the right hand on
each client; the off hand's values in `GetWeaponEnchantInfo()` on Era, TBC and
Mists; `WEAPON_ENCHANT_CHANGED` fires; over an enhancement already on, the
game's own replace question appears and the player's click completes it
(Manners never answers it); retail and Mists poison spells and talents read
right. The friendly-nameplate note and button under Passers-by, and the
empty-key line, as laid out in the real window.

**Group spells are cast by bare name**, trusting the game to pick the best
rank (Buffs.lua header). A priest or druid with two ranks of Prayer of
Fortitude or Gift of the Wild has never pressed one in the live game. On a
level-60 priest, `/run local i=C_Spell.GetSpellInfo("Prayer of Fortitude")
print(i and i.spellID)` printing 21564 says the bare name means the top rank.

**Bug hunt 23 rests on three client facts nobody here can observe.** The nine
old candidates were triaged after 1.7.7: two were already fixed, seven were
fixed in 1.7.8 (`tests/scenarios/hunt23-*.lua`). What they assume:
- Classic Era and TBC answer nothing for spell 61304 (no DB2 row there), so
  `GlobalCooldownReading` (Clicks.lua) reads one of the class's buffs. If those
  clients answer zeros instead, the fallback never runs. `/run
  print(C_Spell.GetSpellCooldown(61304))` on either client settles it.
- The cast spell's `isOnGCD` reads true by `SPELL_UPDATE_COOLDOWN` for a cast
  on the global cooldown (`DropGuessOffGcd`); Blizzard documents the field as
  trustworthy only there.
- Selecting the unit already selected sends no `PLAYER_TARGET_CHANGED`
  (Queue.lua `pointedAt`, `NoteRefusal`).

**What bug hunt 23 left.** A refusal of your aura list longer than both settle
stages (about 34 s: a keystone, a long fight) still loses the first favour
after it (Favours.lua). A target chosen before the addon heard any target event
(login, `/reload`) is not known to be a choice and is backed off as before.

**The retail runs of the fight scenarios are local only.** `check.py
--flavours` runs `unverified.lua`, `hunt23-queue.lua` and `hunt23-favours.lua`
as mainline (`ALSO` in `tools/check.py`), since retail hides auras in a fight
as Forever does. Neither `ci.yml` nor `tools/release.py` runs `--flavours`
(release.py runs `check.py --anchors`); adding it to release.py's check would
cost about 30 s.

**A client bump stales `tests/baselines/mainline.txt`.** Nine of its lines
carry the client line ("12.1.5 (...), interface 120105"); they were rewritten
for 12.1.5 after 1.7.8. `normalise()` in `tests/runscenarios.py` could strip
the build and interface so the next bump does not.

**Unused local functions are found by hand.** `tests/validate.py` reports a
write-only `ns.X`, but nothing finds a local function nobody calls; extending
that check is the one step of the 1.0.0-beta.9 cleanup plan never built.

## Decisions

Code comments point here (`STATUS.md`) for these. They are decisions rather
than code; do not undo them.

- **`verbose` stays on by default** (decided 2026-10-17). Every player gets
  "X buffed you" and the line saying why a cast failed: a new player sees the
  addon notice favours. AceDB stores no value equal to its default, so changing
  the default would flip everybody who never touched the setting.
- **The real player names in git history stay** (decided 2026-10-17): nine
  names in two commits from before the v0.9.5 scrub, plus the pre-scrub
  screenshots as blobs. All of it was public long before, a rewrite would
  change every hash and tag and still leave copies in clones and GitHub's
  caches.

- **The first-name fallback was removed deliberately.** The macro sends one
  `/target`, carrying the full name. Both `CHANGELOG.md` 1.3.0 and
  `.github/AUDIT.md` argue for offering the bare first name as well; both are
  marked superseded, and there is a note above `ExpirePendingClick` in
  `Clicks.lua` saying why. Do not restore it.
- **The aura scan corroborates rather than recognises.** It does not try to
  tell a refusal from an empty list — it cannot, because the shape a refusal
  arrives in is unknown. Nothing primes, prunes or announces on one reading.
  A refusal that repeats identically across two readings is indistinguishable
  from holding nothing, and that residue is documented in the code.
- **A favour names who was there when the aura landed**, not who holds that
  nameplate token when it is noticed. A sighting nobody could name is never
  announced.
- **The never-offer list does not apply to a favour owed.** Somebody on it
  who buffs you is still offered the return, because returning a favour is
  the point of the addon; the options page says so. Shift-right-clicking an
  owed person lets that one favour go too, or they would come straight back
  when the skip ran out -- including somebody who was already on the list.
  Friends-first orders people *within* a kind of offer (group, passers-by)
  and never across one, and below the range key: a friend known to be out of
  range never leads over somebody in range.
- **The combat log is an addition, never a replacement.** It is registered only
  on Classic Era, Burning Crusade and Mists — Forever and retail refuse it — and
  it exists for the one thing the aura scan cannot do anywhere: name a stranger
  with no unit token, from `SPELL_AURA_APPLIED`'s GUID via
  `GetPlayerInfoByGUID`. It goes through the same `NoteFavour`, not a queue of
  its own, and none of the aura scan's corroboration applies to it: a log line
  is an event, not a reading that might be wrong. Where both sources run they
  agree through one claimed-and-consumed mark, so a landing both of them see is
  announced once and a genuine recast still counts.
