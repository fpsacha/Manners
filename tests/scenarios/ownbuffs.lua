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

-- What a press on yourself arms: you targeted by name, the spell, and your
-- target handed back -- the one shape known to work on WoW Forever, where
-- conditional targeting does not resolve and [@player] was never tried.
local function onMe(ns, spell)
	return "/target " .. ns.TargetName(ns.UnitFullName("player")) .. "\n/cast " .. spell .. "\n/targetlasttarget"
end

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
-- macro casts the name of the best rank you know, not the first rank's --
-- and learning it at the trainer re-arms the prompt already up on the armor,
-- through the game's own SPELLS_CHANGED, with nothing else moving.
Mock.reset()
do
	local scenario = "own: Frost Armor is cast by name at low level and Ice Armor once known"
	-- What a trainer visit looks like from here: the spellbook changes, the
	-- probe runs (rate-limited, so the clock moves first), and the next tick
	-- repaints the prompt, which never left the armor.
	local function train(ns, ids)
		know(ids)
		Mock.advance(10)
		ns.addon:SPELLS_CHANGED()
		Mock.runTimers(6)
		ns.Prompt:Refresh()
	end
	with(scenario, { known = { INTELLECT, 168 } }, function(ns)
		ns.Prompt:Refresh()
		if macro(ns) ~= onMe(ns, "Frost Armor") then
			fail(scenario, "a mage knowing only Frost Armor rank 1 arms " .. flat(macro(ns)))
		end
		if key(ns.Prompt:Showing()) ~= "frostarmor" then
			fail(scenario, "SKIPPED -- the prompt is not on the armor: " .. key(ns.Prompt:Showing()))
			return
		end
		train(ns, { INTELLECT, 168, 7300, 7301, ICE1 })
		if key(ns.Prompt:Showing()) ~= "frostarmor" then
			fail(scenario, "SKIPPED -- the prompt left the armor at the trainer: " .. key(ns.Prompt:Showing()))
		elseif macro(ns) ~= onMe(ns, "Ice Armor") then
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
		if macro(ns) ~= onMe(ns, "Demon Skin") then
			fail(scenario, "a warlock knowing Demon Skin arms " .. flat(macro(ns)))
		end
		train(ns, { 5697, 687, 696, 706 })
		if macro(ns) ~= onMe(ns, "Demon Armor") then
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
		if not ns.Prompt:GetButton():IsShown() or macro(ns) ~= onMe(ns, "Aspect of the Monkey") then
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
-- The press targets you by name and casts the spell's own name, with nothing
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
		if macro(ns) ~= onMe(ns, "Ice Armor") then
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

-- ------------------------------------------------------------------ own 17
-- A shaman's shields are one family: only one Elemental Shield may be up on
-- Forever, so a Restoration shaman wearing Water Shield has chosen, and is
-- never told to put Lightning Shield over it. The one up last is the one
-- that comes back, and a shaman who never learned Water Shield is not
-- offered it.
Mock.reset()
do
	local scenario = "own: a shaman wearing Water Shield is not told to cast Lightning Shield"
	local LIGHTNING, WATER = { 324, 325 }, 408510
	with(scenario, { class = "SHAMAN", known = list(LIGHTNING, WATER),
		wearing = { { id = WATER, left = 600 } } }, function(ns)
		if mine(ns) then
			fail(scenario, "wearing Water Shield, you were offered " .. key(mine(ns)))
		end
		wear(ns, {})
		if key(mine(ns)) ~= "watershield" then
			fail(scenario, "with the Water Shield gone, you were offered " .. key(mine(ns))
				.. " rather than the shield up last")
		end
		ns.Prompt:Refresh()
		if macro(ns) ~= onMe(ns, "Water Shield") then
			fail(scenario, "the prompt arms " .. flat(macro(ns)))
		end
		local shield = findOption(ns.optionsTable, "own_shield")
		local values = shield and shield.values and shield.values() or {}
		if not (shield and not shield.hidden() and shield.name() == "Shield")
			or values.watershield ~= "Water Shield" or values.lightningshield ~= "Lightning Shield" then
			fail(scenario, "the shield dropdown reads " .. tostring(values.lightningshield) .. " / "
				.. tostring(values.watershield))
		end
		wear(ns, { { id = 325, left = 600 } })
		if mine(ns) then fail(scenario, "wearing Lightning Shield, you were offered " .. key(mine(ns))) end
	end)
	-- Never learned: Lightning Shield, and no Water Shield to choose.
	with(scenario, { class = "SHAMAN", known = LIGHTNING }, function(ns)
		if key(mine(ns)) ~= "lightningshield" then
			fail(scenario, "a shaman with no shield up was offered " .. key(mine(ns)))
		end
		local shield = findOption(ns.optionsTable, "own_shield")
		if shield and shield.values().watershield then
			fail(scenario, "Water Shield is a choice for a shaman who has not learned it")
		end
	end)
end

-- ------------------------------------------------------------------ own 18
-- A warlock's one buff for others is Unending Breath, which is nothing to be
-- reminded of on dry land: missing both, he is offered his Demon Skin, never
-- the water breathing -- which is still offered to everybody else.
Mock.reset()
do
	local scenario = "own: a warlock missing both is offered Demon Skin, never Unending Breath"
	with(scenario, { class = "WARLOCK", known = { 5697, 687 } }, function(ns)
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		if key(mine(ns)) ~= "demonarmor" then
			fail(scenario, "missing both, a warlock was offered " .. key(mine(ns)) .. " rather than Demon Skin")
		end
		local offered = false
		for _, buff in ipairs(ns.CastableBuffs()) do
			if buff.key == "breath" then offered = true end
		end
		if not offered then fail(scenario, "Unending Breath is no longer offered to anybody else") end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if not said():find("Demon Skin: none up -- Demon Skin is the one to cast.", 1, true)
			or said():find("comes first", 1, true)
			or said():find("nothing you cast goes on yourself alone", 1, true) then
			fail(scenario, "/manners debug does not say Demon Skin is the one: " .. flat(said()))
		end
		wear(ns, { { id = 687, left = 1800 } })
		if mine(ns) then fail(scenario, "with Demon Skin up, a warlock was offered " .. key(mine(ns))) end
	end)
end

-- ------------------------------------------------------------------ own 19
-- Before Mage Armor is learned, Automatic has one armor for everywhere, and
-- says so the same way inside a dungeon and out -- never "outside dungeons
-- and raids", which promises something else inside.
Mock.reset()
do
	local scenario = "own: Automatic says the same inside and out before Mage Armor"
	with(scenario, { known = list(INTELLECT, FROST) }, function(ns)
		local armor = findOption(ns.optionsTable, "own_armor")
		local want = "Automatic (Frost Armor, until you have put one up)"
		for _, place in ipairs({ { false }, { true, "party" }, { true, "raid" } }) do
			IsInInstance = function() return place[1], place[2] end
			local where = place[1] and ("in a " .. place[2]) or "outside"
			local auto = armor and armor.values and armor.values().auto
			if auto ~= want then fail(scenario, where .. " Automatic reads " .. tostring(auto)) end
			if key(mine(ns)) ~= "frostarmor" then fail(scenario, where .. " you were offered " .. key(mine(ns))) end
		end
	end)
end

-- ------------------------------------------------------------------ own 20
-- "The one you had up last" is written from your auras whenever they change,
-- in a fight and in town too, where nothing is offered to you: the paladin who
-- switched to Concentration Aura in a fight and died is reminded of
-- Concentration, and the options page in a city names the aura worn there.
Mock.reset()
do
	local scenario = "own: the one up last is remembered in a fight and in town"
	local PALADIN = { 19740, DEVOTION, RETRIBUTION, CONCENTRATION }
	with(scenario, { class = "PALADIN", known = PALADIN, wearing = { { id = DEVOTION } } }, function(ns)
		-- Whatever the lifecycle's own aura event left to read, read now.
		ns.addon:Tick()
		if ns.db.char.ownLast.aura ~= "devotionaura" then
			fail(scenario, "SKIPPED -- Devotion Aura up was not remembered: " .. tostring(ns.db.char.ownLast.aura))
			return
		end
		-- The fight: nothing is offered you, and the aura changes under it.
		Mock.inCombat = true
		wear(ns, { { id = CONCENTRATION } })
		ns.addon:UNIT_AURA(nil, "player")
		ns.addon:Tick()
		if ns.db.char.ownLast.aura ~= "concentrationaura" then
			fail(scenario, "Concentration Aura put up in a fight was not remembered: "
				.. tostring(ns.db.char.ownLast.aura))
		end
		-- Dead, the aura gone, the fight over.
		Mock.inCombat = false
		wear(ns, {})
		ns.addon:UNIT_AURA(nil, "player")
		ns.addon:Tick()
		if key(mine(ns)) ~= "concentrationaura" then
			fail(scenario, "after the fight you were offered " .. key(mine(ns)) .. " rather than the aura the fight had up")
		end
		-- A city: nothing is offered, and the aura worn there is remembered.
		IsResting = function() return true end
		wear(ns, { { id = RETRIBUTION } })
		ns.addon:UNIT_AURA(nil, "player")
		ns.addon:Tick()
		if ns.db.char.ownLast.aura ~= "retributionaura" then
			fail(scenario, "Retribution Aura put up in a city was not remembered: " .. tostring(ns.db.char.ownLast.aura))
		end
		local aura = findOption(ns.optionsTable, "own_aura")
		local auto = aura and aura.values and aura.values().auto
		if auto ~= "Automatic (Retribution Aura, the one you had up last)" then
			fail(scenario, "in a city Automatic reads " .. tostring(auto))
		end
	end)
end

-- ------------------------------------------------------------------ own 21
-- While your group buff is the one on the prompt, /manners debug and the
-- Diagnostics tab say so above the armor's line, which would otherwise call
-- the armor the one to cast while the prompt reads Arcane Intellect.
Mock.reset()
do
	local scenario = "own: debug says your group buff comes first"
	with(scenario, { known = MAGE }, function(ns)
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		if key(mine(ns)) ~= "intellect" then
			fail(scenario, "SKIPPED -- missing both, you were not offered your Intellect: " .. key(mine(ns)))
			return
		end
		local first = "your own Arcane Intellect comes first -- the buffs below wait until it has been cast."
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local text = said()
		local at = text:find(first, 1, true)
		local armor = text:find("Armor: none up -- Ice Armor is the one to cast.", 1, true)
		if not (at and armor and at < armor) then
			fail(scenario, "/manners debug does not say your Intellect comes before the armor: " .. flat(text))
		end
		local diag = findOption(ns.optionsTable, "ownDiag")
		local shown = diag and not diag.hidden() and tostring(diag.name()) or ""
		if not shown:find(first, 1, true) then
			fail(scenario, "Diagnostics does not say your Intellect comes first: " .. flat(shown))
		end
		-- Your Intellect up: the armor is the one, and nothing says otherwise.
		Mock.playerHeld = nil
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		if said():find("comes first", 1, true) then
			fail(scenario, "with your Intellect up, /manners debug still says it comes first")
		end
	end)
end

-- ------------------------------------------------------------------ own 22
-- A class with buffs for others and none of them to offer -- a warlock before
-- Unending Breath, a mage with her Intellect switched off -- still has a
-- prompt, for its own: the launcher says it is watching and lists "You", and
-- the login line and the greeting say what the prompt is for, not "nothing".
Mock.reset()
do
	local scenario = "own: nothing for others, and the launcher and the login say the prompt is yours"
	local function tooltip()
		local broker = Mock.broker
		local lines = {}
		if broker and broker.OnTooltipShow then
			broker.OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = tostring(text) end })
		end
		return table.concat(lines, " / ")
	end
	with(scenario, { class = "WARLOCK", known = { 687 } }, function(ns)
		ns.Prompt:Refresh()
		if not ns.Prompt:GetButton():IsShown() or macro(ns) ~= onMe(ns, "Demon Skin") then
			fail(scenario, "SKIPPED -- a warlock with only Demon Skin has no prompt on it: " .. flat(macro(ns)))
			return
		end
		local text = tooltip()
		if not text:find("Watching your own buffs; nothing is offered to anybody else: no buff learned.", 1, true) then
			fail(scenario, "the launcher tells a warlock with only Demon Skin " .. text)
		end
		if not text:find("On the prompt: |cffffffffYou|r -- Demon Skin, your own buff", 1, true) then
			fail(scenario, "the launcher does not list you on the prompt: " .. text)
		end
		-- The login line, on a fresh install.
		Mock.sv = {}
		local again = load(scenario)
		if not again then return end
		wear(again, {})
		local login = tostring(H.firstLogin(again))
		if not login:find("watching your own buffs; nothing is offered to anybody else: no buff learned.", 1, true) then
			fail(scenario, "the login line tells a warlock with only Demon Skin " .. flat(login))
		end
	end)
	-- A mage with her Intellect switched off: the greeting too.
	with(scenario, { known = MAGE }, function(ns)
		ns.db.profile.buff.skip.intellect = true
		ns.Prompt:Refresh()
		if key(ns.Prompt:Showing()) ~= "frostarmor" then
			fail(scenario, "SKIPPED -- with her Intellect switched off, the prompt is not on her armor: "
				.. key(ns.Prompt:Showing()))
			return
		end
		local off = "nothing is offered to anybody else: every spell you know is switched off under Who to buff."
		local text = tooltip()
		if not text:find("Watching your own buffs; " .. off, 1, true) then
			fail(scenario, "the launcher tells a mage with her Intellect switched off " .. text)
		end
		Mock.sv = {}
		if not H.savedProfile(scenario, function(profile) profile.buff.skip.intellect = true end) then return end
		local again = load(scenario)
		if not again then return end
		wear(again, {})
		local login = tostring(H.firstLogin(again))
		if not login:find("puts your own buffs on a small prompt when none of them is up; " .. off, 1, true)
			or login:find("nothing will be offered to anybody", 1, true) then
			fail(scenario, "the greeting tells a mage with her Intellect switched off " .. flat(login))
		end
		if not login:find("watching your own buffs; " .. off, 1, true) then
			fail(scenario, "the login line tells a mage with her Intellect switched off " .. flat(login))
		end
	end)
