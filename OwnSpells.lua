-- Add a spell of my own (asked for on CurseForge): a buff of the player's that
-- Manners does not know, reminded on the player alone, as an own buff. The list
-- is the character's (db.char.ownSpells: { id, name, seen }, ten at most, in
-- the order added). Before each probe, Sync turns every entry into a family of
-- one spell at the end of the class's list in ns.OWN_BUFFS (`custom`), so the
-- probe, OwnVerdict, the queue, Myself, cities and inns, the fight hold and
-- the press (Prompt/Macro.lua, STRATEGIES.self) treat it as any other own buff.
-- A spell Manners covers itself is refused, and left to Manners if it comes to
-- cover it later. The client cannot say before a cast whether a spell leaves
-- an aura: the first cast on yourself out of a fight is read two seconds
-- later, and a spell that left none is taken off with a line saying why.
local _, ns = ...
local L = ns.L
local addon = ns.addon
local InCombatLockdown = _G.InCombatLockdown

local OS = {}
ns.OwnSpells = OS
OS.MAX = 10

local PREFIX = "ownspell"
local VERDICT_SECONDS = 2
local said
local built = false
local watch = {}
local sentTo = {}

local TEXT = {
	ADDED = L["Added %s. Manners reminds you of it when it is not on you."],
	EMPTY = L["Type a spell's name or its spell id."],
	NOT_FOUND = L["Manners found no spell called %s in your spellbook. Type it as your spellbook shows it, or its spell id."],
	NOT_KNOWN = L["%s is not in your spellbook: Manners adds only a spell this character knows."],
	PASSIVE = L["%s is passive: it is always on, with nothing to cast."],
	HARMFUL = L["%s is cast on an enemy, so it cannot go on you."],
	COVERED_OWN = L["Manners already reminds you of %s: its switch is %s, on Who to buff under Myself."],
	COVERED_BUFF = L["%s is a buff Manners already offers: its switch is on Who to buff, under What to cast."],
	TWICE = L["%s is on your list already."],
	FULL = L["Your list is full: ten spells at most. Remove one first."],
	NO_AURA = L["%s left no aura on you that Manners could find after you cast it on yourself, so Manners cannot tell when it is up. It is off your list."],
	IN_FIGHT = L["Not in a fight: add or remove a spell once the fight is over."],
	REMOVED = L["Removed %s."],
	NOT_LISTED = L["%s is not on your list."],
	NOT_NOW = L["%s (not in your spellbook now)"],
	COVERED_NOW = L["%s (Manners now reminds you of it itself)"],
	LIST_HEAD = L["Spells of your own (%d of %d):"],
	LIST_NONE = L["No spells of your own yet. Add one on Who to buff, under Add a spell of my own, or with /manners spell add <name or id>."],
	USAGE = L["Type /manners spell add <name or id>, or /manners spell remove <name or id>."],
}

local function Trim(text)
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Char()
	local db = addon and addon.db
	local char = type(db) == "table" and db.char or nil
	return type(char) == "table" and char or nil
end

local function Entries()
	local char = Char()
	local list = char and char.ownSpells
	return type(list) == "table" and list or nil
end

local function Answer(line, ok)
	said = line
	return ok == true, line
end

local function Shown(id, name)
	local icon = ns.safecall(C_Spell and C_Spell.GetSpellTexture, id)
	if type(icon) == "number" or type(icon) == "string" then
		return "|T" .. tostring(icon) .. ":16:16|t " .. name
	end
	return name
end

local function WholeId(id)
	return type(id) == "number" and id >= 1 and id <= 2147483647 and id == math.floor(id)
end

-- A spell id from what was typed: a link, an id, or a name the client resolves.
local function Resolve(text)
	local raw = Trim(text)
	if raw == "" then return nil end
	local id = tonumber(raw:match("|Hspell:(%d+)") or "")
	if not id then
		local bare = Trim((raw:gsub("^%[", ""):gsub("%]$", "")))
		id = tonumber(bare)
		if not id then
			local api = C_Spell
			id = ns.safecall(api and api.GetSpellIDForSpellIdentifier, bare)
			if type(id) ~= "number" then
				local info = ns.safecall(api and api.GetSpellInfo, bare)
				id = type(info) == "table" and ns.plain(info.spellID) or nil
			end
			if type(id) ~= "number" then
				-- "Mana Shield(Rank 2)": the name without its rank.
				local short = Trim((bare:gsub("%(.-%)%s*$", "")))
				if short ~= bare and short ~= "" then return Resolve(short) end
				return nil
			end
		end
	end
	if not WholeId(id) or not ns.SpellNameFor(id) then return nil end
	return id
