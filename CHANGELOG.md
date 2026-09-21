# Changelog

## Unreleased

Six rounds of review on top of 0.9.6, each one fixing what the round before it
found. The version has not been bumped and nothing has been tagged.

### Added

- **The prompt offers the buff they are actually missing.** A priest walks
  Fortitude, then Divine Spirit, then Shadow Protection; a druid offers Thorns
  as well as Mark of the Wild. Before this one buff per class was resolved and
  only that one checked, so the rest were never offered at all -- and worse,
  the default "leave them alone if they have it" then dropped the person from
  the queue the moment they held the first one, so being *partly* buffed made
  you invisible. Individual buffs can be switched off, or one pinned. Paladins
  are excluded on purpose: blessings overwrite one another, so walking would
  replace what the last click gave.
- **Somebody you targeted yourself outranks everyone**, including a favour
  owed -- but only when the game will confirm they are missing it. A guess does
  not jump the queue.
- **Debts survive a reload.** Stored per character on the wall clock and
  rebased on the way back in, because everything held in memory is relative to
  a clock that restarts at login. Clamped to the window as it currently stands,
  so shortening the slider cannot be out-waited by a file written under a
  longer one.
- **Right-click the prompt to skip somebody** without marking their favour
  repaid.
- **`/manners errors`**, and the panel no longer goes silent after the first
  thing it catches -- failures are kept per label, so a broken scanner after a
  broken style pass is visible instead of swallowed.
- Issue templates that require `/manners debug` and `/manners errors`, and a
  second one for reporting whether a class cast, since five of the six have
  never been used in game and "it worked" is the report nobody files unasked.

### Fixed

- **Every loading screen could invent favours.** This was the worst of them.
  The aura baseline was wiped and re-scanned in the same breath, so there was
  nothing to disagree with; the scan primed off a list the client had not
  actually shown it; and when the list read back, every buff you were carrying
  was announced as a fresh favour -- printed, pulsed at a bystander, and
  written to your saved variables. The scan no longer tries to recognise a
  refusal, which it cannot do because the shape one arrives in is unknown.
  Nothing primes, prunes or announces on the strength of a single reading.
- **A favour could name the wrong person.** The caster was resolved when the
  aura was *noticed*, not when it landed, and nameplate tokens are recycled in
  between -- so the debt, the chat line, the amber prompt and the spoken line
  could all be aimed at somebody who had done nothing. The caster is now read
  during the slot walk and carried forward, and a sighting nobody could name is
  never announced rather than announced to whoever is standing there later.
- **A warrior could never repay a favour.** Battle Shout is self-cast, so its
  macro has no `/target` by construction, and the settle path judged every
  click by "did it land on the person we offered?" -- which it never can.
- **A refused cast walked the person down their whole buff list.** Out of range
  or out of sight left standing the per-buff cooldown the click had written
  optimistically, so the prompt offered them the next buff, which failed the
  same way, until they were dropped entirely.
- **Every disarm was a no-op in combat.** Switching the addon off, unlocking
  the prompt or entering preview left it armed and still naming somebody, and
  the click handler had no guard at all -- so a switched-off addon still cast
  through the keybinding and still marked the favour repaid.
- **A cast that landed on the wrong player still counted**, and a late refusal
  arriving after the game had confirmed a send was dropped entirely, leaving a
  tick standing over a cast the server threw away.
- **The grace-window path ignored every filter the main path applies**, so a
  warrior who Battle Shouted you came back holding Arcane Intellect at the top
  of the queue, and a level-5 priest came back after being rejected for it.
- **The keybinding was an up-click on a button that only casts on the way
  down** -- and it is the first route the options panel recommends. It is now
  the native `CLICK` binding form.
- **Speech died silently on any new, copied or reset profile**, and stayed
  broken until a reload while the dropdown still claimed a set was loaded.
- **"Play a sound" played nothing** (the default was "None"), and the sound
  list was showing file paths as names.
- **The minimap button stayed attached to whichever profile loaded first**, so
  after a switch the checkbox and the button disagreed and a drag saved the
  position to neither.
