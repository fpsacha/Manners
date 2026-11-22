-- Manners -- options: the Advanced group (the tuning knobs the options window
-- draws on When to offer and Look) and the per-page reset.

local _, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local rescan, restyleAndMacro, P, S, F = Page.rescan, Page.restyleAndMacro, Page.P, Page.S, Page.F
local pGet, pSet, sGet, sSet = Page.pGet, Page.pSet, Page.sGet, Page.sSet
local fGet, fSet, fGetMacro, fSetMacro = Page.fGet, Page.fSet, Page.fGetMacro, Page.fSetMacro
local tGet, tSet, HasClassBuffs, HasPrompt = Page.tGet, Page.tSet, Page.HasClassBuffs, Page.HasPrompt

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

---------------------------------------------------------------------------
-- the per-page reset
--
-- "Reset this page" in the options window's footer puts back the
-- page in view: every field on that page's list, including rows this class
-- does not show unless the list's `keep` says otherwise, then the hooks those
-- fields' own setters run. Never the master switch, the key, where the prompt
-- sits or its lock, the never-offer list or your lines: what somebody placed,
-- wrote or listed by hand is not a tuning knob. The settings the old Advanced
-- tab's reset put back are all here, on When to offer and Look, where they
-- now sit.
---------------------------------------------------------------------------

local function RefreshBroker()
	if ns.RefreshBrokerText then ns.Guard("broker text", ns.RefreshBrokerText) end
end

