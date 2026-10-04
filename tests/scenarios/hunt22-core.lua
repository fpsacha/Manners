-- Fixes from the twenty-second bug hunt, outside the options window: Salvation
-- still read on somebody it can no longer be cast on, a favour from another
-- raid group to a paladin offering only Salvation, the PvP hold counting
-- raiders a group spell cannot reach, the multi-word pleases and the
-- punctuation of other languages in chat, Toast's keycap, the preview's
-- count, the ledger's group cast line, a silent press that never landed
-- holding the line, and a shout's thank-you said beyond its 20 yards.
--
-- Every scenario name starts with "core22:" so the mutations in
-- tests/mutations/hunt22-core.py can name the one that has to catch them.
-- Globals a scenario replaces are put back after it, whether it finished or
-- threw. (Luxe on a light panel is in tests/scenarios/readable-luxe.lua, with
-- the rest of what it reads.)

local dir, H = ...
local fail, load = H.fail, H.load

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitIsVisible", "UnitIsDeadOrGhost", "UnitIsFeignDeath",
	"GetItemCount", "GetItemInfo", "IsUsableSpell", "C_UnitAuras", "C_Spell", "UnitLevel", "strcmputf8i" }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

-- One scenario: the mock reset, `before()` run on it, `units` named, the addon
-- loaded and body(ns) run. Everything is put back and the mock reset, whether
-- it finished or threw.
local function run(scenario, units, body, before)
	Mock.reset()
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore
	local ok, err = pcall(function()
		if before then before() end
		restore = H.strangers(units or {})
		local ns = load(scenario)
		if not ns then return end
		body(ns)
		noErrors(scenario, ns)
	end)
	if restore then restore() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A character that knows exactly these spell ids.
