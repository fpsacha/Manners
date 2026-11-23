-- Fire Ward and Frost Ward by the school of the target's own cast (Prompt/
-- MomentsSense.lua, Sense.CastSchool; CastSchools.lua), three routes:
--   exact          Classic Era, Burning Crusade, Mists: UnitCastingInfo names the spell
--                  (a plain id) and the table says whether it burns or freezes, so the
--                  ward lights at the start of the cast, before any hit
--   from the game  Forever: the id is hidden; a curve over spell ids is evaluated at it
--                  by the game and the hidden answer paints the ward (the mock's model
--                  of that route: Curve:Evaluate takes a hidden number and answers a
--                  hidden number, SetAlpha takes it)
--   by what hit you   the game refuses (a pcall at setup, or at the first hidden id when
--                  nothing hidden was at hand): today's rule, kept as it was
-- A ward is only ever lit from the id itself on the first two routes. The wards'
-- own rules are in moments-wards.lua, which stands for the fallback.
--
-- Held to the mock's model of the client (tests/momentskit.lua), not to the client
-- (STATUS.md).
--
-- Every name starts with "moments-cast-school:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")

local FIRE, FROST = 9, 10
local FIRE_ID, FROST_ID = 543, 6143
local FIREBALL, FROSTBOLT, SHADOW_BOLT, BLIZZARD, FROSTFIRE = 133, 116, 686, 8364, 999001

