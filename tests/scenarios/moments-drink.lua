-- The drink for the moment (Prompt/Moments.lua, row "drink" in
-- Prompt/MomentsData.lua): out of a fight only, for every class with mana. It
-- lights while your mana is under Mana below (where the game hides the mana, even
-- out of a fight, the game itself lights it through UnitPowerPercent and a curve),
-- you stand still, you are not drinking already and a drink is in your bags. A
-- press is /use item:<best drink>: your conjured water first, the best your level
-- allows, then any other drink. The driver hides it at the pull and the pull
-- clears its macro; out of a fight Lua writes the macro whenever the bags change
-- and shows and hides the button itself.
--
-- Held to the mock's model of the client (tests/momentskit.lua), not to the
-- client: whether UNIT_POWER_UPDATE fires on Forever while the mana is hidden,
-- whether the Drink aura is plain out of a fight, and whether GetItemSpell and
-- IsUsableItem answer plainly are for the game to say (STATUS.md).
--
-- Every name starts with "moments-drink:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")

local SLOT = 11
local WATER = 3772

local function with(name, body, opts)
	K.withMage(H, "moments-drink: " .. name, body, opts)
end
local function name(s) return "moments-drink: " .. s end
local function slot(ns) return ns.Moments:Slot(SLOT) end
local function state(ns) return slot(ns).state end
local function button(ns) return ns.Moments:Button(SLOT) end

local function mana(ns, value)
	Mock.mana = value
	K.event(ns, "UNIT_POWER_UPDATE", "player")
	K.tick(ns, 0.3)
end

-- The bags changed: the bag event, and time for the flush.
local function bags(ns, held)
	Mock.bags = held
	K.event(ns, "BAG_UPDATE_DELAYED")
	K.tick(ns, 0.3)
end

local function drinks()
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.use then n = n + 1 end
	end
	return n
end

-- A cast of your own that no row knows (mounting, shapeshifting): the calm
-- buttons look again.
local function ownCast(ns, id)
	K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", id or 5)
	K.tick(ns, 0.3)
end

local function trailHas(ns, text)
	for _, e in ipairs(ns.addon.db.char.trail or {}) do
		if tostring(e.text):find(text, 1, true) then return true end
	end
	return false
end

----------------------------------------------------------------------------
-- lit, dark, and the click
----------------------------------------------------------------------------

do
	local s = name("lit out of a fight with plain mana under the line and water in the bags; one click drinks")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 15
		bags(ns, { [WATER] = 3 })
		if state(ns) ~= "lit" then fail(s, "not lit at 15%: " .. state(ns) .. " " .. tostring(slot(ns).why)) return end
		if not button(ns):IsShown() then fail(s, "Lua did not show the button out of a fight") end
		if K.shown(ns, SLOT) ~= 1 then fail(s, "shown alpha " .. tostring(K.shown(ns, SLOT))) end
		if K.macro(ns, SLOT) ~= "/use item:" .. WATER then fail(s, "the macro: " .. tostring(K.macro(ns, SLOT))) end
		if slot(ns).cover:IsShown() then fail(s, "the cover stood over a lit drink on the plain route") end
		-- The mana falls and rises through its event.
		mana(ns, 70)
		if state(ns) ~= "dark" or button(ns):IsShown() then fail(s, "still up with mana at 70%: " .. state(ns)) end
		mana(ns, 10)
		if state(ns) ~= "lit" then fail(s, "not lit again when the mana fell: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		local hit = K.click(ns, SLOT)
		if hit ~= button(ns) or drinks() ~= 1 then fail(s, "one click did not drink: " .. drinks()) end
	end)
	s = name("dark at the line and over it, and off the screen: a click there goes to the world")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 20
		bags(ns, { [WATER] = 3 })
		if state(ns) ~= "dark" or slot(ns).why ~= "your mana is not low" then
			fail(s, "lit at the line itself: " .. state(ns) .. " " .. tostring(slot(ns).why))
		end
		if button(ns):IsShown() then fail(s, "shown while dark") end
		if K.click(ns, SLOT) ~= "world" then fail(s, "a click at its place did not go to the world") end
		mana(ns, 70)
		if state(ns) ~= "dark" or K.shown(ns, SLOT) ~= 0 or drinks() ~= 0 then fail(s, "not dark at 70%") end
	end)
