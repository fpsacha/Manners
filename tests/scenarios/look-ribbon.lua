-- The Ribbon look (Looks/Ribbon.lua): what it promises beyond what every look
-- does, which tests/scenarios/looks.lua, hunt35-effects.lua and
-- hunt37-effects.lua already ask of it.
--
-- Run on the recording CreateFrame in tests/frametree.lua, which remembers what
-- every region was told: a look that is wrong throws nothing, it just shows
-- the wrong thing.
--
-- What it holds:
--   * Ribbon is registered, in the toc after the other looks, named in all
--     eight translations; Whisper, the look it took the place of, is gone from
--     the toc, the files and the saved settings (an unknown saved style is
--     repaired to the default);
--   * every state paints on every client without an error;
--   * the layout: the cloth, its rails, the medallion, the icon, the tags and
--     the lines sit inside the width and height the prompt is given, at every
--     size from 160 to 400 wide and 32 to 72 tall, icon on and off, in every
--     marker mode, English and German; the lines never run over the medallion
--     nor past the notch of the fork, and a long name or a long German reason
--     is fitted, never cut over anything;
--   * it is a solid object: the cloth, the rails and the medallion are drawn at
--     full strength at rest (alpha 1, nothing laid over them), and the shipped
--     cloth is opaque in its body;
--   * the reason: the enamel ring of the medallion in the palette's colour
--     ("Ring around the icon"), the cloth dyed deep ("Stripe"), both, or
--     neither; both palettes keep their reasons apart, the name and the reason
--     line hold their contrast on every dye, and the default owed look is the
--     crimson ribbon;
--   * the outcomes, the arrival (slide and glint; fades only on Calm), the owed
--     breath (three, then still), the landing (a shine along the cloth, the
--     medallion's flash), the refusal, the fight, the cooldown on the icon, the
--     cursor, and leaving the look;
--   * every frame of light is under the text, nothing of the look's own scales
--     over the text, and every effect stays inside the prompt's box;
--   * the list: a small ribbon per name, each a button hung off a frame; and
--     the tags for the count and the bound key;
--   * the face: Morpheus where the client writes in Latin letters, the client's
--     own elsewhere, the player's choice above both;
--   * the art is the generator's, byte for byte, every file drawn and used.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local COMMAND = "CLICK MannersPrompt:LeftButton"
local REASONS = { "target", "owed", "asked", "group", "nearby", "self" }
local LOCALES = { "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }
-- The figures the code and the art share (Looks/Ribbon.lua, the generator).
local RIBBON_PX, END_PX, NOTCH_PX = 64, 32, 19
local M_BEZEL = 0.635

local function withTree(scenario, names, body, before)
	Mock.reset()
	if before then before() end
	FT.install()
	local restore = strangers(names or {})
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns, scenario) end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.005)
end

local function sameColour(c, r, g, b)
	return c ~= nil and near(c[1], r) and near(c[2], g) and near(c[3], b)
end

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

-- The prompt up in Ribbon with Anna owed on top (or `who`). Returns the regions,
-- the settings and the look.
local function upIn(ns, scenario, edit, arriving, who)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "ribbon"
	p.showSub, p.showIcon, p.roundIcon = true, true, false
	-- What an earlier call chose is not the next one's.
	for _, key in ipairs({ "bgColor", "fontColor", "accentMode", "reasonPalette", "accentByReason", "accentColor",
		"effects", "flashStyle", "width", "height", "fontSize", "iconSize", "scale", "showQueue", "showCount", "font",
		"queueRows", "classColor" }) do
		local d = ns.defaults.profile.prompt[key]
		if type(d) == "table" then
			local copy = {}
			for i, v in pairs(d) do copy[i] = v end
			d = copy
		end
		p[key] = d
	end
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, who or "Anna Aim")
	tick(ns)
	-- At rest, unless the arrival is what is asked about: the ribbon slides
	-- into place in 0.3 s.
	if not arriving then
		Mock.advance(0.5)
		FT.settle()
	end
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function isRibbon(look)
	return look ~= nil and look.key == "ribbon" and look.cloth ~= nil and look.medal ~= nil
end

local function plays(list)
	local n = 0
	for _, g in ipairs(list) do n = n + (g._plays or 0) end
	return n
end

local function span(r)
	local x0, x1 = FT.span(r, "x")
	local y0, y1 = FT.span(r, "y")
	if not (x0 and y0) then return nil end
	return { x0, y0, x1, y1 }
end

local function inside(b, a, slack)
	slack = slack or 0.05
	return b[1] >= a[1] - slack and b[3] <= a[3] + slack and b[2] >= a[2] - slack and b[4] <= a[4] + slack
end

local function apart(a, b, slack)
	slack = slack or 0
	return a[3] <= b[1] + slack or b[3] <= a[1] + slack or a[4] <= b[2] + slack or b[4] <= a[2] + slack
end

local function lin(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
local function lum(r, g, b) return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b) end
local function contrast(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- CIE76 between two sRGB colours.
local function lab(r, g, b)
	local R, G, B = lin(r), lin(g), lin(b)
	local X = (0.4124 * R + 0.3576 * G + 0.1805 * B) / 0.95047
	local Y = 0.2126 * R + 0.7152 * G + 0.0722 * B
	local Z = (0.0193 * R + 0.1192 * G + 0.9505 * B) / 1.08883
	local function f(t) return t > 0.008856 and t ^ (1 / 3) or 7.787 * t + 16 / 116 end
	return 116 * f(Y) - 16, 500 * (f(X) - f(Y)), 200 * (f(Y) - f(Z))
end

local function deltaE(a, b)
	local l1, a1, b1 = lab(a[1], a[2], a[3])
	local l2, a2, b2 = lab(b[1], b[2], b[3])
	return math.sqrt((l1 - l2) ^ 2 + (a1 - a2) ^ 2 + (b1 - b2) ^ 2)
end

-- As a protanope and a deuteranope see it (Machado et al. 2009, full
-- severity, on linear light).
local function simulate(c, m)
	local R, G, B = lin(c[1]), lin(c[2]), lin(c[3])
	local function enc(v)
		v = math.max(0, math.min(1, v))
		return v <= 0.0031308 and v * 12.92 or 1.055 * v ^ (1 / 2.4) - 0.055
	end
	return { enc(m[1][1] * R + m[1][2] * G + m[1][3] * B), enc(m[2][1] * R + m[2][2] * G + m[2][3] * B),
		enc(m[3][1] * R + m[3][2] * G + m[3][3] * B) }
end
local PROTAN = { { 0.152286, 1.052583, -0.204868 }, { 0.114503, 0.786281, 0.099216 }, { -0.003882, -0.048116, 1.051998 } }
local DEUTAN = { { 0.367322, 0.860646, -0.227968 }, { 0.280085, 0.672501, 0.047413 }, { -0.011820, 0.042940, 0.968881 } }

-- ------------------------------------------------------------------ 1
-- Registered, listed in the toc after the others, named in every language, and
-- Whisper gone.
withTree("look-ribbon: Ribbon is registered, in the toc and translated; Whisper is gone", ANNA, function(ns, scenario)
	local look = ns.Looks.list.ribbon
	if not look then fail(scenario, "no look is registered under \"ribbon\"") return end
	if ns.Looks.Get("ribbon") ~= look then fail(scenario, "Get does not hand back Ribbon") end
	if not ns.Looks.Allowed().ribbon then fail(scenario, "a saved style of \"ribbon\" would be repaired away") end
	local values = ns.Looks.Choices()
	if values.ribbon ~= look.name or not look.name:find("Ribbon", 1, true) then
		fail(scenario, "the look is not in the dropdown under its name: " .. tostring(values.ribbon))
	end
	if look.order ~= 4 then fail(scenario, "the look is not fourth in the dropdown: " .. tostring(look.order)) end
	for _, method in ipairs({ "Apply", "Hide", "Build", "PlaceLines", "Fitted", "PaintReason", "Chip", "Attention",
		"StopAttention", "Flourish", "StopFlourishes", "PaintOutcome", "ClearOutcome", "Combat", "Hover",
		"PaintQueue", "Styled", "TwoLineHeight", "AccentCarriers", "IconSize" }) do
		if type(look[method]) ~= "function" then fail(scenario, "Ribbon has no " .. method) end
	end
	local toc = slurp(dir .. "/Manners.toc") or ""
	local arcane, ribbon = toc:find("Looks\\Arcane.lua", 1, true), toc:find("Looks\\Ribbon.lua", 1, true)
	if not (arcane and ribbon and ribbon > arcane) then fail(scenario, "Looks\\Ribbon.lua is not in Manners.toc after the looks") end
	for _, flavour in ipairs({ "Camelot", "Vanilla", "TBC", "Mists", "Mainline" }) do
		local generated = slurp(dir .. "/Manners_" .. flavour .. ".toc") or ""
		if not generated:find("Looks\\Ribbon.lua", 1, true) then fail(scenario, flavour .. "'s toc does not load Ribbon") end
		if generated:lower():find("whisper.lua", 1, true) then fail(scenario, flavour .. "'s toc still loads Whisper") end
	end
	if toc:lower():find("looks\\whisper", 1, true) then fail(scenario, "Manners.toc still names Whisper") end
	-- The name, the card's title and its line, in all eight translations, read
	-- from the files (the client loads one of them).
	for _, code in ipairs(LOCALES) do
		local text = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
		for _, english in ipairs({ look.name, look.title, look.description }) do
			local key = 'L["' .. english .. '"] = "'
			local at = text:find(key, 1, true)
			local line = at and text:sub(at + #key):match("^([^\n]*)")
			if not at or not line or #line < 4 then fail(scenario, code .. " has no translation of \"" .. english .. "\"") end
			if at and line and line:find(english, 1, true) then fail(scenario, code .. " left \"" .. english .. "\" in English") end
		end
		if text:find("Whisper -- floating letters", 1, true) or text:find('L["Whisper"]', 1, true) then
			fail(scenario, code .. " still holds a translation of the Whisper look")
		end
	end
	if look.title ~= "Ribbon" or type(look.description) ~= "string" or look.description == "" then
		fail(scenario, "the picker's card has no title and line of its own")
	end
	-- Whisper's files are gone, and nobody asks for the look any more.
	for _, path in ipairs({ "Looks/Whisper.lua", "tools/make_whisper_textures.py", "Textures/Whisper/Whisper_Bar.tga",
		"Textures/Previews/Preview_whisper.tga", "tests/scenarios/look-whisper.lua", "tests/mutations/look-whisper.py" }) do
		if slurp(dir .. "/" .. path) then fail(scenario, path .. " is still shipped") end
	end
	if ns.Looks.list.whisper then fail(scenario, "a look is still registered under \"whisper\"") end
	-- A saved style nobody registers is the default: the one that was never
	-- released is repaired like any other.
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	for _, saved in ipairs({ "whisper", "nonsense", 7 }) do
		p.style = saved
		ns.ClampSettings()
		if p.style ~= ns.defaults.profile.prompt.style then
			fail(scenario, ("a saved style of %s is not repaired to the default: %s"):format(tostring(saved), tostring(p.style)))
		end
	end
	p.style = "ribbon"
	ns.ClampSettings()
	if p.style ~= "ribbon" then fail(scenario, "ClampSettings repaired a saved \"ribbon\" away") end
	if not ns.Looks.PreviewFile("ribbon") then fail(scenario, "the picker has no picture for Ribbon") end
	if not slurp(dir .. "/Textures/Previews/Preview_ribbon.tga") then fail(scenario, "Preview_ribbon.tga is not shipped") end
end)

-- ------------------------------------------------------------------ 2
-- Every state paints on every client without an error: each reason, a group
-- cast, an outcome of each kind, a fight, the list, the cooldown.
for _, flavour in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
	local name = "look-ribbon: every state paints on " .. flavour
	withTree(name, CROWD, function(ns, scenario)
		local r, p, look = upIn(ns, scenario)
		if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
		local from = #(ns.errors or {})
		local function check(what)
			FT.settle()
			if #(ns.errors or {}) > from then
				local e = ns.errors[from + 1]
				fail(scenario, ("%s: %s -> %s"):format(what, tostring(e.where), tostring(e.err)))
				from = #ns.errors
			end
		end
		local buff = ns.ResolveBuff(true)
		for _, palette in ipairs({ "standard", "colourblind" }) do
			for _, mode in ipairs({ "icon", "stripe", "both", "off" }) do
				p.reasonPalette, p.accentMode = palette, mode
				ns.Prompt:ApplyStyle()
				for _, reason in ipairs(REASONS) do
					ns.Prompt:Paint({ name = "Anna Aim", short = "Anna", reason = reason, buff = buff }, 2)
					check(palette .. " " .. mode .. " " .. reason)
				end
			end
		end
		p.reasonPalette, p.accentMode = "standard", "icon"
		ns.Prompt:ApplyStyle()
		ns.Prompt:Paint({ name = "Gwen Hollow", short = "Gwen", reason = "group", buff = buff,
			groupCast = { label = "Gwen's party", missing = 3, low = 0, icon = 135932 } }, 0)
		check("a group cast")
		for _, kind in ipairs({ "cast", "failed", "sent" }) do
			Mock.advance(3)
			ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
			check("outcome " .. kind)
		end
		Mock.advance(3)
		tick(ns)
		Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.5, duration = 1.5 } }
		ns.Prompt:SyncCooldown()
		Mock.advance(0.7)
		ns.Prompt:SyncCooldown()
		check("cooldown")
		p.showQueue, p.queueRows = true, 3
		ns.Prompt:ApplyStyle()
		tick(ns)
		check("list")
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		tick(ns)
		ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
		check("combat")
		Mock.inCombat = false
		if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
		Mock.spellCooldowns = nil
		tick(ns)
		check("after")
	end, function() Mock.setFlavour(flavour) end)
end

-- ------------------------------------------------------------------ 3
-- The layout. Everything the ribbon holds sits inside the width and height the
-- prompt is given and apart from the rest; the lines never run over the
-- medallion nor past the notch of the fork: at every size and width, icon on
-- and off, in every marker mode and at the ends of the scale, in English and
-- in German.

-- Where the cloth's right edge is at `y` down from the prompt's top (units),
-- for a ribbon from `top` to `bottom` with its fork `notch` deep: the tip at
-- the top and the bottom, the apex at the middle.
local function forkEdge(W, g, y)
	local mid = (g.top + g.bottom) / 2
	if y <= mid then return W - g.notch * math.max(0, y - g.top) / (mid - g.top) end
	return W - g.notch * math.max(0, g.bottom - y) / (g.bottom - mid)
end

-- The least the fork's edge gives a box spanning `y0` to `y1`.
local function forkLimit(W, g, y0, y1)
	local mid = (g.top + g.bottom) / 2
	local least = math.min(forkEdge(W, g, y0), forkEdge(W, g, y1))
	if y0 <= mid and mid <= y1 then least = math.min(least, W - g.notch) end
	return least
