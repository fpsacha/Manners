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
-- A section is { header = "tab.key" (the model header's name is its title) or
-- title = L[...], fold = true below the hairline, key = "<page>.<name>" (stable:
-- an open fold is remembered by it), items = { ... } }. An item is "tab.key"
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
-- the short list, the ten or so a player of this class changes. A control
-- left off it is still found by search, which opens the full view on it. The
-- window draws the view's own controls itself, from `menu`: the switch under
-- the search box, the offer over a page and what the short list leaves out
-- under it.
--
-- A section marked `home = true` is a home: it has a title and may have no
-- item yet, and a setting that arrives for what its comment names goes there,
-- so it is found where its kin are (other homes are a comment inside the
-- section the setting belongs to; grep HOME). A section with nothing to show
-- is not drawn.

local _, ns = ...
local L = ns.L

-- Only Interface\Icons: an atlas this client lacks draws as a green square.
local ICONS = {
	general = "Interface\\Icons\\INV_Misc_Map_01",
	who = "Interface\\Icons\\Spell_Holy_WordFortitude",
	skip = "Interface\\Icons\\Ability_Vanish",
	when = "Interface\\Icons\\INV_Misc_PocketWatch_01",
	click = "Interface\\Icons\\INV_Misc_Note_01",
	appearance = "Interface\\Icons\\Spell_Holy_MindVision",
	profiles = "Interface\\Icons\\INV_Misc_Head_Human_01",
	diagnostics = "Interface\\Icons\\INV_Misc_Spyglass_03",
}

-- The first spell in `spells` the client has a texture for. The probe asked
-- for each with C_Spell.GetSpellTexture, as the prompt's own icon is.
local function FirstIcon(spells)
	for _, spell in ipairs(spells or {}) do
		local info = ns.BuffInfo(spell)
		local icon = info and ns.plain(info.icon)
		if type(icon) == "number" or type(icon) == "string" then return icon end
	end
end

-- Who to buff shows the class's own first buff: Arcane Intellect for a mage,
-- Fortitude for a priest. A hunter has none for anybody else, so the first of
-- its own (an aspect); a class with neither, the fallback.
local function WhoIcon()
	local class = ns.caps and ns.caps.class
	local icon = FirstIcon(ns.GetClassBuffs(class))
	if not icon then
		local family = (ns.GetOwnFamilies(class) or {})[1]
		icon = family and FirstIcon(family.spells)
	end
	return icon or ICONS.who
end

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

-- What to cast: the buff dropdown, each buff's switch with its own under it,
-- then what is about all of them.
local function CastItems()
	local items, placed = { "who.choice" }, {}
	for _, item in ipairs(OfferItems(placed)) do items[#items + 1] = item end
	-- A paladin's: nobody another paladin has blessed.
	items[#items + 1] = "who.leaveBlessed"
	if not placed["who.skipCasters"] then items[#items + 1] = "who.skipCasters" end
	items[#items + 1] = "who.spareFishBowl"
	if not placed["who.relevantOnly"] then items[#items + 1] = "who.relevantOnly" end
	items[#items + 1] = { "who.autoNote", standIn = true }
	items[#items + 1] = "who.pinNote"
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
		snooze = { "general.snooze5", "general.snooze15", "general.snooze30", "general.snoozeStop" },
		snoozeTip = "general.snoozeNote",
	},
	strip = {
		lock = "general.lockNow",
		-- Line 2 in a fight: the open page's note.
		combat = { click = "click.combatNotice", appearance = "appearance.combatNotice", when = "advanced.advCombatNotice" },
	},
	foldCaption = "advanced.advIntro",
	-- The simple view's own controls: the switch under the search box; over a
	-- page, the line that offers the view to a profile from before it, with its
	-- two buttons; under a page's short list, what it leaves out and the way to
	-- it.
	menu = {
		simple = "general.simpleView",
		offer = "general.simpleOffer", try = "general.simpleTry", dismiss = "general.simpleDismiss",
		more = "general.simpleMore", everything = "general.showEverything",
	},
	-- `about`: who makes Manners, under the build on every page.
	footer = { reset = "advanced.resetAdvanced", build = "diagnostics.buildNote", about = "diagnostics.aboutNote" },

	-- The sidebar, top to bottom; a hairline between groups. Page ids are the
	-- old tab keys (bug reports and ns.OptionsTab() name them), plus skip.
	groups = { { "general" }, { "who", "skip", "when", "click", "appearance" }, { "profiles", "diagnostics" } },

	pages = {
		general = {
			title = L["Start here"],
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
					"general.milestones", { "general.milestoneToast", indent = true }, { "general.milestoneSound", indent = true },
				} },
				-- The hall of fame (Hall.lua), folded under the ledger it is
				-- earned by: how far along, the code once every milestone is
				-- earned (a box that only copies: WidgetsEntry.lua, READ_ONLY),
				-- and who is listed. The two notes keep the fold on the page
				-- while there is no code yet.
				{ key = "general.hall", header = "general.hallHeader", fold = true, items = {
					{ "general.hallNote", standIn = true },
					"general.hallCertificate",
					"general.hallCode",
					{ "general.hallList", standIn = true },
				} },
				-- Unfolded, and on the one page that never hides: the chat lines
				-- are what people look for when they annoy them.
				{ key = "general.minimap", header = "general.minimapHeader", items = {
					"general.minimap",
					"general.verbose",
					"general.silentChat",
					-- What /manners welcome says, again in the chat window, for
					-- somebody who skipped it: with the chat lines, under their heading.
					"general.welcomeAgain",
				} },
			},
		},

		who = {
			title = L["Who to buff"],
			icon = WhoIcon,
			sections = {
				-- Who the prompt is on right now, so a switch can be seen to work.
				{ key = "who.now", items = { "who.rightNow" } },
				-- Who first: the page is called Who to buff. Then what they get,
				-- the order it is tried in, and the group's own casts; your own
				-- buffs after everybody else's, in four sections that go together.
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
					{ "who.courtesyRefresh", indent = true },
					{ "who.courtesyPortals", indent = true },
					{ "who.courtesyHealthstones", indent = true },
					{ "who.courtesySummons", indent = true },
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
				{ key = "who.group", header = "who.groupHeader", items = {
					"who.groupBuffsUse",
					{ "who.groupBuffsAtLeast", indent = true },
					"who.reagentNote",
					{ "who.skipRaidGroups", columns = 4 },
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
				{ key = "who.beyond", title = L["More than buffs"], home = true, items = {
					-- Your resurrection for the group's dead (Resurrect.lua), and
					-- for a dead passer-by under it.
					"who.res",
					{ "who.resStrangers", indent = true },
					-- Cures (Cures.lua), for a class with one: which spell takes off
					-- what, the two switches, and the seconds a debuff must have
					-- left, which either switch governs: gone while both are off.
					"who.curesNote",
					"who.cures",
					"who.curesStrangers",
					{ "who.cureSeconds", indent = true },
				} },
				{ key = "who.myself", header = "who.myselfHeader", items = {
					"who.self",
					-- Only the families this character knows are shown (their own rule).
					{ "who.own_omen", indent = true },
					-- A druid's Moonkin Form, never asked for in another form.
					{ "who.own_moonkinform", indent = true },
					-- A druid's Tree of Life (Burning Crusade, Season of Discovery).
					{ "who.own_treeoflife", indent = true },
					{ "who.own_aspect", indent = true },
					{ "who.own_trueshot", indent = true },
					-- Season of Discovery's Heart of the Lion (Classic Era).
					{ "who.own_heartofthelion", indent = true },
					{ "who.own_armor", indent = true },
					-- A mage's Dampen Magic or Amplify Magic, off until picked.
					{ "who.own_magicmod", indent = true },
					{ "who.ownDampenAlone", indent = 2 },
					{ "who.ownAmplifyAlone", indent = 2 },
					{ "who.own_aura", indent = true },
					{ "who.own_righteousfury", indent = true },
					{ "who.own_innerfire", indent = true },
					{ "who.own_touchofweakness", indent = true },
					{ "who.own_shadowguard", indent = true },
					{ "who.own_shadowform", indent = true },
					{ "who.own_shield", indent = true },
					-- Season of Discovery's Spirit of the Alpha on a shaman who tanks.
					{ "who.own_spiritofthealpha", indent = true },
					{ "who.own_demonarmor", indent = true },
					-- A warlock's Grimoire of Sacrifice (Mists, retail).
					{ "who.own_grimoireofsacrifice", indent = true },
					-- A warlock's Demonic Sacrifice and Soul Link (Classic Era, Forever,
					-- Burning Crusade).
					{ "who.own_demonicsacrifice", indent = true },
					-- A warlock's Detect Invisibility, off until it is turned on.
					{ "who.own_detectinvis", indent = true },
					-- A warlock's Unending Breath on himself, only while he swims.
					{ "who.own_selfbreath", indent = true },
					{ "who.own_tracking", indent = true },
					-- Forever's Find Treasure, kept on beside a gathering tracking.
					{ "who.own_findtreasure", indent = true },
				} },
				{ key = "who.myselfWeapons", title = L["Weapons"], items = {
					-- A shaman's weapon imbues, spells: one a hand at a time.
					"who.own_shamanimbue",
					-- Retail's off hand: Flametongue beside Windfury, or a shield's ward.
					"who.own_shamanimbueoff",
					-- Imbues ahead of the shield, for a shaman short of mana.
					{ "who.ownImbueFirst", indent = 2 },
					-- A Lightsmith paladin's rites on the weapon (retail).
					"who.own_rite",
					-- What goes on a weapon from the bags, per hand, while there is
					-- one in them; a rogue's poisons as spells on Mists and retail.
					"who.own_poisonmain",
					"who.own_poisonoff",
					"who.own_lethal",
					"who.own_nonlethal",
					"who.own_stonemain",
					"who.own_stoneoff",
					"who.own_oilmain",
					"who.own_oiloff",
					-- A warlock's Firestone or Spellstone on the main hand (Forever).
					"who.own_warlockstone",
					"who.own_lure",
				} },
				{ key = "who.myselfItems", title = L["Food, flasks and scrolls"], items = {
					-- Food that gives Well Fed, off until it is turned on; every class has it.
					-- The foods to leave out right under it.
					"who.own_food",
					-- Which food, asked for on CurseForge: the best, the weakest, or one by name.
					{ "who.ownFoodChoice", indent = true },
					{ "who.own_leave_food", indent = true },
					-- The sleeping bag's Well-Rested, off until it is turned on;
					-- shown while the bag is in the bags (Classic Era, Forever).
					"who.own_rested",
					-- A companion pet, off until it is turned on; shown while one is in
					-- the bags or (Forever) the pet journal. Which pet, under it.
					-- HOME: companion pets (the journal's reminder on Mists and
					-- retail, and anything more about them) go here, with these two.
					"who.own_pet",
					{ "who.ownPetChoice", indent = true },
					-- Flasks, elixirs and a scroll of each stat, off until turned on;
					-- shown while one is in the bags (Buffs.lua, CONSUME).
					"who.own_flask",
					"who.own_elixir",
					-- Every scroll at once, then each scroll's own switch under it, one
					-- step further in: off, those switches are gone (Options/Who.lua,
					-- ownScrolls).
					"who.ownScrolls",
					{ "who.own_scrollagility", indent = true },
					{ "who.own_scrollstrength", indent = true },
					{ "who.own_scrollprotection", indent = true },
					{ "who.own_scrollintellect", indent = true },
					{ "who.own_scrollstamina", indent = true },
					{ "who.own_scrollspirit", indent = true },
					-- A mage's scrolls on Forever, while there is one in the bags.
					{ "who.own_familiar", indent = true },
					{ "who.own_imbue", indent = true },
				} },
				{ key = "who.myselfWhen", title = L["When my own buffs come up"], items = {
					-- Where the reminders come up.
					"who.ownCities",
					"who.ownDungeons",
					-- The consumables on a button of their own (Prompt/Supplies.lua).
					"who.ownApart",
					-- A warrior's shout for himself, alone (shown to a warrior only).
					"who.ownShout",
					-- The spells of those families you know, to leave out one by one.
					"who.own_leave",
					-- Why a buff of your own is not being offered, under the switches.
					"diagnostics.ownDiag",
				} },
				-- HOME: asking for a buff (what you want from other people, and
				-- how it is asked) goes here: it is about you, like the four
				-- sections above it.
				-- Asking, not only giving (Ask.lua): the switch, and under it how
				-- the ask is said, gone while it is off.
				{ key = "who.asking", title = L["Asking for a buff"], home = true, items = {
					"who.ask",
					{ "who.askChannel", indent = true },
					{ "who.askLine", indent = true },
					{ "who.askInTowns", indent = true },
				} },
				{ key = "who.first", header = "who.firstHeader", fold = true, items = {
					"who.target",
					"who.friends",
					"who.readyCheck",
					"who.revived",
				} },
			},
		},

		-- Every "Skip ..." switch and the never-offer list, out of Who to buff.
		-- Its title is the old Who to skip header's string.
		skip = {
			title = L["Who to skip"],
			icon = ICONS.skip,
			sections = {
				{ key = "skip.now", items = { "who.rightNowSkip" } },
				{ key = "skip.lead", title = L["Players to skip"], items = {
					"who.skipPvP",
					-- Who that switch holds back right now, under it.
					{ "diagnostics.pvpDiag", indent = true },
					"who.skipSameClass",
					"who.skipGuilds",
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
				} },
			},
		},

		when = {
			title = L["When to offer"],
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
				{ key = "when.self", header = "when.selfHeader", items = {
					"when.selfTopUp",
					{ "when.selfLead", indent = true },
					{ "when.selfLeadNote", indent = true },
				} },
				-- The place rules lead Hold back: they hold back everybody, so
				-- they are not items of the list of people on Who to buff.
				{ key = "when.holdBack", header = "when.wayHeader", items = {
					"who.quietInTowns",
					-- Cities and inns, cities only or inns only.
					{ "who.quietInTownsWhere", indent = true },
					-- Only the short buffs, where the rule above holds everything.
					"who.quietShortInTowns",
					{ "who.quietShortMinutes", indent = true },
					"who.quietInInstances",
					"who.quietTargets",
				} },
				{ key = "when.holdBack2", title = L["Mounted and mana"], items = {
					"when.hideMounted",
					"when.manaFloor",
					-- What it still offers below it: favours and requests, your
					-- own buff only, or nothing.
					{ "when.manaFloorKeeps", indent = true },
					"when.manaNote",
				} },
				-- HOME: battlegrounds and arenas (what is offered there, and to
				-- whom) go here: a place rule, beside Hold back's. Four switches
				-- of their own (Battle.lua), which decide there.
				{ key = "when.battle", title = L["Battlegrounds and arenas"], home = true, items = {
					"when.battleTeam",
					"when.battleSpeak",
					"when.battleThank",
					"when.battleItems",
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
					"advanced.skipSeconds",
					"advanced.scanInterval",
				} },
				{ key = "when.targeting", header = "advanced.targetingHeader", fold = true, items = {
					"advanced.restoreTarget",
					-- A warrior's: the switch is hidden, the note says why.
					{ "advanced.noTargetNote", standIn = true },
				} },
			},
		},

		click = {
			title = L["What I say"],
			icon = ICONS.click,
			sections = {
				-- The quick choice, directly above the switches it sets.
				{ key = "click.lead", items = {
					"general.quickVoice",
					"general.quickVoiceSummary",
				} },
				{ key = "click.speech", header = "click.speechHeader", items = {
					"click.thankEmote",
					{ "click.thankEmoteToken", indent = true },
					-- Others to pick from, under the one picked.
					{ "click.thankEmoteMore", indent = 2, columns = 4 },
					-- The pause before the /thank and the whisper alike.
					{ "click.thankDelay", indent = true },
					"click.thankWhisper",
					"click.enabled",
					{ "click.channel", indent = true },
					{ "click.onlyWhenReturning", indent = true },
					-- While speaking with friendly nameplates off (Speech.lua).
					{ "click.platesNote", indent = true },
					{ "click.showPlates", indent = true },
					{ "click.linesOff", standIn = true },
				} },
				{ key = "click.lines", header = "click.phrasesHeader", items = {
					"click.preset",
					"click.phrasesHelp",
					"click.inCharacterNote",
					"click.phrases",
					-- Your own lines among the In character ones, while that is the set.
					"click.mixedLines",
					{ "click.backToInCharacter", pair = true },
					"click.roll",
					"click.limits",
				} },
			},
		},

		-- Everything about the prompt itself; the wording and the exact
		-- position fold here rather than living on a page of their own.
		appearance = {
			title = L["Look"],
			icon = ICONS.appearance,
			sections = {
				-- The look to wear, as a gallery of cards (WidgetsTheme.lua) in
				-- place of the model's dropdown, which the fallback dialog keeps.
				{ key = "appearance.themes", title = L["Panel style"], items = {
					{ "appearance.style", widget = "themes" },
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
					{ "appearance.width", pair = true },
					"appearance.height",
				} },
				{ key = "appearance.attention", header = "appearance.attentionHeader", items = {
					{ "appearance.flashStyle", pair = true },
					"appearance.effects",
					"appearance.soundEnabled",
					{ "appearance.soundFile", indent = true },
					{ "appearance.soundOwedOnly", indent = true },
					"appearance.noSound",
				} },
				-- What the prompt does when a fight starts, together.
				{ key = "appearance.fight", title = L["In a fight"], items = {
					"appearance.hideInFight",
					"appearance.fightRota",
					"appearance.hideInCombat",
					"appearance.dimInCombat",
				} },
				-- The names waiting after the first, out of the icon's fold: the
				-- clickable list is a feature people look for, not a fine-tune.
				{ key = "appearance.queue", title = L["Waiting list"], items = {
					"appearance.showCount",
					"appearance.showQueue",
					{ "appearance.queueRows", indent = true },
					{ "appearance.clickRows", indent = true },
				} },
				-- The pane's and the marker's colours: every look comes with its own,
				-- so they are fine print, folded, first under the hairline. With the
				-- gallery's nineteen cards above, this keeps Look to three screens.
				{ key = "appearance.style", header = "appearance.styleHeader", fold = true, items = {
					{ "appearance.bgColor", pair = true },
					"appearance.accentByReason",
					-- With Colour marker, whatever else shows: Marker colour
					-- follows on a row of its own while Colour marker by
					-- reason is off.
					{ "appearance.reasonPalette", pair = true },
					"appearance.accentMode",
					"appearance.accentColor",
					"appearance.accentDead",
				} },
				{ key = "appearance.exactPos", header = "advanced.exactPosHeader", fold = true, items = {
					{ "advanced.x", widget = "number", pair = true },
					{ "advanced.y", widget = "number" },
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
					"appearance.showIcon",
					{ "appearance.iconSize", indent = true },
					"appearance.iconSizeCapped",
					"appearance.suppliesSize",
					{ "appearance.roundIcon", indent = true },
					{ "appearance.iconFrame", indent = true },
					{ "appearance.gryphons", indent = true },
					{ "appearance.showCooldown", indent = true },
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
		},

		profiles = {
			title = L["Profiles"],
			icon = ICONS.profiles,
			sections = {
				-- AceDBOptions' own entries (current to reset) with its grey
				-- descriptions beside the controls they explain.
				{ key = "profiles.lead", items = {
					"profiles.profilesIntro",
					"general.sharedNote",
					"general.ownProfile",
					"profiles.current",
					"profiles.choosedesc",
					{ "profiles.new", pair = true },
					"profiles.choose",
					"profiles.copydesc",
					"profiles.copyfrom",
					"profiles.deldesc",
					"profiles.delete",
					"profiles.descreset",
					"profiles.reset",
				} },
				{ key = "profiles.share", header = "profiles.shareHeader", items = {
					"profiles.shareNote",
					"profiles.shareCopy",
					"profiles.shareText",
					"profiles.sharePaste",
					"profiles.shareUndo",
				} },
			},
		},

		diagnostics = {
			title = L["Diagnostics"],
			icon = ICONS.diagnostics,
			sections = {
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
					-- Which of the two buttons a player asked for a report wants.
					"diagnostics.reportHint",
					-- The one press a player asked for a report needs.
					{ "diagnostics.fullReport", big = true },
					{ "diagnostics.copyReport", buttons = true },
					-- /manners selftest launch, beside the short summary.
					{ "diagnostics.launchCheck", buttons = true },
					"diagnostics.report",
					"diagnostics.selftest",
					-- For working out a failed cast: under the buttons.
					"diagnostics.debugClicks",
				} },
			},
		},
	},

	-- The simple view's short list. `pages` are drawn whole: Start here is the
	-- short list already, and Profiles and Diagnostics are not settings to
	-- thin out. Every buff's own switch (who.offer_*) and every own-buff family
	-- (who.own_*, but not what to leave out) are added under the table.
	simple = {
		pages = { general = true, profiles = true, diagnostics = true },
		items = {
			-- Who to buff: who gets it, which buff, and yourself.
			["who.rightNow"] = true, ["who.emptyWarning"] = true,
			["who.owed"] = true, ["who.group"] = true, ["who.strangers"] = true,
			["who.strangersPlatesNote"] = true, ["who.strangersShowPlates"] = true, ["who.strangersNote"] = true,
			["who.asked"] = true,
			-- A class's own courtesies under it (two at most for any class),
			-- its resurrection, its cure for the group, and asking for a buff.
			["who.courtesyRefresh"] = true, ["who.courtesyPortals"] = true,
			["who.courtesyHealthstones"] = true, ["who.courtesySummons"] = true,
			["who.res"] = true, ["who.cures"] = true, ["who.ask"] = true,
			["who.choice"] = true, ["who.autoNote"] = true, ["who.pinNote"] = true,
			["who.self"] = true,
			-- Also in cities and inns: the tick the line said once at an inn names
			-- (Hints.lua), and the answer to "nothing comes up when I log in".
			["who.ownCities"] = true,
			-- Scrolls: the switch each scroll's own (who.own_*, added below) is
			-- indented under, and the only way back to them once it is off.
			["who.ownScrolls"] = true,
			-- Who to skip.
			["who.rightNowSkip"] = true, ["who.skipPvP"] = true, ["who.skipSameClass"] = true,
			["who.minLevel"] = true, ["who.neverAdd"] = true,
			-- When to offer.
			["when.rightNow"] = true, ["when.whenBuffed"] = true, ["when.alwaysNote"] = true,
			["when.selfTopUp"] = true,
			["who.quietInTowns"] = true, ["who.quietInInstances"] = true,
			["when.hideMounted"] = true, ["when.manaFloor"] = true,
			-- Whether the team is buffed in a battleground at all.
			["when.battleTeam"] = true,
			-- What I say.
			["general.quickVoice"] = true, ["general.quickVoiceSummary"] = true,
			["click.thankEmote"] = true, ["click.thankWhisper"] = true, ["click.enabled"] = true,
			["click.channel"] = true, ["click.platesNote"] = true, ["click.showPlates"] = true,
			["click.linesOff"] = true, ["click.preset"] = true, ["click.phrasesHelp"] = true,
			["click.inCharacterNote"] = true, ["click.phrases"] = true,
			-- Look.
			["appearance.style"] = true, ["appearance.move"] = true, ["appearance.posPreset"] = true,
			["appearance.scale"] = true, ["appearance.alpha"] = true,
			["appearance.soundEnabled"] = true, ["appearance.soundFile"] = true,
			["appearance.hideInFight"] = true, ["appearance.showQueue"] = true,
		},
	},

	-- The sections that run the page's whole width when it has columns: what
	-- a page opens with, read before the columns under it.
	spans = {
		["general.lead"] = true,
		["who.now"] = true,
		["skip.now"] = true,
		["when.now"] = true,
	},

	-- How a note is drawn when not in the label colour: grey (a colour code
	-- in its text still wins), or grey in a block inset from the page. Kept
	-- apart from the items, which say where a row goes rather than how it
	-- looks.
	notes = {
		["who.autoNote"] = { hint = true },
		-- Start here, step 2: whether there is a key, in a block that leads the step.
		["general.bindStatus"] = { block = true },
		["diagnostics.ownDiag"] = { hint = true, block = true },
		["diagnostics.pvpDiag"] = { hint = true, block = true },
		["diagnostics.leadDiag"] = { hint = true, block = true },
		["diagnostics.reportHint"] = { hint = true },
		["when.selfLeadNote"] = { hint = true },
		["who.minLevelNote"] = { hint = true },
		-- AceDBOptions' descriptions, beside the controls they explain.
		["profiles.choosedesc"] = { hint = true },
		["profiles.copydesc"] = { hint = true },
		["profiles.deldesc"] = { hint = true },
		["profiles.descreset"] = { hint = true },
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
				return L["Off while %s is on (%s)."]:format(NameOf("who.quietInTowns"), L["When to offer"])
			end
			return L["Needs %s ticked."]:format(NameOf("who.strangers"))
		end,
		["when.battleItems"] = function() return L["Needs %s ticked."]:format(NameOf("who.ownDungeons")) end,
		["appearance.flashStyle"] = L["Needs the icon, the stripe or Full animations."],
	},

	-- Other words people search for a control by (WindowSearch.lua): ranked
	-- with its choices, matched at the start of a word. One string a control,
	-- translated as a whole.
	keywords = {
		["general.silentChat"] = L["quiet mute spam"],
		["general.verbose"] = L["quiet mute spam"],
		["who.ownScrolls"] = L["hide familiar imbue"],
		-- Asked for as hiding "the window" in a fight.
		["appearance.hideInFight"] = L["window frame invisible fight"],
		-- Asked for as moving "the bar".
		["appearance.moveInEditMode"] = L["bar position drag place"],
	},

	-- A control hidden until a switch is on, and that switch: search finds the
	-- control and opens the switch, saying to turn it on first.
	parents = {
		["click.preset"] = "click.enabled",
		["click.phrases"] = "click.enabled",
		["click.mixedLines"] = "click.enabled",
		["click.roll"] = "click.enabled",
		-- My group's pets too, shown only while My party and raid is on.
		["who.pets"] = "who.group",
		-- A class's courtesies, shown only while People who ask me in chat is on.
		["who.courtesyRefresh"] = "who.asked",
		["who.courtesyPortals"] = "who.asked",
		["who.courtesyHealthstones"] = "who.asked",
		["who.courtesySummons"] = "who.asked",
		-- Dead passers-by too, shown only while My group's dead is on.
		["who.resStrangers"] = "who.res",
		-- How an ask is said, shown only while asking is on.
		["who.askChannel"] = "who.ask",
		["who.askLine"] = "who.ask",
		["who.askInTowns"] = "who.ask",
		-- Share the group with other Manners users, the same.
		["who.share"] = "who.group",
		-- Detect Invisibility to passers-by too, shown only once the buff is ticked.
		["who.passers_detectgroup"] = "who.offer_detectgroup",
	},

	-- In the model and drawn nowhere.
	unplaced = {
		-- AceDBOptions' opening paragraph, hidden today: profilesIntro says it.
		["profiles.desc"] = true,
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
		-- (More than buffs, Asking for a buff, Battlegrounds and arenas).
		["who.curesHeader"] = true,
		["who.askHeader"] = true,
		["when.battleHeader"] = true,
		-- Its string is the Who to skip page's title.
		["who.skipHeader"] = true,
		-- "Icon and waiting list": the window gives the icon's fold and the
		-- waiting list titles of their own.
		["appearance.iconHeader"] = true,
		-- "Messages in chat": Log every click joined Reporting a bug.
		["diagnostics.chatHeader"] = true,
	},
}

-- The short list's buffs: each buff's own switch, and each family of the
-- player's own buffs (its dropdown or its switch), wherever the pages place
-- them. Not the lists of what to leave out, which are fine print.
do
	local keep = ns.WindowLayout.simple.items
	for _, page in pairs(ns.WindowLayout.pages) do
		for _, section in ipairs(page.sections) do
			for _, item in ipairs(section.items) do
				local path = type(item) == "table" and item[1] or item
				if type(path) == "string" and (path:find("^who%.offer_")
					or (path:find("^who%.own_") and not path:find("^who%.own_leave"))) then
					keep[path] = true
				end
			end
		end
	end
end
