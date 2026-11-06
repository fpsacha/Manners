-- Oils, stones and food only in dungeons and raids (1.11.6). A player who only
-- uses flasks and oils in dungeons and raids asked for a switch: Who to buff,
-- under Myself, "Oils, stones and food only in dungeons and raids", off by
-- default. On, the reminders for what comes out of the bags -- an oil or a
-- stone for the weapon (Buffs.lua, enhance) and food -- come up only in a dungeon
-- or a raid (IsInInstance says party or raid; a battleground is neither). A
-- rogue's poisons and a fishing lure are not held to it, nor any spell.
--
-- Every scenario name starts with "itemsdungeon:" so the mutations in
-- tests/mutations/itemsdungeon.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local world
local TOUCHED = { "C_Item", "C_Spell", "C_UnitAuras", "UnitLevel", "IsMounted", "IsSpellKnown", "IsPlayerSpell", "IsResting",
	"IsInInstance" }

-- The world: bags (item -> count), the player's level, where he stands.
local function install(ns)
	-- The names the client gives food: Well Fed for the aura, Nutritious Food
	-- for what a meal's use casts (Foods.lua), read by name as the family does.
	rawset(_G, "C_Spell", nil)
	local spells = C_Spell
	local data = ns.FOODS.camelot
	local meals = {}
	for _, row in ipairs(data) do meals[row[3]] = true end
	rawset(_G, "C_Spell", setmetatable({
		GetSpellName = function(id)
			if id == data.fed then return "Well Fed" end
			if meals[id] then return "Nutritious Food" end
			return spells.GetSpellName(id)
		end,
	}, { __index = spells }))
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetAuraDataBySpellName = function() return nil end,
	}, { __index = base }))
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Consumable", "", "", 7100000 + id, 0, 5 end,
	})
	rawset(_G, "UnitLevel", function(unit) if unit == "player" then return 60 end return 12 end)
	rawset(_G, "IsMounted", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "IsSpellKnown", function() return false end)
	rawset(_G, "IsPlayerSpell", function() return false end)
	rawset(_G, "IsInInstance", function()
		if world.where then return true, world.where end
		return false, "none"
	end)
end

-- One session as a warrior on Forever, `bags` held, switch `held` (the setting).
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = opts.class or "WARRIOR"
	world = { bags = opts.bags or {}, where = nil }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		install(ns)
		Mock.playerHeld = {}
		Mock.weaponEnchants = { [0] = {}, [1] = {} }
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		ns.db.profile.sources.self = true
		ns.db.profile.ownBuffs.inCities = true
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.weaponEnchants = nil
	Mock.playerHeld = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function family(ns, class, test)
	for _, f in ipairs(ns.GetOwnFamilies(class) or {}) do
		if test(f) then return f end
	end
	return nil
end

local function stocked(ns, fam)
	local item = fam.spells[1].item
	world.bags[item] = 1
	ns.ForgetScrolls()
	return item
end

local function verdict(ns, fam)
	return ns.OwnVerdict(fam, { name = "x", now = GetTime(), whenBuffed = "skip", refreshUnder = 300 })
end

do
	local scenario = "itemsdungeon: the families it holds are oils, stones and food, and no poison, lure or spell"
	for _, class in ipairs({ "WARRIOR", "ROGUE", "MAGE", "DRUID", "PRIEST" }) do
		with(scenario, { class = class }, function(ns)
			local kinds = {}
			for _, fam in ipairs(ns.GetOwnFamilies(class) or {}) do
				local held = ns.OwnItemsHeldToDungeons(fam)
				local want = fam.food == true
					or (fam.enhance == true and fam.kind ~= "poison" and fam.kind ~= "lure")
				if held ~= want then
					fail(scenario, class .. "'s " .. tostring(fam.key) .. " is " .. (held and "" or "not ")
						.. "held to dungeons, which it should " .. (want and "" or "not ") .. "be")
				end
				kinds[fam.kind or fam.key] = held
			end
			if class == "ROGUE" and kinds.poison ~= false then
				fail(scenario, "a rogue's poison is held to dungeons: " .. tostring(kinds.poison))
			end
			if class == "WARRIOR" and not (kinds.stone and kinds.oil == true and kinds.lure == false) then
				fail(scenario, "a warrior's stone, oil or lure is wrong: " .. tostring(kinds.stone) .. " "
					.. tostring(kinds.oil) .. " " .. tostring(kinds.lure))
			end
		end)
	end
end

