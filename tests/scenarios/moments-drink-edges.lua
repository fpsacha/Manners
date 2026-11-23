-- The drink for the moment, the edges a review found (Prompt/Moments.lua,
-- Prompt/MomentsSense.lua): the clock of your own drink read against an aura that
-- lands after the cast or has another name; one press, one drink, on the hidden
-- route; the cover and the mouse buttons that are not the left one; and the pick
-- recounted when your level or your life changes, not only when the bags do.
--
-- Held to the mock's model of the client (tests/momentskit.lua), not to the client.
--
-- Every name starts with "moments-drink-edges:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")
-- Written for plain values: Forever's hidden ones are asked for by name (Mock.healthSecret, ...).
K.plain = true

local SLOT = 11
local WATER = 3772
local DRINK_SPELL = 1137
local REFRESHMENT = 167152

local function with(name, body, opts)
	K.withMage(H, "moments-drink-edges: " .. name, body, opts)
end
local function name(s) return "moments-drink-edges: " .. s end
local function slot(ns) return ns.Moments:Slot(SLOT) end
local function state(ns) return slot(ns).state end
local function button(ns) return ns.Moments:Button(SLOT) end

local function mana(ns, value)
	Mock.mana = value
	K.event(ns, "UNIT_POWER_UPDATE", "player")
	K.tick(ns, 0.3)
end

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

local function cast(ns, id)
	K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-" .. tostring(id), id)
	K.tick(ns, 0.3)
end

----------------------------------------------------------------------------
-- the clock of your own drink
----------------------------------------------------------------------------

do
	local s = name("the cast comes before the aura: dark across the cast, lit once the aura has come and gone")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 10
		bags(ns, { [WATER] = 1 })
		if state(ns) ~= "lit" then fail(s, "not lit to begin with: " .. state(ns)) return end
		-- The spell succeeded and no aura is on you yet (a plain nil).
		cast(ns, DRINK_SPELL)
		if state(ns) ~= "dark" or slot(ns).why ~= "you are drinking" or button(ns):IsShown() then
			fail(s, "lit across the cast, before the aura landed: " .. state(ns) .. " " .. tostring(slot(ns).why))
		end
		mana(ns, 11)
		if state(ns) ~= "dark" then fail(s, "lit at the next power tick with no aura yet: " .. state(ns)) end
		Mock.drinkAura = true
		mana(ns, 13)
		if state(ns) ~= "dark" then fail(s, "lit while the aura is on you: " .. state(ns)) end
		-- Drunk to full: the aura is gone, the clock ends with it.
		Mock.drinkAura = nil
		mana(ns, 15)
		if state(ns) ~= "lit" then fail(s, "not lit once the aura had come and gone: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		-- A second drink stands on its own: the first one's aura, seen, is not this one's.
		Mock.drinkAura = true
		mana(ns, 16)
		Mock.drinkAura = nil
		cast(ns, DRINK_SPELL)
		if state(ns) ~= "dark" or slot(ns).why ~= "you are drinking" then
			fail(s, "the first drink's aura was taken for the second's: " .. state(ns) .. " " .. tostring(slot(ns).why))
		end
	end)
	s = name("a conjured refreshment has an aura of its own name: dark for the whole meal, lit after it")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 10
		bags(ns, { [WATER] = 1 })
		-- A press, then the cast of the refreshment (not the Drink spell).
		local hit = K.click(ns, SLOT)
		if hit ~= button(ns) then fail(s, "the press did not reach the button") return end
		Mock.playerAuras = { [REFRESHMENT] = true }
		cast(ns, REFRESHMENT)
		if state(ns) ~= "dark" then fail(s, "lit after the press: " .. state(ns)) end
		for i = 1, 4 do
			mana(ns, 10 + i)
			if state(ns) ~= "dark" or slot(ns).why ~= "you are drinking" then
				fail(s, "lit during the meal at tick " .. i .. ": " .. state(ns) .. " " .. tostring(slot(ns).why))
				return
			end
		end
		Mock.playerAuras = nil
		mana(ns, 20 - 1)
		if state(ns) ~= "lit" then fail(s, "not lit once the refreshment was gone: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end)
end

----------------------------------------------------------------------------
-- one press, one drink; the mouse
----------------------------------------------------------------------------

do
	local s = name("hidden mana: two clicks drink once, and a third inside the window does not drink again")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.manaSecret = true
		Mock.mana = 10
		bags(ns, { [WATER] = 3 })
		if state(ns) ~= "game" then fail(s, "not left to the game: " .. state(ns)) return end
		K.click(ns, SLOT)
		Mock.runTimers(0.3)
		if K.click(ns, SLOT) ~= button(ns) or drinks() ~= 1 then fail(s, "the second click did not drink: " .. drinks()) return end
		if not slot(ns).cover:IsShown() or slot(ns).openUntil then
			fail(s, "the cover was not put back after the press")
		end
		Mock.runTimers(0.2)
		local third = K.click(ns, SLOT)
		if third == button(ns) or drinks() ~= 1 then fail(s, "a third click inside the window drank again: " .. drinks()) end
	end)
