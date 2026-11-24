-- Fixes to the own-buff reminders (Buffs.lua's own families, Prompt/Macro.lua's
-- STRATEGIES.self). Every scenario name starts with "own-fix:" so a mutation in
-- tests/mutations/own-fixes.py can name the one that has to catch it.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local SHARD = 6265

-- On Forever, Classic Era and Burning Crusade each rank of Create Healthstone
-- carries its own bracket in its name (tests/scenarios/courtesy.lua mocks the
-- same names).
local NAMES = {
	[6201] = "Create Healthstone (Minor)", [6202] = "Create Healthstone (Lesser)",
	[5699] = "Create Healthstone", [11729] = "Create Healthstone (Greater)",
	[11730] = "Create Healthstone (Major)", [27230] = "Create Healthstone (Master)",
}
local ITEM_NAMES = { [SHARD] = "Soul Shard" }

local TOUCHED = { "C_Spell", "C_Item", "IsSpellKnown", "IsPlayerSpell", "IsUsableSpell", "IsResting", "UnitLevel",
	"StaticPopup_Hide", "GetUnitSpeed", "IsFalling", "GetInventoryItemID" }

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

-- A level-60 warlock on `flavour` who knows `spell`, a Soul Shard in the bags,
-- no healthstone, standing still, in no city.
local function warlock(scenario, flavour, spell, body)
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = "WARLOCK"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local function knows(id) return id == spell end
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
			GetItemCount = function(id) return id == SHARD and 3 or 0 end,
			GetItemNameByID = function(id) return ITEM_NAMES[id] end,
			RequestLoadItemDataByID = function() end,
			GetItemIconByID = function(id) return 7100000 + id end,
			GetItemInfoInstant = function(id) return id, "Miscellaneous", "", "", 7100000 + id, 15, 0 end,
		})
		rawset(_G, "GetInventoryItemID", function() return nil end)
		rawset(_G, "GetUnitSpeed", function() return 0 end)
		rawset(_G, "IsFalling", function() return false end)
		rawset(_G, "UnitLevel", function() return 60 end)
		rawset(_G, "StaticPopup_Hide", function() end)
		local ns = load(scenario)
		if not ns then return end
		-- Ticked at login, as a player who wants it has (off by default since 1.12).
		for _, k in ipairs({ "makehealthstone" }) do ns.defaults.profile.ownBuffs.pick[k] = "auto" end
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

