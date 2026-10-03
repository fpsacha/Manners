-- "/thank people who buff me" for everybody: the thank answers being buffed,
-- not the debt, so a character with nothing to give back (a rogue, a hunter,
-- a warrior with no shout yet) and a player with People who buff me off thank
-- too, while a debt is still only filed the way it always was. Noticing a
-- buff reads who cast it only while one of the two switches would use it.
--
-- The options follow: What I say is there for a hunter or a rogue with the
-- /thank alone on it, the switch is live with People who buff me off, and a
-- mage's page is what it was.
--
-- Every scenario name starts with "thank-everyone:" so the mutations in
-- tests/mutations/thank-everyone.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt, primeAuras, favourFrom =
	H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom

-- Aspect of the Hawk and of the Monkey: a hunter with these has a prompt of
-- her own (Myself), and still nothing for anybody else.
local HAWK, MONKEY = 13165, 13163
-- Power Word: Fortitude, a class buff; Rejuvenation, a heal that is not one.
local FORTITUDE, REJUVENATION = 10938, 774

local PEOPLE = {
	nameplate1 = { "Anna", "Aim" },
	nameplate2 = { "Bo", "Brisk" },
	nameplate3 = { "Cy", "Cole" },
}

-- Globals the scenarios replace, put back after each.
local TOUCHED = { "IsInInstance", "DoEmote", "IsSpellKnown", "IsPlayerSpell" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

-- Every emote made, as { emote, target }.
local emotes = {}
local function record(emote, target) emotes[#emotes + 1] = { emote, target } end
local function outdoors() return false, "none" end
local function said() return table.concat(Mock.printed, "\n") end

local function thanked(target)
	local n = 0
	for _, e in ipairs(emotes) do
		if e[1] == "THANK" and (target == nil or e[2] == target) then n = n + 1 end
	end
	return n
end

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- The class, and the spells it knows (by id) when that is not the mock's own.
local function become(opts)
	Mock.class = opts.class or "MAGE"
	if opts.known then
		local set = {}
		for _, id in ipairs(opts.known) do set[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return set[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return set[id] == true end)
	end
end

-- One scenario: the class, three strangers on nameplates, outdoors and able to
-- emote. With opts.login the body drives the login itself; otherwise the addon
-- is up, /thank on unless opts.thank is false, People who buff me as opts.owed
-- says (the default otherwise), and the baseline of your own buffs settled.
-- Everything put back whether it finished or threw.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.nameplates = { "nameplate1", "nameplate2", "nameplate3" }
	become(opts)
	emotes = {}
	rawset(_G, "IsInInstance", outdoors)
	rawset(_G, "DoEmote", record)
	local undo = strangers(PEOPLE)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		if not opts.login then
			freshPrompt(ns, scenario)
			local db = ns.db.profile
			db.prompt.thankEmote = opts.thank ~= false
			if opts.owed ~= nil then db.sources.owed = opts.owed end
			primeAuras(ns)
			if not ns.auraScan.primed then
				fail(scenario, "SKIPPED -- the baseline never settled")
				return
			end
		end
		body(ns)
		guarded(scenario, ns)
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A buff landing from `unit`, under an instance id never used before.
local nextId = 7000
local function favour(ns, unit, spell)
	nextId = nextId + 1
	return favourFrom(ns, unit, spell or FORTITUDE, nextId)
end

-- The unit APIs Sight, the debt and the thank ask about a caster.
local UNIT_CALLS = { "UnitIsUnit", "UnitIsPlayer", "UnitName", "UnitGUID", "UnitClass", "UnitExists",
	"UnitInParty", "UnitInRaid", "UnitPowerMax", "UnitPowerType", "UnitIsPVP", "UnitIsPVPFreeForAll" }

-- How many times anything asked a unit API about `token` while fn ran: each
-- global swapped for a counter and put back, as perf-budget.lua counts pcall.
local function lookups(token, fn)
	local saved, count = {}, 0
	for _, name in ipairs(UNIT_CALLS) do
		local real = rawget(_G, name)
		if type(real) == "function" then
			saved[name] = real
			rawset(_G, name, function(unit, ...)
				if unit == token then count = count + 1 end
				return real(unit, ...)
			end)
		end
	end
	local ok, err = pcall(fn)
	for name, real in pairs(saved) do rawset(_G, name, real) end
	if not ok then error(err, 0) end
	return count
end

-- Nobody of that name waits on the prompt.
local function queued(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return true end
	end
	return false
end

-- ------------------------------------------------------------------ login
-- A class with nothing to give still listens: UNIT_AURA is registered, the
-- scanner runs and the baseline settles on its own timer, as for a mage.
for _, case in ipairs({
	{ class = "ROGUE", label = "a rogue" },
	{ class = "HUNTER", label = "a hunter", known = { HAWK, MONKEY } },
}) do
	local scenario = "thank-everyone: " .. case.label .. "'s login watches her buffs"
	with(scenario, { class = case.class, known = case.known, login = true }, function(ns)
		local addon = ns.addon
		addon:OnInitialize()
		addon:OnEnable()
		addon:PLAYER_ENTERING_WORLD()
		if ns.caps.hasClassBuffs then
			fail(scenario, "SKIPPED -- " .. case.label .. " has class buffs here")
			return
		end
		if not Mock.registeredEvents.UNIT_AURA then
			fail(scenario, "UNIT_AURA is not registered for " .. case.label)
		end
		if not addon.scanTimer then fail(scenario, "the scanner never started for " .. case.label) end
		-- Nothing but the settle timer asks for the second reading.
		Mock.runTimers(0.3)
		if not ns.auraScan.primed then
			fail(scenario, case.label .. "'s baseline never settled after login")
			return
		end
		ns.db.profile.prompt.thankEmote = true
		Mock.advance(1)
		favour(ns, "nameplate1")
		if thanked("nameplate1") ~= 1 then
			fail(scenario, case.label .. " was not thanked for after login: " .. said())
		end
	end)
end

-- ------------------------------------------------------------------ nothing to give
-- Thanked, and nothing else: no debt, nobody on the prompt for it, no line
-- about returning it. Her /manners debug says the /thank is on and who it
-- last went to, since nothing else would. A warrior who has not learned her
-- shout has class buffs on paper and nothing to cast, like the other two.
for _, case in ipairs({
	{ class = "ROGUE", label = "a rogue", whose = "a rogue's" },
	{ class = "HUNTER", label = "a hunter", whose = "a hunter's", known = { HAWK, MONKEY } },
	{ class = "WARRIOR", label = "a warrior with no shout yet", whose = "a shoutless warrior's" },
}) do
	local scenario = "thank-everyone: " .. case.label .. " thanks a player who buffs her, and owes nothing"
	with(scenario, { class = case.class, known = case.known }, function(ns)
		if #ns.CastableBuffs() > 0 then
			fail(scenario, "SKIPPED -- " .. case.label .. " has a buff to cast here")
			return
		end
		local anna = ns.UnitFullName("nameplate1")
		local text = favour(ns, "nameplate1")
		if thanked("nameplate1") ~= 1 then
			fail(scenario, case.whose .. " favour was not thanked: " .. text)
		end
		if next(ns.owed) then
			fail(scenario, case.label .. " was left owing " .. tostring(next(ns.owed)))
		end
		if queued(ns, anna) then
			fail(scenario, "the player who buffed " .. case.label .. " is on the prompt")
		end
		if text:find("buffed you", 1, true) then
			fail(scenario, case.label .. " was told about returning a favour: " .. text)
		end
		Mock.advance(4)
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("thank with an emote: |cff00ff00on", 1, true)
			or not said():find("last thanked: |cffffffff" .. tostring(anna) .. "|r, 4s ago", 1, true) then
			fail(scenario, "/manners debug does not show " .. case.whose .. " /thank: " .. said())
		end
	end)
end

-- ------------------------------------------------------------------ owed off
-- A mage who thanks people without keeping count: no debt, no line, a thank.
do
	local scenario = "thank-everyone: a mage with People who buff me off still thanks"
	with(scenario, { owed = false }, function(ns)
		local text = favour(ns, "nameplate1")
		if next(ns.owed) then
			fail(scenario, "a debt was recorded with People who buff me off")
		end
		if text:find("buffed you", 1, true) then
			fail(scenario, "a favour was announced with People who buff me off: " .. text)
		end
		if thanked("nameplate1") ~= 1 then
			fail(scenario, "with People who buff me off, the favour was not thanked")
		end
	end)
end

-- ------------------------------------------------------------------ both off
-- With neither switch on, a buff landing reads nobody: no caster is asked for,
-- so the walk costs what it did before the /thank came along. The same favour
-- with the /thank on is the control, and proves the counter sees the reads.
for _, case in ipairs({
	{ class = "MAGE", label = "a mage" },
	{ class = "ROGUE", label = "a rogue" },
}) do
	local scenario = "thank-everyone: " .. case.label .. " with both off reads no caster"
	with(scenario, { class = case.class, owed = false }, function(ns)
		local seen = lookups("nameplate1", function() favour(ns, "nameplate1") end)
		if thanked("nameplate1") ~= 1 then
			fail(scenario, "SKIPPED -- the control favour was not thanked")
			return
		end
		if seen == 0 then
			fail(scenario, "the counter saw no unit lookups for a favour it thanked: it is not counting")
			return
		end
		ns.db.profile.prompt.thankEmote = false
		Mock.advance(20)
		local count = lookups("nameplate2", function() favour(ns, "nameplate2") end)
		if count > 0 then
			fail(scenario, ("a caster was read with both switches off (%d unit lookups)"):format(count))
		end
		if #emotes ~= 1 then fail(scenario, "a favour was thanked with both switches off") end
		if next(ns.owed) then fail(scenario, "a debt was recorded with both switches off") end
	end)
end

-- ------------------------------------------------------------------ the rules
-- Everything the thank held to for a mage holds for a rogue.
do
	local scenario = "thank-everyone: a rogue thanks for class buffs only"
	with(scenario, { class = "ROGUE" }, function(ns)
		favour(ns, "nameplate1", REJUVENATION)
		if thanked() > 0 then
			fail(scenario, "a rogue thanked a buff that is not a class buff")
		end
		-- Ignore shields, heals and trinket procs is hidden from a rogue, and
		-- read all the same.
		ns.db.profile.sources.owedClassBuffsOnly = false
		Mock.advance(20)
		favour(ns, "nameplate2", REJUVENATION)
		if thanked("nameplate2") ~= 1 then
			fail(scenario, "with every buff counted, a rogue did not thank a heal")
		end
	end)
end

do
	local scenario = "thank-everyone: a rogue does not thank in a fight"
	with(scenario, { class = "ROGUE" }, function(ns)
		Mock.inCombat = true
		favour(ns, "nameplate1")
		local log = ns.thankLog and ns.thankLog.skipped
		if not (log and log.why == "in a fight") then
			fail(scenario, "SKIPPED -- the favour in the fight was not noticed")
		elseif thanked() > 0 then
			fail(scenario, "a rogue thanked somebody in a fight")
		end
		Mock.inCombat = false
	end)
end

do
	local scenario = "thank-everyone: a rogue does not thank in an instance"
	with(scenario, { class = "ROGUE" }, function(ns)
		rawset(_G, "IsInInstance", function() return true, "party" end)
		favour(ns, "nameplate1")
		local log = ns.thankLog and ns.thankLog.skipped
		if not (log and log.why == "in an instance") then
			fail(scenario, "SKIPPED -- the favour in the dungeon was not noticed")
		elseif thanked() > 0 then
			fail(scenario, "a rogue thanked somebody in a dungeon")
		end
	end)
end

do
	local scenario = "thank-everyone: a rogue thanks one person once in five minutes"
	with(scenario, { class = "ROGUE" }, function(ns)
		favour(ns, "nameplate1")
		if thanked("nameplate1") ~= 1 then
			fail(scenario, "SKIPPED -- the first favour was not thanked")
			return
		end
		Mock.advance(60)
		favour(ns, "nameplate1")
		if thanked("nameplate1") ~= 1 then
			fail(scenario, "a rogue thanked the same person twice in a minute")
		end
		Mock.advance(250)
		favour(ns, "nameplate1")
		if thanked("nameplate1") ~= 2 then
			fail(scenario, "a rogue did not thank the same person again after five minutes")
		end
	end)
end

-- A buff read while its first reading was not believed is filed on the next
-- one; Manners switched off in between, nothing is thanked.
for _, case in ipairs({
	{ label = "left on", thanks = true },
	{ label = "switched off", off = true },
}) do
	local scenario = "thank-everyone: a favour filed after Manners was " .. case.label
	with(scenario, { class = "ROGUE" }, function(ns)
		Mock.auraHidden = { [1] = true }
		Mock.extraAura, Mock.extraAuraSpell, Mock.extraAuraSource = 6950, FORTITUDE, "nameplate1"
		ns.addon:UNIT_AURA(nil, "player")
		if ns.auraScan.doubt == nil or #emotes > 0 then
			fail(scenario, "SKIPPED -- the first reading was believed")
			return
		end
		if case.off then ns.db.profile.enabled = false end
		Mock.auraHidden = nil
		Mock.advance(0.5)
		ns.addon:UNIT_AURA(nil, "player")
		if case.thanks and thanked("nameplate1") ~= 1 then
			fail(scenario, "SKIPPED -- the deferred favour was not thanked")
		elseif case.off and #emotes > 0 then
			fail(scenario, "a favour sighted before Manners was switched off was thanked")
		end
	end)
end

-- ------------------------------------------------------------------ a mage
-- With People who buff me on, nothing changed: the debt, the line and the
-- thank, in that order.
do
	local scenario = "thank-everyone: a mage's favour is still owed, said and thanked"
	with(scenario, {}, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		local text = favour(ns, "nameplate1")
		if not ns.owed[anna] then fail(scenario, "a mage's favour was not recorded as owed") end
		if not text:find("returning the favour is on the prompt", 1, true) then
			fail(scenario, "a mage was not told the favour is on the prompt: " .. text)
		end
		if thanked("nameplate1") ~= 1 then fail(scenario, "a mage's favour was not thanked") end
		if not queued(ns, anna) then fail(scenario, "a mage's favour is not on the prompt") end
	end)
end

-- ------------------------------------------------------------------ the window
-- The options window for one class, opened from a clean login, as
-- window-classes.lua opens it.
local function window(scenario, opts, body)
	Mock.reset()
	become(opts)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		ns.Prompt:ExitTest()
		guarded(scenario, ns)
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function live(UI, path)
	local w = UI.Where(path)
	return w ~= nil and not UI.Disabled(w.e.item)
end

-- What I say holds the /thank and nothing else for a class with nothing to
-- give, and is in the sidebar for it; the switch is live with People who buff
-- me off. Start here's voice choice, which the window draws at the top of
-- What I say, stays hidden with the rest.
for _, case in ipairs({
	{ class = "HUNTER", label = "a hunter", known = { HAWK, MONKEY } },
	{ class = "ROGUE", label = "a rogue" },
}) do
	local scenario = "thank-everyone: What I say holds only the /thank for " .. case.label
	window(scenario, case, function(ns, UI)
		if ns.caps.hasClassBuffs then
			fail(scenario, "SKIPPED -- " .. case.label .. " has class buffs here")
			return
		end
		ns.db.profile.sources.owed = false
		ns.OpenOptions("click")
		if not (UI.visiblePages or {}).click or UI.page ~= "click" then
			fail(scenario, "What I say is missing from " .. case.label .. "'s sidebar")
			return
		end
		local paths = H.pagePaths(ns, "click") or {}
		if #paths == 0 then
			fail(scenario, "SKIPPED -- the layout places nothing on What I say")
			return
		end
		for _, path in ipairs(paths) do
			local shown = UI.RowShown(path)
			if path == "click.thankEmote" then
				if not shown then fail(scenario, "the /thank is not on " .. case.label .. "'s What I say") end
			elseif shown then
				fail(scenario, "a control other than the /thank shows on What I say: " .. path)
			end
		end
		if not live(UI, "click.thankEmote") then
			fail(scenario, "the /thank is greyed out with People who buff me off")
		end
	end)
end

-- A mage's What I say, control by control, as it was.
do
	local scenario = "thank-everyone: a mage's What I say is unchanged"
	window(scenario, {}, function(ns, UI)
		ns.db.profile.speech.enabled = true
		ns.db.profile.sources.owed = false
		ns.OpenOptions("click")
		for _, path in ipairs({ "general.quickVoice", "general.quickVoiceSummary", "click.thankEmote",
			"click.enabled", "click.channel", "click.onlyWhenReturning", "click.preset", "click.phrasesHelp",
			"click.phrases", "click.roll", "click.limits" }) do
			if not UI.RowShown(path) then fail(scenario, path .. " is missing from a mage's What I say") end
		end
		if UI.RowShown("click.linesOff") then
			fail(scenario, "a mage saying lines is told to tick Say a line")
		end
		if not live(UI, "click.thankEmote") then
			fail(scenario, "a mage's /thank is greyed out with People who buff me off")
		end
		ns.db.profile.speech.enabled = false
		ns.RefreshOptionsDisplay()
		if not UI.RowShown("click.linesOff") or UI.RowShown("click.phrases") then
			fail(scenario, "a mage's Lines section does not follow Say a line")
		end
		if not live(UI, "click.thankEmote") then
			fail(scenario, "SKIPPED -- the /thank went grey with speech off")
		end
	end)
end

-- Start here tells a class with nothing to give what it does have, and the
-- bug report says whether the /thank is on: with it on, somebody buffing you
-- is noticed whatever People who buff me says.
do
	local scenario = "thank-everyone: a rogue's Start here points at the /thank"
	window(scenario, { class = "ROGUE" }, function(ns)
		local note = ns.optionsTable.args.general.args.noBuffs
		local text = note and type(note.name) == "function" and note.name() or ""
		if not text:find("no buffs it can cast", 1, true) then
			fail(scenario, "SKIPPED -- Start here does not say the rogue has nothing: " .. text)
		elseif not (text:find("/thank people who buff me", 1, true) and text:find("What I say", 1, true)) then
			fail(scenario, "a rogue's Start here does not point at the /thank: " .. text)
		end
	end)
end

do
	local scenario = "thank-everyone: the bug report says whether the /thank is on"
	window(scenario, { class = "ROGUE" }, function(ns)
		local report = ns.optionsTable.args.diagnostics.args.report
		ns.db.profile.prompt.thankEmote = false
		local off = report.get({ "diagnostics", "report" })
		ns.db.profile.prompt.thankEmote = true
		local on = report.get({ "diagnostics", "report" })
		if not (off:find("thank=false", 1, true) and on:find("thank=true", 1, true)) then
			fail(scenario, "the bug report does not say whether the /thank is on: " .. on)
		end
	end)
end
