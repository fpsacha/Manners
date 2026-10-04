-- The helpers Start here is built on (Options.lua): the quick choices of who to
-- offer to and what to say (ns.QuickSetup), the sentences that describe the
-- result, and the key binding and macro helpers (ns.Setup).
--
-- A preset writes plain profile fields and then runs the hooks the individual
-- setters run; a dropdown shows the preset the profile matches, or "Custom"
-- when none does, and Custom is never something that can be picked.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function said()
	return table.concat(Mock.printed, "\n")
end

-- Every field an entry sets, as it stands now, compared with the entry.
local function holds(ns, entry)
	local quick = ns.QuickSetup
	for path, value in pairs(entry.set) do
		if quick.Get(path) ~= value then return false, path end
	end
	return true
end

local function session(scenario, class)
	Mock.reset()
	if class then Mock.class = class end
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	return ns
end

-- ------------------------------------------------------------------ who 1
do
	local scenario = "presets: a new profile is Everyone near me and Stay silent"
	local ns = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		if not quick then
			fail(scenario, "there is no ns.QuickSetup")
		else
			if quick.Match(quick.WHO) ~= "nearby" then
				fail(scenario, "a new profile matches " .. tostring(quick.Match(quick.WHO))
					.. ", not Everyone near me, which is what the defaults are")
			end
			if quick.Values(quick.WHO).custom then
				fail(scenario, "Custom is offered on a profile nobody has touched")
			end
			if quick.Match(quick.VOICE) ~= "silent" then
				fail(scenario, "a new profile's voice matches " .. tostring(quick.Match(quick.VOICE)))
			end
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ who 2
do
	local scenario = "presets: each Who preset writes its fields and is then shown"
	local ns = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		local db = ns.db.profile
		-- Asking in chat is its own opt-in and no preset may touch it; nor the
		-- buff, the speech or the look.
		db.sources.asked = true
		db.buff.choice = "auto"
		db.speech.enabled = true
		db.prompt.scale = 1.25
		for _, entry in ipairs(quick.WHO) do
			Mock.printed = {}
			quick.Apply(quick.WHO, entry.key)
			local ok, path = holds(ns, entry)
			if not ok then
				fail(scenario, entry.key .. " did not write " .. tostring(path))
			end
			if quick.Match(quick.WHO) ~= entry.key then
				fail(scenario, "after " .. entry.key .. " the dropdown shows "
					.. tostring(quick.Match(quick.WHO)))
			end
			if not said():find("Set up: " .. entry.name .. ".", 1, true) then
				fail(scenario, entry.key .. " said nothing in chat: " .. said())
			end
			if db.sources.asked ~= true then
				fail(scenario, entry.key .. " switched off People who ask me in chat")
				db.sources.asked = true
			end
			if db.buff.choice ~= "auto" or db.speech.enabled ~= true or db.prompt.scale ~= 1.25 then
				fail(scenario, entry.key .. " changed the buff, the speech or the look")
			end
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ who 3
do
	local scenario = "presets: a change by hand shows Custom, which cannot be picked"
	local ns = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		local db = ns.db.profile
		quick.Apply(quick.WHO, "group")
		if quick.Confirm(quick.WHO, "favours") then
			fail(scenario, "moving from one preset to another asks first, with nothing of yours to lose")
		end
		db.filters.whenBuffed = "always"
		if quick.Match(quick.WHO) ~= "custom" then
			fail(scenario, "a choice made by hand still shows " .. tostring(quick.Match(quick.WHO)))
		end
		local values, order = quick.Values(quick.WHO), quick.Order(quick.WHO)
		if not values.custom then
			fail(scenario, "Custom is not among the choices, so the dropdown is blank")
		end
		if order[#order] ~= "custom" then
			fail(scenario, "Custom is not last in the dropdown")
		end
		for i, entry in ipairs(quick.WHO) do
			if order[i] ~= entry.key then
				fail(scenario, "the dropdown is not in the list's order: " .. table.concat(order, ", "))
				break
			end
		end
		local question = quick.Confirm(quick.WHO, "favours")
		if type(question) ~= "string" or not question:find("Who to buff", 1, true) then
			fail(scenario, "replacing choices made by hand does not ask first: " .. tostring(question))
		end
		Mock.printed = {}
		quick.Apply(quick.WHO, "custom")
		if db.filters.whenBuffed ~= "always" or said():find("Set up", 1, true) then
			fail(scenario, "picking Custom changed something")
		end
		quick.Apply(quick.WHO, "raid")
		if quick.Values(quick.WHO).custom then
			fail(scenario, "Custom is still offered once a preset matches")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ who 4
do
	local scenario = "presets: a warrior is not offered Everyone near me"
	Mock.reset()
	Mock.class = "WARRIOR"
	local ns = load(scenario)
	if ns then
		local known = {}
		for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
		local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		local quick = ns.QuickSetup
		if not ns.OnlyReachesGroup() then
			fail(scenario, "SKIPPED -- the shout is not the only thing on offer")
		else
			if quick.Values(quick.WHO).nearby then
				fail(scenario, "a shout that never reaches a passer-by is offered Everyone near me")
			end
			-- The defaults leave passers-by on, which means nothing here: they
			-- are not held against the other choices.
			if quick.Match(quick.WHO) ~= "group" then
				fail(scenario, "a new warrior's profile shows " .. tostring(quick.Match(quick.WHO))
					.. " rather than People who buff me, and my group")
			end
			if quick.WhoSummary():find("passers-by", 1, true) then
				fail(scenario, "the summary promises a warrior passers-by: " .. quick.WhoSummary())
			end
		end
		IsSpellKnown, IsPlayerSpell = realKnown, realPlayer
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ voice 1
do
	local scenario = "presets: each Voice preset writes its fields and lines and is then shown"
	local ns = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		local sp = ns.db.profile.speech
		local found = {}
		for _, entry in ipairs(quick.VOICE) do
			found[entry.key] = true
			quick.Apply(quick.VOICE, entry.key)
			local ok, path = holds(ns, entry)
			if not ok then fail(scenario, entry.key .. " did not write " .. tostring(path)) end
			if entry.lines then
				if sp.presetChoice ~= entry.lines then
					fail(scenario, entry.key .. " did not choose the " .. entry.lines .. " lines")
				end
				if sp.phrases ~= ns.PhraseSetText(entry.lines) then
					fail(scenario, entry.key .. " did not load the " .. entry.lines .. " lines")
				end
			end
			if quick.Match(quick.VOICE) ~= entry.key then
				fail(scenario, "after " .. entry.key .. " the dropdown shows "
					.. tostring(quick.Match(quick.VOICE)))
			end
		end
		for _, key in ipairs({ "silent", "thank", "polite", "whisper" }) do
			if not found[key] then fail(scenario, "there is no " .. key .. " choice") end
		end
		if ns.InCharacter and not found.incharacter then
			fail(scenario, "In character is loaded and not offered")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ voice 2
do
	local scenario = "presets: lines written by hand are Custom, and replacing them asks"
	local ns = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		local sp = ns.db.profile.speech
		quick.Apply(quick.VOICE, "polite")
		if quick.Confirm(quick.VOICE, "whisper") then
			fail(scenario, "loading the lines over unedited lines asks first")
		end
		sp.phrases = "Cheers, {name}!"
		if quick.Match(quick.VOICE) ~= "custom" then
			fail(scenario, "edited lines still show " .. tostring(quick.Match(quick.VOICE)))
		end
		local question = quick.Confirm(quick.VOICE, "whisper")
		if type(question) ~= "string" or not question:find("Whisper them a thank-you", 1, true) then
			fail(scenario, "replacing lines written by hand does not ask, naming the choice: "
				.. tostring(question))
		end
		if quick.Confirm(quick.VOICE, "silent") then
			fail(scenario, "a choice that loads no lines asks about replacing them")
		end
		quick.Apply(quick.VOICE, "silent")
		if sp.phrases ~= "Cheers, {name}!" then
			fail(scenario, "Stay silent threw away the lines written by hand")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ combat
do
	local scenario = "presets: picked in combat, the button waits for the fight to end"
	local ns = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		local button = ns.Prompt:GetButton()
		button._protected = true
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.protectedCalls = {}
		local before = button:GetAttribute("macrotext1")
		quick.Apply(quick.VOICE, "polite")
		quick.Apply(quick.WHO, "raid")
		if #Mock.protectedCalls > 0 then
			fail(scenario, "a preset in combat called " .. table.concat(Mock.protectedCalls, ", "))
		end
		if button:GetAttribute("macrotext1") ~= before then
			fail(scenario, "a preset in combat rewrote the button's macro")
		end
		if ns.db.profile.speech.enabled ~= true or ns.db.profile.filters.whenBuffed ~= "refresh" then
			fail(scenario, "a preset in combat did not save its choices")
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ summaries
do
	local scenario = "presets: the summaries say what is set"
	local ns = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		local db = ns.db.profile
		local who = quick.WhoSummary()
		for _, part in ipairs({ "people who buff me", "my group", "passers-by within about 10 yards",
			"Already buffed: skipped." }) do
			if not who:find(part, 1, true) then
				fail(scenario, "a new profile's summary leaves out \"" .. part .. "\": " .. who)
			end
		end
		if who:find("ask in chat", 1, true) then
			fail(scenario, "the summary says chat requests are on when they are off: " .. who)
		end
		db.sources.asked = true
		if not quick.WhoSummary():find("People who ask in chat: on.", 1, true) then
			fail(scenario, "the summary does not say chat requests are on: " .. quick.WhoSummary())
		end
		quick.Apply(quick.WHO, "raid")
		if not quick.WhoSummary():find("topped up when low", 1, true)
			or quick.WhoSummary():find("passers-by", 1, true) then
			fail(scenario, "the summary does not follow the preset: " .. quick.WhoSummary())
		end
		db.sources.owed, db.sources.group, db.sources.self = false, false, false
		if not quick.WhoSummary():find("nobody", 1, true) then
			fail(scenario, "with every source off the summary does not say nobody: "
				.. quick.WhoSummary())
		end
		db.sources.owed, db.sources.group, db.sources.self = true, true, true

		quick.Apply(quick.VOICE, "silent")
		if quick.VoiceSummary() ~= "Silent." then
			fail(scenario, "Stay silent reads " .. quick.VoiceSummary())
		end
		quick.Apply(quick.VOICE, "thank")
		if quick.VoiceSummary() ~= "Only /thank." then
			fail(scenario, "Just /thank them reads " .. quick.VoiceSummary())
		end
		quick.Apply(quick.VOICE, "polite")
		local voice = quick.VoiceSummary()
		if voice ~= "Says a polite line in /say when you buff someone back." then
			fail(scenario, "A polite line reads " .. voice)
		end
		quick.Apply(quick.VOICE, "whisper")
		if not quick.VoiceSummary():find("whisper", 1, true) then
			fail(scenario, "Whisper them a thank-you reads " .. quick.VoiceSummary())
		end
		db.speech.phrases = "Cheers, {name}!"
		if not quick.VoiceSummary():find("your own lines", 1, true) then
			fail(scenario, "lines written by hand are described as a set: " .. quick.VoiceSummary())
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ summaries 2
-- Every set is named by a phrase of its own, never by the dropdown's label
-- dropped into "a %s line": "Says a In character: your race and faction line"
-- was the first thing a roleplayer read.
do
	local scenario = "presets: every line set reads as English in the summary"
	local ns = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		local sp = ns.db.profile.speech
		sp.enabled, sp.channel, sp.onlyWhenReturning = true, "SAY", true
		local want = {
			roleplay = "Says a line from Azeroth in /say when you buff someone back.",
			polite = "Says a polite line in /say when you buff someone back.",
			cheeky = "Says a cheeky line in /say when you buff someone back.",
			quiet = "Says just their name in /say when you buff someone back.",
			incharacter = "Says an in-character line in /say when you buff someone back.",
		}
		for _, key in ipairs(ns.PHRASE_SET_ORDER) do
			sp.presetChoice = key
			sp.phrases = ns.PhraseSetText(key)
			local got = quick.VoiceSummary()
			if want[key] and got ~= want[key] then
				fail(scenario, key .. " reads " .. got)
			elseif not want[key] then
				fail(scenario, "no expected summary for the " .. key .. " set: " .. got)
			end
		end
		sp.presetChoice = "polite"
		sp.phrases = ns.PhraseSetText("polite")
		sp.onlyWhenReturning = false
		if quick.VoiceSummary() ~= "Says a polite line in /say when you buff someone." then
			fail(scenario, "speaking to everyone you buff reads " .. quick.VoiceSummary())
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ summaries 3
-- The first page must not contradict the queue: a favour is offered back
-- whatever the person already carries, and group buffs and who goes first are
-- said while they are on.
do
	local scenario = "presets: the Who summary says what favours and the group bring"
	local ns = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		local db = ns.db.profile
		-- Yourself off, so the sentence names only the people who buff
		-- you; tests/scenarios/self.lua reads it with you in.
		db.sources.self = false
		quick.Apply(quick.WHO, "favours")
		local who = quick.WhoSummary()
		if who ~= "Offering to: people who buff me." then
			fail(scenario, "favours only reads " .. who)
		end
		quick.Apply(quick.WHO, "group")
		who = quick.WhoSummary()
		if not who:find("Already buffed: skipped. People who buff me are always offered one back.", 1, true) then
			fail(scenario, "with the group on, the summary does not say favours are always returned: " .. who)
		end
		db.priority.readyCheck, db.priority.revived = true, true
		if not quick.WhoSummary():find("Ready checks and the just-revived go first.", 1, true) then
			fail(scenario, "the summary leaves out who goes first: " .. quick.WhoSummary())
		end
		db.priority.readyCheck, db.priority.revived = false, false
		if quick.WhoSummary():find("go first", 1, true) then
			fail(scenario, "the summary says somebody goes first with both switches off: " .. quick.WhoSummary())
		end
		db.priority.readyCheck = true
		if not quick.WhoSummary():find("At a ready check, your group goes first.", 1, true) then
			fail(scenario, "the ready check alone is not said: " .. quick.WhoSummary())
		end
		db.priority.readyCheck, db.priority.revived = true, true
		quick.Apply(quick.WHO, "favours")
		if quick.WhoSummary():find("go first", 1, true) then
			fail(scenario, "with the group off, the summary still talks about the group: " .. quick.WhoSummary())
		end

		-- A group buff this character has learned, with its reagent in the
		-- bags. Stood in for only while the summary is read.
		quick.Apply(quick.WHO, "raid")
		local realHas, realCastable, realInfo, realCount = ns.ClassHasGroupBuffs, ns.CastableBuffs,
			ns.BuffInfo, ns.ReagentCount
		local buff = { key = "intellect" }
		local count = 5
		ns.ClassHasGroupBuffs = function() return true end
		ns.CastableBuffs = function() return { buff } end
		ns.BuffInfo = function() return { groupRank = 23028, groupReagent = 17020 } end
		ns.ReagentCount = function() return count end
		db.groupBuffs.use, db.groupBuffs.atLeast = true, 3
		who = quick.WhoSummary()
		-- A mage's on Forever counts the whole raid (GroupBuffs.lua).
		if not who:find("Group buffs when 3 of your party or raid need it (", 1, true)
			or not who:find(": 5 in bags).", 1, true) then
			fail(scenario, "the group buffs and their reagent are not said: " .. who)
		end
		count = 0
		if not quick.WhoSummary():find("none in your bags, so group buffs are not offered.", 1, true) then
			fail(scenario, "an empty bag is not said: " .. quick.WhoSummary())
		end
		db.groupBuffs.use = false
		if quick.WhoSummary():find("roup buffs", 1, true) then
			fail(scenario, "group buffs are said with Use group buffs off: " .. quick.WhoSummary())
		end
		ns.ClassHasGroupBuffs, ns.CastableBuffs, ns.BuffInfo, ns.ReagentCount =
			realHas, realCastable, realInfo, realCount
		db.groupBuffs.use = true
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ summaries 4
-- The /thank answers somebody buffing you, with People who buff me on or off
-- (Favours.lua, NoteFavour), so the summary says it the same either way. It
-- used to say the /thank waited for that switch, which was true then.
do
	local scenario = "presets: a /thank is said the same with People who buff me off"
	local ns = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		-- Just /thank them alone, then a polite line with the /thank on too.
		local function summaries()
			quick.Apply(quick.VOICE, "thank")
			local alone = quick.VoiceSummary()
			quick.Apply(quick.VOICE, "polite")
			ns.db.profile.prompt.thankEmote = true
			return alone, quick.VoiceSummary()
		end
		local function saysThanks(voice)
			return voice:find("Also /thanks people who buff you.", 1, true) ~= nil
				and not voice:find("People who buff me", 1, true)
		end
		ns.db.profile.sources.owed = false
		local alone, withLine = summaries()
		if alone ~= "Only /thank." then
			fail(scenario, "with People who buff me off, Just /thank them reads " .. alone)
		end
		if not saysThanks(withLine) then
			fail(scenario, "with People who buff me off, a line and a /thank reads " .. withLine)
		end
		ns.db.profile.sources.owed = true
		alone, withLine = summaries()
		if alone ~= "Only /thank." then
			fail(scenario, "with People who buff me on, Just /thank them reads " .. alone)
		end
		if not saysThanks(withLine) then
			fail(scenario, "with People who buff me on, a line and a /thank reads " .. withLine)
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ tuning
-- Fine-tuning a choice is not leaving it: a passer-by distance changed by
-- hand, or speaking to people buffed first, keeps the dropdown on the choice.
do
	local scenario = "presets: fine-tuning a choice keeps it"
	local ns = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		local db = ns.db.profile
		quick.Apply(quick.WHO, "nearby")
		local far
		for _, tier in ipairs(ns.PROXIMITY) do
			if tier.key ~= "near" then far = tier.key end
		end
		db.filters.proximity = far
		if quick.Match(quick.WHO) ~= "nearby" then
			fail(scenario, "a passer-by distance changed by hand shows " .. tostring(quick.Match(quick.WHO)))
		end
		if quick.Confirm(quick.WHO, "group") then
			fail(scenario, "moving on from a tuned Everyone near me asks as if it were Custom")
		end
		quick.Apply(quick.WHO, "nearby")
		if db.filters.proximity ~= "near" then
			fail(scenario, "picking Everyone near me did not set the distance")
		end

		quick.Apply(quick.VOICE, "polite")
		db.speech.onlyWhenReturning = false
		if quick.Match(quick.VOICE) ~= "polite" then
			fail(scenario, "speaking to people buffed first shows " .. tostring(quick.Match(quick.VOICE)))
		end
		quick.Apply(quick.VOICE, "polite")
		if db.speech.onlyWhenReturning ~= true then
			fail(scenario, "picking A polite line did not set Only when I buff someone back")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ group settings
-- The group buffs and the two priorities are Who to buff's fine-tuning, and no
-- Who choice writes them: one that did turned reagent-eating group buffs back
-- on without asking, and one that did not left them on under another name.
do
	local scenario = "presets: no Who choice touches group buffs or who goes first"
	local ns = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		local db = ns.db.profile
		quick.Apply(quick.WHO, "group")
		db.groupBuffs.use, db.priority.readyCheck, db.priority.revived = false, false, false
		if quick.Match(quick.WHO) ~= "group" then
			fail(scenario, "switching group buffs off by hand shows " .. tostring(quick.Match(quick.WHO)))
		end
		for _, entry in ipairs(quick.WHO) do
			quick.Apply(quick.WHO, entry.key)
			if db.groupBuffs.use ~= false or db.priority.readyCheck ~= false or db.priority.revived ~= false then
				fail(scenario, entry.key .. " switched group buffs or a priority back on")
				db.groupBuffs.use, db.priority.readyCheck, db.priority.revived = false, false, false
			end
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ shared profile
-- Every character starts on the shared Default profile. Start here says so
-- while another character is on it, and offers this one its own copy.
do
	local scenario = "setup: a shared profile is said, and can be made this character's own"
	local ns = session(scenario)
	if ns then
		local general = ns.optionsTable.args.general.args
		local note, own = general.sharedNote, general.ownProfile
		local db = ns.db
		local profiles = { Default = db.profile }
		local current = "Default"
		db.keys = { char = "Mort Defrette - Realm" }
		db.sv = { profileKeys = { ["Mort Defrette - Realm"] = "Default" } }
		db.GetCurrentProfile = function() return current end
		local realSet = db.SetProfile
		db.SetProfile = function(self, name)
			current = name
			profiles[name] = profiles[name] or {}
			self.sv.profileKeys[self.keys.char] = name
		end
		local copiedFrom
		db.CopyProfile = function(_, name) copiedFrom = name end
		if not (note and own) then
			fail(scenario, "Start here has no shared-profile line or button")
		else
			if not (note.hidden() and own.hidden()) then
				fail(scenario, "the shared-profile line shows with nobody else on the profile")
			end
			db.sv.profileKeys["Anna - Realm"] = "Default"
			if note.hidden() or own.hidden() then
				fail(scenario, "a profile two characters share is not said")
			elseif not note.name():find("These settings are shared by your other characters (profile: Default).", 1, true) then
				fail(scenario, "the shared-profile line reads " .. note.name())
			end
			if not (note.order < general.whoHeader.order) then
				fail(scenario, "the shared-profile line is not above step 1")
			end
			Mock.inCombat = true
			if not own.disabled() then fail(scenario, "the own-settings button is live in combat") end
			ns.Setup.OwnProfile()
			if current ~= "Default" then fail(scenario, "the profile was switched in combat") end
			Mock.inCombat = false
			Mock.printed = {}
			own.func()
			if current ~= "Mort Defrette - Realm" or copiedFrom ~= "Default" then
				fail(scenario, "the button did not give this character a copy of the shared settings: "
					.. tostring(current) .. " from " .. tostring(copiedFrom))
			end
			if not said():find("its own settings", 1, true) then
				fail(scenario, "making a profile of its own said nothing: " .. said())
			end
			if not (note.hidden() and own.hidden()) then
				fail(scenario, "the shared-profile line stays up on a profile of its own")
			end
		end
		db.SetProfile, db.CopyProfile, db.GetCurrentProfile, db.keys, db.sv = realSet, nil, nil, nil, nil
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ key 1
do
	local scenario = "setup: a key is bound, moved and cleared"
	local ns = session(scenario)
	if ns then
		local setup = ns.Setup
		local command = "CLICK MannersPrompt:LeftButton"
		if setup.COMMAND ~= command then
			fail(scenario, "the binding is not the one Bindings.xml declares: " .. tostring(setup.COMMAND))
		end
		if setup.Key() ~= nil then fail(scenario, "a new session already has a key") end
		setup.SetKey("F")
		if Mock.bindings.F ~= command or setup.Key() ~= "F" then
			fail(scenario, "F was not bound to the prompt")
		end
		if Mock.bindingsSaved < 1 or Mock.bindingSet ~= 2 then
			fail(scenario, "the binding was not saved to the set in use")
		end
		-- A key that was doing something else: said out loud, then taken.
		Mock.bindings.G = "JUMP"
		_G.BINDING_NAME_JUMP = "Jump"
		Mock.printed = {}
		setup.SetKey("G")
		_G.BINDING_NAME_JUMP = nil
		if Mock.bindings.F ~= nil then fail(scenario, "the old key still buffs as well") end
		if Mock.bindings.G ~= command then fail(scenario, "G was not bound to the prompt") end
		if not said():find("G was bound to Jump", 1, true) then
			fail(scenario, "taking a key from Jump said nothing: " .. said())
		end
		-- In combat the game refuses it, so nothing is tried.
		Mock.inCombat = true
		setup.SetKey("H")
		Mock.inCombat = false
		if Mock.bindings.H ~= nil or Mock.bindings.G ~= command then
			fail(scenario, "a key was changed in combat")
		end
		setup.SetKey("")
		if setup.Key() ~= nil or Mock.bindings.G ~= nil then
			fail(scenario, "clearing the key left one bound")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ key 2
do
	local scenario = "setup: the macro and the key bindings window"
	local ns = session(scenario)
	if ns then
		local setup = ns.Setup
		if setup.MacroMade() then fail(scenario, "a macro nobody made counts as made") end
		Mock.macros = { Manners = 3 }
		if not setup.MacroMade() then fail(scenario, "the Manners macro is not noticed") end

		local realSettings = rawget(_G, "Settings")
		local opened, closed = nil, 0
		local realClose = ns.CloseOptions
		ns.CloseOptions = function() closed = closed + 1 end
		rawset(_G, "Settings", nil)
		if setup.CanOpenBindings() then
			fail(scenario, "a client with no way to the key bindings offers the button")
		end
		rawset(_G, "Settings", { KEYBINDINGS_CATEGORY_ID = 42,
			OpenToCategory = function(id) opened = id end })
		if not setup.CanOpenBindings() then
			fail(scenario, "the key bindings button is hidden where Settings can open them")
		end
		Mock.inCombat = true
		if setup.OpenBindings() or opened then fail(scenario, "the key bindings opened in combat") end
		Mock.inCombat = false
		if not setup.OpenBindings() or opened ~= 42 then
			fail(scenario, "the key bindings were not opened by their category")
		end
		if closed < 1 then
			fail(scenario, "the options window stayed up over the key bindings")
		end
		rawset(_G, "Settings", realSettings)

		-- Make a macro opens the game's macro window, so the macro is there
		-- to drag; never in a fight.
		local shownMacros = 0
		rawset(_G, "ShowMacroFrame", function() shownMacros = shownMacros + 1 end)
		Mock.inCombat = true
		if setup.OpenMacros() or shownMacros > 0 then fail(scenario, "the macro window opened in combat") end
		Mock.inCombat = false
		local make = ns.optionsTable.args.general.args.makeMacro
		local realCreate = ns.CreateClickMacro
		ns.CreateClickMacro = function() Mock.macros = { Manners = 3 } end
		Mock.macros = {}
		make.func()
		if shownMacros ~= 1 then
			fail(scenario, "Make a macro did not open the macro window")
		end
		local status = H.optionText(ns.optionsTable.args.general.args.bindStatus.name)
		if not status:find("open the macro window (/macro) and drag it onto an action bar", 1, true) then
			fail(scenario, "the made-macro line does not say where to drag it from: " .. status)
		end
		ns.CreateClickMacro = realCreate
		rawset(_G, "ShowMacroFrame", nil)
		ns.CloseOptions = realClose
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ voice 4
-- "In character" speaks to everybody it buffs. Picked on Start here it used to
-- switch "Only when I buff someone back" on, so its lines for a request, a
-- stranger or the group were never heard: a player picked it, buffed a
-- passer-by, and their character said nothing. The thank-you choices still
-- speak only when returning a favour. The choice leads What I say in the
-- options window, right above the switch itself, so Start here's copy of the
-- switch is gone, and so is the choice's tooltip pointing at What I say.
do
	local scenario = "presets: In character speaks when you buff a stranger"
	Mock.reset()
	local restore = H.strangers({ nameplate1 = { "Munin", "Hugins" } })
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local quick = ns.QuickSetup
		local sp = ns.db.profile.speech
		if not (ns.InCharacter and quick.Find(quick.VOICE, "incharacter")) then
			fail(scenario, "SKIPPED -- there is no In character choice")
		else
			quick.Apply(quick.VOICE, "incharacter")
			if sp.onlyWhenReturning ~= false then
				fail(scenario, "In character switched Only when I buff someone back on")
			end
			ns.Prompt:InvalidateMacro()
			ns.addon:Tick()
			local text = ns.Prompt:GetButton():GetAttribute("macrotext1")
			if not (text and text:find("/cast", 1, true)) then
				fail(scenario, "SKIPPED -- nobody is on the prompt: " .. tostring(text))
			elseif not text:find("\n/say ", 1, true) then
				fail(scenario, "a press on a passer-by says nothing: "
					.. (tostring(text):gsub("\n", " / ")))
			end
			local general = ns.optionsTable.args.general.args
			if general.onlyWhenReturning then
				fail(scenario, "Start here still has its own copy of Only when I buff someone back")
			end
			local toggle = ns.optionsTable.args.click.args.onlyWhenReturning
			local disabled = toggle and toggle.disabled
			if type(disabled) == "function" then disabled = disabled({}) end
			if not toggle or disabled then
				fail(scenario, "What I say has no live Only when I buff someone back under the choice")
			end
			if general.quickVoice and general.quickVoice.desc ~= nil then
				fail(scenario, "When I buff someone still points at What I say, the page it leads: "
					.. H.optionText(general.quickVoice.desc))
			end
			if ns.WindowLayout then
				local list = H.pagePaths(ns, "click") or {}
				local choice, switch
				for i, path in ipairs(list) do
					if path == "general.quickVoice" then choice = i end
					if path == "click.onlyWhenReturning" then switch = i end
				end
				if not (choice and switch and choice < switch) then
					fail(scenario, "the choice does not lead What I say above Only when I buff someone back")
				end
			end
			quick.Apply(quick.VOICE, "polite")
			if sp.onlyWhenReturning ~= true then
				fail(scenario, "A polite line speaks to everybody you buff")
			end
		end
		restore()
	end
end