-- By page id, each field as "section.field" in the profile, and `after`, the
-- hooks. Pages without a list (Start here, Profiles, Diagnostics) have no
-- reset button.
Page.RESET = {
	who = {
		"buff.choice", "buff.skip", "buff.tanksOnly", "buff.meOnly", "buff.kingsFirst", "buff.order", "filters.relevantOnly",
		"buff.tanksOutside", "buff.keptBack", "buff.forClass",
		"sources.owed", "sources.group", "sources.pets", "sources.share", "sources.strangers", "sources.asked",
		"sources.courtesyRefresh", "sources.courtesyPortals", "sources.courtesyHealthstones", "sources.courtesySummons",
		"sources.res", "sources.resStrangers",
		"sources.cures", "sources.curesStrangers", "sources.curesSelf", "filters.cureSeconds", "prompt.cureFight",
		"filters.proximity", "filters.restingOnly", "groupBuffs.use", "groupBuffs.atLeast", "filters.skipRaidGroups",
		"buff.leaveBlessed",
		"buff.detectPassers",
		"buff.skipCasters",
		"buff.spareFishBowl", "buff.neverFishBowl", "buff.spareCamp", "buff.tanksMe", "buff.notMeInside",
		"buff.optIn",
		"priority.target", "priority.friends", "priority.readyCheck", "priority.revived",
		after = function()
			restyleAndMacro()
			-- The fight buttons the page draws, as their own switches refresh them.
			if ns.CureFight then ns.Guard("cure in a fight", ns.CureFight.Refresh, ns.CureFight) end
			if ns.MendPet then ns.Guard("mend pet", ns.MendPet.Refresh, ns.MendPet) end
			-- The bags counted again for what is switched on now (Scrolls, the picks).
			if ns.ForgetScrolls then ns.ForgetScrolls() end
			-- An own buff's pick shows at once, as its own control does it.
			ns.Prompt:Refresh()
			-- The favour count follows People who buff me.
			RefreshBroker()
		end,
	},
	-- The never-offer list is kept: every name on it was put there by hand.
	skip = {
		"filters.skipPvP", "filters.skipFighting", "filters.skipSameClass", "filters.requireInRange", "filters.minLevel",
		"filters.skipGuilds",
		"filters.skipNearbyClasses",
		-- How long a right-click skips (Who to skip > After a right-click).
		"timing.skipSeconds", "timing.ownSkipMinutes",
		after = function() rescan() end,
	},
	when = {
		"filters.whenBuffed", "filters.refreshUnder", "filters.refreshRaid",
		"filters.verifiedOnly",
		"timing.reciprocateWindow", "sources.owedClassBuffsOnly", "filters.reachableOnly",
		"timing.graceSeconds", "timing.keepDebts", "timing.retryCooldown", "timing.scanInterval",
		"filters.restoreTarget",
		"filters.repayCovered",
		after = function()
			-- keepDebts can only go from off to on here, which deletes
			-- nothing; SaveDebts is still what its setter runs, so the two
			-- ways of switching it on leave the file the same.
			ns.addon:SaveDebts()
			rescan()
			-- Both hold off in combat and catch up when the fight ends, so
			-- this never touches the secure button mid-fight.
			restyleAndMacro()
		end,
	},
	-- Your lines and the line set are kept. So is the rest of the list for a
	-- class with nothing to give, whose page holds the /thank alone (Say.lua,
	-- THANKS_ONLY): the line said with a cast is one it never says, and on a
	-- shared profile it is an alt's.
	click = {
		"prompt.thankEmote", "prompt.thankEmoteToken", "prompt.thankEmoteMore", "speech.enabled", "speech.channel",
		"speech.onlyWhenReturning",
		-- First name only, and how often your own lines are said; the lines
		-- left out are kept, as your lines are.
		"speech.firstNameOnly", "speech.mixedShare",
		"prompt.thankWhisper",
		"prompt.thankDelay",
		"prompt.thankUnseen",
		"prompt.thankAsk",
		-- Asking for a buff (What I say): every class can ask, so these are
		-- put back for all of them, a rogue's page included.
		"sources.ask", "ask.channel", "ask.line", "ask.inTowns", "ask.own",
		keep = function(path)
			if path == "sources.ask" or path:find("^ask%.") then return false end
			return path ~= "prompt.thankEmote" and path ~= "prompt.thankEmoteToken" and not HasClassBuffs()
			and path ~= "prompt.thankWhisper" and path ~= "prompt.thankDelay" and path ~= "prompt.thankEmoteMore"
			and path ~= "prompt.thankUnseen" and path ~= "prompt.thankAsk"
		end,
		after = function()
			ns.Prompt:InvalidateMacro()
			-- Asking changes what the prompt offers, and the favour count.
			ns.Prompt:Refresh()
			RefreshBroker()
		end,
	},
	-- Where the prompt sits and its lock are kept.
	appearance = {
		"prompt.scale", "prompt.alpha", "prompt.width", "prompt.height", "prompt.style",
		"prompt.bgColor", "prompt.accentByReason", "prompt.reasonPalette", "prompt.accentColor",
		"prompt.accentMode", "prompt.peekOnChange", "prompt.flashStyle", "prompt.effects",
		"prompt.font", "prompt.fontSize", "prompt.fontColor", "prompt.classColor", "prompt.showSub",
		"prompt.showGuild",
		"prompt.format", "prompt.reasonTarget", "prompt.reasonOwed", "prompt.reasonAsked",
		"prompt.reasonSelf", "prompt.reasonGroup", "prompt.reasonNearby", "prompt.reasonRefresh",
		"prompt.reasonUnknown", "prompt.showIcon", "prompt.iconSize", "prompt.roundIcon",
		"prompt.iconFrame", "prompt.gryphons", "prompt.classicArt", "prompt.keycap", "prompt.textShadow",
		"prompt.showCooldown", "prompt.showCount", "prompt.showQueue", "prompt.queueRows",
		"prompt.tooltip", "prompt.tooltipPosition",
		"prompt.clickRows", "sound.enabled", "sound.file", "sound.owedOnly",
		"supplies.size",
		-- Use my class's look on each character, and each class's pick.
		"prompt.classLook", "prompt.classStyles",
		after = function()
			-- The profile's own look kept while the switch was on goes too, or
			-- the repair would put it back over Glass (Looks.RepairClassLook).
			ns.db.profile.prompt.profileStyle = nil
			-- The icon back inside the prompt's size, as the size sliders do.
			ns.ClampSettings()
			restyleAndMacro()
		end,
	},
}

