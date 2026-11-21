-- Naming who buffed you from the casts seen at that moment (GitHub issue 26).
-- On WoW Forever, with no combat log, a stranger's buff on you can arrive with
-- sourceUnit nil or withheld even with the friendly nameplates on, and nothing
-- was owed. Favours.lua's cast watch keeps the class-buff casts other players
-- make in sight (UNIT_SPELLCAST_SUCCEEDED, filtered by one table lookup) and a
-- landing that names nobody asks it who cast that buff in the second either
-- side: exactly one player, or nobody is named. Every landing waits for the
-- window to close and is judged over every cast in it, which prefers the cast
-- aimed at you; one with no target names them only while the friendly
-- nameplates are on and the caster plainly does not freshly wear the buff
-- themselves. A cast whose target the client withholds, and your own casts of
-- the buff, block: they are somebody else, never a name.
-- And /manners debug says what became of the last favour, so a favour let go
-- on purpose is not read as "nobody has buffed you".
--
-- Every scenario name starts with "favour-caster:" so the mutations in
-- tests/mutations/favour-caster.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom = H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom

local TOUCHED = { "IsInInstance", "DoEmote", "C_ChatInfo", "GetCVar", "UnitIsUnit", "UnitIsPlayer",
	"C_FriendList", "UnitGUID", "UnitName", "UnitExists" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local emotes = {}
local npc = {}
local aimed = {}

-- One session. opts: class (PRIEST), names (unit -> name; the units that exist
-- besides you, nameplate1 by default), aimed (unit -> the unit it targets, as
-- { nameplate1target = "player" }), plates (the friendly-nameplates CVar, "1"),
-- ignored (set of tokens on your ignore list), npc (set of tokens that are no
-- player), fromPlayer (the aura says it is a player's), thank (the emote on),
-- unseen (Thank them even when I can't see who it was), ask (Ask me before
-- thanking), flavour, enabled (false to switch Manners off).
local function with(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	local names = opts.names or { nameplate1 = { "Anna", "Aim" } }
	local plates = {}
	for unit in pairs(names) do
		if unit:find("^nameplate%d+$") then plates[#plates + 1] = unit end
	end
	table.sort(plates, function(a, b) return tonumber(a:match("%d+")) < tonumber(b:match("%d+")) end)
	Mock.nameplates = plates
	Mock.class = opts.class or "PRIEST"
	if Mock.class == "DRUID" then Mock.knownSpells = { [1126] = true, [5232] = true, [8907] = true, [9885] = true } end
	if Mock.class == "PRIEST" then
		Mock.knownSpells = { [10938] = true, [10937] = true, [2791] = true, [1245] = true,
			[1244] = true, [1243] = true, [21564] = true, [21562] = true }
	end
	Mock.extraAuraFromPlayer = opts.fromPlayer
	emotes, npc, aimed = {}, opts.npc or {}, opts.aimed or {}
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "DoEmote", function(emote, target) emotes[#emotes + 1] = { emote, target } end)
	rawset(_G, "C_ChatInfo", nil)
	local plateValue = opts.plates or "1"
	rawset(_G, "GetCVar", function(name)
		if name == "nameplateShowFriendlyPlayers" or name == "nameplateShowFriends" then return plateValue end
		return original.GetCVar and original.GetCVar(name) or nil
	end)
	rawset(_G, "UnitIsPlayer", function(unit)
		if npc[unit] then return false end
		return original.UnitIsPlayer(unit)
	end)
	rawset(_G, "UnitIsUnit", function(a, b)
		if aimed[a] == b then return true end
		return original.UnitIsUnit(a, b)
	end)
	if opts.ignored then
		rawset(_G, "C_FriendList", setmetatable({
			IsIgnored = function(unit) return opts.ignored[unit] == true end,
			IsIgnoredByGuid = function() return false end,
			GetNumIgnores = function() return 1 end,
		}, { __index = original.C_FriendList or {} }))
	end
	local undo = strangers(names)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.owed = true
		db.prompt.thankEmote = opts.thank == true
		db.prompt.thankUnseen = opts.unseen == true
		db.prompt.thankAsk = opts.ask == true
		primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
		if opts.flavour ~= "vanilla" and not ns.castWatch.armed then
			fail(scenario, "SKIPPED -- the cast watch was not armed")
			return
		end
		if opts.enabled == false then db.enabled = false end
		Mock.printed = {}
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local FORTITUDE, INTELLECT, PRAYER_FORTITUDE, RENEW, FIREBALL = 10938, 10157, 21562, 139, 133

local nextId, nextCast = 9800, 0
-- A buff landing with `source` as its caster (nil: nobody; Mock.SECRET: withheld).
local function land(ns, source, spell)
	nextId = nextId + 1
	return favourFrom(ns, source, spell or FORTITUDE, nextId)
end
-- Somebody's cast, as the client tells every frame that asked for them all.
local function cast(unit, spell, castGUID)
	nextCast = nextCast + 1
	Mock.frameEvent("UNIT_SPELLCAST_SUCCEEDED", unit, castGUID or ("Cast-" .. nextCast), spell or FORTITUDE)
end

local function said() return table.concat(Mock.printed, "\n") end
local function debugText(ns)
	Mock.printed = {}
	ns.addon:HandleSlash("debug")
	return said()
end
local function trailHas(ns, needle)
	local n = 0
	for _, t in ipairs(ns.db.char.trail or {}) do
		if t.text:find(needle, 1, true) then n = n + 1 end
	end
	return n
end
local function debts() return next(H.ownedNow and H.ownedNow() or {}) end

-- Anna on a nameplate who targets you, as a cast aimed at you needs.
local AIMED_NAMES = { nameplate1 = { "Anna", "Aim" }, nameplate1target = { "Me", "Myself" } }
local AIMED = { nameplate1target = "player" }

-- The cast watch answers once the moment has passed and the timers have run.
local function owedBy(ns, who) return ns.owed[who] ~= nil end

-- ------------------------------------------------------ named over the window
-- A cast aimed at you is preferred, but never acted on at the moment the buff
-- lands: a second cast aimed at you a moment later would make it two players. So
-- the debt and the line come once the window has closed, about a second on.
do
	local scenario = "favour-caster: a cast aimed at you names them once the moment has passed"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		cast("nameplate1")
		local text = land(ns, nil)
		if owedBy(ns, anna) then fail(scenario, "named as the buff landed, before its window closed: " .. text) end
		Mock.runTimers(2)
		if not owedBy(ns, anna) then fail(scenario, "nobody was owed once the moment had passed: " .. said()) end
		if not said():find("buffed you", 1, true) then fail(scenario, "no line said who buffed you: " .. said()) end
		if ns.castWatch.late ~= 1 or ns.castWatch.named ~= 1 then
			fail(scenario, "the count of names read: " .. tostring(ns.castWatch.named))
		end
	end)
end

do
	local scenario = "favour-caster: a withheld caster is named from their cast"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		cast("nameplate1")
		land(ns, Mock.SECRET)
		Mock.runTimers(2)
		if not owedBy(ns, anna) then fail(scenario, "a withheld caster was not named from the cast: " .. said()) end
	end)
end

do
	-- The reviewer's sequence for naming at the landing: Anna's cast at you is in the
	-- ring when the buff lands, and Bea casts it at you half a second later. Judged at
	-- the landing, Anna was named; judged over the window it is two players.
	local scenario = "favour-caster: a second cast aimed at you after the landing names nobody"
	local names = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bea", "Bold" },
		nameplate1target = { "Me", "Myself" }, nameplate2target = { "Me", "Myself" } }
	with(scenario, { names = names, aimed = { nameplate1target = "player", nameplate2target = "player" } }, function(ns)
		cast("nameplate1")
		land(ns, nil)
		Mock.advance(0.5)
		cast("nameplate2")
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "somebody was owed with two casters aimed at you: " .. tostring(next(ns.owed))) end
		if trailHas(ns, "two or more players") == 0 then fail(scenario, "the trail does not say that two players cast it") end
	end)
end

-- ------------------------------------------------------- named once it has passed
do
	local scenario = "favour-caster: a cast with no target names them once the moment has passed"
	with(scenario, {}, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		cast("nameplate1")
		land(ns, nil)
		if owedBy(ns, anna) then fail(scenario, "named before the moment had passed") end
		Mock.runTimers(2)
		if not owedBy(ns, anna) then fail(scenario, "not named once the moment had passed: " .. said()) end
	end)
end

do
	local scenario = "favour-caster: two players casting it name nobody"
	local names = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bea", "Bold" },
		nameplate1target = { "Me", "Myself" }, nameplate2target = { "Me", "Myself" } }
	with(scenario, { names = names, aimed = { nameplate1target = "player", nameplate2target = "player" } }, function(ns)
		cast("nameplate1")
		cast("nameplate2")
		local text = land(ns, nil)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "somebody was owed with two casters: " .. tostring(next(ns.owed))) end
		if text:find("buffed you", 1, true) or said():find("buffed you", 1, true) then
			fail(scenario, "a line named somebody with two casters")
		end
		if not debugText(ns):find("more than one player", 1, true) then
			fail(scenario, "/manners debug does not say that two players cast it")
		end
	end)
