-- Manners -- options: the page put together from its tabs, registered with
-- AceConfig and the game's Settings window, and opened and shut.

local ADDON, ns = ...
local Page = ns.OptionsPage

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Asked for optionally. It ships inside AceConfig-3.0 and will be there, but
-- the only thing that depends on it is the page repainting itself when a fight
-- ends -- and a missing library must not take the options screen with it.
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)

-- The page is a setup flow: Start here takes a new player from nothing to a
-- prompt on a key, and every other tab is for fine-tuning, in the order a
-- player thinks about it. Profiles is added last by SetupOptions.
local function BuildOptions()
	return {
		type = "group",
		name = "Manners",
		childGroups = "tab",
		args = {
			general = Page.BuildStartTab(),
			who = Page.BuildWhoTab(),
			when = Page.BuildWhenTab(),
			click = Page.BuildSpeechTab(),
			appearance = Page.BuildLookTab(),
			advanced = Page.BuildAdvancedTab(),
			diagnostics = Page.BuildDiagnosticsTab(),
		},
	}
end

-- Buttons and dropdowns sized to their words. AceConfigDialog gives a control
-- 170 pixels unless told otherwise. AceGUI keeps 15 of them clear either side
-- of a button's label, so "Put these back to default" was cut to "Put these
-- back to de..."; a dropdown's text gets 36 fewer than the control, so "Above
-- the action bars (default)" showed as "Above the action bars (d...". The
-- German for most of these runs a third longer. Every button and dropdown
-- without a width of its own is measured when the options are built and again
-- each time they are opened -- a button against the label it shows then, a
-- dropdown against the longest of its choices -- in the font each draws with,
-- and widened in quarter steps, never below the default, so short controls
-- keep the rows' rhythm.
--
-- The width is written as a plain number. AceConfigDialog would read a
-- function there, but AceConfigRegistry's validator, which runs the first
-- time the page opens, accepts only a string or a number: 1.1.2 to 1.4.0 put
-- a function in and the options would not open at all ("width: expected a
-- string or number"). tests/scenarios/aceconfig.lua now runs that validator.
--
-- Sliders and key bindings are measured too, against their label. It is one
-- line across the top of the control, cut with an ellipsis at its edge: "Top
-- up when less than this is left (minutes)" lost its unit, which was then only
-- in the tooltip. A slider's label draws in GameFontNormal, a key binding's in
-- GameFontHighlight.
local CONTROL_UNIT = 170
local BUTTON_PAD = 30 + 6
local SELECT_PAD = 36 + 6
local measureText

-- How wide `label` is in `font`, or nil when the client will not say.
local function LabelWidth(label, font)
	if type(label) ~= "string" or label == "" then return nil end
	if not measureText then
		measureText = UIParent:CreateFontString(nil, "ARTWORK")
		if not measureText then return nil end
		measureText:Hide()
	end
	if measureText.SetFontObject and _G[font] then measureText:SetFontObject(_G[font]) end
	measureText:SetText(label)
	local measure = measureText.GetUnboundedStringWidth or measureText.GetStringWidth
	local ok, w = pcall(measure, measureText)
	w = ok and ns.plain(w) or nil
	return type(w) == "number" and w or nil
end

local function ControlWidth(w, pad)
	if not w then return nil end
	local units = math.ceil((w + pad) / CONTROL_UNIT * 4) / 4
	if units <= 1 then return nil end
	-- Past three it would not sit beside anything anyway.
	if units > 3 then return "full" end
	return units
end

-- AceConfigDialog asks for a width with the option in info.option; a label or
-- a list of choices that is a function is asked the same way the page asks it.
local function Asked(value, info)
	if type(value) ~= "function" then return value end
	local ok, answer = pcall(value, info)
	return ok and answer or nil
end

local function FitButton(info)
	local option = type(info) == "table" and info.option
	return ControlWidth(LabelWidth(option and Asked(option.name, info), "GameFontNormal"), BUTTON_PAD)
end

-- A slider's or a key binding's width, from its label in `font`. The label
-- spans the whole control, with a few pixels to spare either side.
local function FitLabel(font)
	return function(info)
		local option = type(info) == "table" and info.option
		return ControlWidth(LabelWidth(option and Asked(option.name, info), font), 6)
	end
end

local function FitSelect(info)
	local option = type(info) == "table" and info.option
	local values = option and Asked(option.values, info)
	if type(values) ~= "table" then return nil end
	local widest
	for _, label in pairs(values) do
		local w = LabelWidth(label, "GameFontHighlightSmall")
		if w and (not widest or w > widest) then widest = w end
	end
	return ControlWidth(widest, SELECT_PAD)
end

-- How each kind of control is measured. Radio lists and the media pickers (a
-- dialogControl) lay out otherwise and are left alone.
local FITTERS = {
	button = FitButton,
	select = FitSelect,
	range = FitLabel("GameFontNormal"),
	keybinding = FitLabel("GameFontHighlight"),
}

-- Which controls this file sizes, and how (a key of FITTERS; false for
-- one that names its own width), so measuring again finds the same ones once
-- their width holds a number of ours.
local fitted = setmetatable({}, { __mode = "k" })

local function FitControls(node, key)
	if type(node) ~= "table" then return end
	local kind = fitted[node]
	if kind == nil then
		kind = false
		if node.width == nil then
			if node.type == "execute" then
				kind = "button"
			elseif node.type == "select" and node.style ~= "radio" and not node.dialogControl then
				kind = "select"
			elseif node.type == "range" then
				kind = "range"
			elseif node.type == "keybinding" then
				kind = "keybinding"
			end
		end
		fitted[node] = kind
	end
	if kind then
		-- Asked the way AceConfigDialog asks: the option, and its key last.
		local info = { key, option = node }
		node.width = FITTERS[kind](info)
	end
	if type(node.args) == "table" then
		for childKey, child in pairs(node.args) do FitControls(child, childKey) end
	end
end

---------------------------------------------------------------------------
-- registration
---------------------------------------------------------------------------

-- The canvas frame AddToBlizOptions made for the game's Settings window, and
-- the category ID it hands back beside it. Two values because they are two
-- things: the frame is what can be asked whether the page is on screen, and
-- only the ID is something Settings.OpenToCategory can find the page by.
local blizCategory, blizCategoryID

function ns.SetupOptions()
	local options = BuildOptions()
	options.args.profiles = Page.BuildProfilesTab()
	-- Last, so the profiles tab's controls are fitted too.
	FitControls(options)
	-- Kept so a control can be read back afterwards. A dropdown that lists the
	-- right entries under the wrong labels renders perfectly and is invisible
	-- to every other check we have.
	ns.optionsTable = options

	AceConfig:RegisterOptionsTable(ADDON, options)
	blizCategory, blizCategoryID = AceConfigDialog:AddToBlizOptions(ADDON, "Manners")
	-- The bug-report box shuts with the Settings page (OpenOptions shuts it
	-- for the standalone window). OnHide, because the box's own `hidden` is
	-- only asked while the page is being drawn.
	if blizCategory and blizCategory.HookScript then
		blizCategory:HookScript("OnHide", function() Page.reportOpen = false end)
		blizCategory:HookScript("OnHide", function() Page.shareOpen = false end)
	end

	Page.RegisterLauncher()
end

-- Repaint whatever is on screen from the values as they stand now: AceConfig
-- only asks a `hidden` or a `name` function while it is drawing, and some
-- answers (combat, errors, open boxes) change under it. Optional at both ends,
-- because failing to repaint must never take down the handler it is called from.
function ns.RefreshOptionsDisplay()
	if AceConfigRegistry and AceConfigRegistry.NotifyChange then
		AceConfigRegistry:NotifyChange(ADDON)
	end
end

-- Whether the window somebody would be styling the prompt from is on screen.
-- Asked rather than subscribed to, so a missed notification can never leave a
-- preview running; every answer defaults to "no", so the preview times out.
function ns.OptionsOpen()
	local frames = AceConfigDialog and AceConfigDialog.OpenFrames
	if type(frames) == "table" and frames[ADDON] ~= nil then return true end

	-- The other route in: the Settings window's canvas. IsVisible, not IsShown:
	-- shutting the Settings window hides the window, not the canvas, whose own
	-- shown flag stays set until another page takes its place. AceConfigDialog
	-- asks its own Settings pages the same way.
	if blizCategory then
		local ok, visible = pcall(function() return blizCategory:IsVisible() end)
		if ok and visible then return true end
	end
	return false
end

-- Shut the standalone options window, if it is up. Only that one: the game's
-- Settings window is Blizzard's to open and shut, and some of it is protected
-- in a fight. Guarded, since a library without Close just leaves it open.
function ns.CloseOptions()
	if AceConfigDialog and AceConfigDialog.Close then
		pcall(AceConfigDialog.Close, AceConfigDialog, ADDON)
	end
end

-- The key of the tab the options window has open -- "general", "prompt" -- or
-- nil where the library will not say. The library keeps the choice in its
-- status table for the page, which both the standalone window and the Settings
-- page read, so one answer covers both.
function ns.OptionsTab()
	if not (AceConfigDialog and AceConfigDialog.GetStatusTable) then return nil end
	local ok, status = pcall(AceConfigDialog.GetStatusTable, AceConfigDialog, ADDON)
	local groups = ok and type(status) == "table" and status.groups
	local selected = type(groups) == "table" and groups.selected
	return type(selected) == "string" and selected or nil
end

function ns.OpenOptions()
	-- The boxes start shut when the window opens, but are left alone when it
	-- is already up, where somebody may be copying out of one.
	if not ns.OptionsOpen() then Page.reportOpen = false end
	if not ns.OptionsOpen() then Page.shareOpen = false end
	-- Measured again with today's labels: a snooze button's, a list of buffs
	-- learned since login.
	if ns.optionsTable then ns.Guard("fit controls", FitControls, ns.optionsTable) end

	-- The standalone dialog, first and by default. Settings.OpenToCategory
	-- does not raise when it fails to find the category: on this client it
	-- opens the Settings window at whatever page it was last on and returns
	-- cleanly, so only the route that either works or errors can go first.
	local ok = pcall(AceConfigDialog.Open, AceConfigDialog, ADDON)
	if ok then return end

	-- A last resort, by the ID AddToBlizOptions returned: the canvas frame's
	-- own GetID answers 0, which is no category at all.
	if Settings and Settings.OpenToCategory and blizCategoryID ~= nil then
		pcall(Settings.OpenToCategory, blizCategoryID)
	end
end

-- Open the options on the Profiles tab, where the share boxes are, with the
-- box of this profile's settings showing when that is what was asked for.
-- For /manners export and a bare /manners import. Answers whether there is a
-- page to send them to at all; SelectGroup is asked for because a library
-- without it still opens the window, just not on this tab.
function ns.ShowShareBox(which)
	ns.OpenOptions()
	if which == "export" then Page.shareOpen = true end
	if AceConfigDialog.SelectGroup then
		pcall(AceConfigDialog.SelectGroup, AceConfigDialog, ADDON, "profiles")
	end
	ns.RefreshOptionsDisplay()
	return true
end
