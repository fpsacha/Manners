-- GitHub issue 32: a warlock asked to be reminded to make a healthstone for
-- himself. Create Healthstone (6201) is offered when no healthstone is in the
-- bags (Buffs.lua, makehealthstone, `holds`), outside a fight and standing
-- still, on every client that has the spell (a Soul Shard in the bags where the
-- spell uses one: Forever, Classic Era and Burning Crusade). On by default.
--
-- Every scenario name starts with "healthstone:" so the mutations in
-- tests/mutations/healthstone.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local CREATE = 6201
local SHARD = 6265
local STONE = 5512
local NAMES = {
	[6201] = "Create Healthstone", [6202] = "Create Healthstone", [5699] = "Create Healthstone",
	[11729] = "Create Healthstone", [11730] = "Create Healthstone", [27230] = "Create Healthstone",
}
local ITEM_NAMES = { [SHARD] = "Soul Shard", [STONE] = "Minor Healthstone", [224464] = "Demonic Healthstone" }

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return tostring(ns.Prompt:GetButton():GetAttribute("macrotext1")) end
local function said(ns) return table.concat(ns.MyselfLines(GetTime()), " / ") end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function known(ns, name)
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		if family.key == name then return family end
	end
	return nil
end

local world
local TOUCHED = { "C_Spell", "C_Item", "IsSpellKnown", "IsPlayerSpell", "IsUsableSpell", "IsResting", "UnitLevel",
	"StaticPopup_Hide", "GetUnitSpeed", "IsFalling", "GetInventoryItemID" }

-- The bags changed: the count is read again.
local function restock(ns, bags)
	world.bags = bags
	ns.addon:BAG_UPDATE_DELAYED()
end

-- A warlock on opts.flavour (Forever) who knows opts.known, with opts.bags,
-- standing still, level 60, in no city.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = "WARLOCK"
	world = { known = {}, bags = opts.bags or {}, speed = 0 }
	for _, id in ipairs(opts.known or { CREATE }) do world.known[id] = true end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local function knows(id) return world.known[id] == true end
		rawset(_G, "IsSpellKnown", knows)
		rawset(_G, "IsPlayerSpell", knows)
		rawset(_G, "IsResting", function() return false end)
		local function usable() return true, false end
		rawset(_G, "IsUsableSpell", usable)
		rawset(_G, "C_Spell", nil)
		local spells = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return NAMES[id] or spells.GetSpellName(id) end,
			IsSpellUsable = usable,
		}, { __index = spells }))
		rawset(_G, "C_Item", nil)
		rawset(_G, "C_Item", {
			GetItemCount = function(id) return world.bags[id] or 0 end,
			GetItemNameByID = function(id) return ITEM_NAMES[id] end,
			RequestLoadItemDataByID = function() end,
			GetItemIconByID = function(id) return 7100000 + id end,
			GetItemInfoInstant = function(id) return id, "Miscellaneous", "", "", 7100000 + id, 15, 0 end,
		})
		rawset(_G, "GetInventoryItemID", function() return nil end)
		rawset(_G, "GetUnitSpeed", function() return world.speed end)
		rawset(_G, "IsFalling", function() return false end)
		rawset(_G, "UnitLevel", function() return 60 end)
		rawset(_G, "StaticPopup_Hide", function() end)
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.self = true
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ Forever

do
	local scenario = "healthstone: forever: no healthstone and a Soul Shard, Create Healthstone is offered"
	with(scenario, { bags = { [SHARD] = 3 } }, function(ns)
		if not known(ns, "makehealthstone") then
			fail(scenario, "knowing Create Healthstone, the family is not known; /manners debug says " .. said(ns))
			return
		end
		local entry = mine(ns)
		if key(entry) ~= "createhealthstone" then
			fail(scenario, "offered " .. key(entry) .. "; /manners debug says " .. said(ns))
			return
		end
		ns.Prompt:ApplyTarget(entry)
		if not macro(ns):find("/cast Create Healthstone", 1, true) then fail(scenario, "the press is " .. macro(ns)) end
	end)
end

do
	local scenario = "healthstone: forever: a healthstone of any rank or Improved copy in the bags, nothing is offered"
	for _, item in ipairs({ 9421, 19013, 5512, 19005 }) do
		with(scenario, { bags = { [SHARD] = 3 } }, function(ns)
			if key(mine(ns)) ~= "createhealthstone" then
				fail(scenario, "SKIPPED -- none in the bags, offered " .. key(mine(ns)))
				return
			end
			restock(ns, { [SHARD] = 3, [item] = 1 })
			if mine(ns) then fail(scenario, ("item %d in the bags, offered %s"):format(item, key(mine(ns)))) end
			restock(ns, { [SHARD] = 3 })
			if key(mine(ns)) ~= "createhealthstone" then
				fail(scenario, ("item %d used up, offered %s"):format(item, key(mine(ns))))
			end
		end)
	end
end

do
	local scenario = "healthstone: forever: no Soul Shard, nothing is offered and the debug line says so"
	with(scenario, {}, function(ns)
		if not known(ns, "makehealthstone") then fail(scenario, "the family is not known") return end
		if mine(ns) then fail(scenario, "no Soul Shard, offered " .. key(mine(ns))) end
		if not said(ns):find("Soul Shard", 1, true) then fail(scenario, "no shard and /manners debug says " .. said(ns)) end
		restock(ns, { [SHARD] = 1 })
		if key(mine(ns)) ~= "createhealthstone" then fail(scenario, "a shard in the bags, offered " .. key(mine(ns))) end
	end)
end