end

do
	local scenario = "favour-caster: a second caster just after the landing still names nobody"
	local names = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bea", "Bold" } }
	with(scenario, { names = names }, function(ns)
		cast("nameplate1")
		land(ns, nil)
		Mock.advance(0.5)
		cast("nameplate2")
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "somebody was owed with a second caster: " .. tostring(next(ns.owed))) end
	end)
end

do
	local scenario = "favour-caster: a cast just after the buff lands names them"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		land(ns, nil)
		Mock.advance(0.5)
		cast("nameplate1")
		Mock.runTimers(2)
		if not owedBy(ns, anna) then fail(scenario, "a cast just after the landing named nobody: " .. said()) end
		if not said():find("buffed you", 1, true) then fail(scenario, "no line said who buffed you: " .. said()) end
	end)
end

do
	local scenario = "favour-caster: a cast outside the moment names nobody"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		land(ns, nil)
		Mock.advance(1.5)
		cast("nameplate1")
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "a cast outside the moment named " .. tostring(next(ns.owed))) end
	end)
end

do
	local scenario = "favour-caster: a cast from somebody on your ignore list names nobody"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED, ignored = { nameplate1 = true },
		thank = true, unseen = true, fromPlayer = true }, function(ns)
		cast("nameplate1")
		local text = land(ns, nil)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "somebody on the ignore list was owed") end
		if text:find("buffed you", 1, true) or said():find("buffed you", 1, true) then
			fail(scenario, "a line was said for somebody on the ignore list")
		end
		-- Every landing is judged over its window now, so the thank to nobody (Thank
		-- them even when I can't see who it was) goes as the buff lands, as it always
		-- did for a landing the cast watch could not name at that moment. It names
		-- nobody: what must never go is an emote aimed at the ignored player.
		for _, e in ipairs(emotes) do
			if e[2] ~= nil then fail(scenario, "an emote went at somebody on the ignore list: " .. tostring(e[2])) end
		end
		if not debugText(ns):find("on your ignore list", 1, true) then
			fail(scenario, "/manners debug does not say they are on the ignore list")
		end
	end)