end

do
	local s = name("hidden mana is handed to the game out of a fight: shown 1 under the line, 0 over it; two clicks")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.manaSecret = true
		Mock.mana = 10
		bags(ns, { [WATER] = 3 })
		if state(ns) ~= "game" then fail(s, "not left to the game: " .. state(ns) .. " " .. tostring(slot(ns).why)) return end
		if K.shown(ns, SLOT) ~= 1 then fail(s, "under the line: " .. tostring(K.shown(ns, SLOT))) end
		mana(ns, 60)
		if K.shown(ns, SLOT) ~= 0 then fail(s, "over the line: " .. tostring(K.shown(ns, SLOT))) end
		-- Invisible to the player yet clickable: the first click is swallowed and
		-- shows no ring over an empty spot.
		local first = K.click(ns, SLOT)
		if first == button(ns) or drinks() ~= 0 then fail(s, "the first click over the line was not swallowed") end
		if Mock.shownAlpha(ns.Moments:Look(SLOT).inner) ~= 0 then fail(s, "something shows over the line") end
		if ns.Moments:Look(SLOT).ring:GetParent() ~= slot(ns).inner then fail(s, "the ring is not a child of the layer the game paints") end
		Mock.runTimers(2)
		mana(ns, 10)
		local one = K.click(ns, SLOT)
		if one == button(ns) or drinks() ~= 0 then fail(s, "the first click was not swallowed") end
		Mock.runTimers(0.4)
		K.click(ns, SLOT)
		if drinks() ~= 1 then fail(s, "the second click did not drink: " .. drinks()) end
		if #Mock.secretOnSecure > 0 or Mock.secureAlphaWrites ~= 0 then fail(s, "a hidden value reached a secure frame") end
	end)
	s = name("hidden mana and no power-percent call: dark, the key still drinks")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.manaSecret = true
		Mock.mana = 5
		ns.Sense.can.power = false
		bags(ns, { [WATER] = 3 })
		if state(ns) ~= "dark" then fail(s, "lit on a guess: " .. state(ns)) end
		Mock.bindings = { F = "CLICK MannersMoment11:LeftButton" }
		Mock.pressKey("F")
		if drinks() ~= 1 then fail(s, "the key did not drink: " .. drinks()) end
	end)
end

----------------------------------------------------------------------------
-- a fight
----------------------------------------------------------------------------

do
	local s = name("dark in a fight: the driver hides it and the pull clears its macro; the release arms it and lights it again")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 15
		bags(ns, { [WATER] = 3 })
		if state(ns) ~= "lit" then fail(s, "not lit before the pull: " .. state(ns)) return end
		K.pull(ns)
		K.tick(ns, 0.3)
		if button(ns):IsShown() then fail(s, "the driver left the drink up for the fight") end
		if state(ns) ~= "dark" then fail(s, "not dark in the fight: " .. state(ns)) end
		if K.macro(ns, SLOT) ~= nil then fail(s, "the pull left its macro: " .. tostring(K.macro(ns, SLOT))) end
		Mock.bindings = { F = "CLICK MannersMoment11:LeftButton" }
		Mock.pressKey("F")
		if drinks() ~= 0 then fail(s, "a key press drank in a fight") end
		K.release(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" or not button(ns):IsShown() then
			fail(s, "not lit after the release with no power event: " .. state(ns) .. " " .. tostring(slot(ns).why))
		end
		if K.macro(ns, SLOT) ~= "/use item:" .. WATER then fail(s, "not armed again: " .. tostring(K.macro(ns, SLOT))) end
		if #Mock.protectedCalls > 0 then
			fail(s, "a protected call under the lockdown: " .. tostring(Mock.protectedCalls[1].method or Mock.protectedCalls[1]))
		end
	end)
	s = name("nothing protected is called through a fight; the drink is untouched in it")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 15
		bags(ns, { [WATER] = 3 })
		K.pull(ns)
		K.tick(ns, 0.3)
		Mock.bags = { [2136] = 1 }
		if K.event(ns, "BAG_UPDATE_DELAYED") then fail(s, "a bag event reached the frame in a fight") end
		K.event(ns, "PLAYER_STARTED_MOVING")
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 5)
		K.tick(ns, 0.5)
		if state(ns) ~= "dark" or button(ns):IsShown() or K.macro(ns, SLOT) ~= nil then fail(s, "the drink moved in a fight") end
		if K.click(ns, SLOT) ~= "world" then fail(s, "a click at its place in a fight did not go to the world") end
		K.release(ns)
		if #Mock.protectedCalls > 0 then
			fail(s, "a protected call under the lockdown: " .. tostring(Mock.protectedCalls[1].method or Mock.protectedCalls[1]))
		end
	end)
