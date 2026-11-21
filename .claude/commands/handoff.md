Leave a note for the next session (a new chat, the nightly pass, or another
agent), so it does not have to rebuild the picture from the git log.

Rewrite the section *Where I left off* at the very top of `STATUS.md` (under
the title, above *State*). Keep it under 25 lines, newest only, no history:

- **Date and the last release** (`git describe --tags --abbrev=0`).
- **In flight**: each worktree and branch still open (`git worktree list`),
  what it holds, and whether it is merged; any workflow still running.
- **Waiting on the owner**: decisions asked and not answered, things only the
  game can settle that they were asked to try.
- **Waiting on players**: issues labelled `player` that wait for a reply or a
  log (`gh issue list --label player --state open`).
- **Next**: the next two or three things to do, in order.
- **Watch out**: anything the next session could trip on (a duplicate reply
  that had to be deleted, a branch the nightly left unmerged, a flaky test).

Then commit it alone ("STATUS: where I left off"), with the Co-Authored-By line,
in the live tree only when it is clean and nothing runs there; otherwise in the
worktree being merged next.