end

do
	local scenario = "favour-caster: a cast of another buff names nobody"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		cast("nameplate1", INTELLECT)
		land(ns, nil, FORTITUDE)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "a cast of Arcane Intellect named " .. tostring(next(ns.owed))) end
	end)
end

do
	local scenario = "favour-caster: a cast at somebody else names nobody"
	local names = { nameplate1 = { "Anna", "Aim" }, nameplate1target = { "Cora", "Else" } }
	with(scenario, { names = names }, function(ns)
		cast("nameplate1")
		land(ns, nil)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "a cast at somebody else named " .. tostring(next(ns.owed))) end
	end)
end

do
	local scenario = "favour-caster: one cast seen under two tokens is one caster"
	local names = { nameplate1 = { "Anna", "Aim" }, target = { "Anna", "Aim" },
		nameplate1target = { "Me", "Myself" }, targettarget = { "Me", "Myself" } }
	with(scenario, { names = names, aimed = { nameplate1target = "player", targettarget = "player" } }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		-- The client gives one player the same GUID under every token that means them.
		local realGuid = _G.UnitGUID
		rawset(_G, "UnitGUID", function(unit, ...)
			if unit == "target" then unit = "nameplate1" end
			return realGuid(unit, ...)
		end)
		cast("nameplate1", FORTITUDE, "Cast-shared")
		-- Later than one cast's tokens arrive together, so only the cast guid says it is one.
		Mock.advance(0.6)
		cast("target", FORTITUDE, "Cast-shared")
		if ns.castWatch.seen ~= 1 then
			fail(scenario, ("one cast heard under two tokens was kept %d times"):format(ns.castWatch.seen))
		end
		land(ns, nil)
		Mock.runTimers(2)
		rawset(_G, "UnitGUID", realGuid)
		if not owedBy(ns, anna) then fail(scenario, "one cast under two tokens named nobody: " .. said()) end
	end)
end

do
	local scenario = "favour-caster: a cast by somebody who now wears a fresh one of it names nobody"
	with(scenario, {}, function(ns)
		-- They wear one that began just after they cast: their own, on themselves.
		-- Read straight off the caster by the cast watch's own question; the mock
		-- gives every other unit a Fortitude that ends heldFor seconds after the read,
		-- which puts its start just after the cast, with the timers run two seconds on.
		Mock.held = { [FORTITUDE] = true }
		Mock.heldDuration = 1800
		Mock.heldFor = 1800 - 1.8
		cast("nameplate1")
		land(ns, nil)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "a self-cast was taken for a favour: " .. tostring(next(ns.owed))) end
		-- A cast WAS seen, so neither the chat hint nor /manners debug may say that none was.
		if said():find("saw no player in sight", 1, true) then fail(scenario, "the hint says no cast was seen: " .. said()) end
		if not said():find("saw a cast at that moment", 1, true) then fail(scenario, "the hint does not say a cast was seen: " .. said()) end
		local text = debugText(ns)
		if text:find("no player in sight was seen casting", 1, true) then fail(scenario, "/manners debug says no cast was seen") end
		if not text:find("a cast was seen at that moment", 1, true) then fail(scenario, "/manners debug does not say a cast was seen: " .. text) end
	end)
end

do
	-- The reported case: a druid, and a priest's Fortitude, which is no buff of the
	-- druid's own class. Nothing is stubbed: the cast watch reads the caster's aura
	-- itself, and a caster who wears none is no self-cast.
	local scenario = "favour-caster: another class's buff with no target names the stranger once the moment has passed"
	with(scenario, { class = "DRUID" }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		cast("nameplate1")
		land(ns, nil)
		Mock.runTimers(2)
		if not owedBy(ns, anna) then fail(scenario, "a stranger's Fortitude on a druid named nobody: " .. said()) end
	end)
