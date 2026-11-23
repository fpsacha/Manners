-- Counterspell for the moment (Prompt/Moments.lua, Prompt/MomentsSense.lua): a
-- small button that lights while a hostile target within reach is casting or
-- channelling something you can interrupt, and is dark otherwise.
--
-- These hold Manners to the mock's model of the client (tests/momentskit.lua:
-- a target's cast with the client's return positions, the hidden notInterruptible
-- the game paints the art from, the cooldown with isOnGCD filled only inside its
-- event), not to the client: whether Forever hides a cast's flag only a fight can
-- say (STATUS.md).
--
-- Every name starts with "moments-counterspell:".

local dir, H = ...
local fail, load = H.fail, H.load
local K = dofile(dir .. "/tests/momentskit.lua")
-- Written for plain values: Forever's hidden ones are asked for by name (Mock.healthSecret, ...).
K.plain = true

local SLOT = 1

local function with(name, body, opts)
	K.withMage(H, "moments-counterspell: " .. name, body, opts)
end

local function name(s) return "moments-counterspell: " .. s end

local function state(ns) return ns.Moments:Slot(SLOT).state end
local function why(ns) return ns.Moments:Slot(SLOT).why end

local function trailHas(ns, text)
	for _, e in ipairs(ns.addon.db.char.trail or {}) do
		if tostring(e.text):find(text, 1, true) then return true end
	end
	return false
end

-- A pulled fight against a target that is casting (or not).
local function fight(ns, cast)
	if cast then Mock.targetCast = cast end
	K.pull(ns)
	K.tick(ns, 0.3)
end

local function expectLit(scenario, ns, label)
	K.tick(ns, 0.3)
	if state(ns) ~= "lit" then fail(scenario, label .. ": not lit: " .. state(ns) .. " (" .. tostring(why(ns)) .. ")") end
	if K.shown(ns, SLOT) ~= 1 then fail(scenario, label .. ": shown alpha " .. tostring(K.shown(ns, SLOT))) end
end

local function expectDark(scenario, ns, label, reason)
	K.tick(ns, 0.3)
	if state(ns) ~= "dark" then fail(scenario, label .. ": not dark: " .. state(ns)) end
	if K.shown(ns, SLOT) ~= 0 then fail(scenario, label .. ": shown alpha " .. tostring(K.shown(ns, SLOT))) end
	if reason and why(ns) ~= reason then fail(scenario, label .. ": dark for '" .. tostring(why(ns)) .. "', not '" .. reason .. "'") end
end

do
	local s = name("lit for a hostile target casting in range with the spell ready (plain)")
	with(s, function(ns)
		fight(ns)
		expectDark(s, ns, "before the cast", "your target is not casting")
		K.cast(ns)
		expectLit(s, ns, "casting")
		local slot = ns.Moments:Slot(SLOT)
		if slot.cover:IsShown() then fail(s, "the cover is up while lit") end
		if not slot.glow:IsShown() then fail(s, "no glow while lit") end
	end)
end

do
	local s = name("lit for a channel")
	with(s, function(ns)
		fight(ns)
		K.cast(ns, { channel = true })
		expectLit(s, ns, "channelling")
		K.endCast(ns, "UNIT_SPELLCAST_CHANNEL_STOP")
		expectDark(s, ns, "channel over")
	end)
end

do
	local function dark(label, setup, reason, opts)
		local s = name("dark: " .. label)
		with(s, function(ns)
			setup(ns)
			fight(ns, { })
			K.cast(ns)
			expectDark(s, ns, label, reason)
		end, opts)
	end
	dark("no target", function() Mock.noTarget = true end, "no target")
	dark("a friendly target", function() Mock.targetFriendly = true end, "your target is not hostile")
	dark("a dead target", function() Mock.targetDead = true end, "your target is dead")
	dark("out of range", function() Mock.targetOutOfRange = true end, "out of range")
	dark("cooling down", function()
		Mock.cooldown = { [2139] = { isActive = true, isOnGCD = false, startTime = Mock.now, duration = 30 } }
	end, "cooling down")
	dark("not enough mana", function() Mock.usable = { [2139] = { usable = false, noMana = true } } end, "not enough mana")

	local s = name("dark: not casting")
	with(s, function(ns)
		fight(ns)
		expectDark(s, ns, "not casting", "your target is not casting")
	end)

	s = name("dark: out of a fight")
	with(s, function(ns)
		Mock.targetCast = {}
		-- Nothing is registered out of a fight: the event is not delivered.
		if K.event(ns, "UNIT_SPELLCAST_START", "target") then fail(s, "a target cast event reached the frame out of a fight") end
		expectDark(s, ns, "out of a fight")
	end)
