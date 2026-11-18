-- A mage's Mana Shield, Fire Ward and Frost Ward as own buffs, and Add a spell
-- of my own (asked for on CurseForge): a buff Manners does not know, typed on
-- Who to buff under Myself, reminded on yourself like any own buff
-- (OwnSpells.lua).
--
-- Every scenario name starts with "ownspell:" so the mutations in
-- tests/mutations/ownspell.py can name the one that has to catch them.

local dir, H = ...
local fail, load, strangers, freshPrompt, findOption = H.fail, H.load, H.strangers, H.freshPrompt, H.findOption

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end
local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end

local function mine(ns, want)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" and (not want or key(entry) == want) then return entry end
	end
	return nil
end

local function said() return table.concat(Mock.printed or {}, "\n") end
local function has(text, part) return tostring(text):find(part, 1, true) ~= nil end

local TOUCHED = { "C_UnitAuras", "C_Spell", "IsSpellKnown", "IsPlayerSpell", "IsResting" }
local world

local FEAR = 6346
local PRIEST_NAMES = { [6346] = "Fear Ward" }

-- A character of `opts.class` (a priest) on `opts.flavour` (Forever) who knows
-- opts.known (spell ids), with the spell names the client answers for in
-- opts.names (id -> name; opts.byName says which id a name resolves to when two
-- share one), the spells opts.harmful, opts.passive and opts.helpful name, and
-- the auras world.auras (id -> source unit).
local function with(scenario, opts, body)
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	Mock.class = opts.class or "PRIEST"
	world = { names = opts.names or {}, byName = opts.byName or {}, known = {}, auras = {},
		harmful = opts.harmful or {}, passive = opts.passive or {}, helpful = opts.helpful or {},
		refuse = {}, resting = false }
	for _, id in ipairs(opts.known or {}) do world.known[id] = true end
	for id, name in pairs(world.names) do
		if world.byName[name] == nil then world.byName[name] = id end
	end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local function knows(id) return world.known[id] == true end
		rawset(_G, "IsSpellKnown", knows)
		rawset(_G, "IsPlayerSpell", knows)
		rawset(_G, "IsResting", function() return world.resting end)
		local baseSpell = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) return world.names[id] or baseSpell.GetSpellName(id) end,
			GetSpellIDForSpellIdentifier = function(t) return tonumber(t) or world.byName[t] end,
			GetSpellInfo = function(t)
				local id = tonumber(t) or world.byName[t]
				if not id then return nil end
				return { name = world.names[id] or baseSpell.GetSpellName(id), spellID = id, iconID = 135932 }
			end,
			IsSpellHarmful = function(id) return world.harmful[id] == true end,
			IsSpellPassive = function(id) return world.passive[id] == true end,
			IsSpellHelpful = function(id) return world.helpful[id] == true end,
		}, { __index = baseSpell }))
		local baseAuras = C_UnitAuras
		local function aura(id)
			return { spellId = id, name = world.names[id] or ("Aura " .. id), sourceUnit = world.auras[id],
				expirationTime = Mock.now + 600, duration = 600 }
		end
		rawset(_G, "C_UnitAuras", setmetatable({
			GetUnitAuraBySpellID = function(unit, id)
				if unit ~= "player" then return nil end
				if world.refuse[id] == "secret" then return Mock.SECRET end
				if world.auras[id] == nil then return nil end
				return aura(id)
			end,
			GetAuraDataBySpellName = function(unit, name, filter)
				if unit ~= "player" then return nil end
				for id, source in pairs(world.auras) do
					if world.names[id] == name and (not filter or not filter:find("PLAYER", 1, true) or source == "player") then
						if world.refuse[id] == "secret" then return Mock.SECRET end
						return aura(id)
					end
				end
				return nil
			end,
		}, { __index = baseAuras }))
		freshPrompt(ns, scenario)
		ns.db.profile.sources.self = true
		if opts.list then ns.db.char.ownSpells = opts.list end
		ns.Guard("probe", ns.ProbeCapabilities)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function add(ns, text)
	findOption(ns.optionsTable, "ownSpellAdd").set({ "ownSpellAdd" }, text)
	return ns.OwnSpells.Said()
