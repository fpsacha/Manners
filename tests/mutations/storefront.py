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

mutate(MS,
       '    before = prompt_layer("shot-hero-before", snaps["shot-hero-before"], zoom)',
       '    before = prompt_layer("shot-landed", snaps["shot-landed"], zoom)',
       "storefront: the hero shows only the landing, not the press",
       expect="no longer draws the prompt before the press", script=V)