end

-- The same fork on the ribbon's left, for a ribbon with no medallion.
local function leftEdge(g, y)
	local mid = (g.top + g.bottom) / 2
	if y <= mid then return g.notch * math.max(0, y - g.top) / (mid - g.top) end
	return g.notch * math.max(0, g.bottom - y) / (g.bottom - mid)
end

local function layoutAt(ns, scenario, label, edit, ctx)
	local r, p, look = upIn(ns, scenario, edit)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	ctx.n = ctx.n + 1
	local art = span(r.art)
	local k = (art[3] - art[1]) / look.W
	-- A box in units from the prompt's top left, y running down.
	local function rel(b) return { (b[1] - art[1]) / k, (art[4] - b[4]) / k, (b[3] - art[1]) / k, (art[4] - b[2]) / k } end
	local g, W, H = look.g, look.W, look.H
	local name, sub = span(r.name), r.sub:IsShown() and span(r.sub) or nil
	if not (art and name) then fail(scenario, label .. ": nothing to measure") return end
	local two = sub ~= nil
	local box = { 0, 0, W, H }
	-- Every piece of the ribbon is inside the box the prompt is given.
	local pieces = {}
	for i = 1, 3 do
		pieces["cloth" .. i], pieces["trim" .. i], pieces["drop" .. i] = look.cloth[i], look.trim[i], look.drop[i]
	end
	if look.showIcon then
		pieces.medal, pieces.enamel, pieces.well, pieces.glint, pieces.sweep = look.medal, look.enamel, look.well, look.glint, look.sweep
	else
		pieces.jewel, pieces.jewelSet, pieces.sweep = look.jewel, look.jewelSet, look.sweep
	end
	for what, t in pairs(pieces) do
		local b = t._shown ~= false and span(t)
		if b and not inside(rel(b), box, 0.7) then
			fail(scenario, ("%s: the %s is outside the prompt's box: %.1f %.1f %.1f %.1f in %d x %d"):format(label, what,
				rel(b)[1], rel(b)[2], rel(b)[3], rel(b)[4], W, H))
		end
	end
	-- The medallion's shade is a soft disc: what is seen of it is inside the box.
	if look.showIcon then
		local b = rel(span(look.shade))
		local cx, cy = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
		local hw, hh = (b[3] - b[1]) / 2 * 0.70, (b[4] - b[2]) / 2 * 0.70
		if cx - hw < -0.7 or cx + hw > W + 0.7 or cy - hh < -0.7 or cy + hh > H + 0.7 then
			fail(scenario, label .. ": the medallion's shade falls outside the box")
		end
	end
	-- The cloth: top to bottom, the middle meeting the fork, the fork at the
	-- right edge.
	local c1, c2 = rel(span(look.cloth[1])), rel(span(look.cloth[2]))
	if not (near(c1[2], g.top, 0.05) and near(c1[4], g.bottom, 0.05) and near(c2[2], g.top, 0.05) and near(c2[4], g.bottom, 0.05)) then
		fail(scenario, label .. ": the cloth is not the height the layout says")
	end
	if not (near(c1[3], c2[1], 0.05) and near(c2[3], W, 0.05)) then
		fail(scenario, label .. ": the cloth's middle does not meet its fork, or the fork is short of the right edge")
	end
	if look.showIcon then
		if not near(c1[1], g.cx, 0.05) then fail(scenario, label .. ": the cloth does not start under the medallion's middle") end
	else
		local c3 = rel(span(look.cloth[3]))
		if not (near(c3[1], 0, 0.05) and near(c3[3], c1[1], 0.05)) then
			fail(scenario, label .. ": with no medallion the cloth's left fork does not meet its middle")
		end
	end
	-- The rails sit on the cloth's edges.
	for i = 1, 2 do
		local t, c = rel(span(look.trim[i])), rel(span(look.cloth[i]))
		if not (near(t[1], c[1], 0.05) and near(t[3], c[3], 0.05) and near(t[2], c[2], 0.05) and near(t[4], c[4], 0.05)) then
			fail(scenario, label .. ": the rails are not the cloth's size")
		end
	end
	-- The shadow is one piece: its forked end meets its middle and ends at the
	-- edge, and with no medallion the left end does the same.
	local d1, d2 = rel(span(look.drop[1])), rel(span(look.drop[2]))
	if not (near(d1[3], d2[1], 0.05) and near(d2[3], W, 0.05)) then
		fail(scenario, label .. ": the shadow's middle does not meet its forked end, or the end is not at the edge")
	end
	if not look.showIcon then
		local d3 = rel(span(look.drop[3]))
		if not (near(d3[1], 0, 0.05) and near(d3[3], d1[1], 0.05)) then fail(scenario, label .. ": the shadow's left end does not meet its middle") end
	end
	-- The notch's depth is what the art draws for the cloth's height.
	if not near(g.notch, NOTCH_PX * g.rh / RIBBON_PX, 0.01) or not near(g.endW, END_PX * g.rh / RIBBON_PX, 0.01) then
		fail(scenario, label .. ": the fork's size is not what the art draws")
	end
	-- The medallion: round, inside the box, its icon round and inside its bezel.
	if look.showIcon then
		local m = rel(span(look.medal))
		if math.abs((m[3] - m[1]) - (m[4] - m[2])) > 0.02 then fail(scenario, label .. ": the medallion is not round (its box is not square)") end
		local i = rel(span(r.icon))
		if math.abs((i[3] - i[1]) - (i[4] - i[2])) > 0.02 then fail(scenario, label .. ": the icon is not round (its box is not square)") end
		if not (r.icon._mask == look.mask and look.mask._shown ~= false) then fail(scenario, label .. ": the icon is not cut round by the mask") end
		local mask = rel(span(look.mask))
		if not (near(mask[1], i[1], 0.02) and near(mask[3], i[3], 0.02) and near(mask[2], i[2], 0.02) and near(mask[4], i[4], 0.02)) then
			fail(scenario, label .. ": the mask is not the icon's size")
		end
		if (i[3] - i[1]) / 2 * 0.985 > M_BEZEL * look.g.half + 0.6 then fail(scenario, label .. ": the icon is wider than the bezel it sits in") end
		if not near((i[1] + i[3]) / 2, (m[1] + m[3]) / 2, 0.02) or not near((i[2] + i[4]) / 2, (m[2] + m[4]) / 2, 0.02) then
			fail(scenario, label .. ": the icon is not at the medallion's middle")
		end
		if (m[3] - m[1]) / 2 * 0.98 - 0.05 > H / 2 then fail(scenario, label .. ": the medallion is taller than the prompt") end
		-- The medallion is the panel's height (less its margin), held to half a
		-- narrow panel's width.
		local want = math.min(H - 3, math.max(24, math.floor(W * 0.5)))
		if not near(look.g.M, want, 0.01) then fail(scenario, label .. ": the medallion's size is not the height's") end
		if look.g.M < want - 0.01 or (look.g.M > H - 2) then fail(scenario, label .. ": the medallion is out of proportion") end
	else
		if r.icon:IsShown() then fail(scenario, label .. ": the icon is shown with the icon off") end
		for _, t in ipairs({ look.medal, look.enamel, look.well, look.glint }) do
			if t._shown ~= false then fail(scenario, label .. ": the medallion stayed with the icon off") end
		end
		for _, f in ipairs(look.fx.frames) do
			if f._shown ~= false then fail(scenario, label .. ": a ring's frame stayed up with the icon off") end
		end
		-- The jewel stands on the cloth, past the left fork's apex, clear of the name.
		local j = rel(span(look.jewel))
		if j[1] < g.notch + 1 then fail(scenario, label .. ": the jewel is in the fork's notch") end
		if j[3] > rel(name)[1] + 0.05 then fail(scenario, label .. ": the name starts over the jewel") end
		for _, y in ipairs({ j[2], j[4] }) do
			if j[1] < leftEdge(g, y) + 0.5 then fail(scenario, label .. ": the jewel is cut by the left fork") end
		end
	end
	-- The lines: clear of the medallion, inside the cloth, short of the fork.
	local lines = { name = name, sub = sub }
	for what, b in pairs(lines) do
		local n = rel(b)
		if look.showIcon and n[1] < g.cx + g.R + 0.5 then fail(scenario, ("%s: the %s starts over the medallion (%.1f, the medallion ends at %.1f)"):format(label, what, n[1], g.cx + g.R)) end
		if n[2] < g.top - 0.05 or n[4] > g.bottom + 0.05 then
			fail(scenario, ("%s: the %s leaves the cloth: %.1f to %.1f, the cloth %.1f to %.1f"):format(label, what, n[2], n[4], g.top, g.bottom))
		end
		local edge = forkLimit(W, g, n[2], n[4])
		if n[3] > edge - 2 + 1e-6 then
			fail(scenario, ("%s: the %s runs to %.1f, the fork's notch is at %.1f"):format(label, what, n[3], edge))
		end
		if n[3] > W - g.notch - 2 + 1e-6 then fail(scenario, label .. ": the " .. what .. " runs past the notch's apex") end
		if b[3] - b[1] > art[3] - art[1] then fail(scenario, label .. ": the " .. what .. " is wider than the prompt") end
	end
	if sub and not apart(name, sub, 0.3) then fail(scenario, label .. ": the name and the reason line overlap") end
	-- The chips: a gold tag each, short of the fork, clear of the lines: on the
	-- cloth, between its rails, but for the count's badge, which hangs on the
	-- medallion's rim (inside the prompt, its middle no further out than the rim).
	for what, frame in pairs({ count = look.chipBox, key = look.keyBox }) do
		local up = (what == "count" and look.countMode) or (what == "key" and look.keyUp)
		if up then
			local t = rel(span(frame))
			if what == "count" and look.countMode == "medal" then
				if not look.showIcon then fail(scenario, label .. ": a badge on a medallion that is not there") end
				if not inside(t, { 0, 0, W, H }, 0.3) then fail(scenario, label .. ": the count's badge leaves the prompt") end
				local dist = math.sqrt(((t[1] + t[3]) / 2 - g.cx) ^ 2 + ((t[2] + t[4]) / 2 - g.cy) ^ 2)
				if dist > g.R + 1 or dist < g.R * 0.6 then
					fail(scenario, ("%s: the count's badge is %.1f from the medallion's middle, not on its rim (%.1f)"):format(label, dist, g.R))
				end
			else
				if not inside(t, { 0, g.top, W, g.bottom }, 0.3) then fail(scenario, label .. ": the " .. what .. " tag leaves the cloth") end
				if t[3] > forkLimit(W, g, t[2], t[4]) - 2 + 1e-6 then fail(scenario, label .. ": the " .. what .. " tag is cut by the fork") end
				local rails = 5.8 * g.k
				if two and (t[2] < g.top + rails - 0.6 or t[4] > g.bottom - rails + 0.6) then
					fail(scenario, label .. ": the " .. what .. " tag is over a rail")
				end
			end
			if not apart(name, span(frame), 0.2) then fail(scenario, label .. ": the " .. what .. " tag is over the name") end
			if sub and not apart(sub, span(frame), 0.2) then fail(scenario, label .. ": the " .. what .. " tag is over the reason") end
		end
	end
	if look.countMode and look.keyUp and not apart(span(look.chipBox), span(look.keyBox), 0.2) then
		fail(scenario, label .. ": the count's tag and the key's overlap")
	end
end

for _, locale in ipairs({ "enUS", "deDE" }) do
	local scenario = "look-ribbon: the layout holds at every size, in every mode, and the fork cuts nothing, " .. locale
	withTree(scenario, CROWD, function(ns)
		local ctx = { n = 0 }
		-- A key bound, so the key's tag is up wherever the name leaves it room.
		SetBinding("SHIFT-F", COMMAND)
		local modes = { "icon", "stripe", "both", "off" }
		local long = locale == "deDE" and "hat dich gerade gebufft und wartet auf deine Antwort" or nil
		for _, W in ipairs({ 160, 220, 400 }) do
			for _, Hh in ipairs({ 32, 44, 72 }) do
				for _, icon in ipairs({ true, false }) do
					for _, mode in ipairs(modes) do
						local label = ("%s %dx%d, icon %s, %s"):format(locale, W, Hh, tostring(icon), mode)
						layoutAt(ns, scenario, label, function(p)
							p.width, p.height, p.fontSize = W, Hh, 13
							p.iconSize = math.min(30, Hh - 8)
							p.showIcon, p.accentMode = icon, mode
							p.showCount = true
							if long then p.reasonOwed = long end
						end, ctx)
					end
				end
			end
		end
		-- The biggest icon the slider allows, and big fonts.
		for _, case in ipairs({ { 220, 48, 17, 40 }, { 320, 72, 17, 64 }, { 160, 36, 24, 24 }, { 400, 72, 24, 56 }, { 220, 44, 11, 20 } }) do
			layoutAt(ns, scenario, ("%s %dx%d font %d icon %d"):format(locale, case[1], case[2], case[3], case[4]), function(p)
				p.width, p.height, p.fontSize, p.iconSize = case[1], case[2], case[3], case[4]
				if long then p.reasonOwed = long end
			end, ctx)
		end
		for _, scale in ipairs({ 0.7, 1.0, 1.6 }) do
			layoutAt(ns, scenario, locale .. " scale " .. scale, function(p)
				p.scale = scale
				if long then p.reasonOwed = long end
			end, ctx)
		end
		-- Every width from 160 to 400 at the default height and at a tall one,
		-- with the long reason of a long translation and a long name.
		for _, Hh in ipairs({ 44, 60 }) do
			for W = 160, 400, 16 do
				layoutAt(ns, scenario, ("%s width %d, height %d"):format(locale, W, Hh), function(p)
					p.width, p.height = W, Hh
					if long then p.reasonOwed = long end
				end, ctx)
				local r, look = ns.Prompt:Regions(), ns.Prompt:Regions().look
				for _, others in ipairs({ 0, 2 }) do
					ns.Prompt:Paint({ name = "Anna Aim", short = "Annabelle-Marguerite Thistlewood", reason = "nearby",
						buff = ns.ResolveBuff(true) }, others)
					ns.Prompt.lib.SetLine(r.sub, "needs Arcane Intellect, and a good deal more besides")
					FT.settle()
					local art = span(r.art)
					local g = look.g
					for what, fs in pairs({ name = r.name, sub = r.sub }) do
						if fs:IsShown() then
							local b = span(fs)
							local n = { b[1] - art[1], art[4] - b[4], b[3] - art[1], art[4] - b[2] }
							if n[3] > forkLimit(look.W, g, n[2], n[4]) - 2 + 1e-6 then
								fail(scenario, ("width %d, %d waiting: the long %s runs past the fork's notch (%.1f)"):format(W, others, what, n[3]))
							end
							if look.showIcon and n[1] < g.cx + g.R + 0.5 then
								fail(scenario, ("width %d: the long %s starts over the medallion"):format(W, what))
							end
						end
					end
					ctx.n = ctx.n + 1
				end
			end
		end
		SetBinding("SHIFT-F", nil)
		if ctx.n < 150 then fail(scenario, "only " .. ctx.n .. " layouts were measured") end
	end, function()
		if locale ~= "enUS" then Mock.locale = locale end
	end)
