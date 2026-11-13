-- Hunt 41, the leftovers of the earlier hunts, each held here by what a
-- player (or a saved file) would meet:
--
--   1. ClampSettings repaired the type of only some of the yes/no settings:
--      a hand-edited "false" in filters.relevantOnly, sources.owed,
--      prompt.locked ... stayed a string, and every read of it as a switch
--      said on.
--   2. The prompt's text re-measured and re-set its font on every repaint for
--      any line that had to shrink.
--   3. An untalented Blessing of Sanctuary rank was never read as weaker than
--      a stronger one.
--   4. A blessing left out for want of mana at this moment was not read for
--      coverage, so another blessing was offered over one the person wears.
--   5. The fallback dialog's "Panel style" help spoke of clicking a card, in a
--      dialog that draws a dropdown.
--   6. The capability probe on SPELLS_CHANGED left the open options window as
--      it was, a picker icon read as the question mark staying one.
--
-- Every scenario name starts with "hunt41-leftovers:" so the mutations in
-- tests/mutations/hunt41-leftovers.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

-- One driven session with body(ns) run, the mock reset after it whatever
-- happens.
local function session(scenario, body)
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local ok, err = pcall(body, ns)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ 1: yes/no

-- Every leaf of the given type among the defaults, at most two levels down
-- (section.key), as { section, key, default }; the top level has section nil.
local function leaves(ns, kind)
	local out = {}
	for key, value in pairs(ns.defaults.profile) do
		if type(value) == kind then out[#out + 1] = { nil, key, value } end
		if type(value) == "table" then
			for k, v in pairs(value) do
				if type(k) == "string" and type(v) == kind then out[#out + 1] = { key, k, v } end
			end
		end
	end
	table.sort(out, function(a, b) return (a[1] or "") .. "." .. a[2] < (b[1] or "") .. "." .. b[2] end)
	return out
end

local function holder(profile, leaf) return leaf[1] and profile[leaf[1]] or profile end
local function name(leaf) return (leaf[1] and leaf[1] .. "." or "") .. leaf[2] end

do
	local scenario = "hunt41-leftovers: every yes/no setting of the wrong type goes back to its default"
	session(scenario, function(ns)
		local p = ns.db.profile
		local wrong = { "false", 0, 1, {}, "true" }
		local list = leaves(ns, "boolean")
		if #list < 30 then fail(scenario, "SKIPPED -- only " .. #list .. " yes/no defaults found") return end
		local bad = {}
		for i, leaf in ipairs(list) do
			holder(p, leaf)[leaf[2]] = wrong[i % #wrong + 1]
		end
		ns.ClampSettings()
		for _, leaf in ipairs(list) do
			local v = holder(p, leaf)[leaf[2]]
			if v ~= leaf[3] then bad[#bad + 1] = ("%s read %s, default %s"):format(name(leaf), tostring(v), tostring(leaf[3])) end
		end
		if #bad > 0 then
			fail(scenario, #bad .. " of " .. #list .. " kept a wrong type: " .. table.concat(bad, "; ", 1, math.min(#bad, 6)))
		end
	end)
end

do
	local scenario = "hunt41-leftovers: the repair keeps a valid yes/no, either way, and repeats to the same"
	session(scenario, function(ns)
		local p = ns.db.profile
		local list = leaves(ns, "boolean")
		for _, leaf in ipairs(list) do holder(p, leaf)[leaf[2]] = not leaf[3] end
		ns.ClampSettings()
		local bad = {}
		for _, leaf in ipairs(list) do
			if holder(p, leaf)[leaf[2]] ~= not leaf[3] then bad[#bad + 1] = name(leaf) end
		end
		if #bad > 0 then fail(scenario, "a valid value was changed: " .. table.concat(bad, ", ", 1, math.min(#bad, 6))) end
		-- Idempotent: a second pass changes nothing and logs nothing.
		local before = #ns.repairLog
		local snapshot = {}
		for _, leaf in ipairs(list) do snapshot[name(leaf)] = holder(p, leaf)[leaf[2]] end
		ns.ClampSettings()
		for _, leaf in ipairs(list) do
			if holder(p, leaf)[leaf[2]] ~= snapshot[name(leaf)] then bad[#bad + 1] = name(leaf) end
		end
		if #bad > 0 then fail(scenario, "a second pass changed " .. table.concat(bad, ", ", 1, math.min(#bad, 6))) end
		if #ns.repairLog ~= before then fail(scenario, "a second pass logged repairs") end
	end)
end

do
	local scenario = "hunt41-leftovers: a string or number setting of the wrong type goes back to its default"
	session(scenario, function(ns)
		local p = ns.db.profile
		-- The position is one repair, whole (x and y put the anchor back
		-- with them); the rest is every string and number there is.
		local own = { ["prompt.x"] = true, ["prompt.y"] = true }
		local strings, numbers = leaves(ns, "string"), leaves(ns, "number")
		for _, leaf in ipairs(strings) do holder(p, leaf)[leaf[2]] = 12 end
		for _, leaf in ipairs(numbers) do if not own[name(leaf)] then holder(p, leaf)[leaf[2]] = "12" end end
		ns.ClampSettings()
		local bad = {}
		for _, list in ipairs({ strings, numbers }) do
			for _, leaf in ipairs(list) do
				local v = holder(p, leaf)[leaf[2]]
				if not own[name(leaf)] and type(v) ~= type(leaf[3]) then
					bad[#bad + 1] = ("%s is a %s"):format(name(leaf), type(v))
				end
			end
		end
		if #bad > 0 then fail(scenario, "kept a wrong type: " .. table.concat(bad, "; ", 1, math.min(#bad, 6))) end
		-- A valid value off the default is left alone.
		p.prompt.font = "Some Font"
		p.minimap.minimapPos = 77
		ns.ClampSettings()
		if p.prompt.font ~= "Some Font" or p.minimap.minimapPos ~= 77 then
			fail(scenario, "a valid string or number was changed")
		end
	end)
end

-- ------------------------------------------------------------------ 2: FitLine

do
	local scenario = "hunt41-leftovers: an unchanged line that had to shrink costs no font call on a repaint"
	session(scenario, function(ns)
		local lib = ns.Prompt.lib
		local fit = lib.fit
		local p = ns.db.profile.prompt
		p.width = 220
		ns.Prompt:ApplyStyle()
		local r = ns.Prompt:Regions()
		local fs = r.name
		local calls = { font = 0, width = 0 }
		local setFont, unbounded = fs.SetFont, fs.GetUnboundedStringWidth
		fs.SetFont = function(self, ...) calls.font = calls.font + 1 return setFont(self, ...) end
		fs.GetUnboundedStringWidth = function(self, ...) calls.width = calls.width + 1 return unbounded(self, ...) end
		local function size() return fs._font and fs._font.size end
		local function room() return fit.width - (fit.left or fit.textX) - (fit.right or lib.EDGE_ROOM) end
		local long = "A name far too long to fit the room it has been given on this tag"

		lib.SetLine(fs, long)
		local first = size()
		if not (first and first < p.fontSize) then
			fail(scenario, "SKIPPED -- the long line was not shrunk (size " .. tostring(first) .. ")")
			return
		end
		-- The same line painted again, as every 0.4 s tick does.
		calls.font, calls.width = 0, 0
		for _ = 1, 5 do lib.SetLine(fs, long) end
		if calls.font ~= 0 or calls.width ~= 0 then
			fail(scenario, ("five repaints of an unchanged shrunk line made %d font and %d width calls"):format(calls.font, calls.width))
		end
		if size() ~= first then fail(scenario, "a repaint changed the size from " .. first .. " to " .. tostring(size())) end

		-- A short line brings the size back to the base, and the long one
		-- shrinks to the same size as before.
		lib.SetLine(fs, "Anna")
		if size() ~= p.fontSize then fail(scenario, "a short line did not go back to the base size: " .. tostring(size())) end
		lib.SetLine(fs, long)
		if size() ~= first then fail(scenario, ("the long line came back at %s, not %s"):format(tostring(size()), first)) end

		-- Another room (the count chip up): the same text is fitted again.
		lib.ShowChip(true)
		lib.SetLine(fs, long)
		local w = fs:GetUnboundedStringWidth()
		local least = math.max(7, math.floor(p.fontSize * 0.8 + 0.5))
		if w > room() + 0.5 and size() > least then
			fail(scenario, ("with the chip up the line is %d wide in a room of %d, at size %s"):format(w, room(), tostring(size())))
		end
		lib.ShowChip(false)

		-- A line that shrinks only part of the way, so that every input of the
		-- answer can be seen to matter: another room, base size, face and
		-- outline each get the line fitted afresh.
		local floor = math.floor(p.fontSize * 0.8 + 0.5)
		local medium, partial = "", nil
		for n = 10, 60 do
			medium = ("x"):rep(n)
			lib.SetLine(fs, medium)
			partial = size()
			if partial < p.fontSize and partial > floor then break end
		end
		if not (partial and partial < p.fontSize and partial > math.floor(p.fontSize * 0.8 + 0.5)) then
			fail(scenario, "SKIPPED -- the medium line is at " .. tostring(partial) .. ", not part of the way")
		else
			fit.room[fs] = 400
			lib.SetLine(fs, medium)
			if size() ~= p.fontSize then fail(scenario, "with more room the line is at " .. tostring(size()) .. ", not its own size") end
			fit.room[fs] = nil
			lib.SetLine(fs, medium)
			if size() ~= partial then fail(scenario, "back in its room the line is at " .. tostring(size()) .. ", not " .. partial) end
			-- Fitted by a caller that does not know the text (a look's own
			-- room, say) and then painted again: the font follows the answer.
			fit.room[fs] = 400
			lib.FitLine(fs)
			fit.room[fs] = nil
			lib.SetLine(fs, medium)
			if size() ~= partial then fail(scenario, "after another fit the repaint left the line at " .. tostring(size()) .. ", not " .. partial) end
			-- The size and font set by hand under a remembered answer (a look
			-- does this for its own lines): the repaint puts them back.
			local face = fs._font and fs._font.path
			fs:SetFont(face, p.fontSize, fit.flags)
			fit.size[fs] = p.fontSize
			lib.SetLine(fs, medium)
			if size() ~= partial then fail(scenario, "after a size set by hand the repaint left the line at " .. tostring(size()) .. ", not " .. partial) end
			fit.base[fs] = p.fontSize - 4
			lib.SetLine(fs, medium)
			if size() > fit.base[fs] then fail(scenario, "a new base size left the line at " .. tostring(size())) end
			fit.base[fs] = p.fontSize
			lib.SetLine(fs, medium)
			fit.paths[fs] = "Fonts\MORPHEUS.TTF"
			lib.SetLine(fs, medium)
			if not (fs._font and fs._font.path == "Fonts\MORPHEUS.TTF") then
				fail(scenario, "a new face was not put on the line: " .. tostring(fs._font and fs._font.path))
			end
			fit.paths[fs] = nil
			lib.SetLine(fs, medium)
			local plainFlags = fit.flags
			fit.flags = "OUTLINE"
			lib.SetLine(fs, medium)
			if not (fs._font and fs._font.flags == "OUTLINE") then
				fail(scenario, "a new outline was not put on the line: " .. tostring(fs._font and fs._font.flags))
			end
			fit.flags = plainFlags
			lib.SetLine(fs, medium)
		end

		-- A new style (a bigger font) forgets what was learned.
		p.fontSize = p.fontSize + 4
		ns.Prompt:ApplyStyle()
		lib.SetLine(fs, long)
		if size() > p.fontSize or not size() or (size() < math.floor(p.fontSize * 0.8 + 0.5) and size() < 7) then
			fail(scenario, "after a bigger font the line is at " .. tostring(size()))
		end
		if size() == first then fail(scenario, "after a bigger font the line kept the old size " .. first) end
		local grown = size()
		calls.font = 0
		lib.SetLine(fs, long)
		if calls.font ~= 0 then fail(scenario, "the first repaint after a restyle was not free: " .. calls.font .. " font calls") end
		if size() ~= grown then fail(scenario, "a repaint after a restyle changed the size") end
	end)
end

-- ------------------------------------------------------------------ 3: Sanctuary

-- Blessing of Sanctuary is a talent, but its ranks have levels all the same
-- (SpellLevels: 30, 40, 50, 60 on Classic Era and Burning Crusade, a fifth at
-- 70 on Burning Crusade): the rank another paladin put on somebody is weaker
-- than the one your cast would land on them, and covers nothing.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitLevel" }

local function sanctuary(scenario, flavour, known, body)
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = "PALADIN"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local set = {}
		for _, id in ipairs(known) do set[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return set[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return set[id] == true end)
		local undo = H.strangers({ nameplate1 = { "Petra" } })
		local ns = load(scenario)
		if ns then
			if ns.Flavour.flavour ~= flavour then
				fail(scenario, "SKIPPED -- the mock is " .. tostring(ns.Flavour.flavour))
			else
				drive(scenario, ns)
				ns.Guard("probe", ns.ProbeCapabilities)
				ns.Prompt:ExitTest()
				body(ns)
			end
		end
		if undo then undo() end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.held = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

for _, case in ipairs({
	-- flavour, what the paladin knows, then { rank worn, their level, covered? }
	{ "vanilla", { 20914, 20913, 20912, 20911 }, {
		{ 20911, 60, false }, { 20911, 40, false }, { 20912, 50, false },
		{ 20913, 60, false }, { 20914, 60, true }, { 20911, 39, false }, { 20911, 29, true },
	} },
	{ "tbc", { 27168, 20914, 20913, 20912, 20911 }, {
		{ 20914, 70, false }, { 20914, 60, false }, { 20914, 59, true }, { 20911, 59, false },
		{ 27168, 70, true },
	} },
}) do
	local flavour, known, rows = case[1], case[2], case[3]
	local scenario = ("hunt41-leftovers: %s: a weak worn Sanctuary rank is not the one your cast would land"):format(flavour)
	sanctuary(scenario, flavour, known, function(ns)
		local buff = ns.FindBuff("PALADIN", "sanctuary")
		if not buff then fail(scenario, "SKIPPED -- no Sanctuary on " .. flavour) return end
		for _, row in ipairs(rows) do
			local worn, level, covered = row[1], row[2], row[3]
			rawset(_G, "UnitLevel", function(unit) return unit == "player" and 70 or level end)
			Mock.held = { [worn] = true }
			ns.ForgetUnitAuras(UnitGUID("nameplate1"))
			local has = ns.UnitHasBuff("nameplate1", buff, nil)
			if has ~= covered then
				fail(scenario, ("a level-%d wearing rank %d reads has = %s, expected %s"):format(
					level, worn, tostring(has), tostring(covered)))
			end
		end
	end)
end

-- ------------------------------------------------------------------ 4: Kings unpaid

-- A blessing the game says you cannot pay for right now (Queue.lua,
-- Affordable) leaves the list the walk is handed, and the walk read only that:
-- a paladin short of mana for Kings was offered Might for the very person
-- wearing his Kings, which a press puts over it. Read for coverage as a
-- blessing switched off is, never offered.
do
	local PARTY = { party1 = { "Gwen", "Hale" } }
	for _, client in ipairs({ "camelot", "vanilla" }) do
		for _, case in ipairs({
			{ source = "player", expect = "nothing", text = "his Kings on somebody, out of mana for it, is left alone" },
			{ source = "nameplate2", expect = "other", text = "another paladin's Kings is no reason to leave them" },
			{ source = false, expect = "other", text = "nobody wearing it is offered what he can pay for" },
			{ source = "player", expect = "might", ask = "might pls",
				text = "somebody who asks for Might by name is offered it over his Kings" },
			{ source = "player", expect = "might", pin = "might",
				text = "a pin on Might is offered over his Kings, which a pin replaces as ever" },
		}) do
			local scenario = "hunt41-leftovers: " .. client .. ": " .. case.text
			Mock.reset()
			Mock.setFlavour(client)
			Mock.class = "PALADIN"
			Mock.groupSize = 3
			local restore = H.strangers(PARTY)
			local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_UnitAuras", "UnitClass",
				"UnitPowerMax", "C_Spell", "IsUsableSpell" }
			local saved = {}
			for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
			local known, kingsIds, worn = {}, {}, {}
			local function isKnown(id) return known[id] == true end
			rawset(_G, "IsSpellKnown", isKnown)
			rawset(_G, "IsPlayerSpell", isKnown)
			rawset(_G, "UnitInParty", function(unit) return type(unit) == "string" and unit:find("^party%d") ~= nil end)
			rawset(_G, "UnitClass", function(unit)
				if unit == "party1" then return "WARRIOR", "WARRIOR" end
				return saved.UnitClass(unit)
			end)
			rawset(_G, "UnitPowerMax", function(unit, power)
				if unit == "party1" then return 0 end
				return saved.UnitPowerMax(unit, power)
			end)
			-- No mana for Kings alone.
			local function usable(id)
				if kingsIds[id] then return false, true end
				return true, false
			end
			local base = saved.C_Spell
			rawset(_G, "C_Spell", setmetatable({ IsSpellUsable = usable }, { __index = base }))
			rawset(_G, "IsUsableSpell", usable)
			local baseAuras = C_UnitAuras
			rawset(_G, "C_UnitAuras", setmetatable({
				GetUnitAuraBySpellID = function(unit, spellId)
					if unit ~= "party1" then return baseAuras.GetUnitAuraBySpellID(unit, spellId) end
					if not worn[spellId] then return nil end
					return { spellId = spellId, expirationTime = Mock.now + 3000, duration = 3600,
						sourceUnit = worn[spellId] }
				end,
			}, { __index = baseAuras }))
			local ok, err = pcall(function()
				local ns = load(scenario)
				if not ns then return end
				for _, key in ipairs({ "wisdom", "might", "kings", "salvation", "light" }) do
					local buff = ns.FindBuff("PALADIN", key)
					for _, id in ipairs(buff and buff.ranks or {}) do
						known[id] = true
						if key == "kings" then kingsIds[id] = true end
					end
				end
				H.freshPrompt(ns, scenario)
				ns.db.profile.sources.self = false
				ns.db.profile.sources.strangers = false
				ns.Guard("probe", ns.ProbeCapabilities)
				if case.source then worn[ns.FindBuff("PALADIN", "kings").ranks[1]] = case.source end
				if case.ask then
					ns.db.profile.sources.asked = true
					ns.NoteRequest("WHISPER", case.ask, client == "camelot" and "Gwen Hale" or "Gwen")
				end
				if case.pin then ns.db.profile.buff.choice = case.pin end
				Mock.advance(4)
				local got
				for _, entry in ipairs(ns.BuildQueue()) do
					if entry.unit == "party1" then got = entry.buff and entry.buff.key or false end
				end
				if case.expect == "nothing" and got then
					fail(scenario, "the warrior wearing his Kings is offered " .. tostring(got))
				elseif case.expect == "might" and got ~= "might" then
					fail(scenario, "the warrior is offered " .. tostring(got) .. ", not Might")
				elseif case.expect == "other" and (not got or got == "kings") then
					fail(scenario, "the warrior is offered " .. tostring(got) .. ", not a blessing he can pay for")
				end
			end)
			for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
			restore()
			Mock.reset()
			if not ok then fail(scenario, "threw: " .. tostring(err)) end
		end
	end
end

-- The same on yourself: Kings of yours on you, no mana for Kings, and Might
-- not put over it.
for _, client in ipairs({ "camelot", "vanilla" }) do
	local scenario = "hunt41-leftovers: " .. client .. ": your own Kings on you, out of mana for it, is left alone"
	Mock.reset()
	Mock.setFlavour(client)
	Mock.class = "PALADIN"
	local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_UnitAuras", "C_Spell", "IsUsableSpell" }
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local known, kingsIds, worn = {}, {}, {}
	local function isKnown(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", isKnown)
	rawset(_G, "IsPlayerSpell", isKnown)
	local function usable(id)
		if kingsIds[id] then return false, true end
		return true, false
	end
	rawset(_G, "C_Spell", setmetatable({ IsSpellUsable = usable }, { __index = saved.C_Spell }))
	rawset(_G, "IsUsableSpell", usable)
	local baseAuras = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			if unit ~= "player" then return baseAuras.GetUnitAuraBySpellID(unit, spellId) end
			if not worn[spellId] then return nil end
			return { spellId = spellId, expirationTime = Mock.now + 3000, duration = 3600, sourceUnit = "player" }
		end,
	}, { __index = baseAuras }))
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		for _, key in ipairs({ "wisdom", "might", "kings", "salvation", "light" }) do
			local buff = ns.FindBuff("PALADIN", key)
			for _, id in ipairs(buff and buff.ranks or {}) do
				known[id] = true
				if key == "kings" then kingsIds[id] = true end
			end
		end
		H.freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		ns.db.profile.sources.group = false
		ns.Guard("probe", ns.ProbeCapabilities)
		Mock.advance(4)
		local function mine()
			for _, entry in ipairs(ns.BuildQueue()) do
				if entry.reason == "self" then return entry.buff and entry.buff.key end
			end
		end
		local bare = mine()
		if not bare or bare == "kings" then
			fail(scenario, "SKIPPED -- on yourself with nothing worn the offer is " .. tostring(bare))
			return
		end
		worn[ns.FindBuff("PALADIN", "kings").ranks[1]] = true
		ns.ForgetUnitAuras(UnitGUID("player"))
		Mock.advance(4)
		local got = mine()
		if got then fail(scenario, "wearing your own Kings, you are offered " .. tostring(got)) end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 5: Panel style's words

-- The model's description of Panel style is read by the fallback dialog,
-- which draws a dropdown (the custom window draws a gallery of cards and
-- never shows it, only searches it), so it must not tell the player to click
-- a card.
do
	local scenario = "hunt41-leftovers: Panel style's description fits the dropdown the fallback dialog draws"
	session(scenario, function(ns)
		local option = H.findOption(ns.optionsTable, "style")
		if not option then fail(scenario, "SKIPPED -- no style option in the model") return end
		if option.type ~= "select" then fail(scenario, "Panel style is a " .. tostring(option.type)) return end
		local desc = tostring(option.desc or "")
		if desc == "" then fail(scenario, "Panel style has no description a search for theme could find") return end
		if desc:lower():find("card", 1, true) or desc:lower():find("click", 1, true) then
			fail(scenario, "the dropdown's help speaks of clicking a card: " .. desc)
		end
		if not desc:lower():find("theme", 1, true) then
			fail(scenario, "the description no longer says theme, so a search for it misses the picker: " .. desc)
		end
	end)
end

-- ------------------------------------------------------------------ 6: SPELLS_CHANGED repaints

-- Not a fault, held here all the same: the picker's cards wear the icon of the
-- first buff you can cast, and one the client had not loaded reads as the
-- question mark. The open window is repainted by the probe itself (Window.lua
-- hooks ns.ProbeCapabilities), so SPELLS_CHANGED, directly or through the
-- delayed probe that follows a burst of them, puts the icon on the cards
-- without waiting for another reason to paint.
do
	dofile(dir .. "/tests/frametree.lua")
	local FT = FrameTree
	local QUESTION_MARK, LOADED = 134400, 700000 + 1459
	local function scene(scenario, body)
		Mock.reset()
		local saved = rawget(_G, "C_Spell")
		local env = { noTexture = true }
		local ok, err = pcall(function()
			rawset(_G, "C_Spell", setmetatable({
				GetSpellTexture = function(id)
					if env.noTexture then return nil end
					return 700000 + id
				end,
			}, { __index = saved }))
			FT.install()
			local ns = load(scenario)
			if not ns then return end
			drive(scenario, ns)
			ns.Prompt:ExitTest()
			ns.OpenOptions("appearance", true)
			ns.Prompt:ExitTest()
			local UI = ns.WindowUI
			local row = UI.RowFor("appearance.style")
			if not (row and row.cards and UI.RowShown("appearance.style")) then
				fail(scenario, "SKIPPED -- the gallery is not on the Look page")
				return
			end
			body(ns, row, env)
		end)
		FT.uninstall()
		rawset(_G, "C_Spell", saved)
		Mock.reset()
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	local function icons(row)
		local out = {}
		for i = 1, #row.cards do
			if row.cards[i]:IsShown() then out[#out + 1] = row.cards[i].iconFile end
		end
		return out
	end
	local function allWear(row, want)
		local list = icons(row)
		if #list == 0 then return false, "no card is shown" end
		for _, file in ipairs(list) do
			if file ~= want then return false, tostring(file) end
		end
		return true
	end

	local scenario = "hunt41-leftovers: a spellbook change puts the loaded icon on the open picker's cards"
	scene(scenario, function(ns, row, env)
		local began, what = allWear(row, QUESTION_MARK)
		if not began then fail(scenario, "SKIPPED -- the cards began on " .. what) return end
		-- The icon loads; the client says the spellbook changed.
		env.noTexture = false
		Mock.advance(30)
		ns.addon:SPELLS_CHANGED()
		local ok, got = allWear(row, LOADED)
		if not ok then fail(scenario, "after SPELLS_CHANGED a card shows " .. got .. ", not " .. LOADED) end

		-- And through the probe that waited out the rate limit.
		env.noTexture = true
		Mock.advance(30)
		ns.addon:SPELLS_CHANGED()
		env.noTexture = false
		Mock.advance(1)
		ns.addon:SPELLS_CHANGED()
		Mock.runTimers(10)
		ok, got = allWear(row, LOADED)
		if not ok then fail(scenario, "after the delayed probe a card shows " .. got .. ", not " .. LOADED) end
	end)
end

-- ------------------------------------------------------------------ 7: a restyle with the count up

-- A plain ApplyStyle (a setting changed, the display changed) while the count
-- chip is up and the person on the prompt is the same: the repaint after it
-- must bring the count back with the chip, for every look.
do
	dofile(dir .. "/tests/frametree.lua")
	local FT = FrameTree
	local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" },
		nameplate3 = { "Cara", "Close" } }
	Mock.reset()
	local probe = load("hunt41-leftovers: a restyle with the count chip up (the looks)")
	local styles = { "glass", "framed", "minimal" }
	if probe then
		for key in pairs(probe.Looks.list) do styles[#styles + 1] = key end
		table.sort(styles)
	end
	Mock.reset()
	local function state(r)
		return ("count %q %s, chip %s"):format(tostring(r.count:GetText()), r.count:IsShown() and "shown" or "hidden",
			r.chip:IsShown() and "shown" or "hidden")
	end
	for _, style in ipairs(styles) do
		local scenario = "hunt41-leftovers: " .. style .. ": a restyle with the count chip up brings the count back"
		Mock.reset()
		Mock.geometry = { width = 1920, height = 1080 }
		FT.install()
		local restore = H.strangers(PEOPLE)
		local ok, err = pcall(function()
			local ns = load(scenario)
			if not ns then return end
			H.freshPrompt(ns, scenario)
			local pp = ns.db.profile.prompt
			pp.style = style
			pp.showCount = true
			pp.showQueue, pp.queueRows, pp.clickRows, pp.locked = true, 3, true, true
			H.owe(ns, "Anna Aim")
			ns.Prompt:ApplyStyle()
			ns.addon:Tick()
			ns.Prompt:Refresh()
			local r = ns.Prompt:Regions()
			local was = state(r)
			if (r.count:GetText() or "") == "" then
				fail(scenario, "SKIPPED -- no count on the prompt with three people about")
				return
			end
			-- The same people, the same person on top: only the style is applied.
			ns.Prompt:ApplyStyle()
			local now = state(r)
			if now ~= was then fail(scenario, ("after a restyle the prompt reads %s, not %s"):format(now, was)) end
		end)
		restore()
		FT.uninstall()
		Mock.reset()
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
end
