# Audit, 2026-09-21

Produced by 37 agents: five lenses over UX, the options page, code, bugs and
robustness; four independent feature slates; three judges scoring them; and
adversarial verification of every claimed bug.

- findings raised: 103
- bugs confirmed after verification: 20
- features proposed: 27
- features a majority of judges would build: Offer the buff they're actually missing, not the one you pinned, Your target wins, A click that did not cast must not burn the person, Debts survive a reload, One profile per class, automatically, Right-click to skip this one, The wordless thank-you

Kept in the repository because it is a work queue, not a report. Most of it is
not done.

---

I read the current tree, not the audit's snapshot. That matters: commit `c378114` ("Fix eight bugs found by audit") already landed, so a third of the supplied bug list is fixed in the files as they stand. The plan below covers only what is still true at `D:/Projects/WOW_Addons/Manners` today.

---

# ALREADY FIXED — do not re-fix

Verified in the working tree; the audit ran against `*.lua.bak`.

| Reported bug | Now |
|---|---|
| "Only count real class buffs" is dead | Wired, `Core.lua:824-829` |
| Warriors can never get a prompt | Gated on `myMax > 0`, `Core.lua:625-629` |
| Pinned buff resets on login | Probe before clamp, `Core.lua:1242-1243`; `caps.class` guard at `Core.lua:1204` |
| ScanOwnBuffs stops at first unreadable aura | Tolerates 3 misses, `Core.lua:807-833` |
| `/manners restore` undocumented-but-advertised | Implemented, `Core.lua:1371-1375` |
| Click settles a debt that never cast | `ns.pendingClick` + `SettlePendingClick`, `Prompt.lua:293`, `Core.lua:880-895` |
| Two clicks in 250 ms cast twice | Left-button-only guards, `Prompt.lua:243-244`, `266-267` |
| Roll-a-few previews at 200, macro allows 120 | `ns.PHRASE_BUDGET`, `Core.lua:521`, used at `Prompt.lua:747` and `Options.lua:533` |

Two audit claims were **wrong about the current code** and one of them hides a live bug: `ApplyTarget` sets `type`/`macrotext` unsuffixed as well as `type1`/`macrotext1` (`Prompt.lua:765-768`). See Bug 1.

---

# 1. THE ONE FEATURE — "Offer the buff they're actually missing"

## Why this one

It is not an addition. For five of six classes the addon currently fails at its stated job. `ns.ResolveBuff` (`Core.lua:274-292`) consults the pin, then `ns.CLASS_AUTO` — which has a single PALADIN entry (`Buffs.lua:109-111`) — then `FirstKnownBuff` (`Core.lua:267-271`), which returns list position 1. `BuildQueue` calls it **once per unit** at `Core.lua:653` and checks that one buff at `Core.lua:671`.

Consequence, today: a priest never offers Divine Spirit or Shadow Protection. A druid never offers Thorns. A paladin who has already blessed someone offers to bless them again, because the `has` check only tests the one resolved buff. And the default `whenBuffed = "skip"` (`Core.lua:100`, applied `Core.lua:676-687`) *drops the person from the queue entirely* the moment they hold buff #1 — so being partially buffed makes you invisible to the addon.

Against the runners-up: "Your target wins" changes *who* is offered; this changes whether the offer is *correct*. "Debts survive a reload" recovers state the addon already had. This one recovers behaviour it never had. It also needs no new API — `UnitHasBuff` already takes a buff argument and caches on `guid .. buff.key` (`Core.lua:325-354`, key at `:330`), so the machinery for many buffs per unit exists and nothing has ever asked it for a second one.

## What the user sees

Nothing new on screen, which is the point. The sub-line already defaults to `"needs {buff}"` (`Core.lua:145-146`) and `Substitute` already expands `{buff}` (`Prompt.lua:656`); the icon already comes from `entry.buff` (`Prompt.lua:830-832`). So a priest clicking the same person three times sees the icon and the sub-line step Fortitude → Divine Spirit → Shadow Protection, same name, same panel.

Do **not** change the `reasonOwed` default to name the buff. At the 220 px default width (`Core.lua:118`) it will not fit, and the icon already says which spell.

## Behaviour

Replace the single resolve at `Core.lua:653` with a walk, per unit:

1. **Pin still wins.** If `db.buff.choice ~= "auto"`, behave exactly as today — one buff, no walk. The pin means "only ever this".
2. **Exclusive classes short-circuit.** New table beside `CLASS_AUTO`: `ns.EXCLUSIVE_BUFFS = { PALADIN = true }`. For these, if the unit has *any* of your class buffs, they are covered — return nothing. Otherwise offer the `CLASS_AUTO` pick (`Buffs.lua:110`). Vanilla blessings overwrite each other, so a paladin walking six would fight itself. For a paladin this feature is therefore "stop re-blessing somebody who already holds one of yours" rather than a rotation, which is itself a real fix.
3. **Everyone else walks the class list in `Buffs.lua` order**, taking the first buff that passes: `ns.IsBuffKnown`; not in `db.buff.skip`; the `manaOnly`/`relevantOnly` test currently at `Core.lua:657-659`; the `partyOnly` test at `Core.lua:662`; not blocked by `tried` (see keying below); and `UnitHasBuff(unit, buff, guid) ~= true`.
4. **Two passes when `whenBuffed == "refresh"`.** Pass 1 takes a buff they lack outright. Only if pass 1 finds nothing does pass 2 take a buff whose `remaining` is under the threshold. Missing beats expiring, always.
5. **Degrade honestly.** Where `info.readable` is false (`Core.lua:215`) or `whenBuffed == "always"`, there is no aura truth, so rotate: offer the buff after the one last given to that name, from a session table `ns.lastGave[name] = buffKey` swept in `TickBody` alongside `owed`/`tried` (`Core.lua:1298-1303`). Never rotate for an exclusive class — re-blessing is destructive, so a paladin with unreadable auras keeps today's single-buff behaviour.
6. **The tokenless owed fallback (`Core.lua:722-741`) does not walk.** No token means no aura read and no evidence; one buff per favour is the right semantics there. It gets the filter fix in Bug 2 instead.

## What it stores

Only `db.buff.skip = {}` — a sparse set of buff keys the user has switched off. Sparse matters: AceDB stores nothing until it is non-empty, so no migration and no profile churn. Keys are class-unique (`"might"` only exists for Paladin), so a profile shared across characters cannot collide.

**`auto` changes meaning** rather than gaining a sibling value. `"auto"` is the declared default (`Core.lua:85`) and is therefore absent from every saved profile, so every existing user gets the improvement with zero migration code.

## The one change that is load-bearing elsewhere

`ns.tried` is keyed by bare name — written `Prompt.lua:294`, read `Core.lua:649` and `Core.lua:729`. Left alone, casting Fortitude blocks that person for `retryCooldown` (12 s) and the walk never reaches Spirit. It must become two keys:

- `ns.tried[name .. "\0" .. buffKey]` — set in `PostClick` for the buff that was actually armed; the full `retryCooldown`.
- `ns.tried[name .. "\0*"]` — a short whole-person block, set only by `SettlePendingClick(false)` (`Core.lua:892`) when the game says nothing was cast. Without it, a person behind a pillar makes the prompt march down your entire buff list failing at each one.

`BuildQueue` checks the wildcard once per unit and the per-buff key inside the walk. This also makes the rotation correct despite the 3-second aura cache (`Core.lua:332`): the buff just cast is blocked by `tried` regardless of whether the cache has caught up.

## APIs used

None that are new. `C_UnitAuras.GetUnitAuraBySpellID` via the existing `UnitHasBuff`, `ns.GetClassBuffs`, `ns.IsBuffKnown`. No protected call, no conditional targeting, no chat events, nothing unverified on this client.

## What could go wrong

- **Cost.** A paladin is exclusive so it short-circuits; a priest is the worst realistic case at three buffs × up to six ranks. `UnitHasBuff` breaks on the first hit (`Core.lua:337-347`), so the expensive shape is "has none of them". Mandatory companions: hoist the buff-list resolve out of the per-unit loop (it currently runs per unit at `Core.lua:653`), move the `sources.group`/`sources.strangers` gates from `Core.lua:690-691` to *before* the aura read at `Core.lua:671`, and make `auraCache` two-level (see Code).
- **Unreadable auras re-give a buff someone already has.** True, and already true today; the rotation makes it visible rather than new. It raises the weight of the "unverified" wording (`Core.lua:147`, `Prompt.lua:663-665`), which is why the wording work in section 5 is on the same release.
- **Mana.** Three buffs per person rather than one. No mitigation needed — the user clicks what they click — but the per-buff toggles exist for exactly this.
- **`seen[full]`** (`Core.lua:648`, `696`) must stay. One person appears once per build, holding one buff; the next build offers the next one. That is what makes "click three times" work rather than producing three queue rows for one person.

## Tests

`tests/mockapi.lua:236` returns `nil` from `GetUnitAuraBySpellID` unconditionally, so no scenario can currently exercise any of this. Change it to `function(_, id) return Mock.auras[id] and { expirationTime = Mock.now + 600 } or nil end` with `Mock.auras = {}` in `Mock.reset()`. Then add, in the shape of `tests/scenarios.lua:500-560`:

1. Priest knows all three, target holds Fortitude → queue offers `spirit`.
2. Target holds Fortitude + Spirit → offers `shadow`.
3. Target holds all three → not offered at all.
4. Paladin, target holds `kings` → offered nothing (exclusivity).
5. After `PostClick` on Fortitude, the next `BuildQueue` offers `spirit` to the same name (proves the `tried` re-key).

Mutation-test 1 and 4: reverting the walk must make 1 fail, and removing `EXCLUSIVE_BUFFS` must make 4 fail.

---

# 2. SECOND AND THIRD