local KNOWN = {}
for _, id in ipairs(K.MAGE_SPELLS) do KNOWN[#KNOWN + 1] = id end
for _, id in ipairs(K.WARD_SPELLS) do KNOWN[#KNOWN + 1] = id end

-- opts: flavour, plain (no hidden values), preload, count; the made-up Frostfire id
-- (school 20) is in the table of every scenario that wants it.
local function with(name, body, opts)
	opts = opts or {}
	opts.known = opts.known or KNOWN
	local preload = opts.preload
	opts.preload = function(ns)
		ns.CAST_SCHOOLS[FROSTFIRE] = 20
		if preload then preload(ns) end
	end
	K.withMage(H, "moments-cast-school: " .. name, function(ns, ...)
		K.protect(ns)
		body(ns, ...)
	end, opts)
end
local function name(s) return "moments-cast-school: " .. s end
local function slot(ns, n) return ns.Moments:Slot(n) end
local function state(ns, n) return slot(ns, n).state end
local function route(ns) return (ns.Sense.SchoolRoute()) end
local ERA = { flavour = "vanilla", plain = true }
local TBC = { flavour = "tbc", plain = true }
local FOREVER = { flavour = "camelot" }
local FOREVER_PLAIN = { flavour = "camelot", plain = true }

local function hit(ns, school)
	K.event(ns, "UNIT_COMBAT", "player", "WOUND", "", 40, school)
	K.tick(ns, 0.3)
end

local function wards(spell)
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.spell == spell then n = n + 1 end
	end
	return n
end

local function with2(opts, extra)
	local out = {}
	for k, v in pairs(opts) do out[k] = v end
	for k, v in pairs(extra or {}) do out[k] = v end
	return out
end

-------------------------------------------------------------------------------
-- the table
-------------------------------------------------------------------------------

do
	local s = name("CastSchools.lua: each client's table is whole, small and only fire and frost")
	with(s, function(ns)
		local chunk = loadfile(dir .. "/CastSchools.lua")
		if not chunk then fail(s, "CastSchools.lua does not load") return end
		local shared = {}
		chunk("Manners", shared)
		local all = shared.CAST_SCHOOLS_BY_CLIENT
		if type(all) ~= "table" then fail(s, "no ns.CAST_SCHOOLS_BY_CLIENT") return end
		for _, client in ipairs({ "camelot", "vanilla", "tbc", "mists" }) do
			local list, n = all[client], 0
			if type(list) ~= "table" then fail(s, client .. ": no table") else
				for id, mask in pairs(list) do
					n = n + 1
					if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then fail(s, client .. ": a bad id " .. tostring(id)) end
					if mask ~= 4 and mask ~= 16 and mask ~= 20 then fail(s, client .. ": " .. tostring(id) .. " has mask " .. tostring(mask)) end
				end
				if n < 400 or n > 3000 then fail(s, client .. ": " .. n .. " spells (expected a few hundred to a few thousand)") end
				if list[FIREBALL] ~= 4 or list[FROSTBOLT] ~= 16 then fail(s, client .. ": Fireball or Frostbolt is not named for its school") end
				if list[1953] or list[SHADOW_BOLT] or list[FIRE_ID] or list[FROST_ID] then
					fail(s, client .. ": a spell that is neither a fire nor a frost cast with a bar is listed")
				end
			end
		end
		if all.mainline then fail(s, "retail has no table: it hides the id and offers no wards") end
		-- Prompt/MomentsData.lua keeps the running client's table and lets the others go.
		if ns.CAST_SCHOOLS_BY_CLIENT ~= nil then fail(s, "the other clients' tables are kept in memory") end
		if type(ns.CAST_SCHOOLS) ~= "table" or ns.CAST_SCHOOLS[FIREBALL] ~= 4 then fail(s, "ns.CAST_SCHOOLS is not Forever's table") end
	end, FOREVER_PLAIN)
end

-------------------------------------------------------------------------------
-- exact: a plain spell id (Classic Era's returns put it eighth, TBC's ninth)
-------------------------------------------------------------------------------

do
	local s = name("exact, Classic Era: a Fireball lights Fire Ward at the start of the cast, before any hit")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, { spell = FIREBALL, eraShape = true })
		-- At the start event itself, not when the flush it schedules runs.
		if state(ns, FIRE) ~= "lit" then fail(s, "Fire Ward not lit at the start of a Fireball: " .. state(ns, FIRE) .. " " .. tostring(slot(ns, FIRE).why)) end
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "lit" or K.shown(ns, FIRE) ~= 1 then fail(s, "not lit a moment on: " .. state(ns, FIRE)) end
		if state(ns, FROST) ~= "dark" then fail(s, "Frost Ward lit by a Fireball: " .. state(ns, FROST)) end
		if slot(ns, FROST).why ~= "your target is casting something that is not of that kind" then
			fail(s, "Frost Ward's reason: " .. tostring(slot(ns, FROST).why))
		end
		if route(ns) ~= "exact" then fail(s, "the route: " .. route(ns)) end
		K.click(ns, FIRE)
		if wards("Fire Ward") ~= 1 then fail(s, "a click did not cast Fire Ward: " .. wards("Fire Ward")) end
		K.endCast(ns)
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "dark" then fail(s, "still lit once the cast ended: " .. state(ns, FIRE)) end
	end, ERA)
	s = name("exact, Classic Era: a Frostbolt lights Frost Ward only")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, { spell = FROSTBOLT, eraShape = true })
		K.tick(ns, 0.3)
		if state(ns, FROST) ~= "lit" or state(ns, FIRE) ~= "dark" then fail(s, "frost " .. state(ns, FROST) .. ", fire " .. state(ns, FIRE)) end
	end, ERA)
	s = name("exact, Classic Era: a channel (Blizzard, the id seventh) lights Frost Ward")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, { spell = BLIZZARD, channel = true, eraShape = true })
		K.tick(ns, 0.3)
		if state(ns, FROST) ~= "lit" or state(ns, FIRE) ~= "dark" then fail(s, "frost " .. state(ns, FROST) .. ", fire " .. state(ns, FIRE)) end
	end, ERA)
	s = name("exact, Burning Crusade (the id ninth): the same, and a channel (Blizzard) lights Frost Ward")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, { spell = FIREBALL })
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "lit" or state(ns, FROST) ~= "dark" then fail(s, "fireball: fire " .. state(ns, FIRE) .. ", frost " .. state(ns, FROST)) end
		K.endCast(ns)
		K.tick(ns, 0.3)
		if ns.CAST_SCHOOLS[BLIZZARD] ~= 16 then fail(s, "the table lacks Blizzard (" .. tostring(ns.CAST_SCHOOLS[BLIZZARD]) .. ")") end
		K.cast(ns, { spell = BLIZZARD, channel = true })
		K.tick(ns, 0.3)
		if state(ns, FROST) ~= "lit" or state(ns, FIRE) ~= "dark" then fail(s, "blizzard: fire " .. state(ns, FIRE) .. ", frost " .. state(ns, FROST)) end
		K.endCast(ns, "UNIT_SPELLCAST_CHANNEL_STOP")
		K.tick(ns, 0.3)
		if state(ns, FROST) ~= "dark" then fail(s, "still lit once the channel ended") end
	end, TBC)
