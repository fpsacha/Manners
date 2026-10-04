-- The ids and the facts about them held to what the online databases say of
-- WoW Forever (Wowhead Forever's tooltips and pages, the Forever guides) and
-- to the client's own tables (build 1.60.1.70178):
--
-- - Reagent Economy (1225503), a Legacy perk, takes the vendor reagent off
--   every group spell Manners lists (its class auras 1262650 priest, 1262638
--   mage, 1262636 druid, 1262647 paladin, "No Reagent Cost"). Whoever has it
--   carries no candles, powder, herbs or Symbols, and is still offered the
--   group cast, told it needs no reagent, and not told group buffs are off.
-- - Imbue Spellbreak, until the client has loaded its scroll, is named in
--   each language with the client's own words for Spellbreak and for Imbue.
-- - Buffs.lua's notes on Skyfury's level, a scroll imbue's target and where
--   a mage's scrolls come from say what the client's data says.
--
-- Every scenario name starts with "ids-online:" so the mutations in
-- tests/mutations/ids-online.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local ARCANE_POWDER, WILD_BERRIES, WILD_THORNROOT = 17020, 17021, 17026
local SACRED_CANDLE, HOLY_CANDLE, SYMBOL_OF_KINGS = 17029, 17028, 21177
local ITEM_NAMES = {
	[ARCANE_POWDER] = "Arcane Powder", [WILD_BERRIES] = "Wild Berries",
	[WILD_THORNROOT] = "Wild Thornroot", [SACRED_CANDLE] = "Sacred Candle",
	[HOLY_CANDLE] = "Holy Candle", [SYMBOL_OF_KINGS] = "Symbol of Kings",
}
-- What each group spell eats (Forever's SpellReagents): without the perk the
-- client says it cannot be cast with none in the bags.
local REAGENT_OF = {
	[23028] = ARCANE_POWDER, [21562] = HOLY_CANDLE, [21564] = SACRED_CANDLE,
	[27681] = SACRED_CANDLE, [27683] = SACRED_CANDLE,
	[21849] = WILD_BERRIES, [21850] = WILD_THORNROOT,
	[25782] = SYMBOL_OF_KINGS, [25916] = SYMBOL_OF_KINGS, [25894] = SYMBOL_OF_KINGS,
	[25918] = SYMBOL_OF_KINGS, [25898] = SYMBOL_OF_KINGS, [25895] = SYMBOL_OF_KINGS,
	[25890] = SYMBOL_OF_KINGS,
}

local MAGE_SINGLE = { 10157, 10156, 1461, 1460, 1459 }
local FORTITUDE = { 10938, 10937, 2791, 1245, 1244, 1243 }
local MARK = { 9885, 9884, 8907, 5234, 6756, 5232, 1126 }
local PALADIN_SINGLE = {
	25290, 19854, 19853, 19852, 19850, 19742, -- Wisdom
	25291, 19838, 19837, 19836, 19835, 19834, 19740, -- Might
}

-- The four others in a party of five.
local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
	party4 = { "Dain", "Moor" },
}

-- Globals a scenario may replace, put back after each: Mock.reset owns none.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitPowerMax", "UnitInParty",
	"GetItemCount", "GetItemInfo", "IsUsableSpell", "C_UnitAuras", "C_Spell" }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

local function join(...)
	local out = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if type(v) == "table" then
			for _, id in ipairs(v) do out[#out + 1] = id end
		else
			out[#out + 1] = v
		end
	end
	return out
end

-- The client one scenario stands in: spells known, the bags, each token's
-- class, the auras each wears, and what the client says of a group spell
-- with none of its reagent in the bags. `env.usable`:
--   "perk"   Reagent Economy: usable whatever the bags hold
--   "bags"   usable only with its reagent in the bags (no perk)
--   "always" usable whatever the bags hold, perk or none
--   "silent" the client has no IsSpellUsable or IsUsableSpell at all
-- Asked through C_Spell.IsSpellUsable, as Forever's client is.
local function client(env)
	local known = {}
	for _, id in ipairs(env.known or {}) do known[id] = true end
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = IsSpellKnown
	env.bags = env.bags or {}
	rawset(_G, "GetItemCount", function(id) return env.bags[id] or 0 end)
	rawset(_G, "GetItemInfo", function(id) return ITEM_NAMES[id] end)
	rawset(_G, "IsUsableSpell", nil)
	local classes = env.classes or {}
	local baseClass = UnitClass
	UnitClass = function(unit)
		local class = classes[unit]
		if class then return class, class end
		return baseClass(unit)
	end
	local basePower = UnitPowerMax
	UnitPowerMax = function(unit, power)
		if classes[unit] == "WARRIOR" then return 0 end
		return basePower(unit, power)
	end
	-- The mock counts every unit as in a party of more than one; here only
	-- the party tokens are. A raid is the mock's.
	local baseParty = UnitInParty
	UnitInParty = function(unit)
		if Mock.raid then return baseParty(unit) end
		return type(unit) == "string" and unit:find("^party%d") ~= nil
	end
	env.held = env.held or {}
	local auras = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			if unit == "player" then return auras.GetUnitAuraBySpellID(unit, spellId) end
			local carrying = env.held[unit]
			local source = carrying and carrying[spellId]
			if not source then return nil end
			return { spellId = spellId, expirationTime = Mock.now + 3600, duration = 3600,
				sourceUnit = type(source) == "string" and source or "player" }
		end,
	}, { __index = auras }))
	local spells = C_Spell
	local usable
	if env.usable ~= "silent" then
		usable = function(id)
			local need = REAGENT_OF[id]
			if env.usable == "bags" and need and (env.bags[need] or 0) == 0 then return false, false end
			return true, false
		end
	end
	rawset(_G, "C_Spell", setmetatable({ IsSpellUsable = usable }, { __index = spells }))