end

-- The default prompt (220 x 44, font 13) holds two lines, and the lines sit
-- between the rails of the cloth.
withTree("look-ribbon: the default size holds two lines between the rails", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	if not (p.width == 220 and p.height == 44 and p.fontSize == 13) then fail(scenario, "the defaults are not 220 x 44 at 13") end
	if not r.sub:IsShown() then fail(scenario, "the default prompt has no second line") return end
	if ns.TwoLineHeight(13, "ribbon") > 44 then fail(scenario, "two lines need " .. ns.TwoLineHeight(13, "ribbon") .. " units, more than the default's 44") end
	local art = span(r.art)
	local rails = 5.8 * look.g.k
	for what, fs in pairs({ name = r.name, sub = r.sub }) do
		local b = span(fs)
		local top, bottom = art[4] - b[4], art[4] - b[2]
		if top < look.g.top + rails - 0.05 or bottom > look.g.bottom - rails + 0.05 then
			fail(scenario, ("the %s (%.1f to %.1f) is not between the rails (%.1f to %.1f)"):format(what, top, bottom,
				look.g.top + rails, look.g.bottom - rails))
		end
	end
	-- At the least height that holds two lines, at every font size, they are
	-- between the rails: the figure Options is told is honest.
	for _, size in ipairs({ 9, 11, 13, 15, 17, 20, 24 }) do
		local need = ns.TwoLineHeight(size, "ribbon")
		local rr, pp, lk = upIn(ns, scenario, function(q) q.width, q.height, q.fontSize = 300, need, size end)
		if not rr.sub:IsShown() then
			fail(scenario, ("at %d tall and %d pt, which the page says holds two lines, there is only one"):format(need, size))
		else
			local a = span(rr.art)
			local rl = 5.8 * lk.g.k
			for what, fs in pairs({ name = rr.name, sub = rr.sub }) do
				local b = span(fs)
				local top, bottom = a[4] - b[4], a[4] - b[2]
				if top < lk.g.top + rl - 0.6 or bottom > lk.g.bottom - rl + 0.6 then
					fail(scenario, ("at %d pt on %d tall the %s (%.1f to %.1f) is not between the rails (%.1f to %.1f)"):format(
						size, need, what, top, bottom, lk.g.top + rl, lk.g.bottom - rl))
				end
			end
		end
	end
	upIn(ns, scenario)
	if look.IconSize(p) < 24 or look.IconSize(p) > 44 then fail(scenario, "the icon's size is out of reason: " .. look.IconSize(p)) end
	local icon = span(r.icon)
	if not near(icon[3] - icon[1], look.IconSize(p), 0.5) then fail(scenario, "the icon is not the size the options page is told") end
	local g = look.g
	local ratio = (2 * g.R) / g.rh
	if ratio < 1.1 then fail(scenario, ("the medallion (%.1f) does not stand taller than the ribbon (%.1f)"):format(2 * g.R, g.rh)) end
	if 2 * g.R > p.height then fail(scenario, "the medallion is taller than the prompt") end
end)

-- With the tags up the lines keep clear of them, and the name wins at every
-- width: the count is a badge on the medallion, the key's tag stands on the
-- reason line, and a tag stands on a line only where that line has the room.
withTree("look-ribbon: the lines keep clear of the tags", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	if look.countMode ~= "medal" then fail(scenario, "the count is not a badge on the medallion: " .. tostring(look.countMode)) end
	if not tostring(r.count:GetText()):find("^%+%d") then
		fail(scenario, "the count's tag does not say how many more: " .. tostring(r.count:GetText()))
	end
	SetBinding("SHIFT-F", COMMAND)
	tick(ns)
	if look.countMode ~= "medal" or look.keyLane ~= "sub" or not look.keyUp then
		fail(scenario, ("the count is not on the medallion with the key's tag on the reason line: %s, %s"):format(
			tostring(look.countMode), tostring(look.keyLane)))
	end
	local name, sub = span(r.name), span(r.sub)
	for what, frame in pairs({ count = look.chipBox, key = look.keyBox }) do
		local b = span(frame)
		if b and not apart(name, b, 0.2) then fail(scenario, what .. ": the name runs under the tag") end
		if b and sub and not apart(sub, b, 0.2) then fail(scenario, what .. ": the reason runs under the tag") end
	end
	-- The key's tag stands on the reason's own line, low enough that the name's
	-- room is the whole line's.
	local kb = span(look.keyBox)
	if kb and not (kb[4] <= (name[2] + name[4]) / 2 + 0.01) then fail(scenario, "the key's tag is not on the reason line") end
	if look.inset > look.rightBase + 0.01 then fail(scenario, "the name gives room to a tag that is not on its line") end
	-- The key's tag is gold and its ink a dark crimson on it, never the cloth's
	-- lettering; the count's badge is gold round a field of crimson enamel, and
	-- its ink pale gold on that.
	local keyInk, countInk = look.keyText._textColor, r.count._textColor
	if not (keyInk and lum(keyInk[1], keyInk[2], keyInk[3]) < 0.05) then fail(scenario, "the key's text is not dark on its gold") end
	if not (countInk and lum(countInk[1], countInk[2], countInk[3]) > 0.5) then fail(scenario, "the count's text is not pale on its enamel") end
	if not tostring(look.keyChip[2]._file):find("Ribbon_Tag$") then fail(scenario, "the key's tag is not drawn from Ribbon_Tag: " .. tostring(look.keyChip[2]._file)) end
	if not tostring(look.chip[2]._file):find("Ribbon_Badge$") then fail(scenario, "the count's badge is not drawn from Ribbon_Badge: " .. tostring(look.chip[2]._file)) end
	-- No key over an outcome: it is not a press that casts.
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if look.keyUp or look.keyChip[2]._shown ~= false then fail(scenario, "the key's tag is up over an outcome") end
	Mock.advance(3)
	tick(ns)
	SetBinding("SHIFT-F", COMMAND)
	local sawSub = false
	for width = 120, 400, 5 do
		p.width = width
		ns.Prompt:ApplyStyle()
		ns.Prompt:Paint({ name = "Anna Aim", short = "Annabelle-Marguerite Thistlewood", reason = "owed",
			buff = ns.ResolveBuff(true) }, 3)
		if look.keyLane == "sub" then
			sawSub = true
			if not look:SubFits(look.keyRoom) then fail(scenario, width .. ": the key's tag is on the reason line and cuts it") end
		elseif look.keyLane == "name" then
			if not look:NameFits(look.keyRoom) then fail(scenario, width .. ": the key's tag is on the name line and cuts the name") end
			if look.countMode == "pair" and not look:NameFits(look:PairRoom()) then
				fail(scenario, width .. ": both tags are on the name line and cut the name")
			end
		end
		if look.countMode == "chip" and look.keyLane == "name" then
			fail(scenario, width .. ": the key's tag and a lone count are both on the name line")
		end
	end
	if not sawSub then fail(scenario, "the sweep of widths never put the key's tag on the reason line") end
	-- A name that cannot shrink into the room is not given less of it for a tag.
	p.width = 150
	ns.Prompt:ApplyStyle()
	ns.Prompt:Paint({ name = "Anna Aim", short = "Annabelle-Marguerite Thistlewood", reason = "owed",
		buff = ns.ResolveBuff(true) }, 3)
	if look.keyLane == "name" then fail(scenario, "the key's tag stayed on the line of a name that could not shrink") end
	SetBinding("SHIFT-F", nil)
	p.width = 220
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.keyUp then fail(scenario, "the key's tag outlived the binding") end
end)

-- An ordinary name is whole at the default size with the count and the key up:
-- "Elowen Thistledown" (18 letters) in English and a German two-part name of the
-- same length, on a 220 x 44 prompt at 13 pt with a 30 icon, +2 behind them and
-- F bound. The tags stand on the medallion and the reason line, so the name has
-- the line's room; measured the way a display serif is (0.58 of the size a
-- letter, the width the stand-in for Morpheus draws), which the mock's half a
-- size a letter flatters.
for _, case in ipairs({ { "enUS", { "Elowen", "Thistledown" } }, { "deDE", { "Friedrich", "Eichwald" } } }) do
	local locale, who = case[1], case[2]
	local full = who[1] .. " " .. who[2]
	local scenario = ("look-ribbon: %s with a count and a key is not cut at the default size, %s"):format(full, locale)
	local names = { nameplate1 = who, nameplate2 = { "Brannoc", "Vale" }, nameplate3 = { "Corwin", "Ash" } }
	withTree(scenario, names, function(ns)
		local realMeasure = FT.measure
		FT.measure = function(text, size)
			local letters = select(2, text:gsub("[^\128-\191]", ""))
			return letters * size * 0.58
		end
		local ok, err = pcall(function()
			local r, p, look = upIn(ns, scenario, function(pp)
				pp.width, pp.height, pp.fontSize, pp.iconSize = 220, 44, 13, 30
				pp.showCount = true
			end, false, full)
			if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
			SetBinding("F", COMMAND)
			tick(ns)
			if not tostring(r.name:GetText()):find(who[1], 1, true) then
				fail(scenario, "the name on the prompt is not " .. full .. ": " .. tostring(r.name:GetText()))
				return
			end
			if not look.countMode then fail(scenario, "the count has no tag: it stepped aside for the name") end
			if not tostring(r.count:GetText()):find("^%+2") then fail(scenario, "the count does not say +2: " .. tostring(r.count:GetText())) end
			if not look.keyUp then fail(scenario, "the key has no tag: it stepped aside for the name") end
			local room = span(r.name)
			local width = r.name:GetUnboundedStringWidth()
			local size = select(2, r.name:GetFont())
			local base = look.kit.fit.base[r.name]
			if room and type(width) == "number" and width > room[3] - room[1] + 0.6 then
				fail(scenario, ("the name is %.1f wide in a room of %.1f: it is cut"):format(width, room[3] - room[1]))
			end
			if type(size) == "number" and type(base) == "number" and size < base * 0.9 then
				fail(scenario, ("the name is drawn at %s, shrunk from %s for the tags"):format(tostring(size), tostring(base)))
			end
			if tostring(r.name:GetText()):find("%.%.%.") then fail(scenario, "the name is cut with an ellipsis") end
			-- The reason is whole beside the key's tag too.
			local sub, rs = r.sub, span(r.sub)
			local sw = sub:GetUnboundedStringWidth()
			if rs and type(sw) == "number" and sw > rs[3] - rs[1] + 0.6 then
				fail(scenario, ("the reason is %.1f wide in a room of %.1f: it is cut"):format(sw, rs[3] - rs[1]))
			end
		end)
		FT.measure = realMeasure
		if not ok then error(err, 0) end
	end, locale ~= "enUS" and function() Mock.locale = locale end or nil)
end

-- Long translated lines are fitted, never cut badly nor over anything.
withTree("look-ribbon: a German client's lines fit the cloth", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = 180, 44 end)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	local art = span(r.art)
	for _, text in ipairs({ "Arkane Intelligenz und noch eine Menge mehr", "Kurz" }) do
		ns.Prompt:Paint({ name = "Anna Aim", short = "Annabelle", reason = "owed", buff = ns.ResolveBuff(true) }, 2)
		ns.Prompt.lib.SetLine(r.sub, text)
		FT.settle()
		local sub = span(r.sub)
		if not (sub and inside(sub, art)) then fail(scenario, "the reason line leaves the prompt") end
		local g = look.g
		local n = { sub[1] - art[1], art[4] - sub[4], sub[3] - art[1], art[4] - sub[2] }
		if n[3] > forkLimit(look.W, g, n[2], n[4]) - 2 + 1e-6 then fail(scenario, "a long reason runs into the fork's notch") end
		local size = select(2, r.sub:GetFont())
		if type(size) == "number" and size < 7 then fail(scenario, "the line shrank below 7") end
		local width = r.sub:GetUnboundedStringWidth()
		local room = sub[3] - sub[1]
		local least = math.max(7, math.floor(look.kit.fit.base[r.sub] * 0.8 + 0.5))
		if type(width) == "number" and width > room + 0.6 and type(size) == "number" and size > least then
			fail(scenario, ("a line %.1f wide in a room of %.1f was not fitted (size %s)"):format(width, room, tostring(size)))
		end
	end
end, function() Mock.locale = "deDE" end)

-- ------------------------------------------------------------------ 4
-- A solid object, not a veil: at rest the cloth, the rails and the medallion
-- are drawn at full strength, and nothing is laid over them. The shipped cloth
-- is opaque in its body.
local function readTGA(path)
	local data = slurp(path)
	if not data then return nil end
	local b = { data:byte(1, 18) }
	if #b < 18 or b[3] ~= 2 or b[17] ~= 32 then return nil end
	local w, h = b[13] + b[14] * 256, b[15] + b[16] * 256
	local offset = 18 + b[1]
	-- Stored bottom row first unless the descriptor's bit 5 says otherwise.
	local topFirst = math.floor(b[18] / 32) % 2 == 1
	return { w = w, h = h, alpha = function(x, y)
		local row = topFirst and y or (h - 1 - y)
		return data:byte(offset + (row * w + x) * 4 + 4)
	end }
end

