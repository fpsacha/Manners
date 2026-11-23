-- Cold Snap for the moment (Prompt/Moments.lua): lit in a fight while your health
-- is under Health below, Cold Snap is ready, and the spell it brings back (Ice
-- Block) is known and plainly on cooldown, by the game's own figures or by
-- Manners' own clock for it. Its cast clears that clock, so Ice Block's button
-- lights next. Where the game hides whether Ice Block is cooling and Manners has
-- no clock of its own for it, it stays dark.
--
-- Held to the mock's model of the client (tests/momentskit.lua), not to the
-- client (STATUS.md).
--
-- Every name starts with "moments-coldsnap:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")
-- Written for plain values: Forever's hidden ones are asked for by name (Mock.healthSecret, ...).
K.plain = true

local ICE_SLOT, SNAP_SLOT = 2, 7
local ICE, SNAP = 11958, 12472

local function with(name, body, opts)
	K.withMage(H, "moments-coldsnap: " .. name, body, opts)
end
local function name(s) return "moments-coldsnap: " .. s end
local function slot(ns, n) return ns.Moments:Slot(n) end
local function state(ns, n) return slot(ns, n).state end

local function snaps()
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.spell == "Cold Snap" then n = n + 1 end
	end
	return n
end

local function cooling()
	return { isActive = true, isOnGCD = false, startTime = Mock.now, duration = 300 }
end

local function health(ns, value)
	Mock.health = value
	K.event(ns, "UNIT_HEALTH", "player")
	K.tick(ns, 0.3)
end

