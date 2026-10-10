-- The options window's controls (Options/Window/Widgets*.lua), each built
-- against a real definition of the model and driven the way a player drives
-- it: clicked, picked from the menu, dragged, typed into, confirmed, held.
-- What is checked is the profile afterwards, and what the row then shows.
--
-- Called by scenarios.lua with the addon directory and its helpers. The frames
-- are tests/mockwidgets.lua's: a disabled button ignores Click(), a box fires
-- its focus and text scripts, a slider its OnValueChanged.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- A loaded, driven addon, and the window's side of the contract: a frame to
-- build on, and a record of every change and hold the controls report.
local function session(scenario)
	Mock.reset()
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local ctx = { changes = {}, holds = {}, pages = {}, relayouts = 0 }
	ctx.Window = CreateFrame("Frame", "MannersOptionsTest", UIParent)
	ctx.Window:SetSize(820, 600)
	ctx.OnChange = function(item) ctx.changes[#ctx.changes + 1] = item.path end
	ctx.OnHold = function(on) ctx.holds[#ctx.holds + 1] = on end
	ctx.ScrollPage = function(delta) ctx.pages[#ctx.pages + 1] = delta end
	ctx.Relayout = function(row) ctx.relayouts = ctx.relayouts + 1 row:Layout(row.width) end
	return ns, ctx
end

-- The row for one control of the model, laid out at `width`.
local function build(scenario, ns, ctx, kind, path, layout, width)
	local item = ns.WindowBind.Item(path, layout or {}, ctx)
	if not item then
		fail(scenario, "SKIPPED -- the model has no " .. path)
		return nil
	end
	local row = ns.WindowWidgets.Build(kind, ctx.Window, item)
	row:Layout(width or 560)
	return row
end

local function changed(ctx, path)
	for _, p in ipairs(ctx.changes) do
		if p == path then return true end
	end
	return false
end

local function same(a, b)
	return math.abs((a or 0) - (b or 0)) < 1e-6
end

-- Runs one scenario: a throw is a failure of that scenario, named, and the
-- rest of the file still runs.
local function run(scenario, body)
	local ok, err = pcall(body, scenario)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	Mock.reset()
end

local NEVER = { "who.neverNote", "who.neverPick", "who.neverRemove", "who.neverAdd", "who.neverClear" }

-- ------------------------------------------------------------------ every kind
run("widgets: every kind builds from the model and lays out", function(scenario)
	local ns, ctx = session(scenario)
	if ns then
		local W = ns.WindowWidgets
		local kinds = {
			{ "toggle", "who.skipPvP" }, { "select", "appearance.style" }, { "range", "appearance.alpha" },
			{ "input", "advanced.format" }, { "multiline", "click.phrases" }, { "execute", "profiles.shareCopy" },
			{ "keybinding", "general.bindKey" }, { "color", "appearance.bgColor" },
			{ "multiselect", "who.skipRaidGroups", { columns = 4 } }, { "description", "advanced.formatHelp" },
			{ "header", "who.neverHeader" }, { "number", "advanced.x", { widget = "number" } },
		}
		for _, k in ipairs(kinds) do
			local row = build(scenario, ns, ctx, k[1], k[2], k[3])
			if row then
				for _, width in ipairs({ 560, 280 }) do
					local h = row:Layout(width)
					if not (type(h) == "number" and h > 0) then
						fail(scenario, ("%s (%s) is %s tall at %d"):format(k[2], k[1], tostring(h), width))
					elseif row.frame._height ~= h or row.frame._width ~= width then
						fail(scenario, k[2] .. "'s frame is not the size its layout answered")
					end
				end
				local natural = row:NaturalWidth()
				if not (type(natural) == "number" and natural > 0) then
					fail(scenario, k[2] .. " has no natural width: " .. tostring(natural))
				end
				for _, fn in ipairs({ "Refresh", "Flash", "Focus" }) do
					if type(row[fn]) ~= "function" then fail(scenario, k[2] .. " has no " .. fn) end
				end
			end
		end
		local never = W.Build("never", ctx.Window, { layout = { composite = "never", ids = NEVER }, ctx = ctx })
		if not (never:Layout(560) > 0) then fail(scenario, "the never-offer list lays out to nothing") end
		local section = W.Build("header", ctx.Window, { title = "Size", ctx = ctx })
		section:Layout(560)
		if section.text:GetText() ~= "Size" then
			fail(scenario, "a section title passed as text reads " .. tostring(section.text:GetText()))
		end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ notes and titles
run("widgets: notes keep their colours and take the font their size asks for", function(scenario)
	local ns, ctx = session(scenario)
	if ns then
		local T = ns.WindowWidgets.Theme
		local small = build(scenario, ns, ctx, "description", "advanced.formatHelp")
		local medium = build(scenario, ns, ctx, "description", "who.neverNote")
		local lead = build(scenario, ns, ctx, "description", "general.howItWorks", { lead = true })
		if small and medium and lead then
			if small.text:GetFontObject() ~= GameFontHighlightSmall then
				fail(scenario, "a note with no fontSize is not in GameFontHighlightSmall")
			end
			if medium.text:GetFontObject() ~= GameFontHighlight then
				fail(scenario, "a medium note is not in GameFontHighlight")
			end
			local _, base = (lead.item.def.fontSize == "medium" and GameFontHighlight or GameFontHighlightSmall):GetFont()
			local _, size = lead.text:GetFont()
			if size ~= base + 2 then
				fail(scenario, ("the lead is drawn at %s, not a size up from %d"):format(tostring(size), base))
			end
			local text = small.text:GetText() or ""
			if not text:find("|cff888888", 1, true) then
				fail(scenario, "the colour code in Placeholders' second line was lost: " .. text)
			end
			if text:find("^%s") or text:find("%s$") then
				fail(scenario, "a note keeps AceConfig's blank lines at its ends")
			end
		end
		local header = build(scenario, ns, ctx, "header", "who.neverHeader")
		if header then
			local _, size = header.text:GetFont()
			local c = header.text._textColor or {}
			if size ~= 13 or not (same(c[1], T.gold[1]) and same(c[2], T.gold[2]) and same(c[3], T.gold[3])) then
				fail(scenario, "a section title is not gold Friz 13")
			end
			if not (header.rule and header.rule.points and #header.rule.points == 2) then
				fail(scenario, "a section title has no rule running on from it")
			end
		end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ toggle
run("widgets: clicking a toggle changes the profile", function(scenario)
	local ns, ctx = session(scenario)
	local row = ns and build(scenario, ns, ctx, "toggle", "who.skipPvP")
	if row then
		local F = ns.db.profile.filters
		local was = F.skipPvP == true
		if row.box.check:IsShown() ~= was then fail(scenario, "the check does not show the setting") end
		row.hit:Click()
		if F.skipPvP ~= not was then
			fail(scenario, "Skip players flagged for PvP did not change: " .. tostring(F.skipPvP))
		end
		if row.box.check:IsShown() == was then fail(scenario, "the check did not follow the click") end
		if not changed(ctx, "who.skipPvP") then fail(scenario, "the window was not told of the change") end
		row.hit:Click()
		if F.skipPvP ~= was then fail(scenario, "a second click did not put it back") end
		if (row.label:GetText() or "") ~= ns.L["Skip players flagged for PvP"] then
			fail(scenario, "the label reads " .. tostring(row.label:GetText()))
		end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ select
run("widgets: picking from the menu sets the dropdown", function(scenario)
	local ns, ctx = session(scenario)
	if ns then Mock.useMenu() end
	local row = ns and build(scenario, ns, ctx, "select", "appearance.style")
	if row then
		local P = ns.db.profile.prompt
		row.field:Click()
		local radios = 0
		for _, e in ipairs(Mock.menu and Mock.menuEntries() or {}) do
			if e.kind == "radio" then radios = radios + 1 end
		end
		local values = ns.WindowBind.Values(row.item)
		if radios ~= #values or radios < 2 then
			fail(scenario, ("the menu has %d choices for %d looks"):format(radios, #values))
		else
			local current, other
			for _, v in ipairs(values) do
				if v[1] == P.style then current = v else other = other or v end
			end
			if not (current and Mock.menuChosen(current[2])) then
				fail(scenario, "the menu does not mark the look in use")
			end
			Mock.pickMenu(other[2])
			if P.style ~= other[1] then
				fail(scenario, ("picking %s left the style at %s"):format(other[2], tostring(P.style)))
			end
			if row.value:GetText() ~= other[2] then
				fail(scenario, "the field reads " .. tostring(row.value:GetText()) .. " after the pick")
			end
			if not changed(ctx, "appearance.style") then fail(scenario, "the window was not told of the pick") end
		end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ range
run("widgets: the slider snaps to its step and holds the window while held", function(scenario)
	local ns, ctx = session(scenario)
	local row = ns and build(scenario, ns, ctx, "range", "appearance.alpha")
	if row then
		local P = ns.db.profile.prompt
		P.alpha = 1
		row:Refresh()
		if row.box:GetText() ~= "100%" then fail(scenario, "Opacity reads " .. tostring(row.box:GetText())) end
		if row.low:GetText() ~= "10%" or row.high:GetText() ~= "100%" then
			fail(scenario, "the ends read " .. tostring(row.low:GetText()) .. " and " .. tostring(row.high:GetText()))
		end
		Mock.mouseDown(row.slider)
		if ctx.holds[#ctx.holds] ~= true then fail(scenario, "holding the slider did not tell the window") end
		Mock.drag(row.slider, 0.537)
		if P.alpha ~= 0.55 then fail(scenario, "a drag to 0.537 set the opacity to " .. tostring(P.alpha)) end
		if row.box:GetText() ~= "55%" then fail(scenario, "the value box reads " .. tostring(row.box:GetText())) end
		-- A repaint while the thumb is held leaves it under the pointer.
		P.alpha = 0.3
		row:Refresh()
		if not same(row.slider:GetValue(), 0.55) then fail(scenario, "a repaint moved the thumb being dragged") end
		Mock.mouseUp(row.slider)
		if ctx.holds[#ctx.holds] ~= false then fail(scenario, "letting go did not tell the window") end
		if not same(row.slider:GetValue(), 0.3) then fail(scenario, "letting go did not show the value") end
		-- A value between steps (the client's wheel, or a drag not held to
		-- the step) is snapped by the row itself.
		row.slider.scripts.OnValueChanged(row.slider, 0.712, true)
		if P.alpha ~= 0.7 then fail(scenario, "an unsnapped 0.712 set the opacity to " .. tostring(P.alpha)) end
		Mock.type(row.box, "40")
		Mock.press(row.box, "ENTER")
		if P.alpha ~= 0.4 then fail(scenario, "typing 40 set the opacity to " .. tostring(P.alpha)) end
		if row.box:HasFocus() or row.box:GetText() ~= "40%" then
			fail(scenario, "after Enter the box reads " .. tostring(row.box:GetText()))
		end
		Mock.type(row.box, "5")
		Mock.press(row.box, "ENTER")
		if P.alpha ~= 0.1 then fail(scenario, "5% was not held at the 10% floor: " .. tostring(P.alpha)) end
		local scale = build(scenario, ns, ctx, "range", "appearance.scale")
		P.scale = 1.5
		scale:Refresh()
		-- Every decimal the step has, zeros too, as the mock-up shows them.
		if scale.box:GetText() ~= "1.50" then fail(scenario, "a scale of 1.5 reads " .. tostring(scale.box:GetText())) end
		if scale.low:GetText() ~= "0.50" or scale.high:GetText() ~= "3.00" then
			fail(scenario, "the scale's ends read " .. tostring(scale.low:GetText()) .. " and " .. tostring(scale.high:GetText()))
		end
		P.scale = 1
		scale:Refresh()
		if scale.box:GetText() ~= "1.00" then fail(scenario, "a scale of 1 reads " .. tostring(scale.box:GetText())) end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ input
run("widgets: Enter commits a one-line box and Escape puts it back", function(scenario)
	local ns, ctx = session(scenario)
	local row = ns and build(scenario, ns, ctx, "input", "advanced.format")
	if row then
		local P = ns.db.profile.prompt
		Mock.type(row.box, "{name} -- {buff}")
		if P.format == "{name} -- {buff}" then fail(scenario, "typing committed before Enter") end
		Mock.press(row.box, "ENTER")
		if P.format ~= "{name} -- {buff}" then fail(scenario, "Enter did not commit: " .. tostring(P.format)) end
		if row.box:HasFocus() then fail(scenario, "the box kept the focus after Enter") end
		-- An empty first line snaps back to the default, and the box shows it.
		Mock.type(row.box, "")
		Mock.press(row.box, "ENTER")
		local default = ns.defaults.profile.prompt.format
		if P.format ~= default or row.box:GetText() ~= default then
			fail(scenario, "an empty first line left " .. tostring(P.format) .. " / " .. tostring(row.box:GetText()))
		end
		Mock.type(row.box, "half {name}")
		Mock.press(row.box, "ESCAPE")
		if P.format ~= default or row.box:GetText() ~= default or row.box:HasFocus() then
			fail(scenario, "Escape did not put the box back and let go")
		end
		-- Leaving an ordinary box commits what is in it.
		Mock.type(row.box, "left {name}")
		row.box:ClearFocus()
		if P.format ~= "left {name}" then fail(scenario, "leaving the box lost what was typed") end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ multiline
run("widgets: Accept commits a box of many lines", function(scenario)
	local ns, ctx = session(scenario)
	local row = ns and build(scenario, ns, ctx, "multiline", "click.phrases")
	if row then
		local SP = ns.db.profile.speech
		SP.presetChoice = "polite"
		SP.phrases = ns.PhraseSetText("polite")
		row:Refresh()
		if row.accept:IsEnabled() then fail(scenario, "Accept is lit before anything was typed") end
		local _, size = row.box:GetFont()
		if row.scroll._height ~= 26 * (size + 3) + 12 then
			fail(scenario, "the lines box is " .. tostring(row.scroll._height) .. " tall for 26 lines")
		end
		Mock.type(row.box, "Thank you, {name}.\nMuch obliged.")
		if not row.accept:IsEnabled() then fail(scenario, "Accept stays dark with new lines typed") end
		if SP.phrases == "Thank you, {name}.\nMuch obliged." then fail(scenario, "typing committed before Accept") end
		row.accept:Click()
		if SP.phrases ~= "Thank you, {name}.\nMuch obliged." then
			fail(scenario, "Accept did not commit the lines: " .. tostring(SP.phrases))
		end
		if row.accept:IsEnabled() or row.box:HasFocus() then fail(scenario, "Accept stays lit, or the box focused") end
		-- A read-only box throws typing away and selects all of itself.
		ns.OptionsPage.shareOpen = true
		local share = build(scenario, ns, ctx, "multiline", "profiles.shareText")
		if share then
			local text = share.box:GetText()
			if share.accept then fail(scenario, "the settings as text have an Accept button") end
			Mock.type(share.box, "junk")
			if share.box:GetText() ~= text then fail(scenario, "typing into the settings as text was kept") end
			if not share.box._highlight then fail(scenario, "the settings as text are not selected for copying") end
		end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ confirm
run("widgets: a confirm asks first; No leaves it, Yes does it", function(scenario)
	local ns, ctx = session(scenario)
	if ns then Mock.useMenu() end
	local row = ns and build(scenario, ns, ctx, "select", "click.preset")
	if row then
		local W, SP = ns.WindowWidgets, ns.db.profile.speech
		SP.presetChoice = "roleplay"
		SP.phrases = "My own line, {name}."
		row:Refresh()
		local label
		for _, v in ipairs(ns.WindowBind.Values(row.item)) do
			if v[1] == "polite" then label = v[2] end
		end
		row.field:Click()
		Mock.pickMenu(label)
		local modal = W.Asking()
		if not modal then
			fail(scenario, "picking a line set did not ask first")
		else
			if not tostring(modal.text:GetText()):find(label, 1, true) then
				fail(scenario, "the confirm does not name the set: " .. tostring(modal.text:GetText()))
			end
			modal.no:Click()
			if SP.phrases ~= "My own line, {name}." or W.Asking() then
				fail(scenario, "No replaced the lines, or left the box up")
			end
			row.field:Click()
			Mock.pickMenu(label)
			modal = W.Asking()
			if modal then modal.yes:Click() end
			if SP.phrases ~= ns.PhraseSetText("polite") then fail(scenario, "Yes did not load the polite lines") end
			if row.value:GetText() ~= label then fail(scenario, "the field reads " .. tostring(row.value:GetText())) end
		end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ validate
run("widgets: a refused value says why in red and keeps what was typed", function(scenario)
	local ns, ctx = session(scenario)
	if ns then
		-- AceDBOptions' own "New" box, as the library defines it (the mock's
		-- library builds only its paragraph), on the Profiles group's handler.
		local usage = "Profile names cannot be longer than 50 characters."
		local profiles = ns.optionsTable.args.profiles
		profiles.handler = { db = ns.db, SetProfile = function(self, _, value) self.db:SetProfile(value) end }
		profiles.args.new = { type = "input", name = "New", order = 30, get = false, set = "SetProfile", usage = usage,
			validate = function(_, text)
				local n = select(2, tostring(text):gsub("[^\128-\191]", ""))
				if n > 50 or n == 0 or text:find("^ +$") then return false end
				return true
			end }
	end
	local row = ns and build(scenario, ns, ctx, "input", "profiles.new")
	if row then
		local T = ns.WindowWidgets.Theme
		local before = row:Layout(560)
		local long = ("a"):rep(51)
		Mock.type(row.box, long)
		Mock.press(row.box, "ENTER")
		if row.err:GetText() ~= "Profile names cannot be longer than 50 characters." or not row.err:IsShown() then
			fail(scenario, "a 51-letter name says " .. tostring(row.err:GetText()))
		end
		local c = row.err._textColor or {}
		if not same(c[1], T.red[1]) then fail(scenario, "the refusal is not red") end
		if row.box:GetText() ~= long or not row.box:HasFocus() then fail(scenario, "the refused name was not kept") end
		if (Mock.sv.profileName or "Default") ~= "Default" then fail(scenario, "a refused name made a profile") end
		if not (row.height > before and ctx.relayouts > 0) then fail(scenario, "the refusal took no room under the box") end
		-- A repaint keeps the refused text for fixing.
		row.box:ClearFocus()
		row:Refresh()
		if row.box:GetText() ~= long then fail(scenario, "a repaint threw the refused name away") end
		Mock.type(row.box, "Alt")
		if row.err:IsShown() then fail(scenario, "the refusal stays up while the name is fixed") end
		Mock.press(row.box, "ENTER")
		if Mock.sv.profileName ~= "Alt" then fail(scenario, "Enter did not make the profile Alt") end
		if row.box:GetText() ~= "" then fail(scenario, "the New box was not emptied: " .. tostring(row.box:GetText())) end
		-- The paste box's own validate, from the model: the parser's reason.
		local paste = build(scenario, ns, ctx, "multiline", "profiles.sharePaste")
		if paste then
			Mock.type(paste.box, "not settings at all")
			paste.accept:Click()
			local msg = paste.err:GetText() or ""
			if msg == "" or not paste.err:IsShown() or paste.box:GetText() ~= "not settings at all" then
				fail(scenario, "pasting nonsense did not say why and keep it: " .. msg)
			end
		end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ keybinding
run("widgets: a captured key reaches Setup.SetKey", function(scenario)
	local ns, ctx = session(scenario)
	local row = ns and build(scenario, ns, ctx, "keybinding", "general.bindKey")
	if row then
		local W, Setup = ns.WindowWidgets, ns.Setup
		row.button:Click("LeftButton")
		if W.Capturing() ~= row or not row.button._keyboard or row.button._propagate ~= false then
			fail(scenario, "a click did not start listening for the key")
		end
		Mock.modifiers.shift = true
		Mock.keyDown(row.button, "LSHIFT")
		if W.Capturing() ~= row then fail(scenario, "Shift on its own ended the capture") end
		Mock.keyDown(row.button, "F")
		Mock.modifiers.shift = false
		if Setup.Key() ~= "SHIFT-F" or Mock.bindings["SHIFT-F"] ~= Setup.COMMAND or Mock.bindingsSaved < 1 then
			fail(scenario, "Shift-F was not bound and saved: " .. tostring(Setup.Key()))
		end
		if W.Capturing() or row.button._keyboard then fail(scenario, "the button kept the keyboard") end
		if row.button.text:GetText() ~= "SHIFT-F" then fail(scenario, "the button reads " .. tostring(row.button.text:GetText())) end
		Mock.modifiers.alt, Mock.modifiers.ctrl = true, true
		row.button:Click("LeftButton")
		Mock.keyDown(row.button, "K")
		Mock.modifiers.alt, Mock.modifiers.ctrl = false, false
		if Setup.Key() ~= "ALT-CTRL-K" then fail(scenario, "Alt and Ctrl came out as " .. tostring(Setup.Key())) end
		row.button:Click("LeftButton")
		Mock.keyDown(row.button, "ESCAPE")
		if W.Capturing() or Setup.Key() ~= "ALT-CTRL-K" then fail(scenario, "Escape did not cancel") end
		row.button:Click("RightButton")
		if Setup.Key() ~= nil or row.button.text:GetText() ~= NOT_BOUND then
			fail(scenario, "a right-click did not clear the key: " .. tostring(Setup.Key()))
		end
		-- In a fight the control is greyed out by its own disabled, and one
		-- that was listening lets go of the keyboard at the repaint.
		row.button:Click("LeftButton")
		Mock.inCombat = true
		row:Refresh()
		if W.Capturing() or row.button._keyboard then fail(scenario, "a fight left the key button holding the keyboard") end
		row.button:Click("LeftButton")
		row.button.scripts.OnClick(row.button, "LeftButton")
		if W.Capturing() then fail(scenario, "the key could be captured in combat") end
		Mock.inCombat = false
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ color
run("widgets: a colour shows live, and Cancel puts it back", function(scenario)
	local ns, ctx = session(scenario)
	local row = ns and build(scenario, ns, ctx, "color", "appearance.bgColor")
	if row then
		local P = ns.db.profile.prompt
		local was = { P.bgColor[1], P.bgColor[2], P.bgColor[3], P.bgColor[4] }
		row.hit:Click()
		if not ColorPickerFrame:IsShown() then fail(scenario, "the colour picker did not open") end
		local info = ColorPickerFrame._info or {}
		if not (info.hasOpacity == true and same(info.opacity, was[4]) and same(info.r, was[1])) then
			fail(scenario, "the picker did not open on the panel colour with its opacity")
		end
		if ctx.holds[#ctx.holds] ~= true then fail(scenario, "the window was not told the picker is open") end
		Mock.pickColour(0.2, 0.4, 0.6, 0.5)
		local c = P.bgColor
		if not (same(c[1], 0.2) and same(c[2], 0.4) and same(c[3], 0.6) and same(c[4], 0.5)) then
			fail(scenario, "the colour did not follow the picker live")
		end
		Mock.closeColour(false)
		c = P.bgColor
		if not (same(c[1], was[1]) and same(c[2], was[2]) and same(c[3], was[3]) and same(c[4], was[4])) then
			fail(scenario, "Cancel did not put the colour back")
		end
		if ctx.holds[#ctx.holds] ~= false then fail(scenario, "the window was not told the picker shut") end
		row.hit:Click()
		Mock.pickColour(0.9, 0.1, 0.1, 0.7)
		Mock.closeColour(true)
		if not same(P.bgColor[1], 0.9) then fail(scenario, "Okay did not keep the colour") end
		local swatch = row.colour._color or {}
		if not same(swatch[1], 0.9) then fail(scenario, "the swatch does not show the new colour") end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ multiselect
run("widgets: a grid of checkboxes ticks and unticks one group", function(scenario)
	local ns, ctx = session(scenario)
	local row = ns and build(scenario, ns, ctx, "multiselect", "who.skipRaidGroups", { columns = 4 })
	if row then
		local F = ns.db.profile.filters
		ns.db.profile.sources.group = true
		row:Refresh()
		if row.count ~= 8 then fail(scenario, "the grid has " .. tostring(row.count) .. " boxes, not 8") end
		-- Four across: groups 1 to 4 on the first line, 5 under 1.
		local at = {}
		for i = 1, 8 do at[i] = row.boxes[i] and row.boxes[i].points[1] or { 0, 0, 0, 0, 0 } end
		if not (at[4][5] == at[1][5] and at[4][4] > at[1][4] and at[5][4] == at[1][4] and at[5][5] < at[1][5]) then
			fail(scenario, "group 5 does not start the grid's second row of four")
		end
		row.boxes[3]:Click()
		if F.skipRaidGroups[3] ~= true or row.boxes[3].box.check:IsShown() then
			fail(scenario, "unticking group 3 did not stop buffing it")
		end
		row.boxes[3]:Click()
		if F.skipRaidGroups[3] ~= nil then fail(scenario, "ticking group 3 again did not put it back") end
		-- Too narrow for four columns, it takes fewer rather than cutting.
		row:Layout(150)
		local second = row.boxes[2].points[1]
		if second[4] == 0 and second[5] == row.boxes[1].points[1][5] then
			fail(scenario, "a narrow grid stacks two boxes in one place")
		end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ number
run("widgets: the nudge arrows move by one, ten with Shift, within 2000", function(scenario)
	local ns, ctx = session(scenario)
	local row = ns and build(scenario, ns, ctx, "number", "advanced.x", { widget = "number" })
	if row then
		local P = ns.db.profile.prompt
		P.x = 0
		row:Refresh()
		row.up:Click()
		if P.x ~= 1 then fail(scenario, "up moved x to " .. tostring(P.x)) end
		Mock.modifiers.shift = true
		row.up:Click()
		if P.x ~= 11 then fail(scenario, "Shift-up moved x to " .. tostring(P.x)) end
		row.down:Click()
		Mock.modifiers.shift = false
		row.down:Click()
		if P.x ~= 0 then fail(scenario, "down came back to " .. tostring(P.x)) end
		P.x = 1995
		Mock.modifiers.shift = true
		row.up:Click()
		row.up:Click()
		Mock.modifiers.shift = false
		if P.x ~= 2000 then fail(scenario, "x went past 2000 to " .. tostring(P.x)) end
		if row.box:GetText() ~= "2000" then fail(scenario, "the box reads " .. tostring(row.box:GetText())) end
		Mock.mouseDown(row.up)
		if ctx.holds[#ctx.holds] ~= true then fail(scenario, "holding an arrow did not tell the window") end
		Mock.mouseUp(row.up)
		if ctx.holds[#ctx.holds] ~= false then fail(scenario, "letting go of an arrow did not tell the window") end
		Mock.type(row.box, "-37")
		Mock.press(row.box, "ENTER")
		if P.x ~= -37 then fail(scenario, "typing -37 set x to " .. tostring(P.x)) end
		Mock.type(row.box, "-37")
		Mock.press(row.box, "UP")
		if P.x ~= -36 or row.box:GetText() ~= "-36" then fail(scenario, "the up arrow key did not nudge") end
		Mock.press(row.box, "ESCAPE")
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ never
run("widgets: the never-offer list adds, removes and clears", function(scenario)
	local ns, ctx = session(scenario)
	if ns then
		local W = ns.WindowWidgets
		ns.ClearNeverList()
		local row = W.Build("never", ctx.Window, { layout = { composite = "never", ids = NEVER }, ctx = ctx })
		row:Layout(560)
		if row.count ~= 0 or row.list:IsShown() then fail(scenario, "an empty list shows rows") end
		if not tostring(row.note.text:GetText()):find("Nobody is on the list", 1, true) then
			fail(scenario, "the empty list does not say so: " .. tostring(row.note.text:GetText()))
		end
		for _, name in ipairs({ "Velindra", "Brakkus" }) do
			Mock.type(row.add.box, name)
			Mock.press(row.add.box, "ENTER")
		end
		if not (ns.IsNeverOffered("Brakkus") and ns.IsNeverOffered("Velindra")) then
			fail(scenario, "Add a name did not put both on the list")
		end
		if row.add.box:GetText() ~= "" then fail(scenario, "the add box was not emptied") end
		if row.count ~= 2 or row.lines[1].text:GetText() ~= "Brakkus" or not row.list:IsShown() then
			fail(scenario, "the list does not show the two names in order")
		end
		Mock.printed = {}
		row.lines[1].x:Click()
		if ns.IsNeverOffered("Brakkus") or not ns.IsNeverOffered("Velindra") then
			fail(scenario, "the X took the wrong name off")
		end
		if not table.concat(Mock.printed, "\n"):find("Brakkus", 1, true) then
			fail(scenario, "the X did not say Brakkus can be offered again")
		end
		if row.count ~= 1 then fail(scenario, "the list still shows " .. tostring(row.count) .. " names") end
		row.clear.button:Click()
		local modal = W.Asking()
		if not modal then
			fail(scenario, "Clear the list did not ask first")
		else
			modal.yes:Click()
		end
		if #ns.NeverList() ~= 0 or row.count ~= 0 then fail(scenario, "Yes did not clear the list") end
		if row.clear.button:IsEnabled() then fail(scenario, "Clear the list is lit with nobody on it") end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ disabled
run("widgets: a greyed-out control refuses", function(scenario)
	local ns, ctx = session(scenario)
	if ns then
		Mock.useMenu()
		local T = ns.WindowWidgets.Theme
		local P, F = ns.db.profile.prompt, ns.db.profile.filters
		-- Panel colour greys out on the minimal look.
		P.style = "minimal"
		local colour = build(scenario, ns, ctx, "color", "appearance.bgColor")
		if colour then
			colour.hit:Click()
			colour.hit.scripts.OnClick(colour.hit, "LeftButton")
			if ColorPickerFrame:IsShown() then fail(scenario, "a greyed-out colour opened the picker") end
			local c = colour.label._textColor or {}
			if not same(c[1], T.dim[1]) then fail(scenario, "a greyed-out label is not dimmed") end
		end
		-- My target first greys out while Always offer is chosen.
		F.whenBuffed = "always"
		local target = build(scenario, ns, ctx, "toggle", "who.target")
		if target then
			local was = ns.db.profile.priority.target
			target.hit.scripts.OnClick(target.hit, "LeftButton")
			if ns.db.profile.priority.target ~= was then fail(scenario, "a greyed-out toggle changed") end
		end
		-- Where to say it greys out while nothing is said.
		ns.db.profile.speech.enabled = false
		local channel = build(scenario, ns, ctx, "select", "click.channel")
		if channel then
			channel.field.scripts.OnClick(channel.field, "LeftButton")
			if Mock.menus > 0 then fail(scenario, "a greyed-out dropdown opened its menu") end
		end
		-- And a grid, while nobody in the group is offered anything.
		ns.db.profile.sources.group = false
		local grid = build(scenario, ns, ctx, "multiselect", "who.skipRaidGroups", { columns = 4 })
		if grid then
			grid.boxes[1].scripts.OnClick(grid.boxes[1], "LeftButton")
			if F.skipRaidGroups[1] ~= nil then fail(scenario, "a greyed-out grid ticked a box") end
		end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ focus
run("widgets: a repaint leaves a box being typed in alone", function(scenario)
	local ns, ctx = session(scenario)
	local row = ns and build(scenario, ns, ctx, "input", "advanced.format")
	if row then
		local P = ns.db.profile.prompt
		Mock.type(row.box, "half-typed {name}")
		P.format = "{name}, from elsewhere"
		row:Refresh()
		if row.box:GetText() ~= "half-typed {name}" then
			fail(scenario, "a repaint replaced what was being typed: " .. tostring(row.box:GetText()))
		end
		Mock.press(row.box, "ESCAPE")
		if row.box:GetText() ~= "{name}, from elsewhere" then fail(scenario, "Escape did not show the new value") end
		local lines = build(scenario, ns, ctx, "multiline", "click.phrases")
		Mock.type(lines.box, "typing these")
		ns.db.profile.speech.phrases = "changed under it"
		lines:Refresh()
		if lines.box:GetText() ~= "typing these" then fail(scenario, "a repaint replaced lines being typed") end
		local alpha = build(scenario, ns, ctx, "range", "appearance.alpha")
		Mock.type(alpha.box, "7")
		P.alpha = 0.6
		alpha:Refresh()
		if alpha.box:GetText() ~= "7" then fail(scenario, "a repaint replaced a value being typed") end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ chrome
run("widgets: the window's button, confirm, flash and changing labels", function(scenario)
	local ns, ctx = session(scenario)
	if ns then
		local W, T = ns.WindowWidgets, ns.WindowWidgets.Theme
		local clicks = 0
		local b = W.Button(ctx.Window, CLOSE, function() clicks = clicks + 1 end)
		if b.label:GetText() ~= CLOSE or not (b._width and b._width >= 60) then
			fail(scenario, "the button does not carry its label in a font string of its own")
		end
		b:Click()
		b:Disable()
		b:Click()
		if clicks ~= 1 then fail(scenario, "the button ran " .. clicks .. " times for one enabled click") end
		local c = b.label._textColor or {}
		if not same(c[1], T.btnOffInk[1]) then fail(scenario, "a disabled button keeps its gold words") end
		local answered
		local m = W.Modal(ctx.Window, "Sure?", function() answered = "yes" end, function() answered = "no" end)
		if m.yes.label:GetText() ~= YES or m.no.label:GetText() ~= NO then fail(scenario, "the confirm is not YES and NO") end
		m:Hide()
		if answered ~= "no" or W.Asking() then fail(scenario, "shutting the confirm with the window was not a No") end
		local share = build(scenario, ns, ctx, "execute", "profiles.shareCopy")
		if share then
			ns.OptionsPage.shareOpen = false
			share:Refresh()
			local before = share.button.label:GetText()
			share.button:Click()
			if not ns.OptionsPage.shareOpen or share.button.label:GetText() == before then
				fail(scenario, "Show my settings as text did not turn into Hide the text")
			end
			share:Flash()
			local f = share.frame
			f.scripts.OnUpdate(f, 0.3)
			if not same(share.flash:GetAlpha(), 0.5) then fail(scenario, "the flash is not half gone at 0.3 s") end
			f.scripts.OnUpdate(f, 0.4)
			if share.flash:IsShown() or f.scripts.OnUpdate then fail(scenario, "the flash outlives 0.6 s") end
		end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ bytes
-- Trimming takes ASCII white space only. Lua's %s follows the C library's
-- locale, and under a Western one (this runner's, and perhaps the client's)
-- it takes 0xA0, the last byte of the Chinese "Reason text: top-up" (...加),
-- of the Korean (...신) and of "à": trimmed with it, a label held half a
-- character, and the renderer stopped at the first page that had one.
local ENDS_IN_A0 = {
	"\229\142\159\229\155\160\230\150\135\229\173\151\239\188\154\232\161\165\229\138\160", -- 原因文字：补加
	"\234\176\177\236\139\160", -- 갱신
	"voil\195\160",
}

-- Bytes past ASCII as \ddd, so a cut character can be named without breaking
-- the runner that prints it.
local function bytes(s)
	return (tostring(s):gsub("[\128-\255]", function(c) return "\\" .. c:byte() end))
end

run("widgets: a trim leaves the last byte of a character alone", function(scenario)
	local ns, ctx = session(scenario)
	if ns then
		local W, UI = ns.WindowWidgets, ns.WindowUI
		for _, s in ipairs(ENDS_IN_A0) do
			if W.Trim(s) ~= s or W.Trim("\n  " .. s .. " \n") ~= s then
				fail(scenario, ("W.Trim cut %s to %s"):format(bytes(s), bytes(W.Trim(s))))
			end
			if UI.Plain("|cffffffff" .. s .. "|r\n") ~= s then
				fail(scenario, ("UI.Plain cut %s to %s"):format(bytes(s), bytes(UI.Plain(s))))
			end
		end
		noErrors(scenario, ns)
	end
	-- And a real label, in the language that has one: Look's reason box.
	for _, locale in ipairs({ "zhCN", "koKR" }) do
		Mock.reset()
		Mock.locale = locale
		local zh = load(scenario)
		if zh then
			drive(scenario, zh)
			zh.Prompt:ExitTest()
			local item = zh.WindowBind.Item("advanced.reasonRefresh", {}, ctx)
			local row = item and zh.WindowWidgets.Build("input", ctx.Window, item)
			local want = zh.L["Reason text: top-up"]
			if not row then
				fail(scenario, "SKIPPED -- no reason box for a top-up")
			elseif row.label:GetText() ~= want then
				fail(scenario, ("%s's top-up label reads %s, not %s"):format(locale, bytes(row.label:GetText()), bytes(want)))
			end
			noErrors(scenario, zh)
		end
	end
end)

-- Every string the window wraps breaks inside a word too: Chinese has no
-- spaces, so without it the reset's confirm was cut short with an ellipsis.
run("widgets: the confirm, the strip and the fold caption wrap a line with no spaces", function(scenario)
	local ns, ctx = session(scenario)
	if ns then
		local m = ns.WindowWidgets.Modal(ctx.Window, "Sure?", function() end, function() end)
		if m.text._nonSpaceWrap ~= true then fail(scenario, "the confirm's words do not break inside a word") end
		m:Hide()
		ns.OpenOptions("appearance")
		local UI = ns.WindowUI
		for name, fs in pairs({ ["the strip's line 1"] = UI.strip.line1, ["the strip's line 2"] = UI.strip.line2,
			["the fold caption"] = UI.Model("appearance").caption.text }) do
			if fs._nonSpaceWrap ~= true or fs._wordWrap == false then fail(scenario, name .. " does not break inside a word") end
		end
		ns.Prompt:ExitTest()
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ box bar
-- A box of many lines whose text runs past it says so with a slim bar, which
-- follows the wheel and scrolls the box when dragged, and goes once the text
-- fits again. Without it the last line was cut in half and nothing said more
-- was below.
run("widgets: a box of many lines shows a bar while its text runs past it", function(scenario)
	local ns, ctx = session(scenario)
	if ns then
		local row = build(scenario, ns, ctx, "multiline", "click.phrases")
		if row then
			local lines = {}
			for i = 1, 60 do lines[i] = "Line " .. i .. ", thank you kindly" end
			Mock.type(row.box, table.concat(lines, "\n"))
			local range = row.scroll:GetVerticalScrollRange()
			if not (range > 0) then
				fail(scenario, "SKIPPED -- sixty lines do not run past the box")
			elseif not row.bar:IsShown() then
				fail(scenario, "sixty lines in a box of 26 show no bar")
			else
				row.scroll.scripts.OnMouseWheel(row.scroll, -1)
				local at = row.scroll:GetVerticalScroll()
				if not (at > 0) or row.bar:GetValue() ~= at then
					fail(scenario, ("the wheel took the box to %s and the bar to %s"):format(tostring(at), tostring(row.bar:GetValue())))
				end
				Mock.drag(row.bar, range)
				if row.scroll:GetVerticalScroll() ~= range then
					fail(scenario, "dragging the bar to its end left the box at " .. tostring(row.scroll:GetVerticalScroll()))
				end
				if #ctx.pages ~= 0 then fail(scenario, "the wheel went to the page while the box still moved") end
				row.scroll.scripts.OnMouseWheel(row.scroll, -1)
				if #ctx.pages ~= 1 or ctx.pages[1] ~= -1 then
					fail(scenario, "the wheel at the end of the box was not handed to the page")
				end
			end
			Mock.type(row.box, "One line")
			if row.bar:IsShown() then fail(scenario, "one line still shows the bar") end
			-- Nothing to scroll: the client would not pass the wheel up, so the box does.
			ctx.pages = {}
			row.scroll:SetVerticalScroll(0)
			row.scroll.scripts.OnMouseWheel(row.scroll, 1)
			row.bar.scripts.OnMouseWheel(row.bar, -1)
			if #ctx.pages ~= 2 or ctx.pages[1] ~= 1 or ctx.pages[2] ~= -1 then
				fail(scenario, "the wheel over a box with nothing to scroll was swallowed")
			end
		end
		noErrors(scenario, ns)
	end
end)

-- ------------------------------------------------------------------ recorded
-- On the recording frames tools/ draws from (tests/frametree.lua): every kind
-- builds and lays out there too, and what it made is in the tree.
dofile(dir .. "/tests/frametree.lua")
run("widgets: every kind builds on the recording frames", function(scenario)
	local FT = FrameTree
	FT.install()
	local ok, err = pcall(function()
		local ns, ctx = session(scenario)
		if not ns then return end
		local W = ns.WindowWidgets
		local made = #FT.all
		for _, k in ipairs({ { "toggle", "who.skipPvP" }, { "select", "appearance.style" },
			{ "range", "appearance.alpha" }, { "input", "advanced.format" }, { "multiline", "click.phrases" },
			{ "execute", "profiles.shareCopy" }, { "keybinding", "general.bindKey" },
			{ "color", "appearance.bgColor" }, { "multiselect", "who.skipRaidGroups" },
			{ "description", "general.howItWorks" }, { "header", "who.neverHeader" }, { "number", "advanced.x" } }) do
			build(scenario, ns, ctx, k[1], k[2])
		end
		W.Build("never", ctx.Window, { layout = { ids = NEVER }, ctx = ctx }):Layout(560)
		W.Modal(ctx.Window, "Sure?")
		local tree = FT.snapshot(ctx.Window)
		if #FT.all - made < 100 or #tree < 100 then
			fail(scenario, ("only %d regions were recorded for every kind"):format(#tree))
		end
		-- Every string says its font, as an object (`_fontObject`, which the
		-- renderer maps by its `_name`) or outright (`_font`).
		for i = made + 1, #FT.all do
			local r = FT.all[i]
			if r._kind == "FontString" and (r._text or "") ~= "" and not (r._font or r._fontObject) then
				fail(scenario, "a string has no font: " .. tostring(r._text))
				break
			end
		end
		noErrors(scenario, ns)
	end)
	FT.uninstall()
	if not ok then error(err, 0) end
end)
