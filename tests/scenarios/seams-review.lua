-- The review of the places where the features of one release meet: the
-- resurrection's switches for a class with no buff for anybody else, a
-- courtesy asked for by somebody who has died or gone offline since, the walk
-- a class with a cure and no buff makes (not in a fight, and no passer-by
-- measured for a cure that is the group's alone), and where the group's
-- switches sit in the options window.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every
-- global a scenario replaces is put back after it. Every name starts
-- "seams-review:", so the mutations in tests/mutations/seams-review.py can
-- name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_Spell", "GetItemCount", "C_Container",
	"UnitGUID", "UnitLevel", "UnitInParty", "C_UnitAuras", "UnitAffectingCombat",
	"UnitIsDeadOrGhost", "UnitIsConnected" }

local SPELLS = {
	[1459] = "Arcane Intellect", [475] = "Remove Lesser Curse",
	[5504] = "Conjure Water", [10140] = "Conjure Water", [2008] = "Ancestral Spirit",
}

-- One session. `env.class` is the player's class (a mage), `env.known` the
-- spell ids known, `env.names` the units that exist by token, `env.bags` item
-- -> count, `env.group` the group's size. body(ns, world): `world.dead` and
-- `world.offline` by token, `world.combat` for a fight, `world.cursed` the
-- token wearing a curse, and `world.asked`, UnitIsDeadOrGhost counted by token.
local function with(scenario, env, body)
	Mock.reset()
	Mock.class = env.class or "MAGE"
	if env.group then Mock.groupSize = env.group end
	if env.held then Mock.held = env.held end
	local restore = strangers(env.names or {})
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local world = { dead = {}, offline = {}, asked = {}, bags = env.bags or {} }
	local ok, err = pcall(function()
		local known = {}
		for _, id in ipairs(env.known or {}) do known[id] = true end
		local realDead, realConnected, realSpell, realAuras = UnitIsDeadOrGhost, UnitIsConnected, C_Spell, C_UnitAuras
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return SPELLS[id] or realSpell.GetSpellName(id) end,
		}, { __index = realSpell }))
		rawset(_G, "UnitIsDeadOrGhost", function(unit)
			world.asked[unit] = (world.asked[unit] or 0) + 1
			if world.dead[unit] then return true end
			return realDead(unit)
		end)
		rawset(_G, "UnitIsConnected", function(unit)
			if world.offline[unit] then return false end
			return realConnected(unit)
		end)
		rawset(_G, "UnitAffectingCombat", function() return world.combat == true end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d+$") ~= nil
		end)
		rawset(_G, "UnitGUID", function(unit) return "Player-1-" .. tostring(unit) end)
		rawset(_G, "UnitLevel", function() return 60 end)
		rawset(_G, "GetItemCount", function(item) return world.bags[item] or 0 end)
		rawset(_G, "C_Container", {
			GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
			GetContainerItemID = function(bag, slot)
				local list = {}
				for item, count in pairs(world.bags) do
					if count > 0 then list[#list + 1] = item end
				end
				table.sort(list)
				return bag == 0 and list[slot] or nil
			end,
			GetContainerItemInfo = function() return { isLocked = false } end,
		})
		rawset(_G, "C_UnitAuras", setmetatable({
			GetAuraDataByIndex = function(unit, index, filter)
				if filter ~= "HARMFUL" then return realAuras.GetAuraDataByIndex(unit, index, filter) end
				if not (world.cursed == unit and index == 1) then return nil end
				return {
					name = "Curse thing", spellId = 90000, dispelName = "Curse",
					expirationTime = Mock.now + 60, duration = 60, isHarmful = true, auraInstanceID = 9001,
				}
			end,
		}, { __index = realAuras }))
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns, world)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
	return nil
end

local function hear(ns, event, text, sender, guid)
	ns.addon[event](ns.addon, event, text, sender, "Common", "", "", "", 0, 0, "", 0, 1, guid)
end

-- A mage whose one buff is switched off, with the group's cure on: nothing
-- to give anybody but Remove Lesser Curse.
local function cureOnly(ns, scenario)
	local db = ns.db.profile
	db.sources.asked = true
	db.sources.self = false
	db.sources.group = true
	db.sources.cures = true
	db.sources.curesStrangers = false
	db.buff.skip = { intellect = true }
	ns.Guard("probe", ns.ProbeCapabilities)
	if #ns.CastableBuffs() ~= 0 then
		fail(scenario, "SKIPPED -- the mage still has a buff to give")
		return false
	end
	return true