local function knowing(ids)
	local known = {}
	for _, id in ipairs(ids) do known[id] = true end
	local fn = function(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", fn)
	rawset(_G, "IsPlayerSpell", fn)
end

local function join(...)
	local out = {}
	for i = 1, select("#", ...) do
		for _, id in ipairs((select(i, ...))) do out[#out + 1] = id end
	end
	return out
end

-- A ten-player raid, raid1 being you: subgroup 1 is raid1-5, 2 raid6-10.
local function raidNames()
	local names = {}
	for i = 1, 10 do names["raid" .. i] = { "Raider" .. i, "Stone" } end
	return names
end

local function hover(row)
	Mock.tooltip = {}
	row.scripts.OnEnter(row)
	return table.concat(Mock.tooltip, "\n")
end

-- ------------------------------------------------------------------ core22-1
-- Blessings overwrite each other, so holding any one of yours counts as
-- covered. Salvation can be cast only on your party or raid, and the walk
-- stopped reading it on anybody else: an ex-raider in town still wearing your
-- (Greater) Salvation was offered Wisdom, and the press replaced it. Another
-- paladin's Salvation covers nothing of yours, so Wisdom is still offered.
--
-- Owed, the debt policy offers the blessing they hold from you, which would
-- refresh it: not a Salvation the game refuses on them. And with Salvation
-- pinned, an owed passer-by is offered nothing whatever they wear: not
-- another paladin's Salvation, for want of anything else, nor one they lack.
local SALVATION, GREATER_SALVATION, MIGHT, WISDOM = 1038, 25895, 19740, 19742
for _, case in ipairs({
	{ "your Blessing of Salvation", SALVATION, "player" },
	{ "your Greater Blessing of Salvation", GREATER_SALVATION, "player" },
	{ "a Salvation the client names nobody for", SALVATION, nil },
	{ "another paladin's Salvation", SALVATION, "nameplate2", "wisdom" },
	{ "your Salvation, and owed", SALVATION, "player", nil, { owed = true } },
	{ "another paladin's Salvation, owed, Salvation pinned", SALVATION, "nameplate2", nil,
		{ owed = true, pin = true } },
	{ "nothing, owed, Salvation pinned", nil, nil, nil, { owed = true, pin = true } },
}) do
	local label, id, source, want, how = case[1], case[2], case[3], case[4], case[5] or {}
	local scenario = "core22: a passer-by wearing " .. label .. " is offered " .. (want or "nothing")
	run(scenario, { nameplate1 = { "Anna", "Aim" } }, function(ns)
		H.freshPrompt(ns, scenario)
		if how.pin then ns.db.profile.buff.choice = "salvation" end
		ns.Guard("probe", ns.ProbeCapabilities)
		if id then
			Mock.held = { [id] = true }
			Mock.heldSource = { [id] = source }
		else
			Mock.held = {}
		end
		if how.owed then H.owe(ns, "Anna Aim") end
		ns.ForgetUnitAuras(ns.plain(UnitGUID("nameplate1")))
		local entry = H.inQueue(ns)["Anna Aim"]
		local got = entry and entry.buff and entry.buff.key or nil
		if got ~= want then
			if want then
				fail(scenario, ("a passer-by wearing %s was offered %s, not Wisdom"):format(label, tostring(got)))
			else
				fail(scenario, ("a passer-by wearing %s was offered %s, and the press would replace it: "
					.. "holding any one of your blessings counts as covered"):format(label, tostring(got)))
			end
		end
	end, function()
		Mock.class = "PALADIN"
		knowing({ SALVATION, GREATER_SALVATION, MIGHT, WISDOM })
	end)
end

-- ------------------------------------------------------------------ core22-2
-- A paladin offering only Salvation, in a raid: it reaches the whole raid, so
-- a favour from a raider in another raid group is on the prompt, as the queue
-- offers it, and the ledger's row says the cast reaches your party or raid,
-- not your own subgroup.
for _, case in ipairs({ { "another raid group", "raid8" }, { "your own raid group", "raid3" } }) do
	local where, token = case[1], case[2]
	local scenario = "core22: a Salvation-only paladin's favour from " .. where .. " is on the prompt"
	local name = "Raider" .. token:match("%d+") .. " Stone"
	run(scenario, raidNames(), function(ns)
		H.freshPrompt(ns, scenario)
		local p = ns.db.profile
		p.buff.choice = "salvation"
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.db.char.ledger = nil
		ns.Ledger.Load()
		H.primeAuras(ns)
		local said = H.favourFrom(ns, token, 1459)
		local entry = H.inQueue(ns)[name]
		if not (entry and entry.reason == "owed" and entry.buff.key == "salvation") then
			fail(scenario, "SKIPPED -- " .. name .. " is not offered Salvation as owed: "
				.. tostring(entry and entry.buff.key))
			return
		end
		-- No "buffed you" line in a raid group (Favours.lua, QuietHere): the
		-- prompt is what says they are offered.
		if said:find("buffed you", 1, true) then
			fail(scenario, ("a favour from %s in a raid group was announced in chat: %s"):format(name, flat(said)))
		end
		local row
		for _, e in ipairs(ns.db.char.ledger and ns.db.char.ledger.entries or {}) do
			if e.kind == "received" and e.name == name then row = e end
		end
		ns.addon:HandleSlash("ledger")
		local r = ns.Ledger.Window().rows[1]
		if not (row and r and r.entry == row) then
			fail(scenario, "SKIPPED -- the favour's row is not the top of the ledger")
			return
		end
		local tip = hover(r)
		local T = ns.Ledger.TEXT
		if tip:find("subgroup", 1, true) then
			fail(scenario, "the row says Salvation reaches only your own subgroup, though it reaches the raid: " .. flat(tip))
		elseif row.partyOnly and not tip:find(T.TIP_OWED_GROUP, 1, true) then
			fail(scenario, "the row does not say Salvation reaches your party or raid: " .. flat(tip))
		end
	end, function()
		Mock.class = "PALADIN"
		Mock.raid = { size = 10, player = 1 }
		knowing({ SALVATION, MIGHT, WISDOM })
	end)
end

-- ------------------------------------------------------------------ core22-3
-- "Skip players flagged for PvP" holds a raid-wide group cast back while
-- anybody it lands on is flagged. It counted raiders it cannot land on: out of
-- the client's sight (beyond any group spell's 100 yards) or dead. A hunter
-- feigning death is no corpse, and the cast lands on him, so he still counts,
-- and so does somebody whose visibility the client will not give.
local MAGE_SINGLE = { 10157, 10156, 1461, 1460, 1459 }
local BRILLIANCE, ARCANE_POWDER = 23028, 17020
local WEARING_INT = { raid4 = true, raid5 = true, raid8 = true, raid9 = true, raid10 = true }

local function raidMage()
	Mock.raid = { size = 10, player = 1 }
	knowing(join(MAGE_SINGLE, { BRILLIANCE }))
	rawset(_G, "GetItemCount", function(id) return id == ARCANE_POWDER and 20 or 0 end)
	rawset(_G, "GetItemInfo", function(id) return id == ARCANE_POWDER and "Arcane Powder" or nil end)
	rawset(_G, "IsUsableSpell", function() return true, false end)
	rawset(_G, "UnitLevel", function() return 60 end)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			if unit == "player" then return base.GetUnitAuraBySpellID(unit, spellId) end
			if spellId == 10157 and WEARING_INT[unit] then
				return { spellId = spellId, expirationTime = Mock.now + 3600, duration = 3600, sourceUnit = "player" }
			end
			return nil
		end,
	}, { __index = base }))