end

-- ------------------------------------------------------------------ own 23
-- A warrior has nothing for "Myself": no heading, no switch, no Also in
-- cities and inns. And with Myself off, Also in cities and inns is greyed out
-- like the families under it.
Mock.reset()
do
	local scenario = "own: Myself's heading and cities follow the switch"
	-- AceConfig reads a missing `hidden` or `disabled` as shown and live.
	local function asks(control, field)
		return control ~= nil and type(control[field]) == "function" and control[field]() == true
	end
	with(scenario, { class = "WARRIOR", known = { 6673 } }, function(ns)
		local a = ns.optionsTable.args.who.args
		for _, k in ipairs({ "myselfHeader", "self", "ownCities" }) do
			if not asks(a[k], "hidden") then fail(scenario, k .. " is shown to a warrior") end
		end
	end)
	with(scenario, { known = MAGE }, function(ns)
		local a = ns.optionsTable.args.who.args
		if asks(a.myselfHeader, "hidden") or asks(a.ownCities, "hidden") then
			fail(scenario, "SKIPPED -- a mage is not shown Myself's heading or Also in cities and inns")
			return
		end
		if asks(a.ownCities, "disabled") then fail(scenario, "Also in cities and inns is greyed out with Myself on") end
		ns.db.profile.sources.self = false
		if not asks(a.ownCities, "disabled") then
			fail(scenario, "Also in cities and inns stays live with Myself off")
		end
	end)