- The prompt stayed on screen unlocked after being switched off, kept pulsing
  in combat after the debt was settled, and announced favours from a source
  that was switched off -- a line about something that could never reach it.

### Changed

- **The prompt stops churning.** It holds a candidate for a moment before
  swapping to an equal one, fades instead of vanishing, keeps a floor between
  sounds, says when it is held in combat rather than showing a stale name while
  looking live, and confirms a click landed instead of throwing every
  ingredient away unless a debug flag was on. It no longer starts life in the
  middle of the play area.
- **The options page stops describing things the addon does not do**: a Look
  mode that applied no border, an accent explanation a colour short, a re-offer
  delay that promised a per-player wait while writing a per-spell one, sliders
  with no units that silently mixed seconds with minutes, and a filter whose
  own description contradicted its label.
- **The first-name fallback is gone.** 1.3.0 added it so the game could pick
  whichever spelling resolved; the full name does resolve on this client, so
  the failure it guarded against was never observed, and offering two spellings
  could aim a cast -- and a spoken line -- at whoever else shared a first name.
  See the note above `ExpirePendingClick`. Do not restore it.

### Testing and tooling

- Tests run on every push, not only on a release tag.
- `validate.py` now catches a function given where AceConfig wants a number,
  which rejects the *entire* options table and stops the page drawing at all;
  and it compares `.pkgmeta` against `embeds.xml`, which fail in opposite
  directions and both package cleanly.
- `selftest.py` requires each mutation to be caught by the check that exists
  for it. It used to infer "caught" from the whole run going red, which a
  mutation guarantees -- so a bug reintroduced in one place and noticed
  somewhere else read as a pass.
- 120 scenarios, 96 mutations. The listing images are generated by scripts in
  `tools/` that read the prompt's real defaults out of the addon, so they
  cannot advertise a layout it does not draw.

## 0.9.6

Two live bugs found by the audit, both cases of the addon doing the wrong
thing rather than nothing.

### Fixed

- **The right mouse button still cast.** 0.9.5 stopped a right-press running
  the bookkeeping but not the cast: the unsuffixed `type`/`macrotext` are the
  fallback for every button, and `AnyDown` delivers all of them. So turning the
  camera with the cursor over the panel fired the buff, skipping PreClick's
  re-resolve entirely -- no retry cooldown, no debt settled, the same person
  offered again immediately. Buttons 2-5 are now given a type the secure
  handler does not recognise. The unsuffixed pair stays, because it is the form
  copied from the buttons that provably work on this client.
- **A cast that landed on the wrong player counted as the favour returned.**
  `/target <name>` for a name the game cannot resolve is a no-op -- it leaves
  your existing target in place -- so the cast went to whoever that was, and
  the debt was cleared for somebody who never got anything. The spell-sent
  event carries the name it actually reached, and it now has to match.

### Added

- `.github/AUDIT.md`, the full output of a 37-agent audit: 103 findings, 20
  bugs confirmed after adversarial verification, and a ranked feature plan.
  Kept because it is a work queue, not a report.


From a 103-finding audit across UX, code, performance and bugs.

### Fixed

- **Warriors were offered nobody, ever.** A guard meant as hardening bailed out
  of the whole queue when the player's current mana was zero -- which for a
  warrior is a readable, permanent zero. A whole class was silently dead. The
  check now only applies to classes that have a mana bar at all.
- **A pinned buff was reset to Automatic on every login.** `ClampSettings` ran
  before `ProbeCapabilities`, so it validated the choice against a class it did
  not yet know. Order swapped, and an unknown class now leaves the setting
  alone instead of rewriting it.
- **The "Only count real class buffs" toggle did nothing.** It had a default
  and a full-width control with a paragraph of explanation, and nothing read
  it; the filter was hardcoded. It works now.
- **`/manners restore` was in the help text but not implemented.**
- **The aura scan stopped at the first slot the client withheld**, hiding every
  favour behind it -- which then re-fired as new on the next scan, forever. It
  tolerates gaps now.
