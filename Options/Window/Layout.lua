-- Manners -- options window: where every control sits.
--
-- The window reads its controls from ns.optionsTable (Options/<Tab>.lua, the
-- model) and places them from this table. A control is "tab.key": the tab is
-- where its definition lives, not the page it is drawn on, so a control moves
-- between pages here without its definition moving. Visibility, labels and
-- values stay the model's.
--
-- Read at load, before SetupOptions has built the model, so nothing here may
-- touch ns.optionsTable or ns.db; the icons that need the character are
-- functions the window calls when it draws the sidebar.
--
-- A page is { title = L[...], blurb = L[...] (the line under its title: what the
-- page is for, 120 characters at most), icon, sections }.
--
-- A section is { header = "tab.key" (the model header's name is its title) or
-- title = L[...], fold = true below the hairline (plain = true for a fold that
-- is no fine print and wants no caption over it: What's new), key =
-- "<page>.<name>" (stable: an open fold is remembered by it), items = { ... } }. An item is "tab.key"
-- or { "tab.key", indent (true one step in, 2 two: a choice under a switch
-- that is itself in), pair (may share a row with the item after it; pairs
-- that follow one another are one run, whose shown items go two to a row),
-- standIn (a note that keeps its section while the controls it stands in for
-- are hidden), lead, columns, widget, big (a button that leads its page: taller,
-- in the large font), buttons (buttons that follow one another are one run, laid
-- left to right at their own widths), match (dropdowns sharing the same match
-- draw their fields at one width) }. tests/scenarios/layout.lua holds every
-- control to being placed exactly once.
--
-- A window dragged wide flows a page's sections into two columns, and three
-- when very wide (WindowPage.lua, UI.ColumnsFor): in the order they are listed
-- here, down the first column and then the next, a section never cut in two.
-- So the order of the sections is the reading order at every width, and a
-- section should be a group that stands on its own. `spans` names the
-- sections that take the page's whole width instead, above the columns: the
-- line a page opens with.
--
-- How the pages are arranged (1.12): by what the player came to do. A page
-- answers one question, in the order somebody asks it -- who, then what, then
-- the fine print -- and every section but the line a page opens with has a
-- heading. Each buff has a row of its own with that buff's own switches under
-- it. A sub-option is indented under its switch, and while that switch is off
-- and has greyed it, it is not drawn at all (WindowPage.lua, UnderOff), so an
-- item indented under a switch must be one that switch governs. What only a
-- few change is in a fold, under the hairline. No page is longer than about
-- three screens of the usual window with its folds shut.
--
-- The simple view (Options/Shared.lua, ns.MenuView) draws, of every page not
-- named in `simple.pages`, only the controls and notes `simple.items` names:
-- the essentials, about a tenth of the options. A page left with nothing to
-- show leaves the sidebar. A control left off it is still found by search,
-- which opens the full view on it. The window draws the view's own controls
-- itself, from `menu`: the switch under the search box, and over the page the
-- line that says more is in the full view.
--
-- A section marked `home = true` is a home: it has a title and may have no
-- item yet, and a setting that arrives for what its comment names goes there,
-- so it is found where its kin are (other homes are a comment inside the
-- section the setting belongs to; grep HOME). A section with nothing to show
-- is not drawn.
--
-- A page of many sections names its sub-divisions in `subpages`: a list of
-- entries, each a list of section keys of that page that go together, with
-- an optional `title = L[...]` (else the label is the title of its first
-- section shown). Seven at most: neighbouring small sections share one. The
-- sidebar lists them under the open page, All first, while two or more have
-- something to show (WindowPage.lua, UI.SubsShown); one chosen draws only its
-- sections, at the top of the page with their folds open, and a section no
-- entry names (the line a page opens with) is drawn with every one. Nothing
-- moves between pages: they are only a way to look at one.
--
-- `units` names the sliders whose box shows a unit (WidgetsEntry.lua,
-- RangeText and RangeParse): path -> { kind = "seconds" | "minutes" |
-- "percent" | "times", zero = L[...] optional }. "seconds" reads 12 s,
-- 5 min, 1 min 30 s (0.5 s where the step is a tenth); "minutes" reads 45 min,
-- 2 h, 1 h 30 min (0.5 min where the step is a half); "percent" is the
-- number as it is, 40%; "times" is 2x or 2.5x. `zero` is the word for 0. A
-- typed 5m or 1h is converted into the setting's own unit. A slider with no
-- entry reads as a plain number. The fallback dialog has no unit field, so a
-- label that leaves its unit to the box says it in its tooltip.

local _, ns = ...
local L = ns.L

-- One picture a page, painted for it (Textures/Menu, tools/make_menu_icons.py):
-- the addon's own files, so every client has them. Never an atlas: one this
-- client lacks draws as a green square.
local MENU = "Interface\\AddOns\\Manners\\Textures\\Menu\\"
local ICONS = {
	general = MENU .. "Start",
	who = MENU .. "Who",
	self = MENU .. "Self",
	pet = MENU .. "Pet",
	skip = MENU .. "Skip",
	when = MENU .. "When",
	click = MENU .. "Say",
	fight = MENU .. "Fight",
	quiet = MENU .. "Quiet",
	appearance = MENU .. "Look",
	modules = "Interface\\AddOns\\Manners\\Textures\\Manners64",
	profiles = MENU .. "Profiles",
	diagnostics = MENU .. "Diagnostics",
}

-- The per-spell switches under Buff to offer (Who.lua's AddBuffToggles): one
-- per buff, only for a class with two or more or a lone one flagged switchable (a
-- warlock's Unending Breath), so a mage has none. Each class's
-- in its walk order, which is the order the buff set lists them; the model only
-- ever holds the player's own class's. On Forever that is the priest's three,
-- the paladin's six and the druid's two.
--
-- One buff a row, and under it the switches that are that buff's alone: who
-- gets it (Thorns, Unending Breath), and for the player's own class the one
-- about who it is any use to -- the buff only somebody with mana wants (a
-- priest's Divine Spirit, a paladin's Wisdom), the blessing no caster wants.
-- `placed` is told which of those two went under a buff; the class is asked
-- of the client as the file loads, and where it will not say they keep their
-- place under the list.
local function OwnClass()
	if type(UnitClass) ~= "function" then return nil end
	local ok, _, class = pcall(UnitClass, "player")
	class = ok and ns.plain(class) or nil
	return type(class) == "string" and class or nil
end

-- The last buff of `buffs` carrying `flag`, and whether it is the only one.
local function LastWith(buffs, flag)
	local last, count = nil, 0
	for _, buff in ipairs(buffs or {}) do
		if buff[flag] then last, count = buff, count + 1 end
	end
	return last, count == 1
end

local function OfferItems(placed)
	local items, seen, classes = {}, {}, {}
	local own = OwnClass()
	local ownBuffs = own and type(ns.BUFFS) == "table" and type(ns.BUFFS[own]) == "table" and ns.BUFFS[own] or nil
	local mana, manaAlone = LastWith(ownBuffs, "manaOnly")
	local melee, meleeAlone = LastWith(ownBuffs, "meleeOnly")
	for class, buffs in pairs(ns.BUFFS or {}) do
		if type(buffs) == "table" and (#buffs > 1 or (#buffs == 1 and buffs[1].switchable)) then
			classes[#classes + 1] = class
		end
	end
	table.sort(classes)
	for _, class in ipairs(classes) do
		for _, buff in ipairs(ns.BUFFS[class]) do
			local path = "who.offer_" .. tostring(buff.key)
			if not seen[path] then
				seen[path] = true
				items[#items + 1] = path
				-- Thorns, held to the tanks (Buffs.lua, tankChoice), under its switch.
				if buff.tankChoice then items[#items + 1] = { "who.tank_" .. tostring(buff.key), indent = true } end
				-- And its second switch: not on you in a dungeon or a raid (notMeInside).
				if buff.tankChoice then items[#items + 1] = { "who.notMeInside_" .. tostring(buff.key), indent = true } end
				-- And its third: your target, whatever Offer to says (toTarget).
				if buff.tankChoice then items[#items + 1] = { "who.toTarget_" .. tostring(buff.key), indent = true } end
				-- A buff kept for favours and requests (Buffs.lua, returnOnly), to everybody.
				if buff.returnOnly then items[#items + 1] = { "who.everyone_" .. tostring(buff.key), indent = true } end
				-- A buff held to your group by choice (Buffs.lua, membersOnly), to passers-by too.
				if buff.membersOnly and not (buff.partyOnly or buff.groupOnly or buff.oneTarget) then
					items[#items + 1] = { "who.passers_" .. tostring(buff.key), indent = true }
				end
				-- Only to players with mana, under the buff it names: indented
				-- when that is the one buff it is about.
				if class == own and buff == mana then
					items[#items + 1] = { "who.relevantOnly", indent = manaAlone or nil }
					placed["who.relevantOnly"] = true
				end
				-- Not to mages, warlocks and priests, under the blessing it names.
				if class == own and buff == melee then
					items[#items + 1] = { "who.skipCasters", indent = meleeAlone or nil }
					placed["who.skipCasters"] = true
				end
			end
		end
	end
	return items
end

-- Another control's label as it reads now, in gold, for a sentence that
-- points at it (offNotes). Asked at paint time, when the model is built.
local function NameOf(path)
	local B = ns.WindowBind
	local item = B and B.Item(path)
	local name = item and B.Text(item, "name") or ""
	return "|cffffd100" .. name .. "|r"
end

-- The page a control is on, as the window names it now ("" while unplaced).
local function TabOf(path)
	return ns.OptionsPage.TabOf(path) or ""
end

-- What to cast: the buff dropdown, each buff's switch with its own under it,
-- then what is about all of them.
local function CastItems()
	local items, placed = { "who.choice" }, {}
	for _, item in ipairs(OfferItems(placed)) do items[#items + 1] = item end
	-- The model is built before the class probe; the controls hide themselves
	-- from classes without Battle Shout.
	items[#items + 1] = "who.shoutMelee"
	items[#items + 1] = "who.shoutCombatInstances"
	if not placed["who.skipCasters"] then items[#items + 1] = "who.skipCasters" end
	if not placed["who.relevantOnly"] then items[#items + 1] = "who.relevantOnly" end
	items[#items + 1] = { "who.autoNote", standIn = true }
	items[#items + 1] = "who.pinNote"
	return items
end

-- Other people's buffs, the fine print: what is left alone because somebody
-- else already gave it. Rare, so a fold of its own on Who to buff.
local function FineItems()
	local items = {}
	-- A paladin's: nobody another paladin has blessed.
	items[#items + 1] = "who.leaveBlessed"
	items[#items + 1] = "who.spareFishBowl"
	-- Never Kings over it at all, shown only while the switch above is on.
	items[#items + 1] = { "who.neverFishBowl", indent = true }
	-- Forever: a campsite's Boosted buffs never cast over.
	items[#items + 1] = "who.spareCamp"
	return items
end

ns.WindowLayout = {
	-- The window frame: shown on every page, so no page shows them.
	header = {
		preview = "general.previewStart",
		-- Beside the preview: Move the prompt, which reads Lock it while the
		-- prompt is unlocked. The same control leads Look (appearance.move).
		move = "general.moveToggle",
		enabled = "general.enabled",
		snooze = { "general.snooze5", "general.snooze15", "general.snooze30", "general.snooze60", "general.snooze120", "general.snooze240", "general.snoozeSession", "general.snoozeStop" },
		snoozeTip = "general.snoozeNote",
	},
	strip = {
		lock = "general.lockNow",
		-- Line 2 in a fight: the open page's note.
		combat = { click = "click.combatNotice", quiet = "click.quietCombatNotice", fight = "appearance.fightCombatNotice", appearance = "appearance.combatNotice", when = "advanced.advCombatNotice" },
	},
	foldCaption = "advanced.advIntro",
	-- The simple view's own controls: the switch under the search box, and
	-- over a page the line that says more is in the full view.
	menu = {
		simple = "general.simpleView",
		more = "general.simpleMore",
	},
	-- `about`: who makes Manners, under the build on every page.
	footer = { reset = "advanced.resetAdvanced", build = "diagnostics.buildNote", about = "diagnostics.aboutNote" },

	-- The sidebar, top to bottom; a hairline between groups. Page ids are the
	-- old tab keys (bug reports and ns.OptionsTab() name them), plus skip and
	-- fight, which are pages of the window and not tabs of the old dialog.
	groups = {
		{ "general" },
		{ "who", "skip", "when" },
		{ "click", "quiet" },
		{ "fight", "appearance" },
		{ "modules" },
		{ "profiles", "diagnostics" },
	},
	groupLabels = {
		[2] = L["Buffing"],
		[3] = L["Speech"],
		[4] = L["Prompt"],
		[5] = L["Optional modules"],
		[6] = L["Support"],
	},

	-- A fold moved to another page keeps the open state it was saved under
	-- (UI.State copies it once): old section key -> new.
	renamedFolds = {},

	pages = {
		general = {
			title = L["Start here"],
			blurb = L["Set Manners up in a minute, and find your favour ledger."],
			icon = ICONS.general,
			sections = {
				-- What the prompt is, first: the questions under it are about it.
				-- In the body's own size, so it does not read as a heading.
				{ key = "general.lead", items = {
					{ "general.noBuffs", standIn = true },
					"general.howItWorks",
					-- Asking for buffs, for a class with nothing to give (Ask.lua).
					"general.startAsk",
				} },
				-- A new profile's two questions (Start.lua, Quick.Asking); the
				-- section goes with them once answered or skipped. The two
				-- dropdowns one width, the two buttons side by side.
				{ key = "general.firstRun", header = "general.firstHeader", items = {
					{ "general.firstWho", match = "first" },
					{ "general.firstVoice", match = "first" },
					{ "general.firstDone", buttons = true },
					{ "general.firstSkip", buttons = true },
				} },
				{ key = "general.who", header = "general.whoHeader", items = {
					"general.quickWho",
					-- A hunter's step 1: the own-buff sentence, with no dropdown.
					{ "general.quickWhoSummary", standIn = true },
					-- Passers-by on and the friendly nameplates off (Who to buff
					-- has the same pair, and the page's red dot).
					"general.startPlatesNote",
					"general.startShowPlates",
				} },
				-- The step most players skip, and then can only click the prompt:
				-- where it stands first (No key yet, or the key), in a block of its
				-- own, then the box that sets it.
				{ key = "general.key", header = "general.keyHeader", items = {
					"general.bindStatus",
					"general.bindKey",
					{ "general.makeMacro", buttons = true },
					{ "general.openBindings", buttons = true },
					-- The line in chat that says how, while there is no key.
					"general.keyReminder",
				} },
				{ key = "general.ledger", header = "general.ledgerHeader", items = {
					"general.ledgerSummary",
					"general.ledgerOpen",
				} },
				-- Unfolded, and on the one page that never hides: the chat lines
				-- are what people look for when they annoy them.
				{ key = "general.minimap", header = "general.minimapHeader", items = {
					"general.minimap",
					"general.verbose",
					"general.silentChat",
					-- And which chat window they go to (chat.frame).
					"general.chatFrame",
					-- What /manners welcome says, again in the chat window, for
					-- somebody who skipped it: with the chat lines, under their heading.
					"general.welcomeAgain",
				} },
				-- What's new (Options/Start.lua, News): the newest release's notes
				-- in short, folded at the foot of the page, each note under a head a
				-- size up (`lead`). `plain`: no setting in it.
				{ key = "general.news", header = "general.newsHeader", fold = true, plain = true, items = {
					{ "general.newsHead1", lead = 8 }, "general.newsNote1",
					{ "general.newsHead2", lead = 3 }, "general.newsNote2",
					{ "general.newsHead3", lead = 3 }, "general.newsNote3",
					{ "general.newsHead4", lead = 3 }, "general.newsNote4",
					{ "general.newsHead5", lead = 3 }, "general.newsNote5",
					{ "general.newsHead6", lead = 3 }, "general.newsNote6",
					{ "general.newsHead7", lead = 3 }, "general.newsNote7",
					{ "general.newsHead8", lead = 3 }, "general.newsNote8",
					{ "general.newsHead9", lead = 3 }, "general.newsNote9",
					{ "general.newsHead10", lead = 3 }, "general.newsNote10",
					{ "general.newsHead11", lead = 3 }, "general.newsNote11",
					{ "general.newsHead12", lead = 3 }, "general.newsNote12",
					{ "general.newsHead13", lead = 3 }, "general.newsNote13",
					{ "general.newsHead14", lead = 3 }, "general.newsNote14",
					{ "general.newsHead15", lead = 3 }, "general.newsNote15",
					{ "general.newsHead16", lead = 3 }, "general.newsNote16",
				} },
			},
			-- The steps as they are numbered, the lead with the first.
			subpages = {
				{ "general.lead", "general.firstRun", "general.who" },
				{ "general.key" },
				{ "general.ledger" },
				{ "general.minimap" },
				{ "general.news" },
			},
		},

		modules = {
			title = L["Optional modules"],
			blurb = L["Turn optional modules on or off here. Their changes take effect after Reload UI."],
			icon = ICONS.modules,
			sections = {
				{ key = "modules.lead", title = L["Optional modules"], items = {
					"general.modulesWelcome",
					"general.modulesWelcomeDone",
					-- HOME: companion pets and the rest of My Buffs stay on the
					-- optional My own buffs page, which joins this sidebar group.
					"general.modules",
				} },
				{ key = "modules.reload", title = L["Apply changes"], items = {
					"general.modulesReload",
				} },
				{ key = "modules.list", title = L["Available modules"], items = {
					"general.modulesCombat",
					"general.modulesCombatHelp",
					"general.modulesAchievements",
					"general.modulesAchievementsHelp",
					"general.modulesPets",
					"general.modulesPetsHelp",
					"general.modulesMyBuffs",
					"general.modulesMyBuffsHelp",
					"general.modulesServices",
					"general.modulesServicesHelp",
				} },
			},
		},

		who = {
			title = L["Who to buff"],
			blurb = L["Who gets your buffs, which buff they get, and in what order."],
			icon = ICONS.who,
			sections = {
				-- Who the prompt is on right now, so a switch can be seen to work.
				{ key = "who.now", items = { "who.rightNow" } },
				-- Who first: the page is called Who to buff. Then what they get,
				-- the order it is tried in, and the group's own casts. Your own buffs
				-- are on My own buffs, and a hunter's pet on My pet.
				{ key = "who.sources", header = "who.sourcesHeader", items = {
					"who.emptyWarning",
					"who.owed",
					"who.group",
					-- The pets of the people in it, under the switch it widens.
					-- HOME: the group's pets (anything more about them goes here).
					{ "who.pets", indent = true },
					"who.strangers",
					-- While passers-by are on and the game's nameplates are off.
					{ "who.strangersPlatesNote", indent = true },
					{ "who.strangersShowPlates", indent = true },
					{ "who.strangersNote", standIn = true },
					{ "who.proximity", indent = true },
					{ "who.restingOnly", indent = true },
					"who.asked",
					-- What a class hands out to whoever asks (Courtesy.lua: a mage's
					-- water and portals, a warlock's healthstones and summons), under
					-- the switch that hears the asking: the model shows them only
					-- while it is on, so they come up right where it was ticked.
				} },
				{ key = "who.cast", header = "who.buffsHeader", items = CastItems() },
				-- The class's buffs as a list in the order they are tried, each with an
				-- arrow up and one down (the "order" composite, Widgets: five
				-- definitions drawn as one piece); for a class with two buffs or more
				-- and no spell pinned. A paladin's Blessing of Kings first sits on
				-- top of the list it reorders, so the two read together.
				{ key = "who.order", header = "who.orderHeader", items = {
					"who.kingsFirst",
					{ composite = "order", ids = {
						"who.orderNote", "who.orderPick", "who.orderUp", "who.orderDown", "who.orderReset",
					} },
				} },
				{ key = "who.orderClass", title = L["A blessing for each class"], fold = true, items = {
					-- A blessing for each class, under the order it steps out of.
					"who.classNote",
					{ "who.classPick", match = "classBlessing" },
					{ "who.classBlessing", match = "classBlessing" },
					{ "who.classReset", buttons = true },
				} },
				{ key = "who.group", header = "who.groupHeader", items = {
					"who.groupBuffsUse",
					{ "who.groupBuffsAtLeast", indent = true },
					"who.reagentNote",
					{ "who.skipRaidGroups", columns = 4 },
					-- A shout cannot be aimed at a group: what the ticks do for it.
					{ "who.skipRaidGroupsNote", indent = true },
					-- HOME: sharing a group with other Manners users (who buffs
					-- whom when two of you are in it) goes here. The split with
					-- the others of your class in it (Share.lua); the model shows
					-- it only while My party and raid is on.
					"who.share",
				} },
				-- HOME: what a class does for people beyond its buffs:
				-- resurrection and cures. Their switches go here, a row each
				-- with its own sub-options indented under it. (The courtesies
				-- on request are under People who ask me in chat, above.)
				{ key = "who.beyond", title = L["Resurrection and cures"], home = true, items = {
					-- Your resurrection for the group's dead (Resurrect.lua), and
					-- for a dead passer-by under it.
					"who.res",
					{ "who.resStrangers", indent = true },
				} },
				-- The fine print about buffs other people have given: Paladin's
				-- blessed, Fish Bowl, campsite. Shut, as it is rarely touched.
				{ key = "who.castFine", title = L["Other people's buffs"], fold = true, items = FineItems() },
				{ key = "who.first", header = "who.firstHeader", fold = true, items = {
					"who.target",
					"who.friends",
					"who.readyCheck",
					"who.revived",
				} },
			},
			subpages = {
				{ "who.sources" },
				{ "who.cast", "who.order", "who.orderClass", "who.castFine" },
				{ "who.group" },
				{ "who.beyond" },
				{ "who.first" },
			},
		},

		-- Every "Skip ..." switch and the never-offer list, out of Who to buff.
		-- Its title is the old Who to skip header's string.
		skip = {
			title = L["Who to skip"],
			blurb = L["People Manners leaves alone, and how long a right-click skips someone."],
			icon = ICONS.skip,
			sections = {
				{ key = "skip.now", items = { "who.rightNowSkip" } },
				-- How long a right-click leaves someone alone, in seconds and in
				-- minutes (it was a fold on When to offer).
				{ key = "skip.rightClick", title = L["After a right-click"], items = {
					"advanced.skipSeconds",
					"advanced.ownSkipMinutes",
				} },
				{ key = "skip.lead", title = L["Players to skip"], items = {
					"who.skipPvP",
					-- Who that switch holds back right now, under it.
					{ "diagnostics.pvpDiag", indent = true },
					"who.skipFighting",
					"who.skipSameClass",
					"who.skipGuilds",
					"who.skipMuted",
					{ "who.skipNearbyClasses", columns = 3 },
					"who.requireInRange",
					"who.minLevel",
					"who.minLevelNote",
				} },
				{ key = "skip.never", header = "who.neverHeader", items = {
					-- One list with a remove button per name, built from five
					-- model entries (Widgets.lua).
					{ composite = "never", ids = {
						"who.neverNote", "who.neverPick", "who.neverRemove", "who.neverAdd", "who.neverClear",
					} },
					"who.neverPaste",
					-- The buffs held off somebody the game refused them on (Queue.lua).
					"who.heldRetry",
				} },
			},
		},

		when = {
			title = L["When to offer"],
			blurb = L["When a buff is offered again, and returning favours."],
			icon = ICONS.when,
			sections = {
				{ key = "when.now", items = { "when.rightNow" } },
				-- Other people first, then your own buffs under a heading of their
				-- own: their top-up has a switch and a lead of its own.
				{ key = "when.buffed", header = "when.buffedHeader", items = {
					"when.whenBuffed",
					{ "when.refreshUnder", indent = true },
					{ "when.refreshRaid", indent = true },
					"when.alwaysNote",
					"when.verifiedOnly",
				} },
				-- Where the old note pointing at Advanced was.
				{ key = "when.favours", header = "advanced.favoursHeader", items = {
					"advanced.reciprocateWindow",
					"advanced.owedClassBuffsOnly",
					-- A favour from somebody who already has your buff.
					"advanced.repayCovered",
					"advanced.reachableOnly",
					{ "advanced.graceSeconds", indent = true },
					"advanced.keepDebts",
				} },
				{ key = "when.timing", header = "advanced.timingHeader", fold = true, items = {
					"advanced.retryCooldown",
					"advanced.scanInterval",
				} },
				{ key = "when.targeting", header = "advanced.targetingHeader", fold = true, items = {
					"advanced.restoreTarget",
					-- A warrior's: the switch is hidden, the note says why.
					{ "advanced.noTargetNote", standIn = true },
				} },
			},
			-- The two folds of fine print are one entry.
			subpages = {
				{ "when.buffed" },
				{ "when.favours" },
				{ "when.timing", "when.targeting" },
			},
		},

		-- Your own buffs, apart from the ones you give other people: what Manners
		-- reminds you of, when, how early, and the things you carry.
		-- Where and when Manners holds back or says nothing: the place rules,
		-- the group rules for the spoken line and the thanks, battlegrounds,
		-- and being mounted or low on mana.
		quiet = {
			title = L["Quiet times"],
			blurb = L["Where and when Manners holds back or says nothing. To pause it for a while, use Snooze at the top."],
			icon = ICONS.quiet,
			sections = {
				-- The place rules lead Hold back: they hold back everybody, so
				-- they are not items of the list of people on Who to buff.
				{ key = "quiet.holdBack", header = "when.wayHeader", items = {
					"who.quietInTowns",
					-- Cities and inns, cities only or inns only.
					{ "who.quietInTownsWhere", indent = true },
					-- Only the short buffs, where the rule above holds everything.
					"who.quietShortInTowns",
					{ "who.quietShortMinutes", indent = true },
					"who.quietInInstances",
					"who.quietTargets",
				} },
				{ key = "quiet.group", title = L["In a party or a raid"], items = {
					"click.quietInParty",
					"click.quietInRaid",
					"click.thankNotInGroup",
				} },
				-- HOME: battlegrounds and arenas (what is offered there, and to
				-- whom) go here: a place rule, beside Hold back's. Four switches
				-- of their own (Battle.lua), which decide there.
				{ key = "quiet.battle", title = L["Battlegrounds and arenas"], home = true, items = {
					"when.battleTeam",
					"when.battleSpeak",
					"when.battleThank",
					"when.battleItems",
				} },
				{ key = "quiet.mounted", title = L["Mounted and mana"], items = {
					"when.hideMounted",
					"when.manaFloor",
					-- What it still offers below it: favours and requests, your
					-- own buff only, or nothing.
					{ "when.manaFloorKeeps", indent = true },
					"when.manaNote",
				} },
			},
			subpages = {
				{ "quiet.holdBack" },
				{ "quiet.group" },
				{ "quiet.battle" },
				{ "quiet.mounted" },
			},
		},

		click = {
			title = L["What I say"],
			blurb = L["Your thank-yous, the line said with a buff, and asking others for one."],
			icon = ICONS.click,
			sections = {
				-- The quick choice, directly above the switches it sets.
				{ key = "click.lead", items = {
					"general.quickVoice",
					"general.quickVoiceSummary",
				} },
				{ key = "click.speech", title = L["Thank-yous"], items = {
					"click.thankEmote",
					{ "click.thankEmoteToken", indent = true },
					-- Others to pick from, under the one picked.
					{ "click.thankEmoteMore", indent = 2, columns = 4 },
					"click.thankWhisper",
					-- The pause, the press and the nobody-could-name rule hold for
					-- the /thank and the whisper alike: live while either is on, so
					-- none sits under one switch.
					"click.thankDelay",
					-- Every thank waits for a press of the prompt (ThankPress.lua).
					"click.thankAsk",
					-- A thank for somebody nobody could name, the emote's or the whisper's.
					"click.thankUnseen",
				} },
				{ key = "click.said", title = L["A line when I buff"], items = {
					"click.enabled",
					{ "click.channel", indent = true },
					{ "click.onlyWhenReturning", indent = true },
					-- While speaking with friendly nameplates off (Speech.lua).
					{ "click.platesNote", indent = true },
					{ "click.showPlates", indent = true },
					-- {name} as the first word, in the line and the whispered thank-you alike.
					"click.firstNameOnly",
					{ "click.linesOff", standIn = true },
				} },
				{ key = "click.lines", header = "click.phrasesHeader", items = {
					"click.preset",
					"click.phrasesHelp",
					"click.inCharacterNote",
					-- In character lines left out (speech.leftOut), while that is the set.
					"click.leaveOutLast",
					"click.leftOut",
					"click.phrases",
					-- Your own lines among the In character ones, while that is the set.
					"click.mixedLines",
					-- How often they are said.
					{ "click.mixedShare", indent = true },
					{ "click.backToInCharacter", pair = true },
					"click.roll",
					"click.limits",
				} },
				-- HOME: asking for a buff (what you want from other people, and
				-- how it is asked) goes here: it is about you, not about the
				-- people you buff.
				-- Asking, not only giving (Ask.lua): the switch, and under it how
				-- the ask is said, gone while it is off.
				{ key = "click.asking", title = L["Asking for a buff"], home = true, items = {
					"who.ask",
					{ "who.askChannel", indent = true },
					{ "who.askLine", indent = true },
					{ "who.askBlessing", indent = true },
					{ "who.askOwn", indent = true },
					{ "who.askInTowns", indent = true },
				} },
			},
			subpages = {
				{ "click.speech" },
				{ "click.said", "click.lines" },
				{ "click.asking" },
			},
		},

		-- Everything that changes when a fight starts, together: what the
		-- prompt does, and the buttons that are there for the fight.
		fight = {
			title = L["In a fight"],
			blurb = L["What the prompt does once a fight starts, and the buttons that come up when you need them."],
			icon = ICONS.fight,
			sections = {
				{ key = "fight.prompt", title = L["The prompt in a fight"], items = {
					"appearance.fightRota",
				} },
				{ key = "fight.buttons", title = L["Buttons for when you need them"], items = {
					-- A Forsaken's Will of the Forsaken (Prompt/BreakFree.lua).
					"appearance.breakFree",
					{ "appearance.breakFreeKey", indent = true },
					"appearance.mendInFight",
					{ "appearance.mendInFightKey", indent = true },
					"appearance.fightButtons",
					"appearance.cureFight",
					{ "appearance.cureFightKey", indent = true },
					{ "appearance.cureFightEach", indent = true },
					{ "appearance.cureFightKey2", indent = true },
					{ "appearance.cureFightPlain", indent = true },
					{ "appearance.cureFightShift", indent = true },
					{ "appearance.cureFightCtrl", indent = true },
					"appearance.reactiveWards",
				} },
			},
		},

		-- Everything about the prompt itself; the wording and the exact
		-- position fold here rather than living on a page of their own.
		appearance = {
			title = L["Look"],
			blurb = L["How the prompt looks, where it sits, and how it gets your attention."],
			icon = ICONS.appearance,
			sections = {
				-- The look to wear, as a gallery of cards (WidgetsTheme.lua) in
				-- place of the model's dropdown, which the fallback dialog keeps:
				-- tabs over the cards, a look tried on the prompt under the
				-- pointer. Across the page's whole width (spans).
				-- Use my class's look on each character leads it, over the tabs.
				{ key = "appearance.themes", title = L["Panel style"], items = {
					"appearance.classLook",
					{ "appearance.style", widget = "themes" },
				} },
				-- Straight under it, open, headed by the chosen look's name: what
				-- goes with that look. Earlier art and its line only for a look
				-- that has one, the key only for a look that draws one, the
				-- gryphons only on Glass; the round icon greyed, with why, where
				-- the look rounds it itself (offNotes). The reason's colours after.
				{ key = "appearance.lookOwn", header = "appearance.lookHeader", items = {
					"appearance.classicArt",
					"appearance.classicArtNote",
					"appearance.roundIcon",
					"appearance.gryphons",
					{ "appearance.keycap", pair = true },
					"appearance.bgColor",
					"appearance.accentByReason",
					-- With Colour marker, whatever else shows: Marker colour
					-- follows on a row of its own while Colour marker by
					-- reason is off.
					{ "appearance.reasonPalette", pair = true },
					"appearance.accentMode",
					"appearance.accentColor",
					"appearance.accentDead",
				} },
				-- No header of its own in the model: the control's label is the title.
				-- Moving the prompt leads the page: the button, big, with the
				-- ready-made places beside it. Lock position is not drawn (see
				-- unplaced): the button reads and sets the same lock.
				{ key = "appearance.where", title = L["Position"], items = {
					{ "appearance.move", pair = true, big = true },
					"appearance.posPreset",
					"appearance.moveInEditMode",
				} },
				{ key = "appearance.size", header = "appearance.posHeader", items = {
					{ "appearance.scale", pair = true },
					"appearance.alpha",
				} },
				{ key = "appearance.attention", header = "appearance.attentionHeader", items = {
					{ "appearance.flashStyle", pair = true },
					"appearance.effects",
					"appearance.soundEnabled",
					{ "appearance.soundFile", indent = true },
					{ "appearance.soundOwedOnly", indent = true },
					"appearance.noSound",
				} },
				-- The names waiting after the first, out of the icon's fold: the
				-- clickable list is a feature people look for, not a fine-tune.
				{ key = "appearance.queue", title = L["Waiting list"], items = {
					"appearance.showCount",
					"appearance.showQueue",
					{ "appearance.queueRows", indent = true },
					{ "appearance.clickRows", indent = true },
				} },
				-- The pane's width and height with them: the numbers of where the
				-- prompt sits and how big its pane is, fine print beside Size's
				-- scale. Since a card's description takes the lines it needs
				-- (WidgetsTheme.lua), that row out of Size keeps Look to three
				-- screens.
				{ key = "appearance.exactPos", header = "advanced.exactPosHeader", fold = true, items = {
					{ "advanced.x", widget = "number", pair = true },
					{ "advanced.y", widget = "number" },
					{ "appearance.width", pair = true },
					"appearance.height",
				} },
				{ key = "appearance.text", header = "appearance.textHeader", fold = true, items = {
					{ "appearance.font", pair = true },
					"appearance.fontSize",
					{ "appearance.fontColor", pair = true },
					"appearance.classColor",
					"appearance.textShadow",
					"appearance.showSub",
					{ "appearance.showGuild", indent = true },
				} },
				-- The reason boxes two to a row, in queue order: one run of
				-- pairs, so a hunter's two still share a row.
				{ key = "appearance.wording", header = "advanced.wordingHeader", fold = true, items = {
					"advanced.formatHelp",
					"advanced.format",
					{ "advanced.reasonTarget", pair = true },
					"advanced.reasonOwed",
					{ "advanced.reasonAsked", pair = true },
					"advanced.reasonSelf",
					{ "advanced.reasonGroup", pair = true },
					"advanced.reasonNearby",
					{ "advanced.reasonRefresh", pair = true },
					"advanced.reasonUnknown",
				} },
				-- The model's header reads "Icon and waiting list", for the old
				-- dialog; the waiting list has its own section above.
				{ key = "appearance.icon", title = L["Icon"], fold = true, items = {
					-- Everything Show spell icon governs stands straight under it,
					-- with no row further out between: such a row would be taken
					-- for their switch, and they would stay drawn with the icon
					-- off. The consumables button goes by another setting, so it
					-- stands apart; the round icon and the gryphons, which the
					-- look decides, are with the look's own settings.
					"appearance.showIcon",
					{ "appearance.iconSize", indent = true },
					{ "appearance.iconSizeCapped", indent = true },
					{ "appearance.iconFrame", indent = true },
					{ "appearance.showCooldown", indent = true },
					"appearance.suppliesSize",
				} },
				-- Set once, if ever: folded, which keeps Look to three screens.
				{ key = "appearance.hover", header = "appearance.tooltipHeader", fold = true, items = {
					"appearance.tooltip",
					"appearance.tooltipPosition",
				} },
				-- The options window itself stepping aside while a look is changed.
				{ key = "appearance.window", title = L["This window"], fold = true, items = {
					"appearance.peekOnChange",
				} },
			},
			-- The folds join the section they fine-tune: the look's own settings
			-- and the window stepping aside while one is changed the gallery, the
			-- numbers the position, the icon the waiting list it heads.
			subpages = {
				{ "appearance.themes", "appearance.lookOwn", "appearance.window" },
				{ "appearance.where", "appearance.size", "appearance.exactPos" },
				{ "appearance.attention" },
				{ "appearance.queue", "appearance.icon" },
				{ "appearance.text", "appearance.wording" },
				{ "appearance.hover" },
			},
		},

		profiles = {
			title = L["Profiles"],
			blurb = L["Share settings between characters, or switch them by where you are."],
			icon = ICONS.profiles,
			sections = {
				-- The profile manager (AutoProfile.lua), top to bottom: every
				-- profile and who is on it, in a well; the last action's line
				-- with Undo beside it; a profile of this character's own.
				{ key = "profiles.lead", items = {
					"profiles.profilesIntro",
					-- Keeps the section while Undo and the button under it are
					-- away, which they mostly are.
					{ "profiles.current", standIn = true },
					{ "profiles.undoNote", buttons = true },
					{ "profiles.undo", buttons = true },
					"general.ownProfile",
				} },
				-- Pick, then act: the dropdown and the name Duplicate and Rename
				-- take side by side, the buttons that act on the picked profile
				-- in one row, and why some are greyed under them.
				{ key = "profiles.pick", title = L["Pick a profile"], items = {
					{ "profiles.choose", pair = true },
					"profiles.name",
					{ "profiles.use", buttons = true },
					{ "profiles.duplicate", buttons = true },
					{ "profiles.rename", buttons = true },
					{ "profiles.delete", buttons = true },
					{ "profiles.copyfrom", buttons = true },
					"profiles.pickNote",
					-- How a profile is edited, under the buttons.
					"profiles.editNote",
				} },
				-- A new profile from the defaults, where a new character starts,
				-- and the profile in use back to the defaults.
				{ key = "profiles.start", title = L["Start afresh"], items = {
					{ "profiles.new", pair = true },
					"profiles.newCharacters",
					"profiles.resetProfile",
				} },
				-- Switching profile by where you are (AutoProfile.lua). The
				-- master switch, and under it a dropdown a situation and the
				-- chat line's tick, gone while it is off.
				{ key = "profiles.auto", header = "profiles.autoHeader", items = {
					"profiles.autoEnabled",
					{ "profiles.auto_world", indent = true, match = "auto" },
					{ "profiles.auto_dungeon", indent = true, match = "auto" },
					{ "profiles.auto_raid", indent = true, match = "auto" },
					{ "profiles.auto_battle", indent = true, match = "auto" },
					{ "profiles.autoSay", indent = true },
					-- When a switch happens, in one line: last, so the rows above
					-- are the switch's own and the note stays while it is off.
					"profiles.switchNote",
				} },
				{ key = "profiles.share", header = "profiles.shareHeader", items = {
					"profiles.shareNote",
					"profiles.shareCopy",
					"profiles.shareText",
					-- Where a paste goes: over the profile in use, or into a new
					-- one named under it (AutoProfile.lua).
					"profiles.pasteInto",
					{ "profiles.pasteName", indent = true },
					"profiles.sharePaste",
				} },
			},
			-- Four titled sections: picking and starting afresh together, the
			-- switching by place, the sharing; the manager's lead goes with each.
			subpages = {
				{ "profiles.pick", "profiles.start" },
				{ "profiles.auto" },
				{ "profiles.share" },
			},
		},

		diagnostics = {
			title = L["Diagnostics"],
			blurb = L["Why nothing is offered, what Manners can see, and how to report a bug."],
			icon = ICONS.diagnostics,
			sections = {
				-- What holds the prompt back right now, over everything else: the
				-- answer to "why is nothing offered?" without a key to press.
				{ key = "diagnostics.now", items = { "diagnostics.holdDiag" } },
				{ key = "diagnostics.see", header = "diagnostics.capsHeader", items = {
					"diagnostics.noDiag",
					"diagnostics.diag",
					"diagnostics.leadDiag",
					"diagnostics.proximityDiag",
				} },
				{ key = "diagnostics.errors", header = "diagnostics.errorsHeader", items = {
					-- Notes that keep the section while Show every error is
					-- hidden (five errors or fewer).
					{ "diagnostics.errorList", standIn = true },
					"diagnostics.allErrors",
					{ "diagnostics.noErrors", standIn = true },
				} },
				{ key = "diagnostics.report", header = "diagnostics.reportHeader", items = {
					-- Report a bug (Options/BugReport.lua): the walk-through.
					{ "diagnostics.reportBug", big = true },
					-- Which of the two buttons a player asked for a report wants.
					"diagnostics.reportHint",
					-- The one press a player asked for a report needs.
					{ "diagnostics.fullReport", big = true },
					{ "diagnostics.copyReport", buttons = true },
					-- /manners selftest launch, beside the short summary.
					{ "diagnostics.launchCheck", buttons = true },
					-- The key for Mark this moment, a game key binding.
					"diagnostics.markKey",
					"diagnostics.report",
					"diagnostics.selftest",
					-- For working out a failed cast: under the buttons.
					"diagnostics.debugClicks",
				} },
			},
			subpages = {
				{ "diagnostics.now", "diagnostics.see" },
				{ "diagnostics.errors" },
				{ "diagnostics.report" },
			},
		},
	},

	-- The simple view's short list, the essentials a player asked for ("maybe
	-- a tenth of the options"): Manners on or off, the snooze and Move the
	-- prompt (the header's, always drawn), the key, the buff to cast, who to
	-- buff, the never-offer list, quiet in cities and instances, a few of the
	-- look, the /thank and the voice, and Report a bug. No page is drawn whole.
	-- Every buff's own switch (who.offer_*) is added under the table.
	simple = {
		pages = { modules = true },
		items = {
			-- Start here: a new profile's two questions, and the key.
			["general.noBuffs"] = true,
			["general.firstWho"] = true, ["general.firstVoice"] = true,
			["general.firstDone"] = true, ["general.firstSkip"] = true,
			["general.bindStatus"] = true, ["general.bindKey"] = true,
			["general.makeMacro"] = true, ["general.openBindings"] = true,
			-- Who to buff: who gets it and which buff.
			["who.rightNow"] = true, ["who.emptyWarning"] = true,
			["who.owed"] = true, ["who.group"] = true, ["who.strangers"] = true,
			["who.strangersPlatesNote"] = true, ["who.strangersShowPlates"] = true, ["who.strangersNote"] = true,
			["who.choice"] = true, ["who.autoNote"] = true, ["who.pinNote"] = true,
			-- Myself.
			["who.self"] = true,
			-- The never-offer list.
			["who.neverNote"] = true, ["who.neverPick"] = true, ["who.neverRemove"] = true, ["who.neverAdd"] = true,
			-- Quiet in cities and instances.
			["who.quietInTowns"] = true, ["who.quietInInstances"] = true,
			-- The /thank and the voice.
			["general.quickVoice"] = true, ["general.quickVoiceSummary"] = true, ["click.thankEmote"] = true,
			-- The look, a few.
			["appearance.style"] = true, ["appearance.classLook"] = true,
			["appearance.move"] = true, ["appearance.posPreset"] = true, ["appearance.scale"] = true,
			-- Report a bug.
			["diagnostics.reportBug"] = true,
		},
	},

	-- The sections that run the page's whole width when it has columns: what
	-- a page opens with, read before the columns under it.
	spans = {
		["general.lead"] = true,
		["modules.lead"] = true,
		["who.now"] = true,
		["skip.now"] = true,
		["when.now"] = true,
		-- Look's gallery, so a window dragged wide has three cards to a row
		-- over the columns of settings.
		["appearance.themes"] = true,
	},

	-- How a note is drawn when not in the label colour: grey (a colour code
	-- in its text still wins), or grey in a block inset from the page. Kept
	-- apart from the items, which say where a row goes rather than how it
	-- looks.
	notes = {
		["general.modulesCombatHelp"] = { hint = true },
		["general.modulesAchievementsHelp"] = { hint = true },
		["general.modulesPetsHelp"] = { hint = true },
		["general.modulesMyBuffsHelp"] = { hint = true },
		["general.modulesServicesHelp"] = { hint = true },
		["who.autoNote"] = { hint = true },
		-- Start here, step 2: whether there is a key, in a block that leads the step.
		["general.bindStatus"] = { block = true },
		-- What's new: the newest release's highlights, the second note (the
		-- first is the release's title), in a well of their own.
		["general.newsNote2"] = { block = true },
		["diagnostics.ownDiag"] = { hint = true, block = true },
		["diagnostics.pvpDiag"] = { hint = true, block = true },
		["diagnostics.leadDiag"] = { hint = true, block = true },
		["diagnostics.reportHint"] = { hint = true },
		["when.selfLeadNote"] = { hint = true },
		["who.minLevelNote"] = { hint = true },
		-- Every profile and who is on it, in a well (AutoProfile.lua).
		["profiles.current"] = { block = true },
		-- Why a button is greyed, under the row of them.
		["profiles.pickNote"] = { hint = true },
		["profiles.editNote"] = { hint = true },
		["profiles.switchNote"] = { hint = true },
		-- What Earlier art does, under it.
		["appearance.classicArtNote"] = { hint = true },
	},

	-- Why a control is greyed out, drawn under it in grey while it is, and in
	-- its tooltip (Widgets.lua, W.OffNote): for a control greyed by a switch
	-- that is not the one right above it. A function is asked at paint time,
	-- and names the other switch as its own label reads now.
	offNotes = {
		["general.verbose"] = function() return L["Off while %s is on."]:format(NameOf("general.silentChat")) end,
		["who.groupBuffsUse"] = function() return L["Needs %s ticked."]:format(NameOf("who.group")) end,
		["who.skipRaidGroups"] = function() return L["Needs %s ticked."]:format(NameOf("who.group")) end,
		["who.proximity"] = function() return L["Needs %s ticked."]:format(NameOf("who.strangers")) end,
		["who.restingOnly"] = function()
			local db = ns.db and ns.db.profile
			if db and db.filters.quietInTowns == true then
				return L["Off while %s is on (%s)."]:format(NameOf("who.quietInTowns"), ns.OptionsPage.TabOf("who.quietInTowns") or "")
			end
			return L["Needs %s ticked."]:format(NameOf("who.strangers"))
		end,
		["when.battleItems"] = function() return L["Needs %s ticked."]:format(NameOf("who.ownDungeons")) end,
		["who.ownFoodOutside"] = function() return L["Needs %s ticked."]:format(NameOf("who.ownDungeons")) end,
		-- The pause before a thank, greyed while the thanks wait for a press.
		-- The group rules sit on Quiet times, away from the switch they need.
		["click.quietInParty"] = function() return L["Needs %s ticked, on %s."]:format(NameOf("click.enabled"), TabOf("click.enabled")) end,
		["click.quietInRaid"] = function() return L["Needs %s ticked, on %s."]:format(NameOf("click.enabled"), TabOf("click.enabled")) end,
		["click.thankNotInGroup"] = function()
			return L["Needs %s or %s ticked, on %s."]:format(NameOf("click.thankEmote"), NameOf("click.thankWhisper"), TabOf("click.thankEmote"))
		end,
		["click.thankAsk"] = function() return L["Needs %s or %s ticked."]:format(NameOf("click.thankEmote"), NameOf("click.thankWhisper")) end,
		["click.thankUnseen"] = function() return L["Needs %s or %s ticked."]:format(NameOf("click.thankEmote"), NameOf("click.thankWhisper")) end,
		-- The pause before a thank, greyed while the thanks wait for a press,
		-- else while both thanks are off.
		["click.thankDelay"] = function()
			local p = ns.db and ns.db.profile and ns.db.profile.prompt
			if p and p.thankAsk == true then return L["Off while %s is on."]:format(NameOf("click.thankAsk")) end
			return L["Needs %s or %s ticked."]:format(NameOf("click.thankEmote"), NameOf("click.thankWhisper"))
		end,
		["appearance.flashStyle"] = L["Needs the spell icon, the colour marker or Full animations."],
		["appearance.fightButtons"] = L["Needs the Will of the Forsaken or Mend Pet button ticked."],
		-- Greyed where the look rounds its icon itself, or with the icon off.
		["appearance.roundIcon"] = function()
			local p = ns.db and ns.db.profile and ns.db.profile.prompt
			if p and ns.Looks.RoundAlways(p.style) then
				return L["%s always rounds its icon."]:format((ns.Looks.Card(p.style)))
			end
			return L["Needs %s ticked."]:format(NameOf("appearance.showIcon"))
		end,
		-- What only the three built-in looks draw.
		["appearance.iconFrame"] = function()
			local p = ns.db and ns.db.profile and ns.db.profile.prompt
			if p and p.showIcon == false then return nil end
			return L["Only Glass, Framed and Minimal draw this."]
		end,
		["appearance.textShadow"] = L["Only Glass, Framed and Minimal draw this."],
	},

	-- The unit a slider's box shows (see the header comment).
	units = {
		["advanced.skipSeconds"] = { kind = "seconds" },
		["advanced.ownSkipMinutes"] = { kind = "minutes", zero = L["Same as above"] },
		["advanced.reciprocateWindow"] = { kind = "seconds" },
		["advanced.graceSeconds"] = { kind = "seconds" },
		["advanced.retryCooldown"] = { kind = "seconds" },
		["advanced.scanInterval"] = { kind = "seconds" },
		["who.cureSeconds"] = { kind = "seconds" },
		["when.refreshUnder"] = { kind = "minutes" },
		["who.quietShortMinutes"] = { kind = "minutes" },
		["when.selfLead"] = { kind = "minutes", zero = L["Automatic"] },
		["when.refreshRaid"] = { kind = "times" },
		["when.manaFloor"] = { kind = "percent", zero = L["Off"] },
	},

	-- Other words people search for a control by (WindowSearch.lua): ranked
	-- with its choices, matched at the start of a word. One string a control,
	-- translated as a whole.
	keywords = {
		["general.silentChat"] = L["quiet mute spam"],
		["who.skipMuted"] = L["mute muted ignore olympus"],
		["advanced.ownSkipMinutes"] = L["skip longer food well fed ignore right click not now"],
		["advanced.skipSeconds"] = L["skip longer right click not now ignore"],
		["general.verbose"] = L["quiet mute spam"],
		["general.chatFrame"] = L["chat tab window frame redirect spam"],
		["who.ownScrolls"] = L["hide familiar imbue"],
		["who.ownFoodOutside"] = L["food well fed outside world leveling levelling experience"],
		["who.ownHoldMoving"] = L["moving move running run walking jump still hold"],
		-- Asked for as hiding "the window" in a fight.
		-- Asked for as moving "the bar".
		["appearance.moveInEditMode"] = L["bar position drag place"],
		-- The gallery answers a search for look as the switch over it does.
		["appearance.style"] = L["look skin appearance design"],
		-- Asked for as For my class "on each character", for alts.
		["appearance.classLook"] = L["class character alt alts each per own"],
		-- Asked for as profiles that "auto switch in raid, instance, normal".
		["profiles.autoEnabled"] = L["auto raid dungeon instance battleground arena world normal"],
		-- Asked for as thanking "with a mouse button press", for a personal touch.
		["click.thankAsk"] = L["press click manual personal"],
		-- Asked for as no thanks "in a group or raid".
		["click.thankNotInGroup"] = L["group party raid quiet thank silent"],
		["appearance.cureFight"] = L["cure dispel decurse cleanse fight combat button key"],
		["appearance.cureFightEach"] = L["cure each second button druid poison curse fight"],
		["appearance.cureFightPlain"] = L["cure plain press modifier fight"],
		["appearance.cureFightShift"] = L["cure shift press modifier fight"],
		["appearance.cureFightCtrl"] = L["cure control ctrl press modifier fight"],
		["appearance.fightButtons"] = L["fight button hide show dim invisible will forsaken mend pet"],
		["who.curesFight"] = L["cure dispel decurse cleanse fight combat button key"],
		["who.ownSpellAdd"] = L["custom spell add new buff own"],
		-- The consumables button: asked for as the food and flask key.
		["who.ownApart"] = L["consumables button food flask scroll key"],

		-- The words players typed for a control: wotf, rez, reply, queue, color.
		["appearance.breakFree"] = L["wotf forsaken break free fear charm sleep fight button turn off hide"],
		["appearance.breakFreeKey"] = L["wotf forsaken key bind"],
		["appearance.showQueue"] = L["queue list waiting next"],
		["who.res"] = L["resurrect rez res dead revive"],
		["who.resStrangers"] = L["resurrect rez res dead revive"],
		["click.thankDelay"] = L["delay wait pause seconds later"],
		["click.phrases"] = L["custom own reply replies message messages phrase phrases rp roleplay text words"],
		["click.mixedLines"] = L["custom own reply replies message messages phrase phrases rp roleplay text words"],
		["who.askOwn"] = L["custom own reply message words text"],
		["advanced.format"] = L["custom own words text message wording"],
		["who.neverAdd"] = L["blacklist ignore never block"],
		["who.neverPaste"] = L["paste import copy list names"],
		["who.target"] = L["priority first target order"],
		["when.whenBuffed"] = L["refresh top up expire duration timer"],
		["who.quietInTowns"] = L["quiet city town inn capital silent hide"],
		["who.quietInInstances"] = L["quiet dungeon raid instance silent hide"],
		["click.quietInParty"] = L["quiet silent group party raid mute"],
		["click.quietInRaid"] = L["quiet silent group party raid mute"],
		["when.hideMounted"] = L["mount mounted riding hide"],
		["who.own_aspect"] = L["aspect pick choose one hawk monkey cheetah pack"],
		["who.own_tracking"] = L["tracking track pick choose one herbs minerals"],
		["who.own_pet"] = L["companion pet critter vanity"],
		["general.minimap"] = L["minimap icon button hide"],
	},

	-- A control hidden until a switch is on, and that switch: search finds the
	-- control and opens the switch, saying to turn it on first.
	parents = {
		["click.preset"] = "click.enabled",
		["click.phrases"] = "click.enabled",
		["click.mixedLines"] = "click.enabled",
		["click.mixedShare"] = "click.enabled",
		["click.leaveOutLast"] = "click.enabled",
		["click.leftOut"] = "click.enabled",
		["click.roll"] = "click.enabled",
		-- My group's pets too, shown only while My party and raid is on.
		["who.pets"] = "who.group",
		-- A class's courtesies, shown only while People who ask me in chat is on.
		-- Dead passers-by too, shown only while My group's dead is on.
		["who.resStrangers"] = "who.res",
		-- How an ask is said, shown only while asking is on.
		["who.askChannel"] = "who.ask",
		["who.askLine"] = "who.ask",
		["who.askBlessing"] = "who.ask",
		["who.askOwn"] = "who.ask",
		["who.askInTowns"] = "who.ask",
		-- Share the group with other Manners users, the same.
		["who.share"] = "who.group",
		-- Detect Invisibility to passers-by too, shown only once the buff is ticked.
		["who.passers_detectgroup"] = "who.offer_detectgroup",
		-- Never Kings over Boosted Stats, shown only while Don't put Kings over
		-- a Fish Bowl's Boosted Stats is on.
		["who.neverFishBowl"] = "who.spareFishBowl",
		-- Well-Rested's last five minutes, shown only while Well-Rested is on.
		["who.ownRestedEarly"] = "who.own_rested",
		-- A situation's profile and the chat line's tick, shown only while
		-- Switch profile automatically is on.
		["profiles.auto_world"] = "profiles.autoEnabled",
		["profiles.auto_dungeon"] = "profiles.autoEnabled",
		["profiles.auto_raid"] = "profiles.autoEnabled",
		["profiles.auto_battle"] = "profiles.autoEnabled",
		["profiles.autoSay"] = "profiles.autoEnabled",
		-- The break-free key, shown only while its switch is on.
		["appearance.breakFreeKey"] = "appearance.breakFree",
		["appearance.mendInFightKey"] = "appearance.mendInFight",
		["appearance.cureFightKey"] = "appearance.cureFight",
		["appearance.cureFightEach"] = "appearance.cureFight",
		["appearance.cureFightKey2"] = "appearance.cureFightEach",
		["appearance.cureFightPlain"] = "appearance.cureFight",
		["appearance.cureFightShift"] = "appearance.cureFight",
		["appearance.cureFightCtrl"] = "appearance.cureFight",
	},

	-- What else a control of `parents` needs before its switch would show it:
	-- asked by search, which does not say "turn on" a switch that would show
	-- nothing. A courtesy is its class's alone, and the lines mixed in belong
	-- to the In character set.
	parentsIf = {
		-- Only for a character with the ability: the switch shows nothing else.
		["appearance.breakFreeKey"] = function() return ns.caps.breakFree ~= nil end,
		["appearance.cureFightKey"] = function()
			return ns.CureLearned and ns.CureLearned()
		end,
		["appearance.cureFightEach"] = function()
			local l = ns.CureFightSpells and ns.CureFightSpells()
			return l ~= nil and l[2] ~= nil
		end,
		["appearance.cureFightPlain"] = function()
			local l = ns.CureFightKnown and ns.CureFightKnown()
			return l ~= nil and l[2] ~= nil
		end,
		["appearance.cureFightShift"] = function()
			local l = ns.CureFightKnown and ns.CureFightKnown()
			return l ~= nil and l[2] ~= nil
		end,
		["appearance.cureFightCtrl"] = function()
			local l = ns.CureFightKnown and ns.CureFightKnown()
			return l ~= nil and l[2] ~= nil
		end,
		["appearance.cureFightKey2"] = function()
			local l = ns.CureFightSpells and ns.CureFightSpells()
			return l ~= nil and l[2] ~= nil
		end,
		["click.mixedLines"] = function()
			local db = ns.db and ns.db.profile
			return ns.InCharacter ~= nil and ns.InCharacter.Active(db and db.speech)
		end,
		-- How often those lines are said, and the lines left out, the same.
		["click.mixedShare"] = function()
			local db = ns.db and ns.db.profile
			return ns.InCharacter ~= nil and ns.InCharacter.Active(db and db.speech)
		end,
		["click.leaveOutLast"] = function()
			local db = ns.db and ns.db.profile
			return ns.InCharacter ~= nil and ns.InCharacter.Active(db and db.speech)
		end,
		["click.leftOut"] = function()
			local db = ns.db and ns.db.profile
			return ns.InCharacter ~= nil and ns.InCharacter.Active(db and db.speech)
		end,
		-- Only on a client with the sleeping bag (Classic Era, Forever).
		["who.ownRestedEarly"] = function()
			for _, family in ipairs(ns.KnownOwnFamilies()) do
				if family.rest then return true end
			end
			return false
		end,
	},

	-- In the model and drawn nowhere.
	unplaced = {
		-- AceDBOptions' opening paragraph, hidden today: profilesIntro says it.
		["profiles.desc"] = true,
		-- AceDBOptions' Reset, hidden too: profiles.resetProfile asks first.
		["profiles.reset"] = true,
		-- "These settings are shared by your other characters": the
		-- overview at the top of Profiles names who is on which profile.
		["general.sharedNote"] = true,
		-- "3. See it": its preview is the header's button now.
		["general.tryHeader"] = true,
		-- "4. Say thanks (optional)": the voice choice leads What I say.
		["general.voiceHeader"] = true,
		-- Snooze is a menu button in the header.
		["general.snoozeHeader"] = true,
		-- "Lock position": Look's first control is the Move the prompt button,
		-- which reads Lock it while the prompt is unlocked and goes the same
		-- way as /manners unlock and lock; the saved setting is the same.
		["appearance.locked"] = true,
		-- "Cures", "Asking for buffs" and "In battlegrounds and arenas", the
		-- fallback dialog's headings: the window has a home for each, titled
		-- (Resurrection and cures, Asking for a buff, Battlegrounds and arenas).
		["who.curesHeader"] = true,
		-- "Thanks and speech": the fallback dialog's heading; the window titles
		-- the two halves (Thank-yous, A line when I buff).
		["click.speechHeader"] = true,
		["who.askHeader"] = true,
		["when.battleHeader"] = true,
		-- Its string is the Who to skip page's title.
		["who.skipHeader"] = true,
		-- "Icon and waiting list": the window gives the icon's fold and the
		-- waiting list titles of their own.
		["appearance.iconHeader"] = true,
		-- "Style", the fallback dialog's heading over the looks: the window
		-- heads the gallery Panel style and the look's own settings with its
		-- name (appearance.lookHeader).
		["appearance.styleHeader"] = true,
		-- "Messages in chat": Log every click joined Reporting a bug.
		["diagnostics.chatHeader"] = true,
	},
}

-- The short list's buffs: each buff's own switch, wherever the pages place
-- them.
do
	local keep = ns.WindowLayout.simple.items
	for _, page in pairs(ns.WindowLayout.pages) do
		for _, section in ipairs(page.sections) do
			for _, item in ipairs(section.items) do
				local path = type(item) == "table" and item[1] or item
				if type(path) == "string" and path:find("^who%.offer_") then
					keep[path] = true
				end
				-- "Keep thorns to myself": only me is already one of the choices.
				if type(path) == "string" and path:find("^who%.tank_") then
					local words = ns.WindowLayout.keywords
					if words[path] == nil then words[path] = L["only me myself tank tanks keep"] end
				end
			end
		end
	end
end