end

----------------------------------------------------------------------------
-- what is in the bags
----------------------------------------------------------------------------

do
	local s = name("no drink in the bags, or only food: dark, and no mana or movement event is heard")
	with(s, function(ns)
		Mock.mana = 5
		bags(ns, { [1113] = 4 })
		if state(ns) ~= "dark" or slot(ns).why ~= "no drink in your bags" then
			fail(s, "lit with only food: " .. state(ns) .. " " .. tostring(slot(ns).why))
		end
		if K.macro(ns, SLOT) ~= nil then fail(s, "food was armed: " .. tostring(K.macro(ns, SLOT))) end
		if K.event(ns, "UNIT_POWER_UPDATE", "player") then fail(s, "a mana event is heard with no drink in the bags") end
		if not K.event(ns, "BAG_UPDATE_DELAYED") then fail(s, "the bags are not heard") end
		if K.event(ns, "PLAYER_STARTED_MOVING") then fail(s, "a movement event is heard with no drink in the bags") end
	end, { class = "PRIEST" })
end

do
	local s = name("the macro picks the best conjured water the level allows, then any other drink")
	with(s, function(ns)
		Mock.playerLevel = 34
		bags(ns, { [2136] = 1, [WATER] = 2, [8077] = 1, [1179] = 1 })
		if K.macro(ns, SLOT) ~= "/use item:3772" then fail(s, "the macro: " .. tostring(K.macro(ns, SLOT))) end
		bags(ns, { [2136] = 1, [8077] = 1, [1179] = 1 })
		if K.macro(ns, SLOT) ~= "/use item:2136" then fail(s, "a water above the level was picked: " .. tostring(K.macro(ns, SLOT))) end
		Mock.playerLevel = 40
		bags(ns, { [2136] = 1, [8077] = 1, [1179] = 1 })
		if K.macro(ns, SLOT) ~= "/use item:8077" then fail(s, "a better level did not pick the better water: " .. tostring(K.macro(ns, SLOT))) end
		Mock.playerLevel = 34
		bags(ns, { [1179] = 1 })
		if K.macro(ns, SLOT) ~= "/use item:1179" then fail(s, "no conjured water: the milk was not picked: " .. tostring(K.macro(ns, SLOT))) end
		Mock.itemMinLevel = { [1179] = 20, [1645] = 30 }
		bags(ns, { [1179] = 1, [1645] = 1 })
		if K.macro(ns, SLOT) ~= "/use item:1645" then fail(s, "the best other drink was not picked: " .. tostring(K.macro(ns, SLOT))) end
		Mock.itemMinLevel = { [1179] = 20, [1645] = 45 }
		bags(ns, { [1179] = 1, [1645] = 1 })
		if K.macro(ns, SLOT) ~= "/use item:1179" then fail(s, "a drink above the level was picked: " .. tostring(K.macro(ns, SLOT))) end
		bags(ns, { [1113] = 1, [1179] = 1, [WATER] = 1 })
		if K.macro(ns, SLOT) ~= "/use item:" .. WATER then fail(s, "conjured water did not come before other drinks: " .. tostring(K.macro(ns, SLOT))) end
		if #K.macro(ns, SLOT) > 255 or K.macro(ns, SLOT):find("[", 1, true) or K.macro(ns, SLOT):find("\n", 1, true) then
			fail(s, "the macro is not one plain line")
		end
	end)
	s = name("a drink the game calls unusable is passed over")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.itemUnusable = { [WATER] = true }
		bags(ns, { [WATER] = 3, [2136] = 1 })
		if K.macro(ns, SLOT) ~= "/use item:2136" then fail(s, "the unusable water was picked: " .. tostring(K.macro(ns, SLOT))) end
		bags(ns, { [WATER] = 3 })
		if K.macro(ns, SLOT) ~= nil or state(ns) ~= "dark" then fail(s, "an unusable water was armed: " .. tostring(K.macro(ns, SLOT))) end
		Mock.itemUnusable = { [1179] = true }
		bags(ns, { [1179] = 1 })
		if K.macro(ns, SLOT) ~= nil then fail(s, "an unusable milk was armed") end
	end)
