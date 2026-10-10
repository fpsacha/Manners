-- The UI hunt's fixes, each held here by what the player would see.
--
--   * The colour picker on the Classic clients. Classic Era, TBC Anniversary
--     and Mists have ColorPickerFrameMixin:SetupColorPickerAndShow and
--     :GetColorAlpha, but behind them is the old picker (Gethe/wow-ui-source,
--     branches classic_era, classic_anniversary and classic, Interface/AddOns/
--     Blizzard_FrameXML/Classic/ColorPickerFrame.lua and .xml):
--
--       SetupColorPickerAndShow(info)   self.opacity = info.opacity, then
--                                       SetColorRGB, which fires swatchFunc
--                                       with the frame still hidden
--       OnShow                          OpacitySliderFrame:SetValue(self.opacity)
--       GetColorAlpha()                 return OpacitySliderFrame:GetValue()
--
--     and that slider is the old one: vertical, minValue 0 at the top beside a
--     "+" and maxValue 1 at the bottom beside a "-", so its value is
--     TRANSPARENCY (0 is opaque), where on Forever and retail GetColorAlpha()
--     is the alpha itself. AceGUI-3.0's ColorPicker sets INVERTED_ALPHA for
--     every client but those two. The options window passed the alpha in and
--     took the slider's value as the alpha, so on the Classic clients the Panel
--     colour, Marker colour and Text colour swatches opened with the slider at
--     the wrong end and moving it to "+", the opaque end, wrote alpha 0: an
--     invisible panel or text. The mock's own picker answers the alpha
--     directly, which is why nothing else saw it.
--
--     A swatch clicked while the picker is still up for another is not shown
--     again (Show on a shown frame does nothing), so OnShow never ran and the
--     slider kept the first swatch's value, which swatchFunc then wrote as the
--     second swatch's alpha. Closed first now, as AceGUI's swatch does.
--
--   * The prompt's sound. "Only for people who buff me" is on out of the box,
--     so a passer-by on the prompt makes no sound; core's note on the default
--     says the sound is held to the flash's filter. The flash fires the moment
--     somebody BECOMES owed, a passer-by already on the panel who then buffs
--     you included (Refresh.lua, becameOwed), but the sound was tied to the
--     name changing, so that same moment was silent.
--
-- Every scenario name starts with "hunt-ui-fix:" so the mutations in
-- tests/mutations/hunt-ui-fixes.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local function press(button)
	local onClick = button and button:GetScript("OnClick")
	if onClick then onClick(button, "LeftButton", false) end
end

local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

-- The picker the current client has, step by step as its XML runs. On the
-- classic family that is the old one described above; elsewhere the mock's
-- own, which answers the alpha itself. Returns what the player does with the
-- slider and what it reads, in the picker's own terms.
local function pickerOf(ns)
	local picker = ColorPickerFrame
	if ns.Flavour.family ~= "classic" then
		return false,
			function(v)
				picker._a = v
				if picker._info and picker._info.opacityFunc then picker._info.opacityFunc() end
			end,
			function() return picker._a end
	end
	local sliderValue = 1 -- OpacitySliderFrame's defaultValue, before anyone has used it
	local function setSlider(v)
		if v == sliderValue then return end
		sliderValue = v
		-- <OnValueChanged>: ColorPickerFrame.opacityFunc()
		if picker._info and picker._info.opacityFunc then picker._info.opacityFunc() end
	end
	picker.SetupColorPickerAndShow = function(self, info)
		self._info = info
		self._previous = { r = info.r, g = info.g, b = info.b, a = info.opacity }
		self._r, self._g, self._b = info.r, info.g, info.b
		-- SetColorRGB comes last, and fires OnColorSelect -> swatchFunc, with the
		-- frame still hidden and the slider still holding the last value it had.
		if info.swatchFunc then info.swatchFunc() end
		-- <OnShow> runs when the frame goes from hidden to shown; Show on a
		-- shown frame does nothing.
		local wasShown = self:IsShown()
		self:Show()
		if not wasShown and info.hasOpacity then setSlider(info.opacity) end
	end
	picker.GetColorAlpha = function() return sliderValue end
	return true, setSlider, function() return sliderValue end
end

-- Every client: the first three have the old picker, the last two a picker
-- that answers the alpha itself.
local ALL = { "vanilla", "tbc", "mists", "camelot", "mainline" }

-- One driven session on the appearance page as `flavour` with body(ns, UI)
-- run, the mock reset after it whatever happens.
local function appearance(scenario, flavour, body)
	Mock.reset()
	Mock.setFlavour(flavour)
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			drive(scenario, ns)
			ns.Prompt:ExitTest()
			ns.OpenOptions("appearance", true)
			body(ns, ns.WindowUI)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ the opacity slider

