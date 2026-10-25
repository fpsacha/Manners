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
--   * the layout: the plate, its slanted ends, the lines, the tag, the icon,
--     the chips and the ledge sit inside the width and height the prompt is
--     given and apart from one another, at every size and scale from 160 to
--     400 wide, with the icon on and off, in every marker mode, and the slant
--     never cuts a line of text or the tag at any of them;
--   * nothing is rounded: the art's corners are sharp, the icon is a hexagon
--     whatever "Round the icon" says, and the slant in the art is the slant the
--     code lays it out for;
--   * the secure list names hang off frames, never off a region, each on a
--     strip with a notch in its reason's colour;
--   * every frame of light is under the text, and nothing that moves over the
--     text is scaled;
--   * the cooldown bar: a segment for each step, each dropping out at its share
--     of what is left, the last at the moment the button is ready, with no
--     frame script, kept on Calm and gone with the look;
--   * the accent (blade, ledge, tag, icon's line) carries the reason's colour
--     where the mode says, steel in a fight, and the tag's ink holds it;
--   * the outcomes, the arrival, the owed breath, Calm, the fight, leaving the
--     look;
--   * capitals on ASCII letters only, outside the game's escapes, and only
--     while Slate is the look in use;
--   * the condensed face, unless the player chose a font or the client writes
--     in an alphabet it lacks;
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
-- The slant and the width of a plate's end, which the code and the art share.
local SLANT, CAP = 0.28, 0.75

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
		"effects", "flashStyle", "width", "height", "fontSize", "iconSize", "scale", "showQueue", "showCount", "font" }) do
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
	return look ~= nil and look.key == "slate" and look.warmRing ~= nil and look.segs ~= nil
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
	-- The name and the line in all eight translations, read from the files (the
	-- client loads one of them).
	for _, code in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
		local text = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
		for _, english in ipairs({ look.name, look.description }) do
			local key = 'L["' .. english .. '"] = "'
			local at = text:find(key, 1, true)
			local line = at and text:sub(at + #key):match("^([^\n]*)")
			if not at or not line or #line < 4 then fail(scenario, code .. " has no translation of \"" .. english .. "\"") end
			if at and line and line:find("Slate", 1, true) then fail(scenario, code .. " left the look's name in English") end
			if at and line and line:find(english, 1, true) then fail(scenario, code .. " left \"" .. english .. "\" in English") end
		end
	end
	if look.order == nil then fail(scenario, "the look has no place in the dropdown") end
	if look.title ~= "Slate" or type(look.description) ~= "string" or look.description == "" then
		fail(scenario, "the picker's card has no title and line of its own")
	end
	local old = (slurp(dir .. "/Locales/deDE.lua") or ""):find("soft shadow, thin progress line", 1, true)
	if old then fail(scenario, "a translation of the old description is still kept") end
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
-- The layout. Everything the plate holds sits inside the width and height the
-- prompt is given and apart from the rest, and the slant never cuts a line of
-- text or the tag: at every size and width, icon on and off, in every marker
-- mode and at the ends of the scale.
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

-- Where the plate's two slanted edges are at `y` down from its top, in units
-- from its left, for a plate `hp` tall and `W` wide.
local function plateLeft(hp, y) return SLANT * (hp - y) end
local function plateRight(W, y) return W - SLANT * y end

-- The art's frame as units from its top left, y down: a box's four corners.
-- Divided by the scale the prompt is shown at, so a box is in the units the look lays it out in.
local function relative(art, look)
	local k = (art[3] - art[1]) / look.W
	return function(b) return { (b[1] - art[1]) / k, (art[4] - b[4]) / k, (b[3] - art[1]) / k, (art[4] - b[2]) / k } end
end

local function layoutAt(ns, scenario, label, edit, ctx)
	local r, p, look = upIn(ns, scenario, edit)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	ctx.n = ctx.n + 1
	local art = span(r.art)
	local rel = relative(art, look)
	local name, sub = span(r.name), r.sub:IsShown() and span(r.sub) or nil
	if not (art and name) then fail(scenario, label .. ": nothing to measure") return end
	local W, hp = look.W, look.hp
	if not inside(name, art) then fail(scenario, label .. ": the name is outside the prompt's box") end
	if sub and not inside(sub, art) then fail(scenario, label .. ": the reason line is outside the prompt's box") end
	if sub and not apart(name, sub, 0.3) then fail(scenario, label .. ": the name and the reason line overlap") end
	-- Every piece of the plate is inside the box the prompt is given.
	local pieces = { plate = look.plate[1], plateMiddle = look.plate[2], plateEnd = look.plate[3], hatch = look.hatch,
		ledge = look.ledge[2], blade = look.blade, edge = look.edge[1], wash = look.wash[3], ghost = look.ghosts[1][3],
		streak = look.streak, band = look.band }
	for what, t in pairs(pieces) do
		local b = span(t)
		if b and not inside(b, art, 0.3) then fail(scenario, label .. ": the " .. what .. " is outside the prompt's box") end
	end
	for what, f in pairs({ tag = look.tagFrame, cool = look.coolBox, bladeFrame = look.bladeFrame, key = look.keyBox,
		count = look.chipBox }) do
		local b = span(f)
		if f._shown ~= false and b and not inside(b, art, 0.3) then
			fail(scenario, label .. ": the " .. what .. " is outside the prompt's box")
		end
	end
	-- The plate and the ledge: the plate is the height less the ledge.
	local plate, ledge = span(look.plate[2]), span(look.ledge[2])
	local k = (art[3] - art[1]) / look.W
	local want = math.min(6, math.max(3, math.floor(p.height / 11 + 0.5)))
	if plate and ledge and not (near((ledge[4] - ledge[2]) / k, want, 0.05) and near((plate[4] - plate[2]) / k, p.height - want, 0.05)) then
		fail(scenario, label .. ": the plate and its ledge do not fill the prompt's height")
	end
	-- The lines never meet the slant: the name's box (from where it starts to where it must
	-- end) lies inside the plate's two edges at its top and its bottom.
	local n = rel(name)
	for _, y in ipairs({ n[2], n[4] }) do
		if n[3] > plateRight(W, y) - 1 + 1e-6 then
			fail(scenario, ("%s: the slant cuts the name's room at %.1f down: it runs to %.1f, the edge is at %.1f"):format(
				label, y, n[3], plateRight(W, y)))
		end
		if n[1] < plateLeft(hp, math.min(y, hp)) + 2 - 1e-6 then
			fail(scenario, ("%s: the name starts at %.1f, inside the left slant (%.1f) at %.1f down"):format(
				label, n[1], plateLeft(hp, math.min(y, hp)), y))
		end
	end
	local parts = {}
	if p.showIcon then
		parts.icon = span(r.icon)
		if parts.icon and not inside(parts.icon, art) then fail(scenario, label .. ": the icon is outside the prompt's box") end
		if parts.icon and not apart(parts.icon, name, 3) then
			fail(scenario, label .. ": the name runs into the icon")
		end
		-- The icon's left edge (its slant) clears the blade's thin slash.
		local i = rel(parts.icon)
		local blade = (0.15 + 0.07 + 0.045) * hp
		local top, bottom = i[2], i[4]
		if i[1] + SLANT * (bottom - top) < blade + SLANT * (hp - top) + 2 - 1e-6 then
			fail(scenario, label .. ": the icon runs into the blade")
		end
		for _, t in ipairs({ look.iconPlate, look.iconEdge, look.iconFlash }) do
			local b = span(t)
			if b and not inside(b, art, 0.3) then fail(scenario, label .. ": the icon's frame is outside the prompt's box") end
		end
	end
	-- The tag: a slanted bar whose four corners are inside the plate, clear of
	-- the icon, and under the name.
	if look.tagFrame._shown ~= false and sub then
		local t = rel(span(look.tagFrame))
		local h = t[4] - t[2]
		if t[3] > plateRight(W, t[2]) - 1 + 1e-6 then
			fail(scenario, ("%s: the tag's top right corner is past the plate's edge (%.1f, the edge %.1f)"):format(
				label, t[3], plateRight(W, t[2])))
		end
		if t[3] - SLANT * h > plateRight(W, t[4]) - 1 + 1e-6 then fail(scenario, label .. ": the tag's bottom right corner is past the plate's edge") end
		if t[1] < plateLeft(hp, math.min(t[4], hp)) + 1 - 1e-6 then fail(scenario, label .. ": the tag's left corner is past the plate's edge") end
		if parts.icon then
			local i = rel(parts.icon)
			for _, y in ipairs({ t[2], t[4] }) do
				local tagLeft = t[1] + SLANT * (t[4] - y)
				local iconRight = i[3] - SLANT * math.max(0, y - i[2])
				if y >= i[2] and y <= i[4] and tagLeft < iconRight + 1 - 1e-6 then
					fail(scenario, ("%s: the tag runs into the icon at %.1f down"):format(label, y))
				end
			end
		end
		if not apart(name, span(look.tagFrame), 0.3) then fail(scenario, label .. ": the tag overlaps the name") end
		-- The words stand inside the tag, a pad from either slanted end.
		local s = rel(sub)
		if s[1] < t[1] + SLANT * h / 2 + 2 - 1e-6 then fail(scenario, label .. ": the reason starts inside the tag's slant") end
		local words = r.sub:GetStringWidth()
		if type(words) == "number" and words <= s[3] - s[1] + 0.5 and t[3] - SLANT * h / 2 < s[1] + words + 3 - 1e-6 then
			fail(scenario, label .. ": the tag does not hold its words")
		end
	end
	if not p.showIcon then
		for _, t in ipairs({ look.iconPlate, look.iconEdge, look.iconFlash }) do
			if t._shown ~= false then fail(scenario, label .. ": the icon's frame stayed with the icon off") end
		end
		for _, f in ipairs(look.fx.frames) do
			if f._shown ~= false then fail(scenario, label .. ": a ring's frame stayed up with the icon off") end
		end
	end
	-- The ledge is under the plate and clear of the lines and the icon.
	local line = span(look.coolBox)
	if line then
		if sub and not apart(sub, line, 0.2) then fail(scenario, label .. ": the ledge runs through the reason line") end
		if not apart(name, line, 0.2) then fail(scenario, label .. ": the ledge runs through the name") end
		if parts.icon and not apart(parts.icon, line, 0.2) then fail(scenario, label .. ": the ledge runs under the icon") end
	end
	-- Never the same text twice over: the name is not wider than the prompt.
	if name[3] - name[1] > art[3] - art[1] then fail(scenario, label .. ": the name is wider than the prompt") end