end

local function cast(ns, id, target)
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", target, "Cast-own-" .. id, id)
	ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-own-" .. id, id)
	Mock.runTimers(2)
end

local function me(ns) return ns.plain(UnitName("player")) end
local function list(ns) return ns.db.char.ownSpells or {} end

local VANILLA = { 10193, 10192, 10191, 8495, 8494, 1463, 10225, 10223, 8458, 8457, 543, 28609, 10177, 8462, 8461, 6143 }

-- ------------------------------------------------------------------ the shields

do
	local scenario = "ownspell: shields: Mana Shield and a ward for a mage on Forever, Classic Era and Burning Crusade, none on Mists or retail"
	local want = { camelot = { 6, 5, 5 }, vanilla = { 6, 5, 5 }, tbc = { 7, 6, 6 }, mists = false, mainline = false }
	for client, counts in pairs(want) do
		Mock.reset()
		Mock.setFlavour(client)
		local ns = load(scenario)
		if ns then
			local shield, ward, base
			for class, families in pairs(ns.OWN_BUFFS or {}) do
				for index, family in ipairs(families) do
					if family.key == "manashield" or family.key == "ward" then
						if class ~= "MAGE" then fail(scenario, client .. ": " .. class .. " has " .. family.key) end
						if family.key == "manashield" then shield = family else ward = family end
					end
					if family.key == "magicmod" then base = index end
				end
			end
			if not counts then
				if shield or ward then fail(scenario, client .. " has the family, and no such spell") end
			elseif not (shield and ward) then
				fail(scenario, client .. " lacks Mana Shield or the wards for a mage")
			else
				local f, r = ward.spells[1], ward.spells[2]
				if not (shield.spells[1].key == "manashield" and f and f.key == "fireward" and r and r.key == "frostward") then
					fail(scenario, client .. ": the families' spells are not Mana Shield, Fire Ward, Frost Ward")
				elseif #shield.spells[1].ranks ~= counts[1] or #f.ranks ~= counts[2] or #r.ranks ~= counts[3] then
					fail(scenario, client .. ": the rank counts are not " .. table.concat(counts, ", "))
				end
				if client == "tbc" and not (shield.spells[1].ranks[1] == 27131 and f.ranks[1] == 27128 and r.ranks[1] == 32796) then
					fail(scenario, "Burning Crusade's top ranks are missing")
				end
				if not (shield.optIn and shield.brief and ward.optIn and ward.brief) then
					fail(scenario, client .. ": not off until switched on, or not marked brief")
				end
				if ns.SPELL_SECONDS[shield.spells[1].ranks[1]] ~= 60 or ns.SPELL_SECONDS[f.ranks[1]] ~= 30
					or ns.SPELL_SECONDS[r.ranks[1]] ~= 30 then
					fail(scenario, client .. ": a length is missing from the table")
				end
				local mage = ns.OWN_BUFFS.MAGE
				if not (base and mage[base + 1] == shield and mage[base + 2] == ward) then
					fail(scenario, client .. ": not in place after Dampen Magic's family")
				end
			end
		end
		Mock.reset()
	end
end

do
	local scenario = "ownspell: shields: off on a new profile, offered once switched on"
	with(scenario, { class = "MAGE", known = VANILLA }, function(ns)
		local pick = ns.db.profile.ownBuffs.pick
		if pick.manashield ~= "off" or pick.ward ~= "off" then fail(scenario, "not off on a new profile") end
		if mine(ns) and (key(mine(ns)) == "manashield" or key(mine(ns)) == "fireward" or key(mine(ns)) == "frostward") then
			fail(scenario, "offered while off")
		end
		local control = findOption(ns.optionsTable, "own_manashield")
		if not control then fail(scenario, "no switch for Mana Shield") return end
		if control.type ~= "toggle" then fail(scenario, "Mana Shield's control is " .. tostring(control.type)) end
		control.set({ "own_manashield" }, true)
		local entry = mine(ns, "manashield")
		if not entry then fail(scenario, "switched on, none up: not offered") return end
		ns.Prompt:ApplyTarget(entry)
		local text = tostring(macro(ns))
		if not (has(text, "/target ") and has(text, "/cast Mana Shield")) then fail(scenario, "the macro is " .. text) end
		local ward = findOption(ns.optionsTable, "own_ward")
		local values = ward and (type(ward.values) == "function" and ward.values() or ward.values) or {}
		if not (values.auto and values.fireward and values.frostward and values.off) then
			fail(scenario, "the ward's choice lacks auto, Fire Ward, Frost Ward or off")
		end
	end)
