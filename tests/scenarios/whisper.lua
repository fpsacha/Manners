-- Whisper as a channel for the spoken line: "/w <their name> <line>" to the
-- person being buffed instead of /say. The name has to be what the chat box
-- will read back as that person -- the whole "Name-Realm" for somebody from
-- another realm, name and surname on Camelot -- never a secret and never
-- anything that could break the macro, and the whisper's longer command counts
-- against the 255-character macro.
--
-- Every scenario name starts with "whisper:" so the mutations in
-- tests/mutations/whisper.py can name the one that has to catch them.

local dir, H = ...
local fail, load, findOption = H.fail, H.load, H.findOption

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function macro(ns)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

-- The macro's spoken line: whatever is not the targeting, the cast or the
-- hand-back.
local function spoken(text)
	for line in tostring(text or ""):gmatch("[^\n]+") do
		if not (line:find("^/target") or line:find("^/cast ")) then return line end
	end
	return nil
end

-- A session with one stranger on a nameplate, owed a favour, speech on and set
-- to whisper. `flavour` is the client (nil for Camelot); `names` is what
-- UnitName gives the nameplate; `setup` runs on the profile before the first
-- repaint.
local function session(scenario, flavour, names, key, setup)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	-- Off Camelot the realm is only reported for somebody from another one.
	Mock.crossRealm = names[2] ~= nil
	local restore = H.strangers({ nameplate1 = names })
	local ns = load(scenario)
	if not ns then
		restore()
		return nil
	end
	H.freshPrompt(ns, scenario)
	local speech = ns.db.profile.speech
	speech.enabled = true
	speech.onlyWhenReturning = false
	speech.channel = "WHISPER"
	speech.phrases = "Thanks, {name}."
	if setup then setup(ns) end
	H.owe(ns, key)
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	return ns, function()
		restore()
		Mock.crossRealm = false
	end
end

local function armedAt(ns, key)
	local text = macro(ns)
	return text ~= nil and text:find("/cast ", 1, true) ~= nil and text:find(key, 1, true) ~= nil, text
end

