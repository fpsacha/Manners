-- The geometry of the prompt's effects at a moment, as the renderer works it
-- out (tools/render_prompt.py, group_effect and place): what a playing group
-- does to the frame that owns it, the rectangle of a region as the animations
-- between it and the art have moved and grown it, and whether it is drawn at
-- all. Shared by tests/scenarios/hunt37-effects.lua (the rings' room) and
-- tests/scenarios/entrance-light.lua (the rules of light), so one reading of a
-- Scale serves both: about the frame's middle unless the animation names
-- another origin (SetOrigin: a rule drawn out from its left end grows about
-- LEFT, and its left edge stays put).
--
-- Loaded with dofile after tests/frametree.lua; hands back a table of functions.

local FT = FrameTree

local G = {}

local function smooth(t, how)
	if how == "IN" then return t * t end
	if how == "OUT" then return 1 - (1 - t) * (1 - t) end
	if how == "IN_OUT" then return 3 * t * t - 2 * t * t * t end
	return t
end
G.smooth = smooth

-- What a playing group does to its owner `now`: an alpha, a translation, a
-- scale and the point the scale is about, as the renderer works them out.
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
	local alpha, dx, dy, scale, origin = nil, 0, 0, nil, nil
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
						-- Where the scale is about: the frame's middle unless
						-- the animation says another point.
						origin = a._origin
					end
				end
			end
		end
		start = start + lengths[o]
	end
	return { alpha = alpha, dx = dx, dy = dy, scale = scale, origin = origin }
end
G.groupAt = groupAt

-- What every playing group on `node` adds up to.
function G.effectOf(node, now)
	local out
	for _, g in ipairs(node._groups or {}) do
		local e = groupAt(g, now)
		if e then
			if not out then
				out = e
			else
				if e.alpha ~= nil then out.alpha = e.alpha end
				out.dx, out.dy = out.dx + e.dx, out.dy + e.dy
				if e.scale then out.scale, out.origin = e.scale, e.origin end
			end
		end
	end
	return out
end

-- The chain from a region up to, but not including, `stop` (the art).
function G.chain(r, stop)
	local out = {}
	while r and r ~= stop do
		out[#out + 1] = r
		r = r._parent
	end
	return out
end

-- The fraction of a frame's span a point name stands for, each axis: LEFT 0,
-- CENTER 0.5, RIGHT 1; BOTTOM 0, CENTER 0.5, TOP 1.
local function fraction(point)
	local fx, fy = 0.5, 0.5
	if point:find("LEFT", 1, true) then fx = 0 elseif point:find("RIGHT", 1, true) then fx = 1 end
	if point:find("BOTTOM", 1, true) then fy = 0 elseif point:find("TOP", 1, true) then fy = 1 end
	return fx, fy
end
G.fraction = fraction

-- A region's rectangle as the animations between it and `art` have moved and
-- grown it, in screen units: { L, B, R, T }, or nil when it has none. The
-- scale is about the animated frame's origin -- its own middle unless the
-- animation names a point of it and an offset from that point -- then its
-- translation.
function G.rectAt(r, art, now)
	local L, R = FT.span(r, "x")
	local B, T = FT.span(r, "y")
	if not (L and B) then return nil end
	for _, c in ipairs(G.chain(r, art)) do
		local e = G.effectOf(c, now)
		if e then
			if e.scale then
				local cl, cr = FT.span(c, "x")
				local cb, ct = FT.span(c, "y")
				if cl and cb then
					local origin = e.origin
					local point = origin and origin[1] or "CENTER"
					local fx, fy = fraction(point)
					local s = FT.scaleOf(c)
					local cx = cl + (cr - cl) * fx + (origin and origin[2] or 0) * s
					local cy = cb + (ct - cb) * fy + (origin and origin[3] or 0) * s
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
function G.seenAt(r, art, now)
	if not FT.visible(r) then return false end
	return G.alphaAt(r, now) > 0.02
end

-- The alpha a region is drawn at `now`: its own, replaced by a playing
-- group's while one runs, multiplied up every frame above it.
function G.alphaAt(r, now)
	local a = 1
	local node = r
	while node do
		local own = node._alpha
		if own == nil then own = 1 end
		local e = G.effectOf(node, now)
		if e and e.alpha ~= nil then own = e.alpha end
		a = a * own
		node = node._parent
	end
	return a
end

return G
