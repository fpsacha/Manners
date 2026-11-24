-- Manners -- the prompt's own key casting a spell of your choosing in a fight.
--
-- Why it is a separate route. A fight locks the prompt: what it holds at the
-- pull is what it holds until the fight ends, and its key keeps to buffs
-- (CLAUDE.md, Combat). A second line in the prompt's macro could not carry a
-- shield safely: with nobody to buff the prompt holds no macro at all, the
-- hide snippet strips it, the rota rewrites it at every press, the buff lines
-- ahead of it start the global cooldown, and the bar macro cannot copy it.
--
-- What it does instead. At the pull (PLAYER_REGEN_DISABLED, still out of the
-- lockdown) Lua points the prompt's own bound keys at a secure button of its
-- own, MannersFightKey, with an override binding; at the release it takes the
-- override away. The prompt, its macro, the hold, the hide snippet, the rota
-- and the bar macro are all left as they are, and a click on the prompt still
-- buffs and steps the rota. The button is never shown: nothing of this is on
-- the screen, ever, so nothing can pop up for fun. No override is set or
-- cleared under the lockdown, and a /reload or a login inside a fight never
-- fires the pull, so that fight's key keeps to buffs.

local _, ns = ...
local L = ns.L
local InCombatLockdown = _G.InCombatLockdown
local caps = ns.caps

local FightKey = {}
ns.FightKey = FightKey

local NAME = "MannersFightKey"
-- The prompt's key, as Bindings.xml declares it (Options/Start.lua, Setup).
local PROMPT_COMMAND = "CLICK MannersPrompt:LeftButton"