do
	local s = name("lit only with Ice Block plainly cooling and health under the line")
	with(s, function(ns)
		Mock.health = 10
		Mock.cooldown = { [ICE] = cooling() }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, SNAP_SLOT) ~= "lit" then fail(s, "not lit: " .. state(ns, SNAP_SLOT) .. " " .. tostring(slot(ns, SNAP_SLOT).why)) end
		if K.shown(ns, SNAP_SLOT) ~= 1 then fail(s, "shown alpha " .. tostring(K.shown(ns, SNAP_SLOT))) end
		if K.macro(ns, SNAP_SLOT) ~= "/stopcasting\n/cast Cold Snap" then fail(s, "the macro: " .. tostring(K.macro(ns, SNAP_SLOT))) end
		health(ns, 60)
		if state(ns, SNAP_SLOT) ~= "dark" then fail(s, "lit with health high") end
		health(ns, 10)
		if state(ns, SNAP_SLOT) ~= "lit" then fail(s, "not lit again") end
	end)
	s = name("dark with Ice Block ready")
	with(s, function(ns)
		Mock.health = 10
		Mock.cooldown = { [ICE] = { isActive = false } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, SNAP_SLOT) ~= "dark" then fail(s, "lit with Ice Block ready: " .. state(ns, SNAP_SLOT)) end
		if state(ns, ICE_SLOT) ~= "lit" then fail(s, "Ice Block itself is not lit: " .. state(ns, ICE_SLOT)) end
	end)
	s = name("dark with Ice Block not known")
	with(s, function(ns)
		if not ns.Moments.Has("coldsnap") then fail(s, "Cold Snap not learned") end
		Mock.health = 10
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, SNAP_SLOT) ~= "dark" or slot(ns, SNAP_SLOT).why ~= "the spell it brings back is not known" then
			fail(s, "lit without Ice Block: " .. state(ns, SNAP_SLOT) .. " " .. tostring(slot(ns, SNAP_SLOT).why))
		end
	end, { known = { 12472, 2139 } })
	s = name("dark with Ice Block's cooldown unreadable and no clock of ours")
	with(s, function(ns)
		Mock.health = 10
		Mock.cooldown = { [ICE] = { isActive = true, secretNumbers = true, secretActive = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, SNAP_SLOT) ~= "dark" then fail(s, "lit on a guess: " .. state(ns, SNAP_SLOT)) end
	end)
end

do
	local s = name("the flag read in the cooldown event, with the numbers hidden, lights it")
	with(s, function(ns)
		Mock.health = 10
		Mock.cooldown = { [ICE] = { isActive = true, isOnGCD = false, secretNumbers = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, SNAP_SLOT) ~= "dark" then fail(s, "lit before the flag was read: " .. state(ns, SNAP_SLOT)) end
		K.cooldownEvent(ns)
		K.tick(ns, 0.3)
		if state(ns, SNAP_SLOT) ~= "lit" then fail(s, "not lit once the flag said not the global cooldown: " .. state(ns, SNAP_SLOT)) end
	end)
end

do
	local s = name("the flag read in the cooldown event lights it with Ice Block's own switch off too")
	with(s, function(ns)
		ns.db.profile.moments.iceblock = false
		ns.addon:Tick()
		Mock.health = 10
		Mock.cooldown = { [ICE] = { isActive = true, isOnGCD = false, secretNumbers = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, SNAP_SLOT) ~= "dark" then fail(s, "lit before the flag was read: " .. state(ns, SNAP_SLOT)) end
		K.cooldownEvent(ns)
		K.tick(ns, 0.3)
		if state(ns, SNAP_SLOT) ~= "lit" then fail(s, "not lit by the kept clock's flag: " .. state(ns, SNAP_SLOT)) end
	end)
end

do
	local s = name("it works with Ice Block's own switch off")
	with(s, function(ns)
		ns.db.profile.moments.iceblock = false
		ns.addon:Tick()
		if not ns.Moments:Shadow("iceblock") then fail(s, "no clock kept for the spell it brings back") end
		Mock.health = 10
		Mock.cooldown = { [ICE] = cooling() }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, SNAP_SLOT) ~= "lit" then fail(s, "not lit: " .. state(ns, SNAP_SLOT) .. " " .. tostring(slot(ns, SNAP_SLOT).why)) end
		if ns.Moments:Button(ICE_SLOT) and ns.Moments:Button(ICE_SLOT):GetAttribute("macrotext1") then fail(s, "Ice Block was armed") end
	end)
end

do
	local s = name("your Cold Snap clears Ice Block's own clock and its button lights")
	with(s, function(ns)
		Mock.health = 10
		-- Ice Block was cast out of a fight; the fight hides every figure.
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", ICE)
		Mock.cooldown = { [ICE] = { isActive = true, secretNumbers = true, secretActive = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, ICE_SLOT) ~= "dark" or slot(ns, ICE_SLOT).why ~= "cooling down" then
			fail(s, "Ice Block lit on its own clock: " .. state(ns, ICE_SLOT) .. " " .. tostring(slot(ns, ICE_SLOT).why))
		end
		if state(ns, SNAP_SLOT) ~= "lit" then fail(s, "Cold Snap not lit by the clock: " .. state(ns, SNAP_SLOT) .. " " .. tostring(slot(ns, SNAP_SLOT).why)) end
		local hit = K.click(ns, SNAP_SLOT)
		if hit ~= ns.Moments:Button(SNAP_SLOT) or snaps() ~= 1 then fail(s, "the click did not cast Cold Snap: " .. snaps()) end
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", SNAP)
		Mock.cooldown = nil
		K.tick(ns, 0.3)
		if state(ns, ICE_SLOT) ~= "lit" then fail(s, "Ice Block's button did not light: " .. state(ns, ICE_SLOT) .. " " .. tostring(slot(ns, ICE_SLOT).why)) end
		if state(ns, SNAP_SLOT) ~= "dark" then fail(s, "Cold Snap stayed lit after its own cast: " .. state(ns, SNAP_SLOT)) end
	end)
	s = name("with Ice Block's switch off the cast still clears the clock kept for it")
	with(s, function(ns)
		ns.db.profile.moments.iceblock = false
		ns.addon:Tick()
		Mock.health = 10
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", ICE)
		local shadow = ns.Moments:Shadow("iceblock")
		if not (shadow and shadow.readyAt) then fail(s, "its own cast began no clock") return end
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", SNAP)
		if shadow.readyAt ~= nil then fail(s, "Cold Snap did not clear the clock") end
	end)
end

do
	local s = name("hidden health: handed to the game, two clicks")
	with(s, function(ns)
		Mock.healthSecret = true
		Mock.health = 10
		Mock.cooldown = { [ICE] = cooling() }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, SNAP_SLOT) ~= "game" or K.shown(ns, SNAP_SLOT) ~= 1 then fail(s, "not left to the game: " .. state(ns, SNAP_SLOT)) end
		K.click(ns, SNAP_SLOT)
		if snaps() ~= 0 then fail(s, "the first click cast") end
		Mock.runTimers(0.4)
		K.click(ns, SNAP_SLOT)
		if snaps() ~= 1 then fail(s, "the second click did not cast: " .. snaps()) end
		health(ns, 80)
		if K.shown(ns, SNAP_SLOT) ~= 0 then fail(s, "shown with health high") end
	end)
end

do
	local s = name("Cold Snap's own cooldown keeps it dark; the game's word that the partner is ready beats our clock")
	with(s, function(ns)
		Mock.health = 10
		Mock.cooldown = { [ICE] = cooling(), [SNAP] = cooling() }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, SNAP_SLOT) ~= "dark" or slot(ns, SNAP_SLOT).why ~= "cooling down" then
			fail(s, "lit on its own cooldown: " .. state(ns, SNAP_SLOT) .. " " .. tostring(slot(ns, SNAP_SLOT).why))
		end
		-- Ice Block's clock runs, but the game now says plainly it is ready.
		Mock.cooldown = { [ICE] = { isActive = false } }
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", ICE)
		K.tick(ns, 0.3)
		if state(ns, ICE_SLOT) ~= "lit" then fail(s, "the game's ready did not beat the clock: " .. state(ns, ICE_SLOT) .. " " .. tostring(slot(ns, ICE_SLOT).why)) end
	end)
end