end

do
	local scenario = "ownspell: shields: a ward up, nothing more asked"
	with(scenario, { class = "MAGE", known = VANILLA }, function(ns)
		findOption(ns.optionsTable, "own_ward").set({ "own_ward" }, "auto")
		if not mine(ns, "fireward") then fail(scenario, "auto, none up: no ward offered") end
		world.auras[6143] = "player"
		Mock.advance(4)
		if mine(ns, "fireward") or mine(ns, "frostward") then fail(scenario, "a ward is up and one is still offered") end
		if ns.db.char.ownLast.ward ~= "frostward" then
			fail(scenario, "the ward last up is " .. tostring(ns.db.char.ownLast.ward) .. ", not frostward")
		end
	end)
end

do
	local scenario = "ownspell: shields: never in a fight"
	with(scenario, { class = "MAGE", known = VANILLA }, function(ns)
		findOption(ns.optionsTable, "own_manashield").set({ "own_manashield" }, true)
		Mock.inCombat = true
		if mine(ns, "manashield") then fail(scenario, "offered in a fight") end
		Mock.inCombat = false
		if not mine(ns, "manashield") then fail(scenario, "not offered out of a fight") end
	end)
end

do
	local scenario = "ownspell: shields: the page says outside a fight"
	with(scenario, { class = "MAGE", known = VANILLA }, function(ns)
		local shield = findOption(ns.optionsTable, "own_manashield")
		local ward = findOption(ns.optionsTable, "own_ward")
		local text = shield and (type(shield.desc) == "function" and shield.desc() or shield.desc)
		if not has(text, "outside a fight") then fail(scenario, "Mana Shield's text does not say outside a fight") end
		text = ward and (type(ward.desc) == "function" and ward.desc() or ward.desc)
		if not has(tostring(text):lower(), "outside a fight") then fail(scenario, "the ward's text does not say outside a fight") end
		local note = findOption(ns.optionsTable, "ownBriefNote")
		if not note or note.hidden() then fail(scenario, "the line under them is hidden from a mage who knows them") end
		local sections = ns.WindowLayout.pages.who.sections
		local ok = false
		for _, section in ipairs(sections) do
			if section.key == "who.myself" then
				local at
				for i, item in ipairs(section.items) do
					local k = type(item) == "table" and item[1] or item
					if k == "who.own_manashield" then at = i end
				end
				local function at_(i)
					local item = at and section.items[at + i]
					return type(item) == "table" and item[1] or item
				end
				ok = at ~= nil and at_(1) == "who.own_ward" and at_(2) == "who.ownBriefNote"
			end
		end
		if not ok then fail(scenario, "the layout does not list Mana Shield, the wards and the note in a row") end
	end)
	with(scenario, { class = "MAGE", known = {} }, function(ns)
		local note = findOption(ns.optionsTable, "ownBriefNote")
		if note and not note.hidden() then fail(scenario, "the line is shown to a mage who knows none of them") end
	end)
end

-- ------------------------------------------------------------------ adding

