-- Three additions to What I say, asked for on CurseForge by a player on a
-- roleplay realm (1.11.25):
--
-- * First name only (speech.firstNameOnly, off; Speech.lua, ns.SaidName):
--   {name} in a spoken line is the first word of the name, "Munin Hugins"
--   said as "Munin", in the fixed sets, the lines mixed in, the In character
--   pick, the whispered thank-you and Try a few. Never the name a whisper goes
--   to, the /target line, the prompt or a debt's key; a one-word name is said
--   whole, and the whisper guard after the roll still passes or refuses as it
--   did.
-- * How often my own lines are said (speech.mixedShare, "third"; Speech.lua,
--   OwnTurn): one press in three as before, half, two in three or every press.
-- * Lines left out (speech.leftOut; Phrases.lua, RP.Pick): In character lines
--   as written that the pick never chooses, with Never say my last line again
--   and a box of them on What I say; repaired at load, never in a pasted string.
--
-- Every scenario name starts with "names-own-lines:" so the mutations in
-- tests/mutations/names-own-lines.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive, findOption = H.fail, H.load, H.drive, H.findOption

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

local function macro(ns)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

-- The macro's spoken line: whatever is not the targeting, the cast or the
-- hand-back.
local function spoken(text)
	for line in tostring(text or ""):gmatch("[^\n]+") do
		if not (line:find("^/target") or line:find("^/cast ")) then return line end
	end
	return nil
end

