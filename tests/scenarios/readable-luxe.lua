-- The Luxe look, read the way the game draws it (1.5.1).
--
-- 1.5.0 was tuned by eye against tools/render_prompt.py, which lays added
-- light and pale fills on far more gently than the game does, and in game the
-- tag read white on white. So nothing here looks at a picture: it works out
-- what lies under each line of text and over the spell icon from what the
-- frames were told (tests/frametree.lua) and the art itself (Textures/Luxe,
-- read texel by texel), and holds it to three rules.
--
--   1. The spell icon is drawn clean. Over the icon, at rest, nothing but a
--      frame hugging its edge: at every point more than two units inside its
--      shape, no texture drawn above it adds anything. A flourish of half a
--      second or less may cross it; nothing that stays or runs longer.
--   2. Text has a dark ground. Under the name line and under the tag, the
--      look composited over a world of luminance 0.30 and, apart, a snowfield
--      of 0.85 gives 4.5:1 or better for every colour the line can be: white,
--      the gold |cffffd100, class colours as the look softens them, and on the
--      tag every reason in both palettes and every outcome. Added light counts
--      double, since the game draws it brighter than it is written. A texture
--      keeps one alpha in the game, so each layer is taken both ways -- its
--      colour's alpha times SetAlpha's, and SetAlpha's alone once set -- and
--      the worse is what counts. The tag's and the chip's fills are held solid
--      enough (0.85 or more) that the answer holds however alpha is weighed.
--   3. The count chip never covers the icon.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" } }
local LAYERS = FT.LAYERS
local MIN_RATIO = 4.5
-- Anything drawn over the icon's inside adds less than one step of 255.
local CLEAN = 1 / 255
-- A flourish that may cross the icon, and one that may cross the text.
local ICON_FLOURISH, TEXT_FLOURISH = 0.5, 1.1

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

-- ------------------------------------------------------------------ colour

-- The addon's own measure (Prompt.lua's Luminance and Ratio), re-derived.
local function lin(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end
local function luminance(r, g, b) return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b) end
local function ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end
-- The grey whose luminance is `l`.
local function greyOf(l)
	local lo, hi = 0, 1
	for _ = 1, 30 do
		local m = (lo + hi) / 2
		if lin(m) < l then lo = m else hi = m end
	end
	return (lo + hi) / 2
end
local WORLDS = { { "a dusky world", greyOf(0.30) }, { "snow", greyOf(0.85) } }

local GOLD = { 1, 0xd1 / 255, 0 }
-- The game's class colours, as the name line is given them before the look
-- softens them.
local CLASSES = { "c69b6d", "f48cba", "aad372", "fff468", "ffffff", "c41e3a", "0070dd", "3fc7eb",
	"8788ee", "00ff98", "ff7c0a", "a330c9", "33937f" }