end

do
	local s = name("a plain cast that cannot be interrupted stays dark")
	with(s, function(ns)
		fight(ns)
		K.cast(ns, { notInterruptible = true })
		expectDark(s, ns, "shielded", "it cannot be interrupted")
	end)
end

do
	local s = name("a hidden start value is handed to the game: shown alpha 1 for an interruptible cast, 0 for a shielded one")
	with(s, function(ns)
		fight(ns)
		K.cast(ns, { secret = true, notInterruptible = false })
		K.tick(ns, 0.3)
		if state(ns) ~= "game" then fail(s, "not left to the game: " .. state(ns)) end
		if K.shown(ns, SLOT) ~= 1 then fail(s, "interruptible: shown alpha " .. tostring(K.shown(ns, SLOT))) end
		-- Where only the game knows whether it is lit, the click that cast it by mistake costs a cooldown.
		if not ns.Moments:Slot(SLOT).cover:IsShown() then fail(s, "no cover on a game-painted Counterspell: it takes two clicks") end
		K.endCast(ns)
		K.tick(ns, 0.3)
		K.cast(ns, { secret = true, notInterruptible = true })
		K.tick(ns, 0.3)
		if K.shown(ns, SLOT) ~= 0 then fail(s, "shielded: shown alpha " .. tostring(K.shown(ns, SLOT))) end
		if #Mock.secretOnSecure > 0 then fail(s, "a hidden alpha was written to a secure frame") end
	end)
end

do
	local s = name("a hidden nil after a hidden boolean lights it and throws nothing")
	with(s, function(ns)
		fight(ns)
		K.cast(ns, { secret = true, notInterruptible = false })
		K.endCast(ns)
		K.tick(ns, 0.3)
		K.cast(ns, { secret = true, notIntNil = true })
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "a hidden nil did not light it: " .. state(ns)) end
	end)
end

do
	local s = name("a shielded cast ending shows nothing")
	with(s, function(ns)
		fight(ns)
		K.cast(ns, { secret = true, notInterruptible = true })
		K.tick(ns, 0.3)
		K.endCast(ns)
		for i = 1, 6 do
			if K.shown(ns, SLOT) ~= 0 then fail(s, "something showed after the cast ended, step " .. i) end
			K.tick(ns, 0.05)
		end
	end)
end

do
	local s = name("hidden with no boolean call: lit on the cast alone, and the log says so")
	with(s, function(ns)
		ns.Sense.can.bool = false
		fight(ns)
		K.cast(ns, { secret = true, notInterruptible = true })
		expectLit(s, ns, "no boolean call")
		if not trailHas(ns, "passed over") then fail(s, "the trail does not say a value was passed over") end
	end)
end