end

do
	local scenario = "favour-caster: an NPC casting it at that moment names nobody"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED, npc = { nameplate1 = true } }, function(ns)
		cast("nameplate1")
		land(ns, nil)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "an NPC's cast named " .. tostring(next(ns.owed))) end
		if trailHas(ns, "was not a player's") == 0 then fail(scenario, "the trail does not say the cast was no player's") end
	end)
end

do
	local scenario = "favour-caster: a group form of the buff names nobody"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		cast("nameplate1", PRAYER_FORTITUDE)
		land(ns, nil, FORTITUDE)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "a Prayer of Fortitude named " .. tostring(next(ns.owed))) end
	end)
end

do
	local scenario = "favour-caster: a ring too full to vouch for the moment names nobody"
	local names = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bea", "Bold" }, nameplate1target = { "Me", "Myself" } }
	for i = 3, 34 do names["nameplate" .. i] = { "Crowd" .. i, "Member" } end
	with(scenario, { names = names, aimed = AIMED }, function(ns)
		cast("nameplate2")
		for i = 3, 34 do cast("nameplate" .. i, INTELLECT) end
		cast("nameplate1")
		if ns.castWatch.seen < 33 then fail(scenario, "SKIPPED -- the casts were not all seen: " .. ns.castWatch.seen) return end
		land(ns, nil)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "a full ring named " .. tostring(next(ns.owed))) end
	end)
end

do
	local scenario = "favour-caster: a late-named favour after the thank to nobody is not thanked again"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED, thank = true, unseen = true, ask = true, fromPlayer = true }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		land(ns, nil)
		Mock.advance(0.5)
		cast("nameplate1")
		Mock.runTimers(2)
		if not owedBy(ns, anna) then fail(scenario, "SKIPPED -- the late cast named nobody: " .. said()) return end
		local waiting = trailHas(ns, "waiting for a press to thank")
		if waiting ~= 1 then fail(scenario, ("%d thanks were left waiting for a press, not one"):format(waiting)) end
	end)
end

do
	-- Thank them even when I can't see who it was is on, but that thank is held (you
	-- have somebody targeted): nothing went to nobody, so the caster the cast watch
	-- names afterwards is still thanked by name.
	local scenario = "favour-caster: a thank to nobody that never went does not stop the caster being thanked"
	local names = { nameplate1 = { "Anna", "Aim" }, target = { "Tara", "Target" } }
	with(scenario, { names = names, thank = true, unseen = true, fromPlayer = true }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		land(ns, nil)
		Mock.advance(0.5)
		cast("nameplate1")
		Mock.runTimers(3)
		if not owedBy(ns, anna) then fail(scenario, "SKIPPED -- the late cast named nobody: " .. said()) return end
		if #emotes == 0 then fail(scenario, "the caster was never thanked: " .. said()) end
	end)
end

do
	-- The same with Wait a moment before thanking on: the thank to nobody is queued
	-- behind its pause and then held (you target somebody meanwhile), so it never
	-- went, and the caster named afterwards is thanked by name.
	local scenario = "favour-caster: a queued thank to nobody that is held then does not stop the caster being thanked"
	with(scenario, { thank = true, unseen = true, fromPlayer = true }, function(ns)
		ns.db.profile.prompt.thankDelay = true
		local anna = ns.UnitFullName("nameplate1")
		local targeted = false
		local realExists = _G.UnitExists
		rawset(_G, "UnitExists", function(unit)
			if unit == "target" then return targeted end
			return realExists(unit)
		end)
		-- The shortest pause: held at one second, before the window closes at 1.1.
		local realRandom = math.random
		math.random = function() return 0 end
		land(ns, nil)
		math.random = realRandom
		targeted = true
		Mock.advance(0.5)
		cast("nameplate1")
		Mock.runTimers(0.55)
		targeted = false
		Mock.runTimers(0.6)
		Mock.runTimers(4)
		if not owedBy(ns, anna) then fail(scenario, "SKIPPED -- the late cast named nobody: " .. said()) return end
		if #emotes == 0 then fail(scenario, "the caster was never thanked: " .. said()) end
	end)
end

do
	local scenario = "favour-caster: a buff that landed too long ago to match a cast is in /manners debug"
	with(scenario, {}, function(ns)
		Mock.extraAuraDuration = 1800
		Mock.extraAuraUntil = GetTime() + 1800 - 20
		land(ns, nil)
		if not debugText(ns):find("nobody to buff back", 1, true) then
			fail(scenario, "/manners debug still says nobody buffed you: " .. said())
		end
	end)
end

