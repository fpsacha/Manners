"""Every id the addon holds, checked against each client's own data tables.

    python tools/audit_ids.py                       # all five clients
    python tools/audit_ids.py --client mists        # one (repeatable)
    python tools/audit_ids.py --cache DIR           # where the downloaded CSVs live
    python tools/audit_ids.py --offline             # download nothing; a missing table is an error
    python tools/audit_ids.py --fetch-only          # fill the cache and stop
    python tools/audit_ids.py --notes               # also print the NOTE lines (judgement calls)
    python tools/audit_ids.py --dump mists          # the addon's side as JSON, and stop
    python tools/audit_ids.py --selftest            # the audit goes red when a datum is wrong
    python tools/audit_ids.py --client camelot --build camelot=1.60.1.70338   # a newer build

What it does. The addon is loaded on the mock for each client (tools/audit_ids.lua,
the same way tests/runscenarios.py loads it), and everything it holds that names a
thing the client owns is read off the set it chose: the buffs for others (ranks,
group versions, `alike` ids, reagents), the class's own buffs and tracking, the
scrolls, the favour-only and not-favour lists, ns.RANK_LEVEL, the race files in
RP.FAMILY, the class tokens, the global-cooldown spell. Each is checked against that
client's DB2 tables from wago.tools, for the build CLAUDE.md's "Data sources" cites:

  SpellName          the id exists, and its name is the buff the key says (compared in
                     English; wording that differs only in case or punctuation is fine)
  SkillLineAbility   the rank chain (SupercedesSpell): the ranks listed are the whole
                     chain, highest first, none newer; the class the spell is for;
                     trained or talent
  SpellLevels        ns.RANK_LEVEL is the level the client trains each rank at
  SpellReagents      a group cast's reagent is what the client eats, in ItemSparse
  SpellEffect        the aura a cast lands is an id the addon matches (its own, a
                     trigger, or a listed group id); a group version's effects
  SpellMisc/SpellDuration   a `toggle` family has no duration, a timed one has
  SpellAuraOptions   a shield's `charges`
  Talent             a `talent` buff is a talent (or not)
  ItemSparse, ItemEffect, SpellItemEnchantment, SpellEquippedItems   Forever's scrolls: the
                     item, the spell its use casts, the enchant, the weapon it fits
  SpellEffect targets + SpellRadius   who a cast reaches against the flags that say so
                     (selfCast, partyOnly, groupOnly, alone, wideCasts, partyIsSubgroup,
                     SHOUT_YARDS)
  ChrRaces, ChrClasses   RP.FAMILY's race files, every class token, and ns.MANA_CLASSES
                     against each class's DisplayPower
  (gaps)             friendly auras of 5 minutes or more that one class teaches and the addon
                     holds nowhere: printed as NOTEs, for a human to judge (Mists' Commanding
                     Shout was one until the set gave it to the warrior; Classic Era's
                     Season of Discovery runes are the rest)

A line is `client: KIND: where: what`. KIND is FINDING for something wrong, and NOTE
for something to read and judge (printed with --notes). Exit 1 when there is a
FINDING, 2 when a table could not be fetched.

The CSVs are cached outside the repo (default %TEMP%/manners-audit-cache; pass
--cache to put them elsewhere) and never committed. They are data, read with the csv
module and nothing else. Needs lupa (Lua 5.1, as the tests) and network the first time.
"""
import argparse
import csv
import json
import os
import re
import sys
import tempfile
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

csv.field_size_limit(1 << 28)

FLAVOURS = ("camelot", "vanilla", "tbc", "mists", "mainline")
# The build per client comes from CLAUDE.md ("The builds cited in the code"), by
# tools/clients_watch.py's reading of it; these stand in if that line moves.
BUILDS = {"camelot": "1.60.1.70178", "vanilla": "1.15.9.70003", "tbc": "2.5.6.69795",
          "mists": "5.5.4.70032", "mainline": "12.1.0.69933"}

TABLES = ("SpellName", "Spell", "SpellMisc", "SpellEffect", "SpellLevels", "SkillLineAbility",
          "SpellReagents", "ItemSparse", "ChrRaces", "ChrClasses", "SpellAuraOptions",
          "SpellDuration", "Talent", "SpellEquippedItems", "SpellRadius")
EXTRA = {"camelot": ("ItemEffect", "ItemXItemEffect", "SpellItemEnchantment", "TraitDefinition"),
         "mainline": ("TraitDefinition",)}

CLASS_BIT = {"WARRIOR": 1, "PALADIN": 2, "HUNTER": 4, "ROGUE": 8, "PRIEST": 16, "DEATHKNIGHT": 32,
             "SHAMAN": 64, "MAGE": 128, "WARLOCK": 256, "MONK": 512, "DRUID": 1024,
             "DEMONHUNTER": 2048, "EVOKER": 4096}

# --------------------------------------------------------------- fetching


BUILD_OVERRIDE = {}


def build_for(flavour):
    if flavour in BUILD_OVERRIDE:
        return BUILD_OVERRIDE[flavour]
    try:
        import clients_watch
        _, builds = clients_watch.repo_side()
        if builds.get(flavour):
            return builds[flavour]
    except Exception:
        pass
    return BUILDS[flavour]


def fetch(flavour, table, cache, offline=False, quiet=False):
    """The path of the cached CSV, downloading it first when it is not there."""
    # A build other than the one CLAUDE.md cites (--build) caches under its own name.
    key = flavour if flavour not in BUILD_OVERRIDE else "%s@%s" % (flavour, BUILD_OVERRIDE[flavour])
    path = os.path.join(cache, "%s_%s.csv" % (key, table))
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return path
    if offline:
        return None
    os.makedirs(cache, exist_ok=True)
    url = "https://wago.tools/db2/%s/csv?build=%s" % (table, build_for(flavour))
    last = None
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "manners-audit"})
            with urllib.request.urlopen(req, timeout=600) as resp, open(path + ".part", "wb") as out:
                while True:
                    block = resp.read(1 << 20)
                    if not block:
                        break
                    out.write(block)
            os.replace(path + ".part", path)
            if not quiet:
                print("audit_ids: fetched %s (%d bytes)" % (os.path.basename(path), os.path.getsize(path)),
                      file=sys.stderr)
            return path
        except Exception as e:  # network: retry, then give up on this table
            last = e
            time.sleep(2 * (attempt + 1))
    print("audit_ids: could not fetch %s: %s" % (url, last), file=sys.stderr)
    return None


