-- Readability of the prompt: text on any panel colour, the Minimal look over
-- the world, the colour-blind reason colours, and lines in the longer
-- languages.
--
-- None of it throws when it is wrong. White text on a cream panel, a palette
-- that two reasons share, a German line cut off before the words that say why
-- -- each draws perfectly and reads as nothing. So these measure what the
-- frames were told: the colours against the panel they sit on, worked out here
-- independently of Prompt/Text.lua, and the widths of the lines against their room.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe
local findOption = H.findOption

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

-- Loaded on the recording CreateFrame, as a client in `locale`, and put back
-- afterwards whatever happens.
local function withTree(scenario, names, locale, body)
	Mock.reset()
	Mock.locale = locale
	FT.install()
	FT.measure = nil
	local restore = strangers(names or {})
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then
		ok, err = pcall(body, ns)
	end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ contrast
-- The web's contrast rules, written out again here rather than borrowed from
-- the addon, so a mistake in its arithmetic cannot mark its own homework.
local function lin(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end
local function lum(r, g, b) return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b) end
local function ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- An opaque panel's two ends: the gradient runs from 0.62 of the colour (0.72
-- in blue) at the bottom to the colour itself at the top.
local function ends(c)
	return lum(c[1] * 0.62, c[2] * 0.62, c[3] * 0.72), lum(c[1], c[2], c[3])
end
local function worst(c, lo, hi)
	local l = lum(c[1], c[2], c[3])
	return math.min(ratio(l, lo), ratio(l, hi))
end

local function hexColour(text)
	local r, g, b = tostring(text or ""):match("|c%x%x(%x%x)(%x%x)(%x%x)")
	if not r then return nil end
	return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 }
end

-- ------------------------------------------------------------------ look2 1
-- The text reads on whatever panel colour the player picks.
--
-- It was white on every panel. The page offers a colour picker for the panel,
-- and cream, pale grey or yellow gave white words on a white-ish ground --
-- with a priest's name, white by class, on top of that. Each panel here is
-- opaque, and for each the name, the reason line and the class colour in the
-- name are held to the contrast the prompt promises: 4.5:1 for the plain
-- lines and 3:1 for coloured text, against the worse of the panel's two ends.
-- Where no colour at all reaches that -- a mid grey spanning its gradient --
-- the text has to be the best there is, white or black.
local PANELS = {
	{ "the default dark panel", { 0.04, 0.04, 0.06 } },
	{ "cream", { 0.86, 0.84, 0.78 } },
	{ "white", { 1, 1, 1 } },
	{ "yellow", { 0.95, 0.85, 0.20 } },
	{ "pale pink", { 1, 0.80, 0.85 } },
	{ "dark red", { 0.40, 0.05, 0.05 } },
	{ "mid-blue", { 0.30, 0.45, 0.80 } },
	{ "mid grey", { 0.50, 0.50, 0.50 } },
}
for _, case in ipairs(PANELS) do
	local label, colour = case[1], case[2]
	local scenario = "the prompt's text reads on a " .. label .. " panel"
	withTree(scenario, { nameplate1 = { "Anna", "Aim" } }, nil, function(ns)
		freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		p.bgColor = { colour[1], colour[2], colour[3], 1 }
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local r = ns.Prompt:Regions()
		local lo, hi = ends(colour)
		local best = math.max(worst({ 1, 1, 1 }, lo, hi), worst({ 0, 0, 0 }, lo, hi))
		local want = math.min(4.5, best) - 0.01
		local name, sub = r.name._textColor, r.sub._textColor
		if not (name and sub) then
			fail(scenario, "SKIPPED -- no text colour recorded on the name or the reason line")
			return
		end
		if worst(name, lo, hi) < want then
			fail(scenario, ("the name is drawn in %.2f %.2f %.2f, %.2f:1 against the panel"
				.. " where %.2f:1 was there to be had"):format(name[1], name[2], name[3],
				worst(name, lo, hi), want + 0.01))
		end
		if worst(sub, lo, hi) < want then
			fail(scenario, ("the reason line is drawn in %.2f %.2f %.2f, %.2f:1 against the"
				.. " panel where %.2f:1 was there to be had"):format(sub[1], sub[2], sub[3],
				worst(sub, lo, hi), want + 0.01))
		end
		-- The class colour inside the name: a priest is white by class, which
		-- is the colour a light panel cannot carry.
		local code = hexColour(r.name._text)
		if not code then
			fail(scenario, "SKIPPED -- the name carries no class colour to measure: "
				.. tostring(r.name._text))
		elseif worst(code, lo, hi) < math.min(3, best) - 0.05 then
			fail(scenario, ("the class colour in the name is %.2f:1 against the panel;"
				.. " coloured text is held to 3:1"):format(worst(code, lo, hi)))
		end
	end)
