# Where this stands

Working notes. Not part of the shipped addon — `.pkgmeta` leaves it out. How to
work on the project: `CLAUDE.md`. How to release: `RELEASING.md`.

## State

1.7.8 is released, for all five live clients: WoW Forever, Classic Era, Burning
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
after it (Favours.lua); a zone change while a slow settle timer is parked
starts the next settle up to a second late. With your own name never-offered,
the family lines of `/manners debug` still name a buff to cast (saying why
needs a new string). A target chosen before the addon heard any target event
(login, `/reload`) is not known to be a choice and is backed off as before.

**`tests/baselines/vanilla.txt` and `tbc.txt` predate `unverified.lua`.**
`runscenarios.py --flavour vanilla --baseline` (and tbc) prints 32
`unverified:` failures not in the baseline, the same on 1.7.7. Likely Forever
fixtures (two-part names); confirm before `--update-baseline`.

**"Only for people who buff me" (sound) stays enabled with "People who buff me"
off.** `Options/Look.lua` `soundOwedOnly` is disabled only by the sound
switch. Judged harmless: the sound ignores the setting then
(`Prompt/Refresh.lua`, `db.sources.owed ~= false`), so the toggle does nothing.

**Unused local functions are found by hand.** `tests/validate.py` reports a
write-only `ns.X`, but nothing finds a local function nobody calls; extending
that check is the one step of the 1.0.0-beta.9 cleanup plan never built.

**A stale comment in `release.yml`.** Above the "Confirm the suites can still
fail" step it says CI on master runs the full selftest on every push. It does
not: `ci.yml` runs `selftest.py --anchors`, and the full run is made by hand
before a release (`RELEASING.md`). Reword the comment only; the `shell: bash`
line and the grep below it are mutation anchors.

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