end

do
	local s = name("exact: a spell the table does not hold lights neither ward")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, { spell = SHADOW_BOLT })
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "dark" or state(ns, FROST) ~= "dark" then fail(s, "a Shadow Bolt lit a ward") end
	end, TBC)
	s = name("exact: a Frostfire cast lights both")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, { spell = FROSTFIRE })
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "lit" or state(ns, FROST) ~= "lit" then fail(s, "fire " .. state(ns, FIRE) .. ", frost " .. state(ns, FROST)) end
	end, TBC)
end

do
	local s = name("exact: a cast of another school is not guessed at from an earlier hit")
	with(s, function(ns)
		K.pull(ns)
		hit(ns, 4)
		K.tick(ns, 11)
		if state(ns, FIRE) ~= "dark" then fail(s, "Fire Ward still lit eleven seconds after the hit") end
		-- Today's rule would light Fire Ward here (fire hit you this fight, the target casts).
		K.cast(ns, { spell = FROSTBOLT })
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "dark" then fail(s, "Fire Ward lit by a guess under a Frostbolt: " .. tostring(slot(ns, FIRE).why)) end
		if state(ns, FROST) ~= "lit" then fail(s, "Frost Ward not lit by the Frostbolt") end
		K.endCast(ns)
		K.tick(ns, 0.3)
		-- A fire spell the table names does light it, with no new hit.
		K.cast(ns, { spell = FIREBALL })
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "lit" then fail(s, "Fire Ward not lit by a Fireball") end
	end, TBC)
	s = name("exact: a fire hit still lights Fire Ward for ten seconds whatever is cast")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, { spell = SHADOW_BOLT })
		hit(ns, 4)
		if state(ns, FIRE) ~= "lit" then fail(s, "a fire hit did not light Fire Ward: " .. state(ns, FIRE) .. " " .. tostring(slot(ns, FIRE).why)) end
	end, TBC)
end

do
	local s = name("exact: a cast whose id is not a number is a cast of unknown school, and today's rule applies")
	with(s, function(ns)
		K.pull(ns)
		hit(ns, 4)
		K.tick(ns, 11)
		K.cast(ns, {})
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "lit" then fail(s, "an unnamed cast after a fire hit did not light Fire Ward: " .. state(ns, FIRE)) end
	end, TBC)
end

-------------------------------------------------------------------------------
-- from the game: a hidden id, the mock's model of the secret route
-------------------------------------------------------------------------------

do
	local s = name("from the game: setup tries a hidden number and says so")
	with(s, function(ns)
		if route(ns) ~= "from the game" then fail(s, "the route: " .. route(ns) .. " " .. tostring(select(2, ns.Sense.SchoolRoute()))) end
		if ns.Sense.refused.school or ns.Sense.castRoute.refused then fail(s, "marked refused: " .. tostring(ns.Sense.castRoute.refused)) end
	end, FOREVER)
end