end

do
	local s = name("the bags changing re-arms: the next drink when the last water is gone, nothing when none is left")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 10
		bags(ns, { [WATER] = 1, [2136] = 1 })
		if K.macro(ns, SLOT) ~= "/use item:3772" or state(ns) ~= "lit" then fail(s, "the first water: " .. tostring(K.macro(ns, SLOT))) end
		bags(ns, { [2136] = 1 })
		if K.macro(ns, SLOT) ~= "/use item:2136" or state(ns) ~= "lit" then fail(s, "the next water was not armed: " .. tostring(K.macro(ns, SLOT))) end
		bags(ns, {})
		if K.macro(ns, SLOT) ~= nil then fail(s, "a macro stayed with no drink: " .. tostring(K.macro(ns, SLOT))) end
		if state(ns) ~= "dark" or button(ns):IsShown() then fail(s, "still up with no drink: " .. state(ns)) end
		if K.event(ns, "UNIT_POWER_UPDATE", "player") then fail(s, "the power event stayed registered with no drink") end
		bags(ns, { [1179] = 1 })
		if K.macro(ns, SLOT) ~= "/use item:1179" or state(ns) ~= "lit" then fail(s, "a drink picked up later did not light it: " .. tostring(K.macro(ns, SLOT))) end
		if not K.event(ns, "UNIT_POWER_UPDATE", "player") then fail(s, "the power event was not registered again") end
	end)
	s = name("the bags are walked on a bag event only, never on a mana event")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 50
		bags(ns, { [WATER] = 1 })
		local before = Mock.asked["C_Container.GetContainerItemID"]
		for i = 1, 10 do mana(ns, 50 - i) end
		K.event(ns, "UNIT_MAXPOWER", "player")
		K.event(ns, "PLAYER_STARTED_MOVING")
		K.event(ns, "PLAYER_STOPPED_MOVING")
		K.tick(ns, 0.5)
		if Mock.asked["C_Container.GetContainerItemID"] ~= before then
			fail(s, "the bags were walked without a bag event: " .. (Mock.asked["C_Container.GetContainerItemID"] - before))
		end
		bags(ns, { [WATER] = 1, [2136] = 1 })
		if Mock.asked["C_Container.GetContainerItemID"] <= before then fail(s, "a bag event did not walk the bags") end
	end, { count = { "C_Container.GetContainerItemID" } })
end

----------------------------------------------------------------------------
-- standing still, and drinking already
----------------------------------------------------------------------------

do
	local s = name("dark while moving, lit again when you stop")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 10
		bags(ns, { [WATER] = 1 })
		K.event(ns, "PLAYER_STARTED_MOVING")
		if state(ns) ~= "dark" or slot(ns).why ~= "you are moving" or button(ns):IsShown() then
			fail(s, "not dark while moving: " .. state(ns) .. " " .. tostring(slot(ns).why))
		end
		K.event(ns, "PLAYER_STOPPED_MOVING")
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit again after stopping: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end)
end