end

-- ------------------------------------------------------------------ own 24
-- A hunter's prompt hides while he is mounted when that is ticked, and the
-- launcher sends him to When to offer to change it: the tab is there, with
-- what is about him on it and nothing about other people.
Mock.reset()
do
	local scenario = "own: a hunter has the When to offer tab for his own prompt"
	with(scenario, { class = "HUNTER", known = { HAWK, MONKEY } }, function(ns)
		local when = ns.optionsTable.args.when
		if not when or when.hidden() then
			fail(scenario, "When to offer is hidden from a hunter, whose launcher sends him there")
			return
		end
		local a = when.args
		local function shown(control)
			return control ~= nil and not (type(control.hidden) == "function" and control.hidden())
		end
		if not (shown(a.hideMounted) and shown(a.whenBuffed)) then
			fail(scenario, "a hunter is not shown Hide the prompt while I'm mounted or If they already have it")
		end
		ns.db.profile.filters.whenBuffed = "always"
		for _, k in ipairs({ "manaFloor", "manaNote", "favoursHeader", "favoursNote", "alwaysNote" }) do
			if shown(a[k]) then fail(scenario, k .. " is shown to a hunter") end
		end
		local desc = H.optionText(a.whenBuffed.desc)
		if desc:find("buffed you", 1, true) or not desc:find("Your own buffs", 1, true) then
			fail(scenario, "If they already have it tells a hunter " .. desc)
		end
	end)