do
	local scenario = "itemsdungeon: with it off, food is offered in the world as it was"
	with(scenario, {}, function(ns)
		local data = ns.FOODS.camelot
		world.bags[data[1][1]] = 1
		ns.db.profile.ownBuffs.pick.food = "auto"
		ns.ForgetScrolls()
		Mock.advance(5)
		if not mine(ns) then fail(scenario, "food in the bags was not offered out in the world with the switch off") end
	end)
end

do
	local scenario = "itemsdungeon: on, food waits for a dungeon or a raid"
	with(scenario, {}, function(ns)
		local data = ns.FOODS.camelot
		world.bags[data[1][1]] = 1
		ns.db.profile.ownBuffs.pick.food = "auto"
		ns.db.profile.ownBuffs.itemsInDungeons = true
		ns.ForgetScrolls()
		Mock.advance(5)
		local entry = mine(ns)
		if entry then fail(scenario, "food was offered out in the world with the switch on: " .. key(entry)) end
		world.where = "party"
		Mock.advance(5)
		if not mine(ns) then fail(scenario, "food was not offered in a dungeon with the switch on") end
		world.where = "raid"
		Mock.advance(5)
		if not mine(ns) then fail(scenario, "food was not offered in a raid with the switch on") end
		world.where = "pvp"
		Mock.advance(5)
		if mine(ns) then fail(scenario, "food was offered in a battleground, which is no dungeon") end
	end)
end

do
	local scenario = "itemsdungeon: on, a stone or an oil waits for a dungeon, a fishing lure does not"
	with(scenario, {}, function(ns)
		local stone = family(ns, "WARRIOR", function(f) return f.enhance and f.kind == "stone" and f.slot == 16 end)
		local lure = family(ns, "WARRIOR", function(f) return f.enhance and f.kind == "lure" end)
		if not (stone and lure) then
			fail(scenario, "SKIPPED -- a warrior has no stone or lure family")
			return
		end
		stocked(ns, stone)
		stocked(ns, lure)
		ns.db.profile.ownBuffs.itemsInDungeons = true
		-- No weapon is wielded here, so what steps aside is "noweapon"; the
		-- point is which answer it is, "dungeon" being the switch's.
		local spell, _, _, why = verdict(ns, stone)
		if spell or why ~= "dungeon" then
			fail(scenario, "a stone out in the world with the switch on: " .. tostring(spell and spell.key) .. " / " .. tostring(why))
		end
		local _, _, _, lureWhy = verdict(ns, lure)
		if lureWhy == "dungeon" then fail(scenario, "a fishing lure was held to dungeons") end
		world.where = "party"
		_, _, _, why = verdict(ns, stone)
		if why == "dungeon" then fail(scenario, "a stone in a dungeon was still held back") end
		ns.db.profile.ownBuffs.itemsInDungeons = false
		world.where = nil
		_, _, _, why = verdict(ns, stone)
		if why == "dungeon" then fail(scenario, "a stone out in the world was held back with the switch off") end
	end)
end

do
	local scenario = "itemsdungeon: Who to buff has the switch, off by default, and it is kept"
	with(scenario, {}, function(ns)
		local control = findOption(ns.optionsTable, "ownDungeons")
		if not control then
			fail(scenario, "Who to buff has no switch for oils, stones and food in dungeons")
			return
		end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		if control.get() then fail(scenario, "the switch is on in a new profile") end
		if control.hidden and control.hidden() then fail(scenario, "the switch is hidden from a warrior") end
		control.set(nil, true)
		if ns.db.profile.ownBuffs.itemsInDungeons ~= true or not control.get() then
			fail(scenario, "the switch was not kept")
		end
		ns.db.profile.sources.self = false
		if not (control.disabled and control.disabled()) then
			fail(scenario, "the switch is live with Myself off")
		end
	end)
end

do
	local scenario = "itemsdungeon: /manners debug says why an oil is not offered in the world"
	with(scenario, {}, function(ns)
		local stone = family(ns, "WARRIOR", function(f) return f.enhance and f.kind == "stone" and f.slot == 16 end)
		if not stone then
			fail(scenario, "SKIPPED -- a warrior has no stone family")
			return
		end
		stocked(ns, stone)
		ns.db.profile.ownBuffs.itemsInDungeons = true
		local text = table.concat(ns.MyselfLines(GetTime()) or {}, "\n")
		if not text:find("only offered in a dungeon or a raid", 1, true) then
			fail(scenario, "the reasons do not say it: " .. text)
		end
	end)
end