end

withTree("look-slate: the layout holds at every size, in every mode, and the slant cuts nothing", CROWD, function(ns, scenario)
	local ctx = { n = 0 }
	local modes = { "icon", "stripe", "both", "off" }
	for _, W in ipairs({ 160, 220, 400 }) do
		for _, Hh in ipairs({ 32, 44, 72 }) do
			for _, icon in ipairs({ true, false }) do
				for mi, mode in ipairs(modes) do
					local label = ("%dx%d, icon %s, %s"):format(W, Hh, tostring(icon), mode)
					layoutAt(ns, scenario, label, function(p)
						p.width, p.height, p.fontSize = W, Hh, 13
						p.iconSize = math.min(30, Hh - 8)
						p.showIcon, p.accentMode = icon, mode
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
	layoutAt(ns, scenario, "160x36 icon 24 font 24", function(p)
		p.width, p.height, p.fontSize, p.iconSize = 160, 36, 24, 24
	end, ctx)
	for _, scale in ipairs({ 0.7, 1.6 }) do
		layoutAt(ns, scenario, "scale " .. scale, function(p) p.scale = scale end, ctx)
	end
	-- Every width from 160 to 400 at the default height, with the long reason of
	-- a long translation on the tag.
	for W = 160, 400, 16 do
		layoutAt(ns, scenario, "width " .. W, function(p) p.width = W end, ctx)
		local r, look = ns.Prompt:Regions(), ns.Prompt:Regions().look
		-- With nothing else waiting (no chip at the right) and with two more.
		for _, others in ipairs({ 0, 2 }) do
			ns.Prompt:Paint({ name = "Anna Aim", short = "Anna", reason = "nearby", buff = ns.ResolveBuff(true) }, others)
			ns.Prompt.lib.SetLine(r.sub, "needs Arcane Intellect, and a good deal more besides")
			FT.settle()
			local art = span(r.art)
			local t = relative(art, look)(span(look.tagFrame))
			local Wd = look.W
			if t[3] > plateRight(Wd, t[2]) - 1 + 1e-6 then
				fail(scenario, ("width %d, %d waiting: a long reason's tag is past the plate's slanted edge (%.1f, the edge %.1f)"):format(
					W, others, t[3], plateRight(Wd, t[2])))
			end
		end
		ctx.n = ctx.n + 1
	end
	if ctx.n < 100 then fail(scenario, "only " .. ctx.n .. " layouts were measured") end
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
	-- The chip's own right end is held in by the plate's slant.
	local art = span(r.art)
	local rel = relative(art, look)
	local c = rel(span(look.chipBox))
	local Wd = look.W
	if c[3] > plateRight(Wd, c[2]) - 1 + 1e-6 then fail(scenario, "the count chip is past the plate's slanted edge") end
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
	for width = 120, 400, 5 do
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
withTree("look-slate: a German client's lines fit the plate", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.width, pp.height = 180, 44 end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local art = span(r.art)
	-- A reason that is a little too long at its size, and one that is not.
	for _, text in ipairs({ "Arkane Intelligenz xx", "Kurz" }) do
		ns.Prompt:Paint({ name = "Anna Aim", short = "Annabelle", reason = "owed", buff = ns.ResolveBuff(true) }, 2)
		ns.Prompt.lib.SetLine(r.sub, text)
		FT.settle()
		local sub = span(r.sub)
		if not (sub and inside(sub, art)) then fail(scenario, "the reason line leaves the prompt") end
		local right = r.sub.points[#r.sub.points]
		if not (right and right[1] == "RIGHT" and right[2] <= -12 + 1e-6) then
			fail(scenario, "the reason line has no room kept at the right")
		end
		-- Fitted: drawn smaller before it is cut, and never wider than its room.
		local size = select(2, r.sub:GetFont())
		if type(size) == "number" and size < 7 then fail(scenario, "the line shrank below 7") end
		local room = (sub and sub[3] - sub[1]) or 0
		local width = r.sub:GetUnboundedStringWidth()
		local least = math.max(7, math.floor(look.kit.fit.base[r.sub] * 0.8 + 0.5))
		if type(width) == "number" and width > room + 0.6 and type(size) == "number" and size > least then
			fail(scenario, ("a line %.1f wide in a room of %.1f was not fitted (size %s)"):format(width, room, tostring(size)))
		end
		-- The tag is as wide as the words and a pad, and no wider than the room.
		local tag = span(look.tagFrame)
		if not (tag and inside(tag, art, 0.3)) then fail(scenario, "the tag leaves the prompt") end
	end
	local base = look.kit.fit.base[r.sub]
	ns.Prompt.lib.SetLine(r.sub, "Arkane Intelligenz xx")
	if select(2, r.sub:GetFont()) >= base then fail(scenario, "a long reason line was not drawn smaller to fit") end
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Das Ziel ist außer Reichweite, und noch ein langer Satz dahinter.")
	FT.settle()
	local sub = span(r.sub)
	if not (sub and inside(sub, art)) then fail(scenario, "a long refusal leaves the prompt") end
	-- The tag follows its words.
	local tagW = span(look.tagFrame)
	if tagW and sub and tagW[3] - tagW[1] < (sub[3] - sub[1]) * 0 + 4 then fail(scenario, "the tag has no width") end
end, function() Mock.locale = "deDE" end)

-- ------------------------------------------------------------------ 5
-- The list: a strip for each row, each a step further in, with a notch in the
-- row's reason colour; the names are buttons hung off frames, never off a
-- region; the strips sit clear of the plate above or below.
withTree("look-slate: the list is a stack of slanted strips with notches", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local art = span(r.art)
	local function stripBox(i)
		local s = look.strips[i]
		local a, b = span(s.plate[1]), span(s.plate[3])
		if not (a and b) then return nil end
		return { a[1], math.min(a[2], b[2]), b[3], math.max(a[4], b[4]) }
	end
	local function check(side)
		local rows, lastX, lastY = 0, nil, nil
		for i, fs in ipairs(r.rows) do
			if fs._text and fs._text ~= "" then
				rows = rows + 1
				local strip, b = stripBox(i), span(fs)
				local s = look.strips[i]
				if not strip or s.plate[2]._shown == false then fail(scenario, side .. ": row " .. i .. " has no strip") return end
				if side == "below" and not (strip[4] <= art[2] - 2.5) then fail(scenario, "the strips below touch the plate") end
				if side == "above" and not (strip[2] >= art[4] + 2.5) then fail(scenario, "the strips above touch the plate") end
				if b and not inside(b, strip, 0.5) then fail(scenario, side .. ": row " .. i .. " is outside its strip") end
				-- The strip is slanted as the plate is: its height is the row's, its end
				-- the plate's third of the height wide.
				local h = strip[4] - strip[2]
				local cap = span(s.plate[1])
				if not near(cap[3] - cap[1], CAP * h, 0.05) then
					fail(scenario, side .. ": row " .. i .. "'s strip has its ends " .. (cap[3] - cap[1]) .. " wide, not " .. CAP * h)
				end
				-- The notch is in the row's reason's colour, on the strip's left.
				local notch = span(s.notch)
				local known = false
				for _, reason in ipairs(REASONS) do
					local c = ns.Prompt.lib.ReasonColor(reason)
					if s.notch._color and sameColour(s.notch._color, c[1], c[2], c[3]) then known = true end
				end
				if not known or s.notch._shown == false then fail(scenario, side .. ": row " .. i .. " has no notch in a reason's colour") end
				if notch and not (notch[1] >= strip[1] - 0.05 and notch[3] <= b[1]) then
					fail(scenario, side .. ": row " .. i .. "'s notch is not between the strip's end and its name")
				end
				-- Each strip a step further in than the last.
				if lastX and not (strip[1] > lastX + 1) then fail(scenario, side .. ": the strips do not step in") end
				lastX = strip[1]
				if lastY and not (math.abs(strip[2] - lastY) > 0.5) then fail(scenario, side .. ": two strips on one line") end
				lastY = strip[2]
				local button = r.rowButtons[i]
				local at = button.points[1]
				if not (at and (at[2] == r.art or at[2] == ns.Prompt:GetButton())) then
					fail(scenario, side .. ": row " .. i .. "'s button hangs off something that is not a frame")
				end
				-- The click area covers the notch and the name.
				local area = span(button)
				if area and b and not (area[1] <= notch[1] + 0.5 and area[3] >= b[1]) then
					fail(scenario, side .. ": row " .. i .. "'s click area misses its notch or its name")
				end
			end
		end
		if rows == 0 then fail(scenario, side .. ": no rows were written") end
		for i = rows + 1, #look.strips do
			if look.strips[i].plate[2]._shown ~= false or look.strips[i].notch._shown ~= false then
				fail(scenario, side .. ": a strip with no row")
			end
		end
	end
	check("below")
	Mock.promptCentreY = 40
	ns.Prompt:ApplyStyle()
	tick(ns)
	check("above")
	-- A list that empties between two restyles takes its strips with it.
	look:PaintQueue(nil, 0, false)
	for _, s in ipairs(look.strips) do
		if s.plate[2]._shown ~= false or s.notch._shown ~= false then fail(scenario, "a strip stayed when the list went") end
	end
	ns.Prompt:ApplyStyle()
	tick(ns)
	-- No list, no strips.
	p.showQueue = false
	ns.Prompt:ApplyStyle()
	tick(ns)
	for _, s in ipairs(look.strips) do
		if s.plate[2]._shown ~= false or s.notch._shown ~= false then fail(scenario, "a strip stayed when the list went") end
	end
	-- Icon off: the names still stand beyond their notches.
	p.showQueue, p.showIcon = true, false
	Mock.promptCentreY = nil
	ns.Prompt:ApplyStyle()
	tick(ns)
	local notch, row = span(look.strips[1].notch), span(r.rows[1])
	if look.strips[1].notch._shown == false or not (notch and row and notch[3] <= row[1]) then
		fail(scenario, "with the icon off the notch is not beside its name")
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
-- Every frame of Slate's is under the text, and nothing it moves over the text
-- is scaled (a slide and a fade do not need the room the rings are held to).
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
	-- No scale among the look's own animations: they all cross the text's room.
	for i, g in ipairs(look.anims) do
		for _, a in ipairs(g._anims or {}) do
			if a._kind == "Scale" then fail(scenario, "animation " .. i .. " of Slate's scales: it would cross the text") end
		end
	end
end)

-- ------------------------------------------------------------------ 7
-- The cooldown bar tracks the cooldown: every segment is lit, each drops out at
-- its share of what is left (the leftmost at the moment the button is ready),
-- the bar goes when the cooldown does, and nothing polls. The sweep is drawn at
-- no strength.
withTree("look-slate: the cooldown bar drops a segment at a time with the cooldown", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local cd = r.cooldown
	if not cd then fail(scenario, "SKIPPED -- no cooldown frame") return end
	if look.coolBox._alpha and look.coolBox._alpha > 0.001 then fail(scenario, "the bar is up with no cooldown running") end
	if (cd._alpha or 1) > 0.001 then fail(scenario, "the sweep is drawn: it should be at no strength") end
	local n = look.segCount
	if not (n >= 4 and n <= #look.segs) then fail(scenario, "the bar has " .. tostring(n) .. " segments") return end
	-- Segments are shown for the width, and no more.
	for i, seg in ipairs(look.segs) do
		if (seg.tex._shown ~= false) ~= (i <= n) then fail(scenario, "segment " .. i .. " is shown or hidden against the count of " .. n) end
	end
	-- A cast half a second ago, on a 1.5 s cooldown: 1.0 s is left, two thirds.
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.5, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	if not look.coolRun._playing then fail(scenario, "no bar is up with a cooldown running") return end
	if not near(look.coolHold._duration, 1.0, 0.03) then
		fail(scenario, ("the bar stays up %.3f s for a cooldown with 1.0 s left"):format(look.coolHold._duration or -1))
	end
	local lit, last, firstGone = 0, 0, nil
	for i = 1, n do
		local seg = look.segs[i]
		local share = (i - 1) / n
		if share < (1.0 / 1.5) then
			lit = lit + 1
			if not seg.group._playing then fail(scenario, "segment " .. i .. " is lit and has no fade coming") end
			if not near(seg.tex._alpha, 1) then fail(scenario, "segment " .. i .. " is not lit") end
			local want = 1.0 - share * 1.5
			if not near(seg.drop._startDelay, want, 0.03) then
				fail(scenario, ("segment %d drops out after %.3f s, not the %.3f its share of the cooldown asks"):format(
					i, seg.drop._startDelay or -1, want))
			end
			-- The right-hand segments go first.
			if seg.drop._startDelay and i > 1 and look.segs[i - 1].drop._startDelay
				and not (seg.drop._startDelay < look.segs[i - 1].drop._startDelay) then
				fail(scenario, "segment " .. i .. " does not drop out before the one to its left")
			end
		else
			if seg.group._playing or (seg.tex._alpha or 0) > 0.001 then
				fail(scenario, "segment " .. i .. " is lit though the cooldown has run past it")
			end
			firstGone = firstGone or i
		end
		last = i
	end
	if lit < 2 or lit >= n then fail(scenario, "two thirds of a cooldown left lights " .. lit .. " of " .. n) end
	-- The left-most segment goes out at the moment the button is ready.
	if not near(look.segs[1].drop._startDelay, 1.0, 0.03) then fail(scenario, "the first segment does not go out when the button is ready") end
	-- Half a second on: the last of the lit ones has dropped, the first has not.
	Mock.advance(0.5)
	FT.settle()
	if not look.segs[1].group._playing and (look.segs[1].tex._alpha or 0) < 0.001 then fail(scenario, "the first segment dropped out early") end
	-- Ready: the bar is gone.
	Mock.advance(1)
	FT.settle()
	if look.coolRun._playing or (look.coolBox._alpha or 0) > 0.001 then fail(scenario, "the bar is left up after the cooldown ended") end
	for i = 1, n do
		if look.segs[i].group._playing then fail(scenario, "segment " .. i .. " is still dropping when the cooldown ended") end
	end
	-- A new cooldown while one runs moves every segment to it.
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	Mock.advance(0.3)
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.1, duration = 1.0 } }
	ns.Prompt:SyncCooldown()
	if not near(look.coolHold._duration, 0.9, 0.04) or not near(look.segs[1].drop._startDelay, 0.9, 0.04) then
		fail(scenario, ("a second cooldown did not restart the bar: %.3f s, the first segment out at %.3f"):format(
			look.coolHold._duration or -1, look.segs[1].drop._startDelay or -1))
	end
	-- Cleared: the bar stops at once.
	Mock.spellCooldowns = nil
	ns.Prompt:SyncCooldown()
	if look.coolRun._playing or (look.coolBox._alpha or 0) > 0.001 then fail(scenario, "a cleared cooldown left the bar up") end
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
			fail(scenario, "a frame on the prompt has an OnUpdate while the bar runs")
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
	if look.coolRun._playing then fail(scenario, "a cooldown bar with no icon to cool") end
end)

withTree("look-slate: the bar keeps counting on Calm and leaves with the look", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.effects = "calm" end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	Mock.spellCooldowns = { [61304] = { startTime = Mock.now - 0.2, duration = 1.5 } }
	ns.Prompt:SyncCooldown()
	if not look.coolRun._playing or not look.segs[1].group._playing then fail(scenario, "Calm took the cooldown bar away: it is information") end
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	if look.coolRun._playing or (look.coolBox._alpha or 0) > 0.001 or look.segs[1].group._playing then
		fail(scenario, "the bar outlived the look")
	end
	if (r.cooldown._alpha or 1) < 0.99 then fail(scenario, "the sweep stayed at no strength on glass") end
	-- A cooldown on glass does not drive Slate's bar.
	local plays0 = look.coolRun._plays or 0
	ns.Prompt:SyncCooldown()
	if (look.coolRun._plays or 0) ~= plays0 then fail(scenario, "Slate's bar counted on another look") end
end)

-- ------------------------------------------------------------------ 8
-- The accent: the blade, the ledge, the tag and (where the mode says) the icon's
-- line wear the reason's colour; the neutral grey with the marker off; steel in
-- a fight; and the tag's ink holds whichever it is.
local function lum(r, g, b)
	local function lin(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end

local function contrast(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

withTree("look-slate: the accent carries the reason where the mode says", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local carriers = ns.Looks.Get("slate").AccentCarriers
	for _, case in ipairs({
		{ "icon", true, true }, { "stripe", false, true }, { "both", true, true }, { "off", false, false },
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
				if mode ~= "off" then
					if not sameColour(look.blade._color, cr, cg, cb) then
						fail(scenario, ("%s, %s, %s: the blade is not in the reason's colour"):format(mode, palette, reason))
					end
					if not sameColour(look.tag[2]._color, cr, cg, cb) then
						fail(scenario, ("%s, %s, %s: the tag is not in the reason's colour"):format(mode, palette, reason))
					end
					-- The ledge is the same colour a shade darker.
					local l = look.ledge[2]._color
					if not (l and l[1] <= cr + 0.001 and l[2] <= cg + 0.001 and l[3] <= cb + 0.001 and l[1] + l[2] + l[3] > 0.3) then
						fail(scenario, ("%s, %s, %s: the ledge is not a shade of the reason's colour"):format(mode, palette, reason))
					end
					if case[2] and not sameColour(look.iconEdge._color, cr, cg, cb) then
						fail(scenario, ("%s, %s, %s: the icon's line is not in the reason's colour"):format(mode, palette, reason))
					end
					if not case[2] and sameColour(look.iconEdge._color, cr, cg, cb) and not (cr == cg and cg == cb) then
						fail(scenario, ("%s: the icon's line wears the reason's colour though the mode says it does not"):format(mode))
					end
					-- The tag's text holds the colour it is on.
					local ink = r.sub._textColor
					local tagL = lum(cr, cg, cb)
					local ratio = ink and contrast(lum(ink[1], ink[2], ink[3]), tagL) or 0
					if ratio < 4.5 then
						fail(scenario, ("%s, %s, %s: the tag's text is %.2f:1 on its colour"):format(mode, palette, reason, ratio))
					end
				else
					if not sameColour(look.blade._color, 0.62, 0.67, 0.76) or sameColour(look.tag[2]._color, cr, cg, cb) then
						fail(scenario, "with the marker off the blade or the tag is still in the reason's colour: " .. reason)
					end
				end
			end
		end
	end
	-- One marker colour for every reason, however dark: the tag's ink follows it.
	for _, colour in ipairs({ { 0.85, 0.35, 0.75, 1 }, { 0.20, 0.10, 0.55, 1 }, { 1, 1, 1, 1 } }) do
		p.accentMode, p.accentByReason, p.accentColor = "both", false, colour
		ns.Prompt:ApplyStyle()
		ns.Prompt:PaintAccent("owed")
		if not sameColour(look.blade._color, colour[1], colour[2], colour[3]) then fail(scenario, "the chosen marker colour is not on the blade") end
		local ink = r.sub._textColor
		if not ink or contrast(lum(ink[1], ink[2], ink[3]), lum(colour[1], colour[2], colour[3])) < 4.5 then
			fail(scenario, "the tag's text does not hold a chosen marker colour")
		end
	end
end)

-- ------------------------------------------------------------------ 9
-- The outcomes: the name stays, the tag is the verdict, the plate is washed
-- white-to-green by a streak for a buff and glitches red-amber for a refusal,
-- the sent cast claims nothing; and the next paint takes it all back.
withTree("look-slate: the outcomes write a verdict and play their own motion", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local wash, ghost = look.washFrame, look.ghostFrames[1]
	local washes, glitches = look.landing[1]._plays or 0, look.refusal[#look.refusal - 2]._plays or 0
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	local named = tostring(r.name:GetText())
	if not named:find("ANNA", 1, true) or named:find("BUFFED", 1, true) then fail(scenario, "a landed buff moved the name: " .. named) end
	if r.sub:GetText() ~= "BUFFED" or look.tagFrame._shown == false then
		fail(scenario, "a landed buff's tag is not a \"BUFFED\": " .. tostring(r.sub:GetText()))
	end
	for _, piece in ipairs({ look.blade, look.tag[2], look.iconEdge }) do
		if not sameColour(piece._color, 0.30, 0.88, 0.48) then fail(scenario, "a landed buff did not turn the accent green") end
	end
	if (look.landing[1]._plays or 0) <= washes or (look.landing[2]._plays or 0) < 1 or (look.landing[3]._plays or 0) < 1 then
		fail(scenario, "a landed buff did not wash the plate, cross it with the streak and snap the tag in")
	end
	if (look.refusal[#look.refusal - 2]._plays or 0) ~= glitches then fail(scenario, "a landed buff glitched the plate") end
	-- The streak runs from the plate's left end to its right, white, in under half a second.
	local art = span(r.art)
	local move = look.bandMove
	if not (move._offset and near(move._offset[1], (art[3] - art[1]) - (0.30 + SLANT) * look.hp, 0.5)) then
		fail(scenario, "the landing's streak does not cross the whole plate")
	end
	if not (look.band._color and look.band._color[1] > 0.99 and look.band._color[3] > 0.99) then fail(scenario, "the landing's streak is not white") end
	if not sameColour(look.wash[2]._color, 0.30, 0.88, 0.48) then fail(scenario, "the wash is not green") end
	for _, g in ipairs(look.landing) do
		if FT.groupLength(g) > 0.5 + 1e-6 then fail(scenario, "a landing's effect lasts more than half a second") end
	end
	-- The tag's snap puts it back where it belongs.
	local dx = 0
	for _, a in ipairs(look.landing[3]._anims) do dx = dx + (a._offset and a._offset[1] or 0) end
	if dx ~= 0 then fail(scenario, "the tag's snap does not end at the tag's place: " .. dx) end
	Mock.advance(1)
	ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
	if r.sub:GetText() ~= "OUT OF RANGE." then fail(scenario, "a refusal is not the game's words in the tag: " .. tostring(r.sub:GetText())) end
	if not r.icon._desaturated then fail(scenario, "a refusal did not grey the icon") end
	if (look.refusal[#look.refusal - 2]._plays or 0) <= glitches then fail(scenario, "a refusal did not glitch the plate") end
	if not (sameColour(look.tag[2]._color, 1.0, 0.36, 0.28) and look.tag[2]._color[1] > look.tag[2]._color[3]) then
		fail(scenario, "the refusal's tag is not red-amber")
	end
	-- The glitch: the plate jerks in steps that sum to nothing, and a red and an
	-- amber copy slip past it, each ending where it began.
	local function sums(g, what)
		local sum, steps = 0, 0
		for _, a in ipairs(g._anims) do
			if a._offset then sum = sum + a._offset[1] steps = steps + 1 end
		end
		if sum ~= 0 then fail(scenario, what .. " does not end where it began: " .. sum) end
		if steps < 5 then fail(scenario, what .. " has only " .. steps .. " steps") end
		if FT.groupLength(g) > 0.35 then fail(scenario, what .. " lasts more than 0.35 s") end
	end
	for i = 1, 3 do sums(look.refusal[i], "the plate's jerk") end
	for i = 1, 2 do sums(look.refusal[4 + i], "a ghost's slip") end
	-- Red and amber.
	local red, amber = look.ghosts[1][2]._color, look.ghosts[2][2]._color
	if not (red and amber and red[1] > 0.9 and red[2] < 0.35 and amber[1] > 0.9 and amber[2] > 0.6 and amber[3] < 0.3) then
		fail(scenario, "the glitch's copies are not red and amber")
	end
	Mock.advance(2)
	tick(ns)
	if r.sub:GetText() == "OUT OF RANGE." then fail(scenario, "the verdict outlived the outcome") end
	if r.icon._desaturated then fail(scenario, "the icon stayed grey after the refusal ran out") end
	local cr, cg, cb = ns.Prompt:AccentColor("owed")
	if not sameColour(look.blade._color, cr, cg, cb) then fail(scenario, "the blade kept the outcome's colour") end
	-- A cast nobody confirmed claims nothing.
	local before = plays(look.landing) + plays(look.refusal)
	ns.Prompt:ShowOutcome("sent", "Anna Aim")
	if plays(look.landing) + plays(look.refusal) ~= before then fail(scenario, "a cast nobody confirmed got a flourish") end
	-- Parked at nothing when they stop.
	ns.Prompt:StopFlourishes()
	FT.settle()
	for _, f in ipairs({ wash, ghost, look.bandFrame, look.ghostFrames[2] }) do
		if (f._alpha or 0) > 0.001 then fail(scenario, "a stopped flourish left its light lit") end
	end
	if (r.icon._alpha or 1) < 0.999 then fail(scenario, "a stopped flourish left the icon see-through") end
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
	if (look.heat._alpha or 0) > 0.001 or (look.streakFrame._alpha or 0) > 0.001 then fail(scenario, "Calm left the owed light lit") end
end)

-- ------------------------------------------------------------------ 11
-- The owed breath: the blade's heat (warm white) and a streak across the plate
-- on the same breath, three breaths and still; gone with the favour and the
-- outcome.
withTree("look-slate: the blade heats and the streak runs three times, then it holds", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	if not (look.pulse[1]._playing and look.pulse[2]._playing) then fail(scenario, "somebody owed and the blade is not heating") end
	local c = look.warmRing._color
	if not (c and c[1] > c[3]) then fail(scenario, "the blade's heat is not warm") end
	if look.warmRing._parent ~= look.bladeFrame then fail(scenario, "the heat is not on the blade") end
	local breath = look.pulse[1]._anims[1]._duration
	if breath * 2 < 2 or breath * 2 > 3 then fail(scenario, ("the breath is %.2f s round"):format(breath * 2)) end
	if look.pulse[1]._looping ~= "BOUNCE" then fail(scenario, "the heat does not bounce") end
	-- The streak runs once a breath: its whole run is as long as the breath.
	if look.pulse[2]._looping ~= "REPEAT" or not near(FT.groupLength(look.pulse[2]), breath * 2, 0.02) then
		fail(scenario, ("the streak's run is %.2f s, not the breath's %.2f"):format(FT.groupLength(look.pulse[2]), breath * 2))
	end
	-- It runs the plate's width, left to right, and never scales.
	local art = span(r.art)
	if not (look.streakMove._offset and near(look.streakMove._offset[1], (art[3] - art[1]) - (0.30 + SLANT) * look.hp, 0.5)) then
		fail(scenario, "the streak does not run the plate's width")
	end
	-- Three of them, then still.
	Mock.advance(3 * breath * 2 + 0.5)
	Mock.runTimers()
	FT.settle()
	if look.pulse[1]._playing or look.pulse[2]._playing or (look.heat._alpha or 0) > 0.001 or (look.streakFrame._alpha or 0) > 0.001 then
		fail(scenario, "the blade is still heating after its breaths")
	end
	-- A repaint of the same favour does not breathe again; a new favour does.
	tick(ns)
	if look.pulse[1]._playing then fail(scenario, "a repaint of the same favour started the breath again") end
	owe(ns, "Anna Aim")
	look:Attention(true, false, "pulse")
	if not look.pulse[1]._playing then fail(scenario, "a new favour did not breathe") end
	ns.Prompt:ShowOutcome("cast", "Anna Aim")
	if look.pulse[1]._playing or look.pulse[2]._playing then fail(scenario, "the breath went on over an outcome") end
	-- "Flash once" never loops; "none" does nothing.
	for _, style in ipairs({ "once", "off" }) do
		p.flashStyle = style
		look:Attention(true, true, style)
		if look.pulse[1]._playing or look.pulse[2]._playing then fail(scenario, "the breath played with the flash set to " .. style) end
	end
end)

-- ------------------------------------------------------------------ 12
-- The arrival is for a new favour, once, never over an outcome; every plate
-- slides in from the left one after another and ends where it belongs.
withTree("look-slate: the arrival plays once, for a new favour", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local n = plays(look.arrive)
	if n < #look.arrive then fail(scenario, "somebody buffing you did not play the whole arrival: " .. n) end
	-- The blade flashes white.
	if not (look.flash._color and look.flash._color[1] > 0.99 and look.flash._color[3] > 0.99) then
		fail(scenario, "the blade's flash is not white")
	end
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
	-- Each slide ends where its plate belongs, on a hard ease-out, staggered,
	-- inside its time.
	local starts = {}
	for i, g in ipairs(look.arrive) do
		if FT.groupLength(g) > 0.5 then fail(scenario, ("an arrival's effect lasts %.2f s"):format(FT.groupLength(g))) end
		local dx, hard = 0, false
		for _, a in ipairs(g._anims) do
			if a._kind == "Translation" then
				dx = dx + (a._offset and a._offset[1] or 0)
				if a._smoothing == "OUT" then hard = true end
			end
		end
		if dx ~= 0 then fail(scenario, "arrival effect " .. i .. " does not end at its plate's place: " .. dx) end
		if (g._owner ~= r.icon) and hard == false and g._anims[2] and g._anims[2]._kind == "Translation" then
			fail(scenario, "arrival effect " .. i .. " does not ease out hard")
		end
		for _, a in ipairs(g._anims) do
			if g._owner ~= r.icon and a._kind == "Alpha" and a._order == 1 and a._toAlpha == 0 then starts[#starts + 1] = a._duration end
		end
	end
	table.sort(starts)
	if not (starts[#starts] and starts[1] and starts[#starts] > starts[1] + 0.05) then fail(scenario, "the plates do not arrive one after another") end
	-- The blade flashes white.
	local flash = look.arrive[#look.arrive]
	if not (look.flash._color and look.flash._color[3] > 0.99) then fail(scenario, "the blade's flash is not white") end
	if flash._owner ~= look.flash then fail(scenario, "the arrival does not end in the blade's flash") end
end)

-- ------------------------------------------------------------------ 13
-- A fight: the icon greys and dims by colour, the text dims, the accent goes to
-- a muted steel, the lights go out; it all comes back, and leaving Slate in a
-- fight leaves the icon as it was.
withTree("look-slate: in a fight the accent goes to steel", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.accentMode = "both" end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local reason = { look.blade._color[1], look.blade._color[2], look.blade._color[3] }
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	if not r.icon._desaturated then fail(scenario, "the icon keeps its colour in a fight") end
	if (r.icon._alpha or 1) < 0.99 then fail(scenario, "the icon turned see-through in a fight") end
	if not (r.icon._color and r.icon._color[1] < 0.9) then fail(scenario, "the icon is not dimmed in a fight") end
	if not near(r.name._alpha, 0.78) then fail(scenario, "the text does not dim in a fight") end
	if (r.sub._alpha or 1) < 0.99 or not near(r.textLayer._alpha or 1, 1) then fail(scenario, "the reason is dimmed in a fight") end
	if (r.art._alpha or 1) < 0.99 then fail(scenario, "art dimmed whole in a fight") end
	for _, piece in ipairs({ look.blade, look.tag[2], look.iconEdge }) do
		local c = piece._color
		if not (c and sameColour(c, 0.50, 0.56, 0.66)) then fail(scenario, "the accent is not steel in a fight") end
	end
	if sameColour(look.blade._color, reason[1], reason[2], reason[3]) then fail(scenario, "the blade kept the reason's colour in a fight") end
	-- Steel is muted: the spread of its channels is small beside the reasons'.
	local c = look.blade._color
	if math.max(c[1], c[2], c[3]) - math.min(c[1], c[2], c[3]) > 0.2 then fail(scenario, "steel is not muted") end
	-- The tag's text still holds it.
	local ink = r.sub._textColor
	if not ink or contrast(lum(ink[1], ink[2], ink[3]), lum(c[1], c[2], c[3])) < 4.5 then fail(scenario, "the tag's text does not hold steel") end
	if look.pulse[1]._playing or (look.heat._alpha or 0) > 0.001 then fail(scenario, "the owed light is lit in a fight") end
	if (look.iconPlate._color and look.iconPlate._color[4] or 1) < 0.99 then fail(scenario, "nothing opaque under the icon in a fight") end
	-- Laid out again during the hold: the hold stays.
	look:Apply(ns.db.profile.prompt, false)
	if not r.icon._desaturated then fail(scenario, "laying the plate out again during the hold put the colour back") end
	local before = plays(look.arrive) + plays(look.pulse)
	look:Attention(true, true, "pulse")
	if plays(look.arrive) + plays(look.pulse) ~= before or look.pulse[1]._playing then
		fail(scenario, "laying the plate out again during the hold let the light start in the fight")
	end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	ns.Prompt:PaintAccent("owed")
	if r.icon._desaturated or not near(r.name._alpha or 1, 1) or (r.icon._color and r.icon._color[1] < 0.99) then
		fail(scenario, "the fight's dim stayed on after it ended")
	end
	if not sameColour(look.blade._color, reason[1], reason[2], reason[3]) then fail(scenario, "the blade did not get the reason's colour back after the fight") end
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	Mock.inCombat = false
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	if r.icon._color and r.icon._color[1] < 0.99 then fail(scenario, "leaving Slate during a fight left the icon dimmed on glass") end
	if not near(r.textLayer._alpha or 1, 1) or not near(r.name._alpha or 1, 1) then fail(scenario, "leaving Slate during a fight left the text dimmed on glass") end
	if r.icon._desaturated then fail(scenario, "leaving Slate during a fight left the icon grey on glass") end
end)

-- ------------------------------------------------------------------ 13b
-- The cursor lifts the plate's hairline and lets it go.
withTree("look-slate: the cursor lifts the plate's hairline", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local rest = look.edgeFrame._alpha
	if not (rest and rest > 0.3 and rest < 0.9) then fail(scenario, "the hairline does not rest between dim and full: " .. tostring(rest)) end
	local button = ns.Prompt:GetButton()
	button.scripts.OnEnter(button)
	Mock.advance(0.5)
	FT.settle()
	if not near(look.edgeFrame._alpha, 1, 0.01) then fail(scenario, "the cursor did not lift the hairline: " .. tostring(look.edgeFrame._alpha)) end
	button.scripts.OnLeave(button)
	Mock.advance(0.5)
	FT.settle()
	if not near(look.edgeFrame._alpha, rest, 0.01) then fail(scenario, "the hairline did not settle back: " .. tostring(look.edgeFrame._alpha)) end
end)

-- ------------------------------------------------------------------ 14
-- Leaving Slate gives every shared region back: the icon's mask, alpha and
-- colour, the cooldown's strength, the text's level and alpha, the lines' room,
-- and the lines' own words in the case they were given.
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
	-- The words are the player's again: not in capitals on glass.
	if tostring(r.name:GetText()):find("%l") == nil then fail(scenario, "the name is still in capitals on glass: " .. tostring(r.name:GetText())) end
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
-- The ground: a dark plate by default, the hairline and the icon's plate light
-- on dark and dark on light, the name readable on both, and the tag's text
-- readable whatever colour it is on.
withTree("look-slate: the text is readable on the plate, dark or light", ANNA, function(ns, scenario)
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
				-- The tag: its own colour is the ground of its text.
				local t, c = look.tag[2]._color, r.sub._textColor
				if not (t and c) then fail(scenario, "the tag or its text has no colour") return end
				local ratio = contrast(lum(c[1], c[2], c[3]), lum(t[1], t[2], t[3]))
				if ratio < 4.5 then
					fail(scenario, ("%s, %s, %s: the tag's text is %.2f:1 on the tag"):format(ground[1], palette, reason, ratio))
				end
				-- The name: the plate's top colour where it stands, over a dusky world
				-- where the plate is see-through.
				local top, a = look.top, look.alpha
				local function over(v) return v * a + 0.15 * (1 - a) end
				local plate = lum(over(top[1]), over(top[2]), over(top[3]))
				local n = r.name._textColor
				local need = a >= 0.5 and 4.4 or 3
				-- (The name's colour is Prompt's, the same on every look: held on the
				-- slate, the light panel and the clear one.)
				if n and ground[1] ~= "a mid-blue panel" and contrast(lum(n[1], n[2], n[3]), plate) < need then
					fail(scenario, ("%s, %s: the name is %.2f:1 on the plate"):format(ground[1], palette,
						contrast(lum(n[1], n[2], n[3]), plate)))
				end
			end
		end
	end
	local _, _, look = upIn(ns, scenario, function(pp) pp.bgColor = { 0.86, 0.84, 0.78, 0.92 } end)
	if look.edgeColor[1] > 0.5 or look.iconPlateColor[1] < 0.5 then fail(scenario, "on a light plate the hairline is not dark and the icon's plate light") end
	_, _, look = upIn(ns, scenario)
	if look.edgeColor[1] < 0.5 or look.iconPlateColor[1] > 0.5 then fail(scenario, "on a dark plate the hairline is not light and the icon's plate dark") end
	-- The plate's own slate is dark.
	local top, bottom = look.top, look.bottom
	if lum(top[1], top[2], top[3]) > 0.02 or lum(bottom[1], bottom[2], bottom[3]) > 0.02 then fail(scenario, "the plate's slate is not dark") end
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
-- look names shipped and every shipped file drawn, and the generator draws the
-- same bytes twice, and the bytes that ship.
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

-- The files the look draws, by name.
local FILES = { "Slate_Plate", "Slate_Edge", "Slate_Blade", "Slate_Notch", "Slate_Seg", "Slate_Hatch", "Slate_Streak",
	"Slate_IconMask", "Slate_IconEdge", "Slate_FxRing" }

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
	if #names ~= #FILES then fail(scenario, "the generator wrote " .. #names .. " files, not " .. #FILES .. ": " .. outA:sub(1, 200)) return end
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
	local drawn = {}
	for _, file in ipairs(names) do drawn[file] = true end
	for _, file in ipairs(FILES) do
		if not drawn[file .. ".tga"] then fail(scenario, file .. " is not drawn by the generator") end
		if not slurp(dir .. "/Textures/Slate/" .. file .. ".tga") then fail(scenario, file .. " is not in the package") end
	end
end)

-- Every texture the look draws is one of those files, and every file is drawn.
withTree("look-slate: every texture is from Textures/Slate, and every file is drawn", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local used = {}
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
				else
					used[rel:match("Slate_%w+")] = true
				end
			end
		end
		for _, ring in ipairs(look.fx.rings) do used["Slate_" .. tostring(ring.tex._file):match("Slate_(%w+)$")] = true end
		used[tostring(look.mask._file):match("Slate_%w+")] = true
	end
	for _, file in ipairs(FILES) do
		if not used[file] then fail(scenario, file .. " ships and the look never draws it") end
	end
	-- Nothing else ships (the folder listed by python, like the generator is run).
	local log = tempDir() .. "-list.log"
	os.execute(python .. ' -c "import os,sys;print(chr(10).join(sorted(os.listdir(sys.argv[1]))))" "' .. dir
		.. '/Textures/Slate" > "' .. log .. '" 2>&1')
	local listing = slurp(log)
	os.remove(log)
	if listing and not listing:find("No module", 1, true) then
		for file in listing:gmatch("[^%c]+") do
			local stem = file:match("^(.+)%.tga$")
			if not stem or not used[stem] then fail(scenario, file .. " ships and nothing draws it") end
		end
	end
end)

-- ------------------------------------------------------------------ 18
-- Nothing is rounded. The art's corners are sharp (read from the shipped
-- files), the icon is a hexagon whatever "Round the icon" says, the sweep's
-- edge is not circular, and the slant in the art is the slant the code lays it
-- out for (and the width of a plate's end).
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
		return data:byte(offset + (row * w + x) * 4 + 4) / 255
	end }
end

withTree("look-slate: nothing is rounded, and the slant in the art is the code's", ANNA, function(ns, scenario)
	local code = slurp(dir .. "/Looks/Slate.lua") or ""
	local gen = slurp(dir .. "/tools/make_slate_textures.py") or ""
	local cs, cc = code:match("local SLANT, CAP = ([%d%.]+), ([%d%.]+)")
	local gs = gen:match("\nSLANT = ([%d%.]+)")
	local gc = gen:match("\nCAP = ([%d%.]+)")
	if not (cs and gs and tonumber(cs) == tonumber(gs) and tonumber(cc) == tonumber(gc)) then
		fail(scenario, ("the slant or the width of a plate's end differs between Looks/Slate.lua (%s, %s) and the generator (%s, %s)"):format(
			tostring(cs), tostring(cc), tostring(gs), tostring(gc)))
	end
	if tonumber(cs) ~= SLANT or tonumber(cc) ~= CAP then fail(scenario, "the test's SLANT and CAP are not the look's") end
	-- No file or texture of a rounded shape.
	local look = ns.Looks.list.slate
	for _, bad in ipairs({ "Round", "Pill", "Card", "Glow", "Shadow", "Rim" }) do
		if code:find("Slate_" .. bad, 1, true) or code:find('"' .. bad .. '"', 1, true) then fail(scenario, "Slate names a " .. bad .. " texture") end
	end
	-- The sharp corners of the plate: the bottom left and the top right are opaque
	-- to their last texel, and the far corners of the slant are empty.
	local plate = readTGA(dir .. "/Textures/Slate/Slate_Plate.tga")
	if plate then
		if plate.alpha(1, plate.h - 2) < 0.9 then fail(scenario, "the plate's bottom left corner is rounded off") end
		if plate.alpha(plate.w - 2, 1) < 0.9 then fail(scenario, "the plate's top right corner is rounded off") end
		if plate.alpha(1, 1) > 0.05 or plate.alpha(plate.w - 2, plate.h - 2) > 0.05 then fail(scenario, "the plate has no slant") end
		-- The slant: where the edge crosses the middle row is half the lean in.
		local row = math.floor(plate.h / 2)
		local x = 0
		while x < plate.w and plate.alpha(x, row) < 0.5 do x = x + 1 end
		if math.abs(x - SLANT * plate.h / 2) > 2 then fail(scenario, "the plate's edge leans " .. x .. " texels at its middle, not " .. SLANT * plate.h / 2) end
		-- The end is CAP of the height: the middle strip is solid from there on.
		local cap = CAP * plate.h
		for _, y in ipairs({ 2, plate.h - 3 }) do
			for xx = math.floor(cap) + 4, plate.w - math.floor(cap) - 4 do
				if plate.alpha(xx, y) < 0.9 then fail(scenario, "the plate's middle is not solid past its end") break end
			end
		end
	end
	local hex = readTGA(dir .. "/Textures/Slate/Slate_IconMask.tga")
	if hex then
		-- A hexagon: the two sharp corners are cut, the other two are not.
		if hex.alpha(1, hex.h - 2) > 0.3 or hex.alpha(hex.w - 2, 1) > 0.3 then fail(scenario, "the icon's frame has no cut corners") end
		local lean = math.floor(SLANT * hex.h + 2.5)
		if hex.alpha(lean, 1) < 0.5 or hex.alpha(hex.w - lean - 1, hex.h - 2) < 0.5 then fail(scenario, "the icon's frame's other corners are not sharp") end
	end
	-- Round icon on: still the hexagon, the sweep not circular, the same files.
	local r, p, slate = upIn(ns, scenario, function(pp) pp.roundIcon = true end)
	if not isSlate(slate) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	if not tostring(slate.mask._file):find("Slate_IconMask$") then fail(scenario, "round icon on: the mask is not the hexagon") end
	if r.cooldown and r.cooldown._circular then fail(scenario, "round icon on: the sweep's edge is circular") end
	if not tostring(slate.iconEdge._file):find("Slate_IconEdge$") then fail(scenario, "round icon on: the icon's line is not the hexagon's") end
	local fxFile = tostring(slate.fx.rings[1].tex._file)
	if not fxFile:find("Slate_FxRing$") then fail(scenario, "round icon on: the rings are not the hexagon's: " .. fxFile) end
	_ = look
end)

-- ------------------------------------------------------------------ 19
-- Capitals: ASCII letters only, outside the game's escapes; the lines of other
-- scripts as they are; and only while Slate is the look in use.
withTree("look-slate: capitals on ASCII only, outside the escapes", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp) pp.showQueue, pp.queueRows = true, 3 end)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	local function says(fs, text)
		fs:SetText(text)
		return fs:GetText()
	end
	local cases = {
		{ "Annabelle", "ANNABELLE" },
		{ "Zo\195\171 d'Arc", "ZO\195\171 D'ARC" },
		{ "\208\152\208\178\208\176\208\189", "\208\152\208\178\208\176\208\189" },
		{ "\233\173\148\230\179\149\229\184\136", "\233\173\148\230\179\149\229\184\136" },
		{ "|cff8ce88cBuffed|r you", "|cff8ce88cBUFFED|r YOU" },
		{ "|cFF00ff00ok|r", "|cFF00ff00OK|r" },
		{ "|Hitem:6948:0|h[Hearthstone]|h x", "|Hitem:6948:0|h[HEARTHSTONE]|h X" },
		{ "a|nb", "A|nB" },
		{ "", "" },
		{ "123 !?", "123 !?" },
	}
	for _, case in ipairs(cases) do
		for _, fs in ipairs({ r.name, r.sub, r.rows[1] }) do
			local got = says(fs, case[1])
			-- The tag takes the ink of its own colour: the colour codes of a line set
			-- there are dropped.
			local want = case[2]
			if fs == r.sub then want = want:gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rR]", "") end
			if got ~= want then fail(scenario, ("%q is set as %q, not %q"):format(case[1], tostring(got), want)) end
		end
	end
	-- Repeated words come back the same without being worked out again.
	local one = look:Upper(r.name, "Brannoc Vale")
	if look:Upper(r.name, "Brannoc Vale") ~= one or one ~= "BRANNOC VALE" then fail(scenario, "a repeated line is not set the same way") end
	-- A value the client withholds is passed on untouched.
	if look:Upper(r.name, nil) ~= nil or look:Upper(r.name, 7) ~= 7 then fail(scenario, "a line that is not text is changed") end
	-- Another look: the words are the player's.
	p.style = "glass"
	ns.Prompt:ApplyStyle()
	if says(r.name, "Annabelle") ~= "Annabelle" then fail(scenario, "Slate still sets capitals once it is not the look in use") end
	p.style = "slate"
	ns.Prompt:ApplyStyle()
	if says(r.name, "Annabelle") ~= "ANNABELLE" then fail(scenario, "Slate does not set capitals when it comes back") end
	-- The list's rows too, name and the words after it.
	local text = says(r.rows[2], "Brannoc Vale  |cff8a91a3needs Arcane Intellect|r")
	if text ~= "BRANNOC VALE  |cff8a91a3NEEDS ARCANE INTELLECT|r" then fail(scenario, "a list row is not in capitals outside its colour code: " .. tostring(text)) end
end)

-- ------------------------------------------------------------------ 20
-- The face: the condensed one for the names and the tag where the client has it
-- (Latin and Cyrillic clients), unless the player picked a font; the client's own
-- on koKR, zhCN and zhTW; a font the client refuses is not left as no font.
local CONDENSED = "Fonts\\ARIALN.TTF"
for _, case in ipairs({
	{ "enUS", true }, { "deDE", true }, { "frFR", true }, { "esES", true }, { "ptBR", true }, { "itIT", true },
	{ "koKR", false }, { "zhCN", false }, { "zhTW", false },
}) do
	withTree("look-slate: the face on " .. case[1], ANNA, function(ns, scenario)
		local r, p, look = upIn(ns, scenario)
		if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
		local path = r.name:GetFont()
		local subPath = r.sub:GetFont()
		local rowPath = r.rows[1]:GetFont()
		if case[2] then
			if path ~= CONDENSED or subPath ~= CONDENSED or rowPath ~= CONDENSED then
				fail(scenario, case[1] .. ": the lines are not in the condensed face: " .. tostring(path))
			end
			if look.kit.fit.path ~= CONDENSED then fail(scenario, "a line that is refitted would leave the condensed face") end
			if select(2, r.name:GetFont()) ~= p.fontSize + 2 then fail(scenario, "the name is not a size above the font's") end
		else
			if tostring(path):upper():find("ARIALN", 1, true) or tostring(subPath):upper():find("ARIALN", 1, true) then
				fail(scenario, case[1] .. ": the client's own face is left for the Latin one: " .. tostring(path))
			end
		end
		-- A font the player picked wins, and so does a refusal of the file.
		p.font = "Arial Narrow"
		ns.Prompt:ApplyStyle()
		if r.name:GetFont() == CONDENSED and case[2] then
			-- Arial Narrow is also the condensed file: pick another that is not.
		end
		p.font = "Morpheus"
		ns.Prompt:ApplyStyle()
		if tostring(r.name:GetFont()):upper():find("ARIALN", 1, true) then fail(scenario, case[1] .. ": the chosen font did not win") end
		if select(2, r.name:GetFont()) ~= p.fontSize then fail(scenario, "a chosen font was drawn in the look's size, not the player's") end
	end, function() Mock.locale = case[1] end)
end

withTree("look-slate: a condensed face the client refuses leaves a line with a font", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isSlate(look) then fail(scenario, "SKIPPED -- Slate is not the look in use") return end
	Mock.badFonts = { [CONDENSED] = true }
	ns.Prompt:ApplyStyle()
	for _, fs in ipairs({ r.name, r.sub, r.rows[1] }) do
		if not fs:GetFont() then fail(scenario, "a line was left with no font when the condensed face was refused") end
	end
	if look.kit.fit.path == CONDENSED then fail(scenario, "refitting would keep asking for a face the client refused") end
	local ok, err = pcall(function() ns.Prompt:Paint({ name = "Anna Aim", short = "Anna", reason = "owed", buff = ns.ResolveBuff(true) }, 2) end)
	if not ok then fail(scenario, "painting with the face refused threw: " .. tostring(err)) end
	Mock.badFonts = nil
end)

-- ------------------------------------------------------------------ 21
-- The look's own options: nothing it cannot honour. The icon slider is the
-- slider's; the carriers are stated.
withTree("look-slate: the options page can state what Slate does", ANNA, function(ns, scenario)
	local look = ns.Looks.Get("slate")
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
end)