end

-- Every name of the class's own spells (by family) and of its buffs for
-- others, lower-cased: what Manners covers itself.
local function Names(class)
	local own, buffs = {}, {}
	for _, family in ipairs((class and ns.OWN_BUFFS[class]) or {}) do
		if not (family.custom or family.enhance or family.bagged) then
			for _, spell in ipairs(family.spells or {}) do
				if not spell.item then
					for _, id in ipairs(spell.ranks or {}) do
						local name = ns.SpellNameFor(id)
						if type(name) == "string" then own[name:lower()] = own[name:lower()] or family end
					end
				end
			end
		end
	end
	for _, buff in ipairs((class and ns.GetClassBuffs(class)) or {}) do
		for _, id in ipairs(buff.ranks or {}) do
			local name = ns.SpellNameFor(id)
			if type(name) == "string" then buffs[name:lower()] = true end
		end
		for _, rank in ipairs(buff.groupCast or {}) do
			local name = ns.SpellNameFor(rank.id)
			if type(name) == "string" then buffs[name:lower()] = true end
		end
	end
	return own, buffs
end

-- Where Manners' own switch for it is, or nil when Manners does not cover it.
local function Covered(id, name, own, buffs)
	local spell = ns.OWN_BY_ID[id]
	if spell and not spell.custom then return TEXT.COVERED_OWN:format(name, ns.OwnFamilyLabel(spell.family)) end
	if ns.BUFF_BY_ID[id] then return TEXT.COVERED_BUFF:format(name) end
	local key = name:lower()
	if own[key] then return TEXT.COVERED_OWN:format(name, ns.OwnFamilyLabel(own[key])) end
	if buffs[key] then return TEXT.COVERED_BUFF:format(name) end
	return nil
end

-- The class's own families made again from the list: before every probe.
local function Sync()
	local class = ns.plain(select(2, UnitClass("player")))
	local entries = Entries()
	local count = entries and #entries or 0
	if type(class) ~= "string" or (count == 0 and not built) then return end
	local list = ns.OWN_BUFFS[class]
	if not list then
		list = {}
		ns.OWN_BUFFS[class] = list
	end
	for i = #list, 1, -1 do
		if list[i].custom then table.remove(list, i) end
	end
	built = false
	wipe(watch)
	ns.BuildOwnLookups()
	if count == 0 then return end
	local own, buffs = Names(class)
	for _, entry in ipairs(entries) do
		local name = ns.SpellNameFor(entry.id) or entry.name
		if type(name) == "string" and name ~= "" then
			entry.name = name
			if not Covered(entry.id, name, own, buffs) then
				local ranks = {}
				local current = Resolve(name)
				if current and current ~= entry.id then ranks[#ranks + 1] = current end
				ranks[#ranks + 1] = entry.id
				local key = PREFIX .. entry.id
				list[#list + 1] = { key = key, custom = true, spells = { { key = key, ranks = ranks,
					custom = true, anyCaster = true, castOnOthers = true } } }
				built = true
				if not entry.seen then
					for _, id in ipairs(ranks) do watch[id] = entry end
				end
			end
		end
	end
	if built then ns.BuildOwnLookups() end
end

local function Changed()
	ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
	if ns.Prompt then ns.Guard("own spell repaint", ns.Prompt.Refresh, ns.Prompt) end
	if ns.RepaintOptions then ns.RepaintOptions() end
end

local function IndexOf(entry)
	for i, each in ipairs(Entries() or {}) do
		if each == entry then return i end
	end
	return nil
end

local function Withheld(value) return issecretvalue ~= nil and issecretvalue(value) == true end

