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
-- names, so the minimap button and the addon list show one picture. No
-- extension: the client finds the .tga itself.
local ICON = "Interface\\AddOns\\Manners\\Textures\\Manners64"

-- Whether there is a minimap button at all: LibDataBroker makes the data
-- object and LibDBIcon puts it on the minimap, so it takes both.
local function HasMinimapButton()
	return LDB ~= nil and LDBIcon ~= nil
end

-- The launcher, once it exists. Kept at file scope so its text can be put back
-- in step from outside SetupOptions, which runs once and then never again.
local broker

-- The addon compartment's entry, once RegisterCompartment has made it. Up here
-- so the minimap switch, built earlier in the file, can ask about it.
local compartment

-- Whether the compartment is a way in right now: Manners is registered there
-- and the compartment is on screen. BetterBlizzFrames and EnhanceQoL hide it.
local function CompartmentShown()
	local frame = _G.AddonCompartmentFrame
	if not compartment or type(frame) ~= "table" then return false end
	if type(frame.IsShown) ~= "function" then return true end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and shown and true or false
end

-- Asked with a net under it: the tooltip and the launcher text are read by
-- other addons' display frames, on their own schedule, and one of them asking
-- before AceDB has handed us a profile must not throw inside somebody else's
-- layout pass.
local function Enabled()
	return ns.db ~= nil and ns.db.profile ~= nil and ns.db.profile.enabled == true
end

-- Whether an unlocked prompt is up to be dragged. Prompt:RefreshPanel hides the
-- panel for a character with nothing it can cast and for /manners off before
-- it reads the lock, so the lock alone is not the answer.
local function DragPanelUp()
	return Enabled() and ns.db.profile.prompt.locked == false
		and ns.caps ~= nil and ns.caps.anyKnown == true
end

-- How many people who buffed you are still waiting for one back: the favours,
-- not the whole queue, since a city crowd would keep that number meaningless.
-- Counted by the debt's live expiry, and none at all while "People who buffed
-- me" is off, because the queue then ignores every debt still on file.
local function WaitingCount()
	local profile = ns.db and ns.db.profile
	if not (profile and profile.sources and profile.sources.owed) then return 0 end
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

-- What the launcher says it is: off and snoozed are worth carrying, because
-- from the outside a prompt that never appears looks like a broken addon.
--
-- Each state is one whole phrase with the addon's name passed in, so a
-- translation sees what the word describes and can put it, and its colour,
-- where its own grammar wants them. The name itself is never translated.
local function BrokerText()
	-- Off outranks a snooze, since a snooze ending brings nothing back while off.
	local ends = Enabled() and ns.SnoozeEndsAt and ns.SnoozeEndsAt()
	if ends then return L["%s |cffffd100snoozed until %s|r"]:format("Manners", ends) end
	if not Enabled() then return L["%s |cffff8080off|r"]:format("Manners") end
	-- Then the favours still to return; with none, just the name.
	local waiting = WaitingCount()
	if waiting == 1 then return L["%s |cff80e0801 waiting|r"]:format("Manners") end
	if waiting > 1 then return L["%s |cff80e080%d waiting|r"]:format("Manners", waiting) end
	return "Manners"
end

-- The colour the launcher's icon is drawn in: dimmed while snoozed, darker
-- still while switched off. The icon is the one part of the launcher always in
-- view on the minimap. Brightness only, never a hue: a tint turns the icon's
-- blue arrow olive and it reads as a different icon at minimap size.
local function IconTint()
	if not Enabled() then return 0.4, 0.4, 0.4 end
	if ns.SnoozeLeft and ns.SnoozeLeft() then return 0.7, 0.7, 0.7 end
	return 1, 1, 1
end

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

-- Redraw the page once a run of slider ticks has stopped, for the Width and
-- Height sliders, which shrink the icon and so change the Icon size slider.
-- The dialog redraws on letting go of a drag, but a mouse wheel never lets go.
-- Held back because a redraw rebuilds the slider under the pointer; the token
-- is there because C_Timer.After cannot be cancelled.
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

---------------------------------------------------------------------------
-- dynamic values
---------------------------------------------------------------------------

local function HasClassBuffs()
	return ns.caps.hasClassBuffs == true
end

local function BuffChoices()
	local values = { auto = L["Automatic"] }
	for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
		local info = ns.BuffInfo(buff)
		local label = (info and info.name) or buff.key
		if not (info and info.known) then label = L["%s |cff808080(not learned)|r"]:format(label) end
		values[buff.key] = label
	end
	return values
end

-- The named distances, read off the list Range.lua measures with, so the
-- dropdown cannot offer a setting nothing implements.
local function ProximityChoices()
	local values = {}
	for _, tier in ipairs(ns.PROXIMITY) do
		values[tier.key] = tier.name
	end
	return values
end