do
	local scenario = "ownspell: added by name, with its icon and name, reminded when not on you"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR } }, function(ns)
		local line = add(ns, "Fear Ward")
		if not (has(line, "|T") and has(line, "Fear Ward")) then fail(scenario, "the answer is: " .. tostring(line)) end
		if not (list(ns)[1] and list(ns)[1].id == FEAR) then fail(scenario, "not on the list") return end
		local said_ = findOption(ns.optionsTable, "ownSpellSaid")
		if not said_ or said_.hidden() then fail(scenario, "the answer line is hidden") end
		if findOption(ns.optionsTable, "ownSpellAdd").get() ~= "" then fail(scenario, "the box is not empty") end
		local entry = mine(ns, "ownspell6346")
		if not entry then fail(scenario, "not offered with none up") return end
		ns.Prompt:ApplyTarget(entry)
		local text = tostring(macro(ns))
		if not (has(text, "/target ") and has(text, "/cast Fear Ward")) then fail(scenario, "the macro is " .. text) end
		world.auras[FEAR] = "player"
		Mock.advance(4)
		if mine(ns, "ownspell6346") then fail(scenario, "offered over its own aura") end
		local remove = findOption(ns.optionsTable, "ownSpell1")
		local name = remove.name()
		if not (has(name, "Remove") and has(name, "Fear Ward")) then fail(scenario, "Remove's name is " .. name) end
		if remove.hidden() then fail(scenario, "Remove 1 is hidden") end
		if not findOption(ns.optionsTable, "ownSpell2").hidden() then fail(scenario, "Remove 2 is shown") end
	end)
end

do
	local scenario = "ownspell: added by spell id"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR } }, function(ns)
		local line = add(ns, "6346")
		if not has(line, "Added") then fail(scenario, "the answer is: " .. tostring(line)) end
		if not (list(ns)[1] and list(ns)[1].name == "Fear Ward") then fail(scenario, "the entry is not Fear Ward") end
	end)
end

do
	local scenario = "ownspell: another rank of it on you counts"
	with(scenario, { names = { [900101] = "Test Shield", [900102] = "Test Shield" }, byName = { ["Test Shield"] = 900101 },
		known = { 900101 } }, function(ns)
		add(ns, "Test Shield")
		if not mine(ns, "ownspell900101") then fail(scenario, "not offered with no aura") return end
		world.auras[900102] = "player"
		Mock.advance(4)
		if mine(ns, "ownspell900101") then fail(scenario, "offered with another rank of it on you") end
	end)
end

do
	local scenario = "ownspell: a spell this character does not know is refused"
	with(scenario, { names = { [900201] = "Unknown Ward" }, known = {} }, function(ns)
		if not has(add(ns, "Unknown Ward"), "is not in your spellbook") then fail(scenario, "no refusal for an unknown spell") end
		if not has(add(ns, "Nonesuch"), "found no spell called Nonesuch") then fail(scenario, "no refusal for a name nobody has") end
		if #list(ns) ~= 0 then fail(scenario, "the list is not empty") end
	end)
end

do
	local scenario = "ownspell: a spell cast on an enemy is refused"
	with(scenario, { names = { [900301] = "Test Bolt" }, known = { 900301 }, harmful = { [900301] = true } }, function(ns)
		if not has(add(ns, "Test Bolt"), "cast on an enemy") then fail(scenario, "no refusal") end
		if #list(ns) ~= 0 then fail(scenario, "the list is not empty") end
	end)
end

do
	local scenario = "ownspell: a passive spell is refused"
	with(scenario, { names = { [900401] = "Test Aura" }, known = { 900401 }, passive = { [900401] = true } }, function(ns)
		if not has(add(ns, "Test Aura"), "is passive") then fail(scenario, "no refusal") end
		if #list(ns) ~= 0 then fail(scenario, "the list is not empty") end
	end)
end

do
	local scenario = "ownspell: a spell Manners covers is refused, with where its switch is"
	with(scenario, { class = "MAGE", names = { [168] = "Frost Armor", [10193] = "Mana Shield", [1459] = "Arcane Intellect", [900701] = "Mana Shield" },
		byName = { ["Mana Shield"] = 900701 }, known = { 168, 10193, 1459, 900701 } }, function(ns)
		local line = add(ns, "Frost Armor")
		if not (has(line, "Armor") and has(line, "Myself")) then fail(scenario, "Frost Armor: " .. tostring(line)) end
		line = add(ns, "10193")
		if not (has(line, "Mana Shield") and has(line, "Myself")) then fail(scenario, "Mana Shield: " .. tostring(line)) end
		-- Another id with a covered spell's name, as a rank of it the table lacks.
		line = add(ns, "Mana Shield")
		if not (has(line, "Mana Shield") and has(line, "Myself")) then fail(scenario, "Mana Shield by name: " .. tostring(line)) end
		line = add(ns, "Arcane Intellect")
		if not has(line, "What to cast") then fail(scenario, "Arcane Intellect: " .. tostring(line)) end
		if #list(ns) ~= 0 then fail(scenario, "the list is not empty") end
	end)
