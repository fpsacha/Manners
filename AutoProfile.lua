-- Manners -- profiles: making, copying, renaming and deleting one from the
-- Profiles page, and switching by where you are.
--
-- A profile is AceDB's: every setting on the other pages, shared by whichever
-- characters use it. This file is the page's own way to the library's calls
-- (ns.Profiles: Create, Rename, Use, CopyFrom, Delete, Reset), the controls
-- for them (Profiles.AddOptions, called by Options/Profiles.lua; they take the
-- place of AceDBOptions' own, under the same keys, so the page is the same
-- whatever the library builds), and automatic switching.
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
-- Core.lua is not edited for any of this: its two AceDB callbacks are called
-- by name, so the wraps at the end of this file see every profile change.

local _, ns = ...
local L = ns.L
local plain = ns.plain
local addon = ns.addon

local P = {}
ns.Profiles = P

local GOLD = "|cffffd100"
-- AceDBOptions' own limit for a profile's name.
local NAME_MAX = 50
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
-- The dropdown's value for "Do not switch": no profile has an empty name.
local NONE = ""

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
			if type(name) == "string" then out[name] = true end
		end
	end
	local current = P.Current()
	if current then out[current] = true end
	return out
end

local function Trim(text)
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
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

-- A new profile under `name`, and this character on it: every setting at its
-- default, or with `copy` the settings of the profile in use.
function P.Create(name, copy)
	name = Trim(name)
	local db = Ready()
	if not db then return false end
	local fault = P.NameFault(name)
	if fault then return false, fault end
	local from = P.Current()
	db:SetProfile(name)
	if copy and type(db.CopyProfile) == "function" then db:CopyProfile(from, true) end
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

-- The profile in use under another name. AceDB has no rename: a new profile,
-- the old one copied into it, the old one deleted. Every character that was
-- on the old name is put on the new one (the library's own record of who uses
-- what), and every rule that named it, this character's and the others',
-- follows.
function P.Rename(name)
	name = Trim(name)
	local db = Ready()
	if not db or type(db.CopyProfile) ~= "function" or type(db.DeleteProfile) ~= "function" then return false end
	local fault = P.NameFault(name)
	if fault then return false, fault end
	local old = P.Current()
	local st = Store()
	-- The switch below is the page's own doing, not the player picking
	-- another profile: what automatic switching chose stays chosen.
	local chose = st and st.chose
	db:SetProfile(name)
	db:CopyProfile(old, true)
	if st then st.chose = chose end
	Carry(st, old, name)
	local sv = db.sv
	if type(sv) == "table" then
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
	db:DeleteProfile(old, true)
	if ns.RepaintOptions then ns.RepaintOptions() end
	return true
end

function P.Use(name)
	local db = Ready()
	if not db or type(name) ~= "string" or not P.Names()[name] then return false end
	db:SetProfile(name)
	return true
end

-- Every setting of `name` over the profile in use.
function P.CopyFrom(name)
	local db = Ready()
	if not db or type(db.CopyProfile) ~= "function" then return false end
	if type(name) ~= "string" or name == P.Current() or not P.Names()[name] then return false end
	db:CopyProfile(name, true)
	return true
end

-- Never the profile in use: the library refuses it too.
function P.Delete(name)
	local db = Ready()
	if not db or type(db.DeleteProfile) ~= "function" then return false end
	if type(name) ~= "string" or name == P.Current() or not P.Names()[name] then return false end
	db:DeleteProfile(name, true)
	if ns.RepaintOptions then ns.RepaintOptions() end
	return true
end

function P.Reset()
	local db = Ready()
	if not db or type(db.ResetProfile) ~= "function" then return false end
	db:ResetProfile()
	return true
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
local function NoOthers() return Busy() or next(Choices(true)) == nil end

local function Typed(make)
	return {
		get = function() return "" end,
		validate = function(_, value)
			return P.NameFault(value) or true
		end,
		set = function(_, value) make(value) end,
		disabled = Busy,
	}
end

local function With(option, fields)
	for key, value in pairs(fields) do option[key] = value end
	return option
end

local function AutoOff()
	local st = Store()
	return not (st and st.enabled)
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

