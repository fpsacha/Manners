-- The urgent buttons for the moment (Blink, Counterspell, Ice Block, Cold Snap) lit
-- the moment the need is seen (Prompt/MomentsData.lua `fast`, Prompt/MomentsSense.lua
-- OnlyGcd, Prompt/Moments.lua): the owner's check-up had
--     11:29:05 loss of control: ? (secret)
--     11:29:06 moment blink: lit
-- a second late, and then a fade-in, while he was stunned for two or three seconds.
-- Two paths fit that trail and the trail cannot tell which one it was, so both are
-- held here: the global cooldown (a cooldown flag that says "not the global one", read
-- at the last cooldown event, kept Blink "cooling down" until the next event) and a
-- loss of control whose count the game hides (nothing started the guess until a
-- control-lost event came).
--
-- Held to the mock's model of the client (tests/momentskit.lua: Mock.cooldown[61304]
-- stands in for the global cooldown), not to the client itself: whether 61304 answers
-- isActive plainly on Forever is a question for a fight (STATUS.md).
--
-- Every name starts with "moments-fast:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")
-- Written for plain values; Forever's hidden ones are asked for by name.
K.plain = true

local BLINK, ICE = 1953, 11958
local GCD = 61304

local function with(name, body, opts) K.withMage(H, "moments-fast: " .. name, body, opts) end
local function name(s) return "moments-fast: " .. s end
local function slot(ns, n) return ns.Moments:Slot(n) end

local function trailHas(ns, text)
	for _, e in ipairs(ns.addon.db.char.trail or {}) do
		if tostring(e.text):find(text, 1, true) then return true end
	end
	return false
end

-- A global cooldown running, its figures hidden as a fight hides them.
local function gcdRunning(secret)
	local rec = { isActive = true, startTime = Mock.now - 0.5, duration = 1.5, secretNumbers = secret }
	return rec
end

-- The Blink the owner's trail is about: the game's cooldown record for it says
-- "active" and, at the last cooldown event, "not on the global cooldown".
local function ownersTrail(ns)
	Mock.cooldown = {
		[BLINK] = { isActive = true, isOnGCD = false, secretNumbers = true },
		[GCD] = gcdRunning(true),
	}
	K.cooldownEvent(ns)
	K.tick(ns, 0.3)
end

do
	local s = name("the owner's trail: a stun the game would not name, under the global cooldown, lights Blink in the same frame")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		ownersTrail(ns)
		Mock.lossOfControl = { { locType = Mock.SECRET } }
		K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
		local blink = slot(ns, 3)
		if blink.state ~= "lit" then fail(s, "not lit at the event: " .. blink.state .. " (" .. tostring(blink.why) .. ")") return end
		if blink.face:GetAlpha() ~= 1 then fail(s, "the face is not at full alpha at once: " .. tostring(blink.face:GetAlpha())) end
		if K.shown(ns, 3) ~= 1 then fail(s, "not on the screen in the same frame: " .. tostring(K.shown(ns, 3))) end
		if not blink.button:IsShown() then fail(s, "the button is not up") end
	end)
end

do
	local s = name("a real cooldown still holds Blink dark under the global cooldown")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		-- Our own cast of it: Manners' own clock says a cooldown runs.
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", BLINK)
		K.tick(ns, 0.3)
		ownersTrail(ns)
		Mock.lossOfControl = { { locType = "STUN", spellID = 1 } }
		K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
		K.tick(ns, 0.3)
		if slot(ns, 3).state ~= "dark" then fail(s, "lit on its own cooldown: " .. slot(ns, 3).state) end
		if slot(ns, 3).why ~= "cooling down" then fail(s, "the reason is " .. tostring(slot(ns, 3).why)) end
	end)
	s = name("a plain cooldown of fifteen seconds under the global cooldown keeps Blink dark")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		Mock.cooldown = {
			[BLINK] = { isActive = true, isOnGCD = false, startTime = Mock.now - 1, duration = 15 },
			[GCD] = { isActive = true, startTime = Mock.now - 0.5, duration = 1.5 },
		}
		K.cooldownEvent(ns)
		Mock.lossOfControl = { { locType = "STUN", spellID = 1 } }
		K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
		K.tick(ns, 0.3)
		if slot(ns, 3).state ~= "dark" then fail(s, "a fifteen second cooldown was taken for the global one: " .. slot(ns, 3).state) end
	end)