for _, flavour in ipairs(ALL) do
for _, control in ipairs({
	{ key = "bgColor", name = "Panel colour", start = { 0.04, 0.04, 0.06, 0.88 } },
	{ key = "accentColor", name = "Marker colour", start = { 0.45, 0.4, 0.9, 0.7 } },
	{ key = "fontColor", name = "Text colour", start = { 1, 1, 1, 0.9 } },
}) do
	local scenario = "hunt-ui-fix: colour picker: the opacity slider of the " .. control.name
		.. " swatch means what the client's picker means by it (" .. flavour .. ")"
	appearance(scenario, flavour, function(ns, UI)
		local classic, move, value = pickerOf(ns)
		local P = ns.db.profile.prompt
		P.accentByReason = false
		P[control.key] = { control.start[1], control.start[2], control.start[3], control.start[4] }
		local alpha = control.start[4]
		ns.Prompt:ApplyStyle()
		UI.Refresh()
		local row = UI.RowFor("appearance." .. control.key)
		if not (row and row.hit) then
			fail(scenario, "SKIPPED -- Look shows no " .. control.name)
			return
		end
		press(row.hit)
		if not ColorPickerFrame:IsShown() then
			fail(scenario, "SKIPPED -- the picker did not open")
			return
		end
		-- 1. What the slider is set to: the swatch's opacity, in the picker's terms.
		local expect = classic and (1 - alpha) or alpha
		if not near(value(), expect) then
			fail(scenario, ("the swatch is %d%% opaque and the picker's opacity slider was set to %s, not %s"):format(
				alpha * 100 + 0.5, tostring(value()), tostring(expect)))
		end
		-- 2. Opening it changed nothing.
		if not near(P[control.key][4], alpha) then
			fail(scenario, "merely opening the picker moved the opacity to " .. tostring(P[control.key][4]))
		end
		-- 3. The player drags the slider to the fully opaque end ("+" on the
		-- classic one: value 0; the top of the alpha scale elsewhere: value 1).
		move(classic and 0 or 1)
		if not near(P[control.key][4], 1) then
			fail(scenario, ("the slider was dragged to fully opaque and the alpha is %s"):format(tostring(P[control.key][4])))
		end
		-- 4. And to the clear end.
		move(classic and 1 or 0)
		if not near(P[control.key][4], 0) then
			fail(scenario, ("the slider was dragged to fully clear and the alpha is %s"):format(tostring(P[control.key][4])))
		end
		-- 5. Somewhere between, and Cancel puts the opening opacity back.
		move(classic and 0.25 or 0.75)
		if not near(P[control.key][4], 0.75) then
			fail(scenario, ("the slider was dragged to three quarters opaque and the alpha is %s"):format(tostring(P[control.key][4])))
		end
		Mock.closeColour(false)
		if not near(P[control.key][4], alpha) then
			fail(scenario, "Cancel did not put the opacity back: " .. tostring(P[control.key][4]))
		end
	end)
end
end

-- Opened and left alone, the stored alpha is exactly what it was: the flip
-- there and back must not move a float's last digit.
for _, flavour in ipairs(ALL) do
	local scenario = "hunt-ui-fix: colour picker: opening and accepting a swatch leaves its opacity as it was ("
		.. flavour .. ")"
	appearance(scenario, flavour, function(ns, UI)
		pickerOf(ns)
		local P = ns.db.profile.prompt
		local alpha = 0.3
		P.bgColor = { 0.04, 0.04, 0.06, alpha }
		ns.Prompt:ApplyStyle()
		UI.Refresh()
		local row = UI.RowFor("appearance.bgColor")
		if not (row and row.hit) then
			fail(scenario, "SKIPPED -- Look shows no Panel colour")
			return
		end
		press(row.hit)
		if not ColorPickerFrame:IsShown() then
			fail(scenario, "SKIPPED -- the picker did not open")
			return
		end
		Mock.closeColour(true)
		if P.bgColor[4] ~= alpha then
			fail(scenario, ("opening the picker and pressing Okay left the opacity at %.17g, not %.17g"):format(
				P.bgColor[4], alpha))
		end
	end)
end

-- ------------------------------------------------------------------ a second swatch