local function nameColours(soften)
	local out = { { "white", { 1, 1, 1 } }, { "the gold |cffffd100", GOLD } }
	for _, hex in ipairs(CLASSES) do
		local c = {}
		for i = 1, 3 do
			local v = tonumber(hex:sub(2 * i - 1, 2 * i), 16) / 255
			c[i] = math.floor((v + (1 - v) * (soften or 0)) * 255 + 0.5) / 255
		end
		out[#out + 1] = { "the class colour " .. hex, c }
	end
	return out
end

-- ------------------------------------------------------------------ art

-- The shipped TGA: 32-bit, uncompressed, as tools/make_luxe_textures.py
-- writes it. Alpha and grey, top row first.
local art = {}
local function readArt(file)
	if art[file] ~= nil then return art[file] or nil end
	local leaf = type(file) == "string" and file:match("Textures\\Luxe\\(Luxe_[%w]+)$")
	local img = false
	if leaf then
		local f = io.open(dir .. "/Textures/Luxe/" .. leaf .. ".tga", "rb")
		if f then
			local data = f:read("*a")
			f:close()
			local w = data:byte(13) + 256 * data:byte(14)
			local h = data:byte(15) + 256 * data:byte(16)
			local topDown = math.floor(data:byte(18) / 32) % 2 == 1
			local start = 18 + data:byte(1)
			img = { w = w, h = h, a = {}, v = {} }
			for row = 0, h - 1 do
				local top = topDown and row or (h - 1 - row)
				for col = 0, w - 1 do
					local at = start + (row * w + col) * 4
					local i = top * w + col + 1
					-- BGRA; the art is grey, so one channel is its colour.
					img.v[i] = data:byte(at + 1) / 255
					img.a[i] = data:byte(at + 4) / 255
				end
			end
		end
	end
	art[file] = img
	return img or nil
end

-- ------------------------------------------------------------------ layout

-- Where each region sits, from its anchors, as tests/scenarios/look.lua works
-- it out. Rects are { left, bottom, right, top }.
local function layout(snapshot)
	local byId, rects = {}, {}
	local root
	for _, r in ipairs(snapshot) do
		byId[r.id] = r
		if r.parent == nil then root = r.id end
	end
	local function frac(point)
		local fx, fy = 0.5, 0.5
		if point:find("LEFT", 1, true) then fx = 0 elseif point:find("RIGHT", 1, true) then fx = 1 end
		if point:find("BOTTOM", 1, true) then fy = 0 elseif point:find("TOP", 1, true) then fy = 1 end
		return fx, fy
	end
	local busy = {}
	local function rect(id)
		if rects[id] then return rects[id] end
		if id == root then rects[id] = { 0, 0, 1600, 1000 } return rects[id] end
		local r = byId[id]
		if not r or busy[id] then return nil end
		busy[id] = true
		local L, R, B, T, CX, CY
		for _, p in ipairs(r.points or {}) do
			local rel = rect(p[2] or r.parent)
			if rel then
				local rfx, rfy = frac(p[3] or p[1])
				local ax = rel[1] + (rel[3] - rel[1]) * rfx + (p[4] or 0)
				local ay = rel[2] + (rel[4] - rel[2]) * rfy + (p[5] or 0)
				local fx, fy = frac(p[1])
				if fx == 0 then L = ax elseif fx == 1 then R = ax else CX = ax end
				if fy == 0 then B = ay elseif fy == 1 then T = ay else CY = ay end
			end
		end
		local w, h = r.width or 0, r.height or 0
		if not (L and R) then
			if L then R = L + w elseif R then L = R - w elseif CX then L, R = CX - w / 2, CX + w / 2 end
		end
		if not (B and T) then
			if B then T = B + h elseif T then B = T - h elseif CY then B, T = CY - h / 2, CY + h / 2 end
		end
		busy[id] = nil
		if not (L and R and B and T) then return nil end
		rects[id] = { L, B, R, T }
		return rects[id]
	end
	return rect
end

-- ------------------------------------------------------------------ the scene

local function under(x, top)
	while x do
		if x == top then return true end
		x = x._parent
	end
	return false
end

-- The highest alpha a frame reaches while it stays: its own, or the top of any
-- animation playing on it that loops or runs longer than a flourish may.
local function frameAlpha(f, flourish)
	local a = f._alpha or 1
	for _, g in ipairs(f._groups or {}) do
		if g._playing and ((g._looping and g._looping ~= "NONE") or FT.groupLength(g) > flourish) then
			for _, anim in ipairs(g._anims) do
				a = math.max(a, anim._fromAlpha or 0, anim._toAlpha or 0)
			end
		end
	end
	return a
end

local function chainAlpha(r, flourish)
	local a = 1
	local f = r._parent
	while f do
		a = a * frameAlpha(f, flourish)
		f = f._parent
	end
	return a
end

-- Draw order: frame level, then layer, then sublevel.
local function order(r)
	local f = r._parent
	return (f and f._level or 0) * 10000 + (LAYERS[r._layer or "ARTWORK"] or 3) * 100 + (r._sublevel or 0)
end

-- Everything the prompt draws right now, laid out: each texture with its
-- rect, draw order and the alphas it may be drawn at.
local function scene(ns, flourish)
	local regions = ns.Prompt:Regions()
	local rect = layout(FT.snapshot())
	local out = { rect = rect, textures = {}, regions = regions }
	for _, t in ipairs(FT.all) do
		if t._kind == "Texture" and t ~= regions.icon and under(t, regions.art) and FT.visible(t)
			and t._layer ~= "HIGHLIGHT" then
			local box = rect(t._serial)
			local img = t._file and readArt(t._file)
			if box and (img or t._colorTexture) and box[3] - box[1] > 0.01 and box[4] - box[2] > 0.01 then
				out.textures[#out.textures + 1] = { t = t, box = box, img = img, order = order(t),
					chain = chainAlpha(t, flourish), add = t._blend == "ADD" }
			end
		end
	end
	table.sort(out.textures, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.t._serial < b.t._serial
	end)
	return out
end

-- The texel under (x, y) of a laid-out texture: its alpha and grey, or nil
-- outside it.
local function texel(item, x, y)
	local b = item.box
	if x < b[1] or x > b[3] or y < b[2] or y > b[4] then return nil end
	local img = item.img
	if not img then return item.t._colorTexture[4] or 1, 1 end
	local tc = item.t._texCoord or { 0, 1, 0, 1 }
	local u = tc[1] + (x - b[1]) / (b[3] - b[1]) * (tc[2] - tc[1])
	local v = tc[3] + (b[4] - y) / (b[4] - b[2]) * (tc[4] - tc[3])
	local col = math.max(0, math.min(img.w - 1, math.floor(u * img.w)))
	local row = math.max(0, math.min(img.h - 1, math.floor(v * img.h)))
	local i = row * img.w + col + 1
	return img.a[i], img.v[i]
end

-- The colour and alpha a texture is drawn with at height `y`, taken the two
-- ways the game may weigh a texture's alpha (see the top of this file).
local function paint(item, y)
	local t = item.t
	local r, g, b, a
	local grad = t._gradient
	if grad and grad[2] and grad[3] then
		local k = math.max(0, math.min(1, (y - item.box[2]) / math.max(0.01, item.box[4] - item.box[2])))
		local c1, c2 = grad[2], grad[3]
		r = c1.r + (c2.r - c1.r) * k
		g = c1.g + (c2.g - c1.g) * k
		b = c1.b + (c2.b - c1.b) * k
		a = (c1.a or 1) + ((c2.a or 1) - (c1.a or 1)) * k
	elseif t._colorTexture then
		r, g, b, a = t._colorTexture[1], t._colorTexture[2], t._colorTexture[3], 1
	else
		local c = t._color or {}
		r, g, b, a = c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
	end
	local set = t._alpha
	local times = a * (set or 1)
	local alone = set ~= nil and set or a
	return r, g, b, times * item.chain, alone * item.chain
end

-- ------------------------------------------------------------------ rule 1

-- Whether (x, y) lies more than `depth` units inside the icon's own shape.
local function deepInside(mask, box, x, y, depth)
	local k = depth * 0.7071
	for _, d in ipairs({ { 0, 0 }, { depth, 0 }, { -depth, 0 }, { 0, depth }, { 0, -depth }, { k, k }, { -k, k },
		{ k, -k }, { -k, -k } }) do
		local px, py = x + d[1], y + d[2]
		if px <= box[1] or px >= box[3] or py <= box[2] or py >= box[4] then return false end
		if mask then
			local a = texel(mask, px, py)
			if not a or a < 0.5 then return false end
		end
	end
	return true
end

-- Half a texel of a texture, in units: a texel is drawn whole, so a frame's
-- line that ends within two units of the edge may show half a texel further.
local function halfTexel(item)
	if not item.img then return 0 end
	local tc = item.t._texCoord or { 0, 1, 0, 1 }
	local b = item.box
	local ux = (b[3] - b[1]) / math.max(1e-6, math.abs(tc[2] - tc[1]) * item.img.w)
	local uy = (b[4] - b[2]) / math.max(1e-6, math.abs(tc[4] - tc[3]) * item.img.h)
	return 0.5 * math.max(ux, uy)
end

local deepCache = {}

local function iconOffender(ns)
	local s = scene(ns, ICON_FLOURISH)
	local regions = s.regions
	local icon = regions.icon
	if not FT.visible(icon) then return nil end
	local box = s.rect(icon._serial)
	if not box then return "the icon was not laid out", 1 end
	local mask
	if icon._mask and icon._mask._file then
		mask = { t = icon._mask, box = box, img = readArt(icon._mask._file) }
		if not mask.img then mask = nil end
	end
	-- The points more than `depth` units inside the icon's shape, one a unit.
	local function deepAt(depth)
		local key = ("%s:%.2f:%.2f:%.2f:%.2f:%.1f"):format(tostring(mask and icon._mask._file), box[1], box[2],
			box[3], box[4], depth)
		local deep = deepCache[key]
		if not deep then
			deep = {}
			for x = math.floor(box[1]) + 0.5, box[3], 1 do
				for y = math.floor(box[2]) + 0.5, box[4], 1 do
					if deepInside(mask, box, x, y, depth) then deep[#deep + 1] = { x, y } end
				end
			end
			deepCache[key] = deep
		end
		return deep
	end
	if #deepAt(2) == 0 then return "no point of the icon was found inside it", 1 end
	local iconOrder = order(icon)
	local worst, worstFile = 0, nil
	for _, item in ipairs(s.textures) do
		local b = item.box
		if item.order >= iconOrder and b[1] < box[3] and box[1] < b[3] and b[2] < box[4] and box[2] < b[4] then
			-- A frame goes all the way round the icon, and may draw on its
			-- outer two units; anything else draws nowhere on it.
			local frame = b[1] <= box[1] + 0.01 and b[3] >= box[3] - 0.01 and b[2] <= box[2] + 0.01
				and b[4] >= box[4] - 0.01
			local depth = frame and math.ceil((2 + halfTexel(item)) * 10) / 10 or 0
			for _, pt in ipairs(deepAt(depth)) do
				local ta = texel(item, pt[1], pt[2])
				if ta and ta > 0 then
					local _, _, _, a1, a2 = paint(item, pt[2])
					local added = ta * math.max(a1, a2) * (item.add and 2 or 1)
					if added > worst then worst, worstFile = added, tostring(item.t._file) end
				end
			end
		end
	end
	if worst >= CLEAN then return worstFile, worst end
	return nil
end

-- ------------------------------------------------------------------ rule 2

-- The ground at (x, y) under text drawn at `textOrder`, over a world of grey
-- `world`, the two ways alpha may be weighed; `solid` draws `solidItem` at
-- full alpha (a fill "however the game treats alpha").
local function ground(s, textOrder, x, y, world, way, solidItem)
	local r, g, b = world, world, world
	for _, item in ipairs(s.textures) do
		if item.order <= textOrder then
			local ta, tv = texel(item, x, y)
			if ta and ta > 0 then
				local cr, cg, cb, a1, a2 = paint(item, y)
				local a = (way == 1) and a1 or a2
				if item == solidItem then a = 1 end
				a = a * ta
				cr, cg, cb = cr * tv, cg * tv, cb * tv
				if item.add then
					r = math.min(1, r + cr * 2 * a)
					g = math.min(1, g + cg * 2 * a)
					b = math.min(1, b + cb * 2 * a)
				else
					a = math.min(1, a)
					r = cr * a + r * (1 - a)
					g = cg * a + g * (1 - a)
					b = cb * a + b * (1 - a)
				end
			end
		end
	end
	return r, g, b
end

-- The worst contrast any of `colours` gets anywhere in `box` (a line's own
-- extent), and where. On one ground the worst colour is the darkest or the
-- lightest, so only those two are drawn.
local function worstContrast(s, fs, box, colours, solidItem)
	local textOrder = order(fs)
	local textAlpha = (fs._alpha or 1) * chainAlpha(fs, TEXT_FLOURISH)
	local dark, light
	for _, c in ipairs(colours) do
		local l = luminance(c[2][1], c[2][2], c[2][3])
		if not dark or l < dark[3] then dark = { c[1], c[2], l } end
		if not light or l > light[3] then light = { c[1], c[2], l } end
	end
	local extremes = { dark, light }
	-- Only what can lie under the line.
	local layers = {}
	for _, item in ipairs(s.textures) do
		local b = item.box
		if item.order <= textOrder and b[1] < box[3] and box[1] < b[3] and b[2] < box[4] and box[2] < b[4] then
			layers[#layers + 1] = item
		end
	end
	local sub = { textures = layers }
	local worst, why = math.huge, nil
	local step = 2
	for x = box[1] + 0.25, box[3], step do
		for y = box[2] + 0.25, box[4], step do
			for _, world in ipairs(WORLDS) do
				for way = 1, solidItem and 3 or 2 do
					local gr, gg, gb = ground(sub, textOrder, x, y, world[2], math.min(way, 2),
						way == 3 and solidItem or nil)
					local lg = luminance(gr, gg, gb)
					for _, c in ipairs(extremes) do
						local cc = c[2]
						-- The text itself at its own alpha, over that ground.
						local tr = cc[1] * textAlpha + gr * (1 - textAlpha)
						local tg = cc[2] * textAlpha + gg * (1 - textAlpha)
						local tb = cc[3] * textAlpha + gb * (1 - textAlpha)
						local q = ratio(luminance(tr, tg, tb), lg)
						if q < worst then
							worst = q
							why = ("%s over %s (ground %.2f %.2f %.2f)"):format(c[1], world[1], gr, gg, gb)
						end
					end
				end
			end
		end
	end
	return worst, why
end

-- The name line's extent: where its anchors put it, a line of its size tall.
local function nameBox(s, name)
	local b = s.rect(name._serial)
	if not b then return nil end
	local size = (name._font and name._font.size) or 13
	local cy = (b[2] + b[4]) / 2
	return { b[1], cy - 0.6 * size, b[3], cy + 0.6 * size }
end

-- The tag's words: from where the line starts (past a verdict's tick) to the
-- far cap, a line of its size tall.
local function pillTextBox(s, look, sub)
	local b = s.rect(look.pillFrame._serial)
	local own = s.rect(sub._serial)
	if not (b and own) then return nil end
	local size = (sub._font and sub._font.size) or 10
	local cap = (b[4] - b[2]) / 2
	local cy = (b[2] + b[4]) / 2
	return { math.max(b[1] + cap, own[1]), cy - 0.5 * size, b[3] - cap, cy + 0.5 * size }
end

local function textColour(fs)
	local c = fs._textColor or { 1, 1, 1 }
	return { c[1], c[2], c[3] }
end

local function pillItem(s, look, list)
	for _, item in ipairs(s.textures) do
		if item.t == look[list][2] then return item end
	end
	return nil
end

-- Rule 2 on the lines as they stand: the name in every colour a name can be,
-- the tag in the colour it is painted.
local function readable(ns, scenario, label, extraNameColours)
	local s = scene(ns, TEXT_FLOURISH)
	local r = s.regions
	local look = r.look
	if not look.clear and FT.visible(r.name) and (r.name._text or "") ~= "" then
		local box = nameBox(s, r.name)
		if box then
			local colours = nameColours(look.classSoften or 0.85)
			colours[#colours + 1] = { "the name's own colour", textColour(r.name) }
			for _, c in ipairs(extraNameColours or {}) do colours[#colours + 1] = c end
			local q, why = worstContrast(s, r.name, box, colours)
			if q < MIN_RATIO then
				fail(scenario, ("%s: the name line reads %.2f:1 on its ground, not %.1f -- %s")
					:format(label, q, MIN_RATIO, why))
			end
		end
	end
	if FT.visible(look.pillFrame) and FT.visible(r.sub) then
		local box = pillTextBox(s, look, r.sub)
		local fill = pillItem(s, look, "pillFill")
		if box then
			local q, why = worstContrast(s, r.sub, box, { { "the tag's words", textColour(r.sub) } }, fill)
			if q < MIN_RATIO then
				fail(scenario, ("%s: the reason line reads %.2f:1 on its tag, not %.1f -- %s")
					:format(label, q, MIN_RATIO, why))
			end
		end
		local c = look.pillFill[2]._color
		if not (c and (c[4] or 1) >= 0.85) then
			fail(scenario, label .. ": the tag's fill is not solid enough to stay dark however the game weighs it")
		end
	end
	if FT.visible(r.count) and FT.visible(look.chipFill[2]) then
		local b = s.rect(look.chipBox._serial)
		local size = (r.count._font and r.count._font.size) or 10
		if b then
			local cy = (b[2] + b[4]) / 2
			local cap = (b[4] - b[2]) / 2
			local box = { b[1] + cap, cy - 0.5 * size, b[3] - cap, cy + 0.5 * size }
			local q, why = worstContrast(s, r.count, box, { { "the count", textColour(r.count) } },
				pillItem(s, look, "chipFill"))
			if q < MIN_RATIO then
				fail(scenario, ("%s: the count reads %.2f:1 on its chip, not %.1f -- %s")
					:format(label, q, MIN_RATIO, why))
			end
		end
		local c = look.chipFill[2]._color
		if not (c and (c[4] or 1) >= 0.85) then
			fail(scenario, label .. ": the count chip's fill is not solid enough to stay dark")
		end
	end
end

local function clean(ns, scenario, label)
	local file, amount = iconOffender(ns)
	if file then
		fail(scenario, ("%s: %s is drawn over the spell icon (adds %.3f inside it)"):format(label, file, amount))
	end
end

-- ------------------------------------------------------------------ driving

local REASONS = { "target", "owed", "asked", "group", "nearby", "self" }

local function settle(ns)
	Mock.advance(2)
	ns.addon:Tick()
	FT.settle()
end

-- Every setting these scenarios change, back to its default first: the
-- profile outlives freshPrompt.
local TOUCHED = { "roundIcon", "showIcon", "width", "height", "fontSize", "iconSize", "accentMode",
	"effects", "bgColor", "reasonPalette", "showSub", "showCount" }

local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	local d = ns.defaults.profile.prompt
	for _, key in ipairs(TOUCHED) do p[key] = d[key] end
	p.style = "luxe"
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	settle(ns)
	return ns.Prompt:Regions(), p
end

local function isLuxe(r) return r.look ~= nil and r.look.spine ~= nil and r.look.pillFill ~= nil end

-- The same panel painted in every reason of both palettes, each read.
local function everyReason(ns, scenario, p, label, check)
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		for _, reason in ipairs(REASONS) do
			ns.Prompt:PaintAccent(reason)
			check(("%s, %s (%s)"):format(label, reason, palette))
		end
	end
	p.reasonPalette = "standard"
end

local function hover(ns, on)
	local b = ns.Prompt:GetButton()
	if on then b.scripts.OnEnter(b) else b.scripts.OnLeave(b) end
	Mock.advance(0.5)
	FT.settle()
end

-- The settings the rules are held across: the default card, a round icon,
-- none, a big one on a big panel, the reason on the card's edge as well.
local SHAPES = {
	{ "the default card" },
	{ "a round icon", function(p) p.roundIcon = true end },
	{ "no icon", function(p) p.showIcon = false end },
	{ "a big panel", function(p) p.width, p.height, p.fontSize, p.iconSize = 320, 64, 17, 54 end },
	{ "\"Reason colour: both\"", function(p) p.accentMode = "both" end },
}

-- ------------------------------------------------------------------ 1
withTree("Luxe draws the spell icon clean", ANNA, function(ns, scenario)
	for _, shape in ipairs(SHAPES) do
		local r, p = upIn(ns, scenario, shape[2])
		if not isLuxe(r) then
			fail(scenario, "SKIPPED -- Luxe is not the look in use")
			return
		end
		local label = shape[1]
		if shape[1] ~= "no icon" and not FT.visible(r.icon) then
			fail(scenario, label .. ": the icon is not shown")
		end
		-- At rest, somebody owed on top: the spine breathes.
		everyReason(ns, scenario, p, label .. " at rest", function(l) clean(ns, scenario, l) end)
		-- A new favour arriving: the flare, the tag's pop, the crossing light,
		-- caught while they play.
		owe(ns, "Brannoc Vale")
		ns.owed["Anna Aim"] = nil
		ns.addon:Tick()
		clean(ns, scenario, label .. " as a favour arrives")
		settle(ns)
		-- The cursor on the panel, and held there.
		hover(ns, true)
		clean(ns, scenario, label .. " under the cursor")
		-- A buff that landed, while it plays and after.
		ns.Prompt:ShowOutcome("cast", "Brannoc Vale")
		clean(ns, scenario, label .. " as a buff lands")
		hover(ns, false)
		settle(ns)
		clean(ns, scenario, label .. " after a buff landed")
		-- Calm holds the outcome's light instead of fading it.
		p.effects = "calm"
		ns.Prompt:ApplyStyle()
		settle(ns)
		hover(ns, true)
		ns.Prompt:ShowOutcome("cast", "Brannoc Vale")
		clean(ns, scenario, label .. " on Calm with a buff landed")
		Mock.advance(3)
		ns.addon:Tick()
		ns.Prompt:ShowOutcome("failed", "Brannoc Vale", "Out of range.")
		clean(ns, scenario, label .. " on Calm with a refusal")
		hover(ns, false)
		-- A fight.
		Mock.advance(3)
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		settle(ns)
		clean(ns, scenario, label .. " in a fight")
		Mock.inCombat = false
		if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
		settle(ns)
		clean(ns, scenario, label .. " after a fight")
	end
end)

-- ------------------------------------------------------------------ 2
withTree("Luxe's text stands on a dark ground", ANNA, function(ns, scenario)
	for _, shape in ipairs(SHAPES) do
		local r, p = upIn(ns, scenario, shape[2])
		if not isLuxe(r) then
			fail(scenario, "SKIPPED -- Luxe is not the look in use")
			return
		end
		local label = shape[1]
		if not FT.visible(r.look.pillFrame) then fail(scenario, label .. ": the tag is not up") end
		local function read(l) readable(ns, scenario, l) end
		-- At rest, under the cursor, in a fight: every reason.
		everyReason(ns, scenario, p, label .. " at rest", read)
		hover(ns, true)
		everyReason(ns, scenario, p, label .. " under the cursor", read)
		hover(ns, false)
		-- The fight starting on each reason, before anything repaints.
		everyReason(ns, scenario, p, label .. " as a fight starts", function(l)
			ns.Prompt:SetCombatHold(true)
			read(l)
			ns.Prompt:SetCombatHold(false)
		end)
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		settle(ns)
		everyReason(ns, scenario, p, label .. " in a fight", read)
		Mock.inCombat = false
		if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
		settle(ns)
		-- The outcomes, held on Calm with the cursor on the panel: the
		-- outcome's light at its brightest and staying.
		p.effects = "calm"
		ns.Prompt:ApplyStyle()
		settle(ns)
		hover(ns, true)
		for _, case in ipairs({ { "cast" }, { "failed", "Out of range." }, { "sent" } }) do
			Mock.advance(3)
			ns.addon:Tick()
			ns.Prompt:ShowOutcome(case[1], "Anna Aim", case[2])
			readable(ns, scenario, ("%s, a %s outcome held under the cursor"):format(label, case[1]))
		end
		hover(ns, false)
		p.effects = "full"
		-- A line with a colour of its own takes its tag with it.
		Mock.advance(3)
		ns.Prompt:ApplyStyle()
		settle(ns)
		ns.Prompt:PaintAccent("owed")
		for _, code in ipairs({ "ff3030", "ffd100", "40ff40", "ffffff" }) do
			r.look.kit.SetLine(r.sub, "|cff" .. code .. "held|r")
			readable(ns, scenario, ("%s, a reason line in |cff%s"):format(label, code))
		end
		-- The count chip up.
		ns.Prompt:Paint({ name = "Anna Aim", short = "Anna", reason = "owed", buff = ns.ResolveBuff(true) }, 12)
		readable(ns, scenario, label .. " with the count up")
	end
	-- A nearly clear panel: the name is outlined over the world, but the tag
	-- carries its own dark ground.
	local r, p = upIn(ns, scenario, function(pp) pp.bgColor = { 0.04, 0.04, 0.06, 0.1 } end)
	if isLuxe(r) then
		everyReason(ns, scenario, p, "a nearly clear panel", function(l) readable(ns, scenario, l) end)
	end
end)

-- ------------------------------------------------------------------ 3
withTree("Luxe's count chip keeps off the icon", ANNA, function(ns, scenario)
	local cases = {
		{ "the default card" },
		{ "the narrowest panel", function(p) p.width = 80 end },
		{ "the biggest icon", function(p) p.width, p.height, p.iconSize = 120, 120, 64 end },
		{ "a narrow panel and a big font", function(p) p.width, p.fontSize = 110, 20 end },
		{ "one line", function(p) p.showSub = false end },
	}
	for _, case in ipairs(cases) do
		local r = upIn(ns, scenario, case[2])
		if not isLuxe(r) then
			fail(scenario, "SKIPPED -- Luxe is not the look in use")
			return
		end
		for _, who in ipairs({ "Al", "Anna", "Annabelle-Marguerite" }) do
			ns.Prompt:Paint({ name = "Anna Aim", short = who, reason = "owed", buff = ns.ResolveBuff(true) }, 12)
			local rect = layout(FT.snapshot())
			local icon = FT.visible(r.icon) and rect(r.icon._serial)
			if icon then
				for i, t in ipairs(r.look.chipFill) do
					local b = FT.visible(t) and rect(t._serial)
					if b and b[1] < icon[3] and icon[1] < b[3] and b[2] < icon[4] and icon[2] < b[4] then
						fail(scenario, ("%s, %s: the count chip covers the icon (piece %d)"):format(case[1], who, i))
						break
					end
				end
				local c = FT.visible(r.count) and rect(r.count._serial)
				if c and (c[1] + c[3]) / 2 < icon[3] then
					fail(scenario, ("%s, %s: the count sits on the icon"):format(case[1], who))
				end
			end
		end
	end
end)