do
	local function dark(s, label, why, set, clear, opts)
		with(s .. " " .. label, function(ns)
			Mock.playerLevel = 34
			Mock.mana = 10
			bags(ns, { [WATER] = 1 })
			if state(ns) ~= "lit" then fail(s, label .. ": not lit to begin with: " .. state(ns)) return end
			set()
			ownCast(ns)
			if state(ns) ~= "dark" or slot(ns).why ~= why or button(ns):IsShown() then
				fail(s, label .. ": not dark: " .. state(ns) .. " " .. tostring(slot(ns).why))
			end
			clear()
			ownCast(ns)
			if state(ns) ~= "lit" then fail(s, label .. ": not lit again: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		end, opts)
	end
	local s = name("dark while mounted, swimming, dead, on a taxi, and a druid in a form")
	dark(s, "mounted", "you are mounted", function() Mock.mounted = true end, function() Mock.mounted = false end)
	dark(s, "swimming", "you are swimming", function() Mock.swimming = true end, function() Mock.swimming = false end)
	dark(s, "dead", "you are dead", function() Mock.dead = true end, function() Mock.dead = false end)
	dark(s, "on a taxi", "you are on a taxi", function() Mock.onTaxi = true end, function() Mock.onTaxi = false end)
	dark(s, "a druid in a form", "you are shapeshifted", function() Mock.shapeshift = 1 end, function() Mock.shapeshift = 0 end,
		{ class = "DRUID" })
	s = name("a form does not stop a mage, whose row has no forms flag")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 10
		Mock.shapeshift = 1
		bags(ns, { [WATER] = 1 })
		if state(ns) ~= "lit" then fail(s, "a mage in 'a form' was stopped: " .. state(ns)) end
	end)
	s = name("dead: the death and the rising are heard")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 10
		bags(ns, { [WATER] = 1 })
		Mock.dead = true
		if not K.event(ns, "PLAYER_DEAD") then fail(s, "PLAYER_DEAD is not heard") end
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" then fail(s, "lit while dead: " .. state(ns)) end
		Mock.dead = false
		if not K.event(ns, "PLAYER_ALIVE") then fail(s, "PLAYER_ALIVE is not heard") end
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit after rising: " .. state(ns)) end
	end)
end

do
	local s = name("dark while drinking: the aura read plainly, lit once it is gone")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 10
		bags(ns, { [WATER] = 1 })
		Mock.drinkAura = true
		mana(ns, 12)
		if state(ns) ~= "dark" or slot(ns).why ~= "you are drinking" or button(ns):IsShown() then
			fail(s, "lit while the Drink aura is on you: " .. state(ns) .. " " .. tostring(slot(ns).why))
		end
		Mock.drinkAura = nil
		mana(ns, 14)
		if state(ns) ~= "lit" then fail(s, "not lit once the aura is gone: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end)
	for _, shape in ipairs({ "secret", "throw" }) do
		s = name("dark while drinking with the aura hidden (" .. shape .. "): the clock of your own drink, ended by moving")
		with(s, function(ns)
			Mock.playerLevel = 34
			Mock.mana = 10
			bags(ns, { [WATER] = 1 })
			Mock.drinkAura = shape
			if state(ns) ~= "lit" then fail(s, "not lit with an unreadable aura and no drink of yours: " .. state(ns)) end
			-- Your own drink spell begins the clock.
			K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 1137)
			K.tick(ns, 0.3)
			if state(ns) ~= "dark" or slot(ns).why ~= "you are drinking" then
				fail(s, "lit after your own drink: " .. state(ns) .. " " .. tostring(slot(ns).why))
			end
			mana(ns, 12)
			Mock.runTimers(10)
			mana(ns, 14)
			if state(ns) ~= "dark" then fail(s, "lit again inside the clock: " .. state(ns)) end
			-- Moving stands you up.
			K.event(ns, "PLAYER_STARTED_MOVING")
			K.event(ns, "PLAYER_STOPPED_MOVING")
			K.tick(ns, 0.3)
			if state(ns) ~= "lit" then fail(s, "moving did not end the clock: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
			-- And the clock runs out by itself.
			K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 1137)
			K.tick(ns, 0.3)
			if state(ns) ~= "dark" then fail(s, "not dark after a second drink") end
			Mock.runTimers(31)
			mana(ns, 14)
			if state(ns) ~= "lit" then fail(s, "not lit after the clock's length: " .. state(ns)) end
		end)
	end
	s = name("a press of the button starts the clock too, whatever spell the drink casts")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 10
		Mock.drinkAura = "secret"
		bags(ns, { [WATER] = 1 })
		K.click(ns, SLOT)
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 4242)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or slot(ns).why ~= "you are drinking" then
			fail(s, "lit after your press: " .. state(ns) .. " " .. tostring(slot(ns).why))
		end
	end)
end

----------------------------------------------------------------------------
-- the switch, the classes, a bar of nothing
----------------------------------------------------------------------------

