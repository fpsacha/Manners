-- The Look tab (Options/Look.lua, BuildLookTab): the prompt's position, size,
-- style, the ways it gets your attention, its text and its icon. The preview is
-- the options window's header button now, and the exact position and wording
-- are folds on the same page, so nothing here points elsewhere.
--
-- The tab reads top to bottom in the order a player sets a prompt up: put it
-- somewhere, size it, style it, decide how loud it is, then the text and the
-- icon. Most of what can go wrong here draws perfectly and reads as nothing --
-- a dropdown sorted alphabetically, a choice that can be picked but does
-- nothing, a colour picker left on screen that has no say -- so these read the
-- controls the way AceConfig will.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function text(v)
	if type(v) == "function" then v = v({}) end
	return type(v) == "string" and v or ""
end

-- A driven session and the Look tab's controls, or nil.
local function session(scenario)
	Mock.reset()
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local tab = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.appearance
	if not (tab and tab.args) then
		fail(scenario, "SKIPPED -- there is no Look tab")
		return nil
	end
	return ns, tab, tab.args
end

local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
	for i = 1, #a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

local function list(t)
	local out = {}
	for i, v in ipairs(t or {}) do out[i] = tostring(v) end
	return "{ " .. table.concat(out, ", ") .. " }"
end

-- ------------------------------------------------------------------ order
-- The tab in the order the spec gives it, so the page reads as a setup rather
-- than as the history of which setting arrived when.
local ORDER = {
	"combatNotice", "locked", "posPreset",
	"posHeader", "scale", "alpha", "width", "height",
	"styleHeader", "style", "bgColor", "accentByReason", "reasonPalette", "accentColor",
	"accentMode", "accentDead",
	"attentionHeader", "flashStyle", "effects", "hideInCombat", "soundEnabled", "soundFile",
	"soundOwedOnly", "noSound",
	"textHeader", "font", "fontSize", "fontColor", "classColor", "showSub",
	"iconHeader", "showIcon", "iconSize", "iconSizeCapped", "roundIcon", "showCooldown",
	"showCount", "showQueue", "queueRows",
}

