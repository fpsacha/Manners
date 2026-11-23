-- Slow Fall for the moment (Prompt/Moments.lua): lit in a fight or out of one
-- once you have been falling for a second, while the game calls the spell
-- castable (it says no without a Light Feather where the client asks for one) and
-- it is not already on you. No event says you fall on any client, so a watch asks
-- IsFalling five times a second, only while you move, fight or fall. Out of a
-- fight the button is on the screen only while lit, and Lua shows and hides it;
-- in a fight the driver showed it at the pull and Lua paints only.
--
-- Held to the mock's model of the client (tests/momentskit.lua), not to the
-- client: whether IsFalling is readable in a fight only a fight can say
-- (STATUS.md).
--
-- Every name starts with "moments-slowfall:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")
-- Written for plain values: Forever's hidden ones are asked for by name (Mock.healthSecret, ...).
K.plain = true

local SLOT = 6
local SLOW = 130

local function with(name, body, opts)
	K.withMage(H, "moments-slowfall: " .. name, body, opts)
end
local function name(s) return "moments-slowfall: " .. s end
local function slot(ns) return ns.Moments:Slot(SLOT) end
local function state(ns) return slot(ns).state end
local function button(ns) return ns.Moments:Button(SLOT) end

local function falls()
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.spell == "Slow Fall" then n = n + 1 end
	end
	return n
end

-- Jump: the movement event and the first reads.
local function jump(ns)
	K.event(ns, "PLAYER_STARTED_MOVING")
	Mock.falling = true
end

local function land(ns)
	Mock.falling = false
	K.fallTick(ns, 0.4)
	K.tick(ns, 0.3)
end

do
	local s = name("half a second is no fall; a second lights it, out of a fight")
	with(s, function(ns)
		jump(ns)
		K.fallTick(ns, 0.6)
		if state(ns) ~= "dark" or button(ns):IsShown() then fail(s, "lit after half a second: " .. state(ns)) end
		K.fallTick(ns, 0.8)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit after a second and more: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		if not button(ns):IsShown() then fail(s, "out of a fight Lua did not show the button") end
		if K.shown(ns, SLOT) ~= 1 then fail(s, "shown alpha " .. tostring(K.shown(ns, SLOT))) end
		land(ns)
		if state(ns) ~= "dark" or button(ns):IsShown() then fail(s, "still up after landing: " .. state(ns)) end
	end)
	s = name("a jump shorter than a second never lights it")
	with(s, function(ns)
		jump(ns)
		K.fallTick(ns, 0.8)
		if state(ns) ~= "dark" then fail(s, "lit after less than a second of fall: " .. state(ns)) end
		Mock.falling = false
		K.fallTick(ns, 0.4)
		K.event(ns, "PLAYER_STOPPED_MOVING")
		if state(ns) ~= "dark" or button(ns):IsShown() then fail(s, "a short jump lit it") end
	end)
end

do
	local s = name("in a fight a second lights it with nothing protected called, and landing darkens it")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		if not button(ns):IsShown() then fail(s, "the driver did not show the keep button for the fight") end
		if state(ns) ~= "dark" or not slot(ns).cover:IsShown() then fail(s, "not dark under its cover at the pull") end
		Mock.falling = true
		K.fallTick(ns, 1.6)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" or K.shown(ns, SLOT) ~= 1 then fail(s, "not lit in a fight: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		if slot(ns).cover:IsShown() then fail(s, "the cover stayed up over a lit button") end
		local hit = K.click(ns, SLOT)
		if hit ~= button(ns) or falls() ~= 1 then fail(s, "a click on it did not cast: " .. falls()) end
		Mock.falling = false
		land(ns)
		K.release(ns)
		if #Mock.protectedCalls > 0 then
			fail(s, "a protected call under the lockdown: " .. tostring(Mock.protectedCalls[1].method or Mock.protectedCalls[1]))
		end
	end)
	s = name("in a fight a click on it while it is dark casts nothing")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		local hit = K.click(ns, SLOT)
		if hit == button(ns) or falls() ~= 0 then fail(s, "a dark Slow Fall was clicked into casting") end
	end)
end

do
	local s = name("after a fight with no fall the button is not shown and a click at its place goes to the world")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		K.release(ns)
		if button(ns):IsShown() then fail(s, "the keep button was left up after a fight with no fall") end
		if K.click(ns, SLOT) ~= "world" then fail(s, "a click at its place did not go to the world") end
	end)
end

do
	local s = name("a fight ending mid-fall leaves it up until the landing")
	with(s, function(ns)
		K.pull(ns)
		Mock.falling = true
		K.fallTick(ns, 1.6)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit in the fight: " .. state(ns)) end
		K.release(ns)
		if not button(ns):IsShown() or state(ns) ~= "lit" then fail(s, "taken down mid-fall: shown " .. tostring(button(ns):IsShown()) .. " " .. state(ns)) end
		Mock.falling = false
		K.fallTick(ns, 0.4)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or button(ns):IsShown() then fail(s, "still up after landing") end
	end)
