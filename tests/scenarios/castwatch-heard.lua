-- What the cast watch hears (Favours.lua, GitHub issue 26): on WoW Forever a
-- stranger's cast may reach UNIT_SPELLCAST_SUCCEEDED with its spell, its caster
-- or its cast id withheld, and "0 seen" could not tell a missing event from a
-- withheld one. The watch now counts every cast by another player it hears and
-- how much of it was withheld, reads a spell out of a plain cast id where the
-- spell is withheld, and counts a cast nobody can read as a moment it cannot
-- vouch for (the one-person rule). A buff read long after it landed says so
-- rather than "no player in sight".
--
-- Every scenario name starts with "castwatch-heard:" so the mutations in
-- tests/mutations/castwatch-heard.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom = H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom

local TOUCHED = { "IsInInstance", "DoEmote", "C_ChatInfo", "GetCVar", "UnitIsUnit", "UnitIsPlayer",
	"C_FriendList", "UnitGUID", "UnitName", "UnitExists", "UnitCanAttack" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

-- Fortitude, Arcane Intellect and the group form of Fortitude as this client numbers
-- them (set in with(), once the addon has loaded); Forever keeps 10938, 10157, 21562.
local FORTITUDE, INTELLECT, PRAYER_FORTITUDE = 10938, 10157, 21562
local function numberBuffs(ns)
	local fort = ns.FindBuff("PRIEST", "fortitude")
	local int = ns.FindBuff("MAGE", "intellect")
	FORTITUDE = ns.BUFF_BY_ID[10938] and 10938 or (fort and fort.ranks[1]) or 10938
	INTELLECT = ns.BUFF_BY_ID[10157] and 10157 or (int and int.ranks[1]) or 10157
	PRAYER_FORTITUDE = fort and fort.group and fort.group[#fort.group] or nil
end

local emotes = {}
local npc = {}
local aimed = {}
local hostile = {}

-- One session. opts: class (PRIEST), names (unit -> name; the units that exist
-- besides you, nameplate1 by default), aimed (unit -> the unit it targets, as
-- { nameplate1target = "player" }), plates (the friendly-nameplates CVar, "1"),
-- ignored (set of tokens on your ignore list), npc (set of tokens that are no
-- player), fromPlayer (the aura says it is a player's), thank (the emote on),
-- unseen (Thank them even when I can't see who it was), ask (Ask me before
-- thanking), delay (the pause before a thank), flavour, enabled (false to switch Manners off).
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
	emotes, npc, aimed, hostile = {}, opts.npc or {}, opts.aimed or {}, opts.hostile or {}
	rawset(_G, "UnitCanAttack", function(_, unit) return hostile[unit] == true end)
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
		numberBuffs(ns)
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.owed = true
		db.prompt.thankEmote = opts.thank == true
		db.prompt.thankUnseen = opts.unseen == true
		db.prompt.thankAsk = opts.ask == true
		if opts.delay ~= nil then db.prompt.thankDelay = opts.delay end
		primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
		-- A classic client with its combat log armed has the log name the caster itself.
		if opts.flavour ~= "vanilla" and ns.combatLogArmed and not ns.castWatch.armed then return end
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

local RENEW, FIREBALL = 139, 133

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

do
	local scenario = "castwatch-heard: a stranger's withheld cast is counted heard"
	with(scenario, {}, function(ns)
		local cw = ns.castWatch
		cast("nameplate1", Mock.SECRET, Mock.SECRET)
		if cw.heard ~= 1 then fail(scenario, "heard " .. tostring(cw.heard) .. ", not 1") end
		if cw.noSpell ~= 1 then fail(scenario, "spell withheld counted " .. tostring(cw.noSpell)) end
		if cw.noGuid ~= 1 then fail(scenario, "cast id withheld counted " .. tostring(cw.noGuid)) end
		if cw.noUnit ~= 0 then fail(scenario, "caster withheld counted " .. tostring(cw.noUnit) .. " for a plain caster") end
	end)
end

do
	local scenario = "castwatch-heard: a cast with its caster withheld is counted"
	with(scenario, {}, function(ns)
		local cw = ns.castWatch
		cast(Mock.SECRET, FORTITUDE, "Cast-plain")
		if cw.heard ~= 1 then fail(scenario, "heard " .. tostring(cw.heard) .. ", not 1") end
		if cw.noUnit ~= 1 then fail(scenario, "caster withheld counted " .. tostring(cw.noUnit)) end
		if cw.noSpell ~= 0 or cw.noGuid ~= 0 then fail(scenario, "the spell or the id was counted withheld") end
	end)
end

do
	local scenario = "castwatch-heard: your own casts are not counted heard"
	with(scenario, {}, function(ns)
		cast("player", FORTITUDE, "Cast-own")
		cast("pet", FORTITUDE, "Cast-pet")
		if ns.castWatch.heard ~= 0 then fail(scenario, "heard " .. tostring(ns.castWatch.heard) .. " of your own casts") end
	end)
end

do
	local scenario = "castwatch-heard: a withheld spell is read from a plain cast id and names the caster"
	with(scenario, {}, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		cast("nameplate1", Mock.SECRET, "Cast-3-4170-0-1-" .. FORTITUDE .. "-0000AB12CD")
		land(ns, nil)
		Mock.runTimers(2)
		if ns.castWatch.fromGuid ~= 1 then fail(scenario, "spells read from the cast id: " .. tostring(ns.castWatch.fromGuid)) end
		if ns.owed[anna] == nil then fail(scenario, "Anna was not owed: " .. said()) end
	end)
end

do
	local scenario = "castwatch-heard: a cast id of another shape reads no spell"
	with(scenario, {}, function(ns)
		cast("nameplate1", Mock.SECRET, "Cast-3-1-0-" .. FORTITUDE .. "-00AB")
		land(ns, nil)
		Mock.runTimers(2)
		if ns.castWatch.fromGuid ~= 0 then fail(scenario, "a spell was read from a short cast id") end
		if next(ns.owed) then fail(scenario, "somebody was named from a cast id that carries no spell: " .. tostring(next(ns.owed))) end
	end)
end

do
	local scenario = "castwatch-heard: a withheld cast in the window names nobody"
	local names = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bea", "Bold" },
		nameplate1target = { "Me", "Myself" } }
	with(scenario, { names = names, aimed = { nameplate1target = "player" } }, function(ns)
		cast("nameplate1")
		cast("nameplate2", Mock.SECRET, Mock.SECRET)
		land(ns, nil)
		Mock.runTimers(2)
		if next(ns.owed) then fail(scenario, "somebody was owed beside a cast nobody could read: " .. tostring(next(ns.owed))) end
		if trailHas(ns, "could not tell who made it") == 0 then fail(scenario, "the trail does not say it could not tell who made it") end
	end)
end

do
	local scenario = "castwatch-heard: a withheld cast from a mob does not stop a stranger being named"
	local names = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Gnarl", "Grim" } }
	with(scenario, { names = names, hostile = { nameplate2 = true } }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		cast("nameplate1")
		cast("nameplate2", Mock.SECRET, Mock.SECRET)
		land(ns, nil)
		Mock.runTimers(2)
		if ns.owed[anna] == nil then fail(scenario, "Anna was not owed beside a mob's hidden cast: " .. said()) end
	end)
end

do
	local scenario = "castwatch-heard: /manners debug and the bug report carry what was heard"
	with(scenario, {}, function(ns)
		cast("nameplate1", Mock.SECRET, Mock.SECRET)
		cast("nameplate2", Mock.SECRET, Mock.SECRET)
		local text = debugText(ns)
		if not text:find("2 heard (2 with the spell withheld", 1, true) then fail(scenario, "/manners debug does not count what was heard: " .. text) end
		local report = ns.FullReport()
		if not report:find("cast watch (casts from players and mobs, once per token): 2 heard, 2 spell withheld", 1, true) then
			fail(scenario, "the check-up does not carry the count")
		end
		-- A favour on file: the game's own rule for its spell has a line.
		land(ns, nil)
		Mock.runTimers(2)
		if not debugText(ns):find("the game's rule for spell", 1, true) then fail(scenario, "no line for the game's rule on the spell") end
	end)
end

do
	local scenario = "castwatch-heard: a buff read long after it landed says so"
	with(scenario, {}, function(ns)
		Mock.extraAuraDuration = 300
		Mock.extraAuraUntil = Mock.now + 290
		land(ns, nil)
		if trailHas(ns, "first read it 10 s") == 0 then fail(scenario, "the trail does not say how late it was read") end
		if ns.castWatch.old ~= 1 then fail(scenario, "read too late counted " .. tostring(ns.castWatch.old)) end
		local text = debugText(ns)
		if not text:find("10 seconds after it landed", 1, true) then fail(scenario, "/manners debug does not say it was read late: " .. text) end
		if text:find("no player in sight was seen casting", 1, true) then fail(scenario, "/manners debug still blames the casts: " .. text) end
	end)
end