end

do
	local scenario = "ownspell: ten at most"
	local names, known = {}, {}
	for i = 1, 11 do
		names[900500 + i] = "Test Ward " .. i
		known[#known + 1] = 900500 + i
	end
	with(scenario, { names = names, known = known }, function(ns)
		for i = 1, 10 do add(ns, "Test Ward " .. i) end
		if #list(ns) ~= 10 then fail(scenario, #list(ns) .. " on the list, not ten") end
		if not has(add(ns, "Test Ward 11"), "ten spells at most") then fail(scenario, "no refusal for the eleventh") end
		if #list(ns) ~= 10 then fail(scenario, "the list grew past ten") end
	end)
end

do
	local scenario = "ownspell: the same spell twice is refused"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR } }, function(ns)
		add(ns, "Fear Ward")
		if not has(add(ns, "Fear Ward"), "on your list already") then fail(scenario, "no refusal by name") end
		if not has(add(ns, "6346"), "on your list already") then fail(scenario, "no refusal by id") end
		if #list(ns) ~= 1 then fail(scenario, #list(ns) .. " on the list") end
	end)
end

-- ------------------------------------------------------------------ behaving as an own buff

do
	local scenario = "ownspell: obeys Myself, cities and inns, and a fight"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR } }, function(ns)
		add(ns, "Fear Ward")
		if not mine(ns, "ownspell6346") then fail(scenario, "not offered") return end
		ns.db.profile.sources.self = false
		if mine(ns, "ownspell6346") then fail(scenario, "offered with Myself off") end
		ns.db.profile.sources.self = true
		world.resting = true
		ns.db.profile.ownBuffs.inCities = false
		Mock.advance(1)
		if mine(ns, "ownspell6346") then fail(scenario, "offered in a city with the switch off") end
		ns.db.profile.ownBuffs.inCities = true
		if not mine(ns, "ownspell6346") then fail(scenario, "not offered in a city with the switch on") end
		world.resting = false
		Mock.inCombat = true
		if mine(ns, "ownspell6346") then fail(scenario, "offered in a fight") end
		Mock.inCombat = false
		if not mine(ns, "ownspell6346") then fail(scenario, "not offered after the fight") end
	end)
end

do
	local scenario = "ownspell: Remove takes it off"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR } }, function(ns)
		add(ns, "Fear Ward")
		findOption(ns.optionsTable, "ownSpell1").func()
		if #list(ns) ~= 0 then fail(scenario, "still on the list") end
		if ns.FindOwnFamily("ownspell6346") ~= nil then fail(scenario, "the family is still made") end
		if mine(ns, "ownspell6346") then fail(scenario, "still offered") end
		if not findOption(ns.optionsTable, "ownSpell1").hidden() then fail(scenario, "Remove 1 is still shown") end
		if not has(ns.OwnSpells.Said(), "Removed Fear Ward.") then fail(scenario, "the line is " .. tostring(ns.OwnSpells.Said())) end
	end)
end

do
	local scenario = "ownspell: kept per character, not in the profile"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR } }, function(ns)
		add(ns, "Fear Ward")
		for k in pairs(ns.db.profile.ownBuffs.pick) do
			if tostring(k):sub(1, 8) == "ownspell" then fail(scenario, "a pick " .. k .. " is in the profile") end
		end
		local text = tostring(ns.ExportSettings())
		if has(text, "ownspell") or has(text, "Fear Ward") then fail(scenario, "the export carries it") end
		ns.db:SetProfile("Other")
		ns.db.profile.sources.self = true
		ns.Guard("probe", ns.ProbeCapabilities)
		if not mine(ns, "ownspell6346") then fail(scenario, "gone with another profile") end
	end)
