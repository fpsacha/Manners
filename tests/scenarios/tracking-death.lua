-- Tracking after a death (GitHub issue 55, aisenfaire on CurseForge: "it no
-- longer reminded me to turn on Find Minerals after dying in Badlands"). A
-- death drops your tracking on vanilla content, but the minimap's list can go
-- on saying it is on. So after a death Core.lua's ReadOwnFamily reads a
-- tracking the list shows on as off, until the list changes while you are
-- alive (MINIMAP_UPDATE_TRACKING) or you cast it. Burning Crusade's tracking
-- outlasts a death (Buffs.lua, throughDeath) and reads as the list says.
--
-- Drives a stand-in C_Minimap as tracking.lua does. Every scenario name starts
-- with "tracking-death:" so tests/mutations/tracking-death.py can name it.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local FIND_MINERALS = 2580

local realKnown, realPlayer, realDead = IsSpellKnown, IsPlayerSpell, UnitIsDeadOrGhost

local function session(scenario, flavour, body)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	local list = { { spellID = FIND_MINERALS, active = true } }
	rawset(_G, "C_Minimap", {
		GetNumTrackingTypes = function() return #list end,
		GetTrackingInfo = function(i) return list[i] end,
	})
	local known = { [1459] = true, [FIND_MINERALS] = true }
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
	local dead = false
	rawset(_G, "UnitIsDeadOrGhost", function(unit)
		if unit == "player" then return dead end
		return realDead(unit)
	end)
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			drive(scenario, ns)
			ns.db.profile.ownBuffs.pick.tracking = "auto"
			ns.Prompt:ExitTest()
			ns.ForgetTrackingList()
			local ctx = { name = ns.UnitFullName("player"), now = GetTime(), whenBuffed = "skip" }
			local family = ns.FindOwnFamily("tracking")
			if not family then
				fail(scenario, "with Find Minerals known and on the minimap list, Tracking is not one of your own buffs")
				return
			end
			local function setDead(on) dead = on end
			local function setOn(on) list[1].active = on; ns.ForgetTrackingList() end
			body(ns, ctx, family, setDead, setOn)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
		if not ok then fail(scenario, "errored: " .. tostring(err)) end
	end
	rawset(_G, "IsSpellKnown", realKnown)
	rawset(_G, "IsPlayerSpell", realPlayer)
	rawset(_G, "UnitIsDeadOrGhost", realDead)
	rawset(_G, "C_Minimap", nil)
	Mock.reset()
end

local function offered(ns, family, ctx)
	local spell, up = ns.OwnVerdict(family, ctx)
	return spell and spell.key or nil, up
end

-- Remembered as Find Minerals while it is up, then a death and a release.
local function die(ns, ctx, family, setDead)
	ns.ReadOwnFamily(family)
	setDead(true)
	ns.addon:PLAYER_DEAD()
	setDead(false)
	ns.addon:PLAYER_ALIVE()
	ns.ForgetTrackingList()
end

do
	local scenario = "tracking-death: Find Minerals is reminded after a death though the list still says on"
	session(scenario, nil, function(ns, ctx, family, setDead, setOn)
		local spell, up = offered(ns, family, ctx)
		if spell or up ~= true then
			fail(scenario, ("before the death Find Minerals on read up %s, offered %s"):format(tostring(up), tostring(spell)))
		end
		die(ns, ctx, family, setDead)
		spell, up = offered(ns, family, ctx)
		if spell ~= "findminerals" then
			fail(scenario, ("after a death Find Minerals was not offered (up %s, spell %s)"):format(tostring(up), tostring(spell)))
		end
	end)
end

do
	local scenario = "tracking-death: the list changing once you are back up is believed"
	session(scenario, nil, function(ns, ctx, family, setDead, setOn)
		die(ns, ctx, family, setDead)
		-- Switched back on from the minimap: the client says the list changed.
		setOn(true)
		ns.addon:MINIMAP_UPDATE_TRACKING()
		local spell, up = offered(ns, family, ctx)
		if spell or up ~= true then
			fail(scenario, ("turned on again after the death, Find Minerals read up %s and offered %s")
				:format(tostring(up), tostring(spell)))
		end
	end)
end

do
	local scenario = "tracking-death: a change of the list while dead is not believed"
	session(scenario, nil, function(ns, ctx, family, setDead, setOn)
		ns.ReadOwnFamily(family)
		setDead(true)
		ns.addon:PLAYER_DEAD()
		ns.addon:MINIMAP_UPDATE_TRACKING()
		setDead(false)
		ns.addon:PLAYER_ALIVE()
		ns.ForgetTrackingList()
		if offered(ns, family, ctx) ~= "findminerals" then
			fail(scenario, "a list change heard while dead made the stale Find Minerals read as on")
		end
	end)
end

do
	local scenario = "tracking-death: Burning Crusade reads the list as it is after a death"
	session(scenario, "tbc", function(ns, ctx, family, setDead, setOn)
		die(ns, ctx, family, setDead)
		local spell, up = offered(ns, family, ctx)
		if spell or up ~= true then
			fail(scenario, ("on Burning Crusade, Find Minerals on after a death read up %s and offered %s")
				:format(tostring(up), tostring(spell)))
		end
	end)
end
