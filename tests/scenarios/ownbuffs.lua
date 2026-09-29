-- Your class's own buffs (1.2.0): under "Myself", the buffs a class can only
-- put on itself -- a mage's armor, a priest's Inner Fire, a paladin's aura and
-- Righteous Fury, a hunter's aspect -- offered to you as "You" when none of a
-- family is up. Buffs.lua holds the families (VANILLA_OWN), Core.lua reads
-- them on you and picks one (OwnVerdict, OwnAutoPick), Queue.lua's SelfEntry
-- makes the entry, and Options.lua shows your class's families on Who to buff.
--
-- Every scenario name starts with "own:" so the mutations in
-- tests/mutations/ownbuffs.py can name the one that has to catch them.
--
-- The shared mock dresses the player in every aura there is (Mock.playerHeld
-- nil), which keeps you off every other file's prompt. Here the ids of your
-- class's own buffs answer only from what a scenario says you wear (`wear`),
-- and everything else stays the mock's: a mage keeps her Arcane Intellect on,
-- so her own group buff does not come first unless a scenario takes it off.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local ME = "Mort Defrette"

-- Ranks, by spell, as Buffs.lua lists them.
local FROST = { 168, 7300, 7301 }
local ICE1 = 7302
local MAGE_ARMOR = 6117
local INTELLECT = 1459
local DEVOTION, RETRIBUTION, CONCENTRATION = 465, 7294, 19746
local RIGHTEOUS_FURY = 25780
local HAWK, MONKEY, CHEETAH = 13165, 13163, 5118
local INNER_FIRE = 588

local function said() return table.concat(Mock.printed, "\n") end

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

local function macro(ns) return ns.Prompt:GetButton():GetAttribute("macrotext1") end

local function list(...)
	local out = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if type(v) == "table" then
			for _, id in ipairs(v) do out[#out + 1] = id end
		else
			out[#out + 1] = v
		end
	end
	return out
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- Your own entry in the queue as it stands, or nil.
local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

-- What you wear of your class's own buffs, as { id, left, source, name }:
-- `left` nil is a toggle (no timer), `source` nil is you and false names
-- nobody, `name` defaults to the spell's own. `withheld` is a client that
-- will not say: every read of your own buffs a secret. Read again at once.
local function wear(ns, auras, withheld)
	rawset(_G, "C_UnitAuras", nil)
	local base = C_UnitAuras
	local byId, byName = {}, {}
	for _, a in ipairs(auras or {}) do
		local source = a.source
		if source == nil then source = "player" elseif source == false then source = nil end
		local aura = { spellId = a.id, name = a.name or ns.SpellNameFor(a.id),
			expirationTime = a.left and (Mock.now + a.left) or 0, sourceUnit = source }
		byId[a.id] = aura
		if aura.name then byName[aura.name] = aura end
	end
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, id)
			if unit == "player" and withheld and ns.OWN_BY_ID[id] then return Mock.SECRET end
			if unit == "player" and (ns.OWN_BY_ID[id] or byId[id]) then return byId[id] end
			return base.GetUnitAuraBySpellID(unit, id)
		end,
		GetAuraDataBySpellName = function(unit, name)
			if unit == "player" and withheld then return Mock.SECRET end
			if unit == "player" then return byName[name] end
			return nil
		end,
	}, { __index = base }))
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

-- Globals a scenario may replace, put back after each: Mock.reset owns none.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_UnitAuras", "IsResting", "IsInInstance",
	"UnitGroupRolesAssigned", "UnitAffectingCombat", "GetNumShapeshiftForms",
	"GetShapeshiftFormInfo", "IsShiftKeyDown", "MenuUtil", "C_Spell" }

local function know(ids)
	local known = {}
	for _, id in ipairs(ids) do known[id] = true end
	IsSpellKnown = function(id) return known[id] == true end
	IsPlayerSpell = IsSpellKnown
	return known
end

-- One scenario: nobody else about, the lifecycle driven, you knowing exactly
-- `opts.known` and wearing `opts.wearing` of your own. body(ns) runs and
-- everything is put back, whether it finished or threw.
local function with(scenario, opts, body)
	Mock.reset()
	if opts.class then Mock.class = opts.class end
	if opts.groupSize then Mock.groupSize = opts.groupSize end
	if opts.character then Mock.character = opts.character end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	know(opts.known or { INTELLECT })
	local undo = strangers(opts.people or {})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		-- Before the lifecycle too, whose scans would otherwise read every
		-- armor on you and remember one.
		wear(ns, opts.wearing or {})
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		wear(ns, opts.wearing or {})
		body(ns)
		noErrors(scenario, ns)
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local MAGE = list(INTELLECT, FROST, ICE1, MAGE_ARMOR)

