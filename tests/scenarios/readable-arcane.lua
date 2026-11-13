-- The Arcane look read the way the game draws it (1.5.1).
--
-- 1.5.0's looks were tuned by eye against tools/render_prompt.py, which lays
-- ADD-blended light on far more gently than the game does: in game a gloss
-- over the spell icon washed it out, and text sat on a ground too light to
-- read. So nothing here looks at a picture. Every region the addon made is
-- laid out from its anchors, every texture is read from its .tga, and the
-- rules are computed:
--
--   1. The spell icon is drawn clean: at rest nothing drawn over it reaches
--      more than 2 units inside its shape (a frame hugging the edge may).
--   2. The name and the reason line have a dark ground: over a world of
--      luminance 0.30 and one of 0.85 (snow), every colour those lines can be
--      reads at 4.5:1 or better. ADD-blended layers count at twice their alpha.
--   3. The count's coin never covers the icon.
--
-- Run on the recording CreateFrame in tests/frametree.lua, like look-arcane.lua.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }

-- How far inside the icon's shape a frame may reach, and the strength above
-- which anything over the icon counts as drawn on it.
local EDGE = 2
local FAINT = 0.04
-- The worlds, by relative luminance, and the grey that has it.
local WORLDS = { 0.30, 0.85 }
local LEAST = 4.5

-- ------------------------------------------------------------------ colour

