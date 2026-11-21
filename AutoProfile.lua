-- Manners -- profiles: the Profiles page's profile manager, and switching by
-- where you are.
--
-- A profile is AceDB's: every setting on the other pages, shared by whichever
-- characters use it. This file is the page's own way to the library's calls
-- (ns.Profiles: Create, Duplicate, Rename, Use, CopyFrom, Delete, Reset,
-- PasteAsNew, Undo), the controls for them (Profiles.AddOptions, called by
-- Options/Profiles.lua; they take the place of AceDBOptions' own, under the
-- same keys, so the page is the same whatever the library builds), automatic
-- switching, and the profile a new character starts on.
--
-- The page (1.12): an overview of every profile and who is on it, one
-- dropdown that picks a profile and a row of buttons that act on the picked
-- one (any profile can be renamed or duplicated, not only the one in use), a
-- line saying what the last of them did with Undo beside it, and a new
-- profile from the defaults.
--
-- Undo (`page.last`): one step, this session only, gone after the next action
-- on the page or a profile picked elsewhere, never in a fight. Delete, Reset,
-- Copy into, Rename and a paste can be taken back: a delete puts back the
-- profile's saved table, the characters that were on it and every rule that
-- named it; a reset or a copy the settings the profile had (copied back into
-- it the library's way, through a profile of a moment); a rename is renamed
-- back; a paste into the profile in use is the import's own undo
-- (Commands.lua, ns.UndoImport), and a paste into a new profile goes back to
-- the profile before and deletes the new one.
--
-- Automatic switching (db.char.autoProfile: which profile a character uses is
-- the character's, so its rules are too, and no pasted settings line carries
-- them):
--   enabled   the master switch, off
--   say       one line in chat a switch, on
--   rules     situation -> profile name; absent is "Do not switch"
--   at        the situation last arrived in, kept over a /reload so a login
--             in the same place is no arrival
--   chose     { profile, at }: the profile the last automatic switch chose,
--             for the page's "chosen for" line, while that profile is in use
--
-- The situations are where you are and nothing else: the open world, a
-- dungeon, a raid instance, a battleground or arena. A raid group outside an
-- instance is the open world: one thing decides, the place, and the instance's
-- door is the moment it changes.
--
-- A switch happens on ARRIVING: a zone event (PLAYER_ENTERING_WORLD,
-- ZONE_CHANGED_NEW_AREA), a second and a half after the last of them, finds
-- the situation other than `at`. Then the rule for the new one is read: a
-- profile other than the one in use is switched to, once no fight is on
-- (PLAYER_REGEN_ENABLED asks again), no press is waiting to be settled and
-- nothing is being typed or confirmed in the options window (asked again a
-- second on). "Do not switch" leaves the profile as it is: nothing is put
-- back. A profile the player picks holds until the next arrival, because only
-- an arrival is acted on. Nothing here runs on the scan.
--
-- An automatic switch is not the player turning anything on or off:
-- Milestones' "the switch was turned" (Milestones.lua, M.Switched) is told
-- nothing while both profiles have milestones the same way.
--
-- New characters (db.global.newCharacters, account-wide): the profile a
-- character takes at its first login with Manners, written into AceDB's own
-- record of who uses what (`profileKeys`) before the library reads it, so the
-- character simply starts there: no switch, nothing offered before. Unset, or
-- naming a profile that is gone, it is Default, as AceDB has it.
--
-- Core.lua is not edited for any of this: its AceDB callbacks and its
-- OnInitialize are called by name, so the wraps at the end of this file see
-- every profile change and run before the database is read.

local _, ns = ...
local L = ns.L
local plain = ns.plain
local addon = ns.addon

local P = {}
ns.Profiles = P

local GOLD = "|cffffd100"
local GREY = "|cff9d9d9d"
-- AceDBOptions' own limit for a profile's name.
local NAME_MAX = 50
-- AceDB's name for the profile every character starts on.
local DEFAULT = "Default"
-- A profile of a moment that Undo copies a profile's old settings back
-- through: no player types a control character into a name.
local TEMP = "\001Manners undo"
-- How many characters the overview names before "and N more".
local NAMED = 5
-- Seconds after the last zone event before the place is read: a loading
-- screen fires several, and the client's answer is settled by then.
local SETTLE = 1.5
-- Seconds before asking again while a press or the options window holds a
-- switch back.
local RETRY = 1

local SITUATIONS = { "world", "dungeon", "raid", "battle" }
local KNOWN = { world = true, dungeon = true, raid = true, battle = true }
-- A row's label, and the same words inside a sentence.
local LABEL = {
	world = L["In the open world"],
	dungeon = L["In a dungeon"],
	raid = L["In a raid"],
	battle = L["In a battleground or arena"],
}
local INLINE = {
	world = L["in the open world"],
	dungeon = L["in a dungeon"],
	raid = L["in a raid"],
	battle = L["in a battleground or arena"],
}
-- The overview's words for where automatic switching sends this character.
local PLACES = {
	world = L["the open world"],
	dungeon = L["dungeons"],
	raid = L["raids"],
	battle = L["battlegrounds and arenas"],
}
-- The dropdown's value for "Do not switch": no profile has an empty name.
local NONE = ""

-- What the page holds for the session: the profile picked, the name typed
-- for Duplicate and Rename, where a paste goes and the new profile's name,
-- and the last action's line (with what Undo needs to take it back).
local page = { pick = nil, draft = "", into = "mine", pasteName = "", last = nil, pasting = false }

---------------------------------------------------------------------------
-- the library's calls
---------------------------------------------------------------------------

-- The profile in use, or nil where the database cannot say.
function P.Current()
	local db = ns.db
	if not (db and type(db.GetCurrentProfile) == "function") then return nil end
	local name = db:GetCurrentProfile()
	return type(name) == "string" and name or nil
end

-- Every profile there is, as a set of names; the one in use is always in it.
function P.Names()
	local db, out = ns.db, {}
	if db and type(db.GetProfiles) == "function" then
		local list = db:GetProfiles({})
		for _, name in ipairs(type(list) == "table" and list or {}) do
			if type(name) == "string" and name ~= TEMP then out[name] = true end
		end
	end
	local current = P.Current()
	if current then out[current] = true end
	return out
end

-- The names in the page's order: the one in use first, then by name.
local function Sorted()
	local current, names = P.Current(), {}
	for name in pairs(P.Names()) do
		if name ~= current then names[#names + 1] = name end
	end
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	if current then table.insert(names, 1, current) end
	return names
end

local function Trim(text)
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Gold(name) return GOLD .. tostring(name) .. "|r" end

local function Repaint()
	if ns.RepaintOptions then ns.RepaintOptions() end
end

-- Why a name will not do for a new profile, as a sentence, or nil when it
-- will. Letters, not bytes: an accented one is two or three.
function P.NameFault(name)
	name = Trim(name)
	if name == "" then return L["Type a name first."] end
	local letters = select(2, name:gsub("[^\128-\191]", ""))
	if letters > NAME_MAX then return L["A profile's name is 50 characters at most."] end
	if P.Names()[name] then return L["There is already a profile called %s."]:format(name) end
	return nil
end

-- A profile switch moves the prompt and rewrites its macro, so nothing here
-- happens in a fight; and nothing without the library's calls.
local function Ready()
	local db = ns.db
	if InCombatLockdown() or not P.Current() then return nil end
	if type(db.SetProfile) ~= "function" then return nil end
	return db
end

local function Store()
	local char = ns.db and ns.db.char
	if type(char) ~= "table" then return nil end
	local st = char.autoProfile
	if type(st) ~= "table" then
		st = {}
		char.autoProfile = st
	end
	-- Repaired where it is read: a saved file can hold anything.
	st.enabled = st.enabled == true
	st.say = st.say ~= false
	if type(st.rules) ~= "table" then st.rules = {} end
	for key, name in pairs(st.rules) do
		if not KNOWN[key] or type(name) ~= "string" then st.rules[key] = nil end
	end
	if not KNOWN[st.at] then st.at = nil end
	local chose = st.chose
	if not (type(chose) == "table" and type(chose.profile) == "string" and KNOWN[chose.at]) then st.chose = nil end
	return st
end

-- The saved file's tables: every profile, and who uses which.
local function Saved()
	local db = ns.db
	local sv = db and db.sv
	return type(sv) == "table" and sv or nil
end

-- The account's own section (db.global), where the profile new characters
-- start on is kept.
local function Global()
	local db = ns.db
	local global = db and db.global
	return type(global) == "table" and global or nil
end

-- How AceDB names a character in its record of who uses what.
local function LoginKey()
	local unitName, realm = _G.UnitName, _G.GetRealmName
	if type(unitName) ~= "function" or type(realm) ~= "function" then return nil end
	local name, server = plain((unitName("player"))), plain((realm()))
	if type(name) ~= "string" or type(server) ~= "string" or name == "" then return nil end
	return name .. " - " .. server
end

-- This character's key in that record: the library's own, else made the
-- library's way.
local function CharKey()
	local db = ns.db
	local keys = db and db.keys
	if type(keys) == "table" and type(keys.char) == "string" then return keys.char end
	return LoginKey()
end

-- The characters on a profile, from the library's record, sorted.
function P.Users(name)
	local out, sv = {}, Saved()
	local keys = sv and sv.profileKeys
	if type(keys) == "table" then
		for char, profile in pairs(keys) do
			if profile == name and type(char) == "string" then out[#out + 1] = char end
		end
	end
	table.sort(out)
	return out
end

-- The settings table of a profile: the one in use is the database's own.
local function Source(db, name)
	if name == P.Current() then return db.profile end
	local sv = Saved()
	local profiles = sv and sv.profiles
	return type(profiles) == "table" and profiles[name] or nil
end

-- A copy of every value, as it is.
local function Copy(from)
	local out = {}
	for k, v in pairs(from) do out[k] = type(v) == "table" and Copy(v) or v end
	return out
end

-- A copy with every value that equals its default left out, the way AceDB
-- itself keeps a profile in the saved file (its removeDefaults), so a later
-- release's new default still reaches the copy.
local function Stripped(from, defaults)
	local out = {}
	for k, v in pairs(from) do
		local default = type(defaults) == "table" and defaults[k] or nil
		if type(v) == "table" then
			local inner = Stripped(v, default)
			if next(inner) ~= nil or type(default) ~= "table" then out[k] = inner end
		elseif v ~= default then
			out[k] = v
		end
	end
	return out
end

-- The last action's line: with `undo`, what Undo needs to take it back.
-- Taking one over ends an import's own undo too, so the page never has two.
local function Remember(record)
	page.last = record
	if record and ns.ForgetImportUndo then ns.ForgetImportUndo() end
end

-- A new profile under `name` with every setting at its default, and this
-- character on it.
function P.Create(name)
	name = Trim(name)
	local db = Ready()
	if not db then return false end
	local fault = P.NameFault(name)
	if fault then return false, fault end
	db:SetProfile(name)
	Remember({ text = L["Made %s, with every setting at its default."]:format(Gold(name)) })
	return true
end

-- A copy of `from` (the one in use when not given) under `name`. Nobody is
-- moved onto it: the copy is picked, ready to Use.
function P.Duplicate(name, from)
	name = Trim(name)
	local db = Ready()
	if not db then return false end
	local fault = P.NameFault(name)
	if fault then return false, fault end
	from = from or P.Current()
	local source, sv = Source(db, from), Saved()
	if type(source) ~= "table" or not (sv and type(sv.profiles) == "table") or not P.Names()[from] then return false end
	sv.profiles[name] = Stripped(source, ns.defaults and ns.defaults.profile)
	page.pick, page.draft = name, ""
	Remember({ text = L["Made %s, a copy of %s."]:format(Gold(name), Gold(from)) })
	Repaint()
	return true
end

-- A rule or a "chosen for" naming `old` names `new` instead (nil: nothing).
local function Carry(st, old, new)
	if type(st) ~= "table" then return end
	if type(st.rules) == "table" then
		for key, name in pairs(st.rules) do
			if name == old then st.rules[key] = new end
		end
	end
	if type(st.chose) == "table" and st.chose.profile == old then
		if new then st.chose.profile = new else st.chose = nil end
	end
end

-- `old` under the name `name`. AceDB has no rename. The profile in use: a new
-- profile, the old one copied into it, the old one deleted. Another one: its
-- saved table moved to the new name. Every character that was on the old
-- name is put on the new one (the library's own record of who uses what),
-- every rule that named it, this character's and the others', follows, and
-- so does the profile new characters start on.
local function RenameProfile(db, old, name)
	local sv, st = Saved(), Store()
	if old == P.Current() then
		if type(db.CopyProfile) ~= "function" or type(db.DeleteProfile) ~= "function" then return false end
		-- The switch below is the page's own doing, not the player picking
		-- another profile: what automatic switching chose stays chosen.
		local chose = st and st.chose
		db:SetProfile(name)
		db:CopyProfile(old, true)
		if st then st.chose = chose end
	elseif not (sv and type(sv.profiles) == "table" and type(sv.profiles[old]) == "table") then
		return false
	else
		sv.profiles[name] = sv.profiles[old]
	end
	Carry(st, old, name)
	if sv then
		if type(sv.profileKeys) == "table" then
			for char, profile in pairs(sv.profileKeys) do
				if profile == old then sv.profileKeys[char] = name end
			end
		end
		if type(sv.char) == "table" then
			for _, char in pairs(sv.char) do
				if type(char) == "table" then Carry(char.autoProfile, old, name) end
			end
		end
	end
	local global = Global()
	if global and global.newCharacters == old then global.newCharacters = name end
	if name == P.Current() then
		db:DeleteProfile(old, true)
	else
		sv.profiles[old] = nil
	end
	if page.pick == old then page.pick = name end
	return true
end

-- `old` (the one in use when not given) under the name `name`.
function P.Rename(name, old)
	name = Trim(name)
	local db = Ready()
	if not db then return false end
	local fault = P.NameFault(name)
	if fault then return false, fault end
	old = old or P.Current()
	if type(old) ~= "string" or not P.Names()[old] then return false end
	if not RenameProfile(db, old, name) then return false end
	page.draft = ""
	Remember({ kind = "rename", undo = true, old = old, new = name,
		text = L["Renamed %s to %s."]:format(Gold(old), Gold(name)) })
	Repaint()
	return true
end

function P.Use(name)
	local db = Ready()
	if not db or type(name) ~= "string" or not P.Names()[name] then return false end
	-- The switch ends the page's last line and puts the dropdown on it (the
	-- RefreshConfig wrap at the end of this file).
	db:SetProfile(name)
	return true
end

-- Every setting of `name` over the profile in use.
function P.CopyFrom(name)
	local db = Ready()
	if not db or type(db.CopyProfile) ~= "function" then return false end
	if type(name) ~= "string" or name == P.Current() or not P.Names()[name] then return false end
	local into = P.Current()
	local before = Copy(db.profile)
	db:CopyProfile(name, true)
	Remember({ kind = "copy", undo = true, profile = into, snapshot = before,
		text = L["Copied %s into %s."]:format(Gold(name), Gold(into)) })
	return true
end

-- What a delete takes away, read before it: the saved table, the characters
-- on it, and every character's rules that name it.
local function Doomed(name)
	local record = { kind = "delete", undo = true, name = name, keys = {}, rules = {} }
	if type(name) ~= "string" then return record end
	local sv = Saved()
	record.saved = sv and type(sv.profiles) == "table" and sv.profiles[name] or nil
	record.keys = P.Users(name)
	local stores = { Store() }
	if sv and type(sv.char) == "table" then
		for _, char in pairs(sv.char) do
			if type(char) == "table" and type(char.autoProfile) == "table" then stores[#stores + 1] = char.autoProfile end
		end
	end
	for _, st in ipairs(stores) do
		if type(st.rules) == "table" then
			for at, rule in pairs(st.rules) do
				if rule == name then record.rules[#record.rules + 1] = { st = st, at = at } end
			end
		end
	end
	record.text = L["Deleted %s."]:format(Gold(name))
	return record
end

-- Never the profile in use: the library refuses it too.
function P.Delete(name)
	local db = Ready()
	if not db or type(db.DeleteProfile) ~= "function" then return false end
	local record = Doomed(name)
	if type(name) ~= "string" or name == P.Current() or not P.Names()[name] then return false end
	db:DeleteProfile(name, true)
	-- The characters that were on it go to Default, by name: AceDB leaves
	-- them on no profile at all, which their next login would read as a
	-- first one and start them where new characters start.
	local sv = Saved()
	if sv and type(sv.profileKeys) == "table" then
		for _, key in ipairs(record.keys) do sv.profileKeys[key] = DEFAULT end
	end
	Remember(record)
	Repaint()
	return true
end

function P.Reset()
	local db = Ready()
	if not db or type(db.ResetProfile) ~= "function" then return false end
	local name = P.Current()
	local before = Copy(db.profile)
	db:ResetProfile()
	Remember({ kind = "reset", undo = true, profile = name, snapshot = before,
		text = L["Put every setting of %s back to its default."]:format(Gold(name)) })
	return true
end

-- The question Delete asks, naming the profile and who would go to Default.
function P.DeleteQuestion(name)
	local who = P.Users(name)
	if #who == 0 then return L["Delete %s? No character is on it."]:format(tostring(name)) end
	return L["Delete %s? These characters go to the Default profile: %s."]:format(tostring(name), table.concat(who, ", "))
end

---------------------------------------------------------------------------
-- a paste into a new profile, and Undo
---------------------------------------------------------------------------

-- Settings pasted as a new profile under `name`, which this character
-- switches to first; the import's lines with its own undo left off, since
-- Undo on the page takes the whole profile away.
function P.PasteAsNew(name, text)
	name = Trim(name)
	local db = Ready()
	if not db then return false, L["A profile cannot be made in a fight."] end
	local fault = P.NameFault(name)
	if fault then return false, fault end
	local parsed, err = ns.ParseSettings(text)
	if not parsed then return false, err end
	local from, st = P.Current(), Store()
	local chose = st and st.chose
	db:SetProfile(name)
	if P.Current() ~= name then return false end
	page.pasting = true
	local ok, message = ns.ImportSettings(text)
	page.pasting = false
	page.pasteName = ""
	Remember({ kind = "pasteNew", undo = true, profile = name, from = from, chose = chose,
		text = L["Pasted settings into a new profile, %s."]:format(Gold(name)) })
	message = tostring(message or "")
	local offer = L["|cffffd100/manners import undo|r puts your old settings back."]
	local at = message:find(offer, 1, true)
	if at then message = Trim(message:sub(1, at - 1) .. message:sub(at + #offer)) end
	return ok, Trim(message .. " " .. L["This character is on %s now; Undo on %s takes it away again."]:format(name, ns.TabName("profiles.undo")))
end

-- Where the Share section's paste goes: the new profile's name when it goes
-- into a new one, nil for the profile in use.
function P.PasteInto()
	if page.into ~= "new" then return nil end
	return page.pasteName
end

-- The settings a profile had, copied back into it the library's way: through
-- a profile of a moment, which is gone again at once.
local function PutBack(db, snapshot)
	local sv = Saved()
	if not (sv and type(sv.profiles) == "table" and type(db.CopyProfile) == "function") then return false end
	sv.profiles[TEMP] = snapshot
	local ok = ns.Guard("profile undo", db.CopyProfile, db, TEMP, true)
	sv.profiles[TEMP] = nil
	return ok
end

local UNDO = {
	delete = function(db, r)
		local sv = Saved()
		if P.Names()[r.name] then return false, L["There is already a profile called %s."]:format(r.name) end
		if not (sv and type(sv.profiles) == "table") then return false end
		sv.profiles[r.name] = r.saved or {}
		if type(sv.profileKeys) == "table" then
			for _, key in ipairs(r.keys) do
				if sv.profileKeys[key] == nil or sv.profileKeys[key] == DEFAULT then sv.profileKeys[key] = r.name end
			end
		end
		for _, rule in ipairs(r.rules) do
			if type(rule.st.rules) == "table" and rule.st.rules[rule.at] == nil then rule.st.rules[rule.at] = r.name end
		end
		return true
	end,
	reset = function(db, r) return PutBack(db, r.snapshot) end,
	copy = function(db, r) return PutBack(db, r.snapshot) end,
	rename = function(db, r)
		if P.Names()[r.old] then return false, L["There is already a profile called %s."]:format(r.old) end
		if not P.Names()[r.new] then return false end
		return RenameProfile(db, r.new, r.old)
	end,
	import = function()
		local ok, message = ns.UndoImport()
		if message then addon:Reply(message) end
		return ok
	end,
	pasteNew = function(db, r)
		local back = P.Names()[r.from] and r.from or DEFAULT
		db:SetProfile(back)
		if P.Current() ~= back then return false end
		if type(db.DeleteProfile) == "function" then db:DeleteProfile(r.profile, true) end
		local st = Store()
		if st then st.chose = r.chose end
		return true
	end,
}

-- Whether the last action can be taken back now: a change to a profile's
-- settings only while that profile is in use, an import while the import's
-- own undo still holds.
function P.CanUndo()
	local r = page.last
	if not (r and r.undo) then return false end
	if r.kind == "import" then return ns.ImportUndoHeld ~= nil and ns.ImportUndoHeld() == true end
	if r.kind == "reset" or r.kind == "copy" or r.kind == "pasteNew" then return P.Current() == r.profile end
	return true
end

-- The line under the overview: what the last action did, while it means
-- something; nil otherwise.
function P.Status()
	local r = page.last
	if not r or (r.undo and not P.CanUndo()) then return nil end
	return r.text
end

function P.Undo()
	local db = Ready()
	local r = page.last
	if not (db and r and P.CanUndo()) then return false end
	page.last = nil
	local ok, why = UNDO[r.kind](db, r)
	page.last = { text = ok and L["Put back as it was."] or why }
	Repaint()
	return ok == true
end

---------------------------------------------------------------------------
-- the overview
---------------------------------------------------------------------------

-- "Name" for a character on this realm, "Name - Realm" for one elsewhere.
local function Short(key, realm)
	local name, server = key:match("^(.-) %- (.+)$")
	if name and server == realm then return name end
	return key
end

-- Who is on a profile: "this character", "3 characters: A, B, C", "nobody".
local function Who(name)
	local me = CharKey()
	local realm = me and me:match(" %- (.+)$")
	local others, mine = {}, name == P.Current()
	for _, key in ipairs(P.Users(name)) do
		if key == me then mine = true else others[#others + 1] = Short(key, realm) end
	end
	local count = #others + (mine and 1 or 0)
	if count == 0 then return L["nobody"] end
	if count == 1 and mine then return L["this character"] end
	if mine then table.insert(others, 1, L["this character"]) end
	if #others > NAMED + 1 then
		local more = #others - NAMED
		for i = #others, NAMED + 1, -1 do others[i] = nil end
		others[#others + 1] = L["%d more"]:format(more)
	end
	return L["%d characters: %s"]:format(count, table.concat(others, ", "))
end

-- Where automatic switching sends this character to `name`, or nil.
local function Where(name)
	local st = Store()
	if not (st and st.enabled) then return nil end
	local out = {}
	for _, at in ipairs(SITUATIONS) do
		if st.rules[at] == name then out[#out + 1] = PLACES[at] end
	end
	return #out > 0 and table.concat(out, ", ") or nil
end

-- The profile new characters start on, as the dropdown shows it.
function P.StartProfile()
	local global = Global()
	local name = global and global.newCharacters
	if type(name) == "string" and P.Names()[name] then return name end
	return DEFAULT
end

-- One line a profile, the one in use first and marked.
function P.Overview()
	local current = P.Current()
	if not current then return "" end
	local start = P.StartProfile()
	local lines = {}
	for _, name in ipairs(Sorted()) do
		local head = Gold(name)
		if name == current then head = L["%s (in use)"]:format(head) end
		local text = head .. ": " .. Who(name) .. "."
		local where = Where(name)
		if where then text = text .. " " .. L["Switched to in %s."]:format(where) end
		if name == start and start ~= DEFAULT then text = text .. " " .. L["New characters start here."] end
		lines[#lines + 1] = text
		local why = name == current and P.Why()
		if why then lines[#lines + 1] = "    " .. GREY .. why .. "|r" end
	end
	return table.concat(lines, "\n")
end

-- The picked profile: the one in use until another is picked, and again
-- once the picked one is gone.
function P.Picked()
	local pick = page.pick
	if type(pick) == "string" and P.Names()[pick] then return pick end
	return P.Current()
end

---------------------------------------------------------------------------
-- automatic switching
---------------------------------------------------------------------------

local auto = { serial = 0, look = false, pending = nil, switching = nil, notBefore = nil, milestones = nil }

-- Where you are, by the game's word, or nil when it will not say (nothing is
-- done then). Asked on a zone event, never on the scan, so protected like
-- every other reader of it that is not on a busy path.
local function Situation()
	local ask = _G.IsInInstance
	if type(ask) ~= "function" then return nil end
	local inside, kind = ns.safecall(ask)
	inside, kind = plain(inside), plain(kind)
	if inside == nil and kind == nil then return nil end
	if inside == true or inside == 1 then
		if kind == "raid" then return "raid" end
		if kind == "pvp" or kind == "arena" then return "battle" end
		-- A scenario is a dungeon to anybody choosing settings for one.
		if kind == "party" or kind == "scenario" then return "dungeon" end
	end
	return "world"
end

-- What holds a switch back right now: "fight", "press" (one waiting to be
-- settled: Clicks.lua), "window" (a box being typed in or a question waiting
-- for its answer in the options window, either of which a repaint for another
-- profile would lose), or nil.
local function Held()
	if InCombatLockdown() then return "fight" end
	if ns.pendingClick then return "press" end
	local UI, W = ns.WindowUI, ns.WindowWidgets
	if UI and UI.Shown and UI.Shown() then
		if W and W.Asking and W.Asking() then return "window" end
		local focus = _G.GetCurrentKeyBoardFocus
		if type(focus) == "function" and focus() then return "window" end
	end
	return nil
end

local Step

-- One timer at a time: a later call takes the earlier one's place, and none
-- runs before a zone event's settle is over.
local function Later(seconds)
	if not (C_Timer and C_Timer.After) then return end
	local now = GetTime()
	if auto.notBefore and auto.notBefore - now > seconds then seconds = auto.notBefore - now end
	auto.serial = auto.serial + 1
	local mine = auto.serial
	C_Timer.After(seconds, function()
		if mine == auto.serial then ns.Guard("automatic profile", Step) end
	end)
end

function Step()
	local st = Store()
	if not (st and st.enabled) then
		auto.look, auto.pending = false, nil
		return
	end
	if auto.look then
		auto.look = false
		auto.notBefore = nil
		local at = Situation()
			if at and at ~= st.at then
			st.at = at
			auto.pending = at
		end
	end
	local at = auto.pending
	if not at then return end
	local name, current = st.rules[at], P.Current()
	if not name or not current then
		auto.pending = nil
		return
	end
	-- A profile deleted since (by another character: this one's delete clears
	-- the rule at once): back to "Do not switch". Never made again by a rule.
	if not P.Names()[name] then
		st.rules[at] = nil
		auto.pending = nil
		return
	end
	if name == current then
		auto.pending = nil
		return
	end
	local held = Held()
	-- A fight: PLAYER_REGEN_ENABLED asks again. Anything else: in a moment.
	if held == "fight" then return end
	if held then return Later(RETRY) end
	auto.pending = nil
	auto.switching = at
	auto.milestones = ns.Milestones and ns.Milestones.On and ns.Milestones.On() or false
	ns.Guard("automatic profile switch", ns.db.SetProfile, ns.db, name)
	auto.switching = nil
	if P.Current() ~= name then return end
	st.chose = { profile = name, at = at }
	ns.Trail("profile", "switched automatically, " .. at)
	-- After the switch: the profile arrived at decides whether chat is silent.
	-- (The prompt is already painted for it: Core.lua's RefreshConfig styles
	-- it again, which ends in a repaint.)
	if st.say then
		addon:Print(L["profile %s (%s)"]:format(GOLD .. name .. "|r", INLINE[at]))
	end
end

-- The page's second sentence: why this profile, when automatic switching
-- chose it and it is still the one in use; nil otherwise.
function P.Why()
	local st = Store()
	local chose = st and st.enabled and st.chose
	if not chose or chose.profile ~= P.Current() then return nil end
	return L["Chosen automatically: %s."]:format(INLINE[chose.at])
end

-- The master switch. Turning it on is no arrival: where you are now is noted,
-- and the first switch is at the next place.
local function SetEnabled(on)
	local st = Store()
	if not st then return end
	st.enabled = on == true
	auto.look, auto.pending = false, nil
	if st.enabled then st.at = Situation() or st.at end
end

local watcher = CreateFrame("Frame")
-- Held, so the frame lasts as long as the functions here do.
auto.watcher = watcher
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:SetScript("OnEvent", function(_, event)
	-- Whether the switch is on is Step's to ask, in one place.
	if event == "PLAYER_REGEN_ENABLED" then
		-- A moment on, so the end of the fight's own repaint is over.
		if auto.pending or auto.look then Later(0.3) end
		return
	end
	auto.look = true
	auto.notBefore = GetTime() + SETTLE
	Later(SETTLE)
end)

---------------------------------------------------------------------------
-- the page's controls
---------------------------------------------------------------------------

-- name -> name, for a dropdown; `others` leaves the profile in use out.
local function Choices(others)
	local out = {}
	local current = P.Current()
	for name in pairs(P.Names()) do
		if not (others and name == current) then out[name] = name end
	end
	return out
end

local function Busy() return Ready() == nil end
-- The picked profile is the one in use: nothing to use, delete or copy.
local function PickedInUse() return Busy() or P.Picked() == P.Current() end
-- The name typed for Duplicate and Rename will not do.
local function NameOff() return Busy() or P.NameFault(page.draft) ~= nil end

local function AutoOff()
	local st = Store()
	return not (st and st.enabled)
end

local function Button(order, name, desc, func, disabled)
	return { type = "execute", order = order, name = name, desc = desc, func = func, disabled = disabled }
end

-- One situation's dropdown: every profile, and "Do not switch" first.
local function RuleOption(at, order)
	return {
		type = "select",
		order = order,
		name = LABEL[at],
		desc = L["The profile this character switches to on arriving there."],
		values = function()
			local out = Choices(false)
			out[NONE] = L["Do not switch"]
			return out
		end,
		sorting = function()
			local names = {}
			for name in pairs(P.Names()) do names[#names + 1] = name end
			table.sort(names)
			table.insert(names, 1, NONE)
			return names
		end,
		get = function()
			local st = Store()
			local name = st and st.rules[at]
			if not name then return NONE end
			-- Deleted since, on another character: "Do not switch" again.
			if P.Current() and not P.Names()[name] then
				st.rules[at] = nil
				return NONE
			end
			return name
		end,
		set = function(_, value)
			local st = Store()
			if not st then return end
			st.rules[at] = (type(value) == "string" and value ~= NONE) and value or nil
		end,
		disabled = AutoOff,
	}
end

-- What the grey line under the buttons says: why some are greyed.
local function PickNote()
	local parts = {}
	if P.Picked() == P.Current() then
		parts[1] = L["This is the profile in use: pick another to use, delete or copy it."]
	end
	if Trim(page.draft) ~= "" then parts[#parts + 1] = P.NameFault(page.draft) end
	if #parts == 0 then return nil end
	return table.concat(parts, " ")
end

-- The overview, the last action's line with Undo, and the picked profile's
-- actions: the dropdown, the name box and the row of buttons.
local function AddManager(args)
	args.current = {
		type = "description",
		order = 11,
		fontSize = "medium",
		hidden = function() return P.Current() == nil end,
		name = function() return P.Overview() end,
	}
	args.undoNote = {
		type = "description",
		order = 12,
		fontSize = "medium",
		hidden = function() return P.Status() == nil end,
		name = function() return P.Status() or "" end,
	}
	args.undo = Button(13, L["Undo"], L["Takes back what the line beside it says was done. Once, this session."],
		function() P.Undo() end, Busy)
	args.undo.hidden = function() return not P.CanUndo() end
	args.choose = {
		type = "select",
		order = 20,
		name = L["Profile"],
		desc = L["Pick a profile, then what to do with it below."],
		values = function()
			local out, current = Choices(false), P.Current()
			if current then out[current] = L["%s (in use)"]:format(current) end
			return out
		end,
		sorting = Sorted,
		get = function() return P.Picked() end,
		set = function(_, value)
			if type(value) == "string" and P.Names()[value] then page.pick = value end
		end,
	}
	args.name = {
		type = "input",
		order = 21,
		name = L["Name"],
		desc = L["The name Duplicate and Rename give the profile."],
		get = function() return page.draft end,
		set = function(_, value) page.draft = tostring(value or "") end,
	}
	args.use = Button(22, L["Use"], L["Switches this character to the profile picked above."],
		function() P.Use(P.Picked()) end, PickedInUse)
	args.duplicate = Button(23, L["Duplicate"],
		L["Makes a copy of the profile picked above under the name in the box. No character is moved onto it."],
		function() P.Duplicate(page.draft, P.Picked()) end, NameOff)
	args.rename = Button(24, L["Rename"],
		L["Gives the profile picked above the name in the box. Every character on it stays on it, and automatic switching follows the new name."],
		function() P.Rename(page.draft, P.Picked()) end, NameOff)
	args.delete = Button(25, L["Delete"], L["Deletes the profile picked above, after asking. Undo puts it back."],
		function() P.Delete(P.Picked()) end, PickedInUse)
	args.delete.confirm = function() return P.DeleteQuestion(P.Picked()) end
	args.copyfrom = Button(26, L["Copy into the profile in use"],
		L["Replaces every setting of the profile in use with the ones of the profile picked above, after asking. Undo puts them back."],
		function() P.CopyFrom(P.Picked()) end, PickedInUse)
	args.copyfrom.confirm = function()
		return L["Replace every setting of %s, the profile in use, with the ones of %s?"]
			:format(tostring(P.Current()), tostring(P.Picked()))
	end
	args.pickNote = {
		type = "description",
		order = 27,
		hidden = function() return PickNote() == nil end,
		name = function() return PickNote() or "" end,
	}
	-- How a profile is edited, said once, under the buttons.
	args.editNote = {
		type = "description",
		order = 28,
		name = L["To change a profile's settings, switch to it: every page shows and changes the profile in use."],
	}
end

-- A new profile from the defaults, where new characters start, and Reset.
local function AddStarts(args)
	args.new = {
		type = "input",
		order = 30,
		name = L["New profile"],
		desc = L["Type a name and press Enter: a new profile with every setting at its default."],
		get = function() return "" end,
		validate = function(_, value) return P.NameFault(value) or true end,
		set = function(_, value) P.Create(value) end,
		disabled = Busy,
	}
	args.newCharacters = {
		type = "select",
		order = 31,
		name = L["New characters start on"],
		desc = L["The profile a character takes the first time it logs in with Manners. Characters that have logged in before keep theirs."],
		values = function()
			local out = Choices(false)
			out[DEFAULT] = DEFAULT
			return out
		end,
		get = function() return P.StartProfile() end,
		set = function(_, value)
			local global = Global()
			if not global then return end
			global.newCharacters = (type(value) == "string" and value ~= DEFAULT and P.Names()[value]) and value or nil
		end,
		disabled = Busy,
	}
	-- Under a key of its own: the library's Reset asks nothing, and ours does.
	-- The library's stays in the model, hidden (our copy of it: Profiles.lua).
	if type(args.reset) == "table" then args.reset.hidden = true end
	args.resetProfile = {
		type = "execute",
		order = 35,
		name = L["Reset this profile"],
		desc = L["Puts every setting of this profile back to its default."],
		func = function() P.Reset() end,
		disabled = Busy,
		confirm = true,
		confirmText = L["Put every setting of this profile back to its default? Undo puts them back."],
	}
end

-- Switching by where you are.
local function AddAuto(args)
	args.autoHeader = { type = "header", name = L["Switch automatically"], order = 90 }
	args.autoEnabled = {
		type = "toggle",
		order = 91,
		width = "full",
		name = L["Switch profile automatically"],
		desc = L["Switches this character to the profile you pick for where it is. Each character has its own choices."],
		get = function() return not AutoOff() end,
		set = function(_, value) SetEnabled(value) end,
	}
	args.switchNote = {
		type = "description",
		order = 98,
		name = L["On arriving somewhere, this character switches to the profile picked for it, once any fight is over. Do not switch keeps the profile in use, and so does a profile you pick yourself, until you next arrive somewhere else."],
	}
	for i, at in ipairs(SITUATIONS) do
		args["auto_" .. at] = RuleOption(at, 92 + i)
	end
	args.autoSay = {
		type = "toggle",
		order = 97,
		width = "full",
		name = L["Say so in chat"],
		desc = L["One line in chat at each automatic switch."],
		get = function()
			local st = Store()
			return st ~= nil and st.say
		end,
		set = function(_, value)
			local st = Store()
			if st then st.say = value == true end
		end,
		disabled = AutoOff,
	}
end

-- Where a pasted settings line goes (Options/Profiles.lua's paste box asks
-- P.PasteInto): into the profile in use, or into a new one named here.
local function AddPasteTarget(args)
	args.pasteInto = {
		type = "select",
		order = 103.5,
		name = L["Paste into"],
		desc = L["Where pasted settings go: over the profile in use, or into a new profile this character then switches to."],
		values = { mine = L["The profile in use"], new = L["A new profile"] },
		sorting = { "mine", "new" },
		get = function() return page.into end,
		set = function(_, value) page.into = value == "new" and "new" or "mine" end,
	}
	args.pasteName = {
		type = "input",
		order = 103.6,
		name = L["New profile's name"],
		desc = L["The name of the profile the pasted settings go into."],
		hidden = function() return page.into ~= "new" end,
		get = function() return page.pasteName end,
		set = function(_, value) page.pasteName = tostring(value or "") end,
	}
end

-- Into the Profiles tab's controls (Options/Profiles.lua). The six the
-- library builds (current, new, choose, copyfrom, delete, reset) are replaced
-- by ours, under its keys but for Reset.
function P.AddOptions(args)
	AddManager(args)
	AddStarts(args)
	AddAuto(args)
	AddPasteTarget(args)
end

---------------------------------------------------------------------------
-- what a profile change means here
---------------------------------------------------------------------------

-- AceDB calls these two by name (Core.lua, OnInitialize), so the wraps see
-- every change: any switch puts the page's dropdown back on the profile in
-- use; one the player made also ends what automatic switching chose,
-- anything it was waiting to do and the page's last line; and a deleted
-- profile's rules go back to "Do not switch".
do
	local Refresh = addon.RefreshConfig
	function addon:RefreshConfig(event, ...)
		if event == "OnProfileChanged" then page.pick = nil end
		if event == "OnProfileChanged" and not auto.switching then
			local st = Store()
			if st then st.chose = nil end
			auto.pending = nil
			page.last = nil
		end
		return Refresh(self, event, ...)
	end

	local Deleted = addon.ProfileDeleted
	function addon:ProfileDeleted(event, db, name, ...)
		Carry(Store(), name, nil)
		return Deleted(self, event, db, name, ...)
	end
end

-- A paste from anywhere (the page's box, /manners import) is the page's last
-- action, taken back by the import's own undo; one into a new profile says
-- so itself (P.PasteAsNew).
do
	local Import = ns.ImportSettings
	if Import then
		function ns.ImportSettings(...)
			local ok, message = Import(...)
			local name = P.Current()
			if ok and name and not page.pasting then
				page.last = { kind = "import", undo = true, profile = name,
					text = L["Pasted settings into %s."]:format(Gold(name)) }
			end
			return ok, message
		end
	end
end

-- A character's first login with Manners: AceDB has no record of it yet, and
-- the profile new characters start on (when it still exists) is written in
-- as its own before the library reads the file, so it starts there.
local function StartOn()
	local sv = rawget(_G, "MannersDB")
	if type(sv) ~= "table" then return end
	local key = LoginKey()
	if not key or (type(sv.profileKeys) == "table" and sv.profileKeys[key] ~= nil) then return end
	local global = sv.global
	local name = type(global) == "table" and global.newCharacters or nil
	if type(name) ~= "string" or name == DEFAULT then return end
	if not (type(sv.profiles) == "table" and type(sv.profiles[name]) == "table") then return end
	if type(sv.profileKeys) ~= "table" then sv.profileKeys = {} end
	sv.profileKeys[key] = name
end

do
	local Init = addon.OnInitialize
	function addon:OnInitialize(...)
		ns.Guard("new character's profile", StartOn)
		return Init(self, ...)
	end
end

-- Milestones' switch is the profile's, and a profile change is that switch
-- turned (Milestones.lua, M.Switched: whatever was passed is marked without a
-- toast). An automatic switch between two profiles that have it the same way
-- turned nothing, so nothing is marked behind the player's back.
do
	local M = ns.Milestones
	if M and M.Switched and M.On then
		local Switched = M.Switched
		function M.Switched(...)
			if auto.switching and auto.milestones == M.On() then return end
			return Switched(...)
		end
	end
end