end

do
	local scenario = "ownspell: a damaged list is repaired"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR } }, function(ns)
		ns.db.char.ownSpells = "junk"
		ns.ClampSettings()
		if type(ns.db.char.ownSpells) ~= "table" or #ns.db.char.ownSpells ~= 0 then fail(scenario, "junk is not an empty list") end
		local bad = { { id = "x" }, { id = 0 }, { id = 1.5 }, { id = -3 }, { name = "none" }, 5,
			{ id = FEAR, name = string.rep("x", 300) }, { id = FEAR } }
		for i = 1, 10 do bad[#bad + 1] = { id = 900000 + i } end
		ns.db.char.ownSpells = bad
		ns.db.char.ownLast = { ownspell555 = "ownspell555", ward = "frostward" }
		ns.ClampSettings()
		local l = ns.db.char.ownSpells
		if #l ~= 10 then fail(scenario, #l .. " entries, not ten") return end
		if l[1].id ~= FEAR or #l[1].name ~= 100 then fail(scenario, "the first entry is not Fear Ward cut to 100 bytes") end
		if l[10].id ~= 900009 then fail(scenario, "the tenth is " .. tostring(l[10].id)) end
		local seen = {}
		for _, e in ipairs(l) do
			if seen[e.id] then fail(scenario, "an id twice") end
			seen[e.id] = true
		end
		if ns.db.char.ownLast.ownspell555 ~= nil then fail(scenario, "a memory of an unlisted spell is kept") end
		if ns.db.char.ownLast.ward ~= "frostward" then fail(scenario, "another memory was dropped") end
	end)
end

-- ------------------------------------------------------------------ the verdict

do
	local scenario = "ownspell: a spell that leaves no aura on you is taken off, with why"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR }, helpful = { [FEAR] = true } }, function(ns)
		add(ns, "Fear Ward")
		Mock.printed = {}
		cast(ns, FEAR, me(ns))
		if #list(ns) ~= 0 then fail(scenario, "still on the list") end
		if not has(said(), "left no aura on you") then fail(scenario, "no line saying why") end
		if ns.FindOwnFamily("ownspell6346") ~= nil then fail(scenario, "the family is still made") end
		add(ns, "Fear Ward")
		world.auras[FEAR] = "player"
		cast(ns, FEAR, me(ns))
		if #list(ns) ~= 1 or not list(ns)[1].seen then fail(scenario, "an aura that came was not kept as seen") end
	end)
end

do
	local scenario = "ownspell: cast on somebody else, no verdict"
	with(scenario, { names = { [FEAR] = "Fear Ward", [900601] = "Test Barrier" }, known = { FEAR, 900601 },
		helpful = { [FEAR] = true } }, function(ns)
		add(ns, "Fear Ward")
		cast(ns, FEAR, "Anna Aim")
		if #list(ns) ~= 1 then fail(scenario, "taken off after a cast on another") return end
		-- A friend other than you is the target: the cast may be theirs.
		local same = UnitIsUnit
		rawset(_G, "UnitIsUnit", function(a, b)
			if a == "target" and b == "player" then return false end
			return same(a, b)
		end)
		local exists, assist = UnitExists, UnitCanAssist
		rawset(_G, "UnitExists", function(u) return u == "target" or exists(u) end)
		rawset(_G, "UnitCanAssist", function() return true end)
		cast(ns, FEAR, "")
		rawset(_G, "UnitIsUnit", same)
		rawset(_G, "UnitExists", exists)
		rawset(_G, "UnitCanAssist", assist)
		if #list(ns) ~= 1 then fail(scenario, "taken off after a helpful cast naming nobody") return end
		add(ns, "Test Barrier")
		cast(ns, 900601, "")
		for _, e in ipairs(list(ns)) do
			if e.name == "Test Barrier" then fail(scenario, "a spell that is not helpful, naming nobody, stayed") end
		end
	end)
end