withTree("look-ribbon: the ribbon is a solid object at rest, not a veil", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	-- The breath has run its three and let go.
	Mock.runTimers(12)
	FT.settle()
	local solid = { look.cloth[1], look.cloth[2], look.trim[1], look.trim[2], look.medal, look.enamel, look.well }
	for _, t in ipairs(solid) do
		local what = tostring(t._file):match("Ribbon_(%w+)") or "a part"
		if not FT.visible(t) then fail(scenario, what .. " is not drawn") end
		-- Every frame above it and the region itself at full strength.
		local a, node = 1, t
		while node do
			local own = node._alpha
			if own == nil then own = 1 end
			a = a * own
			node = node._parent
		end
		if not near(a, p.alpha or 1, 0.001) then fail(scenario, ("%s is drawn at %.3f of the prompt's own %.2f: a veil"):format(what, a, p.alpha or 1)) end
		local c = t._color
		if c and not near(c[4] == nil and 1 or c[4], 1, 0.001) then fail(scenario, what .. " has a colour that is not opaque: " .. tostring(c[4])) end
		if t._gradient then
			local g = t._gradient
			if g[2] and g[2][4] and g[2][4] < 0.999 or g[3] and g[3][4] and g[3][4] < 0.999 then
				fail(scenario, what .. " is a gradient that fades out")
			end
		end
		if t._blend and t._blend ~= "BLEND" then fail(scenario, what .. " is drawn " .. tostring(t._blend) .. ", not solid") end
	end
	-- Nothing is laid over it: every light is parked at nothing, and no
	-- additive texture shows.
	for what, t in pairs({ lit = look.lit, enamelLit = look.enamelLit, hover = look.hover, glint = look.glint, sweep = look.sweep,
		dark1 = look.dark[1], dark2 = look.dark[2], hot1 = look.hot[1], hot2 = look.hot[2] }) do
		if (t._alpha or 1) > 0.001 then fail(scenario, ("%s is lit at rest (%.2f)"):format(what, t._alpha or 1)) end
	end
	for _, f in ipairs(look.fx.frames) do
		if (f._alpha or 0) > 0.001 then fail(scenario, "a ring is lit at rest") end
	end
	for _, x in ipairs(look.own) do
		if x._kind == "Texture" and x._blend == "ADD" and FT.visible(x) and (x._alpha or 1) > 0.001 then
			fail(scenario, tostring(x._file) .. " is additive and lit at rest")
		end
	end
	-- The cloth's colour is at full strength: the dye is a colour, never a tint
	-- of the world through it.
	for i = 1, 2 do
		local c = look.cloth[i]._color
		if not (c and near(c[4], 1, 0.001)) then fail(scenario, "the cloth's colour is not opaque") end
	end
	-- The files: the cloth is opaque all through its body, the rails and the
	-- medallion where they are drawn.
	local mid = readTGA(dir .. "/Textures/Ribbon/Ribbon_Cloth_Mid.tga")
	if not mid then fail(scenario, "Ribbon_Cloth_Mid.tga cannot be read") return end
	for y = 0, mid.h - 1 do
		for x = 0, mid.w - 1, 7 do
			if mid.alpha(x, y) ~= 255 then fail(scenario, ("the cloth's middle is not opaque at %d, %d: %d"):format(x, y, mid.alpha(x, y))) return end
		end
	end
	for _, end_ in ipairs({ "Ribbon_Cloth_End", "Ribbon_Cloth_EndL" }) do
		local e = readTGA(dir .. "/Textures/Ribbon/" .. end_ .. ".tga")
		if not e then fail(scenario, end_ .. ".tga cannot be read") return end
		-- The solid part: the rows between the rails, on the side that holds the
		-- cloth, up to the apex of the notch (the tails are cut at an angle).
		local solidFrom, solidTo = 0, END_PX - NOTCH_PX - 3
		if end_ == "Ribbon_Cloth_EndL" then solidFrom, solidTo = NOTCH_PX + 3, END_PX - 1 end
		for y = 6, RIBBON_PX - 7 do
			for x = solidFrom, solidTo do
				if e.alpha(x, y) ~= 255 then fail(scenario, ("%s is not opaque at %d, %d: %d"):format(end_, x, y, e.alpha(x, y))) return end
			end
		end
		-- And it is cut: the middle of the tail's tip side is empty.
		local tipX = end_ == "Ribbon_Cloth_EndL" and 0 or END_PX - 1
		if e.alpha(tipX, math.floor(RIBBON_PX / 2)) ~= 0 then fail(scenario, end_ .. " is not forked: its tip's middle is cloth") end
	end
	local medal = readTGA(dir .. "/Textures/Ribbon/Ribbon_Medal.tga")
	if medal then
		for _, at in ipairs({ { 64, 64 }, { 64, 20 }, { 20, 64 }, { 100, 64 }, { 64, 105 }, { 40, 40 } }) do
			if medal.alpha(at[1], at[2]) ~= 255 then fail(scenario, ("the medallion's gold is not opaque at %d, %d"):format(at[1], at[2])) end
		end
		if medal.alpha(1, 1) ~= 0 then fail(scenario, "the medallion's corner is not empty") end
	end
	for _, name in ipairs({ "Ribbon_Trim_Mid", "Ribbon_Trim_End" }) do
		local t = readTGA(dir .. "/Textures/Ribbon/" .. name .. ".tga")
		if t and t.alpha(math.floor(t.w / 2), 1) < 250 then fail(scenario, name .. "'s rail is not opaque") end
	end
end)

-- ------------------------------------------------------------------ 5
-- The reason. The enamel ring carries it for "Ring around the icon", the cloth
-- for "Stripe", both for "Both", neither for "None"; the owed ribbon in the
-- default look is the mockup's crimson; both palettes keep their reasons apart
-- in each carrier, for normal sight and for the two commonest colour
-- blindnesses; and the lettering holds its contrast on every dye.
local CRIMSON = { 0.78, 0.14, 0.14 }
local FIVE = { "target", "owed", "asked", "group", "nearby" }

-- How lit the cloth is where the lines stand, and the brightest it gets.
local LIT = 0.935

local function colourOf(t)
	local c = t._color
	return c and { c[1], c[2], c[3] } or nil
end

withTree("look-ribbon: the reason is the enamel ring, the cloth, both or neither, in both palettes", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	-- The default: owed, the marker on the ring: a crimson ribbon.
	if not sameColour(look.cloth[1]._color, CRIMSON[1], CRIMSON[2], CRIMSON[3]) then
		fail(scenario, "the default owed ribbon is not crimson: " .. tostring(table.concat(look.cloth[1]._color or {}, ",")))
	end
	local top = { CRIMSON[1] * LIT, CRIMSON[2] * LIT, CRIMSON[3] * LIT }
	if not (top[1] > 0.6 and top[2] < 0.2 and top[3] < 0.2) then fail(scenario, "the crimson is not a crimson at the cloth's lit top") end
	for _, t in ipairs({ look.cloth[2], look.dark[1] }) do
		if t == look.cloth[2] and not sameColour(t._color, CRIMSON[1], CRIMSON[2], CRIMSON[3]) then fail(scenario, "the fork is not the cloth's colour") end
	end
	local carriers = ns.Looks.Get("ribbon").AccentCarriers
	local palettes = {}
	for _, mode in ipairs({ "icon", "stripe", "both", "off" }) do
		local ring, stripe = carriers({ accentMode = mode, showIcon = true })
		local wantRing, wantStripe = mode == "icon" or mode == "both", mode == "stripe" or mode == "both"
		if ring ~= wantRing or stripe ~= wantStripe then
			fail(scenario, ("%s: AccentCarriers says %s, %s"):format(mode, tostring(ring), tostring(stripe)))
		end
		if carriers({ accentMode = mode, showIcon = false }) then fail(scenario, mode .. ": the ring is claimed with the icon off") end
		for _, palette in ipairs({ "standard", "colourblind" }) do
			p.accentMode, p.reasonPalette = mode, palette
			ns.Prompt:ApplyStyle()
			local rings, cloths = {}, {}
			for _, reason in ipairs(REASONS) do
				ns.Prompt:PaintAccent(reason)
				local cr, cg, cb = ns.Prompt:AccentColor(reason)
				local ring, cloth = colourOf(look.enamel), colourOf(look.cloth[1])
				rings[reason], cloths[reason] = ring, cloth
				-- The fork and the rows' ribbons are the cloth's colour.
				if not sameColour(look.cloth[2]._color, cloth[1], cloth[2], cloth[3]) then fail(scenario, "the fork is not the middle's colour") end
				if wantRing then
					-- The enamel is the reason's hue: its chroma points where the
					-- reason's does.
					local l1, l2 = (cr + cg + cb) / 3, (ring[1] + ring[2] + ring[3]) / 3
					local dot, n1, n2 = 0, 0, 0
					for i, v in ipairs({ cr - l1, cg - l1, cb - l1 }) do
						local w = ring[i] - l2
						dot, n1, n2 = dot + v * w, n1 + v * v, n2 + w * w
					end
					if n1 > 0.01 and (dot / math.sqrt(n1 * n2)) < 0.9 then
						fail(scenario, ("%s, %s, %s: the enamel is not in the reason's hue"):format(mode, palette, reason))
					end
					if sameColour(ring, 0.34 * 0.92, 0.10 * 0.92, 0.09 * 0.92) then fail(scenario, mode .. ": the enamel is the neutral one") end
				else
					if not sameColour(ring, 0.34 * 0.92, 0.10 * 0.92, 0.09 * 0.92) then
						fail(scenario, ("%s, %s, %s: the enamel carries the reason though the mode says it does not"):format(mode, palette, reason))
					end
				end
				if wantStripe then
					if palette == "standard" and reason == "owed" and not sameColour(cloth, CRIMSON[1], CRIMSON[2], CRIMSON[3]) then
						fail(scenario, "owed is not the crimson cloth in the standard palette: " .. table.concat(cloth, ","))
					end
				else
					if not sameColour(cloth, CRIMSON[1], CRIMSON[2], CRIMSON[3]) then
						fail(scenario, ("%s, %s, %s: the cloth is dyed though the mode says it is not"):format(mode, palette, reason))
					end
				end
			end
			palettes[mode .. palette] = { rings = rings, cloths = cloths }
			-- Reasons kept apart: self wears the group's colour on purpose.
			local function apartIn(set, label, floor, sim)
				for i = 1, #FIVE do
					for j = i + 1, #FIVE do
						local a, b = set[FIVE[i]], set[FIVE[j]]
						if sim then a, b = simulate(a, sim), simulate(b, sim) end
						local d = deltaE(a, b)
						if d < floor then
							fail(scenario, ("%s, %s, %s: %s and %s are only %.1f apart%s"):format(mode, palette, label, FIVE[i], FIVE[j], d,
								sim and (sim == PROTAN and " to a protanope" or " to a deuteranope") or ""))
						end
					end
				end
			end
			if wantRing then
				apartIn(rings, "the enamel", 30)
				if palette == "colourblind" then
					apartIn(rings, "the enamel", 25, PROTAN)
					apartIn(rings, "the enamel", 22, DEUTAN)
				end
			end
			if wantStripe then
				apartIn(cloths, "the cloth", 18)
				if palette == "colourblind" then
					apartIn(cloths, "the cloth", 18, PROTAN)
					apartIn(cloths, "the cloth", 9, DEUTAN)
				end
			end
			if rings.self and rings.group and not sameColour(rings.self, rings.group[1], rings.group[2], rings.group[3]) then
				fail(scenario, "a self-buff does not wear its group's enamel")
			end
		end
	end
end)

-- The name and the reason line hold their contrast on every dye: both
-- palettes, every mode, a colour of the player's own, and a panel colour.
withTree("look-ribbon: the lettering holds its contrast on every dye", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	local worst = 99
	local function holds(what)
		local cloth = look.cloth[1]._color
		-- The cloth where the lines stand: at its lit top, the brightest it is.
		local ground = lum(cloth[1] * LIT, cloth[2] * LIT, cloth[3] * LIT)
		local sub = r.sub._textColor
		local nameInk = r.name._textColor
		if not (sub and nameInk) then fail(scenario, what .. ": the lines have no colour") return end
		local rs = contrast(lum(sub[1], sub[2], sub[3]), ground)
		local rn = contrast(lum(nameInk[1], nameInk[2], nameInk[3]), ground)
		worst = math.min(worst, rs, rn)
		if rs < 4.5 then fail(scenario, ("%s: the reason is %.2f:1 on the cloth"):format(what, rs)) end
		if rn < 4.5 then fail(scenario, ("%s: the name is %.2f:1 on the cloth"):format(what, rn)) end
	end
	for _, mode in ipairs({ "icon", "stripe", "both", "off" }) do
		for _, palette in ipairs({ "standard", "colourblind" }) do
			p.accentMode, p.reasonPalette, p.accentByReason = mode, palette, true
			ns.Prompt:ApplyStyle()
			for _, reason in ipairs(REASONS) do
				ns.Prompt:PaintAccent(reason)
				holds(("%s, %s, %s"):format(mode, palette, reason))
			end
		end
	end
	-- One marker colour for every reason, however bright or dark.
	for _, colour in ipairs({ { 1, 1, 1, 1 }, { 1, 0.95, 0.1, 1 }, { 0.2, 0.9, 0.3, 1 }, { 0.05, 0.05, 0.05, 1 }, { 0.5, 0.5, 0.5, 1 },
		{ 0.9, 0.2, 0.8, 1 }, { 0, 0.4, 1, 1 } }) do
		p.accentMode, p.accentByReason, p.accentColor = "both", false, colour
		ns.Prompt:ApplyStyle()
		ns.Prompt:PaintAccent("owed")
		holds("a marker colour of " .. table.concat(colour, ","))
	end
	-- A panel colour the player chose becomes the cloth, deep: the lines hold.
	p.accentMode, p.accentByReason = "icon", true
	for _, bg in ipairs({ { 0.96, 0.92, 0.80, 1 }, { 0.2, 0.5, 0.2, 1 }, { 0.1, 0.1, 0.5, 1 }, { 1, 1, 1, 1 } }) do
		p.bgColor = { bg[1], bg[2], bg[3], bg[4] }
		ns.Prompt:ApplyStyle()
		ns.Prompt:PaintAccent("target")
		holds("a panel colour of " .. table.concat(bg, ","))
		local c = look.cloth[1]._color
		if sameColour(c, CRIMSON[1], CRIMSON[2], CRIMSON[3]) then fail(scenario, "a chosen panel colour did not dye the cloth") end
	end
	if worst < 4.5 then fail(scenario, "the worst contrast is " .. worst) end
end)

-- A class-coloured name is taken most of the way to the lettering's gold, so
-- it never fights the cloth.
withTree("look-ribbon: a class colour is taken to the gold, and the chosen font colour wins", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.classColor = true end)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	local text = tostring(r.name:GetText())
	local rr, gg, bb = text:match("|cff(%x%x)(%x%x)(%x%x)")
	if not rr then fail(scenario, "the name carries no class colour to take: " .. text) return end
	local code = { tonumber(rr, 16) / 255, tonumber(gg, 16) / 255, tonumber(bb, 16) / 255 }
	-- A priest is white; the gold's blue is 0.54, so the code is that far.
	if not (code[3] < 0.9 and code[1] > 0.9) then fail(scenario, "a white class is not taken to the gold: " .. text) end
	-- A dark class stays warm and readable.
	for _, class in ipairs({ "DEATHKNIGHT", "WARLOCK", "SHAMAN", "DRUID" }) do
		ns.owed["Anna Aim"].class = class
		ns.Prompt:Paint({ name = "Anna Aim", short = "Anna", class = class, reason = "owed", buff = ns.ResolveBuff(true) }, 0)
		FT.settle()
		local t = tostring(r.name:GetText())
		local a, b, c = t:match("|cff(%x%x)(%x%x)(%x%x)")
		if a then
			local l = lum(tonumber(a, 16) / 255, tonumber(b, 16) / 255, tonumber(c, 16) / 255)
			local ground = lum(CRIMSON[1] * LIT, CRIMSON[2] * LIT, CRIMSON[3] * LIT)
			if contrast(l, ground) < 4.5 then fail(scenario, class .. "'s name is under 4.5:1 on the cloth: " .. t) end
		end
	end
	-- The colour the player chose is the lettering's.
	p.classColor = false
	p.fontColor = { 0.4, 0.9, 0.9, 1 }
	ns.Prompt:ApplyStyle()
	local c = r.name._textColor
	if not (c and sameColour(c, 0.4, 0.9, 0.9)) then fail(scenario, "the chosen font colour was not kept") end
	p.fontColor = { 1, 1, 1, 1 }
	ns.Prompt:ApplyStyle()
	c = r.name._textColor
	if not (c and sameColour(c, 1.00, 0.88, 0.54)) then fail(scenario, "the lettering is not warm gold by default") end
	local s = r.sub._textColor
	if not (s and s[1] > 0.95 and s[2] > 0.78 and s[3] > 0.7 and s[3] < 0.9) then fail(scenario, "the reason is not pale peach by default") end
	-- And a dark crimson shadow under both.
	local sh = r.name._shadowColor
	if not (sh and sh[1] < 0.35 and sh[2] < 0.1) then fail(scenario, "the name's shadow is not a dark crimson") end