for _, flavour in ipairs(ALL) do
	local scenario = "hunt-ui-fix: colour picker: a swatch clicked while another's picker is up gets its own opacity ("
		.. flavour .. ")"
	appearance(scenario, flavour, function(ns, UI)
		local classic, move, value = pickerOf(ns)
		local P = ns.db.profile.prompt
		P.bgColor = { 0.04, 0.04, 0.06, 0.88 }
		P.fontColor = { 1, 1, 1, 0.7 }
		ns.Prompt:ApplyStyle()
		UI.Refresh()
		local panel, text = UI.RowFor("appearance.bgColor"), UI.RowFor("appearance.fontColor")
		if not (panel and panel.hit and text and text.hit) then
			fail(scenario, "SKIPPED -- Look shows no Panel colour or no Text colour")
			return
		end
		press(panel.hit)
		if not ColorPickerFrame:IsShown() then
			fail(scenario, "SKIPPED -- the picker did not open")
			return
		end
		-- The picker is left up, and the other swatch is clicked.
		press(text.hit)
		if not near(P.fontColor[4], 0.7) then
			fail(scenario, "clicking the Text colour swatch moved its opacity from 70% to "
				.. tostring(P.fontColor[4]))
		end
		if not near(P.bgColor[4], 0.88) then
			fail(scenario, "clicking the Text colour swatch moved the Panel colour's opacity to "
				.. tostring(P.bgColor[4]))
		end
		local expect = classic and 0.3 or 0.7
		if not near(value(), expect) then
			fail(scenario, ("the picker is for the Text colour (70%% opaque) and its opacity slider reads %s, not %s"):format(
				tostring(value()), tostring(expect)))
		end
		-- It moves the text and only the text.
		move(0.5)
		if not near(P.fontColor[4], 0.5) then
			fail(scenario, "the slider was moved to half and the Text colour's opacity is " .. tostring(P.fontColor[4]))
		end
		if not near(P.bgColor[4], 0.88) then
			fail(scenario, "the slider for the Text colour moved the Panel colour's opacity to " .. tostring(P.bgColor[4]))
		end
	end)
end

-- ------------------------------------------------------------------ the sound

local function sounds() return #(Mock.sounds or {}) end

for _, case in ipairs({
	{ label = "a passer-by on the prompt who then buffs you sounds once", owedFirst = false, owedOnly = true },
	{ label = "a favour owed to a newcomer sounds once (control)", owedFirst = true, owedOnly = true },
	{ label = "with Only for people who buff me off, the passer-by turning owed is not a second new person", owedFirst = false, owedOnly = false },
}) do
	Mock.reset()
	local restore = strangers({ nameplate1 = { "Anna" } })
	local scenario = "hunt-ui-fix: sound: " .. case.label
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			freshPrompt(ns, scenario)
			ns.nameplateUnits.nameplate1 = true
			ns.db.profile.filters.proximity = "cast"
			ns.db.profile.sound.enabled = true
			if ns.db.profile.sound.owedOnly ~= true then
				fail(scenario, "SKIPPED -- Only for people who buff me is not on out of the box")
				return
			end
			ns.db.profile.sound.owedOnly = case.owedOnly
			Mock.sounds = {}
			if case.owedFirst then owe(ns, "Anna") end
			ns.addon:Tick()
			local shown = ns.Prompt:Showing()
			if not (shown and shown.name == "Anna") then
				fail(scenario, "SKIPPED -- Anna was not on the prompt: " .. tostring(shown and shown.name))
				return
			end
			if case.owedFirst then
				if sounds() ~= 1 then
					fail(scenario, "a favour owed to a newcomer made " .. sounds() .. " sounds")
				end
				return
			end
			-- Only for people who buff me on: a passer-by is silent. Off: a new
			-- person sounds.
			local expectFirst = case.owedOnly and 0 or 1
			if shown.reason == "owed" or sounds() ~= expectFirst then
				fail(scenario, "SKIPPED -- the passer-by was already owed, or made " .. sounds() .. " sounds on arriving")
				return
			end
			-- Out of the three seconds' floor, then she buffs you.
			Mock.advance(5)
			owe(ns, "Anna")
			ns.addon:Tick()
			shown = ns.Prompt:Showing()
			if not (shown and shown.name == "Anna" and shown.reason == "owed") then
				fail(scenario, "SKIPPED -- Anna did not turn owed on the prompt: " .. tostring(shown and shown.reason))
				return
			end
			if case.owedOnly then
				if sounds() ~= 1 then
					fail(scenario, "the passer-by on the prompt buffed you, the panel flashed for the favour, and the sound played "
						.. sounds() .. " times")
				end
			elseif sounds() ~= expectFirst then
				fail(scenario, "the passer-by was announced already and turning owed made the sound play again: "
					.. sounds() .. " times")
			end
			-- And it is once: another look at the same panel is quiet.
			Mock.advance(5)
			ns.addon:Tick()
			if sounds() ~= 1 then
				fail(scenario, "a later look at the same panel made the sound play again: " .. sounds() .. " times")
			end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	restore()
	Mock.reset()
end