def rows(path):
    with open(path, encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            yield r


def num(v, default=0):
    try:
        return int(v)
    except (TypeError, ValueError):
        try:
            return int(float(v))
        except (TypeError, ValueError):
            return default


# ------------------------------------------------------- the client's data


class Client:
    """One client's tables, each loaded the first time it is asked for."""

    def __init__(self, flavour, cache, offline):
        self.flavour, self.cache, self.offline = flavour, cache, offline
        self.missing = []
        self._memo = {}

    def path(self, table):
        p = fetch(self.flavour, table, self.cache, self.offline)
        if p is None:
            if table not in self.missing:
                self.missing.append(table)
        return p

    def memo(self, key, build):
        if key not in self._memo:
            self._memo[key] = build()
        return self._memo[key]

    @property
    def names(self):
        def build():
            p = self.path("SpellName")
            return {num(r["ID"]): r["Name_lang"] for r in rows(p)} if p else {}
        return self.memo("names", build)

    @property
    def subtext(self):
        def build():
            p = self.path("Spell")
            return {num(r["ID"]): r["NameSubtext_lang"] for r in rows(p)} if p else {}
        return self.memo("subtext", build)

    @property
    def levels(self):
        """{spell: (BaseLevel, SpellLevel)} for the default difficulty."""
        def build():
            p = self.path("SpellLevels")
            out = {}
            for r in (rows(p) if p else ()):
                if num(r.get("DifficultyID")) != 0:
                    continue
                out[num(r["SpellID"])] = (num(r["BaseLevel"]), num(r["SpellLevel"]))
            return out
        return self.memo("levels", build)

    @property
    def effects(self):
        """{spell: [ {index, effect, aura, trigger, t0, t1, radius} ]}"""
        def build():
            p = self.path("SpellEffect")
            out = {}
            for r in (rows(p) if p else ()):
                if num(r.get("DifficultyID")) != 0:
                    continue
                out.setdefault(num(r["SpellID"]), []).append({
                    "index": num(r["EffectIndex"]), "effect": num(r["Effect"]),
                    "aura": num(r["EffectAura"]), "trigger": num(r["EffectTriggerSpell"]),
                    "t0": num(r.get("ImplicitTarget_0")), "t1": num(r.get("ImplicitTarget_1")),
                    "radius": num(r.get("EffectRadiusIndex_0")),
                    "misc0": num(r.get("EffectMiscValue_0")),
                })
            for v in out.values():
                v.sort(key=lambda e: e["index"])
            return out
        return self.memo("effects", build)

    @property
    def sla(self):
        """{spell: [ {line, class, race, acquire, supersedes} ]}"""
        def build():
            p = self.path("SkillLineAbility")
            out = {}
            for r in (rows(p) if p else ()):
                out.setdefault(num(r["Spell"]), []).append({
                    "line": num(r["SkillLine"]), "class": num(r["ClassMask"]),
                    "race": num(r.get("RaceMask_0", r.get("RaceMask"))),
                    "acquire": num(r["AcquireMethod"]), "supersedes": num(r["SupercedesSpell"]),
                    "minrank": num(r["MinSkillLineRank"]),
                })
            return out
        return self.memo("sla", build)

    @property
    def superseded_by(self):
        def build():
            out = {}
            for spell, lst in self.sla.items():
                for a in lst:
                    if a["supersedes"]:
                        out.setdefault(a["supersedes"], set()).add(spell)
            return out
        return self.memo("superseded_by", build)

    @property
    def reagents(self):
        def build():
            p = self.path("SpellReagents")
            out = {}
            for r in (rows(p) if p else ()):
                lst = []
                for i in range(8):
                    item, count = num(r.get("Reagent_%d" % i)), num(r.get("ReagentCount_%d" % i))
                    if item > 0 and count > 0:
                        lst.append((item, count))
                if lst:
                    out[num(r["SpellID"])] = lst
            return out
        return self.memo("reagents", build)

    def item_names(self, wanted):
        def build():
            p = self.path("ItemSparse")
            out = {}
            if p:
                for r in rows(p):
                    i = num(r["ID"])
                    if i in wanted:
                        out[i] = r["Display_lang"]
            return out
        return self.memo("items:%s" % sorted(wanted), build)

    @property
    def misc(self):
        def build():
            p = self.path("SpellMisc")
            out = {}
            for r in (rows(p) if p else ()):
                if num(r.get("DifficultyID")) != 0:
                    continue
                out[num(r["SpellID"])] = {"duration": num(r["DurationIndex"]),
                                          "a0": num(r["Attributes_0"]), "a3": num(r["Attributes_3"])}
            return out
        return self.memo("misc", build)

    @property
    def durations(self):
        def build():
            p = self.path("SpellDuration")
            return {num(r["ID"]): num(r["Duration"]) for r in rows(p)} if p else {}
        return self.memo("durations", build)

    def duration_ms(self, spell):
        """The spell's aura duration in ms, -1 for none ('until cancelled'), None unknown."""
        m = self.misc.get(spell)
        if m is None:
            return None
        if m["duration"] == 0:
            return 0
        return self.durations.get(m["duration"])

    @property
    def charges(self):
        def build():
            p = self.path("SpellAuraOptions")
            out = {}
            for r in (rows(p) if p else ()):
                if num(r.get("DifficultyID")) != 0:
                    continue
                out[num(r["SpellID"])] = num(r["ProcCharges"])
            return out
        return self.memo("charges", build)

    @property
    def talent_spells(self):
        """Every spell id a talent hands out, any rank. Classic Era, TBC and Mists: the
        Talent table (Forever's keeps the vanilla rows with no class, which its client
        does not use; its talents are Traits). Forever and retail: TraitDefinition."""
        def build():
            out = set()
            p = self.path("Talent")
            for r in (rows(p) if p else ()):
                if num(r.get("ClassID")) == 0:
                    continue
                for k in ["SpellID"] + ["SpellRank_%d" % i for i in range(9)]:
                    v = num(r.get(k))
                    if v > 0:
                        out.add(v)
            if self.flavour in ("camelot", "mainline"):
                p = self.path("TraitDefinition")
                for r in (rows(p) if p else ()):
                    for k in ("SpellID", "OverridesSpellID", "VisibleSpellID"):
                        v = num(r.get(k))
                        if v > 0:
                            out.add(v)
            return out
        return self.memo("talents", build)

    @property
    def races(self):
        def build():
            p = self.path("ChrRaces")
            return {num(r["ID"]): (r["ClientFileString"], r["Name_lang"]) for r in rows(p)} if p else {}
        return self.memo("races", build)

    @property
    def classes(self):
        def build():
            p = self.path("ChrClasses")
            return {r["Filename"]: r["Name_lang"] for r in rows(p)} if p else {}
        return self.memo("classes", build)

    @property
    def display_power(self):
        """{class token: ChrClasses.DisplayPower}: 0 mana, 1 rage, 2 focus, 3 energy, 6 runic power ..."""
        def build():
            p = self.path("ChrClasses")
            return {r["Filename"]: num(r.get("DisplayPower"), -1) for r in rows(p)} if p else {}
        return self.memo("display_power", build)

    @property
    def radius(self):
        def build():
            p = self.path("SpellRadius")
            return {num(r["ID"]): float(r["Radius"] or 0) for r in rows(p)} if p else {}
        return self.memo("radius", build)

    def level_of(self, spell):
        lv = self.levels.get(spell)
        if not lv:
            return None
        return lv[0] or lv[1]

    def spell_class_bits(self, spell):
        bits = 0
        for a in self.sla.get(spell, ()):
            bits |= a["class"]
        return bits


# ------------------------------------------------------------ expected names

# The English name(s) each key's spells carry, as regular expressions matched whole
# and case-insensitively. A key the tables below do not know is reported as a NOTE
# with the name the client gives, so a new buff cannot slip by unread.
BUFF_NAMES = {
    "intellect": r"Arcane Intellect|Arcane Brilliance|Dalaran Brilliance",
    "fortitude": r"Power Word: Fortitude|Prayer of Fortitude",
    "spirit": r"Divine Spirit|Prayer of Spirit",
    "shadow": r"Shadow Protection|Prayer of Shadow Protection",
    "motw": r"Mark of the Wild|Gift of the Wild",
    "thorns": r"Thorns",
    "wisdom": r"(Greater )?Blessing of Wisdom",
    "might": r"(Greater )?Blessing of Might",
    "kings": r"(Greater )?Blessing of Kings",
    "salvation": r"(Greater )?Blessing of Salvation",
    "light": r"(Greater )?Blessing of Light",
    "sanctuary": r"(Greater )?Blessing of Sanctuary",
    "breath": r"Unending Breath|Water Breathing",
    "battleshout": r"Battle Shout",
    "commandingshout": r"Commanding Shout",
    "emperor": r"Legacy of the Emperor",
    "whitetiger": r"Legacy of the White Tiger",
    "darkintent": r"Dark Intent",
    "hornofwinter": r"Horn of Winter",
    "skyfury": r"Skyfury",
    "bronze": r"Blessing of the Bronze",
    "sourceofmagic": r"Source of Magic",
}
OWN_NAMES = {
    "frostarmor": r"Frost Armor|Ice Armor", "magearmor": r"Mage Armor", "moltenarmor": r"Molten Armor",
    "innerfire": r"Inner Fire", "innerwill": r"Inner Will",
    "touchofweakness": r"Touch of Weakness", "shadowguard": r"Shadowguard",
    "demonarmor": r"Demon Skin|Demon Armor", "felarmor": r"Fel Armor",
    "devotionaura": r"Devotion Aura", "retributionaura": r"Retribution Aura",
    "concentrationaura": r"Concentration Aura", "shadowresaura": r"Shadow Resistance Aura",
    "frostresaura": r"Frost Resistance Aura", "fireresaura": r"Fire Resistance Aura",
    "sanctityaura": r"Sanctity Aura", "crusaderaura": r"Crusader Aura",
    "righteousfury": r"Righteous Fury",
    "aspecthawk": r"Aspect of the Hawk", "aspectmonkey": r"Aspect of the Monkey",
    "aspectwild": r"Aspect of the Wild", "aspectbeast": r"Aspect of the Beast",
    "aspectcheetah": r"Aspect of the Cheetah", "aspectpack": r"Aspect of the Pack",
    "aspectviper": r"Aspect of the Viper", "aspectironhawk": r"Aspect of the Iron Hawk",
    "trueshot": r"Trueshot Aura",
    "lightningshield": r"Lightning Shield", "watershield": r"Water Shield", "earthshield": r"Earth Shield",
    "omen": r"Omen of Clarity",
    "findherbs": r"Find Herbs", "findminerals": r"Find Minerals", "findtreasure": r"Find Treasure",
    "findfish": r"Find Fish",
    "trackbeasts": r"Track Beasts", "trackhumanoids": r"Track Humanoids", "trackundead": r"Track Undead",
    "trackhidden": r"Track Hidden", "trackelementals": r"Track Elementals", "trackdemons": r"Track Demons",
    "trackgiants": r"Track Giants", "trackdragonkin": r"Track Dragonkin",
    "senseundead": r"Sense Undead", "sensedemons": r"Sense Demons",
}
# What a favour-only / not-favour id is, by id: any client that has the id must call it this.
FAVOUR_NAMES = {
    6346: r"Fear Ward", 546: r"Water Walking", 11743: r"Detect (Lesser |Greater )?Invisibility", 2970: r"Detect (Lesser |Greater )?Invisibility",
    132: r"Detect (Lesser |Greater )?Invisibility", 20707: r"Soulstone( Resurrection)?", 20762: r"Soulstone Resurrection",
    20763: r"Soulstone Resurrection", 20764: r"Soulstone Resurrection", 20765: r"Soulstone Resurrection",
    27239: r"Soulstone Resurrection", 5697: r"Unending Breath",
    24932: r"Leader of the Pack", 24907: r"Moonkin Aura", 34123: r"Tree of Life", 6562: r"Heroic Presence",
    28878: r"Inspiring Presence", 19506: r"Trueshot Aura", 55610: r"Unholy Aura|Improved Icy Talons",
    116956: r"Grace of Air", 30809: r"Unleashed Rage", 51470: r"Elemental Oath", 77747: r"Burning Wrath",
    113742: r"Swiftblade'?s Cunning", 465: r"Devotion Aura", 317920: r"Concentration Aura",
    32223: r"Crusader Aura", 183435: r"Retribution Aura",
}
# Ids named in another buff's `alike`, when no buff of the set owns them.
ALIKE_NAMES = {469: r"Commanding Shout", 19506: r"Trueshot Aura", 24932: r"Leader of the Pack",
               21562: r"Power Word: Fortitude", 57330: r"Horn of Winter", 6673: r"Battle Shout", 109773: r"Dark Intent",
               20217: r"Blessing of Kings", 1126: r"Mark of the Wild", 117666: r"Legacy of the Emperor",
               117667: r"Legacy of the Emperor", 1459: r"Arcane Brilliance", 61316: r"Dalaran Brilliance"}

# Reagent items by id, as the client names them (English).
ITEM_NAMES = {17020: "Arcane Powder", 17021: "Wild Berries", 17026: "Wild Thornroot",
              17028: "Holy Candle", 17029: "Sacred Candle", 21177: "Symbol of Kings",
              22148: "Wild Quillvine"}

# Effects that make an aura (SpellEffect.Effect): APPLY_AURA and its area forms.
AURA_EFFECTS = {6, 27, 35, 65, 119, 128, 174}   # aura, party area, raid area, friend area, owner area, ...
TRIGGER_EFFECTS = {3, 64, 85, 140, 142}          # dummy, trigger spell, summon, forced cast...

FINDINGS = []
ALL_RACES = {}


class Report:
    def __init__(self, client):
        self.client = client

    def finding(self, where, text):
        FINDINGS.append((self.client, "FINDING", where, text))

    def note(self, where, text):
        FINDINGS.append((self.client, "NOTE", where, text))


def norm(s):
    return re.sub(r"[^a-z0-9]", "", (s or "").lower())


def name_ok(name, pattern):
    return name is not None and re.fullmatch(pattern, name.strip(), re.I) is not None


# -------------------------------------------------------------- the checks


def addon_dump(flavour):
    from lupa import lua51 as lupa
    rt = lupa.LuaRuntime(unpack_returned_tuples=True)
    src = open(os.path.join(HERE, "audit_ids.lua"), encoding="utf-8").read()
    fn = rt.eval("function(src, cfg) local f = assert(loadstring(src, '@audit_ids.lua')) return f(cfg) end")
    cfg = rt.table(addon=ROOT.replace("\\", "/"), flavour=flavour)
    return json.loads(fn(src, cfg))


def as_map(v):
    return v if isinstance(v, dict) else {}


def siblings(c, pattern, bit):
    """Every spell id of that class, in SkillLineAbility, whose name matches: the ranks
    and the group versions the client has under that name."""
    rx = re.compile(pattern, re.I)
    out = {}
    for spell in c.sla:
        name = c.names.get(spell)
        if name is None or not rx.fullmatch(name.strip()):
            continue
        bits = c.spell_class_bits(spell)
        if not (bits and (bit is None or bits & bit)):
            continue
        # A spell that makes no aura, or only on an enemy (a proc's debuff, a threat
        # effect), is not a rank of a buff.
        fx = [e for e in c.effects.get(spell, ()) if e["effect"] in AURA_EFFECTS and e["aura"]]
        if not fx or all(e["t0"] == 6 and e["t1"] == 0 for e in fx):
            continue
        # Acquired from a rune or engraving (Season of Discovery), not trained.
        if all(a["acquire"] == 3 for a in c.sla.get(spell, ())):
            continue
        out[spell] = name
    return out


def check_complete(rep, c, where, pattern, bit, listed):
    """Rank ids the client has under this buff's names that the addon does not hold
    anywhere: a level-70 wearing the newest rank would read as not wearing it."""
    if not pattern:
        return
    have = siblings(c, pattern, bit)
    for spell in sorted(have):
        if spell in listed:
            continue
        sub = c.subtext.get(spell, "")
        lv = c.level_of(spell)
        rep.finding(where, "client has spell %d %r %r (level %s, SkillLineAbility class mask %d) that the addon does not hold" % (
            spell, have[spell], sub, lv, c.spell_class_bits(spell)))


def check_order(rep, c, where, ids, kind):
    """Highest rank first: the level never rises along the list."""
    prev = None
    for i in ids:
        lv = c.level_of(i)
        if lv is None:
            continue
        if prev is not None and lv > prev[1]:
            rep.finding(where, "%s ranks are not highest first: %d (level %d) comes after %d (level %d)" % (
                kind, i, lv, prev[0], prev[1]))
        prev = (i, lv)


def check_spell_ids(rep, c, where, ids, pattern, bit=None, kind="id"):
    for i in ids:
        name = c.names.get(i)
        if name is None:
            rep.finding(where, "%s %d has no SpellName in this client" % (kind, i))
            continue
        if pattern and not name_ok(name, pattern):
            rep.finding(where, "%s %d is named %r, expected /%s/" % (kind, i, name, pattern))
        if bit:
            bits = c.spell_class_bits(i)
            if bits and not (bits & bit):
                rep.note(where, "%s %d (%s) is not a spell of this class in SkillLineAbility (class mask %d)" % (
                    kind, i, name, bits))


def aura_ids_of(c, spell, depth=0, seen=None):
    """The spell ids that end up as the aura on the target when `spell` is cast:
    itself when an effect applies an aura, and what its trigger chain applies."""
    seen = seen if seen is not None else set()
    if spell in seen or depth > 3:
        return set()
    seen.add(spell)
    out = set()
    for e in c.effects.get(spell, ()):
        if e["effect"] in AURA_EFFECTS and e["aura"]:
            out.add(spell)
        if e["trigger"]:
            out |= aura_ids_of(c, e["trigger"], depth + 1, seen)
        elif e["effect"] in (3, 64) and e["misc0"] and depth == 0 and False:
            pass
    return out


def check_buffs(rep, c, d, flavour):
    buffs = as_map(d["buffs"])
    rank_level = {int(k): v for k, v in as_map(d["rankLevel"]).items()}
    class_set = set()
    seen_reagent = set()
    all_item_ids = set()
    for cls, lst in buffs.items():
        class_set.add(cls)
        bit = CLASS_BIT.get(cls)
        for b in lst:
            key = b["key"]
            where = "%s.%s" % (cls, key)
            pattern = BUFF_NAMES.get(key)
            if pattern is None:
                rep.note(where, "no expected name for key %r (names in this client: %s)" % (
                    key, [c.names.get(i) for i in b["ranks"]]))
            ranks, group = b.get("ranks", []), b.get("group", []) or []
            check_spell_ids(rep, c, where, ranks, pattern, bit, "rank")
            check_spell_ids(rep, c, where + ".group", group, pattern, None, "group id")
            check_order(rep, c, where, ranks, "single")
            check_order(rep, c, where + ".group", group, "group")
            check_complete(rep, c, where, pattern, bit, set(ranks) | set(group) | set(b.get("alike", []) or []))
            # alike: named as the other class's buff
            for i in b.get("alike", []) or []:
                name = c.names.get(i)
                if name is None:
                    rep.finding(where + ".alike", "id %d has no SpellName in this client" % i)
                    continue
                pat = ALIKE_NAMES.get(i)
                if pat is None or not name_ok(name, pat):
                    rep.note(where + ".alike", "id %d is %r (expected /%s/)" % (i, name, pat))
            # levels
            if not (b.get("talent") or b.get("selfCast")):
                for i in ranks:
                    lv = c.level_of(i)
                    have = rank_level.get(i)
                    if lv is None:
                        rep.note(where, "rank %d: no SpellLevels row" % i)
                    elif have is None:
                        if lv != 1:
                            rep.finding(where, "rank %d (%s) is learned at level %d; ns.RANK_LEVEL has no entry, so it counts as level 1" % (
                                i, c.names.get(i), lv))
                    elif have != lv:
                        rep.finding(where, "rank %d (%s): ns.RANK_LEVEL says %d, the client's SpellLevels says %d" % (
                            i, c.names.get(i), have, lv))
            else:
                for i in ranks:
                    lv, have = c.level_of(i), rank_level.get(i)
                    if have is not None and lv is not None and have != lv:
                        rep.note(where, "rank %d has RANK_LEVEL %d, the client says %d (the buff is talent/selfCast, so never read)" % (i, have, lv))
            # talent vs trained
            if ranks:
                top = ranks[-1]
                is_talent = any(i in c.talent_spells for i in ranks)
                trained = any(a["acquire"] in (1, 2) or a["class"] for a in c.sla.get(top, ()))
                if b.get("talent") and not is_talent and flavour != "mainline":
                    rep.note(where, "flagged talent, but no Talent row hands out any of its ranks (trained: %s)" % trained)
                if not b.get("talent") and is_talent:
                    rep.finding(where, "not flagged talent, but a Talent row hands out one of its ranks")
            # group casts
            for gc in b.get("groupCast", []) or []:
                gid, reagent = gc["id"], gc.get("reagent")
                if gid not in group and gid not in ranks:
                    rep.finding(where, "groupCast id %d is in neither ranks nor group" % gid)
                need = c.reagents.get(gid, [])
                items = [i for i, _ in need]
                if reagent is None and items:
                    rep.finding(where, "group cast %d (%s) eats %s in this client; the addon lists no reagent" % (
                        gid, c.names.get(gid), items))
                elif reagent is not None:
                    all_item_ids.add(reagent)
                    if reagent not in items:
                        rep.finding(where, "group cast %d (%s): addon says it eats item %d, the client's SpellReagents says %s" % (
                            gid, c.names.get(gid), reagent, need))
                    elif len(items) > 1:
                        rep.note(where, "group cast %d eats %s; the addon lists one" % (gid, need))
                seen_reagent.add(reagent)
            # the aura a cast lands is an id the addon matches
            matched = set(ranks) | set(group) | set(b.get("alike", []) or [])
            for cast in ranks + group:
                landed = aura_ids_of(c, cast)
                lost = sorted(a for a in landed if a not in matched
                              and not BENIGN_LANDED.fullmatch(c.names.get(a) or ""))
                if lost:
                    rep.note(where, "cast %d (%s) puts on aura id(s) %s not matched by the addon (%s)" % (
                        cast, c.names.get(cast), lost, ", ".join("%d %s" % (a, c.names.get(a)) for a in lost)))
                if not landed:
                    effs = c.effects.get(cast, [])
                    rep.note(where, "cast %d (%s) has no aura effect of its own and triggers none (effects: %s)" % (
                        cast, c.names.get(cast), [(e['effect'], e['aura'], e['trigger']) for e in effs]))
    # reagent item names
    if all_item_ids:
        found = c.item_names(all_item_ids)
        for item in sorted(all_item_ids):
            want = ITEM_NAMES.get(item)
            have = found.get(item)
            if have is None:
                rep.finding("reagents", "item %d is not in this client's ItemSparse" % item)
            elif want is None or norm(have) != norm(want):
                rep.finding("reagents", "item %d is %r in ItemSparse; the addon's notes call it %r" % (item, have, want))


def check_own(rep, c, d, flavour):
    own = as_map(d["own"])
    rank_level = {int(k): v for k, v in as_map(d["rankLevel"]).items()}
    scroll_items = set()
    for cls, families in own.items():
        bit = CLASS_BIT.get(cls)
        for fam in families:
            for spell in fam["spells"]:
                key = spell["key"]
                where = "own.%s.%s.%s" % (cls, fam["key"], key)
                ranks = spell.get("ranks", [])
                if spell.get("item"):
                    scroll_items.add(spell["item"])
                    continue
                pattern = OWN_NAMES.get(key)
                if pattern is None:
                    rep.note(where, "no expected name for key %r (names in this client: %s)" % (
                        key, [c.names.get(i) for i in ranks]))
                present = [i for i in ranks if i in c.names]
                absent = [i for i in ranks if i not in c.names]
                if not present:
                    rep.finding(where, "none of the ids %s exists in this client's SpellName" % ranks)
                    continue
                # an id absent here is fine when it is another client's (Forever's own ranks
                # on Forever only); but then the others must name the spell
                foreign = [i for i in absent if i >= 1000000]
                absent = [i for i in absent if i < 1000000]
                if foreign and flavour == "camelot":
                    rep.finding(where, "Forever's own ids %s are not in this client's SpellName" % foreign)
                if absent and flavour not in ("camelot",):
                    rep.note(where, "ids %s are not in this client's SpellName (the rest exist)" % absent)
                elif absent:
                    rep.finding(where, "ids %s are not in this client's SpellName" % absent)
                for i in present:
                    if pattern and not name_ok(c.names[i], pattern):
                        rep.finding(where, "id %d is named %r, expected /%s/" % (i, c.names[i], pattern))
                    bits = c.spell_class_bits(i)
                    if bit and bits and not (bits & bit) and not fam.get("tracking"):
                        rep.note(where, "id %d (%s) is not this class's in SkillLineAbility (mask %d)" % (i, c.names[i], bits))
                if not fam.get("tracking"):
                    check_order(rep, c, where, present, "own")
                    check_complete(rep, c, where, pattern, bit, set(ranks))
                # toggle / timed
                toggle = fam.get("toggle") or fam.get("tracking")
                top = present[0]
                dur = c.duration_ms(top)
                if not fam.get("tracking") and dur is not None:
                    if toggle and dur not in (-1, 0):
                        rep.note(where, "family is a toggle but %d lasts %s ms" % (top, dur))
                    if not toggle and dur in (-1, 0) and not spell.get("talent"):
                        rep.note(where, "family is not a toggle but %d (%s) has duration %s (until cancelled)" % (top, c.names.get(top), dur))
                # charges
                ch = spell.get("charges")
                got = c.charges.get(top)
                if ch is not None and got is not None and got != ch:
                    rep.finding(where, "charges=%d but SpellAuraOptions.ProcCharges of %d (%s) is %d" % (ch, top, c.names.get(top), got))
                if ch is None and got and got > 1 and not toggle:
                    rep.finding(where, "no `charges`, but %d (%s) has ProcCharges %d in this client, so one down to its last charge is never topped up" % (
                        top, c.names.get(top), got))
                # talent
                is_talent = any(i in c.talent_spells for i in present)
                if spell.get("talent") and not is_talent and flavour != "mainline":
                    rep.note(where, "flagged talent but no Talent row hands out any of its ids")
                if not spell.get("talent") and is_talent:
                    rep.finding(where, "not flagged talent, but a Talent row hands out one of its ids")
    return scroll_items


def check_favours(rep, c, d):
    for label, lst in (("favourOnly", d["favourOnly"]), ("notFavour", d["notFavour"])):
        for i in lst:
            name = c.names.get(i)
            if name is None:
                rep.finding(label, "id %d has no SpellName in this client" % i)
                continue
            pat = FAVOUR_NAMES.get(i)
            if pat is None:
                rep.note(label, "id %d is %r (no expected name recorded)" % (i, name))
            elif not name_ok(name, pat):
                rep.finding(label, "id %d is named %r, expected /%s/" % (i, name, pat))
            else:
                fx = c.effects.get(i, [])
                if label == "notFavour" and fx and not any(e["effect"] in AURA_EFFECTS for e in fx):
                    rep.note(label, "id %d (%s) has no aura effect: %s" % (i, name, [(e['effect'], e['aura']) for e in fx]))


def check_scrolls(rep, c, d):
    if d.get("flavour") != "camelot":
        return
    families = [f for fams in as_map(d["own"]).values() for f in fams if f.get("scroll")]
    items = {s["item"] for f in families for s in f["spells"]}
    names = c.item_names(items)
    p_ie, p_xie, p_se = (c.path("ItemEffect"), c.path("ItemXItemEffect"), c.path("SpellItemEnchantment"))
    effects_by_item = {}
    if p_ie and p_xie:
        ie = {num(r["ID"]): num(r["SpellID"]) for r in rows(p_ie)}
        for r in rows(p_xie):
            item = num(r["ItemID"])
            if item in items:
                effects_by_item.setdefault(item, []).append(ie.get(num(r["ItemEffectID"]), 0))
    ench = {}
    if p_se:
        for r in rows(p_se):
            ench[num(r["ID"])] = r["Name_lang"]
    equipped = {}
    p = c.path("SpellEquippedItems")
    for r in (rows(p) if p else ()):
        equipped.setdefault(num(r["SpellID"]), []).append((num(r["EquippedItemClass"]), num(r["EquippedItemSubclass"])))
    for f in families:
        for s in f["spells"]:
            where = "scroll.%s" % s["key"]
            item = s["item"]
            iname = names.get(item)
            if iname is None:
                rep.finding(where, "item %d is not in ItemSparse" % item)
                continue
            if not iname.lower().startswith("scroll"):
                rep.note(where, "item %d is %r (not named like a scroll)" % (item, iname))
            spells = effects_by_item.get(item, [])
            want = s["ranks"][0]
            if p_ie and want not in spells:
                rep.finding(where, "item %d (%s) uses spell(s) %s in ItemEffect; the addon casts %d (%s)" % (
                    item, iname, spells, want, c.names.get(want)))
            if want not in c.names:
                rep.note(where, "spell %d has no SpellName (named by the item then)" % want)
            if s.get("enchant") and p_se and s["enchant"] not in ench:
                rep.finding(where, "enchant %d is not in SpellItemEnchantment" % s["enchant"])
            elif s.get("enchant") and p_se:
                # the spell's own effect should be an ENCHANT_ITEM_TEMPORARY (54) with this enchant
                fx = [e for e in c.effects.get(want, []) if e["effect"] in (53, 54, 92)]
                if fx and all(e["misc0"] != s["enchant"] for e in fx):
                    rep.note(where, "spell %d enchants %s, the addon says %d (%s)" % (
                        want, [e["misc0"] for e in fx], s["enchant"], ench.get(s["enchant"])))
            if s.get("weapon") is not None and want in equipped:
                mask = 0
                for (_cls, sc) in equipped[want]:
                    mask |= sc
                if mask and not (mask >> s["weapon"]) & 1:
                    rep.finding(where, "spell %d wants weapon subclass mask %d (SpellEquippedItems); the addon says subclass %s" % (
                        want, mask, s["weapon"]))
            lvl = s.get("level")
            if lvl is not None:
                pass


# Spells whose aura is not what the addon should match, with the reason (the audit's NOTE
# for an aura a cast also puts on that no key names would otherwise repeat on every run).
BENIGN_LANDED = re.compile(r".* Highlight|\[DND\].*|Shout Rage Bonus", re.I)


def check_reach(rep, c, d, flavour):
    """The flags that say who a cast reaches, against the implicit targets and radii of
    the top rank's first aura effect (SpellEffect, SpellRadius)."""
    flags = as_map(d["flags"])
    wide = flags.get("wideCasts") is True
    yards_default = flags.get("shoutYards") or 20
    for cls, lst in as_map(d["buffs"]).items():
        for b in lst:
            top = b["ranks"][0]
            where = "%s.%s" % (cls, b["key"])
            fx = [e for e in c.effects.get(top, []) if e["effect"] in AURA_EFFECTS and e["aura"]]
            first = fx[0] if fx else None
            if b.get("selfCast"):
                if first is None:
                    rep.note(where, "selfCast but %d has no aura effect" % top)
                    continue
                yards = c.radius.get(first["radius"], 0)
                if first["t0"] not in (1, 20, 56):
                    rep.finding(where, "selfCast, but %d (%s) targets %d, not the caster's party or raid" % (
                        top, c.names.get(top), first["t0"]))
                elif b.get("partyOnly") and yards and abs(yards - yards_default) > 0.5:
                    rep.finding(where, "partyOnly shout reaches %g yards (SpellRadius %d); the addon's SHOUT_YARDS says %g" % (
                        yards, first["radius"], yards_default))
                if first["t0"] == 56 and flags.get("partyIsSubgroup"):
                    rep.finding(where, "target 56 is the caster's whole raid, but partyIsSubgroup says one subgroup")
                if first["t0"] == 20 and not flags.get("partyIsSubgroup") and flavour in ("vanilla", "camelot", "tbc"):
                    rep.note(where, "target 20 (the caster's party) with partyIsSubgroup off")
                continue
            if first is None:
                continue
            if b.get("groupOnly") and first["t0"] != 57:
                rep.finding(where, "groupOnly but %d targets %d, not 57 (your party or raid)" % (top, first["t0"]))
            if not b.get("groupOnly") and first["t0"] == 57:
                rep.finding(where, "%d targets 57 (your party or raid only) but the buff is not groupOnly" % top)
            if wide and not b.get("alone") and first["t0"] not in (118,):
                rep.note(where, "wideCasts client, but %d (%s) targets %d, not 118 (the target, or the whole group when it is in it)" % (
                    top, c.names.get(top), first["t0"]))
            if wide and b.get("alone") and first["t0"] == 118:
                rep.finding(where, "alone, but %d targets 118, which lands on the whole group" % top)
            if not wide and first["t0"] == 118:
                rep.finding(where, "%d targets 118 (group-wide) but the client's set has no wideCasts" % top)


def check_mana(rep, c, d, flavour):
    """ns.MANA_CLASSES, the class fallback for 'has a mana bar', against ChrClasses.DisplayPower."""
    held = set(d.get("manaClasses") or [])
    power = c.display_power
    # A monk stays (a Mistweaver is a mana user the class cannot name), whatever its class power.
    for tok, p in sorted(power.items()):
        if tok in ("Adventurer", "TRAVELER"):
            continue
        if p == 0 and tok not in held:
            rep.finding("MANA_CLASSES", "%s has a mana bar here (DisplayPower 0) but is not in ns.MANA_CLASSES" % tok)
        if p != 0 and tok in held and tok != "MONK":
            rep.finding("MANA_CLASSES", "%s is in ns.MANA_CLASSES, but its power here is %d (%s), not mana" % (
                tok, p, POWER_NAMES.get(p, "?")))


POWER_NAMES = {0: "mana", 1: "rage", 2: "focus", 3: "energy", 4: "combo points", 5: "runes", 6: "runic power",
               17: "fury"}


# Class buffs the addon deliberately does not hold (Buffs.lua: "emergency spells ... and
# anything that moves somebody", and the two magics that also work against their target).
DELIBERATELY_ABSENT = re.compile(r"Amplify Magic|Dampen Magic|Kindred Spirits|Corpse Exploder", re.I)


def check_gaps(rep, c, d, flavour):
    """Friendly, long auras a single class teaches that the addon neither offers, nor counts as a
    favour, nor lists as party aura or own buff: a buff a stranger gives you that is nobody's
    favour, or one you could give and are never offered. (An `alike` id does not count as held:
    it only says somebody wearing it needs no other of its kind.)"""
    held = set()
    for lst in as_map(d["buffs"]).values():
        for b in lst:
            held |= set(b["ranks"]) | set(b.get("group", []) or [])
    for fams in as_map(d["own"]).values():
        for f in fams:
            for sp in f["spells"]:
                held |= set(sp["ranks"])
    held |= set(d["favourOnly"]) | set(d["notFavour"])
    held_names = {c.names.get(i) for i in held}
    seen = set()
    for spell, rows in sorted(c.sla.items()):
        name = c.names.get(spell)
        if not name or spell in held or name in seen:
            continue
        mask = 0
        for r in rows:
            mask |= r["class"]
        if mask not in CLASS_BIT.values():
            continue
        # a rune or an engraving (Season of Discovery), not trained
        if all(r["acquire"] == 3 for r in rows):
            continue
        fx = [e for e in c.effects.get(spell, []) if e["effect"] in AURA_EFFECTS and e["aura"]]
        dur = c.duration_ms(spell)
        if not fx or dur is None or 0 <= dur < 300000:
            continue
        targets = {e["t0"] for e in fx}
        if not targets & {20, 21, 25, 37, 56, 57, 61, 118, 153}:
            continue
        if DELIBERATELY_ABSENT.fullmatch(name):
            continue
        seen.add(name)
        who = [k for k, v in CLASS_BIT.items() if v == mask][0]
        rep.note("gaps", "%s %r (%d, level %s, %ds, targets %s) is a friendly aura the addon holds nowhere%s" % (
            who, name, spell, c.level_of(spell), dur // 1000 if dur > 0 else dur, sorted(targets),
            "; another id of that name is held" if name in held_names else ""))


def check_races_classes(rep, c, d):
    races = {fs for fs, _ in c.races.values()}
    everywhere = set()
    for fl in FLAVOURS:
        cc = ALL_RACES.get(fl)
        if cc:
            everywhere |= cc
    for token in d["rpFamily"]:
        if token not in races and everywhere and token not in everywhere:
            rep.finding("RP.FAMILY", "race file %r is in no client's ChrRaces" % token)
    # races the client has that no family maps
    unmapped = sorted(r for r in races if r and r not in d["rpFamily"])
    if unmapped:
        rep.note("RP.FAMILY", "ChrRaces file names with no family (speak with the faction's voice): %s" % unmapped)
    classes = set(c.classes)
    held = set(as_map(d["buffs"])) | set(as_map(d["own"])) | set(d["classesWithout"]) | set(d["classesExclusive"])
    for tok in sorted(held):
        if tok not in classes:
            rep.finding("classes", "class token %r is not in this client's ChrClasses" % tok)
    # every class of the client has a buff, an own family, or is named in `without`
    known = set(as_map(d["buffs"])) | set(d["classesWithout"])
    for tok in sorted(classes):
        if tok not in known and not as_map(d["own"]).get(tok):
            rep.note("classes", "%s has no buff, no own family and is not in `without`" % tok)


def check_misc(rep, c, d):
    src = open(os.path.join(ROOT, "Clicks.lua"), encoding="utf-8").read()
    m = re.search(r"local GCD_SPELL = (\d+)", src)
    if m:
        gid = int(m.group(1))
        if gid not in c.names:
            rep.note("Clicks.GCD_SPELL", "spell %d (the global cooldown) is in none of this client's spell tables: "
                     "C_Spell.GetSpellCooldown answers nothing for it, so Clicks.lua reads one of the class's "
                     "buffs instead (GlobalCooldownReading), its 1.5 s guess last" % gid)
    rank_level = {int(k): v for k, v in as_map(d["rankLevel"]).items()}
    # RANK_LEVEL entries naming ids that are not spells here are dead weight, never wrong; skip.


def audit_dump(rep, c, d, flavour):
    check_buffs(rep, c, d, flavour)
    check_own(rep, c, d, flavour)
    check_favours(rep, c, d)
    check_scrolls(rep, c, d)
    check_races_classes(rep, c, d)
    check_reach(rep, c, d, flavour)
    check_mana(rep, c, d, flavour)
    check_gaps(rep, c, d, flavour)
    check_misc(rep, c, d)


def prefetch(flavours, cache, offline):
    """Every table for these clients, four downloads at a time."""
    import concurrent.futures
    jobs = [(fl, t) for fl in flavours for t in TABLES + EXTRA.get(fl, ()) + ("SpellRadius",)]
    jobs = sorted(set(jobs))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(lambda job: fetch(job[0], job[1], cache, offline, quiet=False), jobs))


