# Before a release: five minutes in the game

Nothing in `tools/` or `tests/` talks to a running client. This is the part
only the game can say. Not shipped (`.pkgmeta` ignores it).

Copy the tree to be released into `Interface/AddOns/Manners` (with `Libs/`),
log in on WoW Forever, out of combat, and `/reload`.

These are the first steps of the whole in-game checklist, the first item
under *Open* in `STATUS.md` (numbered, most trust-critical first, each with
what to do and what to look for). Before a release, do the five below; in
your own play sessions, work down the rest of that list.

## 1. The report (checklist step 1)

    /manners selftest launch

Chat prints two lines, and the report opens in the box under *Reporting a bug*:

    launch checks: N passed, N to check, 0 failed -- the report starts with them.
    self-test: N passed, N warnings, 0 failed -- ...

Clean is **0 failed on both lines**, and a last report line
`N checks: N pass, N warn, 0 fail`. Read every `CHECK` line once: each says
whether it is a fallback (fine) or something only eyes can tell (look at it).
*Actions the game refused* lists every "blocked" or "forbidden" the game
raised against Manners since login, so run the report again after the four
steps below. Any `FAIL`, or a red Lua error on screen: stop, copy the report
from the box, paste it to the agent. `/manners errors` shows what Manners
caught.

## 2. Four things to do

1. **A real favour** (checklist step 2). Have somebody buff you (or buff an
   alt in a group): the prompt names them, one press buffs them back and your
   target comes back, the ledger (`/manners ledger`) has the line, and the
   spoken line, if on, is said once.
2. **A fight** (step 5). Pull a mob with the prompt up: no "action blocked"
   message, no error; with *Hide the prompt in combat* on it hides and comes
   back after. The action bar's Manners macro, if you use it, still casts out
   of combat.
3. **The options window** (step 22). Open every tab: no empty page, no
   control on top of another, the search box finds "emote". Change one
   setting, `/reload`, it stuck.
4. **The prompt and the looks** (step 25). `/manners test`: where you left
   it, readable, nothing poking out of the frame; *Look*: every card has its
   picture with your own buff icon; three looks, the newest first, whole and
   animating once.

Whatever this release changed gets a fifth look of its own: do the thing the
changelog's first line says, once, by hand.

On a hunter, once: dismiss the pet and `/reload` (no Call Pet comes up); let
the pet go hungry and press Feed Pet on the prompt (the pet eats, you do not);
after a long fight press the moment with your pet and read chat (the emote
names the pet, your target is unchanged).

Seen all of it clean, and `/manners selftest launch` run again with
*actions the game refused* still clean: `python tools/release.py X.Y.Z`.