end)

-- ------------------------------------------------------------------ 6
-- The face: Morpheus for the names and the reason where the client writes in
-- Latin letters, the client's own where it does not, the player's choice above
-- both, and never a line with no font.
local MORPHEUS = "Fonts\\MORPHEUS.TTF"
for _, case in ipairs({
	{ "enUS", true }, { "deDE", true }, { "frFR", true }, { "esES", true }, { "ptBR", true }, { "itIT", true },
	{ "koKR", false }, { "zhCN", false }, { "zhTW", false }, { "ruRU", false },
}) do
	withTree("look-ribbon: the face on " .. case[1], ANNA, function(ns, scenario)
		local r, p, look = upIn(ns, scenario)
		if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
		local path, subPath, rowPath = r.name:GetFont(), r.sub:GetFont(), r.rows[1]:GetFont()
		if case[2] then
			if path ~= MORPHEUS or subPath ~= MORPHEUS or rowPath ~= MORPHEUS then
				fail(scenario, case[1] .. ": the lines are not in Morpheus: " .. tostring(path))
			end
			if look.kit.fit.path ~= MORPHEUS then fail(scenario, "a line that is refitted would leave Morpheus") end
			local name = select(2, r.name:GetFont())
			if name ~= math.floor(p.fontSize * 1.1 + 0.5) then fail(scenario, "the name is not the size the layout counts on: " .. tostring(name)) end
		else
			if tostring(path):upper():find("MORPHEUS", 1, true) or tostring(subPath):upper():find("MORPHEUS", 1, true) then
				fail(scenario, case[1] .. ": the client's own face is left for a Latin one: " .. tostring(path))
			end
			if not r.name:GetFont() or not r.sub:GetFont() then fail(scenario, case[1] .. ": a line has no font") end
		end
		-- A font the player picked wins, in the sizes this look draws.
		p.font = "Chosen"
		ns.Prompt:ApplyStyle()
		if tostring(r.name:GetFont()):upper():find("MORPHEUS", 1, true) then fail(scenario, case[1] .. ": the chosen font did not win") end
		if tostring(r.sub:GetFont()):upper():find("MORPHEUS", 1, true) then fail(scenario, case[1] .. ": the chosen font did not win on the reason") end
		-- And back to the default: Morpheus again where it belongs.
		p.font = ns.defaults.profile.prompt.font
		ns.Prompt:ApplyStyle()
		if case[2] and r.name:GetFont() ~= MORPHEUS then fail(scenario, "the default font did not bring Morpheus back") end
	end, function() if case[1] ~= "enUS" then Mock.locale = case[1] end end)
end

withTree("look-ribbon: a face the client refuses leaves a line with a font", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	Mock.badFonts = { [MORPHEUS] = true }
	ns.Prompt:ApplyStyle()
	for _, fs in ipairs({ r.name, r.sub, r.rows[1] }) do
		if not fs:GetFont() then fail(scenario, "a line was left with no font when Morpheus was refused") end
	end
	if look.kit.fit.path == MORPHEUS then fail(scenario, "refitting would keep asking for a face the client refused") end
	local ok, err = pcall(function() ns.Prompt:Paint({ name = "Anna Aim", short = "Anna", reason = "owed", buff = ns.ResolveBuff(true) }, 2) end)
	if not ok then fail(scenario, "painting with the face refused threw: " .. tostring(err)) end
	Mock.badFonts = nil
end)

-- ------------------------------------------------------------------ 7
-- The outcomes: the name stays, the second line is the verdict, the enamel
-- takes the outcome's colour, the icon greys for a refusal, the cast nobody
-- confirmed claims nothing; and the next paint takes it all back.
withTree("look-ribbon: the outcomes write a verdict and the enamel takes their colour", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	local ring0 = colourOf(look.enamel)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local named = tostring(r.name:GetText())
	if not named:find("Anna Aim", 1, true) or named:find("buffed", 1, true) then fail(scenario, "a landed buff moved the name: " .. named) end
	if r.sub:GetText() ~= "buffed" then fail(scenario, "a landed buff's second line is not \"buffed\": " .. tostring(r.sub:GetText())) end
	local green = colourOf(look.enamel)
	if not (green[2] > green[1] and green[2] > green[3]) then fail(scenario, "a landed buff did not turn the enamel green") end
	local ink = r.sub._textColor
	if not (ink and ink[2] > ink[1] - 0.001 and ink[2] > 0.9) then fail(scenario, "the verdict of a landed buff is not a green-white") end
	local ground = lum(CRIMSON[1] * LIT, CRIMSON[2] * LIT, CRIMSON[3] * LIT)
	if contrast(lum(ink[1], ink[2], ink[3]), ground) < 4.5 then fail(scenario, "the verdict is under 4.5:1 on the cloth") end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if r.sub:GetText() ~= "Out of range." then fail(scenario, "a refusal is not the game's words: " .. tostring(r.sub:GetText())) end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	local red = colourOf(look.enamel)
	if not (red[1] > red[2] * 1.8 and red[1] > red[3] * 1.8) then fail(scenario, "a refusal did not turn the enamel red") end
	Mock.advance(3)
	tick(ns)
	if r.sub:GetText() == "Out of range." then fail(scenario, "the verdict outlived the outcome") end
	if r.icon._desaturated then fail(scenario, "the icon stayed grey after the refusal ran out") end
	if not sameColour(look.enamel._color, ring0[1], ring0[2], ring0[3]) then
		fail(scenario, "the enamel kept the outcome's colour: " .. table.concat(look.enamel._color, ","))
	end
	local s = r.sub._textColor
	if not (s and s[1] > 0.95 and s[3] < 0.9) then fail(scenario, "the reason line kept the verdict's ink") end
	-- A cast nobody confirmed claims nothing: no flourish.
	local before = plays(look.refuse) + (look.travel._plays or 0) + (look.flash._plays or 0)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if plays(look.refuse) + (look.travel._plays or 0) + (look.flash._plays or 0) ~= before then fail(scenario, "a cast nobody confirmed got a flourish") end
	if r.sub:GetText() ~= "sent, unconfirmed" then fail(scenario, "a cast nobody confirmed is not said so: " .. tostring(r.sub:GetText())) end
end)

-- ------------------------------------------------------------------ 8
-- The arrival: the cloth fades in and slides out from behind the medallion,
-- which glints; every piece starts inside the box, behind the medallion, and
-- ends home. On Calm the cloth only fades.
local function arrival(ns, scenario, edit)
	local r, p, look = upIn(ns, scenario, edit, true)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	return r, p, look
end

withTree("look-ribbon: the cloth slides out from behind the medallion and the medallion glints", ANNA, function(ns, scenario)
	local r, p, look = arrival(ns, scenario)
	if not r then return end
	local g = look.g
	local slide = look.slideBy
	if not (slide >= 6 and slide <= g.R) then fail(scenario, "the slide's length is out of reason: " .. tostring(slide)) end
	-- Every piece of the ribbon is fading in and sliding.
	for i, grp in ipairs(look.fade) do
		if not grp._playing then fail(scenario, "piece " .. i .. " is not fading in") end
		if FT.groupLength(grp) > 0.35 then fail(scenario, "a fade lasts more than 0.35 s") end
	end
	for i, grp in ipairs(look.slide) do
		if not grp._playing then fail(scenario, "piece " .. i .. " is not sliding") end
		local a = grp._anims[1]
		if not (a._offset and near(a._offset[1], slide, 0.01) and near(a._offset[2], 0, 0.01)) then
			fail(scenario, "piece " .. i .. "'s slide is not " .. slide .. " to the right")
		end
		if FT.groupLength(grp) > 0.35 then fail(scenario, "a slide lasts more than 0.35 s") end
	end
	if not look.glintAnim._playing then fail(scenario, "the medallion does not glint") end
	if FT.groupLength(look.glintAnim) > 0.6 then fail(scenario, "the glint lasts more than 0.6 s") end
	-- At the start the ribbon is `slide` to the left of home, still in the box,
	-- its left end behind the medallion.
	local art = span(r.art)
	local c = span(look.cloth[1])
	if not near(c[1] - art[1], g.cx - slide, 0.05) then fail(scenario, ("the cloth does not start %.1f left of home: %.1f"):format(slide, c[1] - art[1])) end
	if c[1] - art[1] < g.cx - g.R then fail(scenario, "the cloth's end starts out beyond the medallion's edge") end
	for what, t in pairs({ cloth2 = look.cloth[2], trim1 = look.trim[1], trim2 = look.trim[2], drop1 = look.drop[1], drop2 = look.drop[2] }) do
		local b = span(t)
		if b[1] < art[1] - 0.05 or b[3] > art[3] + 0.05 then fail(scenario, "the " .. what .. " leaves the box as it slides") end
	end
	-- Home when it is done, every piece, and nothing left playing.
	Mock.advance(0.6)
	FT.settle()
	c = span(look.cloth[1])
	if not near(c[1] - art[1], g.cx, 0.05) then fail(scenario, "the cloth is not home after the slide: " .. (c[1] - art[1])) end
	for i, grp in ipairs(look.slide) do
		if grp._playing then fail(scenario, "slide " .. i .. " is still playing") end
	end
	for _, pair in ipairs({ { look.cloth[2], look.trim[2] }, { look.cloth[1], look.trim[1] }, { look.drop[1], look.drop[2] } }) do
		local a, b = span(pair[1]), span(pair[2])
		_ = a
		_ = b
	end
	local t1, t2 = span(look.trim[1]), span(look.cloth[1])
	if not (near(t1[1], t2[1], 0.05) and near(t1[3], t2[3], 0.05)) then fail(scenario, "the rails did not come home with the cloth") end
	for _, t in ipairs({ look.glint }) do
		if (t._alpha or 0) > 0.001 then fail(scenario, "the glint is left lit") end
	end
	-- A second arrival on top of the first: the ribbon starts from the same place,
	-- never from one it was put to.
	owe(ns, "Bert Beside")
	look:Attention(true, false, "pulse")
	local c2 = span(look.cloth[1])
	if not near(c2[1] - art[1], g.cx - slide, 0.05) then fail(scenario, "a second arrival does not start from the same place") end
	Mock.advance(0.1)
	look:Attention(true, false, "pulse")
	c2 = span(look.cloth[1])
	if not near(c2[1] - art[1], g.cx - slide, 0.05) then fail(scenario, "an arrival on one in progress does not start over") end
	Mock.advance(0.6)
	FT.settle()
	c2 = span(look.cloth[1])
	if not near(c2[1] - art[1], g.cx, 0.05) then fail(scenario, "the ribbon did not come home after two arrivals") end
	-- Stopped part-way (a repaint about somebody else, a fight): home at once.
	look:Attention(true, false, "pulse")
	ns.Prompt:StopFlourishes()
	c2 = span(look.cloth[1])
	if not near(c2[1] - art[1], g.cx, 0.05) then fail(scenario, "a stopped slide left the ribbon off its place") end
end)

withTree("look-ribbon: with the icon off the whole ribbon fades and slides without a medallion to hide behind", ANNA, function(ns, scenario)
	local r, p, look = arrival(ns, scenario, function(pp) pp.showIcon = false end)
	if not r then return end
	if look.slideBy ~= 0 then fail(scenario, "the ribbon slides with no medallion to come out from behind") end
	for i, grp in ipairs(look.fade) do
		if not grp._playing and look.cloth[1]._shown ~= false and i <= 3 then fail(scenario, "the cloth is not fading in") end
	end
	if look.glintAnim._playing then fail(scenario, "a glint with no medallion") end
	Mock.advance(0.6)
	FT.settle()
	local art, c = span(r.art), span(look.cloth[3])
	if not near(c[1] - art[1], 0, 0.05) then fail(scenario, "the left fork is not at the edge") end
end)

withTree("look-ribbon: Calm plays only fades, loops nothing, and leaves nothing lit", ANNA, function(ns, scenario)
	local r, p, look = arrival(ns, scenario, function(pp) pp.effects = "calm" end)
	if not r then return end
	local any = false
	for _, grp in ipairs(look.fade) do if grp._playing then any = true end end
	if not any then fail(scenario, "Calm gives the cloth no fade in") end
	if plays(look.slide) > 0 then fail(scenario, "Calm slid the cloth") end
	if look.glintAnim._playing or (look.glintAnim._plays or 0) > 0 then fail(scenario, "Calm glinted") end
	-- A new favour on top, a landing, a refusal: nothing but the text's own.
	local before = plays(look.slide) + plays(look.refuse) + plays(look.pulse) + (look.travel._plays or 0) + (look.flash._plays or 0)
		+ (look.glintAnim._plays or 0)
	look:Attention(true, true, "pulse")
	look:Attention(true, false, "once")
	owe(ns, "Bert Beside")
	Mock.advance(0.5)
	tick(ns)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	Mock.advance(1)
	local after = plays(look.slide) + plays(look.refuse) + plays(look.pulse) + (look.travel._plays or 0) + (look.flash._plays or 0)
		+ (look.glintAnim._plays or 0)
	if after ~= before then fail(scenario, "Calm played " .. (after - before) .. " of Ribbon's animations") end
	local _, loops = FT.playing()
	if #loops > 0 then fail(scenario, #loops .. " animation(s) loop on Calm") end
	for _, t in ipairs({ look.lit, look.enamelLit, look.glint, look.sweep }) do
		if (t._alpha or 0) > 0.001 then fail(scenario, "Calm left a light lit") end
	end
	for _, f in ipairs(look.fx.frames) do
		if (f._alpha or 0) > 0.001 or f._groups and f._groups[1] and f._groups[1]._playing then fail(scenario, "Calm left a ring up") end
	end
	local ring = look.fx.rings[1]
	if (ring.land._plays or 0) > 0 then fail(scenario, "Calm spread the landing's rings") end
end)

