-- Hunt 3 of the day's work, the hall of fame and Detect Invisibility for
-- passers-by (Options/Who.lua, Queue.lua, Hall.lua):
--
--  1. the "to passers-by too" switch stays in reach while Detect Invisibility
--     is the pinned buff, whatever its own tick says (a pin offers it anyway);
--  2. somebody remembered with Detect Invisibility is let go once the switch
--     is unticked, as a token on them would be refused;
--  3. a namesake of another class is not the listed character;
--  4. a listed player past the list's cut still finds their own row;
--  5. every milestone earned and no code to give: the section says so rather
--     than point at a box that is not there, and chat says nothing of a code.
--
-- Every scenario name starts with "hunt3-hall-detect:" so the mutations in
-- tests/mutations/hunt3-hall-detect.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local function text(control, field)
	local v = control and control[field]
	if type(v) == "function" then v = v() end
	return tostring(v or "")
end

local function hidden(control)
	local v = control and control.hidden
	if type(v) == "function" then v = v() end
	return v == true
end

---------------------------------------------------------------------------
-- Detect Invisibility
---------------------------------------------------------------------------

local RANKS = { 11743, 2970, 132 }
local PARTY = { party1 = { "Gwen", "Hale" }, party2 = { "Bram", "Oake" } }
local STRANGER = { "Anna", "Aim" }
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "UnitInRaid" }

local function filed(pair)
	return Mock.surnames and (pair[1] .. " " .. pair[2]) or pair[1]
end

-- A warlock on Forever knowing every rank of Detect Invisibility, two party
-- members and a passer-by on a nameplate, nobody wearing anything. `names` is
-- the tokens, handed to the body so it can take one away.
local function warlock(scenario, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "WARLOCK"
	Mock.groupSize = 3
	local names = { nameplate1 = STRANGER }
	for token, pair in pairs(PARTY) do names[token] = pair end
	local restore = H.strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local known = {}
		for _, id in ipairs(RANKS) do known[id] = true end
		rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		H.freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.strangers = true
		db.sources.group = true
		db.sources.asked = true
		db.sources.self = false
		Mock.held = {}
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns, names)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- What the queue offers each name, by buff key, `seconds` of clock later.
local function offers(ns, seconds)
	Mock.advance(seconds or 4)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		out[entry.name] = entry.buff and entry.buff.key
	end
	return out
end

-- ------------------------------------------------------------------ 1
do
	local scenario = "hunt3-hall-detect: pinned and never ticked, Detect Invisibility's passers-by switch is in reach"
	warlock(scenario, function(ns)
		local control = H.findOption(ns.optionsTable, "passers_detectgroup")
		if not (control and control.hidden and control.set) then
			fail(scenario, "SKIPPED -- no switch for passers-by on Who to buff")
			return
		end
		local b = ns.db.profile.buff
		if b.optIn.detectgroup or not control.hidden() then
			fail(scenario, "SKIPPED -- on a new profile the buff is ticked or the switch shows")
			return
		end
		b.choice = "detectgroup"
		if not (ns.PinnedBuff() and ns.PinnedBuff().key == "detectgroup") then
			fail(scenario, "SKIPPED -- Detect Invisibility is not the pin")
			return
		end
		if offers(ns)[filed(PARTY.party1)] ~= "detectgroup" then
			fail(scenario, "SKIPPED -- pinned, a party member is not offered it")
			return
		end
		if control.hidden() ~= false then
			fail(scenario, "pinned and offered, the switch that sends it to passers-by is hidden")
		end
		-- And it works from there.
		control.set(nil, true)
		if offers(ns)[filed(STRANGER)] ~= "detectgroup" then
			fail(scenario, "pinned and the switch ticked, a passer-by is not offered it")
		end
		control.set(nil, false)
		-- A pin of another buff hides it, as before.
		b.choice = "breath"
		if not (ns.PinnedBuff() and ns.PinnedBuff().key == "breath") then
			fail(scenario, "SKIPPED -- Unending Breath is not a pin to try")
		elseif control.hidden() ~= true then
			fail(scenario, "the switch shows under a pin of another buff")
		end
		-- And Automatic still asks the buff's own tick.
		b.choice = "auto"
		if control.hidden() ~= true then fail(scenario, "in Automatic the switch shows with the buff unticked") end
	end)
end

