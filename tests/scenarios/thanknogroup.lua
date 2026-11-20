-- Don't thank anybody while I'm in a party or a raid (prompt.thankNotInGroup).
-- Asked for on CurseForge: no /thank in a group or a raid. The switches that
-- sound like it (Say nothing in a party, Say nothing in a raid) only silence
-- the line said with a cast, so this one is a rule of its own, in the one gate
-- every thank passes (Favours.lua, Held): off by default; on, nothing goes in
-- a party or a raid outdoors, to a member or a stranger, by emote, whisper or
-- as an offer on the prompt; a battleground or an arena is left to Thank people
-- there (Battle.lua).
--
-- Every scenario name starts with "thanknogroup:" so the mutations in
-- tests/mutations/thanknogroup.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, primeAuras, favourFrom, findOption =
	H.strangers, H.freshPrompt, H.primeAuras, H.favourFrom, H.findOption

local TOUCHED = { "IsInInstance", "IsInGroup", "IsInRaid", "DoEmote", "SendChatMessage", "C_ChatInfo",
	"UnitInParty", "UnitGUID", "UnitAffectingCombat", "IsResting" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end

local emotes, whispers = {}, {}
local place = false -- false outdoors, else IsInInstance's kind

-- One session. opts: class (a rogue unless named: nothing of his own to offer,
-- so the queue is the thanks alone), names (unit -> name), thank (the /thank,
-- on unless false), whisper (off unless true), unseen, ask, on (the switch:
-- left at its default when nil), grouped ("party" or "raid": what IsInGroup
-- and IsInRaid answer; nil is solo), size (Mock.groupSize, with only the
-- party's own tokens counted as members), before (run before the baseline
-- settles).
local function with(scenario, opts, body)
	Mock.reset()
	local names = opts.names or { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Brisk" } }
	local plates = {}
	for unit in pairs(names) do
		if unit:find("^nameplate") then plates[#plates + 1] = unit end
	end
	table.sort(plates)
	Mock.nameplates = plates
	Mock.class = opts.class or "ROGUE"
	if opts.size then Mock.groupSize = opts.size end
	emotes, whispers, place = {}, {}, false
	rawset(_G, "IsInInstance", function() return place ~= false, place or "none" end)
	rawset(_G, "IsInGroup", function() return opts.grouped == "party" end)
	rawset(_G, "IsInRaid", function() return opts.grouped == "raid" end)
	rawset(_G, "DoEmote", function(emote, target) emotes[#emotes + 1] = { emote, target } end)
	rawset(_G, "C_ChatInfo", nil)
	rawset(_G, "SendChatMessage", function(text, channel, _, target)
		whispers[#whispers + 1] = { text = text, channel = channel, target = target }
	end)
	rawset(_G, "UnitAffectingCombat", function() return false end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "UnitGUID", function(unit)
		local name = Mock.unitNames and Mock.unitNames[unit]
		return "Player-1-" .. (type(name) == "table" and table.concat(name, "-") or tostring(unit))
	end)
	if opts.size then
		rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end)
	end
	local undo = strangers(names)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.prompt.thankEmote = opts.thank ~= false
		db.prompt.thankWhisper = opts.whisper == true
		db.prompt.thankDelay = false
		db.prompt.thankUnseen = opts.unseen == true
		db.prompt.thankAsk = opts.ask == true
		if opts.on ~= nil then db.prompt.thankNotInGroup = opts.on end
		if opts.before then opts.before(ns) end
		primeAuras(ns)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline never settled")
			return
		end
		Mock.timers = {}
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
local function fortitude(ns) return ns.BUFF_BY_ID[10938] and 10938 or 21562 end

local nextId = 9300
local function favour(ns, unit)
	nextId = nextId + 1
	return favourFrom(ns, unit, fortitude(ns), nextId)
end

-- The reason the newest passed-over thank gives.
local function why(ns)
	local log = ns.thankLog.skipped
	return log and log.why
end

-- The thank-yous waiting in a queue built now.
local function offers(ns)
	local out = {}
	for _, e in ipairs(ns.BuildQueue()) do
		if e.thank then out[#out + 1] = e end
	end
	return out
end

local WHY = "in a party or a raid"

-- A party of two besides you, as the mock counts one: a member on party1, a
-- stranger on a nameplate.
local PARTY = {
	size = 2, grouped = "party",
	names = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bo", "Brisk" }, party1 = { "Cy", "Cole" } },
}
local function party(extra)
	local opts = {}
	for k, v in pairs(PARTY) do opts[k] = v end
	for k, v in pairs(extra or {}) do opts[k] = v end
	return opts
end

-- ------------------------------------------------------------------ the switch
do
	local scenario = "thanknogroup: off by default, a party member's buff is thanked"
	with(scenario, party(), function(ns)
		if ns.defaults.profile.prompt.thankNotInGroup ~= false then
			fail(scenario, "the switch is not off in a new profile")
		end
		favour(ns, "party1")
		if #emotes ~= 1 or emotes[1][2] ~= "party1" then
			fail(scenario, ("%d emotes for a party member with the switch off (%s)"):format(#emotes, tostring(why(ns))))
		end
		-- A profile that never had the setting reads as off, not as on.
		Mock.advance(400)
		emotes = {}
		rawset(ns.db.profile.prompt, "thankNotInGroup", nil)
		favour(ns, "nameplate1")
		if #emotes ~= 1 then
			fail(scenario, ("%d emotes with the setting missing altogether (%s)"):format(#emotes, tostring(why(ns))))
		end
	end)
end

do
	local scenario = "thanknogroup: on in a party outdoors, no emote and the skip says in a party or a raid"
	with(scenario, party({ on = true }), function(ns)
		favour(ns, "party1")
		if #emotes ~= 0 then fail(scenario, "a party member was thanked in a party") return end
		if why(ns) ~= WHY then fail(scenario, "the skip says " .. tostring(why(ns))) end
		-- And a stranger beside the party.
		Mock.advance(12)
		favour(ns, "nameplate1")
		if #emotes ~= 0 then fail(scenario, "a stranger was thanked in a party") end
	end)
end

do
	local scenario = "thanknogroup: on in a raid outdoors, a stranger's buff gets no emote"
	with(scenario, { on = true, grouped = "raid" }, function(ns)
		favour(ns, "nameplate1")
		if #emotes ~= 0 then fail(scenario, "a stranger was thanked in a raid") return end
		if why(ns) ~= WHY then fail(scenario, "the skip says " .. tostring(why(ns))) end
	end)
end

do
	local scenario = "thanknogroup: on, the whispered thank-you is held too"
	with(scenario, { grouped = "party", thank = false, whisper = true }, function(ns)
		-- By itself first, as it goes with the switch off.
		favour(ns, "nameplate1")
		if #whispers ~= 1 then
			fail(scenario, ("SKIPPED -- %d whispers with the switch off (%s)"):format(#whispers, tostring(why(ns))))
			return
		end
		ns.db.profile.prompt.thankNotInGroup = true
		Mock.advance(12)
		favour(ns, "nameplate2")
		if #whispers ~= 1 then fail(scenario, "a whisper went in a party with the switch on") end
		if why(ns) ~= WHY then fail(scenario, "the skip says " .. tostring(why(ns))) end
	end)
end

do
	local scenario = "thanknogroup: on and solo, a stranger is thanked"
	with(scenario, { on = true }, function(ns)
		favour(ns, "nameplate1")
		if #emotes ~= 1 or emotes[1][2] ~= "nameplate1" then
			fail(scenario, ("%d emotes for a stranger while solo (%s)"):format(#emotes, tostring(why(ns))))
		end
	end)
end

do
	local scenario = "thanknogroup: on with Ask me before thanking, no thank offer on the prompt"
	with(scenario, party({ ask = true }), function(ns)
		-- The offer made with the switch off, which the switch then drops.
		favour(ns, "nameplate2")
		if #offers(ns) ~= 1 then
			fail(scenario, ("SKIPPED -- %d offers with the switch off"):format(#offers(ns)))
			return
		end
		ns.db.profile.prompt.thankNotInGroup = true
		if #offers(ns) ~= 0 then fail(scenario, "a waiting offer stayed on the queue once the switch was on") end
		Mock.advance(12)
		favour(ns, "nameplate1")
		if #offers(ns) ~= 0 then fail(scenario, "a thank was offered in a party with the switch on") end
		if why(ns) ~= WHY then fail(scenario, "the skip says " .. tostring(why(ns))) end
	end)
end

do
	local scenario = "thanknogroup: in a battleground Thank people there still thanks your team"
	with(scenario, party({ on = true }), function(ns)
		place = "pvp"
		if ns.db.profile.battle.thank ~= true then fail(scenario, "Thank people there is not on in a new profile") end
		favour(ns, "party1")
		if #emotes ~= 1 then
			fail(scenario, ("a team-mate was not thanked in a battleground (%s)"):format(tostring(why(ns))))
		end
	end)
end

do
	local scenario = "thanknogroup: unseen thank held in a party"
	-- The mock's head count stays at nobody, which leaves a buff with no caster
	-- to Favours.lua's MaybeMember (it holds an unseen thank in any group of
	-- somebody who could have cast it): this switch is what holds it here.
	with(scenario, { grouped = "party", unseen = true }, function(ns)
		-- With the switch off, an emote at nobody goes.
		favour(ns, nil)
		if #emotes ~= 1 or emotes[1][2] ~= nil then
			fail(scenario, ("SKIPPED -- %d emotes for an unseen buff with the switch off"):format(#emotes))
			return
		end
		ns.db.profile.prompt.thankNotInGroup = true
		Mock.advance(400)
		emotes = {}
		favour(ns, nil)
		if #emotes ~= 0 then fail(scenario, "an emote at nobody went in a party with the switch on") end
		local log = ns.thankLog.unseenSkipped
		if not (log and log.why == WHY) then
			fail(scenario, "the unseen skip says " .. tostring(log and log.why))
		end
	end)
end

do
	local scenario = "thanknogroup: shown on What I say, greyed with both thank switches off"
	with(scenario, { thank = false, whisper = false }, function(ns)
		local control = findOption(ns.optionsTable, "thankNotInGroup")
		if not control then fail(scenario, "What I say has no switch for it") return end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		if control.get() ~= false then fail(scenario, "the switch is on in a new profile") end
		local hidden = control.hidden
		if type(hidden) == "function" then hidden = hidden() end
		if hidden then fail(scenario, "the switch is hidden from a rogue") end
		if not (type(control.disabled) == "function" and control.disabled()) then
			fail(scenario, "the switch is live with the /thank and the whisper both off")
		end
		ns.db.profile.prompt.thankWhisper = true
		if control.disabled() then fail(scenario, "the switch is greyed with the whisper on") end
		ns.db.profile.prompt.thankWhisper = false
		ns.db.profile.prompt.thankEmote = true
		if control.disabled() then fail(scenario, "the switch is greyed with the /thank on") end
		control.set(nil, true)
		if ns.db.profile.prompt.thankNotInGroup ~= true or control.get() ~= true then
			fail(scenario, "turning it on was not kept")
		end
		local found
		for _, section in ipairs(ns.WindowLayout.pages.click.sections) do
			for i, item in ipairs(section.items) do
				local path = type(item) == "table" and item[1] or item
				if path == "click.thankNotInGroup" then
					local before = section.items[i - 1]
					found = type(item) == "table" and item.indent == true and type(before) == "table"
						and before[1] == "click.thankAsk"
				end
			end
		end
		if not found then fail(scenario, "the switch is not indented under Ask me before thanking") end
		-- What I say's reset puts it back off.
		local reset, answer = pcall(ns.OptionsPage.ResetPage, "click")
		if reset and answer == true and ns.db.profile.prompt.thankNotInGroup ~= false then
			fail(scenario, "the page's reset left it " .. tostring(ns.db.profile.prompt.thankNotInGroup))
		end
	end)
end

do
	local scenario = "thanknogroup: a pasted string can switch it on, never off"
	with(scenario, {}, function(ns)
		local prompt = ns.db.profile.prompt
		prompt.thankNotInGroup = true
		local on = ns.ExportSettings()
		prompt.thankNotInGroup = false
		local off = ns.ExportSettings()
		-- A string that has it off, onto a profile that has it on.
		prompt.thankNotInGroup = true
		local ok = ns.ImportSettings(off)
		if not ok then fail(scenario, "SKIPPED -- the string did not import") return end
		if ns.db.profile.prompt.thankNotInGroup ~= true then
			fail(scenario, "a pasted string that has it off switched it off")
		end
		-- A string that does not carry the key at all, as a friend's from before it existed.
		prompt.thankNotInGroup = true
		local bare = off:gsub("[^\n;,%s]*thankNotInGroup[^\n;,]*[\n;,]?", "")
		if bare ~= off and ns.ImportSettings(bare) and ns.db.profile.prompt.thankNotInGroup ~= true then
			fail(scenario, "a pasted string without the key switched it off")
		end
		-- And one that has it on switches it on.
		ns.db.profile.prompt.thankNotInGroup = false
		ok = ns.ImportSettings(on)
		if ok and ns.db.profile.prompt.thankNotInGroup ~= true then
			fail(scenario, "a pasted string with it on did not carry it")
		end
	end)
end