do
	local scenario = "own-fix: a healthstone whose name ends in its own bracket is cast with () so the macro reads no rank"
	local clients = { { "camelot", 11730 }, { "camelot", 6201 }, { "vanilla", 11730 }, { "tbc", 27230 } }
	for _, each in ipairs(clients) do
		local client, spell = each[1], each[2]
		warlock(scenario, client, spell, function(ns)
			local entry = mine(ns)
			local k = tostring(entry and entry.buff and entry.buff.key)
			if k ~= "createhealthstone" then
				fail(scenario, ("SKIPPED -- %s, knowing %d: offered %s"):format(client, spell, k))
				return
			end
			ns.Prompt:ApplyTarget(entry)
			local text = tostring(ns.Prompt:GetButton():GetAttribute("macrotext1"))
			local cast
			for line in (text .. "\n"):gmatch("([^\n]*)\n") do
				if line:sub(1, 6) == "/cast " then cast = line:sub(7) break end
			end
			if not cast then fail(scenario, client .. ": no /cast line in " .. text) return end
			if cast:sub(1, #NAMES[spell]) ~= NAMES[spell] then
				fail(scenario, ("%s, knowing %d: the /cast line names %q"):format(client, spell, cast))
			elseif cast:sub(-1) == ")" and cast:sub(-2) ~= "()" then
				fail(scenario, ("%s, knowing %d: the /cast line is %q, the macro reads its bracket as a rank and casts nothing")
					:format(client, spell, cast))
			end
		end)
	end
end

do
	-- A battleground match on Forever hides your own auras (GitHub issue 29):
	-- a death takes Well Fed and every flask, elixir and scroll with it, so
	-- until you use one again a hidden reading of them is read as gone
	-- (ns.GoneWithDeath), as it is for an armor or a shield. With Consumables
	-- there too ticked, food and an elixir are offered again after the death.
	local scenario = "own-fix: after a death in a battleground food and an elixir the game hides read as gone"
	local KEEP = { "C_UnitAuras", "UnitLevel", "IsMounted", "IsSpellKnown", "IsPlayerSpell", "IsResting",
		"IsInInstance", "UnitIsDeadOrGhost" }
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "WARRIOR"
	local saved = {}
	for _, name in ipairs(KEEP) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		rawset(_G, "C_UnitAuras", nil)
		local base = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetAuraDataBySpellName = function() return nil end,
			GetUnitAuraBySpellID = function() return nil end,
		}, { __index = base }))
		rawset(_G, "UnitLevel", function(unit) if unit == "player" then return 60 end return 12 end)
		rawset(_G, "IsMounted", function() return false end)
		rawset(_G, "IsResting", function() return false end)
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		rawset(_G, "IsInInstance", function() return true, "pvp" end)
		rawset(_G, "UnitIsDeadOrGhost", function(unit) return unit == "player" and Mock.dead == true end)
		Mock.playerHeld = {}
		-- Ticked at login, as a player who wants it has (off by default since 1.12).
		for _, k in ipairs({ "makehealthstone" }) do ns.defaults.profile.ownBuffs.pick[k] = "auto" end
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		local db = ns.db.profile
		db.sources.self = true
		db.ownBuffs.itemsInDungeons = true
		db.battle = db.battle or {}
		db.battle.items = true
		local food, elixir, flask
		for _, f in ipairs(ns.GetOwnFamilies("WARRIOR") or {}) do
			if f.food == true then food = food or f end
			if f.key == "elixir" then elixir = f end
			if f.key == "flask" then flask = f end
		end
		if not (food and elixir and flask) then
			fail(scenario, "SKIPPED -- a warrior on Forever has no food, no elixir or no flask family")
			return
		end
		db.ownBuffs.pick[food.key] = "auto"
		db.ownBuffs.pick[elixir.key] = "auto"
		db.ownBuffs.pick[flask.key] = "auto"
		-- The match hides Well Fed and every aura that says the elixir or the
		-- flask is up.
		Mock.secretAuraIds = { [food.fed] = true }
		for _, id in ipairs(ns.ConsumableAuras(elixir)) do Mock.secretAuraIds[id] = true end
		for _, id in ipairs(ns.ConsumableAuras(flask)) do Mock.secretAuraIds[id] = true end
		local ctx = { name = "Petra", now = GetTime(), whenBuffed = ns.SelfWhenBuffed(db.filters),
			refreshUnder = db.filters.refreshUnder }
		for _, f in ipairs({ food, elixir, flask }) do
			local before = ns.ReadOwnFamily(f)
			if before ~= nil then
				fail(scenario, ("SKIPPED -- %s reads %s before any death, not hidden"):format(f.key, tostring(before)))
				return
			end
		end
		Mock.dead = true
		ns.addon:PLAYER_DEAD()
		Mock.advance(1)
		Mock.dead = false
		ns.addon:PLAYER_ALIVE()
		Mock.advance(1)
		ctx.now = GetTime()
		for _, f in ipairs({ food, elixir }) do
			local up = ns.ReadOwnFamily(f)
			local why = select(4, ns.OwnVerdict(f, ctx))
			if up ~= false then
				fail(scenario, ("after a death %s (%s) still reads %s while the game hides it, not gone; the verdict says %s")
					:format(f.key, ns.OwnFamilyLabel(f), tostring(up), tostring(why)))
			elseif why == "unread" then
				fail(scenario, ("after a death the verdict on %s is still \"unread\""):format(f.key))
			end
		end
		-- A flask stays on through death: its hidden reading stays unread, never
		-- gone, so no flask is used over the one still on you.
		local kept = ns.ReadOwnFamily(flask)
		if kept ~= nil then
			fail(scenario, ("after a death the flask the game hides reads %s, not unread"):format(tostring(kept)))
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(KEEP) do rawset(_G, name, saved[name]) end
	Mock.secretAuraIds = nil
	Mock.playerHeld = nil
	Mock.dead = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
