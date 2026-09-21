-- Manners -- options table, Blizzard settings panel, minimap button.

local ADDON, ns = ...

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

local ICON = "Interface\\Icons\\Spell_Holy_MagicalSentry"

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

-- The spell's name, with the one thing about it that changes who it is offered
-- to. A priest reading "Divine Spirit" has no way to know from the page that a
-- warrior will never see it.
local function BuffLabel(buff)
	local label = ns.BuffName(buff)
	if buff.manaOnly then label = label .. " |cff808080(mana users only)|r" end
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
	if ns.EXCLUSIVE_BUFFS[ns.caps.class] then
		return ("Your blessings replace one another, so Automatic gives one and stops:"
			.. " the first of %s that suits them. Anybody already carrying one of yours is"
			.. " left alone rather than handed a different one."):format(list)
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
			-- switches over something that is not consulted.
			hidden = function() return B().choice ~= "auto" end,
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
-- else -- a warrior's Battle Shout, which is cast on yourself and heard by the
-- group.
--
-- BuildQueue rejects a party-only buff for anybody outside the group before the
-- strangers toggle is ever consulted, so for these classes that toggle is a
-- switch with nothing behind it. Computed rather than listed by class: it
-- follows the per-spell switches and a pin, so a warrior who learns something
-- else gets the control back on its own.
local function OnlyReachesGroup()
	local castable = ns.CastableBuffs()
	if #castable == 0 then return false end
	for _, buff in ipairs(castable) do
		if not buff.partyOnly then return false end
	end
	return true
end