end

-- ------------------------------------------------------------ seams-review 1
-- A shaman on WoW Forever has no buff for anybody else and Ancestral Spirit:
-- the two switches of the resurrection are shown to him on Who to buff, and
-- Start here and the tab count the resurrection as a prompt.
do
	local scenario = "seams-review: a class with no buff for others is shown the resurrection's switches"
	with(scenario, { class = "SHAMAN", known = { 2008 } }, function(ns)
		if ns.caps.hasClassBuffs then
			fail(scenario, "SKIPPED -- the shaman has a buff for somebody else")
			return
		end
		if not ns.caps.res then
			fail(scenario, "SKIPPED -- Ancestral Spirit is not read as learned")
			return
		end
		local sources = ns.db.profile.sources
		local res, too = H.findOption(ns.optionsTable, "res"), H.findOption(ns.optionsTable, "resStrangers")
		if not (res and too) then
			fail(scenario, "the options hold no My group's dead, or no Dead passers-by too")
			return
		end
		sources.res = true
		if type(res.hidden) ~= "function" or res.hidden() then
			fail(scenario, "My group's dead is hidden from a shaman with Ancestral Spirit")
		end
		if type(too.hidden) ~= "function" or too.hidden() then
			fail(scenario, "Dead passers-by too is hidden from a shaman with Ancestral Spirit")
		end
		-- A switch about buffs for others stays hidden from him.
		local group = H.findOption(ns.optionsTable, "group")
		if group and not (type(group.hidden) == "function" and group.hidden()) then
			fail(scenario, "SKIPPED -- My party and raid is shown to a class with no buff for others")
		end
	end)
end

do
	local scenario = "seams-review: a resurrection learned and switched on is a prompt for Start here"
	with(scenario, { class = "SHAMAN", known = { 2008 } }, function(ns)
		local sources = ns.db.profile.sources
		sources.res = false
		if ns.OptionsPage.HasPrompt() then
			fail(scenario, "SKIPPED -- the shaman has a prompt with the resurrection switched off")
			return
		end
		sources.res = true
		if not ns.CanCastAnything() then
			fail(scenario, "SKIPPED -- the resurrection is nothing to cast")
			return
		end
		if not ns.OptionsPage.HasPrompt() then
			fail(scenario, "with a resurrection learned and My group's dead on, the options say there is no prompt")
		end
	end)
end

-- ------------------------------------------------------------ seams-review 2
-- Somebody who asked for water and has died, or gone offline, since is not
-- offered it: the press would be a trade the game refuses.
do
	local scenario = "seams-review: a courtesy is not offered to an asker who is dead or offline"
	with(scenario, { known = { 1459, 5504, 10140 }, bags = { [8079] = 20 },
		names = { nameplate1 = { "Anna", "Aim" } } }, function(ns, world)
		local db = ns.db.profile
		db.sources.asked = true
		db.sources.strangers, db.sources.group, db.sources.self = false, false, false
		db.sources.courtesyRefresh = true
		hear(ns, "CHAT_MSG_SAY", "water pls", "Anna Aim", "Player-1-nameplate1")
		local anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy) then
			fail(scenario, "SKIPPED -- the water is not offered while she lives")
			return
		end
		world.dead.nameplate1 = true
		anna = entryFor(ns, "Anna Aim")
		if anna then
			fail(scenario, "dead, she is still offered " .. tostring(anna.courtesy and anna.courtesy.stage or "a buff"))
		end
		world.dead.nameplate1 = nil
		world.offline.nameplate1 = true
		anna = entryFor(ns, "Anna Aim")
		if anna then fail(scenario, "offline, she is still offered the water") end
		world.offline.nameplate1 = nil
		anna = entryFor(ns, "Anna Aim")
		if not (anna and anna.courtesy) then
			fail(scenario, "alive and online again, with the request standing, she is not offered the water")
		end
	end)
end