- **Any mouse button burned the candidate.** `RegisterForClicks("AnyDown")` is
  what makes casting work here, but it routes every button through the click
  handlers -- so a right-press to turn the camera set the retry cooldown and
  cleared the favour without casting anything. Only the left button acts.
- **A cast that never happened counted as a favour returned.** Clicking cleared
  the debt outright; if the cast was blocked by range or line of sight, they
  were marked repaid. The debt is now held until the game says what happened,
  and a failure re-offers them in two seconds.
- **The phrase preview promised 200 characters and the cast path allowed 120**,
  so anything in between rolled happily in the options and was silently never
  spoken. One shared constant, and the help says the real number.

### Tests

- The mock gave warriors mana, which is exactly why that bug got through. It
  reports honestly now.
- Three regression scenarios, each mutation-tested: reintroducing the bug makes
  its scenario fail.

## 0.9.3

### Fixed

- **LibDataBroker was fetched from a URL that does not exist.** The packager
  pulled the other twelve libraries and then failed on this one:
  `repos.curseforge.com/wow/libdatabroker-1-1/trunk` returns 404. It is sourced
  from `github.com/tekkub/libdatabroker-1-1` now, which is where it actually
  lives.

## 0.9.2

### Fixed

- **The test suites could only run on one machine.** `validate.py` and
  `runharness.py` carried absolute Windows paths from where they were first
  written, and the Lua harnesses joined paths with a backslash. Everything is
  resolved relative to the test file now, and CI runs them for real.
- `validate.py` treated an absent `Libs/` as a failure. A checkout legitimately
  has none -- they are build-time externals -- so it now says so and carries on,
  while still checking them when present.
- It also checks that the toc, `ns.BUILD` and the changelog agree on the
  version, because a log naming the wrong build has already cost an hour once.

## 0.9.1

### Added

- **Phrase sets.** Four of them, loadable from the Speech tab in one click:
  Roleplay (now the default), Polite, Cheeky, and Just their name. They are a
  starting point, not a cage -- the list stays editable afterwards.

### Changed

- The listing copy leads with what the addon does rather than telling a story
  about it. The toc, README and CurseForge summary all match.
- New project icon, built to sit beside real spell icons: bevelled gold frame,
  arcane interior, two streams of light winding into a core.

## 0.9.0

Renumbered down from 1.6.0 before any release. One class has cast in game;
calling that 1.x claims a confidence the testing does not support. The version
goes to 1.0.0 when the other five have been used by somebody.

### Release engineering

- **`.github/workflows/release.yml`** -- tag a version and it runs all three
  suites, fails the build if any check has stopped being able to detect the
  fault it exists for, then packages and publishes through the BigWigsMods
  packager. `Libs/` is not in the repository, so **a zip built from a clone
  has no libraries and will not load**; this is the supported way to build one,
  and both the README and the gitignore now say so.
- The toc, the README and the addon's own description state which classes have
  been verified in game and which have not.

### Tests

- **Every class, every buff.** All thirteen now have their cast path driven and
  the resulting macro checked: every line a real command, within the 255-byte
  limit, casting something, and targeting where targeting is right.
- **Warrior is structurally different** and is checked for it: Battle Shout is
  selfCast, so its macro must be a single line with no `/target` at all.
  Targeting somebody would be wrong, not merely unnecessary.
- **Paladin's automatic choice** -- Wisdom for a mana bar, Might otherwise --
  is pinned down.
- Writing these found that **a solo warrior is offered nobody**, because Battle
  Shout reaches the party and no further. That is correct, and is now a test
  and a line in the README rather than a surprise.
- Both new checks were mutation-tested: breaking the selfCast branch or
  swapping the Paladin mapping makes them fail.

## 1.6.0

Casting works, so the scaffolding built to find out why it did not has been
taken out. 371 lines removed.

### Removed

- **Probe mode** -- the eight-form cycler that identified `/target` + `/cast`
  as the only working path. It did its job.
- **Self-test mode** -- the bare cast that proved the spell and the button
  independently of targeting.
- **The roster cast path** -- never verified, and a guess does not belong in
  the hot path next to something proven.