-- My own buffs: what Manners reminds you of for yourself, when, and how early.
-- The picks and the lists of what to leave out go back too: Who to buff's reset
-- no longer reaches them. Your own spells (db.char) are kept.
Page.RESET.self = {
	"sources.self", "ownBuffs.pick", "ownBuffs.leave", "ownBuffs.inCities", "ownBuffs.itemsInDungeons", "ownBuffs.itemsLast",
	"ownBuffs.shoutAlone", "ownBuffs.foodOrder", "ownBuffs.dampenAlone", "ownBuffs.amplifyAlone", "ownBuffs.imbueFirst",
	"ownBuffs.restedEarly", "ownBuffs.scrolls", "ownBuffs.elixirKeep", "ownBuffs.apart", "ownBuffs.holdMoving",
	"filters.selfTopUp", "filters.selfLead",
	after = function()
		rescan()
		restyleAndMacro()
		-- The bags counted again for what is switched on now (Scrolls, the picks).
		if ns.ForgetScrolls then ns.ForgetScrolls() end
		-- The consumables button follows its switch.
		if ns.Supplies then ns.Guard("consumables button", ns.Supplies.Refresh, ns.Supplies) end
		-- An own buff's pick shows at once, as its own control does it.
		ns.Prompt:Refresh()
		RefreshBroker()
	end,
}

-- My pet (HunterPet.lua): care and the moments, all on again. Mend Pet in a
-- fight is also on In a fight (the same field, drawn twice on purpose).
Page.RESET.pet = {
	"beast.call", "beast.revive", "beast.feed", "beast.mend", "beast.bond", "beast.fightMend",
	"beast.all", "beast.leaveFood", "beast.growl", "beast.training", "beast.pace", "beast.answer", "beast.words", "beast.memory", "beast.praise", "beast.comfort", "beast.welcome", "beast.sorry", "beast.hello", "beast.morning", "beast.road", "beast.play", "beast.share", "beast.family", "beast.missed", "beast.saved", "beast.grown", "beast.anniversary",
	after = function()
		restyleAndMacro()
		if ns.MendPet then ns.Guard("mend pet", ns.MendPet.Refresh, ns.MendPet) end
		ns.Prompt:Refresh()
	end,
}

-- Quiet times: where and when Manners holds back or says nothing. The rules
-- for a party or a raid are a class's: the spoken line is one a class with
-- nothing to give never says, and on a shared profile it is an alt's, so that
-- stays; Don't thank anybody in a party or a raid is the /thank's and resets.
Page.RESET.quiet = {
	"filters.quietInTowns", "filters.quietInInstances", "filters.quietTargets", "filters.quietInTownsWhere",
	"filters.quietShortInTowns", "filters.quietShortMinutes", "filters.hideMounted", "filters.manaFloor", "filters.manaFloorKeeps",
	"battle.team", "battle.speak", "battle.thank", "battle.items",
	"speech.quietInParty", "speech.quietInRaid", "prompt.thankNotInGroup",
	keep = function(path) return (path == "speech.quietInParty" or path == "speech.quietInRaid") and not HasClassBuffs() end,
	after = function()
		rescan()
		restyleAndMacro()
		ns.Guard("quiet repaint", ns.Prompt.Refresh, ns.Prompt)
	end,
}

-- In a fight: the prompt's fight behaviour and the buttons made for a fight.
-- The cure in a fight is also on Who to buff's list (the same field, drawn
-- twice on purpose), so that page's reset puts it back too.
Page.RESET.fight = {
	"prompt.hideInFight", "prompt.fightRota", "prompt.fightKeySpells", "prompt.fightKeyOn", "prompt.hideInCombat", "prompt.dimInCombat",
	"prompt.breakFree", "beast.fightMend", "prompt.cureFight", "prompt.fightButtons",
	after = function()
		restyleAndMacro()
		if ns.BreakFree then ns.Guard("break free", ns.BreakFree.Refresh, ns.BreakFree) end
		if ns.MendPet then ns.Guard("mend pet", ns.MendPet.Refresh, ns.MendPet) end
		if ns.CureFight then ns.Guard("cure in a fight", ns.CureFight.Refresh, ns.CureFight) end
		if ns.FightKey then ns.Guard("fight key", ns.FightKey.Refresh, ns.FightKey) end
		ns.Prompt:Refresh()
	end,
}

