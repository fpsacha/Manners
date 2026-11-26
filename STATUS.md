# Where this stands

Working notes. Not part of the shipped addon: `.pkgmeta` leaves it out. How to
work on the project: `CLAUDE.md`. How to release: `RELEASING.md`. The long
notes on every feature up to 1.11.36, with the questions only the game can
answer, are in `.claude/docs/status-history.md`. This file holds only what
stands now. Keep it short: what ships goes to the history file or away.

## Where I left off

*26 November 2026. Last release: 1.12.1 (live everywhere and in the owner's
game folder). Read `.claude/docs/lessons.md` first: it holds the 1.11.41
rollback, the scope rule, what Forever hides and what is open.*

- **In flight (branch `fix-44`, worktree `Manners-wt-44`):** issue #44 is
  implemented with the caster's addon whisper, one-candidate fallback and a
  quiet verbose-only hint. The module API, package plumbing and disabled
  `Manners: Combat` folder are implemented. The remaining modules are also
  migrated: disabled Achievements, My Buffs and Services, plus enabled
  `Manners: Pets` (hunter-only behaviour; inert elsewhere). Combat carries the
  Forever cure workaround, break-free and in-fight Mend Pet. Services now has a
  dedicated page and independently controlled, exact-client request services:
  refreshments and named portals, Slow Fall, Levitate, Water Walking,
  healthstones/Soulwell, summons, Soulstones and Fire Shield where supported.
  Disabled services create no event frame or queue entry, and the exact
  `tools/audit_services.py` matrix is clean on all five builds.
- **Context audit:** bag items now obey the client's usability and cooldown
  answers before they are offered; Camper's Lure is modeled on the player's
  Forever 1.60.1.71091 build at +60 Fishing for five minutes. The death,
  resurrection and unghost tracking-cache bug has a focused scenario and is
  installed in the owner's game. GitHub issue #55 records that report.
- **Bug-fix pass:** the final review closed Services-only prompt detection,
  saved Fire Shield lifecycle, combat-rota leakage, whisper/focus scope errors,
  ignored or conflicting caster claims, unreadable caster levels and
  disabled-module resets. All 126 performance-budget loads pass, every new
  mutation is caught, and `check.py --lint --anchors --quick` passes all 8
  steps with 8,044 live anchors. The verified core and all five module folders
  were copied to WoW Forever and hash-checked against this worktree.
- **Paladin cure report:** Forever's secret-aura fallback now draws a
  visible ring at the game-owned poison/disease indicator; a Paladin's
  dangerous Cleanse is replaced by learned Purify when a never-removed debuff
  is beside the ailment. Combat, Pets and My Buffs now suspend their queue
  paths, event frames and visible secure controls when disabled and resume
  them without changing saved settings. All focused cases and the 126
  performance loads pass; the quick gate is 8/8 with 8,051 live anchors. The
  exact build was copied and hash-checked in WoW Forever, with `Libs`
  preserved.
- **Cure ownership moved:** `Modules/Combat/Cures.lua`, the Who-to-buff cure
  controls and their layout now load only from Manners: Combat. The core has
  guarded absent-module queue/report paths, and a pending Combat disable clears
  cure caches, scans and queue work without changing saved switches or duration.
  Disabled Combat settings are also excluded from core-page resets. Focused
  cure/module scenarios, four ownership/reset mutations, 126 performance loads
  and the 8-step quick gate pass; 8,055 anchors are live. WoW Forever is
  hash-matched to the move and its `Libs` remain intact.
- **Architecture backlog complete:** every module suspends immediately and
  resumes without rebuilding secure frames; one safe context decision feeds
  buffs, cures, own items and Services; `/manners debug` keeps the last twenty
  rejected decisions without printing secrets; and `tools/install_package.py`
  stages all six addon folders, preserves source-install libraries and verifies
  every installed byte with SHA-256. Its seven checks include a complete release
  ZIP round trip, unsafe paths, missing libraries, source-library preservation,
  byte checks and rollback. Focused lifecycle/context scenarios, performance
  budgets and package-install mutations pass.
- **Player requests and data gates complete:** asking for a paladin blessing has
  an Automatic/Kings/Might/Wisdom/Salvation choice where supported, and Automatic
  can ask another reachable paladin for another missing blessing. Every cited
  client is on its current upstream build and `audit_ids.py` has zero findings;
  the old 18 Forever shaman-imbue findings are resolved. Mists' Focus fallback
  and consumable-slot audit are fixed, retail fight/module scenarios run in CI
  and release checks, and nightly runs strict client-build, Services and ID
  audits. New shipped Lua locals fail `lint.py` unless deliberately listed in
  the reviewed historical baseline.
- **Presentation and install current:** the prompt, cure, Services, My Buffs,
  options and listing screenshots were redrawn with every optional module
  attached. The verified six-folder build is installed in WoW Forever by the
  package installer, with `Libs` preserved. The complete Forever suite is green,
  the reviewed retail baseline is current, and the final quick gate is 8/8.
- No release, push or commit was made.
- **Waiting on player evidence, not code:** KoriKaiMoon (`/manners debug` from a
  dungeon), issues 33 and 21 (client/settings/report), and issue 28's first-press
  error text or `/manners clicks`. Issue 44 is implemented; issue 55 is fixed
  locally and stays open until release.

## State

- **Released:** 1.12.1 (24 November 2026), on all five clients through
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
