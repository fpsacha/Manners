-- Hunt 37: the rings stay in their room, under the text.
--
-- The landing's rings, the refusal's ring, the arrival's echo and the halo that
-- flares are all drawn round the icon, and all of them used to grow past the
-- gap between the icon and the start of the name (and past the panel's top and
-- bottom edges): the picture of the prompt showed a ring drawn over "buffed
-- Elowen". Each is held to the room the layout leaves, worked out when the
-- style is applied (Prompt/Effects.lua, FXMethods:Fit and Prompt:FitBurst, and
-- each look's Apply), and sits beneath the text's frame level so a letter is
-- never washed even where it does reach.
--
-- The evidence is the frame tree's (tests/frametree.lua): the geometry of every
-- texture an icon-centred effect draws, at several moments of each effect,
-- with the animations that own it played to that moment as the renderer plays
-- them (tools/render_prompt.py, group_effect: the scale about the frame's own
-- middle, the translation), against the rectangles of the name and the reason
-- line (the shake moves them) and the panel's top and bottom.
--
-- What it holds:
--   * in each of the six looks, at the default size, a large one, the narrow
--     prompt that holds the biggest icon, the biggest icon a default-height
--     prompt allows, a tiny icon, a round icon and accents off, the effect's
--     visible edge (its texture's rectangle shrunk to how far out its art is
--     seen) never meets the name or the reason line and never passes the
--     panel's top or bottom, for the arrival, a landing and a refusal;
--   * the art's own reach is what the code says it is (the files are read);
--   * every frame of light under the panel's art, the effects and the band
--     that crosses the panel included, is beneath the text's frame level.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local ALL = { "glass", "framed", "minimal", "luxe", "toast", "arcane", "whisper", "letter" }

local function withTree(scenario, names, body)
	Mock.reset()
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

-- The sizes asked of every look: width, height, font, icon. `edit` is for the
-- ones that are not a size.
local SIZES = {
	{ name = "default" },
	{ name = "large", p = { 320, 58, 17, 40 } },
	{ name = "extreme: 220 wide, icon 40, font 17", p = { 220, 48, 17, 40 } },
	{ name = "the biggest icon at the default height", p = { 220, 44, 13, 36 } },
	{ name = "a tiny icon", p = { 220, 44, 13, 16 } },
	{ name = "tall: 320 x 72, icon 64", p = { 320, 72, 17, 64 } },
	{ name = "round icon", edit = function(p) p.roundIcon = true end },
	{ name = "accents off", edit = function(p) p.accentMode = "off" end },
}
-- Slate joins the looks asked of each size.
ALL[#ALL + 1] = "slate"

local function upIn(ns, scenario, style, size)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = style
	p.flashStyle = "pulse"
	p.effects = "full"
	p.hideInCombat = false
	p.showIcon = true
	p.roundIcon = false
	p.showSub = true
	if size.p then p.width, p.height, p.fontSize, p.iconSize = size.p[1], size.p[2], size.p[3], size.p[4] end
	if size.edit then size.edit(p) end
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	FT.settle()
	return ns.Prompt:Regions(), p
end

-- ------------------------------------------------------------------ the animations at a moment

local function smooth(t, how)
	if how == "IN" then return t * t end
	if how == "OUT" then return 1 - (1 - t) * (1 - t) end
	if how == "IN_OUT" then return 3 * t * t - 2 * t * t * t end
	return t
end

-- What a playing group does to its owner `now`: an alpha, a translation and a
-- scale, as the renderer works them out.
local function groupAt(g, now)
	if not g._playing then return nil end
	local lengths, orders = {}, {}
	for _, a in ipairs(g._anims) do
		local o = a._order or 1
		local len = (a._startDelay or 0) + (a._duration or 0)
		if lengths[o] == nil then orders[#orders + 1] = o end
		lengths[o] = math.max(lengths[o] or 0, len)
	end
	table.sort(orders)
	local total = 0
	for _, o in ipairs(orders) do total = total + lengths[o] end
	if total <= 0 then total = 1e-6 end
	local t = now - (g._startedAt or now)
	if g._looping == "REPEAT" then
		t = t % total
	elseif g._looping == "BOUNCE" then
		t = t % (2 * total)
		if t > total then t = 2 * total - t end
	elseif t > total then
		t = total
	end
	local alpha, dx, dy, scale = nil, 0, 0, nil
	local start = 0
	for _, o in ipairs(orders) do
		for _, a in ipairs(g._anims) do
			if (a._order or 1) == o then
				local a0 = start + (a._startDelay or 0)
				local d = a._duration or 0
				if t < a0 then
					if a._kind == "Alpha" and alpha == nil and o == orders[1] then alpha = a._fromAlpha end
				else
					local p = d <= 0 and 1 or math.min(1, (t - a0) / d)
					p = smooth(p, a._smoothing)
					if a._kind == "Alpha" then
						local fa, ta = a._fromAlpha or 0, a._toAlpha
						if ta == nil then ta = 1 end
						alpha = fa + (ta - fa) * p
					elseif a._kind == "Translation" then
						local off = a._offset or { 0, 0 }
						dx, dy = dx + off[1] * p, dy + off[2] * p
					elseif a._kind == "Scale" then
						local f, to = a._scaleFrom or { 1, 1 }, a._scaleTo or { 1, 1 }
						scale = { f[1] + (to[1] - f[1]) * p, f[2] + (to[2] - f[2]) * p }
					end
				end
			end
		end
		start = start + lengths[o]
	end
	return { alpha = alpha, dx = dx, dy = dy, scale = scale }
end

-- What every playing group on `node` adds up to.
local function effectOf(node, now)
	local out
	for _, g in ipairs(node._groups or {}) do
		local e = groupAt(g, now)
		if e then
			if not out then
				out = e
			else
				if e.alpha ~= nil then out.alpha = e.alpha end
				out.dx, out.dy = out.dx + e.dx, out.dy + e.dy
				if e.scale then out.scale = e.scale end
			end
		end
	end
	return out
end

-- The chain from a region up to, but not including, `stop` (the art).
local function chain(r, stop)
	local out = {}
	while r and r ~= stop do
		out[#out + 1] = r
		r = r._parent
	end
	return out
end

-- A region's rectangle as the animations between it and `art` have moved and
-- grown it, in screen units: { L, B, R, T }, or nil when it has none. The
-- scale is about the animated frame's own middle, then its translation.
local function rectAt(r, art, now)
	local L, R = FT.span(r, "x")
	local B, T = FT.span(r, "y")
	if not (L and B) then return nil end
	for _, c in ipairs(chain(r, art)) do
		local e = effectOf(c, now)
		if e then
			if e.scale then
				local cl, cr = FT.span(c, "x")
				local cb, ct = FT.span(c, "y")
				if cl and cb then
					local cx, cy = (cl + cr) / 2, (cb + ct) / 2
					L, R = cx + (L - cx) * e.scale[1], cx + (R - cx) * e.scale[1]
					B, T = cy + (B - cy) * e.scale[2], cy + (T - cy) * e.scale[2]
				end
			end
			local s = FT.scaleOf(c)
			L, R = L + e.dx * s, R + e.dx * s
			B, T = B + e.dy * s, T + e.dy * s
		end
	end
	return L, B, R, T
end

-- Whether it is drawn at all at `now`: shown, every frame above it shown, and
-- its alpha (an animated one replacing the frame's own) not nothing.
local function seenAt(r, art, now)
	if not FT.visible(r) then return false end
	local a = 1
	local node = r
	while node do
		local own = node._alpha
		if own == nil then own = 1 end
		local e = effectOf(node, now)
		if e and e.alpha ~= nil then own = e.alpha end
		a = a * own
		node = node._parent
	end
	return a > 0.02
end

-- ------------------------------------------------------------------ what is an effect

-- The art's declared reach: the visible fraction of a texture's half-width.
local function edgeOf(ns, tex)
	local lib = ns.Prompt.lib
	local art = tex._file and lib.RingArtOf and lib.RingArtOf(tex._file)
	return art and art.edge or 1
end

-- Every texture an effect of the icon draws that grows: the rings, the echo,
-- the halo that flares, and a look's own lock-on ring. Found by what is
-- animated (a playing group with a scale on the texture or a frame above it,
-- under the art and not in the text), so an effect a look adds later is held
-- to the same room without anybody listing it.
local function scaledTextures(r, art, textLayer, now)
	local out = {}
	for _, node in ipairs(FT.all) do
		if (node._kind == "Texture") and node._parent then
			local under, inText = false, false
			local up = node
			while up do
				if up == art then under = true end
				if up == textLayer then inText = true end
				up = up._parent
			end
			if under and not inText then
				for _, c in ipairs(chain(node, art)) do
					local e = effectOf(c, now)
					if e and e.scale then out[#out + 1] = node break end
				end
			end
		end
	end
	return out
end

local function overlaps(a, b)
	return a[1] < b[3] - 1e-6 and b[1] < a[3] - 1e-6 and a[2] < b[4] - 1e-6 and b[2] < a[4] - 1e-6
end

local TIMES = { 0.01, 0.02, 0.045, 0.05, 0.08, 0.12, 0.16, 0.20, 0.25, 0.30, 0.35, 0.40, 0.50 }

-- Plays `start()` and checks every effect at each moment; `what` names the
-- event. Time is the mock's, so the groups stay playing between the samples.
local function sampleEvent(ns, scenario, r, label, start, seen)
	local art = r.art
	local pb, pt = FT.span(art, "y")
	start()
	local last = 0
	for _, t in ipairs(TIMES) do
		Mock.advance(t - last)
		last = t
		local now = GetTime()
		local texts = {}
		for _, fs in ipairs({ r.name, r.sub }) do
			if fs and FT.visible(fs) and (fs._text or "") ~= "" then
				local L, B, R, T = rectAt(fs, art, now)
				if L then texts[#texts + 1] = { rect = { L, B, R, T }, fs = fs } end
			end
		end
		for _, tex in ipairs(scaledTextures(r, art, r.textLayer, now)) do
			if seenAt(tex, art, now) then
				local L, B, R, T = rectAt(tex, art, now)
				if L then
					local edge = edgeOf(ns, tex)
					local cx, cy = (L + R) / 2, (B + T) / 2
					local vis = { cx + (L - cx) * edge, cy + (B - cy) * edge, cx + (R - cx) * edge, cy + (T - cy) * edge }
					seen.n = seen.n + 1
					for _, text in ipairs(texts) do
						if overlaps(vis, text.rect) then
							fail(scenario, ("%s, %.2f s: an effect (%s) covers the %s: it reaches %.1f, the text starts at %.1f"):format(
								label, t, tostring(tex._file or "light"),
								text.fs == r.name and "name" or "reason line", vis[3], text.rect[1]))
						end
					end
					-- A unit inside the panel's edge, where the light is held to.
					if vis[4] > pt - 1 + 1e-6 or vis[2] < pb + 1 - 1e-6 then
						fail(scenario, ("%s, %.2f s: an effect (%s) passes the panel's %s: %.1f to %.1f, the panel %.1f to %.1f"):format(
							label, t, tostring(tex._file or "light"), vis[4] > pt - 1 and "top" or "bottom", vis[2], vis[4], pb, pt))
					end
				end
			end
		end
	end
	Mock.advance(3)
	FT.settle()
end

-- ------------------------------------------------------------------ 1
-- Each effect, in each look and at each size, stays in its room.
for _, style in ipairs(ALL) do
	local name = "hunt37-effects: the rings, the echo and the halo stay in their room, in " .. style
	withTree(name, ANNA, function(ns, scenario)
		for _, size in ipairs(SIZES) do
			local r = upIn(ns, scenario, style, size)
			local tag = style .. ", " .. size.name
			local seen = { n = 0 }
			-- Somebody buffed you: the arrival.
			sampleEvent(ns, scenario, r, tag .. " arriving", function()
				owe(ns, "Anna Aim")
				ns.addon:Tick()
			end, seen)
			-- A buff the game confirmed: the landing.
			sampleEvent(ns, scenario, r, tag .. " landing", function()
				ns.Prompt:ShowOutcome("cast", "Anna Aim")
			end, seen)
			-- A refusal.
			sampleEvent(ns, scenario, r, tag .. " refused", function()
				ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.")
			end, seen)
			if seen.n < 6 then
				fail(scenario, tag .. ": the effects were not found at work (" .. seen.n .. " samples), so nothing was held")
			end
		end
	end)
end

-- ------------------------------------------------------------------ 2
-- The reach the code declares for each ring file is the reach the file has: the
-- alpha over 2% of the art, as a fraction of its half-width, at most the
-- `edge` the code names (a ring seen further out than that would be held to a
-- room it is not in).
local function readTGA(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	local b = { data:byte(1, 18) }
	if #b < 18 or b[3] ~= 2 or b[17] ~= 32 then return nil end
	local w, h = b[13] + b[14] * 256, b[15] + b[16] * 256
	return { w = w, h = h, data = data, offset = 18 + b[1] }
end

local function reachOf(tga)
	local half = tga.w / 2
	local reach = 0
	for y = 0, tga.h - 1 do
		for x = 0, tga.w - 1 do
			local alpha = tga.data:byte(tga.offset + (y * tga.w + x) * 4 + 4) / 255
			if alpha > 0.02 then
				local d = math.max(math.abs(x + 0.5 - half), math.abs(y + 0.5 - half)) / half
				if d > reach then reach = d end
			end
		end
	end
	return reach
end

local RING_FILES = {
	{ "Textures/Slate/Slate_FxRing", "Interface\\AddOns\\Manners\\Textures\\Slate\\Slate_FxRing" },
	{ "Textures/Ring", "Interface\\AddOns\\Manners\\Textures\\Ring" },
	{ "Textures/RingSq", "Interface\\AddOns\\Manners\\Textures\\RingSq" },
	{ "Textures/Luxe/Luxe_IconRing", "Interface\\AddOns\\Manners\\Textures\\Luxe\\Luxe_IconRing" },
	{ "Textures/Luxe/Luxe_IconRingRound", "Interface\\AddOns\\Manners\\Textures\\Luxe\\Luxe_IconRingRound" },
	{ "Textures/Arcane/Arcane_IconRing", "Interface\\AddOns\\Manners\\Textures\\Arcane\\Arcane_IconRing" },
	{ "Textures/Arcane/Arcane_IconRingSq", "Interface\\AddOns\\Manners\\Textures\\Arcane\\Arcane_IconRingSq" },
	{ "Textures/Arcane/Arcane_RuneRing", "Interface\\AddOns\\Manners\\Textures\\Arcane\\Arcane_RuneRing" },
	{ "Textures/Arcane/Arcane_RuneRingSq", "Interface\\AddOns\\Manners\\Textures\\Arcane\\Arcane_RuneRingSq" },
	{ "Textures/Toast/Toast_RingGlow", "Interface\\AddOns\\Manners\\Textures\\Toast\\Toast_RingGlow" },
}

withTree("hunt37-effects: each ring's declared reach is the reach of its art", ANNA, function(ns, scenario)
	local lib = ns.Prompt.lib
	-- A look registers its files when it is built.
	for _, style in ipairs({ "luxe", "toast", "arcane", "letter", "slate" }) do
		freshPrompt(ns, scenario)
		ns.db.profile.prompt.style = style
		ns.Prompt:ApplyStyle()
	end
	for _, file in ipairs(RING_FILES) do
		local tga = readTGA(dir .. "/" .. file[1] .. ".tga")
		local art = lib.RingArtOf and lib.RingArtOf(file[2])
		if not tga then
			fail(scenario, file[1] .. ".tga cannot be read as a 32-bit TGA")
		elseif not art then
			fail(scenario, file[1] .. " is drawn as a ring and the code does not say how far out it is seen")
		else
			local reach = reachOf(tga)
			if art.edge < reach - 0.0005 then
				fail(scenario, ("%s is seen out to %.3f of its half-width, the code says %.3f"):format(file[1], reach, art.edge))
			end
			if art.edge > reach + 0.06 then
				fail(scenario, ("%s is seen out to %.3f, the code says %.3f: the ring is held to more room than it needs"):format(
					file[1], reach, art.edge))
			end
		end
	end
end)

-- ------------------------------------------------------------------ 3
-- Every frame of light under the art is beneath the text, by frame level and
-- not by the order the frames were made in: the rings, the halo, the echo, the
-- band across the panel.
local function levelOf(f)
	return f and f._level or 0
end

-- The frame a texture or string is drawn with.
local function ownerOf(r)
	if r._kind == "Texture" or r._kind == "FontString" or r._kind == "MaskTexture" then return r._parent end
	return r
end

for _, style in ipairs(ALL) do
	local name = "hunt37-effects: the light is drawn beneath the text, in " .. style
	withTree(name, ANNA, function(ns, scenario)
		local r = upIn(ns, scenario, style, SIZES[1])
		local art, textLayer = r.art, r.textLayer
		local textLevel = levelOf(textLayer)
		local look = r.look
		-- The text's own strings: the name, wherever the look keeps it.
		for _, fs in ipairs({ r.name, r.sub }) do
			if levelOf(ownerOf(fs)) < levelOf(art) + 1 then
				fail(scenario, "a line of text is not above the art")
			end
		end
		-- The effects: the frames that scale, and the light that crosses.
		local lit = {}
		local fx = look and look.fx or r.fx
		for _, ring in ipairs(fx.rings) do lit[#lit + 1] = { "a ring", ring.frame } end
		if fx.echo then lit[#lit + 1] = { "the icon's echo", fx.echo.frame } end
		if not look then
			lit[#lit + 1] = { "the halo that flares", r.burst }
			lit[#lit + 1] = { "the band across the panel", r.shine }
			lit[#lit + 1] = { "the glow", r.glow }
			lit[#lit + 1] = { "the rim", r.rim }
		elseif look.key == "luxe" then
			lit[#lit + 1] = { "the band across the panel", look.sheenFrame }
		elseif look.key == "arcane" then
			lit[#lit + 1] = { "the band across the panel", look.shineFrame }
			lit[#lit + 1] = { "the lift", look.liftFrame }
		end
		for _, item in ipairs(lit) do
			local f = item[2]
			if f == nil then
				fail(scenario, item[1] .. " is not there to be held beneath the text")
			elseif levelOf(f) >= textLevel then
				fail(scenario, ("%s is at frame level %d, not under the text's %d"):format(item[1], levelOf(f), textLevel))
			end
		end
		-- And nothing but the text's own frames above the art draws over it
		-- unless it is meant to: the direct children of the art that are
		-- shown and are not the text hold a level under the text's.
		for _, child in ipairs(art._children or {}) do
			if child ~= textLayer and child._kind ~= "Texture" and child._kind ~= "FontString"
				and child._kind ~= "MaskTexture" and child._shown ~= false then
				local isLight = false
				for _, item in ipairs(lit) do if item[2] == child then isLight = true end end
				if isLight and levelOf(child) >= textLevel then
					fail(scenario, "a frame of light is not under the text")
				end
			end
		end
	end)
end
