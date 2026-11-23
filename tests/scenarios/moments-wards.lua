-- Fire Ward and Frost Ward for the moment (Prompt/Moments.lua; Forever, Classic
-- Era and Burning Crusade): the game shows addons no school for a cast in flight,
-- so they light on what has just landed. Lit in a fight while the ward is ready
-- and affordable, a hostile target is casting, damage of its school hit you in
-- the last ten seconds (UNIT_COMBAT's school, plain), and the cast is aimed at
-- you where the game says. Of the two only the school that hit last lights; a
-- cast of either starts both clocks. They ship switched off.
--
-- Held to the mock's model of the client (tests/momentskit.lua), not to the
-- client (STATUS.md).
--
-- Every name starts with "moments-wards:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")

local FIRE, FROST = 9, 10
local FIRE_ID, FROST_ID = 543, 6143

local KNOWN = {}
for _, id in ipairs(K.MAGE_SPELLS) do KNOWN[#KNOWN + 1] = id end
for _, id in ipairs(K.WARD_SPELLS) do KNOWN[#KNOWN + 1] = id end

local function with(name, body, opts)
	opts = opts or {}
	opts.known = opts.known or KNOWN
	K.withMage(H, "moments-wards: " .. name, function(ns, ...)
		-- Off by default: the scenario switches them on.
		ns.db.profile.moments.fireward = true
		ns.db.profile.moments.frostward = true
		ns.addon:Tick()
		K.protect(ns)
		body(ns, ...)
	end, opts)
end
local function name(s) return "moments-wards: " .. s end
local function slot(ns, n) return ns.Moments:Slot(n) end
local function state(ns, n) return slot(ns, n).state end

local function hit(ns, school, amount)
	K.event(ns, "UNIT_COMBAT", "player", "WOUND", "", amount or 40, school)
	K.tick(ns, 0.3)
end

local function wards(spell)
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.spell == spell then n = n + 1 end
	end
	return n
end

do
	local s = name("off by default")
	K.withMage(H, s, function(ns)
		if ns.db.profile.moments.fireward ~= false or ns.db.profile.moments.frostward ~= false then fail(s, "a ward ships on") end
		if ns.Moments:Button(FIRE) or ns.Moments:Button(FROST) then fail(s, "a ward button was made while off") end
	end, { known = KNOWN })
end

do
	local s = name("no hit: dark, with the reason")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, {})
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "dark" or slot(ns, FIRE).why ~= "nothing of that kind has hit you" then
			fail(s, "lit with no hit: " .. state(ns, FIRE) .. " " .. tostring(slot(ns, FIRE).why))
		end
	end)
end

do
	local s = name("a fire hit then a cast lights Fire Ward only")
	with(s, function(ns)
		K.pull(ns)
		hit(ns, 4)
		if state(ns, FIRE) ~= "dark" then fail(s, "lit with nobody casting") end
		K.cast(ns, {})
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "lit" then fail(s, "Fire Ward not lit: " .. state(ns, FIRE) .. " " .. tostring(slot(ns, FIRE).why)) end
		if state(ns, FROST) ~= "dark" then fail(s, "Frost Ward lit by a fire hit") end
		local click = K.click(ns, FIRE)
		if click ~= ns.Moments:Button(FIRE) or wards("Fire Ward") ~= 1 then fail(s, "a click did not cast Fire Ward: " .. wards("Fire Ward")) end
		if K.macro(ns, FIRE) ~= "/stopcasting\n/cast Fire Ward" then fail(s, "the macro: " .. tostring(K.macro(ns, FIRE))) end
		K.endCast(ns)
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "dark" then fail(s, "still lit when the cast ended") end
	end)
	s = name("a frost hit lights Frost Ward")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, {})
		hit(ns, 16)
		if state(ns, FROST) ~= "lit" or state(ns, FIRE) ~= "dark" then fail(s, "frost " .. state(ns, FROST) .. ", fire " .. state(ns, FIRE)) end
	end)
end

do
	local s = name("the later school wins")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, {})
		hit(ns, 4)
		Mock.runTimers(2)
		hit(ns, 16)
		if state(ns, FROST) ~= "lit" then fail(s, "Frost Ward not lit by the later hit: " .. state(ns, FROST)) end
		if state(ns, FIRE) ~= "dark" or slot(ns, FIRE).why ~= "another kind hit you more recently" then
			fail(s, "Fire Ward lit under a later frost hit: " .. state(ns, FIRE) .. " " .. tostring(slot(ns, FIRE).why))
		end
	end)
	s = name("a hit of both schools at once lights both")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, {})
		hit(ns, 20)
		if state(ns, FROST) ~= "lit" or state(ns, FIRE) ~= "lit" then fail(s, "a frostfire hit did not light both") end
	end)
