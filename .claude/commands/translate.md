---
description: Translate the strings the locales lack (locale_todo, official game names, locale_add)
argument-hint: "[locale codes, default all eight]"
---
Locales: deDE esES frFR itIT koKR ptBR zhCN zhTW (`$ARGUMENTS` narrows them).
No Russian, ever. Work in your worktree; put the todo files outside the repo.

1. `python tools/locale_todo.py --out <dir>` writes `<code>.todo.json`, each
   missing key mapped to `""`, and prints the counts. Nothing missing: stop.
2. Translate the values, one agent per locale in parallel. The file is JSON in
   UTF-8; write it with the Write tool, never a bash heredoc. Rules:
   - keep every `%s`, `{token}` and `|c...|r` exactly as the English has it;
   - game terms (spell, item, class, race, zone names, the client's own UI words
     such as nameplates or Key Bindings) use that client's official localized
     name: Wowhead in that language, GlobalStrings from
     Ketho/BlizzardInterfaceResources. Never a free translation, never a guess;
   - slash commands stay English; the English key is the source, not a gloss;
   - leave a value `""` when unsure: it is skipped, not written.
3. `python tools/locale_add.py <code> <dir>/<code>.todo.json` per locale. It
   checks every value (`check_translation.py`), merges, rebuilds
   `Locales/<code>.lua`, and puts the old file back on any objection, listing
   it. Fix what it lists and run it again.
4. `python tests/validate.py`: no `MISSING <code>` left. Then
   `python tools/check.py --lint --jobs 2`.

A string that is new or changed in the same change needs all eight locales
before it lands; no new or changed `L["..."]` without them.