-- ------------------------------------------------------------------ 2
do
	local scenario = "hunt3-hall-detect: the switch unticked, somebody remembered with Detect Invisibility is let go"
	warlock(scenario, function(ns, names)
		local b = ns.db.profile.buff
		b.optIn.detectgroup = true
		b.detectPassers = true
		local anna = filed(STRANGER)
		ns.addon.CHAT_MSG_SAY(ns.addon, "CHAT_MSG_SAY", "detect invis pls", anna, "Common", "", "", "",
			0, 0, "", 0, 2, "Player-1-nameplate1")
		if offers(ns, 2)[anna] ~= "detectgroup" then
			fail(scenario, "SKIPPED -- a passer-by who asked is not offered it with the switch ticked")
			return
		end
		-- Her nameplate goes: she is offered from memory.
		names.nameplate1 = nil
		ns.addon:NAME_PLATE_UNIT_REMOVED("NAME_PLATE_UNIT_REMOVED", "nameplate1")
		if offers(ns, 2)[anna] ~= "detectgroup" then
			fail(scenario, "SKIPPED -- with no token on her she is not offered from memory")
			return
		end
		local control = H.findOption(ns.optionsTable, "passers_detectgroup")
		control.set(nil, false)
		local out = offers(ns, 2)
		if out[anna] then
			fail(scenario, "the switch unticked, she is still offered " .. tostring(out[anna]) .. " from memory")
		end
		if out[filed(PARTY.party1)] ~= "detectgroup" then
			fail(scenario, "the switch unticked, a party member lost it too")
		end
		-- Ticked again within the ten seconds, memory does not bring her back.
		control.set(nil, true)
		if offers(ns, 1)[anna] then
			fail(scenario, "let go, she came back from memory with the switch ticked again")
		end
	end)
end

---------------------------------------------------------------------------
-- the hall of fame
---------------------------------------------------------------------------

-- 2026-11-14 12:00 UTC.
local NOON = 1794657600

local function calendar()
	local real = date
	date = function(fmt, t) return os.date("!" .. fmt, t) end
	return function() date = real end
end

