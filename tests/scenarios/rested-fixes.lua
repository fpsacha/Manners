-- Bug hunt 35, rested: the Well-Rested family (Buffs.lua, REST; Core.lua,
-- ReadRested, BagBusy, OwnVerdict) and the press of the Cozy Sleeping Bag
-- (Clicks.lua, castingScroll). Each scenario is red on the tree before its fix.
--
-- Every scenario name starts with "rested-fix:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local BAG, RESTED, IN_BAG, UNROLL = 211527, 429959, 429960, 429961

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local world
local TOUCHED = { "C_Item", "C_UnitAuras", "C_Container", "UnitLevel", "GetMaxPlayerLevel", "IsMounted",
	"IsSpellKnown", "IsPlayerSpell", "IsResting", "IsXPUserDisabled" }

local function install()
	rawset(_G, "C_Item", {
		GetItemCount = function(id) return world.bags[id] or 0 end,
		GetItemNameByID = function(id) return "Item " .. id end,
		RequestLoadItemDataByID = function() end,
		GetItemIconByID = function(id) return 7100000 + id end,
		GetItemInfoInstant = function(id) return id, "Miscellaneous", "", "", 7100000 + id, 15, 0 end,
	})
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return world.level end
		return 12
	end)
	rawset(_G, "GetMaxPlayerLevel", function() return world.cap end)
	rawset(_G, "IsMounted", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "IsXPUserDisabled", function() return world.xpOff end)
	local container = rawget(_G, "C_Container")
	rawset(_G, "C_Container", setmetatable({
		GetItemCooldown = function(id)
			if id == BAG and world.secretCooldown then return Mock.SECRET, Mock.SECRET, 1 end
			if id == BAG and world.cooldownUntil then
				return world.cooldownUntil - 3600, 3600, 1
			end
			return 0, 0, 1
		end,
	}, { __index = container or {} }))
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit ~= "player" then return nil end
			-- A secret aura reads as nothing at all.
			if world.hidden and world.hidden[id] then return nil end
			local expires = world.auras[id]
			if expires == nil then return nil end
			return { spellId = id, name = "Aura " .. id, expirationTime = expires, duration = 7200, sourceUnit = "player" }
		end,
	}, { __index = base }))
end

local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = "WARRIOR"
	world = { bags = opts.bags or {}, level = opts.level or 30, cap = opts.cap or 60, auras = {},
		cooldownUntil = nil, xpOff = false }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		install()
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.playerHeld = {}
		if opts.on then
			ns.db.profile.ownBuffs.pick.rested = "auto"
			ns.ForgetScrolls()
		end
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.playerHeld = nil
	Mock.secretAuraIds = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- #0: the client keeping Well-Rested secret (a battleground) reads it as
-- nothing; ShouldSpellAuraBeSecret says so, and the bag is not offered over it.
do
	local scenario = "rested-fix: a secret Well-Rested is not read as missing"
	with(scenario, { on = true, bags = { [BAG] = 1 } }, function(ns)
		if key(mine(ns)) ~= "rested" .. BAG then
			fail(scenario, "SKIPPED -- the bag was not offered to begin with: " .. key(mine(ns)))
			return
		end
		world.auras[RESTED] = GetTime() + 7000
		world.hidden = { [RESTED] = true }
		Mock.secretAuraIds = { [RESTED] = true }
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(1)
		if mine(ns) then
			fail(scenario, "Well-Rested on you but kept secret, and offered " .. key(mine(ns)))
		end
		-- No Well-Rested, but the bag's cooldown is read as secret: not offered.
		world.hidden, world.auras[RESTED], Mock.secretAuraIds = nil, nil, nil
		world.secretCooldown = true
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.advance(1)
		if mine(ns) then
			fail(scenario, "the bag's cooldown kept secret, and offered " .. key(mine(ns)))
		end
		world.secretCooldown = nil
	end)
end