end

-- ------------------------------------------------------------------ own 25
-- Burning Crusade Classic shares the vanilla buffs for others, but not the
-- class's own: every family there has a member this table lacks (Molten
-- Armor, Fel Armor, Earth Shield), and one of those up would read as none of
-- the family up and be replaced.
Mock.reset()
do
	local scenario = "own: Burning Crusade has none of the vanilla families"
	Mock.setFlavour("tbc")
	local ns = load(scenario)
	if ns then
		if ns.GetOwnFamilies("MAGE") or next(ns.OWN_BUFFS) ~= nil then
			fail(scenario, "a Burning Crusade client was given the vanilla families of a class's own buffs")
		end
		if not ns.FindBuff("MAGE", "intellect") then
			fail(scenario, "a Burning Crusade client lost the vanilla buffs for others")
		end
	end
	Mock.reset()
	ns = load(scenario)
	if ns and not ns.GetOwnFamilies("MAGE") then
		fail(scenario, "SKIPPED -- Forever has no mage armor either")
	end
end
Mock.reset()

-- A favour from Anna on a nameplate, landing on you in a fight: the setting
-- for own 26 and 27. Hands back her name, and a count of the slots of your
-- aura list read since, or nil once the scenario has said why it cannot run.
local function fightFavour(scenario, ns)
	H.primeAuras(ns)
	if not ns.auraScan.primed then
		fail(scenario, "SKIPPED -- the baseline of your own buffs never settled")
		return nil
	end
	local anna = ns.UnitFullName("nameplate1")
	local api = C_UnitAuras
	local byIndex = api.GetAuraDataByIndex
	local reads = { n = 0 }
	rawset(api, "GetAuraDataByIndex", function(unit, ...)
		if unit == "player" then reads.n = reads.n + 1 end
		return byIndex(unit, ...)
	end)
	Mock.inCombat = true
	Mock.printed = {}
	Mock.extraAura, Mock.extraAuraSpell, Mock.extraAuraSource = 6101, 10938, "nameplate1"
	return anna, reads
