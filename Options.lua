-- Manners -- options table, Blizzard settings panel, minimap button.

local ADDON, ns = ...

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
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

local pGet, pSet, pGetColor, pSetColor = bind(P, restyle)
local sGet, sSet = bind(S)
local fGet, fSet = bind(F)
-- The armed macro is only rebuilt when the candidate changes, so a filter that
-- alters what the macro says -- rather than who is on the prompt -- has to say
-- so. restoreTarget is the only one.
local fGetMacro, fSetMacro = bind(F, remacro)
local tGet, tSet = bind(T, rescan)
local sndGet, sndSet = bind(SND)
local spGet, spSet = bind(SP, remacro)
local bGet, bSet = bind(B, restyleAndMacro)

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

local function AutoExplanation()
	local auto = ns.CLASS_AUTO[ns.caps.class]
	if auto then
		local mana = ns.FindBuff(ns.caps.class, auto.mana)
		local other = ns.FindBuff(ns.caps.class, auto.other)
		return ("Automatic gives |cffffffff%s|r to anyone with a mana bar and |cffffffff%s|r to everyone else.")
			:format(ns.BuffName(mana), ns.BuffName(other))
	end
	return "Automatic uses the first buff you have learned."
end

---------------------------------------------------------------------------
-- options table
---------------------------------------------------------------------------