-- true for an aura of it on you, false for none, nil when the client
-- would not say (no verdict on that). A timer's read, never a scan's.
local function OnYou(ranks, name)
	local api = C_UnitAuras
	local byId = api and api.GetUnitAuraBySpellID
	local byName = api and api.GetAuraDataBySpellName
	if type(byId) ~= "function" or type(byName) ~= "function" then return nil end
	local ask = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret
	for _, id in ipairs(ranks) do
		if type(ask) == "function" and ns.safecall(ask, id) == true then return nil end
		local ok, aura = pcall(byId, "player", id)
		if not ok or Withheld(aura) then return nil end
		if type(aura) == "table" then return true end
	end
	local ok, aura = pcall(byName, "player", name, "HELPFUL")
	if not ok or Withheld(aura) then return nil end
	return type(aura) == "table"
end

local function Judge(entry)
	if InCombatLockdown() or not IndexOf(entry) then return end
	local spell = ns.FindOwnSpell(PREFIX .. entry.id)
	if not spell then return end
	local up = OnYou(spell.ranks, entry.name or ns.BuffName(spell))
	if up == nil then return end
	if up then
		entry.seen = true
		for _, id in ipairs(spell.ranks) do watch[id] = nil end
		return
	end
	table.remove(Entries(), IndexOf(entry))
	local line = TEXT.NO_AURA:format(entry.name or tostring(entry.id))
	said = line
	addon:Print(line)
	Changed()
end

-- true for the player, false for somebody else, nil when the event named nobody.
local function IsMe(target)
	if type(target) ~= "string" or target == "" then return nil end
	if ns.IsPlayerName(target) then return true end
	return target == ns.plain(UnitName("player"))
end

function OS.Said() return said end

function OS.Label(row)
	local text = Shown(row.id, row.name)
	if row.covered then return TEXT.COVERED_NOW:format(text) end
	if not row.known then return TEXT.NOT_NOW:format(text) end
	return text
end

function OS.List()
	local rows = {}
	for i, entry in ipairs(Entries() or {}) do
		local spell = ns.FindOwnSpell(PREFIX .. entry.id)
		rows[i] = { id = entry.id, name = entry.name or tostring(entry.id),
			covered = spell == nil, known = spell ~= nil and ns.OwnSpellKnown(spell) == true }
	end
	return rows
end