do
	local scenario = "the Look tab reads in setup order"
	local ns, tab, args = session(scenario)
	if ns then
		if tab.name ~= "Look" or tab.order ~= 5 then
			fail(scenario, ("the tab is %s at order %s, not Look at 5"):format(
				tostring(tab.name), tostring(tab.order)))
		end
		for i, key in ipairs(ORDER) do
			local option = args[key]
			if not option then
				fail(scenario, "the tab has no " .. key)
			elseif i > 1 and args[ORDER[i - 1]] and not (args[ORDER[i - 1]].order < option.order) then
				fail(scenario, ("%s is out of order: it comes before %s"):format(key, ORDER[i - 1]))
			end
		end
		local known = {}
		for _, key in ipairs(ORDER) do known[key] = true end
		for key in pairs(args) do
			if not known[key] then
				fail(scenario, "the tab has a control the spec does not: " .. key)
			end
		end
		if args.posPreset and args.posPreset.order >= args.posHeader.order then
			fail(scenario, "Where it sits is not at the top of the tab")
		end
		-- Moved to other tabs, not deleted from the page. The preview is the
		-- window's header button (general.previewStart); the wording is a fold
		-- on this page, so nothing points at it.
		for _, key in ipairs({ "x", "y", "thankEmote", "format", "reset", "test", "wordingNote" }) do
			if args[key] then fail(scenario, key .. " is still on the Look tab") end
		end

		local headers = {
			posHeader = "Size", styleHeader = "Style", attentionHeader = "Getting my attention",
			textHeader = "Text", iconHeader = "Icon and waiting list",
		}
		for key, name in pairs(headers) do
			if args[key] and args[key].name ~= name then
				fail(scenario, ("the %s header reads %q, not %q"):format(key, tostring(args[key].name), name))
			end
		end
		local names = {
			locked = "Lock position", posPreset = "Where it sits", alpha = "Opacity",
			style = "Panel style", bgColor = "Panel colour", accentByReason = "Colour marker by reason",
			reasonPalette = "Reason colours", accentColor = "Marker colour", accentMode = "Colour marker",
			flashStyle = "Flash when someone buffs me", effects = "Animations",
			hideInCombat = "Keep the prompt dim and still in combat",
			soundEnabled = "Play a sound", soundFile = "Sound", soundOwedOnly = "Only for people who buff me",
			fontColor = "Text colour", classColor = "Colour names by class", showSub = "Show a second line",
			showCount = "Show how many are waiting", showQueue = "List the next few below",
			queueRows = "How many to list",
		}
		for key, name in pairs(names) do
			if args[key] and text(args[key].name) ~= name then
				fail(scenario, ("%s is labelled %q, not %q"):format(key, text(args[key].name), name))
			end
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ the top
do
	local scenario = "the top of the Look tab says what each button does"
	local ns, _, args = session(scenario)
	if ns then
		if text(args.locked.desc) ~= "Unlock to drag the prompt; it will not cast until you lock it again." then
			fail(scenario, "Lock position says: " .. text(args.locked.desc))
		end
		Mock.inCombat = true
		local notice = text(args.combatNotice.name)
		if args.combatNotice.hidden() or not notice:find("In combat: changes here show once the fight ends.", 1, true) then
			fail(scenario, "in combat the notice reads: " .. notice)
		end
		Mock.inCombat = false
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ Quick position
-- The default place is on the list, so it is also the way back; "Where I
-- dragged it" shows where a drag left the prompt, and is never a choice.
do
	local scenario = "Quick position names the default and where I dragged it"
	local ns, _, args = session(scenario)
	if ns then
		local option = args.posPreset
		local p = ns.db.profile.prompt
		local values = option.values()
		if values.bars ~= "Above the action bars (default)" then
			fail(scenario, "the default place is not marked: " .. tostring(values.bars))
		end
		if option.get() ~= "bars" then
			fail(scenario, "a new profile reads as " .. tostring(option.get()) .. ", not the default place")
		end
		if values.custom then
			fail(scenario, "Where I dragged it is offered while the prompt sits on a preset")
		end
		if not same(option.sorting(), { "bars", "minimap", "centre" }) then
			fail(scenario, "the places are listed " .. list(option.sorting()))
		end

		-- A drag.
		p.x = p.x + 13
		values = option.values()
		if values.custom ~= "Where I dragged it" then
			fail(scenario, "a dragged prompt has no Where I dragged it: " .. tostring(values.custom))
		end
		if option.get() ~= "custom" then
			fail(scenario, "a dragged prompt reads as " .. tostring(option.get()) .. ", a blank box")
		end
		local order = option.sorting()
		if order[#order] ~= "custom" then
			fail(scenario, "Where I dragged it is not last: " .. list(order))
		end

		-- Picking it does nothing: the prompt stays where it was dragged.
		local x, y = p.x, p.y
		option.set({ "posPreset" }, "custom")
		if p.x ~= x or p.y ~= y then
			fail(scenario, "picking Where I dragged it moved the prompt")
		end

		-- And the default place is the way back.
		option.set({ "posPreset" }, "bars")
		if option.get() ~= "bars" or option.values().custom then
			fail(scenario, "picking the default place did not put the prompt back")
		end
		noErrors(scenario, ns)
	end
end

-- What Reset position did, now done by the default Quick position: the prompt
-- back where a new profile has it, at any scale.
do
	local scenario = "the default Quick position puts the prompt back at any scale"
	local ns, _, args = session(scenario)
	if ns then
		Mock.geometry = { width = 1366, height = 768 }
		local button = ns.Prompt:GetButton()
		local p = ns.db.profile.prompt
		local d = ns.defaults.profile.prompt
		p.scale = 2
		args.posPreset.set({ "posPreset" }, "centre")
		args.posPreset.set({ "posPreset" }, "bars")
		if p.point ~= d.point or p.relPoint ~= d.relPoint or p.x ~= d.x or p.y ~= d.y then
			fail(scenario, ("the default Quick position is %s %s %s,%s; a new profile has %s %s %s,%s")
				:format(tostring(p.point), tostring(p.relPoint), tostring(p.x), tostring(p.y),
					tostring(d.point), tostring(d.relPoint), tostring(d.x), tostring(d.y)))
		end
		local _, bottom = Mock.rectUI(button)
		if math.floor(bottom + 0.5) ~= 300 then
			fail(scenario, ("at Scale 2 the default Quick position put the bottom edge at %d, not 300")
				:format(math.floor(bottom + 0.5)))
		end
		Mock.geometry = nil
		noErrors(scenario, ns)
	end
end

-- Picked in a fight, the place is saved and the secure button left alone
-- until the fight ends.
do
	local scenario = "Quick position waits for the fight to end"
	local ns, _, args = session(scenario)
	if ns then
		local button = ns.Prompt:GetButton()
		local function where()
			local pt = button.points and button.points[1]
			return pt and (tostring(pt[1]) .. " " .. tostring(pt[4]) .. "," .. tostring(pt[5])) or "nowhere"
		end
		local before = where()
		Mock.inCombat = true
		args.posPreset.set({ "posPreset" }, "minimap")
		if where() ~= before then
			fail(scenario, "a place picked in a fight moved the secure button: " .. before .. " -> " .. where())
		end
		if ns.db.profile.prompt.point ~= "TOPRIGHT" then
			fail(scenario, "a place picked in a fight was not saved")
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		if where() == before then
			fail(scenario, "the place picked in a fight never reached the prompt after it")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ Style
do
	local scenario = "Marker colour shows only when it is used"
	local ns, _, args = session(scenario)
	if ns then
		local p = ns.db.profile.prompt
		local picker = args.accentColor
		if picker.disabled then
			fail(scenario, "Marker colour is greyed out rather than hidden")
		end
		p.accentByReason = true
		if not (picker.hidden and picker.hidden()) then
			fail(scenario, "Marker colour still shows while Colour marker by reason is on")
		end
		p.accentByReason = false
		if picker.hidden and picker.hidden() then
			fail(scenario, "Marker colour is hidden while it is the colour in use")
		end
		if text(picker.desc) ~= "Used when Colour marker by reason is off." then
			fail(scenario, "Marker colour says: " .. text(picker.desc))
		end
		local desc = text(args.accentByReason.desc)
		if desc:sub(1, #"A colour that shows why this person is on the prompt.")
			~= "A colour that shows why this person is on the prompt." then
			fail(scenario, "Colour marker by reason opens with: " .. desc)
		end
		if desc:find("targeted comes first", 1, true) then
			fail(scenario, "Colour marker by reason still carries the grey target sentence")
		end
		noErrors(scenario, ns)
	end
end

do
	local scenario = "the dropdowns list their choices in meaning order"
	local ns, _, args = session(scenario)
	if ns then
		local cases = {
			{ "accentMode", "Colour marker", { "icon", "stripe", "both", "off" },
				{ icon = "Ring around the icon", stripe = "Stripe on the left edge", both = "Both", off = "None" } },
			{ "flashStyle", "Flash when someone buffs me", { "pulse", "once", "off" },
				{ pulse = "Pulse until I buff them back", once = "Flash once", off = "None" } },
			{ "effects", "Animations", { "full", "calm" },
				{ full = "Full", calm = "Calm (less movement)" } },
		}
		for _, case in ipairs(cases) do
			local option = args[case[1]]
			local sorting = type(option.sorting) == "function" and option.sorting() or option.sorting
			if not same(sorting, case[3]) then
				fail(scenario, ("%s lists %s, not %s"):format(case[2], list(sorting), list(case[3])))
			end
			local values = type(option.values) == "function" and option.values() or option.values
			for key, label in pairs(case[4]) do
				if values[key] ~= label then
					fail(scenario, ("%s labels %s %q, not %q"):format(case[2], key, tostring(values[key]), label))
				end
			end
		end
		local descs = {
			accentMode = "Framed panels have no stripe.",
			flashStyle = "Needs the icon, the stripe or Full animations.",
			effects = "Calm drops the light sweep, the shake and the fade-out.",
			soundEnabled = "When a new person appears on the prompt.",
			soundOwedOnly = "Off, every new person makes a sound, passers-by included.",
			-- The exact numbers are a fold on this page: no pointer.
			posPreset = "Pick Above the action bars to put it back where it started."
				.. " Dragging the prompt afterwards sets this to Where I dragged it.",
		}
		for key, want in pairs(descs) do
			if text(args[key].desc) ~= want then
				fail(scenario, ("%s says %q, not %q"):format(key, text(args[key].desc), want))
			end
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ Sound
-- Play a sound is the off switch, so None is not a sound to pick. A profile
-- that already holds it still shows it, rather than a blank box.
do
	local scenario = "the sound list leaves None out unless it is chosen"
	local ns, _, args = session(scenario)
	if ns then
		local option = args.soundFile
		local snd = ns.db.profile.sound
		snd.enabled = true
		snd.file = ns.SOUND_KEY
		local values = option.values()
		if values["None"] then
			fail(scenario, "None is offered as a sound beside Play a sound")
		end
		if values[ns.SOUND_KEY] ~= ns.SOUND_KEY then
			fail(scenario, "our own sound is missing from the list: " .. tostring(values[ns.SOUND_KEY]))
		end
		snd.file = "None"
		values = option.values()
		if values["None"] ~= "None" then
			fail(scenario, "a stored None leaves the sound box reading " .. tostring(values["None"]))
		end
		if option.get() ~= "None" then
			fail(scenario, "a stored None reads back as " .. tostring(option.get()))
		end
		if args.noSound.hidden() then
			fail(scenario, "a stored None says nothing about being silent")
		end
		snd.file = ns.SOUND_KEY
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ pointers
do
	local scenario = "Look points at the settings its controls depend on"
	local ns, _, args = session(scenario)
	if ns then
		local desc = text(args.fontColor.desc)
		-- On this page, so named without a page.
		local ref = " |cffffd100Colour names by class|r"
		if desc:sub(-#ref) ~= ref then
			fail(scenario, "Text colour does not end by pointing at Colour names by class: " .. desc)
		end
		desc = text(args.showCooldown.desc)
		-- On this tab now, so named without a tab.
		if not desc:find("|cffffd100Keep the prompt dim and still in combat|r", 1, true)
			or desc:find("(When to offer)", 1, true) then
			fail(scenario, "Show the global cooldown does not point at Keep the prompt dim: " .. desc)
		end
		desc = text(args.roundIcon.desc)
		if desc:find("|cff888888", 1, true) then
			fail(scenario, "Round the icon off still has its grey note: " .. desc)
		end
		local p = ns.db.profile.prompt
		desc = text(args.showSub.desc)
		if p.fontSize == 13 and desc ~= "Needs a prompt at least 39 pixels tall." then
			fail(scenario, "Show a second line says: " .. desc)
		end
		local size = p.fontSize
		p.fontSize = 24
		local want = ("Needs a prompt at least %d pixels tall."):format(ns.TwoLineHeight(24))
		if text(args.showSub.desc) ~= want then
			fail(scenario, "the second line's height does not follow the font: " .. text(args.showSub.desc))
		end
		p.fontSize = size
		noErrors(scenario, ns)
	end
end