-- ------------------------------------------------------------------ whisper-1
-- Somebody from another realm off Camelot: filed and whispered as the whole
-- "Brom-Ravencrest", though the /target line carries "Brom" (a realm is not
-- part of what /target searches). The tooltip quotes the words, not the name.
do
	local scenario = "whisper: a cross-realm name is whispered with its realm"
	local key = "Brom-Ravencrest"
	local ns, restore = session(scenario, "mainline", { "Brom", "Ravencrest" }, key)
	if ns then
		local ok, text = armedAt(ns, key)
		if not ok then
			fail(scenario, "SKIPPED -- Brom is not armed: " .. flat(text))
		else
			local want = "/w Brom-Ravencrest Thanks, Brom."
			if spoken(text) ~= want then
				fail(scenario, ("the spoken line is %q, not %q: %s"):format(
					tostring(spoken(text)), want, flat(text)))
			end
			if not text:find("/target Brom\n", 1, true) then
				fail(scenario, "the /target line changed: " .. flat(text))
			end
			local entry = H.inQueue(ns)[key]
			local quoted = entry and table.concat(ns.Prompt:ClickSummary(entry), " / ") or ""
			if not quoted:find("Says: |cffffffffThanks, Brom.|r", 1, true) then
				fail(scenario, "the tooltip does not quote just the words: " .. quoted)
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------------ whisper-2
-- Same realm: the bare name, which is all the game reports and all a whisper
-- needs.
do
	local scenario = "whisper: somebody from your own realm is whispered by name"
	local ns, restore = session(scenario, "mainline", { "Brom" }, "Brom")
	if ns then
		local ok, text = armedAt(ns, "Brom")
		if not ok then
			fail(scenario, "SKIPPED -- Brom is not armed: " .. flat(text))
		elseif spoken(text) ~= "/w Brom Thanks, Brom." then
			fail(scenario, "the spoken line is not a whisper to Brom: " .. flat(text))
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------------ whisper-3
-- Camelot: name and surname, which is what its chat box reads as one person.
-- A name it would read otherwise gets no line at all, never a whisper to
-- somebody else: a single word (it would take the line's first word as the
-- surname) and a surname outside what it counts as a word.
do
	local scenario = "whisper: Camelot whispers name and surname, and nothing it would misread"
	local cases = {
		{ { "Munin", "Hugins" }, "Munin Hugins", "/w Munin Hugins Thanks, Munin Hugins." },
		{ { "Solo" }, "Solo", nil },
		{ { "Petra", "Br\195\162ve" }, "Petra Br\195\162ve", nil },
	}
	for _, case in ipairs(cases) do
		local names, key, want = case[1], case[2], case[3]
		local ns, restore = session(scenario, nil, names, key, function(ns)
			-- A line that starts with a plain word, the shape that would be
			-- taken for a surname.
			ns.db.profile.speech.phrases = "Thanks for the buff, {name}."
		end)
		if not ns then break end
		if want then want = want:gsub("Thanks,", "Thanks for the buff,") end
		local ok, text = armedAt(ns, key)
		if not ok then
			fail(scenario, "SKIPPED -- " .. key .. " is not armed: " .. flat(text))
		elseif spoken(text) ~= want then
			fail(scenario, ("%s: the spoken line is %s, wanted %s: %s"):format(key,
				tostring(spoken(text)), tostring(want), flat(text)))
		end
		guarded(scenario, ns)
		restore()
	end

	-- Roll a few's stand-in is one word in the reader's language, which the
	-- parse above would refuse; it is still shown what a whisper looks like.
	local ns, restore = session(scenario, nil, { "Munin", "Hugins" }, "Munin Hugins")
	if ns then
		local speech = ns.db.profile.speech
		speech.presetChoice, speech.phrases = "polite", "Thanks for the buff, {name}."
		local roll = findOption(ns.optionsTable, "roll")
		Mock.printed = {}
		if roll and roll.func then roll.func() end
		local printed = table.concat(Mock.printed or {}, " / ")
		if not printed:find("/w Somebody Thanks for the buff, Somebody.", 1, true) then
			fail(scenario, "Roll a few shows no whisper on Camelot: " .. printed)
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------------ whisper-4
-- What the client says about regional names is what decides, since it is what
-- its own chat box asks: a client with them on reads "/w Brom Thanks ..." as
-- Brom Thanks, and one with them off reads "/w Munin Hugins ..." as Munin.
-- Each name is also whispered under the other answer, so the answer is what
-- decides, not a whisper that never goes out.
do
	local scenario = "whisper: the client's regional-names answer decides the parse"
	local real = _G.RegionalUniqueNamesEnabled
	local cases = {
		{ "mainline", { "Brom" }, "Brom", true, nil },
		{ "mainline", { "Brom" }, "Brom", false, "/w Brom Thanks for the buff, Brom." },
		{ nil, { "Munin", "Hugins" }, "Munin Hugins", false, nil },
		{ nil, { "Munin", "Hugins" }, "Munin Hugins", true,
			"/w Munin Hugins Thanks for the buff, Munin Hugins." },
	}
	for _, case in ipairs(cases) do
		local flavour, names, key, answer, want = case[1], case[2], case[3], case[4], case[5]
		_G.RegionalUniqueNamesEnabled = function() return answer end
		local ns, restore = session(scenario, flavour, names, key, function(ns)
			ns.db.profile.speech.phrases = "Thanks for the buff, {name}."
		end)
		if not ns then break end
		local ok, text = armedAt(ns, key)
		if not ok then
			fail(scenario, "SKIPPED -- " .. key .. " is not armed: " .. flat(text))
		elseif spoken(text) ~= want then
			fail(scenario, ("%s with regional names %s: the spoken line is %s, wanted %s: %s"):format(
				key, tostring(answer), tostring(spoken(text)), tostring(want), flat(text)))
		end
		guarded(scenario, ns)
		restore()
	end
	_G.RegionalUniqueNamesEnabled = real
