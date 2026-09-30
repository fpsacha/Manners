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

Page.HasClassBuffs, Page.OnlyReachesGroup = HasClassBuffs, OnlyReachesGroup
Page.HasPrompt, Page.OffersSelf = HasPrompt, OffersSelf

-- Whether the copy-for-a-bug-report box is open: a state of the window, not of
-- the profile, put back in OpenOptions and when the Settings page hides.
Page.reportOpen = false
-- And the box holding these settings as text, for the same reasons.
Page.shareOpen = false

-- Each tab's name, used for its own title and wherever text on another tab
-- points at it, so renaming a tab cannot leave a sentence naming the old one.
-- The keys are the group keys, which never change: Ledger.lua repaints by
-- "general", and the tests and bug reports name tabs by them.
local TAB = {
	general = L["Start here"],
	who = L["Who to buff"],
	when = L["When to offer"],
	click = L["What I say"],
	appearance = L["Look"],
	advanced = L["Advanced"],
	diagnostics = L["Diagnostics"],
}

-- Text that points at a control somewhere else: the control's name in gold,
-- the tab it is on in plain text. Where the dependency can be a `disabled` or
-- a `hidden` instead, it should be.
local function Ref(control, tab)
	return ("|cffffd100%s|r (%s)"):format(control, tab)
end

Page.TAB, Page.Ref = TAB, Ref
