-- Manners -- a class's courtesies beyond buffs, on request: a mage's water,
-- food and portals, a warlock's healthstone and summon.
--
-- Requests.lua reads chat for somebody asking for a buff. The same reader is
-- handed the names below (Courtesy.Named, from its Asks), so "water pls",
-- "port to Orgrimmar?" and "hs pls" are read by the same rules as "int pls":
-- eight words at most, nothing that says no, a please or an opener or nothing
-- but the name. What was asked for goes on the request it keeps as a key of
-- its own ("courtesy:water", "courtesy:portal:11417"), which no buff has, so a
-- courtesy is never read as a buff request, nor "buff pls" as a courtesy.
--
-- The queue then gets one entry for whoever asked (Courtesy.Queue, from
-- BuildQueue), under the reason "asked", and the prompt arms it like any
-- other (Prompt/Macro.lua, STRATEGIES.courtesy). What a press does:
--
--   water, food, a healthstone   with none in the bags that suits them, the
--       press conjures it and targets nobody; with one, it targets them and
--       opens a trade (the client's own /trade), and when the window opens
--       Manners puts the item in it. Picking an item up from the bags and
--       setting it in a trade slot are calls any addon may make out of a
--       fight on all five clients (C_Container.PickupContainerItem carries no
--       restriction in Blizzard's API documentation, and ClickTradeButton is
--       what the game's own trade window calls from unprotected code).
--       Manners never accepts a trade.
--   a portal   /cast Portal: <city>, nobody targeted; for a member of your
--       party or raid, with the city learned and a Rune of Portals in the bags
--       where the client asks for one.
--   a summon   targets the member who asked and casts Ritual of Summoning,
--       leaving them targeted: the portal's clicks summon your target.
--   a healthstone on Mists and retail, where a warlock makes them for the
--       group at a Soulwell: /cast Create Soulwell, for a member of the group.
--
-- A mage's water and food are also offered to your target, with nobody having
-- asked (sources.courtesyTarget, Aimed below): a friendly player you target out
-- of a fight, who is not a mage, gets what suits their level, or food alone
-- where they have no mana. The entry is filed under the reason "target" at the
-- tier of a request. Once they were traded with or skipped they are left alone
-- for TARGET_REST. Water and food trades are filled (sources.courtesyAmount):
-- the trade window takes as many stacks of what suits them as it has free
-- slots and the bags hold, water and food in turn, or one stack of each.
--
-- Nothing here is offered or armed in a fight: the queue gets no courtesy
-- from the pull's own repaint on (Prompt.armedForFight), so none is frozen on
-- the button or handed to the fight's rota.
--
-- A rogue's Pick Lock is left out. The cast has to be aimed at the box in the
-- other player's trade slot, which is a /click on the trade window's own
-- button after the cast: a shape the bar macro's writer refuses (Clicks.lua,
-- Shaped), and one that rests on the asker having opened the trade and set
-- the box in the seventh slot first, which the prompt cannot see coming.
--
-- Each kind has a switch under "People who ask me in chat", off until ticked
-- (sources.courtesyRefresh, courtesyPortals, courtesyHealthstones,
-- courtesySummons), shown for the class that has it on this client.

local ns = select(2, ...)
local L = ns.L
local addon = ns.addon

local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- Core.lua's, Queue.lua's and GroupBuffs.lua's, which load first.
local plain, safecall = ns.plain, ns.safecall
local ShortName, FirstName, SameName = ns.ShortName, ns.FirstName, ns.SameName

local Courtesy = {}
ns.Courtesy = Courtesy

---------------------------------------------------------------------------
-- what each client has
--
-- From each client's own tables (wago.tools, the builds .claude/docs/data-sources.md cites):
-- SkillLineAbility for the class, SpellEffect's created item (effect 24) for
-- what a conjure makes, ItemSparse for the level an item asks of whoever
-- drinks it and for the Improved Healthstone copies (the same name, three
-- ids), SpellReagents for the rune and the shard. A row is the rank, the
-- level its item needs and the items it can leave in the bags, best first.
---------------------------------------------------------------------------

local RUNE_OF_PORTALS, SOUL_SHARD = 17032, 6265

local VANILLA_WATER = {
	{ spell = 10140, level = 55, items = { 8079 } },
	{ spell = 10139, level = 45, items = { 8078 } },
	{ spell = 10138, level = 35, items = { 8077 } },
	{ spell = 6127, level = 25, items = { 3772 } },
	{ spell = 5506, level = 15, items = { 2136 } },
	{ spell = 5505, level = 5, items = { 2288 } },
	{ spell = 5504, level = 1, items = { 5350 } },
}
local VANILLA_FOOD = {
	{ spell = 28612, level = 55, items = { 22895 } },
	{ spell = 10145, level = 45, items = { 8076 } },
	{ spell = 10144, level = 35, items = { 8075 } },
	{ spell = 6129, level = 25, items = { 1487 } },
	{ spell = 990, level = 15, items = { 1114 } },
	{ spell = 597, level = 5, items = { 1113 } },
	{ spell = 587, level = 1, items = { 5349 } },
}
local VANILLA_STONES = {
	{ spell = 11730, level = 48, items = { 9421, 19012, 19013 } },
	{ spell = 11729, level = 36, items = { 5510, 19010, 19011 } },
	{ spell = 5699, level = 24, items = { 5509, 19008, 19009 } },
	{ spell = 6202, level = 12, items = { 5511, 19006, 19007 } },
	{ spell = 6201, level = 1, items = { 5512, 19004, 19005 } },
}

-- `rows` first, then the rest of `more`: a later client's ranks over an
-- earlier one's.
local function Over(rows, more)
	local out = {}
	for _, row in ipairs(rows) do out[#out + 1] = row end
	for _, row in ipairs(more) do out[#out + 1] = row end
	return out
end

-- Classic Era and Forever: Season of Discovery's Conjure Water (468766, its
-- Mountain Spring Water) leads where it is learned.
local ERA_WATER = Over({ { spell = 468766, level = 55, items = { 231778 } } }, VANILLA_WATER)

-- The one spell of Mists and retail makes what suits the mage's own level,
-- water and food in one, so there is no rank to pick for anybody. On Mists
-- each item still asks a level of whoever eats it (`needs`, ItemSparse's
-- RequiredLevel; retail's copies ask none): somebody below it is handed only
-- what the bags hold that suits them, and nothing is conjured that would not.
local MISTS_REFRESHMENT = {
	{ spell = 42955, items = { 80610, 65499, 43523, 43518, 34062, 65517, 65516, 65515, 65500 },
		needs = { [80610] = 90, [65499] = 85, [43523] = 80, [43518] = 74, [34062] = 65, [65517] = 64,
			[65516] = 54, [65515] = 44, [65500] = 34 } },
}
local RETAIL_REFRESHMENT = {
	{ spell = 190336, items = { 113509, 80610, 65499, 43523, 43518, 65517, 65516, 65515, 65500 } },
}

local SETTING = {
	water = "courtesyRefresh", food = "courtesyRefresh", portal = "courtesyPortals",
	healthstone = "courtesyHealthstones", summon = "courtesySummons",
}
-- The order they are told in, and the order one request naming two is
-- answered in.
local ORDER = { "water", "food", "healthstone", "summon", "portal" }

local SETS = {}
SETS.vanilla = {
	MAGE = {
		water = { rows = ERA_WATER },
		food = { rows = VANILLA_FOOD },
		portal = { spells = { 10059, 11416, 11419, 11417, 11418, 11420 }, reagent = RUNE_OF_PORTALS },
	},
	WARLOCK = {
		healthstone = { rows = VANILLA_STONES, reagent = SOUL_SHARD },
		summon = { spell = 698, reagent = SOUL_SHARD },
	},
}
-- Forever's are Classic Era's: the same ranks, items, rune and shard in its
-- own tables (1.60.1.70790).
SETS.camelot = SETS.vanilla
SETS.tbc = {
	MAGE = {
		water = { rows = Over({
			{ spell = 27090, level = 65, items = { 22018 } },
			{ spell = 37420, level = 60, items = { 30703 } },
		}, VANILLA_WATER) },
		food = { rows = Over({ { spell = 33717, level = 65, items = { 22019 } } }, VANILLA_FOOD) },
		portal = { spells = { 10059, 11416, 11419, 32266, 33691, 49360, 11417, 11418, 11420, 32267, 35717, 49361 },
			reagent = RUNE_OF_PORTALS },
	},
	WARLOCK = {
		healthstone = { rows = Over({ { spell = 27230, level = 60, items = { 22103, 22104, 22105 } } },
			VANILLA_STONES), reagent = SOUL_SHARD },
		summon = { spell = 698, reagent = SOUL_SHARD },
	},
}
SETS.mists = {
	MAGE = {
		water = { rows = MISTS_REFRESHMENT },
		food = { rows = MISTS_REFRESHMENT },
		portal = { spells = { 10059, 11416, 11419, 32266, 33691, 49360, 11417, 11418, 11420, 32267, 35717, 49361,
			53142, 88345, 88346, 132620, 132626 } },
	},
	WARLOCK = {
		-- Create Healthstone makes the warlock's own; the group's come from
		-- the Soulwell.
		healthstone = { cast = 29893 },
		summon = { spell = 698 },
	},
}
SETS.mainline = {
	MAGE = {
		water = { rows = RETAIL_REFRESHMENT },
		food = { rows = RETAIL_REFRESHMENT },
		-- Midnight's Silvermoon City ahead of the Burning Crusade's, the
		-- Broken Isles' Dalaran after Northrend's: a request naming a city
		-- with two portals is answered with the first of them learned.
		portal = { spells = { 10059, 11416, 11419, 32266, 49360, 11417, 11418, 11420, 1259194, 32267, 49361,
			33691, 35717, 53142, 224871, 88345, 88346, 132620, 132626, 176246, 176244, 281400, 281402,
			344597, 395289, 446534 } },
	},
	WARLOCK = {
		healthstone = { cast = 29893 },
		summon = { spell = 698 },
	},
}

-- This client's set for this class, or nil: an unrecognised client gets its
-- family's, as Buffs.lua's sets do.
local function ClientSet()
	local flavour = ns.Flavour and ns.Flavour.flavour
	local set = SETS[flavour]
	if not set then
		set = (ns.Flavour and ns.Flavour.family) == "classic" and SETS.vanilla or SETS.mainline
	end
	return set
end

local function MySet()
	return ClientSet()[ns.PlayerClass() or ""]
end

-- The mage's water rows on this client, best first, whatever the player's class:
-- what the drink button for the moment picks conjured water from
-- (Prompt/MomentsSense.lua). Read when asked, so load order does not matter.
function Courtesy.WaterRows()
	local mage = ClientSet().MAGE
	return mage and mage.water and mage.water.rows or {}
end

---------------------------------------------------------------------------
-- the names people ask by
--
-- Lower case, apostrophes dropped, as Requests.lua's Words leaves a message.
-- A name of one word is a nickname ("water", "hs"): beside it every other
-- word has to be a small one. English, and the words of the languages the
-- reader already knows a please in; the spell's own name on this client is
-- added to each (Aliases).
---------------------------------------------------------------------------

-- Not "drink": "need to drink" is somebody sitting down with their own.
local NAMES = {
	water = { "water", "waters", "mage water", "wasser", "eau", "agua", "acqua",
		"água", "вода", "воды", "водички", "물", "求水", "要水", "来点水", "來點水", "给点水", "給點水" },
	food = { "food", "foods", "mage food", "bread", "essen", "brot", "nourriture", "bouffe", "comida",
		"pan", "cibo", "еда", "хлеб", "음식", "빵", "求面包", "求麵包", "求吃的", "来点面包", "來點麵包" },
	healthstone = { "hs", "healthstone", "healthstones", "health stone", "cookie", "cookies",
		"gesundheitsstein", "pierre de soins", "piedra de salud", "pietra della salute", "pedra de vida", "pedra da vida",
		"камень здоровья", "생명석", "생석", "糖", "求糖", "来个糖", "來個糖", "治疗石", "治療石" },
	summon = { "summon", "summons", "summ", "sum", "beschwörung", "beschwören", "invocation", "invoc",
		"invocación", "invocar", "evocazione", "evocação", "призыв", "призови", "소환", "求拉", "拉我", "拉一下" },
}

-- What stands for "portal" beside a city's name, in any order: "port to org",
-- "org portal pls".
local PORTAL_WORDS = { "port", "portal", "ports", "portals", "portail", "portale", "портал", "порт",
	"포탈", "차원문" }
-- In Chinese the word sits inside the sentence, with the city's own name.
local PORTAL_INSIDE = { "门", "門", "传送", "傳送" }

-- The short names of the cities, by the portal's spell; the city's own name
-- on this client comes off the spell's ("Portal: Orgrimmar"), which covers
-- every language. Not "if": a word of every other sentence.
local CITIES = {
	[10059] = { "sw", "stormwind", "storm" },
	[11416] = { "ironforge", "forge" },
	[11419] = { "darn", "darna", "darnassus" },
	[11417] = { "org", "orgri", "orgrimmar", "og" },
	[11418] = { "uc", "undercity" },
	[11420] = { "tb", "thunder bluff", "thunderbluff" },
	[32266] = { "exo", "exodar" },
	[32267] = { "smc", "silvermoon", "silvermoon city" },
	[1259194] = { "smc", "silvermoon", "silvermoon city" },
	[33691] = { "shatt", "shat", "shattrath" },
	[35717] = { "shatt", "shat", "shattrath" },
	[49360] = { "theramore", "thera" },
	[49361] = { "stonard" },
	[53142] = { "dal", "dala", "dalaran", "northrend" },
	[224871] = { "dal", "dala", "dalaran", "legion", "broken isles" },
	[88345] = { "tol barad", "tolbarad" },
	[88346] = { "tol barad", "tolbarad" },
	[132620] = { "vale", "shrine", "pandaria" },
	[132626] = { "vale", "shrine", "pandaria" },
	[176246] = { "stormshield", "ashran" },
	[176244] = { "warspear", "ashran" },
	[281400] = { "boralus" },
	[281402] = { "dazaralor", "dazar", "zuldazar" },
	[344597] = { "oribos" },
	[395289] = { "valdrakken", "vald" },
	[446534] = { "dornogal", "dorn" },
}

-- What joins two things asked for at once ("water and food pls"): covered
-- beside a courtesy, so the pair still reads as nothing but names.
local JOINERS = { "and", "und", "et", "y", "e", "и", "&" }

---------------------------------------------------------------------------
-- what this character can give, now
---------------------------------------------------------------------------

-- Whether a spell is learned, kept a few seconds: asked on a chat line and on
-- a scan with a request standing, never otherwise.
local known = { at = nil }
local function Known(spell)
	local now = GetTime()
	if not known.at or now - known.at > 5 or now < known.at then
		for id in pairs(known) do known[id] = nil end
		known.at = now
	end
	local answer = known[spell]
	if answer == nil then
		answer = ns.SpellKnown ~= nil and ns.SpellKnown(spell) == true
		known[spell] = answer
	end
	return answer
end

-- For a trainer's visit and the tests: what is learned is asked again.
function Courtesy.Forget()
	known.at = nil
	Courtesy.asks = nil
end

-- Whether this kind can be given at all: a rank of it learned.
local function KindKnown(kind)
	if kind.rows then
		for _, row in ipairs(kind.rows) do
			if Known(row.spell) then return true end
		end
		return false
	end
	if kind.spells then
		for _, spell in ipairs(kind.spells) do
			if Known(spell) then return true end
		end
		return false
	end
	return Known(kind.cast or kind.spell)
end

-- Whether this class has a courtesy behind this switch on this client, for
-- the options page: learned or not, the class has it.
function Courtesy.Has(setting)
	local set = MySet()
	if not set then return false end
	for name, wanted in pairs(SETTING) do
		if wanted == setting and set[name] then return true end
	end
	return false
end

-- A healthstone made at a Soulwell rather than traded (Mists, retail), for
-- the option's words.
function Courtesy.FromSoulwell()
	local set = MySet()
	return set ~= nil and set.healthstone ~= nil and set.healthstone.cast ~= nil
end

local function Switched(name)
	local db = addon.db and addon.db.profile
	return db ~= nil and db.sources.asked == true and db.sources[SETTING[name]] == true
end

-- The city a portal goes to, as this client names it: what follows the colon
-- of the spell's name, else the whole name.
local function City(spell)
	local name = ns.SpellNameFor(spell)
	if type(name) ~= "string" then return nil end
	local city = name:match("：%s*(.+)$") or name:match(":%s*(.+)$")
	if not city or city == "" then return name end
	return city
end

-- What is asked for by a key, in words, for the reason line and the check-up.
local function Noun(key)
	if key == "courtesy:water" then return L["water"] end
	if key == "courtesy:food" then return L["food"] end
	if key == "courtesy:healthstone" then return L["a healthstone"] end
	if key == "courtesy:summon" then return L["a summon"] end
	local spell = tonumber(key:match("^courtesy:portal:(%d+)$") or "")
	if spell then return L["a portal to %s"]:format(City(spell) or "?") end
	return key
end

-- The courtesy keys a request holds, in the order they are answered: by kind,
-- and a portal by its place in the client's list.
local function KeysOf(request)
	local keys = request and request.keys
	if type(keys) ~= "table" then return nil end
	local found
	for key in pairs(keys) do
		if type(key) == "string" and key:sub(1, 9) == "courtesy:" then
			found = found or {}
			found[#found + 1] = key
		end
	end
	if not found then return nil end
	if #found > 1 then
		local place = {}
		for i, name in ipairs(ORDER) do place[name] = i end
		-- A portal by where its spell stands in this client's list, not by
		-- its id: Midnight's Silvermoon City is the newest id and the first
		-- of the two in the list.
		local set = MySet()
		local spot = {}
		for i, spell in ipairs(set and set.portal and set.portal.spells or {}) do spot[spell] = i end
		local function rank(key)
			local name, id = key:match("^courtesy:(%a+):?(%d*)$")
			return (place[name] or 99) * 1e8 + (spot[tonumber(id) or 0] or 0)
		end
		table.sort(found, function(a, b) return rank(a) < rank(b) end)
	end
	return found
end

-- For Requests.lua's check-up lines: what a request's courtesy keys ask for,
-- added to the buffs it names.
function Courtesy.Describe(keys, what)
	for _, key in ipairs(KeysOf({ keys = keys }) or {}) do
		what[#what + 1] = Noun(key)
	end
end

---------------------------------------------------------------------------
-- the reader's half (Requests.lua, Asks)
---------------------------------------------------------------------------

-- Everything that can be asked of this character now, with its names split
-- into words by the reader's own Words: { key, names } for a kind,
-- { key, cities, inside } for a portal. Built again when what is switched on
-- or learned may have changed (a few seconds, as Known).
local function Shares(a, b)
	for _, one in ipairs(a or {}) do
		for _, other in ipairs(b or {}) do
			if one == other then return true end
		end
	end
	return false
end

local function Asks(Words)
	local set = MySet()
	if not set then return nil end
	local now = GetTime()
	local db = addon.db and addon.db.profile
	local sign = table.concat({ tostring(db and db.sources.courtesyRefresh), tostring(db and db.sources.courtesyPortals),
		tostring(db and db.sources.courtesyHealthstones), tostring(db and db.sources.courtesySummons),
		tostring(ns.PlayerClass()) }, ",")
	local asks = Courtesy.asks
	if asks and asks.sign == sign and now - asks.at <= 5 and now >= asks.at then return asks end
	asks = { sign = sign, at = now, portalWords = {} }
	for _, word in ipairs(PORTAL_WORDS) do asks.portalWords[#asks.portalWords + 1] = (Words(word)) end
	asks.joiners = {}
	for _, word in ipairs(JOINERS) do asks.joiners[word] = true end

	local function split(list, name)
		if type(name) ~= "string" or name == "" then return end
		local words = Words(name)
		if #words > 0 then list[#list + 1] = words end
	end
	for _, name in ipairs(ORDER) do
		local kind = set[name]
		if kind and Switched(name) and KindKnown(kind) then
			if kind.spells then
				for _, spell in ipairs(kind.spells) do
					if Known(spell) then
						local ask = { key = "courtesy:portal:" .. spell, spell = spell, cities = {} }
						-- A city with two portals, both learned (Dalaran, Silvermoon
						-- City): the one ahead of this in the client's list, which
						-- one request for the city is answered with.
						for _, earlier in ipairs(asks) do
							if earlier.spell and Shares(CITIES[earlier.spell], CITIES[spell]) then
								ask.twin = earlier.key
								break
							end
						end
						for _, city in ipairs(CITIES[spell] or {}) do split(ask.cities, city) end
						local city = City(spell)
						split(ask.cities, city)
						-- A Chinese name is found inside the sentence, which
						-- has no spaces: two ideographs at least.
						if type(city) == "string" and city:find("[\228-\233]") and #city >= 6 then
							ask.inside = city:gsub("[A-Z]", string.lower)
						end
						asks[#asks + 1] = ask
					end
				end
			else
				local ask = { key = "courtesy:" .. name, names = {} }
				for _, entry in ipairs(NAMES[name]) do split(ask.names, entry) end
				-- The spell's own name on this client, every rank's.
				local seen = {}
				for _, row in ipairs(kind.rows or { { spell = kind.cast or kind.spell } }) do
					local own = ns.SpellNameFor(row.spell)
					if type(own) == "string" and not seen[own] then
						seen[own] = true
						split(ask.names, own)
					end
				end
				asks[#asks + 1] = ask
			end
		end
	end
	Courtesy.asks = asks
	return asks
end

-- Called by Requests.lua's Asks with the message as its words, beside the
-- buffs it has just looked for: every courtesy the message names goes into
-- `found` under its key, "short" for a nickname and "strict" for a name of
-- more than one word or a portal with its city, and the places they stand in
-- into `covered` (and `strict`), so the reader's own rules then judge the
-- message exactly as they judge one about a buff. `Mark` and `Words` are the
-- reader's.
function Courtesy.Named(words, lowered, found, covered, strict, Mark, Words)
	local asks = Asks(Words)
	if not asks or #asks == 0 then return end
	local any = false
	-- Where a word for "portal" stands, looked for once.
	local portalAt
	-- How many words of the message named each portal's city.
	local cityWords
	for _, ask in ipairs(asks) do
		if ask.names then
			local strength
			for _, name in ipairs(ask.names) do
				if Mark(words, name, covered) then
					if #name > 1 then
						Mark(words, name, strict)
						strength = "strict"
					else
						strength = strength or "short"
					end
				end
			end
			if strength then found[ask.key], any = strength, true end
		else
			if portalAt == nil then
				portalAt = {}
				local some = false
				for _, word in ipairs(asks.portalWords) do
					if Mark(words, word, portalAt) then some = true end
				end
				if not some then portalAt = false end
			end
			-- The city, marked apart first: named without a word for "portal"
			-- it is no request, and must not read as covered either.
			local cityAt, named = {}, false
			for _, city in ipairs(ask.cities) do
				if Mark(words, city, cityAt) then named = true end
			end
			local inside = false
			if ask.inside and lowered:find(ask.inside, 1, true) then
				for _, part in ipairs(PORTAL_INSIDE) do
					if lowered:find(part, 1, true) then inside = true break end
				end
			end
			if (named and portalAt) or inside then
				for i in pairs(cityAt) do covered[i], strict[i] = true, true end
				for i in pairs(portalAt or {}) do covered[i], strict[i] = true, true end
				if inside then
					-- The one long "word" the sentence is.
					for i, word in ipairs(words) do
						if word:find(ask.inside, 1, true) then covered[i], strict[i] = true, true end
					end
				end
				-- One portal for one city: of two that go there the first in
				-- the client's list, unless more of the message names the
				-- other ("dalaran broken isles").
				local count = 0
				for _ in pairs(cityAt) do count = count + 1 end
				cityWords = cityWords or {}
				cityWords[ask.key] = count
				local twin = ask.twin
				if not (twin and found[twin] and count <= (cityWords[twin] or 0)) then
					if twin then found[twin] = nil end
					found[ask.key], any = "strict", true
				end
			end
		end
	end
	if any then
		for i, word in ipairs(words) do
			if asks.joiners[word] then covered[i] = true end
		end
	end
end

---------------------------------------------------------------------------
-- the queue's half (Queue.lua, BuildQueue)
---------------------------------------------------------------------------

-- What Manners knows about each standing request it is answering, by the
-- request itself: the key in hand, the token that named them at the last
-- scan, why nothing was offered (`verdict`), and whether a press has conjured
-- for it. Weak: a request Requests.lua lets go takes its state with it.
local state = setmetatable({}, { __mode = "k" })
local function State(request)
	local st = state[request]
	if not st then
		st = {}
		state[request] = st
	end
	return st
end

-- The pseudo-buffs the entries carry, one table a key kept from scan to scan:
-- `courtesy` is what ns.BuffInfo answers from (its `info`), and `alone` says
-- the cast lands on nobody else (Buffs.lua).
local buffs = {}
local function BuffFor(key, spell)
	local buff = buffs[key]
	if not buff then
		buff = { key = key, courtesy = true, alone = true, info = { key = key, known = true } }
		buff.info.buff = buff
		buffs[key] = buff
	end
	local info = buff.info
	info.name = ns.SpellNameFor(spell) or "?"
	info.icon = safecall(C_Spell and C_Spell.GetSpellTexture, spell)
	info.topRank = spell
	return buff
end

-- Whether water and food are one thing on this client: the one spell of
-- Mists and retail, whose items are both.
local function Both(set)
	return set ~= nil and set.water ~= nil and set.food ~= nil and set.water.rows == set.food.rows
end

-- Your target, offered water and food unasked (sources.courtesyTarget).
-- `rest` is who was traded with or skipped lately (their GUID, else their full
-- name) and until when; `aimed` is the synthetic request and the answer of the
-- scan it was worked out in, which Standing and Queue both ask for.
local TARGET_REST = 600
local rest = {}
local aimed = { request = nil, at = nil, answer = nil }

local function Rest(who, now)
	if who == nil then return end
	for each, until_ in pairs(rest) do
		if until_ <= now then rest[each] = nil end
	end
	rest[who] = now + TARGET_REST
	aimed.at = nil
end

local function Aimed(now)
	local db = addon.db and addon.db.profile
	if not (db and db.sources.courtesyTarget == true) then return nil end
	if aimed.at == now then return aimed.answer end
	aimed.at, aimed.answer = now, nil
	if InCombatLockdown() or (ns.Prompt and ns.Prompt.armedForFight == true) then return nil end
	local set = MySet()
	if not (set and set.water and set.food and (KindKnown(set.water) or KindKnown(set.food))) then return nil end
	if plain(UnitExists("target")) ~= true or plain(UnitIsPlayer("target")) ~= true
		or plain(UnitCanAssist("player", "target")) ~= true then
		return nil
	end
	if plain(UnitIsDeadOrGhost("target")) == true or plain(UnitIsConnected("target")) == false then return nil end
	local full = ns.UnitFullName("target")
	if not full or ns.IsPlayerName(full) then return nil end
	-- Another mage conjures their own.
	if plain(select(2, UnitClass("target"))) == "MAGE" then return nil end
	local guid = plain(UnitGUID("target"))
	if type(guid) ~= "string" then guid = nil end
	local who = guid or full
	local until_ = rest[who]
	if until_ and until_ > now then return nil end
	if ns.Ignored("target", guid) then return nil end
	local request = aimed.request
	if not (request and request.who == who) then
		request = { name = full, short = ShortName(full), guid = guid, who = who, targeted = true }
	end
	-- Water where they have mana (or it cannot be told, with food only: food
	-- helps everybody, water is offered where it is known to be wanted).
	local mana = ns.UnitHasMana("target")
	local keys = {}
	if Both(set) then
		keys[mana == true and "courtesy:water" or "courtesy:food"] = true
	else
		keys["courtesy:food"] = true
		if mana == true then keys["courtesy:water"] = true end
	end
	request.keys = keys
	request.expires = now + 30
	if next(keys) == nil then return nil end
	aimed.request, aimed.answer = request, request
	return request
end

-- A right-click on somebody's offer (Prompt/Press.lua): your target they were
-- is left alone for a while.
-- Whether the trade for this key is filled (water and food, Fill the trade
-- window) rather than one stack; a healthstone is always one item.
local function Filling(key)
	local db = addon.db and addon.db.profile
	return (key == "courtesy:water" or key == "courtesy:food") and db ~= nil
		and db.sources.courtesyAmount ~= "one"
end

function Courtesy.Skipped(name)
	local request = aimed.request
	if request and SameName(request.name, name) then
		Rest(request.who, GetTime())
		aimed.request = nil
	end
end

local function Standing(now)
	if Aimed(now) ~= nil then return true end
	local list = ns.standingRequests
	if not list or #list == 0 then return false end
	for _, request in ipairs(list) do
		if (request.fight or request.expires > now) and KeysOf(request) then return true end
	end
	return false
end
-- Whether any courtesy is still asked for, for the queue to know there is
-- something to add before it pays for the call.
Courtesy.Standing = Standing

-- Whether a request was made by the person behind this token: the GUID where
-- both sides have one, else the name or its first word, as Requests.lua's own
-- Made has it.
local function Matches(request, unit)
	local guid = plain(UnitGUID(unit))
	if request.guid and type(guid) == "string" then return request.guid == guid end
	local full = ns.UnitFullName(unit)
	if not full then return false end
	local first = FirstName(full)
	return SameName(request.short, ShortName(full)) or (first ~= nil and SameName(request.short, first))
end

-- How many of a row's items the bags hold, and the first of them held. With
-- `level`, only the items somebody of that level can use, where the row says
-- what each asks (`needs`).
local function Held(row, level)
	local total, first = 0, nil
	local needs = level and row.needs
	for _, item in ipairs(row.items) do
		local count = ns.ReagentCount(item)
		if needs and (needs[item] or 0) > level then count = 0 end
		if type(count) == "number" and count > 0 then
			total = total + count
			first = first or item
		end
	end
	return total, first
end

-- Whether a reagent is missing: none in the bags, on the client's own count.
-- Not on Forever when the client calls the spell usable all the same (the
-- Reagent Economy perk, GroupBuffs.lua), and not where the client will not
-- count.
local function Lacks(reagent, spell)
	if not reagent then return false end
	local have = ns.ReagentCount(reagent)
	if have ~= 0 then return false end
	if (ns.Flavour and ns.Flavour.flavour) == "camelot" then
		local check = C_Spell and C_Spell.IsSpellUsable
		if type(check) ~= "function" then check = _G.IsUsableSpell end
		if safecall(check, spell) == true then return false end
	end
	return true
end

-- Whether a spell is on a cooldown of its own, longer than the global one:
-- a ritual, a Soulwell or a portal cast a moment ago for somebody else. A
-- /cast of it now reaches the server and is refused there.
local function Cooling(spell)
	local info = safecall(C_Spell and C_Spell.GetSpellCooldown, spell)
	if type(info) ~= "table" then return false end
	local start, duration = plain(info.startTime), plain(info.duration)
	return type(start) == "number" and type(duration) == "number" and duration > 3
		and start + duration > GetTime()
end

-- What the /cast line names for a rank: the spell's name, with its rank
-- where a higher one of the same name is learned ("Conjure Water(Rank 3)":
-- the game casts the best rank of a bare name), and "()" after a name that
-- ends in a bracket of its own, which the macro would read as a rank
-- ("Create Healthstone (Minor)()").
local function CastText(spell, rows)
	local name = ns.SpellNameFor(spell)
	if type(name) ~= "string" then return nil end
	if name:sub(-1) == ")" then return name .. "()" end
	for _, row in ipairs(rows or {}) do
		if row.spell == spell then break end
		if Known(row.spell) and ns.SpellNameFor(row.spell) == name then
			local get = _G.C_Spell and _G.C_Spell.GetSpellSubtext or _G.GetSpellSubtext
			local rank = type(get) == "function" and plain(get(spell)) or nil
			if type(rank) == "string" and rank ~= "" then return name .. "(" .. rank .. ")" end
			break
		end
	end
	return name
end

-- What a press would do for this key at this person, or nil and why not.
-- { stage, spell, text, item }: "conjure" (cast, nobody targeted), "trade"
-- (target and /trade), "cast" (a portal or a Soulwell, nobody targeted),
-- "summon" (target and cast, left targeted).
local function Plan(key, set, unit, inGroup, st)
	local name, id = key:match("^courtesy:(%a+):?(%d*)$")
	local kind = name and set[name]
	local db = addon.db and addon.db.profile
	if not kind or not ((st.targeted and (name == "water" or name == "food") and db ~= nil
		and db.sources.courtesyTarget == true) or Switched(name)) then
		return nil, "off"
	end
	local sighted = plain(UnitIsVisible and UnitIsVisible(unit)) ~= false

	if kind.spells or kind.cast then
		local spell = kind.cast or tonumber(id)
		if not spell or not Known(spell) then return nil, "off" end
		if not inGroup then return nil, "group" end
		if not sighted then return nil, "sight" end
		if Lacks(kind.reagent, spell) then return nil, "reagent", kind.reagent end
		if Cooling(spell) then return nil, "cooldown" end
		return { stage = "cast", spell = spell, text = CastText(spell) }
	end

	if kind.spell then
		if not Known(kind.spell) then return nil, "off" end
		if not inGroup then return nil, "group" end
		if Lacks(kind.reagent, kind.spell) then return nil, "reagent", kind.reagent end
		if Cooling(kind.spell) then return nil, "cooldown" end
		return { stage = "summon", spell = kind.spell, text = CastText(kind.spell) }
	end

	if not sighted then return nil, "sight" end
	-- Their level, where a rank's item asks one: somebody of level 20 cannot
	-- drink what a level 60 mage conjures by default.
	local level = plain(UnitLevel(unit))
	if type(level) ~= "number" or level < 1 then level = nil end
	-- Never offered to somebody who has not asked, what they might not be able
	-- to use: with their level withheld, only where no item asks one (retail).
	if st.targeted and level == nil then
		for _, row in ipairs(kind.rows) do
			if row.level or row.needs then return nil, "nolevel" end
		end
	end
	local function suits(row) return not (level and row.level) or row.level <= level end
	for _, row in ipairs(kind.rows) do
		if suits(row) then
			local count, item = Held(row, level)
			if count > 0 then return { stage = "trade", spell = row.spell, item = item, level = level } end
		end
	end
	-- One spell that makes what suits your own level (Mists): with nothing in
	-- the bags they can use, and a conjure that would make only what they
	-- cannot, there is nothing to hand them.
	for _, row in ipairs(kind.rows) do
		local needs = level and row.needs
		if needs then
			local mine = plain(UnitLevel("player"))
			for _, item in ipairs(type(mine) == "number" and row.items or {}) do
				if (needs[item] or 0) <= mine then
					if (needs[item] or 0) > level then return nil, "level" end
					break
				end
			end
		end
	end
	-- Conjured for them already and still nothing that suits them: what the
	-- bags hold is what there is, rather than a conjure asked for again.
	if st.conjured then
		for _, row in ipairs(kind.rows) do
			local count, item = Held(row, st.targeted and level or nil)
			if count > 0 then return { stage = "trade", spell = row.spell, item = item, level = level } end
		end
	end
	local conjure, lowest
	for _, row in ipairs(kind.rows) do
		if Known(row.spell) then
			lowest = row
			if not conjure and suits(row) then conjure = row end
		end
	end
	-- A target below every rank learned gets none, rather than the lowest.
	if st.targeted and not conjure and lowest then return nil, "level" end
	conjure = conjure or lowest
	if not conjure then return nil, "off" end
	if Lacks(kind.reagent, conjure.spell) then return nil, "reagent", kind.reagent end
	if Cooling(conjure.spell) then return nil, "cooldown" end
	return { stage = "conjure", spell = conjure.spell, text = CastText(conjure.spell, kind.rows), level = level }
end

-- The queue's hook: one entry for each person with a courtesy standing whom a
-- token names now, in place of an offer nobody asked for (a group member's or
-- a passer-by's buff, which comes back once this is answered) and behind one
-- that outranks it (a favour, a buff they asked for, your target). `inTown`
-- and `manaHeld` are the scan's own: "Offer nothing in cities and inns" and the mana
-- floor hold a courtesy as they hold a request for a buff.
function Courtesy.Queue(queue, rejected, now, inTown, manaHeld)
	local list = ns.standingRequests
	local db = addon.db and addon.db.profile
	local set = MySet()
	if not (db and set) then return end
	local wanted
	if list and db.sources.asked then
		for _, request in ipairs(list) do
			if request.fight or request.expires > now then
				local keys = KeysOf(request)
				if keys then
					local st = State(request)
					st.keys, st.unit, st.pointed, st.verdict, st.detail = keys, nil, nil, nil, nil
					st.targeted = nil
					wanted = wanted or {}
					wanted[#wanted + 1] = request
				end
			end
		end
	end
	-- Your target, after those who asked: theirs wins for the same person.
	local aim = Aimed(now)
	-- Nobody asked for it: held back while you save mana, whatever the floor keeps.
	if aim and ns.SavingMana and ns.SavingMana() ~= nil then
		State(aim).verdict = "mana"
		aim = nil
	end
	if aim then
		local st = State(aim)
		st.keys, st.unit, st.pointed, st.verdict, st.detail = KeysOf(aim), "target", true, nil, nil
		st.targeted = true
		wanted = wanted or {}
		wanted[#wanted + 1] = aim
	end
	if not wanted then return end
	-- Never in a fight, nor from the pull's own repaint, which arms what the
	-- fight then freezes on the button.
	local held = (InCombatLockdown() or (ns.Prompt and ns.Prompt.armedForFight == true)) and "fight"
		or manaHeld and "mana" or nil
	if held then
		for _, request in ipairs(wanted) do State(request).verdict = held end
		return
	end

	-- Your target alone is no walk: its token is known.
	if #wanted > (aim and 1 or 0) then ns.IterateUnits(function(unit, pointed)
		if plain(UnitExists(unit)) ~= true or plain(UnitIsPlayer(unit)) ~= true then return end
		-- Nobody dead, offline or beyond your help, as the walk has it
		-- (IsBuffableUnit): a trade with a corpse fails at every press, and the
		-- walk's verdict on them stays.
		if plain(UnitIsDeadOrGhost(unit)) == true or plain(UnitIsConnected(unit)) == false
			or plain(UnitCanAssist("player", unit)) == false then return end
		for _, request in ipairs(wanted) do
			local st = State(request)
			if not st.unit and Matches(request, unit) then st.unit, st.pointed = unit, pointed == true end
		end
	end) end

	local asked = ns.PRIORITY and ns.PRIORITY.asked or 1.5
	for _, request in ipairs(wanted) do
		local st = State(request)
		local unit = st.unit
		local full = unit and ns.UnitFullName(unit)
		if not full then
			st.verdict = "unseen"
		elseif inTown and not (st.pointed and db.filters.quietTargets ~= true) then
			st.verdict = "town"
		elseif ns.IsBlocked(full, nil, now) then
			st.verdict = "skipped"
		elseif ns.IsNeverOffered(full) then
			st.verdict = "never"
		elseif not st.pointed and ns.MuteListed(full, unit, now) then
			st.verdict = "muted"
		else
			local inGroup = (plain(UnitInParty and UnitInParty(unit)) or plain(UnitInRaid and UnitInRaid(unit)))
				and true or false
			if not inGroup and ns.Ignored(unit) then
				st.verdict = "never"
			else
				-- The first thing they asked for that can be given now.
				local plan, key, why, detail
				local order, tries = st.keys, nil
				if st.targeted then
					-- Water and food are both conjured before a single trade.
					tries = {}
					for _, each in ipairs(order) do
						local made, whyNot, what = Plan(each, set, unit, inGroup, st)
						-- Out of reach, a trade is held: only a definite no counts.
						if made and made.stage == "trade" and not InCombatLockdown()
							and type(_G.CheckInteractDistance) == "function"
							and plain(_G.CheckInteractDistance(unit, 2)) == false then
							made, whyNot = nil, "far"
						end
						tries[each] = { made, whyNot, what }
					end
					order = {}
					for _, stage in ipairs({ "conjure", "trade" }) do
						for _, each in ipairs(st.keys) do
							if tries[each][1] and tries[each][1].stage == stage then order[#order + 1] = each end
						end
					end
					for _, each in ipairs(st.keys) do
						if not tries[each][1] then order[#order + 1] = each end
					end
				end
				for _, each in ipairs(order) do
					local made, whyNot, what
					if tries then
						made, whyNot, what = tries[each][1], tries[each][2], tries[each][3]
					else
						made, whyNot, what = Plan(each, set, unit, inGroup, st)
					end
					if made then
						local buffKey = each .. ":" .. made.stage .. (made.stage == "conjure" and (":" .. made.spell) or "")
						if ns.IsBlocked(full, buffKey, now) then
							-- Pressed a moment ago: what that press began is waited
							-- for, and the next thing they asked for is not offered
							-- over it.
							why = why or "pressed"
							break
						else
							plan, key = made, each
							plan.key, plan.buffKey, plan.request = each, buffKey, request
							if st.targeted then
								request.level = plan.level
								-- What a filled trade will hold, in words.
								local other = each == "courtesy:water" and "courtesy:food" or "courtesy:water"
								if Both(set) then
									plan.noun = L["water and food"]
								elseif plan.stage == "trade" and tries[other]
									and tries[other][1] and tries[other][1].stage == "trade" then
									plan.noun = L["water and food"]
								end
							end
							break
						end
					elseif not why or why == "off" then
						why, detail = whyNot, what
					end
				end
				if not plan then
					st.verdict, st.detail = why or "off", detail
				else
					-- One entry a person: theirs for a buff stays ahead when it
					-- outranks a request, or is a group cast aimed at them.
					local at, waits
					for i, entry in ipairs(queue) do
						if entry.name == full then
							at = i
							waits = entry.groupCast ~= nil or st.targeted == true or (entry.priority or 9) <= asked
							break
						end
					end
					if waits then
						st.verdict = "behind"
					else
						if at then table.remove(queue, at) end
						st.verdict, st.key = "offered", key
						if type(rejected) == "table" then rejected[full] = nil end
						queue[#queue + 1] = {
							name = full,
							short = ShortName(full),
							targetName = ns.TargetName(full),
							unit = unit,
							class = plain(select(2, UnitClass(unit))),
							buff = BuffFor(plan.buffKey, plan.spell),
							reason = st.targeted and "target" or "asked",
							inGroup = inGroup,
							priority = asked,
							known = false,
							checked = true,
							courtesy = plan,
						}
						-- Your target is no buff anybody lacks, as the reason line says.
						if st.targeted then queue[#queue].known = nil end
					end
				end
			end
		end
	end
end

-- BuildQueue's early way out, with no buff to give anybody: your own entry
-- (or none) and whoever asked for a courtesy, in the queue's own shape.
function Courtesy.Alone(own, now, inTown, manaHeld)
	local queue, rejected = {}, {}
	if own then queue[1] = own end
	ns.Guard("courtesies", Courtesy.Queue, queue, rejected, now, inTown, manaHeld)
	if #queue == 0 then return {}, true end
	table.sort(queue, function(a, b) return (a.priority or 9) < (b.priority or 9) end)
	return queue, rejected
end

---------------------------------------------------------------------------
-- the prompt's half
---------------------------------------------------------------------------

-- The macro (Prompt/Macro.lua, STRATEGIES.courtesy): the lines, whether the
-- hand-back follows, and the record of it. `target` is the prompt's own
-- strategy for a cast at somebody, whose targeting line and hand-back rule a
-- trade and a summon take as they are.
function Courtesy.Macro(entry, target)
	local plan = entry.courtesy
	local text = plan.text or ns.EntrySpellName(entry)
	if plan.stage == "trade" then
		local lines, restore, record = target(entry, text)
		lines[2] = "/trade"
		return lines, restore, record
	elseif plan.stage == "summon" then
		-- No hand-back: whoever clicks the portal summons their target.
		local lines, _, record = target(entry, text)
		return lines, false, record
	end
	return { "/cast " .. text }, false, { targeted = false, selfCast = false, onSelf = true, aimedAt = nil }
end

-- The reason line (Prompt/Paint.lua, ReasonText): what they asked for, and
-- that the first press makes it where the bags hold none.
function Courtesy.Reason(entry)
	local plan = entry.courtesy
	local key = plan.key
	if plan.request and plan.request.targeted then
		local noun = plan.noun or Noun(key)
		if plan.stage == "conjure" then
			if type(plan.level) == "number" then
				return L["conjure %s for your target (level %d)"]:format(noun, plan.level)
			end
			return L["conjure %s for your target"]:format(noun)
		end
		return L["trade %s to your target"]:format(noun)
	end
	if plan.stage == "conjure" then
		if key == "courtesy:water" then return L["asked for water -- conjure it first"] end
		if key == "courtesy:food" then return L["asked for food -- conjure it first"] end
		return L["asked for a healthstone -- create it first"]
	end
	if key == "courtesy:water" then return L["asked for water"] end
	if key == "courtesy:food" then return L["asked for food"] end
	if key == "courtesy:healthstone" then return L["asked for a healthstone"] end
	if key == "courtesy:summon" then return L["asked for a summon"] end
	return L["asked for a portal to %s"]:format(City(plan.spell) or "?")
end

-- The tooltip's account of the press (Prompt/Macro.lua, ClickSummary).
function Courtesy.Summary(entry, out)
	local plan = entry.courtesy
	local who = entry.targetName or entry.name or entry.short or "?"
	local spell = ns.EntrySpellName(entry)
	if plan.stage == "trade" then
		out[#out + 1] = L["Targets |cffffffff%s|r and opens a trade."]:format(who)
		if Filling(plan.key) then
			out[#out + 1] = L["Manners fills the trade window with what suits them; accepting the trade is yours."]
		else
			out[#out + 1] = L["Manners puts it in the trade window; accepting the trade is yours."]
		end
	elseif plan.stage == "summon" then
		out[#out + 1] = L["Targets |cffffffff%s|r, casts |cffffffff%s|r, and leaves them targeted for the summoning."]
			:format(who, spell)
	else
		out[#out + 1] = L["Casts |cffffffff%s|r; nobody is targeted."]:format(spell)
	end
	return out
end

-- A press waiting on the game: `trade` for the window to open, `cast` for the
-- spell to go out, `conjure` for the conjure to.
local waiting = {}

-- The courtesy's key comes off the request, which closes once nothing it
-- asked for is left, as a buff landing closes one (Requests.lua).
local function Serve(request, key)
	if type(request) ~= "table" or type(request.keys) ~= "table" then return end
	request.keys[key] = nil
	-- Water and food asked for together where they are one item: both answered.
	local other = key == "courtesy:water" and "courtesy:food" or key == "courtesy:food" and "courtesy:water" or nil
	if other and request.keys[other] and Both(MySet()) then request.keys[other] = nil end
	if next(request.keys) ~= nil then return end
	local list = ns.standingRequests
	for i = #(list or {}), 1, -1 do
		if list[i] == request then table.remove(list, i) end
	end
end

-- A press on a courtesy (Prompt/Press.lua, OnPostClick): nothing is parked
-- for the settle, which judges a buff landing on somebody. The entry leaves
-- the prompt for a moment (the same block a buff's press writes), and what
-- the press began is watched for: the bags filling moves a conjure on to the
-- trade at the next scan, the trade window opening is TradeOpened, the cast
-- going out is CastWentOut.
local Hand, TradingWith
function Courtesy.Pressed(entry, S, now)
	local plan = entry.courtesy
	local request = plan.request
	ns.Trail("press", ("pressed: %s, asked, from %s"):format(tostring(plan.buffKey),
		S.isBar and "the action bar" or (S.isRow and "the list" or "the prompt")), entry.name)
	-- A request is good for a minute from the asking; one being answered is
	-- not let go half way.
	if type(request) == "table" and type(request.expires) == "number" and request.expires < now + 30 then
		request.expires = now + 30
	end
	if plan.stage == "trade" then
		ns.MarkAttempted(entry.name, plan.buffKey, 8)
		if type(request) == "table" and not InCombatLockdown() and TradingWith(request) then
			-- The window is open with them already (they opened it): /trade
			-- opens nothing and no TRADE_SHOW follows, so the item goes in now.
			Hand(request, plan.key, plan.item, entry.name)
		else
			waiting.trade = { request = request, key = plan.key, item = plan.item, at = now, name = entry.name }
		end
	elseif plan.stage == "conjure" then
		ns.MarkAttempted(entry.name, plan.buffKey, 4)
		-- Conjured for them once the cast is seen to go out (CastWentOut), not
		-- at the press: one that failed has made nothing.
		waiting.conjure = { request = request, spell = plan.spell, at = now }
	else
		ns.MarkAttempted(entry.name, plan.buffKey, 12)
		waiting.cast = { request = request, key = plan.key, spell = plan.spell, at = now }
	end
	if not S.isRow and ns.Prompt then ns.Prompt:StopAttention() end
end

-- The first bag slot holding an item, or nil: the backpack and the four bags.
local function SlotOf(item)
	local bags = _G.C_Container
	if type(bags) ~= "table" or type(bags.GetContainerNumSlots) ~= "function"
		or type(bags.GetContainerItemID) ~= "function" then
		return nil
	end
	for bag = 0, 4 do
		local slots = plain(bags.GetContainerNumSlots(bag))
		for slot = 1, type(slots) == "number" and slots or 0 do
			if plain(bags.GetContainerItemID(bag, slot)) == item then
				local info = type(bags.GetContainerItemInfo) == "function" and bags.GetContainerItemInfo(bag, slot)
				if not (type(info) == "table" and plain(info.isLocked) == true) then return bag, slot end
			end
		end
	end
	return nil
end

-- Puts the item into the first free slot of the trade window, as a drag from
-- the bags would: picked up, set down, and the cursor never left holding it.
-- Out of a fight only, and only with the cursor empty. Answers whether it
-- went in.
local function Place(item)
	if InCombatLockdown() or not item then return false end
	local bags = _G.C_Container
	local click, link = _G.ClickTradeButton, _G.GetTradePlayerItemLink
	if type(bags) ~= "table" or type(bags.PickupContainerItem) ~= "function"
		or type(click) ~= "function" or type(link) ~= "function" then
		return false
	end
	if type(_G.GetCursorInfo) == "function" and _G.GetCursorInfo() ~= nil then return false end
	local free
	for i = 1, _G.MAX_TRADABLE_ITEMS or 6 do
		if not link(i) then free = i break end
	end
	local bag, slot = SlotOf(item)
	if not (free and bag) then return false end
	bags.PickupContainerItem(bag, slot)
	local holding = type(_G.CursorHasItem) == "function" and _G.CursorHasItem()
	if not holding then
		if type(_G.ClearCursor) == "function" then _G.ClearCursor() end
		return false
	end
	click(free)
	if _G.CursorHasItem() then
		_G.ClearCursor()
		return false
	end
	return true
end

-- One bag slot onto one trade slot: picked up, set down, the cursor never
-- left holding it. Answers whether it went in.
local function Put(spot, index)
	if type(_G.GetCursorInfo) == "function" and _G.GetCursorInfo() then return false end
	_G.C_Container.PickupContainerItem(spot.bag, spot.slot)
	if not _G.CursorHasItem() then
		if type(_G.ClearCursor) == "function" then _G.ClearCursor() end
		return false
	end
	_G.ClickTradeButton(index)
	if _G.CursorHasItem() then
		_G.ClearCursor()
		return false
	end
	return true
end

-- Fills the open trade with what the bags hold of this request's water and
-- food that somebody of `level` can use: the free slots read once, the bags
-- read once, water and food taking a slot in turn, `perKind` slots to each at
-- most. Only the items the rows list (what a conjure makes) are ever picked
-- up. Answers how many went in, which keys had one, and the first item.
local function Fill(request, level, perKind)
	local served, placed, first = {}, 0, nil
	if InCombatLockdown() or type(request) ~= "table" or type(request.keys) ~= "table" then return 0, served end
	local bags = _G.C_Container
	local click, link = _G.ClickTradeButton, _G.GetTradePlayerItemLink
	if type(bags) ~= "table" or type(bags.PickupContainerItem) ~= "function"
		or type(bags.GetContainerNumSlots) ~= "function" or type(bags.GetContainerItemID) ~= "function"
		or type(click) ~= "function" or type(link) ~= "function" or type(_G.CursorHasItem) ~= "function" then
		return 0, served
	end
	local set = MySet()
	if not set then return 0, served end
	-- Free slots: the ones the player filled are left alone, and so is the
	-- seventh, which holds what is being traded for.
	local free = {}
	for i = 1, _G.MAX_TRADABLE_ITEMS or 6 do
		if not link(i) then free[#free + 1] = i end
	end
	if #free == 0 then return 0, served end
	local held = {}
	for bag = 0, 4 do
		local slots = plain(bags.GetContainerNumSlots(bag))
		for slot = 1, type(slots) == "number" and slots or 0 do
			local item = plain(bags.GetContainerItemID(bag, slot))
			if type(item) == "number" then
				local info = type(bags.GetContainerItemInfo) == "function" and bags.GetContainerItemInfo(bag, slot)
				if not (type(info) == "table" and plain(info.isLocked) == true) then
					held[item] = held[item] or {}
					held[item][#held[item] + 1] = { bag = bag, slot = slot, item = item }
				end
			end
		end
	end
	local lists = {}
	for _, name in ipairs({ "water", "food" }) do
		local key = "courtesy:" .. name
		local kind = set[name]
		if kind and request.keys[key] and not (Both(set) and #lists > 0) then
			local slots = {}
			for _, row in ipairs(kind.rows or {}) do
				if not (level and row.level and row.level > level) then
					for _, item in ipairs(row.items) do
						if not (level and row.needs and (row.needs[item] or 0) > level) then
							for _, spot in ipairs(held[item] or {}) do slots[#slots + 1] = spot end
						end
					end
				end
			end
			lists[#lists + 1] = { key = key, slots = slots, at = 1, put = 0 }
		end
	end
	local nextFree, moved = 1, true
	while moved and nextFree <= #free do
		moved = false
		for _, list in ipairs(lists) do
			local spot = list.slots[list.at]
			if nextFree <= #free and list.put < perKind and spot then
				list.at = list.at + 1
				if not Put(spot, free[nextFree]) then return placed, served, first end
				nextFree, list.put, placed = nextFree + 1, list.put + 1, placed + 1
				served[list.key], first, moved = true, first or spot.item, true
			end
		end
	end
	return placed, served, first
end

-- The request is answered; the item goes into the open trade where it can,
-- and accepting stays the player's. Water and food are filled in (Fill), a
-- healthstone is one item.
function Hand(request, key, item, name)
	local count, first = 0, item
	if key == "courtesy:water" or key == "courtesy:food" then
		local level = plain(UnitLevel("NPC"))
		if type(level) ~= "number" or level < 1 then level = type(request) == "table" and request.level or nil end
		local served, one
		count, served, one = Fill(request, level, Filling(key) and 6 or 1)
		for each in pairs(served) do Serve(request, each) end
		first = one or item
		-- Chat's request is answered as it always was; a target offered
		-- unasked stays on offer after a trade with nothing in it.
		if count == 0 and not (type(request) == "table" and request.targeted) then Serve(request, key) end
	else
		Serve(request, key)
		if Place(item) then count = 1 end
	end
	-- A trade with something in it: they are left alone for a while, a chat
	-- request's person as well.
	local who = type(request) == "table" and (request.who or request.guid) or nil
	if count > 0 then
		Rest(who or plain(UnitGUID("NPC")) or (type(request) == "table" and request.name) or name, GetTime())
	end
	if count > 0 and type(request) == "table" and aimed.request == request then aimed.request = nil end
	-- In the window, which is as far as Manners goes: a milestone's worth
	-- (Milestones.lua). A trade that opened with nothing put in it is none.
	if count > 0 and ns.Milestones then ns.Milestones.Note("courtesy") end
	local db = addon.db and addon.db.profile
	if count > 0 and db and db.verbose then
		if count == 1 then
			addon:Print(L["%s is in the trade with |cffffffff%s|r -- accept it when you are ready."]
				:format(ns.ReagentName(first) or Noun(key), ShortName(name) or name))
		else
			addon:Print(L["%d stacks are in the trade with |cffffffff%s|r -- accept it when you are ready."]
				:format(count, ShortName(name) or name))
		end
	end
end

-- Whether the trade window is open with whoever made this request. The other
-- side of a trade is the client's "NPC" token, as its own trade window names
-- them.
function TradingWith(request)
	local frame = _G.TradeFrame
	if type(frame) ~= "table" or type(frame.IsShown) ~= "function" or not frame:IsShown() then return false end
	return plain(UnitExists("NPC")) == true and Matches(request, "NPC")
end

-- TRADE_SHOW: a trade is open. With whoever a trade press was for, that
-- press's item goes in. With somebody who asked and opened the trade
-- themselves, which is what people asking a mage for water mostly do, what
-- the prompt was offering them goes in where the bags hold it.
function Courtesy.TradeOpened()
	local press = waiting.trade
	waiting.trade = nil
	if InCombatLockdown() or plain(UnitExists("NPC")) ~= true then return end
	if press and GetTime() - press.at <= 20 and Matches(press.request, "NPC") then
		Hand(press.request, press.key, press.item, press.name)
		return
	end
	local set = MySet()
	local list = ns.standingRequests
	if not set then return end
	local now = GetTime()
	-- No press came first, so this rests on the last scan's offer, and with
	-- Manners switched off, snoozed or its prompt unlocked no scan offers
	-- anything: what an earlier one left standing is not gone by.
	local db = addon.db and addon.db.profile
	if not (db and db.enabled) or ns.SnoozeLeft(now) or (db.prompt and db.prompt.locked == false) then return end
	-- Those who asked. Your target who opens a trade unasked gets nothing put in:
	-- only a press of the prompt (above) fills for them.
	local requests = {}
	for i = #(list or {}), 1, -1 do requests[#requests + 1] = list[i] end
	for _, request in ipairs(requests) do
		local st = state[request]
		-- Only what the last scan had on the prompt for them, or would have
		-- but for a press a moment ago: a city's quiet, a skip and the
		-- never-offer list hold this as they hold the offer.
		if st and st.keys and (st.verdict == "offered" or st.verdict == "pressed")
			and (request.fight or request.expires > now) and Matches(request, "NPC") then
			for _, key in ipairs(st.keys) do
				local plan = request.keys[key] and Plan(key, set, "NPC", false, st)
				if plan and plan.stage == "trade" then Hand(request, key, plan.item, request.name) end
			end
		end
	end
end

-- UNIT_SPELLCAST_SUCCEEDED of your own: the portal, the Soulwell or the
-- ritual a press began has gone out.
function Courtesy.CastWentOut(spellId)
	-- A conjure: made for them, so that what the bags then hold is what there
	-- is to give (Plan).
	local made = waiting.conjure
	if made then
		if GetTime() - made.at > 20 then
			waiting.conjure = nil
		elseif plain(spellId) == made.spell then
			waiting.conjure = nil
			if type(made.request) == "table" then State(made.request).conjured = true end
		end
	end
	local press = waiting.cast
	if not press then return end
	if GetTime() - press.at > 20 then
		waiting.cast = nil
		return
	end
	if plain(spellId) ~= press.spell then return end
	waiting.cast = nil
	Serve(press.request, press.key)
	-- The portal, the Soulwell or the summon went out (Milestones.lua).
	if ns.Milestones then ns.Milestones.Note("courtesy") end
end

-- The two events, on a frame of its own: both are asked of the client by
-- addons known to work on each of the five, and neither is an event of
-- Manners' own lifecycle.
do
	local function OnEvent(_, event, unit, _, spellId)
		if event == "TRADE_SHOW" then
			ns.Guard("courtesy trade", Courtesy.TradeOpened)
		elseif (waiting.cast or waiting.conjure) and unit == "player" then
			ns.Guard("courtesy cast", Courtesy.CastWentOut, spellId)
		end
	end
	Courtesy.OnEvent = OnEvent
	local frame = type(_G.CreateFrame) == "function" and _G.CreateFrame("Frame") or nil
	if type(frame) == "table" and type(frame.RegisterEvent) == "function" then
		frame:SetScript("OnEvent", OnEvent)
		ns.Guard("RegisterEvent TRADE_SHOW", frame.RegisterEvent, frame, "TRADE_SHOW")
		if type(frame.RegisterUnitEvent) == "function" then
			ns.Guard("RegisterEvent UNIT_SPELLCAST_SUCCEEDED", frame.RegisterUnitEvent, frame,
				"UNIT_SPELLCAST_SUCCEEDED", "player")
		else
			ns.Guard("RegisterEvent UNIT_SPELLCAST_SUCCEEDED", frame.RegisterEvent, frame, "UNIT_SPELLCAST_SUCCEEDED")
		end
		Courtesy.frame = frame
	end
end

---------------------------------------------------------------------------
-- the check-up (Requests.lua, RequestLines, for /manners debug)
---------------------------------------------------------------------------

-- One line for the switches, and one for each courtesy asked for saying
-- whether it is on the prompt or what holds it back.
function Courtesy.Lines(lines)
	local set = MySet()
	if not set then return end
	local on = {}
	for _, name in ipairs(ORDER) do
		if set[name] and Switched(name) and KindKnown(set[name]) then
			on[#on + 1] = name == "portal" and L["portals"] or Noun("courtesy:" .. name)
		end
	end
	local db = addon.db and addon.db.profile
	if db and db.sources.courtesyTarget == true and set.water and KindKnown(set.water) then
		on[#on + 1] = L["water and food for your target"]
	end
	lines[#lines + 1] = #on > 0 and L["courtesies answered: %s"]:format(table.concat(on, ", "))
		or L["courtesies answered: none (each has a switch under %s)."]:format("|cffffd100" .. L["People who ask me in chat"] .. "|r")
	local now = GetTime()
	for _, request in ipairs(ns.standingRequests or {}) do
		local keys = (request.fight or request.expires > now) and KeysOf(request)
		if keys then
			local st = State(request)
			local verdict = st.verdict
			local why
			if verdict == "offered" then
				why = L["on the prompt"]
			elseif verdict == "fight" then
				why = L["never in a fight"]
			elseif verdict == "mana" then
				why = L["held back while you save mana"]
			elseif verdict == "town" then
				why = L["held back in a city or an inn"]
			elseif verdict == "unseen" then
				why = L["nobody by that name is in sight"]
			elseif verdict == "sight" then
				why = L["they are out of sight"]
			elseif verdict == "group" then
				why = L["they are not in your party or raid"]
			elseif verdict == "reagent" then
				why = L["no %s in your bags"]:format(ns.ReagentName(st.detail) or tostring(st.detail))
			elseif verdict == "cooldown" then
				why = L["the spell is cooling down"]
			elseif verdict == "nolevel" then
				why = L["their level cannot be read"]
			elseif verdict == "far" then
				why = L["they are too far away to trade"]
			elseif verdict == "level" then
				why = L["they are too low in level for what you can conjure"]
			elseif verdict == "behind" then
				why = L["after the buff you have for them"]
			elseif verdict == "skipped" or verdict == "pressed" then
				why = L["pressed or skipped a moment ago"]
			elseif verdict == "never" then
				why = L["they are on your never-offer or ignore list"]
			elseif verdict == "muted" then
				why = L["they are muted, and Who to skip leaves them out"]
			else
				why = L["not looked at yet"]
			end
			-- What was last offered of it, while that is still asked for.
			local key = st.key
			if not (key and request.keys[key]) then key = keys[1] end
			lines[#lines + 1] = L["courtesy: |cffffffff%s|r asked for %s -- %s"]:format(request.name, Noun(key), why)
		end
	end
	local aim = aimed.answer
	if aim and aim.keys then
		local st = State(aim)
		local why = st.verdict == "offered" and L["on the prompt"] or nil
		local verdict = st.verdict
		if not why then
			if verdict == "town" then why = L["held back in a city or an inn"]
			elseif verdict == "mana" then why = L["held back while you save mana"]
			elseif verdict == "nolevel" then why = L["their level cannot be read"]
			elseif verdict == "far" then why = L["they are too far away to trade"]
			elseif verdict == "level" then why = L["they are too low in level for what you can conjure"]
			elseif verdict == "behind" then why = L["after the buff you have for them"]
			elseif verdict == "skipped" or verdict == "pressed" then why = L["pressed or skipped a moment ago"]
			elseif verdict == "never" then why = L["they are on your never-offer or ignore list"]
			elseif verdict == "reagent" then
				why = L["no %s in your bags"]:format(ns.ReagentName(st.detail) or tostring(st.detail))
			elseif verdict == "cooldown" then why = L["the spell is cooling down"]
			else why = L["not looked at yet"] end
		end
		local key = st.key
		if not (key and aim.keys[key]) then key = KeysOf(aim) and KeysOf(aim)[1] or "courtesy:food" end
		lines[#lines + 1] = L["courtesy: |cffffffff%s|r, your target, is offered %s -- %s"]:format(aim.name, Noun(key), why)
	end
end
