-- Whisper a thank-you to people I can't buff back (prompt.thankWhisper, 1.11.15).
-- A warrior on CurseForge asked for a word of thanks to whoever buffs him, as
-- he has nothing to give back. /say needs a key press outside an instance, so
-- it is a whisper, sent outright: an In character thanks line, by the player's
-- people and class, to somebody who buffs you and is owed nothing back. Off by
-- default; under the /thank's rules and limits (no fight, no instance, once a
-- person every five minutes); a favour you will return is thanked by that.
--
-- Every scenario name starts with "thankwhisper:" so the mutations in
-- tests/mutations/thankwhisper.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom, findOption =
	H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom, H.findOption

-- Power Word: Fortitude.
local FORTITUDE = 10938

local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Brisk" } }

local TOUCHED = { "IsInInstance", "DoEmote", "SendChatMessage", "C_ChatInfo" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local emotes, whispers = {}, {}
local inside = false

-- One session as `opts.class` (a rogue: nothing to give), two strangers on
-- nameplates, outdoors, the whisper as opts.whisper says (on unless false) and
-- the /thank as opts.thank (off unless true).
local function with(scenario, opts, body)
	Mock.reset()
	Mock.nameplates = { "nameplate1", "nameplate2" }
	Mock.class = opts.class or "ROGUE"
	emotes, whispers, inside = {}, {}, false
	rawset(_G, "IsInInstance", function() return inside, inside and "party" or "none" end)
	rawset(_G, "DoEmote", function(emote, target) emotes[#emotes + 1] = { emote, target } end)
	rawset(_G, "C_ChatInfo", nil)
	rawset(_G, "SendChatMessage", function(text, channel, _, target)
		whispers[#whispers + 1] = { text = text, channel = channel, target = target }
	end)
	local undo = strangers(PEOPLE)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		if opts.whisper ~= nil then db.prompt.thankWhisper = opts.whisper else db.prompt.thankWhisper = true end
		db.prompt.thankEmote = opts.thank == true
		primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
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

local nextId = 9000
local function favour(ns, unit, spell)
	nextId = nextId + 1
	return favourFrom(ns, unit, spell or FORTITUDE, nextId)
end

local function listed()
	local out = {}
	for _, w in ipairs(whispers) do out[#out + 1] = tostring(w.target) .. ": " .. tostring(w.text) end
	return table.concat(out, " | ")
end

do
	local scenario = "thankwhisper: off by default, nothing is whispered"
	with(scenario, { whisper = false }, function(ns)
		if ns.defaults.profile.prompt.thankWhisper ~= false then fail(scenario, "the whisper is not off by default") end
		favour(ns, "nameplate1")
		if #whispers ~= 0 then fail(scenario, "whispered with the switch off: " .. listed()) end
	end)
end

do
	local scenario = "thankwhisper: a rogue whispers a thank-you to who buffed her"
	with(scenario, {}, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		favour(ns, "nameplate1")
		local w = whispers[1]
		if #whispers ~= 1 or not w then fail(scenario, ("%d whispers went"):format(#whispers)) return end
		if w.channel ~= "WHISPER" or w.target ~= anna then
			fail(scenario, ("the whisper went %s to %s"):format(tostring(w.channel), tostring(w.target)))
		end
		local text = tostring(w.text)
		if text == "" or #text > 255 or text:find("[{}]") or text:find("^/") then
			fail(scenario, "the line whispered was: " .. text)
		end
		if #emotes ~= 0 then fail(scenario, "an emote was made with the /thank off") end
	end)
end

do
	local scenario = "thankwhisper: somebody you will buff back is not whispered"
	with(scenario, { class = "MAGE", thank = true }, function(ns)
		if #ns.CastableBuffs() == 0 then fail(scenario, "SKIPPED -- the mage has nothing to cast") return end
		local anna = ns.UnitFullName("nameplate1")
		favour(ns, "nameplate1")
		if not ns.owed[anna] then fail(scenario, "SKIPPED -- no debt was filed") return end
		if #whispers ~= 0 then fail(scenario, "a favour you will return was whispered: " .. listed()) end
		if #emotes ~= 1 then fail(scenario, ("the /thank went %d times beside it"):format(#emotes)) end
	end)
end

do
	local scenario = "thankwhisper: never in an instance, and once a person at a time"
	with(scenario, {}, function(ns)
		inside = true
		favour(ns, "nameplate1")
		if #whispers ~= 0 then fail(scenario, "whispered in an instance: " .. listed()) end
		inside = false
		Mock.advance(30)
		favour(ns, "nameplate2")
		if #whispers ~= 1 then fail(scenario, "SKIPPED -- the first whisper outdoors did not go") return end
		Mock.advance(30)
		favour(ns, "nameplate2")
		if #whispers ~= 1 then fail(scenario, "the same person was whispered twice in a minute: " .. listed()) end
	end)
end

-- Who cast a buff is read only while something would use it: the whisper is
-- one, with People who buff me and the /thank both off.
do
	local scenario = "thankwhisper: whispered with People who buff me off"
	with(scenario, {}, function(ns)
		ns.db.profile.sources.owed = false
		favour(ns, "nameplate1")
		if #whispers ~= 1 then fail(scenario, ("%d whispers went with People who buff me off"):format(#whispers)) end
	end)
end

do
	local scenario = "thankwhisper: with the /thank on too, both go"
	with(scenario, { thank = true }, function(ns)
		favour(ns, "nameplate1")
		if #whispers ~= 1 then fail(scenario, ("%d whispers went"):format(#whispers)) end
		if #emotes ~= 1 then fail(scenario, ("%d emotes were made"):format(#emotes)) end
	end)
end

do
	local scenario = "thankwhisper: the switch is on What I say, for a class with nothing to give too"
	with(scenario, { whisper = false }, function(ns)
		local option = findOption(ns.optionsTable, "thankWhisper")
		if not option then fail(scenario, "What I say has no whisper switch") return end
		local hidden = option.hidden
		if type(hidden) == "function" then hidden = hidden() end
		if hidden then fail(scenario, "the whisper switch is hidden for a rogue") end
		option.set(nil, true)
		if ns.db.profile.prompt.thankWhisper ~= true or option.get() ~= true then
			fail(scenario, "turning it on was not stored")
		end
	end)
end