end

do
	local s = name("the global cooldown is no reason for Cold Snap: Ice Block cast only a moment ago, under the global cooldown")
	with(s, function(ns)
		Mock.health, Mock.healthMax = 10, 100
		K.pull(ns)
		K.tick(ns, 0.3)
		Mock.cooldown = {
			[ICE] = { isActive = true, isOnGCD = false, secretNumbers = true },
			[GCD] = gcdRunning(true),
		}
		K.cooldownEvent(ns)
		K.event(ns, "UNIT_HEALTH", "player")
		K.tick(ns, 0.3)
		local ice, snap = slot(ns, 2), slot(ns, 7)
		if ice.state ~= "lit" then fail(s, "Ice Block is not lit by the low health under the global cooldown: " .. ice.state .. " " .. tostring(ice.why)) end
		if snap.state ~= "dark" then fail(s, "Cold Snap lit for nothing: " .. snap.state .. " " .. tostring(snap.why)) end
	end)
	s = name("Cold Snap still lights while Ice Block is on a real cooldown of ours")
	with(s, function(ns)
		Mock.health, Mock.healthMax = 100, 100
		K.pull(ns)
		K.tick(ns, 0.3)
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", ICE)
		Mock.health = 10
		K.event(ns, "UNIT_HEALTH", "player")
		K.tick(ns, 0.3)
		if slot(ns, 7).state ~= "lit" then fail(s, "Cold Snap dark with Ice Block cooling: " .. slot(ns, 7).state .. " " .. tostring(slot(ns, 7).why)) end
	end)
end

do
	local s = name("a hidden loss-of-control count lights Blink at the event itself, with no control-lost event")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		Mock.lossOfControl = { { locType = "STUN", spellID = 1 } }
		Mock.lossOfControlCount = Mock.SECRET
		K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
		if slot(ns, 3).state ~= "lit" then fail(s, "not lit at the event: " .. slot(ns, 3).state .. " (" .. tostring(slot(ns, 3).why) .. ")") end
		if K.shown(ns, 3) ~= 1 then fail(s, "not on the screen at once") end
		-- A plain nothing at the update ends it.
		Mock.lossOfControl, Mock.lossOfControlCount = {}, 0
		K.event(ns, "LOSS_OF_CONTROL_UPDATE", "player")
		K.tick(ns, 0.3)
		if slot(ns, 3).state ~= "dark" then fail(s, "still lit after a plain zero: " .. slot(ns, 3).state) end
	end)
	s = name("the hidden guess ends after ten seconds with the count still unreadable")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		-- HasFullControl says nothing helpful: a loss of control is listed all along.
		Mock.lossOfControl = { { locType = "STUN", spellID = 1 } }
		Mock.lossOfControlCount = Mock.SECRET
		K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
		K.tick(ns, 5)
		if slot(ns, 3).state ~= "lit" then fail(s, "not lit five seconds in: " .. slot(ns, 3).state) end
		K.tick(ns, 6)
		if slot(ns, 3).state ~= "dark" then fail(s, "the guess outlived its ten seconds: " .. slot(ns, 3).state) end
		if ns.Sense.locAt ~= nil then fail(s, "the guess is still kept") end
	end)
end