- **The diagnostics ring buffer and the whole SavedVariables dump** -- the scan
  rejection tallies, name sampling, nameplate counts, aura scan counters,
  combat-log counters and the restriction report. All of it answered its
  question.
- **The combat log handler**, which cannot fire on this client at all.

### Fixed

- **UI errors were spamming chat.** Hooking `UI_ERROR_MESSAGE` reports
  everything the game raises -- "that item is not a valid target", "another
  action is in progress", "you are no longer rested" -- none of it ours. Now
  scoped to the second after our own click, and behind `/manners clicks`.
- Cast reporting is opt-in for the same reason.

### Kept, deliberately

- **`ns.Guard`** -- not debug scaffolding but the thing that makes a failure
  visible. A repeating timer whose function throws stops silently, and that is
  exactly what "the prompt never appeared" looked like from the outside.
- **The build stamp**, because a log that does not say which build produced it
  can be read for an hour before anyone notices the game never loaded the file.
- **`/manners try` and `/manners look`** -- a test console, not leftovers.

### Tests

- `tests/selftest.py` now covers five fault classes rather than three, and
  reports loudly when a refactor has moved the code a check depended on. All
  five still go red on demand.

## 1.5.0

It casts. Confirmed in game against four different players in ten seconds,
with the build stamp and form label proving which code ran:

    CLICK build=1.4.1 form=live  macro=/target Elara Brightmoor /cast Arcane Intellect /targetlasttarget
    CAST SENT 1459 -> Elara Brightmoor    CAST OK 1459
    CAST SENT 1459 -> Corvin Ashgrove  CAST OK 1459

`target=` on each line showed the original target already restored, so
/targetlasttarget works too.

### Added -- a test console

Iterating on this client otherwise costs one guess per /reload. These make it
one guess per click.

- **`/manners try <macro text>`** -- arms any macro text on the prompt.
  Tokens `{unit}` `{name}` `{first}` `{spell}` `{id}` expand against whoever is
  currently offered; `
` gives a new line. Bare `/manners try` clears it. The
  command word is matched case-insensitively but the macro text is kept
  verbatim, because it is case- and punctuation-sensitive.
- **`/manners look [unit]`** -- every API answer for a unit, and crucially
  whether each one came back as a **secret value** rather than a real one.
  "false" and "withheld" are indistinguishable after the fact, and telling them
  apart is most of the work on this client.
- **`/manners forms`** -- ready-made macros to paste into `try`.

Everything the console prints also lands in SavedVariables, so a session can be
read off disk without transcribing chat.

### Changed

- Click logging is off by default now that casting is proven. `/manners clicks`
  turns it back on.

## 1.4.1

Findings from a 109-agent investigation across the client corpus.

### Fixed

- **An emptied queue left the previous person's macro armed, and clicking cast
  at them.** `ApplyTarget`'s clear was guarded by `appliedKey ~= nil` as an
  optimisation, but `PreClick` sets `appliedKey` to nil immediately before
  calling it -- so on a click the guard was always false and the clear never
  ran. Now unconditional.

### Added

- **A build stamp and an armed-form label in every click line.** A log that
  does not say which build produced it, or which of live/probe/selftest/roster
  armed the button, can be diagnosed for an hour before anyone notices the game
  never loaded the file being read. That is not hypothetical: it happened here.
- `probeOn`, `selfTestOn` and `rosterOn` in the diagnostics dump, and a red
  DIAGNOSTIC MODE ACTIVE line in `/manners debug`. A mode with no visible state
  is a trap.
- The click line now reports what `/target` actually acquired.
- `/manners roster` -- an opt-in path that casts on group members through a
  party/raid token in `unit1` rather than targeting them. That is the one unit
  form with a working precedent in the corpus (ClassBuffReminder uses it, and
  only ever with roster tokens or "player"); Manners had only ever fed that
  form a nameplate token, which is exactly what does not resolve. Off by
  default: `/target` works, and a proven path should not be replaced by a
  guess.

### Tests

- A regression scenario for the stale-macro bug, mutation-tested: reintroducing
  the guard makes it fail with the stale macro quoted.
