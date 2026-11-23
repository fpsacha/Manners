-- Evocation and the mana gem for the moment (Prompt/Moments.lua): lit in a fight
-- while your mana is under Mana below (default 20), the spell ready (Evocation),
-- or a gem of a kind this client names in the bags and off its cooldown (the
-- gem). Where the game hides your mana in a fight, the game itself lights the
-- art through UnitPowerPercent and a curve, and the button takes two quick
-- clicks. The bags are counted at the pull and on the fight's bag events, never
-- per flush.
--
-- Held to the mock's model of the client (tests/momentskit.lua), not to the
-- client: whether Forever hides your own mana, and whether a gem's cooldown is
-- readable in a fight, only a fight can say (STATUS.md).
--
-- Every name starts with "moments-mana:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")

local EVO, GEM = 4, 5
local EVOCATION = 12051

local function with(name, body, opts)
	K.withMage(H, "moments-mana: " .. name, body, opts)
end
local function name(s) return "moments-mana: " .. s end
local function slot(ns, n) return ns.Moments:Slot(n) end
local function state(ns, n) return slot(ns, n).state end

local KNOWN = {}
for _, id in ipairs(K.MAGE_SPELLS) do KNOWN[#KNOWN + 1] = id end
for _, id in ipairs(K.GEM_SPELLS) do KNOWN[#KNOWN + 1] = id end

local function trailHas(ns, text)
	for _, e in ipairs(ns.addon.db.char.trail or {}) do
		if tostring(e.text):find(text, 1, true) then return true end
	end
	return false
end

local function mana(ns, value)
	Mock.mana = value
	K.event(ns, "UNIT_POWER_UPDATE", "player")
	K.tick(ns, 0.3)
end

local function evocations()
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.spell == "Evocation" then n = n + 1 end
	end
	return n
end

local function used()
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.use then n = n + 1 end
	end
	return n
end

-- A gem in the bags, learned and armed.
local function gems(ns, bags)
	Mock.bags = bags
	K.relearn(ns)
end

----------------------------------------------------------------------------
-- Evocation
----------------------------------------------------------------------------

do
	local s = name("Evocation lit under the line with plain mana, dark at it and over it; one click casts")
	with(s, function(ns)
		Mock.mana = 15
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, EVO) ~= "lit" then fail(s, "not lit at 15%: " .. state(ns, EVO) .. " " .. tostring(slot(ns, EVO).why)) end
		if K.shown(ns, EVO) ~= 1 then fail(s, "shown alpha " .. tostring(K.shown(ns, EVO))) end
		mana(ns, 20)
		if state(ns, EVO) ~= "dark" then fail(s, "lit at the line itself") end
		mana(ns, 70)
		if state(ns, EVO) ~= "dark" or K.shown(ns, EVO) ~= 0 then fail(s, "not dark at 70%") end
		mana(ns, 10)
		if state(ns, EVO) ~= "lit" then fail(s, "not lit again") end
		local hit = K.click(ns, EVO)
		if hit ~= ns.Moments:Button(EVO) or evocations() ~= 1 then fail(s, "one click did not cast: " .. evocations()) end
		if K.macro(ns, EVO) ~= "/cast Evocation" then fail(s, "the macro: " .. tostring(K.macro(ns, EVO))) end
	end)
	s = name("Evocation: a click while dark casts nothing; out of a fight it asks nothing and is dark")
	with(s, function(ns)
		Mock.mana = 90
		K.pull(ns)
		K.tick(ns, 0.3)
		local hit = K.click(ns, EVO)
		if hit == ns.Moments:Button(EVO) or evocations() ~= 0 then fail(s, "a dark Evocation was clicked into casting") end
		K.release(ns)
		Mock.mana = 5
		if K.event(ns, "UNIT_POWER_UPDATE", "player") then fail(s, "a mana event reached the frame out of a fight") end
		if state(ns, EVO) ~= "dark" then fail(s, "lit out of a fight") end
	end)
end

do
	local s = name("Evocation hidden mana is handed to the game: shown 1 under the line, 0 over it; two clicks")
	with(s, function(ns)
		Mock.manaSecret = true
		Mock.mana = 10
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, EVO) ~= "game" then fail(s, "not left to the game: " .. state(ns, EVO) .. " " .. tostring(slot(ns, EVO).why)) end
		if K.shown(ns, EVO) ~= 1 then fail(s, "under the line: " .. tostring(K.shown(ns, EVO))) end
		mana(ns, 60)
		if K.shown(ns, EVO) ~= 0 then fail(s, "over the line: " .. tostring(K.shown(ns, EVO))) end
		mana(ns, 10)
		local first = K.click(ns, EVO)
		if first == ns.Moments:Button(EVO) or evocations() ~= 0 then fail(s, "the first click was not swallowed") end
		Mock.runTimers(0.4)
		K.click(ns, EVO)
		if evocations() ~= 1 then fail(s, "the second click did not cast: " .. evocations()) end
		if #Mock.secretOnSecure > 0 or Mock.secureAlphaWrites ~= 0 then fail(s, "a hidden value reached a secure frame") end
	end)
	s = name("Evocation hidden mana and no power-percent call: dark, the key still casts")
	with(s, function(ns)
		Mock.manaSecret = true
		Mock.mana = 5
		ns.Sense.can.power = false
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, EVO) ~= "dark" then fail(s, "lit on a guess: " .. state(ns, EVO)) end
		Mock.bindings = { F = "CLICK MannersMoment4:LeftButton" }
		Mock.pressKey("F")
		if evocations() ~= 1 then fail(s, "the key did not cast") end
	end)