-- Not a page of the window. The old dialog, which the window falls back to
-- (Register.lua), draws the reset on one tab, Advanced, so that tab has a
-- list: the old reset's seventeen, which are the controls on it -- When to
-- offer's favours, timings and targeting and Look's wording -- less the exact
-- position beside them. Their setters' hooks are When to offer's, whose
-- restyle covers the wording.
Page.RESET.advanced = {
	"sources.owedClassBuffsOnly", "timing.reciprocateWindow", "filters.reachableOnly",
	"timing.graceSeconds", "timing.keepDebts", "timing.retryCooldown", "timing.skipSeconds", "timing.ownSkipMinutes", "timing.scanInterval",
	"filters.restoreTarget", "prompt.format", "prompt.reasonTarget", "prompt.reasonOwed",
	"prompt.reasonAsked", "prompt.reasonSelf", "prompt.reasonGroup", "prompt.reasonNearby",
	"prompt.reasonRefresh", "prompt.reasonUnknown",
	"filters.repayCovered",
	after = Page.RESET.when.after,
}

-- The page the reset's question was asked on. The box stays up while the
-- page under it can change -- the minimap button or a slash command opening
-- another, another tab clicked in the old dialog -- and YES is a yes to the
-- page that was asked about.
local askedFor

local function Copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = Copy(v) end
	return out
end

-- One field back to its default. A set (buff.skip, ownBuffs.pick, the raid
-- groups) is wiped in place and refilled, so anything holding the table sees
-- it change; a colour gets a fresh copy, so the profile never holds the
-- defaults' own table for a picker to write into.
local function ResetField(path)
	local section, name = path:match("^(%w+)%.(%w+)$")
	local default = ns.defaults.profile[section][name]
	local into = ns.db.profile[section]
	local current = into[name]
	if type(default) == "table" and type(current) == "table" and default[1] == nil then
		wipe(current)
		for k, v in pairs(default) do current[k] = Copy(v) end
	else
		into[name] = Copy(default)
	end
end

-- Put page `pageId` back to its defaults, with no question asked (the button's
-- own confirm has asked it), and repaint. Answers false for a page with no
-- list.
function Page.ResetPage(pageId)
	local list = Page.RESET[pageId]
	if not list then return false end
	return ns.Guard("reset page", function()
		for _, path in ipairs(list) do
			if not (list.keep and list.keep(path)) then ResetField(path) end
		end
		if list.after then list.after() end
		ns.RefreshOptionsDisplay()
	end)
end