- **The mock clock can advance.** It was frozen, so once a scenario clicked,
  the retry cooldown never expired and every later `BuildQueue` came back
  empty -- several assertions were skipping while reporting green. Scenarios
  that cannot run now fail loudly instead of passing vacuously.

## 1.4.0

### It casts

Conditional targeting does not work on this client. Every form was probed one
per click against a real player, and every one failed the same way -- the
conditional resolves to nothing, and the cast has nowhere to go:

    [@nameplate4]            UI ERROR: You have no target
    [@nameplate4,help]       UI ERROR: You have no target
    [@Corvin Ashgrove]            UI ERROR: You have no target
    [@Papa]                  UI ERROR: You have no target
    [@focus] after /focus    UI ERROR: You have no target
    [@mouseover]             UI ERROR: You have no target
    type=spell + unit=       nothing at all

What works is hard targeting:

    /target Elara Brightmoor
    /cast Arcane Intellect
    -> CAST SENT 1459 -> Elara Brightmoor   [target then cast]
    -> CAST OK 1459

So that is what it does now, including the space in the name. Your previous
target is handed straight back with /targetlasttarget, which can be turned off
under Who to buff.

This also closes out nine earlier attempts that were all aimed at the wrong
layer. A bare `/cast` with no target casts on you perfectly well, and a `/say`
on the next line of the same macro went out fine while the `/cast` above it did
nothing -- the button, the click, the macro and the spell were never broken.
Only naming somebody else was.

### Added

- `/manners probe` cycles every targeting form, one per click, and names the
  one that lands. This is what found the answer.
- `/manners selftest` arms a bare cast with no target, which proves the spell
  and the button independently of any targeting question.
- `/manners restore` toggles handing your target back.

## 1.3.0

### The cast, again

Matched the secure button configuration to the ones that provably work on this
client, exactly rather than partially. All three of them -- MountActions,
GroupTools, CombatDungeon -- use the same trio, and the two settings go
together:

    RegisterForClicks("AnyDown")
    type = "macro"
    pressAndHoldAction = true

Registering down while leaving `pressAndHoldAction` false, which is where this
was, leaves the click arriving and the attributes reading back correctly with
nothing cast. The spell/unit attribute form is documented and did nothing here,
so it is gone; every working button on this client casts through macro text,
including the one that summons a mount.

There is no `C_ClickBindings` on this client, so Blizzard's own click-casting
route does not exist as an alternative.

### Fixed

- **The macro never tried the bare first name.** `ShortName` splits on `-`, so
  with a surname it returned the whole thing. Whether the game wants `Petra` or
  `Petra Stonewell` depends on whether the second word is a surname or part of the
  character name, which an addon cannot find out -- so both are offered now and
  the game picks whichever resolves.

  **Since retired.** That mechanism was removed: the full name does resolve
  on this client, so the failure it guarded against was never once observed,
  and offering two spellings aimed casts -- and spoken lines -- at whoever
  else shared a first name. See the note in `Core.lua` above
  `ExpirePendingClick`. Do not restore it from this entry.

- **"Buff state unreadable on this build" was shown when nothing had been
  read.** Setting *always offer* skips the aura check entirely, which left the
  state nil -- and nil rendered as the client refusing us. Choosing not to look
  and looking and being refused are now different things.
- **The favour baseline was taken too late.** The first aura scan decides what
  counts as pre-existing, and it only ran when `UNIT_AURA` next fired. Anyone
  who buffed you before that was recorded as something you already had. The
  baseline is now taken on login.
- **Range was checked by spell name**, which has to be resolved against the
  spellbook first; by id where one is known.

### Hardened

- Every fixed-value setting is validated against its set: the three-way buffed
  choice, prompt style, accent placement, flash style, both anchors, and the
  pinned buff -- which is dropped if it belongs to a class you are not. An
  unrecognised value otherwise falls through every branch that handles it into
  whatever the last `else` happens to be.
- Colours are checked for being three numbers before being read as such.

### Tests

