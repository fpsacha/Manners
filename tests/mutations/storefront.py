# Mutations for the storefront: the listing pages (README.md's opening,
# .github/curseforge-description.md, .github/wago-description.md,
# .github/curseforge-summary.txt), the gallery's order and words
# (.github/gallery.md, .github/media/UPLOAD.md) and the pictures' list in
# tools/make-screenshots.py (GALLERY). From the 2026-11-15 review: the first
# picture showed only what happens after the press, the listings left out the
# release's headline features, and small details had gone stale. Each undoes
# one rule and is caught by tests/validate.py's listing sections.
#
# Run by selftest.py with mutate() in scope.

V = "validate.py"
MS = "tools/make-screenshots.py"
HERO_ALT = ("Somebody buffed you: the prompt names Mort Defrette, who buffed you, with a mouse pointer on "
            "it and a key under it; one press, and the same prompt reads buffed Mort Defrette, the game "
            "confirmed it")

# ---- the moment first: one order, the hero before and after the press

mutate(".github/gallery.md",
       "| `manners-prompt.png` | Somebody buffed you. One press. |",
       "| `manners-moment.png` | Somebody buffed you. One press. |",
       "storefront: gallery.md leaves GALLERY's order",
       expect="gallery.md lists the pictures as", script=V)

mutate(".github/media/UPLOAD.md",
       "| 1 | `manners-prompt.png` |",
       "| 1 | `manners-moment.png` |",
       "storefront: UPLOAD.md leaves GALLERY's order",
       expect="UPLOAD.md lists the pictures as", script=V)

mutate(".github/media/UPLOAD.md",
       "| Somebody buffed you. One press. | Somebody buffed you in passing,",
       "| Buff them back in one click | Somebody buffed you in passing,",
       "storefront: UPLOAD.md's title is not the gallery's",
       expect="UPLOAD.md: manners-prompt.png's title or description", script=V)

mutate(MS,
       '    ("manners-prompt.png", "Somebody buffed you. One press.",',
       '    ("manners-moment.png", "Somebody buffed you. One press.",',
       "storefront: GALLERY opens on the film strip, the pages do not follow",
       expect="GALLERY's order is", script=V)

mutate("README.md",
       '<img src=".github/media/manners-prompt.png" alt="',
       '<img src=".github/media/manners-moment.png" alt="Three film strips" width="640">\n\n'
       '<img src=".github/media/manners-prompt.png" alt="',
       "storefront: the README opens on the film strip again",
       expect="README.md's first picture is manners-moment.png", script=V)

mutate(".github/curseforge-description.md",
       "![" + HERO_ALT + "]",
       "![Three film strips](https://raw.githubusercontent.com/fpsacha/Manners/master/.github/media/"
       "manners-moment.png)\n\n![" + HERO_ALT + "]",
       "storefront: the CurseForge description opens on the film strip again",
       expect="curseforge-description.md's first picture is manners-moment.png", script=V)

mutate(".github/wago-description.md",
       "![" + HERO_ALT + "]",
       "![Three film strips](https://raw.githubusercontent.com/fpsacha/Manners/master/.github/media/"
       "manners-moment.png)\n\n![" + HERO_ALT + "]",
       "storefront: the Wago description opens on the film strip again",
       expect="wago-description.md's first picture is manners-moment.png", script=V)

mutate(".github/curseforge-description.md",
       "manners-prompt.png)\n",
       "manners-prompt.png)\n\n![Manners](https://raw.githubusercontent.com/fpsacha/Manners/master/"
       ".github/media/manners-how.jpg)\n",
       "storefront: the how-it-works strip slips below the moment on the CurseForge page",
       expect="curseforge-description.md shows manners-how.jpg, which is not in GALLERY", script=V)

mutate(MS,
       '    before = prompt_layer("shot-hero-before", snaps["shot-hero-before"], zoom)',
       '    before = prompt_layer("shot-landed", snaps["shot-landed"], zoom)',
       "storefront: the hero shows only the landing, not the press",
       expect="no longer draws the prompt before the press", script=V)

# ---- the headline features on every page a browser reads first

mutate(".github/curseforge-description.md",
       "profiles that switch by themselves as you enter",
       "profiles as you enter",
       "storefront: the CurseForge opening leaves out automatic profiles",
       expect="curseforge-description.md's opening does not mention profiles that switch by themselves",
       script=V)

mutate(".github/wago-description.md",
       "**profiles that switch by themselves** as you enter",
       "**profiles** as you enter",
       "storefront: the Wago page leaves out automatic profiles",
       expect="wago-description.md does not mention profiles that switch by themselves", script=V)

mutate(".github/wago-description.md",
       "Kings first, and **a blessing for each class** (Wisdom for mages, say).",
       "Kings first.",
       "storefront: the Wago page leaves out a blessing for each class",
       expect="wago-description.md does not mention a blessing for each class", script=V)

mutate("README.md",
       "- **Profiles that switch by themselves.** One for the open world, one for",
       "- **Profiles.** One for the open world, one for",
       "storefront: the README's opening leaves out automatic profiles",
       expect="README.md's opening does not mention profiles that switch by themselves", script=V)

mutate("README.md",
       "- **A blessing for each class.** A paladin picks the blessing each class is",
       "- **Paladins.** A paladin picks the blessing each class is",
       "storefront: the README's opening leaves out a blessing for each class",
       expect="README.md's opening does not mention a blessing for each class", script=V)

mutate(".github/curseforge-summary.txt",
       "Your group, passers-by and the fallen too.",
       "Your group, passers-by missing yours, the dead of your group, and your own armors, auras, "
       "aspects, poisons, food and more too.",
       "storefront: the summary grows past one short line",
       expect="curseforge-summary.txt is", script=V)

mutate(".github/curseforge-summary.txt",
       "one press buffs them back and your target",
       "one press settles it and your target",
       "storefront: the summary no longer says what the addon is for",
       expect="curseforge-summary.txt does not say what the addon is for", script=V)

# ---- the small facts: alt text, the addon's own words, the counts

mutate("README.md",
       'manners-options.png" alt="The options window on Start here in the Simple view',
       'manners-options.png" alt="The options window on Who to buff, with the pages on the left',
       "storefront: the README describes the options picture as another page",
       expect="README.md describes manners-options.png", script=V)

mutate(".github/curseforge-summary.txt",
       "passers-by and the fallen",
       "nearby players and the fallen",
       "storefront: the summary says nearby, not passer-by",
       expect="curseforge-summary.txt says", script=V)

mutate(".github/curseforge-description.md",
       "Yours to arrange: thirty looks,",
       "Yours to arrange: eighteen looks,",
       "storefront: the CurseForge page counts the looks wrong",
       expect="curseforge-description.md says Eighteen looks", script=V)

mutate(".github/wago-description.md",
       "over three thousand lines picked",
       "over two thousand lines picked",
       "storefront: the Wago page counts the In character lines as before the Forsaken's",
       expect="wago-description.md says over two thousand In character lines", script=V)