do
	-- Companion.lua's frame hears UNIT_SPELLCAST_SUCCEEDED too: for the player's casts
	-- alone, and a cast by anybody else costs it no protected call.
	local scenario = "favour-caster: a cast by somebody else costs the pet's listener no protected call"
	with(scenario, {}, function(ns)
		local frame = ns.Pet and ns.Pet.frame
		if not (frame and frame.scripts and frame.scripts.OnEvent) then
			fail(scenario, "SKIPPED -- the pet's frame is not there")
			return
		end
		local heard = frame.unitEvents and frame.unitEvents.UNIT_SPELLCAST_SUCCEEDED
		if not (type(heard) == "table" and heard[1] == "player" and #heard == 1) then
			fail(scenario, "the pet's frame is not registered for the player's casts alone")
		end
		local count = 0
		local real = { pcall = _G.pcall, xpcall = _G.xpcall }
		for name, fn in pairs(real) do
			rawset(_G, name, function(...)
				if debug.traceback():find("Companion.lua", 1, true) then count = count + 1 end
				return fn(...)
			end)
		end
		local ok, err = real.pcall(frame.scripts.OnEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-pet", FIREBALL)
		for name, fn in pairs(real) do rawset(_G, name, fn) end
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
		if count ~= 0 then fail(scenario, ("somebody else's cast cost the pet's listener %d protected calls"):format(count)) end
	end)
end

do
	local scenario = "favour-caster: an unrelated cast costs the client nothing"
	local function counted(body)
		local calls = { UnitGUID = 0, UnitIsPlayer = 0, UnitName = 0, pcall = 0, xpcall = 0 }
		local real = { UnitGUID = _G.UnitGUID, UnitIsPlayer = _G.UnitIsPlayer, UnitName = _G.UnitName,
			pcall = _G.pcall, xpcall = _G.xpcall }
		for name, fn in pairs(real) do
			rawset(_G, name, function(...)
				-- Another listener on the same event (the pet's, Companion.lua) has its own
				-- Guard on every cast; only a protected call made from Favours.lua is counted.
				if (name ~= "pcall" and name ~= "xpcall") or debug.traceback():find("Favours.lua", 1, true) then
					calls[name] = calls[name] + 1
				end
				return fn(...)
			end)
		end
		local ok, err = real.pcall(body)
		for name, fn in pairs(real) do rawset(_G, name, fn) end
		if not ok then error(err, 0) end
		return calls
	end
	local function total(calls)
		return calls.UnitGUID + calls.UnitIsPlayer + calls.UnitName + calls.pcall + calls.xpcall
	end
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		local calls = counted(function() cast("nameplate1", FIREBALL) end)
		if total(calls) ~= 0 then
			fail(scenario, ("a Fireball cost the client %d guid, %d player, %d name, %d pcall calls"):format(
				calls.UnitGUID, calls.UnitIsPlayer, calls.UnitName, calls.pcall + calls.xpcall))
		end
	end)
	with(scenario, { names = AIMED_NAMES, aimed = AIMED, enabled = false }, function(ns)
		local calls = counted(function() cast("nameplate1", FORTITUDE) end)
		if total(calls) ~= 0 then
			fail(scenario, ("a cast with Manners off cost the client %d calls (%d pcall)"):format(
				total(calls), calls.pcall + calls.xpcall))
		end
	end)
end

do
	local scenario = "favour-caster: classic: the cast watch waits on the combat log"
	with(scenario, { flavour = "vanilla", class = "MAGE" }, function(ns)
		if not ns.combatLogArmed then fail(scenario, "SKIPPED -- the combat log was not armed on this client") return end
		if ns.castWatch.armed then fail(scenario, "the cast watch listens as well where the combat log names the caster") end
	end)
end

-- --------------------------------------------------------- what became of it
do
	local scenario = "favour-caster: debug: a favour that ran out is not 'nobody has buffed you'"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		cast("nameplate1")
		land(ns, nil)
		Mock.runTimers(2)
		if not owedBy(ns, anna) then fail(scenario, "SKIPPED -- the favour was not noted") return end
		Mock.advance(ns.db.profile.timing.reciprocateWindow + 1)
		ns.addon:Tick()
		local text = debugText(ns)
		if not text:find("it was not returned in time", 1, true) then fail(scenario, "/manners debug does not say the favour ran out: " .. text) end
		if text:find("nobody has buffed you recently", 1, true) then fail(scenario, "/manners debug says nobody has buffed you") end
	end)
end

do
	local scenario = "favour-caster: debug: a buff back says you buffed them first"
	with(scenario, { class = "MAGE" }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		local buff = ns.FindBuff("MAGE", "intellect")
		if not buff then fail(scenario, "SKIPPED -- no Arcane Intellect here") return end
		local entry = H.inQueue(ns)[anna]
		if not (entry and entry.buff and entry.buff.key == "intellect") then fail(scenario, "SKIPPED -- Anna was not offered Arcane Intellect") return end
		local info = ns.BuffInfo(buff)
		if not H.pressAndSend(ns, entry, (info and info.topRank) or buff.ranks[1]) then fail(scenario, "SKIPPED -- the press went nowhere") return end
		Mock.advance(60)
		wipe(ns.tried)
		Mock.held = {}
		for _, id in ipairs(buff.auraIds) do Mock.held[id] = true end
		Mock.heldFor = (ns.BuffSeconds(buff) or 3600) - 60
		Mock.heldSource = nil
		ns.ForgetUnitAuras(ns.plain(UnitGUID("nameplate1")))
		favourFrom(ns, "nameplate1", buff.ranks[1], 7301)
		local text = debugText(ns)
		if ns.owed[anna] then fail(scenario, "SKIPPED -- a buff back was filed as a favour owed") return end
		if not text:find("you had buffed them first", 1, true) then fail(scenario, "/manners debug does not say you buffed them first: " .. text) end
		Mock.held = {}
	end)
end

-- ---------------------------------------------------------------- the hint
do
	local scenario = "favour-caster: plates on: a buff with nobody to name says so once"
	with(scenario, {}, function(ns)
		land(ns, nil)
		Mock.runTimers(2)
		local first = said()
		if not first:find("Somebody just put a buff on you", 1, true) then fail(scenario, "nothing was said when nobody could be named: " .. first) return end
		Mock.printed = {}
		land(ns, nil)
		Mock.runTimers(2)
		if said():find("Somebody just put a buff on you", 1, true) then fail(scenario, "the line was said a second time") end
	end)
end

do
	local scenario = "favour-caster: plates off: the new line stays quiet"
	with(scenario, { plates = "0" }, function(ns)
		land(ns, nil)
		Mock.runTimers(2)
		local text = said()
		if text:find("Somebody just put a buff on you", 1, true) then fail(scenario, "the new line was said with the nameplates off: " .. text) end
		if not text:find("the game would not say who", 1, true) then fail(scenario, "the old line was not said: " .. text) end
	end)
end

do
	local scenario = "favour-caster: a new buff that is no class buff is on the trail"
	with(scenario, { fromPlayer = true }, function(ns)
		if ns.ALL_BUFF_IDS[RENEW] then fail(scenario, "SKIPPED -- Renew is a class buff here") return end
		land(ns, "nameplate1", RENEW)
		land(ns, "nameplate1", RENEW)
		local n = trailHas(ns, "is not a class buff")
		if n ~= 1 then fail(scenario, ("%d trail lines about a buff that is no class buff, not one"):format(n)) end
	end)
end

do
	local scenario = "favour-caster: the full check-up names the last favour by an alias"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		cast("nameplate1")
		land(ns, nil)
		wipe(ns.owed)
		ns.lastFavour = { name = "Zed Unique", key = FORTITUDE, at = GetTime(), fate = "covered" }
		local report = ns.FullReport()
		if report:find("Zed Unique", 1, true) then fail(scenario, "the check-up names the last favour") end
		if report:find("Anna Aim", 1, true) then fail(scenario, "the check-up names Anna") end
	end)