end

local function groupCasts(ns)
	local groups = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.groupCast then groups[#groups + 1] = entry end
	end
	return groups
end

for _, case in ipairs({
	{ label = "out of sight", visible = false, held = false },
	{ label = "dead", dead = true, held = false },
	{ label = "a hunter feigning death", dead = true, feigning = true, held = true },
	{ label = "somebody whose visibility the client will not give", visible = "nil", held = true },
	{ label = "in sight and alive", held = true },
}) do
	local scenario = "core22: a flagged raider " .. case.label .. (case.held and " holds" or " does not hold")
		.. " the raid's group cast"
	run(scenario, raidNames(), function(ns)
		H.freshPrompt(ns, scenario)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:InvalidateMacro()
		local before = groupCasts(ns)[1]
		if not before then
			fail(scenario, "SKIPPED -- no group cast for the raid with nobody flagged")
			return
		end
		rawset(_G, "UnitIsVisible", function(unit)
			if unit == "raid9" then
				if case.visible == "nil" then return nil end
				if case.visible == false then return false end
			end
			return true
		end)
		rawset(_G, "UnitIsDeadOrGhost", function(unit)
			if unit == "player" then return Mock.dead end
			return unit == "raid9" and case.dead == true
		end)
		rawset(_G, "UnitIsFeignDeath", function(unit) return unit == "raid9" and case.feigning == true end)
		Mock.pvp = { raid9 = true }
		local flagged = ns.GroupCastFlagged(before)
		local after = groupCasts(ns)
		if case.held then
			if flagged ~= "Raider9 Stone" then
				fail(scenario, ("a press would cast Arcane Brilliance over Raider9, flagged for PvP and %s, whom it lands "
					.. "on: the press-time check named %s"):format(case.label, tostring(flagged)))
			end
			if #after > 0 then
				fail(scenario, "the raid's group cast is still offered with Raider9, flagged and " .. case.label
					.. ", in the raid: it lands on him and would flag you")
			end
		else
			if flagged ~= nil then
				fail(scenario, ("the press-time check lets go of the raid's cast for Raider9, flagged but %s, whom it "
					.. "cannot reach: %s"):format(case.label, tostring(flagged)))
			end
			if #after ~= 1 then
				fail(scenario, ("Raider9, flagged but %s, held back the raid's Arcane Brilliance, which cannot reach "
					.. "him: %d group casts"):format(case.label, #after))
			end
		end
	end, raidMage)
end

-- ------------------------------------------------------------------ core22-4
-- The pleases of more than one word in the shipped languages: "por favor",
-- "per favore", "s'il vous plaît". Beside a nickname or "buff" every other
-- word has to be a small one, and "por" and "per" were not; the French was no
-- please at all. A word of one alone is still none ("ça me plaît").
--
-- And the punctuation other languages put against a word: ¿ ¡, the one-
-- character ellipsis and the dash autocorrect makes, a Chinese keyboard's
-- full-width question mark. Stuck to the nickname, they hid it.
local ASK_CASES = {
	{ locale = "esES", name = "Intelecto Arcano", heard = { "int por favor", "buff por favor", "int, por favor",
		"por favor int", "int por favor?", "¿int?", "¡int pls!", "Intelecto Arcano por favor" },
		unheard = { "int no por favor" } },
	{ locale = "itIT", name = "Intelletto Arcano", heard = { "int per favore", "buff per favore" } },
	{ locale = "frFR", name = "Intelligence des Arcanes", heard = { "int s'il vous plaît", "int s'il te plait",
		"buff s'il vous plaît", "Intelligence des Arcanes s'il vous plaît", "int s\226\128\153il vous plaît",
		"INT S'IL VOUS PLAÎT" },
		unheard = { "int plaît", "int ça me plaît" } },
	{ locale = "enUS", name = "Arcane Intellect", heard = { "int pls\226\128\166", "int \226\128\148 pls",
		"int\239\188\159", "\194\161int pls!", "\194\191int?", "\194\171int\194\187 pls", "int\227\128\130" } },
	-- A sentence is no shorter for a comma: twelve characters at most, the
	-- comma among them, as before it separated words.
	{ locale = "zhCN", name = "奥术智慧", heard = { "请给我加奥术智慧" },
		unheard = { "法师你好，请给我加奥术智慧" } },
}

-- A message in a failure line, its bytes outside ASCII as escapes: the
-- console printing the run may have no character for a full-width one.
local function shown(text)
	return (text:gsub("[\128-\255]", function(c) return ("\\%d"):format(c:byte()) end))
end

local function hear(ns, text)
	ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", text, "Anna Aim", "Common", "", "", "", 0, 0, "", 0, 1,
		"Player-1-nameplate1")
end

for _, case in ipairs(ASK_CASES) do
	local scenario = "core22: a request in " .. case.locale .. " with its own please and punctuation is heard"
	run(scenario, { nameplate1 = { "Anna", "Aim" } }, function(ns)
		H.freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.asked, db.sources.strangers, db.sources.group = true, false, false
		if ns.BuffName(ns.FindBuff("MAGE", "intellect")) ~= case.name then
			fail(scenario, "SKIPPED -- the spell is not named " .. case.name .. " on this client")
			return
		end
		local function asked()
			local anna = H.inQueue(ns)["Anna Aim"]
			return anna ~= nil and anna.reason == "asked"
		end
		for _, text in ipairs(case.heard or {}) do
			hear(ns, text)
			if not asked() then
				fail(scenario, ("%q was not heard as a request for %s"):format(shown(text), shown(case.name)))
			end
			Mock.advance(61)
		end
		for _, text in ipairs(case.unheard or {}) do
			hear(ns, text)
			if asked() then
				fail(scenario, ("%q was heard as a request, though it asks for nothing"):format(shown(text)))
			end
			Mock.advance(61)
		end
	end, function()
		Mock.locale = case.locale
		-- The client's caseless compare, for the capitals: Î is î. Not
		-- string.lower, which on some C runtimes takes a UTF-8 byte for a
		-- Latin-1 letter.
		rawset(_G, "strcmputf8i", function(a, b)
			local function fold(s) return (s:gsub("[A-Z]", string.lower):gsub("\195\142", "\195\174")) end
			local fa, fb = fold(a), fold(b)
			if fa == fb then return 0 end
			return fa < fb and -1 or 1
		end)
		local real = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id)
				if id == 10157 or id == 1459 then return case.name end
				return real.GetSpellName(id)
			end,
		}, { __index = real }))
	end)