**Second — "Your target wins."** Add priority 0 above `owed` in `PRIORITY` (`Core.lua:564`) when `entry.unit == "target"`, with its own `REASON_COLOR`/`REASON_KEY` entry (`Prompt.lua:38-44`) and wording input. `IterateUnits` visits `target` first (`Core.lua:567`) but that is iteration order only — the sort at `Core.lua:743-749` keys purely on priority, so a deliberately targeted player is "nearby" at priority 3 and loses to every owed name. `PickTop` cooperates: it only retains the current pick when `candidate.priority <= top.priority` (`Prompt.lua:692`). Gate it on the target actually missing the buff, and leave `mouseover` out — at the 0.4 s scan the prompt would flicker as the cursor crosses the screen. *Not first because it changes who is offered, not whether the offer is right, and it gets better once the walk exists.*

**Third — "Debts survive a reload."** `owed` is plain memory (`Core.lua:560`) while `reciprocateWindow` runs to 600 s (`Core.lua:1150`). Serialise into `MannersDB` on logout, read back in `PLAYER_ENTERING_WORLD` (`Core.lua:851`), per character. The whole job is the clock: entries hold `GetTime()`-relative `expires`/`at` (`Core.lua:791`), so store wall-clock `time()` and rebase on read — *including* the `graceSeconds` check at `Core.lua:726`, or every restored debt is stale on arrival and the feature does nothing for the case that motivates it. Wrap the read in `ns.Guard`. *Not first because it restores state the addon already had, and it should land after Bug 3 so it is not persisting debts that were settled against the wrong person.*

Free rider on Bug 1: once the non-left buttons stop casting, **right-click = skip this one** is about ten lines in `PostClick` (`Prompt.lua:266`), which already receives the button name and discards it. Record into `tried[name .. "\0*"]` and return before the `pendingClick` lines so declining somebody never marks their favour repaid. `PreClick` already returns early for non-left buttons, so there is no ordering hazard.

---

# 3. REJECT

