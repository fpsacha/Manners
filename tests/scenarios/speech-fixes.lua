-- The "In character" set saying the wrong thing, or never its own thing, on a
-- client other than the one it was written on (round 30's bug hunt):
--
-- 1. The Haranir never spoke as themselves. RP.FAMILY is keyed by UnitRace's
--    second return, the client's ChrRaces.ClientFileString, and for the
--    Haranir that is "Harronir" (wago.tools ChrRaces 86 and 91), as it is
--    "Scourge" for the Forsaken; the family was keyed "Haranir".
-- 2. "Your Fortitude for my Fortitude" was judged by name, so a favour given
--    as the group version (a Prayer of Fortitude, filed under the same buff
--    key) was answered with trade and gift lines, up to "Prayer of Fortitude
--    made my day; Prayer of Fortitude should make your hour."
-- 3. On Mists a warlock hands out Dark Intent, and the warlock's class lines
--    about water (written for Unending Breath) went out with it.
-- 4. On Mists Arcane Brilliance gives everybody 5% crit and is not manaOnly,
--    but RP.ONTO.intellect still told a warrior it did nothing for him.
--
-- Every scenario name starts with "speech-fix:" so the mutations in
-- tests/mutations/speech-fixes.py can name the one that has to catch them.
--
-- math.random is a counter here, so every pick is the same on every run and a
-- pool's lines are each drawn in turn.

local dir, H = ...
local fail, load, drive, findOption = H.fail, H.load, H.drive, H.findOption

local realRandom = math.random

local function counting()
	local rolls = 0
	math.random = function(n)
		rolls = rolls + 1
		if not n then return (rolls * 0.6180339887498949) % 1 end
		return ((rolls - 1) % n) + 1
	end
end

-- A session on this client as this class, with speech on and "In character"
-- loaded through the dropdown, as a player would load it.
local function ready(scenario, flavour, class)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	Mock.class = class
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local speech = ns.db.profile.speech
	speech.enabled = true
	speech.onlyWhenReturning = false
	speech.channel = "SAY"
	local preset = findOption(ns.optionsTable, "preset")
	if not (preset and preset.set) then
		fail(scenario, "SKIPPED -- the Load a set dropdown is not on the page")
		return nil
	end
	preset.set({ "preset" }, "incharacter")
	return ns
end

-- Every line, as written, that n picks for this entry draw.
local function drawn(RP, entry, n)
	counting()
	local out = {}
	for _ = 1, n do
		local _, source = RP.Pick(entry, "say", 250)
		if source then out[source] = true end
	end
	math.random = realRandom
	return out
end

-- A set of every line in these pools, nested or not.
local function linesOf(...)
	local out = {}
	local function walk(tbl)
		if type(tbl) == "string" then out[tbl] = true return end
		if type(tbl) ~= "table" then return end
		for _, v in pairs(tbl) do walk(v) end
	end
	for i = 1, select("#", ...) do walk((select(i, ...))) end
	return out
end

-- ------------------------------------------------------------- speech-fix-1
-- A Haranir player, and a Haranir stranger beside them, as the retail client
-- names them: UnitRace -> "Haranir", "Harronir", 91. The player speaks as the
-- Haranir, the stranger is kin, and the pick draws the Haranir's own lines and
-- their kin lines.
do
	local scenario = "speech-fix: a Haranir (race file Harronir) speaks as the Haranir"
	local realRace, realFaction = rawget(_G, "UnitRace"), rawget(_G, "UnitFactionGroup")
	local restoreUnits
	local ok, err = pcall(function()
		Mock.reset()
		Mock.setFlavour("mainline")
		Mock.playerRace = "Harronir"
		rawset(_G, "UnitFactionGroup", function(unit) return "Horde", "Horde" end)
		rawset(_G, "UnitRace", function(unit)
			if unit == "player" or unit == "nameplate1" then return "Haranir", "Harronir", 91 end
			return nil
		end)
		restoreUnits = H.strangers({ nameplate1 = { "Anna", "Aim" } })
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		local RP = ns.InCharacter
		if not (RP and RP.RACE and RP.RACE.haranir) then
			fail(scenario, "SKIPPED -- no Haranir lines in this build")
			return
		end
		local family = RP.Player()
		if family ~= "haranir" then
			fail(scenario, "a Haranir player (UnitRace -> \"Haranir\", \"Harronir\") speaks as "
				.. tostring(family) .. ", so none of RP.RACE.haranir is ever said")
			return
		end
		local holding = ns.UnitFullName and ns.UnitFullName("nameplate1")
		if holding == nil then
			fail(scenario, "SKIPPED -- nameplate1 names nobody")
			return
		end
		local buff = ns.FindBuff("MAGE", "intellect")
		local entry = { name = holding, short = "Anna", unit = "nameplate1", reason = "owed", buff = buff }
		if not RP.IsKin(entry, "haranir") then
			fail(scenario, "a Haranir stranger (race file Harronir) is not kin to a Haranir")
		end
		local own = linesOf(RP.RACE.haranir)
		entry.lean = "race"
		local said = 0
		for text in pairs(drawn(RP, entry, 40)) do
			if own[text] then said = said + 1 else fail(scenario, "leaning on the race said |" .. text .. "|") end
		end
		if said == 0 then fail(scenario, "a Haranir's thank-you never drew a line of the Haranir's own") end
		local kin = linesOf(RP.RACE.haranir.kin)
		entry.lean = "kin"
		local heard = 0
		for text in pairs(drawn(RP, entry, 40)) do
			if kin[text] then heard = heard + 1 end
		end
		if heard == 0 then fail(scenario, "a Haranir to a Haranir never drew a Haranir kin line") end
	end)
	math.random = realRandom
	if restoreUnits then restoreUnits() end
	rawset(_G, "UnitRace", realRace)
	rawset(_G, "UnitFactionGroup", realFaction)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	Mock.reset()
end

-- ------------------------------------------------------------- speech-fix-2
-- On Classic Era and Burning Crusade a Prayer of Fortitude or an Arcane
-- Brilliance reaches the target's party, so the caster need not wear it and
-- is offered the return. The debt files the group id, which Buffs.lua files
-- under the same buff key as the single spell, under another name. Returning
-- that buff is like for like: no trade line, no line about what it does. A
-- favour of another buff's group version still is a trade, or the check
-- would pass with the trade lines gone.
do
	local scenario = "speech-fix: a favour given as the group version is no trade for the same buff"
	local CASES = {
		-- flavour, class, key going back, the group id they gave, the group
		-- cast going back (GroupBuffs.lua's groupCast) when the return is one,
		-- and whether that is a trade
		{ "vanilla", "PRIEST", "fortitude", 21564 },
		{ "vanilla", "MAGE", "intellect", 23028 },
		{ "tbc", "PRIEST", "fortitude", 25392 },
		{ "vanilla", "PRIEST", "fortitude", 21564, { spell = 21564, spellName = "Prayer of Fortitude" } },
		{ "vanilla", "PRIEST", "fortitude", 23028, nil, true },
	}
	for _, case in ipairs(CASES) do
		local flavour, class, key, groupId, groupCast, isTrade = case[1], case[2], case[3], case[4], case[5], case[6]
		local what = ("%s %s returning %s%s for %d"):format(flavour, class, key,
			groupCast and (" as " .. groupCast.spellName) or "", groupId)
		local ok, err = pcall(function()
			local ns = ready(scenario, flavour, class)
			if not ns then return end
			local RP = ns.InCharacter
			local buff = ns.FindBuff(class, key)
			local given = ns.BUFF_BY_ID[groupId]
			if not (buff and given) then
				fail(scenario, "SKIPPED -- " .. what .. ": no " .. key .. " or nothing filed under " .. groupId)
				return
			end
			if (given == buff) == (isTrade == true) then
				fail(scenario, "SKIPPED -- " .. what .. ": " .. groupId .. " is filed under " .. tostring(given.key))
				return
			end
			ns.owed = ns.owed or {}
			ns.owed["Bram"] = { spell = groupId }
			local entry = { name = "Bram", short = "Bram", reason = "owed", buff = buff, lean = "trade",
				groupCast = groupCast }
			local trade = linesOf(RP.TRADE)
			local gifts = linesOf(RP.GIFT)
			local traded, about
			for text in pairs(drawn(RP, entry, 200)) do
				if trade[text] and text:find("{buff}", 1, true) then traded = traded or text end
				if gifts[text] then about = about or text end
			end
			if isTrade then
				if not traded then fail(scenario, what .. ": another buff's group version was never a trade") end
				if not about then fail(scenario, what .. ": what another buff's group version does was never said") end
			elseif traded or about then
				fail(scenario, ("%s (their %s, the same buff) said |%s| / |%s|")
					:format(what, tostring(RP.Gift(entry)), tostring(traded), tostring(about)))
			end
		end)
		math.random = realRandom
		if not ok then fail(scenario, what .. " threw: " .. tostring(err)) end
	end
	Mock.reset()
end

-- ------------------------------------------------------------- speech-fix-3
-- On Mists a warlock's buff is Dark Intent; Unending Breath is never
-- Automatic's there. The class lines about water are Unending Breath's, and
-- are said with it, on Mists when picked by hand and on Classic Era where it is
-- the warlock's only buff, and never with Dark Intent.
do
	local scenario = "speech-fix: a Mists warlock giving Dark Intent says nothing about water"
	local WATER = {
		"Of course, {name}. Going somewhere wet? I won't ask. Warlocks never ask.",
		"Fall in a lake someday, {name}, and you'll think of me fondly.",
		"Breathe easy, {name}. I'd hate to lose you to anything as dull as water.",
		"Swim all you like, {name}. If anyone drifts off, I'll summon them back.",
	}
	local water = {}
	for _, text in ipairs(WATER) do water[text] = true end
	-- The water lines drawn for this buff, over every moment they belong to.
	local function heardWith(RP, buff)
		local heard = {}
		for _, reason in ipairs({ "asked", "nearby", "group" }) do
			local entry = { name = "Bram", short = "Bram", reason = reason, buff = buff, lean = "class",
				inGroup = reason == "group" or nil }
			for text in pairs(drawn(RP, entry, 120)) do
				if water[text] then heard[text] = reason end
			end
		end
		return heard
	end
	for _, flavour in ipairs({ "mists", "vanilla" }) do
		local ok, err = pcall(function()
			local ns = ready(scenario, flavour, "WARLOCK")
			if not ns then return end
			local RP = ns.InCharacter
			local breath = ns.FindBuff("WARLOCK", "breath")
			if not breath then
				fail(scenario, "SKIPPED -- no Unending Breath on " .. flavour)
				return
			end
			local heard = heardWith(RP, breath)
			for _, text in ipairs(WATER) do
				if not heard[text] then
					fail(scenario, flavour .. ": Unending Breath never said its water line |" .. text .. "|")
				end
			end
			local intent = ns.FindBuff("WARLOCK", "darkintent")
			if flavour == "mists" and not intent then
				fail(scenario, "SKIPPED -- no Dark Intent on Mists")
			elseif intent then
				local wrong = {}
				for text, reason in pairs(heardWith(RP, intent)) do wrong[#wrong + 1] = reason .. ": " .. text end
				table.sort(wrong)
				if #wrong > 0 then
					fail(scenario, flavour .. ": casting Dark Intent said Unending Breath's water lines -- "
						.. table.concat(wrong, " | "))
				end
			end
		end)
		math.random = realRandom
		if not ok then fail(scenario, flavour .. " threw: " .. tostring(err)) end
	end
	Mock.reset()
end

-- ------------------------------------------------------------- speech-fix-4
-- RP.ONTO.intellect is for a spell that fills mana, given to somebody with
-- none. On Mists the intellect key is Arcane Brilliance, +5% crit to anybody
-- (SpellEffect 1459, effect 1: aura 290), and not manaOnly: a warrior given it
-- is not told it does nothing for him. Classic Era's Arcane Intellect is
-- manaOnly, and there he still is.
do
	local scenario = "speech-fix: Arcane Brilliance on Mists is not called useless to a warrior"
	for _, flavour in ipairs({ "mists", "vanilla" }) do
		local ok, err = pcall(function()
			local ns = ready(scenario, flavour, "MAGE")
			if not ns then return end
			local RP = ns.InCharacter
			local buff = ns.FindBuff("MAGE", "intellect")
			if not buff then
				fail(scenario, "SKIPPED -- no intellect on " .. flavour)
				return
			end
			local onto = linesOf((RP.ONTO.intellect or {}).WARRIOR)
			local entry = { name = "Bram", short = "Bram", reason = "nearby", buff = buff, class = "WARRIOR",
				lean = "target" }
			local heard = {}
			for text in pairs(drawn(RP, entry, 120)) do
				if onto[text] then heard[#heard + 1] = text end
			end
			table.sort(heard)
			if buff.manaOnly then
				if #heard == 0 then
					fail(scenario, flavour .. ": a manaOnly Arcane Intellect on a warrior never said so")
				end
			elseif flavour == "mists" then
				if #heard > 0 then
					fail(scenario, "Arcane Brilliance (+5% crit to everybody on Mists) given to a warrior said "
						.. "it does nothing for him -- " .. table.concat(heard, " | "))
				end
			else
				fail(scenario, "SKIPPED -- intellect is not manaOnly on " .. flavour)
			end
		end)
		math.random = realRandom
		if not ok then fail(scenario, flavour .. " threw: " .. tostring(err)) end
	end
	Mock.reset()
end