- **`tests/scenarios.lua`** -- twelve adversarial scenarios rather than the
  happy path: a class with nothing to give, a dead player, combat lockdown, a
  client where every value is secret, a client where every API is missing, a
  profile full of values no slider could produce, the modes that must never
  cast, speech that could break the macro, and names the client might plausibly
  return. Each one drives the full lifecycle and fails on anything thrown.
- The garbage-profile scenario was mutation-tested: removing a validation makes
  it fail, which is the only evidence that a passing test means anything.

## 1.2.0

### The cast

Clicking the prompt did nothing, silently, for a long stretch of testing. The
click arrived, the button held correct attributes, and the game cast nothing and
reported nothing.

The cause: the button registered for **mouse up only**. Every secure button that
works on this client registers for **down** — `MountActions` and `GroupTools`
both use `"AnyDown"`, and one carries the comment *"force the action to trigger
on key down regardless of ActionButtonUseKeyDown"*. With up only, `PostClick`
still fires and the attributes still read back correctly, so from the outside it
is indistinguishable from a broken button.

Now registers `"AnyUp", "AnyDown"` with `pressAndHoldAction = false`.

### Fixed

- **A stale unit token could buff the wrong player.** The key that decides
  whether to rebuild the cast ignored the unit token, so a nameplate index
  handed to somebody else while the name stayed the same left the button aimed
  at whoever held it now.
- **The target is re-resolved in `PreClick`**, the last moment before the secure
  handler reads the attributes, so nothing stale can be cast at.
- **The target no longer churns.** Re-sorting every tick swapped who was offered
  while the cursor was over the prompt: the tooltip described one person and the
  button was aimed at another.
- **Names were invented.** `UnitName`'s second return is documented as the realm
  but carries a **surname** here — six players standing together came back with
  six different values. Joining them with a hyphen produced names like
  `Petra-Stonewell` that no targeting call could resolve.
- Speech rolled its phrase twice, so the line that chose the code path was not
  the line that got used.
- An unlocked or disabled prompt could still arm itself through `PreClick`.
- Macro creation assumed slot limits that differ between flavours.

### Hardened

- Nothing is offered while dead, charmed, in a vehicle, on a taxi, or out of
  mana — all of them buttons that could only fail.
- The aura cache is swept; a city put hundreds of players through it and nothing
  removed them.
- The tooltip refresher runs a few times a second rather than every frame.
- Click logging moved behind its own toggle, so ordinary use is quiet.

### Added

- **A test harness** (`tests/`) that loads the addon against a mock WoW API and
  drives its main paths. It catches calls to names that do not exist, handlers
  registered for events this client lacks, and misspelled APIs — the three
  faults that cost the most time here, none of which a syntax check can see.
  `tests/selftest.py` reintroduces each one to prove the harness still detects
  it.

## 1.1.0

Everything below came out of testing against a live client; several were faults
that could not be found by reading the code.

### Fixed

- **The scanner never started.** `OnEnable` registered `LEARNED_SPELL_IN_TAB`,
  which this client does not have. Registering an unknown event throws, and that
  line sat directly above the call that starts the scan timer — so the prompt
  could never appear for anyone.
- **Nobody was ever eligible.** Unit power comes back as a secret value for
  players outside your group, so the "has a mana bar" test failed for everyone
  and mana-only buffs were filtered out universally. Class is readable when
  power is not.
- **Favours were never noticed.** WoW Forever does not deliver
  `COMBAT_LOG_EVENT_UNFILTERED` to addons at all.
- **Everyone showed as "unverified".** `skipIfBuffed and UnitHasBuff(...) or nil`
  collapsed a definite "they do not have it" into "cannot tell".
- **Nameplate units were invisible.** `namePlateUnitToken` read off the frame is
  secret here; the token from `NAME_PLATE_UNIT_ADDED` is not.
- Preview mode and the unlocked state both looked identical to a working prompt
  while quietly disabling it.

### Added

- **If they already have the buff**: leave them alone, offer a top-up once the
  timer runs low, or always offer.
- A **Create the macro** button, and `/manners macro`.
- Attention pulse that continues until the favour is returned.
- Self-recording diagnostics written to SavedVariables.

## 1.0.0

First release.
