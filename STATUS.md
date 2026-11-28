# Where this stands

Working notes. Not part of the shipped addon: `.pkgmeta` leaves it out. How to
work on the project: `CLAUDE.md`. How to release: `RELEASING.md`. The long
notes on every feature up to 1.11.36, with the questions only the game can
answer, are in `.claude/docs/status-history.md`. This file holds only what
stands now. Keep it short: what ships goes to the history file or away.

## Where I left off

*27 November 2026. Last release: 1.12.6. 1.13.0 is ready on master, not yet
released (the owner runs `python tools/release.py 1.13.0`).*

- **In 1.13.0:** the combat prompt (each action its own place above the buff
  prompt: the client refuses SetFrameLevel on protected frames in a fight since
  11.1.7), My companion moments, the Achievements board, the consumables mover,
  longer own-buff skips (#69), Ask's 30 s arrival wait, own buffs not held into
  a fight, Outline repainted through Gemini, sidebar/tabs/spell icons, #68 and
  #70 (Classic Era) fixes. Changelog written.
- **Nightly 28 November** (`feedback-20261128`, in 1.13.0): *Sleeping bag
  before food and elixirs* (`ownBuffs.restedFirst`, off; Lucitha on CurseForge;
  `tests/scenarios/restedfirst.lua`). #71 opened (Blessing of Freedom).
- **Validated:** focused scenarios and mutations for every change, combat
  actions on all five clients, the 104 pull-touching files, quick check green.
  The full suite runs inside release.py.
- **Waiting on the owner:** the release; posting the drafted CurseForge and
  Discord replies (psardoin, ZachrielCl, xh43k, Dr Kief; #67/#68).
- **Waiting on players:** #70 (which client, for Forever's placement circle),
  #21 (client and log).
- **Next:** release 1.13.0; close #67, #68, #69 with "Fixed in v1.13.0"; ask
  before deleting the ~30 stale worktrees.
- **Watch out:** an invisible combat card (a hidden-health need on Forever) is
  clickable in its own place; same-named companions can catch the emote; the
  new translations are not reviewed by native speakers.

## State

- **Released:** 1.12.5 (27 November 2026), on all five clients through
  CurseForge, Wago and GitHub. `CHANGELOG.md` says what each version brought.
- **The owner does not test in the game** (21 November). The code is taken as
  working once the suites pass; players' reports find the rest, with
  `/manners debug`, `/manners errors` and the full check-up as their evidence.
  The game-only questions in the history file are notes for when a report
  comes in, not a to-do list.
- **Tests:** the whole scenario suite (`tests/runscenarios.py --jobs 4`, about
  15 minutes) runs before every release. The full selftest runs on GitHub
  (`selftest.yml`). Off Forever, `runscenarios.py --flavour X --baseline` shows
  only the reds not already in `tests/baselines/<X>.txt`. `check.py
  --baselines` runs that for all four other clients (about 95 minutes of two
  cores), so it is a release-time step, not one for every change.
- **Players' reports** are GitHub issues labelled `player`. `/answer-comments`
  and `/handoff` run the pass. The Wago page text is set aside by the owner:
  releases still upload there.

## Open

- **KoriKaiMoon: party members missing a paladin's blessings ignored in a
  dungeon (Forever).** Not reproduced. `tests/scenarios/dungeon-party.lua`
  walks a five-man in an instance out of a fight with the defaults: everybody
  missing a blessing is offered, also with the spell's range check silent and
  the follow prompt withheld, with Greater Blessing of Kings and its symbols
  (too few of one class for it), and again after a pull.
  `tests/scenarios/forclass.lua` already covers another paladin's blessing.
  Left to look at: range or aura reads that the game answers differently inside
  an instance (a "no" from `IsSpellInRange` or the follow prompt, or reads
  withheld after the fight is over), and *Only offer people whose buffs can be
  read*. A `/manners debug` from inside a dungeon while it happens is needed.

- **GitHub issue 28 (first press of a CLICK bind errors).** Nothing in the press
  path fails on a first press: the mock casts once on it. Waiting on the
  player's error text or a `/manners clicks` log. Meanwhile the key boxes take a
  controller button (`WidgetsChoice.lua`, `tests/scenarios/gamepad-key.lua`).
- **Other-client suite baselines remain conservative fixtures.** The exact data
  and client-specific focused files are green, but the whole off-Forever suites
  keep their historical failure baselines. New lines still fail a release;
  build/interface churn in those lines is normalized.
- **Release boundary.** Full Forever scenarios, the final quick gate, the
  package round trip and the game-folder hash install are the last pre-release
  steps. Commit, merge, publish and closing/replying to player issues remain the
  owner's call.

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

- **The bar macro carries the cast** (decided 2026-11-02): the client refuses a
  macro that /clicks a button which runs a macro (Blizzard, WoWUIBugs #552;
  retail 11.0.2, the Classic clients since), so no macro may /click
  MannersPrompt. Do not go back to a /click body. The bar's copy says no line:
  only a press of the prompt judges the line at the last moment (HoldLine).

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
- **The mute list (Who to skip, `filters.skipMuted`, off) follows the never-offer
  list**: a favour owed and its thank are excepted, and, as with the other skip
  switches, your target and focus are still offered (a resurrection included;
  an ask holds a muted player regardless). Read live, never copied or written;
  its own muting switched off skips nobody. Shown only while its saved table is
  there (GitHub issue 30).
- **The combat log is an addition, never a replacement.** It is registered only
  on Classic Era, Burning Crusade and Mists — Forever and retail refuse it — and
  it exists for the one thing the aura scan cannot do anywhere: name a stranger
  with no unit token, from `SPELL_AURA_APPLIED`'s GUID via
  `GetPlayerInfoByGUID`. It goes through the same `NoteFavour`, not a queue of
  its own, and none of the aura scan's corroboration applies to it: a log line
  is an event, not a reading that might be wrong. Where both sources run they
  agree through one claimed-and-consumed mark, so a landing both of them see is
  announced once and a genuine recast still counts.