end

-- ------------------------------------------------------------------ core22-5
-- Toast's keycap only where a press casts, as Arcane's: not over a held panel
-- with nothing armed (a fight started under an outcome that emptied the
-- queue), and still there while a fight's frozen macro casts on an unlocked
-- prompt.
dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function keyShown(look)
	if not (look.keyChip and look.keyText) then return nil end
	return look.keyChip[2]._shown ~= false and look.keyText._shown ~= false
end

do
	local scenario = "core22: Toast shows its keycap only where a press casts"
	Mock.reset()
	FT.install()
	local restore = H.strangers({ nameplate1 = { "Anna", "Aim" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local function tick()
			ns.addon:Tick()
			FT.settle()
		end
		local function fight(on)
			Mock.inCombat = on
			if on then ns.addon:PLAYER_REGEN_DISABLED()
			elseif ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
			tick()
		end
		Mock.bindings = { F = COMMAND }
		H.freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		p.style = "toast"
		ns.Prompt:ApplyStyle()
		H.owe(ns, "Anna Aim")
		tick()
		local look = ns.Prompt:Regions().look
		local button = ns.Prompt:GetButton()
		if not (look and look.keyChip and keyShown(look) == true) then
			fail(scenario, "SKIPPED -- Toast shows no keycap armed at Anna with a key bound")
			return
		end
		-- A press lands and empties the queue; a fight starts under the outcome,
		-- which then runs out: the panel is held with nothing armed.
		local db = ns.db.profile
		for k in pairs(db.sources) do db.sources[k] = false end
		wipe(ns.owed)
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		tick()
		fight(true)
		Mock.advance(6)
		tick()
		if button:GetAttribute("type1") then
			fail(scenario, "SKIPPED -- the held panel is still armed")
		elseif keyShown(look) then
			fail(scenario, "the keycap is drawn over a held panel with nothing armed: pressing it casts nothing")
		end
		fight(false)
		-- Armed at Anna, a fight, then the prompt unlocked: the frozen macro
		-- still casts.
		for k in pairs(db.sources) do db.sources[k] = ns.defaults.profile.sources[k] end
		H.owe(ns, "Anna Aim")
		Mock.advance(6)
		tick()
		fight(true)
		p.locked = false
		ns.Prompt:ApplyStyle()
		tick()
		if not button:GetAttribute("type1") then
			fail(scenario, "SKIPPED -- the fight's macro did not stay armed through the unlock")
		elseif not keyShown(look) then
			fail(scenario, "the keycap is gone while the fight's frozen macro still casts on a press")
		end
		fight(false)
		tick()
		if button:GetAttribute("type1") then
			fail(scenario, "SKIPPED -- an unlocked prompt out of a fight is still armed")
		elseif keyShown(look) then
			fail(scenario, "the keycap is drawn on an unlocked prompt out of a fight, where a press casts nothing")
		end
		noErrors(scenario, ns)
	end)
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ core22-6
-- The preview's count chip covers every row it lists below, as a real paint's
-- does: each row is somebody else waiting. It said 2 over five rows.
for _, rows in ipairs({ 3, 5 }) do
	local scenario = "core22: the preview's count covers its " .. rows .. " listed rows"
	run(scenario, {}, function(ns)
		H.freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		p.showQueue, p.queueRows, p.showCount = true, rows, true
		ns.db.profile.sources.self = false
		ns.Prompt:ApplyStyle()
		ns.Prompt:ToggleTest()
		if not ns.Prompt:InTest() then
			fail(scenario, "SKIPPED -- the preview did not start")
			return
		end
		local count = tonumber(ns.Prompt:Regions().count:GetText() or "")
		if not count or count < rows then
			fail(scenario, ("the preview lists %d rows under a count of %s"):format(rows, tostring(count)))
		end
		ns.Prompt:ExitTest()
	end)
end

-- ------------------------------------------------------------------ core22-7
-- A group cast's ledger row said it reached people "in their party or class";
-- on Forever Arcane Brilliance reaches the whole raid. The row names no group.
do
	local scenario = "core22: a raid's group cast in the ledger names no party or class"
	run(scenario, raidNames(), function(ns)
		H.freshPrompt(ns, scenario)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.db.char.ledger = nil
		ns.Ledger.Load()
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:InvalidateMacro()
		local group = groupCasts(ns)[1]
		if not (group and group.groupCast.where == "raid") then
			fail(scenario, "SKIPPED -- no group cast for the raid")
			return
		end
		H.pressAndSend(ns, group, BRILLIANCE)
		local row
		for _, e in ipairs(ns.db.char.ledger and ns.db.char.ledger.entries or {}) do
			if e.kind == "given" and e.covered then row = e end
		end
		if not row then
			fail(scenario, "SKIPPED -- the raid's cast left no row counting who it covered")
			return
		end
		ns.addon:HandleSlash("ledger")
		local r = ns.Ledger.Window().rows[1]
		if not (r and r.entry == row) then
			fail(scenario, "SKIPPED -- the group cast's row is not the top of the ledger")
			return
		end
		local tip = hover(r)
		if not tip:find(tostring(row.covered), 1, true) then
			fail(scenario, "SKIPPED -- the row does not count who the cast covered: " .. flat(tip))
		elseif tip:find("party or class", 1, true) then
			fail(scenario, "the row says a cast that reached the raid reached people in their party or class: "
				.. flat(tip))
		end
	end, raidMage)
end

-- ------------------------------------------------------------------ core22-8
-- A silent press that nothing answered, or that went to somebody else or as
-- another spell, refused nobody and said nothing. It held the line all the
-- same, so the press that landed once he was back in sight went out without
-- the thank-you, the tooltip quoting none.
local WEIRBEARD = "Weirbeard Jenkins"

local function speaks(text) return text ~= nil and text:find("\n/say ", 1, true) ~= nil end

for _, case in ipairs({
	{ "nothing answers it", function() end },
	{ "it went to somebody else", function(ns)
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Somebody Else", "Cast-1", 1459)
	end },
	{ "another spell went out", function(ns)
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-2", 133)
	end },
}) do
	local label, answer = case[1], case[2]
	local scenario = "core22: a silent press where " .. label .. " leaves the next press its line"
	local units = { nameplate1 = { "Weirbeard", "Jenkins" } }
	run(scenario, units, function(ns)
		H.freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, true, "SAY"
		speech.phrases = "Thanks, {name}."
		ns.db.profile.sources.self = false
		H.owe(ns, WEIRBEARD)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		if not speaks(ns.Prompt:GetButton():GetAttribute("macrotext1")) then
			fail(scenario, "SKIPPED -- the line was not armed to begin with")
			return
		end
		-- Out of the client's sight: no token names him, and the owed
		-- fallback keeps him on the panel.
		units.nameplate1 = nil
		ns.nameplateUnits.nameplate1 = nil
		Mock.advance(0.5)
		ns.addon:Tick()
		Mock.advance(1)
		local ran = H.pressButton(ns)
		if not (ran and ran:find("/target " .. WEIRBEARD, 1, true)) or speaks(ran) then
			fail(scenario, "SKIPPED -- the press out of sight was not a silent one at him: " .. flat(ran))
			return
		end
		answer(ns)
		Mock.advance(3)
		ns.addon:Tick()
		if ns.pendingClick then
			fail(scenario, "SKIPPED -- the press is still waiting for an answer")
			return
		end
		-- Back in sight a few seconds later, in reach and still owed.
		Mock.advance(4)
		units.nameplate1 = { "Weirbeard", "Jenkins" }
		ns.nameplateUnits.nameplate1 = true
		ns.addon:Tick()
		Mock.advance(0.5)
		ns.addon:Tick()
		local armed = ns.Prompt:GetButton():GetAttribute("macrotext1")
		local current = ns.Prompt.state.current
		if not (current and current.name == WEIRBEARD) then
			fail(scenario, "SKIPPED -- he is not on the prompt once back")
			return
		end
		if not speaks(armed) then
			fail(scenario, "back in reach, he is armed without the thank-you a silent press held: " .. flat(armed))
		end
		local quoted = table.concat(ns.Prompt:ClickSummary(current), " / ")
		if not quoted:find("Says:", 1, true) then
			fail(scenario, "the tooltip quotes no line for him: " .. quoted)
		end
		Mock.advance(1)
		ran = H.pressButton(ns)
		if not speaks(ran) then
			fail(scenario, "the press that lands once he is back says nothing: " .. flat(ran))
		end
	end)
end

-- ------------------------------------------------------------------ core22-9
-- Battle Shout reaches 20 yards on Forever. The scan's reach for a shout is
-- the follow prompt's 28 yards on purpose, for offering it; but the thank-you
-- went out with it, quoted and pressed, at somebody the shout never reached.
-- The line goes only where something says within 20: the trade prompt, or
-- LibRangeCheck.
for _, case in ipairs({
	{ yards = 25, says = false },
	{ yards = 5, says = true },
	{ yards = 15, says = false },
	{ yards = 15, lib = true, says = true },
	{ yards = 25, lib = true, says = false },
}) do
	local scenario = ("core22: a shout at %d yards %s the thank-you%s"):format(case.yards,
		case.says and "carries" or "leaves out", case.lib and " (LibRangeCheck)" or "")
	run(scenario, { party1 = { "Bob", "Stone" } }, function(ns)
		H.knowShout(ns)
		H.freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, true, "SAY"
		speech.phrases = "Thanks, {name}."
		ns.db.profile.sources.self = false
		local rangeless = {}
		for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do rangeless[id] = true end
		Mock.rangeless = rangeless
		Mock.yards = { party1 = case.yards }
		H.owe(ns, "Bob Stone")
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local entry = H.inQueue(ns)["Bob Stone"]
		local current = ns.Prompt.state.current
		if not (entry and entry.ranged == true and current and current.name == "Bob Stone") then
			fail(scenario, "SKIPPED -- Bob is not offered Battle Shout in reach")
			return
		end
		local armed = ns.Prompt:GetButton():GetAttribute("macrotext1")
		local quoted = table.concat(ns.Prompt:ClickSummary(current), " / ")
		Mock.advance(1)
		local ran = H.pressButton(ns)
		if not (ran and ran:find("/cast Battle Shout", 1, true)) then
			fail(scenario, "SKIPPED -- the press did not shout: " .. flat(ran))
			return
		end
		if speaks(armed) ~= case.says then
			fail(scenario, ("at %d yards the prompt is armed %s the thank-you: %s"):format(case.yards,
				case.says and "without" or "with", flat(armed)))
		end
		if (quoted:find("Says:", 1, true) ~= nil) ~= case.says then
			fail(scenario, ("at %d yards the tooltip %s the line: %s"):format(case.yards,
				case.says and "leaves out" or "quotes", quoted))
		end
		if speaks(ran) ~= case.says then
			fail(scenario, ("at %d yards the press %s the thank-you: %s"):format(case.yards,
				case.says and "leaves out" or "says", flat(ran)))
		end
	end, function()
		Mock.class = "WARRIOR"
		Mock.groupSize = 2
		if case.lib then Mock.rangeCheck = { buckets = { 30, 25, 20, 8 } } end
	end)
end
