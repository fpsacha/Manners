-- Manners -- the buttons for the moment, their data: which small buttons a
-- class offers in a fight and what each one waits for (Prompt/Moments.lua
-- builds them, Prompt/MomentsSense.lua reads the situation). One table per
-- client data set, chosen by ns.Flavour.flavour as Cures.lua chooses its own;
-- nothing else here branches on a client. A client with no set gets none.
--
-- ns.MOMENTS is the chosen set: CLASS -> rows in the order the buttons sit.
-- The mage's rows are in the sets; every class with mana also gets the drink
-- row (AddDrinks below). Another class adds its own rows to each set (Kick,
-- Pummel, Earth Shock ...) and the same code builds them.
--
-- One row:
--   key        the profile field moments.<key> and the options key's suffix
--   slot       1..11, the frame MannersMoment<slot> and its key binding; a role
--              keeps its number in every class's set (1 is the interrupt)
--   ranks      spell ids, highest rank first; or items + makes (a mana gem and
--              the spells that conjure one)
--   needs      the signals that must all be true, cheapest and plainest first
--              (Prompt/MomentsSense.lua names them)
--   stop       "/stopcasting" before the cast or the use of an item, so the press
--              fires at once (a cast under way refuses a channel and an item)
--   self       the cast must land on you
--   peace      works out of a fight too
--   calm       the reverse: out of a fight only (the driver hides it at the
--              pull and the pull clears its macro)
--   drink      the client's "Drink" spell id: its name is how a drink item, a
--              drink cast and the Drink aura are recognised (the drink row)
--   forms      not while shapeshifted (a druid, a shaman's Ghost Wolf)
--   blind      "weak" or "dark": what a needed value the game hides and no call
--              takes does to the button (default dark)
--   guard      "twice": while only the game knows whether it is lit (a hidden
--              health, mana, interrupt flag, stealable flag or the school of a
--              cast), it takes two quick clicks, at least a third of a second apart
--   cooldown   seconds, for Manners' own clock; shares, resets, partner,
--              school, breaks, lockout, reagent, seconds: see Sense
--   kinds      the aura kinds (dispelName) the spell strips from a hostile target,
--              for `removable`: "Magic", and "" and "Enrage" for an enrage
--   purge      the spell removes magic: the game's isStealable flag (stolen or
--              purged by you) counts too, and carries the hidden route
--
-- The ids are the ones each client's spell book names (data-sources.md).

local _, ns = ...

local function Row(fields) return fields end

-- Slot 8 strips a buff from a hostile target: the mage's Spellsteal, and the
-- spells of the other classes that remove one (the dispel effect of each, read
-- from SpellEffect at the builds data-sources.md cites: kind 1 Magic, 9 Enrage).
local MAGIC = { Magic = true }
local ENRAGE = { [""] = true, Enrage = true }
local ENRAGE_MAGIC = { [""] = true, Enrage = true, Magic = true }
local STRIP = { "fight", "ready", "usable", "enemy", "inrange", "removable" }
local function Strip(key, ranks, kinds, extra)
	local row = Row { key = key, slot = 8, ranks = ranks, kinds = kinds, purge = kinds.Magic == true, stop = true,
		guard = "twice", needs = STRIP }
	for field, value in pairs(extra or {}) do row[field] = value end
	return row
end
-- A warrior's Shield Slam: no "/stopcasting" (it would cancel a Slam under way).
local function Slam(ranks)
	return Strip("shieldslam", ranks, MAGIC, { stop = false, cooldown = 6 })
