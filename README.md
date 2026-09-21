# Manners

**One click to buff back whoever just buffed you** — and nearby players missing
yours.

A priest buffs you in passing. By the time you have found them among a dozen
nameplates they are gone. Manners reads who it was, works out what you owe
them, and puts a single button on screen.

It also offers nearby players who are missing your buff — not to optimise a
raid, just so you can be the person who buffs strangers.

Built for WoW Forever (Interface 16001).

## What it does

- **Someone buffs you** → they go to the top of the queue, tagged as a favour
  owed. Read from the combat log, so it works on strangers who are not grouped
  with you.
- **Your party or raid** → anyone missing your buff.
- **Passers-by** → nearby players missing your buff, seen through nameplates,
  your target and your mouseover.

Skips the dead, the out-of-range, anyone you just tried, and anyone the buff
does nothing for — Arcane Intellect is wasted on a rogue.

**If they already have it**, you choose: leave them alone, offer a top-up once
their timer drops below a threshold you set, or always offer regardless.

## Supported classes

| Class | Buffs offered |
|---|---|
| Mage | Arcane Intellect |
| Priest | Power Word: Fortitude, Divine Spirit, Shadow Protection |
| Druid | Mark of the Wild, Thorns |
| Paladin | Wisdom, Might, Kings, Salvation, Light, Sanctuary |
| Warlock | Unending Breath |
| Warrior | Battle Shout (party only) |

Paladins get a sensible automatic pick: Wisdom for anyone with a mana bar,
Might for everyone else. Any class can pin one specific buff instead.

Battle Shout reaches your party and nobody else, so a warrior outside a group
is offered nobody. That is deliberate rather than a fault.

### How far each class has been tested

| | |
|---|---|
| **Mage** | cast in game, repeatedly, against real players |
| Priest, Druid, Paladin, Warlock, Warrior | spell data corroborated against other addons on this client, and every cast path exercised in the test suite -- but never cast in game |

The cast path took ten attempts to get right for Mage, on a client that
documents none of its restrictions. The other classes use the same path and
their macros are checked automatically, but treat them as unproven until
somebody reports otherwise.

Hunters, rogues and shamans have nothing to cast on another player, so Manners
says so plainly rather than looking broken.

## Why a button and not automatic

Blizzard does not let an addon cast a spell on its own — `CastSpellByName` is
protected and only runs from a hardware event. This has been true since patch
2.0 and no addon gets around it.

So Manners does everything except the keypress. It decides who deserves the
buff and writes that decision onto a secure button; the *game* casts when you
click. That split is deliberate on Blizzard's part and it is why the prompt
also freezes during combat.

## Speech

Optionally say something when you buff somebody, with a randomised phrase list.

The line rides along in the macro the button runs rather than going through the
chat API — the game refuses addon-sent `/say` outside instances, which is
exactly where someone buffs you in passing. Through the macro it counts as you
talking.

Off by default, and when on it defaults to speaking only when returning a
favour.

## Usage

```
/manners           options
/manners unlock    drag the prompt, then /manners lock
/manners test      preview, for styling without waiting for a real entry
/manners debug     what your class and this build allow
```

Keybind under **Game Menu → Key Bindings → Manners**, or with a macro
containing `/click MannersPrompt`.

## Notes on WoW Forever

This client differs from other flavours in ways that are not documented
anywhere, and each one took a live test to find.

**Conditional targeting does not work.** `[@unit]`, `[@Name]`, `[@focus]`,
`[@mouseover]` and the secure `unit` attribute all fail, silently or with "You
have no target". Buffing somebody therefore means `/target <name>` then
`/cast`, and handing the target back afterwards. A bare `/cast` with no target
works fine, so this is specifically about naming another unit.

**Secure buttons must register for mouse down.** Registering up only leaves the
click arriving and the attributes correct while the game casts nothing and
reports nothing. Every secure button that works here registers `"AnyDown"`.

**Unit power is a secret value** for players outside your group, so "does this
person have mana" cannot be read directly. Class is used instead, which is
accurate for every vanilla class.

**`UnitName` returns a surname, not a realm**, in its second value. Joining
them with a hyphen produces names that no targeting call resolves.

**Nameplate unit tokens are secret** when read off the frame via
`C_NamePlate.GetNamePlates()`. The token passed to `NAME_PLATE_UNIT_ADDED` is
not, so that is what to track.

**There is no combat log.** `COMBAT_LOG_EVENT_UNFILTERED` never fires; Blizzard
ships `C_DamageMeter` instead. A favour is therefore spotted by watching your
own buffs appear and reading `aura.sourceUnit` — which is a unit token, so
somebody with no nameplate who is not your target cannot be identified at all.
Nothing can be done about that from an addon.

## Building a release

Full checklist in [RELEASING.md](RELEASING.md).

`Libs/` is deliberately not in the repository: `.pkgmeta` declares all 13
libraries as build-time externals, so the packager fetches current upstream
copies under their own licences.

**A zip built from a clone therefore has no libraries and will not load.** Tag
a version and let the workflow build it:

```
git tag v0.9.0 && git push origin v0.9.0
```

`.github/workflows/release.yml` runs the test suites, fails the build if any
check has stopped being able to detect the fault it exists for, then packages
and publishes. Add `CF_API_KEY`, `WOWI_API_TOKEN` or `WAGO_API_TOKEN` to the
repository secrets to publish beyond GitHub; without them those destinations
are skipped.

## Tests

```
python tests/runharness.py     load the addon against a mock client
python tests/runscenarios.py   adversarial scenarios
python tests/selftest.py       confirm the suites can still go red
```

See `tests/README.md`.

## Licence

MIT, see `LICENSE`. Bundled libraries keep their own terms — see
`THIRD-PARTY-NOTICES.md`. LibSharedMedia-3.0 is LGPL v2.1.
