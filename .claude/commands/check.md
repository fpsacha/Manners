---
description: Run every check (lint, validate, harness, scenarios, each client, anchors) and summarise
argument-hint: "[jobs]"
---
Run from the repository root (your worktree, if you work in one):

    python tools/check.py --lint --flavours --anchors --jobs $ARGUMENTS

With no argument leave `--jobs` out (default: cores less two). With other agents
running tests, pass `--jobs 2`: total workers across everybody stay at cores
minus two. It takes minutes; run it in the background and wait.

Then report, and change nothing:

- the last line: `check: all N step(s) passed in Ns`, or which steps FAILED;
- for each failed step the lines printed under its `---` heading, with the
  `file:line` they name, and the log path (`%TEMP%/manners-check/<checkout>/`);
- `lint` failing means nothing else ran: the file:line it names comes first;
- `ANCHOR GONE` means a mutation lost its text. `python tools/anchors_for.py
  --check-after` names it and the file that holds it. Re-aim it at the new code
  so it applies the same fault (never delete it), then run `--anchors` again;
- a `<client>: <file>` step red means that scenario file fails as that client:
  a fix written on Forever that does not hold there, not noise.
