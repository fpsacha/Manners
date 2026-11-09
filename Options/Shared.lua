-- Manners -- options: what several tabs of the page are built from.
--
-- The page is one file per tab, Options/<Tab>.lua, after this one and
-- Launcher.lua in the toc, and Register.lua last, which puts the tabs together
-- and registers them. They share this table: the setting accessors, the tab
-- names and the answers more than one tab asks. Each file copies what it uses
-- into locals of its own when it loads.

local _, ns = ...
local L = ns.L

local Page = {}
ns.OptionsPage = Page

---------------------------------------------------------------------------
-- get/set helpers
--
-- Each group binds to one table in the profile and uses the option's own key,
-- so adding an option is a one-liner rather than a pair of closures. A control
-- whose option key differs from its profile field (the sound controls) names
-- the field outright: moving a setting must never reset it.
---------------------------------------------------------------------------

local function bind(pathFn, after)
	local get = function(info) return pathFn()[info[#info]] end
	local set = function(info, value)
		pathFn()[info[#info]] = value
		if after then after() end
	end
	local getColor = function(info)
		local c = pathFn()[info[#info]] or { 1, 1, 1, 1 }
		return c[1], c[2], c[3], c[4] == nil and 1 or c[4]
	end
	local setColor = function(info, r, g, b, a)
		pathFn()[info[#info]] = { r, g, b, a }
		if after then after() end
	end
	return get, set, getColor, setColor
end

local function restyle() ns.Prompt:ApplyStyle() end
local function rescan() ns.addon:StartScanner() end
local function remacro() ns.Prompt:InvalidateMacro() end
local function restyleAndMacro()
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyStyle()
end

local function P() return ns.db.profile.prompt end
local function S() return ns.db.profile.sources end
local function F() return ns.db.profile.filters end
local function T() return ns.db.profile.timing end
local function SND() return ns.db.profile.sound end
local function SP() return ns.db.profile.speech end
local function B() return ns.db.profile.buff end
local function PR() return ns.db.profile.priority end

local pGet, pSet, pGetColor, pSetColor = bind(P, restyle)
-- The launcher's "N waiting" counts favours only while "People who buffed me"
-- is on, so throwing that switch changes the number on the bar.
local sGet, sSet = bind(S, function()
	if ns.RefreshBrokerText then ns.Guard("broker text", ns.RefreshBrokerText) end
end)
local fGet, fSet = bind(F)
-- The armed macro is only rebuilt when the candidate changes, so a filter that
-- alters what the macro says -- rather than who is on the prompt -- has to say
-- so. restoreTarget is the only one.
local fGetMacro, fSetMacro = bind(F, remacro)
local tGet, tSet = bind(T, rescan)
local spGet, spSet = bind(SP, remacro)
-- The buff dropdown reads the pin through its own get, so only the setter.
local bSet = select(2, bind(B, restyleAndMacro))
local prGet, prSet = bind(PR)

Page.restyle, Page.rescan, Page.restyleAndMacro = restyle, rescan, restyleAndMacro
Page.P, Page.S, Page.F, Page.SND, Page.SP, Page.B, Page.PR = P, S, F, SND, SP, B, PR
Page.pGet, Page.pSet, Page.pGetColor, Page.pSetColor = pGet, pSet, pGetColor, pSetColor
Page.sGet, Page.sSet, Page.fGet, Page.fSet = sGet, sSet, fGet, fSet
Page.fGetMacro, Page.fSetMacro, Page.tGet, Page.tSet = fGetMacro, fSetMacro, tGet, tSet
Page.spGet, Page.spSet, Page.bSet, Page.prGet, Page.prSet = spGet, spSet, bSet, prGet, prSet

---------------------------------------------------------------------------
-- what this character has to offer, asked by several tabs
---------------------------------------------------------------------------

local function HasClassBuffs()
	return ns.caps.hasClassBuffs == true
end

-- Whether everything this character could offer reaches its party and nobody
-- else -- a warrior's Battle Shout -- which leaves the strangers toggle with
-- nothing behind it. Core's answer, so the greeting and favour line agree.
local function OnlyReachesGroup()
	return ns.OnlyReachesGroup()
end

-- Whether there is a prompt on this character at all: a buff for somebody
-- else, or one of the class's own learned (a hunter's aspects). Start here's
-- key and preview steps and the Who to buff tab follow it.
local function HasPrompt()
	return ns.caps.hasClassBuffs == true or ns.OwnBuffsOnly()
end

-- Whether "Myself" is on and has something to offer: read by the warning that
-- nothing is ticked and by the summary on Start here, through the same answer
-- as the lines about saving mana (Core.lua), so they all agree.
local function OffersSelf()
	return ns.OffersSelf()
end

-- Whether every source on Who to buff is off, so the prompt never appears:
-- who.emptyWarning shows on it and the page's red dot reads it. A source this
-- class cannot use (passers-by, or yourself, for a warrior) does not count as
-- switched on: its toggle is hidden.
local function NoSources()
	local s = S()
	return not (s.owed or s.group or s.asked or (s.strangers and not OnlyReachesGroup())
		or OffersSelf())
end

Page.HasClassBuffs, Page.OnlyReachesGroup = HasClassBuffs, OnlyReachesGroup
Page.HasPrompt, Page.OffersSelf, Page.NoSources = HasPrompt, OffersSelf, NoSources

-- A family from the bags (Buffs.lua, `bagged`: food, the sleeping bag, a
-- flask, an elixir, a scroll): whether one of its items is in the bags, asked
-- of the client only for the page, and whether its switch under Myself is
-- shown -- food always, the rest while switched on or one is in the bags.
function Page.BaggedHeld(family)
	local count = C_Item and C_Item.GetItemCount
	if type(count) ~= "function" then return false end
	for _, spell in ipairs(family.spells) do
		local n = ns.plain(count(spell.item))
		if type(n) == "number" and n > 0 then return true end
	end
	return false
end

function Page.BaggedShown(family)
	-- A scroll's own switch is gone while Scrolls is off (Options/Who.lua), and
	-- counts here all the same: Scrolls stands under Myself in its place, to
	-- be turned on again.
	if family.food then return true end
	return ns.OwnPick(family) ~= "off" or Page.BaggedHeld(family)
end

-- Whether any such switch of this class is shown under Myself.
function Page.BaggedSwitchShown()
	for _, family in ipairs(ns.GetOwnFamilies() or {}) do
		if family.bagged and Page.BaggedShown(family) then return true end
	end
	return false
end

-- Whether a character with no prompt has a switch under Myself that would
-- give it one: a retail death knight with a flask in the bags, which is off
-- until it is turned on and so counts for nothing until then (Core's
-- OwnItemsHeld reads the families switched on). Who to buff is shown for it,
-- Myself and that switch alone, as a hunter's is; Start here's steps still
-- follow HasPrompt, since there is no prompt until the switch is on.
--
-- Food counts here only while it is on or in the bags, as the rest do: a
-- rogue with nothing in his bags still has no page about a prompt.
function Page.OwnSwitchWaiting()
	if HasPrompt() then return false end
	for _, family in ipairs(ns.GetOwnFamilies() or {}) do
		if family.bagged and (ns.OwnPick(family) ~= "off" or Page.BaggedHeld(family)) then return true end
	end
	return false
end

-- Move the prompt: the one switch for where the prompt sits, which people did
-- not find as a small checkbox on Look. A button that reads Move the prompt
-- while the prompt is locked and Lock it while it is not, going the way
-- /manners move and /manners lock do, through HandleSlash, so chat says the
-- same thing whichever way in (switched off, in a fight, snoozed). The window
-- draws it twice, in its header (general.moveToggle) and at the top of Look
-- (appearance.move), because its layout places a definition once; this makes
-- both, and the fallback dialog gets them as ordinary buttons.
--
-- Unlocking is a move of the secure prompt, which the client refuses in a
-- fight, so it is greyed out there with the minimap menu's words. Locking is a
-- flag the prompt reads (Press.lua), so Lock it still works in a fight, as the
-- status strip's does.
local function MoveControl(order)
	return {
		type = "execute",
		name = function() return P().locked and L["Move the prompt"] or L["Lock it"] end,
		desc = function()
			if not P().locked then
				return L["Locks the prompt where it is. An unlocked prompt does not buff anyone."]
			end
			local text = L["Unlocks the prompt so you can drag it where you want it; it locks itself when you let go."]
			if InCombatLockdown() then
				text = text .. "\n\n" .. L["The prompt cannot be moved or changed during a fight. This comes back once it ends."]
			end
			return text
		end,
		order = order,
		hidden = function() return not HasPrompt() end,
		disabled = function() return P().locked and InCombatLockdown() end,
		func = function()
			local profile = ns.db.profile
			if not profile.prompt.locked then
				ns.addon:HandleSlash("lock")
				return
			end
			if InCombatLockdown() then return end
			ns.addon:HandleSlash("unlock")
			-- The window sits over the spot the prompt starts at, and a prompt
			-- behind it cannot be dragged: out of the way, as for the game's
			-- key bindings, whenever there is a prompt up to drag. Switched
			-- off, the line in chat says why there is none, and the switch is
			-- in the header.
			if profile.enabled and not profile.prompt.locked then ns.CloseOptions() end
		end,
	}
end
Page.MoveControl = MoveControl

-- Whether the copy-for-a-bug-report box is open: a state of the window, not of
-- the profile, put back in OpenOptions and when the Settings page hides.
Page.reportOpen = false
-- And the box holding these settings as text, for the same reasons.
Page.shareOpen = false

-- Each page's name, used for its own title and wherever text on another page
-- points at it, so renaming a page cannot leave a sentence naming the old one.
-- The keys are the page ids, which never change: Ledger.lua repaints by
-- "general", and the tests and bug reports name pages by them. Who to skip is
-- a page of the window built from Who to buff's controls, not a group.
local TAB = {
	general = L["Start here"],
	who = L["Who to buff"],
	skip = L["Who to skip"],
	when = L["When to offer"],
	click = L["What I say"],
	appearance = L["Look"],
	diagnostics = L["Diagnostics"],
}

-- Text that points at a control on another page: the control's name in gold,
-- the page it is on in plain text. Where the dependency can be a `disabled` or
-- a `hidden` instead, it should be.
local function Ref(control, tab)
	return ("|cffffd100%s|r (%s)"):format(control, tab)
end

Page.TAB, Page.Ref = TAB, Ref

---------------------------------------------------------------------------
-- who the settings come to right now
--
-- A grey line at the top of Who to buff, Who to skip and When to offer: who
-- the prompt is on and how many wait behind them, so a change to a switch
-- can be seen to do something. Read off what the last scan left (the
-- prompt's own entry and the queue it was picked from): never a queue built
-- for a paint. Nil while a preview stands in for the real prompt.
---------------------------------------------------------------------------

local RIGHT_NOW = {
	owed = L["Right now: |cffffffff%s|r -- %s, buffed you."],
	group = L["Right now: |cffffffff%s|r -- %s, in your group."],
	target = L["Right now: |cffffffff%s|r -- %s, your target."],
	nearby = L["Right now: |cffffffff%s|r -- %s, a passer-by."],
	asked = L["Right now: |cffffffff%s|r -- %s, asked for it."],
	self = L["Right now: |cffffffff%s|r -- %s, your own buff."],
}

function Page.RightNow()
	local prompt = ns.Prompt
	if not prompt or (prompt.InTest and prompt:InTest()) then return nil end
	local showing = prompt.Showing and prompt:Showing()
	if not showing then
		-- Nobody because the prompt holds everybody back -- switched off,
		-- unlocked, snoozed, mounted -- said as the launcher and the status
		-- strip say it, not as an empty crowd. In a fight nobody new can come
		-- on until it ends. Options/Launcher.lua loads after this file.
		local watching, line = false, nil
		if ns.LauncherState then watching, line = ns.LauncherState() end
		if watching == false and type(line) == "string" and line ~= "" then
			return "|cff888888" .. L["Right now: %s"]:format(line) .. "|r"
		end
		if InCombatLockdown() then
			return "|cff888888" .. L["Right now: nobody, and nobody new comes on the prompt until this fight ends."] .. "|r"
		end
		return "|cff888888" .. L["Right now: nobody to offer."] .. "|r"
	end
	local others = 0
	local queue = prompt.state and prompt.state.pickedFrom
	for _, entry in ipairs(type(queue) == "table" and queue or {}) do
		if entry.name ~= showing.name then others = others + 1 end
	end
	local who = tostring(showing.display or showing.short or showing.name)
	local spell = (ns.EntrySpellName and ns.EntrySpellName(showing)) or (showing.buff and ns.BuffName(showing.buff)) or "?"
	local text = (RIGHT_NOW[showing.reason] or RIGHT_NOW.nearby):format(who, tostring(spell))
	if others == 1 then
		text = text .. " " .. L["1 more is waiting."]
	elseif others > 1 then
		text = text .. " " .. L["%d more are waiting."]:format(others)
	end
	return "|cff888888" .. text .. "|r"
end

-- The line as a description, one for each page it leads (a placed control is
-- placed once). `windowOnly`: drawn only by the options window, so the old
-- dialog, which puts Who to buff and Who to skip on one tab, says it once.
function Page.RightNowNote(order, windowOnly)
	return {
		type = "description",
		order = order,
		fontSize = "medium",
		hidden = function()
			if not HasPrompt() or Page.RightNow() == nil then return true end
			return windowOnly and not (ns.OptionsWindow and ns.OptionsWindow:IsShown()) or false
		end,
		name = function() return Page.RightNow() or "" end,
	}
end

---------------------------------------------------------------------------
-- the sidebar's red dots
--
-- One predicate per page that can hold a warning, true while that page's
-- warning shows. Each asks the same answers the warning's own `hidden` asks,
-- never the note's text or colour, so the dot and the note cannot disagree.
-- Read at paint time, after every tab file has loaded.
---------------------------------------------------------------------------

-- A buff pinned in Buff to offer that this character has not learned: offered
-- to nobody (who.pinNote in red).
local function PinUnlearned()
	local pin = ns.PinnedBuff()
	return pin ~= nil and not ns.IsBuffKnown(pin)
end

-- Automatic with nothing it can cast (who.autoNote in red).
local function NothingCastable()
	return ns.PinnedBuff() == nil and #ns.CastableBuffs() == 0
end

-- Start here has none: a key is optional (clicking the prompt works), so no
-- key is said in gold under step 2, never as a fault.
Page.Warn = {
	-- emptyWarning, pinNote, autoNote; strangersPlatesNote (Who.lua,
	-- Page.PlatesWanted: passers-by on and the friendly nameplates off).
	who = function()
		if not HasClassBuffs() then return false end
		return NoSources() or PinUnlearned() or NothingCastable()
			or (Page.PlatesWanted ~= nil and Page.PlatesWanted())
	end,
	-- when.alwaysNote.
	when = function()
		return HasClassBuffs() and F().whenBuffed == "always"
	end,
	-- appearance.noSound, appearance.accentDead.
	appearance = function()
		return (SND().enabled == true and SND().file == "None") or Page.AccentDead()
	end,
	-- diagnostics.errorList.
	diagnostics = function()
		return #ns.errors > 0
	end,
}
