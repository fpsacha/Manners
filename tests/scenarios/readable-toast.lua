-- The Toast look (Looks/Toast.lua) read the way the game draws it.
--
-- 1.5.0's toast was tuned by eye against tools/render_prompt.py, which adds
-- light far more gently than the client does. In the game the banner turned
-- gold behind a gold name, and a gloss and a shade over the spell icon washed
-- it out. So nothing here looks at a picture: every rule is arithmetic on what
-- the frames were told (tests/frametree.lua) and on the texels of the files
-- the look ships, composited the way the client composites them.
--
--   1. The spell icon is drawn clean. At rest nothing drawn above it overlaps
--      its box, except the medallion's gold lip, whose texels are clear
--      everywhere more than 2 units inside the icon's drawn edge.
--   2. The text has a dark ground. Under the name line and the reason line,
--      over a world of luminance 0.30 and of 0.85 (a snowfield), every colour
--      the text can be -- white, the look's ivory, the |cffffd100 gold of the
--      preview and several lines, each class colour as the look softens it,
--      and the reason line in every reason of both palettes and every verdict
--      -- clears 4.5:1. An ADD layer counts at twice its alpha: the client
--      draws them brighter than the preview does.
--   3. The count's chip never covers the icon.
--
-- The one-shot flourishes (the rails' glints, the flare, the burst, the
-- arrival's ring of light: 0.6 s at most, on Full only, and the only ADD
-- light the look has -- tests/scenarios/look-toast.lua holds it to that) are
-- left to settle first; everything that stays -- rest, the owed pulse at its
-- brightest, the cursor's light, an outcome held on Calm -- is judged.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local COMMAND = "CLICK MannersPrompt:LeftButton"

-- The sizes judged: the default, the smallest two-line panel, larger fonts,
-- the tallest panel the options allow.
local SIZES = {
	{ 220, 44, 13 }, { 180, 36, 11 }, { 320, 58, 17 }, { 230, 70, 13 }, { 360, 120, 24 },
}

-- The world behind the prompt, as relative luminance.
local WORLDS = { 0.30, 0.85 }
local MINIMUM = 4.5
-- An ADD layer is counted at this many times its alpha.
local ADD_WEIGHT = 2
-- A layer fainter than this over the icon is not drawn on it.
local FAINT = 0.02
-- How far inside the icon's drawn edge its frame may reach, in UI units.
local LIP_UNITS = 2

-- The game's class colours, as RAID_CLASS_COLORS gives them (the mock carries
-- two), for the names a softened class colour paints.
local CLASS_CODES = { "ffc41e3a", "ffa330c9", "ffff7c0a", "ff33937f", "ffaad372", "ff3fc7eb",
	"ff00ff98", "fff48cba", "ffffffff", "fffff468", "ff0070dd", "ff8788ee", "ffc69b6d" }
local WHITE, GOLD = { 1, 1, 1 }, { 1, 0xd1 / 255, 0 }

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

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

-- Past every one-shot flourish, which FT.settle then finishes.
local function rest(ns)
	Mock.advance(3)
	tick(ns)
end

local function isToast(look)
	return look ~= nil and look.band ~= nil and look.ember ~= nil
end

