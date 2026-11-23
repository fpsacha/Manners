-- Manners -- the buttons for the moment, their data: which small buttons a
-- class offers in a fight and what each one waits for (Prompt/Moments.lua
-- builds them, Prompt/MomentsSense.lua reads the situation). One table per
-- client data set, chosen by ns.Flavour.flavour as Cures.lua chooses its own;
-- nothing else here branches on a client. A client with no set gets none.
--
-- ns.MOMENTS is the chosen set: CLASS -> rows in the order the buttons sit.
-- Only the mage's set ships now; another class adds its own rows to each set
-- (Kick, Pummel, Earth Shock ...) and the same code builds them.
--
-- One row:
--   key        the profile field moments.<key> and the options key's suffix
--   slot       1..10, the frame MannersMoment<slot> and its key binding; a role
--              keeps its number in every class's set (1 is the interrupt)
--   ranks      spell ids, highest rank first; or items + makes (a mana gem and
--              the spells that conjure one)
--   needs      the signals that must all be true, cheapest and plainest first
--              (Prompt/MomentsSense.lua names them)
--   stop       "/stopcasting" before the cast, so the press fires at once
--   self       the cast must land on you
--   peace      works out of a fight too
--   blind      "weak" or "dark": what a needed value the game hides and no call
--              takes does to the button (default dark)
--   guard      "twice": while only the game knows whether it is lit, it takes
--              two quick clicks
--   cooldown   seconds, for Manners' own clock; shares, resets, partner,
--              school, breaks, lockout, reagent, seconds: see Sense
--
-- The ids are the ones each client's spell book names (data-sources.md).

local _, ns = ...

local function Row(fields) return fields end

-- Forever (camelot) and Classic Era (vanilla): Ice Block and Cold Snap are
-- talents there, learned or not by the spell book.
local OLD = {
	MAGE = {
		Row { key = "counterspell", slot = 1, ranks = { 2139 }, stop = true, blind = "weak", cooldown = 30,
			needs = { "fight", "ready", "enemy", "casting", "interruptible", "inrange", "usable" } },
		Row { key = "iceblock", slot = 2, ranks = { 11958 }, stop = true, guard = "twice", cooldown = 300,
			needs = { "fight", "ready", "usable", "lowhealth" } },
		Row { key = "blink", slot = 3, ranks = { 1953 }, stop = true, blind = "weak", cooldown = 15,
			breaks = { STUN = true, STUN_MECHANIC = true, ROOT = true },
			needs = { "fight", "stuck", "ready", "usable" } },
		Row { key = "evocation", slot = 4, ranks = { 12051 }, guard = "twice", cooldown = 480,
			needs = { "fight", "ready", "lowmana" } },
		Row { key = "managem", slot = 5, items = { 8008, 8007, 5513, 5514 }, makes = { 10054, 10053, 3552, 759 },
			guard = "twice", cooldown = 120, needs = { "fight", "itemready", "lowmana" } },
		Row { key = "slowfall", slot = 6, ranks = { 130 }, peace = true, self = true, reagent = 17056, seconds = 30,
			needs = { "falling", "usable" } },
		Row { key = "coldsnap", slot = 7, ranks = { 12472 }, partner = "iceblock", resets = { "iceblock", "frostward" },
			stop = true, guard = "twice", cooldown = 600,
			needs = { "fight", "ready", "partnercooling", "lowhealth" } },
		Row { key = "fireward", slot = 9, ranks = { 10225, 10223, 8458, 8457, 543 }, school = 4, shares = "frostward",
			stop = true, cooldown = 30,
			needs = { "fight", "ready", "usable", "enemy", "schoolhit" } },
		Row { key = "frostward", slot = 10, ranks = { 28609, 10177, 8462, 8461, 6143 }, school = 16, shares = "fireward",
			stop = true, cooldown = 30,
			needs = { "fight", "ready", "usable", "enemy", "schoolhit" } },
	},
}