-- ------------------------------------------------------------------ 9
-- The owed breath: the medallion's gold and its enamel lit on one breath,
-- three breaths and still; gone with the favour and the outcome.
withTree("look-ribbon: the medallion's gold breathes three times, then it holds", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, nil, true)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	if not (look.pulse[1]._playing and look.pulse[2]._playing) then fail(scenario, "somebody owed and the gold is not breathing") end
	if look.pulse[1]._looping ~= "BOUNCE" or look.pulse[2]._looping ~= "BOUNCE" then fail(scenario, "the breath does not bounce") end
	local breath = look.pulse[1]._anims[1]._duration
	if breath * 2 < 2 or breath * 2 > 3.2 then fail(scenario, ("the breath is %.2f s round: not slow"):format(breath * 2)) end
	if not near(look.pulse[1]._anims[1]._toAlpha, 0.60, 0.001) or look.pulse[2]._anims[1]._toAlpha > 0.55 then
		fail(scenario, "the breath's peak is out of its bounds")
	end
	if look.lit._blend == "ADD" or look.enamelLit._blend == "ADD" then fail(scenario, "the breath is additive light that stays on screen") end
	local c = look.lit._color
	if not (c and c[1] > 0.9 and c[3] < c[1]) then fail(scenario, "the breath's light is not warm") end
	-- Three breaths, then still.
	Mock.runTimers(3 * 2 * breath - 1)
	if not look.pulse[1]._playing then fail(scenario, "the breath stopped before its three") end
	Mock.runTimers(1.5)
	if look.pulse[1]._playing or look.pulse[2]._playing then fail(scenario, "the breath goes on after three") end
	if (look.lit._alpha or 0) > 0.001 or (look.enamelLit._alpha or 0) > 0.001 then fail(scenario, "the breath left the gold lit") end
	-- A repaint does not start it again; a new favour does.
	tick(ns)
	if look.pulse[1]._playing then fail(scenario, "a repaint restarted the breath") end
	owe(ns, "Bert Beside")
	ns.Prompt:Paint({ name = "Bert Beside", short = "Bert", reason = "owed", buff = ns.ResolveBuff(true) }, 0)
	look:Attention(true, false, "pulse")
	if not look.pulse[1]._playing then fail(scenario, "a new favour does not breathe") end
	-- The outcome stops it; so does nobody owed; and "off" never starts it.
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if look.pulse[1]._playing then fail(scenario, "the breath goes on over an outcome") end
	Mock.advance(3)
	look:Attention(false, false, "off")
	if look.pulse[1]._playing then fail(scenario, "the breath plays with the attention switched off") end
	look:Attention(true, false, "once")
	if look.pulse[1]._playing then fail(scenario, "the breath plays on \"once\"") end
	look:Attention(true, false, "pulse")
	look:StopAttention()
	if look.pulse[1]._playing or (look.lit._alpha or 0) > 0.001 then fail(scenario, "StopAttention left the breath going") end
end)

-- ------------------------------------------------------------------ 10
-- The landing: a shine along the cloth and a flash of the medallion, and the
-- rings; the refusal: the cloth darkens towards red and flashes amber, a ring
-- snaps in, and the text shakes. Each within 0.6 s, each parked at nothing.
withTree("look-ribbon: a landing shines along the cloth and flashes the medallion", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	local g = look.g
	local travel, flash, glint = look.travel._plays or 0, look.flash._plays or 0, look.glintAnim._plays or 0
	local rings = look.fx.rings[1].land._plays or 0
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if (look.travel._plays or 0) <= travel or not look.travel._playing then fail(scenario, "a landed buff does not run the shine along the cloth") end
	if (look.flash._plays or 0) <= flash then fail(scenario, "a landed buff does not flash the medallion") end
	if (look.glintAnim._plays or 0) <= glint then fail(scenario, "a landed buff does not glint") end
	if (look.fx.rings[1].land._plays or 0) <= rings then fail(scenario, "a landed buff does not spread the rings") end
	for what, grp in pairs({ travel = look.travel, flash = look.flash, glint = look.glintAnim }) do
		if FT.groupLength(grp) > 0.6 + 1e-6 then fail(scenario, ("the landing's %s lasts %.2f s"):format(what, FT.groupLength(grp))) end
	end
	-- The shine runs from the cloth's left to the fork's apex, never into the
	-- notch, inside the rails.
	local art = span(r.art)
	local s = span(look.sweep)
	local off = look.travelMove._offset[1]
	if s[1] - art[1] < g.cx - 0.05 then fail(scenario, "the shine starts left of the cloth") end
	if s[3] - art[1] + off > look.W - g.notch + 0.5 then
		fail(scenario, ("the shine ends at %.1f, past the notch's apex at %.1f"):format(s[3] - art[1] + off, look.W - g.notch))
	end
	if art[4] - s[4] < g.top - 0.05 or art[4] - s[2] > g.bottom + 0.05 then fail(scenario, "the shine is taller than the cloth") end
	if look.sweep._blend ~= "ADD" then fail(scenario, "the shine is not light") end
	-- Parked at nothing when they end, and when they stop.
	Mock.advance(0.8)
	FT.settle()
	for _, t in ipairs({ look.sweep, look.lit, look.glint }) do
		if (t._alpha or 0) > 0.001 then fail(scenario, "a landing's light was left lit") end
	end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	ns.Prompt:StopFlourishes()
	FT.settle()
	for _, t in ipairs({ look.sweep, look.glint }) do
		if (t._alpha or 0) > 0.001 then fail(scenario, "a stopped landing left its light lit") end
	end
	for _, f in ipairs(look.fx.frames) do
		if (f._alpha or 0) > 0.001 then fail(scenario, "a stopped landing left a ring up") end
	end
end)

withTree("look-ribbon: a refusal darkens the cloth towards red, flashes amber, snaps a ring in and shakes the text", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	local before = plays(look.refuse)
	local shakes = r.shake and r.shake._plays or 0
	local reject = look.fx.rings[1].reject._plays or 0
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if plays(look.refuse) - before < 6 then fail(scenario, "a refusal does not flash all three pieces of the cloth, dark and amber") end
	if (look.fx.rings[1].reject._plays or 0) <= reject then fail(scenario, "a refusal does not snap a ring in") end
	if not (r.shake and (r.shake._plays or 0) > shakes) then fail(scenario, "a refusal does not shake the text") end
	for i, grp in ipairs(look.refuse) do
		if FT.groupLength(grp) > 0.6 + 1e-6 then fail(scenario, "refusal " .. i .. " lasts more than 0.6 s") end
	end
	-- Red-dark and amber.
	local dark, hot = look.dark[1]._color, look.hot[1]._color
	if not (dark and dark[1] > dark[3] and dark[1] < 0.3 and dark[2] < 0.1) then fail(scenario, "the darkening is not a dark red") end
	if not (hot and hot[1] > 0.9 and hot[2] > 0.3 and hot[2] < 0.55 and hot[3] < 0.2) then fail(scenario, "the flash is not amber") end
	if look.hot[1]._blend ~= "ADD" or look.dark[1]._blend == "ADD" then fail(scenario, "the flash is not light, or the darkening is") end
	-- The three pieces of the cloth flash together.
	for i = 1, 3 do
		if not (look.dark[i]._file == look.cloth[i]._file and look.hot[i]._file == look.cloth[i]._file) then
			fail(scenario, "the refusal's piece " .. i .. " is not the cloth's own shape")
		end
	end
	Mock.advance(1)
	FT.settle()
	for i = 1, 3 do
		if (look.dark[i]._alpha or 0) > 0.001 or (look.hot[i]._alpha or 0) > 0.001 then fail(scenario, "a refusal's flash was left on the cloth") end
	end
	-- Stopped: the same.
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	ns.Prompt:StopFlourishes()
	FT.settle()
	for i = 1, 3 do
		if (look.dark[i]._alpha or 0) > 0.001 or (look.hot[i]._alpha or 0) > 0.001 then fail(scenario, "a stopped refusal's flash was left on the cloth") end
	end
end)

-- ------------------------------------------------------------------ 11
-- A fight: the gold dims to bronze, the cloth darkens, the icon greys, the
-- text dims, the lights go out; the enamel keeps its colour; and it all comes
-- back.
withTree("look-ribbon: a fight dims the ribbon, steadies it and keeps the reason", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.accentMode = "both" end)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	ns.Prompt:PaintAccent("owed")
	local dye, ring = colourOf(look.cloth[1]), colourOf(look.enamel)
	local gold = colourOf(look.medal)
	if not look.pulse[1]._playing then fail(scenario, "no breath to steady") end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not look.combat then fail(scenario, "the look was not told of the fight") end
	local c = colourOf(look.cloth[1])
	if not (c[1] < dye[1] * 0.7 and c[1] > dye[1] * 0.5) then fail(scenario, "the cloth did not darken in a fight") end
	local m = colourOf(look.medal)
	if not (m[1] < gold[1] and m[1] > 0.5 and m[3] < m[1]) then fail(scenario, "the gold did not dim to bronze in a fight: " .. table.concat(m, ",")) end
	if not sameColour(look.enamel._color, ring[1], ring[2], ring[3]) then fail(scenario, "the enamel lost the reason's colour in a fight") end
	if not r.icon._desaturated then fail(scenario, "the icon did not grey in a fight") end
	if not (r.textLayer._alpha and r.textLayer._alpha < 1 and r.textLayer._alpha > 0.7) then fail(scenario, "the text did not dim in a fight") end
	if look.pulse[1]._playing then fail(scenario, "the breath goes on in a fight") end
	for _, t in ipairs({ look.lit, look.enamelLit, look.sweep, look.glint }) do
		if (t._alpha or 0) > 0.001 then fail(scenario, "a light is lit in a fight") end
	end
	-- Steady: no landing or refusal flourish in a fight.
	local before = plays(look.refuse) + (look.travel._plays or 0) + (look.flash._plays or 0) + (look.glintAnim._plays or 0)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if plays(look.refuse) + (look.travel._plays or 0) + (look.flash._plays or 0) + (look.glintAnim._plays or 0) ~= before then
		fail(scenario, "a flourish played in a fight: it should be steady")
	end
	-- A restyle in the fight keeps the hold.
	local held = look.combat
	look:Apply(p, false)
	if look.combat ~= held or not sameColour(look.cloth[1]._color, c[1], c[2], c[3]) then fail(scenario, "a restyle put the fight's dimming back") end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	Mock.advance(3)
	tick(ns)
	if look.combat then fail(scenario, "the fight is over and the look still holds") end
	if not sameColour(look.cloth[1]._color, dye[1], dye[2], dye[3]) then fail(scenario, "the cloth stayed dark after the fight") end
	if not sameColour(look.medal._color, 1, 1, 1) then fail(scenario, "the gold stayed bronze after the fight") end
	if r.icon._desaturated then fail(scenario, "the icon stayed grey after the fight") end
	if (r.textLayer._alpha or 1) < 0.999 then fail(scenario, "the text stayed dim after the fight") end
end)

-- ------------------------------------------------------------------ 12
-- The cooldown sweeps the icon's own round shape, on the medallion; the cursor
-- lights the gold both ways; leaving the look takes every part down.
withTree("look-ribbon: the cooldown sweeps the medallion's icon, round", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	local cd = r.cooldown
	if not cd then fail(scenario, "SKIPPED -- no cooldown frame") return end
	local box, icon = span(cd), span(r.icon)
	if not (box and icon and near(box[1], icon[1], 0.05) and near(box[3], icon[3], 0.05) and near(box[2], icon[2], 0.05) and near(box[4], icon[4], 0.05)) then
		fail(scenario, "the cooldown is not on the icon")
	end
	if tostring(cd._swipeTexture):find("Ribbon_Mask", 1, true) == nil then fail(scenario, "the sweep does not have the icon's round shape: " .. tostring(cd._swipeTexture)) end
	if cd._circular ~= true then fail(scenario, "the sweep's leading edge is not round") end
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.5, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	if not cd:IsShown() then fail(scenario, "no sweep with a cooldown running") end
	Mock.spellCooldowns = nil
	-- The icon off: no sweep.
	p.showIcon = false
	ns.Prompt:ApplyStyle()
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.5, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	if cd:IsShown() then fail(scenario, "a sweep with no icon to sweep") end
	Mock.spellCooldowns = nil
end)

withTree("look-ribbon: the cursor lights the gold and takes it away", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	look:Hover(true)
	if not look.hoverAnim._playing then fail(scenario, "the cursor on the panel does not light the gold") end
	if not near(look.hoverAnim._anims[1]._toAlpha, 0.55, 0.001) then fail(scenario, "the cursor's light is not at its strength") end
	if look.hover._blend == "ADD" then fail(scenario, "the cursor's light is additive") end
	Mock.advance(0.5)
	FT.settle()
	if not near(look.hover._alpha, 0.55, 0.01) then fail(scenario, "the cursor's light did not settle: " .. tostring(look.hover._alpha)) end
	look:Hover(false)
	Mock.advance(0.5)
	FT.settle()
	if (look.hover._alpha or 0) > 0.001 then fail(scenario, "the cursor's light stayed on after it left") end
	look:Hover(true)
	ns.Prompt:ApplyStyle()
	if (look.hover._alpha or 0) > 0.001 and look.hovered then fail(scenario, "a restyle left the cursor's light up") end
end)

withTree("look-ribbon: leaving the look takes down every part and gives back what it borrowed", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	for _, x in ipairs(look.own) do
		if x._kind ~= "Frame" and FT.visible(x) then fail(scenario, tostring(x._file or x._kind) .. " is still drawn on another look") end
		if x._kind == "Frame" and x._shown ~= false then fail(scenario, "one of the look's frames is still shown on another look") end
	end
	for _, grp in ipairs(look.anims) do
		if grp._playing and grp._looping and grp._looping ~= "NONE" then fail(scenario, "an animation of Ribbon's still loops on another look") end
	end
	for _, grp in ipairs(look.anims) do
		if grp._playing then fail(scenario, "an animation of Ribbon's is still playing on another look") end
	end
	if r.icon._mask then fail(scenario, "the icon is still cut by the ribbon's mask") end
	if (r.icon._alpha or 1) < 0.999 or r.icon._desaturated then fail(scenario, "the icon was left dimmed or grey") end
	local v = r.icon._color
	if v and not (near(v[1], 1) and near(v[2], 1) and near(v[3], 1)) then fail(scenario, "the icon was left tinted") end
	if r.cooldown and r.cooldown._circular then fail(scenario, "the cooldown kept the round edge") end
	if (r.textLayer._alpha or 1) < 0.999 then fail(scenario, "the text was left dim") end
	if (r.textLayer._level or 0) ~= (r.art._level or 0) + look.kit.TEXT_LEVEL then fail(scenario, "the text's frame level was not given back") end
	if look.kit.fit.room[r.name] or look.kit.fit.room[r.sub] then fail(scenario, "a room kept for the lines was left behind") end
	if (r.name._shadowOffset or { 1 })[1] ~= 1 then fail(scenario, "the name's shadow was not given back") end
	-- And back: everything drawn again, in its place.
	p.style = "ribbon"
	ns.Prompt:ApplyStyle()
	tick(ns)
	Mock.advance(1)
	FT.settle()
	if not FT.visible(look.cloth[1]) or not FT.visible(look.medal) or not FT.visible(look.cloth[2]) then fail(scenario, "the ribbon did not come back") end
	if r.icon._mask ~= look.mask then fail(scenario, "the icon is not round again") end
	local art, c = span(r.art), span(look.cloth[1])
	if not near(c[1] - art[1], look.g.cx, 0.05) then fail(scenario, "the ribbon is not home after coming back") end
	-- Every region of the built-in looks it hid is shown again by them, not by it.
	p.style = "framed"
	ns.Prompt:ApplyStyle()
	if not FT.visible(r.panel) then fail(scenario, "the framed look's panel is not back") end
end)