-- A mage on Forever with a clean ledger and no milestone yet.
local function hall(scenario, body)
	Mock.reset()
	local restore = calendar()
	local ns, list, fullName
	local ok, err = pcall(function()
		ns = load(scenario)
		if not ns then return end
		list, fullName = ns.HALL_OF_FAME, ns.UnitFullName
		ns.HALL_OF_FAME = {}
		H.freshPrompt(ns, scenario)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.db.char.ledger = nil
		ns.db.char.milestones = nil
		ns.Ledger.Load()
		Mock.printed = {}
		body(ns, ns.Hall)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if ns then ns.HALL_OF_FAME, ns.UnitFullName = list, fullName end
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function earnAll(ns, last, but)
	local rows = ns.Milestones.Rows()
	local st = ns.db.char.milestones
	for i, row in ipairs(rows) do
		if row.id ~= but then st.earned[row.id] = last - (#rows - i) * 60 end
	end
	return #rows
end

local function printed(line)
	local n = 0
	for _, said in ipairs(Mock.printed or {}) do
		if tostring(said):find(line, 1, true) then n = n + 1 end
	end
	return n
end

local function mark(Hall)
	return Hall.TEXT.YOU:match("%%s%s*(.+)$")
end

-- ------------------------------------------------------------------ 3
do
	local scenario = "hunt3-hall-detect: a namesake of another class is not the listed character"
	hall(scenario, function(ns, Hall)
		local me = ns.UnitFullName("player")
		if type(me) ~= "string" or ns.caps.class ~= "MAGE" then
			fail(scenario, "SKIPPED -- the session is not a named mage")
			return
		end
		local note = H.findOption(ns.optionsTable, "hallNote")
		local list = H.findOption(ns.optionsTable, "hallList")
		local of = earnAll(ns, NOON, "courtesy")
		-- The same name on the same client, listed as a warlock: a character
		-- made again under the name, or a namesake elsewhere.
		ns.HALL_OF_FAME = { { name = me, client = "camelot", class = "WARLOCK", date = "2026-11-01" } }
		if Hall.Listed() then fail(scenario, "a mage is taken for the warlock of the same name on the list") end
		if text(note, "name") ~= Hall.TEXT.PROGRESS:format(of - 1, of) then
			fail(scenario, "the namesake is not told how far along it is: " .. text(note, "name"))
		end
		if text(list, "name"):find(mark(Hall), 1, true) then
			fail(scenario, "the warlock's row is marked as the mage's own")
		end
		ns.Milestones.Note("courtesy")
		if printed(Hall.TEXT.OPEN) ~= 1 then
			fail(scenario, "the namesake's last milestone said the hall is open " .. printed(Hall.TEXT.OPEN) .. " times")
		end
		-- The mage's own row, and a row that says no class, still are.
		ns.HALL_OF_FAME = { { name = me, client = "camelot", class = "MAGE", date = "2026-11-01" } }
		if not Hall.Listed() then fail(scenario, "the mage's own row is no longer the mage") end
		ns.HALL_OF_FAME = { { name = me, client = "camelot", date = "2026-11-01" } }
		if not Hall.Listed() then fail(scenario, "a row with no class no longer matches by name") end
	end)
end

-- ------------------------------------------------------------------ 4
do
	local scenario = "hunt3-hall-detect: a listed player past the list's cut still finds their own row"
	hall(scenario, function(ns, Hall)
		local me = ns.UnitFullName("player")
		local many = {}
		for i = 1, Hall.MAX_ROWS + 4 do
			many[i] = { name = "Guest " .. i, client = "camelot", class = "PRIEST", date = "2026-11-10" }
		end
		-- The earliest entrant of all: last of the list, newest first.
		many[#many + 1] = { name = me, client = "camelot", class = "MAGE", date = "2026-01-02" }
		ns.HALL_OF_FAME = many
		if not Hall.Listed() then
			fail(scenario, "SKIPPED -- the player is not read as listed")
			return
		end
		local shown = text(H.findOption(ns.optionsTable, "hallList"), "name")
		local lines = {}
		for line in (shown .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
		local mine
		for i, line in ipairs(lines) do
			if line:find(mark(Hall), 1, true) then mine = i end
		end
		if not mine then
			fail(scenario, "told they are listed, the player's own row is nowhere in the list")
		elseif not lines[mine]:find(me, 1, true) or mine ~= Hall.MAX_ROWS + 2 then
			fail(scenario, "the player's own row is not the one line after the cut: line " .. mine)
		end
		if #lines ~= Hall.MAX_ROWS + 3 or lines[#lines] ~= Hall.TEXT.MORE:format(4) then
			fail(scenario, "the names left out are not counted as 4: " .. tostring(lines[#lines]))
		end
		if shown:find("Guest " .. (Hall.MAX_ROWS + 1), 1, true) then
			fail(scenario, "somebody else past the cut is drawn")
		end
		-- One past the cut and it is the player's: the whole list, nothing to count.
		local few = {}
		for i = 1, Hall.MAX_ROWS do few[i] = many[i] end
		few[#few + 1] = many[#many]
		ns.HALL_OF_FAME = few
		shown = text(H.findOption(ns.optionsTable, "hallList"), "name")
		if shown:find(Hall.TEXT.MORE:format(0), 1, true) or shown:find(Hall.TEXT.MORE:format(1), 1, true) then
			fail(scenario, "with everybody drawn the list still counts some more")
		end
	end)
end

-- ------------------------------------------------------------------ 5
do
	local scenario = "hunt3-hall-detect: every milestone and no code to give, the section says so and chat says nothing"
	hall(scenario, function(ns, Hall)
		local note = H.findOption(ns.optionsTable, "hallNote")
		local box = H.findOption(ns.optionsTable, "hallCode")
		earnAll(ns, NOON, "courtesy")
		-- A name and surname of twelve accented letters each: 49 bytes, one
		-- more than a code carries.
		local real = ns.UnitFullName
		local long = ("\195\169"):rep(12) .. " " .. ("\195\168"):rep(12)
		ns.UnitFullName = function(unit, ...)
			if unit == "player" then return long end
			return real(unit, ...)
		end
		ns.Milestones.Note("courtesy")
		local _, _, done = Hall.Progress()
		if not done then
			fail(scenario, "SKIPPED -- the last milestone did not land")
			return
		end
		if Hall.Code() ~= nil or not hidden(box) then
			fail(scenario, "SKIPPED -- a name of 49 bytes has a code or a box")
			return
		end
		if text(note, "name") == Hall.TEXT.INVITE then
			fail(scenario, "the section says to copy the code below, and there is no code")
		elseif text(note, "name") ~= Hall.TEXT.NOCODE then
			fail(scenario, "the section does not say there is no code: " .. text(note, "name"))
		end
		if Hall.TEXT.NOCODE:find("code below", 1, true) or not Hall.TEXT.NOCODE:find("github.com/fpsacha/Manners", 1, true) then
			fail(scenario, "the line for no code points at a box or names no page")
		end
		if printed(Hall.TEXT.OPEN) ~= 0 then
			fail(scenario, "chat says the code is on Start here, and there is none")
		end
		-- With a name a code carries, the invitation and the box as ever.
		ns.UnitFullName = real
		if text(note, "name") ~= Hall.TEXT.INVITE or hidden(box) or Hall.Code() == nil then
			fail(scenario, "with a name a code carries the section no longer invites")
		end
	end)
end