end

local function favourLines()
	local n = 0
	for _, line in ipairs(Mock.printed) do
		if line:find("buffed you", 1, true) then n = n + 1 end
	end
	return n
end

-- ------------------------------------------------------------------ own 26
-- In a fight, UNIT_AURA on you comes many times a second, and every walk of
-- your aura list is forty slots behind a pcall apiece. The events only mark a
-- walk due and the tick makes it: four events before a tick are one walk, not
-- four, and the favour that landed among them is filed and said once. A tick
-- with no event since walks nothing, and /manners debug counts both.
Mock.reset()
do
	local scenario = "own: four aura events in a fight and a tick walk your buffs once"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		local anna, reads = fightFavour(scenario, ns)
		if not anna then return end
		local events, walks = ns.auraScan.events, ns.auraScan.walks
		for _ = 1, 4 do
			Mock.advance(0.1)
			ns.addon:UNIT_AURA(nil, "player")
		end
		if reads.n ~= 0 then
			fail(scenario, ("the aura events in a fight walked your buffs themselves: %d slots read"
				.. " before the tick"):format(reads.n))
		end
		ns.addon:Tick()
		if reads.n ~= 40 then
			fail(scenario, ("four aura events and a tick read %d slots of your aura list, not one"
				.. " walk's 40"):format(reads.n))
		end
		if not ns.owed[anna] or favourLines() ~= 1 then
			fail(scenario, ("the favour from the fight was %s and said %d times: %s"):format(
				ns.owed[anna] and "filed" or "not filed", favourLines(), flat(said())))
		end
		Mock.advance(0.4)
		ns.addon:Tick()
		if reads.n ~= 40 then
			fail(scenario, ("a tick with no aura event since walked your buffs again: %d slots read")
				:format(reads.n))
		end
		if ns.auraScan.events - events ~= 4 or ns.auraScan.walks - walks ~= 1 then
			fail(scenario, ("/manners debug counts %d aura events and %d walks for four and one")
				:format(ns.auraScan.events - events, ns.auraScan.walks - walks))
		end
		Mock.printed = {}
		ns.addon:HandleSlash("debug")
		local line = ("%d changes to your auras this session, read in %d walks")
			:format(ns.auraScan.events, ns.auraScan.walks)
		if not said():find(line, 1, true) then
			fail(scenario, "/manners debug does not count the aura events and walks: " .. flat(said()))
		end
	end)