- **Chat scanning ("fort plz" bumps them to the top").** Nothing in this codebase registers a `CHAT_MSG_*` event and `tests/mockapi.lua` stubs none. On a client that hides `UnitPowerMax` for non-group players and the entire combat log, "do these fire and is the sender a plain string" are open questions. Worse, a false positive hard-targets a stranger and can speak in their direction through the macro. And it changes what Manners is: noticing what was given to you, not running a request queue. "Your target wins" covers the case where you noticed, at a tenth of the risk.
- **Whisper in the macro.** `/w Vann Lock hello` parses `Vann` as the recipient and `Lock hello` as the message. The proposed guard — only when `ns.FirstName` returns nil (`Core.lua:425-430`) — excludes every two-word name, which per `Core.lua:640-645` is most of them here. Off for the majority while still carrying the risk.
- **Arbitrary `/`-prefixed pass-through in the phrases box.** `SanitizePhrase` (`Core.lua:523-528`) feeds a secure button's macrotext. Phrase sets get copied between players; letting any line starting with `/` through verbatim turns a shared text blob into an arbitrary command that runs on click. If targeted emotes are wanted, an allow-list (`thank`, `bow`, `wave`, `salute`, `cheer`) inserted before `/targetlasttarget` at `Prompt.lua:750-752` reaches the same `/bow` for none of the exposure — and costs ~7 characters against the 255 budget versus ~40 for a spoken line.
- **The ledger / Regulars / persistent mute — anything keyed on player identity across sessions.** The key for a passer-by is `name .. " " .. second` (`Core.lua:644-645`) where `second` is a *surname*, not a realm, as the code itself records at `Core.lua:640-643`. `UnitGUID` is absent for the tokenless owed case entirely (`Core.lua:730-738` builds those entries from a name). A wrong tally is invisible; a wrong "paying you back" on a stranger's face is the one output the user will actually read, and a wrong permanent mute is undiscoverable. Reject all three until GUID stability across sessions has been measured with `/manners look`.
- **The three-strikes auto-cool.** Only honest where `info.readable` is true (`Core.lua:215`); everywhere else it penalises people at random.
- **The grace bar.** Only `owed` entries carry timestamps (`Core.lua:791`), so the bar is absent on most prompts, and an element that appears only sometimes reads as a rendering bug. Steal one line from it: replace the hard `button:Hide()` at `Prompt.lua:906` with a short Alpha fade of the kind already built at `Prompt.lua:350-360`.
- **The second icon showing what they gave you.** At 220 px with a 30 px icon, `textX = 10 + iconSize + 10` (`Prompt.lua:566`) and a count chip already competing, there is no room. Take the *data* half instead — it is a bug fix, and it is Bug 2.
- **Splitting `speech.phrases` into owed/nearby pools.** `onlyWhenReturning` (`Core.lua:533`) already silences the stranger case for anyone who turns speech on. A second multiline box and a migration for that is not worth the Speech tab doubling in height.

---

# 4. BUGS TO FIX NOW, IN ORDER

### Bug 1 — Any mouse button still casts
`ApplyTarget` writes the **unsuffixed** `type`/`macrotext` as well as `type1`/`macrotext1` (`Prompt.lua:765-768`, and again for `/manners try` at `731-732`), and unsuffixed attributes are the fallback for every button. `RegisterForClicks("AnyDown")` (`Prompt.lua:100`) delivers all of them. The 0.9.5 fix stopped the *bookkeeping* running on a right-press (`Prompt.lua:243-244`, `266-267`) but did not stop the *cast*: right-pressing to turn the camera over the panel fires the buff, with no re-resolve in `PreClick`, no `tried`, and no `pendingClick` — so the same person keeps being offered and can be cast at repeatedly.

**Fix.** Do **not** simply delete the unsuffixed attributes: `CHANGELOG.md` 1.3.0 records that `type = "macro"` unsuffixed is the form copied from the buttons that provably work on this client, and removing it risks the one thing that was hardest to get working. Instead neutralise the other buttons explicitly — `button:SetAttribute("type2", "none")` through `type5` in `ApplyTarget`, and add `type2..type5`/`macrotext2..5` to the clear list at `Prompt.lua:710-712`. An unrecognised type string matches nothing in the secure handler. Verify first with `/manners clicks` on: right-press the prompt; a `CAST SENT` line means this is live.

### Bug 2 — The owed grace-window path bypasses the filters the main path applies
`Core.lua:722-741` takes `fallback = ns.ResolveBuff(true)` unconditionally and applies none of: `relevantOnly`/`manaOnly` (`Core.lua:657-659`), `IsBuffableUnit`'s dead/disconnected/`minLevel` rejections (`Core.lua:379-393`), or `requireInRange`. A warrior who Battle Shouts you is rejected by the main path at `657-659` — **before** `seen[full] = true` at `696` — and re-added by the fallback holding Arcane Intellect, at priority 1, ahead of everyone. A level-5 priest rejected by `minLevel` comes back the same way, as does someone who has died since.

The same entries also carry no `class` field, unlike the live-unit path at `Core.lua:701`, so `ClassColored` (`Prompt.lua:644-649`) silently does nothing for exactly the passer-by the addon exists for.

**Fix.** In `NoteFavour`, store `class = plain(select(2, UnitClass(source)))` beside the existing `guid` (`Core.lua:791-792`). In the fallback, resolve per entry with `ns.ResolveBuff(MANA_CLASSES[entry.class] ~= false)` — `MANA_CLASSES` is a file local at `Core.lua:358`, same scope — apply the `relevantOnly`/`manaOnly` rejection, and copy `class` onto the queue entry. Factor the shared rejections into one predicate so the two paths cannot drift again.

### Bug 3 — A cast that landed on the wrong player still counts as the favour returned
`/target <name>` that resolves nothing is a no-op: it does not clear your target, so `/cast` (`Prompt.lua:743-744`) lands on whoever you already had. `UNIT_SPELLCAST_SENT` then fires and `SettlePendingClick(true)` (`Core.lua:897-899`) deletes the debt without ever looking at `target` or `spellId`, both of which are sitting unused in the handler's parameters. `tried` is already set. Nothing is printed unless `debugClicks` is on. The favour is gone and a stranger got your buff.

Note also a **regression**: `CHANGELOG.md` 1.3.0 states the macro offers both the bare first name and the full name so the game can pick whichever resolves. `Prompt.lua:743` emits only `/target entry.name`; `ns.FirstName` now survives solely in `ExpandTokens` (`Core.lua:1130`). The fix was lost in the 1.6.0 cleanup.

**Fix.** Two parts, both cheap. (a) Store `buffKey` in `ns.pendingClick` (`Prompt.lua:293`) and make `SettlePendingClick` require both that `plain(spellId)` is in that buff's `ranks` and that `plain(target)` matches the pending name, its `ShortName` or its `FirstName`; on mismatch keep the debt, drop `tried` to ~2 s, and print the actual recipient when `verbose` is on. `CHANGELOG.md` 1.5.0 shows `CAST SENT 1459 -> Elara Brightmoor`, so `target` is a plain readable string in practice. (b) Restore the first-name line: `/target <first>` then `/target <full>` before `/cast`, unconditional and in that order, so the more specific form wins when it resolves and the bare one is the fallback. ~15 characters against a 255 budget checked at `Prompt.lua:757`.

### Bug 4 — Every loading screen can invent favours
`PLAYER_ENTERING_WORLD` (`Core.lua:851-862`) calls `ScanOwnBuffs` without touching `knownAuras` or `auraScanPrimed` (`Core.lua:772-773`). Either the client renumbers `auraInstanceID`s across a zone, or a transitional scan reads non-table at indices 1-3, breaks at `Core.lua:809-811` with `present = {}` and the prune at `835-837` empties `knownAuras`. Either way every held buff looks brand new, the gate at `826` passes because `auraScanPrimed` is still true, and `aura.sourceUnit` resolves to the party member standing next to you. You get an amber priority-1 pulsing prompt and a "X buffed you" line for a favour that never happened.

**Fix.** Add `ns.ResetAuraBaseline()` next to the two upvalues at `Core.lua:772-773` doing `wipe(knownAuras); auraScanPrimed = false`, and call it immediately before `ScanOwnBuffs` at `Core.lua:857`. That makes the post-zone pass a real baseline, which is what the comment at `855-856` already claims it is.

### Bug 5 — The keybinding is an up-click on a down-only button
`Bindings.xml:4` calls `prompt:Click()`, i.e. `Click("LeftButton", false)`. The button registers `"AnyDown"` only (`Prompt.lua:100`), and the whole 1.2.0/1.3.0 history says an up-delivery does not cast here. This is the *first* route the options panel recommends (`Options.lua:138-140`) and the README repeats it.

**Fix.** `prompt:Click("LeftButton", true)`. Print a line when `not prompt:IsShown()` so a keypress is never a mystery. Until it has been tested in game, swap `Options.lua:138-140` to lead with "Create the macro" and describe the keybinding as the alternative — `Core.lua:984-987` already calls the `/click` macro the dependable route.

### Bug 6 — Speech silently dies on any new, copied or reset profile
The phrase backfill lives only in `OnInitialize` (`Core.lua:1234-1237`). `OnProfileChanged`/`Copied`/`Reset` (`Core.lua:1229-1231`) route to `RefreshConfig` → `ClampSettings` (`Core.lua:1307-1308`), which repairs `format`, `channel`, `whenBuffed`, anchors, styles, the pinned buff and the colours (`Core.lua:1179-1215`) and never touches `speech.phrases`. A fresh profile gets `""`, `PickPhrase` returns nil at `Core.lua:543`, the macro goes out with no `/say`, and the "Load a set" dropdown still reads "Roleplay" (`Options.lua:492`) over an empty box. It stays broken until the next `/reload`.

**Fix.** Move the backfill into `ClampSettings` — it is the same class of repair as the `format`/`channel` lines already there.

### Bug 7 — The unlocked prompt is shown even when the addon is disabled
`Refresh` handles `not p.locked` at `Prompt.lua:872-883` and returns at `882`, before the `not db.enabled` block at `885-890`. `/manners unlock` then `/manners off` leaves "Drag to move" on screen on every subsequent refresh until a lock or a reload.

**Fix.** Move the `not db.enabled` block above the `not p.locked` block. Disabled always wins.

### Bug 8 — The pulse keeps breathing in combat after the debt is settled
`Refresh` returns at `Prompt.lua:896` whenever `InCombatLockdown()`, never reaching the `StopAttention` branch at `931-935`. `TickBody` sweeps the expired `owed` entry at `Core.lua:1298-1300`, but the looping BOUNCE group keeps running on a settled debt for the rest of the fight.

**Fix.** Before the early return, reconcile against the frozen `current`: if it is nil or `ns.owed[current.name]` is gone, call `self:StopAttention()`. That touches only `glowFrame`, which lives on `art`, so it is legal in combat.

### Bug 9 — Verbose announces favours from a source that is switched off
`NoteFavour` never consults `db.sources.owed`: it writes `owed[full]` and prints "X buffed you — returning the favour is on the prompt" (`Core.lua:791-795`). With the source off, `isOwed` is false at `Core.lua:672` and the fallback loop is skipped entirely at `722`, so nothing ever reaches the prompt and the printed line is a lie. `/manners debug` then lists them as "owes returning" (`Core.lua:1411-1418`) with no mention of the setting, and `TickBody` sweeps a dead table every tick.

**Fix.** Return early from `NoteFavour` when `not db.sources.owed`, before the write and the print.

### Bug 10 — The minimap button stays bound to whichever profile was loaded first
`LDBIcon:Register(ADDON, dataObject, ns.db.profile.minimap)` at `Options.lua:796` captures that profile's sub-table once. `RefreshConfig` (`Core.lua:1307-1312`) never touches LDBIcon, so after a profile switch the checkbox reads one profile and the button obeys another — and a drag writes `minimapPos` into a table AceDB has already detached, so the position is saved for neither.

**Fix.** In `RefreshConfig`, re-point the registered object's db at `ns.db.profile.minimap` and call `Show`/`Hide` to match `hide`.

### Bug 11 — "Play a sound" plays nothing
`sound.file` defaults to `"None"` (`Core.lua:160`) and `Prompt.lua:926` tests `db.sound.file ~= "None"`. Ticking the toggle produces silence, which is indistinguishable from a broken addon.

**Fix.** Default to a real LSM entry. Add a `set` on the file select (`Options.lua:161-169`) that plays the chosen sound immediately. If the user deliberately picks "None", show a red line under the toggle saying the sound is off.

---

# 5. UX AND DESIGN, BY HOW MUCH IT IS FELT

1. **The prompt strobes in a crowd.** `Refresh` hides, re-shows, replays the intro (`Prompt.lua:919-920`) and replays the sound (`926-929`) every time the top candidate churns, at 2.5 Hz. Add three pieces of hysteresis: record `shownAt` when a candidate is painted and refuse to swap to an equal-or-lower priority for ~1.5 s; on an empty queue start a ~0.75 s fuse instead of the immediate `button:Hide()` at `906`, cancelling on refill; keep a `lastSoundAt` with a ~3 s floor.
2. **Nothing confirms the click worked.** Every ingredient exists — `ns.pendingClick`, `ns.lastClickTime`, `UNIT_SPELLCAST_SENT` with its `target`, `UI_ERROR_MESSAGE` (`Core.lua:897-932`) — and all of it is thrown away unless `debugClicks` is on. On a confirmed settle, fill the panel with the accent colour at low alpha and swap the name line to `✓ Bob` for ~0.6 s using the existing `textLayer.swap` (`Prompt.lua:364-376`); on an error in the same window, flash red and put the game's own reason in the sub-line. This is the visible half of Bug 3.
3. **The default position is in the middle of the play area.** `CENTER`, `y = -140` (`Core.lua:114-117`) puts a click-stealing panel over the world — and, until Bug 1 lands, one that casts on a right-press. Default to `BOTTOM`/`BOTTOM`, `y ≈ 300`, just above the action bars, and add three position presets (above action bars / under minimap / centre) so moving it does not need the unlock-drag-lock dance.
4. **In combat the prompt shows a stale person while looking completely live.** `Prompt.lua:892-897`. Register `PLAYER_REGEN_DISABLED` (not currently in the list at `Core.lua:1255-1269`), drop `art:SetAlpha` to ~0.55, blank the queue rows, set the sub-line to "held — in combat", and hide the tooltip. `PLAYER_REGEN_ENABLED` already re-applies the style (`Core.lua:946-950`).
5. **Preview self-destructs after 20 s, and instantly in any populated area.** `TEST_SECONDS = 20` (`Prompt.lua:792`) and the exit-on-real-candidate rule at `849-856` mean you cannot style the prompt in a city at all. Keep preview alive while the options window is open (AceConfigDialog fires a close callback), apply the exit rule only when it is shut, make the label dynamic — `name = function() return ns.Prompt:InTest() and "Stop preview" or "Preview" end` — and move it to the top of the Prompt tab.
6. **Time sliders show bare numbers and silently mix units.** `graceSeconds`, `reciprocateWindow`, `retryCooldown`, `scanInterval` are seconds; `refreshUnder` is minutes (`Core.lua:101`). AceConfig ranges have no suffix field, so the unit goes in the name: "Remember a buff for (seconds)", "Wait before re-offering (seconds)", "Scan every (seconds)", "Top up when under (minutes) are left", and rename `graceSeconds` to stand alone as "Let them go after (seconds)".
7. **Duplicate `order` values put dependants beside the wrong control.** `reachableOnly` is 23 (`Options.lua:331`) and `whenBuffed` is also 23 (`353`); `graceSeconds` is 24 (`340`) and `refreshUnder` is also 24 (`368`). AceConfig then tie-breaks on name, so "...after this long" can render under "If they already have the buff". Renumber uniquely: `reachableOnly` 23, `graceSeconds` 23.5, `whenBuffed` 24, `refreshUnder` 24.5, `alwaysNote` 25, `minLevel` 26.
8. **"Only players in range" does not restrict to players in range** — its own description says so (`Options.lua:304-312`), and the label is what people read. Rename to "Hide players known to be out of range", desc "When the game will not tell us the range — common on this client — they are still offered." Give `minLevel` (`383-392`) a description; it has none.
9. **The sound fires for strangers while the flash fires only for owed.** `Prompt.lua:926` versus `931`. Give sound the same reason filter, or a "Only when somebody buffed me" sub-toggle defaulting on, and put the Sound group next to `flashStyle` under one "Getting your attention" header instead of stranding it on General.
10. **Turning off all three sources leaves a permanently empty prompt with no warning.** Add a description under the Sources header with `hidden = function() local s = S(); return s.owed or s.group or s.strangers end` reading "Nothing is selected, so the prompt will never appear." Same for `enabled = false`.
11. **Diagnostics shows capabilities but never the errors the addon caught.** `ns.errors` (`Core.lua:57-64`) is never surfaced; the block at `Options.lua:208-227` shows only the capability dump. Add a hidden-when-empty list of the last five as `HH:MM:SS where — err`, plus a "Copy for a bug report" execute opening a read-only multiline box with those lines and `ns.BUILD` — which appears nowhere on the options page today.
12. **"Announce every buff it sees" is on by default and reads like it talks to other players** (`Options.lua:186-196`). Rename to "Print a line in my chat when someone buffs me", lead the description with the local-only fact, and move it out of Diagnostics into a small Chat group.
13. **The tooltip's "Will run" is not the macro that will run.** `ns.lastMacro` is rebuilt on every `ApplyTarget`, and `PickPhrase` re-rolls `math.random` each time (`Prompt.lua:747`, `Core.lua:545`), so the quoted `/say` line changes 2.5 times a second and again in `PreClick` (`Prompt.lua:263`). Cache the phrase on the entry when it first becomes current. Lead the tooltip with plain English — "Targets Bob, casts Arcane Intellect, then restores your target" — and move the raw dump behind `debugClicks`.
14. **Queue rows are unreadable and fall off the screen.** They hang below the panel with no background (`Prompt.lua:611-617`, painted `937-941`). Extend the panel behind them with a 1 px hairline, flip the anchor above the button when its centre is in the lower third of the screen, and prefix each row with a 3 px bar tinted by `REASON_COLOR[entry.reason]` so priority is legible without reading.
15. **Two prompt settings can be set to values that break each other.** `iconSize` can exceed `height` (`Options.lua:720-730`), and `showSub` silently does nothing under 34 px (`Prompt.lua:583`) with only a `desc` to say so. Give `iconSize` `max = function() return math.max(12, P().height - 8) end` and add a description under `showSub`, shown only when it is on and the height is short.
16. **"Colour the stripe by reason" controls the icon ring.** `accentMode` defaults to `"icon"` (`Core.lua:126`) and sits at order 15 (`Options.lua:621`), *after* the two colour pickers it governs. Reorder to `accentMode` 11, `accentByReason` 12, `accentColor` 13; rename to "Where the reason colour goes", "Colour it by reason", "Accent colour"; and note in the `accentMode` desc that the Blizzard look has no stripe (`Prompt.lua:516`).
17. **Every Prompt-tab control silently does nothing in combat.** `ApplyStyle` returns at `Prompt.lua:479-482`. Add a description at the top of the tab with `hidden = function() return not InCombatLockdown() end` saying the changes are saved and will appear when combat ends, and clear it with `AceConfigRegistry:NotifyChange` on `PLAYER_REGEN_ENABLED`.
18. **"Load a set" wipes hand-written phrases with no confirmation** (`Options.lua:493-499`) while "Reset position" has one (`573`). Add `confirm` to the preset select and drop it from Reset position.
19. **"Automatic" only explains itself for Paladin** (`Options.lua:81-90`). With the walk shipped it becomes: "Automatic offers the first of these they are missing: Fortitude, Divine Spirit, Shadow Protection." For a pinned buff that is not learned, add a red line naming what will actually be cast via `ns.ResolveBuff(true)`.

---

# 6. THE OPTIONS PAGE, RESTRUCTURED

Current shape has four jobs on the "Who to buff" tab (which buff, which sources, which filters, timing), and Sound + Minimap + Diagnostics stacked under General. `restoreTarget` is filed under Filters and is not a filter. Proposed layout in full:

**Tab 1 — General** *(order 1)*
- `enabled` (1) · `noBuffs` notice (2) · `howItWorks` (3)
- header **Getting started** (10): `makeMacro` (11), `keybindingNote` (12, describing the binding as the alternative until Bug 5 is verified)
- header **Minimap** (20): `minimap` (21)
- header **Chat** (30): `verbose`, renamed (31)

**Tab 2 — Who to buff** *(order 2)*
- header **Buffs** (1): `choice` (2, "Whatever they are missing" / pinned spells) · `autoNote` (3, naming the real order) · per-buff toggles `offer_<key>` (4.1…4.n, hidden unless `choice == "auto"` and the class has more than one)
- header **Sources** (10): `emptyWarning` (10.5) · `owed` (11) · `owedClassBuffsOnly` (12) · `group` (13) · `strangers` (14) · a one-line note naming the resolved buff, and for a `selfCast`/`partyOnly` class (Warrior) hiding `strangers` outright
- header **Who to skip** (20): `relevantOnly` (21) · `requireInRange`, renamed (22) · `reachableOnly` (23) · `graceSeconds` (23.5) · `minLevel` (24)

**Tab 3 — When** *(order 3)*
- header **Already buffed** (1): `whenBuffed` (2) · `refreshUnder` (3) · `alwaysNote` (4)
- header **Timing** (10): `reciprocateWindow` (11) · `retryCooldown` (12) · `scanInterval` (13) — all with units in their names

**Tab 4 — When you click** *(order 4)*
- header **Targeting** (1): `restoreTarget` (2) · a short note on the `/target … /cast … /targetlasttarget` macro and why conditionals are not used
- header **Speech** (10): `intro` (11) · `enabled` (12) · `channel` (13) · `onlyWhenReturning` (14)
- header **Phrases** (20): `preset` with `confirm` (21) · `phrasesHelp` (22, quoting `ns.PHRASE_BUDGET`) · `phrases` (23) · `roll` (24) · `limits` (25)

**Tab 5 — Prompt** *(order 5)*
- `test` (1, dynamic label) · `locked` (2) · `reset` (3) · `combatNotice` (0.5, hidden out of combat)
- header **Style** (10): `accentMode` (11) · `accentByReason` (12) · `accentColor` (13) · `style` (14) · `bgColor` (15)
- header **Getting your attention** (20): `flashStyle` (21) · `soundEnabled` (22) · `soundFile` (23) · `soundOwedOnly` (24)
- header **Position and size** (30): presets (31) · `x` `y` `width` `height` `scale` `alpha` (32-37) · `hideInCombat` (38)
- header **Text** (40): `format` · `showSub` (+ short-height notice) · `formatHelp` · the four reason inputs · `font` · `fontSize` · `fontColor` · `classColor`
- header **Icon and queue** (50): unchanged, with `iconSize`'s max bound to `height`

**Tab 6 — Diagnostics** *(order 6)* — `debugClicks`, the capability dump currently at `Options.lua:208-227`, the last five `ns.errors`, `ns.BUILD`, and a copy-for-a-bug-report box.

**Tab 7 — Profiles** *(order 90)* — unchanged.

---

# 7. CODE WORK

**Worth doing**

- **Two-level `auraCache`.** `auraCache[guid][buffKey]` instead of `guid .. key` strings. `UNIT_AURA` currently builds one string per class buff per unit per aura event (`Core.lua:844-848`) — six per event for a paladin, constant in a raid. Invalidation becomes `auraCache[guid] = nil` with zero concatenation and an early-out when the guid was never cached. Touches `Core.lua:311`, `330`, `350-351`, `314-320`, `846-848`.
- **Hoist the buff resolve out of the per-unit loop.** `ns.ResolveBuff` runs per unit at `Core.lua:653`. Resolve the mana and non-mana lists once before `IterateUnits` and return `{}` immediately when both are empty. This becomes mandatory with the walk.
- **Reorder `BuildQueue`'s rejections cheapest-first.** The `sources.group`/`sources.strangers` gates sit at `Core.lua:690-691`, after the aura read at `671` and before the range check at `693`. Compute `inGroup` and `reason` right after the `owed` lookup and reject there. Cache `InRange` per guid for a tick — it is three `pcall`s per unit per tick (`Core.lua:397-411`).
- **Restore `appliedKey`'s meaning, or delete it.** It is assigned in four places (`Prompt.lua:262`, `714`, `734`, `774`) and compared in none, so `ApplyTarget` rebuilds a macro and pushes four `SetAttribute`s 2.5 times a second. Give it `table.concat({entry.name, entry.buff.key, entry.reason, tostring(ns.tryMacro)}, "\1")`, return early on a match, and keep the *clear* path unconditional — that asymmetry is the 1.4.1 bug and must not come back. Otherwise delete it along with `InvalidateMacro` and its four callers.
- **One rule for the speech budget.** Assemble the cast/target/restore lines first, then call `PickPhrase` with `ns.MACRO_LIMIT - #table.concat(lines, "\n") - 1`, and delete the after-the-fact drop at `Prompt.lua:757-763`. `ns.PHRASE_BUDGET = 120` (`Core.lua:521`) is a magic number fighting a second, correct check immediately below it.
- **Extract `UnitFullName(unit)`.** The `plain()`-both-returns-then-join dance is duplicated verbatim at `Core.lua:636-645` and `784-788`, including the comment explaining why. One function next to `ShortName` (`Core.lua:415`), returning nil when the name is unreadable or macro-unsafe.
- **`ns.MarkAttempted(name, buffKey)` and `ns.SettleFavour(name)`.** `Prompt.lua:293-294` reaches into Core's `owed`/`tried` and encodes the expiry convention in the wrong file. With the per-buff re-keying in the feature, that convention gets more complex, so it needs one owner.
- **Per-label `ns.shouted`.** `Core.lua:65-70` announces the first failure of the session and then goes silent forever, so a broken scanner after a broken style pass is invisible. Key it by label, cap `ns.errors` the way `ns.console` is capped, and add `/manners errors`.
- **Reuse the `present` table** in `ScanOwnBuffs` (`Core.lua:805`) — a fresh table plus up to 40 `pcall`s on every player aura tick.
- **Delete `ns.clicks`** (`Prompt.lua:274`, incremented, never read). Either read `Prompt.pendingStyle` (`Prompt.lua:480-483`, set and cleared, never tested — `PLAYER_REGEN_ENABLED` re-applies the whole style unconditionally at `Core.lua:946-950`) or delete it. Either persist `ns.console` in `WriteProbe` or delete it and fix the comment at `Core.lua:1033-1034`, which claims everything printed lands in SavedVariables when `WriteProbe` (`953-979`) writes only the probe.
- **One test asserting every command named in the help block is handled.** `Core.lua:1430-1437` lists eight commands against an if/elseif chain; `restore` was advertised without existing once already.
- **Delete `Core.lua.bak`, `Options.lua.bak`, `Prompt.lua.bak`.** They are not in the `.toc` and not tracked by git, but they sit in the addon folder where the packager and every future grep will find them.

**Not worth doing**

- Rewriting the slash chain as a dispatch table with generated help. The bug it was proposed to prevent is fixed, and it is churn in a file that works; the test above is the cheap version of the same guarantee.
- Splitting the phrase pool by reason, or building an emote configuration block. `onlyWhenReturning` already covers the case, and the allow-list version of emotes is two lines inside `ApplyTarget`.
- Per-class profiles. The bug that motivated it — every pinned buff reset on login — is fixed at `Core.lua:1242-1243` and `1204`. Auto-switching profiles forks every existing user's settings on first run, and the copy-forward is the part that is easy to get wrong. If per-class state is wanted later, make `buff.choice` a small table keyed by class rather than switching whole profiles.
- Generating the options table from a schema. It is 800 readable lines with working closures; a generator would buy nothing but a layer to debug.