end

-- ------------------------------------------------------------------ look2 2
-- Nobody who kept the default panel sees a colour move.
--
-- The contrast rule decides the colours now, and on the dark panel it has to
-- arrive at exactly what was drawn before it: white names, the grey reason
-- line warmed a third of the way towards the reason colour, the class colour
-- as the game gives it, and the black shadows.
do
	local scenario = "the default panel's text colours are the ones it always had"
	withTree(scenario, { nameplate1 = { "Anna", "Aim" } }, nil, function(ns)
		freshPrompt(ns, scenario)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local r = ns.Prompt:Regions()
		local function near(got, want, what)
			for i = 1, #want do
				if not got or math.abs((got[i] or -1) - want[i]) > 0.002 then
					fail(scenario, ("%s is %s, not %s"):format(what,
						got and table.concat(got, " ", 1, #want) or "unset", table.concat(want, " ")))
					return
				end
			end
		end
		near(r.name._textColor, { 1, 1, 1, 1 }, "the name's colour")
		-- 0.60 0.61 0.68 taken 0.35 of the way to the owed amber.
		near(r.sub._textColor, { 0.60 + 0.40 * 0.35, 0.61 + 0.17 * 0.35, 0.68 - 0.38 * 0.35, 1 },
			"the reason line's colour")
		near(r.name._shadowColor, { 0, 0, 0, 0.9 }, "the name's shadow")
		near(r.sub._shadowColor, { 0, 0, 0, 0.8 }, "the reason line's shadow")
		local code = tostring(r.name._text):match("|c(%x%x%x%x%x%x%x%x)")
		local want = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PRIEST and RAID_CLASS_COLORS.PRIEST.colorStr
		if want and code and code:lower() ~= want:lower() then
			fail(scenario, ("the priest's class colour was redrawn as %s on the default panel,"
				.. " where the game's own %s reads"):format(code, want))
		end
	end)
end

-- The priest's white above cannot catch a coloured word moving on the dark
-- panel: on a dark ground the only way a colour moves is towards white, and
-- white is already there. The colours that could move are the ones only just
-- clear of the 3:1 line on this panel -- the list's own 707078 behind each
-- name, and the deepest class colours: the death knight's red, the demon
-- hunter's purple and the shaman's blue. Each goes through the same pass every
-- line does, and has to come out as it went in.
do
	local scenario = "the default panel leaves the colours near its contrast line alone"
	withTree(scenario, { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Corwin", "Ash" },
		nameplate3 = { "Dara", "Fenn" } }, nil, function(ns)
		freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		p.showQueue, p.queueRows = true, 3
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local r = ns.Prompt:Regions()
		local row = tostring(r.rows[1]._text or "")
		if row == "" then
			fail(scenario, "SKIPPED -- three people and an empty list")
		elseif not row:find("|cff707078", 1, true) then
			fail(scenario, "the list's grey behind a name was redrawn on the default panel: " .. row)
		end
		local deep = { "|cffc41e3aDeath knight|r", "|cffa330c9Demon hunter|r", "|cff0070ddShaman|r" }
		local rows = {}
		for i, text in ipairs(deep) do rows[i] = { text = text, reason = "group" } end
		ns.Prompt:PaintQueue(rows)
		for i, text in ipairs(deep) do
			local got = tostring(r.rows[i]._text or "")
			if got ~= text then
				fail(scenario, ("%s was redrawn as %s on the default panel, where it reads as it is")
					:format(text, got))
			end
		end
	end)
end

-- ------------------------------------------------------------------ look2 3
-- A text colour the player picked is drawn as it is.
--
-- The light-or-dark choice is the prompt's only while the colour is left at
-- its default. Somebody who picked red wants red, on any panel; overriding it
-- is the setting being ignored. And the default white left alone on a cream
-- panel is the case that has to change, keeping any transparency it was given.
do
	local scenario = "a text colour the player picked is used as picked"
	withTree(scenario, { nameplate1 = { "Anna", "Aim" } }, nil, function(ns)
		freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		local r = ns.Prompt:Regions()
		for _, bg in ipairs({ { 0.86, 0.84, 0.78, 1 }, { 0.04, 0.04, 0.06, 0.88 } }) do
			p.bgColor = bg
			p.fontColor = { 0.9, 0.2, 0.2, 1 }
			ns.Prompt:ApplyStyle()
			local c = r.name._textColor or {}
			if math.abs((c[1] or 0) - 0.9) > 1e-6 or math.abs((c[2] or 0) - 0.2) > 1e-6
				or math.abs((c[3] or 0) - 0.2) > 1e-6 then
				fail(scenario, ("red text picked for a panel of %.2f became %s"):format(bg[1],
					table.concat(c, " ")))
			end
		end
		p.bgColor = { 0.86, 0.84, 0.78, 1 }
		p.fontColor = { 1, 1, 1, 0.6 }
		ns.Prompt:ApplyStyle()
		local c = r.name._textColor or {}
		if (c[1] or 1) > 0.5 then
			fail(scenario, "white text left at its default stayed white on a cream panel")
		end
		if math.abs((c[4] or 0) - 0.6) > 1e-6 then
			fail(scenario, ("the text's own transparency was dropped: alpha %s, not 0.6")
				:format(tostring(c[4])))
		end
		-- A dark line under which a black shadow is a smudge: none.
		local s = r.name._shadowColor or {}
		if (s[4] or 0) > 0 and (s[1] or 0) < 0.5 then
			fail(scenario, "dark text on a light panel still has a black shadow under it")
		end
	end)
end

-- ------------------------------------------------------------------ look2 4
-- The Minimal look reads over the world.
--
-- With no panel the text lies on whatever is behind it, and the lines under
-- the name were a dim grey that vanished on a lit field. They are outlined
-- now, shadowed in full, and bright; the name stays white.
do
	local scenario = "the minimal look's text is outlined and bright"
	withTree(scenario, { nameplate1 = { "Anna", "Aim" } }, nil, function(ns)
		freshPrompt(ns, scenario)
		ns.db.profile.prompt.style = "minimal"
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local r = ns.Prompt:Regions()
		for what, fs in pairs({ name = r.name, ["reason line"] = r.sub, ["first list row"] = r.rows[1] }) do
			local flags = fs._font and fs._font.flags or ""
			if not tostring(flags):find("OUTLINE", 1, true) then
				fail(scenario, ("the %s has no outline over the world"):format(what))
			end
			local s = fs._shadowColor or {}
			if (s[4] or 0) < 0.99 then
				fail(scenario, ("the %s's shadow is at %s, not a full one"):format(what, tostring(s[4])))
			end
		end
		local sub = r.sub._textColor or { 0, 0, 0 }
		if lum(sub[1], sub[2], sub[3]) < 0.5 then
			fail(scenario, ("the reason line is %.2f %.2f %.2f over the world -- the dim grey"
				.. " that could not be read on a bright one"):format(sub[1], sub[2], sub[3]))
		end
	end)
end

-- And the list under it. Each row's words after the name carry a colour code
-- of their own, which the row's text colour cannot reach: brightening the row
-- brightened the two spaces between the name and the words, and the words
-- stayed the list's dim grey over the world.
do
	local scenario = "the minimal look's list rows are bright after the name too"
	withTree(scenario, { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Corwin", "Ash" },
		nameplate3 = { "Dara", "Fenn" } }, nil, function(ns)
		freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		p.style, p.showQueue, p.queueRows = "minimal", true, 3
		ns.Prompt:ApplyStyle()
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		local r = ns.Prompt:Regions()
		local row = tostring(r.rows[1]._text or "")
		-- The last code in the row is the one on the words after the name.
		local code = hexColour(row:match(".*(|c%x%x%x%x%x%x%x%x)"))
		if row == "" then
			fail(scenario, "SKIPPED -- three people and an empty list")
		elseif not code then
			fail(scenario, "SKIPPED -- the row carries no colour to measure: " .. row)
		elseif lum(code[1], code[2], code[3]) < 0.5 then
			fail(scenario, ("the words after the name are %.2f %.2f %.2f over the world -- the"
				.. " list's dim grey: %s"):format(code[1], code[2], code[3], row))
		end
	end)
end

-- ------------------------------------------------------------------ look2 5
-- The colour-blind palette: off by default, a real choice on the page,
-- clamped, applied everywhere the reason colour goes, and actually apart for
-- the colour blindness it is for.
local function simulate(M, c)
	local l = { lin(c[1]), lin(c[2]), lin(c[3]) }
	local out = {}
	for i = 1, 3 do
		local v = M[i][1] * l[1] + M[i][2] * l[2] + M[i][3] * l[3]
		out[i] = math.max(0, math.min(1, v))
	end
	return out
end
-- CIE L*a*b* from linear RGB, D65.
local function labOf(l)
	local X = (0.4124 * l[1] + 0.3576 * l[2] + 0.1805 * l[3]) / 0.9505
	local Y = 0.2126 * l[1] + 0.7152 * l[2] + 0.0722 * l[3]
	local Z = (0.0193 * l[1] + 0.1192 * l[2] + 0.9505 * l[3]) / 1.089
	local function f(t) if t > 0.008856 then return t ^ (1 / 3) end return 7.787 * t + 16 / 116 end
	return 116 * f(Y) - 16, 500 * (f(X) - f(Y)), 200 * (f(Y) - f(Z))
end
-- Machado, Oliveira and Fernandes (2009), full severity, on linear RGB.
local VISION = {
	{ "normal sight", { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } } },
	{ "protanopia", { { 0.152286, 1.052583, -0.204868 }, { 0.114503, 0.786281, 0.099216 },
		{ -0.003882, -0.048116, 1.051998 } } },
	{ "deuteranopia", { { 0.367322, 0.860646, -0.227968 }, { 0.280085, 0.672501, 0.047413 },
		{ -0.011820, 0.042940, 0.968881 } } },
}

do
	local scenario = "the colour-blind palette is off by default, clamped and applied"
	withTree(scenario, { nameplate1 = { "Anna", "Aim" } }, nil, function(ns)
		freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		local REASONS = { "target", "owed", "group", "nearby", "asked" }
		local function colours()
			local out = {}
			for _, reason in ipairs(REASONS) do out[reason] = { ns.Prompt:AccentColor(reason) } end
			return out
		end
		if p.reasonPalette ~= "standard" then
			fail(scenario, "the palette defaults to " .. tostring(p.reasonPalette) .. ", not standard")
		end
		local standard = colours()
		if math.abs(standard.owed[1] - 1) > 1e-6 or math.abs(standard.owed[2] - 0.78) > 1e-6 then
			fail(scenario, "the standard palette no longer paints owed in its amber")
		end

		local option = findOption(ns.optionsTable, "reasonPalette")
		if not option then
			fail(scenario, "no Reason colours control on the options page")
		else
			if type(option.values) ~= "table" or not option.values.standard
				or not option.values.colourblind then
				fail(scenario, "the Reason colours control does not offer both palettes")
			end
			if option.get() ~= "standard" then
				fail(scenario, "the Reason colours control reads " .. tostring(option.get()))
			end
			-- Between the Style header and the one after it, whatever the
			-- numbers are.
			local look = ns.optionsTable.args.appearance.args
			local first, last = look.styleHeader and look.styleHeader.order, look.attentionHeader and look.attentionHeader.order
			if type(option.order) ~= "number" or not (first and last)
				or option.order < first or option.order >= last then
				fail(scenario, "the Reason colours control is not under Style")
			end
			-- Greyed out only where nothing is drawn in the reason colours.
			-- The list's bars take the palette whatever the accent says, and
			-- with the accent at Neither the glow and a press's wash still do.
			local cases = {
				{ true, "off", true, false, "the accent at Neither and the list up" },
				{ false, "icon", true, false, "Colour it by reason off and the list up" },
				{ true, "off", false, false, "the accent at Neither, where the glow still uses it" },
				{ false, "icon", false, true, "Colour it by reason off and the list hidden" },
			}
			local saved = { p.accentByReason, p.accentMode, p.showQueue }
			for _, c in ipairs(cases) do
				p.accentByReason, p.accentMode, p.showQueue = c[1], c[2], c[3]
				local off = type(option.disabled) == "function" and option.disabled() or false
				if (off and true or false) ~= c[4] then
					fail(scenario, ("the Reason colours control is %s with %s"):format(
						off and "greyed out" or "live", c[5]))
				end
			end
			p.accentByReason, p.accentMode, p.showQueue = saved[1], saved[2], saved[3]
			option.set({ "reasonPalette" }, "colourblind")
		end
		if p.reasonPalette ~= "colourblind" then p.reasonPalette = "colourblind" end
		ns.Prompt:ApplyStyle()
		local cvd = colours()
		for _, reason in ipairs(REASONS) do
			local a, b = standard[reason], cvd[reason]
			if math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) + math.abs(a[3] - b[3]) < 0.05 then
				fail(scenario, ("%s is painted the same in both palettes"):format(reason))
			end
		end
		-- Apart, and further apart than the standard set, under each vision.
		for _, v in ipairs(VISION) do
			local label, M = v[1], v[2]
			local closest, pair = math.huge, nil
			for i = 1, #REASONS do
				for j = i + 1, #REASONS do
					local L1, a1, b1 = labOf(simulate(M, cvd[REASONS[i]]))
					local L2, a2, b2 = labOf(simulate(M, cvd[REASONS[j]]))
					local d = math.sqrt((L1 - L2) ^ 2 + (a1 - a2) ^ 2 + (b1 - b2) ^ 2)
					if d < closest then closest, pair = d, REASONS[i] .. " and " .. REASONS[j] end
				end
			end
			if closest < 32 then
				fail(scenario, ("with %s, %s are only %.1f apart in the colour-blind palette")
					:format(label, pair, closest))
			end
		end

		-- The list's bars carry the palette too: they are the reason colour at
		-- a glance, and a palette that stopped at the ring would leave them in
		-- the colours it exists to replace.
		local r = ns.Prompt:Regions()
		ns.Prompt:PaintQueue({ { text = "Gwen Hollow", reason = "group" } })
		local bar = r.bars[1]._color or {}
		if math.abs((bar[1] or 0) - cvd.group[1]) > 1e-6 or math.abs((bar[3] or 0) - cvd.group[3]) > 1e-6 then
			fail(scenario, "the queue's bar for a group member is not the palette's group colour")
		end

		-- A palette this build does not know, from a hand-edited file or a
		-- newer version's export: drawn as the standard set, and put back to it
		-- by the clamp.
		p.reasonPalette = "rainbow"
		local odd = colours()
		if math.abs(odd.owed[2] - standard.owed[2]) > 1e-6 then
			fail(scenario, "an unknown palette is not drawn as the standard one")
		end
		ns.ClampSettings()
		if p.reasonPalette ~= "standard" then
			fail(scenario, "the clamp left the palette at " .. tostring(p.reasonPalette))
		end
		p.reasonPalette = 7
		ns.ClampSettings()
		if p.reasonPalette ~= "standard" then
			fail(scenario, "the clamp left a numeric palette in place")
		end
	end)
end

-- ------------------------------------------------------------------ look2 6
-- Long German lines fit their room.
--
-- The German and the Russian for the panel's lines run a third longer than
-- the English, and the client cuts a line that does not fit with an ellipsis
-- -- which cut exactly the words that said why. A line too long for its room
-- is drawn up to a fifth smaller first; the count chip's room is given back
-- to the lines while the chip is down; and only a line that still does not
-- fit is left to the client to cut, which it does rather than running off the
-- panel. Measured with the recorder's own widths: half the font's size a
-- character.
local function room(ns, fs)
	local p = ns.db.profile.prompt
	local left, right
	for _, pt in ipairs(fs.points or {}) do
		if pt[1] == "RIGHT" then right = pt[2] end
		if pt[1] == "TOPLEFT" or pt[1] == "BOTTOMLEFT" or pt[1] == "LEFT" then left = pt[2] end
	end
	if not (left and right) then return nil end
	return p.width - left + right
end

do
	local scenario = "long German reason lines fit their room"
	withTree(scenario, { nameplate1 = { "Brannoc", "Vale" }, nameplate2 = { "Corwin", "Ash" },
		nameplate3 = { "Dara", "Fenn" } }, "deDE", function(ns)
		freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		-- Narrow enough that "braucht Arcane Intellect" is too long beside
		-- the chip, as it is at the default width in Friz Quadrata in game.
		p.width = 180
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		local r = ns.Prompt:Regions()
		local sub = r.sub
		local text = tostring(sub._text or "")
		if not text:find("braucht", 1, true) then
			fail(scenario, "SKIPPED -- the reason line is not the German one: " .. text)
			return
		end
		if not r.chip:IsShown() then
			fail(scenario, "SKIPPED -- three people and no count chip")
			return
		end
		local space = room(ns, sub)
		local width = sub:GetStringWidth()
		local size = sub._font and sub._font.size
		if not (space and width and size) then
			fail(scenario, "SKIPPED -- the reason line's room or width could not be read")
			return
		end
		if width > space + 0.5 then
			fail(scenario, ("the reason line is %d wide in a room of %d at size %d -- cut off"
				.. " by the client"):format(width, space, size))
		end
		if size >= p.fontSize - 3 then
			fail(scenario, "SKIPPED -- the line fitted without shrinking, so nothing was tested")
		end
		if size < 8 then
			fail(scenario, ("the reason line was shrunk to %d, past four fifths of its size"):format(size))
		end
		if text:find("...", 1, true) then
			fail(scenario, "the addon cut the line itself: " .. text)
		end

		-- One person left, the chip down: the room comes back and the line
		-- goes back to its own size.
		wipe(Mock.unitNames)
		Mock.unitNames.nameplate1 = { "Brannoc", "Vale" }
		ns.nameplateUnits.nameplate2, ns.nameplateUnits.nameplate3 = nil, nil
		-- Long gone, not just out of sight a moment (see passing in Queue.lua).
		wipe(ns.passersBy)
		ns.addon:Tick()
		if r.chip:IsShown() then
			fail(scenario, "SKIPPED -- the chip is still up with one person")
			return
		end
		local wide = room(ns, sub)
		if not wide or wide <= space then
			fail(scenario, ("the reason line's room stayed %s with the chip down"):format(tostring(wide)))
		end
		if (sub._font and sub._font.size) ~= p.fontSize - 3 then
			fail(scenario, ("a line that fits again stayed shrunk, at %s"):format(
				tostring(sub._font and sub._font.size)))
		end
	end)
end

do
	local scenario = "a German line too long to fit is cut, not run off the panel"
	withTree(scenario, { nameplate1 = { "Anna", "Aim" } }, "deDE", function(ns)
		freshPrompt(ns, scenario)
		owe(ns, "Anna Aim")
		ns.addon:Tick()
		ns.Prompt:ShowOutcome("sent", "Anna Aim")
		local r = ns.Prompt:Regions()
		local sub = r.sub
		local base = ns.db.profile.prompt.fontSize - 3
		local size = sub._font and sub._font.size
		local least = math.max(7, math.floor(base * 0.8 + 0.5))
		if not tostring(sub._text or ""):find("Client", 1, true) then
			fail(scenario, "SKIPPED -- the sent line is not the German one: " .. tostring(sub._text))
			return
		end
		if size ~= least then
			fail(scenario, ("the sent line is at size %s; one that does not fit goes to %d"
				.. " before it is cut"):format(tostring(size), least))
		end
		if sub._wordWrap ~= false then
			fail(scenario, "the reason line wraps, so a long one runs out of the panel")
		end
		if room(ns, sub) ~= ns.db.profile.prompt.width - 50 - 10 then
			fail(scenario, ("the outcome's lines are not given the chip's room: %s")
				:format(tostring(room(ns, sub))))
		end
	end)
end

-- ------------------------------------------------------------------ look2 7
-- A long row in the list under the prompt is drawn smaller before it is cut.
--
-- The rows had a width and nothing else: "Sable Harrow  needs Arcane
-- Intellect" ran a fifth past a 220-wide prompt's row and the client cut it
-- to "needs Arcane Inte...", which only the listing pictures noticed, on the
-- one machine whose font ran wide. The rows now go through the same fitting
-- as the panel's lines, into their own width. Half the font's size a
-- character: 36 characters at 10 is 180, at 9 it is 162, the row's room.
do
	local scenario = "a long row in the list is drawn smaller to fit"
	withTree(scenario, { nameplate1 = { "Bo", "Ash" }, nameplate2 = { "Sable", "Harrow" } },
		"enUS", function(ns)
		freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		p.width, p.showQueue, p.queueRows = 220, true, 3
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		local row
		for _, fs in ipairs(ns.Prompt:Regions().rows) do
			if tostring(fs._text or ""):find("Sable Harrow", 1, true) then row = fs end
		end
		if not row then
			fail(scenario, "SKIPPED -- Sable Harrow is not in the list")
			return
		end
		local width, room = row:GetStringWidth(), row._width
		local size = row._font and row._font.size
		if not (width and room and size) then
			fail(scenario, "SKIPPED -- the row's width, room or font could not be read")
			return
		end
		if size >= p.fontSize - 3 then
			fail(scenario, ("the row is %d wide in a room of %d and was left at size %d,"
				.. " so the client cuts it"):format(width, room, size))
		elseif width > room + 0.5 then
			fail(scenario, ("the row is %d wide in a room of %d at size %d -- cut off"
				.. " by the client"):format(width, room, size))
		end
	end)
end

-- ------------------------------------------------------------------ look2 8
-- Every button and dropdown on the options page holds its words.
--
-- AceConfigDialog gives a control 170 pixels unless the option names a width,
-- and none did: "Put these back to default" showed as "Put these back to
-- de..." and "Above the action bars (default)" as "Above the action bars
-- (d..." (a player's screenshots), and the German runs longer still. Every
-- button and dropdown, in English and in German, is asked for its width the way
-- AceConfigDialog asks, and has to hold its label (a button, with the 15
-- pixels AceGUI keeps clear either side) or its longest choice (a dropdown,
-- whose text gets 36 fewer than the control). Measured the recorder's way:
-- half the font's size a character, at the 12 a font string has before
-- anything sets one.
local function controlsOf(node, out)
	if type(node) ~= "table" then return out end
	if node.type == "execute"
		or (node.type == "select" and node.style ~= "radio" and not node.dialogControl) then
		out[#out + 1] = node
	end
	if type(node.args) == "table" then
		for _, child in pairs(node.args) do controlsOf(child, out) end
	end
	return out
end

local function chars(text)
	return select(2, tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[^\128-\191]", ""))
end

for _, locale in ipairs({ "enUS", "deDE" }) do
	local scenario = "every options button and dropdown holds its words (" .. locale .. ")"
	withTree(scenario, {}, locale, function(ns)
		freshPrompt(ns, scenario)
		local controls = controlsOf(ns.optionsTable, {})
		if #controls < 20 then
			fail(scenario, ("SKIPPED -- only %d buttons and dropdowns found on the options page")
				:format(#controls))
			return
		end
		for _, node in ipairs(controls) do
			local info = { option = node }
			local width = node.width
			if type(width) == "function" then width = width(info) end
			if width ~= "full" then
				local units = type(width) == "number" and width
					or (width == "double" and 2) or (width == "half" and 0.5) or 1
				local text, needed
				if node.type == "execute" then
					text = node.name
					if type(text) == "function" then text = text(info) end
					needed = type(text) == "string" and chars(text) * 6 + 30 or nil
				else
					local values = node.values
					if type(values) == "function" then values = values(info) end
					for _, label in pairs(type(values) == "table" and values or {}) do
						local w = chars(label) * 6 + 36
						if not needed or w > needed then needed, text = w, label end
					end
				end
				if needed and units * 170 < needed then
					fail(scenario, ("%s %q is %d wide and needs %d -- the game cuts it with an"
						.. " ellipsis"):format(node.type == "execute" and "button" or "dropdown",
						tostring(text), units * 170, needed))
				end
			end
		end
	end)
end