end

-- ------------------------------------------------------------------ own 27
-- A buff that lands after the fight's last tick is walked when the fight
-- ends, before the repaint that takes the combat hold off: by the time that
-- repaint asks who is owed, the favour is filed, and out in the world the
-- prompt offers her as owed rather than as a passer-by. The walk is made out
-- of the fight, but what it finds landed in it, so it is treated as the fight
-- would have treated it: not thanked with an emote, and in a dungeon not said.
local emotes = {}
local function recordEmote(emote, target) emotes[#emotes + 1] = { emote, target } end
for _, case in ipairs({
	{ label = "out in the world", inside = false, kind = "none" },
	{ label = "in a dungeon", inside = true, kind = "party" },
}) do
	Mock.reset()
	local scenario = "own: a favour from the fight's last moments is filed before the repaint after it ("
		.. case.label .. ")"
	local realEmote = rawget(_G, "DoEmote")
	emotes = {}
	rawset(_G, "DoEmote", recordEmote)
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		IsInInstance = function() return case.inside, case.kind end
		ns.db.profile.prompt.thankEmote = true
		local anna, reads = fightFavour(scenario, ns)
		if not anna then return end
		Mock.advance(0.1)
		ns.addon:UNIT_AURA(nil, "player")
		if reads.n ~= 0 or ns.owed[anna] then
			fail(scenario, "SKIPPED -- the aura event in a fight walked your buffs itself")
			return
		end
		-- Who is owed when the fight's end repaints, whichever way it does.
		local prompt = ns.Prompt
		local refresh = prompt.Refresh
		local owedAtRepaint
		prompt.Refresh = function(self, ...)
			if owedAtRepaint == nil then owedAtRepaint = ns.owed[anna] ~= nil end
			return refresh(self, ...)
		end
		Mock.inCombat = false
		local ok, err = pcall(ns.addon.PLAYER_REGEN_ENABLED, ns.addon)
		prompt.Refresh = refresh
		if not ok then
			fail(scenario, "leaving the fight threw: " .. tostring(err))
			return
		end
		if owedAtRepaint == nil then
			fail(scenario, "SKIPPED -- leaving the fight did not repaint the prompt")
		elseif not owedAtRepaint then
			fail(scenario, "the repaint after the fight ran before the favour from its last moments was filed")
		end
		if #emotes > 0 then
			fail(scenario, "the favour from the fight was thanked with an emote after it")
		end
		if case.inside then
			if favourLines() > 0 then
				fail(scenario, "the favour from a dungeon fight was said in chat after it: " .. flat(said()))
			end
			return
		end
		if favourLines() ~= 1 then
			fail(scenario, ("SKIPPED -- the favour was said %d times out in the world: %s")
				:format(favourLines(), flat(said())))
		end
		-- Offered as owed, not as a passer-by, which she would be anyway.
		local showing = prompt:Showing()
		if not (showing and showing.name == anna and showing.reason == "owed") then
			fail(scenario, ("after the fight the prompt shows %s (%s), not %s as owed: %s"):format(
				tostring(showing and showing.name), tostring(showing and showing.reason), anna,
				flat(said())))
		end
	end)
	rawset(_G, "DoEmote", realEmote)