end

-- ------------------------------------------------------------------ whisper-5
-- A secret name is no line at all, and so is a realm withheld as a secret: the
-- name is then filed bare, and a whisper to it would reach somebody on your own
-- realm. That holds with no unit too (the tokenless fallback), where a bare name
-- goes out only when the debt's GUID says own realm. A name that could break
-- the macro is no line either. Each refusal has its control beside it: the same
-- setup with the name plain does whisper.
do
	local scenario = "whisper: a secret or unsafe name says nothing"
	local ns, restore = session(scenario, "mainline", { "Brom", "Ravencrest" }, "Brom-Ravencrest")
	if ns then
		local ok, text = armedAt(ns, "/target Brom")
		if not ok then
			fail(scenario, "SKIPPED -- Brom-Ravencrest is not armed: " .. flat(text))
		elseif spoken(text) ~= "/w Brom-Ravencrest Thanks, Brom." then
			fail(scenario, "control: the plain realm is not whispered: " .. flat(text))
		end
		guarded(scenario, ns)
		restore()
	end

	ns, restore = session(scenario, "mainline", { "Brom", Mock.SECRET }, "Brom")
	if ns then
		local ok, text = armedAt(ns, "Brom")
		if not ok then
			fail(scenario, "SKIPPED -- Brom is not armed: " .. flat(text))
		elseif spoken(text) ~= nil then
			fail(scenario, "a whisper went to a name whose realm was secret: " .. flat(text))
		end

		local buff = ns.ResolveBuff(true)
		local control = { name = "Brom-Ravencrest", short = "Brom", targetName = "Brom", reason = "owed", buff = buff }
		local line = ns.PickPhrase(control, 200)
		if line ~= "/w Brom-Ravencrest Thanks, Brom." then
			fail(scenario, "control: a safe name gets no whisper: " .. tostring(line))
		end
		-- Shaped like the control, realm and all, so the tokenless GUID check
		-- (which a bare name would meet first) cannot be what stops them.
		local names = { Mock.SECRET, "Bad;Name-Ravencrest", "Bad]Name-Ravencrest", "Bad|Name-Ravencrest",
			"Bad\nName-Ravencrest", "Bad\1Name-Ravencrest", "" }
		for _, name in ipairs(names) do
			local entry = { name = name, short = "Brom", targetName = "Brom", reason = "owed", buff = buff }
			local called, line = pcall(ns.PickPhrase, entry, 200)
			if not called then
				fail(scenario, ("%q threw: %s"):format(tostring(name), tostring(line)))
			elseif line ~= nil then
				fail(scenario, ("%q got a line: %s"):format(tostring(name), flat(line)))
			end
		end
		guarded(scenario, ns)
		restore()
	end

	-- No nameplate: Brom is offered from the tokenless fallback, filed bare.
	-- What the client says of the debt's GUID decides: own realm is the control,
	-- a secret realm, a GUID that now names somebody else, or no GUID at all (a
	-- debt back from disk) is no line.
	Mock.reset()
	Mock.setFlavour("mainline")
	restore = H.strangers({})
	ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning = true, false
		speech.channel, speech.phrases = "WHISPER", "Thanks, {name}."
		local guid = "Player-1-BROM"
		local cases = {
			{ "Brom", "", guid, "/w Brom Thanks, Brom." },
			{ "Brom", Mock.SECRET, guid, nil },
			{ "Bram", "", guid, nil },
			{ "Brom", "", nil, nil },
		}
		for _, case in ipairs(cases) do
			local now, realm, owner, want = case[1], case[2], case[3], case[4]
			Mock.guids = { [guid] = { class = "PRIEST", name = now, realm = realm } }
			wipe(ns.owed)
			H.owe(ns, "Brom")
			ns.owed.Brom.guid = owner
			ns.pendingClick = nil
			ns.Prompt:InvalidateMacro()
			ns.addon:Tick()
			local ok, text = armedAt(ns, "Brom")
			local entry = H.inQueue(ns).Brom
			local label = ("tokenless, GUID %s names %s, realm %s"):format(
				tostring(owner), now, realm == "" and "own" or "secret")
			if not ok then
				fail(scenario, "SKIPPED -- " .. label .. ": Brom is not armed: " .. flat(text))
			elseif entry and entry.unit ~= nil then
				fail(scenario, "SKIPPED -- " .. label .. ": Brom has a unit: " .. tostring(entry.unit))
			elseif spoken(text) ~= want then
				fail(scenario, ("%s: the spoken line is %s, wanted %s: %s"):format(
					label, tostring(spoken(text)), tostring(want), flat(text)))
			end
		end
		Mock.guids = nil
		guarded(scenario, ns)
	end
	restore()