function OS.Add(text)
	local typed = Trim(text)
	if typed == "" then return Answer(TEXT.EMPTY) end
	if InCombatLockdown() then return Answer(TEXT.IN_FIGHT) end
	local id = Resolve(typed)
	if not id then return Answer(TEXT.NOT_FOUND:format(typed)) end
	local name = ns.SpellNameFor(id) or typed
	if not ns.SpellKnown(id) then return Answer(TEXT.NOT_KNOWN:format(name)) end
	if ns.safecall(C_Spell and C_Spell.IsSpellPassive, id) == true then return Answer(TEXT.PASSIVE:format(name)) end
	if ns.safecall(C_Spell and C_Spell.IsSpellHarmful, id) == true then return Answer(TEXT.HARMFUL:format(name)) end
	local own, buffs = Names(ns.plain(select(2, UnitClass("player"))))
	local where = Covered(id, name, own, buffs)
	if where then return Answer(where) end
	local char = Char()
	if not char then return Answer(TEXT.NOT_FOUND:format(typed)) end
	if type(char.ownSpells) ~= "table" then char.ownSpells = {} end
	local list = char.ownSpells
	local lower = name:lower()
	for _, entry in ipairs(list) do
		if entry.id == id or (entry.name and entry.name:lower() == lower) then return Answer(TEXT.TWICE:format(name)) end
	end
	if #list >= OS.MAX then return Answer(TEXT.FULL) end
	local entry = { id = id, name = name }
	if OnYou({ id }, name) == true then entry.seen = true end
	list[#list + 1] = entry
	Changed()
	return Answer(TEXT.ADDED:format(Shown(id, name)), true)
end

-- `which`: the row's place (the page) or what was typed, an id or a name (chat).
function OS.Remove(which)
	if InCombatLockdown() then return Answer(TEXT.IN_FIGHT) end
	local list = Entries() or {}
	local index
	if type(which) == "number" then
		if list[which] then index = which end
	else
		local typed = Trim(which)
		if typed == "" then return Answer(TEXT.EMPTY) end
		local id = tonumber(typed) or Resolve(typed)
		local lower = typed:lower()
		for i, entry in ipairs(list) do
			if entry.id == id or (entry.name and entry.name:lower() == lower) then index = i end
		end
		if not index then return Answer(TEXT.NOT_LISTED:format(typed)) end
	end
	if not index then return Answer(TEXT.NOT_LISTED:format(tostring(which))) end
	local entry = table.remove(list, index)
	local char = Char()
	if char and type(char.ownLast) == "table" then char.ownLast[PREFIX .. entry.id] = nil end
	Changed()
	return Answer(TEXT.REMOVED:format(entry.name or tostring(entry.id)), true)
end

-- ClampSettings' repair (Core.lua): whole ids, no twice, ten at most, a name
-- of 100 bytes at most, and no memory (ownLast) of a spell no longer listed.
function OS.Repair(char)
	if type(char) ~= "table" or char.ownSpells == nil then return end
	if type(char.ownSpells) ~= "table" then
		char.ownSpells = {}
		return
	end
	local list = char.ownSpells
	local keys, out, seenIds = {}, {}, {}
	for k in pairs(list) do
		if type(k) == "number" then keys[#keys + 1] = k end
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local e = list[k]
		if type(e) == "table" and WholeId(e.id) and not seenIds[e.id] and #out < OS.MAX then
			seenIds[e.id] = true
			local name = type(e.name) == "string" and Trim(e.name) or nil
			if name == "" then name = nil end
			if name and #name > 100 then name = name:sub(1, 100) end
			-- The entry itself stays: Sync's watch holds this very table.
			local seen = e.seen == true
			for k in pairs(e) do
				if k ~= "id" then e[k] = nil end
			end
			e.name, e.seen = name, seen or nil
			out[#out + 1] = e
		end
	end
	wipe(list)
	for i, e in ipairs(out) do list[i] = e end
	local last = char.ownLast
	if type(last) == "table" then
		for key in pairs(last) do
			if type(key) == "string" and key:sub(1, #PREFIX) == PREFIX then
				local id = tonumber(key:sub(#PREFIX + 1))
				if not (id and seenIds[id]) then last[key] = nil end
			end
		end
	end
end

-- /manners spell, /manners spell add <name or id>, /manners spell remove <name or id>.
function OS.Slash(rest)
	local verb, arg = Trim(rest):match("^(%S*)%s*(.*)$")
	verb = (verb or ""):lower()
	if verb == "" or verb == "list" then
		local rows = OS.List()
		if #rows == 0 then
			addon:Print(TEXT.LIST_NONE)
			return
		end
		addon:Print(TEXT.LIST_HEAD:format(#rows, OS.MAX))
		for i, row in ipairs(rows) do addon:Print(("  %d. %s"):format(i, OS.Label(row))) end
	elseif verb == "add" then
		local _, line = OS.Add(arg)
		addon:Print(line)
	elseif verb == "remove" then
		local _, line = OS.Remove(arg)
		addon:Print(line)
	else
		addon:Print(TEXT.USAGE)
	end
end

-- The verdict's casts, through the handlers Clicks.lua defines: one lookup a
-- cast, and nothing more for a spell nobody watches.
do
	local sent = addon.UNIT_SPELLCAST_SENT
	function addon:UNIT_SPELLCAST_SENT(event, unit, target, castGUID, spellId, ...)
		if sent then sent(self, event, unit, target, castGUID, spellId, ...) end
		if unit ~= "player" then return end
		local id = ns.plain(spellId)
		if id == nil or watch[id] == nil then return end
		sentTo[id] = ns.plain(target) or ""
	end
	local succeeded = addon.UNIT_SPELLCAST_SUCCEEDED
	function addon:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellId, ...)
		if succeeded then succeeded(self, event, unit, castGUID, spellId, ...) end
		if unit ~= "player" then return end
		local id = ns.plain(spellId)
		local entry = id ~= nil and watch[id] or nil
		if not entry then return end
		local target = sentTo[id]
		sentTo[id] = nil
		if InCombatLockdown() then return end
		local me = IsMe(target)
		-- A cast the client sent to your own pet (Mend Pet) is read like one on you.
		if me == false and target ~= ns.plain(UnitName("pet")) then return end
		if me == nil and ns.safecall(C_Spell and C_Spell.IsSpellHelpful, id) == true then return end
		C_Timer.After(VERDICT_SECONDS, function() ns.Guard("own spell verdict", Judge, entry) end)
	end
end

local probe = ns.ProbeCapabilities
function ns.ProbeCapabilities(...)
	ns.Guard("own spells", Sync)
	return probe(...)
end
