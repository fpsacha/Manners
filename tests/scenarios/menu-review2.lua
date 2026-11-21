-- The second review of the menu: the reminder to set a key (Options/Start.lua,
-- Commands.lua) and the simple view (Options/Window/Layout.lua, WindowPage.lua,
-- WindowSearch.lua, WindowChrome.lua).
--
--   * /manners typed after the reminder opens Start here, as its line says,
--     whichever page the window was last on;
--   * a reminder the chat switch would drop is not counted as said;
--   * a search result that leads through a switch to a setting the short list
--     leaves out opens the full view, so turning the switch on shows it;
--   * When to offer's combat line keeps quiet about a control the simple view
--     is leaving out;
--   * the short list has Scrolls, the switch each scroll's own stands under.
--
-- Every scenario name starts with "menu-review2:" so the mutations in
-- tests/mutations/menu-review2.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

-- opts: class, page, before(ns).
local function with(scenario, opts, body)
	Mock.reset()
	FT.install()
	local ok, err = pcall(function()
		if opts.class then Mock.class = opts.class end
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		if opts.before then opts.before(ns) end
		ns.OpenOptions(opts.page or "when")
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	Mock.inCombat = false
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

---------------------------------------------------------------------------
-- the reminder to set a key
---------------------------------------------------------------------------

local NO_KEY = "Manners has no key yet"

local function saidOf(needle)
	local n = 0
	for _, line in ipairs(Mock.printed or {}) do
		if tostring(line):find(needle, 1, true) then n = n + 1 end
	end
	return n
end

-- A login on the saved file as it stands (tests/scenarios/menu.lua): the
-- addon loaded and enabled, the clock run past the login's own lines and then
-- past the reminder's wait. `before` runs between the two.
local function login(scenario, before)
	local ns = load(scenario)
	if not ns then return nil end
	ns.addon:OnInitialize()
	ns.addon:OnEnable()
	Mock.printed = {}
	Mock.runTimers(2)
	if before then before(ns) end
	Mock.runTimers(ns.KEY_NUDGE_AFTER + 1)
	return ns, saidOf(NO_KEY)
end

local function sessions(scenario, body)
	Mock.reset()
	FT.install()
	local ok, err = pcall(body)
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The first run's two questions answered (while they are asked, every
-- /manners opens on them), and the window last left on Look.
local function leftOnLook(ns)
	ns.db.profile.firstRun = "answered"
	ns.OpenOptions("appearance")
	ns.CloseOptions()
end

