-- The options window class by class: IA 1.11's table as checks (which pages
-- each class has, and what changes on them), the note rule that keeps a
-- section on screen, the sidebar's red dots, and every page built in English
-- and German for six classes without an error.
--
-- None of it is special-cased in the window: every line follows from the
-- visibility rules in IA 1.5, which is what these hold it to.
--
-- Every scenario name starts with "window:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell" }

local HAWK, MONKEY = 13165, 13163

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- What each class knows: its buffs by key (every rank), or spell ids.
local CLASSES = {
	MAGE = {},
	PRIEST = { buffs = { "fortitude", "spirit", "shadow" } },
	PALADIN = { buffs = { "wisdom", "might", "kings", "salvation", "light", "sanctuary" } },
	WARRIOR = { buffs = { "battleshout" } },
	HUNTER = { known = { HAWK, MONKEY } },
	ROGUE = {},
}

local function with(scenario, class, locale, body)
	Mock.reset()
	Mock.class, Mock.locale = class, locale
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local spec = CLASSES[class] or {}
		if spec.buffs or spec.known then
			local set = {}
			for _, id in ipairs(spec.known or {}) do set[id] = true end
			for _, key in ipairs(spec.buffs or {}) do
				local buff = ns.FindBuff(class, key)
				for _, id in ipairs(buff and buff.ranks or {}) do set[id] = true end
			end
			IsSpellKnown = function(id) return set[id] == true end
			IsPlayerSpell = IsSpellKnown
		end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		ns.Prompt:ExitTest()
		noErrors(scenario, ns)
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function shown(frame) return frame ~= nil and frame:IsShown() == true end