end

do
	local scenario = "favour-caster: a secret spell or token on a cast is no error"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		Mock.frameEvent("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-s1", Mock.SECRET)
		Mock.frameEvent("UNIT_SPELLCAST_SUCCEEDED", Mock.SECRET, "Cast-s2", FORTITUDE)
		Mock.frameEvent("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", Mock.SECRET, FORTITUDE)
		if #(ns.errors or {}) ~= 0 then fail(scenario, "a secret value on a cast threw") end
		if ns.castWatch.seen ~= 1 then
			fail(scenario, ("%d casts kept: a secret spell or token was kept, or a plain one dropped"):format(ns.castWatch.seen))
		end
	end)
end

-- ------------------------------------------------ the wrong person is worse than none
-- Each of these is a sequence the review found that named a stranger who had not
-- buffed you (or a bystander): now it names nobody, or the right person.

do
	-- The client withholds whom Anna targets: the cast may be at you, at somebody
	-- else, or at nothing. A withheld answer is not "no target".
	local scenario = "favour-caster: a cast whose target is withheld names nobody"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		local realExists = _G.UnitExists
		rawset(_G, "UnitExists", function(unit)
			if unit == "nameplate1target" then return Mock.SECRET end
			return realExists(unit)
		end)
		cast("nameplate1")
		land(ns, nil)
		Mock.runTimers(2)
		rawset(_G, "UnitExists", realExists)
		if next(ns.owed) then fail(scenario, "a cast with a withheld target named " .. tostring(next(ns.owed))) end
		if trailHas(ns, "could not tell who made it") == 0 then fail(scenario, "the trail does not say the cast could not be read") end
	end)
end

do
	-- The target exists, and whether it is you is withheld.
	local scenario = "favour-caster: a cast at a target who may be you names nobody"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		local realIsUnit = _G.UnitIsUnit
		rawset(_G, "UnitIsUnit", function(a, b)
			if a == "nameplate1target" and b == "player" then return Mock.SECRET end
			return realIsUnit(a, b)
		end)
		cast("nameplate1")
		land(ns, nil)
		Mock.runTimers(2)
		rawset(_G, "UnitIsUnit", realIsUnit)
		if next(ns.owed) then fail(scenario, "a cast at a withheld target named " .. tostring(next(ns.owed))) end
	end)
end

