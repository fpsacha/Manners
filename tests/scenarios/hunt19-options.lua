-- Round 19's options fixes, each driven the way a player meets it: a box left
-- with the keyboard as the page changes, a slider dragged or a nudge arrow
-- clicked beside a box that had it, a slider whose release went missing, the
-- key button clicked straight from the search box, a dropdown longer than the
-- screen, a rogue's What I say and its reset, the Profiles tab and the table
-- AceDBOptions shares with every addon, a pasted /thank, and /manners macro
-- with Start here open.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every
-- scenario name starts with "hunt19-options:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function click(button, which)
	local onClick = button and button:GetScript("OnClick")
	if onClick then onClick(button, which or "LeftButton", false) end
end

-- The client takes the focus from an edit box as soon as it, or a frame it
-- sits in, is hidden, and the box hears OnEditFocusLost there and then. The
-- mock's frames do not; the window's frames, made after this is put in, do.
local function HidesFocus(f)
	local hide, setShown = f.Hide, f.SetShown
	local function drop(self)
		local focused, p = Mock.focus, Mock.focus
		while p do
			if p == self then
				focused:ClearFocus()
				return
			end
			p = p._parentFrame
		end
	end
	f.Hide = function(self, ...)
		local out = hide(self, ...)
		drop(self)
		return out
	end
	f.SetShown = function(self, on, ...)
		local out = setShown(self, on, ...)
		if not on then drop(self) end
		return out
	end
	return f
end

local SAVED = { "CreateFrame", "CreateMacro", "GetCurrentKeyBoardFocus", "MenuUtil" }