end

-- One scenario: the client `env` describes in a party of five (or the raid
-- `env.raid` names), on Forever unless `env.flavour` says otherwise, the
-- lifecycle driven and the slate cleared, then body(ns). Everything is put
-- back and the mock reset, whether it finished or threw.
local function with(scenario, env, body)
	Mock.reset()
	if env.flavour then Mock.setFlavour(env.flavour) end
	Mock.class = env.class or "MAGE"
	if env.raid then Mock.raid = env.raid else Mock.groupSize = 5 end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = H.strangers(env.names or PARTY)
	local ok, err = pcall(function()
		client(env)
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		body(ns)
		noErrors(scenario, ns)
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The one group cast in the queue, or nil.
local function groupCast(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.groupCast then return entry end
	end
	return nil
end

local function macro(ns)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

local function tooltip(ns)
	local button = ns.Prompt:GetButton()
	Mock.tooltip = {}
	if button.scripts.OnEnter then button.scripts.OnEnter(button) end
	return table.concat(Mock.tooltip, " / ")
end

-- A ten-player raid, raid1 being you: four warriors missing Might across both
-- raid groups, two mages, and three priests already wearing our Wisdom.
local function paladinRaid()
	local names, classes = {}, {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	for _, i in ipairs({ 2, 3, 6, 7 }) do classes["raid" .. i] = "WARRIOR" end
	for _, i in ipairs({ 4, 8 }) do classes["raid" .. i] = "MAGE" end
	for _, i in ipairs({ 5, 9, 10 }) do classes["raid" .. i] = "PRIEST" end
	return {
		class = "PALADIN", raid = { size = 10, player = 1 }, names = names, classes = classes,
		known = join(PALADIN_SINGLE, 25916, 25782, 25918, 25894),
		held = { raid5 = { [25290] = true }, raid9 = { [25290] = true }, raid10 = { [25290] = true } },
	}
end

-- Each class's group spell with Reagent Economy and an empty bag.
local function perkCases()
	local raid = paladinRaid()
	raid.usable = "perk"
	return {
		{ label = "mage", spell = "Arcane Brilliance", item = "Arcane Powder",
			env = { known = join(MAGE_SINGLE, 23028), usable = "perk" } },
		{ label = "priest", spell = "Prayer of Fortitude", item = "Sacred Candle",
			env = { class = "PRIEST", known = join(FORTITUDE, 21562, 21564), usable = "perk" } },
		{ label = "druid", spell = "Gift of the Wild", item = "Wild Thornroot",
			env = { class = "DRUID", known = join(MARK, 21849, 21850), usable = "perk" } },
		{ label = "paladin", spell = "Greater Blessing of Might", item = "Symbol of Kings", env = raid },
	}
end

-- ------------------------------------------------------------------ 1
-- With the perk and none of the reagent, the group cast is offered as it is
-- with a bag full: one cast for the party (for a paladin, the class), the
-- macro casting the group spell.
for _, case in ipairs(perkCases()) do
	local scenario = "ids-online: Reagent Economy offers the group spell with no reagent (" .. case.label .. ")"
	with(scenario, case.env, function(ns)
		local group = groupCast(ns)
		if not group then
			fail(scenario, ("a %s with Reagent Economy and no %s was not offered %s, which the game "
				.. "lets them cast without it"):format(case.label, case.item, case.spell))
			return
		end
		local text = flat(macro(ns))
		if not text:find("/cast " .. case.spell, 1, true) then
			fail(scenario, "the macro does not cast " .. case.spell .. ": " .. text)
		end
		if group.groupCast.reagentWaived ~= true then
			fail(scenario, "the group cast does not know the reagent was waived")
		end
	end)
end

-- ------------------------------------------------------------------ 2
-- Its tooltip says nothing is used, not "Uses one Arcane Powder -- you have 0."
do
	local scenario = "ids-online: Reagent Economy: the tooltip says no reagent is needed"
	with(scenario, { known = join(MAGE_SINGLE, 23028), usable = "perk" }, function(ns)
		if not groupCast(ns) then
			fail(scenario, "SKIPPED -- no group cast with Reagent Economy")
			return
		end
		local said = tooltip(ns)
		if not said:find("Arcane Brilliance", 1, true) then
			fail(scenario, "SKIPPED -- the tooltip is not about the group cast: " .. said)
		elseif said:find("Uses one", 1, true) then
			fail(scenario, "the tooltip counts a reagent the cast does not use: " .. said)
		elseif not said:find("No reagent needed.", 1, true) then
			fail(scenario, "the tooltip does not say no reagent is needed: " .. said)
		end
	end)
end

-- ------------------------------------------------------------------ 3
-- The last reagent gone with the perk: nothing has run out, so no "you are
-- out of" note, and the group cast stays.
do
	local scenario = "ids-online: Reagent Economy: an empty bag is not running out"
	local env = { known = join(MAGE_SINGLE, 23028), usable = "perk", bags = { [ARCANE_POWDER] = 1 } }
	with(scenario, env, function(ns)
		if not groupCast(ns) then
			fail(scenario, "SKIPPED -- no group cast with one Arcane Powder")
			return
		end
		Mock.printed = {}
		env.bags[ARCANE_POWDER] = 0
		ns.addon:Tick()
		local said = table.concat(Mock.printed, "\n")
		if said:find("you are out of", 1, true) then
			fail(scenario, "a mage with Reagent Economy was told the prompt goes back to one at a time: " .. said)
		end
		if not groupCast(ns) then
			fail(scenario, "the group cast went with the last Arcane Powder, though the perk needs none")
		end
	end)
end

-- ------------------------------------------------------------------ 4
-- Without the perk, nothing changes: none in the bags is no group cast, the
-- client saying so or saying nothing at all.
for _, case in ipairs({
	{ label = "the client says no", usable = "bags" },
	{ label = "the client says nothing", usable = "silent" },
}) do
	local scenario = "ids-online: without Reagent Economy an empty bag is no group cast (" .. case.label .. ")"
	with(scenario, { known = join(MAGE_SINGLE, 23028), usable = case.usable }, function(ns)
		if groupCast(ns) then
			fail(scenario, "Arcane Brilliance was offered with no Arcane Powder and no perk to waive it")
		end
		for _, buff in ipairs(ns.GetClassBuffs("MAGE") or {}) do
			local info = ns.BuffInfo(buff)
			if info and info.groupRank and ns.ReagentWaived and ns.ReagentWaived(info, 0) then
				fail(scenario, "the reagent of " .. tostring(info.groupRank) .. " reads as waived with no perk")
			end
		end
	end)
end

-- And the client calling the spell usable while the bags hold the reagent
-- is no perk: the tooltip counts it, and the last one going is news.
do
	local scenario = "ids-online: without Reagent Economy a stocked bag is counted and runs out"
	local env = { known = join(MAGE_SINGLE, 23028), usable = "bags", bags = { [ARCANE_POWDER] = 20 } }
	with(scenario, env, function(ns)
		local group = groupCast(ns)
		if not group then
			fail(scenario, "SKIPPED -- no group cast with twenty Arcane Powder")
			return
		end
		local said = tooltip(ns)
		if group.groupCast.reagentWaived or not said:find("Uses one Arcane Powder -- you have 20.", 1, true) then
			fail(scenario, "with no perk the reagent reads as waived while the bags hold it: " .. said)
		end
		Mock.printed = {}
		env.bags[ARCANE_POWDER] = 0
		ns.addon:Tick()
		if not table.concat(Mock.printed, "\n"):find("you are out of Arcane Powder", 1, true) then
			fail(scenario, "running out with no perk is not said: " .. table.concat(Mock.printed, "\n"))
		end
	end)
end

-- ------------------------------------------------------------------ 5
-- Only Forever has the perk. On Classic Era an empty bag is no group cast,
-- whatever the client answers.
do
	local scenario = "ids-online: Classic Era never waives the reagent"
	with(scenario, { flavour = "vanilla", known = join(MAGE_SINGLE, 23028), usable = "always" }, function(ns)
		if groupCast(ns) then
			fail(scenario, "Classic Era offered Arcane Brilliance with no Arcane Powder")
		end
	end)
end

-- ------------------------------------------------------------------ 6
-- Who to buff, Start here and the bug report: an empty bag with the perk is
-- not "none in your bags, so group buffs are not offered."
do
	local scenario = "ids-online: Reagent Economy: the options do not say group buffs are off"
	with(scenario, { known = join(MAGE_SINGLE, 23028), usable = "perk" }, function(ns)
		local note = H.findOption(ns.optionsTable, "reagentNote")
		if not note then
			fail(scenario, "SKIPPED -- no reagent line")
			return
		end
		local text = H.optionText(note.name)
		if text:find("none in your bags", 1, true) then
			fail(scenario, "Who to buff tells a mage with Reagent Economy group buffs are off: " .. text)
		elseif text ~= "Arcane Powder: none needed -- the game lets you cast without it." then
			fail(scenario, "Who to buff does not say the reagent is not needed: " .. text)
		end
		local who = ns.QuickSetup.WhoSummary()
		if who:find("none in your bags", 1, true) then
			fail(scenario, "Start here tells a mage with Reagent Economy group buffs are off: " .. who)
		elseif not who:find("Group buffs when 3 of your party or raid need it.", 1, true) then
			fail(scenario, "Start here does not say when group buffs are offered: " .. who)
		end
		local report = H.findOption(ns.optionsTable, "report")
		local lines = report and report.get({ "diagnostics", "report" }) or ""
		if not lines:find("group spell 23028, reagent 17020 x0 (waived", 1, true) then
			fail(scenario, "the bug report does not say the reagent is waived: " .. flat(lines))
		end
	end)
end

-- ------------------------------------------------------------------ 7
-- Spellbreak's name until the client loads its scroll (item 277503), in the
-- client's own words: its item name per locale on Wowhead Forever, and the
-- order its imbue spells use ("Funken erfüllen", "注入火花", "灌注火花",
-- "전기 불꽃 주입", "Imbuir Fagulha", "Imbuir chispa").
do
	local WANT = {
		deDE = "Zauberbrechen erfüllen",
		ptBR = "Imbuir Rompencanto",
		koKR = "주문 파괴 주입",
		zhCN = "注入破法",
		zhTW = "灌注斷法",
		esES = "Imbuir rompehechizos",
		esMX = "Imbuir rompehechizos",
		frFR = "Imprégnation de brise-sort",
	}
	for _, code in ipairs({ "deDE", "ptBR", "koKR", "zhCN", "zhTW", "esES", "esMX", "frFR" }) do
		local scenario = "ids-online: Spellbreak's stand-in name is the client's in " .. code
		Mock.reset()
		Mock.locale = code
		local ns = load(scenario)
		if ns then
			local name = ns.L["Imbue Spellbreak"]
			if name ~= WANT[code] then
				fail(scenario, ("a %s client is shown %q for Spellbreak before the scroll loads, where its own "
					.. "words are %q"):format(code, tostring(name), WANT[code]))
			end
			noErrors(scenario, ns)
		end
		Mock.reset()
	end
end

-- ------------------------------------------------------------------ 8
-- Buffs.lua's notes say what the client's data says: Skyfury is learned at
-- 16 (retail SpellLevels; Wowhead), a scroll imbue's use is aimed at an item
-- (SpellTargetRestrictions Targets 16, hence the macro's /use 16), and a
-- mage finds the scrolls (Study's Bundle of Scrolls, Comprehend Scroll), never
-- writes them: no spell in the client creates one.
do
	local scenario = "ids-online: Buffs.lua's notes agree with the client's data"
	Mock.reset()
	-- Loaded only so a narrowed run can leave this out like any other.
	local ns = load(scenario)
	local f = ns and io.open(dir .. "/Buffs.lua", "r")
	local source = f and f:read("*a") or ""
	if f then f:close() end
	if not ns then
		-- Left out of this run.
	elseif source == "" then
		fail(scenario, "SKIPPED -- Buffs.lua could not be read")
	else
		if source:find("learned at 17", 1, true) or not source:find("learned at 16", 1, true) then
			fail(scenario, "Buffs.lua does not say Skyfury is learned at 16")
		end
		if source:find("in the main hand by itself", 1, true)
			or not source:find("aimed at an item (Targets 16)", 1, true) then
			fail(scenario, "Buffs.lua says a scroll imbue enchants the weapon by itself, where the macro's /use 16 aims it")
		end
		if source:find("a mage writes", 1, true) or not source:find("Bundle of Scrolls", 1, true) then
			fail(scenario, "Buffs.lua says a mage writes the scrolls, where they are found or deciphered")
		end
	end
end