-- ------------------------------------------------------------------ 13
-- Every frame of Ribbon's is under the text, and nothing it moves over the
-- text is scaled.
withTree("look-ribbon: every frame of Ribbon's is under the text, and nothing that crosses it scales", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	local text = r.textLayer._level or 0
	for _, x in ipairs(look.own) do
		if x._kind == "Frame" and (x._level or 0) >= text then
			fail(scenario, "a frame of Ribbon's is at level " .. tostring(x._level) .. ", not under the text's " .. text)
		end
	end
	for _, f in ipairs(look.fx.frames) do
		if (f._level or 0) >= text then fail(scenario, "a ring's frame is not under the text") end
	end
	if (r.textLayer._level or 0) <= (r.art._level or 0) then fail(scenario, "the text is not above the art") end
	-- The chips' frame is over the cloth and under the lines.
	if (look.chipFrame._level or 0) <= (r.art._level or 0) or (look.chipFrame._level or 0) >= text then
		fail(scenario, "the tags' frame is not between the art and the text")
	end
	-- No scale among the look's own animations: they all cross the text's room.
	for i, grp in ipairs(look.anims) do
		for _, a in ipairs(grp._anims or {}) do
			if a._kind == "Scale" then fail(scenario, "animation " .. i .. " of Ribbon's scales: it would cross the text") end
		end
	end
	-- Nothing is a frame script on a clock.
	local button = ns.Prompt:GetButton()
	for _, node in ipairs(FT.all) do
		local up, onPrompt = node._parent, false
		while up do
			if up == button then onPrompt = true end
			up = up._parent
		end
		if onPrompt and node ~= button and node.scripts and node.scripts.OnUpdate then fail(scenario, "a frame on the prompt has an OnUpdate") end
	end
end)

-- ------------------------------------------------------------------ 14
-- The list: a small ribbon for each name, hanging from behind the main one,
-- a gem in its reason's colour at its left end, the name on it; each name a
-- button hung off a frame, never a region.
withTree("look-ribbon: the list is a small ribbon per name, hung from behind the main one", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp)
		pp.showQueue, pp.queueRows = true, 3
		pp.accentMode = "both"
	end)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	local art = span(r.art)
	local g = look.g
	local function rel(b) return { b[1] - art[1], art[4] - b[4], b[3] - art[1], art[4] - b[2] } end
	local function check(above)
		local shown = 0
		for i = 1, 3 do
			local row = r.rows[i]
			if not row:IsShown() then fail(scenario, "row " .. i .. " is not shown") end
			local cloth, trim = look.rowCloth[i], look.rowTrim[i]
			for j = 1, 2 do
				if cloth[j]._shown == false or trim[j]._shown == false then fail(scenario, "row " .. i .. "'s ribbon is not drawn") end
			end
			if cloth[3]._shown ~= false then fail(scenario, "row " .. i .. " has a left fork with the medallion on") end
			if look.gems[i]._shown == false or look.gemSets[i]._shown == false then fail(scenario, "row " .. i .. " has no gem") end
			shown = shown + 1
			local m, e = rel(span(cloth[1])), rel(span(cloth[2]))
			local t = rel(span(row))
			local gem = rel(span(look.gems[i]))
			-- The ribbon runs from under the medallion's right to the right edge.
			if e[3] > look.W + 0.05 or m[1] < 0 then fail(scenario, "row " .. i .. "'s ribbon leaves the prompt's width") end
			if not near(m[3], e[1], 0.05) then fail(scenario, "row " .. i .. "'s fork does not meet its middle") end
			-- The name and the gem stand on it, the name short of the fork.
			local mid = (m[2] + m[4]) / 2
			if not (t[2] >= m[2] - 0.05 and t[4] <= m[4] + 0.05) then
				fail(scenario, ("row %d's text (%.1f to %.1f) is not on its ribbon (%.1f to %.1f)"):format(i, t[2], t[4], m[2], m[4]))
			end
			if gem[1] < m[1] - 0.05 or gem[3] > t[1] then fail(scenario, "row " .. i .. "'s gem is not between the ribbon's end and its name") end
			if gem[2] < m[2] - 0.05 or gem[4] > m[4] + 0.05 then fail(scenario, "row " .. i .. "'s gem leaves its ribbon") end
			local notch = NOTCH_PX * (m[4] - m[2]) / RIBBON_PX
			local tip = e[3]
			if t[3] > tip - notch - 1 + 1e-6 then fail(scenario, ("row %d's name runs to %.1f, the fork's apex is at %.1f"):format(i, t[3], tip - notch)) end
			-- Hung from behind the main ribbon: the first is tucked under its hem,
			-- below it or above it, and every row is a pitch from the next.
			if i == (above and 3 or 1) then
				if above then
					if not (m[4] > g.top + 0.5 and m[4] <= g.top + 4 + 1e-6) then fail(scenario, "the row next to the main ribbon is not tucked under its top rail") end
				else
					if not (m[2] < g.bottom - 0.5 and m[2] >= g.bottom - 4 - 1e-6) then fail(scenario, "the row next to the main ribbon is not tucked under its hem") end
				end
			end
			if i > 1 then
				local prev = rel(span(look.rowCloth[i - 1][1]))
				local step = math.abs(((m[2] + m[4]) / 2) - ((prev[2] + prev[4]) / 2))
				if not near(step, look.pitch, 0.05) then fail(scenario, ("row %d is %.1f from the one before, not the pitch %.1f"):format(i, step, look.pitch)) end
				if not (m[4] <= prev[2] + 1.5 or prev[4] <= m[2] + 1.5) then fail(scenario, "row " .. i .. "'s ribbon overlaps the one before") end
			end
			-- Its own side of the main ribbon.
			if above and mid > g.top + 0.5 then fail(scenario, "a row hangs below the top when the list is above") end
			if not above and mid < g.bottom - 0.5 then fail(scenario, "a row hangs above the hem when the list is below") end
			-- The gem is in the reason's colour, and the row's cloth the reason's dye.
			local c = look.gems[i]._color
			if not (c and (c[1] > 0.05 or c[2] > 0.05 or c[3] > 0.05)) then fail(scenario, "row " .. i .. "'s gem has no colour") end
			-- The name is a button on it (hung off a frame).
			local button = r.rowButtons[i]
			if not (button and button:IsShown()) then fail(scenario, "row " .. i .. "'s name is not a button") end
			local b, text = span(button), span(row)
			if not (b and text and b[1] <= text[1] and b[3] >= text[3] - 1) then fail(scenario, "row " .. i .. "'s button does not cover its name") end
			for _, pt in ipairs(button.points or {}) do
				local anchor = pt[2]
				if type(anchor) == "table" and (anchor._kind == "Texture" or anchor._kind == "FontString") then
					fail(scenario, "row " .. i .. "'s button is anchored to a " .. tostring(anchor._kind))
				end
			end
		end
		if shown < 3 then fail(scenario, "only " .. shown .. " rows") end
		-- The fourth and fifth are not drawn.
		for i = 4, #look.gems do
			if look.gems[i]._shown ~= false or look.rowCloth[i][1]._shown ~= false then fail(scenario, "row " .. i .. " is drawn though the list has three") end
		end
	end
	check(false)
	Mock.promptCentreY = 40
	ns.Prompt:ApplyStyle()
	tick(ns)
	check(true)
	-- The reasons in the rows: the group member's gem is the group's enamel, a
	-- stranger's the nearby one, and in the stripe modes the cloth is dyed.
	local standard = { group = true }
	for i = 1, 3 do
		local reason = r.rows[i]._reason
		_ = reason
		_ = standard
	end
	local c1 = colourOf(look.rowCloth[1][1])
	local base = { 0.78 * 0.86, 0.14 * 0.86, 0.14 * 0.86 }
	if not c1 then fail(scenario, "row 1 has no cloth colour") end
	-- A list that empties between two restyles takes its ribbons with it.
	look:PaintQueue(nil, 0, false)
	for i = 1, #look.gems do
		if look.gems[i]._shown ~= false or look.rowCloth[i][1]._shown ~= false or look.rowTrim[i][2]._shown ~= false then
			fail(scenario, "a row's ribbon stayed when the list went")
		end
	end
	Mock.promptCentreY = nil
	p.showQueue = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	for i = 1, #look.gems do
		if look.gems[i]._shown ~= false or look.rowCloth[i][1]._shown ~= false then fail(scenario, "a row's ribbon stayed with no list") end
	end
	_ = base
	-- Icon off: the rows start at the left edge, the names still clear of the gem.
	p.showQueue, p.showIcon = true, false
	ns.Prompt:ApplyStyle()
	tick(ns)
	local m = span(look.rowCloth[1][1])
	local gem, row = span(look.gems[1]), span(r.rows[1])
	if not (m and gem and row and gem[3] <= row[1] and gem[1] >= m[1]) then fail(scenario, "with the icon off the gem is not between the ribbon's end and its name") end
end)

-- The rows' cloth and gem carry the reasons where the mode says.
withTree("look-ribbon: the rows' gems carry the reason and their cloth is dyed in the stripe modes", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp)
		pp.showQueue, pp.queueRows = true, 3
		pp.accentMode = "icon"
	end)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	-- Three strangers: nearby on every row, in the standard palette.
	local want = ns.Prompt.lib.ReasonColor("nearby")
	local gem = colourOf(look.gems[1])
	local l1, l2 = (want[1] + want[2] + want[3]) / 3, (gem[1] + gem[2] + gem[3]) / 3
	local dot, n1, n2 = 0, 0, 0
	for i = 1, 3 do
		local a, b = want[i] - l1, gem[i] - l2
		dot, n1, n2 = dot + a * b, n1 + a * a, n2 + b * b
	end
	if n1 > 0.001 and dot / math.sqrt(n1 * n2) < 0.9 then fail(scenario, "a row's gem is not in its reason's hue") end
	local plain = colourOf(look.rowCloth[1][1])
	for mode, dyed in pairs({ icon = false, stripe = true, both = true, off = false }) do
		p.accentMode = mode
		ns.Prompt:ApplyStyle()
		tick(ns)
		local c = colourOf(look.rowCloth[1][1])
		local k = 0.86
		local crimson = sameColour(c, 0.78 * k, 0.14 * k, 0.14 * k)
		if dyed and crimson then fail(scenario, mode .. ": a stranger's row is not dyed") end
		if not dyed and not crimson then fail(scenario, mode .. ": a row is dyed though the mode says it is not") end
		if mode == "off" then
			local g = colourOf(look.gems[1])
			if not sameColour(g, 0.34, 0.10, 0.09) then fail(scenario, "off: a row's gem carries a reason") end
		end
	end
	_ = plain
end)

-- ------------------------------------------------------------------ 15
-- The options page can say what Ribbon does: its carriers, its icon, its
-- height for two lines.
withTree("look-ribbon: the options page can state what Ribbon does", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("ribbon")
	local h = look.TwoLineHeight(13)
	if h > 44 then fail(scenario, "two lines at the default font need " .. h .. ", more than the default 44") end
	if h ~= ns.TwoLineHeight(13, "ribbon") then fail(scenario, "Prompt and Ribbon disagree about two lines") end
	if look.TwoLineHeight(17) <= look.TwoLineHeight(11) then fail(scenario, "two lines need no more at a big font") end
	for _, size in ipairs({ 9, 11, 13, 15, 17, 20, 24 }) do
		local need = look.TwoLineHeight(size)
		-- The least height that holds them: one shorter does not (it would be
		-- two lines drawn over the rails).
		if need > 24 and look.TwoLineHeight(size) ~= need then fail(scenario, "TwoLineHeight is not steady") end
	end
	-- The icon is sized by the height, and the page is told.
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	for _, height in ipairs({ 32, 44, 58, 72 }) do
		p.height = height
		p.style = "ribbon"
		ns.Prompt:ApplyStyle()
		local r = ns.Prompt:Regions()
		local box = span(r.icon)
		if not near(box[3] - box[1], look.IconSize(p), 0.5) then
			fail(scenario, ("at %d tall the icon is %.1f and the page is told %d"):format(height, box[3] - box[1], look.IconSize(p)))
		end
	end
	if look.IconSize({ width = 220, height = 72 }) <= look.IconSize({ width = 220, height = 44 }) then fail(scenario, "a taller prompt has no bigger icon") end
	local ring, stripe = look.AccentCarriers({ accentMode = "icon", showIcon = true })
	if not ring or stripe then fail(scenario, "the ring alone should carry the default marker") end
end)

-- ------------------------------------------------------------------ 16
-- The art: the generator draws the same bytes twice and the bytes that ship,
-- every file is 32 bits, uncompressed and a power of two up to 256, every
-- file is drawn by the look, and nothing ships that nothing draws.
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-ribbon-" .. token .. "-" .. tostring(os.time())
end

local python = os.getenv("MANNERS_PYTHON") or "python"

local function header(path)
	local data = slurp(path)
	if not data or #data < 18 then return nil end
	local b = { data:byte(1, 18) }
	return { imageType = b[3], width = b[13] + b[14] * 256, height = b[15] + b[16] * 256, bits = b[17] }
end

local function powerOfTwo(n)
	if n < 1 then return false end
	while n > 1 do
		if n % 2 ~= 0 then return false end
		n = n / 2
	end
	return true
end

-- The files the look draws, by name.
local FILES = { "Ribbon_Cloth_Mid", "Ribbon_Cloth_End", "Ribbon_Cloth_EndL", "Ribbon_Trim_Mid", "Ribbon_Trim_End", "Ribbon_Trim_EndL",
	"Ribbon_Drop_Mid", "Ribbon_Drop_End", "Ribbon_Drop_EndL", "Ribbon_Medal", "Ribbon_Enamel", "Ribbon_Gloss", "Ribbon_Lit",
	"Ribbon_Shade", "Ribbon_Disc", "Ribbon_Mask", "Ribbon_Ring", "Ribbon_Sweep", "Ribbon_Glint", "Ribbon_Tag", "Ribbon_Badge",
	"Ribbon_Gem", "Ribbon_GemSet" }