local TBC = {
	MAGE = {
		Row { key = "counterspell", slot = 1, ranks = { 2139 }, stop = true, blind = "weak", cooldown = 24,
			needs = { "fight", "ready", "enemy", "casting", "interruptible", "inrange", "usable" } },
		Row { key = "iceblock", slot = 2, ranks = { 45438 }, stop = true, guard = "twice", cooldown = 300,
			lockout = { aura = 41425, seconds = 30 },
			needs = { "fight", "ready", "usable", "lowhealth", "nolockout" } },
		Row { key = "blink", slot = 3, ranks = { 1953 }, stop = true, blind = "weak", cooldown = 15,
			breaks = { STUN = true, STUN_MECHANIC = true, ROOT = true },
			needs = { "fight", "stuck", "ready", "usable" } },
		Row { key = "evocation", slot = 4, ranks = { 12051 }, guard = "twice", cooldown = 480,
			needs = { "fight", "ready", "lowmana" } },
		Row { key = "managem", slot = 5, items = { 22044, 8008, 8007, 5513, 5514 },
			makes = { 27101, 10054, 10053, 3552, 759 },
			guard = "twice", cooldown = 120, needs = { "fight", "itemready", "lowmana" } },
		Row { key = "slowfall", slot = 6, ranks = { 130 }, peace = true, self = true, reagent = 17056, seconds = 30,
			needs = { "falling", "usable" } },
		Row { key = "coldsnap", slot = 7, ranks = { 11958 }, partner = "iceblock", resets = { "iceblock", "frostward" },
			stop = true, guard = "twice", cooldown = 480,
			needs = { "fight", "ready", "partnercooling", "lowhealth" } },
		Row { key = "spellsteal", slot = 8, ranks = { 30449 }, stop = true,
			needs = { "fight", "ready", "usable", "enemy", "inrange", "stealable" } },
		Row { key = "fireward", slot = 9, ranks = { 27128, 10225, 10223, 8458, 8457, 543 }, school = 4, shares = "frostward",
			stop = true, cooldown = 30,
			needs = { "fight", "ready", "usable", "enemy", "schoolhit" } },
		Row { key = "frostward", slot = 10, ranks = { 32796, 28609, 10177, 8462, 8461, 6143 }, school = 16, shares = "fireward",
			stop = true, cooldown = 30,
			needs = { "fight", "ready", "usable", "enemy", "schoolhit" } },
	},
}

local MISTS = {
	MAGE = {
		Row { key = "counterspell", slot = 1, ranks = { 2139 }, stop = true, blind = "weak", cooldown = 24,
			needs = { "fight", "ready", "enemy", "casting", "interruptible", "inrange", "usable" } },
		Row { key = "iceblock", slot = 2, ranks = { 45438 }, stop = true, guard = "twice", cooldown = 300,
			lockout = { aura = 41425, seconds = 30 },
			needs = { "fight", "ready", "usable", "lowhealth", "nolockout" } },
		Row { key = "blink", slot = 3, ranks = { 1953 }, stop = true, blind = "weak", cooldown = 15,
			breaks = { STUN = true, STUN_MECHANIC = true, ROOT = true },
			needs = { "fight", "stuck", "ready", "usable" } },
		Row { key = "evocation", slot = 4, ranks = { 12051 }, guard = "twice", cooldown = 120,
			needs = { "fight", "ready", "lowmana" } },
		Row { key = "managem", slot = 5, items = { 36799 }, makes = { 759 },
			guard = "twice", cooldown = 120, needs = { "fight", "itemready", "lowmana" } },
		Row { key = "slowfall", slot = 6, ranks = { 130 }, peace = true, self = true, seconds = 30,
			needs = { "falling", "usable" } },
		Row { key = "coldsnap", slot = 7, ranks = { 11958 }, partner = "iceblock", resets = { "iceblock" },
			stop = true, guard = "twice", cooldown = 180,
			needs = { "fight", "ready", "partnercooling", "lowhealth" } },
		Row { key = "spellsteal", slot = 8, ranks = { 30449 }, stop = true,
			needs = { "fight", "ready", "usable", "enemy", "inrange", "stealable" } },
	},
}

local MAINLINE = {
	MAGE = {
		Row { key = "counterspell", slot = 1, ranks = { 2139 }, stop = true, blind = "weak", cooldown = 24,
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
		Row { key = "spellsteal", slot = 8, ranks = { 30449 }, stop = true,
			needs = { "fight", "ready", "usable", "enemy", "inrange", "stealable" } },
	},
}

local SETS = { camelot = OLD, vanilla = OLD, tbc = TBC, mists = MISTS, mainline = MAINLINE }

-- The profile's defaults for every key any set may name (Core.lua repeats
-- them in defaults.profile.moments; a scenario holds the two together).
ns.MOMENT_DEFAULTS = { counterspell = true, spellsteal = true, blink = true, iceblock = true, coldsnap = true,
	evocation = true, managem = true, slowfall = true, fireward = true, frostward = true }

-- The keys of every row, in the order the options page lists them, for the
-- scenarios and the reset list.
ns.MOMENT_KEYS = { "counterspell", "spellsteal", "blink", "iceblock", "coldsnap", "evocation", "managem",
	"slowfall", "fireward", "frostward" }

local flavour = ns.Flavour and ns.Flavour.flavour
ns.MOMENTS = SETS[flavour] or {}
-- The sets, for a scenario that holds each client's rows to the rules.
ns.MOMENT_SETS = SETS