local function sidebar(ns)
	local UI, out = ns.WindowUI, {}
	for _, group in ipairs(ns.WindowLayout.groups) do
		for _, id in ipairs(group) do
			if (UI.visiblePages or {})[id] then out[#out + 1] = id end
		end
	end
	return table.concat(out, " ")
end

-- Opens the fold a path is in, so its rows are drawn.
local function unfold(ns, path)
	local UI = ns.WindowUI
	local w = UI.Where(path)
	if w and w.sec.fold then UI.State().open[w.sec.key] = true end
	ns.RefreshOptionsDisplay()
end

local ALL = "general who skip when click appearance profiles diagnostics"

-- ------------------------------------------------------------------ IA 1.11
local TABLE = {
	{ "MAGE", ALL, function(scenario, ns, UI)
		ns.OpenOptions("who")
		if UI.Where("who.offer_fortitude") then fail(scenario, "a mage has per-spell switches") end
		if not UI.RowShown("who.relevantOnly") then fail(scenario, "a mage has no Skip players it does nothing for") end
		if not UI.RowShown("who.autoNote") then fail(scenario, "a mage is not told what she offers") end
		ns.OpenOptions("when")
		for _, path in ipairs({ "advanced.retryCooldown", "advanced.restoreTarget" }) do
			unfold(ns, path)
			if not UI.RowShown(path) then fail(scenario, path .. " is not on When to offer for a mage") end
		end
	end },
	{ "PRIEST", ALL, function(scenario, ns, UI)
		ns.OpenOptions("who")
		for _, key in ipairs({ "fortitude", "spirit", "shadow" }) do
			if not UI.RowShown("who.offer_" .. key) then fail(scenario, "a priest has no switch for " .. key) end
		end
	end },
	{ "PALADIN", ALL, function(scenario, ns, UI)
		ns.OpenOptions("who")
		for _, key in ipairs({ "wisdom", "might", "kings", "salvation", "light", "sanctuary" }) do
			if not UI.RowShown("who.offer_" .. key) then fail(scenario, "a paladin has no switch for " .. key) end
		end
	end },
	{ "WARRIOR", ALL, function(scenario, ns, UI)
		ns.OpenOptions("who")
		-- The note stands in: What to cast is the sentence alone.
		if not UI.RowShown("who.autoNote") then fail(scenario, "a warrior's What to cast is gone") end
		if UI.RowShown("who.choice") then fail(scenario, "a warrior with one buff is offered a choice") end
		if UI.RowShown("who.strangers") or not UI.RowShown("who.strangersNote") then
			fail(scenario, "a warrior has the passer-by rows instead of the note")
		end
		-- The switch xor the note, in the Targeting fold.
		ns.OpenOptions("when")
		unfold(ns, "advanced.noTargetNote")
		if UI.RowShown("advanced.restoreTarget") or not UI.RowShown("advanced.noTargetNote") then
			fail(scenario, "a warrior's Targeting fold does not hold the note in place of the switch")
		end
	end },
	{ "HUNTER", "general who when appearance profiles diagnostics", function(scenario, ns, UI)
		ns.OpenOptions("general")
		if UI.RowShown("general.quickWho") or not UI.RowShown("general.quickWhoSummary") then
			fail(scenario, "a hunter's step 1 is not the own-buff sentence standing in")
		end
		ns.OpenOptions("when")
		if UI.RowShown("advanced.reciprocateWindow") then fail(scenario, "a hunter has Favours") end
		local targeting = UI.Where("advanced.restoreTarget")
		if targeting and targeting.sec.visible then fail(scenario, "a hunter has a Targeting fold") end
		unfold(ns, "advanced.retryCooldown")
		if not UI.RowShown("advanced.retryCooldown") then fail(scenario, "a hunter has no Timing") end
		if not (shown(UI.header.preview) and shown(UI.header.snooze)) then
			fail(scenario, "a hunter's header lacks the preview or Snooze")
		end
	end },
	{ "ROGUE", "general profiles diagnostics", function(scenario, ns, UI)
		ns.OpenOptions("general")
		if not UI.RowShown("general.noBuffs") then fail(scenario, "a rogue's Start here does not lead with noBuffs") end
		if shown(UI.header.preview) or shown(UI.header.snooze) then fail(scenario, "a rogue has a preview or Snooze") end
		if not shown(UI.header.enabled and UI.header.enabled.frame) then fail(scenario, "a rogue has no master switch") end
		if (UI.strip.height or 0) > 0 then fail(scenario, "a rogue carries a strip: " .. tostring(UI.strip.line)) end
		for _, id in ipairs({ "general", "profiles", "diagnostics" }) do
			ns.OpenOptions(id)
			if shown(UI.footer.reset) then fail(scenario, "a rogue has a reset button on " .. id) end
		end
		ns.OpenOptions("diagnostics")
		if not UI.RowShown("diagnostics.noDiag") then fail(scenario, "a rogue's Diagnostics does not show noDiag") end
	end },
}

for _, case in ipairs(TABLE) do
	local class, want, more = case[1], case[2], case[3]
	local scenario = "window: the class table (" .. class .. ")"
	with(scenario, class, nil, function(ns, UI)
		ns.OpenOptions()
		local has = sidebar(ns)
		if has ~= want then fail(scenario, "the sidebar is " .. has .. ", not " .. want) end
		more(scenario, ns, UI)
	end)
end

-- ------------------------------------------------------------------ note rule
-- Attached notes never keep a section, or a page, by themselves.
do
	local scenario = "window: a note keeps its section only when it stands in or the section has no controls"
	with(scenario, "HUNTER", nil, function(ns, UI)
		ns.OpenOptions("general")
		-- Start here's lead holds no controls, so its notes keep it; Who to
		-- skip's PvP lines are attached, so a hunter has no Who to skip.
		if (UI.visiblePages or {}).skip then fail(scenario, "Who to skip is kept for a hunter by a note") end
		local w = UI.Where("general.howItWorks")
		if w and UI.EntryShown(w.e) and not w.sec.visible then
			fail(scenario, "Start here's lead, which holds no controls, is gone with its sentence shown")
		end
		ns.OpenOptions("diagnostics")
		local see = UI.Where("diagnostics.diag")
		if see and not see.sec.visible then fail(scenario, "What Manners can see is gone though it holds only notes") end
		-- Who to buff is Myself alone: no other section is kept on screen by
		-- a note attached to controls the hunter does not have.
		ns.OpenOptions("who")
		local mine = UI.Where("who.self")
		if mine and not mine.sec.visible then fail(scenario, "a hunter's Myself is gone") end
		for _, sec in ipairs(UI.Model("who").sections) do
			if sec.visible and sec ~= (mine and mine.sec) then
				fail(scenario, "a hunter's Who to buff shows " .. sec.key .. " beside Myself")
			end
		end
	end)
end

-- A page made up for the purpose, so each rule is met head on: an attached
-- note beside a hidden control, a note standing in for one, a section of
-- notes alone, a pair that fits half the width, and an indented row.
do
	local scenario = "window: sections follow the note rule, pairs share a row, indents step in"
	with(scenario, "MAGE", nil, function(ns, UI)
		local function toggle(name, hidden)
			return { type = "toggle", name = name, hidden = hidden and function() return true end or nil,
				get = function() return true end, set = function() end }
		end
		ns.optionsTable.args.zz = { type = "group", name = "zz", args = {
			ctl = toggle("Gone", true), note = { type = "description", name = "Attached to Gone." },
			ctl2 = toggle("Also gone", true), stand = { type = "description", name = "Standing in." },
			alone = { type = "description", name = "A note in a section of notes." },
			live = toggle("Live"), live2 = toggle("Live too"), deep = toggle("Deep"),
		} }
		ns.WindowLayout.pages.zz = { title = "Zz", sections = {
			{ key = "zz.one", title = "One", items = { "zz.ctl", "zz.note" } },
			{ key = "zz.two", title = "Two", items = { "zz.ctl2", { "zz.stand", standIn = true } } },
			{ key = "zz.three", title = "Three", items = { "zz.alone" } },
			{ key = "zz.four", title = "Four", items = { { "zz.live", pair = true }, "zz.live2", { "zz.deep", indent = true } } },
		} }
		local groups = ns.WindowLayout.groups
		groups[#groups][#groups[#groups] + 1] = "zz"
		ns.OpenOptions("zz")
		if ns.OptionsTab() ~= "zz" then
			fail(scenario, "SKIPPED -- the made-up page did not open")
			return
		end
		if UI.RowShown("zz.note") then fail(scenario, "an attached note kept a section whose control is hidden") end
		if not UI.RowShown("zz.stand") then fail(scenario, "a note standing in for a hidden control lost its section") end
		if not UI.RowShown("zz.alone") then fail(scenario, "a section of notes alone is gone") end
		local live, live2, deep = UI.Where("zz.live").e, UI.Where("zz.live2").e, UI.Where("zz.deep").e
		if live.y ~= live2.y or not (live2.x > live.x) then fail(scenario, "two short toggles marked pair do not share a row") end
		if deep.x ~= live.x + 16 then fail(scenario, ("an indented row starts at %s, not %s"):format(tostring(deep.x), tostring(live.x + 16))) end
		ns.CloseOptions()
		table.remove(groups[#groups])
		ns.WindowLayout.pages.zz, ns.optionsTable.args.zz = nil, nil
	end)
end

-- ------------------------------------------------------------------ pairs
-- A pair's partner is the item after it, not whatever shows next: Look's
-- Reason colours sits beside Colour marker whether or not Marker colour shows,
-- and a run of pairs (the reason boxes) puts its shown items two to a row, so
-- a hunter's own-buff and top-up boxes still share one.
local function sameRow(a, b) return a and b and a.e.y == b.e.y and b.e.x > a.e.x end

do
	local scenario = "window: a pair keeps its partner, and a run of pairs closes up round hidden items"
	with(scenario, "MAGE", nil, function(ns, UI)
		ns.db.profile.prompt.accentByReason = false
		ns.OpenOptions("appearance")
		local palette, mode, colour = UI.Where("appearance.reasonPalette"), UI.Where("appearance.accentMode"),
			UI.Where("appearance.accentColor")
		if not (UI.RowShown("appearance.reasonPalette") and UI.RowShown("appearance.accentMode")
			and UI.RowShown("appearance.accentColor")) then
			fail(scenario, "SKIPPED -- Reason colours, Colour marker or Marker colour is not shown")
		else
			if not sameRow(palette, mode) then fail(scenario, "Reason colours and Colour marker do not share a row") end
			if not (colour.e.y >= math.max(palette.e.y + palette.e.h, mode.e.y + mode.e.h)) then
				fail(scenario, "Marker colour is not on a row of its own under them")
			end
		end
	end)
	with(scenario, "HUNTER", nil, function(ns, UI)
		ns.OpenOptions("appearance")
		unfold(ns, "advanced.reasonSelf")
		local mine, topUp = UI.Where("advanced.reasonSelf"), UI.Where("advanced.reasonRefresh")
		if not (UI.RowShown("advanced.reasonSelf") and UI.RowShown("advanced.reasonRefresh")) then
			fail(scenario, "SKIPPED -- a hunter's own-buff or top-up box is not shown")
		elseif UI.RowShown("advanced.reasonOwed") then
			fail(scenario, "SKIPPED -- a hunter has Reason text: buffed me")
		elseif not sameRow(mine, topUp) then
			fail(scenario, "a hunter's two reason boxes do not share a row")
		end
	end)
end

-- Two side by side line up their controls, not their tops: Lock position's
-- box level with the dropdown beside it rather than with that dropdown's
-- label (Panel colour's swatch beside Panel style goes the same way).
do
	local scenario = "window: a switch or a swatch beside a dropdown sits level with the dropdown"
	with(scenario, "MAGE", nil, function(ns, UI)
		ns.OpenOptions("appearance")
		local function middle(e) return e.y + (e.row.fieldTop or 0) + (e.row.fieldHeight or 0) / 2 end
		for _, pair in ipairs({ { "appearance.posPreset", "appearance.locked" } }) do
			local field, beside = UI.Where(pair[1]), UI.Where(pair[2])
			if not (UI.RowShown(pair[1]) and UI.RowShown(pair[2])) then
				fail(scenario, "SKIPPED -- " .. pair[1] .. " or " .. pair[2] .. " is not shown")
			elseif not (beside.e.x > field.e.x) then
				fail(scenario, "SKIPPED -- " .. pair[2] .. " is not beside " .. pair[1])
			elseif math.abs(middle(field.e) - middle(beside.e)) > 1 or not (beside.e.y > field.e.y) then
				fail(scenario, ("%s sits at %s, level with %s's label rather than its field (%s)"):format(
					pair[2], tostring(middle(beside.e)), pair[1], tostring(middle(field.e))))
			end
		end
	end)
end

-- ------------------------------------------------------------------ notes
-- IA section 2's grey notes are grey (a colour code in the text still wins),
-- and the Myself and PvP lines are a grey block inset from the page; a plain
-- note is in the label colour.
do
	local scenario = "window: grey notes are grey, and the Myself and PvP lines are a block"
	with(scenario, "MAGE", nil, function(ns, UI)
		local T = ns.WindowWidgets.Theme
		ns.OpenOptions("general")
		ns.OpenOptions("who")
		ns.OpenOptions("skip")
		local function colour(path)
			local row = UI.RowFor(path)
			return row and row.text and row.text._textColor
		end
		local function is(c, want) return c and math.abs(c[1] - want[1]) < 1e-6 and math.abs(c[2] - want[2]) < 1e-6 end
		for _, path in ipairs({ "who.autoNote", "diagnostics.ownDiag", "diagnostics.pvpDiag" }) do
			if not UI.RowFor(path) then
				fail(scenario, "SKIPPED -- no row for " .. path)
			elseif not is(colour(path), T.hint) then
				fail(scenario, path .. " is not grey")
			end
		end
		for _, path in ipairs({ "diagnostics.ownDiag", "diagnostics.pvpDiag" }) do
			local row = UI.RowFor(path)
			if row and not (row.well and row.wellRule) then fail(scenario, path .. " is not drawn as a block") end
		end
		if not is(colour("general.howItWorks"), T.ink) then fail(scenario, "Start here's lead is not in the label colour") end
		local auto = UI.RowFor("who.autoNote")
		if auto and auto.well then fail(scenario, "a grey note that is not a block has a well") end
	end)
end

-- ------------------------------------------------------------------ red dots
do
	local scenario = "window: a page's red dot follows its warning, and a warning that throws is named"
	with(scenario, "MAGE", nil, function(ns, UI)
		local Page = ns.OptionsPage
		local real = Page.Warn
		ns.OpenOptions()
		local buttons = UI.side.buttons
		-- With the model's own: no key and no macro is Start here's warning.
		if real and real.general then
			if not shown(buttons.general.dot) then fail(scenario, "no key and no macro, and Start here has no red dot") end
		end
		local on = { who = true }
		Page.Warn = {}
		for _, id in ipairs({ "general", "who", "when", "appearance", "diagnostics" }) do
			Page.Warn[id] = function() return on[id] end
		end
		ns.RefreshOptionsDisplay()
		if not shown(buttons.who.dot) or shown(buttons.general.dot) then fail(scenario, "the red dots do not follow Page.Warn") end
		on.who, on.general = nil, true
		ns.RefreshOptionsDisplay()
		if shown(buttons.who.dot) or not shown(buttons.general.dot) then fail(scenario, "the red dots did not move with the warnings") end
		Page.Warn.when = function() error("warning broke", 0) end
		local ok = pcall(ns.RefreshOptionsDisplay)
		Page.Warn = real
		if not ok then fail(scenario, "a warning that throws took the repaint down") end
		local named = false
		for i = #ns.errors, 1, -1 do
			if tostring(ns.errors[i].where):find("red dot", 1, true) then
				named = true
				table.remove(ns.errors, i)
			end
		end
		if not named then fail(scenario, "a warning that throws was not named in /manners errors") end
	end)
end

-- ------------------------------------------------------------------ builds
-- Every page and every fold, opened and painted, with a search run over
-- them: nothing may throw or be caught by the guard.
for _, locale in ipairs({ "enUS", "deDE" }) do
	for _, class in ipairs({ "MAGE", "PRIEST", "PALADIN", "WARRIOR", "HUNTER", "ROGUE" }) do
		local scenario = ("window: every page builds (%s, %s)"):format(locale, class)
		with(scenario, class, locale, function(ns, UI)
			ns.OpenOptions()
			local pages = 0
			for _, group in ipairs(ns.WindowLayout.groups) do
				for _, id in ipairs(group) do
					if (UI.visiblePages or {})[id] then
						ns.OpenOptions(id)
						for _, sec in ipairs(UI.Model(id).sections) do
							if sec.fold then UI.State().open[sec.key] = true end
						end
						ns.RefreshOptionsDisplay()
						pages = pages + 1
						local drawn = false
						for _, sec in ipairs(UI.Model(id).sections) do
							for _, e in ipairs(sec.entries) do drawn = drawn or UI.RowShown(e.path) end
						end
						if not drawn then fail(scenario, id .. " is in the sidebar and draws no row") end
					end
				end
			end
			if pages < 3 then fail(scenario, ("only %d pages opened"):format(pages)) end
			local found = ns.WindowSearch.Find("e", UI.SearchEntries(), 8)
			if #found == 0 then fail(scenario, "a search for \"e\" found nothing") end
			ns.CloseOptions()
		end)
	end
end