do
	local scenario = "healthstone: in a fight, nothing is offered"
	with(scenario, { bags = { [SHARD] = 3 } }, function(ns)
		if key(mine(ns)) ~= "createhealthstone" then fail(scenario, "SKIPPED -- offered " .. key(mine(ns))) return end
		Mock.inCombat = true
		if mine(ns) then fail(scenario, "in a fight, offered " .. key(mine(ns))) end
		Mock.inCombat = false
		if key(mine(ns)) ~= "createhealthstone" then fail(scenario, "the fight over, offered " .. key(mine(ns))) end
	end)
end

do
	local scenario = "healthstone: on the move it waits; standing still it comes back"
	with(scenario, { bags = { [SHARD] = 3 } }, function(ns)
		if key(mine(ns)) ~= "createhealthstone" then fail(scenario, "SKIPPED -- offered " .. key(mine(ns))) return end
		world.speed = 7
		Mock.advance(0.5)
		if mine(ns) then fail(scenario, "moving, offered " .. key(mine(ns))) end
		if not said(ns):find("waits until you stand still", 1, true) then
			fail(scenario, "the Myself lines do not say why: " .. said(ns))
		end
		world.speed = 0
		Mock.advance(2)
		if key(mine(ns)) ~= "createhealthstone" then fail(scenario, "standing still again, offered " .. key(mine(ns))) end
	end)
end

do
	local scenario = "healthstone: switched off, nothing is offered; a new profile has it on"
	with(scenario, { bags = { [SHARD] = 3 } }, function(ns)
		local pick = ns.db.profile.ownBuffs.pick.makehealthstone
		if pick ~= nil and pick ~= "auto" then fail(scenario, "a new profile has it as " .. tostring(pick)) end
		if ns.OwnPick(ns.FindOwnFamily("makehealthstone")) ~= "auto" then fail(scenario, "a new profile does not read Automatic") end
		if key(mine(ns)) ~= "createhealthstone" then fail(scenario, "a new profile, offered " .. key(mine(ns))) return end
		local own = findOption(ns.optionsTable, "own_makehealthstone")
		if not own or own.hidden() then fail(scenario, "Who to buff shows no switch for it") return end
		if own.get() ~= true then fail(scenario, "the switch is not ticked in a new profile") end
		own.set(nil, false)
		if ns.db.profile.ownBuffs.pick.makehealthstone ~= "off" then
			fail(scenario, "unticked, the pick is " .. tostring(ns.db.profile.ownBuffs.pick.makehealthstone))
		end
		if mine(ns) then fail(scenario, "switched off, offered " .. key(mine(ns))) end
		own.set(nil, true)
		if key(mine(ns)) ~= "createhealthstone" then fail(scenario, "ticked again, offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ every client

do
	local scenario = "healthstone: offered on every client where Create Healthstone is learned"
	local clients = {
		{ "camelot", 11730, true }, { "vanilla", 11730, true }, { "tbc", 27230, true },
		{ "mists", CREATE, false }, { "mainline", CREATE, false },
	}
	for _, each in ipairs(clients) do
		local client, spell, shard = each[1], each[2], each[3]
		with(scenario, { flavour = client, known = { spell }, bags = shard and { [SHARD] = 1 } or {} }, function(ns)
			if not known(ns, "makehealthstone") then
				fail(scenario, client .. ": knowing Create Healthstone, the family is not known") return
			end
			if key(mine(ns)) ~= "createhealthstone" then
				fail(scenario, client .. ": offered " .. key(mine(ns)) .. "; /manners debug says " .. said(ns))
				return
			end
			-- A stone in the bags, whatever its rank: nothing.
			restock(ns, shard and { [SHARD] = 1, [STONE] = 1 } or { [STONE] = 1 })
			if mine(ns) then fail(scenario, client .. ": a healthstone in the bags, offered " .. key(mine(ns))) end
			-- Without a shard, where the spell uses one.
			if shard then
				restock(ns, {})
				if mine(ns) then fail(scenario, client .. ": no Soul Shard, offered " .. key(mine(ns))) end
			end
		end)
	end
end

do
	local scenario = "healthstone: retail's Demonic Healthstone counts as one in the bags"
	with(scenario, { flavour = "mainline" }, function(ns)
		if key(mine(ns)) ~= "createhealthstone" then fail(scenario, "SKIPPED -- offered " .. key(mine(ns))) return end
		restock(ns, { [224464] = 1 })
		if mine(ns) then fail(scenario, "a Demonic Healthstone in the bags, offered " .. key(mine(ns))) end
	end)
end

do
	local scenario = "healthstone: knowing no Create Healthstone, the family is not known and its switch is hidden"
	with(scenario, { known = { 1 }, bags = { [SHARD] = 3 } }, function(ns)
		if known(ns, "makehealthstone") then fail(scenario, "knowing no Create Healthstone, the family is known") end
		if mine(ns) then fail(scenario, "knowing no Create Healthstone, offered " .. key(mine(ns))) end
		local own = findOption(ns.optionsTable, "own_makehealthstone")
		if not own then fail(scenario, "no switch is built for it") return end
		if not own.hidden() then fail(scenario, "its switch is shown to a warlock who has not learned it") end
	end)
end

do
	local scenario = "healthstone: the switch is placed on My own buffs under the warlock's own"
	with(scenario, {}, function(ns)
		if not H.placedOn(ns, "who.own_makehealthstone") then
			fail(scenario, "who.own_makehealthstone is not placed on My own buffs")
		end
	end)
end

do
	local scenario = "healthstone: the debug line says a healthstone is in your bags"
	with(scenario, { bags = { [SHARD] = 3, [STONE] = 1 } }, function(ns)
		if mine(ns) then fail(scenario, "a healthstone in the bags, offered " .. key(mine(ns))) end
		if not said(ns):find("a healthstone is in your bags already", 1, true) then
			fail(scenario, "/manners debug says " .. said(ns))
		end
	end)
end