-- math.random answering from a list in turn (the last one for ever after), or
-- from a function of the range asked, given one.
local function withRolls(rolls, fn)
	local real, at = math.random, 0
	math.random = function(n)
		at = at + 1
		if type(rolls) == "function" then return rolls(n) or real() end
		local v = rolls[at] or rolls[#rolls]
		if n then return math.max(1, math.min(n, v)) end
		return real()
	end
	local ok, err = pcall(fn)
	math.random = real
	if not ok then error(err, 0) end
end

-- A stranger on a nameplate, owed a favour, speech on and whispered, as
-- whisper.lua's sessions are. `flavour` nil is Camelot.
local function whisperSession(scenario, flavour, names, key, setup)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	Mock.crossRealm = false
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
	speech.phrases = "Thanks for the buff, {name}."
	if setup then setup(ns) end
	H.owe(ns, key)
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	return ns, restore
end

local function armedAt(ns, key)
	local text = macro(ns)
	return text ~= nil and text:find("/cast ", 1, true) ~= nil and text:find(key, 1, true) ~= nil, text
end

-- A session with speech on in /say and In character loaded through the dropdown.
local function ready(scenario)
	Mock.reset()
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local speech = ns.db.profile.speech
	speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
	local preset = findOption(ns.optionsTable, "preset")
	if not (preset and preset.set) then
		fail(scenario, "SKIPPED -- the Load a set dropdown is not on the page")
		return nil
	end
	preset.set({ "preset" }, "incharacter")
	if not ns.InCharacter.Active(speech) then
		fail(scenario, "SKIPPED -- In character is not the set")
		return nil
	end
	return ns
end

local function person(ns, name)
	name = name or "Munin Hugins"
	return { name = name, short = name, reason = "nearby",
		buff = ns.ResolveBuff(true) or ns.FindBuff("MAGE", "intellect") }
end

-- Where a control sits on What I say: its section's key and its item.
local function placed(ns, path)
	for _, section in ipairs(ns.WindowLayout.pages.click.sections) do
		for index, item in ipairs(section.items) do
			if (type(item) == "table" and item[1] or item) == path then return section.key, item, index end
		end
	end
	return nil
end

-- Every line of text the In character set holds, its pools and all.
local function everyLine(ns)
	local out, seen = {}, {}
	local function walk(t)
		if seen[t] then return end
		seen[t] = true
		for _, v in pairs(t) do
			if type(v) == "string" then
				out[#out + 1] = v
			elseif type(v) == "table" then
				walk(v)
			end
		end
	end
	walk(ns.InCharacter)
	return out
end

-- ------------------------------------------------------------- names-own-lines 1
-- On Camelot "Munin Hugins" is said as "Munin", and the whisper still goes to
-- the whole name, as do the /target line, the prompt and the debt. A line that
-- opens on the first name still passes the whisper guard after the roll: the
-- chat box walks "/w Munin Hugins Munin, take this." back to Munin Hugins.
do
	local scenario = "names-own-lines: first name only says the first word, the whisper keeps the whole name"
	local key = "Munin Hugins"
	for _, case in ipairs({
		{ "Thanks for the buff, {name}.", "/w Munin Hugins Thanks for the buff, Munin." },
		{ "{name}, take this.", "/w Munin Hugins Munin, take this." },
	}) do
		local ns, restore = whisperSession(scenario, nil, { "Munin", "Hugins" }, key, function(ns)
			ns.db.profile.speech.firstNameOnly = true
			ns.db.profile.speech.phrases = case[1]
		end)
		if not ns then break end
		local ok, text = armedAt(ns, key)
		if not ok then
			fail(scenario, "SKIPPED -- Munin Hugins is not armed: " .. flat(text))
		else
			if spoken(text) ~= case[2] then
				fail(scenario, ("the line was said as %s, wanted %s: %s"):format(
					tostring(spoken(text)), case[2], flat(text)))
			end
			if not text:find("/target Munin Hugins\n", 1, true) then
				fail(scenario, "the /target line changed: " .. flat(text))
			end
			local current = ns.Prompt.state and ns.Prompt.state.current
			if not (current and current.name == key and current.short == key) then
				fail(scenario, "the prompt does not show the whole name: " .. tostring(current and current.short))
			end
			if not (ns.owed and ns.owed[key]) then fail(scenario, "the debt is not filed under the whole name") end
		end
		guarded(scenario, ns)
		restore()
	end
	-- Off, the whole name as before.
	local ns, restore = whisperSession(scenario, nil, { "Munin", "Hugins" }, key)
	if ns then
		local _, text = armedAt(ns, key)
		if spoken(text) ~= "/w Munin Hugins Thanks for the buff, Munin Hugins." then
			fail(scenario, "with the switch off the line was " .. tostring(spoken(text)))
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------- names-own-lines 2
-- A one-word name is said whole, and the guard after the roll refuses what
-- the chat box would misread as before: on Camelot "/w Solo Thanks for the
-- buff, Solo." goes to "Solo Thanks", so no line. Off Camelot the line goes.
do
	local scenario = "names-own-lines: a one-word name is said whole, and the whisper guard still refuses a misread"
	local ns, restore = whisperSession(scenario, nil, { "Solo" }, "Solo", function(ns)
		ns.db.profile.speech.firstNameOnly = true
	end)
	if ns then
		local ok, text = armedAt(ns, "Solo")
		if not ok then
			fail(scenario, "SKIPPED -- Solo is not armed: " .. flat(text))
		elseif spoken(text) ~= nil then
			fail(scenario, "a whisper the chat box would misread went out: " .. flat(text))
		end
		guarded(scenario, ns)
		restore()
	end
	ns, restore = whisperSession(scenario, "mainline", { "Brom" }, "Brom", function(ns)
		ns.db.profile.speech.firstNameOnly = true
	end)
	if ns then
		local ok, text = armedAt(ns, "Brom")
		if not ok then
			fail(scenario, "SKIPPED -- Brom is not armed: " .. flat(text))
		elseif spoken(text) ~= "/w Brom Thanks for the buff, Brom." then
			fail(scenario, "a one-word name was said as " .. tostring(spoken(text)))
		end
		guarded(scenario, ns)
		restore()
	end
end

-- ------------------------------------------------------------- names-own-lines 3
-- The In character pick, the lines mixed in and the whispered thank-you say
-- the first name too; the thank-you still goes to the whole name.
do
	local scenario = "names-own-lines: first name only reaches In character, the lines mixed in and the whispered thank-you"
	local ns = ready(scenario)
	if ns then
		local speech = ns.db.profile.speech
		speech.firstNameOnly = true
		local entry = person(ns)
		local named, whole = 0, nil
		for _ = 1, 40 do
			local line = ns.PickPhrase(entry, 250) or ""
			if line:find("Hugins", 1, true) then whole = line end
			if line:find("Munin", 1, true) then named = named + 1 end
		end
		if whole then fail(scenario, "In character said the whole name: " .. whole) end
		if named == 0 then fail(scenario, "SKIPPED -- no In character line of forty named them") end
		speech.mixedLines = "Well met, {name}!"
		withRolls({ 1, 1 }, function()
			local line = ns.PickPhrase(entry, 250)
			if line ~= "/say Well met, Munin!" then fail(scenario, "a line mixed in was said as " .. tostring(line)) end
		end)
		speech.firstNameOnly = false
		withRolls({ 1, 1 }, function()
			local line = ns.PickPhrase(entry, 250)
			if line ~= "/say Well met, Munin Hugins!" then
				fail(scenario, "with the switch off a line mixed in was said as " .. tostring(line))
			end
		end)
		speech.firstNameOnly = true
		-- The fixed sets.
		speech.presetChoice, speech.phrases = "polite", "Cheers, {name}."
		local line = ns.PickPhrase(entry, 250)
		if line ~= "/say Cheers, Munin." then fail(scenario, "a fixed set's line was said as " .. tostring(line)) end
		-- The whispered thank-you, caught: the mock client has no chat call.
		local sent, real = {}, rawget(_G, "SendChatMessage")
		rawset(_G, "SendChatMessage", function(text, kind, _, to)
			sent[#sent + 1] = { text = text, kind = kind, to = to }
		end)
		local whispered = ns.ThankWhisper({ name = "Munin Hugins", inGroup = false }, nil)
		rawset(_G, "SendChatMessage", real)
		if whispered ~= true or #sent ~= 1 then
			fail(scenario, "SKIPPED -- the whispered thank-you did not go")
		else
			if sent[1].to ~= "Munin Hugins" then fail(scenario, "the thank-you was whispered to " .. tostring(sent[1].to)) end
			if tostring(sent[1].text):find("Hugins", 1, true) then
				fail(scenario, "the whispered thank-you said the whole name: " .. tostring(sent[1].text))
			end
		end
		guarded(scenario, ns)
	end
end

-- ------------------------------------------------------------- names-own-lines 4
-- The switch: on What I say, off by default, live while either the line or the
-- whispered thank-you is on, placed on the page; /manners debug and the
-- check-up say it.
do
	local scenario = "names-own-lines: First name only is a switch on What I say, off by default"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		if speech.firstNameOnly ~= false then fail(scenario, "a new profile has it " .. tostring(speech.firstNameOnly)) end
		local option = findOption(ns.optionsTable, "firstNameOnly")
		if not option then
			fail(scenario, "What I say has no First name only")
		else
			speech.enabled = false
			ns.db.profile.prompt.thankWhisper = false
			if not option.disabled() then fail(scenario, "live with nothing said at all") end
			ns.db.profile.prompt.thankWhisper = true
			if option.disabled() then fail(scenario, "greyed with the whispered thank-you on") end
			speech.enabled = true
			ns.db.profile.prompt.thankWhisper = false
			if option.disabled() then fail(scenario, "greyed with Say a line on") end
			option.set({ "firstNameOnly" }, true)
			if speech.firstNameOnly ~= true or option.get({ "firstNameOnly" }) ~= true then
				fail(scenario, "ticking it wrote " .. tostring(speech.firstNameOnly))
			end
		end
		if not placed(ns, "click.firstNameOnly") then fail(scenario, "click.firstNameOnly is not placed on What I say") end
		speech.firstNameOnly = true
		speech.mixedShare, speech.leftOut = "half", { "One line.", "Another line." }
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not table.concat(Mock.printed, "\n"):find("first name only", 1, true) then
			fail(scenario, "/manners debug does not say First name only is on")
		end
		local ok, results = pcall(ns.Selftest.Run)
		local said
		for _, r in ipairs(ok and results or {}) do
			if r.id == "speech.voice" then said = tostring(r.value) end
		end
		if not (said and said:find("first name only on", 1, true)) then
			fail(scenario, "the check-up does not say it: " .. tostring(said))
		end
		-- The check-up lists How often my own lines are said and the lines left
		-- out beside it.
		if not (said and said:find("own lines half", 1, true)) then
			fail(scenario, "the check-up does not say how often my own lines are said: " .. tostring(said))
		end
		if not (said and said:find("2 left out", 1, true)) then
			fail(scenario, "the check-up does not count the lines left out: " .. tostring(said))
		end
		guarded(scenario, ns)
	end
end

-- ------------------------------------------------------------- names-own-lines 5
-- How often my own lines are said: one press in three by default, as before,
-- half, two in three, or every press, when In character speaks only if none of
-- them fits. An unknown value is one in three, and the load repairs it.
do
	local scenario = "names-own-lines: how often my own lines are said"
	local ns = ready(scenario)
	if ns then
		local speech = ns.db.profile.speech
		if speech.mixedShare ~= "third" then fail(scenario, "a new profile has " .. tostring(speech.mixedShare)) end
		speech.mixedLines = "Well met, {name}!"
		local entry = person(ns, "Bram")
		local own = "/say Well met, Bram!"
		local cases = {
			{ "third", { 1, 1 }, true }, { "third", { 2 }, false }, { "third", { 3 }, false },
			{ "half", { 1, 1 }, true }, { "half", { 2 }, false },
			-- One in two, not one in three: a roll of two comes up one, any other its top.
			{ "half", function(n) if n == 2 then return 1 end return n end, true },
			{ "twothirds", { 2, 1 }, true }, { "twothirds", { 3, 1 }, true }, { "twothirds", { 1 }, false },
			{ "always", { 3 }, true }, { "always", { 2 }, true },
			{ "sometimes", { 1, 1 }, true }, { "sometimes", { 2 }, false },
		}
		for _, case in ipairs(cases) do
			speech.mixedShare = case[1]
			withRolls(case[2], function()
				local line = ns.PickPhrase(entry, 250)
				if (line == own) ~= case[3] then
					fail(scenario, ("%s with rolls %s: the line was %s"):format(case[1],
						type(case[2]) == "table" and table.concat(case[2], ",") or "by range", tostring(line)))
				end
			end)
		end
		-- Every press, and none of the player's lines fits: In character speaks.
		speech.mixedShare = "always"
		speech.mixedLines = ("x"):rep(300)
		withRolls({ 1 }, function()
			local line = ns.PickPhrase(entry, 250)
			if not line or line:find("xxxx", 1, true) then
				fail(scenario, "every press, with no own line that fits, said " .. tostring(line))
			end
		end)
		speech.mixedShare = "sometimes"
		ns.ClampSettings()
		if speech.mixedShare ~= "third" then fail(scenario, "an unknown value was left as " .. tostring(speech.mixedShare)) end
		guarded(scenario, ns)
	end
end

-- ------------------------------------------------------------- names-own-lines 6
-- The choice sits under the box of own lines, shown with it, and the box's note
-- no longer promises one press in three.
do
	local scenario = "names-own-lines: the share is chosen under the box, and the box's note stays true"
	local ns = ready(scenario)
	if ns then
		local speech = ns.db.profile.speech
		local option = findOption(ns.optionsTable, "mixedShare")
		if not option then
			fail(scenario, "What I say has no How often my own lines are said")
		else
			local n = 0
			for _ in pairs(option.values) do n = n + 1 end
			if n ~= 4 or not option.values.always or not option.values.third then
				fail(scenario, "the choice has " .. n .. " values")
			end
			if option.hidden() then fail(scenario, "hidden with In character as the set") end
			option.set({ "mixedShare" }, "half")
			if speech.mixedShare ~= "half" then fail(scenario, "choosing wrote " .. tostring(speech.mixedShare)) end
			speech.presetChoice, speech.phrases = "polite", "Cheers, {name}."
			if not option.hidden() then fail(scenario, "shown with another set loaded") end
		end
		local box = findOption(ns.optionsTable, "mixedLines")
		if box and tostring(box.desc):find("one press in three", 1, true) then
			fail(scenario, "the box still says one press in three: " .. tostring(box.desc))
		end
		local section, item = placed(ns, "click.mixedShare")
		local boxSection, _, boxAt = placed(ns, "click.mixedLines")
		local _, _, at = placed(ns, "click.mixedShare")
		if not section then
			fail(scenario, "click.mixedShare is not placed on What I say")
		elseif section ~= boxSection or at ~= boxAt + 1 or not (type(item) == "table" and item.indent) then
			fail(scenario, "click.mixedShare is not indented under the box")
		end
		guarded(scenario, ns)
	end
end

-- ------------------------------------------------------------- names-own-lines 7
-- A line left out is never said, and a line added to the list later is left
-- out too.
do
	local scenario = "names-own-lines: a left-out line is never said"
	local ns = ready(scenario)
	if ns then
		local speech = ns.db.profile.speech
		local entry = person(ns, "Bram")
		local _, first = ns.PickPhrase(entry, 250)
		if type(first) ~= "string" then
			fail(scenario, "SKIPPED -- In character picked nothing")
		else
			speech.leftOut = { first }
			local second
			for _ = 1, 80 do
				local _, source = ns.PickPhrase(entry, 250)
				if source == first then
					fail(scenario, "a left-out line was said: " .. first)
					break
				end
				second = second or source
			end
			if second then
				table.insert(speech.leftOut, second)
				for _ = 1, 80 do
					local _, source = ns.PickPhrase(entry, 250)
					if source == second then
						fail(scenario, "a line added to the list later was said: " .. second)
						break
					end
				end
			end
		end
		guarded(scenario, ns)
	end
end

-- ------------------------------------------------------------- names-own-lines 8
-- Every line left out: nothing is said and nothing breaks, the lines mixed in
-- still go, Try a few prints its nothing, the thank-you is not whispered.
do
	local scenario = "names-own-lines: with every line left out nothing is said, and nothing breaks"
	local ns = ready(scenario)
	if ns then
		local speech = ns.db.profile.speech
		speech.leftOut = everyLine(ns)
		local entry = person(ns, "Bram")
		local line = ns.PickPhrase(entry, 250)
		if line ~= nil then fail(scenario, "with every line left out the line was " .. tostring(line)) end
		speech.mixedLines, speech.mixedShare = "Own line, {name}.", "always"
		line = ns.PickPhrase(entry, 250)
		if line ~= "/say Own line, Bram." then fail(scenario, "the line mixed in did not go: " .. tostring(line)) end
		speech.mixedLines = ""
		local roll = findOption(ns.optionsTable, "roll")
		Mock.printed = {}
		if roll and roll.func then roll.func() end
		local printed = table.concat(Mock.printed or {}, " / ")
		if printed:find("/say ", 1, true) or not printed:find("(nothing", 1, true) then
			fail(scenario, "Try a few said a left-out line: " .. printed)
		end
		local sent, real = {}, rawget(_G, "SendChatMessage")
		rawset(_G, "SendChatMessage", function(text) sent[#sent + 1] = text end)
		local whispered = ns.ThankWhisper({ name = "Bram", inGroup = false }, nil)
		rawset(_G, "SendChatMessage", real)
		if whispered ~= false or #sent ~= 0 then fail(scenario, "a left-out line was whispered: " .. tostring(sent[1])) end
		guarded(scenario, ns)
	end
end

-- ------------------------------------------------------------- names-own-lines 9
-- Never say my last line again, and the box of lines left out.
do
	local scenario = "names-own-lines: Never say my last line again leaves out the last line said"
	local ns = ready(scenario)
	if ns then
		local speech = ns.db.profile.speech
		local button = findOption(ns.optionsTable, "leaveOutLast")
		local box = findOption(ns.optionsTable, "leftOut")
		if not (button and box) then
			fail(scenario, "What I say has no button or no box for lines left out")
		else
			if not button.disabled() then fail(scenario, "live with no line said yet") end
			if not tostring(button.desc()):find("No In character line", 1, true) then
				fail(scenario, "with nothing said its note reads " .. tostring(button.desc()))
			end
			local _, source = ns.PickPhrase(person(ns, "Bram"), 250)
			ns.InCharacter.Remember(source)
			if button.disabled() then fail(scenario, "greyed with a line said") end
			if not tostring(button.desc()):find(source, 1, true) then
				fail(scenario, "its note does not show the line: " .. tostring(button.desc()))
			end
			button.func()
			if speech.leftOut[1] ~= source or #speech.leftOut ~= 1 then
				fail(scenario, "the press left out " .. tostring(speech.leftOut[1]))
			end
			if not button.disabled() then fail(scenario, "live with the line already left out") end
			button.func()
			if #speech.leftOut ~= 1 then fail(scenario, "a second press wrote the line twice") end
			if box.hidden() then fail(scenario, "the box is hidden with In character as the set") end
			if box.get() ~= source then fail(scenario, "the box shows " .. tostring(box.get())) end
			-- Rows trimmed, empty ones and doubles dropped.
			box.set(nil, "A line.\n\n  Another line.  \nA line.")
			if #speech.leftOut ~= 2 or speech.leftOut[2] ~= "Another line." then
				fail(scenario, "the box wrote " .. table.concat(speech.leftOut, " | "))
			end
			-- A row matching no line leaves the set speaking.
			if not ns.PickPhrase(person(ns, "Bram"), 250) then fail(scenario, "a row matching nothing silenced the set") end
			-- Deleting a row brings the line back.
			box.set(nil, "")
			if #speech.leftOut ~= 0 then fail(scenario, "emptying the box left " .. #speech.leftOut) end
			local rows = {}
			for i = 1, 250 do rows[i] = "Line " .. i end
			box.set(nil, table.concat(rows, "\n"))
			if #speech.leftOut ~= ns.LEFT_OUT_MAX then fail(scenario, "the box kept " .. #speech.leftOut .. " lines") end
			speech.leftOut = {}
			-- A press that said one of the player's own lines: the last line said
			-- is theirs, so the button names no older In character line.
			ns.InCharacter.Remember(source)
			ns.InCharacter.SaidOwn()
			if not button.disabled() then fail(scenario, "live after one of my own lines was said") end
			if ns.InCharacter.Last() ~= nil then
				fail(scenario, "after my own line the last line is still " .. tostring(ns.InCharacter.Last()))
			end
			if tostring(button.desc()):find(source, 1, true) or not tostring(button.desc()):find("one of your own", 1, true) then
				fail(scenario, "after my own line its note reads " .. tostring(button.desc()))
			end
			button.func()
			if #speech.leftOut ~= 0 then fail(scenario, "after my own line the press left out " .. tostring(speech.leftOut[1])) end
			ns.InCharacter.Remember(source)
			if ns.InCharacter.Last() ~= source then fail(scenario, "the next In character line was not remembered") end
			-- Another set loaded: In character says nothing, so nothing to leave out.
			speech.presetChoice, speech.phrases = "polite", "Cheers, {name}."
			if not button.disabled() then fail(scenario, "live with another set loaded") end
		end
		if not (placed(ns, "click.leaveOutLast") and placed(ns, "click.leftOut")) then
			fail(scenario, "the button or the box is not placed on What I say")
		end
		guarded(scenario, ns)
	end
end

-- ------------------------------------------------------------ names-own-lines 10
-- The list is repaired at load, and a pasted settings string does not carry
-- it; First name only and the share travel.
do
	local scenario = "names-own-lines: the list is repaired at load and does not travel in a pasted string"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		if type(speech.leftOut) ~= "table" or #speech.leftOut ~= 0 then fail(scenario, "a new profile's list is not empty") end
		speech.leftOut = "junk"
		ns.ClampSettings()
		if type(speech.leftOut) ~= "table" then fail(scenario, "a damaged list was left as " .. tostring(speech.leftOut)) end
		local long = { 7, "Two\nlines", "  Padded.  ", "Padded." }
		for i = 1, 250 do long[#long + 1] = "Line " .. i end
		speech.leftOut = long
		ns.ClampSettings()
		local list = speech.leftOut
		if list[1] ~= "Two lines" or list[2] ~= "Padded." or list[3] ~= "Line 1" then
			fail(scenario, "the list was repaired as " .. tostring(list[1]) .. " | " .. tostring(list[2]) .. " | " .. tostring(list[3]))
		end
		if #list ~= ns.LEFT_OUT_MAX then fail(scenario, "the list kept " .. #list .. " lines") end
		speech.enabled = true
		speech.leftOut = { "Some line of mine." }
		speech.firstNameOnly, speech.mixedShare = true, "half"
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not table.concat(Mock.printed, "\n"):find("lines left out", 1, true) then
			fail(scenario, "/manners debug does not say lines are left out")
		end
		local text = ns.ExportSettings()
		if tostring(text):find("leftOut", 1, true) then fail(scenario, "the string carries the lines left out") end
		speech.firstNameOnly, speech.mixedShare = false, "third"
		speech.leftOut = { "Mine." }
		local ok, said = ns.ImportSettings(text)
		speech = ns.db.profile.speech
		if not ok then
			fail(scenario, "SKIPPED -- the string did not import: " .. tostring(said))
		else
			if speech.firstNameOnly ~= true then fail(scenario, "First name only did not travel") end
			if speech.mixedShare ~= "half" then fail(scenario, "the share did not travel: " .. tostring(speech.mixedShare)) end
			if speech.leftOut[1] ~= "Mine." then fail(scenario, "the paste changed the lines left out") end
		end
		-- A row of the list a string carries (written by hand: no export holds
		-- one) is dropped without a word, not called a newer version's setting,
		-- and changes nothing.
		local body = tostring(text):match("^(.*):%x+$")
		if not body then
			fail(scenario, "SKIPPED -- the export has no checksum: " .. tostring(text))
		else
			local signed = body .. ";speech.leftOut.1=Mine."
			local h = 0
			for i = 1, #signed do h = (h * 31 + signed:byte(i)) % 16777213 end
			local parsed, why = ns.ParseSettings(signed .. (":%06x"):format(h))
			if not parsed then
				fail(scenario, "SKIPPED -- a string with a row of the list did not parse: " .. tostring(why))
			elseif parsed.unknown ~= 0 then
				fail(scenario, "a row of the lines left out was called a newer version's setting: " .. parsed.unknown)
			elseif parsed.values["speech.leftOut.1"] ~= nil or parsed.values["speech.leftOut"] ~= nil then
				fail(scenario, "a row of the lines left out was read as a setting")
			end
		end
		guarded(scenario, ns)
	end
end

-- ------------------------------------------------------------ names-own-lines 11
-- A press that says one of the player's own lines makes it the last line said:
-- Never say my last line again no longer names the In character line said
-- before it, and leaves nothing out.
do
	local scenario = "names-own-lines: after my own line the button names no older In character line"
	Mock.reset()
	Mock.crossRealm = false
	local restore = H.strangers({ nameplate1 = { "Munin", "Hugins" } })
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
		local preset = findOption(ns.optionsTable, "preset")
		if preset and preset.set then preset.set({ "preset" }, "incharacter") end
		speech.mixedLines, speech.mixedShare = "Own line, {name}.", "always"
		H.owe(ns, "Munin Hugins")
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local text = macro(ns)
		if not ns.InCharacter.Active(speech) then
			fail(scenario, "SKIPPED -- In character is not the set")
		elseif spoken(text) ~= "/say Own line, Munin Hugins." then
			fail(scenario, "SKIPPED -- the press is not armed with my own line: " .. flat(text))
		else
			local earlier = "An In character line said before, {name}."
			ns.InCharacter.Remember(earlier)
			H.pressButton(ns)
			local button = findOption(ns.optionsTable, "leaveOutLast")
			if ns.InCharacter.Last() ~= nil then
				fail(scenario, "after my own line was said the last line is " .. tostring(ns.InCharacter.Last()))
			end
			if button then
				if not button.disabled() then fail(scenario, "the button is live after my own line was said") end
				button.func()
				if #speech.leftOut ~= 0 then
					fail(scenario, "the button left out an older line: " .. tostring(speech.leftOut[1]))
				end
			end
		end
		guarded(scenario, ns)
	end
	restore()
end

-- ------------------------------------------------------------ names-own-lines 12
-- The line that asks for a buff (Ask.lua) says the first name too; its whisper
-- still goes to the whole name.
do
	local scenario = "names-own-lines: first name only reaches the line that asks for a buff"
	Mock.reset()
	Mock.class = "WARRIOR"
	Mock.unitClass = "PRIEST"
	Mock.playerHeld = {}
	-- The quiet world ask.lua hands its scenarios: the mock answers nothing
	-- about resting or fighting, and an ask waits on both.
	local realResting, realFighting = rawget(_G, "IsResting"), rawget(_G, "UnitAffectingCombat")
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "UnitAffectingCombat", function() return false end)
	local restoreUnits = H.strangers({ nameplate1 = { "Anna", "Aim" } })
	local function restore()
		restoreUnits()
		rawset(_G, "IsResting", realResting)
		rawset(_G, "UnitAffectingCombat", realFighting)
	end
	local ns = load(scenario)
	local ok, err = pcall(function()
		if not ns then return end
		H.freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.ask = true
		db.ask.channel = "WHISPER"
		local entry
		for _, e in ipairs(ns.BuildQueue()) do
			if e.ask then entry = e break end
		end
		if not entry then
			fail(scenario, "SKIPPED -- nobody is asked")
		else
			local function words()
				local line = ns.Ask.MacroFor(entry)
				if type(line) ~= "string" or line:sub(1, 12) ~= "/w Anna Aim " then return nil, line end
				return line:sub(13), line
			end
			local said, line = words()
			if not (said and said:find("Anna Aim", 1, true)) then
				fail(scenario, "SKIPPED -- with the switch off the ask was " .. tostring(line))
			end
			db.speech.firstNameOnly = true
			said, line = words()
			if not said then
				fail(scenario, "with First name only the ask did not go to the whole name: " .. tostring(line))
			elseif said:find("Anna Aim", 1, true) or not said:find("Anna", 1, true) then
				fail(scenario, "with First name only the ask said " .. said)
			end
		end
		guarded(scenario, ns)
	end)
	restore()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------ names-own-lines 13
-- What I say's reset puts First name only and the share back, and keeps the
-- lines left out, as it keeps the player's own lines.
do
	local scenario = "names-own-lines: the reset puts the switch and the share back and keeps the lines left out"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		speech.firstNameOnly, speech.mixedShare, speech.leftOut = true, "always", { "Kept, {name}." }
		local ok, answer = pcall(ns.OptionsPage.ResetPage, "click")
		speech = ns.db.profile.speech
		if not ok or answer ~= true then
			fail(scenario, "SKIPPED -- the reset did not run: " .. tostring(answer))
		else
			if speech.firstNameOnly ~= false then fail(scenario, "First name only was left " .. tostring(speech.firstNameOnly)) end
			if speech.mixedShare ~= "third" then fail(scenario, "the share was left " .. tostring(speech.mixedShare)) end
			if type(speech.leftOut) ~= "table" or speech.leftOut[1] ~= "Kept, {name}." then
				fail(scenario, "the reset dropped the lines left out")
			end
		end
		guarded(scenario, ns)
	end
end