do
	local scenario = "menu-review2: /manners after the reminder opens Start here, not the page last open"
	sessions(scenario, function()
		if not login(scenario) then return end
		-- The window was last left on Look, by this character or another.
		local ns, said = login(scenario, function(ns)
			leftOnLook(ns)
		end)
		if not ns then return end
		local UI = ns.WindowUI
		if said ~= 1 then fail(scenario, "SKIPPED -- the reminder was said " .. said .. " time(s)") return end
		if UI.State().page ~= "appearance" then
			fail(scenario, "SKIPPED -- the window was not left on Look: " .. tostring(UI.State().page))
			return
		end
		ns.addon:HandleSlash("")
		if not ns.OptionsOpen() then fail(scenario, "/manners did not open the window") return end
		if UI.page ~= "general" then
			fail(scenario, "the reminder says /manners opens Start here, and it opened " .. tostring(UI.page))
		end
		-- Once: the next /manners is back to the page last open.
		UI.ShowPage("appearance")
		ns.CloseOptions()
		ns.addon:HandleSlash("")
		if UI.page ~= "appearance" then
			fail(scenario, "a later /manners opened " .. tostring(UI.page) .. ", not the page last open")
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	-- With no reminder said, and with a key set since it was, /manners opens
	-- the page last open.
	sessions(scenario, function()
		local ns = login(scenario, function(ns)
			leftOnLook(ns)
		end)
		if not ns then return end
		ns.addon:HandleSlash("")
		if ns.WindowUI.page ~= "appearance" then
			fail(scenario, "with no reminder said, /manners opened " .. tostring(ns.WindowUI.page))
		end
		local said
		ns, said = login(scenario, function(ns)
			leftOnLook(ns)
		end)
		if not ns then return end
		if said ~= 1 then fail(scenario, "SKIPPED -- the reminder was said " .. said .. " time(s)") return end
		SetBinding("F9", "CLICK MannersPrompt:LeftButton")
		ns.addon:HandleSlash("")
		if ns.WindowUI.page ~= "appearance" then
			fail(scenario, "with a key set since the reminder, /manners opened " .. tostring(ns.WindowUI.page))
		end
	end)
end

do
	local scenario = "menu-review2: a reminder the chat switch would drop is not counted as said"
	sessions(scenario, function()
		if not login(scenario) then return end
		local ns, said
		for n = 1, 3 do
			ns, said = login(scenario, function(ns) ns.db.profile.silentChat = true end)
			if not ns then return end
			if said ~= 0 then fail(scenario, "said with every Manners message hidden") end
			if Mock.sv.char.keyReminders ~= 0 then
				fail(scenario, ("login %d with chat hidden: nothing was said and %s reminder(s) are counted as said")
					:format(n, tostring(Mock.sv.char.keyReminders)))
			end
		end
		local held = ns.Setup.ReminderHeld()
		if held ~= "chat messages are hidden" then
			fail(scenario, "with chat hidden, the reminder is held by: " .. tostring(held))
		end
		-- The chat back on: the reminder comes, the first of three.
		ns, said = login(scenario, function(ns) ns.db.profile.silentChat = false end)
		if not ns then return end
		if said ~= 1 then fail(scenario, ("the chat back on: said %d time(s), not once"):format(said)) end
		if Mock.sv.char.keyReminders ~= 1 then
			fail(scenario, "the chat back on: the count reads " .. tostring(Mock.sv.char.keyReminders))
		end
	end)
end

---------------------------------------------------------------------------
-- the simple view
---------------------------------------------------------------------------

-- The search's entry for a setting, by the setting's own path.
local function entryFor(UI, path)
	for _, entry in ipairs(UI.SearchEntries()) do
		if (entry.ref.via or entry.ref.path) == path then return entry end
	end
	return nil
end

do
	local scenario = "menu-review2: a result behind a switch, for a setting off the short list, opens the full view"
	-- { the class, the page, the setting, its switch, the switch's place in the profile }
	local cases = {
		{ nil, "appearance", "appearance.queueRows", "appearance.showQueue" },
		{ "PRIEST", "click", "who.askChannel", "who.ask" },
	}
	for _, case in ipairs(cases) do
		local class, page, setting, switch = case[1], case[2], case[3], case[4]
		with(scenario, { class = class, page = page }, function(ns, UI)
			local B = ns.WindowBind
			local item = UI.Item(switch)
			if not item or UI.Hidden(item) then fail(scenario, "SKIPPED -- " .. switch .. " is not shown") return end
			if B.Value(item) == true then B.Commit(item, false) end
			ns.SetMenuView("simple")
			if B.Value(item) == true then fail(scenario, "SKIPPED -- " .. switch .. " could not be turned off") return end
			if not UI.RowShown(switch) then fail(scenario, "SKIPPED -- " .. switch .. " is not on the short list") return end
			local found = entryFor(UI, setting)
			if not found then fail(scenario, setting .. " is not searched with " .. switch .. " off") return end
			if found.ref.path ~= switch then
				fail(scenario, "SKIPPED -- the result for " .. setting .. " leads to " .. tostring(found.ref.path))
				return
			end
			local e = UI.Choose(found.ref)
			if not (e and e.path == switch) then
				fail(scenario, "the result for " .. setting .. " landed on " .. tostring(e and e.path))
			end
			if ns.MenuView() ~= "full" then
				fail(scenario, ("%s is behind %s and off the short list, and its result left the view %s")
					:format(setting, switch, ns.MenuView()))
			end
			-- The switch turned on, as the result says: the setting is there.
			B.Commit(item, true)
			ns.RefreshOptionsDisplay()
			if not UI.RowShown(setting) then
				fail(scenario, switch .. " turned on as the result said, and " .. setting .. " is still not drawn")
			end
		end)
	end
	-- A setting on the short list behind its switch: the view is left alone.
	with(scenario, { page = "appearance" }, function(ns, UI)
		ns.db.profile.sound.enabled = false
		ns.SetMenuView("simple")
		local found = entryFor(UI, "appearance.soundFile")
		if not (found and found.ref.via) then fail(scenario, "SKIPPED -- Sound is not found behind Play a sound") return end
		UI.Choose(found.ref)
		if ns.MenuView() ~= "simple" then
			fail(scenario, "a result for a setting on the short list left the view " .. ns.MenuView())
		end
	end)
end

do
	local scenario = "menu-review2: the combat line keeps quiet about a control the simple view leaves out"
	with(scenario, { page = "when" }, function(ns, UI)
		local w = UI.Where("advanced.restoreTarget")
		if not (w and w.sec.fold) then fail(scenario, "SKIPPED -- Hand my target back is not in a fold") return end
		-- The fold left open earlier, account-wide.
		UI.State().open[w.sec.key] = true
		Mock.inCombat = true
		ns.RefreshOptionsDisplay()
		if not UI.strip.combat then
			fail(scenario, "SKIPPED -- the full view, the Targeting fold open, a fight: no combat line")
			return
		end
		ns.SetMenuView("simple")
		if UI.RowShown("advanced.restoreTarget") then
			fail(scenario, "SKIPPED -- Hand my target back is on the short list")
			return
		end
		if UI.strip.combat then
			fail(scenario, "the strip speaks of targeting in the simple view, which draws no targeting control: "
				.. tostring(UI.strip.combat))
		end
		ns.SetMenuView("full")
		if not UI.strip.combat then fail(scenario, "back in the full view, the combat line did not return") end
		Mock.inCombat = false
		ns.RefreshOptionsDisplay()
	end)
end

do
	local scenario = "menu-review2: the short list has Scrolls, the switch its scrolls stand under"
	with(scenario, { page = "who" }, function(ns, UI)
		-- Every row of the short list that is indented stands under a row of
		-- the short list: the layout's own word on it, for every page.
		local layout = UI.Layout()
		local keep = layout.simple.items
		for id, page in pairs(layout.pages) do
			if not layout.simple.pages[id] then
				for _, section in ipairs(page.sections) do
					local head
					for _, item in ipairs(section.items) do
						local path = type(item) == "table" and item[1] or item
						if type(item) == "table" and item.indent then
							if keep[path] and head and not keep[head] then
								fail(scenario, ("%s is on the short list, and %s, which it is indented under, is not")
									:format(tostring(path), tostring(head)))
							end
						else
							head = path
						end
					end
				end
			end
		end
		-- Scrolls off: the scroll switches are gone, and the one that brings
		-- them back is on the page.
		ns.db.profile.sources.self = true
		ns.db.profile.ownBuffs.scrolls = false
		ns.RefreshOptionsDisplay()
		local item = UI.Item("who.ownScrolls")
		if not item or UI.Hidden(item) then fail(scenario, "SKIPPED -- this client has no Scrolls switch") return end
		if not UI.Reveal("who.ownScrolls") then fail(scenario, "SKIPPED -- Scrolls is not drawn in the full view") return end
		ns.SetMenuView("simple")
		if not UI.RowShown("who.ownScrolls") then
			fail(scenario, "Scrolls is off, and the simple view does not draw the switch that turns it back on")
		end
	end)
end
