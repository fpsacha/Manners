-- The player's own lines said among the In character ones (1.11.25). A player
-- on the RP server asked to add lines of their own without giving up the In
-- character set: the phrase box cannot hold both, since typing in it turns In
-- character off. *My own lines, mixed in* (speech.mixedLines, What I say) is a
-- box of its own, shown while In character is the set; about one press in
-- three says one of its lines (Speech.lua, MixedIn), the rest stay In
-- character's.
--
-- Every scenario name starts with "mixedlines:" so the mutations in
-- tests/mutations/mixedlines.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive, findOption = H.fail, H.load, H.drive, H.findOption

-- A session with speech on and In character loaded through the dropdown.
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
	return ns
end

local function person(ns)
	return { name = "Bram", short = "Bram", reason = "nearby",
		buff = ns.ResolveBuff(true) or ns.FindBuff("MAGE", "intellect") }
end

-- math.random answering from a list in turn (the last one for ever after).
-- An empty interval (n below 1) is refused as the game's Lua refuses it, so a
-- pick from no lines at all throws here as it would there.
local function withRolls(rolls, fn)
	local real, at = math.random, 0
	math.random = function(n)
		at = at + 1
		local v = rolls[at] or rolls[#rolls]
		if n and n < 1 then return real(n) end
		if n then return math.max(1, math.min(n, v)) end
		return real()
	end
	local ok, err = pcall(fn)
	math.random = real
	if not ok then error(err, 0) end
end

do
	local scenario = "mixedlines: one press in three says one of your own lines, the rest stay In character's"
	local ns = ready(scenario)
	if ns then
		local speech = ns.db.profile.speech
		if speech.mixedLines ~= "" then fail(scenario, "a new profile's own lines are " .. tostring(speech.mixedLines)) end
		if not ns.InCharacter.Active(speech) then fail(scenario, "SKIPPED -- In character is not the set") end
		local entry = person(ns)
		-- Empty: every line is In character's, whatever the roll.
		withRolls({ 1 }, function()
			local line = ns.PickPhrase(entry, 250)
			if line and line:find("Well met", 1, true) then fail(scenario, "an own line was said with the box empty") end
		end)
		speech.mixedLines = "Well met, {name}!\nHave some {buff}."
		-- The roll of three comes up one: an own line, the first of the two.
		withRolls({ 1, 1 }, function()
			local line = ns.PickPhrase(entry, 250)
			if line ~= "/say Well met, Bram!" then fail(scenario, "the roll came up, and the line was " .. tostring(line)) end
		end)
		-- ...and the second, with the spell's name in it.
		withRolls({ 1, 2 }, function()
			local line = ns.PickPhrase(entry, 250) or ""
			if not (line:find("^/say Have some ") and not line:find("{buff}", 1, true)) then
				fail(scenario, "the second own line was said as " .. line)
			end
		end)
		-- The roll comes up two or three: In character's own pick.
		for _, roll in ipairs({ 2, 3 }) do
			withRolls({ roll }, function()
				local line = ns.PickPhrase(entry, 250) or ""
				if line:find("Well met", 1, true) or line:find("Have some", 1, true) then
					fail(scenario, "a roll of " .. roll .. " in three said an own line: " .. line)
				end
			end)
		end
		-- A line too long for the macro is left out, and one that fits is still said.
		speech.mixedLines = ("x"):rep(300) .. "\nShort one."
		withRolls({ 1, 1 }, function()
			local line = ns.PickPhrase(entry, 250)
			if line ~= "/say Short one." then fail(scenario, "with one line too long, the line was " .. tostring(line)) end
		end)
		-- Only lines too long: In character answers, never nothing.
		speech.mixedLines = ("x"):rep(300)
		withRolls({ 1 }, function()
			local ok, line = pcall(ns.PickPhrase, entry, 250)
			if not ok then line = "an error: " .. tostring(line) end
			if not ok or not line or line:find("xxxx", 1, true) then fail(scenario, "with only a line too long, the line was " .. tostring(line)) end
		end)
		-- Not while another set is loaded: the phrase box is the player's own already.
		speech.mixedLines = "Well met, {name}!"
		speech.presetChoice, speech.phrases = "polite", "Cheers, {name}."
		withRolls({ 1, 1 }, function()
			local line = ns.PickPhrase(entry, 250)
			if line ~= "/say Cheers, Bram." then fail(scenario, "with another set loaded the line was " .. tostring(line)) end
		end)
	end
end

do
	local scenario = "mixedlines: the box is on What I say while In character is the set, and is kept"
	local ns = ready(scenario)
	if ns then
		local speech = ns.db.profile.speech
		local box = findOption(ns.optionsTable, "mixedLines")
		if not box then
			fail(scenario, "What I say has no box for your own lines")
		else
			if box.hidden() then fail(scenario, "hidden with In character as the set") end
			box.set(nil, "Hail, {name}!")
			if speech.mixedLines ~= "Hail, {name}!" or box.get() ~= "Hail, {name}!" then
				fail(scenario, "typing in it wrote " .. tostring(speech.mixedLines))
			end
			speech.enabled = false
			if not box.hidden() then fail(scenario, "shown with speaking off") end
			speech.enabled = true
			speech.presetChoice, speech.phrases = "polite", "Cheers, {name}."
			if not box.hidden() then fail(scenario, "shown with another set loaded") end
		end
		-- A damaged value is repaired, and a paste cannot put words in a speaker's mouth.
		speech.mixedLines = 7
		ns.repairLog = {}
		ns.ClampSettings()
		if speech.mixedLines ~= "" then fail(scenario, "a damaged box was left as " .. tostring(speech.mixedLines)) end
		-- ...and written down with the other repairs, for /manners selftest.
		local logged = false
		for _, line in ipairs(ns.repairLog) do
			if line:find("speech.mixedLines (was 7)", 1, true) then logged = true end
		end
		if not logged then fail(scenario, "the repair of a damaged box is not in the repair log") end
		-- Placed on the page.
		local placed = false
		for _, section in ipairs(ns.WindowLayout.pages.click.sections) do
			for _, item in ipairs(section.items) do
				if (type(item) == "table" and item[1] or item) == "click.mixedLines" then placed = true end
			end
		end
		if not placed then fail(scenario, "click.mixedLines is not placed on What I say") end
	end
end
