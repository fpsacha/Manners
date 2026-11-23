-- Blink for the moment (Prompt/Moments.lua): lit in a fight while a loss of
-- control is on you that Blink frees you from (a stun or a root) and the spell is
-- ready. Where the game hides what took control of your character (Forever
-- always, in a fight) it lights for any loss of control: lighting while feared
-- costs nothing, the cast is refused. The game's own per-spell lock flag may keep
-- it dark only after that flag has been seen to tell cases apart.
--
-- Held to the mock's model of the client (C_LossOfControl in its shapes, the
-- control events, tests/momentskit.lua's lock flag), not to the client: which
-- loss of control Forever reports, and whether the flag tells a stun from a fear,
-- only a fight can say (STATUS.md).
--
-- Every name starts with "moments-blink:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")

local SLOT = 3
local BLINK = 1953

local function with(name, body, opts)
	K.withMage(H, "moments-blink: " .. name, body, opts)
end
local function name(s) return "moments-blink: " .. s end
local function slot(ns) return ns.Moments:Slot(SLOT) end
local function state(ns) return slot(ns).state end

local function trailHas(ns, text)
	for _, e in ipairs(ns.addon.db.char.trail or {}) do
		if tostring(e.text):find(text, 1, true) then return true end
	end
	return false
end

local function lose(ns, kind)
	Mock.lossOfControl = { { locType = kind, spellID = 1 } }
	K.event(ns, "PLAYER_CONTROL_LOST")
	K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
	K.tick(ns, 0.3)
end

local function regain(ns)
	Mock.lossOfControl = {}
	K.event(ns, "LOSS_OF_CONTROL_UPDATE")
	K.event(ns, "PLAYER_CONTROL_GAINED")
	K.tick(ns, 0.3)
end

local function blinks()
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.spell == "Blink" then n = n + 1 end
	end
	return n
end