-- ------------------------------------------------------------ seams-review 3
-- A class with a cure and no buff for anybody walks its group for the cure,
-- but not in a fight, where no cure is offered: nobody is read for nothing.
do
	local scenario = "seams-review: a class with a cure and no buff walks nobody in a fight"
	with(scenario, { known = { 1459, 475 }, group = 2, held = { [1459] = true },
		names = { party1 = { "Gwen", "Hale" } } }, function(ns, world)
		if not cureOnly(ns, scenario) then return end
		world.cursed = "party1"
		Mock.advance(4)
		local gwen = entryFor(ns, "Gwen Hale")
		if not (gwen and gwen.cure == "Curse") then
			fail(scenario, "SKIPPED -- out of a fight the cursed party member is not offered the cure")
			return
		end
		wipe(world.asked)
		ns.BuildQueue()
		if (world.asked.party1 or 0) == 0 then
			fail(scenario, "SKIPPED -- the walk out of a fight is not seen by this scenario")
			return
		end
		world.combat = true
		wipe(world.asked)
		local queue = ns.BuildQueue()
		if (world.asked.party1 or 0) ~= 0 then
			fail(scenario, ("in a fight the party member was still walked (%d reads)"):format(world.asked.party1))
		end
		for _, entry in ipairs(queue) do
			if entry.cure then fail(scenario, "a cure is offered in a fight") end
		end
		world.combat = false
		gwen = entryFor(ns, "Gwen Hale")
		if not (gwen and gwen.cure == "Curse") then
			fail(scenario, "after the fight the cursed party member is not offered the cure again")
		end
	end)
end

-- With the group's cure alone ticked and no buff in hand, a passer-by can be
-- offered nothing: none is measured for nearness. With Cure passers-by on
-- they are.
do
	local scenario = "seams-review: no passer-by is measured for a cure that is the group's alone"
	with(scenario, { known = { 1459, 475 }, group = 2, held = { [1459] = true },
		names = { party1 = { "Gwen", "Hale" }, nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } } },
		function(ns, world)
		if not cureOnly(ns, scenario) then return end
		local db = ns.db.profile
		db.sources.strangers = true
		local measured = 0
		local real = ns.NearEnough
		ns.NearEnough = function(unit)
			measured = measured + 1
			return true
		end
		local ok, err = pcall(function()
			db.sources.curesStrangers = true
			ns.BuildQueue()
			if measured == 0 then
				fail(scenario, "SKIPPED -- with Cure passers-by on no passer-by is measured")
				return
			end
			db.sources.curesStrangers = false
			measured = 0
			world.cursed = "party1"
			Mock.advance(4)
			measured = 0
			local gwen = entryFor(ns, "Gwen Hale")
			if measured ~= 0 then
				fail(scenario, ("%d passers-by were measured with nothing to offer them"):format(measured))
			end
			if not (gwen and gwen.cure == "Curse") then
				fail(scenario, "the cursed party member is no longer offered the cure")
			end
		end)
		ns.NearEnough = real
		if not ok then error(err, 0) end
	end)
end

-- ------------------------------------------------------------ seams-review 4
-- In the options window Share the group sits with My group's pets too, right
-- under My party and raid, and the resurrection's switches after the two.
do
	local scenario = "seams-review: the group's own switches sit together, ahead of the resurrection's"
	with(scenario, { class = "PRIEST", known = {} }, function(ns)
		if not H.layoutInToc() then return end
		local page, section, group = H.placedOn(ns, "who.group")
		local _, petsSection, pets = H.placedOn(ns, "who.pets")
		local _, shareSection, share = H.placedOn(ns, "who.share")
		local _, resSection, res = H.placedOn(ns, "who.res")
		local _, tooSection, too = H.placedOn(ns, "who.resStrangers")
		if not (group and pets and share and res and too) then
			fail(scenario, "SKIPPED -- one of the group's switches has no place in the window")
			return
		end
		if petsSection ~= section or shareSection ~= section or resSection ~= section or tooSection ~= section then
			fail(scenario, "the group's switches are not in one section")
			return
		end
		if pets ~= group + 1 or share ~= pets + 1 then
			fail(scenario, ("Share the group is not right under My group's pets too (group %d, pets %d, share %d)")
				:format(group, pets, share))
		end
		if res ~= share + 1 or too ~= res + 1 then
			fail(scenario, ("the resurrection's switches do not follow the group's own (share %d, dead %d, passers-by %d)")
				:format(share, res, too))
		end
		for _, at in ipairs({ pets, share, too }) do
			local item = section.items[at]
			if not (type(item) == "table" and item.indent == true) then
				fail(scenario, "item " .. at .. " of the section is not a step in")
			end
		end
		if type(section.items[res]) == "table" and section.items[res].indent then
			fail(scenario, "My group's dead is drawn as a step in")
		end
	end)
end