-- One session with the window open on `page`, everything put back. opts:
-- class; focusRule, to give the window's frames the client's rule above; and
-- beforeOpen(ns), run before the window is first built.
local function with(scenario, page, body, opts)
	opts = opts or {}
	Mock.reset()
	Mock.class = opts.class or Mock.class
	local saved = {}
	for _, name in ipairs(SAVED) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		if opts.beforeOpen then opts.beforeOpen(ns) end
		if opts.focusRule then
			local make = CreateFrame
			CreateFrame = function(...) return HidesFocus(make(...)) end
		end
		ns.OpenOptions(page)
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		ns.Prompt:ExitTest()
		noErrors(scenario, ns)
	end)
	for _, name in ipairs(SAVED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The window's alpha once its fade has had `seconds` to run.
local function settle(ns, seconds)
	local f = ns.OptionsWindow
	local update = f:GetScript("OnUpdate")
	for _ = 1, 10 do update(f, (seconds or 0.5) / 10) end
	return f:GetAlpha()
end

-- How many of a page's rows are drawn.
local function rowsShown(UI, id)
	local n = 0
	for _, sec in ipairs(UI.Model(id).sections) do
		for _, e in ipairs(sec.entries) do
			if e.row and e.row.frame:IsShown() then n = n + 1 end
		end
	end
	return n
end

-- ------------------------------------------------------------------ leaving a page
-- A box on Look with the keyboard, the sidebar clicked: the box commits as
-- it is hidden, and that commit's repaint used to paint Look -- the page
-- still in view while its rows were put away -- so Look's title and rows
-- stayed drawn, and clickable, over the page the player went to.
do
	local scenario = "hunt19-options: a box left with the keyboard as the page changes leaves nothing of its page behind"
	with(scenario, "appearance", function(ns, UI)
		local scale = UI.RowFor("appearance.scale")
		if not (scale and scale.box and UI.RowShown("appearance.scale")) then
			fail(scenario, "SKIPPED -- no Scale box on Look")
			return
		end
		Mock.advance(5)
		settle(ns, 0.5)
		Mock.type(scale.box, "2")
		click(UI.side.buttons.who)
		if UI.page ~= "who" then
			fail(scenario, "SKIPPED -- the sidebar did not open Who to buff")
			return
		end
		local left = rowsShown(UI, "appearance")
		if left > 0 then
			fail(scenario, left .. " of Look's rows are still drawn over Who to buff after leaving Scale's box")
		end
		if UI.Model("appearance").title:IsShown() then
			fail(scenario, "Look's title is still drawn over Who to buff")
		end
		if rowsShown(UI, "who") == 0 then fail(scenario, "Who to buff drew none of its rows") end
		if ns.db.profile.prompt.scale ~= 2 then
			fail(scenario, "the 2 typed into Scale was not kept as the page changed: "
				.. tostring(ns.db.profile.prompt.scale))
		end
		-- Who to buff has nothing on the prompt to look at.
		local alpha = settle(ns, 0.5)
		if alpha ~= 1 then fail(scenario, "the window faded over Who to buff, to " .. alpha) end

		-- A reason line under Prompt wording, typed into and left for
		-- Diagnostics: every row above it on Look came back before.
		click(UI.side.buttons.appearance)
		UI.State().open["appearance.wording"] = true
		UI.Refresh()
		local reason = UI.RowFor("advanced.reasonTarget")
		if not (reason and reason.box and UI.RowShown("advanced.reasonTarget")) then
			fail(scenario, "SKIPPED -- no reason box under Prompt wording")
			return
		end
		Mock.type(reason.box, "your target!")
		click(UI.side.buttons.diagnostics)
		left = rowsShown(UI, "appearance")
		if left > 0 then
			fail(scenario, left .. " of Look's rows are still drawn over Diagnostics after leaving a reason box")
		end
		if ns.db.profile.prompt.reasonTarget ~= "your target!" then
			fail(scenario, "the reason typed was not kept as the page changed: "
				.. tostring(ns.db.profile.prompt.reasonTarget))
		end
	end, { focusRule = true })
end

-- ------------------------------------------------------------------ slider and box
-- Clicked into Scale's box, then the slider dragged: the box went on holding
-- the old number while it had the keyboard, and put it back as soon as it lost
-- it. The same with the exact position's nudge arrows.
do
	local scenario = "hunt19-options: a drag or a nudge beside a box that had the keyboard is what stays"
	with(scenario, "appearance", function(ns, UI)
		local scale, alpha = UI.RowFor("appearance.scale"), UI.RowFor("appearance.alpha")
		if not (scale and scale.slider and alpha and alpha.box and UI.RowShown("appearance.scale")) then
			fail(scenario, "SKIPPED -- no Scale slider or Opacity box on Look")
			return
		end
		scale.box:SetFocus()
		Mock.mouseDown(scale.slider)
		Mock.drag(scale.slider, 2)
		Mock.mouseUp(scale.slider)
		if scale.box:GetText() ~= "2.00" then
			fail(scenario, "dragged to 2, the Scale box beside the slider reads " .. tostring(scale.box:GetText()))
		end
		-- Another box clicked into: the Scale box loses the keyboard if it
		-- still had it.
		alpha.box:SetFocus()
		if ns.db.profile.prompt.scale ~= 2 then
			fail(scenario, "clicking into Opacity put the dragged Scale back to " .. tostring(ns.db.profile.prompt.scale))
		end
		alpha.box:ClearFocus()

		UI.State().open["appearance.exactPos"] = true
		UI.Refresh()
		local x = UI.RowFor("advanced.x")
		if not (x and x.up and x.box and UI.RowShown("advanced.x")) then
			fail(scenario, "SKIPPED -- no Left / right box under the exact position")
			return
		end
		local from = tonumber(x.box:GetText()) or 0
		x.box:SetFocus()
		for _ = 1, 3 do
			Mock.mouseDown(x.up)
			x.up:Click("LeftButton")
			Mock.mouseUp(x.up)
		end
		if tonumber(x.box:GetText()) ~= from + 3 then
			fail(scenario, "three clicks on the up arrow and the Left / right box reads " .. tostring(x.box:GetText()))
		end
		-- Enter, as the player presses it next.
		Mock.press(x.box, "ENTER")
		if tonumber(ns.db.profile.prompt.x) ~= from + 3 then
			fail(scenario, "three nudges up, then Enter, and the position is back at " .. tostring(ns.db.profile.prompt.x))
		end
	end)
end

-- ------------------------------------------------------------------ a lost release
-- 1.6.1 let the window's fade go once the mouse button is up, because the
-- slider's OnMouseUp can go missing. The slider's own hold stayed: the next
-- press on it did not fade the window, and the slider and its box showed
-- where the drag ended instead of the setting.
do
	local scenario = "hunt19-options: a slider whose release went missing follows the setting again"
	with(scenario, "appearance", function(ns, UI)
		local scale = UI.RowFor("appearance.scale")
		if not (scale and scale.slider and UI.RowShown("appearance.scale")) then
			fail(scenario, "SKIPPED -- no Scale slider on Look")
			return
		end
		Mock.mouseDown(scale.slider)
		Mock.drag(scale.slider, 1.5)
		-- The button comes up; the slider never hears it.
		Mock.buttonsDown.LeftButton = nil
		Mock.advance(2)
		settle(ns, 0.5)
		Mock.mouseDown(scale.slider)
		local alpha = settle(ns, 0.3)
		if math.abs(alpha - 0.25) > 0.001 then
			fail(scenario, "pressing Scale again after a lost release left the window at " .. alpha)
		end
		Mock.drag(scale.slider, 1.6)
		Mock.buttonsDown.LeftButton = nil
		Mock.advance(2)
		Mock.type(scale.box, "2")
		Mock.press(scale.box, "ENTER")
		if ns.db.profile.prompt.scale ~= 2 then
			fail(scenario, "SKIPPED -- typing 2 into Scale set it to " .. tostring(ns.db.profile.prompt.scale))
			return
		end
		if scale.slider:GetValue() ~= 2 or scale.box:GetText() ~= "2.00" then
			fail(scenario, ("typed 2 after a lost release: the slider is at %s and the box reads %s")
				:format(tostring(scale.slider:GetValue()), tostring(scale.box:GetText())))
		end
	end)
end

-- ------------------------------------------------------------------ the key button
-- Clicked straight from the search box: the box kept the keyboard, and the
-- client gives keys to the box with the focus before any frame that asked for
-- them, so the key typed into the search instead of being bound.
do
	local scenario = "hunt19-options: the key button takes the keyboard from a box that had it"
	with(scenario, "general", function(ns, UI)
		GetCurrentKeyBoardFocus = function() return Mock.focus end
		local row = UI.RowFor("general.bindKey")
		local box = UI.search and UI.search.box
		if not (row and row.button and box and UI.RowShown("general.bindKey")) then
			fail(scenario, "SKIPPED -- no key button on Start here, or no search box")
			return
		end
		box:SetFocus()
		click(row.button)
		if ns.WindowWidgets.Capturing() ~= row then
			fail(scenario, "SKIPPED -- clicking the key button did not start waiting for a key")
			return
		end
		if Mock.focus ~= nil then
			fail(scenario, "waiting for a key, the search box kept the keyboard: the key would be typed into it")
		end
		Mock.keyDown(row.button, "F")
		if ns.WindowBind.Value(row.item) ~= "F" then
			fail(scenario, "F pressed while the key button waited bound " .. tostring(ns.WindowBind.Value(row.item)))
		end
	end)
end

-- ------------------------------------------------------------------ a long dropdown
-- The client's menu is kept on the screen and scrolls only when it is told it
-- may; a font or sound list from a media pack ran off the edge out of reach.
do
	local scenario = "hunt19-options: a dropdown longer than the screen scrolls"
	local LSM = LibStub("LibSharedMedia-3.0")
	local fonts = LSM.media.font
	local many = {}
	for k, v in pairs(fonts or {}) do many[k] = v end
	for i = 1, 60 do many[("Pack font %02d"):format(i)] = ("pack%02d.ttf"):format(i) end
	LSM.media.font = many
	with(scenario, "appearance", function(ns, UI)
		Mock.useMenu()
		UI.State().open["appearance.text"] = true
		UI.Refresh()
		local row = UI.RowFor("appearance.font")
		if not (row and row.field and UI.RowShown("appearance.font")) then
			fail(scenario, "SKIPPED -- no Font dropdown on Look")
			return
		end
		click(row.field)
		local menu = Mock.menu
		if not menu or #menu.entries < 60 then
			fail(scenario, "SKIPPED -- the Font menu holds " .. tostring(menu and #menu.entries) .. " entries")
			return
		end
		local extent = menu.root.scrollExtent
		if type(extent) ~= "number" then
			fail(scenario, "the Font menu of " .. #menu.entries .. " entries never scrolls: past the screen's edge they cannot be picked")
		elseif extent > 600 or extent < 100 then
			fail(scenario, "the Font menu scrolls only past " .. extent .. " units")
		end
	end)
	LSM.media.font = fonts
end

-- ------------------------------------------------------------------ a rogue's reset
-- What I say is a rogue's one page with a list to put back (the /thank), but
-- the footer asked the reset's tab too -- Advanced, which a class with no
-- prompt does not have -- so the button never showed for them.
do
	local scenario = "hunt19-options: a rogue's What I say has its reset"
	with(scenario, "click", function(ns, UI)
		if UI.page ~= "click" then
			fail(scenario, "SKIPPED -- a rogue cannot open What I say")
			return
		end
		if not UI.footer.reset:IsShown() then
			fail(scenario, "a rogue's What I say, with a list to put back, has no Put these back to default")
			return
		end
		ns.db.profile.prompt.thankEmote = true
		click(UI.footer.reset)
		local asking = ns.WindowWidgets.Asking()
		if not asking then
			fail(scenario, "the reset did not ask first")
			return
		end
		click(asking.yes)
		if ns.db.profile.prompt.thankEmote ~= false then
			fail(scenario, "a rogue's reset left /thank people who buff me on")
		end
		for _, id in ipairs({ "general", "profiles", "diagnostics" }) do
			ns.OpenOptions(id)
			if UI.page == id and UI.footer.reset:IsShown() then
				fail(scenario, "a rogue has a reset button on " .. id .. ", which has nothing to put back")
			end
		end
	end, { class = "ROGUE" })
end

-- ------------------------------------------------------------------ the shared table
-- AceDBOptions hands every addon that asks the same table of controls. The
-- tab wrote into it, so another addon's Profiles tab lost the library's
-- paragraph and gained Manners' intro and share boxes, the paste box there
-- importing into Manners.
do
	local scenario = "hunt19-options: the Profiles tab never writes into the table every addon shares"
	with(scenario, "general", function(ns, UI)
		local lib = LibStub("AceDBOptions-3.0")
		local mine = ns.optionsTable.args.profiles
		local other = lib:GetOptionsTable({ profile = {} })
		if not (mine and other and type(other.args) == "table") then
			fail(scenario, "SKIPPED -- no Profiles tab, or no library table to compare it with")
			return
		end
		if other.args == mine.args then
			fail(scenario, "the Profiles tab's controls are the library's own table, shared with every other addon")
		end
		for _, key in ipairs({ "profilesIntro", "shareHeader", "shareNote", "shareCopy", "shareText", "sharePaste" }) do
			if other.args[key] ~= nil then
				fail(scenario, key .. " shows on another addon's Profiles tab")
			end
		end
		if type(other.args.desc) == "table" and other.args.desc.hidden then
			fail(scenario, "another addon's Profiles tab lost the library's own paragraph")
		end
		-- The library's own controls are still on ours, its handler with them.
		if not (type(mine.args.desc) == "table" and mine.args.desc.hidden) then
			fail(scenario, "the library's paragraph is not hidden under the intro on the Profiles tab")
		end
		if mine.handler == nil or mine.handler ~= lib.handlers[ns.db] then
			fail(scenario, "the Profiles tab lost the handler the library's controls are called on")
		end
	end)
end

-- And a newer copy of the library, loading after Manners and before the
-- window is first opened, puts a fresh table in every group it handed out,
-- which took the share boxes off the tab /manners export sends the player to.
do
	local scenario = "hunt19-options: the Profiles tab keeps its share boxes when a newer AceDBOptions loads"
	with(scenario, "general", function(ns, UI)
		local mine = ns.optionsTable.args.profiles
		for _, key in ipairs({ "profilesIntro", "shareHeader", "shareText", "sharePaste" }) do
			if mine.args[key] == nil then
				fail(scenario, "after a newer AceDBOptions loaded, the Profiles tab lost " .. key)
			end
		end
		if not (type(mine.args.desc) == "table" and mine.args.desc.hidden) then
			fail(scenario, "after a newer AceDBOptions loaded, the library's paragraph is back above the intro")
		end
		ns.addon:HandleSlash("export")
		if not UI.RowShown("profiles.shareText") then
			fail(scenario, "/manners export sent the player to a box the Profiles tab no longer has")
		end
	end, { beforeOpen = function() LibStub("AceDBOptions-3.0"):Upgrade() end })
end

-- ------------------------------------------------------------------ a pasted /thank
-- An emote is seen by everybody nearby, so it is off until the player puts it
-- on; a pasted string kept only speaking off, and switched the /thank on
-- without a word.
do
	local scenario = "hunt19-options: a pasted string never switches on the /thank"
	with(scenario, "general", function(ns, UI)
		local p = ns.db.profile
		p.prompt.thankEmote = true
		local text = ns.ExportSettings()
		p.prompt.thankEmote = false
		local ok, message = ns.ImportSettings(text)
		message = tostring(message)
		if not ok then
			fail(scenario, "SKIPPED -- a string with the /thank on was refused: " .. message)
			return
		end
		if p.prompt.thankEmote ~= false then
			fail(scenario, "an imported string switched on /thank people who buff me, which everybody near sees")
		elseif not message:find("everybody near you sees it", 1, true) then
			fail(scenario, "the import left the /thank off without saying so: " .. message)
		end
		-- The player's own, on, stays on, and nothing is said about it.
		p.prompt.thankEmote = true
		ok, message = ns.ImportSettings(ns.ExportSettings())
		if p.prompt.thankEmote ~= true then
			fail(scenario, "an import turned off the player's own /thank")
		elseif tostring(message):find("everybody near you sees it", 1, true) then
			fail(scenario, "the import said it held back a /thank the player already had on: " .. tostring(message))
		end
		-- The undo puts back exactly what the player had.
		p.prompt.thankEmote = false
		ns.ImportSettings(text)
		p.prompt.thankEmote = true
		ns.UndoImport()
		if p.prompt.thankEmote ~= false then
			fail(scenario, "/manners import undo did not put the /thank back as it was")
		end
	end)
end

-- ------------------------------------------------------------------ /manners macro
-- Start here says whether the macro is made, and the sidebar warns while
-- there is neither a key nor a macro; /manners macro made it and left both
-- as they were until something else repainted.
do
	local scenario = "hunt19-options: /manners macro repaints Start here"
	with(scenario, "general", function(ns, UI)
		CreateMacro = function(name)
			Mock.macros = { [name] = 1 }
			return 1
		end
		local row = UI.RowFor("general.bindStatus")
		local function painted() return tostring(row and row.text and row.text:GetText()) end
		if not (row and UI.RowShown("general.bindStatus") and painted():find("No key yet", 1, true)) then
			fail(scenario, "SKIPPED -- Start here does not start without a key: " .. painted())
			return
		end
		ns.addon:HandleSlash("macro")
		if not ns.Setup.MacroMade() then
			fail(scenario, "SKIPPED -- /manners macro made no macro")
			return
		end
		if not painted():find("macro is made", 1, true) then
			fail(scenario, "/manners macro made the macro and Start here still says: " .. painted())
		end
	end)
end
