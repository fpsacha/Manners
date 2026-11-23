-- Spellsteal for the moment (Prompt/Moments.lua; Burning Crusade, Mists and
-- retail only, no such spell on Forever or Classic Era): lit in a fight while a
-- hostile target in range carries a buff the game marks stealable and the spell
-- is ready and affordable. Plain where the auras are readable. Where they are
-- withheld, the plain list of buff ids is walked and each record's hidden flag
-- is handed to the game, ORed; records hidden whole stay dark.
--
-- Held to the mock's model of the client (tests/momentskit.lua), not to the
-- client (STATUS.md).
--
-- Every name starts with "moments-spellsteal:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")
-- Written for plain values: Forever's hidden ones are asked for by name (Mock.healthSecret, ...).
K.plain = true

local SLOT = 8
local STEAL = 30449

local function with(name, body, opts)
	K.withMage(H, "moments-spellsteal: " .. name, body, opts)
end
local function name(s) return "moments-spellsteal: " .. s end
local function slot(ns) return ns.Moments:Slot(SLOT) end
local function state(ns) return slot(ns).state end
local TBC = { flavour = "tbc" }

local function steals()
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.spell == "Spellsteal" then n = n + 1 end
	end
	return n
end

local function look(ns, buffs)
	Mock.targetBuffs = buffs
	K.event(ns, "UNIT_AURA", "target")
	K.tick(ns, 0.3)
end

do
	local s = name("plain: a stealable buff lights it, none does not, a new one lights it mid-fight")
	with(s, function(ns)
		Mock.targetBuffs = { { steal = false } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or slot(ns).why ~= "nothing to steal" then fail(s, "lit with nothing to steal: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		look(ns, { { steal = false }, { steal = true } })
		if state(ns) ~= "lit" or K.shown(ns, SLOT) ~= 1 then fail(s, "not lit with a stealable buff: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		local hit = K.click(ns, SLOT)
		if hit ~= ns.Moments:Button(SLOT) or steals() ~= 1 then fail(s, "one click did not cast: " .. steals()) end
		if K.macro(ns, SLOT) ~= "/stopcasting\n/cast Spellsteal" then fail(s, "the macro: " .. tostring(K.macro(ns, SLOT))) end
		look(ns, { { steal = false } })
		if state(ns) ~= "dark" then fail(s, "still lit with the buff gone") end
	end, TBC)
	s = name("plain: no buffs at all is dark and says so")
	with(s, function(ns)
		Mock.targetBuffs = {}
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or slot(ns).why ~= "your target has no buffs" then fail(s, "not dark: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end, TBC)
end

do
	local s = name("dark with no target, a friendly target, out of range, cooling down")
	with(s, function(ns)
		Mock.targetBuffs = { { steal = true } }
		Mock.noTarget = true
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" then fail(s, "lit with no target") end
		Mock.noTarget = nil
		Mock.targetFriendly = true
		K.event(ns, "PLAYER_TARGET_CHANGED")
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" then fail(s, "lit on a friend") end
		Mock.targetFriendly = nil
		Mock.targetOutOfRange = true
		K.event(ns, "PLAYER_TARGET_CHANGED")
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or slot(ns).why ~= "out of range" then fail(s, "lit out of range: " .. state(ns)) end
		Mock.targetOutOfRange = nil
		Mock.cooldown = { [STEAL] = { isActive = true, isOnGCD = false, startTime = Mock.now, duration = 10 } }
		K.event(ns, "PLAYER_TARGET_CHANGED")
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or slot(ns).why ~= "cooling down" then fail(s, "lit on cooldown: " .. state(ns)) end
	end, TBC)
end

do
	local s = name("withheld: the hidden flags are ORed by the game")
	with(s, function(ns)
		Mock.buffsWithheld = true
		Mock.targetBuffs = { { steal = false }, { steal = false } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "game" then fail(s, "not left to the game: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		if K.shown(ns, SLOT) ~= 0 then fail(s, "shown with nothing to steal: " .. tostring(K.shown(ns, SLOT))) end
		look(ns, { { steal = false }, { steal = true } })
		if K.shown(ns, SLOT) ~= 1 then fail(s, "not shown with a stealable buff: " .. tostring(K.shown(ns, SLOT))) end
		if #Mock.secretOnSecure > 0 or Mock.secureAlphaWrites ~= 0 then fail(s, "a hidden value reached a secure frame") end
		-- Two clicks where only the game knows: the first is swallowed, a later second reaches the button.
		local hit = K.click(ns, SLOT)
		if hit == ns.Moments:Button(SLOT) then fail(s, "one click reached a game-painted Spellsteal") end
		Mock.runTimers(0.5)
		hit = K.click(ns, SLOT)
		if hit ~= ns.Moments:Button(SLOT) then fail(s, "the second click did not reach a game-painted Spellsteal") end
	end, TBC)
	s = name("withheld: a hidden nil flag is skipped, and a list of nothing else stays dark")
	with(s, function(ns)
		Mock.buffsWithheld = true
		Mock.targetBuffs = { { steal = "nil" }, { steal = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "game" or K.shown(ns, SLOT) ~= 1 then fail(s, "the nil flag broke the OR: " .. state(ns)) end
		look(ns, { { steal = "nil" } })
		if state(ns) ~= "dark" or K.shown(ns, SLOT) ~= 0 then fail(s, "lit on a flag nobody could read: " .. state(ns)) end
	end, TBC)
	s = name("withheld whole: records the game hides stay dark")
	with(s, function(ns)
		Mock.buffsHidden = true
		Mock.targetBuffs = { { steal = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or K.shown(ns, SLOT) ~= 0 then fail(s, "lit with the records hidden: " .. state(ns)) end
	end, TBC)
	s = name("withheld with no evaluate call: dark")
	with(s, function(ns)
		Mock.buffsWithheld = true
		Mock.targetBuffs = { { steal = true } }
		ns.Sense.can.eval = false
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" then fail(s, "lit with no way to evaluate: " .. state(ns)) end
	end, TBC)
end

do
	local s = name("the index read hidden but the id list and the records plain: read through the list")
	with(s, function(ns)
		Mock.indexHidden = true
		Mock.targetBuffs = { { steal = false }, { steal = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit through the list: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
		look(ns, { { steal = false } })
		if state(ns) ~= "dark" or slot(ns).why ~= "nothing to steal" then fail(s, "not dark with nothing to steal: " .. state(ns) .. " " .. tostring(slot(ns).why)) end
	end, TBC)
end

do
	local s = name("retail has it too")
	with(s, function(ns)
		if not ns.Moments.Has("spellsteal") then fail(s, "not learned on retail") end
		Mock.targetBuffs = { { steal = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit: " .. state(ns)) end
	end, { flavour = "mainline" })
	s = name("absent on Forever: no row, no button, no switch")
	with(s, function(ns)
		if ns.Moments.Has("spellsteal") then fail(s, "learned on Forever") end
		if ns.Moments:Button(SLOT) then fail(s, "a button was made") end
	end)
end
