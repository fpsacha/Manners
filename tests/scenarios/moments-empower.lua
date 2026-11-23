-- Empowered casts for the moment (Prompt/Moments.lua; retail): a client that has
-- UNIT_SPELLCAST_EMPOWER_START and _STOP has them registered at the pull like
-- the other cast events and treated as a channel's start and stop. A client that
-- lacks them (the default test client) refuses the names at the probe, and the
-- rest of the pull's events are registered all the same.
--
-- Held to the mock's model of the client, not to the client (STATUS.md).
--
-- Every name starts with "moments-empower:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")

local SLOT = 1

local function name(s) return "moments-empower: " .. s end
local function slot(ns) return ns.Moments:Slot(SLOT) end
local function state(ns) return slot(ns).state end

do
	local s = name("an empowered cast start lights Counterspell and its stop darkens it")
	K.withMage(H, s, function(ns)
		if not ns.Sense.accepted.UNIT_SPELLCAST_EMPOWER_START then fail(s, "the probe refused the empower start") end
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" then fail(s, "lit with nobody casting") end
		Mock.targetCast = { channel = true }
		if not K.event(ns, "UNIT_SPELLCAST_EMPOWER_START", "target") then fail(s, "the start event was not registered") end
		if state(ns) ~= "lit" then fail(s, "not lit by the empower start: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		Mock.targetCast = nil
		if not K.event(ns, "UNIT_SPELLCAST_EMPOWER_STOP", "target") then fail(s, "the stop event was not registered") end
		if state(ns) ~= "dark" then fail(s, "not dark the instant the empowered cast stopped: " .. state(ns)) end
		K.release(ns)
		if K.event(ns, "UNIT_SPELLCAST_EMPOWER_START", "target") then fail(s, "still registered after the release") end
		Mock.empowerEvents = nil
	end, { flavour = "mainline", preload = function() Mock.empowerEvents = true end })
end

do
	local s = name("without the events the pull still registers the rest")
	K.withMage(H, s, function(ns)
		if ns.Sense.accepted.UNIT_SPELLCAST_EMPOWER_START then fail(s, "the default client accepted an event it lacks") end
		local lacking = table.concat(ns.Sense.lacking, ",")
		if not lacking:find("UNIT_SPELLCAST_EMPOWER_START", 1, true) then fail(s, "the lack was not recorded: " .. lacking) end
		K.pull(ns)
		K.tick(ns, 0.3)
		Mock.targetCast = {}
		if not K.event(ns, "UNIT_SPELLCAST_START", "target") then fail(s, "the cast start was not registered") end
		if state(ns) ~= "lit" then fail(s, "not lit by an ordinary cast: " .. state(ns)) end
		local found
		for _, line in ipairs(ns.MomentLines()) do
			if line:find("events this client lacks: UNIT_SPELLCAST_EMPOWER", 1, true) then found = true end
		end
		if not found then fail(s, "/manners debug does not list the events the client lacks") end
	end, { flavour = "mainline" })
end