do
	local s = name("switch off: no macro, no event heard, nothing shown")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 5
		Mock.bags = { [WATER] = 1 }
		if ns.Moments:Button(SLOT) then fail(s, "a button was made with the switch off") end
		if K.event(ns, "BAG_UPDATE_DELAYED") or K.event(ns, "UNIT_POWER_UPDATE", "player") then fail(s, "an event is heard with the switch off") end
	end, { preload = function(ns) ns.defaults.profile.moments.drink = false end })
	s = name("turning the switch off at run time takes it down")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 5
		bags(ns, { [WATER] = 1 })
		if state(ns) ~= "lit" then fail(s, "not lit to begin with") return end
		ns.db.profile.moments.drink = false
		ns.addon:Tick()
		Mock.runTimers(0.5)
		if button(ns):IsShown() or K.macro(ns, SLOT) ~= nil then fail(s, "still up or armed with the switch off") end
		if K.event(ns, "BAG_UPDATE_DELAYED") or K.event(ns, "UNIT_POWER_UPDATE", "player") then fail(s, "an event is still heard") end
	end)
end

do
	local s = name("every class with mana gets the drink and nothing else; a warrior gets none; a retail hunter none")
	for _, class in ipairs({ "PRIEST", "WARLOCK" }) do
		with(s .. " " .. class, function(ns)
			if not ns.Moments.Has("drink") then fail(s, class .. " has no drink") return end
			for n = 1, 10 do
				if ns.Moments:Slot(n) then fail(s, class .. " has a button in slot " .. n) end
			end
			if not slot(ns) or not slot(ns).armed then fail(s, class .. "'s drink is not armed") end
			if ns.Moments.FightWords() ~= nil then fail(s, "the fight summary speaks of a button that is dark in every fight") end
			if class == "PRIEST" then
				Mock.playerLevel = 34
				Mock.mana = 10
				bags(ns, { [WATER] = 1 })
				K.pull(ns)
				K.tick(ns, 0.3)
				if K.event(ns, "UNIT_POWER_UPDATE", "player") or K.event(ns, "BAG_UPDATE_DELAYED") then
					fail(s, "the drink's events are heard in a fight")
				end
				K.release(ns)
				K.tick(ns, 0.3)
				if not K.event(ns, "BAG_UPDATE_DELAYED") then fail(s, "the bags are not heard again after the fight") end
			end
			Mock.playerLevel = 34
			Mock.mana = 10
			bags(ns, { [WATER] = 1 })
			if state(ns) ~= "lit" or K.macro(ns, SLOT) ~= "/use item:" .. WATER then
				fail(s, class .. ": " .. state(ns) .. " " .. tostring(K.macro(ns, SLOT)))
			end
		end, { class = class })
	end
	with(s .. " WARRIOR", function(ns)
		if ns.caps.moments ~= nil or ns.Moments.Has("drink") or slot(ns) then fail(s, "a warrior has a drink") end
	end, { class = "WARRIOR" })
	with(s .. " HUNTER on a client where it has focus", function(ns)
		if ns.Moments.Has("drink") or slot(ns) then fail(s, "a retail hunter has a drink") end
	end, { class = "HUNTER", flavour = "mainline" })
	with(s .. " HUNTER on Forever", function(ns)
		if not ns.Moments.Has("drink") then fail(s, "a Forever hunter has no drink") end
	end, { class = "HUNTER" })
	with(s .. " the data", function(ns)
		local with = { camelot = "PRIEST", vanilla = "PRIEST", tbc = "PRIEST", mists = "PRIEST", mainline = "PRIEST" }
		for flavour, class in pairs(with) do
			local rows = ns.Moments.Sets[flavour][class]
			local found
			for _, row in ipairs(rows or {}) do
				if row.key == "drink" then found = row end
			end
			if not found or found.slot ~= 11 or found.calm ~= true or found.guard ~= "twice" then fail(s, flavour .. ": the priest's drink row is wrong") end
		end
		for _, flavour in ipairs({ "camelot", "tbc", "mists", "mainline" }) do
			for class, rows in pairs(ns.Moments.Sets[flavour]) do
				for _, row in ipairs(rows) do
					if row.key == "drink" and row.forms == true and class ~= "DRUID" and class ~= "SHAMAN" then
						fail(s, flavour .. " " .. class .. " would not drink in a form")
					end
				end
			end
		end
		for _, class in ipairs({ "DRUID", "SHAMAN" }) do
			for _, row in ipairs(ns.Moments.Sets.camelot[class] or {}) do
				if row.key == "drink" and row.forms ~= true then fail(s, class .. " may drink in a form") end
			end
		end
	end)