end

do
	local s = name("no feather: the game says it cannot be cast, so it stays dark; castable with none lit")
	with(s, function(ns)
		Mock.usable = { [SLOW] = { usable = false, noMana = false } }
		jump(ns)
		K.fallTick(ns, 1.6)
		if state(ns) ~= "dark" or slot(ns).why ~= "the game says it cannot be cast now" then
			fail(s, "lit without a feather: " .. state(ns) .. " " .. tostring(slot(ns).why))
		end
		Mock.usable = { [SLOW] = { usable = true } }
		K.fallTick(ns, 0.4)
		if state(ns) ~= "lit" then fail(s, "not lit once castable: " .. state(ns)) end
	end)
end

do
	local s = name("a hidden IsFalling stays dark, and the key still casts")
	with(s, function(ns)
		Mock.fallingSecret = true
		jump(ns)
		K.fallTick(ns, 1.6)
		if state(ns) ~= "dark" or button(ns):IsShown() then fail(s, "lit on a hidden answer: " .. state(ns)) end
		if not tostring(slot(ns).why):find("would not say", 1, true) then fail(s, "the reason does not say the game would not tell: " .. tostring(slot(ns).why)) end
		Mock.bindings = { F = "CLICK MannersMoment6:LeftButton" }
		Mock.pressKey("F")
		if falls() ~= 1 then fail(s, "the key did not cast") end
	end)
end

do
	local s = name("your own cast keeps it dark for its length")
	with(s, function(ns)
		jump(ns)
		K.fallTick(ns, 1.6)
		if state(ns) ~= "lit" then fail(s, "not lit: " .. state(ns)) end
		K.click(ns, SLOT)
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", SLOW)
		if state(ns) ~= "dark" or slot(ns).why ~= "it is on you" then fail(s, "still lit after the cast: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		K.fallTick(ns, 10)
		if state(ns) ~= "dark" then fail(s, "lit again inside its length") end
		Mock.runTimers(30)
		K.fallTick(ns, 0.4)
		if state(ns) ~= "lit" then fail(s, "not lit again after its length: " .. state(ns)) end
	end)
end

do
	local s = name("the watch is hidden standing still out of a fight and asks the client nothing")
	with(s, function(ns)
		local watch = ns.Moments:Watch()
		if not watch then fail(s, "no watch made") return end
		if watch:IsShown() then fail(s, "the watch runs standing still") end
		Mock.asked.IsFalling = 0
		K.fallTick(ns, 5)
		if Mock.asked.IsFalling ~= 0 then fail(s, "IsFalling asked while standing still: " .. Mock.asked.IsFalling) end
		K.event(ns, "PLAYER_STARTED_MOVING")
		if not watch:IsShown() then fail(s, "moving did not start the watch") end
		K.fallTick(ns, 1)
		if Mock.asked.IsFalling < 4 then fail(s, "five reads a second were not made: " .. Mock.asked.IsFalling) end
		K.event(ns, "PLAYER_STOPPED_MOVING")
		K.fallTick(ns, 4)
		if watch:IsShown() then fail(s, "the watch did not go quiet after the hold") end
	end, { count = { "IsFalling" } })
	s = name("with the switch off nothing is registered, no watch made")
	with(s, function(ns)
		ns.db.profile.moments.slowfall = false
		ns.addon:Tick()
		if K.event(ns, "PLAYER_STARTED_MOVING") then fail(s, "a movement event reached the frame") end
	end)
end

do
	local s = name("Forever's macro targets you by name and hands the target back, with no [@player]")
	with(s, function(ns)
		local macro = K.macro(ns, SLOT)
		if not macro or macro:find("@player", 1, true) then fail(s, "the macro has a conditional: " .. tostring(macro)) end
		local who = macro and macro:match("^/target (.+)\n/cast Slow Fall\n/targetlasttarget$")
		if not who then fail(s, "not the self-cast shape: " .. tostring(macro)) end
		if #macro > 255 then fail(s, "over 255 characters") end
	end)
	s = name("elsewhere it is /cast [@player]")
	with(s, function(ns)
		if K.macro(ns, SLOT) ~= "/cast [@player] Slow Fall" then fail(s, "the macro: " .. tostring(K.macro(ns, SLOT))) end
	end, { flavour = "tbc" })
	s = name("the debug line names the shape")
	with(s, function(ns)
		local found
		for _, line in ipairs(ns.MomentLines()) do
			if line:find("moment slowfall:", 1, true) and line:find("target yourself by name", 1, true) then found = true end
		end
		if not found then fail(s, "the shape is not in the debug lines") end
	end)
end

do
	local s = name("a fall that began out of a fight and goes on into one stays lit through the pull")
	with(s, function(ns)
		jump(ns)
		K.fallTick(ns, 1.6)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit before the pull") end
		K.pull(ns)
		K.fallTick(ns, 0.4)
		if state(ns) ~= "lit" then fail(s, "not lit after the pull: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end)
end