do
	local s = name("from the game: a hidden Fireball lights Fire Ward before any hit, and only the game knows")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, { spell = FIREBALL, spellHidden = true })
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "game" or state(ns, FROST) ~= "game" then fail(s, "fire " .. state(ns, FIRE) .. ", frost " .. state(ns, FROST)) end
		if K.shown(ns, FIRE) ~= 1 then fail(s, "Fire Ward's art not painted: " .. tostring(K.shown(ns, FIRE))) end
		if K.shown(ns, FROST) ~= 0 then fail(s, "Frost Ward's art painted by a Fireball: " .. tostring(K.shown(ns, FROST))) end
		-- Only the game knows, so a ward takes two clicks and the cover is up for the first.
		if not slot(ns, FIRE).cover:IsShown() then fail(s, "no cover over a ward only the game lights") end
		if K.click(ns, FIRE) == ns.Moments:Button(FIRE) then fail(s, "the first click got through to the spell") end
		K.endCast(ns)
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "dark" or state(ns, FROST) ~= "dark" then fail(s, "not dark once the cast ended: " .. state(ns, FIRE) .. " " .. state(ns, FROST)) end
		if route(ns) ~= "from the game" then fail(s, "the route: " .. route(ns)) end
	end, FOREVER)
	s = name("from the game: a hidden Frostbolt lights Frost Ward alone")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, { spell = FROSTBOLT, spellHidden = true })
		K.tick(ns, 0.3)
		if K.shown(ns, FROST) ~= 1 or K.shown(ns, FIRE) ~= 0 then fail(s, "frost " .. tostring(K.shown(ns, FROST)) .. ", fire " .. tostring(K.shown(ns, FIRE))) end
	end, FOREVER)
	s = name("from the game: a hidden spell that is neither paints neither ward, and a Frostfire paints both")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, { spell = SHADOW_BOLT, spellHidden = true })
		K.tick(ns, 0.3)
		if K.shown(ns, FROST) ~= 0 or K.shown(ns, FIRE) ~= 0 then fail(s, "a Shadow Bolt painted a ward") end
		K.endCast(ns)
		K.tick(ns, 0.3)
		K.cast(ns, { spell = FROSTFIRE, spellHidden = true })
		K.tick(ns, 0.3)
		if K.shown(ns, FROST) ~= 1 or K.shown(ns, FIRE) ~= 1 then fail(s, "a Frostfire did not paint both") end
	end, FOREVER)
	s = name("from the game: a hidden channel is read too")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns, { spell = BLIZZARD, spellHidden = true, channel = true })
		K.tick(ns, 0.3)
		if K.shown(ns, FROST) ~= 1 or K.shown(ns, FIRE) ~= 0 then fail(s, "frost " .. tostring(K.shown(ns, FROST)) .. ", fire " .. tostring(K.shown(ns, FIRE))) end
	end, FOREVER)
end

do
	local s = name("from the game: the ward is lit from the id alone, never from what hit you")
	with(s, function(ns)
		K.pull(ns)
		hit(ns, 4)
		K.tick(ns, 11)
		-- The fallback would light Fire Ward on any cast now; the id says Frostbolt.
		K.cast(ns, { spell = FROSTBOLT, spellHidden = true })
		K.tick(ns, 1)
		if K.shown(ns, FIRE) ~= 0 or K.shown(ns, FROST) ~= 1 then fail(s, "fire " .. tostring(K.shown(ns, FIRE)) .. ", frost " .. tostring(K.shown(ns, FROST))) end
		if state(ns, FIRE) == "lit" then fail(s, "Fire Ward lit by a guess") end
	end, FOREVER)
	s = name("from the game: a fire hit still lights Fire Ward plainly")
	with(s, function(ns)
		K.pull(ns)
		hit(ns, 4)
		if state(ns, FIRE) ~= "lit" or K.shown(ns, FIRE) ~= 1 then fail(s, "fire " .. state(ns, FIRE)) end
		-- A hidden Frostbolt now: the game paints Frost Ward, and Fire Ward stays lit by the hit.
		K.cast(ns, { spell = FROSTBOLT, spellHidden = true })
		K.tick(ns, 1)
		if state(ns, FIRE) ~= "lit" or K.shown(ns, FIRE) ~= 1 then fail(s, "fire " .. state(ns, FIRE) .. " under a hidden Frostbolt") end
		if K.shown(ns, FROST) ~= 1 then fail(s, "Frost Ward not painted by the Frostbolt") end
	end, FOREVER)
	s = name("from the game: a cast with no id, or one that is not a number, is today's rule")
	with(s, function(ns)
		K.pull(ns)
		hit(ns, 4)
		K.tick(ns, 11)
		K.cast(ns, {})
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "lit" then fail(s, "an unnamed cast after a fire hit: " .. state(ns, FIRE)) end
	end, FOREVER)
end

