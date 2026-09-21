# Changelog

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

    CLICK build=1.4.1 form=live  macro=/target Dunstan Mirren /cast Arcane Intellect /targetlasttarget
    CAST SENT 1459 -> Dunstan Mirren    CAST OK 1459
    CAST SENT 1459 -> Elara Rowena  CAST OK 1459

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
    [@Papa Brannock]            UI ERROR: You have no target
    [@Papa]                  UI ERROR: You have no target
    [@focus] after /focus    UI ERROR: You have no target
    [@mouseover]             UI ERROR: You have no target
    type=spell + unit=       nothing at all

What works is hard targeting:

    /target Petra Alric
    /cast Arcane Intellect
    -> CAST SENT 1459 -> Petra Alric   [target then cast]
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
  with a surname it returned the whole thing. Whether the game wants `Vann` or
  `Vann Lock` depends on whether the second word is a surname or part of the
  character name, which an addon cannot find out -- so both are offered now and
  the game picks whichever resolves.
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
  `Corvin-Ysolde` that no targeting call could resolve.
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
