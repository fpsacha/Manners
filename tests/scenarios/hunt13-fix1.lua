-- Round 13, fix 1: three faults the hunt found in the queue and the words on
-- the prompt.
--
-- A buff you cannot pay for was offered all the same. Only a mana bar at
-- exactly zero stopped the queue, so a mage at 150 mana was offered an
-- Intellect costing more, every press failed with "Not enough mana", nothing
-- backed off (the fault is the caster's), and with speech on everybody was
-- thanked and nobody buffed. The queue now asks the game about each spell
-- once a scan (Queue.lua, Affordable), and drops only a no for want of mana.
--
-- The out-of-sight test asked only group members offered as the group, so a
-- raider owed a favour, or who asked in chat, and then hearthed away sat on
-- top of the prompt with every press failing out of range.
--
-- {class} in Prompt wording printed the game's token ("PRIEST") in every
-- language; it now reads the client's own class names (Core.lua, ClassName).
--
-- Every scenario name starts with "hunt13-fix1:" so the mutations in
-- tests/mutations/hunt13-fix1.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local ANNA, BERT, CARA, ZED = "Anna Aim", "Bert Beside", "Cara Close", "Zed Far"

-- A mage's armor in every rank the own-buff scenarios use (ownbuffs.lua):
-- Frost Armor, Ice Armor, Mage Armor. Cheap next to an Intellect.
local ARMOR = { 168, 7300, 7301, 7302, 6117 }

-- Globals a scenario below replaces for its own length, and puts back. The
-- spellbook pair and C_Spell are not Mock.reset's.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_Spell", "IsUsableSpell",
	"UnitPower", "UnitPowerMax", "UnitIsVisible", "LOCALIZED_CLASS_NAMES_MALE" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

-- Runs one scenario body and puts every global above back, whether it
-- finished or threw. A throw is a failure of that scenario, named.
local function run(scenario, body)
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.inCombat = false
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

local function macroOf(ns)
	return tostring(ns.Prompt:GetButton():GetAttribute("macrotext1") or "")
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
	return nil
end

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

local function know(ids)
	local known = {}
	for _, id in ipairs(ids) do known[id] = true end
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = IsSpellKnown
end

local function join(a, b)
	local out = {}
	for _, id in ipairs(a) do out[#out + 1] = id end
	for _, id in ipairs(b) do out[#out + 1] = id end
	return out
end

-- The client's IsSpellUsable, as C_Spell.IsSpellUsable or the older global
-- IsUsableSpell: `answer.usable, answer.noMana` for every rank of Intellect,
-- yes for everything else. `answer` is the caller's, to change between reads.
local function usableCall(ids, answer)
	local intellect = {}
	for _, id in ipairs(ids) do intellect[id] = true end
	return function(spell)
		answer.asked = answer.asked + 1
		if intellect[spell] then return answer.usable, answer.noMana end
		return true, false
	end
end

local function installModern(fn)
	rawset(_G, "C_Spell", nil)
	local base = C_Spell
	rawset(_G, "C_Spell", setmetatable({ IsSpellUsable = fn }, { __index = base }))
end

-- -------------------------------------------------------------- fix1 1
-- A mage low on mana, owed by a party member and by somebody no token
-- reaches, and missing both her own Intellect and her armor. The game says
-- Intellect cannot be paid for: nobody is offered it, not the party member,
-- not the favour out of sight, not herself -- and the armor, which she can
-- pay for, is still offered. A plain no (a form) and a client that will not
-- say keep Intellect on offer.
for _, case in ipairs({
	{ label = "C_Spell", modern = true, usable = false, noMana = true, dropped = true },
	{ label = "the older call", modern = false, usable = false, noMana = true, dropped = true },
	{ label = "a form", modern = true, usable = false, noMana = false, dropped = false },
	{ label = "the client will not say", modern = true, usable = Mock.SECRET, noMana = Mock.SECRET,
		dropped = false },
}) do
	Mock.reset()
	local scenario = case.dropped
		and ("hunt13-fix1: a buff you cannot pay for is offered to nobody (" .. case.label .. ")")
		or ("hunt13-fix1: a no that is not for want of mana keeps the buff on offer (" .. case.label .. ")")
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" } })
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		local intellect = ns.FindBuff("MAGE", "intellect").ranks
		know(join(intellect, ARMOR))
		Mock.groupSize = 2
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		ns.db.profile.sources.strangers = false
		UnitPowerMax = function() return 5000 end
		UnitPower = function(unit) if unit == "player" then return 150 end return 500 end
		owe(ns, ANNA)
		owe(ns, ZED)
		-- Wearing nothing of your own: Intellect first, then the armor.
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))

		-- Before the game has a word to say: all three on Intellect.
		local me = ns.UnitFullName("player")
		for _, who in ipairs({ ANNA, ZED, me }) do
			if key(entryFor(ns, who)) ~= "intellect" then
				fail(scenario, "SKIPPED -- " .. tostring(who) .. " was not offered Intellect to begin with: "
					.. key(entryFor(ns, who)))
				return
			end
		end

		local answer = { usable = case.usable, noMana = case.noMana, asked = 0 }
		local fn = usableCall(intellect, answer)
		if case.modern then
			installModern(fn)
		else
			-- No C_Spell.IsSpellUsable at all, only the older global.
			rawset(_G, "C_Spell", nil)
			IsUsableSpell = fn
		end

		local queue = ns.BuildQueue()
		local offered = {}
		for _, entry in ipairs(queue) do
			if key(entry) == "intellect" then offered[#offered + 1] = tostring(entry.name) end
		end
		if case.dropped then
			if #offered > 0 then
				fail(scenario, "offered Intellect the game says you cannot pay for, to "
					.. table.concat(offered, ", "))
			end
			local mine = entryFor(ns, me)
			if not (mine and mine.reason == "self" and key(mine) ~= "intellect"
				and key(mine) ~= "nil") then
				fail(scenario, "your armor, which you can pay for, was not offered in its place: "
					.. key(mine))
			end
			ns.addon:Tick()
			ns.addon:Tick()
			if macroOf(ns):find("Arcane Intellect", 1, true) then
				fail(scenario, "the prompt armed a cast you cannot pay for: " .. flat(macroOf(ns)))
			end
			-- /manners debug and Diagnostics say what the prompt is on, not
			-- an Intellect it has dropped.
			local first = ns.SelfBuffFirst(ns.db.profile, GetTime())
			if first then
				fail(scenario, "debug says your own " .. tostring(first.key)
					.. " comes first, which the prompt dropped for want of mana")
			end
		else
			for _, who in ipairs({ ANNA, ZED }) do
				if key(entryFor(ns, who)) ~= "intellect" then
					fail(scenario, tostring(who) .. " was not offered Intellect on a no that is not"
						.. " for want of mana: " .. key(entryFor(ns, who)))
				end
			end
		end
		if answer.asked == 0 then
			fail(scenario, "the game was never asked whether Intellect can be cast")
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
	Mock.reset()
end

-- -------------------------------------------------------------- fix1 1b
-- Judged spell by spell: a priest who cannot pay for Fortitude can still pay
-- for Shadow Protection, and is offered it. But a pin is "only ever this
-- one", and PickBuffFor swaps whatever list it is handed for the pin: pinned
-- to a Fortitude she cannot pay for, she is offered nothing at all.
for _, case in ipairs({
	{ scenario = "hunt13-fix1: a spell you can pay for is still offered beside one you cannot" },
	{ scenario = "hunt13-fix1: a pinned buff you cannot pay for is offered to nobody", pinned = true },
}) do
	Mock.reset()
	local scenario = case.scenario
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" } })
	run(scenario, function()
		Mock.class = "PRIEST"
		local ns = load(scenario)
		if not ns then return end
		local fortitude = ns.FindBuff("PRIEST", "fortitude").ranks
		know(join(fortitude, ns.FindBuff("PRIEST", "shadow").ranks))
		Mock.groupSize = 2
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		ns.db.profile.sources.strangers = false
		owe(ns, ANNA)
		if key(entryFor(ns, ANNA)) ~= "fortitude" then
			fail(scenario, "SKIPPED -- Anna was not offered Fortitude to begin with: " .. key(entryFor(ns, ANNA)))
			return
		end
		local answer = { usable = false, noMana = true, asked = 0 }
		installModern(usableCall(fortitude, answer))
		if case.pinned then
			ns.db.profile.buff.choice = "fortitude"
			for _, entry in ipairs(ns.BuildQueue()) do
				if key(entry) == "fortitude" then
					fail(scenario, "offered the pinned Fortitude you cannot pay for, to " .. tostring(entry.name))
				end
			end
		elseif key(entryFor(ns, ANNA)) ~= "shadow" then
			fail(scenario, "Anna was not offered the Shadow Protection you can pay for: "
				.. key(entryFor(ns, ANNA)))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
	Mock.reset()
end

-- -------------------------------------------------------------- fix1 2
-- A party member out of sight -- hearthed to town while you are inside -- is
-- out of range for certain, whatever brought them onto the prompt: a favour
-- owed or a request in /party as much as the group. The range check answers
-- nothing here (Mock.rangeless), as it often does on this client, so nothing
-- else would keep them off it. Once the game sees them again they are back,
-- at a favour's or a request's priority.
for _, case in ipairs({
	{ label = "owed", reason = "owed", priority = 1 },
	{ label = "asking", reason = "asked", priority = 1.5 },
}) do
	Mock.reset()
	local scenario = "hunt13-fix1: a party member out of sight is not offered though " .. case.label
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" },
		party3 = { "Cara", "Close" } })
	local visible = { party3 = false }
	run(scenario, function()
		UnitIsVisible = function(unit)
			if visible[unit] == nil then return true end
			return visible[unit]
		end
		local ns = load(scenario)
		if not ns then return end
		Mock.groupSize = 4
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		ns.db.profile.sources.strangers = false
		ns.db.profile.sources.asked = true
		Mock.rangeless = {}
		for _, id in ipairs(ns.FindBuff("MAGE", "intellect").ranks) do Mock.rangeless[id] = true end
		if not entryFor(ns, ANNA) or entryFor(ns, CARA) then
			fail(scenario, "SKIPPED -- the party in sight was not offered, or Cara out of sight was")
			return
		end
		if case.reason == "owed" then
			owe(ns, CARA)
		else
			ns.addon.CHAT_MSG_PARTY(ns.addon, "CHAT_MSG_PARTY", "int pls", CARA, "Common", "", "", "",
				0, 0, "", 0, 1, "Player-1-party3")
		end
		local cara = entryFor(ns, CARA)
		if cara then
			fail(scenario, ("a party member out of sight was offered, %s at priority %s")
				:format(tostring(cara.reason), tostring(cara.priority)))
		end
		ns.addon:Tick()
		if ns.Prompt:GetButton():IsShown() and ns.Prompt:PanelName() == CARA then
			fail(scenario, "the prompt put up a party member out of sight: " .. flat(macroOf(ns)))
		end
		if case.reason == "owed" and not ns.owed[CARA] then
			fail(scenario, "being out of sight wrote off the favour owed")
		end
		visible.party3 = true
		cara = entryFor(ns, CARA)
		if not cara then
			fail(scenario, "back in sight, the party member was not offered again")
		elseif cara.reason ~= case.reason or cara.priority ~= case.priority then
			fail(scenario, ("back in sight, the party member was offered as %s at priority %s")
				:format(tostring(cara.reason), tostring(cara.priority)))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
	Mock.reset()
end

-- -------------------------------------------------------------- fix1 3
-- {class} in the prompt's first line is the class as the client spells it:
-- "Priester" on a German client, "Priest" where the client has no table of
-- names -- never the token "PRIEST". The paladin's "Every Warrior" reads the
-- same localiser (groupbuffs.lua), so the two cannot drift apart.
Mock.reset()
do
	local scenario = "hunt13-fix1: {class} on the prompt is the class in the client's words"
	local restoreUnits = strangers({})
	run(scenario, function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		local p = ns.db.profile.prompt
		p.format = "{name} ({class})"
		p.classColor = false
		owe(ns, ANNA)
		local anna = entryFor(ns, ANNA)
		if not (anna and anna.class == "PRIEST") then
			fail(scenario, "SKIPPED -- the favour owed by a priest was not offered: " .. tostring(anna and anna.class))
			return
		end
		LOCALIZED_CLASS_NAMES_MALE = { PRIEST = "Priester" }
		ns.addon:Tick()
		ns.addon:Tick()
		local regions = ns.Prompt:Regions()
		local painted = regions.name and regions.name:GetText()
		if painted ~= "Anna Aim (Priester)" then
			fail(scenario, "with the client's class names the panel reads " .. tostring(painted))
		end
		LOCALIZED_CLASS_NAMES_MALE = nil
		local line = ns.Prompt:RenderPrimary(entryFor(ns, ANNA), 0)
		if line ~= "Anna Aim (Priest)" then
			fail(scenario, "with no class names the first line reads " .. tostring(line))
		end
		-- An entry with no class reads as nothing rather than throwing.
		local _, classless = pcall(ns.Prompt.RenderPrimary, ns.Prompt,
			{ name = BERT, short = BERT, reason = "owed" }, 0)
		if classless ~= "Bert Beside ()" then
			fail(scenario, "with no class at all the first line reads " .. tostring(classless))
		end
		noErrors(scenario, ns)
	end)
	restoreUnits()
end
Mock.reset()
