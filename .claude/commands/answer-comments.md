Answer the players: read every new CurseForge comment and GitHub issue on
Manners, fix or build what they report, release, and reply to each once. The
owner does not want to be asked along the way; a release and a deletion still
follow CLAUDE.md and the owner's standing word (the nightly task's, or theirs in
the session).

1. **See what is already in hand, before anything else.**
   - `gh issue list --state open --label player` (every player report is an
     issue: step 3).
   - `git branch --list "feedback-*" "fixes-*" "pass-*"` and `git log master
     -15`: the nightly pass (11 PM, `feedback-YYYYMMDD`) or another session may
     have built the fix already. Merge such a branch; never build it twice.
   - STATUS.md's first section, *Where I left off*.
2. **Read the comments.** Claude in Chrome on
   https://www.curseforge.com/wow/addons/manners/comments (signed in as
   fpsacha; the built-in browser can read but not post). Expand *Read more*.
   A top-level comment with no reply by fpsacha is new; so is a reply to one of
   ours that asks something.
3. **One issue per report**, so both sessions see it:
   `gh issue create --label player --label <bug|enhancement|question> --title
   "<short>" --body "<the comment verbatim, the author, the date, a link>"`.
   A question answered from the settings needs no issue.
4. **Investigate and build** with the saved workflow:
   `git worktree add D:/Projects/WOW_Addons/Manners-wt-<name> -b <name> master`,
   then the Workflow tool with `name: "player-reports"` and `args: { worktree,
   branch, coauthor, skip, reports: [{ id, text }] }`. It investigates with
   Opus, builds the real ones with Sonnet, reviews with Opus and repairs.
5. **Merge and release.** In the worktree: `python tests/runscenarios.py
   --jobs 4` to `failures: 0`, `git merge master`, `python tools/check.py
   --quick`. Then in the live tree, only when it is clean: `git merge
   --ff-only <name>`, copy to the game folder, `python tools/release.py X.Y.Z
   --dry-run`, then the release (`/release`).
6. **Reply once each** with `.claude/snippets/curseforge-reply.js`: paste it
   into the page with javascript_tool, then `await window.mannersReply(author,
   snippet, text)` one at a time. It skips a player already answered; a
   reply already there that is now wrong gets `{ correction: true }` and a text
   starting "I got that wrong". 201 is the only proof of a post. Never tell a
   player something is impossible.
7. **Close the loop.** `gh issue close <n> --comment "Fixed in vX.Y.Z"` for
   each released fix; a no-go stays open with the reason. Add each comment
   to the nightly's `state.json` (`C:/Users/Sacha/.claude/scheduled-tasks/manners-daily-feedback/state.json`,
   `"<author>: <first 60 chars>"`), so it does not answer again. Then `/handoff`.
