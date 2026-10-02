-- The What I say tab (Options/Say.lua, BuildSpeechTab): the social replies to
-- a buff and nothing else. The /thank, whether a line is said, where and when;
-- then the lines themselves, a section that is only there while a line is
-- said at all. Targeting lives on Advanced. The options window leads the page
-- with Start here's voice choice, so it has no intro pointing there.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption, optionText = H.findOption, H.optionText

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
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

local function tab(ns)
	return ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.click
end

local function shown(control)
	if not control then return false end
	return not (type(control.hidden) == "function" and control.hidden({}))
		and control.hidden ~= true
end

local function live(control)
	if not control then return false end
	return not (type(control.disabled) == "function" and control.disabled({}))
		and control.disabled ~= true
end

-- ------------------------------------------------------------------ layout
do
	local scenario = "click tab: the social replies, in order"
	local ns = session(scenario)
	local click = ns and tab(ns)
	if ns and not click then
		fail(scenario, "SKIPPED -- there is no click tab")
	elseif click then
		if click.name ~= "What I say" then
			fail(scenario, "the tab is called " .. tostring(click.name))
		end
		if click.order ~= 4 then
			fail(scenario, "the What I say tab is not fourth: order " .. tostring(click.order))
		end
		local want = {
			{ "combatNotice", 0.5 },
			{ "speechHeader", 10, "Thanks and speech" },
			{ "thankEmote", 11, "/thank people who buff me" },
			{ "enabled", 12, "Say a line when I buff someone" },
			{ "channel", 13, "Where to say it" },
			{ "onlyWhenReturning", 14, "Only when I buff someone back" },
			{ "linesOff", 19.5 },
			{ "phrasesHeader", 20, "Lines" },
			{ "preset", 21, "Line set" },
			{ "phrasesHelp", 22 },
			{ "inCharacterNote", 22.5 },
			{ "phrases", 23, "Your lines (one per line)" },
			{ "backToInCharacter", 23.5, "Go back to In character" },
			{ "roll", 24, "Try a few lines" },
			{ "limits", 25 },
		}
		for _, row in ipairs(want) do
			local control = click.args[row[1]]
			if not control then
				fail(scenario, row[1] .. " is not on the What I say tab")
			else
				if control.order ~= row[2] then
					if row[1] == "thankEmote" then
						fail(scenario, "/thank people who buff me is not first under Thanks and speech")
					else
						fail(scenario, ("%s sits at %s, not %s"):format(row[1], tostring(control.order),
							tostring(row[2])))
					end
				end
				if row[3] and optionText(control.name) ~= row[3] then
					fail(scenario, ("%s is labelled %q"):format(row[1], optionText(control.name)))
				end
			end
		end
		for _, key in ipairs({ "targetingHeader", "restoreTarget", "noTargetNote", "targetingNote" }) do
			if click.args[key] then fail(scenario, key .. " is still on What I say, not Advanced") end
		end
		-- It only repeated the switch above it, and said "hear" for "say".
		if click.args.onlyNote then
			fail(scenario, "the note repeating Only when I buff someone back is still on the tab")
		end
		-- The voice choice leads the page now; an intro saying Start here
		-- has quick choices would point at the row right under it.
		if click.args.intro then
			fail(scenario, "the intro pointing at Start here's quick choices is still on the tab")
		end
		local roll = click.args.roll
		if not optionText(roll and roll.desc):find("only you see them", 1, true) then
			fail(scenario, "Try a few lines does not say only you see them")
		end
		local thank = click.args.thankEmote
		if thank then
			if not optionText(thank.desc):find("at most once per person every five minutes", 1, true) then
				fail(scenario, "the /thank toggle does not say how often it thanks")
			end
			ns.db.profile.sources.owed = false
			if live(thank) then fail(scenario, "the /thank toggle is live with People who buff me off") end
			ns.db.profile.sources.owed = true
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ rogue
do
	local scenario = "click tab: hidden for a class with nothing to cast"
	local ns = session(scenario, "ROGUE")
	local click = ns and tab(ns)
	if click then
		if ns.caps.hasClassBuffs then
			fail(scenario, "SKIPPED -- the rogue has class buffs here")
		elseif shown(click) then
			fail(scenario, "What I say shows for a rogue, who has nothing to say it with")
		end
	end
