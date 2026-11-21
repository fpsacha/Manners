-- Naming who buffed you from the casts seen at that moment (GitHub issue 26).
-- On WoW Forever, with no combat log, a stranger's buff on you can arrive with
-- sourceUnit nil or withheld even with the friendly nameplates on, and nothing
-- was owed. Favours.lua's cast watch keeps the class-buff casts other players
-- make in sight (UNIT_SPELLCAST_SUCCEEDED, filtered by one table lookup) and a
-- landing that names nobody asks it who cast that buff in the second either
-- side: exactly one player, or nobody is named. A cast aimed at you names them
-- at once; one with no target waits for the window to close and is judged
-- then, and only when the caster does not freshly wear the buff themselves.
-- And /manners debug says what became of the last favour, so a favour let go
-- on purpose is not read as "nobody has buffed you".
--
-- Every scenario name starts with "favour-caster:" so the mutations in
-- tests/mutations/favour-caster.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom = H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom

local TOUCHED = { "IsInInstance", "DoEmote", "C_ChatInfo", "GetCVar", "UnitIsUnit", "UnitIsPlayer",
	"C_FriendList", "UnitGUID", "UnitName" }
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

-- -------------------------------------------------------------- named at once
do
	local scenario = "favour-caster: a cast aimed at you names them as the buff lands"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		cast("nameplate1")
		local text = land(ns, nil)
		if not owedBy(ns, anna) then fail(scenario, "nobody was owed when the buff landed: " .. text) end
		if not text:find("buffed you", 1, true) then fail(scenario, "no line said who buffed you: " .. text) end
		if ns.castWatch.named ~= 1 then fail(scenario, "the count of names read: " .. tostring(ns.castWatch.named)) end
	end)
end

do
	local scenario = "favour-caster: a withheld caster is named from their cast"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		cast("nameplate1")
		local text = land(ns, Mock.SECRET)
		if not owedBy(ns, anna) then fail(scenario, "a withheld caster was not named from the cast: " .. text) end
	end)
end

-- ------------------------------------------------------- named once it has passed
do
	local scenario = "favour-caster: a cast with no target names them once the moment has passed"
	with(scenario, {}, function(ns)
		ns.UnitHasBuff = function() return false end
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
		ns.UnitHasBuff = function() return false end
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
		ns.UnitHasBuff = function() return false end
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
		if #emotes ~= 0 then fail(scenario, "an emote went to somebody on the ignore list or to nobody") end
		if not debugText(ns):find("on your ignore list", 1, true) then
			fail(scenario, "/manners debug does not say they are on the ignore list")
		end
	end)
end

do
	local scenario = "favour-caster: a cast of another buff names nobody"
	with(scenario, { names = AIMED_NAMES, aimed = AIMED }, function(ns)
		ns.UnitHasBuff = function() return false end
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
		ns.UnitHasBuff = function() return false end
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
		cast("nameplate1", FORTITUDE, "Cast-shared")
		cast("target", FORTITUDE, "Cast-shared")
		local text = land(ns, nil)
		if not owedBy(ns, anna) then fail(scenario, "one cast under two tokens named nobody: " .. text) end
	end)
end

do
	local scenario = "favour-caster: a cast by somebody who now wears a fresh one of it names nobody"
	with(scenario, {}, function(ns)
		local at
		-- They wear one that began just after they cast: their own, on themselves.
		-- Said only to the cast watch's own question: asked the same later, the favour
		-- would be let go as already covered, which is another matter.
		ns.UnitHasBuff = function()
			if not debug.traceback():find("SelfCast", 1, true) then return false end
			return true, 1800 - (GetTime() - at - 0.2), false, false, 1800
		end
		at = GetTime()
		cast("nameplate1")
		land(ns, nil)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "a self-cast was taken for a favour: " .. tostring(next(ns.owed))) end
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
		ns.UnitHasBuff = function() return false end
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