local function BuildOptions()
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
					makeMacro = {
						type = "execute",
						name = "Create the macro",
						desc = "Adds a macro called Manners containing /click MannersPrompt LeftButton 1. "
							.. "Drag it onto an action bar and it fires the prompt.",
						order = 4,
						hidden = function() return not HasClassBuffs() end,
						func = function() ns.CreateClickMacro() end,
					},

					soundHeader = { type = "header", name = "Sound", order = 10 },
					enabledSound = {
						type = "toggle",
						name = "Play a sound",
						desc = "Play a sound when somebody new reaches the top of the queue.",
						order = 11,
						get = function() return SND().enabled end,
						set = function(_, v) SND().enabled = v end,
					},
					file = {
						type = "select",
						name = "Sound",
						order = 12,
						disabled = function() return not SND().enabled end,
						-- HashTable maps key -> file, and AceConfig shows the
						-- value as the label, so this listed one entry whose
						-- name was "1".
						values = function()
							local list = {}
							for key in pairs(LSM:HashTable("sound")) do list[key] = key end
							return list
						end,
						get = sndGet,
						set = function(info, value)
							SND()[info[#info]] = value
							-- Picking a sound you cannot hear is how the
							-- silent default went unnoticed for so long.
							ns.Guard("sound preview", ns.PlayPromptSound, value)
						end,
					},
					noSound = {
						type = "description",
						order = 12.5,
						hidden = function() return not SND().enabled or SND().file ~= "None" end,
						name = "|cffff8080None is silent. Pick a sound above.|r",
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

					diagHeader = { type = "header", name = "Diagnostics", order = 30 },
					verbose = {
						type = "toggle",
						name = "Announce every buff it sees",
						desc = "Prints a line to chat whenever somebody buffs you. Use it to tell "
							.. "'the buff was never noticed' apart from 'it was noticed but they could "
							.. "not be reached' -- two very different problems.",
						order = 30.5,
						width = "full",
						get = function() return ns.db.profile.verbose end,
						set = function(_, v) ns.db.profile.verbose = v end,
					},
					debugClicks = {
						type = "toggle",
						name = "Log every click to chat",
						desc = "Prints what the button was actually holding at the moment you clicked it, "
							.. "and what the game did with it. Noisy; for working out why a cast did not "
							.. "happen.",
						order = 30.6,
						width = "full",
						get = function() return ns.db.profile.debugClicks end,
						set = function(_, v) ns.db.profile.debugClicks = v end,
					},
					diag = {
						type = "description",
						order = 31,
						fontSize = "medium",
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
				},
			},

			---------------------------------------------------------------
			who = {
				type = "group",
				name = "Who to buff",
				order = 2,
				hidden = function() return not HasClassBuffs() end,
				args = {
					choice = {
						type = "select",
						name = "Buff to cast",
						order = 1,
						values = BuffChoices,
						get = bGet,
						set = bSet,
					},
					autoNote = {
						type = "description",
						order = 2,
						name = function() return AutoExplanation() end,
					},

					sourcesHeader = { type = "header", name = "Sources", order = 10 },
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
						get = sGet,
						set = sSet,
					},

					filtersHeader = { type = "header", name = "Filters", order = 20 },
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
						type = "toggle",
						name = "Only players in range",
						desc = "People whose range cannot be determined are still offered.",
						order = 22,
						width = "full",
						get = fGet,
						set = fSet,
					},
					restoreTarget = {
						type = "toggle",
						name = "Hand my target back afterwards",
						desc = "Buffing somebody means targeting them first -- conditional targeting does "
							.. "not work on this client. With this on, your previous target is restored "
							.. "immediately after the cast.",
						order = 22.5,
						width = "full",
						get = fGetMacro,
						set = fSetMacro,
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
						type = "range",
						name = "...after this long",
						desc = "How long a favour stays offerable once we can no longer see the player.",
						order = 24,
						min = 10,
						max = 180,
						step = 5,
						disabled = function() return not F().reachableOnly end,
						get = tGet,
						set = tSet,
					},
					whenBuffed = {
						type = "select",
						name = "If they already have the buff",
						desc = "Reading whether somebody has a buff needs the game's permission. See the "
							.. "diagnostics on the General tab for which of your buffs qualify.",
						order = 23,
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
						name = "Top up when less than this is left",
						desc = "Only offer a refresh once their remaining time drops below this. "
							.. "Somebody whose buff timer cannot be read is left alone.",
						order = 24,
						min = 1,
						max = 60,
						step = 1,
						hidden = function() return F().whenBuffed ~= "refresh" end,
						get = fGet,
						set = fSet,
					},
					alwaysNote = {
						type = "description",
						order = 25,
						hidden = function() return F().whenBuffed ~= "always" end,
						name = "|cffff8080Everyone nearby will be offered constantly, including people "
							.. "whose buff has barely ticked down. Expect to be spending mana.|r",
					},
					minLevel = {
						type = "range",
						name = "Minimum level",
						order = 26,
						min = 1,
						max = 60,
						step = 1,
						get = fGet,
						set = fSet,
					},

					timingHeader = { type = "header", name = "Timing", order = 30 },
					reciprocateWindow = {
						type = "range",
						name = "Remember a buff for",
						order = 31,
						min = 15,
						max = 600,
						step = 5,
						get = tGet,
						set = tSet,
					},
					retryCooldown = {
						type = "range",
						name = "Wait before re-offering",
						desc = "After you click, how long before the same player can come back up. "
							.. "Covers casts that failed out of sight.",
						order = 32,
						min = 3,
						max = 60,
						step = 1,
						get = tGet,
						set = tSet,
					},
					scanInterval = {
						type = "range",
						name = "Scan every",
						desc = "Lower is more responsive and slightly heavier.",
						order = 33,
						min = 0.1,
						max = 2,
						step = 0.1,
						get = tGet,
						set = tSet,
					},
				},
			},

			---------------------------------------------------------------
			speech = {
				type = "group",
				name = "Speech",
				order = 3,
				hidden = function() return not HasClassBuffs() end,
				args = {
					intro = {
						type = "description",
						order = 1,
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
						order = 2,
						width = "full",
						get = spGet,
						set = spSet,
					},
					channel = {
						type = "select",
						name = "Channel",
						order = 3,
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
						order = 4,
						width = "full",
						disabled = function() return not SP().enabled end,
						get = spGet,
						set = spSet,
					},

					phrasesHeader = { type = "header", name = "Phrases", order = 10 },
					preset = {
						type = "select",
						name = "Load a set",
						desc = "Replaces the lines below. Edit them afterwards as much as you like.",
						order = 10.5,
						disabled = function() return not SP().enabled end,
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
						order = 11,
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
						order = 12,
						multiline = 10,
						width = "full",
						disabled = function() return not SP().enabled end,
						get = spGet,
						set = spSet,
					},
					roll = {
						type = "execute",
						name = "Roll a few",
						order = 13,
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
						order = 14,
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
				order = 4,
				args = {
					locked = {
						type = "toggle",
						name = "Locked",
						desc = "Unlock to drag the prompt. It will not cast while unlocked.",
						order = 1,
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
					test = {
						type = "execute",
						name = "Preview",
						desc = "Show a sample entry so you can style the prompt without waiting for one.",
						order = 2,
						func = function() ns.Prompt:ToggleTest() end,
					},
					reset = {
						type = "execute",
						name = "Reset position",
						order = 3,
						confirm = true,
						func = function()
							local d, p = ns.defaults.profile.prompt, P()
							p.point, p.relPoint, p.x, p.y = d.point, d.relPoint, d.x, d.y
							restyle()
						end,
					},

					styleHeader = { type = "header", name = "Style", order = 10 },
					style = {
						type = "select",
						name = "Look",
						order = 11,
						values = {
							glass = "Glass -- dark panel, accent stripe",
							blizzard = "Blizzard -- default UI border",
							minimal = "Minimal -- text only, no panel",
						},
						get = pGet,
						set = pSet,
					},
					accentByReason = {
						type = "toggle",
						name = "Colour the stripe by reason",
						desc = "Amber when returning a favour, blue for your group, grey for passers-by.",
						order = 12,
						width = "full",
						get = pGet,
						set = pSet,
					},
					accentColor = {
						type = "color",
						name = "Stripe colour",
						order = 13,
						hasAlpha = true,
						disabled = function() return P().accentByReason end,
						get = pGetColor,
						set = pSetColor,
					},
					bgColor = {
						type = "color",
						name = "Panel colour",
						order = 14,
						hasAlpha = true,
						disabled = function() return P().style == "minimal" end,
						get = pGetColor,
						set = pSetColor,
					},
					accentMode = {
						type = "select",
						name = "Where the reason colour goes",
						desc = "A ring around the icon reads better than a stripe at the panel edge, "
							.. "which ends up competing with the icon rather than framing it.",
						order = 15,
						values = {
							icon = "Ring around the icon",
							stripe = "Stripe down the left edge",
							both = "Both",
							off = "Neither",
						},
						get = pGet,
						set = pSet,
					},
					flashStyle = {
						type = "select",
						name = "When someone buffs you",
						desc = "Pulse keeps breathing until you have returned the favour or they are gone. "
							.. "Flash once is easy to miss if you were looking elsewhere.",
						order = 16,
						values = {
							pulse = "Pulse until dealt with",
							once = "Flash once",
							off = "Nothing",
						},
						get = pGet,
						set = pSet,
					},

					posHeader = { type = "header", name = "Position and size", order = 20 },
					x = { type = "range", name = "X offset", order = 21, min = -2000, max = 2000, step = 1, get = pGet, set = pSet },
					y = { type = "range", name = "Y offset", order = 22, min = -2000, max = 2000, step = 1, get = pGet, set = pSet },
					width = { type = "range", name = "Width", order = 23, min = 80, max = 500, step = 1, get = pGet, set = pSet },
					height = { type = "range", name = "Height", order = 24, min = 20, max = 120, step = 1, get = pGet, set = pSet },
					scale = { type = "range", name = "Scale", order = 25, min = 0.5, max = 3, step = 0.05, get = pGet, set = pSet },
					alpha = { type = "range", name = "Opacity", order = 26, min = 0.1, max = 1, step = 0.05, isPercent = true, get = pGet, set = pSet },
					hideInCombat = {
						type = "toggle",
						name = "Hide in combat",
						desc = "The prompt cannot retarget in combat anyway, since Blizzard freezes secure "
							.. "frames. Leave this off to keep the last target clickable.",
						order = 27,
						width = "full",
						get = pGet,
						set = pSet,
					},

					textHeader = { type = "header", name = "Text", order = 30 },
					format = {
						type = "input",
						name = "First line",
						desc = "Tokens: {name} {reason} {count} {class} {buff} {time}",
						order = 31,
						width = "full",
						get = pGet,
						set = pSet,
					},
					showSub = {
						type = "toggle",
						name = "Show a second line",
						desc = "Needs a prompt at least 34 pixels tall.",
						order = 32,
						width = "full",
						get = pGet,
						set = pSet,
					},
					formatHelp = {
						type = "description",
						order = 33,
						name = "|cff888888{name}|r who   |cff888888{reason}|r why   |cff888888{count}|r how many more   "
							.. "|cff888888{class}|r their class   |cff888888{buff}|r the spell\n"
							.. "|cff888888{time}|r what theirs has left, on a top-up and nowhere else\n"
							.. "The second line always shows the reason.",
					},
					reasonTarget = {
						type = "input",
						name = "Wording: your target",
						desc = "Somebody you targeted yourself outranks everyone else, including a "
							.. "favour owed -- but only when the game lets us see they are missing it.",
						order = 33.5,
						get = pGet,
						set = pSet,
					},
					reasonOwed = { type = "input", name = "Wording: buffed you", order = 34, get = pGet, set = pSet },
					reasonGroup = { type = "input", name = "Wording: in your group", order = 35, get = pGet, set = pSet },
					reasonNearby = { type = "input", name = "Wording: nearby", order = 36, get = pGet, set = pSet },
					reasonRefresh = {
						type = "input",
						name = "Wording: topping one up",
						desc = "Used instead of the four above when they already have the buff and"
							.. " it is about to run out, which only the refresh mode offers."
							.. " |cffffd100{time}|r is how long theirs has left.",
						order = 36.5,
						get = pGet,
						set = pSet,
					},
					reasonUnknown = {
						type = "input",
						name = "Wording: state unknown",
						desc = "Used when the game will not let addons read whether they already have it.",
						order = 37,
						get = pGet,
						set = pSet,
					},
					font = {
						type = "select",
						name = "Font",
						order = 38,
						values = function() return LSM:HashTable("font") end,
						get = pGet,
						set = pSet,
					},
					fontSize = { type = "range", name = "Font size", order = 39, min = 6, max = 32, step = 1, get = pGet, set = pSet },
					fontColor = { type = "color", name = "Text colour", order = 40, hasAlpha = true, get = pGetColor, set = pSetColor },
					classColor = { type = "toggle", name = "Colour names by class", order = 41, width = "full", get = pGet, set = pSet },

					iconHeader = { type = "header", name = "Icon and queue", order = 50 },
					showIcon = { type = "toggle", name = "Show spell icon", order = 51, get = pGet, set = pSet },
					iconSize = {
						type = "range",
						name = "Icon size",
						order = 52,
						min = 12,
						max = 64,
						step = 1,
						disabled = function() return not P().showIcon end,
						get = pGet,
						set = pSet,
					},
					roundIcon = {
						type = "toggle",
						name = "Round the icon off",
						desc = "Masks the icon into a circle. Reads more like a portrait than a spell, "
							.. "so it is off by default.",
						order = 53,
						width = "full",
						disabled = function() return not P().showIcon end,
						get = pGet,
						set = pSet,
					},
					showCount = { type = "toggle", name = "Show how many are waiting", order = 54, width = "full", get = pGet, set = pSet },
					showQueue = { type = "toggle", name = "List the next few below", order = 55, width = "full", get = pGet, set = pSet },
					queueRows = {
						type = "range",
						name = "How many to list",
						order = 56,
						min = 1,
						max = 5,
						step = 1,
						disabled = function() return not P().showQueue end,
						get = pGet,
						set = pSet,
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

-- LibDBIcon keeps the table it was handed at Register, and AceDB hands out a
-- different one per profile -- so after a switch the checkbox and the button
-- read different tables, and a drag saves the position into the old one.
-- Refresh does the whole job: re-points the table, repositions from the new
-- minimapPos, and shows or hides to match the new hide.
function ns.RefreshMinimapButton()
	if not (LDBIcon and LDBIcon.Refresh and LDBIcon:IsRegistered(ADDON)) then return end
	LDBIcon:Refresh(ADDON, ns.db.profile.minimap)
end

function ns.OpenOptions()
	-- The standalone dialog is the dependable path. Blizzard's own panel moved
	-- between Settings APIs, so we only try it when the handle looks usable.
	if Settings and Settings.OpenToCategory and blizCategory and blizCategory.GetID then
		if pcall(Settings.OpenToCategory, blizCategory:GetID()) then return end
	end
	AceConfigDialog:Open(ADDON)
end
