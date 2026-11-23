-- Ice Block for the moment (Prompt/Moments.lua): lit in a fight while your health
-- is under the line, the spell is ready and castable, and (where the client has
-- Hypothermia) it is not on you. Where the game hides your health in a fight, the
-- game itself lights the art through a curve and the button takes two quick
-- clicks, so one stray click never casts.
--
-- Held to the mock's model of the client (tests/momentskit.lua), not to the
-- client: whether Forever hides your own health, and whether the cooldown flag is
-- filled, only a fight can say (STATUS.md).
--
-- Every name starts with "moments-iceblock:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")
-- Written for plain values: Forever's hidden ones are asked for by name (Mock.healthSecret, ...).
K.plain = true

local SLOT = 2
local ICE = 11958

local function with(name, body, opts)
	K.withMage(H, "moments-iceblock: " .. name, body, opts)
end
local function name(s) return "moments-iceblock: " .. s end
local function slot(ns) return ns.Moments:Slot(SLOT) end
local function state(ns) return slot(ns).state end

local function trailHas(ns, text)
	for _, e in ipairs(ns.addon.db.char.trail or {}) do
		if tostring(e.text):find(text, 1, true) then return true end
	end
	return false
end

local function health(ns, value)
	Mock.health = value
	K.event(ns, "UNIT_HEALTH", "player")
	K.tick(ns, 0.3)
end

local function casts()
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.spell == "Ice Block" then n = n + 1 end
	end
	return n
end

do
	local s = name("lit under the line with plain health, dark at it and over it; one click casts")
	with(s, function(ns)
		Mock.health = 15
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit at 15%: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		if K.shown(ns, SLOT) ~= 1 then fail(s, "shown alpha " .. tostring(K.shown(ns, SLOT))) end
		health(ns, 20)
		if state(ns) ~= "dark" then fail(s, "lit at the line itself: " .. state(ns)) end
		health(ns, 60)
		if state(ns) ~= "dark" or K.shown(ns, SLOT) ~= 0 then fail(s, "not dark at 60%") end
		health(ns, 10)
		if state(ns) ~= "lit" then fail(s, "not lit again at 10%") end
		local hit = K.click(ns, SLOT)
		if hit ~= ns.Moments:Button(SLOT) then fail(s, "the first click did not reach the button") end
		if casts() ~= 1 then fail(s, "one click did not cast: " .. casts()) end
		if K.macro(ns, SLOT) ~= "/stopcasting\n/cast Ice Block" then fail(s, "the macro: " .. tostring(K.macro(ns, SLOT))) end
	end)
end