end
local function AddStrips(set, rows)
	for class, row in pairs(rows) do
		local list = set[class] or {}
		set[class] = list
		list[#list + 1] = row
	end
end

-- Forever (camelot) and Classic Era (vanilla): Ice Block and Cold Snap are
-- talents there, learned or not by the spell book.
local OLD = {
	MAGE = {
		Row { key = "counterspell", slot = 1, ranks = { 2139 }, stop = true, guard = "twice", blind = "weak", cooldown = 30,
			needs = { "fight", "ready", "enemy", "casting", "interruptible", "inrange", "usable" } },
		Row { key = "iceblock", slot = 2, ranks = { 11958 }, stop = true, guard = "twice", cooldown = 300,
			needs = { "fight", "ready", "usable", "lowhealth" } },
		Row { key = "blink", slot = 3, ranks = { 1953 }, stop = true, blind = "weak", cooldown = 15,
			breaks = { STUN = true, STUN_MECHANIC = true, ROOT = true },
			needs = { "fight", "stuck", "ready", "usable" } },
		Row { key = "evocation", slot = 4, ranks = { 12051 }, stop = true, guard = "twice", cooldown = 480,
			needs = { "fight", "ready", "lowmana" } },
		Row { key = "managem", slot = 5, items = { 8008, 8007, 5513, 5514 }, makes = { 10054, 10053, 3552, 759 },
			stop = true, guard = "twice", cooldown = 120, needs = { "fight", "itemready", "lowmana" } },
		Row { key = "slowfall", slot = 6, ranks = { 130 }, peace = true, self = true, reagent = 17056, seconds = 30,
			needs = { "falling", "usable" } },
		Row { key = "coldsnap", slot = 7, ranks = { 12472 }, partner = "iceblock", resets = { "iceblock", "frostward" },
			stop = true, guard = "twice", cooldown = 600,
			needs = { "fight", "ready", "partnercooling", "lowhealth" } },
		Row { key = "fireward", slot = 9, ranks = { 10225, 10223, 8458, 8457, 543 }, school = 4, shares = "frostward",
			stop = true, guard = "twice", cooldown = 30,
			needs = { "fight", "ready", "usable", "enemy", "schoolhit" } },
		Row { key = "frostward", slot = 10, ranks = { 28609, 10177, 8462, 8461, 6143 }, school = 16, shares = "fireward",
			stop = true, guard = "twice", cooldown = 30,
			needs = { "fight", "ready", "usable", "enemy", "schoolhit" } },
	},
}

local TBC = {
	MAGE = {
		Row { key = "counterspell", slot = 1, ranks = { 2139 }, stop = true, guard = "twice", blind = "weak", cooldown = 24,
			needs = { "fight", "ready", "enemy", "casting", "interruptible", "inrange", "usable" } },
		Row { key = "iceblock", slot = 2, ranks = { 45438 }, stop = true, guard = "twice", cooldown = 300,
			lockout = { aura = 41425, seconds = 30 },
			needs = { "fight", "ready", "usable", "lowhealth", "nolockout" } },
		Row { key = "blink", slot = 3, ranks = { 1953 }, stop = true, blind = "weak", cooldown = 15,
			breaks = { STUN = true, STUN_MECHANIC = true, ROOT = true },
			needs = { "fight", "stuck", "ready", "usable" } },
		Row { key = "evocation", slot = 4, ranks = { 12051 }, stop = true, guard = "twice", cooldown = 480,
			needs = { "fight", "ready", "lowmana" } },
		Row { key = "managem", slot = 5, items = { 22044, 8008, 8007, 5513, 5514 },
			makes = { 27101, 10054, 10053, 3552, 759 },
			stop = true, guard = "twice", cooldown = 120, needs = { "fight", "itemready", "lowmana" } },
		Row { key = "slowfall", slot = 6, ranks = { 130 }, peace = true, self = true, reagent = 17056, seconds = 30,
			needs = { "falling", "usable" } },
		Row { key = "coldsnap", slot = 7, ranks = { 11958 }, partner = "iceblock", resets = { "iceblock", "frostward" },
			stop = true, guard = "twice", cooldown = 480,
			needs = { "fight", "ready", "partnercooling", "lowhealth" } },
		Row { key = "spellsteal", slot = 8, ranks = { 30449 }, stop = true, guard = "twice",
			needs = { "fight", "ready", "usable", "enemy", "inrange", "stealable" } },
		Row { key = "fireward", slot = 9, ranks = { 27128, 10225, 10223, 8458, 8457, 543 }, school = 4, shares = "frostward",
			stop = true, guard = "twice", cooldown = 30,
			needs = { "fight", "ready", "usable", "enemy", "schoolhit" } },
		Row { key = "frostward", slot = 10, ranks = { 32796, 28609, 10177, 8462, 8461, 6143 }, school = 16, shares = "fireward",
			stop = true, guard = "twice", cooldown = 30,
			needs = { "fight", "ready", "usable", "enemy", "schoolhit" } },
	},
}

local MISTS = {
	MAGE = {
		Row { key = "counterspell", slot = 1, ranks = { 2139 }, stop = true, guard = "twice", blind = "weak", cooldown = 24,
			needs = { "fight", "ready", "enemy", "casting", "interruptible", "inrange", "usable" } },
		Row { key = "iceblock", slot = 2, ranks = { 45438 }, stop = true, guard = "twice", cooldown = 300,
			lockout = { aura = 41425, seconds = 30 },
			needs = { "fight", "ready", "usable", "lowhealth", "nolockout" } },
		Row { key = "blink", slot = 3, ranks = { 1953 }, stop = true, blind = "weak", cooldown = 15,
			breaks = { STUN = true, STUN_MECHANIC = true, ROOT = true },
			needs = { "fight", "stuck", "ready", "usable" } },
		Row { key = "evocation", slot = 4, ranks = { 12051 }, stop = true, guard = "twice", cooldown = 120,
			needs = { "fight", "ready", "lowmana" } },
		Row { key = "managem", slot = 5, items = { 36799 }, makes = { 759 },
			stop = true, guard = "twice", cooldown = 120, needs = { "fight", "itemready", "lowmana" } },
		Row { key = "slowfall", slot = 6, ranks = { 130 }, peace = true, self = true, seconds = 30,
			needs = { "falling", "usable" } },
		Row { key = "coldsnap", slot = 7, ranks = { 11958 }, partner = "iceblock", resets = { "iceblock" },
			stop = true, guard = "twice", cooldown = 180,
			needs = { "fight", "ready", "partnercooling", "lowhealth" } },
		Row { key = "spellsteal", slot = 8, ranks = { 30449 }, stop = true, guard = "twice",
			needs = { "fight", "ready", "usable", "enemy", "inrange", "stealable" } },
	},
}

local MAINLINE = {
	MAGE = {
		Row { key = "counterspell", slot = 1, ranks = { 2139 }, stop = true, guard = "twice", blind = "weak", cooldown = 24,
			needs = { "fight", "ready", "enemy", "casting", "interruptible", "inrange", "usable" } },
		-- Blink 1953 only: 212653 (Shimmer) does not free you from a stun, and a
		-- mage who took it does not know 1953 and gets no Blink button.
		Row { key = "blink", slot = 3, ranks = { 1953 }, stop = true, blind = "weak", cooldown = 15,
			breaks = { STUN = true, STUN_MECHANIC = true, ROOT = true },
			needs = { "fight", "stuck", "ready", "usable" } },
		Row { key = "iceblock", slot = 2, ranks = { 45438 }, stop = true, guard = "twice", cooldown = 240,
			lockout = { aura = 41425, seconds = 30 },
			needs = { "fight", "ready", "usable", "lowhealth", "nolockout" } },
		Row { key = "slowfall", slot = 6, ranks = { 130 }, peace = true, self = true, seconds = 30,
			needs = { "falling", "usable" } },
		Row { key = "coldsnap", slot = 7, ranks = { 235219 }, partner = "iceblock", resets = { "iceblock" },
			stop = true, guard = "twice", cooldown = 300,
			needs = { "fight", "ready", "partnercooling", "lowhealth" } },
		Row { key = "spellsteal", slot = 8, ranks = { 30449 }, stop = true, guard = "twice",
			needs = { "fight", "ready", "usable", "enemy", "inrange", "stealable" } },
	},
}

-- The other classes' strips, slot 8 like Spellsteal: Purge 8012/370, Dispel Magic
-- 988/527 (528 on Mists and retail, where 527 is Purify), Tranquilizing Shot 19801
-- (an enrage on Forever, Classic Era and Burning Crusade; an enrage or magic on
-- Mists and retail), Shield Slam 23922.. (magic; retail's no longer dispels).
local SLAM_OLD = { 23925, 23924, 23923, 23922 }
AddStrips(OLD, { SHAMAN = Strip("purge", { 8012, 370 }, MAGIC), PRIEST = Strip("dispel", { 988, 527 }, MAGIC),
	HUNTER = Strip("tranq", { 19801 }, ENRAGE, { cooldown = 20 }), WARRIOR = Slam(SLAM_OLD) })
AddStrips(TBC, { SHAMAN = Strip("purge", { 8012, 370 }, MAGIC), PRIEST = Strip("dispel", { 988, 527 }, MAGIC),
	HUNTER = Strip("tranq", { 19801 }, ENRAGE, { cooldown = 20 }),
	WARRIOR = Slam({ 30356, 25258, 23925, 23924, 23923, 23922 }) })
AddStrips(MISTS, { SHAMAN = Strip("purge", { 370 }, MAGIC), PRIEST = Strip("dispel", { 528 }, MAGIC),
	HUNTER = Strip("tranq", { 19801 }, ENRAGE_MAGIC), WARRIOR = Slam({ 23922 }) })
AddStrips(MAINLINE, { SHAMAN = Strip("purge", { 370 }, MAGIC), PRIEST = Strip("dispel", { 528 }, MAGIC),
	HUNTER = Strip("tranq", { 19801 }, ENRAGE_MAGIC, { cooldown = 10 }) })

-- The drink, out of a fight, for every class that keeps a mana bar (a hunter
-- uses focus on Mists and retail, a warrior or a rogue has none). `forms` is
-- true only where a shapeshift stops you drinking (a druid, a shaman's Ghost
-- Wolf): on Mists a paladin's seal, shadowform and a monk's stance also report
-- as forms, so those must not get the flag. The press is /use item:<best drink
-- in the bags> (Prompt/Moments.lua); slot 11.
local function Drink(forms)
	return Row { key = "drink", slot = 11, drink = 430, peace = true, calm = true, forms = forms, guard = "twice",
		seconds = 30, needs = { "calm", "drinkheld", "still", "notdrinking", "lowmana" } }
end
local function AddDrinks(set, classes)
	for class, forms in pairs(classes) do
		local rows = set[class] or {}
		set[class] = rows
		rows[#rows + 1] = Drink(forms)
	end
end
local WITH_MANA_OLD = { DRUID = true, HUNTER = false, MAGE = false, PALADIN = false, PRIEST = false, SHAMAN = true,
	WARLOCK = false }
AddDrinks(OLD, WITH_MANA_OLD)
AddDrinks(TBC, WITH_MANA_OLD)
AddDrinks(MISTS, { DRUID = true, MAGE = false, MONK = false, PALADIN = false, PRIEST = false, SHAMAN = true,
	WARLOCK = false })
AddDrinks(MAINLINE, { DRUID = true, EVOKER = false, MAGE = false, MONK = false, PALADIN = false, PRIEST = false,
	SHAMAN = true, WARLOCK = false })

local SETS = { camelot = OLD, vanilla = OLD, tbc = TBC, mists = MISTS, mainline = MAINLINE }

-- The profile's defaults for every key any set may name (Core.lua repeats
-- them in defaults.profile.moments; a scenario holds the two together).
ns.MOMENT_DEFAULTS = { counterspell = true, spellsteal = true, blink = true, iceblock = true, coldsnap = true,
	evocation = true, managem = true, drink = true, slowfall = true, fireward = true, frostward = true,
	-- A warrior presses Shield Slam anyway: its button waits to be asked for.
	purge = true, dispel = true, tranq = true, shieldslam = false }

-- The keys of every row, in the order the options page lists them, for the
-- scenarios and the reset list.
ns.MOMENT_KEYS = { "counterspell", "spellsteal", "purge", "dispel", "tranq", "shieldslam", "blink", "iceblock",
	"coldsnap", "evocation", "managem", "drink", "slowfall", "fireward", "frostward" }

local flavour = ns.Flavour and ns.Flavour.flavour
ns.MOMENTS = SETS[flavour] or {}
-- The spells of this client with a cast bar that burn (4) or freeze (16), or
-- both (20): CastSchools.lua, generated from the client's own spell data. The
-- wards read it (Prompt/MomentsSense.lua); the other clients' tables are let go.
ns.CAST_SCHOOLS = (ns.CAST_SCHOOLS_BY_CLIENT or {})[flavour] or {}
ns.CAST_SCHOOLS_BY_CLIENT = nil
-- The sets, for a scenario that holds each client's rows to the rules.
ns.MOMENT_SETS = SETS
