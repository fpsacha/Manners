-- The Slate look (Looks/Slate.lua): what it promises beyond what every look
-- does, which tests/scenarios/looks.lua, hunt35-effects.lua and
-- hunt37-effects.lua already ask of it.
--
-- Run on the recording CreateFrame in tests/frametree.lua, which remembers what
-- every region was told: a look that is wrong throws nothing, it just shows
-- the wrong thing.
--
-- What it holds:
--   * Slate is registered, in the toc after the other looks, named in all eight
--     translations;
--   * every state paints on every client without an error;
--   * the layout: the lines, the icon, the chips, the line along the bottom and
--     the list sit inside the card and apart from one another, at every size
--     and scale, with the icon on and off, round, and in every marker mode;
--   * the secure list names hang off frames, never off a region;
--   * the icon's pop and bounce stay in the room and every frame of light is
--     under the text;
--   * the cooldown line burns down with the cooldown's own start and length,
--     from the left, and goes with it; the sweep is drawn at no strength;
--   * the outcomes, the marker modes, Calm, the fight, leaving the look;
--   * the art is the generator's, byte for byte.

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

-- The prompt up in Slate with Anna owed on top. Returns the regions, the
-- settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "slate"
	p.showSub, p.showIcon, p.roundIcon = true, true, false
	-- What an earlier call chose is not the next one's.
	for _, key in ipairs({ "bgColor", "fontColor", "accentMode", "reasonPalette", "accentByReason", "accentColor",
		"effects", "flashStyle", "width", "height", "fontSize", "iconSize", "scale", "showQueue", "showCount" }) do
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
	owe(ns, "Anna Aim")
	tick(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function isSlate(look)
	return look ~= nil and look.key == "slate" and look.warmRim ~= nil and look.coolBurn ~= nil
end

local function plays(list)
	local n = 0
	for _, g in ipairs(list) do n = n + (g._plays or 0) end
	return n
end

local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

-- ------------------------------------------------------------------ 1
-- Registered, listed in the toc after the others, and named in every language.
withTree("look-slate: Slate is registered, in the toc and translated", ANNA, function(ns, scenario)
	local look = ns.Looks.list.slate
	if not look then fail(scenario, "no look is registered under \"slate\"") return end
	if ns.Looks.Get("slate") ~= look then fail(scenario, "Get does not hand back Slate") end
	if not ns.Looks.Allowed().slate then fail(scenario, "a saved style of \"slate\" would be repaired away") end
	local values = ns.Looks.Choices()
	if values.slate ~= look.name or not look.name:find("Slate", 1, true) then
		fail(scenario, "the look is not in the dropdown under its name: " .. tostring(values.slate))
	end
	for _, method in ipairs({ "Apply", "Hide", "Build", "PlaceLines", "Fitted", "PaintReason", "Chip", "Attention",
		"StopAttention", "Flourish", "StopFlourishes", "PaintOutcome", "ClearOutcome", "Combat", "Hover",
		"PaintQueue", "Styled" }) do
		if type(look[method]) ~= "function" then fail(scenario, "Slate has no " .. method) end
	end
	local toc = slurp(dir .. "/Manners.toc") or ""
	local arcane, slate = toc:find("Looks\\Arcane.lua", 1, true), toc:find("Looks\\Slate.lua", 1, true)
	if not (arcane and slate and slate > arcane) then fail(scenario, "Looks\\Slate.lua is not in Manners.toc after the looks") end
	-- The name in all eight translations, read from the files (the client loads
	-- one of them).
	for _, code in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
		local text = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
		local key = 'L["' .. "Slate -- modern card, soft shadow, thin progress line" .. '"] = "'
		local at = text:find(key, 1, true)
		local line = at and text:sub(at + #key):match("^([^\n]*)")
		if not at or not line or #line < 4 then fail(scenario, code .. " has no translation of the look's name") end
		if at and line and line:find("Slate", 1, true) then fail(scenario, code .. " left the look's name in English") end
	end
	if look.order == nil then fail(scenario, "the look has no place in the dropdown") end
end)

-- ------------------------------------------------------------------ 2
-- Every state paints on every client without an error: each reason, a group
-- cast, an outcome of each kind, a fight, the list, the cooldown.
for _, flavour in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
	local name = "look-slate: every state paints on " .. flavour
	withTree(name, CROWD, function(ns, scenario)
		local r, p, look = upIn(ns, scenario)
		if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
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
			p.reasonPalette = palette
			ns.Prompt:ApplyStyle()
			for _, reason in ipairs(REASONS) do
				ns.Prompt:Paint({ name = "Anna Aim", short = "Anna", reason = reason, buff = buff }, 2)
				check(palette .. " " .. reason)
			end
		end
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
		if #(ns.errors or {}) > 0 and #ns.errors > from then check("after") end
	end, function() Mock.setFlavour(flavour) end)
end

-- ------------------------------------------------------------------ 3
-- The layout. Everything the card holds sits inside it and apart from the
-- rest: the lines clear of the icon, the chips and the line along the bottom;
-- the pill, the ring and the line inside the card's edge; at every size, icon
-- on and off, round, in every marker mode and at the ends of the scale.
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

local function layoutAt(ns, scenario, label, edit, ctx)
	local r, p, look = upIn(ns, scenario, edit)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	ctx.n = ctx.n + 1
	local art = span(r.art)
	local name, sub = span(r.name), r.sub:IsShown() and span(r.sub) or nil
	if not (art and name) then fail(scenario, label .. ": nothing to measure") return end
	if not inside(name, art) then fail(scenario, label .. ": the name is outside the card") end
	if sub and not inside(sub, art) then fail(scenario, label .. ": the reason line is outside the card") end
	if sub and not apart(name, sub, 0.3) then fail(scenario, label .. ": the name and the reason line overlap") end
	local parts = {}
	if p.showIcon then
		parts.icon = span(r.icon)
		if parts.icon and not inside(parts.icon, art) then fail(scenario, label .. ": the icon is outside the card") end
		if parts.icon and not apart(parts.icon, name, 3) then
			fail(scenario, label .. ": the name runs into the icon")
		end
		if parts.icon and sub and not apart(parts.icon, sub, 3) then
			fail(scenario, label .. ": the reason line runs into the icon")
		end
		for _, t in ipairs({ look.plate, look.ring, look.glow, look.flash }) do
			local b = span(t)
			if b and not inside(b, art, 0.3) then fail(scenario, label .. ": the icon's ring or light is outside the card") end
		end
	end
	-- The frames of the card's furniture, inside the card.
	for what, f in pairs({ bar = look.barFrame, line = look.coolBox, fill = look.landFill, flare = look.refuseFill }) do
		local b = span(f)
		if f._shown ~= false and b and not inside(b, art, 0.3) then
			fail(scenario, label .. ": the " .. what .. " is outside the card")
		end
	end
	-- The line along the bottom is under the text and clear of the icon.
	local line = span(look.coolBox)
	if line then
		if sub and not apart(sub, line, 0.2) then fail(scenario, label .. ": the line runs through the reason line") end
		if not apart(name, line, 0.2) then fail(scenario, label .. ": the line runs through the name") end
		if parts.icon and not apart(parts.icon, line, 0.2) then fail(scenario, label .. ": the line runs under the icon") end
	end
	-- The pill is clear of the icon and the lines.
	if look.barFrame._shown ~= false then
		local bar = span(look.barFrame)
		if bar and parts.icon and not apart(bar, parts.icon, 0.5) then fail(scenario, label .. ": the pill touches the icon") end
		if bar and not apart(bar, name, 0.5) then fail(scenario, label .. ": the pill touches the name") end
	end
	-- Never the same text twice over: the name is not wider than the card.
	if name[3] - name[1] > art[3] - art[1] then fail(scenario, label .. ": the name is wider than the card") end
end

withTree("look-slate: the layout holds at every size, in every mode", CROWD, function(ns, scenario)
	local ctx = { n = 0 }
	local modes = { "icon", "stripe", "both", "off" }
	for _, W in ipairs({ 160, 220, 400 }) do
		for _, Hh in ipairs({ 32, 44, 72 }) do
			for _, icon in ipairs({ true, false }) do
				for mi, mode in ipairs(modes) do
					local round = (mi % 2 == 0) and icon
					local label = ("%dx%d, icon %s, %s%s"):format(W, Hh, tostring(icon), mode, round and ", round" or "")
					layoutAt(ns, scenario, label, function(p)
						p.width, p.height, p.fontSize = W, Hh, 13
						p.iconSize = math.min(30, Hh - 8)
						p.showIcon, p.roundIcon, p.accentMode = icon, round, mode
						p.showCount = true
					end, ctx)
				end
			end
		end
	end
	-- The biggest icon the slider allows, and a big font.
	layoutAt(ns, scenario, "220x48 icon 40 font 17", function(p)
		p.width, p.height, p.fontSize, p.iconSize = 220, 48, 17, 40
	end, ctx)
	layoutAt(ns, scenario, "320x72 icon 64 font 17", function(p)
		p.width, p.height, p.fontSize, p.iconSize = 320, 72, 17, 64
	end, ctx)
	layoutAt(ns, scenario, "80x36 icon 24 font 24", function(p)
		p.width, p.height, p.fontSize, p.iconSize = 80, 36, 24, 24
	end, ctx)
	for _, scale in ipairs({ 0.7, 1.6 }) do
		layoutAt(ns, scenario, "scale " .. scale, function(p) p.scale = scale end, ctx)
	end
	if ctx.n < 70 then fail(scenario, "only " .. ctx.n .. " layouts were measured") end
end)

-- With the chips up the lines keep clear of them.
withTree("look-slate: the lines keep clear of the chips", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local function clear(what)
		local name, sub = span(r.name), span(r.sub)
		for chipName, box in pairs({ count = look.chipBox, key = look.keyBox }) do
			if box._shown ~= false and look[chipName == "count" and "countMode" or "keyUp"] then
				local b = span(box)
				if b and not apart(name, b, 0.2) then fail(scenario, what .. ": the name runs under the " .. chipName .. " chip") end
				if b and sub and not apart(sub, b, 0.2) then fail(scenario, what .. ": the reason runs under the " .. chipName .. " chip") end
			end
		end
	end
	if look.countMode ~= "chip" then fail(scenario, "the count has no chip beside the name: " .. tostring(look.countMode)) end
	if not tostring(r.count:GetText()):find("^%+%d") then
		fail(scenario, "the count chip does not say how many more: " .. tostring(r.count:GetText()))
	end
	clear("count")
	SetBinding("SHIFT-F", COMMAND)
	tick(ns)
	if look.countMode ~= "pair" or not look.keyUp then
		fail(scenario, "the key and the count are not both up: " .. tostring(look.countMode))
	end
	clear("key and count")
	-- No key over an outcome: it is not a press that casts.
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if look.keyUp or look.keyChip[2]._shown ~= false then fail(scenario, "the key's chip is up over an outcome") end
	Mock.advance(3)
	tick(ns)
	-- The name wins at every width: a chip is up only where the name, at its
	-- smallest, still fits beside it; the pair only where it fits beside both.
	SetBinding("SHIFT-F", COMMAND)
	local sawPair, sawKeyAlone = false, false
	for width = 120, 320, 5 do
		p.width = width
		ns.Prompt:ApplyStyle()
		ns.Prompt:Paint({ name = "Anna Aim", short = "Annabelle-Marguerite Thistlewood", reason = "owed",
			buff = ns.ResolveBuff(true) }, 3)
		if look.countMode == "pair" then
			sawPair = true
			if not look:NameFits(look:PairRoom()) then fail(scenario, width .. ": both chips are up and cut the name") end
		elseif look.keyUp then
			sawKeyAlone = true
			if look.countMode == "chip" then fail(scenario, width .. ": the key's chip and a lone count are both up") end
		end
		if look.keyUp and not look:NameFits(look.keyRoom) then fail(scenario, width .. ": the key's chip is up and cuts the name") end
	end
	if not (sawPair and sawKeyAlone) then fail(scenario, "the sweep of widths never showed both the pair and the key alone") end
	p.width = 220
	ns.Prompt:ApplyStyle()
	tick(ns)
	-- The name wins: a long one at a narrow width and the chips step aside.
	p.width = 150
	ns.Prompt:ApplyStyle()
	ns.Prompt:Paint({ name = "Anna Aim", short = "Annabelle-Marguerite Thistlewood", reason = "owed",
		buff = ns.ResolveBuff(true) }, 3)
	if look.keyChip[2]._shown ~= false then fail(scenario, "the key's chip stayed up and cut a name that could not shrink") end
	SetBinding("SHIFT-F", nil)
	tick(ns)
	if look.keyUp then fail(scenario, "the key's chip outlived the binding") end
end)

-- ------------------------------------------------------------------ 4
-- Long translated lines are fitted, never cut badly nor over anything.
withTree("look-slate: a German client's lines fit the card", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = 180, 44 end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local art = span(r.art)
	-- A reason that is a little too long at its size, and one that is not.
	for _, text in ipairs({ "Arkane Intelligenz xx", "Kurz" }) do
		ns.Prompt:Paint({ name = "Anna Aim", short = "Annabelle", reason = "owed", buff = ns.ResolveBuff(true) }, 2)
		ns.Prompt.lib.SetLine(r.sub, text)
		FT.settle()
		local sub = span(r.sub)
		if not (sub and inside(sub, art)) then fail(scenario, "the reason line leaves the card") end
		local right = r.sub.points[#r.sub.points]
		if not (right and right[1] == "RIGHT" and right[2] <= -12 + 1e-6) then
			fail(scenario, "the reason line has no room kept at the right")
		end
		-- Fitted: drawn smaller before it is cut, and never wider than its room.
		local size = select(2, r.sub:GetFont())
		if type(size) == "number" and size < 7 then fail(scenario, "the line shrank below 7") end
		local room = (sub and sub[3] - sub[1]) or 0
		local width = r.sub:GetUnboundedStringWidth()
		if type(width) == "number" and width > room + 0.6 and type(size) == "number" and size > 7 then
			fail(scenario, ("a line %.1f wide in a room of %.1f was not fitted (size %s)"):format(width, room, tostring(size)))
		end
	end
	local base = look.kit.fit.base[r.sub]
	ns.Prompt.lib.SetLine(r.sub, "Arkane Intelligenz xx")
	if select(2, r.sub:GetFont()) >= base then fail(scenario, "a long reason line was not drawn smaller to fit") end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Das Ziel ist außer Reichweite, und noch ein langer Satz dahinter.")
	FT.settle()
	local sub = span(r.sub)
	if not (sub and inside(sub, art)) then fail(scenario, "a long refusal leaves the card") end
	-- The glyph leads it and the line gives way.
	local glyph = span(look.glyph)
	if glyph and not apart(glyph, sub, 0.5) then fail(scenario, "the verdict's glyph overlaps the words") end
end, function() Mock.locale = "deDE" end)

-- ------------------------------------------------------------------ 5
-- The list's names are buttons hung off frames, never off a region, the tray
-- sits clear of the card above or below, and the dots wear the reasons'
-- colours.
withTree("look-slate: the list hangs off frames in a tray with dots", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local art = span(r.art)
	-- The tray's box: all nine pieces of its card.
	local function trayBox()
		local tl, br = span(look.trayBody[1]), span(look.trayBody[8])
		if not (tl and br) then return nil end
		return { tl[1], br[2], br[3], tl[4] }
	end
	local function check(side)
		local tray = trayBox()
		if not tray or look.trayBody[9]._shown == false then fail(scenario, side .. ": no tray under the list") return end
		if side == "below" and not (tray[4] <= art[2] - 2.5) then fail(scenario, "the tray below touches the card") end
		if side == "above" and not (tray[2] >= art[4] + 2.5) then fail(scenario, "the tray above touches the card") end
		local rows = 0
		for i, fs in ipairs(r.rows) do
			if fs._text and fs._text ~= "" then
				rows = rows + 1
				local b = span(fs)
				if b and not inside(b, { tray[1], tray[2], tray[3], tray[4] }, 0.5) then
					fail(scenario, side .. ": row " .. i .. " is outside the tray")
				end
				local dot = look.dots[i]
				if dot._shown == false or not dot._color then fail(scenario, side .. ": row " .. i .. " has no dot") end
				-- In a reason's colour, whichever it is.
				local known = false
				for _, reason in ipairs(REASONS) do
					local c = ns.Prompt.lib.ReasonColor(reason)
					if dot._color and sameColour(dot._color, c[1], c[2], c[3]) then known = true end
				end
				if not known then fail(scenario, side .. ": row " .. i .. "'s dot is not in a reason's colour") end
				local button = r.rowButtons[i]
				local at = button.points[1]
				if not (at and (at[2] == r.art or at[2] == ns.Prompt:GetButton())) then
					fail(scenario, side .. ": row " .. i .. "'s button hangs off something that is not a frame")
				end
				-- The click area covers the dot and the name.
				local area, dotBox = span(button), span(dot)
				if area and b and not (area[1] <= dotBox[1] + 0.5 and area[3] >= b[1]) then
					fail(scenario, side .. ": row " .. i .. "'s click area misses its dot or its name")
				end
			end
		end
		if rows == 0 then fail(scenario, side .. ": no rows were written") end
		for i = rows + 1, #look.dots do
			if look.dots[i]._shown ~= false then fail(scenario, side .. ": a dot with no row") end
		end
	end
	check("below")
	Mock.promptCentreY = 40
	ns.Prompt:ApplyStyle()
	tick(ns)
	check("above")
	-- A list that empties between two restyles takes its tray with it.
	look:PaintQueue(nil, 0, false)
	if look.trayBody[9]._shown ~= false or look.trayRim[1]._shown ~= false then
		fail(scenario, "the tray stayed when the list went")
	end
	for _, dot in ipairs(look.dots) do
		if dot._shown ~= false then fail(scenario, "a dot stayed when the list went") end
	end
	ns.Prompt:ApplyStyle()
	tick(ns)
	-- No list, no tray.
	p.showQueue = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.trayBody[9]._shown ~= false or look.trayRim[1]._shown ~= false then
		fail(scenario, "the tray stayed when the list went")
	end
	-- Icon off: the dots stand by the names.
	p.showQueue, p.showIcon = true, false
	Mock.promptCentreY = nil
	ns.Prompt:ApplyStyle()
	tick(ns)
	local dotBox, row = span(look.dots[1]), span(r.rows[1])
	if look.dots[1]._shown == false or not (dotBox and row and dotBox[3] <= row[1]) then
		fail(scenario, "with the icon off the dot is not beside its name")
	end
end)

withTree("look-slate: a click on a name in the list reaches it", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local shown = 0
	for i, button in ipairs(r.rowButtons) do
		if button:IsShown() then
			shown = shown + 1
			local box, text = span(button), span(r.rows[i])
			if not (box and text and box[1] <= text[1] and box[3] >= text[3] - 1) then
				fail(scenario, "row " .. i .. "'s button does not cover its name")
			end
			-- The refusal of a region anchor is the mock's, as the client's.
			for _, pt in ipairs(button.points or {}) do
				local rel = pt[2]
				if type(rel) == "table" and (rel._kind == "Texture" or rel._kind == "FontString") then
					fail(scenario, "row " .. i .. "'s button is anchored to a " .. tostring(rel._kind))
				end
			end
		end
	end
	if shown < 3 then fail(scenario, "only " .. shown .. " names are buttons") end
end)

-- ------------------------------------------------------------------ 6
-- The room the effects keep to: the icon's pop and bounce stay within the room
-- between the icon, the text and the card's top and bottom; every frame of
-- light is under the text.
local function scaleOf(a) return a._scaleFrom, a._scaleTo end

withTree("look-slate: the icon's pop and bounce stay in their room", ANNA, function(ns, scenario)
	for _, size in ipairs({
		{ "default" },
		{ "extreme", 220, 48, 17, 40 },
		{ "tall", 320, 72, 17, 64 },
		{ "tiny icon", 220, 44, 13, 16 },
		{ "very tall", 300, 120, 13, 64 },
	}) do
		local r, p, look = upIn(ns, scenario, function(pp)
			if size[2] then pp.width, pp.height, pp.fontSize, pp.iconSize = size[2], size[3], size[4], size[5] end
		end)
		if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
		local half = look.S / 2
		local limit = math.min(look.textX - look.cx - look.kit.TEXT_MARGIN, look.cx - look.kit.EDGE_MARGIN,
			p.height / 2 - look.kit.EDGE_MARGIN)
		local cap = limit / half
		for _, a in ipairs({ look.popIn, look.popSettle, look.bounceUp, look.bounceSettle }) do
			local from, to = scaleOf(a)
			for _, v in ipairs({ from[1], to[1] }) do
				if v > cap + 1e-6 and v > 1 + 1e-6 then
					fail(scenario, ("%s: the icon grows to %.3f, past the room's %.3f"):format(size[1], v, cap))
				end
			end
		end
		-- And at its largest it is inside the card's top and bottom edges.
		local grown = math.max(1, math.min(1.12, cap))
		if look.iconX + look.S / 2 + half * grown > look.textX - look.kit.TEXT_MARGIN + 1e-6 then
			fail(scenario, size[1] .. ": the grown icon reaches the text")
		end
		if look.S / 2 * grown > p.height / 2 - look.kit.EDGE_MARGIN + 1e-6 then
			fail(scenario, size[1] .. ": the grown icon passes the card's top or bottom")
		end
	end
end)

withTree("look-slate: every frame of Slate's is under the text", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local text = r.textLayer._level or 0
	for _, x in ipairs(look.own) do
		if x._kind == "Frame" and (x._level or 0) >= text then
			fail(scenario, "a frame of Slate's is at level " .. tostring(x._level) .. ", not under the text's " .. text)
		end
	end
	for _, f in ipairs(look.fx.frames) do
		if (f._level or 0) >= text then fail(scenario, "a ring's frame is not under the text") end
	end
	if (r.textLayer._level or 0) <= (r.art._level or 0) then fail(scenario, "the text is not above the art") end
end)

-- ------------------------------------------------------------------ 7
-- The cooldown line tracks the cooldown: it begins at what is left, from the
-- left edge, runs the time that is left, and goes when the cooldown does. The
-- sweep is drawn at no strength.
-- What a playing group does to its owner's width at `now`: the fraction a
-- scale from the left edge has got to.
local function smooth(t, how)
	if how == "IN" then return t * t end
	if how == "OUT" then return 1 - (1 - t) * (1 - t) end
	if how == "IN_OUT" then return 3 * t * t - 2 * t * t * t end
	return t
end

local function widthFraction(group, anim, now)
	if not group._playing then return nil end
	local t = (now - (group._startedAt or now)) / math.max(1e-6, anim._duration)
	t = math.max(0, math.min(1, t))
	local from, to = anim._scaleFrom or { 1, 1 }, anim._scaleTo or { 1, 1 }
	return from[1] + (to[1] - from[1]) * smooth(t, anim._smoothing)
end

withTree("look-slate: the cooldown line burns down with the cooldown", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local cd = r.cooldown
	if not cd then fail(scenario, "SKIPPED -- no cooldown frame") return end
	if look.coolBox._alpha and look.coolBox._alpha > 0.001 then fail(scenario, "the line is up with no cooldown running") end
	if (cd._alpha or 1) > 0.001 then fail(scenario, "the sweep is drawn: it should be at no strength") end
	-- A cast half a second ago, on a 1.5 s cooldown.
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.5, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	if not (look.coolScale._playing and look.coolRun._playing) then fail(scenario, "no line burns with a cooldown running") return end
	local anim = look.coolBurn
	if not near(anim._scaleFrom[1], 1 / 1.5, 0.03) then
		fail(scenario, ("the line starts at %.3f of its length, not the %.3f the cooldown has left"):format(anim._scaleFrom[1], 1 / 1.5))
	end
	if not near(anim._duration, 1.0, 0.03) then
		fail(scenario, ("the line runs %.3f s for a cooldown with 1.0 s left"):format(anim._duration))
	end
	if not (anim._origin and anim._origin[1] == "LEFT") then fail(scenario, "the line does not burn towards its left edge") end
	if not near(anim._scaleTo[2], 1) or not near(anim._scaleFrom[2], 1) then fail(scenario, "the line changes height as it burns") end
	if not near(look.coolBox._alpha, 1, 0.01) and not look.coolRun._playing then fail(scenario, "the line is not shown") end
	-- Half of what is left on, a third of the line is.
	Mock.advance(0.5)
	local f = widthFraction(look.coolScale, anim, GetTime())
	if not near(f, (1.5 - 1.0) / 1.5, 0.03) then
		fail(scenario, ("half a second on, %.3f of the line is left, not %.3f"):format(f or -1, 0.5 / 1.5))
	end
	-- Ready: the line is gone.
	Mock.advance(1)
	FT.settle()
	if look.coolScale._playing or look.coolRun._playing then fail(scenario, "the line is still burning when the cooldown ended") end
	if (look.coolBox._alpha or 0) > 0.001 then fail(scenario, "the line is left up after the cooldown ended") end
	-- A new cooldown while one runs moves the line to it.
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	Mock.advance(0.3)
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.1, duration = 1.0 } }
	ns.Prompt:SyncCooldown()
	if not near(anim._duration, 0.9, 0.04) or not near(anim._scaleFrom[1], 0.9, 0.05) then
		fail(scenario, ("a second cooldown did not restart the line: %.3f s from %.3f"):format(anim._duration, anim._scaleFrom[1]))
	end
	-- Cleared: the line stops at once.
	Mock.spellCooldowns = nil
	ns.Prompt:SyncCooldown()
	if look.coolScale._playing or (look.coolBox._alpha or 0) > 0.001 then fail(scenario, "a cleared cooldown left the line up") end
	-- No OnUpdate anywhere on the prompt, running or not.
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.2, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	local button = ns.Prompt:GetButton()
	for _, node in ipairs(FT.all) do
		local up = node._parent
		local onPrompt = false
		while up do
			if up == button then onPrompt = true end
			up = up._parent
		end
		if onPrompt and node ~= button and node.scripts and node.scripts.OnUpdate then
			fail(scenario, "a frame on the prompt has an OnUpdate while the line runs")
		end
	end
	-- Not on a panel with no icon, which has no cooldown.
	Mock.spellCooldowns = nil
	ns.Prompt:SyncCooldown()
	p.showIcon = false
	ns.Prompt:ApplyStyle()
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.2, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	look:Cool(Mock.now - 0.2, 1.5)
	if look.coolScale._playing then fail(scenario, "a cooldown line with no icon to cool") end
end)

withTree("look-slate: the line keeps burning on Calm and leaves with the look", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.2, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	if not look.coolScale._playing then fail(scenario, "Calm took the cooldown line away: it is information") end
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	if look.coolScale._playing or (look.coolBox._alpha or 0) > 0.001 then fail(scenario, "the line outlived the look") end
	if (r.cooldown._alpha or 1) < 0.99 then fail(scenario, "the sweep stayed at no strength on glass") end
	-- A cooldown on glass does not drive Slate's line.
	local plays0 = look.coolScale._plays or 0
	ns.Prompt:SyncCooldown()
	if (look.coolScale._plays or 0) ~= plays0 then fail(scenario, "Slate's line burned on another look") end
end)

-- ------------------------------------------------------------------ 8
-- The marker modes and the palettes: the pill and the ring wear the reason's
-- colour where the mode says, the neutral grey where it does not.
withTree("look-slate: the reason is carried where the mode says", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local carriers = ns.Looks.Get("slate").AccentCarriers
	for _, case in ipairs({
		{ "icon", true, false, true, false }, { "stripe", false, true, false, true },
		{ "both", true, true, true, true }, { "off", false, false, false, false },
	}) do
		local mode = case[1]
		p.accentMode = mode
		local ring, stripe = carriers(p)
		if ring ~= case[2] or stripe ~= case[3] then
			fail(scenario, ("%s: AccentCarriers says %s, %s"):format(mode, tostring(ring), tostring(stripe)))
		end
		for _, palette in ipairs({ "standard", "colourblind" }) do
			p.reasonPalette = palette
			ns.Prompt:ApplyStyle()
			for _, reason in ipairs(REASONS) do
				ns.Prompt:PaintAccent(reason)
				local cr, cg, cb = ns.Prompt:AccentColor(reason)
				local shown = look.barFrame._shown ~= false
				if shown ~= case[5] then fail(scenario, ("%s: the pill is %s"):format(mode, shown and "up" or "down")) end
				if mode ~= "off" then
					if shown and not sameColour(look.bar[2]._color, cr, cg, cb) then
						fail(scenario, ("%s, %s, %s: the pill is not in the reason's colour"):format(mode, palette, reason))
					end
					if case[4] and not sameColour(look.ring._color, cr, cg, cb) then
						fail(scenario, ("%s, %s, %s: the ring is not in the reason's colour"):format(mode, palette, reason))
					end
					if not case[4] and sameColour(look.ring._color, cr, cg, cb) and not (cr == cg and cg == cb) then
						fail(scenario, ("%s: the ring wears the reason's colour though the mode says it does not"):format(mode))
					end
					if not sameColour(look.glow._color, cr, cg, cb) then
						fail(scenario, ("%s, %s: the owed light is not in the reason's colour"):format(mode, reason))
					end
				else
					if not sameColour(look.bar[2]._color, 0.62, 0.67, 0.76) or sameColour(look.glow._color, cr, cg, cb) then
						fail(scenario, "with the marker off the pill or the light is still in the reason's colour: " .. reason)
					end
				end
			end
		end
	end
	-- One marker colour for every reason.
	p.accentMode, p.accentByReason, p.accentColor = "both", false, { 0.85, 0.35, 0.75, 1 }
	ns.Prompt:ApplyStyle()
	ns.Prompt:PaintAccent("owed")
	if not sameColour(look.ring._color, 0.85, 0.35, 0.75) then fail(scenario, "the chosen marker colour is not on the ring") end
end)

-- ------------------------------------------------------------------ 9
-- The outcomes: the name stays, the verdict is the second line with its glyph,
-- the line fills green for a buff and flashes for a refusal, the sent cast
-- claims nothing; and the next paint takes it all back.
withTree("look-slate: the outcomes write a verdict and play their own motion", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local fill, flare, bounce, tick_ = look.landFill, look.refuseFill, look.landing[2], look.landing[3]
	local fills, flares = look.landing[1]._plays or 0, look.refusal[1]._plays or 0
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local named = tostring(r.name:GetText())
	if not named:find("Anna", 1, true) or named:find("buffed", 1, true) then fail(scenario, "a landed buff moved the name: " .. named) end
	if r.sub:GetText() ~= "buffed" or look.glyph._shown == false or not tostring(look.glyph._file):find("Check", 1, true) then
		fail(scenario, "a landed buff's second line is not a ticked \"buffed\": " .. tostring(r.sub:GetText()))
	end
	if not sameColour(look.ring._color, 0.40, 0.86, 0.52) then fail(scenario, "a landed buff did not turn the ring green") end
	if (look.landing[1]._plays or 0) <= fills or (bounce._plays or 0) < 1 or (tick_._plays or 0) < 1 then
		fail(scenario, "a landed buff did not fill the line, bounce the icon and pop the tick")
	end
	if (look.refusal[1]._plays or 0) ~= flares then fail(scenario, "a landed buff flashed the refusal") end
	-- The fill is a scale from the left edge, green, within half a second.
	local grow = look.fillGrow
	if not (grow._origin and grow._origin[1] == "LEFT" and grow._scaleFrom[1] < 0.05 and near(grow._scaleTo[1], 1)) then
		fail(scenario, "the landing's fill does not slide from the left edge to the right")
	end
	if not sameColour(look.land[2]._color, 0.40, 0.86, 0.52) then fail(scenario, "the fill is not green") end
	if FT.groupLength(look.landing[1]) > 0.5 + 1e-6 then fail(scenario, "the fill lasts more than half a second") end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if r.sub:GetText() ~= "Out of range." or not tostring(look.glyph._file):find("Cross", 1, true) then
		fail(scenario, "a refusal is not the game's words with a cross: " .. tostring(r.sub:GetText()))
	end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	if (look.refusal[1]._plays or 0) <= flares then fail(scenario, "a refusal did not flash the line") end
	if not (sameColour(look.refuse[2]._color, 1.0, 0.40, 0.30) and look.refuse[2]._color[1] > look.refuse[2]._color[3]) then
		fail(scenario, "the refusal's flash is not red-amber")
	end
	-- The pill's shake sums to nothing and dies away.
	local shake, sum, steps = look.refusal[2], 0, {}
	for _, a in ipairs(shake._anims) do
		steps[#steps + 1] = { a._order, a._offset and a._offset[1] or 0 }
		sum = sum + (a._offset and a._offset[1] or 0)
	end
	table.sort(steps, function(a, b) return a[1] < b[1] end)
	if sum ~= 0 then fail(scenario, "the pill's shake does not end where it began: " .. sum) end
	if #steps < 5 or math.abs(steps[#steps][2]) >= math.abs(steps[2][2]) then fail(scenario, "the pill's shake does not die away") end
	if FT.groupLength(shake) > 0.35 then fail(scenario, "the pill's shake lasts more than 0.35 s") end
	Mock.advance(2)
	tick(ns)
	if look.glyph._shown ~= false or r.sub:GetText() == "Out of range." then fail(scenario, "the verdict outlived the outcome") end
	if r.icon._desaturated then fail(scenario, "the icon stayed grey after the refusal ran out") end
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not sameColour(look.ring._color, cr, cg, cb) then fail(scenario, "the ring kept the outcome's colour") end
	-- A cast nobody confirmed claims nothing.
	local before = plays(look.landing) + plays(look.refusal)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if plays(look.landing) + plays(look.refusal) ~= before then fail(scenario, "a cast nobody confirmed got a flourish") end
	if look.glyph._shown ~= false then fail(scenario, "a cast nobody confirmed got a tick") end
	-- Parked at nothing when they stop.
	ns.Prompt:StopFlourishes()
	FT.settle()
	for _, f in ipairs({ fill, flare }) do
		if (f._alpha or 0) > 0.001 then fail(scenario, "a stopped flourish left its line lit") end
	end
	if (r.icon._alpha or 1) < 0.999 then fail(scenario, "a stopped bounce left the icon see-through") end
end)

-- ------------------------------------------------------------------ 10
-- Calm is fades only; it plays no arrival, no landing, no refusal and nothing
-- loops.
withTree("look-slate: Calm plays none of the motion and loops nothing", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local before = plays(look.arrive) + plays(look.landing) + plays(look.refusal) + plays(look.pulse)
	-- A new favour reaching the panel, on Calm: the look is told, and plays nothing.
	look:Attention(true, true, "pulse")
	look:Attention(true, false, "once")
	owe(ns, "Bert Beside")
	Mock.advance(0.5)
	tick(ns)
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	Mock.advance(1)
	local after = plays(look.arrive) + plays(look.landing) + plays(look.refusal) + plays(look.pulse)
	if after ~= before then fail(scenario, "Calm played " .. (after - before) .. " of Slate's animations") end
	local _, loops = FT.playing()
	if #loops > 0 then fail(scenario, #loops .. " animation(s) loop on Calm") end
	if (look.glow._alpha or 0) > 0.001 or (look.warmFrame._alpha or 0) > 0.001 then fail(scenario, "Calm left the owed light lit") end
end)

-- ------------------------------------------------------------------ 11
-- The owed breath: three breaths and still, the light and the card's
-- highlight together, warm; gone with the favour and the outcome.
withTree("look-slate: the owed light breathes three times and holds", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	if not (look.pulse[1]._playing and look.pulse[2]._playing) then fail(scenario, "somebody owed and the light is not breathing") end
	local c = look.warmRing._color
	if not (c and c[1] > c[3]) then fail(scenario, "the second tone of the breath is not warm") end
	local breath = look.pulse[1]._anims[1]._duration
	if breath * 2 < 2 or breath * 2 > 3 then fail(scenario, ("the breath is %.2f s round"):format(breath * 2)) end
	if look.pulse[1]._looping ~= "BOUNCE" then fail(scenario, "the breath does not bounce") end
	-- Three of them, then still.
	Mock.advance(3 * breath * 2 + 0.5)
	Mock.runTimers()
	FT.settle()
	if look.pulse[1]._playing or (look.glow._alpha or 0) > 0.001 then fail(scenario, "the light is still breathing after its breaths") end
	-- A repaint of the same favour does not breathe again; a new favour does.
	tick(ns)
	if look.pulse[1]._playing then fail(scenario, "a repaint of the same favour started the breath again") end
	-- An outcome lets it go.
	owe(ns, "Anna Aim")
	look:Attention(true, false, "pulse")
	if not look.pulse[1]._playing then fail(scenario, "a new favour did not breathe") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if look.pulse[1]._playing then fail(scenario, "the breath went on over an outcome") end
	-- "Flash once" never loops; "none" does nothing.
	for _, style in ipairs({ "once", "off" }) do
		p.flashStyle = style
		look:Attention(true, true, style)
		if look.pulse[1]._playing then fail(scenario, "the breath played with the flash set to " .. style) end
	end
end)

-- ------------------------------------------------------------------ 12
-- The arrival is for a new favour, once, never over an outcome.
withTree("look-slate: the arrival plays once, for a new favour", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local n = plays(look.arrive)
	if n < 3 then fail(scenario, "somebody buffing you did not play the arrival: " .. n) end
	Mock.advance(0.4)
	tick(ns)
	Mock.advance(0.4)
	tick(ns)
	if plays(look.arrive) ~= n then fail(scenario, "the arrival played again on a repaint") end
	-- Over an outcome: no arrival.
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local m = plays(look.arrive)
	look:Attention(true, false, "pulse")
	if plays(look.arrive) ~= m then fail(scenario, "the arrival played over an outcome") end
	-- The arrival stays inside its time and inside the pill's place.
	for _, g in ipairs(look.arrive) do
		if FT.groupLength(g) > 0.5 then fail(scenario, ("an arrival's effect lasts %.2f s"):format(FT.groupLength(g))) end
	end
	-- The slide ends where the pill belongs: what it moves out, it moves back.
	local dx = 0
	for _, a in ipairs(look.arrive[2]._anims) do dx = dx + (a._offset and a._offset[1] or 0) end
	if dx ~= 0 then fail(scenario, "the pill's slide-in does not end at the pill's place: " .. dx) end
end)

-- ------------------------------------------------------------------ 13
-- A fight: the icon greys and dims by colour, the text dims, the ring, the pill
-- and the line keep their colour, the lights go out; it all comes back, and
-- leaving Slate in a fight leaves the icon as it was.
withTree("look-slate: in a fight the reason is the one colour left", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.accentMode = "both" end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local ring = { look.ring._color[1], look.ring._color[2], look.ring._color[3] }
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not r.icon._desaturated then fail(scenario, "the icon keeps its colour in a fight") end
	if (r.icon._alpha or 1) < 0.99 then fail(scenario, "the icon turned see-through in a fight") end
	if not (r.icon._color and r.icon._color[1] < 0.9) then fail(scenario, "the icon is not dimmed in a fight") end
	if not near(r.textLayer._alpha, 0.78) then fail(scenario, "the text does not dim in a fight") end
	if (r.art._alpha or 1) < 0.99 then fail(scenario, "art dimmed whole in a fight") end
	if not sameColour(look.ring._color, ring[1], ring[2], ring[3]) then fail(scenario, "the ring lost the reason's colour in a fight") end
	if look.pulse[1]._playing or (look.glow._alpha or 0) > 0.001 then fail(scenario, "the owed light is lit in a fight") end
	if (look.plate._color and look.plate._color[4] or 1) < 0.99 then fail(scenario, "nothing opaque under the icon in a fight") end
	-- Laid out again during the hold: the hold stays.
	look:Apply(ns.db.profile.prompt, false)
	if not r.icon._desaturated then fail(scenario, "laying the card out again during the hold put the colour back") end
	-- ...and the hold is still the look's: no light starts in the fight.
	local before = plays(look.arrive) + plays(look.pulse)
	look:Attention(true, true, "pulse")
	if plays(look.arrive) + plays(look.pulse) ~= before or look.pulse[1]._playing then
		fail(scenario, "laying the card out again during the hold let the light start in the fight")
	end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	if r.icon._desaturated or not near(r.textLayer._alpha or 1, 1) or (r.icon._color and r.icon._color[1] < 0.99) then
		fail(scenario, "the fight's dim stayed on after it ended")
	end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	Mock.inCombat = false
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	if r.icon._color and r.icon._color[1] < 0.99 then fail(scenario, "leaving Slate during a fight left the icon dimmed on glass") end
	if not near(r.textLayer._alpha or 1, 1) then fail(scenario, "leaving Slate during a fight left the text dimmed on glass") end
	if r.icon._desaturated then fail(scenario, "leaving Slate during a fight left the icon grey on glass") end
end)

-- ------------------------------------------------------------------ 13b
-- The cursor lifts the card's highlight and lets it go.
withTree("look-slate: the cursor lifts the card's highlight", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local rest = look.rimFrame._alpha
	if not (rest and rest > 0.3 and rest < 0.9) then fail(scenario, "the highlight does not rest between dim and full: " .. tostring(rest)) end
	local button = ns.Prompt:GetButton()
	button.scripts.OnEnter(button)
	Mock.advance(0.5)
	FT.settle()
	if not near(look.rimFrame._alpha, 1, 0.01) then fail(scenario, "the cursor did not lift the highlight: " .. tostring(look.rimFrame._alpha)) end
	button.scripts.OnLeave(button)
	Mock.advance(0.5)
	FT.settle()
	if not near(look.rimFrame._alpha, rest, 0.01) then fail(scenario, "the highlight did not settle back: " .. tostring(look.rimFrame._alpha)) end
	-- A card nearly clear has no shadow to hold on to.
	p.bgColor = { 0.04, 0.04, 0.06, 0.1 }
	ns.Prompt:ApplyStyle()
	if look.shadow[1]._color and look.shadow[1]._color[4] > 0.001 then fail(scenario, "a nearly clear card keeps its shadow") end
	p.bgColor = { 0.04, 0.04, 0.06, 0.9 }
	ns.Prompt:ApplyStyle()
	if not (look.shadow[1]._color and look.shadow[1]._color[4] > 0.2) then fail(scenario, "an opaque card has no shadow") end
end)

-- ------------------------------------------------------------------ 14
-- Leaving Slate gives every shared region back: the icon's mask, alpha and
-- colour, the cooldown's strength, the text's level and alpha, the lines' room.
withTree("look-slate: leaving Slate gives the shared regions back", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.2, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	tick(ns)
	local kit = look.kit
	if kit.fit.room[r.name] ~= nil or kit.fit.room[r.sub] ~= nil then fail(scenario, "glass fits its lines to the room Slate kept") end
	if r.icon._mask == look.mask then fail(scenario, "Slate's mask still shapes the icon on glass") end
	if (r.icon._alpha or 1) < 0.999 or (r.icon._color and r.icon._color[1] < 0.99) or r.icon._desaturated then
		fail(scenario, "the icon was not given back")
	end
	if (r.cooldown._alpha or 1) < 0.999 then fail(scenario, "the sweep was not given back its strength") end
	if not near(r.textLayer._alpha or 1, 1) then fail(scenario, "the text's alpha was not given back") end
	for _, x in ipairs(look.own) do
		if x._shown ~= false and x._kind ~= "FontString" then fail(scenario, "a piece of Slate's is still shown on glass") break end
	end
	-- Round trips leave nothing behind: the same count of regions after many.
	p.style = "slate"
	ns.Prompt:ApplyStyle()
	local count = #FT.all
	for _ = 1, 4 do
		p.style = "glass"
		ns.Prompt:ApplyStyle()
		p.style = "slate"
		ns.Prompt:ApplyStyle()
	end
	if #FT.all ~= count then fail(scenario, ("restyling made %d new regions"):format(#FT.all - count)) end
end)

-- ------------------------------------------------------------------ 15
-- The ground: a dark card by default, the hairline and the plate light on dark
-- and dark on light, and the reason line readable on both.
local function lum(r, g, b)
	local function lin(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end

local function contrast(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

withTree("look-slate: the text is readable on the card, dark or light", ANNA, function(ns, scenario)
	for _, ground in ipairs({
		{ "slate", nil }, { "a light panel", { 0.86, 0.84, 0.78, 0.92 } }, { "a mid-blue panel", { 0.30, 0.45, 0.80, 0.92 } },
		{ "a clear panel", { 0.04, 0.04, 0.06, 0.25 } },
	}) do
		for _, palette in ipairs({ "standard", "colourblind" }) do
			local r, p, look = upIn(ns, scenario, function(pp)
				if ground[2] then pp.bgColor = ground[2] end
				pp.reasonPalette = palette
				pp.fontColor = { 1, 1, 1, 1 }
			end)
			if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
			for _, reason in ipairs(REASONS) do
				ns.Prompt:PaintAccent(reason)
				-- The card where the reason line stands: the bottom colour,
				-- over a dusky world where the card is see-through.
				local b, a = look.bottom, look.alpha
				local function over(v) return v * a + 0.15 * (1 - a) end
				local card = lum(over(b[1]), over(b[2]), over(b[3]))
				local c = r.sub._textColor
				if not c then fail(scenario, "the reason line has no colour") return end
				local ratio = contrast(lum(c[1], c[2], c[3]), card)
				-- 4.5:1 where the card is opaque enough to judge; over a clear
				-- panel the world decides, and 3:1 is what the other looks hold.
				local need = a >= 0.5 and 4.4 or 3
				if ratio < need then
					fail(scenario, ("%s, %s, %s: the reason line is %.2f:1 on the card"):format(ground[1], palette, reason, ratio))
				end
			end
		end
	end
	local _, _, look = upIn(ns, scenario, function(pp) pp.bgColor = { 0.86, 0.84, 0.78, 0.92 } end)
	if look.rimColor[1] > 0.5 or look.plateColor[1] < 0.5 then fail(scenario, "on a light card the hairline is not dark and the plate light") end
	_, _, look = upIn(ns, scenario)
	if look.rimColor[1] < 0.5 or look.plateColor[1] > 0.5 then fail(scenario, "on a dark card the hairline is not light and the plate dark") end
	-- The card's own slate is dark enough for the dimmest reason line.
	local top, bottom = look.top, look.bottom
	if lum(top[1], top[2], top[3]) > 0.02 or lum(bottom[1], bottom[2], bottom[3]) > 0.02 then fail(scenario, "the card's slate is not dark") end
end)

-- ------------------------------------------------------------------ 16
-- Nothing that stays on screen is additive.
withTree("look-slate: no additive light at rest", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	for _, t in ipairs(look.own) do
		if t._blend == "ADD" then fail(scenario, "a texture of Slate's is additive: " .. tostring(t._file)) end
	end
	-- The rings are the shared ones: one-shots, gone at rest.
	Mock.advance(9)
	Mock.runTimers()
	FT.settle()
	for _, ring in ipairs(look.fx.rings) do
		if ring.land._playing or (ring.frame._alpha or 0) > 0.001 then fail(scenario, "a ring is lit at rest") end
	end
	local _, loops = FT.playing()
	if #loops > 0 then fail(scenario, #loops .. " animation(s) still loop at rest") end
end)

-- ------------------------------------------------------------------ 17
-- The art: 32-bit uncompressed TGAs, power-of-two sides to 256, every file the
-- look names shipped, and the generator draws the same bytes twice, and the
-- bytes that ship.
local function header(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local h = f:read(18)
	f:close()
	if not h or #h < 18 then return nil end
	local b = { h:byte(1, 18) }
	return { imageType = b[3], width = b[13] + b[14] * 256, height = b[15] + b[16] * 256, bits = b[17] }
end

local function powerOfTwo(n)
	if n < 1 then return false end
	while n % 2 == 0 do n = n / 2 end
	return n == 1
end

local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-slate-" .. token .. "-" .. tostring(os.time())
end

local python = os.getenv("MANNERS_PYTHON") or "python"

withTree("look-slate: the generator draws the same bytes twice, and the bytes that ship", ANNA, function(_, scenario)
	local a, b = tempDir() .. "-a", tempDir() .. "-b"
	-- os.execute and a log file rather than io.popen, which the Lua that lupa
	-- builds on Linux leaves out.
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/make_slate_textures.py" --out "' .. out .. '" > "' .. log .. '" 2>&1')
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
	if #names < 14 then fail(scenario, "the generator wrote " .. #names .. " files: " .. outA:sub(1, 200)) return end
	for _, file in ipairs(names) do
		local one, two = slurp(a .. "/" .. file), slurp(b .. "/" .. file)
		local ships = slurp(dir .. "/Textures/Slate/" .. file)
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
	-- Every file in Textures/Slate is one the generator draws.
	local drawn = {}
	for _, file in ipairs(names) do drawn[file] = true end
	for _, file in ipairs({ "Slate_Card", "Slate_Rim", "Slate_Shadow", "Slate_Pill", "Slate_PillV", "Slate_IconMask",
		"Slate_IconMaskRound", "Slate_IconRing", "Slate_IconRingRound", "Slate_IconGlow", "Slate_IconGlowRound",
		"Slate_FxRing", "Slate_FxRingRound", "Slate_Check", "Slate_Cross", "Slate_Dot" }) do
		if not drawn[file .. ".tga"] then fail(scenario, file .. " is not drawn by the generator") end
		if not slurp(dir .. "/Textures/Slate/" .. file .. ".tga") then fail(scenario, file .. " is not in the package") end
	end
end)

-- Every texture the look draws is one of those files.
withTree("look-slate: every texture is from Textures/Slate", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	for _, round in ipairs({ false, true }) do
		p.roundIcon = round
		ns.Prompt:ApplyStyle()
		tick(ns)
		ns.Prompt:ShowOutcome("cast", "Anna Aim")
		ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
		for _, t in ipairs(look.own) do
			if t._kind == "Texture" and t._file then
				local rel = tostring(t._file):match("^Interface\\AddOns\\Manners\\(.+)$")
				if not rel or not rel:find("^Textures\\Slate\\Slate_") then
					fail(scenario, "a texture of Slate's is from " .. tostring(t._file))
				elseif not slurp(dir .. "/" .. rel:gsub("\\", "/") .. ".tga") then
					fail(scenario, tostring(t._file) .. " is not shipped")
				end
			end
		end
	end
end)

-- ------------------------------------------------------------------ 18
-- The mask is the icon's shape: rounded, or round with "Round the icon", and
-- the plate and the ring agree with it.
withTree("look-slate: the icon is rounded, and round on request", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	for _, round in ipairs({ false, true, false }) do
		p.roundIcon = round
		ns.Prompt:ApplyStyle()
		local want = round and "IconMaskRound" or "IconMask"
		if not tostring(look.mask._file):find(want .. "$") and not tostring(look.mask._file):find(want, 1, true) then
			fail(scenario, "the icon's mask is not " .. want)
		end
		if r.icon._mask ~= look.mask then fail(scenario, "the icon is not masked") end
		if not tostring(look.plate._file):find(want, 1, true) then fail(scenario, "the plate is not the icon's shape") end
		if not tostring(look.ring._file):find(round and "IconRingRound" or "IconRing$") then
			fail(scenario, "the ring is not the icon's shape")
		end
		if r.cooldown and r.cooldown._circular ~= round then fail(scenario, "the sweep's edge does not follow the shape") end
		local fxArt = look.fx.rings[1].art
		if not fxArt or not tostring(look.fx.rings[1].tex._file):find(round and "FxRingRound" or "FxRing$") then
			fail(scenario, "the rings are not in the icon's shape")
		end
	end
	-- Icon off: no mask, no ring, no light, no rings.
	p.showIcon = false
	ns.Prompt:ApplyStyle()
	if look.ring._shown ~= false or look.plate._shown ~= false or look.glow._shown ~= false then
		fail(scenario, "the icon's ring, plate or light stayed with the icon off")
	end
	for _, f in ipairs(look.fx.frames) do
		if f._shown ~= false then fail(scenario, "a ring's frame stayed up with the icon off") end
	end
end)

-- ------------------------------------------------------------------ 19
-- The look's own options: nothing it cannot honour. The icon slider is the
-- slider's; the carriers are stated.
withTree("look-slate: the options page can state what Slate does", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("slate")
	local p = ns.db and ns.db.profile and ns.db.profile.prompt or ns.defaults.profile.prompt
	for _, mode in ipairs({ "icon", "stripe", "both", "off" }) do
		local ring, stripe = look.AccentCarriers({ accentMode = mode, showIcon = true })
		if (ring ~= true and ring ~= false) or (stripe ~= true and stripe ~= false) then
			fail(scenario, mode .. ": AccentCarriers does not answer true or false")
		end
	end
	if look.IconSize then fail(scenario, "Slate sizes the icon itself; the slider should") end
	local h = look.TwoLineHeight(13)
	if h > 44 then fail(scenario, "two lines at the default font need " .. h .. ", more than the default 44") end
	if h ~= ns.TwoLineHeight(13, "slate") then fail(scenario, "Prompt and Slate disagree about two lines") end
	if look.TwoLineHeight(17) <= look.TwoLineHeight(11) then fail(scenario, "two lines need no more at a big font") end
	_ = p
end)
