# Where this stands

Working notes. Not part of the shipped addon: `.pkgmeta` leaves it out. How to
work on the project: `CLAUDE.md`. How to release: `RELEASING.md`. The long
notes on every feature up to 1.11.36, with the questions only the game can
answer, are in `.claude/docs/status-history.md`. This file holds only what
stands now. Keep it short: what ships goes to the history file or away.

## Where I left off

*22 November 2026. Last release: 1.11.40.*

- **Released today:** 1.11.38 (controller buttons in key boxes, battlegrounds
  after a death, mute list, hold food while moving), 1.11.39 (healthstone
  reminder, Will of the Forsaken on loss of control, /moo, cure button for
  secret auras and a button per cure, *Food still offered outside dungeons and
  raids*) and 1.11.40 (own buffs asked again after a death in a battleground:
  the cast on yourself went unnoticed under Forever's surname spelling, issue
  38). All issues from 32 to 38 are closed.
- **In flight:** the Report a bug flow, on branch `report-flow` (worktree
  `Manners-wt-report`), not yet merged: `Options/BugReport.lua` (window, link,
  Mark this moment, the hold-back watch, the "Report it" chat link), a fight
  summary line, the trail at 300, the self-test's *Fight buttons and keys*
  group, `tools/read_report.py`, the issue form's category and game fields. Its
  own scenarios: `bugreport.lua`, `trail-mark.lua`, `selftest-fight.lua`.
  The branch also carries the unreleased r39 fixes (cure button, break free on a
  second fear, healthstone "()", battleground food after a death, Greater
  Blessing, slider unit words, own-buff controls, the debug dungeon line).
  No workflow runs.
  Old worktrees kept on purpose (uncommitted files or unmerged): `look-fel`,
  `look-wild`, `relcheck`, `logo`, `ci-diag-generators`.
- **Water and food for your target,** on branch `water-target` (worktree
  `Manners-wt-water`), not yet merged: *Offer water and food to my target*,
  *How much to trade* (Fill by default, asked water and food fill too),
  scenarios `water-target.lua`, mutations `water-target.py`.
- **Waiting on the owner:** nothing.
- **Waiting on players:** issue 33 (which game, the Will of the Forsaken
  button), issue 39 (nonpromqueen: which "special, longer thank-you" option
  went missing; nothing was found removed), issue 22 (the imp's Fire Shield),
  issue 21 (no popup: their client and `/manners debug`). The cure button on
  Forever under secret auras is only proven in the simulator: user_fer3yhwuvuz52jwg
  and LuckyDan were asked for `/manners debug` if it still does not show.
- **Next:** (1) rewrite the retail and Mists baselines: `python
  tests/runscenarios.py --flavour mainline --update-baseline --jobs 4`, then
  `--flavour mists`, read the diff, commit. (2) Read new CurseForge comments
  and `gh issue list --label player`; build, whole suite, release, no asking.
  (3) If nonpromqueen names an option, find where it went.
- **Watch out:** the nightly pass (11 PM) answers comments and can release on
  its own: check the page and `git branch --list "feedback-*"` first. All of
  today's CurseForge replies are posted (201); its `state.json` lists them. I
  once dropped its `pending` notes by mistake and rewrote them condensed. A
  reply to a comment never goes up twice (`.claude/snippets/curseforge-reply.js`).
  Releases go out without asking once the whole suite is green on the exact
  commit.

## State

- **Released:** 1.11.36 (21 November 2026), on all five clients through
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

- **GitHub issue 28 (first press of a CLICK bind errors).** Nothing in the press
  path fails on a first press: the mock casts once on it. Waiting on the
  player's error text or a `/manners clicks` log. Meanwhile the key boxes take a
  controller button (`WidgetsChoice.lua`, `tests/scenarios/gamepad-key.lua`).
- **Classic Era, TBC, Mists and retail get less care than Forever.** Their
  baselines took in about 900 to 1,250 known reds each on 15 November. Most of
  those are Forever fixtures (two-part names, Forever's scrolls and group
  casts), and nobody has read them line by line. Mists and retail are worth
  reading first. Give the Forever-only files the `hasBuffs` skip so that what
  remains is real.
- **A client bump stales `tests/baselines/mainline.txt`:** nine lines carry
  the client line. `normalise()` in `tests/runscenarios.py` could strip the
  build and interface.
- **Retail runs of the fight scenarios are local only:** `check.py --flavours`
  runs them as mainline. CI and `release.py` do not.
- **Client builds move:** `python tools/clients_watch.py` shows DRIFT, and the
  toc then needs the new number (`tools/maketocs.py`'s `FLAVOURS` and
  `Manners.toc`).
- **Unused local functions are found by hand:** nothing flags a local
  function that nobody calls.
- **`tools/audit_ids.py --client camelot --offline` lists 18 findings:** these
  are the shaman imbue ranks the client may name. They are known and nothing
  reads them.
- **The listing pictures** of the options window need redrawing after the
  menu pass (see *Where I left off*).

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