-- Whether the copy-for-a-bug-report box is open.
--
-- A file local rather than a setting: it is a state of the window rather than
-- of the profile, and one that has no business surviving the window being shut.
local reportOpen = false

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

	for _, buff in ipairs(ns.GetClassBuffs(caps.class) or {}) do
		local info = ns.BuffInfo(buff)
		lines[#lines + 1] = ("  %-12s known=%s readable=%s off=%s"):format(
			buff.key,
			tostring(info and info.known),
			tostring(info and info.readable),
			tostring(B().skip[buff.key] == true))
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

	local scan = ns.auraScan
	lines[#lines + 1] = ("own buffs: %s read, baseline %s, primed=%s, doubt=%s"):format(
		tostring(scan.read), tostring(scan.held), tostring(scan.primed), tostring(scan.doubt))

	if #ns.errors == 0 then
		lines[#lines + 1] = "errors: none this session"
	else
		lines[#lines + 1] = ("errors: %d this session, last five:"):format(#ns.errors)
		for i = math.max(1, #ns.errors - 4), #ns.errors do
			local e = ns.errors[i]
			lines[#lines + 1] = ("  %s %s -- %s"):format(
				tostring(e.at), tostring(e.where), tostring(e.err))
		end
	end

	return table.concat(lines, "\n")
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
				get = bGet,
				set = bSet,
			},
			autoNote = {
				type = "description",
				order = 3,
				hidden = function() return B().choice ~= "auto" end,
				name = function() return AutoExplanation() end,
			},
			-- Below the per-spell switches, because when it is red the thing it
			-- is about is the dropdown two controls up rather than the switches.
			pinNote = {
				type = "description",
				order = 5,
				fontSize = "medium",
				hidden = function() return B().choice == "auto" end,
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
					return s.owed or s.group or s.strangers
				end,
				name = "|cffff8080Nothing below is switched on, so the prompt will never"
					.. " appear.|r",
			},
			owed = {
				type = "toggle",
				name = "People who buffed me",
				desc = "Watch for buffs cast on you and offer to return them. "
					.. "Works on strangers who are not in your group.",
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
				desc = "Offer passers-by who are missing the buff. "
					.. "Seen through nameplates, your target and your mouseover.",
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
				desc = "Targeting somebody is the plainest way of saying you mean them, so they"
					.. " outrank a favour owed -- but only when the game lets us read that they"
					.. " are genuinely missing the buff. Switched off, a target is ranked by why"
					.. " they are on the list like anybody else.\n\n"
					.. "|cff888888Mouseover is deliberately left out: at a scan every four tenths"
					.. " of a second the prompt would flicker as the cursor crossed the"
					.. " screen.|r",
				order = 16,
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
				desc = "How long a favour stays offerable once we can no longer see the player.",
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
							.. "Game Menu > Key Bindings > Manners.\n",
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

					miscHeader = { type = "header", name = "Minimap", order = 20 },
					minimap = {
						type = "toggle",
						name = "Show minimap button",
						order = 21,
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
						name = "Print a line in my chat when someone buffs me",
						desc = "Only you see it -- nothing is ever said to anybody else from here. "
							.. "Use it to tell 'the buff was never noticed' apart from 'it was "
							.. "noticed but they could not be reached' -- two very different "
							.. "problems.",
						order = 31,
						width = "full",
						get = function() return ns.db.profile.verbose end,
						set = function(_, v) ns.db.profile.verbose = v end,
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
						desc = "Reading whether somebody has a buff needs the game's permission. See "
							.. "the Diagnostics tab for which of your buffs qualify.",
						order = 2,
						width = "full",
						values = {
							skip = "Leave them alone",
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
							.. "Somebody whose buff timer cannot be read is left alone.",
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
						name = "|cffff8080Everyone nearby will be offered constantly, including people "
							.. "whose buff has barely ticked down. Expect to be spending mana.|r",
					},

					timingHeader = { type = "header", name = "Timing", order = 10 },
					-- Every one of these is a number of seconds except the
					-- top-up threshold, which is minutes. There is no suffix
					-- field on an AceConfig range, so the unit goes in the name
					-- or it is nowhere.
					reciprocateWindow = {
						type = "range",
						name = "Remember a buff for (seconds)",
						desc = "How long after somebody buffs you they stay on the prompt.",
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
					retryCooldown = {
						type = "range",
						name = "Wait before re-offering (seconds)",
						desc = "After you click, how long before the same player can come back up. "
							.. "Covers casts that failed out of sight.",
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
					targetingHeader = { type = "header", name = "Targeting", order = 1 },
					restoreTarget = {
						type = "toggle",
						name = "Hand my target back afterwards",
						desc = "Buffing somebody means targeting them first -- conditional targeting does "
							.. "not work on this client. With this on, your previous target is restored "
							.. "immediately after the cast.",
						order = 2,
						width = "full",
						get = fGetMacro,
						set = fSetMacro,
					},
					targetingNote = {
						type = "description",
						order = 3,
						name = "|cff888888The prompt runs |cffffd100/target|r, then the cast, then"
							.. " |cffffd100/targetlasttarget|r. Conditional forms -- [@name], [@focus],"
							.. " [@mouseover] -- do not resolve on this client at all, which is why the"
							.. " macro takes your target rather than aiming past it.|r\n",
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
						get = function() return SP().presetChoice or "roleplay" end,
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
							.. "|cffffd100Roll a few|r shows what would really go out.|r",
					},
					phrases = {
						type = "input",
						name = "",
						order = 23,
						multiline = 10,
						width = "full",
						disabled = function() return not SP().enabled end,
						get = spGet,
						set = spSet,
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
						desc = "Show a sample entry so you can style the prompt without waiting"
							.. " for one. It stays for as long as this window is open.",
						order = 1,
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
							.. "|cff888888The Blizzard look has no stripe at all, so on it the stripe "
							.. "settings do nothing.|r",
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
						desc = "Amber when returning a favour, blue for your group, grey for passers-by.",
						order = 12,
						width = "full",
						get = pGet,
						set = pSet,
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
						values = {
							glass = "Glass -- dark panel, accent stripe",
							blizzard = "Blizzard -- default UI border",
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
							.. "Flash once is easy to miss if you were looking elsewhere.",
						order = 21,
						values = {
							pulse = "Pulse until dealt with",
							once = "Flash once",
							off = "Nothing",
						},
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
					width = { type = "range", name = "Width", order = 34, min = 80, max = 500, step = 1, get = pGet, set = pSet },
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
						-- longer accept.
						set = function(info, value)
							pSet(info, value)
							ns.ClampSettings()
							restyle()
						end,
					},
					scale = { type = "range", name = "Scale", order = 36, min = 0.5, max = 3, step = 0.05, get = pGet, set = pSet },
					alpha = { type = "range", name = "Opacity", order = 37, min = 0.1, max = 1, step = 0.05, isPercent = true, get = pGet, set = pSet },
					hideInCombat = {
						type = "toggle",
						name = "Hide in combat",
						desc = "The prompt cannot retarget in combat anyway, since Blizzard freezes secure "
							.. "frames. Leave this off to keep the last target clickable.",
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
						set = pSet,
					},
					showSub = {
						type = "toggle",
						name = "Show a second line",
						desc = "Needs a prompt at least 34 pixels tall.",
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
						values = function() return LSM:HashTable("font") end,
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
						desc = "Kept inside the prompt's height -- raise that first for a bigger icon.",
						order = 62,
						min = 12,
						max = 64,
						step = 1,
						disabled = function() return not P().showIcon end,
						get = pGet,
						set = function(info, value)
							pSet(info, value)
							-- Re-read it: ClampSettings may have just cut it down,
							-- and the slider should show what was actually kept.
							AceConfigRegistry:NotifyChange(ADDON)
						end,
					},
					iconSizeCapped = {
						type = "description",
						order = 62.5,
						hidden = function()
							local p = P()
							-- Shown only when the icon is sitting on the ceiling
							-- the height imposes, which is the case where the
							-- slider will not go any further and nothing else on
							-- the page explains why.
							return not p.showIcon or p.iconSize < p.height - 8
						end,
						name = function()
							return ("|cffffd100The icon is held at %d to fit a prompt %d high.|r")
								:format(P().iconSize, P().height)
						end,
					},
					roundIcon = {
						type = "toggle",
						name = "Round the icon off",
						desc = "Masks the icon into a circle. Reads more like a portrait than a spell, "
							.. "so it is off by default.",
						order = 63,
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
							if #ns.errors > 5 then
								lines[#lines + 1] = ("|cff888888(%d in all this session --"
									.. " |cffffd100/manners errors|r)|r"):format(#ns.errors)
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

local blizCategory

function ns.SetupOptions()
	local options = BuildOptions()
	options.args.profiles = AceDBOptions:GetOptionsTable(ns.db)
	options.args.profiles.order = 90
	-- Kept so a control can be read back afterwards. A dropdown that lists the
	-- right entries under the wrong labels renders perfectly and is invisible
	-- to every other check we have.
	ns.optionsTable = options

	AceConfig:RegisterOptionsTable(ADDON, options)
	blizCategory = AceConfigDialog:AddToBlizOptions(ADDON, "Manners")

	if LDB then
		local dataObject = LDB:NewDataObject(ADDON, {
			type = "launcher",
			text = "Manners",
			icon = ICON,
			OnClick = function(_, mouseButton)
				if mouseButton == "RightButton" then
					ns.db.profile.enabled = not ns.db.profile.enabled
					ns.Prompt:Refresh()
					ns.addon:Print(ns.db.profile.enabled and "enabled." or "disabled.")
				else
					ns.OpenOptions()
				end
			end,
			OnTooltipShow = function(tooltip)
				tooltip:AddLine("Manners")
				tooltip:AddLine("Left click: options", 0.8, 0.8, 0.8)
				tooltip:AddLine("Right click: enable or disable", 0.8, 0.8, 0.8)
			end,
		})
		if LDBIcon and dataObject then
			LDBIcon:Register(ADDON, dataObject, ns.db.profile.minimap)
		end
	end
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
-- library version without the table, or a Blizzard panel handle that is a
-- category object rather than a frame, has to mean the preview times out as it
-- always did rather than throwing inside the scan.
function ns.OptionsOpen()
	local frames = AceConfigDialog and AceConfigDialog.OpenFrames
	if type(frames) == "table" and frames[ADDON] ~= nil then return true end

	-- The other route in. AddToBlizOptions hands back a frame on some clients
	-- and a category object on others, so this is asked with a net under it.
	if blizCategory then
		local ok, shown = pcall(function() return blizCategory:IsShown() end)
		if ok and shown then return true end
	end
	return false
end

function ns.OpenOptions()
	-- The standalone dialog is the dependable path. Blizzard's own panel moved
	-- between Settings APIs, so we only try it when the handle looks usable.
	if Settings and Settings.OpenToCategory and blizCategory and blizCategory.GetID then
		if pcall(Settings.OpenToCategory, blizCategory:GetID()) then return end
	end
	AceConfigDialog:Open(ADDON)
end