do
	local s = name("a dark verdict that clears on its own is read again within a quarter second")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		Mock.usable = { [BLINK] = { usable = false, noMana = false } }
		Mock.lossOfControl = { { locType = "STUN", spellID = 1 } }
		K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
		K.tick(ns, 0.3)
		if slot(ns, 3).state ~= "dark" then fail(s, "lit while the game says it cannot be cast: " .. slot(ns, 3).state) return end
		-- The game's no clears with no event of any kind.
		Mock.usable = nil
		K.tick(ns, 0.3)
		if slot(ns, 3).state ~= "lit" then fail(s, "still dark a quarter second after the game's no cleared: " .. slot(ns, 3).state .. " " .. tostring(slot(ns, 3).why)) end
	end)
end

do
	local s = name("Counterspell and Ice Block painted by the game appear at once with no fade")
	with(s, function(ns)
		Mock.healthSecret, Mock.health = true, 100
		-- Ice Block is left to the game from the pull on (a hidden health): on the screen in that frame.
		K.pull(ns)
		local ice, counter = slot(ns, 2), slot(ns, 1)
		if ice.state ~= "game" then fail(s, "Ice Block is not left to the game: " .. ice.state .. " " .. tostring(ice.why)) return end
		if ice.face:GetAlpha() ~= 1 then fail(s, "Ice Block fades in: " .. tostring(ice.face:GetAlpha())) end
		K.tick(ns, 0.3)
		Mock.targetCast = { secret = true, notInterruptible = false }
		K.event(ns, "UNIT_SPELLCAST_START", "target")
		if counter.state ~= "game" then fail(s, "Counterspell is not left to the game: " .. counter.state .. " " .. tostring(counter.why)) return end
		if counter.face:GetAlpha() ~= 1 or K.shown(ns, 1) ~= 1 then fail(s, "Counterspell fades in: " .. tostring(counter.face:GetAlpha())) end
	end, { plain = false })
	s = name("Evocation still fades in over a fifth of a second")
	with(s, function(ns)
		Mock.manaSecret, Mock.mana = true, 100
		K.pull(ns)
		local evo = slot(ns, 4)
		if evo.state ~= "game" then fail(s, "Evocation is not left to the game: " .. evo.state .. " " .. tostring(evo.why)) return end
		if evo.face:GetAlpha() >= 1 then fail(s, "Evocation appeared with no fade") end
		K.tick(ns, 0.3)
		if evo.face:GetAlpha() ~= 1 then fail(s, "Evocation never reached full alpha: " .. tostring(evo.face:GetAlpha())) end
	end, { plain = false })
end

do
	local s = name("a held dark Blink says why on the trail, once")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", BLINK)
		Mock.lossOfControl = { { locType = "STUN", spellID = 1 } }
		K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
		K.tick(ns, 0.6)
		if slot(ns, 3).state ~= "dark" then fail(s, "not held dark: " .. slot(ns, 3).state) end
		if not trailHas(ns, "held dark: cooling down; global cooldown ") then fail(s, "no held line on the trail") end
		local n = 0
		for _, e in ipairs(ns.addon.db.char.trail or {}) do
			if tostring(e.text):find("held dark", 1, true) then n = n + 1 end
		end
		if n ~= 1 then fail(s, "the held line was said " .. n .. " times") end
		local found
		for _, line in ipairs(ns.Moments.MarkWords()) do
			if tostring(line):find("moment blink", 1, true) and tostring(line):find("held dark: cooling down", 1, true) then found = true end
		end
		if not found then fail(s, "the mark does not carry it") end
	end)
end

do
	local s = name("the urgent rows are marked fast in every client's set, and no other row is")
	with(s, function(ns)
		local want = { blink = true, counterspell = true, iceblock = true, coldsnap = true }
		for flavour, set in pairs(ns.Moments.Sets) do
			for class, rows in pairs(set) do
				for _, row in ipairs(rows) do
					if (row.fast == true) ~= (want[row.key] == true) then
						fail(s, flavour .. " " .. class .. " " .. row.key .. ": fast " .. tostring(row.fast))
					end
				end
			end
		end
	end)
end