do
	-- Forever calls any spell that can land on you helpful, and a self-only cast
	-- (Blink) names nobody: with no friend targeted it is yours, and is judged.
	local scenario = "ownspell: a spell cast at nobody with nobody targeted is judged"
	with(scenario, { names = { [900602] = "Test Step" }, known = { 900602 }, helpful = { [900602] = true } }, function(ns)
		add(ns, "Test Step")
		local exists = UnitExists
		rawset(_G, "UnitExists", function(u)
			if u == "target" then return false end
			return exists(u)
		end)
		cast(ns, 900602, "")
		rawset(_G, "UnitExists", exists)
		if #list(ns) ~= 0 then fail(scenario, "still listed after a cast that left nothing on you") end
		-- A friend is targeted, and the spell has no range on anybody: still yours.
		add(ns, "Test Step")
		local same, assist, spells = UnitIsUnit, UnitCanAssist, C_Spell
		rawset(_G, "UnitIsUnit", function(a, b)
			if a == "target" and b == "player" then return false end
			return same(a, b)
		end)
		rawset(_G, "UnitExists", function(u) return u == "target" or exists(u) end)
		rawset(_G, "UnitCanAssist", function() return true end)
		rawset(_G, "C_Spell", setmetatable({ IsSpellInRange = function() return nil end }, { __index = spells }))
		cast(ns, 900602, "")
		rawset(_G, "UnitIsUnit", same)
		rawset(_G, "UnitExists", exists)
		rawset(_G, "UnitCanAssist", assist)
		rawset(_G, "C_Spell", spells)
		if #list(ns) ~= 0 then fail(scenario, "still listed with a friend targeted whom it cannot be cast on") end
		local told
		for _, line in ipairs(ns.OwnSpellLines()) do
			if line:find("taken off", 1, true) then told = true end
		end
		if not told then fail(scenario, "/manners debug does not say what became of the cast") end
	end)
end

do
	local scenario = "ownspell: no verdict in a fight, on a withheld read, or once seen"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR }, helpful = { [FEAR] = true } }, function(ns)
		add(ns, "Fear Ward")
		Mock.inCombat = true
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", me(ns), "Cast-own-1", FEAR)
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-own-1", FEAR)
		Mock.inCombat = false
		Mock.runTimers(2)
		if #list(ns) ~= 1 then fail(scenario, "judged a cast in a fight") end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", me(ns), "Cast-own-2", FEAR)
		ns.addon:UNIT_SPELLCAST_SUCCEEDED(nil, "player", "Cast-own-2", FEAR)
		Mock.inCombat = true
		Mock.runTimers(2)
		Mock.inCombat = false
		if #list(ns) ~= 1 then fail(scenario, "judged when the fight began before the timer") end
		world.refuse[FEAR] = "secret"
		cast(ns, FEAR, me(ns))
		if #list(ns) ~= 1 then fail(scenario, "judged on a withheld read") end
		world.refuse = {}
	end)
	with(scenario, { names = PRIEST_NAMES, known = { FEAR }, helpful = { [FEAR] = true },
		list = { { id = FEAR, name = "Fear Ward", seen = true } } }, function(ns)
		cast(ns, FEAR, me(ns))
		if #list(ns) ~= 1 then fail(scenario, "judged an entry already seen") end
	end)
end

do
	local scenario = "ownspell: one Manners came to cover is left to Manners"
	with(scenario, { class = "MAGE", known = { 10193 }, list = { { id = 10193, name = "Mana Shield" } } }, function(ns)
		if ns.FindOwnFamily("ownspell10193") ~= nil then fail(scenario, "made as an entry of the player's own") end
		if ns.FindOwnFamily("manashield") == nil then fail(scenario, "Manners' own family is gone") end
		local row = findOption(ns.optionsTable, "ownSpell1")
		if not (row and has(row.name(), "Manners now reminds you of it itself")) then fail(scenario, "the row does not say so") end
	end)
end

-- ------------------------------------------------------------------ the page

do
	local scenario = "ownspell: no control of its own on the page"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR } }, function(ns)
		add(ns, "Fear Ward")
		local who = ns.OptionsPage.BuildWhoTab()
		for k in pairs(who.args) do
			if tostring(k):sub(1, 12) == "own_ownspell" then fail(scenario, k .. " is a control of its own") end
		end
		if not (who.args.ownSpell1 and who.args.ownSpellAdd) then fail(scenario, "the section's controls are missing") end
	end)