do
	local s = name("NOT_INTERRUPTIBLE mid-cast turns it dark, INTERRUPTIBLE lights it, both plainly")
	with(s, function(ns)
		fight(ns)
		K.cast(ns)
		expectLit(s, ns, "casting")
		K.event(ns, "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "target")
		expectDark(s, ns, "shield went up", "it cannot be interrupted")
		K.event(ns, "UNIT_SPELLCAST_INTERRUPTIBLE", "target")
		expectLit(s, ns, "shield dropped")
		-- The shield of one cast is not the next one's: a new cast starts clean.
		K.event(ns, "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "target")
		expectDark(s, ns, "shield up again", "it cannot be interrupted")
		-- A start with no stop before it: the new cast replaces the old one.
		K.cast(ns)
		expectLit(s, ns, "a new cast after a shielded one")
	end)
end

do
	for _, event in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED" }) do
		local s = name("dark the instant the cast stops: " .. event)
		with(s, function(ns)
			fight(ns)
			K.cast(ns, { channel = event == "UNIT_SPELLCAST_CHANNEL_STOP" })
			expectLit(s, ns, "casting")
			-- The client still answers the cast for that frame: no read may light it again.
			K.endCast(ns, event, true)
			if state(ns) ~= "dark" then fail(s, "not dark at once: " .. state(ns)) end
			-- A read that follows in the same frame (a failed cast on the target) sees
			-- the stale answer too: the stop event's word stands until a start or a re-read.
			K.event(ns, "UNIT_SPELLCAST_FAILED", "target")
			if state(ns) ~= "dark" then fail(s, "a stale read lit it again: " .. state(ns)) end
			if ns.Moments:Slot(SLOT).face:GetAlpha() > 1 then fail(s, "alpha out of range") end
		end)
	end
end

do
	local s = name("a FAILED with the cast still running leaves it lit")
	with(s, function(ns)
		fight(ns)
		K.cast(ns)
		K.event(ns, "UNIT_SPELLCAST_FAILED", "target")
		-- At the event itself: the flush a cast start now schedules would put it right a tenth of a second on.
		if state(ns) ~= "lit" then fail(s, "dark at once after a failed cast of something else: " .. state(ns)) end
		expectLit(s, ns, "after a failed cast of something else")
	end)
end

do
	local s = name("a new target already casting lights it with no START")
	with(s, function(ns)
		fight(ns)
		Mock.targetCast = {}
		K.event(ns, "PLAYER_TARGET_CHANGED")
		expectLit(s, ns, "new target")
	end)
end

do
	local s = name("a cast under way at the pull lights it with no START")
	with(s, function(ns)
		Mock.targetCast = {}
		K.pull(ns)
		-- The pull's own first look: no event and no time has passed yet.
		if state(ns) ~= "lit" then fail(s, "not lit at the pull before any event or flush: " .. state(ns)) end
		expectLit(s, ns, "at the pull")
	end)
end

do
	local s = name("the press stops your cast first, then casts")
	with(s, function(ns)
		fight(ns)
		K.cast(ns)
		K.tick(ns, 0.3)
		local hit = K.click(ns, SLOT)
		if hit ~= ns.Moments:Button(SLOT) then fail(s, "the click did not reach the button") end
		local log = Mock.castLog
		if not (log[1] and log[1].stop and log[2] and log[2].spell == "Counterspell") then
			fail(s, "the macro did not stop casting, then cast Counterspell: " .. tostring(K.macro(ns, SLOT)))
		end
		if K.macro(ns, SLOT):find("%[") then fail(s, "the macro has a conditional") end
	end)
end

do
	local s = name("pressed lit and nothing went out is said on the trail")
	with(s, function(ns)
		fight(ns)
		K.cast(ns)
		K.tick(ns, 0.3)
		K.click(ns, SLOT)
		Mock.runTimers(1.5)
		if not trailHas(ns, "pressed lit, nothing went out") then fail(s, "no trail line for a press that cast nothing") end
		if ns.Moments:Slot(SLOT).tally.silent ~= 1 then fail(s, "silent not counted") end
	end)
	s = name("pressed lit and the cast went out is told and not called silent")
	with(s, function(ns)
		fight(ns)
		K.cast(ns)
		K.tick(ns, 0.3)
		K.click(ns, SLOT)
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 2139)
		Mock.runTimers(1.5)
		if trailHas(ns, "nothing went out") then fail(s, "a cast that went out was called silent") end
		if ns.Moments:Slot(SLOT).tally.out ~= 1 then fail(s, "out not counted") end
	end)
end

do
	local s = name("a whole hidden cast runs with no guarded error")
	with(s, function(ns)
		fight(ns)
		K.cast(ns, { secret = true, notInterruptible = false })
		K.event(ns, "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "target")
		K.tick(ns, 0.3)
		K.event(ns, "UNIT_SPELLCAST_INTERRUPTIBLE", "target")
		K.endCast(ns)
		K.tick(ns, 0.3)
		K.release(ns)
	end)
end