-- The web's contrast rules, derived here rather than borrowed from Prompt/,
-- so a mistake there cannot pass for a pass here.
local function linear(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function luminance(r, g, b)
	return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
end

local function ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- The sRGB grey whose relative luminance is `l`.
local function greyOf(l)
	if l <= 0.03928 / 12.92 then return l * 12.92 end
	return 1.055 * l ^ (1 / 2.4) - 0.055
end

-- Every class's colour as the game gives it, for the softened names.
local CLASSES = {
	DEATHKNIGHT = "c41e3a", DEMONHUNTER = "a330c9", DRUID = "ff7c0a", EVOKER = "33937f",
	HUNTER = "aad372", MAGE = "3fc7eb", MONK = "00ff98", PALADIN = "f48cba", PRIEST = "ffffff",
	ROGUE = "fff468", SHAMAN = "0070dd", WARLOCK = "8788ee", WARRIOR = "c69b6d",
}

local function hex(code, at) return tonumber(code:sub(at, at + 1), 16) / 255 end

-- ------------------------------------------------------------------ the art

-- Each texture file read once: its size and, per texel from the top left,
-- red, green, blue and alpha in 0..1.
local files = {}

local function readTga(path)
	local hit = files[path]
	if hit ~= nil then return hit or nil end
	local rel = path:gsub("^Interface\\AddOns\\Manners\\", ""):gsub("\\", "/")
	local f = io.open(dir .. "/" .. rel .. ".tga", "rb")
	if not f then files[path] = false return nil end
	local data = f:read("*a")
	f:close()
	local idLen, kind = data:byte(1), data:byte(3)
	local w = data:byte(13) + data:byte(14) * 256
	local h = data:byte(15) + data:byte(16) * 256
	local bpp, desc = data:byte(17), data:byte(18)
	if kind ~= 2 or (bpp ~= 32 and bpp ~= 24) then files[path] = false return nil end
	local step = bpp / 8
	local topDown = math.floor(desc / 32) % 2 == 1
	local img = { w = w, h = h, r = {}, g = {}, b = {}, a = {} }
	local at = 18 + idLen
	for row = 0, h - 1 do
		local y = topDown and row or (h - 1 - row)
		for x = 0, w - 1 do
			local o = at + (row * w + x) * step
			local b, g, r, a = data:byte(o + 1, o + 4)
			local i = y * w + x + 1
			img.r[i], img.g[i], img.b[i] = r / 255, g / 255, b / 255
			img.a[i] = step == 4 and a / 255 or 1
		end
	end
	files[path] = img
	return img
end

-- ------------------------------------------------------------------ layout

-- Where every region is, from its anchors: { left, top, right, bottom } in
-- units from the prompt's top left, y down. The secure button is the root.
local function Layout(button, W, Hh)
	local cache = {}
	local rectOf
	local function side(point)
		local h = point:find("LEFT") and "L" or point:find("RIGHT") and "R" or "C"
		local v = point:find("TOP") and "T" or point:find("BOTTOM") and "B" or "C"
		return h, v
	end
	local function at(rect, point)
		local h, v = side(point)
		local x = h == "L" and rect[1] or h == "R" and rect[3] or (rect[1] + rect[3]) / 2
		local y = v == "T" and rect[2] or v == "B" and rect[4] or (rect[2] + rect[4]) / 2
		return x, y
	end
	rectOf = function(r)
		if cache[r] ~= nil then return cache[r] or nil end
		cache[r] = false
		local out
		if r == button then
			out = { 0, 0, W, Hh }
		elseif r._allPointsTo then
			out = rectOf(r._allPointsTo)
		elseif r.points and #r.points > 0 then
			local hx, vy = {}, {}
			for _, p in ipairs(r.points) do
				local point, a, b, c, d = p[1], p[2], p[3], p[4], p[5]
				local rel, relPoint, x, y = r._parent, point, 0, 0
				if type(a) == "number" then
					x, y = a, b or 0
				elseif a ~= nil then
					rel = a
					if type(b) == "string" then
						relPoint, x, y = b, c or 0, d or 0
					elseif type(b) == "number" then
						x, y = b, c or 0
					end
				end
				local relRect = rel and rectOf(rel)
				if not relRect then return nil end
				local ax, ay = at(relRect, relPoint)
				local h, v = side(point)
				hx[h], vy[v] = ax + x, ay - y
			end
			-- A line with no width of its own is as wide as its text.
			local w = r._width or (r._kind == "FontString" and r.GetStringWidth and r:GetStringWidth()) or nil
			local hgt = r._height or (r._kind == "FontString" and r._font and r._font.size) or nil
			local l, rr, t, bb
			if hx.L and hx.R then l, rr = hx.L, hx.R
			elseif hx.L and w then l, rr = hx.L, hx.L + w
			elseif hx.R and w then l, rr = hx.R - w, hx.R
			elseif hx.C and w then l, rr = hx.C - w / 2, hx.C + w / 2 end
			if vy.T and vy.B then t, bb = vy.T, vy.B
			elseif vy.T and hgt then t, bb = vy.T, vy.T + hgt
			elseif vy.B and hgt then t, bb = vy.B - hgt, vy.B
			elseif vy.C and hgt then t, bb = vy.C - hgt / 2, vy.C + hgt / 2 end
			if l and t then out = { l, t, rr, bb } end
		end
		cache[r] = out or false
		return out
	end
	return rectOf
end

-- The frame a region draws with, and where in that frame's stack it draws:
-- frame level, then layer, then sublevel, then the order it was made in.
local function drawKey(r)
	local frame = r
	if r._kind == "Texture" or r._kind == "FontString" then frame = r._parent end
	return { (frame and frame._level) or 0, FT.LAYERS[r._layer or "ARTWORK"] or 3, r._sublevel or 0, r._serial or 0 }
end

local function drawsAbove(a, b)
	local ka, kb = drawKey(a), drawKey(b)
	for i = 1, 4 do
		if ka[i] ~= kb[i] then return ka[i] > kb[i] end
	end
	return false
end

-- How strongly a region is drawn: its alpha and every frame's above it. A
-- group that is playing is taken at the brightest its alpha animations reach:
-- the mock does not run them, the game does.
local function strength(r)
	local a = 1
	local x = r
	while x do
		local own = x._alpha or 1
		for _, g in ipairs(x._groups or {}) do
			if g._playing then
				for _, anim in ipairs(g._anims) do
					if anim._kind == "Alpha" then
						own = math.max(own, anim._fromAlpha or 0, anim._toAlpha or 0)
					end
				end
			end
		end
		a = a * own
		x = x._parent
	end
	return a
end

-- The colour a texture puts at (x, y), vertex colour included, with its
-- alpha; nil where it draws nothing there.
local function sample(r, rect, x, y)
	if x < rect[1] or x >= rect[3] or y < rect[2] or y >= rect[4] then return nil end
	local c = r._color or { 1, 1, 1, 1 }
	local vr, vg, vb, va = c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
	if r._colorTexture then
		local k = r._colorTexture
		return k[1] * vr, k[2] * vg, k[3] * vb, (k[4] or 1) * va
	end
	if type(r._file) ~= "string" then return nil end
	local img = readTga(r._file)
	if not img then return nil end
	local l, rr, t, b = 0, 1, 0, 1
	local tc = r._texCoord
	if tc and #tc == 4 then l, rr, t, b = tc[1], tc[2], tc[3], tc[4] end
	local u = l + (x - rect[1]) / (rect[3] - rect[1]) * (rr - l)
	local v = t + (y - rect[2]) / (rect[4] - rect[2]) * (b - t)
	local tx = math.max(0, math.min(img.w - 1, math.floor(u * img.w)))
	local ty = math.max(0, math.min(img.h - 1, math.floor(v * img.h)))
	local i = ty * img.w + tx + 1
	return img.r[i] * vr, img.g[i] * vg, img.b[i] * vb, img.a[i] * va
end

-- Everything on screen that is a texture, with where it is.
local function drawn(rectOf)
	local out = {}
	for _, r in ipairs(FT.all) do
		if r._kind == "Texture" and FT.visible(r) and r._layer ~= "HIGHLIGHT" then
			local a = strength(r)
			local rect = a > 0 and rectOf(r)
			if rect and rect[3] > rect[1] and rect[4] > rect[2] then
				out[#out + 1] = { r = r, rect = rect, a = a }
			end
		end
	end
	return out
end

-- A region's name on the look, for the message.
local function nameOf(look, r)
	for k, v in pairs(look) do
		if v == r then return k end
		if type(v) == "table" and not v._kind then
			for i, x in ipairs(v) do
				if x == r then return k .. "[" .. i .. "]" end
			end
		end
	end
	return "a region of Prompt's (" .. tostring(r._file or "solid") .. ")"
end

-- ------------------------------------------------------------------ rule 1

-- What is drawn over the icon, more than EDGE units inside its shape. The
-- shape is the icon's mask where it has one.
local function overIcon(ns, look)
	local r = ns.Prompt:Regions()
	local icon = r.icon
	if not FT.visible(icon) or (icon._alpha or 1) <= 0 then return {} end
	local p = ns.db.profile.prompt
	local rectOf = Layout(ns.Prompt:GetButton(), p.width, p.height)
	local box = rectOf(icon)
	if not box then return { "the icon has no place to be found" } end
	local mask = icon._mask
	local maskRect = mask and rectOf(mask)
	local function inside(x, y)
		if x < box[1] or x >= box[3] or y < box[2] or y >= box[4] then return false end
		if not maskRect then return true end
		local _, _, _, a = sample(mask, maskRect, x, y)
		return (a or 0) >= 0.5
	end
	local d = EDGE * 0.7071
	local function deep(x, y)
		return inside(x, y) and inside(x - EDGE, y) and inside(x + EDGE, y) and inside(x, y - EDGE)
			and inside(x, y + EDGE) and inside(x - d, y - d) and inside(x + d, y - d)
			and inside(x - d, y + d) and inside(x + d, y + d)
	end
	local found, seen = {}, {}
	for _, t in ipairs(drawn(rectOf)) do
		local tr = t.rect
		if t.r ~= icon and t.r._kind == "Texture" and drawsAbove(t.r, icon)
			and tr[1] < box[3] - EDGE and tr[3] > box[1] + EDGE and tr[2] < box[4] - EDGE and tr[4] > box[2] + EDGE then
			local x0, x1 = math.max(tr[1], box[1] + EDGE), math.min(tr[3], box[3] - EDGE)
			local y0, y1 = math.max(tr[2], box[2] + EDGE), math.min(tr[4], box[4] - EDGE)
			local worst = 0
			for y = y0 + 0.25, y1, 0.5 do
				for x = x0 + 0.25, x1, 0.5 do
					if deep(x, y) then
						local _, _, _, a = sample(t.r, tr, x, y)
						if a then
							a = a * t.a * (t.r._blend == "ADD" and 2 or 1)
							if a > worst then worst = a end
						end
					end
				end
			end
			if worst > FAINT then
				local name = nameOf(look, t.r)
				if not seen[name] then
					seen[name] = true
					found[#found + 1] = ("%s (%.2f)"):format(name, worst)
				end
			end
		end
	end
	return found
end

local function iconClean(ns, look, scenario, when)
	local found = overIcon(ns, look)
	if #found > 0 then
		fail(scenario, ("drawn over the spell icon %s: %s"):format(when, table.concat(found, ", ")))
	end
end

-- ------------------------------------------------------------------ rule 2

-- The ground under a line of text, over a world of this luminance, at every
-- unit of the line: every texture drawn under it, in the order drawn, ADD at
-- twice its alpha. A list of { r, g, b, x, y }.
local function groundUnder(ns, fs, world)
	local p = ns.db.profile.prompt
	local rectOf = Layout(ns.Prompt:GetButton(), p.width, p.height)
	local box = rectOf(fs)
	if not box then return nil end
	local under = {}
	for _, t in ipairs(drawn(rectOf)) do
		if drawsAbove(fs, t.r) then under[#under + 1] = t end
	end
	table.sort(under, function(a, b) return drawsAbove(b.r, a.r) end)
	local grey = greyOf(world)
	local out = {}
	for y = box[2] + 0.5, box[4], 1 do
		for x = box[1] + 0.5, box[3], 1 do
			local cr, cg, cb = grey, grey, grey
			for _, t in ipairs(under) do
				local sr, sg, sb, sa = sample(t.r, t.rect, x, y)
				if sr then
					local a = sa * t.a
					if t.r._blend == "ADD" then
						a = math.min(1, a * 2)
						cr, cg, cb = math.min(1, cr + sr * a), math.min(1, cg + sg * a), math.min(1, cb + sb * a)
					else
						cr, cg, cb = sr * a + cr * (1 - a), sg * a + cg * (1 - a), sb * a + cb * (1 - a)
					end
				end
			end
			out[#out + 1] = { cr, cg, cb, x, y }
		end
	end
	return out
end

-- Each colour against the ground under the line, over both worlds, at its
-- worst unit. The text is laid on at the alpha it is drawn with -- its own
-- and every frame's above it, so a fight's dimmed text is judged as dimmed.
local function readable(ns, scenario, fs, line, colours, when)
	local ta = strength(fs)
	for _, world in ipairs(WORLDS) do
		local ground = groundUnder(ns, fs, world)
		if not ground or #ground == 0 then
			fail(scenario, ("the %s has no place to be found %s"):format(line, when))
			return
		end
		for _, c in ipairs(colours) do
			local a = ta * (c[4] or 1)
			local got, where = math.huge, nil
			for _, g in ipairs(ground) do
				local lt = luminance(c[1] * a + g[1] * (1 - a), c[2] * a + g[2] * (1 - a), c[3] * a + g[3] * (1 - a))
				local lg = luminance(g[1], g[2], g[3])
				local here = lt > lg and ratio(lt, lg) or 0
				if here < got then got, where = here, g end
			end
			if got < LEAST then
				fail(scenario, ("%s on the ground under the %s %s, over a world of luminance %.2f: %.2f:1 (at %.0f,%.0f)")
					:format(c.name, line, when, world, got, where[4], where[5]))
			end
		end
	end
end

-- The colours a line is drawn in: its own, and every colour code written in
-- its text (the fight's "held" line, a hint), which the game draws instead.
local function colourOf(fs, name)
	local c = fs._textColor or { 1, 1, 1, 1 }
	local out = { { c[1], c[2], c[3], c[4] or 1, name = name } }
	local text = fs.GetText and fs:GetText()
	if type(text) == "string" then
		for a, r, g, b in text:gmatch("|c(%x%x)(%x%x)(%x%x)(%x%x)") do
			out[#out + 1] = { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255,
				(c[4] or 1) * tonumber(a, 16) / 255, name = name .. " (|c" .. a .. r .. g .. b .. " in its text)" }
		end
	end
	return out
end

-- What the name line can be drawn in: white, the gold the preview and the
-- hints use, and every class colour taken as far towards white as the look
-- takes it; and whatever colour the line itself is set to.
local function nameColours(ns, look)
	local out = { { 1, 1, 1, name = "white" }, { 1, 0xd1 / 255, 0, name = "gold |cffffd100" } }
	local soften = look.classSoften or 0
	for class, code in pairs(CLASSES) do
		local c = { name = "a " .. class .. "'s softened colour" }
		for i, at in ipairs({ 1, 3, 5 }) do
			local v = hex(code, at)
			c[i] = math.floor((v + (1 - v) * soften) * 255 + 0.5) / 255
		end
		out[#out + 1] = c
	end
	for _, c in ipairs(colourOf(ns.Prompt:Regions().name, "the name's own colour")) do out[#out + 1] = c end
	return out
end

-- ------------------------------------------------------------------ setup

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

-- The prompt up in Arcane with Anna owed on top, the arrival's flare over.
local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "arcane"
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	Mock.advance(1.5)
	ns.addon:Tick()
	FT.settle()
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function isArcane(look) return look ~= nil and look.runes ~= nil and look.keycap ~= nil end

local SHAPES = {
	{ "a square icon", function() end },
	{ "a round icon", function(p) p.roundIcon = true end },
	{ "a big icon on a tall card", function(p) p.height, p.iconSize, p.fontSize, p.width = 58, 44, 17, 320 end },
	{ "a small icon on a short card", function(p) p.height, p.iconSize, p.fontSize = 34, 16, 11 end },
}

-- ------------------------------------------------------------------ 1
-- The icon at rest: somebody owed on top (the breath running), under the
-- cursor, on Calm, in a fight, with the list and the count up.
withTree("Arcane draws the spell icon clean", CROWD, function(ns, scenario)
	for _, shape in ipairs(SHAPES) do
		local _, p, look = upIn(ns, scenario, function(pp)
			pp.showQueue, pp.queueRows = true, 3
			shape[2](pp)
		end)
		if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
		iconClean(ns, look, scenario, "at rest with " .. shape[1])
		local b = ns.Prompt:GetButton()
		b.scripts.OnEnter(b)
		Mock.advance(0.5)
		FT.settle()
		iconClean(ns, look, scenario, "under the cursor with " .. shape[1])
		b.scripts.OnLeave(b)
		Mock.advance(0.5)
		FT.settle()
		p.effects = "calm"
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		Mock.advance(1.5)
		FT.settle()
		iconClean(ns, look, scenario, "on Calm with " .. shape[1])
		p.effects = "full"
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		ns.addon:Tick()
		Mock.advance(2)
		FT.settle()
		iconClean(ns, look, scenario, "in a fight with " .. shape[1])
		Mock.inCombat = false
		if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
		ns.addon:Tick()
		FT.settle()
	end
end)

-- ------------------------------------------------------------------ 2
-- A new favour's flourish may cross the icon for half a second; what is
-- still playing after that may not.
withTree("Arcane's arrival leaves the icon clean after half a second", ANNA, function(ns, scenario)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "arcane"
	ns.Prompt:ApplyStyle()
	local look = ns.Prompt:Regions().look
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	-- A favour returned: the light crosses too.
	look:Attention(true, true, "pulse")
	-- What has run its length is over; what is still playing is taken at its
	-- brightest.
	Mock.advance(0.5)
	FT.settle()
	iconClean(ns, look, scenario, "half a second after a favour arrived")
end)

-- ------------------------------------------------------------------ 3
-- The coin with the count on it, wherever the icon and the text are.
withTree("Arcane's count coin never covers the icon", CROWD, function(ns, scenario)
	for _, shape in ipairs(SHAPES) do
		local r, _, look = upIn(ns, scenario, function(pp)
			pp.showCount = true
			shape[2](pp)
		end)
		if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
		local p = ns.db.profile.prompt
		local rectOf = Layout(ns.Prompt:GetButton(), p.width, p.height)
		local icon = rectOf(r.icon)
		if not (look.badge[2]._shown ~= false and r.count._shown ~= false) then
			fail(scenario, "three more people waiting and no count with " .. shape[1])
		else
			for i, t in ipairs(look.badge) do
				local c = rectOf(t)
				if not c then
					fail(scenario, "the count's coin has no place to be found with " .. shape[1])
				elseif icon and c[1] < icon[3] and c[3] > icon[1] and c[2] < icon[4] and c[4] > icon[2] then
					fail(scenario, ("the count's coin (part %d) covers the icon with %s"):format(i, shape[1]))
					break
				end
			end
			local name = rectOf(r.name)
			local coin = rectOf(look.badgeBox)
			if name and coin and name[3] > coin[1] + 0.5 then
				fail(scenario, "the name runs under the count's coin with " .. shape[1])
			end
		end
	end
end)

-- ------------------------------------------------------------------ 4
-- The name and the reason line on their ground, for every reason in both
-- palettes, under the cursor too.
withTree("Arcane's text has a dark ground", CROWD, function(ns, scenario)
	for _, shape in ipairs({ SHAPES[1], SHAPES[2], SHAPES[3] }) do
		local r, p, look = upIn(ns, scenario, function(pp)
			pp.showCount = true
			shape[2](pp)
		end)
		if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
		if not r.sub:IsShown() then fail(scenario, "no reason line to read with " .. shape[1]) return end
		readable(ns, scenario, r.name, "name", nameColours(ns, look), "with " .. shape[1])
		for _, palette in ipairs({ "standard", "colourblind" }) do
			p.reasonPalette = palette
			for _, mode in ipairs({ "icon", "off" }) do
				p.accentMode = mode
				ns.Prompt:ApplyStyle()
				for _, reason in ipairs({ "owed", "target", "asked", "group", "nearby", "self" }) do
					ns.Prompt:PaintAccent(reason)
					readable(ns, scenario, r.sub, "reason line", colourOf(r.sub, reason .. "'s reason line"),
						("in the %s set, marker %s, with %s"):format(palette, mode, shape[1]))
				end
			end
		end
		p.reasonPalette, p.accentMode = "standard", "icon"
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		FT.settle()
		if r.count._shown ~= false then
			readable(ns, scenario, r.count, "count", colourOf(r.count, "the count"), "with " .. shape[1])
		end
		local b = ns.Prompt:GetButton()
		b.scripts.OnEnter(b)
		Mock.advance(0.5)
		FT.settle()
		readable(ns, scenario, r.name, "name", nameColours(ns, look), "under the cursor with " .. shape[1])
		readable(ns, scenario, r.sub, "reason line", colourOf(r.sub, "the reason line"),
			"under the cursor with " .. shape[1])
		b.scripts.OnLeave(b)
		Mock.advance(0.5)
		FT.settle()
		-- In a fight the text dims with the rest of the ink and keeps the
		-- reason's colour: dimmed, it still reads.
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		ns.addon:Tick()
		Mock.advance(2)
		FT.settle()
		readable(ns, scenario, r.name, "name", nameColours(ns, look), "in a fight with " .. shape[1])
		readable(ns, scenario, r.sub, "reason line", colourOf(r.sub, "the reason line"),
			"as a fight starts with " .. shape[1])
		for _, palette in ipairs({ "standard", "colourblind" }) do
			p.reasonPalette = palette
			ns.Prompt:ApplyStyle()
			for _, reason in ipairs({ "owed", "target", "asked", "group", "nearby", "self" }) do
				ns.Prompt:PaintAccent(reason)
				readable(ns, scenario, r.sub, "reason line", colourOf(r.sub, reason .. "'s reason line"),
					("in a fight in the %s set with %s"):format(palette, shape[1]))
			end
		end
		p.reasonPalette = "standard"
		Mock.inCombat = false
		if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		FT.settle()
	end
end)

-- ------------------------------------------------------------------ 4b
-- A marker colour of the player's own, deep, on every reason: one colour, so
-- nothing repaints the reason line when a fight starts. The look must bring
-- it up to the dimmed text itself.
withTree("Arcane's reason line reads as a fight starts", ANNA, function(ns, scenario)
	local r, p, look = upIn(ns, scenario, function(pp)
		pp.accentByReason = false
		pp.accentColor = { 0.30, 0.16, 0.62, 1 }
	end)
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	readable(ns, scenario, r.sub, "reason line", colourOf(r.sub, "the marker colour's reason line"), "at rest")
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.addon:Tick()
	Mock.advance(2)
	FT.settle()
	readable(ns, scenario, r.sub, "reason line", colourOf(r.sub, "the marker colour's reason line"), "in a fight")
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
	ns.addon:Tick()
	FT.settle()
	readable(ns, scenario, r.sub, "reason line", colourOf(r.sub, "the marker colour's reason line"), "after the fight")
	if p.accentColor[1] ~= 0.30 then fail(scenario, "the player's marker colour was changed") end
end)

-- ------------------------------------------------------------------ 5
-- An outcome's verdict is written where its wash and its flourish play: it
-- must read there too, with the icon and without.
withTree("Arcane's verdict reads on its wash", ANNA, function(ns, scenario)
	for _, showIcon in ipairs({ true, false }) do
		local r, _, look = upIn(ns, scenario, function(pp) pp.showIcon = showIcon end)
		if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
		local with = showIcon and "" or " with the icon off"
		for _, case in ipairs({ { "cast" }, { "failed", "Out of range." }, { "sent" } }) do
			ns.Prompt:ShowOutcome(case[1], "Anna Aim", case[2])
			local when = "during a " .. case[1] .. " outcome" .. with
			readable(ns, scenario, r.name, "name", colourOf(r.name, "the name"), when)
			readable(ns, scenario, r.sub, "reason line", colourOf(r.sub, "the " .. case[1] .. " verdict"), when)
			Mock.advance(2)
			ns.addon:Tick()
			FT.settle()
		end
	end
	-- And in a fight, where the text is dimmed.
	local r = upIn(ns, scenario)
	Mock.inCombat = true
	ns.addon:PLAYER_REGEN_DISABLED()
	ns.addon:Tick()
	Mock.advance(2)
	FT.settle()
	for _, case in ipairs({ { "cast" }, { "failed", "Out of range." }, { "sent" } }) do
		ns.Prompt:ShowOutcome(case[1], "Anna Aim", case[2])
		-- Past the text's own cross-fade, which brings it up to full for a
		-- moment: the verdict is read at the fight's dimmed alpha.
		Mock.advance(0.3)
		FT.settle()
		readable(ns, scenario, r.sub, "reason line", colourOf(r.sub, "the " .. case[1] .. " verdict"),
			"during a " .. case[1] .. " outcome in a fight")
		Mock.advance(2)
		ns.addon:Tick()
		FT.settle()
	end
	Mock.inCombat = false
	if ns.addon.PLAYER_REGEN_ENABLED then ns.addon:PLAYER_REGEN_ENABLED() end
end)

-- ------------------------------------------------------------------ 6
-- The preview's name is white, not the gold of the hints, and reads.
withTree("Arcane's preview name is white", {}, function(ns, scenario)
	freshPrompt(ns, scenario)
	ns.db.profile.prompt.style = "arcane"
	ns.Prompt:ApplyStyle()
	local r = ns.Prompt:Regions()
	local look = r.look
	if not isArcane(look) then fail(scenario, "SKIPPED -- Arcane is not the look in use") return end
	Mock.optionsOpen = true
	ns.Prompt:ToggleTest()
	FT.settle()
	local text = tostring(r.name:GetText())
	if not text:find("PREVIEW", 1, true) then
		fail(scenario, "the preview does not name itself: " .. text)
	elseif text:lower():find("|cffffd100", 1, true) then
		fail(scenario, "the preview's name is still gold: " .. text)
	end
	readable(ns, scenario, r.name, "name", colourOf(r.name, "the preview's name"), "in the preview")
	ns.Prompt:ToggleTest()
	Mock.optionsOpen = nil
end)