do
	-- The events' own guard may use pcall; what a hidden id adds to it is what is held to none.
	local function pcalls(ns, cast)
		local before = Mock.asked.pcall
		K.cast(ns, cast)
		K.tick(ns, 0.3)
		K.endCast(ns)
		K.tick(ns, 0.3)
		return Mock.asked.pcall - before
	end
	local s = name("from the game: no pcall once the route is settled, at the pull or on a cast")
	with(s, function(ns)
		K.pull(ns)
		pcalls(ns, {})
		local base = pcalls(ns, {})
		local fire = pcalls(ns, { spell = FIREBALL, spellHidden = true })
		local frost = pcalls(ns, { spell = FROSTBOLT, spellHidden = true })
		if fire ~= base or frost ~= base then fail(s, "a hidden id cost pcalls: " .. base .. " without, " .. fire .. " and " .. frost .. " with") end
	end, with2(FOREVER, { count = { "pcall" } }))
end

-------------------------------------------------------------------------------
-- refused: the game says no, the rule stays as it was
-------------------------------------------------------------------------------

do
	local s = name("refused at setup: Curve:Evaluate throws on a hidden number, and the fallback lights from the hit")
	with(s, function(ns)
		local why = select(2, ns.Sense.SchoolRoute())
		if route(ns) ~= "by what hit you" or not tostring(why):find("Curve:Evaluate", 1, true) then
			fail(s, "the route: " .. route(ns) .. " (" .. tostring(why) .. ")")
		end
		K.pull(ns)
		K.cast(ns, { spell = FIREBALL, spellHidden = true })
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "dark" or slot(ns, FIRE).why ~= "nothing of that kind has hit you" then
			fail(s, "lit or odd with nothing hit: " .. state(ns, FIRE) .. " " .. tostring(slot(ns, FIRE).why))
		end
		K.endCast(ns)
		hit(ns, 4)
		K.tick(ns, 11)
		K.cast(ns, { spell = FIREBALL, spellHidden = true })
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "lit" or state(ns, FROST) ~= "dark" then fail(s, "today's rule: fire " .. state(ns, FIRE) .. ", frost " .. state(ns, FROST)) end
	end, with2(FOREVER, { preload = function() Mock.curveRefusesSecret = true end }))
	s = name("refused at setup: the game takes the number but will not paint from the answer")
	with(s, function(ns)
		local why = select(2, ns.Sense.SchoolRoute())
		if route(ns) ~= "by what hit you" or not ns.Sense.refused.school then
			fail(s, "the route: " .. route(ns) .. " (" .. tostring(why) .. ")")
		end
		K.pull(ns)
		hit(ns, 16)
		K.tick(ns, 11)
		K.cast(ns, { spell = FROSTBOLT, spellHidden = true })
		K.tick(ns, 0.3)
		if state(ns, FROST) ~= "lit" or state(ns, FIRE) ~= "dark" then fail(s, "today's rule: frost " .. state(ns, FROST) .. ", fire " .. state(ns, FIRE)) end
	end, with2(FOREVER, { preload = function() Mock.refuseSecretAlpha = true end }))
end

do
	local s = name("not settled at setup (nothing hidden to try): the first hidden id settles it, from the game")
	with(s, function(ns)
		if route(ns) ~= "not settled yet" then fail(s, "the route before a cast: " .. route(ns)) end
		K.pull(ns)
		K.cast(ns, { spell = FIREBALL, spellHidden = true })
		K.tick(ns, 0.3)
		if K.shown(ns, FIRE) ~= 1 or K.shown(ns, FROST) ~= 0 then fail(s, "fire " .. tostring(K.shown(ns, FIRE)) .. ", frost " .. tostring(K.shown(ns, FROST))) end
		if route(ns) ~= "from the game" then fail(s, "the route after: " .. route(ns)) end
	end, FOREVER_PLAIN)
	s = name("not settled at setup: the first hidden id refused settles it on the fallback, once")
	with(s, function(ns)
		K.pull(ns)
		hit(ns, 4)
		K.tick(ns, 11)
		K.cast(ns, { spell = FROSTBOLT, spellHidden = true })
		K.tick(ns, 0.3)
		if route(ns) ~= "by what hit you" then fail(s, "the route after a refusal: " .. route(ns)) end
		-- Today's rule: fire hit you this fight, the target casts.
		if state(ns, FIRE) ~= "lit" then fail(s, "the fallback did not light Fire Ward: " .. state(ns, FIRE)) end
		K.endCast(ns)
		K.tick(ns, 0.3)
		local function pcalls(cast)
			local before = Mock.asked.pcall
			K.cast(ns, cast)
			K.tick(ns, 0.3)
			K.endCast(ns)
			K.tick(ns, 0.3)
			return Mock.asked.pcall - before
		end
		local base, again = pcalls({}), pcalls({ spell = FROSTBOLT, spellHidden = true })
		if again ~= base then fail(s, "the refused route was tried again: " .. base .. " pcalls without an id, " .. again .. " with") end
	end, with2(FOREVER_PLAIN, { count = { "pcall" }, preload = function() Mock.curveRefusesSecret = true end }))