-- Into the Profiles tab's controls (Options/Profiles.lua). The six the
-- library builds (current, new, choose, copyfrom, delete, reset) are replaced
-- by ours, under its keys but for Reset; its grey sentences beside them stay.
function P.AddOptions(args)
	args.current = {
		type = "description",
		order = 11,
		fontSize = "medium",
		hidden = function() return P.Current() == nil end,
		name = function()
			local text = L["This character uses the profile %s."]:format(GOLD .. tostring(P.Current() or "") .. "|r")
			local why = P.Why()
			return why and (text .. " " .. why) or text
		end,
	}
	args.new = With(Typed(function(value) P.Create(value, false) end), {
		type = "input",
		order = 30,
		name = L["New profile"],
		desc = L["Type a name and press Enter: a new profile with every setting at its default."],
	})
	args.saveAs = With(Typed(function(value) P.Create(value, true) end), {
		type = "input",
		order = 31,
		name = L["New profile from these settings"],
		desc = L["Type a name and press Enter: a new profile that starts as a copy of the one in use, and this character switches to it."],
	})
	args.rename = With(Typed(function(value) P.Rename(value) end), {
		type = "input",
		order = 32,
		name = L["Rename this profile"],
		desc = L["Type the new name and press Enter. Every character on this profile stays on it, and automatic switching follows the new name."],
	})
	args.choose = {
		type = "select",
		order = 40,
		name = L["Use profile"],
		desc = L["The profile this character uses."],
		values = function() return Choices(false) end,
		get = function() return P.Current() end,
		set = function(_, value) P.Use(value) end,
		disabled = Busy,
	}
	-- How a profile is edited, said once, under the dropdown that does it.
	args.editNote = {
		type = "description",
		order = 41,
		name = L["To change a profile's settings, switch to it: every page shows and changes the profile in use."],
	}
	args.copyfrom = {
		type = "select",
		order = 60,
		name = L["Copy from"],
		desc = L["Replaces this profile's settings with the ones of the profile you pick."],
		values = function() return Choices(true) end,
		get = function() return nil end,
		set = function(_, value) P.CopyFrom(value) end,
		disabled = NoOthers,
		confirm = function(_, value)
			return L["Replace every setting of this profile with the ones of %s?"]:format(tostring(value))
		end,
	}
	args.delete = {
		type = "select",
		order = 80,
		name = L["Delete"],
		desc = L["Deletes the profile you pick. It asks first."],
		-- The profile in use is not in the list, and P.Delete refuses it.
		values = function() return Choices(true) end,
		get = function() return nil end,
		set = function(_, value) P.Delete(value) end,
		disabled = NoOthers,
		confirm = true,
		confirmText = L["Delete this profile? This cannot be undone."],
	}
	-- Under a key of its own: the library's Reset asks nothing, and ours does.
	-- The library's stays in the model, hidden (our copy of it: Profiles.lua).
	if type(args.reset) == "table" then args.reset.hidden = true end
	args.resetProfile = {
		type = "execute",
		order = 10,
		name = L["Reset this profile"],
		desc = L["Puts every setting of this profile back to its default."],
		func = function() P.Reset() end,
		disabled = Busy,
		confirm = true,
		confirmText = L["Put every setting of this profile back to its default? This cannot be undone."],
	}

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

---------------------------------------------------------------------------
-- what a profile change means here
---------------------------------------------------------------------------

-- AceDB calls these two by name (Core.lua, OnInitialize), so the wraps see
-- every change: one the player made ends what automatic switching chose and
-- anything it was waiting to do, and a deleted profile's rules go back to
-- "Do not switch".
do
	local Refresh = addon.RefreshConfig
	function addon:RefreshConfig(event, ...)
		if event == "OnProfileChanged" and not auto.switching then
			local st = Store()
			if st then st.chose = nil end
			auto.pending = nil
		end
		return Refresh(self, event, ...)
	end

	local Deleted = addon.ProfileDeleted
	function addon:ProfileDeleted(event, db, name, ...)
		Carry(Store(), name, nil)
		return Deleted(self, event, db, name, ...)
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