do
	for _, kind in ipairs({ "STUN", "STUN_MECHANIC", "ROOT" }) do
		local s = name("lit for a plain " .. kind)
		with(s, function(ns)
			K.pull(ns)
			K.tick(ns, 0.3)
			if state(ns) ~= "dark" then fail(s, "lit with nothing on you") end
			lose(ns, kind)
			if state(ns) ~= "lit" or K.shown(ns, SLOT) ~= 1 then fail(s, "not lit: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
			regain(ns)
			if state(ns) ~= "dark" then fail(s, "still lit with control back") end
		end)
	end
	for _, kind in ipairs({ "FEAR", "SILENCE" }) do
		local s = name("dark for a plain " .. kind)
		with(s, function(ns)
			K.pull(ns)
			lose(ns, kind)
			if state(ns) ~= "dark" or slot(ns).why ~= "not a stun or a root" then
				fail(s, "not dark: " .. state(ns) .. " " .. tostring(slot(ns).why))
			end
		end)
	end
end

do
	local s = name("a kind the game hides lights it")
	with(s, function(ns)
		K.pull(ns)
		lose(ns, Mock.SECRET)
		if state(ns) ~= "lit" then fail(s, "a hidden kind did not light it: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		if not trailHas(ns, "would not name") then fail(s, "the trail does not say the game would not name it") end
	end)
end

do
	local s = name("the lock flag reading true on the first loss of control of the session still lights it")
	with(s, function(ns)
		Mock.lockFlag = { [BLINK] = true }
		K.pull(ns)
		lose(ns, Mock.SECRET)
		if state(ns) ~= "lit" then fail(s, "an unproven flag vetoed it: " .. state(ns)) end
		if not trailHas(ns, "the game's lock flag for it: true") then fail(s, "the trail does not carry the flag") end
	end)
	s = name("the lock flag seen false once, then true, keeps it dark the second time")
	with(s, function(ns)
		Mock.lockFlag = { [BLINK] = false }
		K.pull(ns)
		lose(ns, Mock.SECRET)
		if state(ns) ~= "lit" then fail(s, "not lit the first time: " .. state(ns)) end
		if not ns.Sense.lockProven then fail(s, "the flag was not proven") end
		regain(ns)
		Mock.lockFlag = { [BLINK] = true }
		lose(ns, Mock.SECRET)
		if state(ns) ~= "dark" then fail(s, "a proven flag did not keep it dark: " .. state(ns)) end
	end)
end

do
	local s = name("stunned a frame before the pull lights it at the pull")
	with(s, function(ns)
		-- The control events are registered out of a fight, so the stun is known.
		lose(ns, "STUN")
		K.pull(ns)
		if state(ns) ~= "lit" then fail(s, "not lit at the pull: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end)
end

do
	local s = name("another unit's loss of control does nothing")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		Mock.lossOfControl = { { locType = "STUN", spellID = 1 } }
		K.event(ns, "LOSS_OF_CONTROL_ADDED", "party1", 1)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" then fail(s, "a party member's stun lit it") end
	end)
end

do
	local s = name("no loss-of-control API: control lost before the pull lights it, control gained ends it")
	with(s, function(ns)
		Mock.lossOfControlShape = "none"
		Mock.charmed = true
		-- The client will not say whether control is back: only the event does.
		local real = _G.HasFullControl
		_G.HasFullControl = function() return nil end
		K.event(ns, "PLAYER_CONTROL_LOST")
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit by the control events: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		Mock.charmed = nil
		K.event(ns, "PLAYER_CONTROL_GAINED")
		K.tick(ns, 0.3)
		_G.HasFullControl = real
		if state(ns) ~= "dark" then fail(s, "still lit with control back") end
	end)
	s = name("a loss of control announced only by the loss-of-control event lights it")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" then fail(s, "lit with control") end
		Mock.lossOfControl = { { locType = "ROOT", spellID = 1 } }
		K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "the loss-of-control event did not light it: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end)
	s = name("dark on cooldown; dark when control is back; the guess ends after ten seconds unreadable")
	with(s, function(ns)
		Mock.cooldown = { [BLINK] = { isActive = true, isOnGCD = false, startTime = Mock.now, duration = 15 } }
		K.pull(ns)
		lose(ns, "STUN")
		if state(ns) ~= "dark" or slot(ns).why ~= "cooling down" then fail(s, "lit on cooldown: " .. state(ns)) end
		-- The game's own word that it is over.
		Mock.cooldown = { [BLINK] = { isActive = false } }
		K.event(ns, "LOSS_OF_CONTROL_UPDATE")
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit with the cooldown over: " .. state(ns)) end
		regain(ns)
		if state(ns) ~= "dark" then fail(s, "lit with control back") end
	end)
	s = name("the guess ends after ten seconds unreadable")
	with(s, function(ns)
		Mock.lossOfControlShape = "none"
		local real = _G.HasFullControl
		_G.HasFullControl = function() return nil end
		K.event(ns, "PLAYER_CONTROL_LOST")
		K.pull(ns)
		K.tick(ns, 0.3)
		local lit = state(ns) == "lit"
		Mock.runTimers(11)
		K.event(ns, "UNIT_HEALTH", "player")
		ns.Moments:Frame().scripts.OnEvent(ns.Moments:Frame(), "PLAYER_TARGET_CHANGED")
		K.tick(ns, 0.3)
		_G.HasFullControl = real
		if not lit then fail(s, "not lit while the guess ran") end
		if state(ns) ~= "dark" then fail(s, "the guess outlived its ten seconds: " .. state(ns)) end
	end)
end

do
	local s = name("its cover is exact: a click while dark casts nothing, a click while lit casts")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		local hit = K.click(ns, SLOT)
		if hit == ns.Moments:Button(SLOT) or blinks() ~= 0 then fail(s, "a click on a dark Blink cast") end
		lose(ns, "STUN")
		hit = K.click(ns, SLOT)
		if hit ~= ns.Moments:Button(SLOT) or blinks() ~= 1 then fail(s, "a click on a lit Blink did not cast: " .. blinks()) end
		if K.macro(ns, SLOT) ~= "/stopcasting\n/cast Blink" then fail(s, "the macro: " .. tostring(K.macro(ns, SLOT))) end
	end)
end