end

-- ------------------------------------------------------------------ the switch
do
	local scenario = "click tab: the Lines section follows Say a line"
	local ns = session(scenario)
	local click = ns and tab(ns)
	if click then
		local a = click.args
		local speech = ns.db.profile.speech

		speech.enabled = false
		speech.onlyWhenReturning = true
		if shown(a.phrasesHeader) then fail(scenario, "the Lines header stays up with speech off") end
		if shown(a.preset) then fail(scenario, "the Line set dropdown stays up with speech off") end
		if shown(a.phrasesHelp) then fail(scenario, "the placeholder help stays up with speech off") end
		if shown(a.phrases) then fail(scenario, "the phrase box stays up with speech off") end
		if shown(a.roll) then fail(scenario, "Try a few lines stays up with speech off") end
		if shown(a.limits) then fail(scenario, "the limits line stays up with speech off") end
		if shown(a.backToInCharacter) then
			fail(scenario, "Go back to In character stays up with speech off")
		end
		if not shown(a.linesOff) then
			fail(scenario, "nothing says how to get the lines back with speech off")
		elseif not optionText(a.linesOff.name):find("Tick Say a line to choose what you say.", 1, true) then
			fail(scenario, "the hint reads: " .. optionText(a.linesOff.name))
		end
		if live(a.channel) then fail(scenario, "Where to say it is live with speech off") end
		if live(a.onlyWhenReturning) then
			fail(scenario, "Only when I buff someone back is live with speech off")
		end
		if a.preset and a.preset.disabled ~= nil then
			fail(scenario, "the Line set dropdown still has a disabled rule of its own")
		end

		speech.enabled = true
		for _, key in ipairs({ "phrasesHeader", "preset", "phrasesHelp", "phrases", "roll", "limits" }) do
			if not shown(a[key]) then fail(scenario, key .. " is hidden with speech on") end
		end
		if shown(a.linesOff) then fail(scenario, "the hint to tick Say a line stays up with speech on") end
		if not (live(a.channel) and live(a.onlyWhenReturning)) then
			fail(scenario, "the speech controls stay greyed with speech on")
		end
		speech.onlyWhenReturning = false
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ channel
do
	local scenario = "click tab: Where to say it lists its choices in order"
	local ns = session(scenario)
	local click = ns and tab(ns)
	local channel = click and click.args.channel
	if channel then
		local sorting = channel.sorting
		if type(sorting) == "function" then sorting = sorting() end
		local want = { "SAY", "WHISPER", "EMOTE", "PARTY", "RAID", "YELL" }
		local got = type(sorting) == "table" and table.concat(sorting, ",") or tostring(sorting)
		if got ~= table.concat(want, ",") then
			fail(scenario, "the Where to say it dropdown is not in its order: " .. got)
		end
		local values = channel.values
		if type(values) == "function" then values = values() end
		local labels = { SAY = "Say", WHISPER = "Whisper them", EMOTE = "Emote", PARTY = "Party",
			RAID = "Raid", YELL = "Yell" }
		for key, label in pairs(labels) do
			if type(values) ~= "table" or values[key] ~= label then
				fail(scenario, ("%s is labelled %s"):format(key, tostring(values and values[key])))
			end
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ set names
do
	local scenario = "click tab: the Line set names say what they are"
	local ns = session(scenario)
	local preset = ns and tab(ns) and tab(ns).args.preset
	if preset then
		local values = preset.values
		if type(values) == "function" then values = values() end
		-- Not "Roleplay": beside In character, a roleplayer could not tell
		-- which of the two they had.
		if values.roleplay ~= "Fantasy (general)" then
			fail(scenario, "the general set is not named Fantasy (general): " .. tostring(values.roleplay))
		end
		if ns.InCharacter and values.incharacter ~= "In character (fits your race and class)" then
			fail(scenario, "the In character set is named " .. tostring(values.incharacter))
		end
		-- One name for one set: the quick choice on Start here reads the same.
		local quick = ns.QuickSetup and ns.QuickSetup.Find(ns.QuickSetup.VOICE, "incharacter")
		if ns.InCharacter and not (quick and quick.name == values.incharacter) then
			fail(scenario, "Start here names the In character set differently: "
				.. tostring(quick and quick.name))
		end
		for _, key in ipairs(ns.PHRASE_SET_ORDER) do
			if key ~= "roleplay" and key ~= "incharacter" and values[key] ~= ns.PHRASE_SETS[key].label then
				fail(scenario, key .. " has no name in the Line set dropdown: " .. tostring(values[key]))
			end
		end
		if not preset.confirm then fail(scenario, "loading a set no longer asks first") end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ in character
