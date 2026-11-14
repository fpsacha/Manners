# Before a release: five minutes in the game

Nothing in `tools/` or `tests/` talks to a running client. This is the part
only the game can say. Not shipped (`.pkgmeta` ignores it).

Copy the tree to be released into `Interface/AddOns/Manners` (with `Libs/`),
log in on WoW Forever, out of combat, and `/reload`.

## 1. The report

    /manners selftest launch

Chat prints two lines, and the report opens in the box under *Reporting a bug*:

    launch checks: N passed, N to check, 0 failed -- the report starts with them.
    self-test: N passed, N warnings, 0 failed -- ...

Clean is **0 failed on both lines**, and a last report line
`N checks: N pass, N warn, 0 fail`. Read every `CHECK` line once: each says
whether it is a fallback (fine) or something only eyes can tell (look at it).
Any `FAIL`, or a red Lua error on screen: stop, copy the report from the box,
paste it to the agent. `/manners errors` shows what Manners caught.

## 2. Five things to look at

1. **The prompt.** `/manners test`. It appears where you left it, the icon,
   name and reason are readable, nothing overlaps or pokes out of the frame.
   Press it: the cast goes off and your target comes back.
2. **The looks.** `/manners options`, *Look*: every card in the picker has its
   picture with your own buff icon on it. Pick three looks, the newest one
   first, with `/manners test` up: the art is whole (no green or white
   squares, no stretched strip), the words sit on it, the animation plays once
   and stops.
3. **The options window.** Open every tab: no empty page, no control on top of
   another, the search box finds "emote". Change one setting, `/reload`, it
   stuck.
4. **A real favour.** Have somebody buff you (or buff an alt in a group): the
   prompt names them, one press buffs them back, the ledger
   (`/manners ledger`) has the line, and the spoken line, if on, is said once.
5. **A fight.** Pull a mob with the prompt up: no "action blocked" message, no
   error; with *Hide the prompt in combat* on it hides and comes back after.
   The action bar's Manners macro, if you use it, still casts out of combat.

Whatever this release changed gets a sixth look of its own: do the thing the
changelog's first line says, once, by hand.

Seen all of it clean: `python tools/release.py X.Y.Z`.