def audit(flavour, cache, offline, notes):
    c = Client(flavour, cache, offline)
    rep = Report(flavour)
    d = addon_dump(flavour)
    if not d.get("buffs") and not d.get("own"):
        rep.finding("load", "the addon loaded no buffs for this client (source %r)" % d.get("source"))
    # materialise every table up front so a missing one is reported once
    for t in TABLES + EXTRA.get(flavour, ()):
        c.path(t)
    if c.missing:
        return c, d, False
    audit_dump(rep, c, d, flavour)
    return c, d, True


def selftest(cache, offline):
    """The audit goes red when a datum is wrong: Classic Era's dump is changed in seven ways, one
    after another, and each must produce the FINDING it exists for."""
    import copy
    fl = "vanilla"
    base = addon_dump(fl)
    c = Client(fl, cache, offline)
    for t in TABLES:
        c.path(t)
    if c.missing:
        print("audit_ids --selftest: tables missing: %s" % ", ".join(c.missing))
        return 2

    def mage(d):
        return [b for b in d["buffs"]["MAGE"] if b["key"] == "intellect"][0]

    def kings(d):
        return [b for b in d["buffs"]["PALADIN"] if b["key"] == "kings"][0]

    def change_level(d):
        d["rankLevel"]["1459"] = 99

    def drop_rank(d):
        mage(d)["ranks"].remove(10157)

    def wrong_reagent(d):
        mage(d)["groupCast"][0]["reagent"] = 17021

    def wrong_id(d):
        d["buffs"]["WARLOCK"][0]["ranks"] = [5697, 99999999]

    def kings_not_talent(d):
        kings(d).pop("talent")

    def shout_range(d):
        d["flags"]["shoutYards"] = 100

    def mana_warrior(d):
        d["manaClasses"].append("WARRIOR")

    cases = [
        ("a rank learned at another level than RANK_LEVEL says", change_level, "ns.RANK_LEVEL says 99"),
        ("a rank the client has that the addon dropped", drop_rank, "does not hold"),
        ("a reagent that is not what the spell eats", wrong_reagent, "SpellReagents"),
        ("an id the client does not have", wrong_id, "99999999 has no SpellName"),
        ("a talent not flagged as one", kings_not_talent, "not flagged talent"),
        ("a shout range that is not the spell's", shout_range, "SHOUT_YARDS"),
        ("a class with no mana bar among the mana classes", mana_warrior, "MANA_CLASSES"),
    ]
    clean = Report(fl)
    FINDINGS.clear()
    audit_dump(clean, c, copy.deepcopy(base), fl)
    baseline = [f for f in FINDINGS if f[1] == "FINDING"]
    failed = 0
    for label, mutate, want in cases:
        FINDINGS.clear()
        d = copy.deepcopy(base)
        mutate(d)
        audit_dump(Report(fl), c, d, fl)
        got = [f for f in FINDINGS if f[1] == "FINDING" and f not in baseline]
        hit = any(want in f[3] for f in got)
        print("%s: %s" % ("ok  " if hit else "FAIL", label))
        if not hit:
            failed += 1
            for f in got:
                print("      saw: %s" % (f,))
    return 1 if failed else 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--client", action="append", choices=FLAVOURS, help="a client (repeatable); default all five")
    ap.add_argument("--cache", default=os.environ.get("MANNERS_AUDIT_CACHE") or os.path.join(tempfile.gettempdir(), "manners-audit-cache"))
    ap.add_argument("--offline", action="store_true", help="download nothing")
    ap.add_argument("--fetch-only", action="store_true", help="fill the cache and stop")
    ap.add_argument("--notes", action="store_true", help="also print NOTE lines")
    ap.add_argument("--dump", choices=FLAVOURS, help="print the addon's side as JSON and stop")
    ap.add_argument("--selftest", action="store_true",
                    help="change Classic Era's dump in seven ways and check each one is caught")
    ap.add_argument("--build", action="append", default=[], metavar="CLIENT=BUILD",
                    help="audit against another build of that client (e.g. camelot=1.60.1.70338), "
                         "for data that moved since the build CLAUDE.md cites")
    args = ap.parse_args(argv)
    for spec in args.build:
        name, _, build = spec.partition("=")
        if name not in FLAVOURS or not re.fullmatch(r"\d+\.\d+\.\d+\.\d+", build):
            ap.error("--build wants CLIENT=X.Y.Z.BUILD, got %r" % spec)
        BUILD_OVERRIDE[name] = build

    if args.dump:
        print(json.dumps(addon_dump(args.dump), indent=1, sort_keys=True))
        return 0
    if args.selftest:
        return selftest(args.cache, args.offline)
    clients = args.client or list(FLAVOURS)
    if not args.offline:
        prefetch(clients, args.cache, args.offline)
        # The race files are checked against every client's ChrRaces, which is small.
        for fl in FLAVOURS:
            fetch(fl, "ChrRaces", args.cache, args.offline, quiet=True)
    if args.fetch_only:
        bad = sum(1 for fl in clients for t in TABLES + EXTRA.get(fl, ())
                  if fetch(fl, t, args.cache, True, quiet=True) is None)
        return 2 if bad else 0

    incomplete = False
    for fl in FLAVOURS:
        p = fetch(fl, "ChrRaces", args.cache, args.offline)
        if p:
            ALL_RACES[fl] = {r["ClientFileString"] for r in rows(p) if r["ClientFileString"]}
    for fl in clients:
        c, d, ok = audit(fl, args.cache, args.offline, args.notes)
        if not ok:
            incomplete = True
            print("%s: INCOMPLETE: tables missing: %s" % (fl, ", ".join(c.missing)))
    shown = {"FINDING": 0, "NOTE": 0}
    for client, kind, where, text in FINDINGS:
        shown[kind] += 1
        if kind == "NOTE" and not args.notes:
            continue
        print("%s: %s: %s: %s" % (client, kind, where, text))
    print("audit_ids: %d finding(s), %d note(s)%s" % (
        shown["FINDING"], shown["NOTE"], "" if args.notes or not shown["NOTE"] else " (--notes prints them)"))
    if incomplete:
        return 2
    return 1 if shown["FINDING"] else 0


if __name__ == "__main__":
    sys.exit(main())