end

-- ------------------------------------------------------------------ whisper-6
-- The budget counts the whisper's name. With a long name and realm, a line cut
-- to fit the room exactly goes in and fills the macro to 255; one character
-- more is dropped, not cut, and the same line still fits a /say, whose command
-- is shorter. In character measures with the same command.
do
	local scenario = "whisper: the budget counts a long name and realm"
	local key = "Aurelianthos-Twistingnether"
	local ns, restore = session(scenario, "mainline", { "Aurelianthos", "Twistingnether" }, key)
	if ns then
		local entry = H.inQueue(ns)[key]
		local budget = entry and ns.PhraseBudget(entry)
		if not budget then
			fail(scenario, "SKIPPED -- Aurelianthos is not in the queue")
		else
			local speech = ns.db.profile.speech
			local room = budget - #("/w " .. key .. " ")
			local function arm(words, channel)
				speech.channel = channel or "WHISPER"
				speech.phrases = words
				ns.Prompt:InvalidateMacro()
				ns.addon:Tick()
				return macro(ns)
			end

			local exact = string.rep("a", room)
			local text = arm(exact)
			if spoken(text) ~= "/w " .. key .. " " .. exact then
				fail(scenario, "a whisper cut to fit exactly was left out: " .. flat(text))
			elseif #text ~= ns.MACRO_LIMIT then
				fail(scenario, ("the macro is %d characters, not %d"):format(#text, ns.MACRO_LIMIT))
			end

			local over = exact .. "a"
			text = arm(over)
			if #tostring(text) > ns.MACRO_LIMIT then
				fail(scenario, ("a whisper overran the macro: %d characters"):format(#text))
			elseif spoken(text) ~= nil then
				fail(scenario, "a whisper one character too long went in: " .. flat(text))
			elseif not text:find("/cast ", 1, true) then
				fail(scenario, "the cast went with the line: " .. flat(text))
			end

			text = arm(over, "SAY")
			if spoken(text) ~= "/say " .. over then
				fail(scenario, "the same line no longer fits a /say: " .. flat(text))
			end

			-- In character, loaded through the dropdown as a player would.
			local preset = findOption(ns.optionsTable, "preset")
			if preset and preset.set then
				speech.channel = "WHISPER"
				preset.set({ "preset" }, "incharacter")
				for _ = 1, 20 do
					ns.Prompt:InvalidateMacro()
					ns.addon:Tick()
					text = macro(ns)
					local line = spoken(text)
					if #tostring(text) > ns.MACRO_LIMIT then
						fail(scenario, ("In character overran the macro: %d characters"):format(#text))
						break
					elseif line and line:sub(1, #key + 4) ~= "/w " .. key .. " " then
						fail(scenario, "In character's whisper does not name them: " .. flat(line))
						break
					end
				end
			end
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------------ whisper-7
-- The rules every channel keeps: only when returning a favour, and no line for
-- somebody known to be out of reach.
do
	local scenario = "whisper: returning a favour and range still decide"
	local ns, restore = session(scenario, "mainline", { "Brom" }, "Brom", function(ns)
		ns.db.profile.speech.onlyWhenReturning = true
		ns.db.profile.filters.requireInRange = false
	end)
	if ns then
		local buff = ns.ResolveBuff(true)
		-- On the nameplate, as the queue has them: a bare name with no unit is
		-- the tokenless case whisper-5 covers.
		local stranger = { name = "Brom", short = "Brom", targetName = "Brom", unit = "nameplate1",
			reason = "nearby", buff = buff }
		if ns.PickPhrase(stranger, 200) ~= nil then
			fail(scenario, "a whisper went to somebody who never buffed you")
		end
		stranger.reason = "owed"
		if ns.PickPhrase(stranger, 200) ~= "/w Brom Thanks, Brom." then
			fail(scenario, "no whisper for a favour returned")
		end

		Mock.inRange = false
		ns.addon:Tick()
		local ok, text = armedAt(ns, "Brom")
		if not ok then
			fail(scenario, "SKIPPED -- Brom is not armed out of range: " .. flat(text))
		elseif spoken(text) ~= nil then
			fail(scenario, "a whisper went to somebody out of reach: " .. flat(text))
		end
		Mock.inRange = true
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------------ whisper-8
-- The other channels are exactly as they were, the default is still /say, the
-- setting survives a reload and nonsense still becomes Say. The dropdown lists
-- the whisper and says who hears it; Roll a few prints one.
do
	local scenario = "whisper: other channels unchanged"
	local ns, restore = session(scenario, "mainline", { "Brom", "Ravencrest" }, "Brom-Ravencrest")
	if ns then
		local buff = ns.ResolveBuff(true)
		local entry = { name = "Brom-Ravencrest", short = "Brom", targetName = "Brom",
			reason = "owed", buff = buff }
		local speech = ns.db.profile.speech
		for channel, command in pairs({ SAY = "say", YELL = "yell", PARTY = "party",
			RAID = "raid", EMOTE = "emote" }) do
			speech.channel = channel
			local line = ns.PickPhrase(entry, 200)
			if line ~= "/" .. command .. " Thanks, Brom." then
				fail(scenario, ("%s says %s"):format(channel, tostring(line)))
			end
		end

		if ns.defaults and ns.defaults.profile and ns.defaults.profile.speech
			and ns.defaults.profile.speech.channel ~= "SAY" then
			fail(scenario, "the default channel is no longer Say")
		end
		speech.channel = "WHISPER"
		ns.ClampSettings()
		if speech.channel ~= "WHISPER" then
			fail(scenario, "the load-time repair threw the whisper away: " .. tostring(speech.channel))
		end
		speech.channel = "SHOUT"
		ns.ClampSettings()
		if speech.channel ~= "SAY" then
			fail(scenario, "a channel that does not exist became " .. tostring(speech.channel))
		end

		local channel = findOption(ns.optionsTable, "channel")
		local values = channel and channel.values
		if type(values) == "function" then values = values() end
		if not (type(values) == "table" and values.WHISPER == "Whisper them") then
			fail(scenario, "the Channel dropdown has no Whisper them")
		end
		local desc = channel and H.optionText(channel.desc) or ""
		if not desc:find("Whisper them sends it to the person you buff and nobody else", 1, true) then
			fail(scenario, "the Channel dropdown does not say who hears a whisper: " .. desc)
		end

		speech.channel = "WHISPER"
		speech.presetChoice, speech.phrases = "polite", "Thanks, {name}."
		local roll = findOption(ns.optionsTable, "roll")
		Mock.printed = {}
		if roll and roll.func then roll.func() end
		local printed = table.concat(Mock.printed or {}, " / ")
		if not printed:find("/w ", 1, true) then
			fail(scenario, "Roll a few shows no whisper: " .. printed)
		end
		guarded(scenario, ns)
		restore()
	end
end