-- The prompt up in Toast with Anna owed on top, settled. Returns the regions,
-- the settings and the look.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "toast"
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	rest(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

---------------------------------------------------------------------------
-- colour arithmetic, derived here and not borrowed from Prompt/
---------------------------------------------------------------------------

local function linear(c)
	if c <= 0.04045 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function luminance(r, g, b)
	return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
end

local function ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- The grey whose luminance is `l`.
local function greyOf(l)
	if l <= 0.0031308 then return l * 12.92 end
	return 1.055 * l ^ (1 / 2.4) - 0.055
end

local function soften(code, by)
	local out = {}
	for i = 1, 3 do
		local v = tonumber(code:sub(1 + 2 * i, 2 + 2 * i), 16) / 255
		out[i] = math.floor((v + (1 - v) * by) * 255 + 0.5) / 255
	end
	return out
end

---------------------------------------------------------------------------
-- the files the look ships, read as the client reads them
---------------------------------------------------------------------------

local images = {}

-- A 24- or 32-bit uncompressed TGA, or false for a file that is not ours (a
-- client texture, drawn here as solid white).
local function image(file)
	if type(file) ~= "string" then return false end
	local hit = images[file]
	if hit ~= nil then return hit end
	local rel = file:match("^Interface\\AddOns\\Manners\\(.+)$")
	if not rel then images[file] = false return false end
	local f = io.open(dir .. "/" .. rel:gsub("\\", "/") .. ".tga", "rb")
	if not f then images[file] = false return false end
	local data = f:read("*a")
	f:close()
	local kind, bpp, desc = data:byte(3), data:byte(17), data:byte(18)
	if kind ~= 2 or (bpp ~= 32 and bpp ~= 24) then
		error(file .. ".tga is not an uncompressed 24/32-bit TGA")
	end
	hit = {
		data = data, start = 18 + data:byte(1), bytes = bpp / 8,
		w = data:byte(13) + data:byte(14) * 256, h = data:byte(15) + data:byte(16) * 256,
		topDown = desc % 64 >= 32,
	}
	images[file] = hit
	return hit
end

local function pixel(img, x, y)
	if x < 0 then x = 0 elseif x >= img.w then x = img.w - 1 end
	if y < 0 then y = 0 elseif y >= img.h then y = img.h - 1 end
	local row = img.topDown and y or (img.h - 1 - y)
	local at = img.start + (row * img.w + x) * img.bytes + 1
	local b, g, r, a = img.data:byte(at, at + 3)
	if img.bytes == 3 then a = 255 end
	return r / 255, g / 255, b / 255, a / 255
end

-- The colour at (u, v), v from the top, filtered between the four nearest
-- texels as the client filters it.
local function texel(img, u, v)
	local fx, fy = u * img.w - 0.5, v * img.h - 0.5
	local x0, y0 = math.floor(fx), math.floor(fy)
	local tx, ty = fx - x0, fy - y0
	local r, g, b, a = 0, 0, 0, 0
	for j = 0, 1 do
		for i = 0, 1 do
			local k = (i == 0 and 1 - tx or tx) * (j == 0 and 1 - ty or ty)
			if k > 0 then
				local pr, pg, pb, pa = pixel(img, x0 + i, y0 + j)
				r, g, b, a = r + pr * k, g + pg * k, b + pb * k, a + pa * k
			end
		end
	end
	return r, g, b, a
end

---------------------------------------------------------------------------
-- the scene: where everything is, what draws over what
---------------------------------------------------------------------------

local LAYER = FT.LAYERS

-- Tests/scenarios/look.lua's layout: two edges on an axis give its extent,
-- one edge and a size the rest. Rects are { left, bottom, right, top }.
local function layout(snapshot, byId)
	local rects, root = {}, nil
	for _, r in ipairs(snapshot) do
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

local function overlaps(a, b)
	return a[1] < b[3] - 0.01 and b[1] < a[3] - 0.01 and a[2] < b[4] - 0.01 and b[2] < a[4] - 0.01
end

-- The prompt as it stands. `peak`: a region a looping animation is running
-- on counts at the brightest the loop takes it to.
local function scene(ns, peak)
	local r = ns.Prompt:Regions()
	local snap = FT.snapshot(UIParent)
	local byId = {}
	for _, e in ipairs(snap) do byId[e.id] = e end
	local S = { byId = byId, rect = layout(snap, byId), list = snap, r = r }
	S.art, S.textLayer = r.art._serial, r.textLayer._serial

	-- Shown all the way up, and the alpha all the way up to the screen.
	function S.drawn(e)
		local a, x = 1, e
		while x do
			if x.shown == false then return 0 end
			local own = x.alpha or 1
			if peak and x == e then
				for _, g in ipairs(x.groups or {}) do
					if g.playing and g.looping and g.looping ~= "NONE" then
						for _, anim in ipairs(g.anims) do
							own = math.max(own, anim.fromAlpha or 0, anim.toAlpha or 0)
						end
					end
				end
			end
			a = a * own
			x = x.parent and byId[x.parent]
		end
		return a
	end
	-- Under art, and not in a cooldown (the global cooldown is the game's).
	function S.inArt(e)
		local x = e
		while x do
			if x.kind == "Cooldown" then return false end
			if x.id == S.art then return true end
			x = x.parent and byId[x.parent]
		end
		return false
	end
	function S.under(e, id)
		local x = e
		while x do
			if x.id == id then return true end
			x = x.parent and byId[x.parent]
		end
		return false
	end
	-- Draw order: the owning frame's level, then layer, sublevel, creation.
	function S.key(e)
		local owner = byId[e.parent]
		return { owner and owner.level or 0, LAYER[e.layer or "ARTWORK"] or 3, e.sublevel or 0, e.id }
	end
	function S.textures()
		local out = {}
		for _, e in ipairs(snap) do
			if (e.kind == "Texture") and S.inArt(e) then out[#out + 1] = e end
		end
		table.sort(out, function(a, b)
			local ka, kb = S.key(a), S.key(b)
			for i = 1, 4 do
				if ka[i] ~= kb[i] then return ka[i] < kb[i] end
			end
			return false
		end)
		return out
	end
	return S
end

local function above(ka, kb)
	for i = 1, 4 do
		if ka[i] ~= kb[i] then return ka[i] > kb[i] end
	end
	return false
end

-- What a texture puts at (x, y): its colour and alpha there, or nil when the
-- point is off it. The alpha is the texel's, the vertex colour's and every
-- frame's above it.
local function sample(S, e, x, y, drawnAlpha)
	local box = S.rect(e.id)
	if not box or x < box[1] or x > box[3] or y < box[2] or y > box[4] then return nil end
	local w, h = box[3] - box[1], box[4] - box[2]
	if w <= 0 or h <= 0 then return nil end
	local fx, fy = (x - box[1]) / w, (box[4] - y) / h
	local u, v = fx, fy
	local c = e.texCoord
	if c and #c >= 8 then
		local ux, uy = c[1] + (c[5] - c[1]) * fx, c[2] + (c[6] - c[2]) * fx
		local lx, ly = c[3] + (c[7] - c[3]) * fx, c[4] + (c[8] - c[4]) * fx
		u, v = ux + (lx - ux) * fy, uy + (ly - uy) * fy
	elseif c and #c >= 4 then
		u, v = c[1] + (c[2] - c[1]) * fx, c[3] + (c[4] - c[3]) * fy
	end
	local tr, tg, tb, ta = 1, 1, 1, 1
	if e.colorTexture then
		tr, tg, tb, ta = e.colorTexture[1], e.colorTexture[2], e.colorTexture[3], e.colorTexture[4] or 1
	else
		local img = image(e.file)
		if img then tr, tg, tb, ta = texel(img, u, v) end
	end
	if e.desaturated then
		local l = 0.299 * tr + 0.587 * tg + 0.114 * tb
		tr, tg, tb = l, l, l
	end
	local vr, vg, vb, va = 1, 1, 1, 1
	local gr = e.gradient
	if gr and type(gr[2]) == "table" and type(gr[3]) == "table" then
		local t = gr[1] == "HORIZONTAL" and fx or (1 - fy)
		local a, b = gr[2], gr[3]
		vr = (a.r or 1) + ((b.r or 1) - (a.r or 1)) * t
		vg = (a.g or 1) + ((b.g or 1) - (a.g or 1)) * t
		vb = (a.b or 1) + ((b.b or 1) - (a.b or 1)) * t
		va = (a.a or 1) + ((b.a or 1) - (a.a or 1)) * t
	elseif e.color then
		vr, vg, vb, va = e.color[1] or 1, e.color[2] or 1, e.color[3] or 1, e.color[4] or 1
	end
	local alpha = ta * va * drawnAlpha
	local m = e.mask and S.byId[e.mask]
	if m then
		local mbox = S.rect(m.id)
		local img = image(m.file)
		if mbox and img and mbox[3] > mbox[1] and mbox[4] > mbox[2] then
			if x < mbox[1] or x > mbox[3] or y < mbox[2] or y > mbox[4] then return nil end
			local _, _, _, ma = texel(img, (x - mbox[1]) / (mbox[3] - mbox[1]), (mbox[4] - y) / (mbox[4] - mbox[2]))
			alpha = alpha * ma
		end
	end
	return tr * vr, tg * vg, tb * vb, alpha
end

-- The ground at (x, y) over a world of grey `world`, from `layers` in draw
-- order (each { e, alpha }).
local function ground(S, layers, x, y, world)
	local r, g, b = world, world, world
	for _, layer in ipairs(layers) do
		local e = layer[1]
		local sr, sg, sb, sa = sample(S, e, x, y, layer[2])
		if sr and sa > 0 then
			if e.blend == "ADD" then
				local k = sa * ADD_WEIGHT
				r, g, b = math.min(1, r + sr * k), math.min(1, g + sg * k), math.min(1, b + sb * k)
			elseif e.blend == "MOD" then
				r, g, b = r * sr, g * sg, b * sb
			else
				r, g, b = sr * sa + r * (1 - sa), sg * sa + g * (1 - sa), sb * sa + b * (1 - sa)
			end
		end
	end
	return luminance(r, g, b)
end

---------------------------------------------------------------------------
-- the three rules
---------------------------------------------------------------------------

-- The worst contrast seen for each kind of text, and with READABLE_REPORT
-- set in the environment, what lay under it: printed at the end of the file.
local worst, worstOrder = {}, { "the name", "the reason line", "a chip's words" }
local REPORT = os and os.getenv and os.getenv("READABLE_REPORT")

local function note(kind, q, at, where)
	local w = worst[kind]
	if not w or q < w.ratio then worst[kind] = { ratio = q, at = at, where = where } end
end

-- Rule 1 and rule 3 on the prompt as it stands.
local function checkIcon(ns, scenario, what)
	local S = scene(ns, false)
	local r = S.r
	local icon = S.byId[r.icon._serial]
	if not (icon and S.drawn(icon) > 0) then return end
	local ibox = S.rect(icon.id)
	if not ibox then
		fail(scenario, what .. ": the icon could not be placed")
		return
	end
	local look = r.look
	local medallion = look.medallion and look.medallion._serial

	-- The icon's drawn shape, and the points of it more than LIP_UNITS in
	-- from its edge.
	local mask = icon.mask and S.byId[icon.mask]
	local mimg = mask and image(mask.file)
	local mbox = mask and S.rect(mask.id)
	local function inside(x, y)
		if x < ibox[1] or x > ibox[3] or y < ibox[2] or y > ibox[4] then return false end
		if not (mimg and mbox) then return true end
		local _, _, _, a = texel(mimg, (x - mbox[1]) / (mbox[3] - mbox[1]), (mbox[4] - y) / (mbox[4] - mbox[2]))
		return a >= 0.5
	end
	local deep = {}
	local step = math.max(0.5, (ibox[3] - ibox[1]) / 48)
	local d = LIP_UNITS * 0.7071
	for x = ibox[1] + step / 2, ibox[3], step do
		for y = ibox[2] + step / 2, ibox[4], step do
			if inside(x, y) and inside(x + LIP_UNITS, y) and inside(x - LIP_UNITS, y)
				and inside(x, y + LIP_UNITS) and inside(x, y - LIP_UNITS)
				and inside(x + d, y + d) and inside(x - d, y - d)
				and inside(x + d, y - d) and inside(x - d, y + d) then
				deep[#deep + 1] = { x, y }
			end
		end
	end
	if #deep == 0 then
		fail(scenario, what .. ": the icon has no inside to judge")
		return
	end

	local iconKey = S.key(icon)
	for _, e in ipairs(S.textures()) do
		local a = S.drawn(e)
		if a > FAINT and above(S.key(e), iconKey) then
			local box = S.rect(e.id)
			if box and overlaps(box, ibox) then
				if medallion and S.under(e, medallion) then
					-- The medallion's gold: clear over the icon's inside.
					for _, pt in ipairs(deep) do
						local _, _, _, sa = sample(S, e, pt[1], pt[2], a)
						if sa and sa > FAINT then
							fail(scenario, ("%s: %s is drawn over the spell icon %.1f units in from its"
								.. " edge (alpha %.2f)"):format(what, tostring(e.file):match("[^\\]+$") or "?",
								math.min(pt[1] - ibox[1], ibox[3] - pt[1], pt[2] - ibox[2], ibox[4] - pt[2]), sa))
							break
						end
					end
				else
					fail(scenario, ("%s: %s lies over the spell icon's box (alpha %.2f)")
						:format(what, tostring(e.file or "a solid"):match("[^\\]+$") or "?", a))
				end
			end
		end
	end

	-- Rule 3: the count, and any chip, off the icon.
	local chips = {}
	for _, t in ipairs(look.chip or {}) do chips[#chips + 1] = t end
	for _, t in ipairs(look.keyChip or {}) do chips[#chips + 1] = t end
	for _, t in ipairs(chips) do
		local e = S.byId[t._serial]
		local box = e and S.drawn(e) > 0 and S.rect(e.id)
		if box and box[3] > box[1] and overlaps(box, ibox) then
			fail(scenario, what .. ": the count's chip covers the spell icon")
			break
		end
	end
	local count = S.byId[r.count._serial]
	if count and S.drawn(count) > 0 and look.chipBox then
		local box = S.rect(look.chipBox._serial)
		if box and box[3] > box[1] and overlaps(box, ibox) then
			fail(scenario, what .. ": the count's chip covers the spell icon")
		end
	end
end

-- The box a line of text is drawn in: its anchors across, its size up.
local function lineBox(S, fs)
	local e = S.byId[fs._serial]
	local box = e and S.rect(e.id)
	local size = fs._font and fs._font.size or 12
	if not box then return nil end
	local cy = (box[2] + box[4]) / 2
	return { box[1], cy - size * 0.5, box[3], cy + size * 0.5 }
end

-- The layers that can lie under a box: everything under art drawn beneath the
-- text, save the text layer's own glyph and the text itself.
local function groundLayers(S, box)
	local layers = {}
	for _, e in ipairs(S.textures()) do
		if not S.under(e, S.textLayer) then
			local a = S.drawn(e)
			local b = S.rect(e.id)
			if a > 0 and b and overlaps(b, box) then layers[#layers + 1] = { e, a } end
		end
	end
	return layers
end

-- What lies at (x, y), for the report.
local function describe(S, layers, x, y)
	local parts = {}
	for _, layer in ipairs(layers) do
		local e = layer[1]
		local sr, sg, sb, sa = sample(S, e, x, y, layer[2])
		if sr and sa > 0.001 then
			parts[#parts + 1] = ("%s %s a=%.2f rgb=%.2f,%.2f,%.2f"):format(
				tostring(e.file or "solid"):match("[^\\]+$") or "?", e.blend or "BLEND", sa, sr, sg, sb)
		end
	end
	return table.concat(parts, "; ")
end

-- The lightest ground under a box, as a luminance, for each world; and with
-- REPORT, what lay there.
local function lightest(S, box)
	local layers = groundLayers(S, box)
	local out, where = {}, {}
	local w = box[3] - box[1]
	local xs = math.max(2, math.floor(w / 4))
	for wi, world in ipairs(WORLDS) do
		local g = greyOf(world)
		local most, at = 0, nil
		for i = 0, xs do
			local x = box[1] + 0.5 + (w - 1) * i / xs
			for j = 0, 4 do
				local y = box[2] + (box[4] - box[2]) * (0.05 + 0.9 * j / 4)
				local l = ground(S, layers, x, y, g)
				if l > most then most, at = l, { x, y } end
			end
		end
		out[wi] = most
		if REPORT and at then
			where[wi] = ("%.1f units in, %.1f up the line: %s"):format(at[1] - box[1], at[2] - box[2],
				describe(S, layers, at[1], at[2]))
		end
	end
	return out, where
end

-- Rule 2: `colours` for the name line (the reason line is judged in the
-- colour it is painted), on the prompt as it stands.
local function checkText(ns, scenario, what, colours, peak)
	local S = scene(ns, peak)
	local r = S.r
	local lines = { { r.name, colours, "the name" } }
	if r.sub:IsShown() and r.sub._textColor then
		lines[2] = { r.sub, { r.sub._textColor }, "the reason line" }
	end
	for _, line in ipairs(lines) do
		local fs = line[1]
		local e = S.byId[fs._serial]
		if e and S.drawn(e) > 0 then
			local box = lineBox(S, fs)
			if not box or box[3] - box[1] < 4 then
				fail(scenario, what .. ": " .. line[3] .. " could not be placed")
			else
				local grounds, where = lightest(S, box)
				for _, c in ipairs(line[2]) do
					local lt = luminance(c[1], c[2], c[3])
					for wi, lg in ipairs(grounds) do
						local q = ratio(lt, lg)
						note(line[3], q, ("%s, in %.2f %.2f %.2f, world %.2f"):format(what,
							c[1], c[2], c[3], WORLDS[wi]), where[wi])
						if q < MINIMUM then
							fail(scenario, ("%s: %s in %.2f %.2f %.2f reads %.2f:1 on its ground over a world"
								.. " of luminance %.2f"):format(what, line[3], c[1], c[2], c[3], q, WORLDS[wi]))
						end
					end
				end
			end
		end
	end
end

-- The count's and the key's words on their chips.
local function checkChips(ns, scenario, what)
	local S = scene(ns, false)
	local look = S.r.look
	for _, pair in ipairs({ { S.r.count, look.chipBox }, { look.keyText, look.keyBox } }) do
		local fs, holder = pair[1], pair[2]
		local e = fs and S.byId[fs._serial]
		local hb = holder and S.rect(holder._serial)
		if e and hb and S.drawn(e) > 0 and fs._textColor and hb[3] > hb[1] then
			local cx, cy = (hb[1] + hb[3]) / 2, (hb[2] + hb[4]) / 2
			local w, h = (hb[3] - hb[1]) * 0.3, (hb[4] - hb[2]) * 0.25
			local box = { cx - w, cy - h, cx + w, cy + h }
			local c = fs._textColor
			local lt = luminance(c[1], c[2], c[3])
			local grounds, where = lightest(S, box)
			for wi, lg in ipairs(grounds) do
				local q = ratio(lt, lg)
				note("a chip's words", q, ("%s, in %.2f %.2f %.2f, world %.2f"):format(what,
					c[1], c[2], c[3], WORLDS[wi]), where[wi])
				if q < MINIMUM then
					fail(scenario, ("%s: the words on a chip read %.2f:1 over a world of luminance %.2f")
						:format(what, q, WORLDS[wi]))
				end
			end
		end
	end
end

-- Every colour the name can be here: the one it is, white, the look's ivory,
-- the gold, and each class colour as the look softens it.
local function nameColours(ns, look)
	local r = ns.Prompt:Regions()
	local list = { WHITE, GOLD }
	if r.name._textColor then list[#list + 1] = r.name._textColor end
	local by = look.classSoften or 0
	for _, code in ipairs(CLASS_CODES) do list[#list + 1] = soften(code, by) end
	return list
end

local function report()
	if not REPORT then return end
	for _, kind in ipairs(worstOrder) do
		local w = worst[kind]
		if w then
			print(("readable-toast: %s at worst %.2f:1 -- %s"):format(kind, w.ratio, tostring(w.at)))
			print("readable-toast:   under it, " .. tostring(w.where))
		end
	end
end

---------------------------------------------------------------------------
-- 1 and 3: the icon clean, the count off it
---------------------------------------------------------------------------

withTree("Toast draws the spell icon clean", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	local judged = 0
	for _, round in ipairs({ false, true }) do
		for _, size in ipairs(SIZES) do
			p.roundIcon = round
			p.width, p.height, p.fontSize = size[1], size[2], size[3]
			ns.Prompt:ApplyStyle()
			tick(ns)
			rest(ns)
			local what = ("%dx%d %s"):format(size[1], size[2], round and "round" or "square")
			checkIcon(ns, scenario, what .. " at rest")
			judged = judged + 1
			-- The cursor on it: the medallion's light comes up and stays.
			local button = ns.Prompt:GetButton()
			if button.scripts.OnEnter then button.scripts.OnEnter(button) else look:Hover(true) end
			Mock.advance(0.3)
			FT.settle()
			checkIcon(ns, scenario, what .. " under the cursor")
			if button.scripts.OnLeave then button.scripts.OnLeave(button) else look:Hover(false) end
			Mock.advance(0.3)
			FT.settle()
		end
	end
	-- An outcome held on Calm, and a fight.
	p.width, p.height, p.fontSize, p.roundIcon = 220, 44, 13, false
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	for _, kind in ipairs({ "cast", "failed", "sent" }) do
		Mock.advance(3)
		ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
		checkIcon(ns, scenario, "a " .. kind .. " outcome on Calm")
	end
	Mock.advance(3)
	tick(ns)
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	tick(ns)
	checkIcon(ns, scenario, "in a fight")
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	tick(ns)
	-- The favour clock all but run out: its spark at the medallion's side.
	p.effects = "full"
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	Mock.advance(99)
	tick(ns)
	if look.bead._shown == false then
		fail(scenario, "SKIPPED -- the favour clock was not burning")
	end
	checkIcon(ns, scenario, "the favour clock all but run out")
	if judged == 0 or r.icon._shown == false then fail(scenario, "no icon was judged") end
end)

withTree("Toast keeps the count off the spell icon", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	-- With a key bound, where 1.5.0 moved the count onto the medallion.
	SetBinding("SHIFT-F", COMMAND)
	local shown = 0
	for _, size in ipairs(SIZES) do
		p.width, p.height, p.fontSize = size[1], size[2], size[3]
		ns.Prompt:ApplyStyle()
		tick(ns)
		rest(ns)
		if r.count._shown ~= false and look.countMode then shown = shown + 1 end
		checkIcon(ns, scenario, ("%dx%d with a key bound"):format(size[1], size[2]))
		checkChips(ns, scenario, ("%dx%d with a key bound"):format(size[1], size[2]))
	end
	if shown == 0 then fail(scenario, "the count never showed beside a bound key, so this checks nothing") end
	SetBinding("SHIFT-F", nil)
	p.width, p.height, p.fontSize = 220, 44, 13
	ns.Prompt:ApplyStyle()
	tick(ns)
	rest(ns)
	checkIcon(ns, scenario, "with no key bound")
	checkChips(ns, scenario, "with no key bound")
end)

---------------------------------------------------------------------------
-- 2: the text on a dark ground
---------------------------------------------------------------------------

withTree("Toast's text stands on a dark ground", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	-- Every reason in both palettes, the owed pulse at its brightest; at the
	-- default size and the tallest.
	for _, size in ipairs({ SIZES[1], SIZES[5] }) do
		p.width, p.height, p.fontSize = size[1], size[2], size[3]
		for _, palette in ipairs({ "standard", "colourblind" }) do
			p.reasonPalette = palette
			ns.Prompt:ApplyStyle()
			owe(ns, "Anna Aim")
			tick(ns)
			rest(ns)
			for _, reason in ipairs({ "target", "owed", "asked", "group", "nearby", "self" }) do
				ns.Prompt:PaintAccent(reason)
				checkText(ns, scenario, ("%dx%d, %s in the %s set"):format(size[1], size[2], reason, palette),
					nameColours(ns, look), true)
			end
		end
	end
	p.reasonPalette = "standard"
	-- Every size: at rest with the pulse at its brightest, and under the
	-- cursor.
	for _, size in ipairs(SIZES) do
		p.width, p.height, p.fontSize = size[1], size[2], size[3]
		ns.Prompt:ApplyStyle()
		tick(ns)
		rest(ns)
		local what = ("%dx%d"):format(size[1], size[2])
		checkText(ns, scenario, what .. " owed, breathing", nameColours(ns, look), true)
		local button = ns.Prompt:GetButton()
		if button.scripts.OnEnter then button.scripts.OnEnter(button) else look:Hover(true) end
		Mock.advance(0.3)
		FT.settle()
		checkText(ns, scenario, what .. " under the cursor", nameColours(ns, look), true)
		if button.scripts.OnLeave then button.scripts.OnLeave(button) else look:Hover(false) end
		Mock.advance(0.3)
		FT.settle()
	end
	-- The verdicts, as they first land on Full and as they are held on Calm.
	p.width, p.height, p.fontSize = 220, 44, 13
	for _, effects in ipairs({ "full", "calm" }) do
		p.effects = effects
		ns.Prompt:ApplyStyle()
		tick(ns)
		for _, kind in ipairs({ "cast", "failed", "sent" }) do
			Mock.advance(3)
			ns.Prompt:ShowOutcome(kind, "Anna Aim", "Out of range.")
			checkText(ns, scenario, ("a %s outcome on %s"):format(kind, effects), nameColours(ns, look), true)
		end
	end
	p.effects = "full"
	-- One line, the icon off, and the preview's gold name.
	for _, setup in ipairs({
		{ "the second line off", function() p.showSub = false end },
		{ "the icon off", function() p.showSub, p.showIcon = true, false end },
		{ "a round icon", function() p.showIcon, p.roundIcon = true, true end },
	}) do
		setup[2]()
		ns.Prompt:ApplyStyle()
		Mock.advance(3)
		tick(ns)
		rest(ns)
		checkText(ns, scenario, setup[1], nameColours(ns, look), true)
	end
end)

---------------------------------------------------------------------------
-- 4, 5 and 6: the gold, the medallion and the body, read from the files
---------------------------------------------------------------------------

-- In the game 1.5.1's toast wore a thin glaring yellow line all round the
-- banner, a heavy square bevelled frame round the icon with a glow ring, and
-- an olive-black body. The redo is held to these, from the texels the look
-- ships and what the frames were told:
--   4. the gold is a deep old gold -- no gold texel the look draws brighter
--      than 0.62 (Rec.601 luma, vertex colour applied), each rail with a
--      darker line inside it, the frame thin (3.2 units at a 12-unit corner)
--      and crisp: no light haloed round it;
--   5. the medallion is round: every disc of it round, a gold ring 1.5 to 2.5
--      units wide hugging the icon (at most a unit of dark between, along
--      the axis as well as the diagonal), the enamel just outside it,
--      darkened from the reason colour; the icon round at either setting of
--      "Round the icon off" -- squared, it sat in a dark round hole;
--   6. the body is a deep warm brown with a quiet vertical gradient baked in.

local GOLD_MOST = 0.62
local RING_LEAST, RING_MOST = 1.5, 2.5

local function luma(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end

-- The brightest opaque texel of `img` in the texcoord box of `t`, with its
-- vertex colour applied. Cached per file, box and colour.
local brightestCache = {}
local function brightest(t, img)
	local c = t._texCoord
	local u0, u1, v0, v1 = 0, 1, 0, 1
	if c and #c == 4 then u0, u1, v0, v1 = c[1], c[2], c[3], c[4] end
	local vc = t._color or { 1, 1, 1, 1 }
	local key = ("%s:%.3f:%.3f:%.3f:%.3f:%.3f:%.3f:%.3f"):format(tostring(t._file), u0, u1, v0, v1,
		vc[1] or 1, vc[2] or 1, vc[3] or 1)
	local hit = brightestCache[key]
	if hit then return hit end
	local most = 0
	local x0, x1 = math.floor(math.min(u0, u1) * img.w), math.ceil(math.max(u0, u1) * img.w) - 1
	local y0, y1 = math.floor(math.min(v0, v1) * img.h), math.ceil(math.max(v0, v1) * img.h) - 1
	for y = y0, y1 do
		for x = x0, x1 do
			local r, g, b, a = pixel(img, x, y)
			if a >= 0.5 then
				local l = luma(r * (vc[1] or 1), g * (vc[2] or 1), b * (vc[3] or 1))
				if l > most then most = l end
			end
		end
	end
	brightestCache[key] = most
	return most
end

-- Where a round file's alpha falls through a half, from its middle out along
-- its middle row, as a fraction of its half-width; along the diagonal with
-- `diagonal`, as a fraction of the half-width too.
local function reach(img, diagonal)
	local n = img.w / 2
	local last = 0
	for i = 0, n * 15 do
		local d = i / 10
		local u = diagonal and (0.5 + d / img.w * 0.7071) or (0.5 + d / img.w)
		local v = diagonal and (0.5 + d / img.h * 0.7071) or 0.5
		if u >= 1 or v >= 1 then break end
		local _, _, _, a = texel(img, u, v)
		if a < 0.5 then return d / n end
		last = d / n
	end
	return last
end

-- The medallion's rim must still read as gold: dimmed to a brown line, the
-- enamel sat on a dark edge and the medallion lost its gilded bezel.
local RIM_LEAST = 0.42
-- And the frame's darker inner line must still be seen: at 0.15 it existed
-- only in the file, and the rail read as a dim pencil line.
local INNER_LEAST = 0.28

withTree("Toast's gold is old gold, thin and crisp", CROWD, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	SetBinding("SHIFT-F", COMMAND)
	local judged, seen = 0, {}
	-- Every piece of gold on show, the list's drawer and gems among them
	-- (the crowd fills three rows), and with the icon off the jewel's setting.
	for _, size in ipairs({ { 220, 44, 13, true }, { 180, 36, 11, true }, { 220, 44, 13, false } }) do
		p.width, p.height, p.fontSize, p.showIcon = size[1], size[2], size[3], size[4]
		p.showQueue, p.queueRows = true, 3
		ns.Prompt:ApplyStyle()
		tick(ns)
		rest(ns)
		for _, t in ipairs(look.gold) do
			local img = t._shown ~= false and image(t._file)
			if img then
				judged = judged + 1
				seen[t] = true
				seen[tostring(t._file):match("_(%a+)$") or "?"] = true
				local most = brightest(t, img)
				if most > GOLD_MOST then
					fail(scenario, ("%dx%d: %s is gold as bright as %.2f, over %.2f"):format(size[1], size[2],
						tostring(t._file):match("[^\\]+$") or "?", most, GOLD_MOST))
				end
				if t == look.rim and most < RIM_LEAST then
					fail(scenario, ("%dx%d: the medallion's rim is %.2f at its brightest, too dark to read as gold")
						:format(size[1], size[2], most))
				end
			end
		end
		-- The frame's profile, down the middle of its top edge.
		local frame = look.border[2]
		local img = image(frame._file)
		if not img then
			fail(scenario, "the frame's file could not be read")
		else
			local x = math.floor(img.w / 2)
			local runs, run, deepest, halo = {}, nil, -1, 0
			for y = 0, math.floor(img.h / 4) - 1 do
				local cr, cg, cb, a = pixel(img, x, y)
				local l = luma(cr, cg, cb)
				if a >= 0.5 then deepest = y end
				if a >= 0.5 and l > 0.12 then
					if not run then
						run = { most = 0 }
						runs[#runs + 1] = run
					end
					run.most = math.max(run.most, l)
				else
					run = nil
				end
			end
			for y = 0, img.h - 1 do
				for xx = 0, img.w - 1 do
					local cr, cg, cb, a = pixel(img, xx, y)
					if a > 0.02 and a < 0.5 and luma(cr, cg, cb) > 0.3 then halo = halo + 1 end
				end
			end
			local what = ("%dx%d"):format(size[1], size[2])
			if #runs < 2 then
				fail(scenario, what .. ": the frame has no darker line inside its rail")
			elseif runs[#runs].most > 0.8 * runs[1].most then
				fail(scenario, ("%s: the frame's inner line (%.2f) is not darker than its rail (%.2f)")
					:format(what, runs[#runs].most, runs[1].most))
			elseif runs[#runs].most < INNER_LEAST then
				fail(scenario, ("%s: the frame's inner line (%.2f) is too dark to see at the game's scale")
					:format(what, runs[#runs].most))
			end
			local units = (deepest + 1) / (img.w / 4) * 12
			if units > 3.2 then
				fail(scenario, ("%s: the frame is %.1f units deep at a 12-unit corner, not thin"):format(what, units))
			end
			if halo > 0 then
				fail(scenario, ("%s: the frame has %d texels of light haloed round it, a glowing outline")
					:format(what, halo))
			end
		end
	end
	SetBinding("SHIFT-F", nil)
	if judged == 0 then fail(scenario, "no gold was judged") end
	for _, want in ipairs({ { "Drawer", "the list's drawer" }, { "GemSet", "a gem's setting" },
		{ look.jewelSet, "the jewel's setting" }, { look.rim, "the medallion's rim" } }) do
		if not seen[want[1]] then fail(scenario, want[2] .. " was never judged") end
	end
end)

withTree("Toast's medallion is round, its gold ring thin", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	local discs = { "medallion", "rim", "band", "ring", "well" }
	for _, round in ipairs({ false, true }) do
		for _, size in ipairs(SIZES) do
			p.roundIcon = round
			p.width, p.height, p.fontSize = size[1], size[2], size[3]
			ns.Prompt:ApplyStyle()
			tick(ns)
			rest(ns)
			local what = ("%dx%d %s"):format(size[1], size[2], round and "round" or "square")
			-- Every disc round, and each one's drawn radius.
			local radius = {}
			for _, key in ipairs(discs) do
				local t = look[key]
				local img = t and image(t._file)
				if not (img and t._shown ~= false) then
					fail(scenario, what .. ": the medallion's " .. key .. " is not drawn")
					return
				end
				local _, _, _, corner = texel(img, 0.1, 0.1)
				local _, _, _, middle = texel(img, 0.5, 0.5)
				local _, _, _, edge = texel(img, 0.5, 0.04)
				if corner > 0.01 or middle < 0.99 or edge < 0.5 then
					fail(scenario, ("%s: the medallion's %s is not round (%s)"):format(what, key, tostring(t._file)))
				end
				if t._blend == "ADD" then fail(scenario, what .. ": the medallion's " .. key .. " is additive") end
				radius[key] = (t._width or 0) / 2 * reach(img)
			end
			-- The icon, round at either setting: its reach from the centre along
			-- the axis and along the diagonal, which for a round icon agree.
			local icon = r.icon
			local mask = icon._mask and image(icon._mask._file)
			if not mask then
				fail(scenario, what .. ": the icon has no mask")
				return
			end
			local corner = select(4, texel(mask, 0.12, 0.12))
			if corner > 0.01 then
				fail(scenario, ("%s: rounding is %s and the icon is not round"):format(what, round and "on" or "off"))
			end
			local axis = (icon._width or 0) / 2 * reach(mask, false)
			local diagonal = (icon._width or 0) / 2 * reach(mask, true)
			local ring = radius.ring - math.max(radius.well, axis, diagonal)
			if ring < RING_LEAST - 0.05 or ring > RING_MOST + 0.05 then
				fail(scenario, ("%s: the gold ring is %.2f units wide, not %.1f to %.1f")
					:format(what, ring, RING_LEAST, RING_MOST))
			end
			local gap = radius.well - math.min(axis, diagonal)
			if gap > 1.0 then
				fail(scenario, ("%s: the gold ring stands %.2f units off the icon; it should hug it"):format(what, gap))
			end
			local enamel = radius.band - radius.ring
			if enamel < 1.5 or enamel > 5 or radius.rim - radius.band > 1.6 then
				fail(scenario, ("%s: the enamel is not a band just outside the ring (%.2f wide, %.2f of rim)")
					:format(what, enamel, radius.rim - radius.band))
			end
		end
	end
	-- The enamel is the reason colour darkened, never lit.
	p.width, p.height, p.fontSize, p.roundIcon = 220, 44, 13, false
	for _, palette in ipairs({ "standard", "colourblind" }) do
		p.reasonPalette = palette
		ns.Prompt:ApplyStyle()
		tick(ns)
		rest(ns)
		for _, reason in ipairs({ "target", "owed", "asked", "group", "nearby", "self" }) do
			ns.Prompt:PaintAccent(reason)
			local cr, cg, cb = ns.Prompt:AccentColor(reason)
			local c = look.band._color
			if not (c and luminance(c[1], c[2], c[3]) < 0.5 * luminance(cr, cg, cb)) then
				fail(scenario, ("the enamel for %s in the %s set is not the reason colour darkened"):format(reason, palette))
			end
		end
	end
end)

withTree("Toast's body is a deep warm brown", ANNA, function(ns, scenario)
	local _, _, look = upIn(ns, scenario)
	if not isToast(look) then
		fail(scenario, "SKIPPED -- Toast is not the look in use")
		return
	end
	local body = look.body
	local gr = body._gradient
	local img = image(body._file)
	if not (gr and gr[1] == "VERTICAL" and type(gr[2]) == "table" and type(gr[3]) == "table" and img) then
		fail(scenario, "the body has no vertical gradient on its own file")
		return
	end
	-- Warm: red over green over blue, the red well over the blue; deep: dark
	-- enough that the text keeps its ground (tests the lines above).
	for i, stop in ipairs({ gr[2], gr[3] }) do
		local sr, sg, sb = stop.r or 1, stop.g or 1, stop.b or 1
		if not (sr > sg and sg > sb and sr >= 1.8 * sb) then
			fail(scenario, ("the body's %s stop is not a warm brown: %.3f %.3f %.3f")
				:format(i == 1 and "bottom" or "top", sr, sg, sb))
		end
		if luminance(sr, sg, sb) > 0.03 then
			fail(scenario, ("the body's %s stop is not deep: %.3f %.3f %.3f"):format(i == 1 and "bottom" or "top", sr, sg, sb))
		end
	end
	-- The file's own quiet fall from the top down, along its middle.
	local top = pixel(img, math.floor(img.w / 2), math.floor(img.h * 0.1))
	local bottom = pixel(img, math.floor(img.w / 2), math.floor(img.h * 0.9))
	if not (top - bottom >= 0.08 and top - bottom <= 0.35) then
		fail(scenario, ("the body's file has no subtle gradient baked in: %.2f at the top, %.2f at the foot")
			:format(top, bottom))
	end
end)

report()
