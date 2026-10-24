"""Spoken lines that give the speaker, or the person spoken to, a gender.

    python tools/audit_i18n_gender.py               # French, Italian, Spanish, Portuguese
    python tools/audit_i18n_gender.py frFR --all    # also the lines it only half trusts

The English lines (Phrases.lua, Speech.lua) are written so that anybody can
say them: "I'm old, dry and extremely flammable" suits a dwarf of either sex.
In a language that agrees an adjective or a participle with its subject, the
same sentence has to pick: "Je suis vieux, sec et très inflammable" is a man's
line, and a female dwarf says it in the voice of a man every time it is picked.
The addon knows the speaker's sex (UnitSex("player")) and the listener's, and
uses neither, so each such line is wrong for half of its speakers, or half of
those it is said to. Languages that have no gendered adjectives (German's
predicate adjectives, Korean, Chinese) have none of this.

This looks for the plainest shape: a first-person "I am / I was / I feel" (je
suis, sono, soy, estou ...) followed within two words by an adjective or a
participle in its masculine form, and prints each line it finds as

    frFR [je suis vieux] Éloignez les torches de moi, {name}. Je suis vieux, sec et ...

It is a lead list. A masculine-looking word can be a noun ("je suis le chef",
"soy yo"), a name or invariable; each line is meant to be read. The lines read
and found to be a man's voice go into RP.MASCULINE (Phrases.lua), which RP.Pick
leaves out for a woman; the patterns miss some ("Obrigado" in Portuguese, said
by the speaker), so a new language or a new batch of lines wants a look beyond
this list too. The patterns
do not look for a gendered address to {name} ("vous voilà prêt"), which can
only be answered by the sex of the person on the prompt.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import locale_keys  # noqa: E402

OPEN = {
    "frFR": r"(?:je suis|j'suis|j’suis|je me suis|je ne suis pas|j'étais|j’étais|je serai|je reste)",
    "itIT": r"(?:sono|ero|sarò|mi sento|mi sono|resto)",
    "esES": r"(?:estoy|soy|era|estaba|seré|estaré|me siento|me quedo)",
    "ptBR": r"(?:estou|sou|era|estava|serei|fico)",
}
# Words that follow and are not an adjective in the masculine singular.
SKIP = {
    "frFR": r"(?:en|à|de|du|des|la|le|les|un|une|juste|là|ici|d|tout|plutôt|déjà|toujours|presque|aux|sur|dans|avec|pas|ton|ta|mon|ma|libre|modeste|mi|devant|derrière|aux)",
    "itIT": r"(?:in|a|di|del|della|la|il|i|le|un|una|qui|lì|già|sempre|quasi|con|per|senza|molto|più|solo|ancora|su|da|al|nel|dietro|davanti|io|tutti|stato|stati|stata|state)",
    "esES": r"(?:en|a|de|del|la|el|los|las|un|una|aquí|ahí|casi|siempre|ya|con|por|para|sin|muy|más|solo|aún|todavía|no|yo|lo|todo|esto)",
    "ptBR": r"(?:em|a|de|do|da|o|os|as|um|uma|aqui|aí|já|sempre|quase|com|para|sem|muito|mais|só|ainda|no|na|atrás|eu|tudo|isto|disso)",
}
MASC = {
    "frFR": re.compile(r"(?:é|i|if|eux|ant|ent|ul|ort|ou|et|ois|eux)$|^(?:vieux|sec|nul|mort|content|prêt|seul|fier|vivant|petit|grand|gentil|fou|heureux|ravi)$"),
    "itIT": re.compile(r"(?:o|ato|uto|ito)$"),
    "esES": re.compile(r"(?:o|ado|ido)$"),
    "ptBR": re.compile(r"(?:o|ado|ido)$"),
}
FEMININE_OR_NEUTRAL = re.compile(r"(?:ée|ie|ndo|ndo)$")


def out(line):
    sys.stdout.buffer.write((line + "\n").encode("utf-8"))


def main(argv):
    if any(a in ("-h", "--help") for a in argv[1:]):
        out(__doc__)
        return 0
    args = [a for a in argv[1:] if not a.startswith("--")]
    codes = args or list(OPEN)
    unknown = [c for c in codes if c not in OPEN]
    if unknown:
        out("no check for %s; the languages are %s" % (", ".join(unknown), " ".join(OPEN)))
        return 2
    keys, _ = locale_keys.keys()
    phrases = [k for k, w in keys.items() if all(x.startswith(("Phrases.lua", "Speech.lua")) for x in w)]
    total = 0
    for code in codes:
        if code not in OPEN:
            continue
        table = locale_keys.load_locale(code)
        rx = re.compile(r"\b(" + OPEN[code] + r")\s+(\w+)(?:\s+(\w+))?", re.I)
        skip = re.compile("^" + SKIP[code] + "$", re.I)
        seen = set()
        for key in phrases:
            text = table.get(key, "")
            for m in rx.finditer(text):
                for word in (m.group(2), m.group(3)):
                    if not word or skip.match(word):
                        break
                    w = word.lower()
                    if MASC[code].search(w) and not FEMININE_OR_NEUTRAL.search(w) and text not in seen:
                        seen.add(text)
                        total += 1
                        out("%s [%s %s] %s" % (code, m.group(1), word, text))
                        break
                    if "--all" not in argv:
                        break
    print("%d line(s)" % total)
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