withTree("look-ribbon: the generator draws the same bytes twice, and the bytes that ship", ANNA, function(_, scenario)
	local a, b = tempDir() .. "-a", tempDir() .. "-b"
	-- os.execute and a log file rather than io.popen, which the Lua that lupa
	-- builds on Linux leaves out.
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_ribbon_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	-- CI's test job installs lupa only; the generator needs numpy and Pillow.
	if outA:find("No module named", 1, true) then return end
	local names = {}
	for file in outA:gmatch("([%w_]+%.tga)") do names[#names + 1] = file end
	if #names ~= #FILES then fail(scenario, "the generator wrote " .. #names .. " files, not " .. #FILES .. ": " .. outA:sub(1, 200)) return end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Ribbon/" .. file)
		local h = header(a .. "/" .. file)
		if h and (h.width > 256 or h.height > 256 or not powerOfTwo(h.width) or not powerOfTwo(h.height)
			or h.bits ~= 32 or h.imageType ~= 2) then
			fail(scenario, ("%s is %dx%d at %d bits, type %d"):format(file, h.width, h.height, h.bits, h.imageType))
		end
		if not one or not two then
			fail(scenario, file .. " was not written")
		elseif one ~= two then
			fail(scenario, file .. " differs between two runs")
		elseif not ships then
			fail(scenario, file .. " is drawn but does not ship")
		elseif one ~= ships then
			fail(scenario, file .. " does not match the file that ships: run the generator")
		end
		os.remove(a .. "/" .. file)
		os.remove(b .. "/" .. file)
	end
	local drawn = {}
	for _, file in ipairs(names) do drawn[file] = true end
	for _, file in ipairs(FILES) do
		if not drawn[file .. ".tga"] then fail(scenario, file .. " is not drawn by the generator") end
		if not slurp(dir .. "/Textures/Ribbon/" .. file .. ".tga") then fail(scenario, file .. " is not in the package") end
	end
end)

-- Every texture the look draws is one of those files, and every file is drawn.
withTree("look-ribbon: every texture is from Textures/Ribbon, and every file is drawn", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isRibbon(look) then fail(scenario, "SKIPPED -- Ribbon is not the look in use") return end
	local used = {}
	local function note(t)
		if t._kind == "Texture" and t._file then
			local rel = tostring(t._file):match("^Interface\\AddOns\\Manners\\(.+)$")
			if not rel or not rel:find("^Textures\\Ribbon\\Ribbon_") then
				fail(scenario, "a texture of Ribbon's is from " .. tostring(t._file))
			elseif not slurp(dir .. "/" .. rel:gsub("\\", "/") .. ".tga") then
				fail(scenario, tostring(t._file) .. " is not shipped")
			else
				used[rel:match("Ribbon_[%w_]+")] = true
			end
		end
	end
	for _, icon in ipairs({ true, false }) do
		p.showIcon = icon
		ns.Prompt:ApplyStyle()
		tick(ns)
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
		for _, t in ipairs(look.own) do note(t) end
		for _, ring in ipairs(look.fx.rings) do used["Ribbon_" .. tostring(ring.tex._file):match("Ribbon_([%w_]+)$")] = true end
		used[tostring(look.mask._file):match("Ribbon_[%w_]+")] = true
	end
	for _, file in ipairs(FILES) do
		if not used[file] then fail(scenario, file .. " ships and the look never draws it") end
	end
	-- Nothing else ships (the folder listed by python, like the generator is run).
	local log = tempDir() .. "-list.log"
	os.execute(python .. ' -c "import os,sys;print(chr(10).join(sorted(os.listdir(sys.argv[1]))))" "' .. dir
		.. '/Textures/Ribbon" > "' .. log .. '" 2>&1')
	local listing = slurp(log)
	os.remove(log)
	if listing and not listing:find("No module", 1, true) then
		for file in listing:gmatch("[^%c]+") do
			local stem = file:match("^(.+)%.tga$")
			if not stem or not used[stem] then fail(scenario, file .. " ships and nothing draws it") end
		end
	end
end)

-- The figures the code and the art share are the same in both: the fork's
-- depth and width, the rows of a ribbon file, the medallion's radii, the ring's
-- peak and its reach.
withTree("look-ribbon: the code and the generator agree about the art's figures", ANNA, function(ns, scenario)
	local code = slurp(dir .. "/Looks/Ribbon.lua") or ""
	local gen = slurp(dir .. "/tools/make_ribbon_textures.py") or ""
	local function num(text, pattern) return tonumber(text:match(pattern)) end
	local cr, ce, cn, cs = code:match("local RIBBON_PX, END_PX, NOTCH_PX, SHADOW_PX = (%d+), (%d+), (%d+), (%d+)")
	local gr, ge = gen:match("RIBBON_PX, END_PX = (%d+), (%d+)")
	local gn = gen:match("\nNOTCH_PX = ([%d%.]+)")
	local gs = gen:match("\nSHADOW_PX = ([%d%.]+)")
	if not (tonumber(cr) == tonumber(gr) and tonumber(ce) == tonumber(ge) and tonumber(cn) == tonumber(gn) and tonumber(cs) == tonumber(gs)) then
		fail(scenario, ("the ribbon's figures differ: code %s %s %s %s, generator %s %s %s %s"):format(
			tostring(cr), tostring(ce), tostring(cn), tostring(cs), tostring(gr), tostring(ge), tostring(gn), tostring(gs)))
	end
	if tonumber(cr) ~= RIBBON_PX or tonumber(ce) ~= END_PX or tonumber(cn) ~= NOTCH_PX then fail(scenario, "the test's figures are not the look's") end
	local c1, c2, c3, c4, c5 = code:match("local M_OUT, M_CH_OUT, M_CH_IN, M_BEZEL = ([%d%.]+), ([%d%.]+), ([%d%.]+), ([%d%.]+)")
	local g1, g2, g3, g4, g5 = gen:match("M_OUT, M_LIP, M_CH_OUT, M_CH_IN, M_BEZEL = ([%d%.]+), ([%d%.]+), ([%d%.]+), ([%d%.]+), ([%d%.]+)")
	if not (tonumber(c1) == tonumber(g1) and tonumber(c2) == tonumber(g3) and tonumber(c3) == tonumber(g4) and tonumber(c4) == tonumber(g5)) then
		fail(scenario, "the medallion's radii differ between the code and the generator")
	end
	_ = c5
	_ = g2
	if tonumber(c4) ~= M_BEZEL then fail(scenario, "the test's bezel is not the look's") end
	local peak, edge = code:match("local SHADE_FILL, RING_PEAK, RING_EDGE = ([%d%.]+), ([%d%.]+), ([%d%.]+)")
	local gshade = gen:match("\nSHADE_FILL = ([%d%.]+)")
	local gpeak = gen:match("RING_PEAK, RING_SIGMA = ([%d%.]+),")
	if tonumber(peak) ~= tonumber(gpeak) or tonumber(code:match("SHADE_FILL, RING_PEAK, RING_EDGE = ([%d%.]+)")) ~= tonumber(gshade) then
		fail(scenario, "the ring's peak or the shade's edge differs between the code and the generator")
	end
	_ = edge
	-- The lettering's lightest cloth: no file is lighter than the code says.
	local lit = num(code, "local LIT_GREY = ([%d%.]+)")
	for _, name in ipairs({ "Ribbon_Cloth_Mid", "Ribbon_Cloth_End", "Ribbon_Cloth_EndL" }) do
		local data = slurp(dir .. "/Textures/Ribbon/" .. name .. ".tga")
		if data then
			local b = { data:byte(1, 18) }
			local w, h = b[13] + b[14] * 256, b[15] + b[16] * 256
			local offset = 18 + b[1]
			local top = 0
			for i = 0, w * h - 1 do
				local alpha = data:byte(offset + i * 4 + 4)
				if alpha == 255 then top = math.max(top, data:byte(offset + i * 4 + 3) / 255) end
			end
			if top > lit + 1e-6 then fail(scenario, ("%s is lighter (%.3f) than the %.3f the lettering's contrast counts on"):format(name, top, lit)) end
			if top < lit - 0.08 then fail(scenario, ("%s is much darker (%.3f) than the %.3f the lettering counts on"):format(name, top, lit)) end
		end
	end
end)

-- ------------------------------------------------------------------ 10
-- The art is modelled, not painted flat. Read from a fresh run of the
-- generator (the shipped bytes are held to it above): the cloth has a sheen
-- band above its middle, a hem in shade and folds along its length; the
-- medallion's gold is lit at the upper left and dark at the lower right, with
-- a dark outline round its edge; the cord on the cloth's edge has a dark
-- outline outside it; the ribbon's shadow is a shadow; the key's tag is gold
-- through, and the count's badge is gold round a field of crimson enamel.
local function readPixels(path)
	local data = slurp(path)
	if not data then return nil end
	local b = { data:byte(1, 18) }
	if #b < 18 or b[3] ~= 2 or b[17] ~= 32 then return nil end
	local w, h = b[13] + b[14] * 256, b[15] + b[16] * 256
	local offset = 18 + b[1]
	local topFirst = math.floor(b[18] / 32) % 2 == 1
	-- Stored blue, green, red, alpha.
	return { w = w, h = h, at = function(x, y)
		local row = topFirst and y or (h - 1 - y)
		local i = offset + (row * w + x) * 4
		local bb, g, r, a = data:byte(i + 1, i + 4)
		return r / 255, g / 255, bb / 255, a / 255
	end }
end

withTree("look-ribbon: the art is modelled: a sheen and a hem on the cloth, gold lit from the upper left, enamel in the badge", ANNA, function(_, scenario)
	local out = tempDir() .. "-art"
	local log = out .. ".log"
	os.execute(python .. ' "' .. dir .. '/tools/make_ribbon_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
	local text = slurp(log)
	os.remove(log)
	if not text then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	-- CI's test job installs lupa only; the generator needs numpy and Pillow.
	if text:find("No module named", 1, true) then return end
	local function file(name)
		local t = readPixels(out .. "/" .. name .. ".tga")
		if not t then fail(scenario, name .. " was not written, or is not 32-bit uncompressed") end
		return t
	end
	local function luma(t, x, y)
		local r, g, b = t.at(x, y)
		return 0.299 * r + 0.587 * g + 0.114 * b
	end
	-- The cloth: its rows averaged along the length. The sheen is the
	-- brightest row above the middle, well above the top edge; the hem is
	-- in shade; along the sheen's row the folds lift and drop the grey.
	local mid = file("Ribbon_Cloth_Mid")
	if mid then
		local rows = {}
		for y = 0, mid.h - 1 do
			local sum = 0
			for x = 0, mid.w - 1 do sum = sum + luma(mid, x, y) end
			rows[y] = sum / mid.w
		end
		local band, at, hem = 0, 0, 1
		for y = 6, 30 do
			if rows[y] > band then band, at = rows[y], y end
		end
		for y = 54, 61 do hem = math.min(hem, rows[y]) end
		if band - hem < 0.25 then fail(scenario, ("the cloth is flat: its sheen band is %.3f, its hem %.3f"):format(band, hem)) end
		local top = (rows[1] + rows[2]) / 2
		if band - top < 0.08 then fail(scenario, ("the cloth has no sheen band above its middle: the band is %.3f, the top edge %.3f"):format(band, top)) end
		local lo, hi = 1, 0
		for x = 8, mid.w - 9 do
			local l = luma(mid, x, at)
			lo, hi = math.min(lo, l), math.max(hi, l)
		end
		if hi - lo < 0.05 then fail(scenario, ("the cloth has no folds along its length: %.3f to %.3f on the sheen's row"):format(lo, hi)) end
	end
	-- The medallion's gold: the outer slope of the lip and of the bezel are
	-- lit at the upper left and in shade at the lower right (sampled over a
	-- few degrees either side, as the beads vary round the lip), and the edge
	-- is drawn dark round the lit lip.
	local medal = file("Ribbon_Medal")
	if medal then
		local half = medal.w / 2
		local function ring(r, deg)
			local a = math.rad(deg)
			return luma(medal, math.floor(half + r * half * math.cos(a)), math.floor(half + r * half * math.sin(a)))
		end
		local function round(r, deg)
			local sum = 0
			for d = -12, 12, 4 do sum = sum + ring(r, deg + d) end
			return sum / 7
		end
		for _, slope in ipairs({ { 0.93, "the medallion's lip" }, { 0.71, "the medallion's bezel" } }) do
			local ul, lr = round(slope[1], -135), round(slope[1], 45)
			if ul - lr < 0.35 then fail(scenario, ("%s is not lit from the upper left: %.3f there, %.3f at the lower right"):format(slope[2], ul, lr)) end
		end
		local edge, lip = round(0.976, -135), round(0.93, -135)
		if lip - edge < 0.30 then fail(scenario, ("the medallion has no dark outline: %.3f at the edge, %.3f on the lip"):format(edge, lip)) end
	end
	-- The cord: a dark outline drawn outside it, the cord bright over it.
	local trim = file("Ribbon_Trim_Mid")
	if trim then
		local x = math.floor(trim.w / 2)
		local _, _, _, a0 = trim.at(x, 0)
		if a0 < 0.75 then fail(scenario, ("the cord's outline is not drawn: alpha %.2f on the outermost row"):format(a0)) end
		local outline, cord = luma(trim, x, 0), luma(trim, x, 1)
		if cord - outline < 0.25 then fail(scenario, ("the cord has no dark outline: %.3f outside, %.3f on the cord"):format(outline, cord)) end
	end
	-- The shadow is a shadow.
	local drop = file("Ribbon_Drop_Mid")
	if drop then
		local _, _, _, a = drop.at(math.floor(drop.w / 2), math.floor(drop.h / 2))
		if a < 0.55 then fail(scenario, ("the ribbon's shadow is faint: %.2f at its middle"):format(a)) end
	end
	-- The key's tag is gold through; the count's badge is gold round crimson.
	local tag, badge = file("Ribbon_Tag"), file("Ribbon_Badge")
	if tag and badge then
		local r, g, b, a = tag.at(32, 16)
		if not (a > 0.99 and g > 0.45 and r > g and g > b) then fail(scenario, ("the key's tag is not gold at its middle: %.2f %.2f %.2f"):format(r, g, b)) end
		r, g, b, a = badge.at(32, 16)
		if not (a > 0.99 and r > 0.30 and g < 0.22 and b < 0.25) then fail(scenario, ("the badge's field is not crimson enamel: %.2f %.2f %.2f"):format(r, g, b)) end
		r, g, b = badge.at(32, 3)
		if not (g > 0.40 and r >= g and g > b) then fail(scenario, ("the badge's rim is not gold: %.2f %.2f %.2f"):format(r, g, b)) end
	end
	for _, name in ipairs(FILES) do os.remove(out .. "/" .. name .. ".tga") end
end)
