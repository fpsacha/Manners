-- Thank them even when I can't see who it was (prompt.thankUnseen). Asked for
-- on CurseForge by a player who keeps the game's friendly nameplates off: a
-- class buff from a stranger the game gives no token for had nobody to owe
-- and nobody to thank, so nothing went out. With this on (off by default, live
-- while the /thank or the whispered thank-you is), Favours.lua:
--   A. ThankUnseen: a landing the aura scan reads with plainly nobody behind it
--      is answered by the emote with no target, under every rule a thank obeys
--      that needs no person, and never with somebody targeted, for a shout, or
--      for a buff that may be a group member's.
--   B. ThankByName: on the clients with a combat log, a stranger the log names
--      and no token holds is whispered by name, under the whisper's rules.
-- One landing is one thank, whichever source reads it first.
--
-- Every scenario name starts with "thank-unseen:" so the mutations in
-- tests/mutations/thank-unseen.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom, findOption =
	H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom, H.findOption

local TOUCHED = { "IsInInstance", "DoEmote", "SendChatMessage", "C_ChatInfo", "C_Timer",
	"GetCVar", "GetNumGroupMembers", "UnitIsPlayer" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local emotes, whispers = {}, {}
local place = false -- false outdoors, else IsInInstance's kind
local npc = {}

-- One session. opts: flavour, class, names (unit -> name, the units that exist
-- besides you), thank (the /thank, on unless false), whisper (off unless true),
-- unseen (the switch: left at its default when nil), delay, platesOff, group
-- (GetNumGroupMembers), before (run before the baseline settles).
local function with(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	local names = opts.names or { nameplate1 = { "Anna", "Aim" } }
	local plates = {}
	for unit in pairs(names) do
		if unit:find("^nameplate") then plates[#plates + 1] = unit end
	end
	table.sort(plates)
	Mock.nameplates = plates
	Mock.class = opts.class or "ROGUE"
	emotes, whispers, place, npc = {}, {}, false, {}
	rawset(_G, "IsInInstance", function() return place ~= false, place or "none" end)
	rawset(_G, "DoEmote", function(emote, target) emotes[#emotes + 1] = { emote, target } end)
	rawset(_G, "C_ChatInfo", nil)
	rawset(_G, "SendChatMessage", function(text, channel, _, target)
		whispers[#whispers + 1] = { text = text, channel = channel, target = target }
	end)
	if opts.platesOff then
		rawset(_G, "GetCVar", function(name)
			if name == "nameplateShowFriendlyPlayers" or name == "nameplateShowFriends" then return "0" end
			return original.GetCVar and original.GetCVar(name) or nil
		end)
	end
	if opts.group then rawset(_G, "GetNumGroupMembers", function() return opts.group end) end
	rawset(_G, "UnitIsPlayer", function(unit)
		if npc[unit] then return false end
		return original.UnitIsPlayer(unit)
	end)
	local undo = strangers(names)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.prompt.thankEmote = opts.thank ~= false
		db.prompt.thankWhisper = opts.whisper == true
		if opts.unseen ~= nil then db.prompt.thankUnseen = opts.unseen end
		db.prompt.thankDelay = opts.delay == true
		if opts.before then opts.before(ns) end
		primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
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

-- Power Word: Fortitude as this client numbers it.
local function fortitude(ns)
	return ns.BUFF_BY_ID[10938] and 10938 or 21562
end

local nextId = 9700
-- A buff landing with `source` as its caster: nil is nobody at all.
local function land(ns, source, spell)
	nextId = nextId + 1
	return favourFrom(ns, source, spell or fortitude(ns), nextId)
end

-- The emotes made with nobody targeted, and with somebody.
local function atNobody()
	local n = 0
	for _, e in ipairs(emotes) do if e[2] == nil then n = n + 1 end end
	return n
end

local function why(ns)
	local log = ns.thankLog.unseenSkipped
	return log and log.why
end

local function said() return table.concat(Mock.printed, "\n") end

-- ------------------------------------------------------------------ the switch
do
	local scenario = "thank-unseen: off by default, a buff from nobody named is not thanked"
	with(scenario, {}, function(ns)
		if ns.defaults.profile.prompt.thankUnseen ~= false then fail(scenario, "the switch is not off by default") end
		land(ns, nil)
		if #emotes ~= 0 then fail(scenario, ("%d emotes with the switch off"):format(#emotes)) end
	end)
end

do
	local scenario = "thank-unseen: on, the emote goes out with nobody targeted"
	with(scenario, { unseen = true }, function(ns)
		local text = land(ns, nil)
		if #emotes ~= 1 then fail(scenario, ("%d emotes for a buff from nobody named"):format(#emotes)) return end
		if emotes[1][1] ~= "THANK" then fail(scenario, "the emote made was " .. tostring(emotes[1][1])) end
		if emotes[1][2] ~= nil then fail(scenario, "the emote went at " .. tostring(emotes[1][2])) end
		local log = ns.thankLog.unseen
		if not (log and log.key == fortitude(ns)) then fail(scenario, "the thank was not written down") end
		if text:find("buffed you", 1, true) then fail(scenario, "a chat line was said for it: " .. text) end
		if next(ns.owed) then fail(scenario, "somebody was left owing: " .. tostring(next(ns.owed))) end
		if #whispers ~= 0 then fail(scenario, "a whisper went to nobody") end
	end)
end

do
	local scenario = "thank-unseen: live only while the /thank is on"
	with(scenario, { unseen = true, thank = false, whisper = true }, function(ns)
		land(ns, nil)
		if #emotes ~= 0 then fail(scenario, "an emote was made with the /thank off") end
	end)
end

do
	local scenario = "thank-unseen: a buff from somebody named is thanked at them as ever"
	with(scenario, { unseen = true }, function(ns)
		land(ns, "nameplate1")
		if #emotes ~= 1 or emotes[1][2] ~= "nameplate1" then
			fail(scenario, ("%d emotes, the first at %s"):format(#emotes, tostring(emotes[1] and emotes[1][2])))
		end
		if ns.thankLog.unseen then fail(scenario, "a named favour was written down as unseen") end
	end)
end

-- ------------------------------------------------------------------ is it a landing
do
	local scenario = "thank-unseen: the buffs worn at login are not thanked"
	with(scenario, { unseen = true, before = function(ns)
		Mock.extraAura = 9690
		Mock.extraAuraSpell = fortitude(ns)
		Mock.extraAuraSource = nil
		-- A zone change (or a login): the baseline taken afresh, the buff on you.
		ns.addon:PLAYER_ENTERING_WORLD(nil, false, false)
	end }, function(ns)
		ns.ScanOwnBuffs()
		ns.addon:UNIT_AURA(nil, "player")
		if #emotes ~= 0 then fail(scenario, ("%d emotes for what was worn before the baseline"):format(#emotes)) end
	end)
end

do
	local scenario = "thank-unseen: a refresh of a buff already worn is not thanked again"
	with(scenario, { unseen = true }, function(ns)
		land(ns, nil)
		if #emotes ~= 1 then fail(scenario, "SKIPPED -- the first landing was not thanked") return end
		Mock.advance(400)
		-- The client restating its end by a second: no cast.
		Mock.extraAuraUntil = 2001
		ns.addon:UNIT_AURA(nil, "player")
		ns.addon:UNIT_AURA(nil, "player")
		if #emotes ~= 1 then fail(scenario, ("a restated end was thanked: %d emotes"):format(#emotes)) end
	end)
end

do
	local scenario = "thank-unseen: a shout is never thanked"
	with(scenario, { unseen = true }, function(ns)
		local shout = ns.FindBuff("WARRIOR", "battleshout")
		local id = shout and shout.ranks and shout.ranks[1]
		if not (id and ns.ALL_BUFF_IDS[id]) then fail(scenario, "SKIPPED -- no Battle Shout here") return end
		land(ns, nil, id)
		if #emotes ~= 0 then fail(scenario, "a Battle Shout from nobody named was thanked") end
	end)
end

-- ------------------------------------------------------------------ where and when
do
	local scenario = "thank-unseen: never in a fight"
	with(scenario, { unseen = true }, function(ns)
		Mock.inCombat = true
		land(ns, nil)
		Mock.inCombat = false
		if #emotes ~= 0 then fail(scenario, "thanked in a fight") end
		if why(ns) ~= "in a fight" then fail(scenario, "the skip says " .. tostring(why(ns))) end
	end)
end

do
	local scenario = "thank-unseen: never in a dungeon"
	with(scenario, { unseen = true }, function(ns)
		place = "party"
		land(ns, nil)
		if #emotes ~= 0 then fail(scenario, "thanked in a dungeon") end
		if why(ns) ~= "in an instance" then fail(scenario, "the skip says " .. tostring(why(ns))) end
	end)
end

do
	local scenario = "thank-unseen: never in a battleground, where nobody unseen is of your team"
	with(scenario, { unseen = true }, function(ns)
		place = "pvp"
		land(ns, nil)
		if #emotes ~= 0 then fail(scenario, "thanked somebody unseen in a battleground") end
	end)
end

do
	local scenario = "thank-unseen: never with somebody targeted"
	with(scenario, { unseen = true, names = { nameplate1 = { "Anna", "Aim" }, target = { "Bo", "Brisk" } } }, function(ns)
		land(ns, nil)
		if #emotes ~= 0 then fail(scenario, "the emote went with somebody targeted, at them") end
		if why(ns) ~= "you have somebody targeted" then fail(scenario, "the skip says " .. tostring(why(ns))) end
	end)
end

do
	local scenario = "thank-unseen: a buff that may be a group member's is not thanked"
	with(scenario, { unseen = true, group = 2, names = { nameplate1 = { "Anna", "Aim" }, party1 = { "Pia", "Pale" } } },
		function(ns)
			Mock.unitClass = "PRIEST"
			land(ns, nil)
			if #emotes ~= 0 then fail(scenario, "a Fortitude with a priest in the group was thanked as nobody's") return end
			-- Nobody of that class in the group: a stranger's.
			Mock.unitClass = "WARRIOR"
			Mock.advance(400)
			land(ns, nil)
			if atNobody() ~= 1 then fail(scenario, "a Fortitude with no priest in the group was not thanked") end
		end)
end

-- ------------------------------------------------------------------ nobody, or cannot tell
do
	local scenario = "thank-unseen: a withheld caster is not nobody"
	with(scenario, { unseen = true }, function(ns)
		land(ns, Mock.SECRET)
		if #emotes ~= 0 then fail(scenario, "a caster the client withheld was thanked as nobody") end
	end)
end

do
	local scenario = "thank-unseen: a withheld spell is not thanked"
	with(scenario, { unseen = true }, function(ns)
		land(ns, nil, Mock.SECRET)
		if #emotes ~= 0 then fail(scenario, "a buff whose spell was withheld was thanked") end
	end)
end

do
	local scenario = "thank-unseen: an NPC's buff is not thanked"
	with(scenario, { unseen = true, names = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Guard", "Post" } } },
		function(ns)
			npc.nameplate2 = true
			land(ns, "nameplate2")
			if #emotes ~= 0 then fail(scenario, "an NPC's buff was thanked") end
		end)
end

do
	local scenario = "thank-unseen: a buff you cast yourself is not thanked"
	with(scenario, { unseen = true }, function(ns)
		land(ns, "player")
		if #emotes ~= 0 then fail(scenario, "your own buff was thanked") end
		if ns.thankLog.unseen then fail(scenario, "your own buff was written down as unseen") end
	end)
end

-- isFromPlayerOrPlayerPet is true for any player's aura, a stranger's too (the
-- client sets it so; Blizzard's TargetFrame reads it as casterIsAPlayer): it is
-- what tells a stranger with no nameplate from an NPC with none.
do
	local scenario = "thank-unseen: a stranger's buff the client flags as a player's is thanked"
	with(scenario, { unseen = true }, function(ns)
		Mock.extraAuraFromPlayer = true
		land(ns, nil)
		if atNobody() ~= 1 then
			fail(scenario, ("%d emotes for a stranger's buff flagged as a player's"):format(atNobody()))
		end
	end)
end

do
	local scenario = "thank-unseen: an NPC with no token is not thanked"
	with(scenario, { unseen = true }, function(ns)
		-- No nameplate and not targeted: no token, as for a stranger, but the
		-- client says no player cast it.
		Mock.extraAuraFromPlayer = false
		land(ns, nil)
		if #emotes ~= 0 then fail(scenario, "an NPC's buff with no token was thanked into the air") end
	end)
end

do
	local scenario = "thank-unseen: a caster the client will not call a player or not is not thanked"
	with(scenario, { unseen = true }, function(ns)
		Mock.extraAuraFromPlayer = nil
		land(ns, nil)
		if #emotes ~= 0 then fail(scenario, "thanked with the client saying nothing of who cast it") return end
		Mock.advance(400)
		Mock.extraAuraFromPlayer = Mock.SECRET
		land(ns, nil)
		if #emotes ~= 0 then fail(scenario, "thanked with whose cast it was withheld") end
	end)
end

do
	local scenario = "thank-unseen: Manners off, nothing is thanked"
	with(scenario, { unseen = true, delay = true }, function(ns)
		land(ns, nil)
		ns.db.profile.enabled = false
		Mock.runTimers(3.5)
		if #emotes ~= 0 then fail(scenario, "thanked with Manners switched off during the pause") end
	end)
end

-- ------------------------------------------------------------------ the limits
do
	local scenario = "thank-unseen: the gap after a named thank holds it back"
	with(scenario, { unseen = true }, function(ns)
		land(ns, "nameplate1")
		if #emotes ~= 1 then fail(scenario, "SKIPPED -- the named favour was not thanked") return end
		Mock.advance(2)
		land(ns, nil)
		if #emotes ~= 1 then fail(scenario, "two thanks two seconds apart") end
		if why(ns) ~= "thanked somebody a moment ago" then fail(scenario, "the skip says " .. tostring(why(ns))) end
	end)
end

do
	local scenario = "thank-unseen: one landing read again with a token is one thank"
	with(scenario, { unseen = true }, function(ns)
		land(ns, nil)
		if atNobody() ~= 1 then fail(scenario, "SKIPPED -- the landing was not thanked") return end
		-- The same buff handed over again under a new number, its caster read now.
		Mock.advance(1)
		land(ns, "nameplate1")
		if #emotes ~= 1 then fail(scenario, ("one landing was thanked %d times"):format(#emotes)) end
	end)
end

do
	local scenario = "thank-unseen: three buffs from one unseen druid are one thank, and the same buff again none"
	with(scenario, { unseen = true }, function(ns)
		local spells = {}
		for _, buff in ipairs(ns.BUFFS.DRUID or {}) do
			local id = buff.ranks and buff.ranks[1]
			if id and ns.ALL_BUFF_IDS[id] and not (buff.selfCast and buff.partyOnly) then spells[#spells + 1] = id end
		end
		while #spells < 3 and #spells > 0 do spells[#spells + 1] = spells[1] end
		if #spells == 0 then fail(scenario, "SKIPPED -- no druid buff here") return end
		for i = 1, 3 do
			land(ns, nil, spells[i])
			Mock.advance(1.5)
		end
		if #emotes ~= 1 then fail(scenario, ("%d emotes for three buffs"):format(#emotes)) return end
		Mock.advance(30)
		land(ns, nil, spells[1])
		if #emotes ~= 1 then fail(scenario, "the same buff thanked again half a minute later") end
		if why(ns) ~= "thanked for that buff a moment ago" then fail(scenario, "the skip says " .. tostring(why(ns))) end
		Mock.advance(400)
		land(ns, nil, spells[1])
		if #emotes ~= 2 then fail(scenario, "the same buff was never thanked again") end
	end)
end

do
	local scenario = "thank-unseen: with the pause on, the emote waits for it"
	with(scenario, { unseen = true, delay = true }, function(ns)
		land(ns, nil)
		if #emotes ~= 0 then fail(scenario, "the emote went at once with the pause on") return end
		Mock.runTimers(3.5)
		if atNobody() ~= 1 then fail(scenario, ("%d emotes after the pause"):format(#emotes)) end
	end)
end

do
	local scenario = "thank-unseen: switched off during the pause, nothing goes"
	with(scenario, { unseen = true, delay = true }, function(ns)
		land(ns, nil)
		ns.db.profile.prompt.thankUnseen = false
		Mock.runTimers(3.5)
		if #emotes ~= 0 then fail(scenario, "thanked after the switch was turned off") end
	end)
end

-- A class buff of another spell than Fortitude, for a second landing.
local function another(ns)
	for _, class in ipairs({ "MAGE", "DRUID", "PALADIN" }) do
		for _, buff in ipairs(ns.BUFFS[class] or {}) do
			local id = buff.ranks and buff.ranks[1]
			if id and id ~= fortitude(ns) and ns.ALL_BUFF_IDS[id] and not (buff.selfCast and buff.partyOnly) then
				return id
			end
		end
	end
end

do
	local scenario = "thank-unseen: a landing passed over while a named thank waits is thanked when that one never goes"
	local names = { nameplate1 = { "Anna", "Aim" } }
	with(scenario, { unseen = true, delay = true, names = names }, function(ns)
		local spell = another(ns)
		if not spell then fail(scenario, "SKIPPED -- no second class buff here") return end
		land(ns, "nameplate1")
		Mock.advance(0.5)
		land(ns, nil, spell)
		-- Anna rides off before her pause ends: her thank cannot go.
		names.nameplate1 = nil
		Mock.runTimers(3.5)
		if #emotes ~= 1 or emotes[1][2] ~= nil then
			fail(scenario, ("%d emotes, the first at %s: the unseen landing was dropped"):format(#emotes,
				tostring(emotes[1] and emotes[1][2])))
		end
	end)
end

do
	local scenario = "thank-unseen: a landing passed over while a named thank waits adds nothing when that one goes"
	with(scenario, { unseen = true, delay = true }, function(ns)
		local spell = another(ns)
		if not spell then fail(scenario, "SKIPPED -- no second class buff here") return end
		land(ns, "nameplate1")
		Mock.advance(0.5)
		land(ns, nil, spell)
		Mock.runTimers(3.5)
		if #emotes ~= 1 or emotes[1][2] ~= "nameplate1" then
			fail(scenario, ("%d emotes for a burst, the first at %s"):format(#emotes, tostring(emotes[1] and emotes[1][2])))
		end
	end)
end

-- ------------------------------------------------------------------ what it says
do
	local scenario = "thank-unseen: the nameplates line says the emote thanks them"
	with(scenario, { unseen = true, platesOff = true }, function(ns)
		land(ns, nil)
		local text = said()
		if not text:find("the game would not say who", 1, true) then fail(scenario, "SKIPPED -- no nameplates line") return end
		if not text:find("Manners thanks them with your emote", 1, true) then
			fail(scenario, "the line says nothing could be done: " .. text)
		end
	end)
end

do
	local scenario = "thank-unseen: the nameplates line names the switch to a player who thanks"
	with(scenario, { unseen = false, platesOff = true }, function(ns)
		land(ns, nil)
		local text = said()
		if not text:find("the game would not say who", 1, true) then fail(scenario, "SKIPPED -- no nameplates line") return end
		if not text:find("Thank them even when I can't see who it was", 1, true) then
			fail(scenario, "the line does not name the switch: " .. text)
		end
	end)
end

do
	local scenario = "thank-unseen: debug and the check-up say what went and what did not"
	with(scenario, { unseen = true }, function(ns)
		land(ns, nil)
		Mock.advance(2)
		land(ns, nil)
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local text = said()
		if not text:find("thank them even when you can't see who it was: |cff00ff00on", 1, true) then
			fail(scenario, "/manners debug does not say the switch is on")
		end
		if not text:find("last thanked somebody unseen", 1, true) then
			fail(scenario, "/manners debug does not say the unseen thank went")
		end
		if not text:find("last not thanked somebody unseen", 1, true) then
			fail(scenario, "/manners debug does not say the unseen thank passed over")
		end
		if not ns.FullReport():find("thankUnseen=true", 1, true) then
			fail(scenario, "the full check-up does not say the switch is on")
		end
	end)
end

-- ------------------------------------------------------------------ the options
do
	local scenario = "thank-unseen: the switch is on What I say, live with either thank"
	with(scenario, { unseen = false, thank = false }, function(ns)
		local option = findOption(ns.optionsTable, "thankUnseen")
		if not option then fail(scenario, "What I say has no such switch") return end
		local prompt = ns.db.profile.prompt
		local function off() return type(option.disabled) == "function" and option.disabled() end
		if not off() then fail(scenario, "live with the /thank and the whisper both off") end
		prompt.thankWhisper = true
		if off() then fail(scenario, "greyed with the whispered thank-you on") end
		prompt.thankWhisper, prompt.thankEmote = false, true
		if off() then fail(scenario, "greyed with the /thank on") end
		option.set(nil, true)
		if prompt.thankUnseen ~= true or option.get() ~= true then fail(scenario, "turning it on was not stored") end
		local hidden = option.hidden
		if type(hidden) == "function" then hidden = hidden() end
		if hidden then fail(scenario, "the switch is hidden for a rogue") end
	end)
end

do
	local scenario = "thank-unseen: a pasted line does not switch it on"
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.prompt.thankEmote, db.prompt.thankUnseen = true, true
		local theirs = ns.ExportSettings()
		db.prompt.thankUnseen = false
		local applied, message = ns.ImportSettings(theirs)
		if not applied then fail(scenario, "SKIPPED -- the string was refused: " .. tostring(message)) return end
		if db.prompt.thankUnseen ~= false then
			fail(scenario, "a pasted line switched it on; the import said: " .. tostring(message))
		elseif not tostring(message):find("even when you can't see who it was", 1, true) then
			fail(scenario, "the import held it off without a word: " .. tostring(message))
		end
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ the combat log
-- Classic Era: Petra the priest, named by the log from her GUID alone, with no
-- token anywhere (Mock's default log line: Fortitude 21562 on you).
local function classic(scenario, opts, body)
	opts.flavour = "vanilla"
	opts.names = opts.names or {}
	with(scenario, opts, function(ns)
		if not ns.combatLogArmed then fail(scenario, "SKIPPED -- the log is not armed") return end
		if opts.owed ~= nil then ns.db.profile.sources.owed = opts.owed end
		body(ns)
	end)
end

local function fromTheLog(ns) ns.addon:COMBAT_LOG_EVENT_UNFILTERED() end

local function listed()
	local out = {}
	for _, w in ipairs(whispers) do out[#out + 1] = tostring(w.target) .. ": " .. tostring(w.text) end
	return table.concat(out, " | ")
end

do
	local scenario = "thank-unseen: classic: a stranger the log names and no token holds is whispered by name"
	classic(scenario, { unseen = true, whisper = true, thank = false, owed = false }, function(ns)
		fromTheLog(ns)
		if #whispers ~= 1 then fail(scenario, ("%d whispers went"):format(#whispers)) return end
		if whispers[1].target ~= "Petra" or whispers[1].channel ~= "WHISPER" then
			fail(scenario, "the whisper went: " .. listed())
		end
		if #emotes ~= 0 then fail(scenario, "an emote went with the /thank off") end
	end)
end

do
	local scenario = "thank-unseen: classic: off, the log whispers nobody"
	classic(scenario, { unseen = false, whisper = true, thank = false }, function(ns)
		fromTheLog(ns)
		if #whispers ~= 0 then fail(scenario, "whispered by name with the switch off: " .. listed()) end
	end)
end

do
	local scenario = "thank-unseen: classic: somebody you will buff back is not whispered"
	classic(scenario, { class = "MAGE", unseen = true, whisper = true, thank = false, owed = true }, function(ns)
		if #ns.CastableBuffs() == 0 then fail(scenario, "SKIPPED -- the mage has nothing to cast") return end
		fromTheLog(ns)
		if not ns.owed.Petra then fail(scenario, "SKIPPED -- no debt was filed") return end
		if #whispers ~= 0 then fail(scenario, "a favour you will return was whispered: " .. listed()) end
	end)
end

do
	local scenario = "thank-unseen: classic: a bare name the client will not place on your realm is not whispered"
	classic(scenario, { unseen = true, whisper = true, thank = false, owed = false }, function(ns)
		Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra" } }
		fromTheLog(ns)
		if #whispers ~= 0 then fail(scenario, "whispered a name of no known realm: " .. listed()) end
	end)
end

do
	local scenario = "thank-unseen: classic: somebody a token holds is left to the aura scan"
	classic(scenario, { unseen = true, whisper = true, thank = false, names = { nameplate1 = { "Petra" } } },
		function(ns)
			if ns.UnitFullName("nameplate1") ~= "Petra" then fail(scenario, "SKIPPED -- the nameplate is not Petra") return end
			fromTheLog(ns)
			if #whispers ~= 0 then fail(scenario, "the log whispered somebody a token holds: " .. listed()) return end
			land(ns, "nameplate1", 21562)
			if #whispers ~= 1 then fail(scenario, ("the aura scan's whisper: %d went"):format(#whispers)) end
		end)
end

do
	local scenario = "thank-unseen: classic: the log's whisper and the scan's late reading of one landing are one thank"
	classic(scenario, { unseen = true, whisper = true }, function(ns)
		fromTheLog(ns)
		if #whispers ~= 1 then fail(scenario, "SKIPPED -- the log's whisper did not go") return end
		Mock.advance(12)
		land(ns, nil, 21562)
		if #emotes ~= 0 then fail(scenario, "one landing was whispered and then thanked with an emote") end
	end)
end

do
	local scenario = "thank-unseen: classic: the scan's emote and the log's late line of one landing are one thank"
	classic(scenario, { unseen = true, whisper = true }, function(ns)
		land(ns, nil, 21562)
		if atNobody() ~= 1 then fail(scenario, "SKIPPED -- the scan's emote did not go") return end
		Mock.advance(12)
		fromTheLog(ns)
		if #whispers ~= 0 then fail(scenario, "one landing was thanked with an emote and then whispered: " .. listed()) end
	end)
end

do
	local scenario = "thank-unseen: classic: the whisper by name refused after its pause leaves the emote to the scan"
	classic(scenario, { unseen = true, whisper = true, delay = true, owed = false }, function(ns)
		fromTheLog(ns)
		if #whispers ~= 0 then fail(scenario, "SKIPPED -- the whisper did not wait out its pause") return end
		Mock.advance(0.5)
		land(ns, nil, 21562)
		-- By the end of the pause the client will not place the name on your realm.
		Mock.guids = { ["Player-1-PETRA"] = { class = "PRIEST", name = "Petra" } }
		Mock.runTimers(3.5)
		if #whispers ~= 0 then fail(scenario, "SKIPPED -- the whisper went all the same") return end
		if atNobody() ~= 1 then fail(scenario, ("%d emotes: one landing, and nobody thanked"):format(atNobody())) end
	end)
end