end
Mock.reset()

-- ------------------------------------------------------------------ own 28
-- core2-2 (hunt5-core2.lua) between two ticks of a fight. There the aura
-- events only mark a walk due and the tick makes it (own 26), so a buff that
-- runs out and is put back under its own instance id before the tick is never
-- read gone: the walk finds the number it had, the spell it had and a later
-- end, and the reading before held the same, which is what a refresh looks
-- like. The end that reading saw having gone by is what tells them apart: a
-- cast that ran out was cast again, not refreshed, and that is a favour
-- whether or not it was your last buff. A refresh read before that end is not
-- one, nor when read again after the end it replaced has gone by, nor is the
-- same aura still read with the end it had, nor a buff with no end at all
-- (a toggle, which never runs out) read later with one.
for _, case in ipairs({
	{ label = "beside your other buffs", others = 2, recast = true },
	{ label = "your last buff", others = 0, recast = true },
	{ label = "refreshed before it ran out", others = 2, refresh = true },
	{ label = "still read with the end it had", others = 2 },
	{ label = "no end, then one", others = 2, noEnd = true },
}) do
	local scenario = "own: a buff that runs out and is recast between two fight ticks is a favour ("
		.. case.label .. ")"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" } } }, function(ns)
		-- Anna's Fortitude, on you before the fight and filed as carried.
		Mock.auraCount = case.others
		Mock.extraAura, Mock.extraAuraSpell, Mock.extraAuraSource = 4001, 10938, "nameplate1"
		Mock.extraAuraUntil = case.noEnd and 0 or (Mock.now + 20)
		ns.ResetAuraBaseline()
		H.primeAuras(ns)
		wipe(ns.owed)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline of your own buffs never settled")
			return
		end
		local anna = ns.UnitFullName("nameplate1")
		local ends = Mock.extraAuraUntil
		local api = C_UnitAuras
		local byIndex = api.GetAuraDataByIndex
		local reads = 0
		rawset(api, "GetAuraDataByIndex", function(unit, ...)
			if unit == "player" then reads = reads + 1 end
			return byIndex(unit, ...)
		end)
		Mock.inCombat = true
		Mock.printed = {}
		if case.noEnd then
			-- An end of 0 is none: read later with one, nothing it had ran out.
			Mock.advance(2)
			Mock.extraAuraUntil = Mock.now + 1800
			ns.addon:UNIT_AURA(nil, "player")
			ns.addon:Tick()
			if ns.owed[anna] then
				fail(scenario, "a buff with no end, read later with one, was taken for a recast: " .. flat(said()))
			end
			return
		end
		if case.refresh then
			-- Put back with a later end while the first still had a while to run.
			Mock.advance(2)
			Mock.extraAuraUntil = Mock.now + 1800
			ns.addon:UNIT_AURA(nil, "player")
			ns.addon:Tick()
			if ns.owed[anna] then
				fail(scenario, "a refresh read before the end it replaced was taken for a favour: " .. flat(said()))
				return
			end
			-- And read again once that end has gone by: the reading before saw
			-- the new end, so nothing has run out.
			Mock.advance(ends - Mock.now + 1)
			ns.addon:UNIT_AURA(nil, "player")
			ns.addon:Tick()
			if ns.owed[anna] then
				fail(scenario, "a refresh read again after the end it replaced had gone by was taken for a favour: "
					.. flat(said()))
			end
			return
		end
		-- Its end goes by...
		Mock.advance(ends - Mock.now + 0.5)
		if not case.recast then
			-- ...and the client has not taken it off yet: the same aura, the same end.
			ns.addon:UNIT_AURA(nil, "player")
			ns.addon:Tick()
			if ns.owed[anna] then
				fail(scenario, "the same aura read after its end with the end it had was taken for a favour: "
					.. flat(said()))
			end
			return
		end
		-- ...it runs out, and Anna puts it back under the number it had, all
		-- before the tick.
		Mock.extraAura = false
		ns.addon:UNIT_AURA(nil, "player")
		Mock.advance(0.1)
		Mock.extraAura, Mock.extraAuraUntil = 4001, Mock.now + 1800
		ns.addon:UNIT_AURA(nil, "player")
		if reads ~= 0 then
			fail(scenario, "SKIPPED -- the aura events in the fight walked your buffs themselves")
			return
		end
		ns.addon:Tick()
		if not ns.owed[anna] then
			fail(scenario, "the buff that ran out and was recast under its own number before the tick"
				.. " was not taken for a favour: " .. flat(said()))
		elseif favourLines() ~= 1 then
			fail(scenario, ("the favour recast between two fight ticks was said %d times: %s")
				:format(favourLines(), flat(said())))
		end
	end)
