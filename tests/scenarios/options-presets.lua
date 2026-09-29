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
		db.sources.owed, db.sources.group = false, false
		if not quick.WhoSummary():find("nobody", 1, true) then
			fail(scenario, "with every source off the summary does not say nobody: "
				.. quick.WhoSummary())
		end

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
		if not (voice:find("Polite", 1, true) and voice:find("/say", 1, true)
			and voice:find("back", 1, true)) then
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
		ns.CloseOptions = realClose
		noErrors(scenario, ns)
	end
end
