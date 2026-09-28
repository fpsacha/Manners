-- "Thank them with an emote": a favour the prompt can return answered with
-- C_ChatInfo.PerformEmote("THANK", <their token>) -- DoEmote where the client
-- has only that -- and every reason it is not: off, a fight, an instance, chat
-- held back, a token that no longer holds them, the two throttles, a favour the
-- chat line does not put on the prompt, an emote call that is missing or
-- throws, and one the game answers was restricted.
--
-- Every scenario name starts with "thank:" so the mutations in
-- tests/mutations/thank.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom =
	H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom

-- Three strangers on nameplates, and nobody else.
local PEOPLE = {
	nameplate1 = { "Anna", "Aim" },
	nameplate2 = { "Bo", "Brisk" },
	nameplate3 = { "Cy", "Cole" },
}

-- Globals the scenarios replace, put back after each: Mock.reset owns none of
-- them, and several are read through the mock's own fallback when absent.
local TOUCHED = { "IsInInstance", "DoEmote", "C_ChatInfo", "C_InstanceEncounter",
	"IsEncounterInProgress", "C_RestrictedActions", "Enum", "UnitGUID", "UnitName",
	"UnitPowerMax", "IsSpellKnown", "IsPlayerSpell" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

-- Every emote made, as { emote, target }.
local emotes = {}
local function record(emote, target) emotes[#emotes + 1] = { emote, target } end

-- Outdoors and able to emote, unless the scenario says otherwise.
local function outdoors() return false, "none" end

local function said() return table.concat(Mock.printed, "\n") end

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- One scenario: `globals` in place over the outdoor defaults, the addon up with
-- the emote on (unless opts.off), the baseline of your own buffs settled, and
-- body(ns) run. Everything put back whether it finished or threw.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.nameplates = { "nameplate1", "nameplate2", "nameplate3" }
	if opts.class then Mock.class = opts.class end
	if opts.groupSize then Mock.groupSize = opts.groupSize end
	if opts.unitClass then Mock.unitClass = opts.unitClass end
	emotes = {}
	rawset(_G, "IsInInstance", outdoors)
	rawset(_G, "DoEmote", record)
	for name, value in pairs(opts.globals or {}) do
		if value == false then rawset(_G, name, nil) else rawset(_G, name, value) end
	end
	local undo = strangers(opts.people or PEOPLE)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		if opts.before then opts.before(ns) end
		freshPrompt(ns, scenario)
		if not opts.off then ns.db.profile.prompt.thankEmote = true end
		primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
		body(ns)
		guarded(scenario, ns)
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A buff landing from `unit`, under an instance id never used before, so each
-- is a favour of its own. Hands back what was said about it.
local nextId = 6000
local function favour(ns, unit, spell)
	nextId = nextId + 1
	return favourFrom(ns, unit, spell or 10938, nextId)
end

-- The favour from `unit` was noticed at all, or the scenario proves nothing.
local function noticed(scenario, ns, unit, text)
	local name = ns.UnitFullName(unit)
	if not (name and text:find(name, 1, true) and text:find("buffed you", 1, true)) then
		fail(scenario, "SKIPPED -- the favour from " .. unit .. " was not noticed: " .. text)
		return false
	end
	return true
end

local function thanked(target)
	local n = 0
	for _, e in ipairs(emotes) do
		if target == nil or e[2] == target then n = n + 1 end
	end
	return n
end

-- ------------------------------------------------------------------ on / off
do
	local scenario = "thank: off by default, and off makes no emote"
	with(scenario, { off = true }, function(ns)
		if ns.db.profile.prompt.thankEmote ~= false then
			fail(scenario, "the emote is not off in a new profile: "
				.. tostring(ns.db.profile.prompt.thankEmote))
		end
		if noticed(scenario, ns, "nameplate1", favour(ns, "nameplate1")) and #emotes > 0 then
			fail(scenario, "an emote was made with the setting off")
		end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("thank with an emote: |cffff0000off", 1, true) then
			fail(scenario, "/manners debug does not say the emote is off: " .. said())
		end
	end)
end

do
	local scenario = "thank: a favour is thanked at the token it came from"
	with(scenario, {}, function(ns)
		local text = favour(ns, "nameplate2")
		if not noticed(scenario, ns, "nameplate2", text) then return end
		if #emotes ~= 1 then
			fail(scenario, ("%d emotes for one favour"):format(#emotes))
			return
		end
		if emotes[1][1] ~= "THANK" then
			fail(scenario, "the emote made was " .. tostring(emotes[1][1]))
		end
		if emotes[1][2] ~= "nameplate2" then
			fail(scenario, "the emote went to " .. tostring(emotes[1][2])
				.. ", not the token the buff came from")
		end
		local bo = ns.UnitFullName("nameplate2")
		local log = ns.thankLog and ns.thankLog.thanked
		if not (log and log.name == bo) then
			fail(scenario, "the thank was not written down for /manners debug")
		end
		Mock.advance(7)
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("thank with an emote: |cff00ff00on", 1, true) then
			fail(scenario, "/manners debug does not say the emote is on: " .. said())
		end
		if not said():find("last thanked: |cffffffff" .. bo
			.. "|r, 7s ago (the game answered nil)", 1, true) then
			fail(scenario, "/manners debug does not name the last thank: " .. said())
		end
	end)
end

-- ------------------------------------------------------------------ combat
-- In a fight it would be noise, and the favour is not saved up for later.
do
	local scenario = "thank: not in a fight, and not afterwards either"
	with(scenario, {}, function(ns)
		Mock.inCombat = true
		local text = favour(ns, "nameplate1")
		if not noticed(scenario, ns, "nameplate1", text) then return end
		if #emotes > 0 then fail(scenario, "an emote was made in a fight") end
		local log = ns.thankLog and ns.thankLog.skipped
		if not (log and log.why == "in a fight") then
			fail(scenario, "the skip was not written down with its reason")
		end
		Mock.inCombat = false
		Mock.advance(3)
		ns.addon:PLAYER_REGEN_ENABLED()
		ns.addon:UNIT_AURA(nil, "player")
		ns.addon:Tick()
		if #emotes > 0 then fail(scenario, "the favour from the fight was thanked after it") end
		-- Nor did the skip hold anybody back: the next favour is thanked.
		favour(ns, "nameplate2")
		if thanked("nameplate2") ~= 1 then
			fail(scenario, "a favour after the fight was not thanked")
		end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("last not thanked: |cffffffff" .. ns.UnitFullName("nameplate1")
			.. "|r, 3s ago (in a fight)", 1, true) then
			fail(scenario, "/manners debug does not name the last skip: " .. said())
		end
	end)
end

-- ------------------------------------------------------------------ instances
-- Chat from addon code is held back in an encounter, and which instances do it
-- when is not known, so none of them; nor anywhere the client will not say.
for _, case in ipairs({
	{ label = "a dungeon", fn = function() return true, "party" end },
	{ label = "a raid", fn = function() return true, "raid" end },
	{ label = "a battleground", fn = function() return true, "pvp" end },
	{ label = "no IsInInstance", fn = false },
	{ label = "IsInInstance throws", fn = function() error("no") end },
	{ label = "IsInInstance a secret", fn = function() return Mock.SECRET, "party" end },
	{ label = "outdoors", fn = outdoors, thanks = true },
}) do
	local scenario = "thank: not in an instance (" .. case.label .. ")"
	with(scenario, { globals = { IsInInstance = case.fn } }, function(ns)
		if not noticed(scenario, ns, "nameplate1", favour(ns, "nameplate1")) then return end
		if case.thanks and #emotes ~= 1 then
			fail(scenario, "a favour outdoors was not thanked")
		elseif not case.thanks and #emotes > 0 then
			fail(scenario, "an emote was made in " .. case.label)
		end
	end)
end

-- ------------------------------------------------------------------ chat held
-- The checks other addons on this client make before they chat, and an
-- encounter outdoors.
local CHAT_TYPE = 7
local function restriction(state)
	return {
		C_RestrictedActions = { GetAddOnRestrictionState = function(kind)
			return kind == CHAT_TYPE and state or 0
		end },
		Enum = {
			PowerType = { Mana = 0 },
			SecrecyLevel = { NeverSecret = 0 },
			AddOnRestrictionState = { Inactive = 0, Active = 1, Activating = 2 },
			AddOnRestrictionType = { Map = 1, Combat = 2, Chat = CHAT_TYPE },
		},
	}
end
for _, case in ipairs({
	{ label = "messaging lockdown", globals = {
		C_ChatInfo = { InChatMessagingLockdown = function() return true end } } },
	{ label = "lockdown unreadable", globals = {
		C_ChatInfo = { InChatMessagingLockdown = function() error("no") end } } },
	{ label = "no lockdown", thanks = true, globals = {
		C_ChatInfo = { InChatMessagingLockdown = function() return false end } } },
	{ label = "a chat API without the lockdown", thanks = true, globals = {
		C_ChatInfo = {} } },
	{ label = "an encounter", globals = {
		C_InstanceEncounter = { IsEncounterInProgress = function() return true end } } },
	{ label = "an encounter, old API", globals = {
		IsEncounterInProgress = function() return true end } },
	{ label = "no encounter", thanks = true, globals = {
		C_InstanceEncounter = { IsEncounterInProgress = function() return false end },
		IsEncounterInProgress = function() return false end } },
	{ label = "chat restriction active", globals = restriction(1) },
	{ label = "chat restriction activating", globals = restriction(2) },
	{ label = "chat restriction inactive", thanks = true, globals = restriction(0) },
	-- Another restriction active says nothing about chat, and a client that
	-- has no Chat kind, or no way to ask, is not held on its account.
	{ label = "no Chat restriction kind", thanks = true, globals = {
		C_RestrictedActions = { GetAddOnRestrictionState = function() return 1 end } } },
	{ label = "no restriction state call", thanks = true, globals = {
		C_RestrictedActions = {}, Enum = restriction(1).Enum } },
}) do
	local scenario = "thank: not while chat is held back (" .. case.label .. ")"
	with(scenario, { globals = case.globals }, function(ns)
		if not noticed(scenario, ns, "nameplate1", favour(ns, "nameplate1")) then return end
		if case.thanks and #emotes ~= 1 then
			fail(scenario, "a favour was not thanked with nothing holding chat back")
		elseif not case.thanks and #emotes > 0 then
			fail(scenario, "an emote was made with " .. case.label)
		end
	end)
end

-- ------------------------------------------------------------------ the token
-- The favour is filed against whoever held the token when the buff was read;
-- by the time it is filed the token may mean somebody else, or nobody. A
-- refused first reading defers the filing to the next scan, which is where the
-- token is changed.
for _, case in ipairs({
	{ label = "still theirs", thanks = true },
	{ label = "handed to somebody else", change = function()
		Mock.unitNames.nameplate1 = { "Dee", "Dunn" }
	end },
	{ label = "gone", change = function() Mock.unitNames.nameplate1 = nil end },
	{ label = "existence a secret", change = function()
		local real = UnitExists
		UnitExists = function(unit)
			if unit == "nameplate1" then return Mock.SECRET end
			return real(unit)
		end
	end },
	{ label = "name a secret", change = function()
		local real = UnitName
		rawset(_G, "UnitName", function(unit)
			if unit == "nameplate1" then return Mock.SECRET, Mock.SECRET end
			return real(unit)
		end)
	end },
	{ label = "somebody else by the same name", change = function()
		local real = UnitGUID
		rawset(_G, "UnitGUID", function(unit)
			if unit == "nameplate1" then return "Player-9-somebodyelse" end
			return real(unit)
		end)
	end },
}) do
	local scenario = "thank: only at a token that still holds them (" .. case.label .. ")"
	with(scenario, { people = {
		nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Brisk" },
	} }, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		Mock.printed = {}
		Mock.auraHidden = { [1] = true }
		Mock.extraAura, Mock.extraAuraSpell, Mock.extraAuraSource = 6900, 10938, "nameplate1"
		ns.addon:UNIT_AURA(nil, "player")
		if ns.auraScan.doubt == nil or ns.owed[anna] then
			fail(scenario, "SKIPPED -- the first reading was believed")
			return
		end
		if case.change then case.change() end
		Mock.auraHidden = nil
		Mock.advance(0.5)
		ns.addon:UNIT_AURA(nil, "player")
		if not ns.owed[anna] then
			fail(scenario, "SKIPPED -- the deferred favour was not filed: " .. said())
			return
		end
		if case.thanks then
			if thanked("nameplate1") ~= 1 then
				fail(scenario, "a token still holding them was not thanked")
			end
		elseif #emotes > 0 then
			fail(scenario, "an emote went to a token " .. case.label)
		end
	end)
	-- UnitExists is the strangers() stand-in, which its undo puts back.
end

-- ------------------------------------------------------------------ throttles
do
	local scenario = "thank: once per person in five minutes"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		if thanked("nameplate1") ~= 1 then
			fail(scenario, "SKIPPED -- the first favour was not thanked")
			return
		end
		-- Bo in between, well clear of the gap: thanking him must not forget Anna.
		Mock.advance(20)
		favour(ns, "nameplate2")
		if thanked("nameplate2") ~= 1 then
			fail(scenario, "somebody else's favour twenty seconds later was not thanked")
		end
		Mock.advance(40)
		local text = favour(ns, "nameplate1")
		if not noticed(scenario, ns, "nameplate1", text) then return end
		if thanked("nameplate1") ~= 1 then
			fail(scenario, "the same person was thanked twice in a minute")
		end
		local log = ns.thankLog and ns.thankLog.skipped
		if not (log and log.why == "thanked them a moment ago") then
			fail(scenario, "the per-person skip was not written down")
		end
		Mock.advance(250)
		favour(ns, "nameplate1")
		if thanked("nameplate1") ~= 2 then
			fail(scenario, "the same person was not thanked again after five minutes")
		end
	end)
end

do
	local scenario = "thank: one emote in ten seconds for anybody"
	with(scenario, {}, function(ns)
		favour(ns, "nameplate1")
		Mock.advance(3)
		local text = favour(ns, "nameplate2")
		if not noticed(scenario, ns, "nameplate2", text) then return end
		if thanked("nameplate1") ~= 1 then
			fail(scenario, "SKIPPED -- the first favour was not thanked")
			return
		end
		if thanked("nameplate2") ~= 0 then
			fail(scenario, "two people were thanked three seconds apart")
		end
		local log = ns.thankLog and ns.thankLog.skipped
		if not (log and log.why == "thanked somebody a moment ago") then
			fail(scenario, "the gap's skip was not written down")
		end
		Mock.advance(8)
		favour(ns, "nameplate3")
		if thanked("nameplate3") ~= 1 then
			fail(scenario, "a favour eleven seconds after the last thank was not thanked")
		end
		-- The one passed over was never thanked, so the next of his is.
		Mock.advance(15)
		favour(ns, "nameplate2")
		if thanked("nameplate2") ~= 1 then
			fail(scenario, "a favour passed over by the gap held that person back")
		end
	end)
end

-- ------------------------------------------------------------------ not on the prompt
-- The chat line's rule: a favour nothing you cast could return, and one only
-- your own party can be reached with, are not thanked.
do
	local scenario = "thank: not a favour nothing you cast is any use for"
	with(scenario, {
		unitClass = "WARRIOR",
		globals = { UnitPowerMax = function(unit, ...)
			if unit ~= "player" then return 0 end
			return original.UnitPowerMax(unit, ...)
		end },
	}, function(ns)
		local text = favour(ns, "nameplate1", 25289)
		if not text:find("nothing you cast is any use", 1, true) then
			fail(scenario, "SKIPPED -- the favour was not the useless kind: " .. text)
		elseif #emotes > 0 then
			fail(scenario, "a favour nothing you cast could return was thanked")
		end
	end)
end

-- A warrior's shout reaches the party only: a stranger's favour is kept, not
-- offered, and not thanked; a party member's is thanked at the party token.
-- The mock counts everybody as in your party once you have one, so the
-- stranger is met alone.
for _, case in ipairs({
	{ label = "a stranger", unit = "nameplate1", groupSize = 0 },
	{ label = "a party member", unit = "party1", groupSize = 3, thanks = true },
}) do
	local scenario = "thank: a shout's favour only from the party (" .. case.label .. ")"
	local shoutKnown = function(ns)
		local known = {}
		for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
	end
	with(scenario, {
		class = "WARRIOR", groupSize = case.groupSize,
		people = { nameplate1 = { "Anna", "Aim" }, party1 = { "Grom", "Hale" } },
		before = shoutKnown,
	}, function(ns)
		local text = favour(ns, case.unit)
		if not noticed(scenario, ns, case.unit, text) then return end
		if case.thanks then
			if not text:find("on the prompt", 1, true) then
				fail(scenario, "SKIPPED -- the party member's favour is not on the prompt: " .. text)
			elseif thanked("party1") ~= 1 then
				fail(scenario, "a party member's favour was not thanked at their party token")
			end
		else
			if text:find("on the prompt", 1, true) then
				fail(scenario, "SKIPPED -- the stranger's favour is on the prompt: " .. text)
			elseif #emotes > 0 then
				fail(scenario, "a favour the shout cannot return was thanked")
			end
		end
	end)
end

-- ------------------------------------------------------------------ the emote call
-- DoEmote is a deprecation shim that may not be loaded, and either call may
-- throw: skipped without a word, and a call that never went holds nobody back.
for _, case in ipairs({
	{ label = "missing", fn = false },
	{ label = "throws", fn = function() error("DoEmote refused") end },
}) do
	local scenario = "thank: DoEmote " .. case.label .. " is skipped silently"
	with(scenario, { globals = { DoEmote = case.fn } }, function(ns)
		local text = favour(ns, "nameplate1")
		if not noticed(scenario, ns, "nameplate1", text) then return end
		if text:find("DoEmote", 1, true) or text:find("thank", 1, true) then
			fail(scenario, "something was said about the emote: " .. text)
		end
		local log = ns.thankLog and ns.thankLog.skipped
		if not (log and log.why == "the game would not do it") then
			fail(scenario, "the refusal was not written down for /manners debug")
		end
		if ns.thankLog.thanked then
			fail(scenario, "an emote that never went was recorded as made")
		end
		-- The game takes it again: the next favour, even at once, is thanked.
		rawset(_G, "DoEmote", record)
		Mock.advance(1)
		favour(ns, "nameplate1")
		if thanked("nameplate1") ~= 1 then
			fail(scenario, "an emote that never went held the next one back")
		end
	end)
end

-- C_ChatInfo.PerformEmote is the live call and is taken over DoEmote whenever
-- the client has it: alone (the shim not loaded), or with DoEmote beside it.
for _, case in ipairs({
	{ label = "without DoEmote", doEmote = false },
	{ label = "beside DoEmote", doEmote = true },
}) do
	local scenario = "thank: PerformEmote is the call made (" .. case.label .. ")"
	local shim = {}
	with(scenario, { globals = {
		C_ChatInfo = { PerformEmote = record },
		DoEmote = case.doEmote and function(...) shim[#shim + 1] = { ... } end or false,
	} }, function(ns)
		if not noticed(scenario, ns, "nameplate1", favour(ns, "nameplate1")) then return end
		if #shim > 0 then fail(scenario, "DoEmote was called with PerformEmote there") end
		if #emotes ~= 1 or emotes[1][1] ~= "THANK" or emotes[1][2] ~= "nameplate1" then
			fail(scenario, ("PerformEmote made %d emotes, not THANK at the token"):format(#emotes))
		end
		if not (ns.thankLog.thanked and ns.thankLog.thanked.name == ns.UnitFullName("nameplate1")) then
			fail(scenario, "the thank through PerformEmote was not written down")
		end
	end)
end

-- What the game answers, read the way Blizzard's chat box reads it: true is a
-- restricted emote that did not go, and is not written down as a thank; the
-- limits hold anyway, in case that reading is backwards. Anything else went,
-- and the answer is shown in /manners debug so the reading can be settled.
do
	local scenario = "thank: an emote the game says was restricted is not a thank"
	local answer = true
	local function perform(emote, target)
		record(emote, target)
		return answer
	end
	with(scenario, { globals = { C_ChatInfo = { PerformEmote = perform } } }, function(ns)
		local text = favour(ns, "nameplate1")
		if not noticed(scenario, ns, "nameplate1", text) then return end
		if #emotes ~= 1 then
			fail(scenario, "SKIPPED -- the emote was never tried")
			return
		end
		if text:find("thank", 1, true) or text:find("restricted", 1, true) then
			fail(scenario, "something was said about the emote: " .. text)
		end
		if ns.thankLog.thanked then
			fail(scenario, "an emote the game said was restricted was recorded as made")
		end
		local log = ns.thankLog.skipped
		if not (log and log.why == "the game said it was restricted") then
			fail(scenario, "the restricted answer was not written down for /manners debug")
		end
		Mock.advance(3)
		favour(ns, "nameplate2")
		if thanked("nameplate2") ~= 0 then
			fail(scenario, "a restricted answer did not hold the gap, which read backwards emotes at every favour")
		end
		answer = false
		Mock.advance(11)
		favour(ns, "nameplate3")
		if thanked("nameplate3") ~= 1 then
			fail(scenario, "SKIPPED -- the favour after the gap was not tried")
			return
		end
		Mock.advance(2)
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("last thanked: |cffffffff" .. ns.UnitFullName("nameplate3")
			.. "|r, 2s ago (the game answered false)", 1, true) then
			fail(scenario, "/manners debug does not show what the game answered: " .. said())
		end
	end)
end

-- A secret answer is no answer, so not true: counted as went, shown as nil.
do
	local scenario = "thank: a secret answer is read safely"
	with(scenario, { globals = { C_ChatInfo = { PerformEmote = function(emote, target)
		record(emote, target)
		return Mock.SECRET
	end } } }, function(ns)
		if not noticed(scenario, ns, "nameplate1", favour(ns, "nameplate1")) then return end
		local log = ns.thankLog.thanked
		if not (log and log.answer == "nil") then
			fail(scenario, "a secret answer was not read through plain: "
				.. tostring(log and log.answer))
		end
	end)
end

-- ------------------------------------------------------------------ the setting
do
	local scenario = "thank: the setting on the Prompt tab, and repaired"
	with(scenario, { off = true }, function(ns)
		local appearance = ns.optionsTable and ns.optionsTable.args.appearance
		local control = appearance and appearance.args.thankEmote
		if not control then
			fail(scenario, "no Thank them with an emote on the Prompt tab")
			return
		end
		local flash = appearance.args.flashStyle
		if control.type ~= "toggle" or not (control.order > flash.order
			and control.order < appearance.args.effects.order) then
			fail(scenario, "the toggle is not beside When someone buffs you")
		end
		control.set({ "thankEmote" }, true)
		if ns.db.profile.prompt.thankEmote ~= true or control.get({ "thankEmote" }) ~= true then
			fail(scenario, "the toggle does not switch the setting on")
		end
		control.set({ "thankEmote" }, false)
		if ns.db.profile.prompt.thankEmote ~= false then
			fail(scenario, "the toggle does not switch the setting off")
		end
		ns.db.profile.sources.owed = false
		if not (type(control.disabled) == "function" and control.disabled()) then
			fail(scenario, "the toggle is live with People who buffed me off")
		end
		ns.db.profile.sources.owed = true
		ns.db.profile.prompt.thankEmote = "yes"
		ns.ClampSettings()
		if ns.db.profile.prompt.thankEmote ~= false then
			fail(scenario, "a setting that is not a yes or no was kept: "
				.. tostring(ns.db.profile.prompt.thankEmote))
		end
	end)
end