end

do
	local scenario = "ownspell: a class with nothing for others sees the section"
	with(scenario, { class = "HUNTER", known = {} }, function(ns)
		local control = findOption(ns.optionsTable, "ownSpellAdd")
		if not control then fail(scenario, "no box for a hunter") return end
		if control.hidden and control.hidden() then fail(scenario, "the box is hidden from a hunter") end
	end)
end

do
	local scenario = "ownspell: not in a fight"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR } }, function(ns)
		add(ns, "Fear Ward")
		Mock.inCombat = true
		if not findOption(ns.optionsTable, "ownSpellAdd").disabled() then fail(scenario, "the box is open in a fight") end
		if not findOption(ns.optionsTable, "ownSpell1").disabled() then fail(scenario, "Remove is open in a fight") end
		if not has(add(ns, "Test"), "Not in a fight") then fail(scenario, "Add answered in a fight") end
		ns.OwnSpells.Remove(1)
		if #list(ns) ~= 1 then fail(scenario, "Remove worked in a fight") end
		Mock.inCombat = false
	end)
end

do
	local scenario = "ownspell: /manners spell adds, lists and removes"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR } }, function(ns)
		local function say(text)
			Mock.printed = {}
			ns.addon:HandleSlash(text)
			return said()
		end
		if not has(say("spell"), "No spells of your own yet") then fail(scenario, "the empty list") end
		if not has(say("spell add Fear Ward"), "Added") then fail(scenario, "add") end
		if not has(say("spell"), "Spells of your own (1 of 10):") then fail(scenario, "the list") end
		if not has(say("spell remove Fear Ward"), "Removed Fear Ward.") then fail(scenario, "remove") end
		if not has(say("spell xyz"), "/manners spell add") then fail(scenario, "the usage") end
	end)
end

do
	local scenario = "ownspell: the Who to buff reset keeps the list"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR } }, function(ns)
		add(ns, "Fear Ward")
		ns.OptionsPage.ResetPage("who")
		if not (list(ns)[1] and list(ns)[1].id == FEAR) then fail(scenario, "the reset took the list") end
	end)
end

for _, client in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
	local scenario = "ownspell: " .. client .. ": added and reminded"
	with(scenario, { flavour = client, names = { [900001] = "Test Ward" }, known = { 900001 } }, function(ns)
		add(ns, "Test Ward")
		if not mine(ns, "ownspell900001") then fail(scenario, "not offered") return end
		world.auras[900001] = "player"
		Mock.advance(4)
		if mine(ns, "ownspell900001") then fail(scenario, "offered over its own aura") end
	end)
end

do
	local scenario = "ownspell: cooldown: a ward still cooling is not offered, and is once it is ready"
	with(scenario, { class = "MAGE", known = VANILLA }, function(ns)
		findOption(ns.optionsTable, "own_ward").set({ "own_ward" }, "auto")
		Mock.spellCooldowns = {}
		for _, id in ipairs(VANILLA) do
			Mock.spellCooldowns[id] = { startTime = Mock.now, duration = 30 }
		end
		Mock.advance(4)
		if mine(ns, "fireward") or mine(ns, "frostward") then fail(scenario, "a ward on a 30 second cooldown was offered") end
		Mock.advance(30)
		if not (mine(ns, "fireward") or mine(ns, "frostward")) then fail(scenario, "not offered once the cooldown ended") end
	end)
end

do
	local scenario = "ownspell: cooldown: an added spell still cooling is not offered, and is once it is ready"
	with(scenario, { names = PRIEST_NAMES, known = { FEAR } }, function(ns)
		add(ns, "Fear Ward")
		Mock.spellCooldowns = { [FEAR] = { startTime = Mock.now, duration = 30 } }
		Mock.advance(4)
		if mine(ns, "ownspell6346") then fail(scenario, "offered during its cooldown") end
		Mock.advance(30)
		if not mine(ns, "ownspell6346") then fail(scenario, "not offered once the cooldown ended") end
	end)
end