-- #1: a profile switched to with Well-Rested on reads the bags again.
do
	local scenario = "rested-fix: a profile switch to Well-Rested on counts the bag"
	with(scenario, { bags = { [BAG] = 1 } }, function(ns)
		if mine(ns) then
			fail(scenario, "SKIPPED -- offered with the switch off: " .. key(mine(ns)))
			return
		end
		if not ns.db.SetProfile then
			fail(scenario, "SKIPPED -- the mock has no profile switch")
			return
		end
		Mock.sv.profiles = Mock.sv.profiles or {}
		Mock.sv.profiles["Alt"] = { ownBuffs = { pick = { rested = "auto" } } }
		ns.db:SetProfile("Alt")
		if ns.db.profile.ownBuffs.pick.rested ~= "auto" then
			fail(scenario, "SKIPPED -- the profile switched to reads " .. tostring(ns.db.profile.ownBuffs.pick.rested))
			return
		end
		Mock.advance(1)
		if key(mine(ns)) ~= "rested" .. BAG then
			fail(scenario, "switched to a profile with Well-Rested on, the bag in the bags, and offered " .. key(mine(ns)))
		end
		ns.db:SetProfile("Default")
	end)
end

-- #2: Forever's Unroll Bag is a 15-second cast (SpellMisc CastingTimeIndex
-- 653, 15000 ms). The bag is not offered again during it, and an interrupt
-- 10 s in is still the bag's.
do
	local scenario = "rested-fix: the bag's 15-second cast on Forever is held to its end"
	with(scenario, { on = true, bags = { [BAG] = 1 } }, function(ns)
		ns.Prompt:Refresh()
		if key(ns.Prompt:Showing()) ~= "rested" .. BAG then
			fail(scenario, "SKIPPED -- the prompt is on " .. key(ns.Prompt:Showing()))
			return
		end
		local function press(guid)
			ns.Prompt:Refresh()
			local button = ns.Prompt:GetButton()
			button.scripts.PreClick(button, "LeftButton", true)
			button.scripts.PostClick(button, "LeftButton", true)
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, guid, UNROLL)
			return not ns.pendingClick
		end
		if not press("Cast-bag-1") then fail(scenario, "SKIPPED -- the bag's use was never settled") return end
		-- Moved 8 s in: the cast is cut short, nothing used, the bag back.
		Mock.advance(8)
		ns.addon:UNIT_SPELLCAST_INTERRUPTED(nil, "player", "Cast-bag-1", UNROLL)
		Mock.advance(2.1)
		if key(mine(ns)) ~= "rested" .. BAG then
			fail(scenario, "the bag's cast interrupted 8 s in, and 2 s later offered " .. key(mine(ns)))
		end
		Mock.advance(5)
		wipe(ns.tried)
		if not press("Cast-bag-2") then fail(scenario, "SKIPPED -- the second press was never settled") return end
		Mock.advance(13)
		if mine(ns) then
			fail(scenario, "13 s into the bag's 15-second cast, offered " .. key(mine(ns)))
		end
	end)
end

-- #3: no experience to gain is the player's own cap (below 60) or experience
-- turned off, as Blizzard's XP bar has it.
do
	local scenario = "rested-fix: no bag where there is no experience to gain"
	with(scenario, { on = true, bags = { [BAG] = 1 } }, function(ns)
		if key(mine(ns)) ~= "rested" .. BAG then
			fail(scenario, "SKIPPED -- the bag was not offered to begin with: " .. key(mine(ns)))
			return
		end
		world.xpOff = true
		Mock.advance(1)
		if mine(ns) then fail(scenario, "experience turned off, and offered " .. key(mine(ns))) end
		world.xpOff = false
		world.cap, world.level = 25, 25
		Mock.advance(1)
		if mine(ns) then fail(scenario, "at your own level cap of 25, and offered " .. key(mine(ns))) end
	end)
end