end

do
	local s = name("a client with no table of spells falls back at once")
	with(s, function(ns)
		if route(ns) ~= "by what hit you" then fail(s, "the route: " .. route(ns)) end
		K.pull(ns)
		K.cast(ns, { spell = FIREBALL })
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "dark" then fail(s, "lit with no table and no hit") end
		hit(ns, 4)
		if state(ns, FIRE) ~= "lit" then fail(s, "a fire hit did not light Fire Ward") end
		-- Nothing is known of a cast's school here, so today's guess stands: fire hit you, the target casts.
		K.tick(ns, 11)
		K.endCast(ns)
		K.cast(ns, { spell = FROSTBOLT })
		K.tick(ns, 0.3)
		if state(ns, FIRE) ~= "lit" then fail(s, "the guess was not made: " .. state(ns, FIRE) .. " " .. tostring(slot(ns, FIRE).why)) end
	end, with2(TBC, { preload = function(ns) for id in pairs(ns.CAST_SCHOOLS) do ns.CAST_SCHOOLS[id] = nil end end }))
end

-------------------------------------------------------------------------------
-- what the check-up and /manners debug say
-------------------------------------------------------------------------------

do
	local function selfLine(ns)
		for _, r in ipairs(ns.Selftest.Run()) do
			if r.id == "fight.apis" and tostring(r.value):find("cast school:", 1, true) then return tostring(r.value) end
		end
		return nil
	end
	local function debugLine(ns)
		for _, line in ipairs(ns.MomentLines()) do
			if line:find("cast school:", 1, true) then return line end
		end
		return nil
	end
	local s = name("debug and the self-test name the route: from the game")
	with(s, function(ns)
		local d, t = debugLine(ns), selfLine(ns)
		if not (d and d:find("cast school: from the game", 1, true)) then fail(s, "debug: " .. tostring(d)) end
		if not (t and t:find("cast school: from the game", 1, true)) then fail(s, "self-test: " .. tostring(t)) end
	end, FOREVER)
	s = name("debug and the self-test name the route: exact, once a plain id was seen")
	with(s, function(ns)
		local d = debugLine(ns)
		if not (d and d:find("cast school: not settled yet", 1, true)) then fail(s, "before a cast: " .. tostring(d)) end
		K.pull(ns)
		K.cast(ns, { spell = FIREBALL })
		K.tick(ns, 0.3)
		K.endCast(ns)
		K.release(ns)
		d = debugLine(ns)
		local t = selfLine(ns)
		if not (d and d:find("cast school: exact", 1, true)) then fail(s, "debug: " .. tostring(d)) end
		if not (t and t:find("cast school: exact", 1, true)) then fail(s, "self-test: " .. tostring(t)) end
	end, TBC)
	s = name("debug and the self-test name the route: by what hit you, and why")
	with(s, function(ns)
		local d, t = debugLine(ns), selfLine(ns)
		if not (d and d:find("cast school: by what hit you", 1, true) and d:find("Curve:Evaluate", 1, true)) then fail(s, "debug: " .. tostring(d)) end
		if not (t and t:find("cast school: by what hit you", 1, true)) then fail(s, "self-test: " .. tostring(t)) end
	end, with2(FOREVER, { preload = function() Mock.curveRefusesSecret = true end }))
end