end

do
	local s = name("eleven seconds is too long")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, {})
		hit(ns, 4)
		if state(ns, FIRE) ~= "lit" then fail(s, "not lit first") end
		K.tick(ns, 11)
		if state(ns, FIRE) ~= "dark" then fail(s, "still lit eleven seconds after the hit: " .. state(ns, FIRE)) end
	end)
end

do
	local s = name("a hidden school mask is ignored")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, {})
		hit(ns, Mock.secret(4))
		if state(ns, FIRE) ~= "dark" then fail(s, "lit by a hit whose school nobody could read") end
	end)
	s = name("only a wound counts")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, {})
		K.event(ns, "UNIT_COMBAT", "player", "HEAL", "", 40, 4)
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "dark" then fail(s, "lit by a heal") end
	end)
end

do
	local s = name("aimed: plain false is dark, plain true is lit")
	with(s, function(ns)
		K.pull(ns)
		hit(ns, 4)
		Mock.aimedAtMe = false
		K.cast(ns, {})
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "dark" or slot(ns, FIRE).why ~= "not aimed at you" then fail(s, "lit on a cast at somebody else: " .. state(ns, FIRE)) end
		Mock.aimedAtMe = true
		K.cast(ns, {})
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "lit" then fail(s, "not lit on a cast at you: " .. state(ns, FIRE)) end
	end)
	s = name("aimed: a hidden answer is handed to the game")
	with(s, function(ns)
		K.pull(ns)
		hit(ns, 4)
		Mock.aimedAtMe = Mock.secret(true)
		K.cast(ns, {})
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "game" or K.shown(ns, FIRE) ~= 1 then fail(s, "not shown for a hidden yes: " .. state(ns, FIRE)) end
		Mock.aimedAtMe = Mock.secret(false)
		K.cast(ns, {})
		K.tick(ns, 0.3)
		if K.shown(ns, FIRE) ~= 0 then fail(s, "shown for a hidden no") end
		if #Mock.secretOnSecure > 0 or Mock.secureAlphaWrites ~= 0 then fail(s, "a hidden value reached a secure frame") end
	end)
	s = name("aimed: no call to ask passes it over")
	with(s, function(ns)
		_G.PlayerIsSpellTarget = nil
		K.pull(ns)
		hit(ns, 4)
		K.cast(ns, {})
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "lit" then fail(s, "not lit with the aim unknown: " .. state(ns, FIRE)) end
	end)
	s = name("aimed: hidden with no boolean call passes it over")
	with(s, function(ns)
		ns.Sense.can.bool = false
		Mock.aimedAtMe = Mock.secret(false)
		K.pull(ns)
		hit(ns, 4)
		K.cast(ns, {})
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "lit" then fail(s, "not lit weakly: " .. state(ns, FIRE)) end
	end)
end

do
	local s = name("a cast of either darkens both")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, {})
		hit(ns, 20)
		if state(ns, FROST) ~= "lit" or state(ns, FIRE) ~= "lit" then fail(s, "not both lit first") end
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", FIRE_ID)
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "dark" or state(ns, FROST) ~= "dark" then
			fail(s, "fire " .. state(ns, FIRE) .. ", frost " .. state(ns, FROST))
		end
		if slot(ns, FROST).why ~= "cooling down" then fail(s, "Frost Ward's reason: " .. tostring(slot(ns, FROST).why)) end
	end)
	s = name("and the other way round")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, {})
		hit(ns, 20)
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", FROST_ID)
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "dark" or state(ns, FROST) ~= "dark" then fail(s, "not both dark") end
	end)
end

do
	local s = name("the hits are heard only in a fight, and the event is gone at the release")
	with(s, function(ns)
		if K.event(ns, "UNIT_COMBAT", "player", "WOUND", "", 40, 4) then fail(s, "a combat event reached the frame out of a fight") end
		K.pull(ns)
		if not K.event(ns, "UNIT_COMBAT", "player", "WOUND", "", 40, 4) then fail(s, "not registered at the pull") end
		K.release(ns)
		if K.event(ns, "UNIT_COMBAT", "player", "WOUND", "", 40, 4) then fail(s, "still registered after the release") end
	end)
end