-- AceConfig sorts a select's values by their labels unless it is given an
-- order, and a translation would scramble loosest-to-tightest.
local function ProximityOrder()
	local keys = {}
	for _, tier in ipairs(ns.PROXIMITY) do
		keys[#keys + 1] = tier.key
	end
	return keys
end

-- The spell's name, with the one thing about it that changes who it is offered
-- to. "Mana users only" only while "Skip players the buff does nothing for" is
-- on, since that filter is what holds a mana-only spell back.
local function BuffLabel(buff)
	local label = ns.BuffName(buff)
	if buff.manaOnly and F().relevantOnly then
		label = L["%s |cff808080(mana users only)|r"]:format(label)
	end
	if buff.partyOnly then label = L["%s |cff808080(your group only)|r"]:format(label) end
	return label
end

-- What "Automatic" will actually do, for this character, as it is configured
-- right now: the list in the order it is walked, taken from the same function
-- the scan uses so the two cannot drift.
local function AutoExplanation()
	local castable = ns.CastableBuffs()
	if #castable == 0 then
		-- Each way to have nothing to offer gets its own answer, so nobody is
		-- sent looking at switches that are already on.
		if not HasClassBuffs() then
			return L["This character has nothing it can cast on another player."]
		end
		local anyKnown = false
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if ns.IsBuffKnown(buff) then anyKnown = true end
		end
		if not anyKnown then
			return "|cffff8080"
				.. L["You have not learned any of these yet, so nobody will be offered anything."]
				.. "|r"
		end
		-- The only thing learned is one Automatic never reaches for -- a Mists
		-- warlock with Unending Breath and no Dark Intent yet.
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if buff.neverAuto and ns.IsBuffKnown(buff) and not B().skip[buff.key] then
				return "|cffff8080"
					.. L["Automatic never offers %s -- nobody standing in a city wants it -- so nobody will be offered anything."]
						:format(ns.BuffName(buff))
					.. "|r\n\n"
					.. L["Pin it in the dropdown above if you want it given out anyway."]
			end
		end
		-- Everything learned is switched off, but a spell not learned yet is
		-- still ticked, and learning it brings the prompt back. A neverAuto
		-- spell is left out: learning it would bring nothing back.
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if not buff.neverAuto and not ns.IsBuffKnown(buff) and not B().skip[buff.key] then
				return "|cffff8080"
					.. L["Every spell you have learned is switched off, so nothing is offered until you switch one back on or learn one of the others."]
					.. "|r"
			end
		end
		return "|cffff8080" .. L["Every spell below is switched off, so the prompt will never appear."]
			.. "|r"
	end

	local names = {}
	for _, buff in ipairs(castable) do
		names[#names + 1] = "|cffffffff" .. BuffLabel(buff) .. "|r"
	end
	local list = table.concat(names, ", ")

	-- Blessings overwrite one another, so for these classes Automatic gives one
	-- and stops. "Left alone" rests on reading what they carry: "Always offer"
	-- chooses not to look and a client that hides a blessing's aura cannot, and
	-- either way the first blessing that suits them can replace one of yours
	-- (deliberately, see PickBuffFor).
	--
	-- Whole sentences rather than one with a clause bolted on, so that a
	-- translation can put the exception wherever its own grammar wants it.
	if ns.EXCLUSIVE_BUFFS[ns.caps.class] then
		local hidden = false
		for _, buff in ipairs(castable) do
			local info = ns.BuffInfo(buff)
			if not (info and info.readable) then hidden = true end
		end
		if F().whenBuffed == "always" then
			return L["Your blessings replace one another, so Automatic gives only the first of %s that suits them. |cffffd100Always offer|r does not check what they carry, so it can replace one of yours."]
				:format(list)
		elseif hidden then
			return L["Your blessings replace one another, so Automatic gives only the first of %s that suits them. Where the game hides which blessing somebody carries, it can replace one of yours."]
				:format(list)
		end
		return L["Your blessings replace one another, so Automatic gives only the first of %s that suits them. Anybody already carrying one of yours is left alone."]
			:format(list)
	end

	local text = L["Automatic offers the first of these they are missing, in this order: %s."]
		:format(list)
	if ns.RotatesBuffs() then
		text = text .. "\n|cff888888"
			.. L["Where the game will not say what somebody is carrying, it moves down the list each time instead of offering the same one over and over."]
			.. "|r"
	end
	return text
end

-- What pinning one spell means, and the one case where pinning is a silent
-- switch-off: a pinned buff you have not learned is offered to nobody. The pin
-- is deliberately not reset for you (a failed spell probe must not rewrite a
-- setting), which is why it has to be said out loud here.
local function PinExplanation()
	local choice = B().choice
	local buff = ns.FindBuff(ns.caps.class, choice)
	local name = buff and ns.BuffName(buff) or tostring(choice)

	if buff and ns.IsBuffKnown(buff) then
		return L["Only |cffffffff%s|r is offered, to everybody, whatever else they are missing. The per-spell switches come back with Automatic."]
			:format(name)
	end

	return "|cffff8080"
		.. L["You have pinned %s, which you have not learned."]:format(name)
		.. "|r\n\n"
		.. L["Nothing will be offered to anybody until you learn it or switch back to Automatic."]
end

-- One toggle per spell the class can put on somebody else, built once with the
-- page (only whether each is learned changes, and the label asks that live).
-- Switched on is the *absence* of a key, so an untouched profile stores nothing.
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
					label = L["%s |cff808080(not learned)|r"]:format(label)
				end
				return label
			end,
			desc = L["Switched off, this one is never offered to anybody and Automatic walks straight past it. Everything else carries on as before."],
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
-- else -- a warrior's Battle Shout -- which leaves the strangers toggle with
-- nothing behind it. Core's answer, so the greeting and favour line agree.
local function OnlyReachesGroup()
	return ns.OnlyReachesGroup()
end

-- Whether nothing this character can offer takes a target at all -- a warrior,
-- whose Battle Shout is cast on himself. CastLines builds no /target line for a
-- selfCast buff, so the Targeting section has nothing to say. Follows the
-- per-spell switches and a pin, like OnlyReachesGroup.
local function NeverTargets()
	local castable = ns.CastableBuffs()
	if #castable == 0 then return false end
	for _, buff in ipairs(castable) do
		if not buff.selfCast then return false end
	end
	return true
end

-- Which of the two things that can carry the reason colour is actually on
-- screen (ring, stripe). ApplyStyle refuses the stripe on the framed look, and
-- the ring is a texture *behind* the icon, so hiding the icon or rounding it
-- off (which swaps that texture for a mask) takes the ring away.
local function AccentCarriers()
	local p = P()
	local mode = p.accentMode or "icon"
	local ring = (mode == "icon" or mode == "both") and p.showIcon and not p.roundIcon
	local stripe = (mode == "stripe" or mode == "both") and p.style ~= "framed"
	return ring == true, stripe == true
end

-- Whether the copy-for-a-bug-report box is open: a state of the window, not of
-- the profile, put back in OpenOptions and when the Settings page hides.
local reportOpen = false
-- And the box holding these settings as text, for the same reasons.
local shareOpen = false

-- Everything somebody would otherwise be asked for twice, in one block that can
-- be selected and pasted. No colour codes: this is written to be quoted
-- somewhere that is not a chat frame.
local function BugReport()
	local lines = { ("Manners %s"):format(tostring(ns.BUILD)) }

	-- Guarded: this is read from a `get`, which nothing wraps, and must not take
	-- the page down while somebody is reporting a bug.
	local ok, version, build, _, toc = pcall(GetBuildInfo)
	if ok and version then
		lines[#lines + 1] = ("client %s (%s), interface %s")
			:format(tostring(version), tostring(build), tostring(toc))
	end

	local caps = ns.caps
	lines[#lines + 1] = ("class %s | secrets %s | auras secret now %s | nameplates %s")
		:format(tostring(caps.class), tostring(caps.hasSecrets),
			tostring(caps.aurasSecretNow), tostring(caps.namePlates))
	-- Which spell tables this client was handed, so a spell never offered can be
	-- told from one that does not exist on the reporter's client.
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
		-- The group version the prompt would cast, and the reagent it would
		-- eat as the bags hold it now: "never offers the group buff" is most
		-- often answered here.
		if info and info.groupRank then
			lines[#lines + 1] = ("    group spell %s, reagent %s x%s"):format(
				tostring(info.groupRank), tostring(info.groupReagent),
				tostring(ns.ReagentCount and ns.ReagentCount(info.groupReagent)))
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
	-- Who is ordered and who is held back: "my friend is never offered" is most
	-- often answered by the last number here.
	lines[#lines + 1] = ("friendsFirst=%s restingOnly=%s neverOffered=%d"):format(
		tostring(db.priority.friends), tostring(db.filters.restingOnly), #ns.NeverList())
	lines[#lines + 1] = ("groupBuffs=%s atLeast=%s"):format(
		tostring(db.groupBuffs.use), tostring(db.groupBuffs.atLeast))
	-- The dungeon and raid settings, each of which leaves people out or moves
	-- them up: the raid groups as the ones switched off.
	local skipped = {}
	for group = 1, 8 do
		if db.filters.skipRaidGroups[group] then skipped[#skipped + 1] = tostring(group) end
	end
	lines[#lines + 1] = ("manaFloor=%s readyCheckFirst=%s revivedFirst=%s raidGroupsOff=%s"):format(
		tostring(db.filters.manaFloor), tostring(db.priority.readyCheck),
		tostring(db.priority.revived), #skipped > 0 and table.concat(skipped, ",") or "none")

	local scan = ns.auraScan
	lines[#lines + 1] = ("own buffs: %s read, baseline %s, primed=%s, doubt=%s"):format(
		tostring(scan.read), tostring(scan.held), tostring(scan.primed), tostring(scan.doubt))

	-- The second favour source, left out entirely on a client with no combat
	-- log rather than reported as zeroes.
	if caps.combatLog then
		local log = ns.logScan
		lines[#lines + 1] = ("combat log: armed=%s, %s seen, %s filed"):format(
			tostring(log.armed), tostring(log.applied), tostring(log.noted))
	end

	if #ns.errors == 0 then
		lines[#lines + 1] = "errors: none this session"
	else
		-- How many have happened, then how many are still here to read: the
		-- ring holds thirty, so its length is not the count.
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

-- Who is picked in the never-offer dropdown, waiting for Take them off; a state
-- of the window, like reportOpen.
local neverPicked

-- The never-offer list as dropdown choices, built fresh each time, because a
-- shift-right-click or /manners never can add to it while the page is open.
local function NeverChoices()
	local values = {}
	for _, name in ipairs(ns.NeverList()) do values[name] = name end
	return values
end

-- The eight raid groups as checkbox labels, keyed by group number, which is
-- what the profile stores.
local function RaidGroupChoices()
	local values = {}
	for group = 1, 8 do values[group] = L["Group %d"]:format(group) end
	return values
end

---------------------------------------------------------------------------
-- options table
---------------------------------------------------------------------------

-- The page is a setup flow: Start here takes a new player from nothing to a
-- prompt on a key, and every other tab is for fine-tuning, in the order a
-- player thinks about it. One builder per tab, each a function of its own so
-- that none of them captures every file-level local the page uses: Lua 5.1
-- allows a function 60 upvalues, and a file past that does not load. The
-- shared helpers live in three tables (TAB, Setup, Quick) rather than loose
-- locals, since the main chunk has 200 locals in all.

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

---------------------------------------------------------------------------
-- Setup: the key, the macro and the game's key bindings window
---------------------------------------------------------------------------

local Setup = {}
ns.Setup = Setup

-- The binding Bindings.xml declares: a click on the prompt's secure button.
Setup.COMMAND = "CLICK MannersPrompt:LeftButton"

function Setup.CanBind()
	return type(GetBindingKey) == "function" and type(SetBinding) == "function"
		and type(SaveBindings) == "function"
end

-- Every key on the command, in the order the game lists them.
function Setup.Keys()
	if type(GetBindingKey) ~= "function" then return {} end
	local ok, keys = pcall(function() return { GetBindingKey(Setup.COMMAND) } end)
	if not ok or type(keys) ~= "table" then return {} end
	local out = {}
	for _, key in ipairs(keys) do
		if type(key) == "string" and key ~= "" then out[#out + 1] = key end
	end
	return out
end

-- The first key that buffs the prompted player, or nil.
function Setup.Key()
	return Setup.Keys()[1]
end

-- Put the command on one key, or on none for "" or nil. Key bindings are the
-- game's, saved with its binding set rather than in the profile, so this works
-- on every profile. SetBinding is refused in combat, so nothing happens there;
-- the control that calls this is greyed out in combat anyway.
function Setup.SetKey(key)
	if InCombatLockdown() or not Setup.CanBind() then return false end
	return ns.Guard("key binding", function()
		for _, old in ipairs(Setup.Keys()) do SetBinding(old) end
		if type(key) == "string" and key ~= "" then
			local was = type(GetBindingAction) == "function" and GetBindingAction(key) or ""
			if type(was) == "string" and was ~= "" and was ~= Setup.COMMAND then
				ns.addon:Print(L["%s was bound to %s; it now buffs the prompted player."]
					:format(key, tostring(_G["BINDING_NAME_" .. was] or was)))
			end
			SetBinding(key, Setup.COMMAND)
		end
		SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
		ns.RefreshOptionsDisplay()
	end)
end

-- Unverified on the Camelot client: whether Settings.KEYBINDINGS_CATEGORY_ID
-- exists there. Without either route the button hides itself, and the key
-- control on Start here still does the job.
function Setup.CanOpenBindings()
	if type(Settings) == "table" and type(Settings.OpenToCategory) == "function"
		and Settings.KEYBINDINGS_CATEGORY_ID ~= nil then
		return true
	end
	return type(KeyBindingFrame_LoadUI) == "function"
end

-- The game's key bindings, where Manners has a section of its own. The
-- standalone options window is shut first: it sits above the Settings window,
-- as it does above the ledger. Refused in combat. Answers whether it opened.
function Setup.OpenBindings()
	if InCombatLockdown() then return false end
	ns.CloseOptions()
	if type(Settings) == "table" and type(Settings.OpenToCategory) == "function"
		and Settings.KEYBINDINGS_CATEGORY_ID ~= nil
		and pcall(Settings.OpenToCategory, Settings.KEYBINDINGS_CATEGORY_ID) then
		return true
	end
	if type(KeyBindingFrame_LoadUI) == "function" then
		return (pcall(function()
			KeyBindingFrame_LoadUI()
			ShowUIPanel(KeyBindingFrame)
		end))
	end
	return false
end

-- Whether the macro Make a macro writes is there.
function Setup.MacroMade()
	if type(GetMacroIndexByName) ~= "function" then return false end
	local ok, index = pcall(GetMacroIndexByName, ns.CLICK_MACRO_NAME or "Manners")
	return ok and type(index) == "number" and index > 0
end

---------------------------------------------------------------------------
-- Quick: the presets on Start here
--
-- Each preset writes plain profile fields, the same ones the controls on the
-- other tabs write, then runs the hooks their setters run. InvalidateMacro and
-- ApplyStyle already hold off in combat and catch up when the fight ends, so a
-- preset picked in combat never touches the secure button.
---------------------------------------------------------------------------

local Quick = {}
ns.QuickSetup = Quick

-- A field by its path from the profile, "sources.owed" style.
function Quick.Get(path)
	local node = ns.db.profile
	for part in path:gmatch("[^%.]+") do
		if type(node) ~= "table" then return nil end
		node = node[part]
	end
	return node
end

function Quick.Set(path, value)
	local node = ns.db.profile
	local parts = {}
	for part in path:gmatch("[^%.]+") do parts[#parts + 1] = part end
	for i = 1, #parts - 1 do
		if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
		node = node[parts[i]]
	end
	node[parts[#parts]] = value
end

-- Who to offer to. Never touches sources.asked (reading chat is its own
-- opt-in), the buff, the speech or the look. "nearby" is a new profile's
-- defaults, so a fresh profile shows it; the entries are ordered so that
-- exactly one can match.
Quick.WHO = {
	{ key = "favours", name = L["Only people who buff me"], set = {
		["sources.owed"] = true, ["sources.group"] = false, ["sources.strangers"] = false,
		["filters.whenBuffed"] = "skip",
	} },
	{ key = "group", name = L["People who buff me, and my group"], set = {
		["sources.owed"] = true, ["sources.group"] = true, ["sources.strangers"] = false,
		["filters.whenBuffed"] = "skip",
	} },
	{ key = "nearby", name = L["Everyone near me"], set = {
		["sources.owed"] = true, ["sources.group"] = true, ["sources.strangers"] = true,
		["filters.whenBuffed"] = "skip", ["filters.proximity"] = "near",
	} },
	{ key = "raid", name = L["Dungeon and raid buffer"], set = {
		["sources.owed"] = true, ["sources.group"] = true, ["sources.strangers"] = false,
		["filters.whenBuffed"] = "refresh", ["groupBuffs.use"] = true,
		["priority.readyCheck"] = true, ["priority.revived"] = true,
	} },
}

-- What to say. An entry with `lines` also loads that phrase set.
Quick.VOICE = {
	{ key = "silent", name = L["Stay silent"], set = {
		["speech.enabled"] = false, ["prompt.thankEmote"] = false,
	} },
	{ key = "thank", name = L["Just /thank them"], set = {
		["speech.enabled"] = false, ["prompt.thankEmote"] = true,
	} },
	{ key = "polite", name = L["A polite line"], lines = "polite", set = {
		["speech.enabled"] = true, ["speech.channel"] = "SAY",
		["speech.onlyWhenReturning"] = true, ["prompt.thankEmote"] = false,
	} },
	{ key = "whisper", name = L["Whisper them a thank-you"], lines = "polite", set = {
		["speech.enabled"] = true, ["speech.channel"] = "WHISPER",
		["speech.onlyWhenReturning"] = true, ["prompt.thankEmote"] = false,
	} },
}
-- Phrases.lua loads before this file; without it there is no such set.
if ns.InCharacter then
	table.insert(Quick.VOICE, 4, { key = "incharacter", name = L["Roleplay, in character"],
		lines = "incharacter", set = {
			["speech.enabled"] = true, ["speech.channel"] = "SAY",
			["speech.onlyWhenReturning"] = true, ["prompt.thankEmote"] = false,
		} })
end

function Quick.Find(list, key)
	for _, entry in ipairs(list) do
		if entry.key == key then return entry end
	end
	return nil
end

-- Paths a class cannot use: a warrior's shout never reaches a passer-by, so the
-- passer-by switches are left out of the comparison (and of the choices).
function Quick.Ignored(list, path)
	return list == Quick.WHO and ns.OnlyReachesGroup()
		and (path == "sources.strangers" or path == "filters.proximity")
end

-- Whether every field the entry sets holds its value now, and for an entry
-- with lines, that the set is chosen and its lines are unedited.
function Quick.Matches(list, entry)
	for path, value in pairs(entry.set) do
		if not Quick.Ignored(list, path) and Quick.Get(path) ~= value then return false end
	end
	if entry.lines then
		local sp = SP()
		if sp.presetChoice ~= entry.lines then return false end
		if entry.lines == "incharacter" then
			return ns.InCharacter ~= nil and ns.InCharacter.Active(sp) == true
		end
		return sp.phrases == ns.PhraseSetText(entry.lines)
	end
	return true
end

-- The key of the entry the profile matches, or "custom".
function Quick.Match(list)
	for _, entry in ipairs(list) do
		if Quick.Offered(list, entry) and Quick.Matches(list, entry) then return entry.key end
	end
	return "custom"
end

function Quick.Offered(list, entry)
	return not (list == Quick.WHO and entry.key == "nearby" and ns.OnlyReachesGroup())
end

-- The dropdown's choices: "Custom" only while nothing matches, so it can never
-- be picked, only shown.
function Quick.Values(list)
	local out = {}
	for _, entry in ipairs(list) do
		if Quick.Offered(list, entry) then out[entry.key] = entry.name end
	end
	if Quick.Match(list) == "custom" then out.custom = L["Custom (changed by hand)"] end
	return out
end

function Quick.Order(list)
	local values = Quick.Values(list)
	local keys = {}
	for _, entry in ipairs(list) do
		if values[entry.key] then keys[#keys + 1] = entry.key end
	end
	if values.custom then keys[#keys + 1] = "custom" end
	return keys
end

function Quick.Apply(list, key)
	return ns.Guard("quick setup", function()
		local entry = Quick.Find(list, key)
		if entry then
			for path, value in pairs(entry.set) do Quick.Set(path, value) end
			if entry.lines then
				local sp = SP()
				sp.presetChoice = entry.lines
				sp.phrases = ns.PhraseSetText(entry.lines) or sp.phrases
			end
			-- The hooks the individual setters run; both hold off in combat.
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyStyle()
			ns.addon:Print(L["Set up: %s."]:format(entry.name))
		end
		-- The broker text too: the favour count follows People who buff me.
		ns.RepaintOptions()
	end)
end

-- The confirm question for picking `key`, or false. Who: only over choices made
-- by hand. Voice: only when the box holds lines somebody wrote.
function Quick.Confirm(list, key)
	local entry = Quick.Find(list, key)
	if not entry then return false end
	if list == Quick.WHO then
		if Quick.Match(list) == "custom" then
			return L["This replaces your own choices on Who to buff and When to offer. Continue?"]
		end
		return false
	end
	if entry.lines then
		local sp = SP()
		local edited = sp.phrases ~= ns.PhraseSetText(sp.presetChoice or "roleplay")
		local inCharacter = ns.InCharacter and ns.InCharacter.Active(sp)
		if edited and not inCharacter then
			return L["This replaces the lines you wrote with the %s lines. Continue?"]:format(entry.name)
		end
	end
	return false
end

-- One live sentence about who is offered, from the values as they stand,
-- whatever the preset: on Custom it says what the custom mix is.
function Quick.WhoSummary()
	local s, f = S(), F()
	local who = {}
	if s.owed then who[#who + 1] = L["people who buff me"] end
	if s.group then who[#who + 1] = L["my group"] end
	if s.strangers and not ns.OnlyReachesGroup() then
		local about
		for _, tier in ipairs(ns.PROXIMITY) do
			if tier.key == f.proximity then about = tier.about end
		end
		who[#who + 1] = about and L["passers-by within %s"]:format(about) or L["passers-by"]
	end
	local list = #who > 0 and table.concat(who, ", ") or L["nobody"]
	local buffed = f.whenBuffed == "refresh" and L["topped up when low"]
		or f.whenBuffed == "always" and L["offered anyway"]
		or L["skipped"]
	local text = L["Offering to: %s. Already buffed: %s."]:format(list, buffed)
	if s.asked then text = text .. " " .. L["People who ask in chat: on."] end
	return text
end

-- And one about what is said.
function Quick.VoiceSummary()
	local sp = SP()
	local thanks = P().thankEmote
	if not sp.enabled then
		return thanks and L["Only /thank."] or L["Silent."]
	end
	local set = ns.PHRASE_SETS[sp.presetChoice or "roleplay"]
	local label
	if ns.InCharacter and ns.InCharacter.Active(sp) then
		label = set and set.label
	elseif set and sp.phrases == ns.PhraseSetText(sp.presetChoice or "roleplay") then
		label = set.label
	end
	local where = sp.channel == "WHISPER" and L["a whisper"]
		or "/" .. tostring(ns.CHANNEL_COMMANDS[sp.channel] or "say")
	local text
	if label then
		text = sp.onlyWhenReturning
			and L["Says a %s line in %s when you buff someone back."]:format(label, where)
			or L["Says a %s line in %s when you buff someone."]:format(label, where)
	else
		text = sp.onlyWhenReturning
			and L["Says one of your own lines in %s when you buff someone back."]:format(where)
			or L["Says one of your own lines in %s when you buff someone."]:format(where)
	end
	if thanks then text = text .. " " .. L["Also /thanks people who buff you."] end
	return text
end

-- Start here: switching Manners on, the first steps, the snooze and the
-- ledger. Ledger.lua repaints this tab by its key, "general".
local function BuildStartTab()
	return {
		type = "group",
		name = TAB.general,
		order = 1,
		args = {
			enabled = {
				type = "toggle",
				name = L["Enable"],
				order = 1,
				width = "full",
				get = function() return ns.db.profile.enabled end,
				set = function(_, v)
					ns.db.profile.enabled = v
					ns.Prompt:Refresh()
					-- The launcher's text carries this switch too. Through
					-- the guarded shared call, because what runs on the far
					-- side is another addon's display frame.
					ns.RepaintOptions()
				end,
			},
			-- Switched off, every other page still reads as a working
			-- addon being configured. The prompt simply never appears.
			offNotice = {
				type = "description",
				order = 1.5,
				hidden = function() return ns.db.profile.enabled end,
				name = "|cffff8080"
					.. L["Manners is switched off, so the prompt will never appear. Everything below is still saved."]
					.. "|r",
			},
			noBuffs = {
				type = "description",
				order = 2,
				fontSize = "medium",
				hidden = HasClassBuffs,
				-- "Your class has none" and "we could not work out what
				-- you can cast" look identical from hasClassBuffs alone;
				-- CLASSES_WITHOUT_BUFFS is what tells them apart.
				name = function()
					if ns.caps.class and ns.CLASSES_WITHOUT_BUFFS[ns.caps.class] then
						return "\n|cffff8080"
							.. L["Your class has no buffs it can cast on another player."]
							.. "|r\n\n"
							.. L["Manners has nothing to offer here. It is still worth keeping installed on an alt that does."]
							.. "\n"
					end
					-- The command is handed in rather than written into the
					-- sentence, so no translation can turn it into a word the
					-- slash handler does not know.
					return "\n|cffff8080" .. L["Manners could not work out what you can cast."]
						.. "|r\n\n"
						.. L["Either your class has nothing for other players, or the spell probe came back empty -- %s says which."]
							:format("|cffffd100/manners debug|r")
						.. "\n"
				end,
			},
			howItWorks = {
				type = "description",
				order = 3,
				fontSize = "medium",
				hidden = function() return not HasClassBuffs() end,
				name = "\n|cffffd100" .. L["How this works"] .. "|r\n"
					.. L["Blizzard does not let an addon cast a spell by itself, so Manners works out who deserves a buff and puts them on the prompt. Click the prompt and it casts."]
					.. "\n\n|cffffd100" .. L["Putting it on a key"] .. "|r\n"
					.. L["Make the macro below and drag it onto a bar, or bind a key under Options > Keybindings > Manners."]
					.. "\n",
			},

			startHeader = { type = "header", name = L["Getting started"], order = 10 },
			makeMacro = {
				type = "execute",
				name = L["Create the macro"],
				-- The macro's text is handed in: it is what CreateClickMacro
				-- really writes, and a translated copy would describe a
				-- macro that does not exist.
				desc = L["Adds a macro called Manners containing %s. Drag it onto an action bar and it fires the prompt."]
					:format("/click MannersPrompt LeftButton 1"),
				order = 11,
				hidden = function() return not HasClassBuffs() end,
				func = function() ns.CreateClickMacro() end,
			},

			-- The three lengths in ns.SNOOZE_CHOICES. The minimap menu
			-- keeps its own list, with an hour added; all of them go
			-- through ns.StartSnooze, as /manners snooze does, so every
			-- way in says the same thing in chat.
			snoozeHeader = {
				type = "header", name = L["Snooze"], order = 15,
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
					-- is only shown while it is true. Worded for a snooze
					-- started in the fight and one started before it.
					if ends and InCombatLockdown() then
						return L["|cffffd100Snoozed until %s.|r In a fight the prompt stays as the fight found it, and follows the snooze once the fight ends."]
							:format(ends)
					elseif ends and DragPanelUp() then
						-- The lock is read before the snooze, so an unlocked
						-- prompt stays on screen for the whole snooze.
						return L["|cffffd100Snoozed until %s.|r The prompt is unlocked, so it stays up to be dragged, casting nothing, until you lock it."]
							:format(ends)
					elseif ends then
						-- Not "offered when it ends": a favour is remembered for
						-- as long as the When tab says, usually less than a snooze.
						return L["|cffffd100Snoozed until %s.|r No prompt until then, though who buffs you is still noticed."]
							:format(ends)
					end
					return L["Keep the prompt out of the way for a while without switching Manners off. It comes back when the time is up, or after a %s."]
						:format("/reload")
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
				name = L["Stop snoozing"],
				order = 19,
				hidden = function() return not ns.SnoozeLeft() end,
				func = function() ns.StopSnooze() end,
			},

			miscHeader = {
				type = "header", name = L["Minimap"], order = 20,
				hidden = function() return not HasMinimapButton() end,
			},
			minimap = {
				type = "toggle",
				name = L["Show minimap button"],
				order = 21,
				-- Said where the choice is made, because hiding the button
				-- loses nothing only while the compartment holds Manners
				-- and is itself on screen.
				desc = function()
					if CompartmentShown() then
						return L["Manners stays in the addon compartment under the minimap either way."]
					end
					return L["Without it, |cffffd100/manners|r and the AddOns page in the game's options are the way in."]
				end,
				-- Gone entirely where the libraries are not: there is no
				-- button for a greyed-out control to be about.
				hidden = function() return not HasMinimapButton() end,
				get = function() return not ns.db.profile.minimap.hide end,
				set = function(_, v)
					ns.db.profile.minimap.hide = not v
					if LDBIcon then
						if v then LDBIcon:Show(ADDON) else LDBIcon:Hide(ADDON) end
					end
				end,
			},

			-- What the addon has done, rather than a setting. Here
			-- because General is the page people land on, and the
			-- window is otherwise only a slash command away.
			ledgerHeader = {
				type = "header", name = L["Favour ledger"], order = 50,
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
				name = L["Open the ledger"],
				desc = L["Who buffed you and with what, whether you returned it, and who you buffed unasked. Also %s, or shift-click the minimap button."]
					:format("/manners ledger"),
				order = 52,
				hidden = function() return not ns.Ledger end,
				-- This window shut first: it sits in a higher strata than
				-- the ledger, which would open hidden underneath it.
				func = function()
					ns.CloseOptions()
					ns.Ledger.Show()
				end,
			},
		},
	}
end

-- Who to buff, built apart from the rest so that no one function captures
-- every file-level local the page uses: Lua 5.1 allows a function 60
-- upvalues, and a file past that does not load. Every tab has its own
-- builder for the same reason.
local function BuildWhoTab()
	local who = {
		type = "group",
		name = TAB.who,
		order = 2,
		hidden = function() return not HasClassBuffs() end,
		args = {
			buffsHeader = { type = "header", name = L["Buffs"], order = 1 },
			choice = {
				type = "select",
				name = L["Buff to cast"],
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
			sourcesHeader = { type = "header", name = L["Sources"], order = 10 },
			-- Three toggles, all off, and the only symptom is a prompt that
			-- never appears -- which is what a broken addon looks like.
			emptyWarning = {
				type = "description",
				order = 10.5,
				hidden = function()
					local s = S()
					-- A source this class cannot use (passers-by, for a warrior)
					-- does not count as switched on: its toggle is hidden.
					return s.owed or s.group or s.asked or (s.strangers and not OnlyReachesGroup())
				end,
				name = "|cffff8080"
					.. L["Nothing below is switched on, so the prompt will never appear."] .. "|r",
			},
			owed = {
				type = "toggle",
				name = L["People who buff me"],
				-- A function: a warrior's shout reaches only his group (his own
				-- subgroup in a raid on the older flavours), so a stranger who
				-- buffed him is turned down until they join.
				desc = function()
					if OnlyReachesGroup() then
						if ns.PARTY_IS_SUBGROUP then
							return L["Watch for buffs cast on you and offer to return them. What you cast reaches only your own party -- in a raid, your own subgroup -- so somebody outside it is offered once they join."]
						end
						return L["Watch for buffs cast on you and offer to return them. What you cast reaches your group only, so somebody outside it is offered once they join."]
					end
					return L["Watch for buffs cast on you and offer to return them. Works on strangers who are not in your group."]
				end,
				order = 11,
				width = "full",
				get = sGet,
				set = sSet,
			},
			group = {
				type = "toggle",
				name = L["My party and raid"],
				order = 13,
				width = "full",
				get = sGet,
				set = sSet,
			},
			-- Group buffs (GroupBuffs.lua), under the source they change: they
			-- only ever replace offers to your party. Shown to the classes that
			-- have a group version at all, learned yet or not.
			groupBuffsUse = {
				type = "toggle",
				name = L["Use group buffs"],
				-- Worded for this class and the group spells it has learned.
				desc = function() return (ns.GroupBuffDescriptions()) end,
				order = 13.1,
				width = "full",
				hidden = function() return not (ns.ClassHasGroupBuffs and ns.ClassHasGroupBuffs()) end,
				disabled = function() return not S().group end,
				get = function() return ns.db.profile.groupBuffs.use end,
				-- The next scan (a fraction of a second) folds or unfolds the
				-- party, and the macro follows it.
				set = function(_, v) ns.db.profile.groupBuffs.use = v end,
			},
			groupBuffsAtLeast = {
				type = "range",
				-- Says what happens at the number, so it reads on its own
				-- wherever the page puts it.
				name = L["Group buff once this many need it"],
				desc = function() return select(2, ns.GroupBuffDescriptions()) end,
				order = 13.2,
				min = 2,
				max = 5,
				step = 1,
				hidden = function() return not (ns.ClassHasGroupBuffs and ns.ClassHasGroupBuffs()) end,
				disabled = function() return not (S().group and ns.db.profile.groupBuffs.use) end,
				get = function() return ns.db.profile.groupBuffs.atLeast end,
				set = function(_, v) ns.db.profile.groupBuffs.atLeast = math.floor(v) end,
			},
			strangers = {
				type = "toggle",
				name = L["Nearby players not in my group"],
				-- IterateUnits asks target, mouseover and focus before it
				-- touches a single nameplate.
				desc = L["Offer passers-by who are missing the buff. Seen through nameplates, your target, your focus and your mouseover."],
				order = 14,
				width = "full",
				-- Hidden, not disabled: nothing on this page could ever make a
				-- shout reach a stranger.
				hidden = OnlyReachesGroup,
				get = sGet,
				set = sSet,
			},
			strangersNote = {
				type = "description",
				order = 14.5,
				hidden = function() return not OnlyReachesGroup() end,
				name = "|cff888888"
					.. L["Everything you can offer is cast on yourself and heard by your party, so there is nothing to give a passer-by."]
					.. "|r",
			},
			-- The source that reads chat. The tooltip gives the gist; the full rule
			-- for what counts as asking lives in Requests.lua, which is the rule in code.
			asked = {
				type = "toggle",
				name = L["People who ask me for it"],
				desc = L["For a minute, offer your buff to somebody who asks for it in /say, /yell, group chat or a whisper -- \"int pls\", \"fort?\", \"buffs please\"."]
					.. "\n\n"
					.. L["Only short requests count, and in a fight only whispers. Nothing is said back to them."]
					.. "\n\n|cff888888"
					.. L["Off at first: reading chat is guesswork, so now and then somebody only talking about a buff is offered one."]
					.. "|r",
				order = 14.6,
				width = "full",
				get = sGet,
				set = sSet,
			},

			-- Not a source: everybody here is already on the list by one of the
			-- sources above. This decides who reaches the top of it.
			firstHeader = { type = "header", name = L["Who comes first"], order = 15 },
			target = {
				type = "toggle",
				name = L["Whoever I have targeted comes first"],
				-- The second condition is the first one arriving from the When
				-- tab: Always offer means nobody's buffs are read, so there is
				-- never a reading to promote a target on.
				desc = L["Your target outranks a favour owed, but only when the game can read that they are missing the buff."]
					.. "\n\n"
					.. L["Not while |cffffd100If they already have the buff|r is set to Always offer, under When, since nothing is read then."]
					.. "\n\n|cff888888"
					.. L["Mouseover is left out: the prompt would flicker as the cursor crossed the screen."]
					.. "|r",
				order = 16,
				width = "full",
				get = prGet,
				set = prSet,
			},
			friends = {
				type = "toggle",
				name = L["My friends and guildmates come before the others"],
				-- Inside a kind of offer and never across one, which is what the
				-- sort does; see BuildQueue.
				desc = L["A friend or guildmate goes ahead of the other passers-by, or of the rest of your group. It only changes the order; nobody is added or left out."]
					.. "\n\n|cff888888"
					.. L["Friends include Battle.net friends. When the game will not say whether somebody is a friend, they are ranked like anybody else."]
					.. "|r",
				order = 17,
				width = "full",
				get = prGet,
				set = prSet,
			},

			skipHeader = { type = "header", name = L["Who to skip"], order = 20 },
			relevantOnly = {
				type = "toggle",
				name = L["Skip players the buff does nothing for"],
				desc = L["Mana-only buffs such as Arcane Intellect, Wisdom and Divine Spirit are wasted on warriors and rogues."],
				order = 21,
				width = "full",
				get = fGet,
				set = fSet,
			},
			requireInRange = {
				-- The label is the promise: only a known out-of-range is hidden.
				type = "toggle",
				name = L["Hide players known to be out of range"],
				desc = L["When the game will not tell us the range -- common on this client -- they are still offered."]
					.. " " .. L["Group members the game cannot see at all -- still in town, or far off in the instance -- count as out of range."],
				order = 22,
				width = "full",
				get = fGet,
				set = fSet,
			},
			proximity = {
				type = "select",
				name = L["How near a passer-by has to be"],
				-- The yardage is here rather than in the choices: what somebody
				-- picks is a feeling, but they will want to know roughly what
				-- they just asked for.
				desc = L["Being in range is not the same as being near: Arcane Intellect and its like reach about thirty yards, which in a city is everybody on the screen."]
					.. "\n\n" .. L["|cffffd100Anywhere I can cast|r -- about thirty yards, as it was."]
					.. "\n" .. L["|cffffd100Nearby|r -- about ten yards."]
					.. "\n" .. L["|cffffd100Right beside me|r -- about five yards."]
					.. "\n\n"
					.. L["Only passers-by are measured; not somebody who buffed you, your group, or whoever you targeted or focused."]
					.. "\n\n|cff888888"
					.. L["The game gives no exact distance, so this is measured as closely as the client allows. When it cannot measure at all, everybody in casting range is offered."]
					.. "|r",
				order = 22.5,
				width = "full",
				values = ProximityChoices,
				sorting = ProximityOrder,
				-- About passers-by only, so it follows the passer-by toggle.
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
				-- Which signal is doing the measuring and how often it answers,
				-- since a filter that has quietly stopped measuring looks the
				-- same as nobody being nearby.
				name = function()
					return "|cff888888" .. tostring(ns.ProximitySummary()) .. "|r"
				end,
			},
			restingOnly = {
				type = "toggle",
				name = L["Only offer passers-by in cities and inns"],
				-- Hidden and disabled like the distance setting above.
				desc = L["Out in the world, passers-by are left alone; they are offered only where the game shows you as resting, which is in a city or an inn."]
					.. "\n\n"
					.. L["Somebody who buffed you, your group, and whoever you have targeted or focused are offered anywhere."]
					.. "\n\n|cff888888"
					.. L["If the game will not say whether you are resting, passers-by are offered as usual."]
					.. "|r",
				order = 22.7,
				width = "full",
				hidden = OnlyReachesGroup,
				disabled = function() return not S().strangers end,
				get = fGet,
				set = fSet,
			},
			minLevel = {
				type = "range",
				name = L["Minimum level"],
				desc = L["Players below this are never offered. Somebody known only by name cannot be level-checked and is offered anyway."],
				order = 24,
				min = 1,
				max = 60,
				step = 1,
				get = fGet,
				set = fSet,
			},

			-- Everything a dungeon or a raid adds, together where somebody
			-- setting up for one will look.
			raidHeader = { type = "header", name = L["Dungeons and raids"], order = 25 },
			readyCheck = {
				type = "toggle",
				name = L["Party or raid comes first at a ready check"],
				desc = L["From a ready check until the pull (or a minute after everybody has answered), everybody in your party or raid who is missing your buff goes to the front of the queue."],
				order = 25.1,
				width = "full",
				get = prGet,
				set = prSet,
			},
			revived = {
				type = "toggle",
				name = L["Somebody just back from the dead comes first"],
				desc = L["Dying costs every buff, so for two minutes after a group member is brought back to life, they go to the front of the queue if they are missing yours."],
				order = 25.2,
				width = "full",
				get = prGet,
				set = prSet,
			},
			skipRaidGroups = {
				type = "multiselect",
				name = L["Raid groups I buff"],
				-- Somebody told "groups 1 to 4" should be able to untick the
				-- rest and forget about it.
				desc = L["In a raid, only members of the groups ticked here are offered your buff, the way a raid leader hands out groups to each buffer. Somebody who buffed you or asked, and whoever you target, is offered whatever their group. Outside a raid this does nothing."],
				order = 25.3,
				values = RaidGroupChoices,
				-- Stored as the groups switched off, so a new profile buffs all
				-- eight and the box shows them ticked.
				get = function(_, group) return F().skipRaidGroups[group] ~= true end,
				set = function(_, group, on)
					F().skipRaidGroups[group] = (not on) or nil
				end,
			},

			neverHeader = { type = "header", name = L["Never offer"], order = 30 },
			neverNote = {
				type = "description",
				order = 31,
				fontSize = "medium",
				name = function()
					local count = #ns.NeverList()
					if count == 0 then
						return L["Nobody is on the list. Shift-right-click the prompt to put whoever it is showing on it, or add a name below."]
					end
					-- The favour exception (STATUS.md) is said every time the list
					-- is, rather than in a tooltip nobody hovers.
					local text = count == 1
						and L["One person is on the list. They are never offered anything as a passer-by or as a member of your group."]
						or L["%d people are on the list. They are never offered anything as passers-by or as members of your group."]:format(count)
					return text .. "\n\n"
						.. L["Somebody on it who buffs you is still offered the favour back. Shift-right-click them on the prompt to let that favour go."]
				end,
			},
			neverAdd = {
				type = "input",
				name = L["Add somebody by name"],
				desc = L["Spelled the way the prompt shows them. Capitals do not matter."],
				order = 32,
				width = "full",
				-- Always empty: it is a box to type into, not a setting with a
				-- value to show back.
				get = function() return "" end,
				set = function(_, value) ns.PutOnNeverList(value) end,
			},
			neverPick = {
				type = "select",
				name = L["On the list"],
				order = 33,
				values = NeverChoices,
				disabled = function() return #ns.NeverList() == 0 end,
				-- Only somebody still on the list: the pick outlives a removal
				-- made from chat.
				get = function()
					if neverPicked and ns.IsNeverOffered(neverPicked) then return neverPicked end
					return nil
				end,
				set = function(_, value) neverPicked = value end,
			},
			neverRemove = {
				type = "execute",
				name = L["Take them off"],
				order = 34,
				disabled = function()
					return not (neverPicked and ns.IsNeverOffered(neverPicked))
				end,
				func = function()
					local name = neverPicked and ns.AllowAgain(neverPicked)
					neverPicked = nil
					if name then
						ns.addon:Print(L["|cffffffff%s|r can be offered again."]:format(name))
					end
				end,
			},
			neverClear = {
				type = "execute",
				name = L["Clear the list"],
				order = 35,
				disabled = function() return #ns.NeverList() == 0 end,
				confirm = true,
				confirmText = L["Take everybody off the never-offer list?"],
				func = function()
					ns.ClearNeverList()
					neverPicked = nil
				end,
			},
		},
	}
	AddBuffToggles(who.args)
	return who
end

-- When to offer, and when the prompt holds back.
local function BuildWhenTab()
	return {
		type = "group",
		name = TAB.when,
		order = 3,
		hidden = function() return not HasClassBuffs() end,
		args = {
			buffedHeader = { type = "header", name = L["Already buffed"], order = 1 },
			whenBuffed = {
				type = "select",
				name = L["If they already have the buff"],
				-- The favour exception is said here and on the choice
				-- itself because none of the three choices touches it:
				-- BuildQueue offers a debt regardless.
				desc = L["Reading whether somebody has a buff needs the game's permission. See the Diagnostics tab for which of your buffs qualify."]
					.. "\n\n"
					.. L["Somebody who buffed you is offered the favour back whichever you choose, even if they already have it."],
				order = 2,
				width = "full",
				values = {
					skip = L["Leave them alone (unless they buffed you)"],
					refresh = L["Offer a top-up when it is running out"],
					always = L["Always offer, whatever they have"],
				},
				get = fGet,
				set = fSet,
			},
			refreshUnder = {
				type = "range",
				name = L["Top up when under (minutes) are left"],
				desc = L["Only offer a refresh once their remaining time drops below this. Somebody whose timer cannot be read is left alone, unless they buffed you."],
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
				name = "|cffff8080"
					.. L["Everyone nearby will be offered constantly, including people whose buff has barely ticked down. Expect to be spending mana."]
					.. "|r\n\n|cff888888"
					.. L["Nothing is read in this mode, so |cffffd100Whoever I have targeted comes first|r has no effect."]
					.. "|r",
			},

			-- Only the mount has a switch: dead, a taxi and a vehicle are
			-- places nothing can be cast from, while a cast from a mount
			-- works and costs you the mount, a trade some players want.
			wayHeader = { type = "header", name = L["Out of the way"], order = 20 },
			hideMounted = {
				type = "toggle",
				name = L["Not while mounted"],
				desc = L["Keep the prompt away while you are on a mount, since casting would take you off it. It comes back when you get off."]
					.. "\n\n|cff888888"
					.. L["It already stays away while you are dead, on a flight path or in a vehicle. In a fight the prompt stays as the fight found it until the fight ends."]
					.. "|r",
				order = 21,
				width = "full",
				get = fGet,
				set = fSet,
			},
			-- The key keeps its old name, "hide in combat", but it hides
			-- nothing: Hide() on the protected button is refused in combat,
			-- and a secure visibility driver ([combat] resolves here) would
			-- leave a hidden button that still fires from its key binding
			-- and /click, casting the frozen macro out of sight. So the
			-- panel stays up on purpose, and this decides whether the
			-- confirmation flash of a click in a fight still shows.
			hideInCombat = {
				type = "toggle",
				name = L["Keep the prompt dim and still in combat"],
				desc = L["A click still casts in combat, and the prompt flashes to say what happened -- red if it failed. With this on it stays dimmed and still for the fight."]
					.. "\n\n|cff888888"
					.. L["It stays on screen in a fight on purpose: your key binding would still cast the frozen macro if it were hidden."]
					.. "|r",
				order = 38,
				width = "full",
				get = pGet,
				set = pSet,
			},
			manaFloor = {
				type = "range",
				name = L["Percent of my mana to keep for myself"],
				-- The two kinds that are never held back are named, since the
				-- rule is about who asked rather than about who they are.
				desc = L["Below this percent of your mana, only people who buffed you or asked you for it are offered; your group, your target and passers-by wait until you have 5 percent more than this. 0 turns it off."],
				order = 24.5,
				min = 0,
				max = 90,
				step = 5,
				-- A class with no mana bar has nothing to keep.
				hidden = function()
					local class = ns.caps and ns.caps.class
					return class ~= nil and ns.MANA_CLASSES[class] ~= true
				end,
				get = fGet,
				set = fSet,
			},
		},
	}
end

-- What I say: the thanks and the lines that go out with a cast.
local function BuildSpeechTab()
	return {
		type = "group",
		name = TAB.click,
		order = 4,
		hidden = function() return not HasClassBuffs() end,
		args = {
			-- Everything on this tab is a line in the macro, a secure
			-- attribute the fight has frozen: the macro is rebuilt when the
			-- fight ends, and until then a press runs the old one.
			combatNotice = {
				type = "description",
				order = 0.5,
				fontSize = "medium",
				hidden = function() return not InCombatLockdown() end,
				name = L["|cffffd100In combat.|r Blizzard freezes the prompt's macro during a fight, so these settings apply once it ends."]
					.. "\n",
			},

			speechHeader = { type = "header", name = L["Speech"], order = 10 },
			intro = {
				type = "description",
				order = 11,
				fontSize = "medium",
				name = L["Say something when you buff somebody. The line is added to the macro the prompt runs, so it goes out as you talking rather than as an addon."]
					.. "\n\n|cff888888"
					.. L["The game refuses addon-sent %s and %s outside instances, so going through the macro is what lets them work."]:format("/say", "/yell")
					.. "|r\n",
			},
			-- The other answer to a favour arriving, so under the flash.
			-- Its own get and set: pSet restyles the prompt, and this
			-- changes nothing on it.
			thankEmote = {
				type = "toggle",
				name = L["Thank them with an emote"],
				desc = L["When somebody buffs you and returning it is on the prompt, you /thank them, and everybody near sees it."]
					.. "\n\n|cff888888"
					.. L["Never in a fight, in a dungeon, raid, battleground or arena. At most once per person every five minutes, and once every ten seconds in all, so a raid full of buffs is one thank."]
					.. "|r",
				order = 21.2,
				width = "full",
				-- Nobody is noticed buffing you with that source off.
				disabled = function() return not S().owed end,
				get = function() return P().thankEmote end,
				set = function(_, v) P().thankEmote = v end,
			},
			enabled = {
				type = "toggle",
				name = L["Say something"],
				order = 12,
				width = "full",
				get = spGet,
				set = spSet,
			},
			channel = {
				type = "select",
				name = L["Channel"],
				desc = L["Who hears the line: Say and Emote reach players near you, Yell a wider area, Party and Raid your group. Whisper them sends it to the person you buff and nobody else."],
				order = 13,
				disabled = function() return not SP().enabled end,
				values = { SAY = L["Say"], YELL = L["Yell"], PARTY = L["Party"], RAID = L["Raid"], EMOTE = L["Emote"],
					WHISPER = L["Whisper them"] },
				get = spGet,
				set = spSet,
			},
			onlyWhenReturning = {
				type = "toggle",
				name = L["Only when returning a favour"],
				desc = L["Speak only when buffing somebody who buffed you first. Leave this on unless you want to announce every stranger you buff."],
				order = 14,
				width = "full",
				disabled = function() return not SP().enabled end,
				get = spGet,
				set = spSet,
			},

			phrasesHeader = { type = "header", name = L["Phrases"], order = 20 },
			preset = {
				type = "select",
				name = L["Load a set"],
				desc = L["Replaces the lines below. Edit them afterwards as much as you like."],
				order = 21,
				disabled = function() return not SP().enabled end,
				-- It overwrites hand-written lines with no undo.
				confirm = function(_, value)
					return L["Replace everything in the box below with the %s lines?"]:format(
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
				-- fires when the item clicked becomes checked, so a set shown
				-- as chosen could not be picked again to reload it.
				get = function()
					local choice = SP().presetChoice or "roleplay"
					if SP().phrases == ns.PhraseSetText(choice) then return choice end
					-- In character is untouched on every character sharing the
					-- profile, though each one's examples differ.
					if ns.InCharacter and ns.InCharacter.Active(SP()) then return choice end
					return nil
				end,
				set = function(_, value)
					SP().presetChoice = value
					SP().phrases = ns.PhraseSetText(value) or SP().phrases
					ns.Prompt:InvalidateMacro()
					ns.addon:Print(L["loaded the %s lines."]:format(
						ns.PHRASE_SETS[value] and ns.PHRASE_SETS[value].label or value))
				end,
			},
			phrasesHelp = {
				type = "description",
				order = 22,
				name = L["One per line -- a random one is picked each time the prompt changes target. Tokens: |cff888888{name}|r the player, |cff888888{buff}|r the spell."]
					.. "\n|cff888888"
					.. L["A macro holds 255 characters, so a line that will not fit is dropped, not cut off -- |cffffd100Roll a few|r shows what would go out. An empty box goes back to the chosen set."]
					.. "|r",
			},
			inCharacterNote = {
				type = "description",
				order = 22.5,
				hidden = function() return not (ns.InCharacter and ns.InCharacter.Active(SP())) end,
				name = function()
					return "\n|cffffd100" .. L["In character: the line is picked when you click, to fit your race, your faction and the moment -- thanks for a favour, an answer to a request, or an offer. Below are a few of this character's lines; edit them and they become your own lines instead."]
						.. " " .. L["It notices more than that: your class, the spell, what they gave you, how often you two have met this session, where you are and the hour."]
						.. "|r\n"
				end,
			},
			phrases = {
				type = "input",
				name = "",
				order = 23,
				multiline = 10,
				width = "full",
				disabled = function() return not SP().enabled end,
				-- In character shows the examples of whoever is logged in,
				-- whichever character's the shared profile was saved with.
				get = function(info)
					if ns.InCharacter and ns.InCharacter.Active(SP()) then
						return ns.PhraseSetText("incharacter")
					end
					return spGet(info)
				end,
				-- An empty box snaps back to the set the dropdown names, the
				-- way the First line does, since the load-time repair would
				-- refill it anyway: what the box shows is what is kept.
				set = function(info, value)
					if type(value) ~= "string" or value:match("^%s*$") then
						value = ns.PhraseSetText(SP().presetChoice) or ns.PhraseSetText("roleplay")
					end
					spSet(info, value)
				end,
			},
			roll = {
				type = "execute",
				name = L["Roll a few"],
				order = 24,
				func = function()
					-- In character speaks differently for each reason, so
					-- it rolls one line per reason.
					if ns.InCharacter and ns.InCharacter.Active(SP()) then
						ns.InCharacter.Roll(L["Somebody"])
						return
					end
					-- reason "owed" so the sample survives the
					-- only-when-returning filter either way. The
					-- stand-in name is read in the lines printed, so it
					-- is in the player's language like the lines are.
					local somebody = L["Somebody"]
					local fake = {
						short = somebody,
						name = somebody,
						reason = "owed",
						buff = ns.ResolveBuff(true),
					}
					for _ = 1, 3 do
						-- The same budget the cast path measures, for a
						-- representative name.
						ns.addon:Print(ns.PickPhrase(fake, ns.PhraseBudget(fake))
							or "|cffff8080" .. L["(nothing -- speech off, or no usable lines)"] .. "|r")
					end
				end,
			},
			limits = {
				type = "description",
				order = 25,
				name = "\n|cff888888"
					.. L["A line goes out when you click, even if the cast then fails out of range or line of sight."]
					.. "|r",
			},
		},
	}
end

-- How the prompt looks, where it sits and how it gets your attention.
local function BuildLookTab()
	return {
		type = "group",
		name = TAB.appearance,
		order = 5,
		args = {
			-- Everything on this tab is a secure attribute or a texture
			-- on a secure frame, and ApplyStyle returns at once in combat;
			-- the values are kept and flushed when the fight ends.
			combatNotice = {
				type = "description",
				order = 0.5,
				fontSize = "medium",
				hidden = function() return not InCombatLockdown() end,
				name = L["|cffffd100In combat.|r Blizzard freezes secure frames, so changes here are saved and appear once the fight ends."]
					.. "\n",
			},
			-- First on the tab, because everything under it is something
			-- you want to see while you change it, and on a live prompt
			-- most of it is invisible until somebody happens to walk past.
			test = {
				type = "execute",
				-- A button labelled "Preview" whichever thing it was about
				-- to do is a button you press twice to find out.
				name = function()
					return ns.Prompt:InTest() and L["Stop preview"] or L["Preview"]
				end,
				-- Both exits are held off while this window is open (see
				-- Refresh, where the expiry is pushed forward), so the
				-- sentence order here is the rule.
				desc = L["Show a sample entry to style the prompt by. It stays while this window is open, then twenty seconds more or until somebody real turns up."],
				order = 1,
				-- Greyed out in a fight, where ToggleTest refuses to start
				-- one: the fight may have hidden the panel or frozen its
				-- macro at somebody real. One already running can still be
				-- stopped.
				disabled = function()
					return InCombatLockdown() and not ns.Prompt:InTest()
				end,
				func = function() ns.Prompt:ToggleTest() end,
			},
			locked = {
				type = "toggle",
				name = L["Locked"],
				desc = L["Unlock to drag the prompt. It will not cast while unlocked."],
				order = 2,
				get = pGet,
				-- Its own setter, like /manners unlock: the prompt is hidden
				-- by `enabled` before `locked` is read, so unlocking while
				-- off leaves nothing on screen to drag.
				set = function(info, value)
					pSet(info, value)
					if not value and not ns.db.profile.enabled then
						ns.addon:Print(L["unlocked, but the addon is |cffff8080off|r so there is no prompt to drag -- switch it on first."])
					end
				end,
			},
			reset = {
				type = "execute",
				name = L["Reset position"],
				-- No confirmation: it is undone by dragging the prompt back
				-- or picking a preset.
				order = 3,
				func = function()
					local d, p = ns.defaults.profile.prompt, P()
					p.point, p.relPoint, p.x, p.y = d.point, d.relPoint, d.x, d.y
					restyle()
				end,
			},

			styleHeader = { type = "header", name = L["Style"], order = 10 },
			-- Where the colour goes comes first: it governs the two colour
			-- pickers under it.
			accentMode = {
				type = "select",
				name = L["Where the reason colour goes"],
				desc = L["A ring around the icon reads better than a stripe at the panel edge, which ends up competing with the icon rather than framing it."]
					.. "\n\n|cff888888"
					.. L["The framed look has no stripe at all -- it would run down the inside of its border -- so on it the stripe settings do nothing."]
					.. "|r",
				order = 11,
				values = {
					icon = L["Ring around the icon"],
					stripe = L["Stripe down the left edge"],
					both = L["Both"],
					off = L["Neither"],
				},
				get = pGet,
				set = pSet,
			},
			accentByReason = {
				type = "toggle",
				name = L["Colour it by reason"],
				-- All five reasons, in the order the queue ranks them, in
				-- the chosen palette's colours. The target is the only one
				-- with a condition: BuildQueue writes that reason only with
				-- the switch on, and never under Always offer, which reads
				-- nothing.
				desc = function()
					local colours = P().reasonPalette == "colourblind"
						and L["Pale yellow for your own target, orange for a favour owed, deep pink for somebody who asked, sky blue for your group, violet for passers-by -- the order they are offered in."]
						or L["Pale blue for your own target, amber for a favour owed, pink for somebody who asked, deeper blue for your group, grey for passers-by -- the order they are offered in."]
					return colours
						.. "\n\n|cff888888"
						.. L["The first of those appears only while |cffffd100Whoever I have targeted comes first|r is on and |cffffd100If they already have the buff|r is not Always offer."]
						.. "|r"
				end,
				order = 12,
				width = "full",
				get = pGet,
				set = pSet,
			},
			-- Which colours, for somebody the standard set fails.
			-- Greyed out only where nothing is drawn in the reason
			-- colours: the list's bars, the glow and the wash of a press
			-- take the palette whatever the accent says.
			reasonPalette = {
				type = "select",
				name = L["Reason colours"],
				-- Names no hues and counts none: Colour it by reason names
				-- them. Every reason has a colour of its own in both sets,
				-- and hunt5-options.lua holds this sentence to that.
				desc = L["The colour-blind set keeps the reasons apart for red-green colour blindness, in colours that differ in lightness too."],
				order = 12.2,
				values = {
					standard = L["Standard"],
					colourblind = L["Colour-blind friendly"],
				},
				sorting = { "standard", "colourblind" },
				disabled = function()
					local p = P()
					return not p.accentByReason and not p.showQueue
				end,
				-- Whatever a hand-edited file holds, the dropdown shows
				-- the palette the prompt is actually drawn with.
				get = function() return P().reasonPalette == "colourblind" and "colourblind" or "standard" end,
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
				-- the first. Each combination is a sentence of its own,
				-- because a list joined with ", and" is English grammar a
				-- translation cannot rearrange.
				name = function()
					local p = P()
					local mode = p.accentMode or "icon"
					local ring
					if mode == "icon" or mode == "both" then
						if not p.showIcon then
							ring = "hidden"
						elseif p.roundIcon then
							ring = "round"
						end
					end
					local stripe = (mode == "stripe" or mode == "both") and p.style == "framed"
					local text
					if ring == "hidden" and stripe then
						text = L["There is nothing left to colour: the ring is drawn behind the icon, which is switched off, and the framed look has no stripe."]
					elseif ring == "round" and stripe then
						text = L["There is nothing left to colour: rounding the icon off replaces the ring with a mask, and the framed look has no stripe."]
					elseif ring == "hidden" then
						text = L["There is nothing left to colour: the ring is drawn behind the icon, which is switched off."]
					elseif ring == "round" then
						text = L["There is nothing left to colour: rounding the icon off replaces the ring with a mask."]
					elseif stripe then
						text = L["There is nothing left to colour: the framed look has no stripe."]
					else
						-- Nothing was lost, so the notice is hidden and
						-- has nothing to say.
						return ""
					end
					return "|cffffd100" .. text .. "|r"
				end,
			},
			accentColor = {
				type = "color",
				name = L["Accent colour"],
				desc = L["Used for the ring, the stripe, or both -- whichever the setting above asks for."],
				order = 13,
				hasAlpha = true,
				disabled = function() return P().accentByReason end,
				get = pGetColor,
				set = pSetColor,
			},
			style = {
				type = "select",
				name = L["Look"],
				order = 14,
				-- Framed draws its own border out of the panel's white
				-- texture; profiles holding its old name are carried
				-- across in ClampSettings.
				values = {
					glass = L["Glass -- dark panel, soft shadow"],
					framed = L["Framed -- flat panel, thin border"],
					minimal = L["Minimal -- text only, no panel"],
				},
				get = pGet,
				set = pSet,
			},
			bgColor = {
				type = "color",
				name = L["Panel colour"],
				order = 15,
				hasAlpha = true,
				disabled = function() return P().style == "minimal" end,
				get = pGetColor,
				set = pSetColor,
			},

			-- The flash and the sound are one job, kept together so they
			-- agree about who is worth interrupting for.
			attentionHeader = { type = "header", name = L["Getting your attention"], order = 20 },
			flashStyle = {
				type = "select",
				name = L["When someone buffs you"],
				desc = L["Pulse keeps breathing until you have returned the favour or they are gone. Flash once is easy to miss if you were looking elsewhere."]
					.. "\n\n|cff888888"
					.. L["It lights the spell icon, sweeps the stripe, and with Effects on Full the panel catches the light. With none of those showing it has nothing to do."]
					.. "|r",
				order = 21,
				-- The glow lives on the icon, the sweep on the stripe and
				-- the light on arrival on the panel; with none of them this
				-- does nothing, and a live control would read as broken.
				disabled = function()
					local _, stripe = AccentCarriers()
					local noLight = P().effects == "calm" or P().style == "minimal"
					return not P().showIcon and not stripe and noLight
				end,
				values = {
					pulse = L["Pulse until dealt with"],
					once = L["Flash once"],
					off = L["Nothing"],
				},
				get = pGet,
				set = pSet,
			},
			-- How much the prompt moves to get your attention, so next to
			-- the flash.
			effects = {
				type = "select",
				name = L["Effects"],
				desc = L["Full: light crosses the panel when a buff lands, a refused buff shakes the text, and the prompt fades out after your last buff."]
					.. "\n\n"
					.. L["Calm: none of that movement. The prompt still fades in, and the glow set above still works."]
					.. "\n\n|cff888888"
					.. L["The Minimal look has no panel, so no light crosses it. In a fight, Stay quiet in combat keeps the outcome still as well."]
					.. "|r",
				order = 21.5,
				values = {
					full = L["Full"],
					calm = L["Calm -- less movement"],
				},
				sorting = { "full", "calm" },
				get = pGet,
				set = pSet,
			},
			soundEnabled = {
				type = "toggle",
				name = L["Play a sound"],
				desc = L["Play a sound when somebody new reaches the top of the queue."],
				order = 22,
				get = function() return SND().enabled end,
				set = function(_, v) SND().enabled = v end,
			},
			soundFile = {
				type = "select",
				name = L["Sound"],
				order = 23,
				disabled = function() return not SND().enabled end,
				-- HashTable maps key -> file, and AceConfig shows the
				-- value as the label, so the key is copied into both.
				values = function()
					local list = {}
					for key in pairs(LSM:HashTable("sound")) do list[key] = key end
					-- The chosen sound, even when its pack has not
					-- registered it, so the box still says what was
					-- picked rather than going blank. It plays ours
					-- until the pack is there.
					local chosen = SND().file
					if type(chosen) == "string" and not list[chosen] then
						list[chosen] = L["%s |cff808080(not loaded)|r"]:format(chosen)
					end
					return list
				end,
				get = function() return SND().file end,
				set = function(_, value)
					SND().file = value
					-- Picking a sound plays it.
					ns.Guard("sound preview", ns.PlayPromptSound, value)
				end,
			},
			soundOwedOnly = {
				-- The flash fires only for a favour owed; this lets the
				-- sound agree with it.
				type = "toggle",
				name = L["Only when somebody buffed me"],
				desc = L["Off, every new person on the prompt makes a noise -- including strangers you happen to walk past."],
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
				-- "None" is the name the sound list shows, which is a
				-- LibSharedMedia key and never translated. It goes in as
				-- an argument so a translation cannot rename it to an
				-- entry the list does not have.
				name = "|cffff8080" .. L["%s is silent. Pick a sound above."]:format("None") .. "|r",
			},

			posHeader = { type = "header", name = L["Position and size"], order = 30 },
			-- Moving the prompt otherwise means unlock, find it, drag it,
			-- lock it -- four steps and a mode you can forget you are in,
			-- because an unlocked prompt is also one that will not cast.
			posPreset = {
				type = "select",
				name = L["Put it"],
				desc = L["Three places that are already right. Dragging the prompt afterwards leaves this blank, because it is then not on one of them."],
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
			width = {
				type = "range",
				name = L["Width"],
				order = 34,
				min = 80,
				max = 500,
				step = 1,
				get = pGet,
				-- The same setter the height has: the icon is bound by the
				-- width as well.
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
				name = L["Height"],
				order = 35,
				min = 20,
				max = 120,
				step = 1,
				get = pGet,
				-- Its own setter because the icon's maximum is bound to
				-- this: ClampSettings shrinks the icon, and RepaintSoon
				-- redraws its slider.
				set = function(info, value)
					local icon = P().iconSize
					pSet(info, value)
					ns.ClampSettings()
					restyle()
					if P().iconSize ~= icon then RepaintSoon() end
				end,
			},
			scale = { type = "range", name = L["Scale"], order = 36, min = 0.5, max = 3, step = 0.05, get = pGet, set = pSet },
			alpha = { type = "range", name = L["Opacity"], order = 37, min = 0.1, max = 1, step = 0.05, isPercent = true, get = pGet, set = pSet },

			textHeader = { type = "header", name = L["Text"], order = 40 },
			showSub = {
				type = "toggle",
				name = L["Show a second line"],
				-- Worked out from the font, by the same function ApplyStyle
				-- decides it with, never a constant.
				desc = function()
					return L["Needs a prompt at least %d pixels tall at this font size."]
						:format(ns.TwoLineHeight(P().fontSize))
				end,
				order = 42,
				width = "full",
				get = pGet,
				set = pSet,
			},
			font = {
				type = "select",
				name = L["Font"],
				order = 50,
				-- Keys, not files, as in the sound list: AceConfig shows the
				-- value as the label.
				values = function()
					local list = {}
					for key in pairs(LSM:HashTable("font")) do list[key] = key end
					-- The chosen font even when unregistered, as in the sound
					-- list: koKR, zhCN and zhTW never register the default.
					local chosen = P().font
					if type(chosen) == "string" and not list[chosen] then
						list[chosen] = L["%s |cff808080(not loaded)|r"]:format(chosen)
					end
					return list
				end,
				get = pGet,
				set = pSet,
			},
			fontSize = { type = "range", name = L["Font size"], order = 51, min = 6, max = 32, step = 1, get = pGet, set = pSet },
			-- The prompt picks light or dark text for the panel colour
			-- only while this is left at its default, and the class
			-- colour on a name overrides it; both are said here so
			-- neither reads as the setting being ignored.
			fontColor = {
				type = "color",
				name = L["Text colour"],
				desc = L["Left at white, text turns dark on a light panel by itself. Other colours are used as picked, except for names while |cffffd100Colour names by class|r is on."],
				order = 52,
				hasAlpha = true,
				get = pGetColor,
				set = pSetColor,
			},
			classColor = { type = "toggle", name = L["Colour names by class"], order = 53, width = "full", get = pGet, set = pSet },

			iconHeader = { type = "header", name = L["Icon and queue"], order = 60 },
			showIcon = { type = "toggle", name = L["Show spell icon"], order = 61, get = pGet, set = pSet },
			iconSize = {
				type = "range",
				name = L["Icon size"],
				-- The icon must fit inside the panel, but the bound cannot
				-- live here: AceConfigRegistry types min and max as "number
				-- or nil" and rejects the whole options table if either is a
				-- function. ClampSettings enforces it instead.
				desc = L["Kept inside the prompt -- make it taller or wider first for a bigger icon."],
				order = 62,
				min = 12,
				max = 64,
				step = 1,
				disabled = function() return not P().showIcon end,
				get = pGet,
				set = function(info, value)
					pSet(info, value)
					-- The bound, applied (see above), as the height slider
					-- applies it.
					ns.ClampSettings()
					restyle()
					-- Repainted only when the clamp actually moved it: a
					-- mouse wheel never lets go of the slider, and a repaint
					-- every time would rebuild it under a dragging finger.
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
					-- Shown only when the icon sits on the ceiling
					-- ClampSettings enforces, bound by width and height.
					return not p.showIcon or p.iconSize < ns.IconCeiling(p)
				end,
				name = function()
					local p = P()
					local byWidth = (p.width - 60) < (p.height - 8)
					local text
					if byWidth then
						text = L["The icon is held at %d to fit a prompt %d wide."]:format(p.iconSize, p.width)
					else
						text = L["The icon is held at %d to fit a prompt %d high."]:format(p.iconSize, p.height)
					end
					return "|cffffd100" .. text .. "|r"
				end,
			},
			roundIcon = {
				type = "toggle",
				name = L["Round the icon off"],
				-- The ring is a texture behind the square icon, and the mask
				-- that rounds it goes there instead, so this switches off
				-- "Ring around the icon".
				desc = L["Masks the icon into a circle. Reads more like a portrait than a spell, so it is off by default."]
					.. "\n\n|cff888888"
					.. L["The mask replaces the ring, so move the reason colour to the stripe if you want both. The glow when somebody buffs you follows the circle."]
					.. "|r",
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
				name = L["Show the global cooldown on the icon"],
				desc = L["Sweeps the spell icon while the global cooldown runs, like your action bars, so you can see when the next press will go through."]
					.. "\n\n|cff888888"
					.. L["Not in a fight while Stay quiet in combat is on."]
					.. "|r",
				order = 63.5,
				width = "full",
				disabled = function() return not P().showIcon end,
				get = pGet,
				set = pSet,
			},
			showCount = { type = "toggle", name = L["Show how many are waiting"], order = 64, width = "full", get = pGet, set = pSet },
			showQueue = { type = "toggle", name = L["List the next few below"], order = 65, width = "full", get = pGet, set = pSet },
			queueRows = {
				type = "range",
				name = L["How many to list"],
				order = 66,
				min = 1,
				max = 5,
				step = 1,
				disabled = function() return not P().showQueue end,
				get = pGet,
				set = pSet,
			},
		},
	}
end

-- The tuning knobs: favours, timing, targeting, exact position and the
-- prompt's wording. Every control keeps its own key and get/set.
local function BuildAdvancedTab()
	return {
		type = "group",
		name = TAB.advanced,
		order = 6,
		hidden = function() return not HasClassBuffs() end,
		args = {
			owedClassBuffsOnly = {
				type = "toggle",
				name = L["Only count real class buffs"],
				desc = L["A shield, a heal-over-time or a trinket proc is not a favour owed. Leave this on unless you want every incoming aura to count."],
				order = 11,
				width = "full",
				disabled = function() return not S().owed end,
				get = sGet,
				set = sSet,
			},
			-- Every one of these is a number of seconds except the
			-- top-up threshold, which is minutes. There is no suffix
			-- field on an AceConfig range, so the unit goes in the name
			-- or it is nowhere.
			reciprocateWindow = {
				type = "range",
				name = L["Remember a buff for (seconds)"],
				-- For a passer-by with no nameplate BuildQueue lets go once
				-- the grace on the Who to buff tab runs out, which is
				-- shorter at the defaults.
				desc = L["How long a favour is remembered. Somebody the game cannot see may be let go sooner by |cffffd100Drop people who are probably gone|r, under Who to buff."],
				order = 12,
				min = 15,
				max = 600,
				step = 5,
				get = tGet,
				set = tSet,
			},
			reachableOnly = {
				type = "toggle",
				name = L["Drop people who are probably gone"],
				desc = L["Somebody who buffed you can rarely be range-checked afterwards. With this on, they count as in range for a while after their buff, then are let go."],
				order = 13,
				width = "full",
				get = fGet,
				set = fSet,
			},
			graceSeconds = {
				-- Named so it stands on its own, not only directly under the
				-- toggle above.
				type = "range",
				name = L["Let them go after (seconds)"],
				-- BuildQueue measures from the moment they buffed you, the one
				-- instant they were provably in range; nothing notices a player
				-- walking off.
				desc = L["How long somebody counts as in range after they buff you. It runs from their buff, not from when they walk off."],
				order = 14,
				min = 10,
				max = 180,
				step = 5,
				disabled = function() return not F().reachableOnly end,
				get = tGet,
				set = tSet,
			},
			keepDebts = {
				type = "toggle",
				name = L["Remember them across a reload"],
				desc = L["Keep favours owed through a reload or a disconnect. The clock keeps running meanwhile, so a favour that ran out is not brought back."]
					.. "\n\n|cff888888"
					.. L["Stored against this character, never shared between profiles. Switching it off deletes what has already been stored."]
					.. "|r",
				order = 15,
				width = "full",
				get = tGet,
				set = function(info, value)
					tSet(info, value)
					-- Off means gone, now. SaveDebts owns the stored debts,
					-- so it does the erasing too.
					ns.addon:SaveDebts()
				end,
			},

			timingHeader = { type = "header", name = L["Timing"], order = 20 },
			-- Per spell, deliberately: PickBuffFor is built on it, and it
			-- is what moves a priest off Fortitude and onto Divine Spirit
			-- on the very next scan. A right-press blocks the whole person
			-- for the same number.
			retryCooldown = {
				type = "range",
				name = L["Wait before offering the same spell again (seconds)"],
				desc = L["After you click, how long before that spell is offered to that player again. Covers casts that failed out of sight."]
					.. "\n\n|cff888888"
					.. L["Per spell, not per person: after Fortitude the next scan can still offer them Divine Spirit. Right-clicking the prompt skips the whole person for this long."]
					.. "|r",
				order = 21,
				min = 3,
				max = 60,
				step = 1,
				get = tGet,
				set = tSet,
			},
			scanInterval = {
				type = "range",
				name = L["Scan every (seconds)"],
				desc = L["Lower is more responsive and slightly heavier."],
				order = 22,
				min = 0.1,
				max = 2,
				step = 0.1,
				get = tGet,
				set = tSet,
			},

			targetingHeader = { type = "header", name = L["Targeting"], order = 30 },
			restoreTarget = {
				type = "toggle",
				name = L["Hand my target back afterwards"],
				desc = L["The prompt targets whoever it buffs, group members too. With this on, your previous target is restored right after the cast."],
				order = 31,
				width = "full",
				-- Hidden, not disabled, like the strangers toggle: nothing
				-- on this page would put a /target in a Battle Shout macro.
				hidden = NeverTargets,
				get = fGetMacro,
				set = fSetMacro,
			},
			noTargetNote = {
				type = "description",
				order = 31.5,
				hidden = function() return not NeverTargets() end,
				name = "|cff888888" .. L["Everything you can offer is cast on yourself and heard by your party, so the prompt never takes your target and has none to hand back."]
					.. "|r\n",
			},
			targetingNote = {
				type = "description",
				order = 32,
				hidden = NeverTargets,
				-- A function, so it names the command the macro is really
				-- built with, asked of the builder itself (/targetexact is
				-- probed for but deliberately not used, see TargetCommand),
				-- and follows the switch above. The strategy drops
				-- /targetlasttarget for somebody already your target,
				-- except in a fight, where the macro armed at the pull keeps
				-- it: nothing can rebuild the macro to follow them.
				--
				-- Whole sentences, so a translation can order each as its
				-- language needs. The commands and the conditional are
				-- arguments, not part of the text: they are macro syntax,
				-- and a translated /targetlasttarget or [@name] would name
				-- something the game does not have.
				name = function()
					local cmd = (ns.TargetCommand and ns.TargetCommand()) or "/target"
					local text
					if F().restoreTarget then
						text = L["The prompt runs |cffffd100%s|r, the cast, then |cffffd100%s|r, except outside a fight for somebody already your target, who stays targeted."]
							:format(cmd, "/targetlasttarget")
					else
						text = L["The prompt runs |cffffd100%s|r, then the cast, and leaves them targeted."]
							:format(cmd)
					end
					text = text .. " " .. L["A %s conditional only reaches your party or raid, so the macro targets everybody it buffs."]
						:format("[@name]")
					return "|cff888888" .. text .. "|r\n"
				end,
			},

			x = { type = "range", name = L["X offset"], order = 41, min = -2000, max = 2000, step = 1, get = pGet, set = pSet },
			y = { type = "range", name = L["Y offset"], order = 42, min = -2000, max = 2000, step = 1, get = pGet, set = pSet },

			formatHelp = {
				type = "description",
				order = 51,
				name = L["|cff888888{name}|r who   |cff888888{reason}|r why   |cff888888{count}|r how many more   |cff888888{class}|r their class   |cff888888{buff}|r the spell"]
					.. "\n"
					.. L["|cff888888{time}|r what theirs has left, on a top-up and nowhere else"]
					.. "\n"
					.. L["The second line always shows the reason."],
			},
			format = {
				type = "input",
				name = L["First line"],
				desc = L["Tokens: {name} {reason} {count} {class} {buff} {time}"],
				order = 52,
				width = "full",
				get = pGet,
				-- An empty first line is a prompt that names nobody, and the
				-- load-time repair would put the default back anyway: it
				-- snaps back here, so what the box shows is what is kept.
				set = function(info, value)
					if not ns.UsableFormat(value) then
						value = ns.defaults.profile.prompt.format
					end
					pSet(info, value)
				end,
			},
			reasonTarget = {
				type = "input",
				name = L["Wording: your target"],
				desc = L["Your target outranks everyone, including a favour owed, while that is switched on under Who to buff and the game can see they lack it."],
				order = 53,
				get = pGet,
				set = pSet,
			},
			reasonOwed = { type = "input", name = L["Wording: buffed you"], order = 54, get = pGet, set = pSet },
			reasonAsked = {
				type = "input",
				name = L["Wording: asked for it"],
				desc = L["The prompt's second line for somebody who asked for the buff in chat."],
				order = 55,
				disabled = function() return not S().asked end,
				get = pGet,
				set = pSet,
			},
			reasonGroup = { type = "input", name = L["Wording: in your group"], order = 56, get = pGet, set = pSet },
			reasonNearby = { type = "input", name = L["Wording: nearby"], order = 57, get = pGet, set = pSet },
			reasonRefresh = {
				type = "input",
				name = L["Wording: topping one up"],
				desc = L["Used instead of the four above when their buff is about to run out, which only the refresh mode offers. |cffffd100{time}|r is how long theirs has left."],
				order = 58,
				get = pGet,
				set = pSet,
			},
			reasonUnknown = {
				type = "input",
				name = L["Wording: state unknown"],
				desc = L["Used when the game will not let addons read whether they already have it."],
				order = 59,
				get = pGet,
				set = pSet,
			},
		},
	}
end

-- What this client allows, what has broken, and a bug report.
local function BuildDiagnosticsTab()
	return {
		type = "group",
		name = TAB.diagnostics,
		order = 7,
		args = {
			-- Lines printed to your own chat frame, never said aloud: the
			-- header says so, so it does not read as an addon that talks
			-- to other players.
			chatHeader = { type = "header", name = L["Messages in chat"], order = 1 },
			verbose = {
				type = "toggle",
				-- A cast that worked prints nothing unless it repaid a
				-- favour, so the label promises what it is doing, not a
				-- line per click.
				name = L["Tell me in chat what Manners is doing"],
				-- What it prints first: a cast that worked prints only
				-- "repaid", and somebody who switched it on to watch
				-- their casts took the silence for a broken switch.
				desc = L["A line when somebody buffs you, when a favour is counted as repaid, and when a click fails, is skipped, or leaves somebody owed."]
					.. "\n\n"
					.. L["Only you see these; they show whether a buff was missed or someone could not be reached."],
				order = 2,
				width = "full",
				get = function() return ns.db.profile.verbose end,
				set = function(_, v) ns.db.profile.verbose = v end,
			},
			debugClicks = {
				type = "toggle",
				name = L["Log every click (noisy)"],
				desc = L["Prints what the prompt held and what the game did, to work out why a cast failed."],
				order = 3,
				width = "full",
				get = function() return ns.db.profile.debugClicks end,
				set = function(_, v) ns.db.profile.debugClicks = v end,
			},

			capsHeader = { type = "header", name = L["What Manners can see"], order = 10 },
			diag = {
				type = "description",
				order = 11,
				fontSize = "medium",
				hidden = function() return not HasClassBuffs() end,
				name = function()
					-- The class is the client's own token, MAGE and the
					-- like; shown in the player's language where the
					-- client names it, and as the token where it does not.
					local class = ns.caps.class
					local names = _G.LOCALIZED_CLASS_NAMES_MALE
					local shown = (names and class and names[class]) or class
					local lines = { L["Class: |cffffffff%s|r"]:format(tostring(shown)) .. "\n" }
					for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
						local info = ns.BuffInfo(buff)
						-- Each field is one key with its label, so the
						-- translator sees what "yes" or "blocked" answers
						-- and can make the words agree.
						lines[#lines + 1] = ("|cffffffff%s|r  --  %s   %s"):format(
							(info and info.name) or buff.key,
							(info and info.known) and L["learned: |cff00ff00yes|r"]
								or L["learned: |cff808080no|r"],
							(info and info.readable) and L["can see who has it: |cff00ff00yes|r"]
								or L["can see who has it: |cffff8080no|r"])
						-- Manners being wrong about the game, rather than
						-- the game withholding something. "Never offer"
						-- only where no rank resolves: a missing group id
						-- (Arcane Brilliance) costs only the check of
						-- whether somebody is wearing it.
						if info and info.unresolved and #info.unresolved > 0 then
							local missing = {}
							for _, id in ipairs(info.unresolved) do missing[id] = true end
							local rankResolves = false
							for _, id in ipairs(buff.ranks) do
								if not missing[id] then rankResolves = true end
							end
							if not info.known and not rankResolves then
								lines[#lines + 1] = "|cffff4040    "
									.. L["this client has never heard of spell %s, so Manners will never offer this one. That is a mistake in Manners -- please report it."]
										:format(table.concat(info.unresolved, ", "))
									.. "|r"
							else
								lines[#lines + 1] = "|cffff4040    "
									.. L["this client doesn't know spell %s, so somebody already carrying that version may be offered this anyway. That is a mistake in Manners -- please report it."]
										:format(table.concat(info.unresolved, ", "))
									.. "|r"
							end
						end
					end
					lines[#lines + 1] = "\n|cff888888"
						.. L["Where Manners cannot see a buff, people are still offered, but some may already have it."]
						.. "|r"
					return table.concat(lines, "\n")
				end,
			},
			-- What is measuring how near a passer-by is, and how often it
			-- answers: a filter that has quietly stopped measuring looks
			-- the same as nobody being nearby. The only place it is shown.
			proximityDiag = {
				type = "description",
				order = 12,
				fontSize = "medium",
				hidden = OnlyReachesGroup,
				name = function()
					return "|cff888888"
						.. L["Passer-by distance: %s"]:format(tostring(ns.ProximitySummary()))
						.. "|r"
				end,
			},
			noDiag = {
				type = "description",
				order = 11.5,
				fontSize = "medium",
				hidden = HasClassBuffs,
				name = "|cffff8080"
					.. L["Nothing to report: this character has no buffs it can put on another player."]
					.. "|r",
			},

			-- What ns.Guard caught, on the page where somebody is looking
			-- when nothing works.
			errorsHeader = { type = "header", name = L["Errors this session"], order = 20 },
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
					-- The count, not the ring's length: the ring holds thirty.
					if #ns.errors > 5 then
						-- Two whole sentences, and the command an argument:
						-- it is what the player types, in any language.
						local total = ns.errorCount or #ns.errors
						local text
						if total > #ns.errors then
							text = L["(%d in all this session, %d kept -- |cffffd100%s|r)"]
								:format(total, #ns.errors, "/manners errors")
						else
							text = L["(%d in all this session -- |cffffd100%s|r)"]
								:format(total, "/manners errors")
						end
						lines[#lines + 1] = "|cff888888" .. text .. "|r"
					end
					return table.concat(lines, "\n")
				end,
			},
			noErrors = {
				type = "description",
				order = 21.5,
				fontSize = "medium",
				hidden = function() return #ns.errors > 0 end,
				name = L["Nothing has gone wrong this session."],
			},

			reportHeader = { type = "header", name = L["Reporting a bug"], order = 30 },
			buildNote = {
				type = "description",
				order = 31,
				fontSize = "medium",
				-- The first question on every bug report.
				name = function()
					return ("Manners |cffffffff%s|r"):format(tostring(ns.BUILD))
				end,
			},
			copyReport = {
				type = "execute",
				name = function() return reportOpen and L["Hide the report"] or L["Copy for a bug report"] end,
				desc = L["Opens a box with the build, what this client allows, the settings that matter and anything that has broken, ready to copy."],
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
				-- typed in is discarded.
				set = function() end,
			},
		},
	}
end

-- The Profiles tab: AceDBOptions' own table, with the share boxes added to it.
-- The library's strings and orders are its own; ours start at 100.
local function BuildProfilesTab()
	local t = AceDBOptions:GetOptionsTable(ns.db)
	t.order = 90
	t.args = t.args or {}
	for key, option in pairs({
		-- Two boxes rather than one that does both: a box that shows
		-- your settings and also applies whatever is typed into it
		-- is one stray keypress from replacing them.
		shareHeader = { type = "header", name = L["Share as text"], order = 100 },
		shareNote = {
			type = "description",
			order = 101,
			fontSize = "medium",
			name = L["Copy these settings as one line of text, or paste one you were given."]
				.. " "
				.. L["A paste leaves your on switch, lock, prompt position, click log and minimap button alone. It never switches on speaking, and while speaking is on, what you say and where stays yours."],
		},
		shareCopy = {
			type = "execute",
			name = function()
				return shareOpen and L["Hide the text"] or L["Show my settings as text"]
			end,
			desc = L["Shows these settings as one line of text in a box below, ready to select and copy. %s opens it too."]
				:format("|cffffd100/manners export|r"),
			order = 102,
			func = function()
				shareOpen = not shareOpen
				ns.RefreshOptionsDisplay()
			end,
		},
		shareText = {
			type = "input",
			-- On the page rather than in a tooltip: the game has no way
			-- to put text on the clipboard for the player.
			name = L["Click in the box, press Ctrl+A to select it all, then Ctrl+C to copy (Cmd on a Mac)."],
			order = 103,
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
			name = L["Paste settings to use them"],
			desc = L["Replaces the settings on this profile with the ones in the text. %s puts yours back."]
				:format("|cffffd100/manners import undo|r"),
			order = 104,
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
	}) do
		t.args[key] = option
	end
	return t
end

local function BuildOptions()
	return {
		type = "group",
		name = "Manners",
		childGroups = "tab",
		args = {
			general = BuildStartTab(),
			who = BuildWhoTab(),
			when = BuildWhenTab(),
			click = BuildSpeechTab(),
			appearance = BuildLookTab(),
			advanced = BuildAdvancedTab(),
			diagnostics = BuildDiagnosticsTab(),
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

-- The minimap button's right-click menu; the middle button throws the switch.
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

-- Picks the line for why somebody is being offered a buff.
--
-- The caller writes out all five lines, one whole sentence per reason, rather
-- than slotting a word for the reason into one sentence: "buffed you" slotted
-- into three different sentences is a word a translation has to make agree
-- with a subject it never sees.
local function ByReason(entry, owed, group, target, nearby, asked)
	local reason = entry and entry.reason
	if reason == "owed" then return owed end
	if reason == "group" then return group end
	if reason == "target" then return target end
	if reason == "asked" then return asked end
	return nearby
end

-- As the prompt says it: a group cast is "Your party" and its group spell,
-- not the one person it is aimed at and the single buff.
local function WhoIs(entry)
	return tostring(entry.display or entry.short or entry.name)
end

local function WhatBuff(entry)
	return tostring(ns.EntrySpellName and ns.EntrySpellName(entry)
		or ns.BuffName and ns.BuffName(entry.buff) or "?")
end

-- Who the prompt is armed at and who comes after them, in that order, with
-- nobody twice; the second answer is nil when no prompt is up. Read, never
-- acted on. The one on the prompt comes from the prompt itself, because in a
-- fight it stays whoever the fight found there while the queue moves on.
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

-- The entry a fight holds on the prompt, if there is one.
local function HeldInFight()
	if not InCombatLockdown() then return nil end
	local ok, showing = pcall(function()
		return ns.Prompt and ns.Prompt.Showing and ns.Prompt:Showing() or nil
	end)
	return ok and showing or nil
end

-- Whether the button is still up with a macro on it, which after /manners off
-- in a fight is all that is left of the prompt: `current` is cleared, and the
-- macro and the panel cannot be until the fight ends. Both are readable there.
local function ArmedButtonLeft()
	local ok, armed = pcall(function()
		local button = ns.Prompt and ns.Prompt.GetButton and ns.Prompt:GetButton()
		return button ~= nil and button:IsShown() and button:GetAttribute("macrotext1") ~= nil
	end)
	return ok and armed == true
end

-- Whether a prompt can appear at all right now, and the line that says so:
-- watching, then the line with its colour and whether it wraps. "On" is not
-- enough to say "watching": a class with nothing to give, nothing learned yet
-- and a setting in the way are told apart as the greeting tells them apart.
-- One answer for the tooltip and the menu's Who's next, so they agree.
--
-- A seventh answer, `heldOnly`, is true while a fight holds a prompt that a
-- snooze or the lock will take down once it ends: the one on it is still armed
-- and still worth a Skip, and nobody after them is going to be offered.
local function LauncherState()
	local class = ns.caps and ns.caps.class
	local snoozeLeft = ns.SnoozeLeft and ns.SnoozeLeft()
	local held = HeldInFight()
	if not Enabled() then
		-- Switched off in a fight leaves the panel the fight froze on screen,
		-- and a press on it still casts. "No prompt will appear" is false for
		-- as long as that lasts.
		if InCombatLockdown() and ArmedButtonLeft() then
			return false, L["Switched off -- the prompt this fight froze stays up until it ends, and a press still casts it."],
				1, 0.5, 0.5, true
		end
		return false, L["Switched off -- no prompt will appear."], 1, 0.5, 0.5
	elseif DragPanelUp() then
		-- Ahead of the snooze, as the prompt reads them: an unlocked prompt is
		-- up to be dragged and casts nothing.
		--
		-- Except in a fight, where the macro on the button is frozen and a
		-- press still casts at whoever the fight found on it: while the prompt
		-- still names them they are listed with their Skip, and once the name
		-- is cleared only the macro is left, said as /manners off says it.
		if held then
			return true, L["Unlocked, but in this fight the prompt stays as the fight found it, and a press still casts it; it can be dragged once the fight ends."],
				1, 0.82, 0, true, true
		elseif InCombatLockdown() and ArmedButtonLeft() then
			return false, L["Unlocked -- the prompt this fight froze stays up until it ends, and a press still casts it; then it can be dragged."],
				1, 0.82, 0, true
		end
		if snoozeLeft then
			return false, L["Unlocked, and snoozed until %s -- the prompt stays up to be dragged, casting nothing, until you lock it."]
				:format(ns.SnoozeEndsAt()), 1, 0.82, 0, true
		end
		return false, L["Unlocked -- the prompt is up to be dragged and casts nothing until you lock it (%s)."]
			:format("|cffffd100/manners lock|r"), 1, 0.82, 0, true
	elseif snoozeLeft and held then
		-- A snooze started in the fight: the panel stays as the fight found it,
		-- armed, and follows the snooze once it ends. Said as that, and with the
		-- held entry still listed, since a press still casts at them.
		return true, L["Snoozed until %s -- in this fight the prompt stays as the fight found it, and follows the snooze once the fight ends."]
			:format(ns.SnoozeEndsAt()), 1, 0.82, 0, true, true
	elseif snoozeLeft then
		-- The clock time and the minutes both: the time is what the player
		-- compares with a raid timer, and the minutes are what they asked for.
		return false, L["Snoozed until %s, %s from now -- no prompt until then."]
			:format(ns.SnoozeEndsAt(), ns.MinutesText(math.ceil(snoozeLeft / 60))), 1, 0.82, 0, true
	elseif class and ns.CLASSES_WITHOUT_BUFFS and ns.CLASSES_WITHOUT_BUFFS[class] then
		return false, L["Nothing to do: %s"]:format(ns.NO_CLASS_BUFFS), 1, 0.82, 0
	elseif not HasClassBuffs() then
		return false, L["Nothing to cast on this character -- /manners debug says why."], 1, 0.82, 0
	elseif not ns.ResolveBuff(true) then
		if ns.caps.anyKnown then
			return false, L["Nothing will be offered: %s."]:format(ns.NothingToCast()), 1, 0.5, 0.5, true
		end
		return false, L["Nothing learned to cast yet."], 1, 0.82, 0
	elseif not held and ns.HiddenWhileMounted and ns.HiddenWhileMounted() then
		-- The queue offers nobody while this is true, so name the mount -- but
		-- not over a prompt a fight holds, which is still up and armed. The
		-- option and its tab go in by their own keys, so a translation names
		-- the labels the window shows.
		return false, L["Kept away while you are mounted -- %s, on the %s tab."]
			:format(L["Not while mounted"], L["When"]), 1, 0.82, 0, true
	end
	return true, L["Watching for people to buff."], 0.4, 0.9, 0.4
end

-- What the launcher's tooltip says, for the minimap button, a broker display
-- and the addon compartment alike.
local function FillLauncherTooltip(tooltip)
	tooltip:AddLine("Manners")
	-- The state, said here as well as in the text, because a broker display is
	-- free to show the icon on its own.
	local watching, line, r, g, b, wrap, heldOnly = LauncherState()
	tooltip:AddLine(line, r, g, b, wrap)

	-- Who is waiting, while there is a prompt to wait on.
	if watching then
		local list, showing = WhoIsWaiting(TOOLTIP_QUEUE_ROWS + 1)
		-- Snoozed in a fight: only the one the fight holds. Nobody after them
		-- is going to be offered until the snooze ends, so neither the rows
		-- under them nor the count of favours waiting is anything to read.
		if heldOnly then list = showing and { showing } or {} end

		-- In a fight the prompt keeps whoever it had when the fight began, so
		-- "watching" alone would promise a prompt that follows the queue. Only
		-- while there is a prompt up to be held.
		if showing and InCombatLockdown() then
			tooltip:AddLine(L["Held in combat -- the prompt moves on once the fight ends."], 1, 0.82, 0, true)
		end

		-- The favours first: they are what the launcher's own text counts, so a
		-- bar reading "2 waiting" is answered by the first line of the hover.
		local waiting = heldOnly and 0 or WaitingCount()
		if waiting == 1 then
			tooltip:AddLine(L["1 person who buffed you is waiting for one back."], 0.5, 0.88, 0.5, true)
		elseif waiting > 1 then
			tooltip:AddLine(L["%d people who buffed you are waiting for one back."]:format(waiting),
				0.5, 0.88, 0.5, true)
		end
		for i, entry in ipairs(list) do
			if entry == showing then
				tooltip:AddLine(ByReason(entry,
					L["On the prompt: |cffffffff%s|r -- %s, buffed you"],
					L["On the prompt: |cffffffff%s|r -- %s, in your group"],
					L["On the prompt: |cffffffff%s|r -- %s, your target"],
					L["On the prompt: |cffffffff%s|r -- %s, nearby"],
					L["On the prompt: |cffffffff%s|r -- %s, asked for it"]
				):format(WhoIs(entry), WhatBuff(entry)), 1, 0.82, 0, true)
			elseif i <= TOOLTIP_QUEUE_ROWS + (showing and 1 or 0) then
				tooltip:AddLine(ByReason(entry,
					L["Next: |cffffffff%s|r -- %s, buffed you"],
					L["Next: |cffffffff%s|r -- %s, in your group"],
					L["Next: |cffffffff%s|r -- %s, your target"],
					L["Next: |cffffffff%s|r -- %s, nearby"],
					L["Next: |cffffffff%s|r -- %s, asked for it"]
				):format(WhoIs(entry), WhatBuff(entry)), 0.8, 0.8, 0.8, true)
			end
		end
	end

	-- Today's favours and the lifetime counts, from the ledger.
	-- Guarded like the rest of what this tooltip borrows: a count
	-- that throws must not take the lines above with it.
	if ns.Ledger then ns.Guard("ledger tooltip", ns.Ledger.AddTooltip, tooltip) end

	-- What each click will do, not what the button is for. Grey, under
	-- everything else: they are the part read once.
	tooltip:AddLine(L["Left click: options"], 0.6, 0.6, 0.6)
	if ns.Ledger then
		tooltip:AddLine(L["Shift-click: favour ledger"], 0.6, 0.6, 0.6)
	end
	-- Where there is no menu both buttons throw the switch, and one line says
	-- so rather than two saying the same thing.
	if HasLauncherMenu() then
		tooltip:AddLine(Enabled() and L["Middle click: switch it off"]
			or L["Middle click: switch it on"], 0.6, 0.6, 0.6)
		tooltip:AddLine(L["Right click: snooze, preview, who's next and more"], 0.6, 0.6, 0.6)
	else
		tooltip:AddLine(Enabled() and L["Middle or right click: switch it off"]
			or L["Middle or right click: switch it on"], 0.6, 0.6, 0.6)
	end
end

-- The switch, thrown in one press: the right-click where there is no menu,
-- and the middle button everywhere. Off is said with the way back in it,
-- because it lasts across logins and a stray wheel press can throw it.
local function ToggleEnabled(mouseButton)
	ns.db.profile.enabled = not ns.db.profile.enabled
	ns.Prompt:Refresh()
	if ns.db.profile.enabled then
		ns.addon:Print(L["enabled."])
	elseif mouseButton == "RightButton" then
		ns.addon:Print(L["switched off from the launcher -- right-click it again, or type |cffffd100/manners on|r, to switch it back."])
	else
		ns.addon:Print(L["switched off from the launcher -- middle-click it again, or type |cffffd100/manners on|r, to switch it back."])
	end
	-- The Enable checkbox and the launcher's text do not re-read the profile
	-- on their own.
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
-- and the same repaint after it, which moves the panel on only where the fight
-- allows. Said in chat every time, since skipping somebody further down the
-- list changes nothing on screen -- and for the one on the prompt in a fight,
-- that a press still casts at them.
local function SkipFromMenu(entry)
	ns.BlockPerson(entry.name)
	-- A group cast is skipped whole, as a right-press on it is.
	if ns.SkipGroupCast then ns.SkipGroupCast(entry) end
	local showing = ns.Prompt.Showing and ns.Prompt:Showing()
	local onPrompt = showing and showing.name == entry.name
	if onPrompt then ns.Prompt:StopAttention() end
	-- Inside a sentence a group cast is "your party", not the panel's title.
	local who = entry.groupCast and entry.groupCast.label or WhoIs(entry)
	if onPrompt and InCombatLockdown() then
		ns.addon:Print(L["skipping |cffffffff%s|r for now -- but the prompt cannot move off them in a fight, and a press still casts at them."]
			:format(who))
	else
		ns.addon:Print(L["skipping |cffffffff%s|r for now."]:format(who))
	end
	ns.Guard("skip repaint", ns.Prompt.Refresh, ns.Prompt)
end

-- Never, from the menu: the never-offer list, as a shift-right-press on the
-- prompt puts them there. With the same block first, as that press writes it:
-- the list alone reaches the panel only after the hold and the fuse have run,
-- and the block takes them off it at once.
local function NeverFromMenu(entry)
	ns.BlockPerson(entry.name)
	-- Only the one it is aimed at is listed; the rest of a group cast are
	-- skipped, as a shift-right-press on it does.
	if ns.SkipGroupCast then ns.SkipGroupCast(entry) end
	local showing = ns.Prompt.Showing and ns.Prompt:Showing()
	if showing and showing.name == entry.name then ns.Prompt:StopAttention() end
	-- Says the fight's warning itself and repaints the prompt, for every route
	-- onto the list alike, so nothing is said here as well.
	ns.PutOnNeverList(entry.name)
end

-- One greyed line in place of the list.
local function Nobody(parent, text)
	local none = parent:CreateButton(text)
	if none.SetEnabled then none:SetEnabled(false) end
end

-- The people the prompt would offer, and only while it would offer anybody:
-- the same test the tooltip makes. Except the one a fight holds on the prompt
-- after a snooze or an unlock in it: a press still casts at them until the
-- fight ends, so they are listed with their Skip, and nobody after them is.
local function FillWhoIsNext(parent)
	local watching, line, _, _, _, _, heldOnly = LauncherState()
	if not Enabled() then
		Nobody(parent, L["Nobody -- Manners is switched off"])
		return
	end
	-- The lock before the snooze, as LauncherState reads them, except over the
	-- one a fight still holds.
	if DragPanelUp() and not heldOnly then
		Nobody(parent, line)
		return
	end
	local ends = ns.SnoozeEndsAt and ns.SnoozeEndsAt()
	if ends and not heldOnly then
		Nobody(parent, L["Nobody -- snoozed until %s"]:format(ends))
		return
	end
	if not watching then
		Nobody(parent, line)
		return
	end
	local list, showing
	if heldOnly then
		showing = HeldInFight()
		list = showing and { showing } or {}
	else
		list, showing = WhoIsWaiting(MENU_QUEUE_ROWS)
	end
	if #list == 0 then
		-- Favours can be live while the queue offers none of them (skipped,
		-- dead, out of reach), and the launcher's text counts them.
		local waiting = WaitingCount()
		if waiting == 1 then
			Nobody(parent, L["Nobody can be offered right now -- 1 favour is waiting"])
		elseif waiting > 1 then
			Nobody(parent, L["Nobody can be offered right now -- %d favours are waiting"]:format(waiting))
		else
			Nobody(parent, L["Nobody is waiting"])
		end
		return
	end
	for _, entry in ipairs(list) do
		local label
		if entry == showing then
			label = ByReason(entry,
				L["%s -- %s (buffed you), on the prompt"],
				L["%s -- %s (in your group), on the prompt"],
				L["%s -- %s (your target), on the prompt"],
				L["%s -- %s (nearby), on the prompt"],
				L["%s -- %s (asked for it), on the prompt"])
		else
			label = ByReason(entry,
				L["%s -- %s (buffed you)"],
				L["%s -- %s (in your group)"],
				L["%s -- %s (your target)"],
				L["%s -- %s (nearby)"],
				L["%s -- %s (asked for it)"])
		end
		local person = parent:CreateButton(label:format(WhoIs(entry), WhatBuff(entry)))
		person:CreateButton(L["Skip for now"], Act(function() SkipFromMenu(entry) end))
		-- Somebody already on the list is in the queue only because they are
		-- owed, and for them the same act lets the favour go. The one a fight
		-- holds on the prompt may owe nothing, so owed is asked as the queue
		-- asks it.
		local listed = ns.IsNeverOffered and ns.IsNeverOffered(entry.name)
		local ok, owedNow = pcall(function()
			local debt = ns.owed and ns.owed[entry.name]
			return ns.db.profile.sources.owed and debt ~= nil and ns.DebtExpiry(debt) > GetTime()
		end)
		owedNow = ok and owedNow == true
		if listed and not owedNow then
			Nobody(person, L["On your never-offer list"])
		else
			person:CreateButton(listed and L["Let this favour go"] or L["Never offer"],
				Act(function() NeverFromMenu(entry) end))
		end
	end
	-- Unlocked or snoozed in a fight: the one the fight holds, then a line
	-- saying why nobody comes after them -- the lock first, as it is read.
	if heldOnly and DragPanelUp() then
		Nobody(parent, L["Nobody else -- the prompt is unlocked"])
	elseif heldOnly and ends then
		Nobody(parent, L["Nobody else -- snoozed until %s"]:format(ends))
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
	Check(parent, L["Keep the prompt dim and still in combat"], function() return ns.db.profile.prompt.hideInCombat end,
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

-- Profile names in alphabetical order in any language: the client's
-- strcmputf8i folds every script's capitals, where string.lower folds only
-- A-Z.
local function NameBefore(a, b)
	local fold = _G.strcmputf8i
	if type(fold) == "function" then
		local ok, order = pcall(fold, a, b)
		if ok and type(order) == "number" and order ~= 0 then return order < 0 end
	end
	local la, lb = a:lower(), b:lower()
	if la ~= lb then return la < lb end
	return a < b
end

-- AceDB's profiles, when the database can list them and there is a second one
-- to switch to. Switching changes where the prompt sits and what it is armed
-- with, so it waits for the fight to end like the lock does.
local function AddProfiles(root, fight)
	local db = ns.db
	if not (db.GetProfiles and db.GetCurrentProfile and db.SetProfile) then return end
	local names = {}
	local ok = pcall(function()
		local list = db:GetProfiles()
		for _, name in pairs(list or {}) do
			if type(name) == "string" then names[#names + 1] = name end
		end
	end)
	table.sort(names, NameBefore)
	if not ok or #names < 2 then return end
	local parent = root:CreateButton(L["Profiles"])
	for _, name in ipairs(names) do
		local choice = Radio(parent, FightLabel(name, fight), function() return db:GetCurrentProfile() == name end,
			ActOutOfCombat(function()
				if db:GetCurrentProfile() ~= name then db:SetProfile(name) end
			end))
		if fight then HeldForFight(choice) end
	end
end

-- In four groups: the state (on, snoozed), the people (who is next, the
-- ledger), the prompt and how it talks, and the options window.
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

	Divider(root)
	FillWhoIsNext(root:CreateButton(L["Who's next"]))
	if ns.Ledger then
		root:CreateButton(L["Open the ledger"], Act(function() ns.Ledger.Show() end))
	end

	Divider(root)
	-- Greyed out in a fight as it is on the options page: ToggleTest refuses to
	-- start one there. One already running can still be stopped.
	local inTest = ns.Prompt:InTest()
	-- Each entry does only what its label says: the menu is built once, and a
	-- preview can time out under it while /manners test is a toggle.
	local preview
	if inTest then
		preview = root:CreateButton(L["End the preview"], Act(function()
			if ns.Prompt:InTest() then
				ns.addon:HandleSlash("test")
			else
				ns.addon:Print(L["the preview has already ended."])
			end
		end))
	else
		preview = root:CreateButton(FightLabel(L["Preview the prompt"], fight), Act(function()
			if not ns.Prompt:InTest() then ns.addon:HandleSlash("test") end
		end))
	end
	if fight and not inTest then HeldForFight(preview) end
	FillPromptMenu(root:CreateButton(L["Prompt"]), fight)
	Check(root, L["Tell me in chat what the addon is doing"], function() return ns.db.profile.verbose end,
		Act(function() ns.addon:HandleSlash("verbose") end))
	AddProfiles(root, fight)

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
		ToggleEnabled(mouseButton)
		return
	end
	-- Shift with the left button opens the ledger; the plain click stays the
	-- options window.
	if mouseButton ~= "RightButton" and ns.Ledger
		and IsShiftKeyDown and IsShiftKeyDown() then
		ns.Guard("ledger window", ns.Ledger.Toggle)
		return
	end
	-- The menu where the client has one; the switch on its own
	-- where it does not, which is what a right-click always did.
	if mouseButton == "RightButton" and OpenLauncherMenu(owner, later) then return end
	if mouseButton == "RightButton" then
		ToggleEnabled(mouseButton)
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
-- addon, which this client has, and the one launcher that is always there.
--
-- Registered here rather than through the toc's AddonCompartmentFunc fields,
-- which name global functions, and directly rather than through LibDBIcon's
-- copy, which only adds a button it is also showing on the minimap.
local function RegisterCompartment()
	local frame = _G.AddonCompartmentFrame
	if compartment or type(frame) ~= "table" or type(frame.RegisterAddon) ~= "function" then
		return false
	end
	compartment = {
		text = BrokerText(),
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
	options.args.profiles = BuildProfilesTab()
	-- Kept so a control can be read back afterwards. A dropdown that lists the
	-- right entries under the wrong labels renders perfectly and is invisible
	-- to every other check we have.
	ns.optionsTable = options

	AceConfig:RegisterOptionsTable(ADDON, options)
	blizCategory, blizCategoryID = AceConfigDialog:AddToBlizOptions(ADDON, "Manners")
	-- The bug-report box shuts with the Settings page (OpenOptions shuts it
	-- for the standalone window). OnHide, because the box's own `hidden` is
	-- only asked while the page is being drawn.
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
-- LibDataBroker fires its own change callback when a field on a data object is
-- assigned, so every display showing this launcher repaints from here. Called
-- through ns.RepaintOptions, and by Core whenever the favour count changes.
function ns.RefreshBrokerText()
	local text = BrokerText()
	-- The compartment builds its menu from the registered tables each time it
	-- opens, so a plain assignment is all it takes.
	if compartment then compartment.text = text end
	if not broker then return end
	-- Only when it has actually changed: assigning wakes every display showing
	-- it, and this is reached at both ends of every fight.
	if broker.text ~= text then broker.text = text end
	-- The tint the same way, one channel at a time: LibDBIcon repaints the
	-- icon on each of the three.
	local r, g, b = IconTint()
	if broker.iconR ~= r then broker.iconR = r end
	if broker.iconG ~= g then broker.iconG = g end
	if broker.iconB ~= b then broker.iconB = b end
end

-- Repaint whatever is on screen from the values as they stand now: AceConfig
-- only asks a `hidden` or a `name` function while it is drawing, and some
-- answers (combat, errors, open boxes) change under it. Optional at both ends,
-- because failing to repaint must never take down the handler it is called from.
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
-- Asked rather than subscribed to, so a missed notification can never leave a
-- preview running; every answer defaults to "no", so the preview times out.
function ns.OptionsOpen()
	local frames = AceConfigDialog and AceConfigDialog.OpenFrames
	if type(frames) == "table" and frames[ADDON] ~= nil then return true end

	-- The other route in: the Settings window's canvas. IsVisible, not IsShown:
	-- shutting the Settings window hides the window, not the canvas, whose own
	-- shown flag stays set until another page takes its place. AceConfigDialog
	-- asks its own Settings pages the same way.
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
	-- The boxes start shut when the window opens, but are left alone when it
	-- is already up, where somebody may be copying out of one.
	if not ns.OptionsOpen() then reportOpen = false end
	if not ns.OptionsOpen() then shareOpen = false end

	-- The standalone dialog, first and by default. Settings.OpenToCategory
	-- does not raise when it fails to find the category: on this client it
	-- opens the Settings window at whatever page it was last on and returns
	-- cleanly, so only the route that either works or errors can go first.
	local ok = pcall(AceConfigDialog.Open, AceConfigDialog, ADDON)
	if ok then return end

	-- A last resort, by the ID AddToBlizOptions returned: the canvas frame's
	-- own GetID answers 0, which is no category at all.
	if Settings and Settings.OpenToCategory and blizCategoryID ~= nil then
		pcall(Settings.OpenToCategory, blizCategoryID)
	end
end

-- Open the options on the Profiles tab, where the share boxes are, with the
-- box of this profile's settings showing when that is what was asked for.
-- For /manners export and a bare /manners import. Answers whether there is a
-- page to send them to at all; SelectGroup is asked for because a library
-- without it still opens the window, just not on this tab.
function ns.ShowShareBox(which)
	ns.OpenOptions()
	if which == "export" then shareOpen = true end
	if AceConfigDialog.SelectGroup then
		pcall(AceConfigDialog.SelectGroup, AceConfigDialog, ADDON, "profiles")
	end
	ns.RefreshOptionsDisplay()
	return true
end