end

do
	local s = name("the cover is the left button's alone: a right press neither opens it nor stops the camera")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.manaSecret = true
		Mock.mana = 60
		bags(ns, { [WATER] = 3 })
		if state(ns) ~= "game" or not slot(ns).cover:IsShown() then fail(s, "no cover over the game's button: " .. state(ns)) return end
		-- The client passes the other buttons through to the world.
		for _, which in ipairs({ "RightButton", "MiddleButton" }) do
			if Mock.clickAt(button(ns), which) ~= "world" then fail(s, which .. " did not go through to the world") end
		end
		if drinks() ~= 0 then fail(s, "a right or middle click drank") end
		-- And where a client offers no pass-through, the cover still ignores them.
		slot(ns).cover.scripts.OnMouseDown(slot(ns).cover, "RightButton")
		if slot(ns).openUntil then fail(s, "a right press opened the cover") end
		if K.click(ns, SLOT) == button(ns) or drinks() ~= 0 then fail(s, "a left click after a right one drank: " .. drinks()) end
	end)
end

----------------------------------------------------------------------------
-- what the pick reads: your level and your life
----------------------------------------------------------------------------

do
	local s = name("a level-up lights a drink the level did not allow before")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.mana = 10
		Mock.itemMinLevel = { [1179] = 35 }
		bags(ns, { [1179] = 1 })
		if state(ns) ~= "dark" or K.macro(ns, SLOT) ~= nil then fail(s, "armed with a drink above the level: " .. state(ns)) return end
		Mock.playerLevel = 35
		if not K.event(ns, "PLAYER_LEVEL_UP", "player", 35) then fail(s, "PLAYER_LEVEL_UP is not heard with no drink picked") return end
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" or K.macro(ns, SLOT) ~= "/use item:1179" then
			fail(s, "not lit after the level-up: " .. state(ns) .. " " .. tostring(K.macro(ns, SLOT)))
		end
		K.pull(ns)
		K.tick(ns, 0.3)
		if K.event(ns, "PLAYER_LEVEL_UP", "player", 36) then fail(s, "the level event is heard in a fight") end
		K.release(ns)
	end)
end

do
	local function risen(label, event)
		local s = name("dead at the release and alive again lights the drink (" .. label .. ")")
		with(s, function(ns)
			Mock.playerLevel = 34
			Mock.mana = 10
			bags(ns, { [WATER] = 3 })
			if state(ns) ~= "lit" then fail(s, "not lit before the fight: " .. state(ns)) return end
			K.pull(ns)
			K.tick(ns, 0.3)
			-- Dead in the fight: the game calls the water unusable while you are.
			Mock.dead = true
			Mock.itemUnusable = { [WATER] = true }
			K.release(ns)
			K.tick(ns, 0.3)
			if state(ns) ~= "dark" then fail(s, "lit while dead: " .. state(ns)) end
			Mock.dead = false
			Mock.itemUnusable = nil
			if not K.event(ns, event) then fail(s, event .. " is not heard") return end
			K.tick(ns, 0.3)
			if state(ns) ~= "lit" or K.macro(ns, SLOT) ~= "/use item:" .. WATER then
				fail(s, "not lit after rising: " .. state(ns) .. " " .. tostring(slot(ns).why) .. " " .. tostring(K.macro(ns, SLOT)))
			end
		end)
	end
	risen("alive", "PLAYER_ALIVE")
	risen("unghost", "PLAYER_UNGHOST")
end