end

do
	local s = name("a mana bar of zero is no low mana")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana, Mock.manaMax = 0, 0
		bags(ns, { [WATER] = 1 })
		if state(ns) ~= "dark" or slot(ns).why ~= "you have no mana" then
			fail(s, "a bar of zero lit it: " .. state(ns) .. " " .. tostring(slot(ns).why))
		end
	end)
end

----------------------------------------------------------------------------
-- cost
----------------------------------------------------------------------------

do
	local s = name("moving with Slow Fall on does not judge the drink five times a second")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 90
		bags(ns, { [WATER] = 1 })
		K.event(ns, "PLAYER_STARTED_MOVING")
		local before = Mock.asked.UnitIsDeadOrGhost
		K.fallTick(ns, 2)
		if Mock.asked.UnitIsDeadOrGhost - before > 1 then
			fail(s, "the fall watch judged the drink " .. (Mock.asked.UnitIsDeadOrGhost - before) .. " times in two seconds")
		end
		Mock.falling = true
		K.fallTick(ns, 1.6)
		K.tick(ns, 0.3)
		if ns.Moments:Slot(6).state ~= "lit" then fail(s, "Slow Fall itself did not light: " .. ns.Moments:Slot(6).state) end
		Mock.falling = false
		K.fallTick(ns, 0.4)
	end, { count = { "UnitIsDeadOrGhost" } })
	s = name("without Slow Fall the movement events serve the drink and the fall watch is never made")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 10
		bags(ns, { [WATER] = 1 })
		if not K.event(ns, "PLAYER_STARTED_MOVING") then fail(s, "movement is not heard with a drink in the bags") end
		if ns.Moments:Watch() and ns.Moments:Watch():IsShown() then fail(s, "the fall watch runs for the drink") end
		if state(ns) ~= "dark" then fail(s, "lit while moving") end
	end, { preload = function(ns) ns.defaults.profile.moments.slowfall = false end })
end

----------------------------------------------------------------------------
-- words
----------------------------------------------------------------------------

do
	local s = name("the debug line and the self-test name the drink; no drink is a pass, not a warning")
	with(s, function(ns)
		local function printed(text)
			for _, line in ipairs(Mock.printed or {}) do
				if tostring(line):find(text, 1, true) then return line end
			end
			return nil
		end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local none = printed("moment drink:")
		if not none or not none:find("no drink in your bags", 1, true) or not none:find("slot 11", 1, true) then
			fail(s, "the line with no drink: " .. tostring(none))
		end
		local row
		for _, r in ipairs(ns.Moments.SelfRows()) do
			if r.key == "drink" then row = r end
		end
		if not row or row.warn or not row.text:find("no drink in your bags", 1, true) then
			fail(s, "no drink is not a pass: " .. tostring(row and row.text) .. " warn " .. tostring(row and row.warn))
		end
		Mock.playerLevel = 34
		bags(ns, { [WATER] = 1 })
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local held = printed("moment drink:")
		if not held then fail(s, "no line with a drink") return end
		for _, part in ipairs({ "drink item:3772 Drink", "learned yes", "switch on", "armed (/use item:3772)", "slot 11",
			"two clicks where the game alone knows" }) do
			if not held:find(part, 1, true) then fail(s, "the line lacks '" .. part .. "': " .. held) end
		end
		for _, r in ipairs(ns.Moments.SelfRows()) do
			if r.key == "drink" then row = r end
		end
		if row.warn then fail(s, "a made drink is a warning: " .. row.text) end
		Mock.mana = 10
		mana(ns, 9)
		if not trailHas(ns, "moment drink: lit") then fail(s, "the lit drink left no line in the trail") end
		K.pull(ns)
		K.tick(ns, 0.3)
		for _, r in ipairs(ns.Moments.SelfRows()) do
			if r.key == "drink" then row = r end
		end
		if row.warn then fail(s, "a fight's cleared macro is a warning: " .. row.text) end
	end)
end