do
	-- With the friendly nameplates off the cast seen is a bystander's as likely as the
	-- caster's: Anna, with no target, is not named (plates on, the same sequence names
	-- her: "a cast with no target names them once the moment has passed").
	local scenario = "favour-caster: plates off: a cast with no target names nobody"
	with(scenario, { plates = "0" }, function(ns)
		cast("nameplate1")
		land(ns, nil)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "with the nameplates off, a cast with no target named " .. tostring(next(ns.owed))) end
		if trailHas(ns, "out of sight") == 0 then fail(scenario, "the trail does not say others may have cast it out of sight") end
	end)
end

do
	local scenario = "favour-caster: plates off: a cast aimed at you still names them"
	with(scenario, { plates = "0", names = AIMED_NAMES, aimed = AIMED }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		cast("nameplate1")
		land(ns, nil)
		Mock.runTimers(2)
		if not owedBy(ns, anna) then fail(scenario, "a cast aimed at you was not enough with the nameplates off: " .. said()) end
	end)
end

do
	-- The caster's aura list is hidden from you (the client returns nothing for it):
	-- "none of the ids found" says nothing about whether they cast it on themselves.
	local scenario = "favour-caster: a caster whose auras are not shown names nobody"
	with(scenario, {}, function(ns)
		local had, api = rawget(_G, "C_UnitAuras"), _G.C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetAuraDataByIndex = function(unit, ...)
				if unit == "nameplate1" then return nil end
				return api.GetAuraDataByIndex(unit, ...)
			end,
		}, { __index = api }))
		cast("nameplate1")
		land(ns, nil)
		Mock.runTimers(2)
		rawset(_G, "C_UnitAuras", had)
		if next(ns.owed) then fail(scenario, "a caster whose auras are hidden was taken for a stranger who cast it: " .. tostring(next(ns.owed))) end
		if trailHas(ns, "out of sight") == 0 then fail(scenario, "the trail does not say others may have cast it out of sight") end
	end)
end

do
	-- Two players, one cast GUID (a client that reuses or blanks it): two casters.
	local scenario = "favour-caster: two players under one cast guid name nobody"
	local names = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bea", "Bold" },
		nameplate1target = { "Me", "Myself" }, nameplate2target = { "Me", "Myself" } }
	with(scenario, { names = names, aimed = { nameplate1target = "player", nameplate2target = "player" } }, function(ns)
		cast("nameplate1", FORTITUDE, "Cast-same")
		cast("nameplate2", FORTITUDE, "Cast-same")
		land(ns, nil)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "two players with one cast guid named " .. tostring(next(ns.owed))) end
	end)
end

do
	-- You recast your own Fortitude on yourself and the game withholds who made the
	-- aura; Anna, nearby, cast hers at you a moment before.
	local scenario = "favour-caster: your own recast beside a stranger's cast names nobody"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		cast("nameplate1")
		cast("player")
		land(ns, Mock.SECRET)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "a recast of your own buff named " .. tostring(next(ns.owed))) end
	end)
end

do
	local scenario = "favour-caster: your own cast of the buff is the only one seen and names nobody"
	with(scenario, {}, function(ns)
		cast("player")
		land(ns, Mock.SECRET)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "your own cast named " .. tostring(next(ns.owed))) end
		if trailHas(ns, "was your own") == 0 then fail(scenario, "the trail does not say the cast seen was your own") end
	end)
end

-- --------------------------------------------- what the check-up and the hint say
do
	-- Where the combat log is the source of record, a landing is not filed as unnamed
	-- by the cast watch that is not listening.
	local scenario = "favour-caster: classic: a landing is not called unnamed where the combat log names the caster"
	with(scenario, { flavour = "vanilla", class = "MAGE" }, function(ns)
		if not ns.combatLogArmed then fail(scenario, "SKIPPED -- the combat log was not armed on this client") return end
		if not ns.ALL_BUFF_IDS[FORTITUDE] then fail(scenario, "SKIPPED -- no Fortitude on this client") return end
		land(ns, nil)
		Mock.runTimers(2)
		if ns.lastFavour and ns.lastFavour.fate == "unnamed" then
			fail(scenario, "the cast watch called a landing unnamed though it was not listening")
		end
	end)
end

do
	-- Not while the landing waits for its window: its fate is the decision's.
	local scenario = "favour-caster: a landing waiting for its window is not yet called unnamed"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		cast("nameplate1")
		land(ns, nil)
		if ns.lastFavour then fail(scenario, "the check-up already had a fate for it: " .. tostring(ns.lastFavour.fate)) end
		Mock.runTimers(2)
		if not (ns.lastFavour and ns.lastFavour.fate == "owed") then
			fail(scenario, "once the window closed it was not owed: " .. tostring(ns.lastFavour and ns.lastFavour.fate))
		end
	end)
end

do
	-- An aura the client plainly says is an NPC's is no favour and no unnamed buff.
	local scenario = "favour-caster: a landing that is plainly an NPC's is not called unnamed"
	with(scenario, { fromPlayer = false }, function(ns)
		land(ns, nil)
		Mock.runTimers(2)
		if ns.lastFavour then fail(scenario, "an NPC's aura was filed as " .. tostring(ns.lastFavour.fate)) end
	end)
end

