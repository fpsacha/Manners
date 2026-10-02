-- The options window (Options/Window/*.lua, Options/Register.lua): the frame,
-- the calls the rest of the addon makes (IA 1.13), the fallback to the old
-- dialog, a fight, folds, search, the footer's reset, the status strip, the
-- peek, the preview, the Settings entry, and where the window keeps its state.
-- The class table (IA 1.11) and every page in two languages are in
-- window-classes.lua.
--
-- Written against BUILD.md's interfaces rather than any one set of widgets:
-- rows are reached through the row table (Refresh, Flash), the confirm box
-- through ns.WindowWidgets.Modal, and the model through ns.WindowBind.
--
-- Every scenario name starts with "window:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

-- Globals a scenario may replace, put back after each: Mock.reset owns none.
local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "MenuUtil" }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function said() return table.concat(Mock.printed, "\n") end

-- One session as opts.class (a mage by default), knowing opts.known (spell
-- ids), with body(ns, UI) run and every global put back however it ends.
local function with(scenario, opts, body)
	Mock.reset()
	Mock.class = opts.class or "MAGE"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	if opts.settings then Mock.installSettings() end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		if opts.known then
			local set = {}
			for _, id in ipairs(opts.known) do set[id] = true end
			IsSpellKnown = function(id) return set[id] == true end
			IsPlayerSpell = IsSpellKnown
		end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		Mock.printed = {}
		body(ns, ns.WindowUI)
		if not opts.allowErrors then noErrors(scenario, ns) end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	if opts.settings then Mock.removeSettings() end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Shut as Escape or the X does: hidden, and the client's OnHide run (once
-- more is harmless, should the mock's Hide run it too).
local function shut(ns)
	ns.CloseOptions()
	local f = ns.OptionsWindow
	local onHide = f and f:GetScript("OnHide")
	if onHide then onHide(f) end
end

local function press(button)
	local onClick = button and button:GetScript("OnClick")
	if onClick then onClick(button, "LeftButton", false) end
end

local function shown(frame) return frame ~= nil and frame:IsShown() == true end

-- The window's reach into what the model says, with the window's own context.
local function item(ns, path)
	return ns.WindowBind.Item(path, nil, ns.WindowUI.ctx)
end

-- ------------------------------------------------------------------ binding
-- A tab made up for the purpose, with every AceConfig rule IA 1.12 lists:
-- handler method strings on the group, get = false, validate's three
-- answers, a confirm function, values with and without sorting, a
-- multiselect, and the tab's own hidden and disabled reaching its items.
do
	local scenario = "window: the binding reads a definition the way AceConfigDialog does"
	with(scenario, {}, function(ns)
		local B, W = ns.WindowBind, ns.WindowWidgets
		local store, calls, ran = { a = true }, {}, 0
		local handler = {}
		function handler.Get(self, info) return store[info[#info]] end
		function handler.Set(self, info, value)
			calls[#calls + 1] = info[#info] .. "=" .. tostring(value) .. "/" .. tostring(info.arg)
			store[info[#info]] = value
		end
		function handler.List() return { x = "Bravo", y = "alpha" } end
		local tab = { type = "group", name = "zz", handler = handler, get = "Get", set = "Set", args = {
			a = { type = "toggle", name = "A", arg = "common" },
			b = { type = "select", name = "B", values = "List", get = false },
			c = { type = "input", name = "C", usage = "Use letters.",
				validate = function(_, v) if v == "ok" then return true elseif v == "no" then return false end return "not that" end },
			d = { type = "execute", name = function() return "Dee" end, confirm = function() return "Sure?" end,
				func = function() ran = ran + 1 end },
			e = { type = "toggle", name = "E", hidden = function() return false end, disabled = function() return false end },
			f = { type = "select", name = "F", values = { x = "Bravo", y = "alpha" }, sorting = { "x", "y" } },
			m = { type = "multiselect", name = "M", values = { [2] = "Group 2", [10] = "Group 10", [1] = "Group 1" } },
		} }
		ns.optionsTable.args.zz = tab
		local function it(key) return B.Item("zz." .. key, nil, ns.WindowUI.ctx) end
		if B.Value(it("a")) ~= true then fail(scenario, "a handler method named on the tab did not answer the get") end
		B.Commit(it("a"), false)
		if calls[1] ~= "a=false/common" then fail(scenario, "the tab's set ran as " .. tostring(calls[1])) end
		if B.Value(it("b")) ~= nil then fail(scenario, "get = false showed a value") end
		local labels = {}
		for _, pair in ipairs(B.Values(it("b"))) do labels[#labels + 1] = pair[2] end
		if table.concat(labels, ",") ~= "alpha,Bravo" then fail(scenario, "without sorting the choices came " .. table.concat(labels, ",")) end
		labels = {}
		for _, pair in ipairs(B.Values(it("f"))) do labels[#labels + 1] = pair[2] end
		if table.concat(labels, ",") ~= "Bravo,alpha" then fail(scenario, "with sorting the choices came " .. table.concat(labels, ",")) end
		labels = {}
		for _, pair in ipairs(B.Values(it("m"))) do labels[#labels + 1] = tostring(pair[1]) end
		if table.concat(labels, ",") ~= "1,2,10" then fail(scenario, "a multiselect listed its keys " .. table.concat(labels, ",")) end
		local ok, said = B.Commit(it("c"), "x")
		if ok ~= false or said ~= "not that" then fail(scenario, "a validate's sentence came back as " .. tostring(said)) end
		ok, said = B.Commit(it("c"), "no")
		if ok ~= false or said ~= "Use letters." then fail(scenario, "a validate's false came back as " .. tostring(said)) end
		B.Commit(it("c"), "ok")
		if store.c ~= "ok" then fail(scenario, "an accepted value was not set") end
		local realModal, asked = W.Modal, nil
		W.Modal = function(_, text, yes) asked = { text = text, yes = yes } end
		B.Run(it("d"))
		W.Modal = realModal
		if not asked or asked.text ~= "Sure?" or ran ~= 0 then
			fail(scenario, "a confirm function's text was not asked first: " .. tostring(asked and asked.text))
		elseif asked.yes() == nil and ran ~= 1 then
			fail(scenario, "YES did not run the button")
		end
		-- The origin rule: the tab hidden or greyed takes its items with it,
		-- whatever their own rules say.
		tab.hidden, tab.disabled = function() return true end, function() return true end
		if not B.Hidden(it("e")) or not B.Disabled(it("e")) then fail(scenario, "a hidden, greyed tab left its item shown or live") end
		tab.hidden, tab.disabled = nil, nil
		if B.Hidden(it("e")) or B.Disabled(it("e")) then fail(scenario, "the item's own false was not honoured") end
		if B.Item("zz.nothing") ~= nil or B.Item("advanced") ~= nil then fail(scenario, "a path with no control made an item") end
		ns.optionsTable.args.zz = nil
	end)
end

-- ------------------------------------------------------------------ the frame
do
	local scenario = "window: the frame is MannersOptions, 820 by 600, high, and Escape shuts it"
	with(scenario, {}, function(ns)
		ns.OpenOptions()
		local f = ns.OptionsWindow
		if not f then
			fail(scenario, "SKIPPED -- no window was built")
			return
		end
		if f._name ~= nil and f._name ~= "MannersOptions" then fail(scenario, "the window is named " .. tostring(f._name)) end
		if f._width ~= 820 or f._height ~= 600 then
			fail(scenario, ("the window is %s by %s"):format(tostring(f._width), tostring(f._height)))
		end
		if f._strata ~= "HIGH" then fail(scenario, "the window's strata is " .. tostring(f._strata)) end
		if f._toplevel ~= true then fail(scenario, "the window is not toplevel, so the ledger stays above it") end
		if f._clamped ~= true then fail(scenario, "the window can be dragged off the screen") end
		if f._movable ~= true then fail(scenario, "the window cannot be moved") end
		local listed = false
		for _, name in ipairs(UISpecialFrames or {}) do listed = listed or name == "MannersOptions" end
		if not listed then fail(scenario, "MannersOptions is not in UISpecialFrames, so Escape does not shut it") end
		if not ns.OptionsOpen() then fail(scenario, "the window is up and OptionsOpen says no") end
		if ns.OptionsTab() ~= "general" then fail(scenario, "the first open lands on " .. tostring(ns.OptionsTab())) end
	end)
end

-- ------------------------------------------------------------------ the API
do
	local scenario = "window: OpenOptions, OptionsOpen, CloseOptions and OptionsTab"
	with(scenario, {}, function(ns, UI)
		local Page = ns.OptionsPage
		ns.OpenOptions("when")
		if ns.OptionsTab() ~= "when" then fail(scenario, "OpenOptions(\"when\") opened " .. tostring(ns.OptionsTab())) end
		shut(ns)
		if ns.OptionsOpen() then fail(scenario, "CloseOptions left the window reading as open") end
		ns.OpenOptions()
		if ns.OptionsTab() ~= "when" then fail(scenario, "reopened on " .. tostring(ns.OptionsTab()) .. ", not the last page") end
		-- Advanced is model, not a page.
		ns.OpenOptions("advanced")
		if ns.OptionsTab() ~= "when" then fail(scenario, "OpenOptions(\"advanced\") went to " .. tostring(ns.OptionsTab())) end
		local ids = {}
		for _, group in ipairs(ns.WindowLayout.groups) do
			for _, id in ipairs(group) do ids[#ids + 1] = id end
		end
		if table.concat(ids, " ") ~= "general who skip when click appearance profiles diagnostics" then
			fail(scenario, "the page ids are " .. table.concat(ids, " "))
		end

		-- The boxes start shut when the window was shut, and are left alone
		-- while it is up; shutting it shuts them.
		Page.reportOpen, Page.shareOpen = true, true
		ns.OpenOptions("diagnostics")
		if not (Page.reportOpen and Page.shareOpen) then fail(scenario, "opening the open window again shut the boxes") end
		shut(ns)
		if Page.reportOpen or Page.shareOpen then fail(scenario, "shutting the window left the report or share box open") end
		Page.reportOpen = true
		ns.OpenOptions()
		if Page.reportOpen then fail(scenario, "the report box survived the window being opened again") end

		-- Repaints re-read the rows, never rebuild them.
		local W = ns.WindowWidgets
		local realBuild, built = W.Build, 0
		W.Build = function(...)
			built = built + 1
			return realBuild(...)
		end
		ns.OpenOptions("who")
		ns.OpenOptions("general")
		local before = built
		local row = UI.RowFor("general.verbose")
		local refreshed = 0
		local realRefresh = row and row.Refresh
		if row then
			row.Refresh = function(r)
				refreshed = refreshed + 1
				return realRefresh(r)
			end
		end
		ns.RefreshOptionsDisplay()
		ns.OpenOptions("who")
		ns.OpenOptions("general")
		W.Build = realBuild
		if row then row.Refresh = realRefresh end
		if built ~= before then fail(scenario, ("%d rows were built again by repaints and page switches"):format(built - before)) end
		if not row then
			fail(scenario, "SKIPPED -- no row for Tell me in chat")
		elseif refreshed == 0 then
			fail(scenario, "RefreshOptionsDisplay did not re-read a row on the open page")
		elseif UI.RowFor("general.verbose") ~= row then
			fail(scenario, "a repaint replaced a row")
		end
	end)
end

do
	local scenario = "window: ShowShareBox opens Profiles at the share boxes"
	with(scenario, {}, function(ns, UI)
		local Page = ns.OptionsPage
		if ns.ShowShareBox("export") ~= true then fail(scenario, "ShowShareBox(\"export\") did not answer true") end
		if ns.OptionsTab() ~= "profiles" then fail(scenario, "export opened " .. tostring(ns.OptionsTab())) end
		if not Page.shareOpen then fail(scenario, "export left the box of settings shut") end
		if not UI.RowShown("profiles.shareText") then fail(scenario, "export did not show the box of settings") end
		shut(ns)
		ns.OpenOptions("general")
		ns.ShowShareBox("import")
		if ns.OptionsTab() ~= "profiles" then fail(scenario, "import opened " .. tostring(ns.OptionsTab())) end
		if Page.shareOpen then fail(scenario, "import opened the box of this profile's settings") end
		if not UI.RowShown("profiles.sharePaste") then fail(scenario, "import did not show the paste box") end
	end)
end

-- ------------------------------------------------------------------ fallback
do
	local scenario = "window: a window that will not build falls back to the old dialog, said once"
	with(scenario, { allowErrors = true }, function(ns)
		local dialog = LibStub("AceConfigDialog-3.0")
		local realOpen, opened = dialog.Open, 0
		dialog.Open = function(_, app) if app == "Manners" then opened = opened + 1 end end
		local W = ns.WindowWidgets
		local realButton = W.Button
		W.Button = function() error("no buttons today", 0) end
		local before = #ns.errors
		local ok, err = pcall(function()
			ns.OpenOptions()
			ns.OpenOptions("who")
			ns.RefreshOptionsDisplay()
		end)
		W.Button, dialog.Open = realButton, realOpen
		if not ok then fail(scenario, "opening the options threw: " .. tostring(err)) end
		if opened ~= 2 then fail(scenario, ("the old dialog opened %d times for two asks"):format(opened)) end
		if #ns.errors - before ~= 1 or (ns.errors[#ns.errors] or {}).where ~= "options window" then
			fail(scenario, ("%d failures were recorded, the last in %s"):format(#ns.errors - before,
				tostring((ns.errors[#ns.errors] or {}).where)))
		end
		local _, lines = said():gsub("something broke in options window", "")
		if lines ~= 1 then fail(scenario, ("the failure was said %d times in chat"):format(lines)) end
		if shown(ns.OptionsWindow) then fail(scenario, "a half-built window was left on screen") end
		if ns.OptionsOpen() then fail(scenario, "with the dialog shut, the options read as open") end
	end)
end

-- ------------------------------------------------------------------ combat
do
	local scenario = "window: in a fight the controls the game refuses grey out, and the strip says why"
	with(scenario, {}, function(ns, UI)
		local B = ns.WindowBind
		ns.OpenOptions("appearance")
		ns.Prompt:ExitTest()
		Mock.inCombat = true
		ns.RefreshOptionsDisplay()
		for _, path in ipairs({ "general.bindKey", "general.openBindings", "general.previewStart", "general.ownProfile" }) do
			local it = item(ns, path)
			if not it then
				fail(scenario, "SKIPPED -- no " .. path)
			elseif not B.Disabled(it) then
				fail(scenario, path .. " is not greyed out in a fight")
			end
		end
		if UI.header.preview:IsEnabled() then fail(scenario, "Show me the prompt can be pressed in a fight") end
		local function note(path) return UI.Plain(B.Text(item(ns, path), "name")) end
		local function strip() return UI.strip.combat and UI.Plain(UI.strip.combat) or nil end
		if strip() ~= note("appearance.combatNotice") then fail(scenario, "Look's strip in a fight reads " .. tostring(strip())) end
		ns.OpenOptions("click")
		if strip() ~= note("click.combatNotice") then fail(scenario, "What I say's strip in a fight reads " .. tostring(strip())) end
		ns.OpenOptions("when")
		if strip() ~= note("advanced.advCombatNotice") then fail(scenario, "When to offer's strip in a fight reads " .. tostring(strip())) end
		ns.OpenOptions("general")
		if strip() then fail(scenario, "Start here has a combat line: " .. strip()) end

		-- A preview already running can still be stopped.
		Mock.inCombat = false
		ns.Prompt:ToggleTest()
		Mock.inCombat = true
		ns.RefreshOptionsDisplay()
		if B.Disabled(item(ns, "general.previewStart")) or not UI.header.preview:IsEnabled() then
			fail(scenario, "a running preview cannot be stopped in a fight")
		end
		Mock.inCombat = false
		ns.Prompt:ExitTest()
		ns.OpenOptions("appearance")
		if strip() then fail(scenario, "the combat line outlived the fight") end
		if B.Disabled(item(ns, "general.bindKey")) then fail(scenario, "the key binding stayed grey after the fight") end
		ns.Prompt:ExitTest()
	end)
end

-- ------------------------------------------------------------------ folds
do
	local scenario = "window: a fold remembers being open, across a reopen and a profile switch"
	with(scenario, {}, function(ns, UI)
		ns.OpenOptions("appearance")
		ns.Prompt:ExitTest()
		local w = UI.Where("advanced.x")
		if not (w and w.sec.fold and w.sec.button) then
			fail(scenario, "SKIPPED -- Left / right is not in a fold on Look")
			return
		end
		if UI.RowShown("advanced.x") then fail(scenario, "Exact position starts open") end
		press(w.sec.button)
		if not UI.RowShown("advanced.x") then fail(scenario, "opening Exact position did not show Left / right") end
		local saved = Mock.sv.global and Mock.sv.global.window
		if not (saved and saved.open and saved.open[w.sec.key]) then
			fail(scenario, "the open fold is not kept in ns.db.global.window.open")
		end
		shut(ns)
		ns.OpenOptions("appearance")
		if not UI.RowShown("advanced.x") then fail(scenario, "Exact position shut itself when the window was reopened") end
		ns.db:SetProfile("Somebody Else")
		ns.RefreshOptionsDisplay()
		if not UI.RowShown("advanced.x") then fail(scenario, "switching profile shut Exact position") end
		if Mock.sv.profile.window ~= nil then fail(scenario, "the window's state went into the profile") end
		press(w.sec.button)
		if UI.RowShown("advanced.x") or UI.State().open[w.sec.key] then fail(scenario, "Exact position would not shut") end
		ns.Prompt:ExitTest()
	end)
end

do
	local scenario = "window: a fold's gold dot shows only while something in it differs from default"
	with(scenario, {}, function(ns, UI)
		ns.OpenOptions("who")
		local w = UI.Where("who.friends")
		if not (w and w.sec.fold and w.sec.button) then
			fail(scenario, "SKIPPED -- Friends and guildmates first is not in a fold")
			return
		end
		if shown(w.sec.button.dot) then fail(scenario, "Who comes first has a gold dot with nothing changed") end
		ns.db.profile.priority.friends = false
		ns.RefreshOptionsDisplay()
		if not shown(w.sec.button.dot) then fail(scenario, "Who comes first has no gold dot with Friends first off") end
		ns.db.profile.priority.friends = true
		ns.db.profile.timing.scanInterval = 0.43
		if UI.Differs("advanced.scanInterval", item(ns, "advanced.scanInterval")) then
			fail(scenario, "0.43 against 0.4, inside half a step, counts as changed")
		end
		ns.db.profile.timing.scanInterval = 0.5
		if not UI.Differs("advanced.scanInterval", item(ns, "advanced.scanInterval")) then
			fail(scenario, "Check for people every 0.5 s does not count as changed")
		end
		ns.db.profile.timing.scanInterval = 0.4
		ns.db.profile.prompt.fontColor = { 1, 1, 1 }
		if UI.Differs("appearance.fontColor", item(ns, "appearance.fontColor")) then
			fail(scenario, "a colour with no alpha counts as changed from the same colour at alpha 1")
		end
		ns.db.profile.prompt.fontColor = { 1, 1, 1, 1 }
	end)
end

-- ------------------------------------------------------------------ search
do
	local scenario = "window: a search result opens its page and fold, scrolls to the row and flashes it"
	with(scenario, {}, function(ns, UI)
		ns.OpenOptions("when")
		ns.OpenOptions("general")
		local row = UI.RowFor("advanced.scanInterval")
		local w = UI.Where("advanced.scanInterval")
		if not (row and w and w.sec.fold) then
			fail(scenario, "SKIPPED -- Check for people every is not in a fold on When to offer")
			return
		end
		local flashed = 0
		local realFlash = row.Flash
		row.Flash = function(r)
			flashed = flashed + 1
			if realFlash then return realFlash(r) end
		end
		local box = UI.search.box
		box:SetText("check for PEOPLE")
		box:GetScript("OnTextChanged")(box, true)
		Mock.runTimers(0.2)
		local first = UI.search.found[1]
		if not (first and first.ref.path == "advanced.scanInterval") then
			fail(scenario, "the first result for \"check for PEOPLE\" is " .. tostring(first and first.ref.path))
		end
		if not shown(UI.search.results) then fail(scenario, "the results are not on screen") end
		box:GetScript("OnEnterPressed")(box)
		row.Flash = realFlash
		if ns.OptionsTab() ~= "when" then fail(scenario, "Enter went to " .. tostring(ns.OptionsTab())) end
		if not UI.State().open[w.sec.key] then fail(scenario, "Enter did not open (and keep open) the Timing fold") end
		if not UI.RowShown("advanced.scanInterval") then fail(scenario, "the row is not shown after the jump") end
		if flashed ~= 1 then fail(scenario, ("the row flashed %d times"):format(flashed)) end
		local view = UI.view
		local want = math.max(0, math.min(w.e.y - 30, view.range))
		if view.scrollY ~= want then fail(scenario, ("scrolled to %s, not %s"):format(tostring(view.scrollY), tostring(want))) end
		if shown(UI.search.results) then fail(scenario, "the results stayed over the page") end

		-- Escape clears; nothing found turns the box red where the client
		-- has no sentence for it.
		box:SetText("zzqqxx")
		box:GetScript("OnTextChanged")(box, true)
		Mock.runTimers(0.2)
		if #UI.search.found ~= 0 or shown(UI.search.results) or not UI.search.bad then
			fail(scenario, "a search that finds nothing did not leave the list shut and the box red")
		end
		box:GetScript("OnEscapePressed")(box)
		if box:GetText() ~= "" or UI.search.bad then fail(scenario, "Escape did not clear the box") end
	end)
end

do
	local scenario = "window: search reads a dropdown's choices and leaves notes and hidden controls out"
	with(scenario, {}, function(ns, UI)
		ns.OpenOptions()
		local entries = UI.SearchEntries()
		local paths = {}
		for _, e in ipairs(entries) do paths[e.ref.path] = e end
		for _, path in ipairs({ "general.howItWorks", "diagnostics.pvpDiag", "diagnostics.ownDiag", "diagnostics.diag" }) do
			if paths[path] then fail(scenario, "the note " .. path .. " is searched") end
		end
		if paths["general.noBuffs"] then fail(scenario, "a hidden note is searched") end
		local channel = paths["click.channel"]
		if not channel then
			fail(scenario, "SKIPPED -- Where to say it is not searched")
		elseif #channel.choices == 0 then
			fail(scenario, "Where to say it is searched without its choices")
		end
		local found = ns.WindowSearch.Find(channel and channel.choices[#channel.choices] or "", entries, 8)
		local hit = false
		for _, e in ipairs(found) do hit = hit or e.ref.path == "click.channel" end
		if channel and not hit then fail(scenario, "a choice of Where to say it does not find it") end
	end)
end

-- ------------------------------------------------------------------ reset
do
	local scenario = "window: the reset button is hidden on Start here, Profiles and Diagnostics"
	with(scenario, {}, function(ns, UI)
		local want = { general = false, who = true, skip = true, when = true, click = true, appearance = true,
			profiles = false, diagnostics = false }
		for _, group in ipairs(ns.WindowLayout.groups) do
			for _, id in ipairs(group) do
				ns.OpenOptions(id)
				if ns.OptionsTab() ~= id then
					fail(scenario, "SKIPPED -- a mage cannot open " .. id)
				elseif shown(UI.footer.reset) ~= want[id] then
					fail(scenario, ("the reset button is %s on %s"):format(shown(UI.footer.reset) and "shown" or "hidden", id))
				end
			end
		end
		ns.Prompt:ExitTest()

		-- It asks first, in the window's own box, with the item's words.
		ns.OpenOptions("when")
		local W, B = ns.WindowWidgets, ns.WindowBind
		local realModal, asked = W.Modal, nil
		W.Modal = function(_, text, yes, no) asked = { text = text, yes = yes, no = no } end
		ns.db.profile.timing.scanInterval = 1.5
		press(UI.footer.reset)
		W.Modal = realModal
		if not asked then
			fail(scenario, "the reset did not ask first")
			return
		end
		if asked.text ~= B.Text(item(ns, "advanced.resetAdvanced"), "confirmText") then
			fail(scenario, "the reset asked: " .. tostring(asked.text))
		end
		if ns.db.profile.timing.scanInterval ~= 1.5 then fail(scenario, "the reset ran before YES") end
		asked.yes()
		if ns.db.profile.timing.scanInterval ~= ns.defaults.profile.timing.scanInterval then
			fail(scenario, "YES left Check for people every at " .. tostring(ns.db.profile.timing.scanInterval))
		end
	end)
end

-- ------------------------------------------------------------------ strip
do
	local scenario = "window: the strip says the launcher's line for the states the player can act on"
	with(scenario, {}, function(ns, UI)
		ns.OpenOptions()
		ns.Prompt:ExitTest()
		local real = ns.LauncherState
		-- With the model's own export in, a switched-off addon is one of them.
		if real then
			ns.db.profile.enabled = false
			ns.RefreshOptionsDisplay()
			if UI.strip.kind ~= "off" or (UI.strip.height or 0) == 0 then
				fail(scenario, "switched off, the strip reads " .. tostring(UI.strip.line))
			end
			ns.db.profile.enabled = true
		end
		local SHOWN = { off = true, unlocked = true, snoozed = true, ownoff = true, blocked = true, mounted = true,
			watching = false, ownwatch = false, noclass = false, nothing = false, unlearned = false }
		for kind, want in pairs(SHOWN) do
			ns.LauncherState = function() return false, "line for " .. kind, 1, 0.82, 0, true, false, kind end
			ns.RefreshOptionsDisplay()
			local says = UI.strip.line
			if want and (says ~= "line for " .. kind or UI.strip.height == 0) then
				fail(scenario, kind .. " is not in the strip")
			elseif not want and says then
				fail(scenario, kind .. " is in the strip: " .. tostring(says))
			end
		end
		ns.LauncherState = function() return true, "held in a fight", 1, 0.82, 0, true, true, "watching" end
		ns.RefreshOptionsDisplay()
		if UI.strip.line ~= "held in a fight" then fail(scenario, "a fight's held prompt is not in the strip") end
		ns.LauncherState = real
		ns.RefreshOptionsDisplay()

		-- Lock it, there while the prompt is unlocked, and gone once pressed.
		ns.db.profile.prompt.locked = false
		ns.RefreshOptionsDisplay()
		if not shown(UI.strip.lock) then fail(scenario, "Lock it is not in the strip while the prompt is unlocked") end
		press(UI.strip.lock)
		if not ns.db.profile.prompt.locked then fail(scenario, "Lock it did not lock the prompt") end
		if shown(UI.strip.lock) then fail(scenario, "Lock it stayed after locking") end
	end)
end

-- ------------------------------------------------------------------ peek
do
	local scenario = "window: the window fades to a quarter while Look's changes show on the prompt"
	with(scenario, {}, function(ns, UI)
		ns.OpenOptions("appearance")
		local f = ns.OptionsWindow
		local update = f:GetScript("OnUpdate")
		local function settle(seconds)
			for _ = 1, 10 do update(f, (seconds or 0.5) / 10) end
		end
		local B = ns.WindowBind
		B.Commit(item(ns, "appearance.showSub"), false)
		settle(0.3)
		if math.abs(f:GetAlpha() - 0.25) > 0.001 then fail(scenario, "after a change on Look the window is at " .. f:GetAlpha()) end
		Mock.advance(1.6)
		settle(0.3)
		if f:GetAlpha() ~= 1 then fail(scenario, "1.6 s after the change the window is still at " .. f:GetAlpha()) end
		B.Commit(item(ns, "appearance.showSub"), true)
		B.Commit(item(ns, "who.friends"), false)
		Mock.advance(1.6)
		settle(0.3)
		if f:GetAlpha() ~= 1 then fail(scenario, "a change on Who to buff faded the window") end
		B.Commit(item(ns, "who.friends"), true)

		UI.ctx.OnHold(true)
		settle(0.3)
		if math.abs(f:GetAlpha() - 0.25) > 0.001 then fail(scenario, "holding a slider on Look left the window at " .. f:GetAlpha()) end
		UI.ctx.OnHold(false)
		settle(0.3)
		if f:GetAlpha() ~= 1 then fail(scenario, "letting go left the window at " .. f:GetAlpha()) end

		-- Resting on Show me the prompt while a preview runs.
		if not ns.Prompt:InTest() then ns.Prompt:ToggleTest() end
		local preview = UI.header.preview
		preview:GetScript("OnEnter")(preview)
		Mock.runTimers(0.5)
		settle(0.3)
		if math.abs(f:GetAlpha() - 0.25) > 0.001 then fail(scenario, "resting on the preview button did not fade the window") end
		preview:GetScript("OnLeave")(preview)
		settle(0.3)
		if f:GetAlpha() ~= 1 then fail(scenario, "leaving the preview button left the window faded") end

		-- Never in a fight, and shutting the window ends one.
		Mock.inCombat = true
		B.Commit(item(ns, "appearance.showSub"), false)
		settle(0.3)
		if f:GetAlpha() ~= 1 then fail(scenario, "a change in a fight faded the window") end
		Mock.inCombat = false
		B.Commit(item(ns, "appearance.showSub"), true)
		settle(0.05)
		shut(ns)
		if f:GetAlpha() ~= 1 then fail(scenario, "shutting the window left it faded") end
		ns.Prompt:ExitTest()
	end)
end

-- ------------------------------------------------------------------ preview
do
	local scenario = "window: the first open starts the preview once, and Look starts it unless it was stopped"
	with(scenario, {}, function(ns, UI)
		ns.OpenOptions()
		if not ns.Prompt:InTest() then fail(scenario, "the first open did not start the preview") end
		if not UI.State().previewShown then fail(scenario, "previewShown was not kept") end
		shut(ns)
		ns.Prompt:ExitTest()
		ns.OpenOptions("general")
		if ns.Prompt:InTest() then fail(scenario, "the second open started the preview again") end
		ns.OpenOptions("appearance")
		if not ns.Prompt:InTest() then fail(scenario, "opening Look did not start the preview") end
		press(UI.header.preview)
		if ns.Prompt:InTest() then fail(scenario, "the header button did not stop the preview") end
		ns.OpenOptions("general")
		ns.OpenOptions("appearance")
		if ns.Prompt:InTest() then fail(scenario, "Look started a preview the player had just stopped") end
		shut(ns)
		ns.OpenOptions("appearance")
		if not ns.Prompt:InTest() then fail(scenario, "Look in a new window session did not start the preview") end
		ns.Prompt:ExitTest()
	end)
end

-- ------------------------------------------------------------------ header
do
	local scenario = "window: the snooze menu holds the layout's entries and the button says until when"
	with(scenario, {}, function(ns, UI)
		local entries
		MenuUtil = { CreateContextMenu = function(owner, generator)
			entries = {}
			local root = {}
			root.CreateButton = function(_, text, fn)
				entries[#entries + 1] = { text = text, fn = fn }
				return root
			end
			root.CreateDivider = function() end
			root.CreateTitle = function() end
			generator(owner, root)
		end }
		ns.OpenOptions()
		ns.Prompt:ExitTest()
		local B = ns.WindowBind
		press(UI.header.snooze)
		local want = B.Text(item(ns, "general.snooze5"), "name")
		if not (entries and entries[1] and entries[1].text == want) then
			fail(scenario, "the menu's first entry is " .. tostring(entries and entries[1] and entries[1].text))
			return
		end
		local stop = B.Text(item(ns, "general.snoozeStop"), "name")
		for _, e in ipairs(entries) do
			if e.text == stop then fail(scenario, "Stop snoozing is in the menu with no snooze running") end
		end
		entries[1].fn()
		if not ns.SnoozeLeft() then fail(scenario, "the first entry did not snooze") end
		if UI.header.snoozeLabel ~= ns.L["Snoozed until %s"]:format(ns.SnoozeEndsAt()) then
			fail(scenario, "snoozed, the button reads " .. tostring(UI.header.snoozeLabel))
		end
		press(UI.header.snooze)
		local last = entries[#entries]
		if not (last and last.text == stop) then fail(scenario, "Stop snoozing is not in the menu during a snooze") end
		if last then last.fn() end
		if ns.SnoozeLeft() then fail(scenario, "Stop snoozing did not stop it") end
		if UI.header.snoozeLabel ~= ns.L["Snooze"] then fail(scenario, "after the snooze the button reads " .. tostring(UI.header.snoozeLabel)) end
	end)
end

-- ------------------------------------------------------------------ state
do
	local scenario = "window: where it sits, its page and its folds are the account's, never the profile's"
	with(scenario, {}, function(ns, UI)
		Mock.geometry = { width = 1365, height = 768 }
		ns.OpenOptions("appearance")
		ns.Prompt:ExitTest()
		local f = ns.OptionsWindow
		local header = UI.header.frame
		header:GetScript("OnDragStart")(header)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -50)
		header:GetScript("OnDragStop")(header)
		local w = UI.Where("appearance.font")
		if w and w.sec.button then press(w.sec.button) end
		local saved = Mock.sv.global and Mock.sv.global.window
		if not saved then
			fail(scenario, "nothing was kept in ns.db.global.window")
			return
		end
		if saved.point ~= "TOPLEFT" or saved.x ~= 100 or saved.y ~= -50 then
			fail(scenario, ("kept the place as %s %s %s"):format(tostring(saved.point), tostring(saved.x), tostring(saved.y)))
		end
		if saved.page ~= "appearance" then fail(scenario, "kept the page as " .. tostring(saved.page)) end
		if not saved.previewShown then fail(scenario, "previewShown was not kept") end
		for key in pairs(Mock.sv.profile) do
			if key == "window" then fail(scenario, "the profile holds the window's state") end
		end

		-- A reload: the same saved file, a new session.
		local again = load(scenario)
		if not again then return end
		drive(scenario, again)
		again.OpenOptions()
		local g = again.OptionsWindow
		local point = g and g.points[1]
		if not (point and point[1] == "TOPLEFT" and point[4] == 100 and point[5] == -50) then
			fail(scenario, "after a reload the window is not where it was left")
		end
		if again.OptionsTab() ~= "appearance" then fail(scenario, "after a reload it opened on " .. tostring(again.OptionsTab())) end
		if w and not again.WindowUI.RowShown("appearance.font") then fail(scenario, "after a reload the Text fold is shut") end
		again.Prompt:ExitTest()
		noErrors(scenario, again)
	end)
end

-- ------------------------------------------------------------------ Settings
do
	local scenario = "window: the game's Settings window has an entry with a button into the window"
	with(scenario, { settings = true }, function(ns)
		local record = Mock.settings
		local category = record and record.canvases[1]
		if not category then
			fail(scenario, "nothing was registered with the Settings window")
			return
		end
		if category.name ~= "Manners" or record.added[1] ~= category then
			fail(scenario, "the entry is " .. tostring(category.name) .. " and was not added as an addon's")
		end
		if Mock.blizCanvas then fail(scenario, "AceConfigDialog's AddToBlizOptions is still used") end
		local canvas = category.frame
		local about = canvas.about and canvas.about:GetText()
		if about ~= ns.L["Manners shows a small button, the prompt, with the next person to buff. Click it, or press your key, and it casts on them; the game does not let addons cast by themselves."] then
			fail(scenario, "the entry says: " .. tostring(about))
		end
		press(canvas.open)
		if record.hidden ~= 1 then fail(scenario, "the Settings panel was not put away for the window") end
		if not ns.OptionsOpen() then fail(scenario, "the button did not open the window") end
		ns.Prompt:ExitTest()
	end)
end

-- ------------------------------------------------------------------ spells
do
	local scenario = "window: a spell learned mid-session adds its row without a reload"
	with(scenario, { known = { 1459 } }, function(ns, UI)
		ns.OpenOptions("who")
		ns.Prompt:ExitTest()
		if UI.RowShown("who.own_armor") then
			fail(scenario, "SKIPPED -- Armor is shown before any armor is learned")
			return
		end
		IsSpellKnown = function(id) return id == 1459 or id == 168 end
		IsPlayerSpell = IsSpellKnown
		Mock.advance(10)
		ns.addon:SPELLS_CHANGED()
		Mock.runTimers(6)
		if not UI.RowShown("who.own_armor") then fail(scenario, "learning Frost Armor did not add Armor to Who to buff") end
	end)
end

-- ------------------------------------------------------------------ relayout
-- A row that changes height by itself -- a refusal said in red under its box,
-- with nothing committed to repaint the page -- asks the window through
-- ctx.Relayout to place the page again round it. Without it the row grew
-- inside a slot laid out for its old height, over the row under it.
--
-- AceDBOptions' New box, which the mock's stand-in for the library does not
-- build, is put in as the library defines it.
do
	local scenario = "window: a refusal under a box lays the page out again round it"
	with(scenario, {}, function(ns, UI)
		local profiles = ns.optionsTable.args.profiles
		profiles.handler = profiles.handler or {}
		profiles.handler.SetProfile = function() end
		profiles.args.new = { order = 30, type = "input", name = "New", desc = "Create a new empty profile.",
			get = false, set = "SetProfile", usage = "Profile names cannot be longer than 50 characters.",
			validate = function(_, text) return #text > 0 and #text <= 50 end }
		ns.OpenOptions("profiles")
		local w = UI.Where("profiles.new")
		local row = w and w.e.row
		if not (row and row.box and UI.RowShown("profiles.new")) then
			fail(scenario, "SKIPPED -- no New box on Profiles")
			return
		end
		local before = w.e.h
		local below = UI.Where("profiles.shareCopy")
		local belowAt = below and below.e.y
		Mock.type(row.box, string.rep("x", 60))
		Mock.press(row.box, "ENTER")
		if not row.error then
			fail(scenario, "SKIPPED -- the New box took a name of 60 characters")
			return
		end
		if not (w.e.h > before) then
			fail(scenario, ("the red sentence made the New box's row %s tall and the page still gave it %s")
				:format(tostring(row.height), tostring(w.e.h)))
		elseif belowAt and not (below.e.y > belowAt) then
			fail(scenario, "the rows under the New box did not move down for the red sentence")
		end
		Mock.press(row.box, "ESCAPE")
		if row.error or w.e.h ~= before then
			fail(scenario, "Escape left the refusal's room on the page (" .. tostring(w.e.h) .. ", was " .. before .. ")")
		end
	end)
end