end

-- ------------------------------------------------------------------ own 29
-- /manners debug sets the changes to your auras beside the walks of your aura
-- list they cost: one each out of a fight, one a tick in a fight (own 26).
-- Only a walk some change asked for is counted, so the walks never outnumber
-- the changes they sit beside: the ones a login and the settle timer make of
-- their own accord are nobody's.
do
	local scenario = "own: /manners debug counts only the walks a change to your auras asked for"
	with(scenario, {}, function(ns)
		H.primeAuras(ns)
		local events, walks = ns.auraScan.events, ns.auraScan.walks
		-- A reload's walk and the settle timer's after it: no change asked.
		ns.addon:PLAYER_ENTERING_WORLD(nil, false, true)
		Mock.runTimers(5)
		if not ns.auraScan.primed then
			fail(scenario, "SKIPPED -- the baseline of your own buffs never settled after the reload")
			return
		end
		if ns.auraScan.walks ~= walks then
			fail(scenario, ("a walk no change to your auras asked for was counted: %d walks, and no change")
				:format(ns.auraScan.walks - walks))
		end
		-- Out of a fight each change walks at once, and each walk is counted.
		for _ = 1, 3 do
			Mock.advance(1)
			ns.addon:UNIT_AURA(nil, "player")
		end
		if ns.auraScan.events - events ~= 3 or ns.auraScan.walks - walks ~= 3 then
			fail(scenario, ("an aura event out of a fight was not counted as a walk: %d changes and %d walks,"
				.. " for three and three"):format(ns.auraScan.events - events, ns.auraScan.walks - walks))
		end
	end)
end
Mock.reset()