-- The tuning knobs: favours, timing, targeting, exact position and the
-- prompt's wording. Every control keeps its own key and get/set, so moving it
-- here left its profile field where it was. No longer a page of its own: the
-- options window draws these on When to offer and Look, and the intro, the
-- combat notice and the reset in its frame.
function Page.BuildAdvancedTab()
	-- The group is there for every class with a prompt; the knobs about other
	-- people -- favours, their reason lines, handing a target back -- are
	-- hidden from a class that only ever offers you your own buff (a hunter's
	-- aspect), where they would be switches that change nothing.
	local function NoOthers() return not HasClassBuffs() end

	return {
		type = "group",
		-- Named for the old dialog, which the window falls back to if it
		-- cannot be shown.
		name = L["Advanced"],
		order = 6,
		-- The same rule as When to offer: a hunter's own prompt has a first
		-- line, a reason, a place and timings like anybody's. What is about
		-- other people is hidden inside (NoOthers).
		hidden = function() return not HasPrompt() end,
		args = {
			advIntro = {
				type = "description",
				order = 0.5,
				name = L["The defaults suit most players; change these only if something bothers you."] .. "\n",
			},
			advCombatNotice = {
				type = "description",
				order = 0.6,
				hidden = function() return not InCombatLockdown() end,
				name = "|cffffd100" .. L["In combat: targeting changes apply once the fight ends."] .. "|r\n",
			},
			-- The footer's reset, for whichever page is open; hidden on a
			-- page with nothing to put back.
			resetAdvanced = {
				type = "execute",
				name = L["Reset this page"],
				order = 0.7,
				hidden = function() return Page.RESET[ns.OptionsTab()] == nil end,
				-- Asked as it is pressed, which is when the page is noted.
				confirm = function()
					askedFor = ns.OptionsTab()
					return true
				end,
				confirmText = L["Put every setting on this page back to its default? Where the prompt sits, the lines you wrote and the never-offer list are kept."],
				-- Run with no question asked, it puts back the page in view.
				func = function()
					local pageId = askedFor or ns.OptionsTab()
					askedFor = nil
					Page.ResetPage(pageId)
				end,
			},

			favoursHeader = { type = "header", name = L["Buffing back"], order = 10, hidden = NoOthers },
			owedClassBuffsOnly = {
				type = "toggle",
				name = L["Only class buffs count as favours"],
				desc = L["Only class buffs such as Fortitude count as a favour to return."]
					.. " " .. L["The same goes for /thank people who buff me."],
				order = 11,
				width = "full",
				hidden = NoOthers,
				-- Live while either switch it filters is: the favour scan reads
				-- the casters it lets through for both (Favours.lua, watching).
				disabled = function() return not (S().owed or P().thankEmote) end,
				get = sGet,
				set = sSet,
			},
			-- Somebody who buffed you and already wears everything you could
			-- give them, with time to spare: off, nothing is offered and the
			-- favour is let go (Queue.lua, LetGoCovered); on, what they hold is
			-- refreshed to return it, as it was before a priest asked.
			repayCovered = {
				type = "toggle",
				name = L["Buff them back even when they already have my buff"],
				desc = L["Off, somebody who buffs you and already has everything you could give them, with time to spare, is offered nothing, whoever cast it: a thank-you is enough, and the favour is let go. A buff they are missing, or one about to run out, is still offered back."]
					.. "\n\n" .. L["On, the buff they already have is offered again to return the favour."],
				order = 11.5,
				width = "full",
				hidden = NoOthers,
				disabled = function() return not S().owed end,
				get = fGet,
				set = fSet,
			},
			-- Most of these are a number of seconds. The window's box shows the
			-- unit itself (Layout.lua, units), and the label no longer says it;
			-- the dialog the window falls back to has no unit field, so each
			-- tooltip starts with the unit.
			reciprocateWindow = {
				type = "range",
				name = L["How long a favour stays on offer"],
				desc = L["In seconds."] .. " " .. L["How long someone who buffed you stays on offer."],
				order = 12,
				width = "double",
				hidden = NoOthers,
				min = 15,
				max = 600,
				step = 5,
				get = tGet,
				set = tSet,
			},
			reachableOnly = {
				type = "toggle",
				name = L["Let them go sooner if they have probably left"],
				desc = L["Manners can rarely tell whether somebody who buffed you is still in range, so they are let go after the time below."],
				order = 13,
				width = "full",
				hidden = NoOthers,
				get = fGet,
				set = fSet,
			},
			graceSeconds = {
				-- BuildQueue measures from the moment they buffed you, the one
				-- instant they were provably in range; nothing notices a player
				-- walking off.
				type = "range",
				name = L["Let them go after"],
				desc = L["In seconds."] .. " " .. L["Counted from their buff, not from when they walked off."],
				order = 14,
				min = 10,
				max = 180,
				step = 5,
				width = "double",
				hidden = NoOthers,
				disabled = function() return not F().reachableOnly end,
				get = tGet,
				set = tSet,
			},
			keepDebts = {
				type = "toggle",
				name = L["Keep favours through a /reload"],
				desc = L["Turning it off forgets what is already kept."],
				order = 15,
				width = "full",
				hidden = NoOthers,
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
			-- on the very next scan. A right-click skips for its own length
			-- (skipSeconds, below).
			retryCooldown = {
				type = "range",
				name = L["Wait before trying the same spell on someone again"],
				desc = function()
					return L["In seconds."] .. " " .. L["In case the cast failed. How long a right-click skips someone is set on %s."]:format(Page.TabOf("advanced.skipSeconds") or "")
				end,
				order = 21,
				width = "double",
				min = 3,
				max = 60,
				step = 1,
				get = tGet,
				set = tSet,
			},
			skipSeconds = {
				type = "range",
				name = L["A right-click skips someone for"],
				desc = L["In seconds: how long right-clicking the prompt, or Skip for now in its menu, leaves that person, or your own buff, alone."],
				order = 21.5,
				width = "double",
				min = 3,
				max = 1800,
				step = 1,
				get = tGet,
				set = tSet,
			},
			ownSkipMinutes = {
				type = "range",
				name = L["A right-click skips my own buffs for"],
				desc = L["In minutes: how long right-clicking one of your own buffs, on the prompt or the consumables button, or Skip for now in the menu, leaves it alone. Skipping a food skips every food in your bags, since any of them gives Well Fed. At 0 it follows A right-click skips someone for."],
				order = 21.6,
				width = "double",
				min = 0,
				max = 240,
				step = 1,
				bigStep = 5,
				get = tGet,
				set = tSet,
			},
			scanInterval = {
				type = "range",
				name = L["Look for people every"],
				desc = L["In seconds."] .. " " .. L["Lower reacts faster and uses a little more CPU."],
				order = 22,
				width = "double",
				min = 0.1,
				max = 2,
				step = 0.1,
				get = tGet,
				set = tSet,
			},

			targetingHeader = { type = "header", name = L["Targeting"], order = 30, hidden = NoOthers },
			restoreTarget = {
				type = "toggle",
				name = L["Hand my target back afterwards"],
				desc = L["The prompt has to target someone to buff them; this puts your old target back."],
				order = 31,
				width = "full",
				-- Hidden, not disabled, like the strangers toggle: nothing
				-- on this page would put a /target in a Battle Shout macro.
				-- A press on yourself always hands your target back
				-- (STRATEGIES.self, Prompt/Macro.lua), so for a class whose
				-- only prompt is "You" this would be a switch that changes
				-- nothing.
				hidden = function() return NeverTargets() or NoOthers() end,
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

			exactPosHeader = { type = "header", name = L["Exact position"], order = 40 },
			x = { type = "range", name = L["Left / right"], order = 41, min = -2000, max = 2000, step = 1, get = pGet, set = pSet },
			y = { type = "range", name = L["Up / down"], order = 42, min = -2000, max = 2000, step = 1, get = pGet, set = pSet },

			wordingHeader = { type = "header", name = L["Prompt wording"], order = 50 },
			-- Above the box it explains, so it is read first.
			formatHelp = {
				type = "description",
				order = 51,
				name = L["Placeholders: {name} their name, {reason} why, {count} how many others are waiting, {class} their class, {buff} the spell, {time} time left on their buff (top-ups only)."]
					.. "\n|cff888888"
					.. L["The second line always shows the reason."]
					.. "|r\n",
			},
			format = {
				type = "input",
				name = L["First line"],
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
			-- The second line, in the order the queue ranks people.
			reasonTarget = {
				type = "input",
				name = L["For my target"],
				desc = L["Shown when your target is first in line."],
				order = 53,
				hidden = NoOthers,
				get = pGet,
				set = pSet,
			},
			reasonOwed = { type = "input", name = L["For someone who buffed me"], order = 54, hidden = NoOthers, get = pGet, set = pSet },
			reasonAsked = {
				type = "input",
				name = L["For someone who asked in chat"],
				desc = L["Shown for someone who asked in chat."],
				order = 55,
				hidden = NoOthers,
				get = pGet,
				set = pSet,
			},
			-- Between the two it sits between in the queue.
			reasonSelf = {
				type = "input",
				name = L["For my own buff"],
				desc = L["Shown when the prompt offers you your own buff."],
				order = 55.5,
				get = pGet,
				set = pSet,
			},
			reasonGroup = { type = "input", name = L["For my group"], order = 56, hidden = NoOthers, get = pGet, set = pSet },
			reasonNearby = { type = "input", name = L["For a passer-by"], order = 57, hidden = NoOthers, get = pGet, set = pSet },
			reasonRefresh = {
				type = "input",
				name = L["For a top-up"],
				desc = L["{time} is how long theirs has left."],
				order = 58,
				get = pGet,
				set = pSet,
			},
			reasonUnknown = {
				type = "input",
				name = L["When the game hides their buffs"],
				desc = L["Shown when the game hides whether they already have it."],
				order = 59,
				-- Your own buffs are never offered on a reading the game
				-- withholds, so this line is only ever about somebody else.
				hidden = NoOthers,
				get = pGet,
				set = pSet,
			},
		},
	}
end