end

do
	local s = name("Evocation used between pulls stays dark next fight")
	with(s, function(ns)
		-- Out of a fight your own cast is heard and Manners keeps its own clock.
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", EVOCATION)
		Mock.cooldown = nil
		Mock.mana = 5
		-- The fight hides the figures: no readable cooldown at the pull.
		Mock.cooldown = { [EVOCATION] = { isActive = true, secretNumbers = true, secretActive = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, EVO) ~= "dark" or slot(ns, EVO).why ~= "cooling down" then
			fail(s, "lit with a cooldown begun between pulls: " .. state(ns, EVO) .. " " .. tostring(slot(ns, EVO).why))
		end
	end)
	s = name("Evocation: a cooldown seen plainly at the refresh keeps it dark at the pull")
	with(s, function(ns)
		Mock.cooldown = { [EVOCATION] = { isActive = true, isOnGCD = false, startTime = Mock.now - 10, duration = 480 } }
		ns.addon:PLAYER_REGEN_DISABLED()
		K.release(ns)
		Mock.mana = 5
		Mock.cooldown = { [EVOCATION] = { isActive = true, secretNumbers = true, secretActive = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, EVO) ~= "dark" then fail(s, "the seeded clock did not keep it dark: " .. state(ns, EVO)) end
	end)
end

do
	local s = name("the slider moves the mana line, in a fight too")
	with(s, function(ns)
		Mock.mana = 30
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, EVO) ~= "dark" then fail(s, "lit at 30% with the line at 20") end
		ns.db.profile.moments.mana = 40
		mana(ns, 30)
		if state(ns, EVO) ~= "lit" then fail(s, "not lit at 30% with the line at 40") end
	end)
end

----------------------------------------------------------------------------
-- the mana gem
----------------------------------------------------------------------------

do
	local s = name("the gem is lit with one in the bags and mana low; dark with none")
	with(s, function(ns)
		gems(ns, { [5514] = 1 })
		if not ns.Moments.Has("managem") then fail(s, "not learned with a gem in the bags") end
		Mock.mana = 10
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, GEM) ~= "lit" then fail(s, "not lit: " .. state(ns, GEM) .. " " .. tostring(slot(ns, GEM).why)) end
		Mock.bags = {}
		K.event(ns, "BAG_UPDATE_DELAYED")
		K.tick(ns, 0.3)
		if state(ns, GEM) ~= "dark" or slot(ns, GEM).why ~= "no gem in your bags" then
			fail(s, "the last gem used did not darken it: " .. state(ns, GEM) .. " " .. tostring(slot(ns, GEM).why))
		end
	end, { known = KNOWN })
	s = name("the gem: mana not low keeps it dark")
	with(s, function(ns)
		gems(ns, { [5514] = 1 })
		Mock.mana = 60
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, GEM) ~= "dark" or slot(ns, GEM).why ~= "your mana is not low" then
			fail(s, "lit with mana high: " .. state(ns, GEM) .. " " .. tostring(slot(ns, GEM).why))
		end
	end, { known = KNOWN })
end

do
	local s = name("the macro lists the gems in the bags best first, and refreshes at the pull")
	with(s, function(ns)
		gems(ns, { [5514] = 2, [8008] = 1 })
		if K.macro(ns, GEM) ~= "/use item:8008\n/use item:5514" then fail(s, "the macro: " .. tostring(K.macro(ns, GEM))) end
		-- A gem picked up since: the pull counts again and arms again.
		Mock.bags = { [5514] = 2, [8008] = 1, [5513] = 1 }
		K.pull(ns)
		if K.macro(ns, GEM) ~= "/use item:8008\n/use item:5513\n/use item:5514" then
			fail(s, "the macro at the pull: " .. tostring(K.macro(ns, GEM)))
		end
	end, { known = KNOWN })
	s = name("the macro lists every gem the mage can conjure when the bags hold none")
	with(s, function(ns)
		Mock.bags = {}
		K.relearn(ns)
		if not ns.Moments.Has("managem") then fail(s, "not learned from the conjure spells") end
		-- The mage knows all four conjures in this list: every kind, best first.
		if K.macro(ns, GEM) ~= "/use item:8008\n/use item:8007\n/use item:5513\n/use item:5514" then
			fail(s, "the macro: " .. tostring(K.macro(ns, GEM)))
		end
	end, { known = KNOWN })
	s = name("no gem and no conjure spell: not learned, no switch")
	with(s, function(ns)
		if ns.Moments.Has("managem") then fail(s, "learned with nothing to use") end
		if ns.Moments:Button(GEM) then fail(s, "a button was made") end
	end)
	s = name("the macro fits")
	with(s, function(ns)
		gems(ns, { [5514] = 1, [5513] = 1, [8007] = 1, [8008] = 1 })
		if #K.macro(ns, GEM) > 255 then fail(s, "over 255 characters") end
	end, { known = KNOWN })
