-- Bug hunt 34, the phrase box across languages (Phrases.lua RP.OTHER_HASH,
-- RP.InThisLanguage; Speech.lua EnglishPhraseSet; Core.lua ClampSettings): a
-- box a client in one language filled with an unedited set follows the client
-- when its language changes, and a player's own words are never touched.
-- Names start with "hunt34-phrases:".

local dir, H = ...
local fail, load = H.fail, H.load

local LOCALES = { "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }
local SETS = { "roleplay", "polite", "cheeky", "quiet", "incharacter" }

-- A session as `locale`, the addon loaded and driven, body(ns) run, the mock
-- reset after.
local function session(scenario, locale, body)
	Mock.reset()
	Mock.locale = locale
	local ns = load(scenario)
	if ns then
		H.drive(scenario, ns)
		ns.Prompt:ExitTest()
		local ok, err = pcall(body, ns)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end
	Mock.reset()
end

-- What each language writes into the box for each set, and that the table holds
-- every one of them as it reads there (a line the table has read differently
-- would come back from InThisLanguage as something else).
local texts = {}
for _, locale in ipairs(LOCALES) do
	local scenario = "hunt34-phrases: " .. locale .. " reads its own sets as they are"
	texts[locale] = {}
	session(scenario, locale, function(ns)
		for _, set in ipairs(SETS) do
			local text = ns.PhraseSetText(set)
			texts[locale][set] = text
			if ns.InThisLanguage(text) ~= text then
				fail(scenario, "the other-languages table does not read the " .. set .. " set as it stands here")
			end
		end
	end)
end

-- Every language's unedited set, found in a box on a client in another.
for _, client in ipairs({ "enUS", "zhCN", "deDE" }) do
	local scenario = "hunt34-phrases: an unedited set from another language follows a " .. client .. " client"
	session(scenario, client ~= "enUS" and client or nil, function(ns)
		local bad = {}
		for _, locale in ipairs(LOCALES) do
			for _, set in ipairs(SETS) do
				local text = texts[locale][set]
				if text and text ~= ns.PhraseSetText(set) then
					local speech = ns.db.profile.speech
					speech.presetChoice, speech.phrases = set, text
					ns.ClampSettings()
					if speech.phrases ~= ns.PhraseSetText(set) then
						bad[#bad + 1] = locale .. "/" .. set
					end
				end
			end
		end
		if #bad > 0 then
			fail(scenario, #bad .. " box(es) kept the language they were filled in: "
				.. table.concat(bad, " ", 1, math.min(#bad, 8)))
		end
	end)
end

-- Words of the player's own stay: a line changed, one dropped, one added, the
-- lines turned about, in the other language's set and in the examples.
do
	local scenario = "hunt34-phrases: a player's own box in another language's words is left alone"
	session(scenario, nil, function(ns)
		local speech = ns.db.profile.speech
		for _, set in ipairs({ "roleplay", "polite", "incharacter" }) do
			local lines = {}
			for line in texts.deDE[set]:gmatch("[^\n]+") do lines[#lines + 1] = line end
			local edits = {
				changed = function(t) t[2] = t[2] .. " (mine)" return t end,
				dropped = function(t) table.remove(t, 1) return t end,
				added = function(t) t[#t + 1] = "Mein eigener Satz, {name}." return t end,
				swapped = function(t) t[1], t[2] = t[2], t[1] return t end,
				blank = function(t) t[#t + 1] = "" return t end,
			}
			for name, edit in pairs(edits) do
				local copy = {}
				for i, line in ipairs(lines) do copy[i] = line end
				local box = table.concat(edit(copy), "\n")
				speech.presetChoice, speech.phrases = set, box
				ns.ClampSettings()
				if speech.phrases ~= box then
					fail(scenario, ("the German %s box with one line %s was rewritten as %s"):format(
						set, name, speech.phrases:sub(1, 60)))
				end
			end
		end
		-- In character with such a box stops reading as the set, as it always has.
		speech.presetChoice, speech.phrases = "incharacter", texts.deDE.incharacter .. "\nMein Satz, {name}."
		if ns.InCharacter.Active(speech) then
			fail(scenario, "a German examples box with a line of the player's own still reads as In character")
		end
	end)
end

-- In character stays on: the German examples are the set on an English client
-- and are saved again as this character's English examples.
do
	local scenario = "hunt34-phrases: In character keeps speaking after the client's language changes"
	session(scenario, nil, function(ns)
		local speech = ns.db.profile.speech
		speech.presetChoice, speech.phrases = "incharacter", texts.deDE.incharacter
		if texts.deDE.incharacter == ns.PhraseSetText("incharacter") then
			fail(scenario, "SKIPPED -- the German examples are the English ones")
			return
		end
		if not ns.InCharacter.Active(speech) then
			fail(scenario, "In character does not read a German examples box as the set on an English client")
		end
		ns.ClampSettings()
		if speech.phrases ~= ns.PhraseSetText("incharacter") then
			fail(scenario, "the German examples were not saved as this client's own")
		end
	end)
end