-- ------------------------------------------------------------------ own 1
-- A mage with no armor up is offered the armor Automatic picks: out in the
-- world, Ice Armor, cast by its own name; in a dungeon or raid, Mage Armor.
-- The dropdown's Automatic says which, and why, in plain words.
Mock.reset()
do
	local scenario = "own: a mage with no armor is offered their Automatic armor"
	with(scenario, { known = MAGE }, function(ns)
		local me = mine(ns)
		if not me then
			fail(scenario, "a mage with no armor up was not offered one")
			return
		end
		if me.reason ~= "self" or me.name ~= ME or key(me) ~= "frostarmor" or me.known ~= false then
			fail(scenario, ("offered %s as %s (%s), known %s"):format(key(me), tostring(me.reason),
				tostring(me.name), tostring(me.known)))
		end
		if ns.Prompt:ReasonText(me) ~= "your own Ice Armor" then
			fail(scenario, "the reason line reads " .. tostring(ns.Prompt:ReasonText(me)))
		end
		local armor = findOption(ns.optionsTable, "own_armor")
		local values = armor and armor.values and armor.values() or {}
		if values.auto ~= "Automatic (Ice Armor, outside dungeons and raids)" then
			fail(scenario, "Automatic reads " .. tostring(values.auto))
		end
		IsInInstance = function() return true, "party" end
		me = mine(ns)
		if key(me) ~= "magearmor" then
			fail(scenario, "in a dungeon Automatic offered " .. key(me) .. ", not Mage Armor")
		end
		values = armor and armor.values and armor.values() or {}
		if values.auto ~= "Automatic (Mage Armor, in a dungeon or raid)" then
			fail(scenario, "in a dungeon Automatic reads " .. tostring(values.auto))
		end
		-- A battleground is not a dungeon.
		IsInInstance = function() return true, "pvp" end
		if key(mine(ns)) ~= "frostarmor" then
			fail(scenario, "in a battleground Automatic offered " .. key(mine(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ own 2
-- The armor you had up last is what Automatic offers next, once it is gone:
-- remembered from your own auras, per character, across a reload -- and an
-- alt on the same profile has a memory of their own.
Mock.reset()
do
	local scenario = "own: the one you had up last is remembered and offered next time"
	with(scenario, { known = MAGE, wearing = { { id = MAGE_ARMOR, left = 1800 } } }, function(ns)
		if mine(ns) then
			fail(scenario, "offered " .. key(mine(ns)) .. " while wearing Mage Armor")
		end
		local memory = ns.db.char.ownLast
		if not (memory and memory.armor == "magearmor") then
			fail(scenario, "wearing Mage Armor was not remembered: " .. tostring(memory and memory.armor))
		end
		wear(ns, {})
		local me = mine(ns)
		if key(me) ~= "magearmor" then
			fail(scenario, "with the Mage Armor gone, Automatic offered " .. key(me) .. " rather than the one you had up last")
		end
		local armor = findOption(ns.optionsTable, "own_armor")
		local auto = armor and armor.values and armor.values().auto
		if auto ~= "Automatic (Mage Armor, the one you had up last)" then
			fail(scenario, "Automatic reads " .. tostring(auto))
		end

		-- The next session on the same saved file.
		local again = load(scenario)
		if not again then return end
		freshPrompt(again, scenario)
		wear(again, {})
		if key(mine(again)) ~= "magearmor" then
			fail(scenario, "after a reload Automatic offered " .. key(mine(again)))
		end

		-- An alt logging in on the same file and profile: no memory of hers.
		Mock.character = "Alt Second"
		local alt = load(scenario)
		if not alt then return end
		freshPrompt(alt, scenario)
		wear(alt, {})
		if key(mine(alt)) ~= "frostarmor" then
			fail(scenario, "an alt on the same profile was offered " .. key(mine(alt))
				.. ", remembered from another character")
		end
	end)
end

-- ------------------------------------------------------------------ own 3
-- A spell picked in the dropdown is offered whatever Automatic would say, and
-- Don't remind me offers nothing -- while any of the family is up nothing is
-- offered either way, a rank the table lacks included, read by its name.
Mock.reset()
do
	local scenario = "own: a chosen spell overrides Automatic"
	with(scenario, { known = MAGE }, function(ns)
		local armor = findOption(ns.optionsTable, "own_armor")
		if not (armor and armor.set) then
			fail(scenario, "there is no armor dropdown for a mage")
			return
		end
		armor.set({ "own_armor" }, "magearmor")
		if ns.db.profile.ownBuffs.pick.armor ~= "magearmor" or armor.get() ~= "magearmor" then
			fail(scenario, "the dropdown does not write the pick")
		end
		if key(mine(ns)) ~= "magearmor" then
			fail(scenario, "picked Mage Armor, and was offered " .. key(mine(ns)))
		end
		armor.set({ "own_armor" }, "frostarmor")
		IsInInstance = function() return true, "raid" end
		if key(mine(ns)) ~= "frostarmor" then
			fail(scenario, "picked Ice Armor, and in a raid was offered " .. key(mine(ns)))
		end
	end)
end

Mock.reset()
do
	local scenario = "own: Don't remind me offers nothing"
	with(scenario, { known = MAGE }, function(ns)
		if not mine(ns) then
			fail(scenario, "SKIPPED -- not offered an armor to begin with")
			return
		end
		local armor = findOption(ns.optionsTable, "own_armor")
		local values = armor and armor.values and armor.values() or {}
		if values.off ~= "Don't remind me" then
			fail(scenario, "the dropdown has no Don't remind me: " .. tostring(values.off))
		end
		armor.set({ "own_armor" }, "off")
		if mine(ns) then fail(scenario, "Don't remind me still offered " .. key(mine(ns))) end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("Armor: switched off (Don't remind me).", 1, true) then
			fail(scenario, "/manners debug does not say the armor is switched off: " .. flat(said()))
		end
	end)
end

Mock.reset()
do
	local scenario = "own: having any armor up offers nothing"
	with(scenario, { known = MAGE }, function(ns)
		if not mine(ns) then
			fail(scenario, "SKIPPED -- not offered an armor to begin with")
			return
		end
		for _, case in ipairs({
			{ label = "Frost Armor rank 3", aura = { id = 7301, left = 1800 } },
			-- A client naming the aura otherwise: its id alone says what it is.
			{ label = "Frost Armor under another name", aura = { id = 7301, name = "Frost Armour", left = 1800 } },
			{ label = "Ice Armor", aura = { id = ICE1, left = 1800 } },
			{ label = "Mage Armor", aura = { id = MAGE_ARMOR, left = 1800 } },
			-- A rank the table does not have: only its name says what it is.
			{ label = "an Ice Armor rank the table lacks", aura = { id = 99002, name = "Ice Armor", left = 1800 } },
			-- Nobody the client names: counts as yours rather than nag.
			{ label = "an armor naming nobody", aura = { id = ICE1, left = 1800, source = false } },
		}) do
			wear(ns, { case.aura })
			if mine(ns) then
				fail(scenario, "wearing " .. case.label .. ", you were offered " .. key(mine(ns)))
			end
		end
		-- The same by the aura list walked, on a client with no lookup by name.
		wear(ns, {})
		local base = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetAuraDataBySpellName = false,
			GetUnitAuraBySpellID = function(unit, id)
				if unit == "player" and ns.OWN_BY_ID[id] then return nil end
				return base.GetUnitAuraBySpellID(unit, id)
			end,
			GetAuraDataByIndex = function(unit, i)
				if unit == "player" and i == 1 then
					return { spellId = 99002, name = "Ice Armor", expirationTime = Mock.now + 1800, sourceUnit = "player" }
				end
				return nil
			end,
		}, { __index = base }))
		if mine(ns) then
			fail(scenario, "an Ice Armor rank the table lacks, found by walking your auras, still offered " .. key(mine(ns)))
		end
		wear(ns, {})
		-- A client that will not say is no reason to offer you what you may
		-- be wearing.
		wear(ns, {}, true)
		if mine(ns) then
			fail(scenario, "the client will not read your armor, and you were offered " .. key(mine(ns)))
		end
		wear(ns, {})
		-- Somebody else's is not yours.
		wear(ns, { { id = ICE1, left = 1800, source = "party1" } })
		if not mine(ns) then
			fail(scenario, "an armor cast by somebody else counted as yours")
		end
	end)
end

-- ------------------------------------------------------------------ own 4
-- Frost Armor becomes Ice Armor at 30, a new name for the same line: the
-- macro casts the name of the best rank you know, not the first rank's.
Mock.reset()
do
	local scenario = "own: Frost Armor is cast by name at low level and Ice Armor once known"
	local known
	with(scenario, { known = { INTELLECT, 168 } }, function(ns)
		ns.Prompt:Refresh()
		if macro(ns) ~= "/cast [@player] Frost Armor" then
			fail(scenario, "a mage knowing only Frost Armor rank 1 arms " .. flat(macro(ns)))
		end
		known = know({ INTELLECT, 168, 7300, 7301, ICE1 })
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:InvalidateMacro()
		ns.Prompt:Refresh()
		if macro(ns) ~= "/cast [@player] Ice Armor" then
			fail(scenario, "a mage who has learned Ice Armor arms " .. flat(macro(ns)))
		end
		-- The icon follows the name.
		if ns.BuffName(ns.FindOwnSpell("frostarmor")) ~= "Ice Armor" then
			fail(scenario, "the spell is named " .. tostring(ns.BuffName(ns.FindOwnSpell("frostarmor"))))
		end
	end)
	-- A warlock's Demon Skin becomes Demon Armor at 20 in the same way.
	with(scenario, { class = "WARLOCK", known = { 5697, 687, 696 } }, function(ns)
		ns.Prompt:Refresh()
		if macro(ns) ~= "/cast [@player] Demon Skin" then
			fail(scenario, "a warlock knowing Demon Skin arms " .. flat(macro(ns)))
		end
		know({ 5697, 687, 696, 706 })
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:InvalidateMacro()
		ns.Prompt:Refresh()
		if macro(ns) ~= "/cast [@player] Demon Armor" then
			fail(scenario, "a warlock who has learned Demon Armor arms " .. flat(macro(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ own 5
-- A paladin's aura is a toggle: any of it up (or the shapeshift form the
-- client makes of it) is your choice and nothing is offered; none up, the one
-- you had up last, else Devotion Aura. Another paladin's aura on you is not
-- yours.
Mock.reset()
do
	local scenario = "own: a paladin with any aura up is not reminded and with none is offered the last used"
	local PALADIN = { 19740, DEVOTION, RETRIBUTION, CONCENTRATION }
	with(scenario, { class = "PALADIN", known = PALADIN }, function(ns)
		local me = mine(ns)
		if key(me) ~= "devotionaura" then
			fail(scenario, "with no aura up and none remembered, offered " .. key(me) .. " rather than Devotion Aura")
		end
		wear(ns, { { id = CONCENTRATION } })
		if mine(ns) then fail(scenario, "offered " .. key(mine(ns)) .. " with Concentration Aura up") end
		-- Even one a client reports a timer on: an aura is not topped up.
		ns.db.profile.filters.whenBuffed = "refresh"
		wear(ns, { { id = CONCENTRATION, left = 60 } })
		if mine(ns) then fail(scenario, "a toggle was offered as a top-up") end
		ns.db.profile.filters.whenBuffed = "skip"
		wear(ns, {})
		if key(mine(ns)) ~= "concentrationaura" then
			fail(scenario, "with the aura dropped, offered " .. key(mine(ns)) .. " rather than the Concentration Aura last up")
		end
		-- Another paladin's Devotion Aura on you says nothing about yours.
		wear(ns, { { id = DEVOTION, source = "party1" } })
		if not mine(ns) then fail(scenario, "another paladin's aura counted as yours") end
		-- The client's shapeshift bar: Retribution Aura's form active.
		wear(ns, {})
		GetNumShapeshiftForms = function() return 3 end
		GetShapeshiftFormInfo = function(i)
			return 135873, i == 2, true, ({ DEVOTION, RETRIBUTION, CONCENTRATION })[i]
		end
		if mine(ns) then fail(scenario, "offered " .. key(mine(ns)) .. " with Retribution Aura's form active") end
		if ns.db.char.ownLast.aura ~= "retributionaura" then
			fail(scenario, "the active form was not remembered: " .. tostring(ns.db.char.ownLast.aura))
		end
	end)
end

-- ------------------------------------------------------------------ own 6
-- Righteous Fury under Automatic only while your group role is tank -- solo,
-- or with another role or none, never. Always offers it whenever it is off;
-- Don't remind me never.
Mock.reset()
do
	local scenario = "own: Righteous Fury only as a tank under Automatic"
	with(scenario, { class = "PALADIN", known = { 19740, DEVOTION, RIGHTEOUS_FURY },
		wearing = { { id = DEVOTION } } }, function(ns)
		local role
		UnitGroupRolesAssigned = function(unit) return unit == "player" and role or "NONE" end
		role = "TANK"
		if mine(ns) then fail(scenario, "a paladin alone was offered " .. key(mine(ns)) .. " as a tank") end
		Mock.groupSize = 5
		role = "DAMAGER"
		if mine(ns) then fail(scenario, "a damage-dealing paladin was offered " .. key(mine(ns))) end
		role = "NONE"
		if mine(ns) then fail(scenario, "a paladin with no role was offered " .. key(mine(ns))) end
		role = "TANK"
		if key(mine(ns)) ~= "righteousfury" then
			fail(scenario, "a tank without Righteous Fury was offered " .. key(mine(ns)))
		end
		local fury = findOption(ns.optionsTable, "own_righteousfury")
		local values = fury and fury.values and fury.values() or {}
		if fury.type ~= "select" or values.auto ~= "Automatic (only while I'm the tank)"
			or values.righteousfury ~= "Always" then
			fail(scenario, "Righteous Fury's choices read " .. tostring(values.auto) .. " / "
				.. tostring(values.righteousfury))
		end
		fury.set({ "own_righteousfury" }, "off")
		if mine(ns) then fail(scenario, "Don't remind me offered a tank " .. key(mine(ns))) end
		fury.set({ "own_righteousfury" }, "righteousfury")
		Mock.groupSize = 0
		if key(mine(ns)) ~= "righteousfury" then
			fail(scenario, "Always did not offer Righteous Fury to a paladin alone")
		end
	end)
end

-- ------------------------------------------------------------------ own 7
-- A hunter has nothing to give anybody else, and still a prompt for his own
-- aspect. Aspect of the Cheetah up is a choice: nothing is offered, and it is
-- never what Automatic remembers, which is the last aspect for a fight.
Mock.reset()
do
	local scenario = "own: a hunter with Aspect of the Cheetah up is not reminded"
	with(scenario, { class = "HUNTER", known = { HAWK, MONKEY, CHEETAH },
		wearing = { { id = CHEETAH } } }, function(ns)
		if not ns.CanCastAnything() then
			fail(scenario, "a hunter with his aspects learned has nothing to cast")
			return
		end
		if mine(ns) then fail(scenario, "offered " .. key(mine(ns)) .. " with Aspect of the Cheetah up") end
		local memory = ns.db.char.ownLast
		if memory and memory.aspect then
			fail(scenario, "Aspect of the Cheetah was remembered as the last aspect: " .. tostring(memory.aspect))
		end
		wear(ns, {})
		if key(mine(ns)) ~= "aspecthawk" then
			fail(scenario, "with no aspect up, offered " .. key(mine(ns)) .. " rather than Aspect of the Hawk")
		end
		wear(ns, { { id = MONKEY } })
		if mine(ns) then fail(scenario, "offered " .. key(mine(ns)) .. " with Aspect of the Monkey up") end
		wear(ns, {})
		if key(mine(ns)) ~= "aspectmonkey" then
			fail(scenario, "with the Monkey dropped, offered " .. key(mine(ns)) .. " rather than the aspect last up")
		end
		ns.Prompt:Refresh()
		if not ns.Prompt:GetButton():IsShown() or macro(ns) ~= "/cast [@player] Aspect of the Monkey" then
			fail(scenario, "the hunter's prompt is not up on his aspect: " .. flat(macro(ns)))
		end
		local broker = Mock.broker
		if broker and broker.OnTooltipShow then
			local lines = {}
			broker.OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = tostring(text) end })
			if not table.concat(lines, " / "):find("Watching your own buffs.", 1, true) then
				fail(scenario, "the launcher tells a hunter " .. table.concat(lines, " / "))
			end
		end
	end)
end

-- ------------------------------------------------------------------ own 8
-- Nothing on yourself in a city or an inn unless "Also in cities and inns" is
-- ticked -- your class's own and your group buff alike -- and nothing in a
-- fight, the pull's own repaint included.
Mock.reset()
do
	local scenario = "own: not reminded while resting unless Also in cities and inns"
	with(scenario, { known = MAGE }, function(ns)
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		if key(mine(ns)) ~= "intellect" then
			fail(scenario, "SKIPPED -- missing both, you were not offered your Intellect first: " .. key(mine(ns)))
			return
		end
		IsResting = function() return true end
		if mine(ns) then fail(scenario, "in a city you were offered " .. key(mine(ns))) end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("your own buffs: held back -- you are in a city or an inn", 1, true) then
			fail(scenario, "/manners debug does not say why nothing is offered in a city: " .. flat(said()))
		end
		local cities = findOption(ns.optionsTable, "ownCities")
		if not (cities and cities.set) then
			fail(scenario, "there is no Also in cities and inns")
			return
		end
		if cities.get() ~= false then fail(scenario, "Also in cities and inns starts ticked") end
		cities.set({ "ownCities" }, true)
		if key(mine(ns)) ~= "intellect" then
			fail(scenario, "with Also in cities and inns ticked, in a city you were offered " .. key(mine(ns)))
		end
		Mock.playerHeld = nil
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		if key(mine(ns)) ~= "frostarmor" then
			fail(scenario, "with Also in cities and inns ticked, in a city no armor was offered: " .. key(mine(ns)))
		end
	end)
end

Mock.reset()
do
	local scenario = "own: not reminded in combat"
	with(scenario, { known = MAGE }, function(ns)
		if not mine(ns) then
			fail(scenario, "SKIPPED -- not offered an armor out of a fight")
			return
		end
		Mock.inCombat = true
		if mine(ns) then fail(scenario, "in a fight you were offered " .. key(mine(ns))) end
		Mock.inCombat = false
		-- The pull's own repaint, before the lockdown starts.
		UnitAffectingCombat = function(unit) return unit == "player" end
		if mine(ns) then fail(scenario, "on the pull you were offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ own 9
-- The press casts on you by [@player] and the spell's own name, with nothing
-- said whatever the speech settings, and files nothing; the game naming
-- another spell instead is not the armor.
Mock.reset()
do
	local scenario = "own: the macro casts on you with no speech"
	with(scenario, { known = MAGE }, function(ns)
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
		speech.phrases = "Here you are, {name}."
		ns.db.char.ledger = nil
		ns.Ledger.Load()
		ns.Prompt:InvalidateMacro()
		ns.Prompt:Refresh()
		if macro(ns) ~= "/cast [@player] Ice Armor" then
			fail(scenario, "the macro reads " .. flat(macro(ns)))
		end
		local pressed = H.pressButton(ns)
		if not (pressed and ns.pendingClick and ns.pendingClick.onSelf) then
			fail(scenario, "SKIPPED -- the press on you did not go out: " .. flat(pressed))
			return
		end
		Mock.printed = {}
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", ME, "Cast-own-1", 116)
		if not said():find("Frostbolt", 1, true) then
			fail(scenario, "a Frostbolt going out was taken for the armor: " .. flat(said()))
		end
		Mock.advance(30)
		ns.pendingClick = nil
		wipe(ns.tried)
		wipe(ns.refusals)
		ns.Prompt:Refresh()
		H.pressButton(ns)
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", ME, "Cast-own-2", ICE1)
		if ns.pendingClick then fail(scenario, "the press was never settled") end
		local lead = tostring(ns.Prompt:Regions().name:GetText())
		if not lead:find("yourself", 1, true) then fail(scenario, "the panel reads " .. lead) end
		if not ns.IsBlocked(ME, "frostarmor") then
			fail(scenario, "the armor was not given its retry cooldown after the press")
		end
		-- Your auras still read no armor for a moment after the cast.
		if mine(ns) then fail(scenario, "offered the armor again right after the press: " .. key(mine(ns))) end
		local s = ns.db.char.ledger
		if s and #s.entries > 0 then
			fail(scenario, "the press wrote a " .. tostring(s.entries[1].kind) .. " row in the ledger")
		end
	end)
end

-- ------------------------------------------------------------------ own 10
-- A right-press skips you for now, as it does for your group buff, and
-- shift-right-press switches Myself off.
Mock.reset()
do
	local scenario = "own: right-click skips your own buff"
	with(scenario, { known = MAGE }, function(ns)
		ns.Prompt:Refresh()
		if key(ns.Prompt:Showing()) ~= "frostarmor" then
			fail(scenario, "SKIPPED -- the prompt is not on your armor: " .. key(ns.Prompt:Showing()))
			return
		end
		Mock.printed = {}
		H.pressButton(ns, "RightButton")
		if not said():find("skipping your own buff for now.", 1, true) then
			fail(scenario, "the skip reads " .. flat(said()))
		end
		if mine(ns) then fail(scenario, "still offered " .. key(mine(ns)) .. " right after a skip") end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("your own buffs: held back -- skipped for now.", 1, true) then
			fail(scenario, "/manners debug does not say you are skipped: " .. flat(said()))
		end
		Mock.advance(60)
		wipe(ns.tried)
		ns.Prompt:Refresh()
		if not mine(ns) then
			fail(scenario, "SKIPPED -- not offered again after the skip ran out")
			return
		end
		IsShiftKeyDown = function() return true end
		Mock.advance(1)
		H.pressButton(ns, "RightButton")
		IsShiftKeyDown = nil
		if ns.db.profile.sources.self ~= false then
			fail(scenario, "shift-right-click on your armor left Myself on")
		end
		if mine(ns) then fail(scenario, "with Myself off, still offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ own 11
-- The options: under "Myself" on Who to buff, only your class's families you
-- know -- a dropdown for a choice, a checkbox for a spell alone -- then Also
-- in cities and inns. A hunter, with nothing for anybody else, sees Myself
-- and nothing else of the tab, and Start here's steps for his prompt.
Mock.reset()
do
	local scenario = "own: the options show only your class's families"
	with(scenario, { known = MAGE }, function(ns)
		local root = ns.optionsTable
		local a = root and root.args.who and root.args.who.args
		if not a then
			fail(scenario, "there is no Who to buff tab")
			return
		end
		local header, armor, cities = a.myselfHeader, a.own_armor, a.ownCities
		if not (header and armor and cities and a.self) then
			fail(scenario, "Myself is missing its heading, the armor or Also in cities and inns")
			return
		end
		if not (header.order < a.self.order and a.self.order < armor.order and armor.order < cities.order
			and cities.order < a.groupHeader.order) then
			fail(scenario, "Myself is not heading, switch, armor, then cities, above My group and raid")
		end
		if armor.hidden() then fail(scenario, "a mage's armor is hidden") end
		for _, other in ipairs({ "own_innerfire", "own_aura", "own_aspect", "own_righteousfury", "own_omen" }) do
			if a[other] and not a[other].hidden() then fail(scenario, other .. " is shown to a mage") end
		end
		local values = armor.values()
		local names = {}
		for k in pairs(values) do names[#names + 1] = k end
		table.sort(names)
		if table.concat(names, ",") ~= "auto,frostarmor,magearmor,off" then
			fail(scenario, "the armor dropdown offers " .. table.concat(names, ","))
		end
		if values.frostarmor ~= "Ice Armor" or values.magearmor ~= "Mage Armor" then
			fail(scenario, "the armor dropdown names " .. tostring(values.frostarmor) .. " and " .. tostring(values.magearmor))
		end
		local order = table.concat(armor.sorting(), ",")
		if order ~= "auto,frostarmor,magearmor,off" then fail(scenario, "the armor dropdown runs " .. order) end
		ns.db.profile.sources.self = false
		if not armor.disabled() then fail(scenario, "the armor dropdown stays live with Myself off") end
		ns.db.profile.sources.self = true
		-- Mage Armor not learned yet: not a choice.
		know(list(INTELLECT, FROST))
		ns.Guard("probe", ns.ProbeCapabilities)
		if armor.values().magearmor then fail(scenario, "Mage Armor is a choice for a mage who has not learned it") end
	end)
	-- A priest's Inner Fire alone is a checkbox.
	with(scenario, { class = "PRIEST", known = { 10938, INNER_FIRE } }, function(ns)
		local fire = findOption(ns.optionsTable, "own_innerfire")
		if not (fire and fire.type == "toggle" and not fire.hidden()) then
			fail(scenario, "a priest's Inner Fire is not a checkbox on Who to buff")
			return
		end
		if fire.name() ~= "Inner Fire" or fire.get() ~= true then
			fail(scenario, "Inner Fire reads " .. tostring(fire.name()) .. ", ticked " .. tostring(fire.get()))
		end
		fire.set({ "own_innerfire" }, false)
		if ns.db.profile.ownBuffs.pick.innerfire ~= "off" then fail(scenario, "unticking Inner Fire does not switch it off") end
		local weak = findOption(ns.optionsTable, "own_touchofweakness")
		if weak and not weak.hidden() then fail(scenario, "a human priest is shown Touch of Weakness") end
	end)
	-- A hunter: Myself and nothing else on Who to buff, and his prompt's steps.
	with(scenario, { class = "HUNTER", known = { HAWK, MONKEY } }, function(ns)
		local root = ns.optionsTable
		local who = root.args.who
		if who.hidden() then
			fail(scenario, "Who to buff is hidden from a hunter with his aspects learned")
			return
		end
		for _, other in ipairs({ "owed", "group", "choice", "neverAdd", "sourcesHeader" }) do
			local control = who.args[other]
			if control and not (control.hidden and control.hidden()) then
				fail(scenario, other .. " is shown to a hunter")
			end
		end
		if who.args.self.hidden() or who.args.own_aspect.hidden() then
			fail(scenario, "Myself or the aspect is hidden from a hunter")
		end
		local makeMacro = findOption(root, "makeMacro")
		local summary = findOption(root, "quickWhoSummary")
		if makeMacro.hidden() or summary.hidden() then
			fail(scenario, "Start here hides a hunter's prompt steps")
		end
		local text = tostring(summary.name())
		if not text:find("reminds you of your own: Aspect", 1, true) then
			fail(scenario, "Start here tells a hunter " .. text)
		end
		if not findOption(root, "quickWho").hidden() then
			fail(scenario, "Start here offers a hunter the choice of who to buff")
		end
	end)
end

-- ------------------------------------------------------------------ own 12
-- The saved settings: the picks and "Also in cities and inns" kept as they
-- are, nonsense put back to Automatic (or off), a family nobody has dropped,
-- and a settings string carrying them both ways.
Mock.reset()
do
	local scenario = "own: saved-settings repair keeps and restores the new keys"
	with(scenario, { known = MAGE }, function(ns)
		local own = ns.db.profile.ownBuffs
		own.pick.armor, own.pick.aura, own.inCities = "magearmor", "off", true
		ns.ClampSettings()
		if own.pick.armor ~= "magearmor" or own.pick.aura ~= "off" or own.inCities ~= true then
			fail(scenario, "the repair changed good settings: " .. tostring(own.pick.armor) .. ", "
				.. tostring(own.pick.aura) .. ", " .. tostring(own.inCities))
		end
		own.pick.armor, own.pick.aspect, own.pick.nonsense, own.inCities = "banana", "frostarmor", "auto", "yes"
		ns.ClampSettings()
		if own.pick.armor ~= "auto" or own.pick.aspect ~= "auto" then
			fail(scenario, "nonsense picks were kept: " .. tostring(own.pick.armor) .. ", " .. tostring(own.pick.aspect))
		end
		if own.pick.nonsense ~= nil then fail(scenario, "a family nobody has was kept") end
		if own.inCities ~= false then fail(scenario, "a nonsense Also in cities and inns was kept: " .. tostring(own.inCities)) end
		own.pick.innerfire = nil
		ns.ClampSettings()
		if own.pick.innerfire ~= "auto" then fail(scenario, "a family missing its pick was not given Automatic") end
		ns.db.profile.ownBuffs = 7
		ns.ClampSettings()
		own = ns.db.profile.ownBuffs
		if type(own) ~= "table" or own.pick.armor ~= "auto" or own.inCities ~= false then
			fail(scenario, "a broken section was not put back")
			return
		end

		own.pick.armor, own.inCities = "magearmor", true
		local text = tostring(ns.ExportSettings())
		if not (text:find("ownBuffs.pick.armor=magearmor", 1, true) and text:find("ownBuffs.inCities=1", 1, true)) then
			fail(scenario, "a settings string leaves them out: " .. text)
		end
		own.pick.armor, own.inCities = "off", false
		ns.ImportSettings(text)
		own = ns.db.profile.ownBuffs
		if own.pick.armor ~= "magearmor" or own.inCities ~= true then
			fail(scenario, "importing did not put them back: " .. tostring(own.pick.armor) .. ", " .. tostring(own.inCities))
		end
	end)
end

-- ------------------------------------------------------------------ own 13
-- A wrong id fails safe: a spell whose ids this client does not have, or that
-- is known only by an id the table lacks, is never offered, never shown, and
-- never nags.
Mock.reset()
do
	local scenario = "own: a wrong or unknown id never offers anything"
	local ids = list(FROST, ICE1, 7320, 10219, 10220, MAGE_ARMOR, 22782, 22783)
	with(scenario, { known = list(INTELLECT, ids) }, function(ns)
		if not mine(ns) then
			fail(scenario, "SKIPPED -- the armor is not offered with its ids working")
			return
		end
		Mock.unknownSpells = {}
		for _, id in ipairs(ids) do Mock.unknownSpells[id] = true end
		ns.Guard("probe", ns.ProbeCapabilities)
		if mine(ns) then fail(scenario, "an armor whose ids the client does not have was offered: " .. key(mine(ns))) end
		local armor = findOption(ns.optionsTable, "own_armor")
		if armor and not armor.hidden() then fail(scenario, "an armor the client does not have is shown") end
		Mock.unknownSpells = nil
		-- Known by an id the table does not list: not known at all.
		know({ INTELLECT, 99001 })
		ns.Guard("probe", ns.ProbeCapabilities)
		if mine(ns) then fail(scenario, "a spell known only by an unlisted id was offered: " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ own 14
-- One entry for you at a time: your group buff first, then your class's own
-- in the table's order; and a timed buff of your own offered as a top-up when
-- it runs low with top-ups on, the one you wear.
Mock.reset()
do
	local scenario = "own: one entry for you, your group buff first, then a top-up"
	with(scenario, { known = MAGE }, function(ns)
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		local count = 0
		for _, entry in ipairs(ns.BuildQueue()) do
			if entry.reason == "self" then count = count + 1 end
		end
		if count ~= 1 then fail(scenario, count .. " entries for you at once") end
		if key(mine(ns)) ~= "intellect" then
			fail(scenario, "missing both, you were offered " .. key(mine(ns)) .. " before your Intellect")
		end
		Mock.playerHeld = nil
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		wear(ns, { { id = MAGE_ARMOR, left = 60 } })
		if mine(ns) then fail(scenario, "a minute of Mage Armor was topped up with top-ups off") end
		ns.db.profile.filters.whenBuffed = "refresh"
		local me = mine(ns)
		if key(me) ~= "magearmor" or me.known ~= true or type(me.remaining) ~= "number" then
			fail(scenario, "a minute of Mage Armor with top-ups on offered " .. key(me) .. ", known "
				.. tostring(me and me.known))
		elseif ns.Prompt:ReasonText(me) ~= "expires in 1m" then
			fail(scenario, "the top-up reads " .. tostring(ns.Prompt:ReasonText(me)))
		end
	end)
end

-- ------------------------------------------------------------------ own 15
-- /manners debug and the Diagnostics tab say what each of your own buffs is
-- doing, in the queue's own words.
Mock.reset()
do
	local scenario = "own: debug and Diagnostics say what Myself is doing"
	with(scenario, { known = MAGE, wearing = { { id = MAGE_ARMOR, left = 1800 } } }, function(ns)
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("Armor: Mage Armor is up.", 1, true) then
			fail(scenario, "/manners debug does not say the armor is up: " .. flat(said()))
		end
		wear(ns, {})
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("Armor: none up -- Mage Armor is the one to cast.", 1, true) then
			fail(scenario, "/manners debug does not say which armor is due: " .. flat(said()))
		end
		local diag = findOption(ns.optionsTable, "ownDiag")
		local text = diag and not diag.hidden() and tostring(diag.name()) or ""
		if not text:find("Armor: none up -- Mage Armor is the one to cast.", 1, true) then
			fail(scenario, "Diagnostics does not say which armor is due: " .. flat(text))
		end
		Mock.inCombat = true
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		Mock.inCombat = false
		if not said():find("your own buffs: held back -- you are in a fight.", 1, true) then
			fail(scenario, "/manners debug does not say a fight holds you back: " .. flat(said()))
		end
	end)
end

-- ------------------------------------------------------------------ own 16
-- Not offered while the game says it cannot be cast: a druid in cat form, a
-- priest in Shadowform, a mage without the mana. A client that will not say
-- offers it.
Mock.reset()
do
	local scenario = "own: not offered what the game says cannot be cast"
	with(scenario, { known = MAGE }, function(ns)
		if not mine(ns) then
			fail(scenario, "SKIPPED -- not offered an armor to begin with")
			return
		end
		rawset(_G, "C_Spell", nil)
		local base = C_Spell
		rawset(_G, "C_Spell", setmetatable({ IsSpellUsable = function() return false end }, { __index = base }))
		if mine(ns) then fail(scenario, "offered " .. key(mine(ns)) .. " though the game says it cannot be cast") end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("Armor: the game says Ice Armor cannot be cast right now.", 1, true) then
			fail(scenario, "/manners debug does not say the armor cannot be cast: " .. flat(said()))
		end
		rawset(_G, "C_Spell", setmetatable({ IsSpellUsable = function() return nil end }, { __index = base }))
		if not mine(ns) then fail(scenario, "a client that will not say kept the armor back") end
	end)
end