do
	local s = name("dark out of a fight, on cooldown, not learned, switch off")
	with(s, function(ns)
		Mock.health = 5
		if state(ns) ~= "dark" then fail(s, "lit out of a fight") end
		if K.event(ns, "UNIT_HEALTH", "player") then fail(s, "a health event reached the frame out of a fight") end
		Mock.cooldown = { [ICE] = { isActive = true, isOnGCD = false, startTime = Mock.now, duration = 300 } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or slot(ns).why ~= "cooling down" then fail(s, "on cooldown: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end)
	s = name("dark: not learned")
	with(s, function(ns)
		if ns.Moments.Has("iceblock") then fail(s, "learned without the spell") end
		if ns.Moments:Button(SLOT) then fail(s, "a button was made") end
	end, { known = { 2139, 1953 } })
	s = name("dark: switch off")
	with(s, function(ns)
		ns.db.profile.moments.iceblock = false
		ns.addon:Tick()
		Mock.health = 5
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or K.shown(ns, SLOT) ~= 0 then fail(s, "lit with its switch off") end
		if ns.Moments:Button(SLOT) and ns.Moments:Button(SLOT):GetAttribute("macrotext1") ~= nil then fail(s, "still armed") end
	end)
end

do
	local s = name("on by default")
	with(s, function(ns)
		if ns.db.profile.moments.iceblock ~= true then fail(s, "the switch is not on") end
		if ns.db.profile.moments.health ~= 20 then fail(s, "the line is not 20") end
	end)
end

do
	local s = name("hidden health is handed to the game: shown alpha 1 under the line, 0 over it")
	with(s, function(ns)
		Mock.healthSecret = true
		Mock.health = 15
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "game" then fail(s, "not left to the game: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		if K.shown(ns, SLOT) ~= 1 then fail(s, "under the line: " .. tostring(K.shown(ns, SLOT))) end
		health(ns, 60)
		if K.shown(ns, SLOT) ~= 0 then fail(s, "over the line: " .. tostring(K.shown(ns, SLOT))) end
		if #Mock.secretOnSecure > 0 then fail(s, "a hidden alpha reached a secure frame") end
		if Mock.secureAlphaWrites ~= 0 then fail(s, "the secure button's alpha was written") end
		if not trailHas(ns, "left to the game") then fail(s, "the trail never says it was left to the game") end
	end)
end

do
	local s = name("hidden health: one click casts nothing and opens it, the second inside a second and a half casts")
	with(s, function(ns)
		Mock.healthSecret = true
		Mock.health = 15
		K.pull(ns)
		K.tick(ns, 0.3)
		local first = K.click(ns, SLOT)
		if first == ns.Moments:Button(SLOT) or first == "world" then fail(s, "the first click was not swallowed by the cover") end
		if casts() ~= 0 then fail(s, "the first click cast") end
		if not slot(ns).ring:IsShown() then fail(s, "no ring after the first click") end
		Mock.runTimers(0.5)
		local second = K.click(ns, SLOT)
		if second ~= ns.Moments:Button(SLOT) then fail(s, "the second click did not reach the button") end
		if casts() ~= 1 then fail(s, "the second click did not cast: " .. casts()) end
		if slot(ns).tally.opened ~= 1 then fail(s, "opened not counted") end
	end)
	s = name("hidden health: two clicks three seconds apart cast nothing")
	with(s, function(ns)
		Mock.healthSecret = true
		Mock.health = 15
		K.pull(ns)
		K.tick(ns, 0.3)
		K.click(ns, SLOT)
		Mock.runTimers(3)
		if not slot(ns).cover:IsShown() then fail(s, "the cover did not come back") end
		if slot(ns).ring:IsShown() then fail(s, "the ring stayed") end
		K.click(ns, SLOT)
		if casts() ~= 0 then fail(s, "two slow clicks cast") end
	end)
end

do
	local s = name("hidden health, then the cooldown starts: nothing flashes")
	with(s, function(ns)
		Mock.healthSecret = true
		Mock.health = 15
		K.pull(ns)
		K.tick(ns, 0.3)
		local painted = slot(ns).inner._alpha
		Mock.cooldown = { [ICE] = { isActive = true, isOnGCD = false, startTime = Mock.now, duration = 300 } }
		K.cooldownEvent(ns)
		-- The event's flush is a tenth of a second away; from the moment it runs
		-- nothing may show, step by step.
		K.tick(ns, 0.12)
		for i = 1, 6 do
			if K.shown(ns, SLOT) ~= 0 then fail(s, "something showed at step " .. i) end
			K.tick(ns, 0.04)
		end
		if state(ns) ~= "dark" then fail(s, "not dark: " .. state(ns)) end
		if slot(ns).inner._alpha ~= painted then fail(s, "inner was written on the way to dark") end
	end)
end

do
	local s = name("hidden health and no curve call: dark, the key still casts")
	with(s, function(ns)
		Mock.healthSecret = true
		Mock.health = 5
		ns.Sense.can.curve = false
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or K.shown(ns, SLOT) ~= 0 then fail(s, "lit with no way to read health: " .. state(ns)) end
		Mock.bindings = { F = "CLICK MannersMoment2:LeftButton" }
		Mock.pressKey("F")
		if casts() ~= 1 then fail(s, "the key did not cast") end
	end)
end

do
	local s = name("the slider moves the line, in a fight too")
	with(s, function(ns)
		Mock.health = 30
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" then fail(s, "lit at 30% with the line at 20") end
		ns.db.profile.moments.health = 40
		health(ns, 30)
		if state(ns) ~= "lit" then fail(s, "not lit at 30% with the line at 40") end
	end)
	s = name("the slider moves the curve's line when health is hidden")
	with(s, function(ns)
		Mock.healthSecret = true
		Mock.health = 30
		K.pull(ns)
		K.tick(ns, 0.3)
		if K.shown(ns, SLOT) ~= 0 then fail(s, "shown at 30% with the line at 20") end
		ns.db.profile.moments.health = 40
		health(ns, 30)
		if K.shown(ns, SLOT) ~= 1 then fail(s, "not shown at 30% with the line at 40") end
	end)
end

do
	local s = name("a second pull already under the line lights it at the pull")
	with(s, function(ns)
		Mock.health = 80
		K.pull(ns)
		K.tick(ns, 0.3)
		K.release(ns)
		Mock.health = 10
		K.pull(ns)
		if state(ns) ~= "lit" then fail(s, "not lit at the second pull: " .. state(ns)) end
	end)
end

do
	local s = name("the global cooldown does not hide it")
	with(s, function(ns)
		Mock.health = 10
		Mock.cooldown = { [ICE] = { isActive = true, isOnGCD = true, secretNumbers = true } }
		K.pull(ns)
		K.cooldownEvent(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "the global cooldown hid it: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end)
	s = name("isOnGCD missing during the global cooldown leaves it lit")
	with(s, function(ns)
		Mock.health = 10
		Mock.cooldown = { [ICE] = { isActive = true, secretNumbers = true } }
		K.pull(ns)
		K.cooldownEvent(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "a missing isOnGCD hid it: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end)
	s = name("isOnGCD read outside the cooldown event is not trusted")
	with(s, function(ns)
		Mock.health = 10
		-- Outside the event the kit's client leaves the flag out, as the game says it may be wrong there.
		Mock.cooldown = { [ICE] = { isActive = true, isOnGCD = false, secretNumbers = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "a flag nobody could trust decided: " .. state(ns)) end
	end)
	s = name("isActive true with the numbers hidden and the flag read inside the cooldown event keeps it dark")
	with(s, function(ns)
		Mock.health = 10
		Mock.cooldown = { [ICE] = { isActive = true, isOnGCD = false, secretNumbers = true } }
		K.pull(ns)
		K.cooldownEvent(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or slot(ns).why ~= "cooling down" then
			fail(s, "a real cooldown with hidden numbers did not keep it dark: " .. state(ns) .. " " .. tostring(slot(ns).why))
		end
		-- Only the global cooldown: the flag says so inside the event, and it stays lit.
		Mock.cooldown = { [ICE] = { isActive = true, isOnGCD = true, secretNumbers = true } }
		K.cooldownEvent(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "the global cooldown hid it: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end)
end

do
	local s = name("a cooldown begun before the pull keeps it dark with every fight-time field hidden")
	with(s, function(ns)
		Mock.health = 10
		-- Your own cast between pulls (the event stays registered out of a fight),
		-- then the fight hides every number.
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", ICE)
		Mock.cooldown = { [ICE] = { secretNumbers = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or slot(ns).why ~= "cooling down" then fail(s, "not kept dark: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end)
	s = name("a cooldown the pull read plainly is kept by the clock when the fight hides it")
	with(s, function(ns)
		Mock.health = 10
		-- Begun between pulls, its numbers plain when the pull reads them ...
		Mock.cooldown = { [ICE] = { isActive = true, isOnGCD = false, startTime = Mock.now, duration = 300 } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" then fail(s, "not dark while the numbers were plain: " .. state(ns)) end
		-- ... and hidden from then on: only the clock the pull seeded knows.
		Mock.cooldown = { [ICE] = { secretNumbers = true } }
		K.event(ns, "UNIT_HEALTH", "player")
		K.tick(ns, 0.5)
		if state(ns) ~= "dark" or slot(ns).why ~= "cooling down" then
			fail(s, "the seeded clock did not hold it dark: " .. state(ns) .. " " .. tostring(slot(ns).why))
		end
	end)
end

do
	local s = name("Hypothermia by a plain aura keeps it dark")
	with(s, function(ns)
		Mock.health = 10
		Mock.playerAuras = { [41425] = true }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or slot(ns).why ~= "Hypothermia" then fail(s, "not dark for Hypothermia: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end, { flavour = "tbc" })
	s = name("Hypothermia by its own clock after your own cast")
	with(s, function(ns)
		Mock.health = 10
		K.pull(ns)
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 45438)
		-- The game's plain word says the cooldown is over; Hypothermia is still on.
		Mock.cooldown = { [45438] = { isActive = false } }
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or slot(ns).why ~= "Hypothermia" then fail(s, "not dark by the clock: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		Mock.runTimers(31)
		K.event(ns, "UNIT_HEALTH", "player")
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "still dark after the lockout: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end, { flavour = "tbc" })
end

do
	local s = name("no arithmetic on a secret alpha")
	with(s, function(ns)
		Mock.healthSecret = true
		Mock.health = 10
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "game" then fail(s, "not game-painted: " .. state(ns)) end
		local fader = ns.Moments:Fader()
		for _ = 1, 5 do fader.scripts.OnUpdate(fader, 0.05) end
	end)
end