do
	-- The nameplates line says nobody could be named: not while the cast watch might
	-- still name them, and never when it does.
	local scenario = "favour-caster: plates off: the nameplates line waits for the decision and is not said for a named caster"
	with(scenario, { plates = "0", names = AIMED_NAMES, aimed = AIMED, fromPlayer = true }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		cast("nameplate1")
		local text = land(ns, nil)
		if text:find("the game would not say who", 1, true) then fail(scenario, "the nameplates line was said as the buff landed: " .. text) end
		Mock.runTimers(2)
		if not owedBy(ns, anna) then fail(scenario, "SKIPPED -- the caster was not named: " .. said()) return end
		if said():find("the game would not say who", 1, true) then fail(scenario, "the nameplates line was said for a named caster: " .. said()) end
	end)
end

do
	local scenario = "favour-caster: plates off: a landing nobody names says the nameplates line once its window closes"
	with(scenario, { plates = "0" }, function(ns)
		local text = land(ns, nil)
		if text:find("the game would not say who", 1, true) then fail(scenario, "said before the window closed: " .. text) end
		Mock.runTimers(2)
		if not said():find("the game would not say who", 1, true) then fail(scenario, "not said once nobody was named: " .. said()) end
	end)
end

do
	-- Four landings wait at most: a fifth judges the oldest on the casts the ring holds
	-- (Anna's, aimed at you) rather than giving up on it.
	local scenario = "favour-caster: a fifth landing judges the oldest waiting one on the casts seen"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		cast("nameplate1")
		for _ = 1, 4 do land(ns, nil) end
		if owedBy(ns, anna) then fail(scenario, "SKIPPED -- named before the queue was full") return end
		land(ns, nil)
		if not owedBy(ns, anna) then fail(scenario, "the oldest landing was given up on, not judged: " .. said()) end
	end)
end

-- ------------------------------------------------------------ the cost of a cast
do
	-- Nothing could use a named caster (People who buff me and the thank emote and
	-- whisper all off): a class buff's cast asks the client nothing.
	local scenario = "favour-caster: a cast nothing could use costs the client nothing"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		ns.db.profile.sources.owed = false
		ns.db.profile.prompt.thankEmote = false
		ns.db.profile.prompt.thankWhisper = false
		local calls = 0
		local real = { UnitGUID = _G.UnitGUID, UnitIsPlayer = _G.UnitIsPlayer, UnitName = _G.UnitName, UnitExists = _G.UnitExists }
		for name, fn in pairs(real) do
			rawset(_G, name, function(...) calls = calls + 1 return fn(...) end)
		end
		local ok, err = pcall(cast, "nameplate1")
		for name, fn in pairs(real) do rawset(_G, name, fn) end
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
		if calls ~= 0 then fail(scenario, ("a cast nothing could use cost the client %d calls"):format(calls)) end
	end)
end

do
	-- The cast watch asks whether they are a player and what their GUID is once for
	-- a cast, not once for the ring entry and again for the name.
	local scenario = "favour-caster: a cast asks the client for the caster's guid and kind once"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		local guids, kinds = 0, 0
		local realGuid, realKind = _G.UnitGUID, _G.UnitIsPlayer
		rawset(_G, "UnitGUID", function(unit, ...) if unit == "nameplate1" then guids = guids + 1 end return realGuid(unit, ...) end)
		rawset(_G, "UnitIsPlayer", function(unit, ...) if unit == "nameplate1" then kinds = kinds + 1 end return realKind(unit, ...) end)
		local ok, err = pcall(cast, "nameplate1")
		rawset(_G, "UnitGUID", realGuid)
		rawset(_G, "UnitIsPlayer", realKind)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
		if guids ~= 1 or kinds ~= 1 then
			fail(scenario, ("one cast asked UnitGUID %d times and UnitIsPlayer %d times, not once each"):format(guids, kinds))
		end
	end)
end

do
	-- A window already closed when the scan files the landing (the aura's own timer
	-- puts its landing three seconds back) is decided on the next frame, not inside
	-- the scan that is filing it.
	local scenario = "favour-caster: a window already closed is decided after the scan, not inside it"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		cast("nameplate1")
		Mock.advance(3)
		Mock.extraAuraDuration = 1800
		Mock.extraAuraUntil = GetTime() + 1800 - 2.9
		land(ns, nil)
		if owedBy(ns, anna) then fail(scenario, "decided inside the scan that filed the landing") return end
		Mock.runTimers(0)
		if not owedBy(ns, anna) then fail(scenario, "never decided: " .. said()) end
	end)
end

do
	-- A landing too old to match any cast is never parked, so the scan says the
	-- nameplates line itself.
	local scenario = "favour-caster: plates off: a landing too old to match a cast says the nameplates line at once"
	with(scenario, { plates = "0" }, function(ns)
		Mock.extraAuraDuration = 1800
		Mock.extraAuraUntil = GetTime() + 1800 - 20
		local text = land(ns, nil)
		if not text:find("the game would not say who", 1, true) then fail(scenario, "not said: " .. text) end
	end)
end
