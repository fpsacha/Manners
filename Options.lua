-- Manners -- options table, Blizzard settings panel, minimap button.

local ADDON, ns = ...
-- Player-facing text, in the client's language: see Locales/Init.lua.
local L = ns.L

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
-- Asked for optionally. It ships inside AceConfig-3.0 and will be there, but
-- the only thing that depends on it is the page repainting itself when a fight
-- ends -- and a missing library must not take the options screen with it.
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
local AceDBOptions = LibStub("AceDBOptions-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

-- The logo tools/make-icon.py draws, and the same file the toc's IconTexture
-- names, so the minimap button and the addon list show one picture. It was a
-- Blizzard spell icon while the TGA shipped in every zip with nothing pointing
-- at it. No extension: the client finds the .tga itself.
local ICON = "Interface\\AddOns\\Manners\\Textures\\Manners64"

-- Whether there is a minimap button at all.
--
-- It takes both libraries and SetupOptions only registers one when it has both:
-- LibDataBroker makes the data object, LibDBIcon is what puts it on the
-- minimap. Either missing and there is nothing on the minimap to show or hide.
local function HasMinimapButton()
	return LDB ~= nil and LDBIcon ~= nil
end

-- The launcher, once it exists. Kept at file scope so its text can be put back
-- in step from outside SetupOptions, which runs once and then never again.
local broker

-- Asked with a net under it: the tooltip and the launcher text are read by
-- other addons' display frames, on their own schedule, and one of them asking
-- before AceDB has handed us a profile must not throw inside somebody else's
-- layout pass.
local function Enabled()
	return ns.db ~= nil and ns.db.profile ~= nil and ns.db.profile.enabled == true
end

-- How many people who buffed you are still waiting for one back.
--
-- The favours, and not the whole queue. A crowd in a city puts a dozen
-- strangers missing a buff into the queue on every scan, and a bar reading
-- "12 waiting" all evening is a number nobody reads twice; somebody who buffed
-- you is the one kind of person actually waiting for something. Counted by the
-- debt's live expiry, the one every other reader of the debts asks.
local function WaitingCount()
	local owed, expiry = ns.owed, ns.DebtExpiry
	if type(owed) ~= "table" or type(expiry) ~= "function" then return 0 end
	local now, n = GetTime(), 0
	for _, debt in pairs(owed) do
		if type(debt) == "table" then
			local ok, ends = pcall(expiry, debt)
			if ok and type(ends) == "number" and ends > now then n = n + 1 end
		end
	end
	return n
end

-- What the launcher says it is.
--
-- It used to say "Manners" and nothing else, which on a broker display is the
-- addon's name written next to the addon's icon -- so the only way to find out
-- whether it was switched on was to right-click it and read chat, and that
-- changes the answer. Off is the state worth carrying: the prompt simply never
-- appears, and from the outside that is exactly what a broken addon looks like.
local function BrokerText()
	-- A snooze is the other state in which no prompt appears on purpose, and
	-- the end of it is the part worth reading off a bar. Only while on: off
	-- outranks it, since a snooze ending brings nothing back while off.
	local ends = Enabled() and ns.SnoozeEndsAt and ns.SnoozeEndsAt()
	if ends then return ("Manners |cffffd100%s|r"):format(L["snoozed until %s"]:format(ends)) end
	if not Enabled() then return "Manners |cffff8080" .. L["off"] .. "|r" end
	-- Then the favours still to return, which is the number worth glancing at
	-- a bar for. Nothing at all when there are none, so a quiet evening reads
	-- as the name and nothing else, as it always has.
	local waiting = WaitingCount()
	if waiting == 1 then return "Manners |cff80e080" .. L["1 waiting"] .. "|r" end
	if waiting > 1 then return ("Manners |cff80e080%s|r"):format(L["%d waiting"]:format(waiting)) end
	return "Manners"
end

-- The colour the launcher's icon is drawn in: dimmed while switched off,
-- warmed while snoozed, as it is otherwise. The icon is the only part of the
-- launcher on the minimap that is always in view -- the text is only on a
-- broker bar, and the tooltip only on a hover -- so it is the one place a
-- glance can tell a resting addon from a working one.
local function IconTint()
	if not Enabled() then return 0.45, 0.45, 0.45 end
	if ns.SnoozeLeft and ns.SnoozeLeft() then return 1, 0.78, 0.35 end
	return 1, 1, 1
end

---------------------------------------------------------------------------
-- get/set helpers
--
-- Each group binds to one table in the profile and uses the option's own key,
-- so adding an option is a one-liner rather than a pair of closures.
--
-- Where a control has moved between tabs its key has deliberately not changed,
-- and where it had to -- the three sound controls, which now sit beside the
-- flash setting on a tab that has its own `enabled` -- the get and set name the
-- profile field outright instead of reading it off the option's key. Moving a
-- setting must never be a setting reset.
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

-- Redraw the page once a run of slider ticks has stopped.
--
-- For the Width and Height sliders, which shrink the icon to fit and so change
-- what another slider on the page should be showing. The dialog redraws a
-- slider when a drag is let go, but a mouse wheel never lets go of anything, so
-- without this a wheel left the Icon size slider showing a value the prompt was
-- no longer using. Held back rather than immediate because a redraw rebuilds
-- the slider being dragged under the pointer; each call replaces the one
-- before, so a wheel or a drag ends with a single redraw. C_Timer.After cannot
-- be cancelled, hence the token.
local repaintToken = 0
local function RepaintSoon()
	repaintToken = repaintToken + 1
	local mine = repaintToken
	C_Timer.After(0.3, function()
		if mine == repaintToken and ns.RefreshOptionsDisplay then
			ns.Guard("icon repaint", ns.RefreshOptionsDisplay)
		end
	end)
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
local sGet, sSet = bind(S)
local fGet, fSet = bind(F)
-- The armed macro is only rebuilt when the candidate changes, so a filter that
-- alters what the macro says -- rather than who is on the prompt -- has to say
-- so. restoreTarget is the only one.
local fGetMacro, fSetMacro = bind(F, remacro)
local tGet, tSet = bind(T, rescan)
local spGet, spSet = bind(SP, remacro)
local bGet, bSet = bind(B, restyleAndMacro)
local prGet, prSet = bind(PR)

---------------------------------------------------------------------------
-- dynamic values
---------------------------------------------------------------------------

local function HasClassBuffs()
	return ns.caps.hasClassBuffs == true
end

local function BuffChoices()
	local values = { auto = "Automatic" }
	for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
		local info = ns.BuffInfo(buff)
		local label = (info and info.name) or buff.key
		if not (info and info.known) then label = label .. " |cff808080(not learned)|r" end
		values[buff.key] = label
	end
	return values
end

-- The named distances, read off the list Core.lua measures with.
--
-- Both built from the one table rather than written out here as well: a
-- dropdown that has its own copy of the choices is a dropdown that can offer a
-- setting nothing implements, and an ordering with its own copy is one that
-- silently drops a new entry off the end.
local function ProximityChoices()
	local values = {}
	for _, tier in ipairs(ns.PROXIMITY) do
		values[tier.key] = tier.name
	end
	return values
end

-- AceConfig sorts a select's values by their labels unless it is given an
-- order, and alphabetically these read "Anywhere I can cast", "Nearby", "Right
-- beside me" -- which is loosest to tightest by luck rather than by design. One
-- rename would scramble them.
local function ProximityOrder()
	local keys = {}
	for _, tier in ipairs(ns.PROXIMITY) do
		keys[#keys + 1] = tier.key
	end
	return keys
end

-- The spell's name, with the one thing about it that changes who it is offered
-- to. A priest reading "Divine Spirit" has no way to know from the page that a
-- warrior will never see it.
--
-- Unless "Skip players the buff does nothing for" is off, which is the only
-- thing that holds a mana-only spell back from a warrior. With it off the
-- warrior is offered Divine Spirit, and the qualifier was a promise about a
-- filter that was not running.
local function BuffLabel(buff)
	local label = ns.BuffName(buff)
	if buff.manaOnly and F().relevantOnly then
		label = label .. " |cff808080(mana users only)|r"
	end
	if buff.partyOnly then label = label .. " |cff808080(your group only)|r" end
	return label
end

-- What "Automatic" will actually do, for this character, as it is configured
-- right now.
--
-- It used to name Wisdom and Might and nothing else -- the single class whose
-- auto pick depends on who is standing there -- so every other class read an
-- explanation of somebody else's spells. Automatic is a walk down the class
-- list now rather than one resolved choice, so the list in the order it is
-- walked is the answer, and it is taken from the same function the scan uses so
-- the two cannot drift.
local function AutoExplanation()
	local castable = ns.CastableBuffs()
	if #castable == 0 then
		-- Three ways to have nothing to offer, and they are three different
		-- problems with three different answers. One line saying "nothing is
		-- switched on" would be wrong for two of them, and wrong in the
		-- direction that sends somebody looking at the switches.
		if not HasClassBuffs() then
			return "This character has nothing it can cast on another player."
		end
		local anyKnown = false
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if ns.IsBuffKnown(buff) then anyKnown = true end
		end
		if not anyKnown then
			return "|cffff8080You have not learned any of these yet, so nobody will be"
				.. " offered anything.|r"
		end
		-- A fourth way, which arrived with the per-flavour tables: everything
		-- learned and switched on, and the only thing learned is one Automatic
		-- deliberately never reaches for -- a Mists warlock with Unending Breath
		-- and no Dark Intent yet. Both answers above would be false, and the one
		-- below would send somebody hunting for a switch that is already on.
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if buff.neverAuto and ns.IsBuffKnown(buff) and not B().skip[buff.key] then
				return ("|cffff8080Automatic never offers %s -- nobody standing in a"
					.. " city wants it -- so nobody will be offered anything.|r\n\nPin it"
					.. " in the dropdown above if you want it given out anyway.")
					:format(ns.BuffName(buff))
			end
		end
		-- Everything learned is switched off -- but the spells not learned yet
		-- are still ticked below, and learning one of them brings the prompt
		-- back without anybody touching a switch. "Every spell" and "never" are
		-- only both true once those are unticked as well. A neverAuto spell is
		-- left out: learning it would bring nothing back.
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if not buff.neverAuto and not ns.IsBuffKnown(buff) and not B().skip[buff.key] then
				return "|cffff8080Every spell you have learned is switched off, so nothing is"
					.. " offered until you switch one back on or learn one of the others.|r"
			end
		end
		return "|cffff8080Every spell below is switched off, so the prompt will never"
			.. " appear.|r"
	end

	local names = {}
	for _, buff in ipairs(castable) do
		names[#names + 1] = "|cffffffff" .. BuffLabel(buff) .. "|r"
	end
	local list = table.concat(names, ", ")

	-- Blessings overwrite one another, so for these classes Automatic is not a
	-- walk at all: it gives one and stops. Saying "the first of these they are
	-- missing" here would promise a rotation that would take away what the last
	-- click gave.
	--
	-- "Left alone" rests on reading what they carry, and two things stop the
	-- reading: "Always offer" chooses not to look, and a client that hides a
	-- blessing's aura cannot. Either way the walk hands out the first blessing
	-- that suits them -- deliberately, see PickBuffFor -- and for a mana user
	-- wearing your Might that is Wisdom, which takes the Might away. The note
	-- said it could not happen.
	if ns.EXCLUSIVE_BUFFS[ns.caps.class] then
		local text = ("Your blessings replace one another, so Automatic gives one and stops:"
			.. " the first of %s that suits them. Anybody already carrying one of yours is"
			.. " left alone rather than handed a different one"):format(list)
		local hidden = false
		for _, buff in ipairs(castable) do
			local info = ns.BuffInfo(buff)
			if not (info and info.readable) then hidden = true end
		end
		if F().whenBuffed == "always" then
			return text .. " -- except with |cffffd100Always offer|r chosen, which does not look:"
				.. " then the first that suits them is offered, and it can replace one of yours."
		elseif hidden then
			return text .. " -- except where the game won't show which blessing they carry:"
				.. " then the first that suits them is offered, and it can replace one of yours."
		end
		return text .. "."
	end

	local text = ("Automatic offers the first of these they are missing, in this order: %s.")
		:format(list)
	if ns.RotatesBuffs() then
		text = text .. "\n|cff888888Where the game will not say what somebody is carrying, it"
			.. " moves down the list each time instead of offering the same one over and"
			.. " over.|r"
	end
	return text
end

-- What pinning one spell means, and the one case where pinning is a silent
-- switch-off.
--
-- A pinned buff you have not learned is not a fallback: the scan resolves the
-- pin, finds it unlearned and offers that person nothing, and it does that for
-- everybody -- so the addon goes quiet with nothing anywhere saying why. The
-- pin is deliberately not reset for you (a failed spell probe must not rewrite
-- a setting), which is exactly why it has to be said out loud here.
local function PinExplanation()
	local choice = B().choice
	local buff = ns.FindBuff(ns.caps.class, choice)
	local name = buff and ns.BuffName(buff) or tostring(choice)

	if buff and ns.IsBuffKnown(buff) then
		return ("Only |cffffffff%s|r is ever offered, to everybody, whatever else they are"
			.. " missing. The per-spell switches above apply to Automatic and are left alone"
			.. " while one spell is pinned."):format(name)
	end

	return ("|cffff8080You have pinned %s, which you have not learned.|r\n\nNothing will be"
		.. " offered to anybody until you learn it or switch back to Automatic -- a pinned"
		.. " spell is the only one considered, so there is nothing to fall back to.")
		:format(name)
end

-- One toggle per spell the class can put on somebody else.
--
-- Built once, with the page: which spells a class has never changes during a
-- session -- only whether each is learned, which the label asks for live.
-- Sparse on the way in as well as out: switched on is the *absence* of a key,
-- so a profile nobody has touched stores nothing at all and every existing one
-- arrives with the whole list on.
local function AddBuffToggles(args)
	local buffs = ns.GetClassBuffs(ns.caps.class) or {}
	-- One spell is not a choice. The walk has nothing to walk, and a lone
	-- toggle under "Automatic" reads as a second way to switch the addon off.
	if #buffs < 2 then return end

	for index, buff in ipairs(buffs) do
		args["offer_" .. buff.key] = {
			type = "toggle",
			name = function()
				local label = BuffLabel(buff)
				if not ns.IsBuffKnown(buff) then
					label = label .. " |cff808080(not learned)|r"
				end
				return label
			end,
			desc = "Switched off, this one is never offered to anybody and Automatic walks"
				.. " straight past it. Everything else carries on as before.",
			-- Sub-one steps so the whole block sits between the buff dropdown
			-- and the Sources header whatever the class has, and in the order
			-- the walk visits them.
			order = 4 + index / 10,
			width = "full",
			-- A pinned spell is the only one considered, so these would be
			-- switches over something that is not consulted. Only a pin of this
			-- class's counts: another class's is Automatic here.
			hidden = function() return ns.PinnedBuff() ~= nil end,
			disabled = function() return not ns.IsBuffKnown(buff) end,
			get = function() return not B().skip[buff.key] end,
			set = function(_, value)
				-- nil rather than false: AceDB stores the difference from the
				-- defaults, and an empty table is stored as nothing.
				B().skip[buff.key] = (not value) or nil
				restyleAndMacro()
			end,
		}
	end
end

-- Whether everything this character could offer reaches its party and nobody
-- else -- a warrior's Battle Shout. For these classes the strangers toggle is a
-- switch with nothing behind it. Core's answer, which the greeting and the
-- favour line read as well; a copy here is how the three would come to
-- disagree.
local function OnlyReachesGroup()
	return ns.OnlyReachesGroup()
end

-- Whether nothing this character can offer takes a target at all -- a warrior,
-- whose Battle Shout is cast on himself and heard by the party.
--
-- CastLines builds no /target line for a selfCast buff and returns restore =
-- false with it, so for these classes the whole Targeting section is about a
-- line the macro will never contain: a toggle that does nothing and a note
-- explaining a /target that is not there. Computed the same way
-- OnlyReachesGroup is, and for the same reason -- it follows the per-spell
-- switches and a pin, so a warrior who learns something targetable gets the
-- control back on its own.
local function NeverTargets()
	local castable = ns.CastableBuffs()
	if #castable == 0 then return false end
	for _, buff in ipairs(castable) do
		if not buff.selfCast then return false end
	end
	return true
end

-- Which of the two things that can carry the reason colour is actually on
-- screen, given every setting that silently takes one away.
--
-- Both are switched off somewhere other than the dropdown that asks for them,
-- and neither says so: ApplyStyle refuses the stripe on the framed look, and
-- the ring is a texture *behind* the icon, so hiding the icon takes it -- and so
-- does rounding the icon off, which swaps that texture for a mask. Pick the
-- ring, round the icon, and the setting above reads "Ring around the icon" over
-- a prompt with no reason colour anywhere on it.
--
-- Returns two booleans rather than one, because the interesting answer is which
-- one is left, not merely whether any is.
local function AccentCarriers()
	local p = P()
	local mode = p.accentMode or "icon"
	local ring = (mode == "icon" or mode == "both") and p.showIcon and not p.roundIcon
	local stripe = (mode == "stripe" or mode == "both") and p.style ~= "framed"
	return ring == true, stripe == true
end

-- Whether the copy-for-a-bug-report box is open.
--
-- A file local rather than a setting: it is a state of the window rather than
-- of the profile, and one that has no business surviving the window being shut.
-- Put back in OpenOptions and when the Settings page hides; see there.
local reportOpen = false
-- And the box holding these settings as text, for the same reasons.
local shareOpen = false

-- Everything somebody would otherwise be asked for twice, in one block that can
-- be selected and pasted. No colour codes: this is written to be quoted
-- somewhere that is not a chat frame.
local function BugReport()
	local lines = { ("Manners %s"):format(tostring(ns.BUILD)) }

	-- Guarded, not assumed. This is read from a `get`, which nothing wraps, and
	-- a client without GetBuildInfo would otherwise take the whole page down at
	-- the moment somebody is trying to report that something is broken.
	local ok, version, build, _, toc = pcall(GetBuildInfo)
	if ok and version then
		lines[#lines + 1] = ("client %s (%s), interface %s")
			:format(tostring(version), tostring(build), tostring(toc))
	end

	local caps = ns.caps
	lines[#lines + 1] = ("class %s | secrets %s | auras secret now %s | nameplates %s")
		:format(tostring(caps.class), tostring(caps.hasSecrets),
			tostring(caps.aurasSecretNow), tostring(caps.namePlates))
	-- Which spell tables this client was handed. Without it, a report about a
	-- spell that is never offered cannot be told from a report about a spell
	-- that no longer exists on the reporter's client.
	lines[#lines + 1] = ("buff data %s%s"):format(tostring(ns.BUFFS_SOURCE),
		ns.BUFFS_MISSING and (" -- " .. tostring(ns.BUFFS_MISSING)) or "")

	for _, buff in ipairs(ns.GetClassBuffs(caps.class) or {}) do
		local info = ns.BuffInfo(buff)
		lines[#lines + 1] = ("  %-12s known=%s readable=%s off=%s"):format(
			buff.key,
			tostring(info and info.known),
			tostring(info and info.readable),
			tostring(B().skip[buff.key] == true))
		if info and info.unresolved and #info.unresolved > 0 then
			lines[#lines + 1] = ("    no such spell on this client: %s"):format(
				table.concat(info.unresolved, ", "))
		end
	end

	-- The settings that change what it does, rather than how it looks. A report
	-- that leaves these out is a report about the defaults.
	local db = ns.db.profile
	lines[#lines + 1] = ("enabled=%s buff=%s sources owed/group/strangers=%s/%s/%s"
		.. " whenBuffed=%s targetFirst=%s keepDebts=%s"):format(
		tostring(db.enabled), tostring(db.buff.choice),
		tostring(db.sources.owed), tostring(db.sources.group), tostring(db.sources.strangers),
		tostring(db.filters.whenBuffed), tostring(db.priority.target),
		tostring(db.timing.keepDebts))
	-- Who is ordered and who is held back, as opposed to who is on the list at
	-- all. A report of "my friend is never offered" is answered by the last
	-- number here more often than by anything else.
	lines[#lines + 1] = ("friendsFirst=%s restingOnly=%s neverOffered=%d"):format(
		tostring(db.priority.friends), tostring(db.filters.restingOnly), #ns.NeverList())

	local scan = ns.auraScan
	lines[#lines + 1] = ("own buffs: %s read, baseline %s, primed=%s, doubt=%s"):format(
		tostring(scan.read), tostring(scan.held), tostring(scan.primed), tostring(scan.doubt))

	-- The second favour source, where the client has one. Left out entirely
	-- rather than reported as zeroes on a client with no combat log: a line
	-- about a source that cannot exist there is a question the person reading
	-- the report has to go and answer before they can ignore it.
	if caps.combatLog then
		local log = ns.logScan
		lines[#lines + 1] = ("combat log: armed=%s, %s seen, %s filed"):format(
			tostring(log.armed), tostring(log.applied), tostring(log.noted))
	end

	if #ns.errors == 0 then
		lines[#lines + 1] = "errors: none this session"
	else
		-- How many have happened, then how many are still here to read. The ring
		-- holds thirty, so its length was never the count this line claimed to
		-- print: "errors: 30 this session" is what a handler throwing on every
		-- frame looks like and what three unrelated bugs look like, and the
		-- person receiving this report cannot ask which.
		lines[#lines + 1] = ("errors: %d this session (%d kept), last five:")
			:format(ns.errorCount or #ns.errors, #ns.errors)
		for i = math.max(1, #ns.errors - 4), #ns.errors do
			local e = ns.errors[i]
			lines[#lines + 1] = ("  %s %s -- %s"):format(
				tostring(e.at), tostring(e.where), tostring(e.err))
		end
	end

	return table.concat(lines, "\n")
end

-- Who is picked in the never-offer dropdown, waiting for Take them off. A file
-- local for the reason reportOpen is one: it is a state of the window, not of
-- the profile.
local neverPicked

-- The never-offer list as dropdown choices, built fresh each time the page asks,
-- because a shift-right-click on the prompt or /manners never can add to it
-- while the page is open.
local function NeverChoices()
	local values = {}
	for _, name in ipairs(ns.NeverList()) do values[name] = name end
	return values
end

---------------------------------------------------------------------------
-- options table
---------------------------------------------------------------------------

local function BuildOptions()
	local who = {
		type = "group",
		name = "Who to buff",
		order = 2,
		hidden = function() return not HasClassBuffs() end,
		args = {
			buffsHeader = { type = "header", name = "Buffs", order = 1 },
			choice = {
				type = "select",
				name = "Buff to cast",
				order = 2,
				values = BuffChoices,
				-- What the walk is honouring, rather than what is stored. The
				-- profile is shared, so a pin can be another class's, and read
				-- raw the dropdown was blank over a walk that was Automatic.
				get = function()
					local pin = ns.PinnedBuff()
					return pin and pin.key or "auto"
				end,
				set = bSet,
			},
			autoNote = {
				type = "description",
				order = 3,
				hidden = function() return ns.PinnedBuff() ~= nil end,
				name = function() return AutoExplanation() end,
			},
			-- Below the per-spell switches, because when it is red the thing it
			-- is about is the dropdown two controls up rather than the switches.
			pinNote = {
				type = "description",
				order = 5,
				fontSize = "medium",
				hidden = function() return ns.PinnedBuff() == nil end,
				name = function() return PinExplanation() end,
			},
			sourcesHeader = { type = "header", name = "Sources", order = 10 },
			-- Three toggles, all off, and the only symptom is a prompt that
			-- never appears -- which is what a broken addon looks like.
			emptyWarning = {
				type = "description",
				order = 10.5,
				hidden = function()
					local s = S()
					-- A source this class cannot use does not count as switched
					-- on. A warrior's Battle Shout reaches the group and nobody
					-- else, so the page hides "passers-by" -- and this used to
					-- read the hidden toggle's leftover true and stay silent,
					-- in exactly the case where the prompt really was dead and
					-- no visible control could explain it.
					return s.owed or s.group or (s.strangers and not OnlyReachesGroup())
				end,
				name = "|cffff8080Nothing below is switched on, so the prompt will never"
					.. " appear.|r",
			},
			owed = {
				type = "toggle",
				name = "People who buffed me",
				-- A function, because the second sentence is not true of every
				-- class. A warrior's shout reaches the group and nobody else, so
				-- a stranger who buffed him is turned down until they join --
				-- which is what the favour line in chat says, and what the
				-- strangers note a few lines down says too.
				--
				-- In a raid on the older flavours that group is the warrior's
				-- own subgroup, and saying "group" there told somebody already in
				-- the raid to join it.
				desc = function()
					if OnlyReachesGroup() then
						return "Watch for buffs cast on you and offer to return them. What you"
							.. (ns.PARTY_IS_SUBGROUP and " cast reaches only your own party --"
								.. " in a raid, your own subgroup --"
								or " cast reaches your group only,")
							.. " so somebody outside it is offered once they join."
					end
					return "Watch for buffs cast on you and offer to return them. "
						.. "Works on strangers who are not in your group."
				end,
				order = 11,
				width = "full",
				get = sGet,
				set = sSet,
			},
			owedClassBuffsOnly = {
				type = "toggle",
				name = "Only count real class buffs",
				desc = "A shield, a heal-over-time or a trinket proc is not a favour owed. "
					.. "Leave this on unless you want every incoming aura to count.",
				order = 12,
				width = "full",
				disabled = function() return not S().owed end,
				get = sGet,
				set = sSet,
			},
			group = {
				type = "toggle",
				name = "My party and raid",
				order = 13,
				width = "full",
				get = sGet,
				set = sSet,
			},
			strangers = {
				type = "toggle",
				name = "Nearby players not in my group",
				-- Four tokens are walked, not three: IterateUnits asks target,
				-- mouseover and focus before it touches a single nameplate.
				-- Leaving focus out made a genuine way of reaching somebody
				-- look like it was not one.
				desc = "Offer passers-by who are missing the buff. "
					.. "Seen through nameplates, your target, your focus and your mouseover.",
				order = 14,
				width = "full",
				-- Hidden, not disabled: a disabled control is one you could
				-- have if something else were different, and there is nothing
				-- on this page that would ever make a shout reach a stranger.
				hidden = OnlyReachesGroup,
				get = sGet,
				set = sSet,
			},
			strangersNote = {
				type = "description",
				order = 14.5,
				hidden = function() return not OnlyReachesGroup() end,
				name = "|cff888888Everything you can offer is cast on yourself and heard by your"
					.. " party, so there is nothing to give a passer-by.|r",
			},

			-- Not a source: everybody here is already on the list by one of the
			-- three above. This decides who reaches the top of it, which is its
			-- own question and used to have no answer on the page at all.
			firstHeader = { type = "header", name = "Who comes first", order = 15 },
			target = {
				type = "toggle",
				name = "Whoever I have targeted comes first",
				-- The second condition is the same one as the first, arriving
				-- from the When tab: Always offer means nobody's buffs are read,
				-- so there is never a reading to promote a target on. The
				-- switch stayed ticked and did nothing, and nothing said why.
				desc = "Targeting somebody is the plainest way of saying you mean them, so they"
					.. " outrank a favour owed -- but only when the game lets us read that they"
					.. " are genuinely missing the buff. Switched off, a target is ranked by why"
					.. " they are on the list like anybody else.\n\n"
					.. "Not while |cffffd100If they already have the buff|r is set to Always"
					.. " offer, under When: nothing is read then, so your target is ranked by"
					.. " why they are on the list like anybody else.\n\n"
					.. "|cff888888Mouseover is deliberately left out: at a scan every four tenths"
					.. " of a second the prompt would flicker as the cursor crossed the"
					.. " screen.|r",
				order = 16,
				width = "full",
				get = prGet,
				set = prSet,
			},
			friends = {
				type = "toggle",
				name = "My friends and guildmates come before the others",
				-- Inside a kind of offer and never across one, which is what the
				-- sort does; see BuildQueue. Saying "ahead of strangers" alone
				-- would promise a friend passing by a place above your group.
				-- Your target is named only where it is true: a target is put
				-- first by the switch above, which needs their buffs readable,
				-- and a stranger's often are not. Otherwise a targeted stranger
				-- is a passer-by like any other, and a friend goes ahead of them.
				desc = "A friend or guildmate passing by comes ahead of the other passers-by,"
					.. " and one in your group ahead of the rest of your group. People who"
					.. " buffed you still come first, and so does your target whenever"
					.. " |cffffd100Whoever I have targeted comes first|r puts them there."
					.. " Nobody is added or left out by this -- it only changes the"
					.. " order.\n\n"
					.. "|cff888888Friends include Battle.net friends. When the game will not say"
					.. " whether somebody is a friend, they are ranked like anybody else.|r",
				order = 17,
				width = "full",
				get = prGet,
				set = prSet,
			},

			skipHeader = { type = "header", name = "Who to skip", order = 20 },
			relevantOnly = {
				type = "toggle",
				name = "Skip players the buff does nothing for",
				desc = "Mana-only buffs such as Arcane Intellect, Wisdom and Divine Spirit are "
					.. "wasted on warriors and rogues.",
				order = 21,
				width = "full",
				get = fGet,
				set = fSet,
			},
			requireInRange = {
				-- It was called "Only players in range", which is what people
				-- read and is not what it does -- its own description said so
				-- one line below. The label has to be the promise.
				type = "toggle",
				name = "Hide players known to be out of range",
				desc = "When the game will not tell us the range -- common on this client -- they"
					.. " are still offered.",
				order = 22,
				width = "full",
				get = fGet,
				set = fSet,
			},
			proximity = {
				type = "select",
				name = "How near a passer-by has to be",
				-- The yardage is here rather than in the choices themselves:
				-- what somebody picks is a feeling, and nobody can judge ten
				-- yards from inside the game -- but they will want to know
				-- roughly what they just asked for.
				desc = "Being in range is not the same as being near. Arcane Intellect and"
					.. " its like reach about thirty yards, which in a city is everybody on"
					.. " the screen.\n\n"
					.. "|cffffd100Anywhere I can cast|r -- about thirty yards, as it was.\n"
					.. "|cffffd100Nearby|r -- about ten yards.\n"
					.. "|cffffd100Right beside me|r -- about five yards.\n\n"
					.. "This only applies to passers-by. Somebody who buffed you was close"
					.. " enough a moment ago, your group is your group, and whoever you have"
					.. " targeted or focused you picked on purpose -- none of them are"
					.. " measured.\n\n"
					.. "|cff888888The game will not say how far away somebody is, so this is"
					.. " measured with whatever this client offers and lands on the nearest"
					.. " step it has. When it cannot measure at all, everybody in casting"
					.. " range is offered, as before.|r",
				order = 22.5,
				width = "full",
				values = ProximityChoices,
				sorting = ProximityOrder,
				-- The setting is about passers-by and nothing else, so it is
				-- hidden exactly where the passer-by toggle is and switched off
				-- exactly when that toggle is.
				hidden = OnlyReachesGroup,
				disabled = function() return not S().strangers end,
				get = fGet,
				set = fSet,
			},
			proximityNote = {
				type = "description",
				order = 22.6,
				hidden = function()
					return OnlyReachesGroup() or F().proximity == "cast"
				end,
				-- Where the promise is kept. A distance filter that has quietly
				-- stopped measuring offers the same crowded queue it always
				-- did, and a user who has just turned it on has no way to tell
				-- that from nobody being nearby -- so the page says which
				-- signal is doing the work and how often it answers, in the
				-- one place they are already looking.
				name = function()
					return "|cff888888" .. tostring(ns.ProximitySummary()) .. "|r"
				end,
			},
			restingOnly = {
				type = "toggle",
				name = "Only offer passers-by in cities and inns",
				-- Hidden and disabled exactly where the distance setting above
				-- is, and for the same reasons: it is about passers-by and
				-- nothing else.
				desc = "Out in the world, passers-by are left alone; they are offered only where"
					.. " the game shows you as resting, which is in a city or an inn.\n\n"
					.. "Somebody who buffed you, your group, and whoever you have targeted or"
					.. " focused are offered anywhere.\n\n"
					.. "|cff888888If the game will not say whether you are resting, passers-by are"
					.. " offered as usual.|r",
				order = 22.7,
				width = "full",
				hidden = OnlyReachesGroup,
				disabled = function() return not S().strangers end,
				get = fGet,
				set = fSet,
			},
			reachableOnly = {
				type = "toggle",
				name = "Drop people who are probably gone",
				desc = "Somebody who buffed you is rarely your target or showing a nameplate, so "
					.. "there is usually no way to range-check them. What we do know is that they "
					.. "were within casting range the moment they buffed you. With this on, that "
					.. "counts for a short while and then they are let go.",
				order = 23,
				width = "full",
				get = fGet,
				set = fSet,
			},
			graceSeconds = {
				-- Named so it stands on its own. It used to read "...after this
				-- long", which only makes sense directly under the toggle above
				-- -- and directly under it is exactly where a duplicate order
				-- number stopped putting it.
				type = "range",
				name = "Let them go after (seconds)",
				-- It said "once we can no longer see the player", which is not the
				-- clock this runs on. BuildQueue measures from the moment they
				-- buffed you -- that moment is the whole of the evidence, because
				-- it is the one instant they were provably in casting range -- and
				-- nothing anywhere notices a player walking off. Somebody who
				-- buffed you two minutes ago and has not moved is let go on exactly
				-- the same schedule as somebody who left at once.
				desc = "How long after somebody buffs you that counts as proof they were in"
					.. " range. It runs from their buff, not from the moment they walk off:"
					.. " nothing here can see them go.",
				order = 23.5,
				min = 10,
				max = 180,
				step = 5,
				disabled = function() return not F().reachableOnly end,
				get = tGet,
				set = tSet,
			},
			minLevel = {
				type = "range",
				name = "Minimum level",
				desc = "Players below this are never offered. The level is read off the unit, so"
					.. " somebody we only know by name -- the usual case for a passer-by who"
					.. " buffed you -- cannot be level-checked at all and is offered anyway.",
				order = 24,
				min = 1,
				max = 60,
				step = 1,
				get = fGet,
				set = fSet,
			},

			neverHeader = { type = "header", name = "Never offer", order = 30 },
			neverNote = {
				type = "description",
				order = 31,
				fontSize = "medium",
				name = function()
					local count = #ns.NeverList()
					if count == 0 then
						return "Nobody is on the list. Shift-right-click the prompt to put whoever"
							.. " it is showing on it, or add a name below."
					end
					-- The exception is the decision this section rests on, so it
					-- is said every time the list is, rather than once in a
					-- tooltip nobody hovers.
					local text = count == 1
						and "One person is on the list. They are never offered anything as a"
							.. " passer-by or as a member of your group."
						or ("%d people are on the list. They are never offered anything as"
							.. " passers-by or as members of your group."):format(count)
					return text .. "\n\nSomebody on it who buffs you is still offered the favour"
						.. " back: returning a favour is what Manners is for. Shift-right-click"
						.. " them on the prompt to let that favour go."
				end,
			},
			neverAdd = {
				type = "input",
				name = "Add somebody by name",
				desc = "Spelled the way the prompt shows them. Capitals do not matter.",
				order = 32,
				width = "full",
				-- Always empty: it is a box to type into, not a setting with a
				-- value to show back.
				get = function() return "" end,
				set = function(_, value) ns.PutOnNeverList(value) end,
			},
			neverPick = {
				type = "select",
				name = "On the list",
				order = 33,
				values = NeverChoices,
				disabled = function() return #ns.NeverList() == 0 end,
				-- Only somebody still on the list: the pick outlives a removal
				-- made from chat, and a dropdown showing a name that is no
				-- longer there offers a Remove that does nothing.
				get = function()
					if neverPicked and ns.IsNeverOffered(neverPicked) then return neverPicked end
					return nil
				end,
				set = function(_, value) neverPicked = value end,
			},
			neverRemove = {
				type = "execute",
				name = "Take them off",
				order = 34,
				disabled = function()
					return not (neverPicked and ns.IsNeverOffered(neverPicked))
				end,
				func = function()
					local name = neverPicked and ns.AllowAgain(neverPicked)
					neverPicked = nil
					if name then
						ns.addon:Print(("|cffffffff%s|r can be offered again."):format(name))
					end
				end,
			},
			neverClear = {
				type = "execute",
				name = "Clear the list",
				order = 35,
				disabled = function() return #ns.NeverList() == 0 end,
				confirm = true,
				confirmText = "Take everybody off the never-offer list?",
				func = function()
					ns.ClearNeverList()
					neverPicked = nil
				end,
			},
		},
	}
	AddBuffToggles(who.args)

	return {
		type = "group",
		name = "Manners",
		childGroups = "tab",
		args = {

			---------------------------------------------------------------
			general = {
				type = "group",
				name = "General",
				order = 1,
				args = {
					enabled = {
						type = "toggle",
						name = "Enable",
						order = 1,
						width = "full",
						get = function() return ns.db.profile.enabled end,
						set = function(_, v)
							ns.db.profile.enabled = v
							ns.Prompt:Refresh()
							-- The launcher's text carries this switch too, and it
							-- is the one reader of it that is not on the page
							-- AceConfig is about to redraw by itself. Through the
							-- shared call rather than straight at the data object:
							-- that one is guarded, and what runs on the far side of
							-- the assignment is a display frame belonging to some
							-- other addon.
							ns.RepaintOptions()
						end,
					},
					-- Switched off, every other page still reads as a working
					-- addon being configured. The prompt simply never appears.
					offNotice = {
						type = "description",
						order = 1.5,
						hidden = function() return ns.db.profile.enabled end,
						name = "|cffff8080Manners is switched off, so the prompt will never"
							.. " appear. Everything below is still saved.|r",
					},
					noBuffs = {
						type = "description",
						order = 2,
						fontSize = "medium",
						hidden = HasClassBuffs,
						-- "Your class has none" and "we could not work out what
						-- you can cast" look identical from hasClassBuffs alone,
						-- and telling those two apart is most of the work on
						-- this client. The list of classes that genuinely have
						-- nothing to give exists precisely so this can say which.
						name = function()
							if ns.caps.class and ns.CLASSES_WITHOUT_BUFFS[ns.caps.class] then
								return "\n|cffff8080Your class has no buffs it can cast on another "
									.. "player.|r\n\nManners has nothing to offer here. It is still "
									.. "worth keeping installed on an alt that does.\n"
							end
							return "\n|cffff8080Manners could not work out what you can cast.|r\n\n"
								.. "Either your class has nothing for other players, or the spell "
								.. "probe came back empty -- |cffffd100/manners debug|r says which.\n"
						end,
					},
					howItWorks = {
						type = "description",
						order = 3,
						fontSize = "medium",
						hidden = function() return not HasClassBuffs() end,
						name = "\n|cffffd100How this works|r\n"
							.. "Blizzard does not let an addon cast a spell by itself, so this one does "
							.. "everything except the keypress: it works out who deserves a buff and puts "
							.. "them on the prompt. Click the prompt and it casts.\n\n"
							.. "|cffffd100Putting it on a key|r\n"
							.. "Make the macro below and drag it onto a bar, or bind a key under "
							.. "Options > Keybindings > Manners.\n",
					},

					startHeader = { type = "header", name = "Getting started", order = 10 },
					makeMacro = {
						type = "execute",
						name = "Create the macro",
						desc = "Adds a macro called Manners containing /click MannersPrompt LeftButton 1. "
							.. "Drag it onto an action bar and it fires the prompt.",
						order = 11,
						hidden = function() return not HasClassBuffs() end,
						func = function() ns.CreateClickMacro() end,
					},

					-- The same three lengths as the minimap menu, and through the
					-- same functions as /manners snooze, so all three say the
					-- same thing in chat.
					snoozeHeader = {
						type = "header", name = "Snooze", order = 15,
						hidden = function() return not HasClassBuffs() end,
					},
					snoozeNote = {
						type = "description",
						order = 15.5,
						fontSize = "medium",
						hidden = function() return not HasClassBuffs() end,
						name = function()
							local ends = ns.SnoozeEndsAt()
							-- The page is repainted at both ends of a fight, so this
							-- is only shown while it is true.
							if ends and InCombatLockdown() then
								-- Worded for both ways into this: a snooze started in the
								-- fight, over a panel that is still up, and one started
								-- before it, over a panel that is already gone.
								return ("|cffffd100Snoozed until %s.|r In a fight the prompt stays"
									.. " as the fight found it, and follows the snooze once the"
									.. " fight ends."):format(ends)
							elseif ends then
								-- Not "offered when it ends": a favour is remembered for
								-- as long as the When tab says, which is usually shorter
								-- than a snooze.
								return ("|cffffd100Snoozed until %s.|r No prompt until then,"
									.. " though who buffs you is still noticed."):format(ends)
							end
							return "Keep the prompt out of the way for a while without switching"
								.. " Manners off. It comes back by itself when the time is up, and"
								.. " a /reload ends a snooze as well. One started in a fight takes"
								.. " effect when the fight ends."
						end,
					},
					snooze5 = {
						type = "execute",
						name = function() return ns.MinutesText(ns.SNOOZE_CHOICES[1]) end,
						order = 16,
						hidden = function() return not HasClassBuffs() end,
						func = function() ns.StartSnooze(ns.SNOOZE_CHOICES[1]) end,
					},
					snooze15 = {
						type = "execute",
						name = function() return ns.MinutesText(ns.SNOOZE_CHOICES[2]) end,
						order = 17,
						hidden = function() return not HasClassBuffs() end,
						func = function() ns.StartSnooze(ns.SNOOZE_CHOICES[2]) end,
					},
					snooze30 = {
						type = "execute",
						name = function() return ns.MinutesText(ns.SNOOZE_CHOICES[3]) end,
						order = 18,
						hidden = function() return not HasClassBuffs() end,
						func = function() ns.StartSnooze(ns.SNOOZE_CHOICES[3]) end,
					},
					snoozeStop = {
						type = "execute",
						name = "Stop snoozing",
						order = 19,
						hidden = function() return not ns.SnoozeLeft() end,
						func = function() ns.StopSnooze() end,
					},

					miscHeader = {
						type = "header", name = "Minimap", order = 20,
						hidden = function() return not HasMinimapButton() end,
					},
					minimap = {
						type = "toggle",
						name = "Show minimap button",
						order = 21,
						-- Gone entirely where the libraries are not, rather than
						-- greyed out. Without this the checkbox writes a setting
						-- nothing reads and calls Show or Hide on a button that
						-- was never registered -- a control that ticks, saves,
						-- and does nothing at all, which is indistinguishable
						-- from the addon being broken. There is no minimap
						-- button to explain the absence of, so there is nothing
						-- a disabled control would be telling anybody.
						hidden = function() return not HasMinimapButton() end,
						get = function() return not ns.db.profile.minimap.hide end,
						set = function(_, v)
							ns.db.profile.minimap.hide = not v
							if LDBIcon then
								if v then LDBIcon:Show(ADDON) else LDBIcon:Hide(ADDON) end
							end
						end,
					},

					-- Its own header rather than a line under Diagnostics. It
					-- was called "Announce every buff it sees", filed beside the
					-- click logger, and on by default -- three things that
					-- together read as an addon that talks to other players.
					chatHeader = { type = "header", name = "Chat", order = 30 },
					verbose = {
						type = "toggle",
						-- It said "when someone buffs me", which is one of seven
						-- things this switch prints. The others are the ones worth
						-- having: a debt that survived a click, a cast counted as
						-- repaid, a cast the game refused, a person skipped, a
						-- sound that would not play, and a press that may have cast
						-- from a macro the fight would not let us disarm. Somebody
						-- reading the old label had no reason to switch it on to
						-- find out why a buff went nowhere, which is the question
						-- it answers best.
						--
						-- Those, and not "what each click turned into", which it
						-- used to promise: a cast that worked prints nothing
						-- unless it repaid a favour, so somebody switching this on
						-- to watch their casts saw silence and took it for broken.
						name = "Tell me in chat what the addon is doing",
						desc = "A line when somebody buffs you, when a favour is counted as repaid,"
							.. " and when a click fails, is skipped, or leaves somebody owed.\n\n"
							.. "Only you see any of it; nothing is ever said to anybody else from"
							.. " here. Use it to tell 'the buff was never noticed' apart from 'it was"
							.. " noticed but they could not be reached' -- two very different"
							.. " problems.",
						order = 31,
						width = "full",
						get = function() return ns.db.profile.verbose end,
						set = function(_, v) ns.db.profile.verbose = v end,
					},

					-- Two boxes rather than one that does both: a box that shows
					-- your settings and also applies whatever is typed into it
					-- is one stray keypress from replacing them.
					shareHeader = { type = "header", name = "Share settings", order = 40 },
					shareNote = {
						type = "description",
						order = 41,
						fontSize = "medium",
						name = "Copy these settings as one line of text, to keep or to give to"
							.. " somebody, or paste one you were given. Whether Manners is on,"
							.. " whether the prompt is locked, where it sits, the click log and"
							.. " the minimap button stay as they are. A pasted line never"
							.. " switches on speaking when you buff, and while you have it on,"
							.. " what you say and where stays yours too.",
					},
					shareCopy = {
						type = "execute",
						name = function() return shareOpen and "Hide the text" or "Show my settings as text" end,
						desc = "Shows these settings as one line of text in a box below, ready to"
							.. " select and copy. |cffffd100/manners export|r opens it too.",
						order = 42,
						func = function()
							shareOpen = not shareOpen
							ns.RefreshOptionsDisplay()
						end,
					},
					shareText = {
						type = "input",
						-- On the page rather than in the button's tooltip: the game
						-- has no way to put text on the clipboard for the player,
						-- and somebody who pasted after clicking a button that said
						-- "Copy" pasted whatever they had copied before.
						name = "Click in the box, press Ctrl+A to select it all, then Ctrl+C to copy"
							.. " (Cmd on a Mac).",
						order = 43,
						multiline = 3,
						width = "full",
						hidden = function() return not shareOpen end,
						get = function() return ns.ExportSettings() or "" end,
						-- Read-only the way the bug report is: anything typed in
						-- is discarded, and the box repaints from the profile.
						set = function() end,
					},
					sharePaste = {
						type = "input",
						name = "Paste settings to use them",
						desc = "Replaces the settings on this profile with the ones in the text."
							.. " |cffffd100/manners import undo|r puts yours back.",
						order = 44,
						multiline = 3,
						width = "full",
						get = function() return "" end,
						-- Refused here with the reason, before anything changes.
						-- The dialog shows the sentence and keeps what was pasted,
						-- so it can be fixed rather than pasted again.
						validate = function(_, value)
							local parsed, err = ns.ParseSettings(value)
							if not parsed then return err end
							return true
						end,
						set = function(_, value)
							local _, message = ns.ImportSettings(value)
							ns.addon:Print(message)
						end,
					},
					-- What the addon has done, rather than a setting. Here
					-- because General is the page people land on, and the
					-- window is otherwise only a slash command away.
					ledgerHeader = {
						type = "header", name = "Favour ledger", order = 50,
						hidden = function() return not ns.Ledger end,
					},
					ledgerSummary = {
						type = "description",
						order = 51,
						fontSize = "medium",
						hidden = function() return not ns.Ledger end,
						name = function() return ns.Ledger and ns.Ledger.OptionsText() or "" end,
					},
					ledgerOpen = {
						type = "execute",
						name = "Open the ledger",
						desc = "A window listing who buffed you and with what, whether you returned"
							.. " it, and who you buffed without being asked. Also /manners ledger,"
							.. " or shift-click the minimap button.",
						order = 52,
						hidden = function() return not ns.Ledger end,
						-- This window shut first. It sits in a higher strata
						-- than the ledger and both are centred on the screen,
						-- so the ledger opened underneath it with only its
						-- title showing, and the button seemed to do nothing.
						func = function()
							ns.CloseOptions()
							ns.Ledger.Show()
						end,
					},
				},
			},

			---------------------------------------------------------------
			who = who,

			---------------------------------------------------------------
			-- Split off "Who to buff", which was doing four jobs. Everything
			-- here is a question about timing, and two of the four duplicate
			-- order numbers were between the two halves.
			when = {
				type = "group",
				name = "When",
				order = 3,
				hidden = function() return not HasClassBuffs() end,
				args = {
					buffedHeader = { type = "header", name = "Already buffed", order = 1 },
					whenBuffed = {
						type = "select",
						name = "If they already have the buff",
						-- The favour exception is said here and on the choice
						-- itself because it is a policy none of the three choices
						-- touches: BuildQueue offers a debt regardless, and what it
						-- offers is the buff they already hold, which is a refresh
						-- and takes nothing away. Left unsaid, the one person the
						-- prompt did offer under "Leave them alone" read as a bug.
						desc = "Reading whether somebody has a buff needs the game's permission. See "
							.. "the Diagnostics tab for which of your buffs qualify.\n\n"
							.. "Somebody who buffed you is offered the favour back whichever you"
							.. " choose, even if they already have it.",
						order = 2,
						width = "full",
						values = {
							skip = "Leave them alone (unless they buffed you)",
							refresh = "Offer a top-up when it is running out",
							always = "Always offer, whatever they have",
						},
						get = fGet,
						set = fSet,
					},
					refreshUnder = {
						type = "range",
						name = "Top up when under (minutes) are left",
						desc = "Only offer a refresh once their remaining time drops below this. "
							.. "Somebody whose buff timer cannot be read is left alone -- unless"
							.. " they buffed you, in which case they are offered the favour back"
							.. " anyway.",
						order = 3,
						min = 1,
						max = 60,
						step = 1,
						hidden = function() return F().whenBuffed ~= "refresh" end,
						get = fGet,
						set = fSet,
					},
					alwaysNote = {
						type = "description",
						order = 4,
						hidden = function() return F().whenBuffed ~= "always" end,
						-- The second sentence is a setting on another tab going
						-- quiet. A target is promoted only on a reading that they
						-- lack the buff, and this mode takes no readings.
						name = "|cffff8080Everyone nearby will be offered constantly, including people "
							.. "whose buff has barely ticked down. Expect to be spending mana.|r\n\n"
							.. "|cff888888Nothing is read in this mode, so |cffffd100Whoever I have"
							.. " targeted comes first|r has nothing to go on: your target is ranked by"
							.. " why they are on the list like anybody else.|r",
					},

					timingHeader = { type = "header", name = "Timing", order = 10 },
					-- Every one of these is a number of seconds except the
					-- top-up threshold, which is minutes. There is no suffix
					-- field on an AceConfig range, so the unit goes in the name
					-- or it is nowhere.
					reciprocateWindow = {
						type = "range",
						name = "Remember a buff for (seconds)",
						-- It said this was how long somebody stays on the prompt,
						-- and for the ordinary favour -- a passer-by with no
						-- nameplate -- it is not: BuildQueue lets them go once the
						-- grace on the Who to buff tab runs out, forty-five seconds
						-- against this one's hundred and twenty at the defaults.
						desc = "How long a favour is remembered. Somebody the game can still see"
							.. " stays on the prompt this long. Somebody it cannot see is let go"
							.. " sooner if |cffffd100Let them go after|r is shorter, while"
							.. " |cffffd100Drop people who are probably gone|r is on, under Who to"
							.. " buff.",
						order = 11,
						min = 15,
						max = 600,
						step = 5,
						get = tGet,
						set = tSet,
					},
					keepDebts = {
						type = "toggle",
						name = "Remember them across a reload",
						desc = "A favour noticed a minute before a disconnect is the case this is"
							.. " for. The clock keeps running while you are away, so somebody"
							.. " whose time ran out in the meantime is not brought back.\n\n"
							.. "|cff888888Stored against this character, never shared between"
							.. " profiles. Switching it off deletes what has already been"
							.. " stored.|r",
						order = 11.5,
						width = "full",
						get = tGet,
						set = function(info, value)
							tSet(info, value)
							-- Off means gone, now. Leaving the file behind means
							-- the next login restores debts from a setting that
							-- says not to -- and SaveDebts is the one function
							-- that owns that file, so it does the erasing too.
							ns.addon:SaveDebts()
						end,
					},
					-- It read "Wait before re-offering", over "how long before the
					-- same player can come back up" -- a promise about the person,
					-- from a click that blocks one spell. For a class with two
					-- buffs the setting did not do what it said.
					--
					-- The label follows the code rather than the other way round,
					-- because the code is right. The walk is the headline feature,
					-- and PickBuffFor is built on this block being per spell: it is
					-- what moves a priest off Fortitude and onto Divine Spirit on
					-- the very next scan. Making the setting mean what it said
					-- would have put twelve seconds between the two halves of the
					-- one thing the addon is for.
					--
					-- Both readings are true of something, which is the other half
					-- of why this went unnoticed: the same number is what a
					-- right-press blocks the whole person for. That is now said
					-- here rather than left to be discovered.
					retryCooldown = {
						type = "range",
						name = "Wait before offering the same spell again (seconds)",
						desc = "After you click, how long before that spell is offered to that"
							.. " player again. Covers casts that failed out of sight.\n\n"
							.. "|cff888888Per spell, not per person: cast Fortitude and the next"
							.. " scan can still offer them Divine Spirit, which is how the walk"
							.. " down your buffs works at all. Right-click the prompt to skip"
							.. " somebody and the same number applies to the whole person --"
							.. " nothing is offered to them until it lifts.|r",
						order = 12,
						min = 3,
						max = 60,
						step = 1,
						get = tGet,
						set = tSet,
					},
					scanInterval = {
						type = "range",
						name = "Scan every (seconds)",
						desc = "Lower is more responsive and slightly heavier.",
						order = 13,
						min = 0.1,
						max = 2,
						step = 0.1,
						get = tGet,
						set = tSet,
					},

					-- Only the mount has a switch. Dead, a taxi and a vehicle
					-- are places nothing can be cast from, and the queue has
					-- always been empty there; a mount is a place the cast
					-- works and costs you the mount, which is a trade some
					-- players want to make.
					wayHeader = { type = "header", name = "Out of the way", order = 20 },
					hideMounted = {
						type = "toggle",
						name = "Not while mounted",
						desc = "Keep the prompt away while you are on a mount, since casting would"
							.. " take you off it. It comes back when you get off, if there is"
							.. " somebody to buff.\n\n"
							.. "|cff888888It already stays away while you are dead, on a flight"
							.. " path or in a vehicle, where nothing can be cast. In a fight the"
							.. " prompt stays as the fight found it, and follows this once the"
							.. " fight ends.|r",
						order = 21,
						width = "full",
						get = fGet,
						set = fSet,
					},
				},
			},

			---------------------------------------------------------------
			-- Everything that happens at the moment of the press. Handing your
			-- target back is a line in the macro rather than a filter on the
			-- queue, and it spent four releases filed under Filters.
			click = {
				type = "group",
				name = "When you click",
				order = 4,
				hidden = function() return not HasClassBuffs() end,
				args = {
					-- Everything on this tab is a line in the macro, and the macro
					-- is a secure attribute the fight has frozen. The settings are
					-- kept and the macro rebuilt when the fight ends, but until then
					-- a press runs the old one -- a /yell you have just switched
					-- off among them -- and the Prompt tab's own notice is scoped
					-- to that tab, so nothing here said so.
					combatNotice = {
						type = "description",
						order = 0.5,
						fontSize = "medium",
						hidden = function() return not InCombatLockdown() end,
						name = "|cffffd100In combat.|r Blizzard freezes the macro on the prompt"
							.. " for the length of a fight, so these settings apply once it ends."
							.. " Until then a press runs the macro already on the button.\n",
					},
					targetingHeader = { type = "header", name = "Targeting", order = 1 },
					restoreTarget = {
						type = "toggle",
						name = "Hand my target back afterwards",
						desc = "Buffing somebody means targeting them first -- a named conditional only "
							.. "reaches your own party or raid, and this prompt is mostly for passers-by. "
							.. "With this on, your previous target is restored immediately after the cast.",
						order = 2,
						width = "full",
						-- Hidden, not disabled, for the same reason the strangers
						-- toggle is: a disabled control is one you could have if
						-- something else were different, and nothing on this page
						-- would ever put a /target in a Battle Shout macro.
						hidden = NeverTargets,
						get = fGetMacro,
						set = fSetMacro,
					},
					noTargetNote = {
						type = "description",
						order = 2.5,
						hidden = function() return not NeverTargets() end,
						name = "|cff888888Everything you can offer is cast on yourself and heard by"
							.. " your party, so the prompt never takes your target and has none to"
							.. " hand back.|r\n",
					},
					targetingNote = {
						type = "description",
						order = 3,
						hidden = NeverTargets,
						-- A function, so it names the command the macro is really
						-- built with, asked of the builder itself. That is /target
						-- today on every client -- /targetexact is probed for but
						-- deliberately not used, see TargetCommand -- and a fixed
						-- string here would be a second opinion about the macro,
						-- wrong the day the builder changes its mind.
						--
						-- For the same reason it reads the switch directly above
						-- it. It used to name /targetlasttarget whatever that
						-- switch said, and the strategy drops the line when it is
						-- off -- and for somebody who is already your target, who
						-- has nobody before them worth handing back. Except in a
						-- fight, where the macro armed at the pull keeps the line
						-- for everybody: the player may target the mob afterwards,
						-- and nothing can rebuild the macro to follow them.
						name = function()
							local cmd = (ns.TargetCommand and ns.TargetCommand()) or "/target"
							local after
							if F().restoreTarget then
								after = ", then |cffffd100/targetlasttarget|r -- except, outside a"
									.. " fight, for somebody who is already your target, who stays"
									.. " targeted."
							else
								after = ", and leaves them targeted."
							end
							return ("|cff888888The prompt runs |cffffd100%s|r, then the cast%s A"
								.. " conditional -- [@name] -- resolves only for somebody already in"
								.. " your party or raid, and this prompt is mostly for passers-by, so"
								.. " the macro takes your target rather than aiming past it.|r\n")
								:format(cmd, after)
						end,
					},

					speechHeader = { type = "header", name = "Speech", order = 10 },
					intro = {
						type = "description",
						order = 11,
						fontSize = "medium",
						name = "Say something when you buff somebody. The line is added to the macro the "
							.. "prompt runs, so it goes out as you talking rather than as an addon.\n\n"
							.. "|cff888888This matters: the game refuses addon-sent /say and /yell outside "
							.. "instances, which is exactly where somebody buffs you in passing. Going "
							.. "through the macro sidesteps that.|r\n",
					},
					enabled = {
						type = "toggle",
						name = "Say something",
						order = 12,
						width = "full",
						get = spGet,
						set = spSet,
					},
					channel = {
						type = "select",
						name = "Channel",
						order = 13,
						disabled = function() return not SP().enabled end,
						values = { SAY = "Say", YELL = "Yell", PARTY = "Party", RAID = "Raid", EMOTE = "Emote" },
						get = spGet,
						set = spSet,
					},
					onlyWhenReturning = {
						type = "toggle",
						name = "Only when returning a favour",
						desc = "Speak only when buffing somebody who buffed you first. Leave this on unless "
							.. "you want to announce every stranger you buff.",
						order = 14,
						width = "full",
						disabled = function() return not SP().enabled end,
						get = spGet,
						set = spSet,
					},

					phrasesHeader = { type = "header", name = "Phrases", order = 20 },
					preset = {
						type = "select",
						name = "Load a set",
						desc = "Replaces the lines below. Edit them afterwards as much as you like.",
						order = 21,
						disabled = function() return not SP().enabled end,
						-- It overwrites a box somebody may have spent ten
						-- minutes filling, with no undo anywhere in the addon --
						-- while "Reset position", which is undone by dragging the
						-- prompt back, was the one control that asked.
						confirm = function(_, value)
							return ("Replace everything in the box below with the %s lines?"):format(
								(ns.PHRASE_SETS[value] and ns.PHRASE_SETS[value].label)
									or tostring(value))
						end,
						values = function()
							local out = {}
							for _, key in ipairs(ns.PHRASE_SET_ORDER) do
								out[key] = ns.PHRASE_SETS[key].label
							end
							return out
						end,
						sorting = function() return ns.PHRASE_SET_ORDER end,
						-- Blank once the box has been edited. AceGUI's dropdown only
						-- fires when the item clicked becomes checked, so showing the
						-- last set loaded over lines that are no longer it made that
						-- one set the only one that could not be picked -- somebody
						-- wanting the Roleplay lines back got nothing at all.
						get = function()
							local choice = SP().presetChoice or "roleplay"
							if SP().phrases == ns.PhraseSetText(choice) then return choice end
							return nil
						end,
						set = function(_, value)
							SP().presetChoice = value
							SP().phrases = ns.PhraseSetText(value) or SP().phrases
							ns.Prompt:InvalidateMacro()
							ns.addon:Print(("loaded the %s lines."):format(
								ns.PHRASE_SETS[value] and ns.PHRASE_SETS[value].label or value))
						end,
					},
					phrasesHelp = {
						type = "description",
						order = 22,
						name = "One per line -- a random one is picked each time the prompt changes target. "
							.. "Tokens: |cff888888{name}|r the player, |cff888888{buff}|r the spell.\n"
							.. "|cff888888The whole macro cannot exceed 255 characters, so how long a line "
							.. "may be depends on the name and on whether your target is handed back. "
							.. "One that will not fit is dropped rather than cut off -- "
							.. "|cffffd100Roll a few|r shows what would really go out. "
							.. "An empty box goes back to the chosen set -- switch off "
							.. "|cffffd100Say something|r to stay quiet.|r",
					},
					phrases = {
						type = "input",
						name = "",
						order = 23,
						multiline = 10,
						width = "full",
						disabled = function() return not SP().enabled end,
						get = spGet,
						-- An empty box snaps back to the set the dropdown names,
						-- the way the First line does. It used to be kept as
						-- typed: nothing was said and the box looked empty, until
						-- the load-time repair refilled it -- which also runs from
						-- the Width, Height and Icon size sliders, so the deleted
						-- lines came back on a nudge of one of those, or at the
						-- next login. What the box shows is now what is kept.
						set = function(info, value)
							if type(value) ~= "string" or value:match("^%s*$") then
								value = ns.PhraseSetText(SP().presetChoice) or ns.PhraseSetText("roleplay")
							end
							spSet(info, value)
						end,
					},
					roll = {
						type = "execute",
						name = "Roll a few",
						order = 24,
						func = function()
							-- reason "owed" so the sample survives the
							-- only-when-returning filter either way.
							local fake = {
								short = "Somebody",
								name = "Somebody",
								reason = "owed",
								buff = ns.ResolveBuff(true),
							}
							for _ = 1, 3 do
								-- The same budget the cast path measures, for a
								-- representative name, rather than a constant
								-- that promised lines the macro then dropped.
								ns.addon:Print(ns.PickPhrase(fake, ns.PhraseBudget(fake))
									or "|cffff8080(nothing -- speech off, or no usable lines)|r")
							end
						end,
					},
					limits = {
						type = "description",
						order = 25,
						name = "\n|cff888888A macro cannot exceed 255 characters, so an over-long line is "
							.. "dropped rather than truncated. The message goes out when you click, so it is "
							.. "sent even if the cast then fails out of range or line of sight.|r",
					},
				},
			},

			---------------------------------------------------------------
			appearance = {
				type = "group",
				name = "Prompt",
				order = 5,
				args = {
					-- Everything on this tab is a secure attribute or a texture
					-- on a secure frame, and ApplyStyle gives up and returns the
					-- moment it is called in combat. The values are kept and
					-- flushed when the fight ends; what was missing was anything
					-- saying so, so every control on the tab silently did
					-- nothing for the length of a fight.
					combatNotice = {
						type = "description",
						order = 0.5,
						fontSize = "medium",
						hidden = function() return not InCombatLockdown() end,
						name = "|cffffd100In combat.|r Blizzard freezes secure frames, so the prompt"
							.. " cannot be restyled or re-aimed until the fight ends. Anything you"
							.. " change here is saved and appears the moment you leave combat.\n",
					},
					-- First on the tab, because everything under it is something
					-- you want to see while you change it, and on a live prompt
					-- most of it is invisible until somebody happens to walk past.
					test = {
						type = "execute",
						-- A button labelled "Preview" whichever thing it was about
						-- to do is a button you press twice to find out.
						name = function()
							return ns.Prompt:InTest() and "Stop preview" or "Preview"
						end,
						-- What happens after the window is shut was missing, and it
						-- is the half somebody meets by surprise: the preview is
						-- not still running when they go back to the game. Both
						-- exits are held off while this window is open -- see
						-- Refresh, where the expiry is pushed forward rather than
						-- read -- so the sentence order here is the rule.
						desc = "Show a sample entry so you can style the prompt without waiting"
							.. " for one. It stays for as long as this window is open; once you"
							.. " close it, twenty seconds more, or until somebody real turns up.",
						order = 1,
						-- Greyed out in a fight, where ToggleTest refuses to start
						-- one: a preview there is painted on a panel the fight may
						-- have hidden, or over a macro it froze at somebody real.
						-- One already running can still be stopped. The page is
						-- repainted at both ends of a fight, so this follows it.
						disabled = function()
							return InCombatLockdown() and not ns.Prompt:InTest()
						end,
						func = function() ns.Prompt:ToggleTest() end,
					},
					locked = {
						type = "toggle",
						name = "Locked",
						desc = "Unlock to drag the prompt. It will not cast while unlocked.",
						order = 2,
						get = pGet,
						-- Its own setter rather than the shared one, for the same
						-- reason /manners unlock has its own line: the prompt is
						-- hidden by `enabled` before `locked` is ever read, so
						-- unlocking while the addon is off leaves nothing on
						-- screen to drag and no clue as to why.
						set = function(info, value)
							pSet(info, value)
							if not value and not ns.db.profile.enabled then
								ns.addon:Print("unlocked, but the addon is |cffff8080off|r so there"
									.. " is no prompt to drag -- switch it on first.")
							end
						end,
					},
					reset = {
						type = "execute",
						name = "Reset position",
						-- No confirmation. It is undone by dragging the prompt
						-- back or picking a preset, and it was the only control
						-- in the addon that asked -- while the one that wipes
						-- hand-written phrases did not.
						order = 3,
						func = function()
							local d, p = ns.defaults.profile.prompt, P()
							p.point, p.relPoint, p.x, p.y = d.point, d.relPoint, d.x, d.y
							restyle()
						end,
					},

					styleHeader = { type = "header", name = "Style", order = 10 },
					-- Where the colour goes comes first, because the two colour
					-- pickers under it are the things it governs -- it used to
					-- sit below both of them.
					accentMode = {
						type = "select",
						name = "Where the reason colour goes",
						desc = "A ring around the icon reads better than a stripe at the panel edge, "
							.. "which ends up competing with the icon rather than framing it.\n\n"
							.. "|cff888888The framed look has no stripe at all -- it would run down "
							.. "the inside of its border -- so on it the stripe settings do "
							.. "nothing.|r",
						order = 11,
						values = {
							icon = "Ring around the icon",
							stripe = "Stripe down the left edge",
							both = "Both",
							off = "Neither",
						},
						get = pGet,
						set = pSet,
					},
					accentByReason = {
						-- It was called "Colour the stripe by reason" while
						-- defaulting to colouring the ring, so the label was
						-- wrong for everybody who had not changed the setting
						-- above.
						type = "toggle",
						name = "Colour it by reason",
						-- There are four reasons and this named three, leaving out
						-- the one most people see most often: pale blue is what a
						-- target you picked yourself gets, and that priority is on
						-- by default. Listed in the order the queue ranks them, so
						-- the list doubles as the ordering.
						--
						-- Pale blue, not green: the target colour moved to a pale
						-- cyan so it survives colour blindness beside the amber,
						-- and this went on promising a green ring nobody would ever
						-- see. It sits beside the group's deeper blue and is told
						-- from it by lightness, which is why both are qualified.
						--
						-- The target is the only one with a condition on it,
						-- because "target" is the only reason BuildQueue will not
						-- write unless a switch is on -- and the switch is on
						-- another tab. And the switch has a condition of its own,
						-- on a third: with Always offer nothing is read, so no
						-- target is ever promoted and the pale blue never shows.
						desc = "Pale blue for somebody you targeted yourself, amber when returning a"
							.. " favour, deeper blue for your group, grey for passers-by. That is"
							.. " also the order they are offered in.\n\n"
							.. "|cff888888The first of those only ever appears while |cffffd100Whoever"
							.. " I have targeted comes first|r is on, under Who to buff, and never"
							.. " while |cffffd100If they already have the buff|r is set to Always"
							.. " offer, under When.|r",
						order = 12,
						width = "full",
						get = pGet,
						set = pSet,
					},
					-- Shown only when the colour above has nowhere left to go. "Off"
					-- is excluded: that is somebody asking for no accent, and a
					-- warning about getting what you asked for is noise.
					accentDead = {
						type = "description",
						order = 12.5,
						hidden = function()
							if (P().accentMode or "icon") == "off" then return true end
							local ring, stripe = AccentCarriers()
							return ring or stripe
						end,
						-- Every carrier the mode asked for and did not get, not just
						-- the first: "Both" on a framed prompt with a rounded icon
						-- loses two, and naming one of them sends somebody to undo
						-- the wrong setting.
						name = function()
							local p = P()
							local mode = p.accentMode or "icon"
							local why = {}
							if mode == "icon" or mode == "both" then
								if not p.showIcon then
									why[#why + 1] = "the ring is drawn behind the icon, which is"
										.. " switched off"
								elseif p.roundIcon then
									why[#why + 1] = "rounding the icon off replaces the ring with"
										.. " a mask"
								end
							end
							if (mode == "stripe" or mode == "both") and p.style == "framed" then
								why[#why + 1] = "the framed look has no stripe"
							end
							return ("|cffffd100There is nothing left to colour: %s.|r"):format(
								table.concat(why, ", and "))
						end,
					},
					accentColor = {
						type = "color",
						name = "Accent colour",
						desc = "Used for the ring, the stripe, or both -- whichever the setting above"
							.. " asks for.",
						order = 13,
						hasAlpha = true,
						disabled = function() return P().accentByReason end,
						get = pGetColor,
						set = pSetColor,
					},
					style = {
						type = "select",
						name = "Look",
						order = 14,
						-- The middle one used to read "Blizzard -- default UI
						-- border" and no part of the addon has ever applied a
						-- backdrop, a border or an atlas: picking it took the
						-- shadow, the bevel and the stripe off and left a bare
						-- rectangle, which is the one thing the hairlines exist
						-- to prevent. It draws its own border now, out of the
						-- same white texture as the rest of the panel, and says
						-- so. Profiles holding the old name are carried across
						-- in ClampSettings.
						values = {
							glass = "Glass -- dark panel, soft shadow",
							framed = "Framed -- flat panel, thin border",
							minimal = "Minimal -- text only, no panel",
						},
						get = pGet,
						set = pSet,
					},
					bgColor = {
						type = "color",
						name = "Panel colour",
						order = 15,
						hasAlpha = true,
						disabled = function() return P().style == "minimal" end,
						get = pGetColor,
						set = pSetColor,
					},

					-- The flash and the sound are the same job and were two tabs
					-- apart, which is how they came to disagree about who is
					-- worth interrupting for.
					attentionHeader = { type = "header", name = "Getting your attention", order = 20 },
					flashStyle = {
						type = "select",
						name = "When someone buffs you",
						desc = "Pulse keeps breathing until you have returned the favour or they are gone. "
							.. "Flash once is easy to miss if you were looking elsewhere.\n\n"
							.. "|cff888888It lights up round the spell icon and sweeps the stripe, and"
							.. " with Effects on Full the panel catches the light the moment they buff"
							.. " you. With the icon hidden, no stripe showing and no light either --"
							.. " Effects on Calm, or the Minimal look, which has no panel -- there is"
							.. " nothing for it to do.|r",
						order = 21,
						-- A setting with nothing to act on reads as one that is
						-- broken, which is what accentDead exists to prevent for
						-- the colour. The glow lives on the icon, the sweep on the
						-- stripe and the light on arrival on the panel, and with
						-- none of them this does nothing.
						disabled = function()
							local _, stripe = AccentCarriers()
							local noLight = P().effects == "calm" or P().style == "minimal"
							return not P().showIcon and not stripe and noLight
						end,
						values = {
							pulse = "Pulse until dealt with",
							once = "Flash once",
							off = "Nothing",
						},
						get = pGet,
						set = pSet,
					},
					-- The motion added with the new look, and a way to have the
					-- prompt without it. Next to the flash because they are the
					-- same kind of thing: how much the prompt moves to get your
					-- attention. The description names each effect and the
					-- condition it has, so none of it is a promise the panel then
					-- breaks -- the ring needs the icon, the light on arrival
					-- needs the setting above, and a fight with Stay quiet in
					-- combat on gets none of the outcome motion.
					effects = {
						type = "select",
						name = "Effects",
						desc = "Full: when a buff lands, light crosses the panel and a ring pops out of"
							.. " the spell icon, if it is shown; a refused buff makes the text give a small shake;"
							.. " somebody who buffs you makes the panel catch the light, unless the"
							.. " setting above is Nothing; and after your last buff the prompt fades"
							.. " out instead of vanishing.\n\nCalm: none of that movement. The prompt"
							.. " still fades in, and the glow set above still works.\n\n|cff888888The"
							.. " Minimal look has no panel, so no light crosses it. The cooldown sweep"
							.. " on the icon has its own switch, under Icon and queue. In a fight, Stay"
							.. " quiet in combat keeps the outcome still as well.|r",
						order = 21.5,
						values = {
							full = "Full",
							calm = "Calm -- less movement",
						},
						sorting = { "full", "calm" },
						get = pGet,
						set = pSet,
					},
					soundEnabled = {
						type = "toggle",
						name = "Play a sound",
						desc = "Play a sound when somebody new reaches the top of the queue.",
						order = 22,
						get = function() return SND().enabled end,
						set = function(_, v) SND().enabled = v end,
					},
					soundFile = {
						type = "select",
						name = "Sound",
						order = 23,
						disabled = function() return not SND().enabled end,
						-- HashTable maps key -> file, and AceConfig shows the
						-- value as the label, so this listed one entry whose
						-- name was "1".
						values = function()
							local list = {}
							for key in pairs(LSM:HashTable("sound")) do list[key] = key end
							-- The chosen sound, even when its pack has not
							-- registered it, so the box still says what was
							-- picked rather than going blank. It plays ours
							-- until the pack is there.
							local chosen = SND().file
							if type(chosen) == "string" and not list[chosen] then
								list[chosen] = chosen .. " |cff808080(not loaded)|r"
							end
							return list
						end,
						get = function() return SND().file end,
						set = function(_, value)
							SND().file = value
							-- Picking a sound you cannot hear is how the
							-- silent default went unnoticed for so long.
							ns.Guard("sound preview", ns.PlayPromptSound, value)
						end,
					},
					soundOwedOnly = {
						-- The flash fires only for a favour owed; the sound
						-- fired for everybody, so a passer-by got the noise and
						-- the person who actually buffed you got the pulse.
						type = "toggle",
						name = "Only when somebody buffed me",
						desc = "Off, every new person on the prompt makes a noise -- including"
							.. " strangers you happen to walk past.",
						order = 24,
						width = "full",
						disabled = function() return not SND().enabled end,
						get = function() return SND().owedOnly end,
						set = function(_, v) SND().owedOnly = v end,
					},
					noSound = {
						type = "description",
						order = 24.5,
						hidden = function() return not SND().enabled or SND().file ~= "None" end,
						name = "|cffff8080None is silent. Pick a sound above.|r",
					},

					posHeader = { type = "header", name = "Position and size", order = 30 },
					-- Moving the prompt otherwise means unlock, find it, drag it,
					-- lock it -- four steps and a mode you can forget you are in,
					-- because an unlocked prompt is also one that will not cast.
					posPreset = {
						type = "select",
						name = "Put it",
						desc = "Three places that are already right. Dragging the prompt afterwards"
							.. " leaves this blank, because it is then not on one of them.",
						order = 31,
						values = function()
							local out = {}
							for _, preset in ipairs(ns.POSITION_PRESETS) do
								out[preset.key] = preset.name
							end
							return out
						end,
						-- The list has a meaning order -- top of the screen to
						-- bottom -- and a dropdown sorted alphabetically loses it.
						sorting = function()
							local out = {}
							for i, preset in ipairs(ns.POSITION_PRESETS) do out[i] = preset.key end
							return out
						end,
						get = function() return ns.CurrentPositionPreset() end,
						set = function(_, value) ns.ApplyPositionPreset(value) end,
					},
					x = { type = "range", name = "X offset", order = 32, min = -2000, max = 2000, step = 1, get = pGet, set = pSet },
					y = { type = "range", name = "Y offset", order = 33, min = -2000, max = 2000, step = 1, get = pGet, set = pSet },
					width = {
						type = "range",
						name = "Width",
						order = 34,
						min = 80,
						max = 500,
						step = 1,
						get = pGet,
						-- The same setter the height has, for the same reason: the
						-- icon is bound by the width as well. Narrowing the prompt
						-- left a big icon in place, and the name, inset past the
						-- icon on the left and short of the edge on the right, had
						-- nowhere left to draw.
						set = function(info, value)
							local icon = P().iconSize
							pSet(info, value)
							ns.ClampSettings()
							restyle()
							if P().iconSize ~= icon then RepaintSoon() end
						end,
					},
					height = {
						type = "range",
						name = "Height",
						order = 35,
						min = 20,
						max = 120,
						step = 1,
						get = pGet,
						-- Its own setter because the icon's maximum is bound to
						-- this. Lowering the height under an icon already larger
						-- than it would otherwise leave the icon overhanging both
						-- hairlines and the slider showing a number it would no
						-- longer accept. Repainted when that happens; see
						-- RepaintSoon.
						set = function(info, value)
							local icon = P().iconSize
							pSet(info, value)
							ns.ClampSettings()
							restyle()
							if P().iconSize ~= icon then RepaintSoon() end
						end,
					},
					scale = { type = "range", name = "Scale", order = 36, min = 0.5, max = 3, step = 0.05, get = pGet, set = pSet },
					alpha = { type = "range", name = "Opacity", order = 37, min = 0.1, max = 1, step = 0.05, isPercent = true, get = pGet, set = pSet },
					-- It was called "Hide in combat" and it hides nothing. The one
					-- call that ever acted on it -- a button:Hide() inside the
					-- combat branch -- was a protected method on a protected frame,
					-- so Blizzard refused it every single time it was made, and it
					-- has since been deleted rather than guarded. A secure
					-- visibility driver could hide it -- only the conditionals
					-- that name a unit, [@Name], are restricted on this client,
					-- and [combat] resolves -- but a hidden secure button still
					-- fires from its key binding and from /click, casting the
					-- frozen macro out of sight. So the panel stays up on
					-- purpose, and the page says that rather than "cannot".
					--
					-- What is left is real and worth a switch, so the switch stays
					-- and the label moves to it. In a fight the panel is frozen at
					-- whoever it was holding, and a click still casts that frozen
					-- macro -- so the confirmation flash for that click is the one
					-- thing on the panel that still changes. This decides whether
					-- it does.
					--
					-- The flash is the reason's own colour and turns red only for
					-- a failure; nothing paints it green, which this used to
					-- promise.
					hideInCombat = {
						type = "toggle",
						name = "Stay quiet in combat",
						desc = "A click still casts in combat, and the prompt still flashes to say what"
							.. " happened -- red if it failed. With this on it does not -- the panel"
							.. " simply sits there dimmed for the length of the fight, with no cooldown"
							.. " sweep on the icon.\n\n"
							.. "|cff888888It stays on screen in a fight on purpose: your key binding"
							.. " would still cast the frozen macro if it were hidden.|r",
						order = 38,
						width = "full",
						get = pGet,
						set = pSet,
					},

					textHeader = { type = "header", name = "Text", order = 40 },
					format = {
						type = "input",
						name = "First line",
						desc = "Tokens: {name} {reason} {count} {class} {buff} {time}",
						order = 41,
						width = "full",
						get = pGet,
						-- An empty first line is a prompt that names nobody. The
						-- box took one for the session and the load-time repair
						-- put the default back at the next login; it snaps back
						-- here instead, so what the box shows is what is kept.
						set = function(info, value)
							if not ns.UsableFormat(value) then
								value = ns.defaults.profile.prompt.format
							end
							pSet(info, value)
						end,
					},
					showSub = {
						type = "toggle",
						name = "Show a second line",
						-- Worked out from the font, by the same function ApplyStyle
						-- decides it with. It said 34 after the prompt stopped using
						-- 34, so at 34 to 38 pixels the page said there was room and
						-- the line was silently missing.
						desc = function()
							return ("Needs a prompt at least %d pixels tall at this font size.")
								:format(ns.TwoLineHeight(P().fontSize))
						end,
						order = 42,
						width = "full",
						get = pGet,
						set = pSet,
					},
					formatHelp = {
						type = "description",
						order = 43,
						name = "|cff888888{name}|r who   |cff888888{reason}|r why   |cff888888{count}|r how many more   "
							.. "|cff888888{class}|r their class   |cff888888{buff}|r the spell\n"
							.. "|cff888888{time}|r what theirs has left, on a top-up and nowhere else\n"
							.. "The second line always shows the reason.",
					},
					reasonTarget = {
						type = "input",
						name = "Wording: your target",
						desc = "Somebody you targeted yourself outranks everyone else, including a "
							.. "favour owed -- but only when the game lets us see they are missing it, "
							.. "and only while that is switched on under Who to buff.",
						order = 44,
						get = pGet,
						set = pSet,
					},
					reasonOwed = { type = "input", name = "Wording: buffed you", order = 45, get = pGet, set = pSet },
					reasonGroup = { type = "input", name = "Wording: in your group", order = 46, get = pGet, set = pSet },
					reasonNearby = { type = "input", name = "Wording: nearby", order = 47, get = pGet, set = pSet },
					reasonRefresh = {
						type = "input",
						name = "Wording: topping one up",
						desc = "Used instead of the four above when they already have the buff and"
							.. " it is about to run out, which only the refresh mode offers."
							.. " |cffffd100{time}|r is how long theirs has left.",
						order = 48,
						get = pGet,
						set = pSet,
					},
					reasonUnknown = {
						type = "input",
						name = "Wording: state unknown",
						desc = "Used when the game will not let addons read whether they already have it.",
						order = 49,
						get = pGet,
						set = pSet,
					},
					font = {
						type = "select",
						name = "Font",
						order = 50,
						-- Keys, not files. HashTable maps key -> file and AceConfig
						-- shows the value as the label, so this listed font paths,
						-- sorted by path: the bug the sound list below had fixed,
						-- left in this one.
						values = function()
							local list = {}
							for key in pairs(LSM:HashTable("font")) do list[key] = key end
							return list
						end,
						get = pGet,
						set = pSet,
					},
					fontSize = { type = "range", name = "Font size", order = 51, min = 6, max = 32, step = 1, get = pGet, set = pSet },
					fontColor = { type = "color", name = "Text colour", order = 52, hasAlpha = true, get = pGetColor, set = pSetColor },
					classColor = { type = "toggle", name = "Colour names by class", order = 53, width = "full", get = pGet, set = pSet },

					iconHeader = { type = "header", name = "Icon and queue", order = 60 },
					showIcon = { type = "toggle", name = "Show spell icon", order = 61, get = pGet, set = pSet },
					iconSize = {
						type = "range",
						name = "Icon size",
						-- The icon must fit inside the panel: the range runs to 64
						-- against a height that runs down to 20, so it could be set
						-- three times the height of the thing it sits in, over both
						-- hairlines and pushing the text off the right-hand edge.
						--
						-- The bound cannot live here. AceConfigRegistry types min
						-- and max as "number or nil" and rejects the whole options
						-- table if either is a function -- not this control, the
						-- whole table, so the page cannot be drawn at all. It is
						-- enforced in ClampSettings instead, which is where every
						-- other cross-setting repair already lives.
						desc = "Kept inside the prompt -- make it taller or wider first for a bigger icon.",
						order = 62,
						min = 12,
						max = 64,
						step = 1,
						disabled = function() return not P().showIcon end,
						get = pGet,
						set = function(info, value)
							pSet(info, value)
							-- The bound, applied. It lives in ClampSettings because
							-- it cannot live on the control (see above) -- and this
							-- setter never called it, so dragging the slider to 64
							-- on a 44-high prompt left the icon exactly there,
							-- overhanging both hairlines and pushing the text off
							-- the right-hand edge, until something unrelated
							-- happened to clamp. The notice below said "the icon is
							-- held at 64 to fit a prompt 44 high" while it was held
							-- at nothing. Written the same way the height slider
							-- writes it, which is the other half of the same rule.
							ns.ClampSettings()
							restyle()
							-- Repainted only when the clamp actually moved it. The
							-- dialog redraws when a drag is let go, but a mouse
							-- wheel never lets go of anything, so a wheel tick past
							-- the limit left the slider showing a value the prompt
							-- was not using. Asking every time rebuilt the slider
							-- under a dragging finger; asking only when the kept
							-- value differs from the one set does neither.
							if P().iconSize ~= value and ns.RefreshOptionsDisplay then
								ns.Guard("icon repaint", ns.RefreshOptionsDisplay)
							end
						end,
					},
					iconSizeCapped = {
						type = "description",
						order = 62.5,
						hidden = function()
							local p = P()
							-- Shown only when the icon is sitting on the ceiling,
							-- which is the case where the slider will not go any
							-- further and nothing else on the page explains why.
							-- The same ceiling ClampSettings enforces: it is bound
							-- by the width as well as the height, and a notice that
							-- only knew the height stayed hidden, or named the
							-- wrong one, whenever the width was the limit.
							return not p.showIcon or p.iconSize < ns.IconCeiling(p)
						end,
						name = function()
							local p = P()
							local byWidth = (p.width - 60) < (p.height - 8)
							return ("|cffffd100The icon is held at %d to fit a prompt %d %s.|r")
								:format(p.iconSize, byWidth and p.width or p.height,
									byWidth and "wide" or "high")
						end,
					},
					roundIcon = {
						type = "toggle",
						name = "Round the icon off",
						-- The second sentence is the one that was missing. The ring
						-- is a texture sitting behind a square icon, and the mask
						-- that rounds the icon is put there instead of it -- so
						-- this quietly switches off "Ring around the icon" above,
						-- which is the default place the reason colour goes.
						desc = "Masks the icon into a circle. Reads more like a portrait than a spell, "
							.. "so it is off by default.\n\n"
							.. "|cff888888The mask goes where the ring was, so a rounded icon has no"
							.. " ring to colour -- move the reason colour to the stripe if you want"
							.. " both. The glow when somebody buffs you follows the circle.|r",
						order = 63,
						width = "full",
						disabled = function() return not P().showIcon end,
						get = pGet,
						set = pSet,
					},
					-- Greyed out with the icon hidden, since the sweep is drawn on
					-- it and there is then nothing for this to do.
					showCooldown = {
						type = "toggle",
						name = "Show the global cooldown on the icon",
						desc = "Sweeps the spell icon while the global cooldown runs after a cast,"
							.. " the way your action bars do, so you can see when the next press will"
							.. " go through.\n\n|cff888888Not in a fight while Stay quiet in combat"
							.. " is on.|r",
						order = 63.5,
						width = "full",
						disabled = function() return not P().showIcon end,
						get = pGet,
						set = pSet,
					},
					showCount = { type = "toggle", name = "Show how many are waiting", order = 64, width = "full", get = pGet, set = pSet },
					showQueue = { type = "toggle", name = "List the next few below", order = 65, width = "full", get = pGet, set = pSet },
					queueRows = {
						type = "range",
						name = "How many to list",
						order = 66,
						min = 1,
						max = 5,
						step = 1,
						disabled = function() return not P().showQueue end,
						get = pGet,
						set = pSet,
					},
				},
			},

			---------------------------------------------------------------
			-- Its own tab. The capability dump was buried at the bottom of
			-- General under a header shared with two toggles that are not
			-- diagnostics at all, and the errors the addon had already caught
			-- appeared nowhere on the page.
			diagnostics = {
				type = "group",
				name = "Diagnostics",
				order = 6,
				args = {
					debugClicks = {
						type = "toggle",
						name = "Log every click to chat",
						desc = "Prints what the button was actually holding at the moment you clicked it, "
							.. "and what the game did with it. Noisy; for working out why a cast did not "
							.. "happen.",
						order = 1,
						width = "full",
						get = function() return ns.db.profile.debugClicks end,
						set = function(_, v) ns.db.profile.debugClicks = v end,
					},

					capsHeader = { type = "header", name = "What this client allows", order = 10 },
					diag = {
						type = "description",
						order = 11,
						fontSize = "medium",
						hidden = function() return not HasClassBuffs() end,
						name = function()
							local lines = { "Class: |cffffffff" .. tostring(ns.caps.class) .. "|r\n" }
							for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
								local info = ns.BuffInfo(buff)
								lines[#lines + 1] = string.format(
									"|cffffffff%s|r  --  learned: %s   missing-check: %s",
									(info and info.name) or buff.key,
									(info and info.known) and "|cff00ff00yes|r" or "|cff808080no|r",
									(info and info.readable) and "|cff00ff00works|r" or "|cffff8080blocked|r")
								-- Manners being wrong about the game, rather
								-- than the game withholding something. The two
								-- read identically from the line above -- both
								-- are a spell that is never offered -- and only
								-- one of them is fixable by the people reading
								-- this page's bug reports.
								--
								-- "Never offer" only where it is true. The list
								-- holds the group version as well as the ranks,
								-- and a group id the client lacks -- Arcane
								-- Brilliance -- costs only the check of whether
								-- somebody is wearing it: Arcane Intellect is
								-- still learned, offered and cast. Said as "never
								-- offer", right under "learned: yes".
								if info and info.unresolved and #info.unresolved > 0 then
									local missing = {}
									for _, id in ipairs(info.unresolved) do missing[id] = true end
									local rankResolves = false
									for _, id in ipairs(buff.ranks) do
										if not missing[id] then rankResolves = true end
									end
									if not info.known and not rankResolves then
										lines[#lines + 1] = ("|cffff4040    this client has never heard of"
											.. " spell %s, so Manners will never offer this one."
											.. " That is a mistake in Manners -- please report it.|r")
											:format(table.concat(info.unresolved, ", "))
									else
										lines[#lines + 1] = ("|cffff4040    this client doesn't know spell"
											.. " %s, so Manners can't see that version on anyone --"
											.. " somebody already carrying it may be offered this anyway."
											.. " That is a mistake in Manners -- please report it.|r")
											:format(table.concat(info.unresolved, ", "))
									end
								end
							end
							lines[#lines + 1] = "\n|cff888888Where the missing-check is blocked, the game will "
								.. "not let addons read that aura. Players are still offered, but some may "
								.. "already have the buff.|r"
							return table.concat(lines, "\n")
						end,
					},
					noDiag = {
						type = "description",
						order = 11.5,
						fontSize = "medium",
						hidden = HasClassBuffs,
						name = "|cffff8080Nothing to report: this character has no buffs it can put on"
							.. " another player.|r",
					},

					-- ns.Guard catches everything that can throw and says each
					-- label out loud once. The rest of them existed only in
					-- /manners errors, which nobody reads while they are looking
					-- at the options page wondering why nothing works.
					errorsHeader = { type = "header", name = "What has broken", order = 20 },
					errorList = {
						type = "description",
						order = 21,
						fontSize = "medium",
						hidden = function() return #ns.errors == 0 end,
						name = function()
							local lines = {}
							for i = math.max(1, #ns.errors - 4), #ns.errors do
								local e = ns.errors[i]
								lines[#lines + 1] = ("|cff808080%s|r %s -- |cffff8080%s|r"):format(
									tostring(e.at), tostring(e.where), tostring(e.err))
							end
							-- The count, not the ring's length. The ring holds thirty,
							-- so this said thirty whether thirty things had broken or
							-- thirty thousand -- the reading /manners errors and the
							-- bug report were both corrected away from.
							if #ns.errors > 5 then
								local total = ns.errorCount or #ns.errors
								local kept = total > #ns.errors
									and (", %d kept"):format(#ns.errors) or ""
								lines[#lines + 1] = ("|cff888888(%d in all this session%s --"
									.. " |cffffd100/manners errors|r)|r"):format(total, kept)
							end
							return table.concat(lines, "\n")
						end,
					},
					noErrors = {
						type = "description",
						order = 21.5,
						fontSize = "medium",
						hidden = function() return #ns.errors > 0 end,
						name = "Nothing has broken this session.",
					},

					reportHeader = { type = "header", name = "Reporting a bug", order = 30 },
					buildNote = {
						type = "description",
						order = 31,
						fontSize = "medium",
						-- The build number appeared nowhere on this page, so the
						-- first question on every bug report was the one the
						-- reporter could not answer from the screen they were
						-- looking at.
						name = function()
							return ("Manners |cffffffff%s|r"):format(tostring(ns.BUILD))
						end,
					},
					copyReport = {
						type = "execute",
						name = function() return reportOpen and "Hide the report" or "Copy for a bug report" end,
						desc = "Opens a box with the build number, what this client allows, the settings"
							.. " that change what it does and anything that has broken -- ready to select"
							.. " and paste.",
						order = 32,
						func = function()
							reportOpen = not reportOpen
							ns.RefreshOptionsDisplay()
						end,
					},
					report = {
						type = "input",
						name = "",
						order = 33,
						multiline = 14,
						width = "full",
						hidden = function() return not reportOpen end,
						get = function() return BugReport() end,
						-- Read-only in the only way AceConfig offers: anything
						-- typed in is discarded, and the box repaints from the
						-- addon the next time it is opened. It exists to be
						-- copied out of, not written into.
						set = function() end,
					},
				},
			},
		},
	}
end

---------------------------------------------------------------------------
-- registration
---------------------------------------------------------------------------

-- The canvas frame AddToBlizOptions made for the game's Settings window, and
-- the category ID it hands back beside it. Two values because they are two
-- things: the frame is what can be asked whether the page is on screen, and
-- only the ID is something Settings.OpenToCategory can find the page by.
local blizCategory, blizCategoryID

-- The minimap button's right-click menu.
--
-- A right-click used to switch the addon off and on and do nothing else, which
-- spent the one free click on the thing least often wanted and left a snooze,
-- the preview and the options three different commands away. The switch is
-- the first line here, so it is still one click and a choice -- and the middle
-- button now throws it outright.
--
-- MenuUtil is the client's own context menu, and the addons known to work on
-- this client open theirs the same way. Asked for at the moment of the click:
-- a client without it keeps the old right-click, the switch on its own.
local function HasLauncherMenu()
	return type(MenuUtil) == "table" and type(MenuUtil.CreateContextMenu) == "function"
end

-- The lengths the menu offers. Its own list rather than the options page's:
-- an hour is the length a raid night wants, and a menu has room for a fourth
-- line where a row of buttons on the page does not.
local MENU_SNOOZE_MINUTES = { 5, 15, 30, 60 }

-- How many people the menu's Who's next lists, and how many of them the
-- tooltip names under the one on the prompt.
local MENU_QUEUE_ROWS = 8
local TOOLTIP_QUEUE_ROWS = 3

-- Why somebody is being offered a buff, in the words the prompt uses.
local function WhyWords(entry)
	local reason = entry and entry.reason
	if reason == "owed" then return L["buffed you"] end
	if reason == "group" then return L["in your group"] end
	if reason == "target" then return L["your target"] end
	return L["nearby"]
end

local function WhoIs(entry)
	return tostring(entry.short or entry.name)
end

local function WhatBuff(entry)
	return tostring(ns.BuffName and ns.BuffName(entry.buff) or "?")
end

-- Who the prompt is armed at and who comes after them, in that order, with
-- nobody twice. The first answer is nil when no prompt is up.
--
-- Read, never acted on: the queue is built the same way the scan builds it,
-- and nothing here arms, clicks or repaints anything. The one on the prompt
-- comes from the prompt itself, because in a fight it stays whoever the fight
-- found there while the queue under it goes on changing.
local function WhoIsWaiting(limit)
	local showing = ns.Prompt and ns.Prompt.Showing and ns.Prompt:Showing() or nil
	local list, seen = {}, {}
	if showing and showing.name then
		list[1] = showing
		seen[showing.name] = true
	end
	local queue
	ns.Guard("launcher queue", function() queue = ns.BuildQueue() end)
	for _, entry in ipairs(type(queue) == "table" and queue or {}) do
		if #list >= limit then break end
		if entry.name and not seen[entry.name] then
			seen[entry.name] = true
			list[#list + 1] = entry
		end
	end
	return list, showing
end

-- What the launcher's tooltip says, for the minimap button, a broker display
-- and the addon compartment alike.
local function FillLauncherTooltip(tooltip)
	tooltip:AddLine("Manners")
	-- The state, said here as well as in the text, because a broker
	-- display is free to show the icon on its own -- and then this
	-- tooltip is the only place left that can say why no prompt has
	-- appeared all evening.
	--
	-- Which is why "on" is not enough to say "watching". A rogue, a
	-- mage who has not learned Arcane Intellect and a priest with
	-- every spell switched off are all switched on, and none of
	-- them will ever see a prompt -- so "Watching for people to
	-- buff" was the one line that made the missing prompt look like
	-- a bug. Told apart as the greeting tells them apart: a class
	-- with nothing to give, a class the buff data has no table for,
	-- nothing learned yet, and a setting in the way.
	local class = ns.caps and ns.caps.class
	local snoozeLeft = ns.SnoozeLeft and ns.SnoozeLeft()
	local watching = false
	if not Enabled() then
		tooltip:AddLine(L["Switched off -- no prompt will appear."], 1, 0.5, 0.5)
	elseif snoozeLeft then
		-- The clock time and the minutes both: the time is what the
		-- player compares with a raid timer, and the minutes are what
		-- they asked for.
		tooltip:AddLine(L["Snoozed until %s, %s from now -- no prompt until then."]
			:format(ns.SnoozeEndsAt(), ns.MinutesText(math.ceil(snoozeLeft / 60))),
			1, 0.82, 0, true)
	elseif class and ns.CLASSES_WITHOUT_BUFFS and ns.CLASSES_WITHOUT_BUFFS[class] then
		tooltip:AddLine(L["Nothing to do: %s"]:format(ns.NO_CLASS_BUFFS), 1, 0.82, 0)
	elseif not HasClassBuffs() then
		tooltip:AddLine(L["Nothing to cast on this character -- /manners debug says why."],
			1, 0.82, 0)
	elseif not ns.ResolveBuff(true) then
		if ns.caps.anyKnown then
			tooltip:AddLine(L["Nothing will be offered: %s."]:format(ns.NothingToCast()),
				1, 0.5, 0.5, true)
		else
			tooltip:AddLine(L["Nothing learned to cast yet."], 1, 0.82, 0)
		end
	else
		tooltip:AddLine(L["Watching for people to buff."], 0.4, 0.9, 0.4)
		watching = true
	end

	-- In a fight the prompt keeps whoever it had when the fight began, and a
	-- press still casts at them; the list under it stops moving. Said beside
	-- the state because "watching" alone would promise a prompt that follows
	-- the queue, which in a fight it cannot.
	if watching and InCombatLockdown() then
		tooltip:AddLine(L["Held in combat -- the prompt moves on once the fight ends."], 1, 0.82, 0, true)
	end

	-- Who is waiting, while there is a prompt to wait on. The favours first:
	-- they are what the launcher's own text counts, so a bar reading "2
	-- waiting" is answered by the first line of the hover.
	if watching then
		local waiting = WaitingCount()
		if waiting == 1 then
			tooltip:AddLine(L["1 person who buffed you is waiting for one back."], 0.5, 0.88, 0.5, true)
		elseif waiting > 1 then
			tooltip:AddLine(L["%d people who buffed you are waiting for one back."]:format(waiting),
				0.5, 0.88, 0.5, true)
		end
		local list, showing = WhoIsWaiting(TOOLTIP_QUEUE_ROWS + 1)
		for i, entry in ipairs(list) do
			if entry == showing then
				tooltip:AddLine(L["On the prompt: |cffffffff%s|r -- %s, %s"]:format(
					WhoIs(entry), WhatBuff(entry), WhyWords(entry)), 1, 0.82, 0, true)
			elseif i <= TOOLTIP_QUEUE_ROWS + (showing and 1 or 0) then
				tooltip:AddLine(L["Next: |cffffffff%s|r -- %s, %s"]:format(
					WhoIs(entry), WhatBuff(entry), WhyWords(entry)), 0.8, 0.8, 0.8, true)
			end
		end
	end

	-- Today's favours and the lifetime counts, from the ledger.
	-- Guarded like the rest of what this tooltip borrows: a count
	-- that throws must not take the lines above with it.
	if ns.Ledger then ns.Guard("ledger tooltip", ns.Ledger.AddTooltip, tooltip) end

	-- What each click will do, not what the button is for. "Enable or disable"
	-- is true of every press and tells you nothing about the one you are about
	-- to make. Grey, under everything else: they are the part read once.
	tooltip:AddLine(L["Left click: options"], 0.6, 0.6, 0.6)
	if ns.Ledger then
		tooltip:AddLine(L["Shift-click: favour ledger"], 0.6, 0.6, 0.6)
	end
	tooltip:AddLine(Enabled() and L["Middle click: switch it off"]
		or L["Middle click: switch it on"], 0.6, 0.6, 0.6)
	if HasLauncherMenu() then
		tooltip:AddLine(L["Right click: snooze, preview, who's next and more"], 0.6, 0.6, 0.6)
	else
		tooltip:AddLine(Enabled() and L["Right click: switch it off"]
			or L["Right click: switch it on"], 0.6, 0.6, 0.6)
	end
end

-- The switch, thrown in one press. What a right-click always did where there
-- is no menu, and what the middle button does everywhere.
local function ToggleEnabled()
	ns.db.profile.enabled = not ns.db.profile.enabled
	ns.Prompt:Refresh()
	ns.addon:Print(ns.db.profile.enabled and L["enabled."] or L["disabled."])
	-- The switch this click just threw has a checkbox on the options page and
	-- a word in the launcher's own text, and neither re-reads the profile on
	-- its own. Without this, clicking with the window open leaves Enable
	-- ticked over an addon that is off.
	ns.RepaintOptions()
end

---------------------------------------------------------------------------
-- building the menu
--
-- Every entry goes through the same function its slash command or its control
-- on the options page does, so the menu cannot describe a state the others
-- disagree with, and says the same line in chat.
--
-- The client's menu calls these back from its own code, and whatever throws
-- there is lost -- so every callback runs under Guard, which names it.
---------------------------------------------------------------------------

local function Act(fn)
	return function() ns.Guard("minimap menu", fn) end
end

-- For the entries that move the prompt or change what it is armed with: the
-- lock, its position and the profile. The client refuses all of that on a
-- secure frame in a fight, so they are greyed out there -- and refused again
-- at the click, because a menu opened before the pull is still open after it.
local function ActOutOfCombat(fn)
	return function()
		if InCombatLockdown() then
			ns.addon:Print(L["that has to wait until after the fight -- the prompt cannot be moved or changed in combat."])
			return
		end
		ns.Guard("minimap menu", fn)
	end
end

-- The label an entry wears while a fight holds it, so the reason is on the
-- line itself rather than only in a tooltip nobody hovers for.
local function FightLabel(label, fight)
	if not fight then return label end
	return L["%s |cff808080-- after the fight|r"]:format(label)
end

local function HeldForFight(description)
	if type(description) ~= "table" then return end
	if description.SetEnabled then description:SetEnabled(false) end
	if description.SetTooltip then
		description:SetTooltip(function(tooltip)
			tooltip:AddLine(L["The prompt cannot be moved or changed during a fight. This comes back once it ends."],
				1, 0.82, 0, true)
		end)
	end
end

-- Answered under pcall: the menu asks while it draws, and a question that
-- throws there takes the whole menu with it.
local function Asked(get)
	return function()
		local ok, value = pcall(get)
		return ok and value == true
	end
end

-- A checkbox where the client's menu has them, and a plain button that does
-- the same thing where it does not.
local function Check(parent, text, get, set)
	if parent.CreateCheckbox then return parent:CreateCheckbox(text, Asked(get), set) end
	return parent:CreateButton(text, set)
end

local function Radio(parent, text, get, set)
	if parent.CreateRadio then return parent:CreateRadio(text, Asked(get), set) end
	return parent:CreateButton(text, set)
end

local function Divider(parent)
	if parent.CreateDivider then parent:CreateDivider() end
end

-- Not now, from the menu: the same block a right-press on the prompt writes,
-- and the same repaint after it, which knows about the fight and moves the
-- panel on only where it may. Said in chat every time, unlike the press on the
-- prompt: somebody further down the list leaves nothing on screen changed.
local function SkipFromMenu(entry)
	ns.BlockPerson(entry.name)
	local showing = ns.Prompt.Showing and ns.Prompt:Showing()
	if showing and showing.name == entry.name then ns.Prompt:StopAttention() end
	ns.addon:Print(L["skipping |cffffffff%s|r for now."]:format(WhoIs(entry)))
	ns.Guard("skip repaint", ns.Prompt.Refresh, ns.Prompt)
end

-- Never, from the menu: the never-offer list, as a shift-right-press on the
-- prompt puts them there, with the line that says how to undo it.
local function NeverFromMenu(entry)
	ns.PutOnNeverList(entry.name)
	ns.Guard("never repaint", ns.Prompt.Refresh, ns.Prompt)
end

local function FillWhoIsNext(parent)
	if not Enabled() then
		local none = parent:CreateButton(L["Nobody -- Manners is switched off"])
		if none.SetEnabled then none:SetEnabled(false) end
		return
	end
	local list, showing = WhoIsWaiting(MENU_QUEUE_ROWS)
	if #list == 0 then
		local none = parent:CreateButton(L["Nobody is waiting"])
		if none.SetEnabled then none:SetEnabled(false) end
		return
	end
	for _, entry in ipairs(list) do
		local label
		if entry == showing then
			label = L["%s -- %s (%s), on the prompt"]:format(WhoIs(entry), WhatBuff(entry), WhyWords(entry))
		else
			label = L["%s -- %s (%s)"]:format(WhoIs(entry), WhatBuff(entry), WhyWords(entry))
		end
		local person = parent:CreateButton(label)
		person:CreateButton(L["Skip for now"], Act(function() SkipFromMenu(entry) end))
		-- Somebody already on the list is only here because they are owed,
		-- and for them the same act lets the favour go -- which is what it
		-- says, as the prompt's own tooltip does.
		local listed = ns.IsNeverOffered and ns.IsNeverOffered(entry.name)
		person:CreateButton(listed and L["Let this favour go"] or L["Never offer"],
			Act(function() NeverFromMenu(entry) end))
	end
end

local function FillPromptMenu(parent, fight)
	local lock = Check(parent, FightLabel(L["Locked"], fight), function() return ns.db.profile.prompt.locked end,
		ActOutOfCombat(function()
			ns.addon:HandleSlash(ns.db.profile.prompt.locked and "unlock" or "lock")
		end))
	local reset = parent:CreateButton(FightLabel(L["Reset position"], fight), ActOutOfCombat(function()
		-- The same four values the options page's Reset position puts back.
		local d, now = ns.defaults.profile.prompt, ns.db.profile.prompt
		now.point, now.relPoint, now.x, now.y = d.point, d.relPoint, d.x, d.y
		ns.Prompt:ApplyStyle()
		ns.addon:Print(L["the prompt is back where it started."])
		ns.RepaintOptions()
	end))
	if fight then
		HeldForFight(lock)
		HeldForFight(reset)
	end
	Divider(parent)
	-- These three are drawing and sound, never where the button is or what it
	-- casts: the style is put back after the fight by ApplyStyle itself, so
	-- they stay open in one.
	Check(parent, L["Stay quiet in combat"], function() return ns.db.profile.prompt.hideInCombat end,
		Act(function()
			local now = ns.db.profile.prompt
			now.hideInCombat = not now.hideInCombat
			ns.Prompt:ApplyStyle()
			ns.RepaintOptions()
		end))
	Check(parent, L["Play a sound"], function() return ns.db.profile.sound.enabled end,
		Act(function()
			local sound = ns.db.profile.sound
			sound.enabled = not sound.enabled
			ns.RepaintOptions()
		end))
	local effects = parent:CreateButton(L["Effects"])
	for _, choice in ipairs({
		{ key = "full", label = L["Full"] },
		{ key = "calm", label = L["Calm -- less movement"] },
	}) do
		Radio(effects, choice.label, function() return (ns.db.profile.prompt.effects or "full") == choice.key end,
			Act(function()
				ns.db.profile.prompt.effects = choice.key
				ns.Prompt:ApplyStyle()
				ns.RepaintOptions()
			end))
	end
end

-- AceDB's profiles, when the database can list them. Switching one changes
-- where the prompt sits and what it is armed with, so it waits for the fight
-- to end like the lock does.
local function FillProfiles(parent, fight)
	local db = ns.db
	local names = {}
	local ok = pcall(function()
		local list = db:GetProfiles()
		for _, name in pairs(list or {}) do
			if type(name) == "string" then names[#names + 1] = name end
		end
	end)
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	if not ok or #names == 0 then return end
	for _, name in ipairs(names) do
		local choice = Radio(parent, FightLabel(name, fight), function() return db:GetCurrentProfile() == name end,
			ActOutOfCombat(function()
				if db:GetCurrentProfile() ~= name then db:SetProfile(name) end
			end))
		if fight then HeldForFight(choice) end
	end
end

local function FillLauncherMenu(root)
	local fight = InCombatLockdown()
	if root.CreateTitle then root:CreateTitle("Manners") end
	Check(root, L["Enable"], Enabled, Act(function()
		ns.addon:HandleSlash(Enabled() and "off" or "on")
	end))

	-- The snooze, with its end on the entry itself while one is running.
	local ends = ns.SnoozeEndsAt()
	local snooze = root:CreateButton(ends and L["Snoozed until %s"]:format(ends) or L["Snooze"])
	for _, minutes in ipairs(MENU_SNOOZE_MINUTES) do
		snooze:CreateButton(L["For %s"]:format(ns.MinutesText(minutes)), Act(function()
			ns.StartSnooze(minutes)
		end))
	end
	if ends then
		Divider(snooze)
		snooze:CreateButton(L["Stop snoozing"], Act(function() ns.StopSnooze() end))
	end

	-- Greyed out in a fight as it is on the options page: ToggleTest refuses to
	-- start one there. One already running can still be stopped.
	local inTest = ns.Prompt:InTest()
	local preview = root:CreateButton(
		inTest and L["End the preview"] or FightLabel(L["Preview the prompt"], fight),
		Act(function() ns.addon:HandleSlash("test") end))
	if fight and not inTest then HeldForFight(preview) end

	if ns.Ledger then
		root:CreateButton(L["Open the ledger"], Act(function() ns.Ledger.Show() end))
	end

	FillWhoIsNext(root:CreateButton(L["Who's next"]))
	FillPromptMenu(root:CreateButton(L["Prompt"]), fight)
	Check(root, L["Tell me in chat what the addon is doing"], function() return ns.db.profile.verbose end,
		Act(function() ns.addon:HandleSlash("verbose") end))
	if ns.db.GetProfiles and ns.db.GetCurrentProfile and ns.db.SetProfile then
		FillProfiles(root:CreateButton(L["Profiles"]), fight)
	end

	Divider(root)
	root:CreateButton(L["Options"], Act(function() ns.OpenOptions() end))
end

-- Opens the menu and answers whether there was one to open. A menu that
-- throws while being built is caught and named like any other failure, and
-- still counts as opened: falling back to the switch then would turn the
-- addon off in answer to a click that asked for a menu.
--
-- `later` is for a click that arrives from inside another menu -- the addon
-- compartment's -- which closes every open menu once its click handler
-- returns, the one just opened included. Opened on the next frame instead, on
-- UIParent, since the compartment's line is gone by then.
local function OpenLauncherMenu(owner, later)
	if not HasLauncherMenu() then return false end
	local function open()
		ns.Guard("minimap menu", MenuUtil.CreateContextMenu, owner or UIParent, function(_, root)
			ns.Guard("minimap menu", FillLauncherMenu, root)
		end)
	end
	if later and C_Timer and C_Timer.After then
		C_Timer.After(0, open)
	else
		open()
	end
	return true
end

-- Every click on the launcher, from the minimap, a broker bar or the addon
-- compartment.
local function LauncherClick(owner, mouseButton, later)
	-- The middle button throws the switch: the one thing wanted in a hurry,
	-- with no menu in the way.
	if mouseButton == "MiddleButton" then
		ToggleEnabled()
		return
	end
	-- Shift with the left button opens the ledger. The plain click
	-- stays the options window, which is what everybody who has
	-- used this button before expects of it.
	if mouseButton ~= "RightButton" and ns.Ledger
		and IsShiftKeyDown and IsShiftKeyDown() then
		ns.Guard("ledger window", ns.Ledger.Toggle)
		return
	end
	-- The menu where the client has one; the switch on its own
	-- where it does not, which is what a right-click always did.
	if mouseButton == "RightButton" and OpenLauncherMenu(owner, later) then return end
	if mouseButton == "RightButton" then
		ToggleEnabled()
	else
		ns.OpenOptions()
	end
end

-- The tooltip for the compartment's line, which is a menu entry rather than a
-- button of ours. The client's menu tooltip where it has one, anchored the way
-- the rest of that menu's are; GameTooltip where it does not.
local function ShowLauncherTooltip(owner)
	if type(MenuUtil) == "table" and type(MenuUtil.ShowTooltip) == "function" then
		MenuUtil.ShowTooltip(owner, FillLauncherTooltip)
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	FillLauncherTooltip(GameTooltip)
	GameTooltip:Show()
end

local function HideLauncherTooltip(owner)
	if type(MenuUtil) == "table" and type(MenuUtil.HideTooltip) == "function" then
		MenuUtil.HideTooltip(owner)
		return
	end
	GameTooltip:Hide()
end

-- The addon compartment: the drop-down under the minimap that lists every
-- addon, which this client has. The minimap button can be hidden, and a broker
-- display is another addon; this is the one launcher that is always there, so
-- hiding the button no longer hides the menu with it.
--
-- Registered here rather than through the toc's AddonCompartmentFunc fields,
-- which name global functions: this keeps the whole launcher in one file, and a
-- client without the frame is one check rather than a toc of dead names.
-- Directly rather than through LibDBIcon's copy, which only adds a button it
-- is also showing on the minimap and writes that choice into the profile.
local compartment
local function RegisterCompartment()
	local frame = _G.AddonCompartmentFrame
	if compartment or type(frame) ~= "table" or type(frame.RegisterAddon) ~= "function" then
		return false
	end
	compartment = {
		text = "Manners",
		icon = ICON,
		notCheckable = true,
		registerForAnyClick = true,
		-- The client hands over which button, inside the input data. Anything
		-- else -- an older shape of the call -- is read as a left click, which
		-- opens the options and changes nothing.
		func = function(_, input)
			local which = type(input) == "table" and input.buttonName or nil
			ns.Guard("addon compartment", LauncherClick, nil, which or "LeftButton", true)
		end,
		funcOnEnter = function(owner) ns.Guard("addon compartment", ShowLauncherTooltip, owner) end,
		funcOnLeave = function(owner) ns.Guard("addon compartment", HideLauncherTooltip, owner) end,
	}
	frame:RegisterAddon(compartment)
	return true
end

function ns.SetupOptions()
	local options = BuildOptions()
	options.args.profiles = AceDBOptions:GetOptionsTable(ns.db)
	options.args.profiles.order = 90
	-- Kept so a control can be read back afterwards. A dropdown that lists the
	-- right entries under the wrong labels renders perfectly and is invisible
	-- to every other check we have.
	ns.optionsTable = options

	AceConfig:RegisterOptionsTable(ADDON, options)
	blizCategory, blizCategoryID = AceConfigDialog:AddToBlizOptions(ADDON, "Manners")
	-- The bug-report box shuts with the page. The standalone window is only
	-- ever opened through OpenOptions, which shuts it there; this is the other
	-- route in. OnHide rather than a check inside the box's own `hidden`,
	-- because that is only asked while the page is being drawn -- which is
	-- exactly when the page is open.
	if blizCategory and blizCategory.HookScript then
		blizCategory:HookScript("OnHide", function() reportOpen = false end)
		blizCategory:HookScript("OnHide", function() shareOpen = false end)
	end

	if LDB then
		local r, g, b = IconTint()
		broker = LDB:NewDataObject(ADDON, {
			type = "launcher",
			text = BrokerText(),
			icon = ICON,
			iconR = r, iconG = g, iconB = b,
			OnClick = function(owner, mouseButton) LauncherClick(owner, mouseButton) end,
			OnTooltipShow = FillLauncherTooltip,
		})
		if LDBIcon and broker then
			LDBIcon:Register(ADDON, broker, ns.db.profile.minimap)
		end
	end
	ns.Guard("addon compartment", RegisterCompartment)
end

-- Put the current state back into the launcher's text and its icon's colour.
--
-- LibDataBroker fires its own change callback when a field on a data object is
-- assigned, so every display showing this launcher repaints from one line here.
-- Called through ns.RepaintOptions, alongside the options page, because the two
-- are stale for the same reason and at the same moments -- and by Core each
-- time a favour is filed, settled or let go, which is when the count changes.
--
-- Everything is checked: the library is optional, the object is only built when
-- it is there, and a launcher whose text is a release behind is not worth
-- taking down the command that changed the setting.
function ns.RefreshBrokerText()
	if not broker then return end
	local text = BrokerText()
	-- Only when it has actually changed. Assigning to a data object wakes every
	-- display showing it, and this is reached at both ends of every fight --
	-- so writing the same string back would be a call into somebody else's
	-- layout code on every pull, in a city, for nothing.
	if broker.text ~= text then broker.text = text end
	-- The tint the same way, one channel at a time: LibDBIcon repaints the
	-- icon on each of the three.
	local r, g, b = IconTint()
	if broker.iconR ~= r then broker.iconR = r end
	if broker.iconG ~= g then broker.iconG = g end
	if broker.iconB ~= b then broker.iconB = b end
end

-- Repaint whatever is on screen from the values as they stand now.
--
-- Most of this page is static, but three things on it are answers to questions
-- with a current answer -- whether we are in combat, what has broken, and
-- whether the bug-report box is open -- and AceConfig only asks a `hidden` or a
-- `name` function while it is drawing. Without this, leaving combat with the
-- window open leaves the combat notice standing over controls that work again.
--
-- Optional at both ends: the library is asked for silently and the method is
-- checked, because failing to repaint a panel must never be the thing that
-- takes down the event handler it is called from.
function ns.RefreshOptionsDisplay()
	if AceConfigRegistry and AceConfigRegistry.NotifyChange then
		AceConfigRegistry:NotifyChange(ADDON)
	end
end

-- LibDBIcon keeps the table it was handed at Register, and AceDB hands out a
-- different one per profile -- so after a switch the checkbox and the button
-- read different tables, and a drag saves the position into the old one.
-- Refresh does the whole job: re-points the table, repositions from the new
-- minimapPos, and shows or hides to match the new hide.
function ns.RefreshMinimapButton()
	if not (LDBIcon and LDBIcon.Refresh and LDBIcon:IsRegistered(ADDON)) then return end
	LDBIcon:Refresh(ADDON, ns.db.profile.minimap)
end

-- Whether the window somebody would be styling the prompt from is on screen.
--
-- Asked rather than subscribed to. AceConfigDialog keeps the frames it has open
-- in a table keyed by addon name, so this is a question with a current answer;
-- a close callback would be a second piece of state to keep in step, and the
-- one thing this must never do is leave a preview running because a notification
-- went missing.
--
-- Everything is checked for existence and every answer defaults to "no": a
-- library version without the table, or a Blizzard panel handle without the
-- method, has to mean the preview times out as it always did rather than
-- throwing inside the scan.
function ns.OptionsOpen()
	local frames = AceConfigDialog and AceConfigDialog.OpenFrames
	if type(frames) == "table" and frames[ADDON] ~= nil then return true end

	-- The other route in: the canvas frame AddToBlizOptions made for the game's
	-- Settings window. Asked whether it is visible, not whether it is shown.
	-- Shutting the Settings window hides the window, not the canvas inside it,
	-- and the client only clears the canvas's own shown flag when another page
	-- takes its place -- so IsShown went on answering yes after the window was
	-- shut, and a preview started from that page pushed its clock forward and
	-- stood in front of real people until the window was next opened.
	-- AceConfigDialog asks its own Settings pages the same way, for the same
	-- reason.
	if blizCategory then
		local ok, visible = pcall(function() return blizCategory:IsVisible() end)
		if ok and visible then return true end
	end
	return false
end

-- Shut the standalone options window, if it is up. Only that one: the game's
-- Settings window is Blizzard's to open and shut, and some of it is protected
-- in a fight. Guarded, since a library without Close just leaves it open.
function ns.CloseOptions()
	if AceConfigDialog and AceConfigDialog.Close then
		pcall(AceConfigDialog.Close, AceConfigDialog, ADDON)
	end
end

-- The key of the tab the options window has open -- "general", "prompt" -- or
-- nil where the library will not say. The library keeps the choice in its
-- status table for the page, which both the standalone window and the Settings
-- page read, so one answer covers both.
function ns.OptionsTab()
	if not (AceConfigDialog and AceConfigDialog.GetStatusTable) then return nil end
	local ok, status = pcall(AceConfigDialog.GetStatusTable, AceConfigDialog, ADDON)
	local groups = ok and type(status) == "table" and status.groups
	local selected = type(groups) == "table" and groups.selected
	return type(selected) == "string" and selected or nil
end

function ns.OpenOptions()
	-- The bug-report box starts shut. Only its own button ever changed it, so
	-- shutting the window and opening it again found the fourteen-line box
	-- still open and the button reading "Hide the report". Left alone when the
	-- window is already up, where this is a click on the minimap button rather
	-- than an opening, and shutting the box under somebody copying it would be
	-- the surprise.
	if not ns.OptionsOpen() then reportOpen = false end
	if not ns.OptionsOpen() then shareOpen = false end

	-- The standalone dialog, first and by default.
	--
	-- This used to try Settings.OpenToCategory first and fall back to here, on
	-- the reasoning that the game's own panel is the more familiar home. It
	-- cannot work that way round: OpenToCategory does not raise when it fails
	-- to find the category, it opens the Settings window at whatever page it
	-- was last on and returns cleanly -- so the pcall reports success and this
	-- function returns, having shown somebody the Controls page. On the client
	-- this addon is actually used on, that is what clicking the minimap button
	-- did.
	--
	-- A pcall cannot tell the difference, and there is nothing else to ask, so
	-- the route that either works or errors goes first.
	local ok = pcall(AceConfigDialog.Open, AceConfigDialog, ADDON)
	if ok then return end

	-- Only if that is somehow unavailable, and only as a last resort, since it
	-- may well land on the wrong page.
	--
	-- By the ID AddToBlizOptions returned, not the canvas frame's own GetID.
	-- Nothing sets a frame ID on that canvas, so it answered 0, which is no
	-- category at all, and the Settings window came up on whatever page it was
	-- last on every time this ran.
	if Settings and Settings.OpenToCategory and blizCategoryID ~= nil then
		pcall(Settings.OpenToCategory, blizCategoryID)
	end
end

-- Open the options on the General tab, where the share boxes are, with the
-- box of this profile's settings showing when that is what was asked for.
-- For /manners export and a bare /manners import. Answers whether there is a
-- page to send them to at all; SelectGroup is asked for because a library
-- without it still opens the window, just not on this tab.
function ns.ShowShareBox(which)
	ns.OpenOptions()
	if which == "export" then shareOpen = true end
	if AceConfigDialog.SelectGroup then
		pcall(AceConfigDialog.SelectGroup, AceConfigDialog, ADDON, "general")
	end
	ns.RefreshOptionsDisplay()
	return true
end