end

do
	local s = name("the gem cooling down keeps it dark; its own use begins a clock the fight cannot hide")
	with(s, function(ns)
		gems(ns, { [5514] = 1 })
		Mock.itemCooldown = { [5514] = { startTime = Mock.now, duration = 120 } }
		Mock.mana = 10
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, GEM) ~= "dark" or slot(ns, GEM).why ~= "the gem is cooling down" then
			fail(s, "lit on cooldown: " .. state(ns, GEM) .. " " .. tostring(slot(ns, GEM).why))
		end
	end, { known = KNOWN })
	s = name("the gem: hidden cooldown figures count as ready until it is used")
	with(s, function(ns)
		gems(ns, { [5514] = 1 })
		Mock.itemCooldown = { [5514] = { startTime = 0, duration = 0, secretNumbers = true } }
		Mock.mana = 10
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, GEM) ~= "lit" then fail(s, "not lit with the cooldown hidden: " .. state(ns, GEM)) end
		-- A press, and the gem's own spell goes out inside the window.
		local hit = K.click(ns, GEM)
		if hit ~= ns.Moments:Button(GEM) then fail(s, "the click did not reach the button") end
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 5405)
		K.tick(ns, 0.3)
		if slot(ns, GEM).tally.out ~= 1 then fail(s, "the use was not counted as gone out") end
		if state(ns, GEM) ~= "dark" then fail(s, "still lit after its own use: " .. state(ns, GEM)) end
	end, { known = KNOWN })
	s = name("the gem: a plain cooldown from the game's own item call beats nothing")
	with(s, function(ns)
		gems(ns, { [5514] = 1 })
		_G.C_Spell.GetItemCooldown = function() return { isActive = true, startTime = Mock.now, duration = 120 } end
		Mock.mana = 10
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, GEM) ~= "dark" then fail(s, "the spell-side item cooldown was not read: " .. state(ns, GEM)) end
	end, { known = KNOWN })
end

do
	local s = name("the gem with hidden mana: handed to the game, two clicks")
	with(s, function(ns)
		gems(ns, { [5514] = 1 })
		Mock.manaSecret = true
		Mock.mana = 10
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns, GEM) ~= "game" or K.shown(ns, GEM) ~= 1 then fail(s, "not left to the game: " .. state(ns, GEM)) end
		K.click(ns, GEM)
		if used() ~= 0 then fail(s, "the first click used a gem") end
		Mock.runTimers(0.4)
		K.click(ns, GEM)
		if used() ~= 1 then fail(s, "the second click did not use it: " .. used()) end
	end, { known = KNOWN })
end

do
	local s = name("a flush counts no gems: the bags are asked at the pull and on a bag event only")
	with(s, function(ns)
		gems(ns, { [5514] = 1, [8008] = 1 })
		Mock.asked["C_Item.GetItemCount"] = 0
		Mock.mana = 10
		K.pull(ns)
		local atPull = Mock.asked["C_Item.GetItemCount"]
		if atPull ~= 4 then fail(s, "the pull asked " .. atPull .. " times, one for each of four kinds") end
		for _ = 1, 5 do
			K.event(ns, "UNIT_POWER_UPDATE", "player")
			K.tick(ns, 0.3)
		end
		if Mock.asked["C_Item.GetItemCount"] ~= atPull then fail(s, "a flush asked the bags") end
		K.event(ns, "BAG_UPDATE_DELAYED")
		if Mock.asked["C_Item.GetItemCount"] ~= atPull + 4 then fail(s, "a bag event asked " .. (Mock.asked["C_Item.GetItemCount"] - atPull)) end
	end, { known = KNOWN, count = { "C_Item.GetItemCount" } })
end

do
	local s = name("the gem: nothing protected is called through a fight, no hidden value reaches a secure frame")
	with(s, function(ns)
		gems(ns, { [5514] = 1 })
		Mock.manaSecret = true
		Mock.mana = 10
		K.pull(ns)
		K.tick(ns, 0.3)
		K.event(ns, "BAG_UPDATE_DELAYED")
		mana(ns, 50)
		mana(ns, 10)
		K.release(ns)
		if #Mock.protectedCalls > 0 then
			fail(s, "a protected call under the lockdown: " .. tostring(Mock.protectedCalls[1].method or Mock.protectedCalls[1]))
		end
	end, { known = KNOWN })
end

