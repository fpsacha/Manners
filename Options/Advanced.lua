-- Manners -- options: the Advanced tab.

local _, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local rescan, restyleAndMacro, S, F = Page.rescan, Page.restyleAndMacro, Page.S, Page.F
local pGet, pSet, sGet, sSet = Page.pGet, Page.pSet, Page.sGet, Page.sSet
local fGet, fSet, fGetMacro, fSetMacro = Page.fGet, Page.fSet, Page.fGetMacro, Page.fSetMacro
local tGet, tSet, HasClassBuffs, HasPrompt = Page.tGet, Page.tSet, Page.HasClassBuffs, Page.HasPrompt
local TAB = Page.TAB

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

-- The tuning knobs: favours, timing, targeting, exact position and the
-- prompt's wording. Every control keeps its own key and get/set, so moving it
-- here left its profile field where it was.
function Page.BuildAdvancedTab()
	-- The tab is there for every class with a prompt; the knobs about other
	-- people -- favours, their reason lines, handing a target back -- are
	-- hidden from a class that only ever offers you your own buff (a hunter's
	-- aspect), where they would be switches that change nothing.
	local function NoOthers() return not HasClassBuffs() end

	-- What "Put these back to default" puts back: every field this tab
	-- writes, by its section in the profile. Nothing else on the page, and
	-- not where the prompt sits: that is a place somebody dragged it to, not
	-- a tuning knob, and Where it sits (Look, Start here) puts it back.
	local resetFields = {
		{ "sources", "owedClassBuffsOnly" },
		{ "timing", "reciprocateWindow" },
		{ "filters", "reachableOnly" },
		{ "timing", "graceSeconds" },
		{ "timing", "keepDebts" },
		{ "timing", "retryCooldown" },
		{ "timing", "scanInterval" },
		{ "filters", "restoreTarget" },
		{ "prompt", "format" },
		{ "prompt", "reasonTarget" },
		{ "prompt", "reasonOwed" },
		{ "prompt", "reasonAsked" },
		{ "prompt", "reasonSelf" },
		{ "prompt", "reasonGroup" },
		{ "prompt", "reasonNearby" },
		{ "prompt", "reasonRefresh" },
		{ "prompt", "reasonUnknown" },
	}
	local function ResetAdvanced()
		ns.Guard("reset advanced", function()
			local defaults, profile = ns.defaults.profile, ns.db.profile
			for _, field in ipairs(resetFields) do
				profile[field[1]][field[2]] = defaults[field[1]][field[2]]
			end
			-- keepDebts can only go from off to on here, which deletes
			-- nothing; SaveDebts is still what its setter runs, so the two
			-- ways of switching it on leave the file the same.
			ns.addon:SaveDebts()
			rescan()
			-- Both hold off in combat and catch up when the fight ends, so
			-- this never touches the secure button mid-fight.
			restyleAndMacro()
			ns.RefreshOptionsDisplay()
		end)
	end

	return {
		type = "group",
		name = TAB.advanced,
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
			resetAdvanced = {
				type = "execute",
				name = L["Put these back to default"],
				order = 0.7,
				confirm = true,
				confirmText = L["Put every setting on this tab back to its default? This also restores what the prompt says; where it sits is kept."],
				func = ResetAdvanced,
			},

			favoursHeader = { type = "header", name = L["Favours"], order = 10, hidden = NoOthers },
			owedClassBuffsOnly = {
				type = "toggle",
				name = L["Ignore shields, heals and trinket procs"],
				desc = L["Only class buffs such as Fortitude count as a favour to return."],
				order = 11,
				width = "full",
				hidden = NoOthers,
				disabled = function() return not S().owed end,
				get = sGet,
				set = sSet,
			},
			-- Every one of these is a number of seconds. There is no suffix
			-- field on an AceConfig range, so the unit goes in the name or it
			-- is nowhere.
			reciprocateWindow = {
				type = "range",
				name = L["Offer a buff back for (seconds)"],
				desc = L["How long someone who buffed you stays on offer."],
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
				name = L["Stop sooner if they are probably gone"],
				desc = L["Someone who buffed you rarely can be range-checked, so they are let go after the time below."],
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
				name = L["Let them go after (seconds)"],
				desc = L["Counted from their buff, not from when they walked off."],
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
			-- on the very next scan. A right-press blocks the whole person
			-- for the same number.
			retryCooldown = {
				type = "range",
				name = L["Don't repeat a spell on someone for (seconds)"],
				desc = L["In case the cast failed; right-clicking the prompt skips the person for this long."],
				order = 21,
				width = "double",
				min = 3,
				max = 60,
				step = 1,
				get = tGet,
				set = tSet,
			},
			scanInterval = {
				type = "range",
				name = L["Check for people every (seconds)"],
				desc = L["Lower reacts faster and uses a little more CPU."],
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
				-- (STRATEGIES.self in Prompt.lua), so for a class whose only
				-- prompt is "You" this would be a switch that changes nothing.
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
				name = L["Reason text: my target"],
				desc = L["Shown when your target is first in line."],
				order = 53,
				hidden = NoOthers,
				get = pGet,
				set = pSet,
			},
			reasonOwed = { type = "input", name = L["Reason text: buffed me"], order = 54, hidden = NoOthers, get = pGet, set = pSet },
			reasonAsked = {
				type = "input",
				name = L["Reason text: asked in chat"],
				desc = L["Shown for someone who asked in chat."],
				order = 55,
				hidden = NoOthers,
				get = pGet,
				set = pSet,
			},
			-- Between the two it sits between in the queue.
			reasonSelf = {
				type = "input",
				name = L["Reason text: my own buff"],
				desc = L["Shown when the prompt offers you your own buff."],
				order = 55.5,
				get = pGet,
				set = pSet,
			},
			reasonGroup = { type = "input", name = L["Reason text: my group"], order = 56, hidden = NoOthers, get = pGet, set = pSet },
			reasonNearby = { type = "input", name = L["Reason text: passer-by"], order = 57, hidden = NoOthers, get = pGet, set = pSet },
			reasonRefresh = {
				type = "input",
				name = L["Reason text: top-up"],
				desc = L["{time} is how long theirs has left."],
				order = 58,
				get = pGet,
				set = pSet,
			},
			reasonUnknown = {
				type = "input",
				name = L["Reason text: can't tell"],
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