---------------------------------------------------------------------------
-- The spells
---------------------------------------------------------------------------
-- SPELLS[family][class] = ordered rows { key, id, self }. The id is rank 1:
-- on the older clients the lower ranks stay known, so ns.SpellKnown answers
-- for it, and /cast by plain name casts the top rank. `self` marks a spell
-- that only lands on you. Lay on Hands, Divine Shield, Shield Wall and Ice
-- Block are left out: too big for one key. Every id is the client's own
-- SpellName at the builds .claude/docs/data-sources.md cites (1463 is Incanter's Ward on Mists,
-- so Mana Shield stays out of it; Cloak of Shadows is not in Classic Era's or
-- Forever's data, so it is never known there).
local function r(key, id, solo) return { key = key, id = id, self = solo == true } end

local OLD = {
	PRIEST = { r("shield", 17), r("renew", 139), r("flash", 2061) },
	MAGE = { r("barrier", 11426, true), r("manashield", 1463, true) },
	DRUID = { r("rejuv", 774), r("barkskin", 22812, true) },
	PALADIN = { r("flash", 19750), r("divprot", 498, true) },
	SHAMAN = { r("lhw", 8004) },
	WARLOCK = { r("shadowward", 6229, true) },
	WARRIOR = { r("shieldblock", 2565, true), r("bloodrage", 2687, true) },
	ROGUE = { r("evasion", 5277, true), r("cloak", 31224, true) },
	HUNTER = { r("deterrence", 19263, true) },
}

local MISTS = {
	PRIEST = { r("shield", 17), r("renew", 139), r("flash", 2061) },
	MAGE = { r("barrier", 11426, true) },
	DRUID = { r("rejuv", 774), r("barkskin", 22812, true) },
	PALADIN = { r("wog", 85673), r("flash", 19750), r("divprot", 498, true) },
	SHAMAN = { r("surge", 8004) },
	WARLOCK = { r("unending", 104773, true) },
	WARRIOR = { r("shieldblock", 2565, true), r("shieldbarrier", 112048, true) },
	ROGUE = { r("evasion", 5277, true), r("cloak", 31224, true) },
	HUNTER = { r("deterrence", 19263, true) },
	DEATHKNIGHT = { r("ibf", 48792, true), r("ams", 48707, true) },
	MONK = { r("expel", 115072, true), r("fortbrew", 115203, true) },
}

local MAINLINE = {
	PRIEST = { r("shield", 17), r("renew", 139), r("flash", 2061) },
	MAGE = { r("barrier", 11426, true), r("prismatic", 235450, true), r("blazing", 235313, true) },
	DRUID = { r("rejuv", 774), r("regrowth", 8936), r("barkskin", 22812, true) },
	PALADIN = { r("wog", 85673), r("flash", 19750), r("divprot", 498, true) },
	SHAMAN = { r("surge", 8004), r("astral", 108271, true) },
	WARLOCK = { r("unending", 104773, true), r("darkpact", 108416, true) },
	WARRIOR = { r("ignorepain", 190456, true), r("shieldblock", 2565, true) },
	ROGUE = { r("crimson", 185311, true), r("evasion", 5277, true), r("cloak", 31224, true) },
	HUNTER = { r("exhil", 109304, true), r("turtle", 186265, true) },
	DEATHKNIGHT = { r("ibf", 48792, true), r("ams", 48707, true) },
	MONK = { r("vivify", 116670), r("expel", 322101, true), r("fortbrew", 115203, true) },
	DEMONHUNTER = { r("blur", 198589, true) },
	EVOKER = { r("verdant", 360995), r("scales", 363916, true) },
}

FightKey.SPELLS = { old = OLD, mists = MISTS, mainline = MAINLINE }

local FAMILY = { camelot = "old", vanilla = "old", tbc = "old", mists = "mists", mainline = "mainline" }

local function Rows()
	local flavour = ns.Flavour and ns.Flavour.flavour
	local byClass = FightKey.SPELLS[FAMILY[flavour] or "old"]
	local class = caps.class
	return class and byClass[class] or nil
end

-- What this character can pick, kept on caps (every probe empties it, so a
-- spell learned or lost is asked again): "none" first, then each row whose
-- spell is known and has a name to cast by, with the spell's own name and
-- icon. list[i] = { key, name, self, icon, id }.
local function State()
	local state = caps.fightKey
	if state then return state end
	state = { list = { { key = "none" } }, byKey = {} }
	local rows = Rows()
	if rows then
		for _, row in ipairs(rows) do
			if ns.SpellKnown(row.id) then
				local name = ns.SpellNameFor(row.id)
				if name then
					local icon = ns.safecall(_G.C_Spell and _G.C_Spell.GetSpellTexture, row.id)
					local entry = { key = row.key, name = name, self = row.self, icon = icon, id = row.id }
					state.list[#state.list + 1] = entry
					state.byKey[row.key] = entry
				end
			end
		end
	end
	if caps.class then caps.fightKey = state end
	return state
end

function FightKey.Choices()
	return State().list
end

local function Profile()
	return ns.db and ns.db.profile
end

-- The setting's value for this character's class, a plain field read: the
-- choice is kept per class (prompt.fightKeySpells), since every character
-- shares the one profile and a row key such as "flash" means one spell on a
-- priest and another on a paladin.
local function Raw(db)
	local p = db and db.prompt
	local by = p and p.fightKeySpells
	local class = caps.class
	return type(by) == "table" and class and by[class] or nil
end

local function Spell(db)
	local key = Raw(db)
	if type(key) ~= "string" or key == "none" then return nil end
	return key
end

-- What the options window shows and keeps: this class's choice, "none" when
-- there is none or the character no longer has it in its list.
function FightKey.Value(db)
	db = db or Profile()
	local key = Raw(db)
	if type(key) ~= "string" then return "none" end
	if key ~= "none" and not State().byKey[key] then return "none" end
	return key
end

function FightKey.Set(db, key)
	db = db or Profile()
	local p = db and db.prompt
	local class = caps.class
	if not (p and class) then return end
	if type(p.fightKeySpells) ~= "table" then p.fightKeySpells = {} end
	p.fightKeySpells[class] = key
end

-- The classes whose list holds a row key, for a profile saved before the
-- choice was kept per class.
function FightKey.ClassesFor(key)
	local flavour = ns.Flavour and ns.Flavour.flavour
	local byClass = FightKey.SPELLS[FAMILY[flavour] or "old"]
	local out = {}
	for class, rows in pairs(byClass) do
		for _, row in ipairs(rows) do
			if row.key == key then out[#out + 1] = class end
		end
	end
	return out
end

-- The chosen row, only while the character still knows it. The saved value is
-- never wiped, so a respec back brings it back.
function FightKey.Chosen(db)
	db = db or Profile()
	local key = Spell(db)
	if not key then return nil end
	return State().byKey[key]
end

function FightKey.Applies(db)
	db = db or Profile()
	return db ~= nil and db.enabled == true and FightKey.Chosen(db) ~= nil
end

-- The macro the button holds: the spell and nothing else. One for yourself
-- alone; otherwise (off Forever, where [@unit] does not resolve) the player
-- under the mouse, else a friendly target, else you, or you alone; on Forever
-- a bare cast, which lands on a friendly target, else you.
function FightKey.MacroFor(row, on)
	local macro
	if row.self then
		macro = "/cast " .. row.name
	elseif caps.conditionalTargeting then
		if on == "me" then
			macro = "/cast [@player] " .. row.name
		else
			macro = "/cast [@mouseover,help,nodead][help,nodead][@player] " .. row.name
		end
	else
		macro = "/cast " .. row.name
	end
	if #macro > ns.MACRO_LIMIT then return nil end
	return macro
end

---------------------------------------------------------------------------
-- The button and the override
---------------------------------------------------------------------------
local button, owner
local armedMacro, taken
local dirty, settledSpell, settledOn, settledState, settledEnabled = true, nil, nil, nil, nil

local function PreClick(_, mouse)
	if mouse ~= "LeftButton" then return end
	local pending = ns.pendingClick
	if pending and ns.ExpirePendingClick then ns.ExpirePendingClick(pending, L["you used your fight key instead"]) end
	ns.Trail("press", "pressed: fight key")
end

-- Made the first time it is wanted, out of combat. Never shown: it has no key
-- of its own, only the prompt's, lent to it for a fight.
function FightKey:Create()
	if button or InCombatLockdown() then return end
	button = CreateFrame("Button", NAME, UIParent, "SecureActionButtonTemplate")
	button:RegisterForClicks("AnyDown")
	-- A key press is a down click: without this the client takes it as neither
	-- the action nor a release while ActionButtonUseKeyDown is off (Panel.lua).
	button:SetAttribute("pressAndHoldAction", true)
	for index = 2, 31 do
		if index <= 5 then button:SetAttribute("type" .. index, "none") end
		button:SetAttribute("*type" .. index, "none")
	end
	button:SetScript("PreClick", PreClick)
	button:Hide()
	owner = CreateFrame("Frame")
end

local function Disarm()
	if armedMacro ~= nil and button then
		button:SetAttribute("type1", nil)
		button:SetAttribute("macrotext1", nil)
		button:SetAttribute("type", nil)
		button:SetAttribute("macrotext", nil)
	end
	armedMacro = nil
end

local function Arm(macro)
	if macro == armedMacro and button:GetAttribute("macrotext1") == macro then return end
	button:SetAttribute("type1", "macro")
	button:SetAttribute("macrotext1", macro)
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", macro)
	armedMacro = macro
end

-- At the end of a fight (out of the lockdown): the prompt has its keys back.
function FightKey:Release()
	if InCombatLockdown() then return end
	if owner then _G.ClearOverrideBindings(owner) end
	taken = nil
end

-- From a scan when Wanted says something changed, from the two selects, and
-- from Take. Out of combat only: nothing changes in a fight, so a change made
-- there counts from the next pull.
function FightKey:Refresh()
	if InCombatLockdown() then return end
	if taken then self:Release() end
	local db = Profile()
	if not db then return end
	local row = FightKey.Chosen(db)
	local p = db.prompt
	settledSpell, settledOn, settledState, settledEnabled, dirty = Raw(db), p.fightKeyOn, caps.fightKey, db.enabled, false
	if not (db.enabled == true and row) then
		if button then Disarm() end
		return
	end
	local macro = FightKey.MacroFor(row, p.fightKeyOn)
	if not macro then
		if button then Disarm() end
		return
	end
	if not button then self:Create() end
	if not button then return end
	Arm(macro)
end

-- Whether a scan has anything to do here: plain field reads only; the list of
-- spells is asked about only while one is chosen.
function FightKey:Wanted()
	if InCombatLockdown() then return false end
	if dirty then return true end
	local db = Profile()
	local p = db and db.prompt
	if not p then return false end
	if Raw(db) ~= settledSpell or p.fightKeyOn ~= settledOn or db.enabled ~= settledEnabled then return true end
	if Spell(db) and caps.fightKey ~= settledState then return true end
	return false
end

-- The pull, from PLAYER_REGEN_DISABLED: still out of the lockdown, the last
-- chance to point the prompt's keys at the button.
function FightKey:Take()
	if InCombatLockdown() then return end
	self:Release()
	self:Refresh()
	local db = Profile()
	local row = db and FightKey.Chosen(db)
	if not (row and owner and button and button:GetAttribute("macrotext1")) then return end
	local set = 0
	local keys = { _G.GetBindingKey(PROMPT_COMMAND) }
	for _, key in ipairs(keys) do
		if type(key) == "string" and key ~= "" then
			_G.SetOverrideBindingClick(owner, false, key, NAME, "LeftButton")
			set = set + 1
		end
	end
	if set > 0 then
		taken = row.name
		ns.Trail("fight", "the prompt's key casts " .. row.name .. " this fight")
	end
end

-- The spell the prompt's key casts for this fight, only while the lockdown
-- holds: the panel's line reads it (Prompt/Refresh.lua).
function FightKey:Taken()
	if InCombatLockdown() then return taken end
	return nil
end

function FightKey:Button() return button end

-- For /manners debug.
function ns.FightKeyLines()
	local db = Profile()
	local row = db and FightKey.Chosen(db)
	local keys = type(_G.GetBindingKey) == "function" and { _G.GetBindingKey(PROMPT_COMMAND) } or {}
	return { ("fight key: spell %s; macro %s; prompt keys %d; taken %s; shown %s"):format(
		row and row.name or "none",
		tostring(button and button:GetAttribute("macrotext1") or "none"),
		#keys, tostring(taken or "no"), tostring(button ~= nil and button:IsShown())) }
end