do
	local scenario = "click tab: editing In character asks first, and there is a way back"
	local ns = session(scenario)
	local click = ns and tab(ns)
	if click and not ns.InCharacter then
		fail(scenario, "SKIPPED -- no In character set")
	elseif click then
		local a = click.args
		local speech = ns.db.profile.speech
		speech.enabled = true
		a.preset.set({ "preset" }, "incharacter")
		if not ns.InCharacter.Active(speech) then
			fail(scenario, "SKIPPED -- loading In character did not switch it on")
		else
			local question = a.phrases.confirm and a.phrases.confirm({ "phrases" }, "My own line.")
			if type(question) ~= "string" or not question:find("In character", 1, true) then
				fail(scenario, "editing In character's lines does not ask first")
			end
			if shown(a.backToInCharacter) then
				fail(scenario, "Go back to In character is offered while In character is already on")
			end
			if not shown(a.inCharacterNote) then
				fail(scenario, "the In character note is hidden while In character is on")
			end

			a.phrases.set({ "phrases" }, "My own line, {name}.")
			if ns.InCharacter.Active(speech) then
				fail(scenario, "SKIPPED -- edited lines still count as In character")
			else
				if a.phrases.confirm and a.phrases.confirm({ "phrases" }, "Another line.") then
					fail(scenario, "the box asks before editing lines that are already the player's own")
				end
				if not shown(a.backToInCharacter) then
					fail(scenario, "no way back to In character once its lines are edited")
				else
					a.backToInCharacter.func({ "backToInCharacter" })
					if not ns.InCharacter.Active(speech)
						or speech.phrases ~= ns.PhraseSetText("incharacter") then
						fail(scenario, "Go back to In character did not bring it back")
					end
					if shown(a.backToInCharacter) then
						fail(scenario, "Go back to In character stays up once it is back")
					end
				end
			end

			-- Another set, edited: there is no In character to go back to.
			a.preset.set({ "preset" }, "polite")
			a.phrases.set({ "phrases" }, "Thanks, {name}.")
			if shown(a.backToInCharacter) then
				fail(scenario, "Go back to In character is offered over a different set")
			end

			a.preset.set({ "preset" }, "incharacter")
			speech.enabled = false
			if shown(a.inCharacterNote) then
				fail(scenario, "the In character note stays up with speech off")
			end
			-- Edited In character with speech off: the whole Lines section is
			-- gone, the way back with it.
			speech.phrases = "My own line, {name}."
			if shown(a.backToInCharacter) then
				fail(scenario, "Go back to In character stays up with speech off")
			end
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ combat
do
	local scenario = "click tab: the fight notice"
	local ns = session(scenario)
	local notice = ns and tab(ns) and tab(ns).args.combatNotice
	if notice then
		Mock.inCombat = false
		if shown(notice) then fail(scenario, "the combat notice shows out of combat") end
		Mock.inCombat = true
		if not shown(notice) then
			fail(scenario, "the combat notice is hidden in a fight")
		elseif not optionText(notice.name):find("In combat: changes here apply once the fight ends.", 1, true) then
			fail(scenario, "the combat notice reads: " .. optionText(notice.name))
		end
		Mock.inCombat = false
		noErrors(scenario, ns)
	end
end
