-- 1.5.1: the In character box's note names how many lines the set has.
--
-- The box holds a handful of examples, the first line of a few pools, and a
-- player read those eight lines as everything In character could say ("i asked
-- to get more lines but there's only 8"). The note above the box now gives the
-- count of what the pick can really say on this client: every pool, after the
-- untranslated lines are left out on another language's client.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function note(ns)
	local node = H.findOption and H.findOption(ns.optionsTable, "inCharacterNote")
	if not node then return nil end
	local name = node.name
	if type(name) == "function" then name = name({ "inCharacterNote", option = node }) end
	return name
end

for _, locale in ipairs({ "enUS", "deDE" }) do
	local scenario = "hotfix151: the In character note counts the lines (" .. locale .. ")"
	Mock.reset()
	Mock.locale = locale
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local count = ns.InCharacter and ns.InCharacter.Count and ns.InCharacter.Count()
		if type(count) ~= "number" then
			fail(scenario, "In character has no count of its lines")
		elseif count < 2000 then
			fail(scenario, ("In character counts %d lines, far fewer than the set has"):format(count))
		end
		local text = note(ns)
		if type(text) ~= "string" then
			fail(scenario, "SKIPPED -- the note above the box could not be read")
		elseif count and not text:find(tostring(count), 1, true) then
			fail(scenario, "the note above the box does not say how many lines there are: " .. text)
		end
	end
	Mock.locale = nil
end

-- "Say a line when I buff someone" does what it says on a fresh profile: a
-- player ticked it, buffed a passer-by and heard nothing, because "Only when I
-- buff someone back" was on by default underneath it.
do
	local scenario = "hotfix151: ticking Say a line speaks to a passer-by"
	Mock.reset()
	local restore = H.strangers({ nameplate1 = { "Slow", "Demise" } })
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		if speech.onlyWhenReturning ~= false then
			fail(scenario, "a fresh profile speaks only when returning a favour")
		end
		speech.enabled = true
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local text = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if not (text and text:find("/cast", 1, true)) then
			fail(scenario, "SKIPPED -- nobody is on the prompt: " .. tostring(text))
		elseif not text:find("\n/say ", 1, true) then
			fail(scenario, "a press on a passer-by says nothing: " .. (tostring(text):gsub("\n", " / ")))
		end
	end
	restore()
end
