-- The built-in bezel's lip in the owed light: one lit frame, corners and all.
--
-- The bezel (tools/make_panel_textures.py) is round at its corners: its dark
-- lip turns each corner on an arc about the hole's corner, closer in than it
-- runs along the sides. The halos that breathe on an owed bezel (the reason's
-- glow and the warm white rim, Prompt/Prompt.lua's Halo) start a square gap
-- out from the icon. So a lip the light lay on along every side turned each
-- corner inside the gap, out of the light, and showed as a dark notch at the
-- four corners of every owed bezel in glass, framed and minimal. Panel.lua now
-- carries the halos' light in at each corner as far as the lip comes, where
-- (and only where) the lip along the sides is in the light.
--
-- What these hold the prompt to:
--   * at the default size, a small one and a large one, in every built-in
--     look, every point along the middle of the lip's band -- along the sides
--     and round the arc of each corner -- lies in the glow and in the rim (or
--     within a sliver of it too thin to show);
--   * where the lip is out of the light all round (the biggest icon at the
--     default height, a 160 x 32 prompt) nothing lights the gap, and round a
--     round icon only the ring is drawn;
--   * the light carried into each corner is the halo's own: the same file,
--     blend and vertex colour, cut from within a texel of the glow's middle on
--     its corner's side, so it meets the corner piece and the sides without a
--     seam;
--   * Prompt.lua's figures for the lip are the generator's.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local BUILTIN = { "glass", "framed", "minimal" }
local GLOW = "Interface\\AddOns\\Manners\\Textures\\Glow"
local GENERATOR = "tools/make_panel_textures.py"
-- The bezel file's texels, and where its lip runs in them (from the file's
-- middle): the hole's corner circle, the radius of the lip's inner edge round
-- it, that edge along a side, and the lip's width (its outer edge is the
-- inner one moved out by that much on each axis: the outer corner is the
-- same radius about a centre LIP texels further out). Read against the
-- generator below.
local BEZEL_TEXELS = 128
local HOLE_CORNER, LIP_IN_RADIUS, LIP_IN_SIDE, LIP_WIDTH = 47, 12, 59, 3
-- A sliver of the gap thinner than this, in units, is a sixth of a pixel at
-- the finest scale anybody plays at: it cannot show.
local SLIVER = 0.15

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

-- The prompt in `style` at `size` (width, height, font, icon; nil for the
-- default 220 x 44, 13 pt, icon 30), Anna owed on top.
local function upIn(ns, scenario, style, size, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = style
	p.effects = "full"
	p.flashStyle = "pulse"
	p.showIcon = true
	p.roundIcon = false
	p.accentMode = "icon"
	size = size or { 220, 44, 13, 30 }
	p.width, p.height, p.fontSize, p.iconSize = size[1], size[2], size[3], size[4]
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	FT.settle()
	return ns.Prompt:Regions(), p
end

local function rectOf(r)
	local L, R = FT.span(r, "x")
	local B, T = FT.span(r, "y")
	if not (L and B) then return nil end
	return { L, B, R, T }
end

-- Every texture a light frame draws: shown, with a size.
local function lights(frame)
	local out = {}
	for _, node in ipairs(FT.all) do
		if node._kind == "Texture" and node._parent == frame and FT.visible(node) then
			local box = rectOf(node)
			if box and box[3] - box[1] > 1e-6 and box[4] - box[2] > 1e-6 then
				out[#out + 1] = { tex = node, box = box }
			end
		end
	end
	return out
end

local function inside(box, x, y, slack)
	return x >= box[1] - slack and x <= box[3] + slack and y >= box[2] - slack and y <= box[4] + slack
end

local function lit(list, x, y)
	for _, l in ipairs(list) do
		if inside(l.box, x, y, SLIVER) then return true end
	end
	return false
end

-- Points along the middle of the lip's band, in texels from the bezel's
-- middle, one corner's worth (x and y both positive): along the two sides up
-- to the corner, and round the corner's arc.
local function lipPoints()
	local out = {}
	local half = LIP_WIDTH / 2
	local d = LIP_IN_SIDE + half
	for _, t in ipairs({ 0, 15, 30, 40, HOLE_CORNER }) do
		out[#out + 1] = { d, t, "the side" }
		out[#out + 1] = { t, d, "the side" }
	end
	local c = HOLE_CORNER + half
	for i = 0, 12 do
		local a = math.rad(i * 7.5)
		out[#out + 1] = { c + LIP_IN_RADIUS * math.cos(a), c + LIP_IN_RADIUS * math.sin(a), "the corner" }
	end
	return out
end

local SIZES = {
	{ name = "the default 220 x 44, icon 30" },
	{ name = "180 x 40, icon 26", p = { 180, 40, 11, 26 } },
	{ name = "320 x 58, icon 40", p = { 320, 58, 17, 40 } },
}

-- ------------------------------------------------------------------ 1
withTree("bezel-corner: an owed bezel is lit all the way round its lip, corners and all", ANNA, function(ns, scenario)
	local points = lipPoints()
	local checked = 0
	for _, style in ipairs(BUILTIN) do
		for _, size in ipairs(SIZES) do
			local r = upIn(ns, scenario, style, size.p)
			local tag = style .. ", " .. size.name
			local bezel = r.bezel and rectOf(r.bezel)
			if not (bezel and r.glow and r.rim and FT.visible(r.bezel)) then
				fail(scenario, tag .. ": SKIPPED -- the bezel, the glow or the rim is not reachable")
			else
				local cx, cy = (bezel[1] + bezel[3]) / 2, (bezel[2] + bezel[4]) / 2
				local k = (bezel[3] - bezel[1]) / BEZEL_TEXELS
				for _, which in ipairs({ { "glow", lights(r.glow) }, { "rim", lights(r.rim) } }) do
					local list = which[2]
					if #list < 8 then
						fail(scenario, ("%s: the %s draws %d pieces, so there is no square halo to judge"):format(tag, which[1], #list))
					else
						local missed = {}
						for _, sx in ipairs({ -1, 1 }) do
							for _, sy in ipairs({ -1, 1 }) do
								for _, pt in ipairs(points) do
									local x, y = cx + sx * pt[1] * k, cy + sy * pt[2] * k
									checked = checked + 1
									if not lit(list, x, y) then
										missed[#missed + 1] = ("%s (%.1f, %.1f from the middle)"):format(pt[3], sx * pt[1] * k, sy * pt[2] * k)
									end
								end
							end
						end
						if #missed > 0 then
							fail(scenario, ("%s: %d points of the bezel's lip lie out of the %s, a dark notch in the lit frame: %s"):format(
								tag, #missed, which[1], table.concat(missed, "; ", 1, math.min(4, #missed))))
						end
					end
				end
			end
		end
	end
	if checked < 300 then fail(scenario, "only " .. checked .. " points were judged") end
end)

-- ------------------------------------------------------------------ 2
-- Where the lip lies inside the gap all round, it is a dark outline the whole
-- way, and light carried into the corners alone would be four bright dots.
withTree("bezel-corner: no light is carried in where the lip is out of the light", ANNA, function(ns, scenario)
	local cases = {
		{ name = "220 x 44, icon 36", p = { 220, 44, 13, 36 } },
		{ name = "160 x 32, icon 24", p = { 160, 32, 13, 24 } },
	}
	for _, style in ipairs(BUILTIN) do
		for _, case in ipairs(cases) do
			local r = upIn(ns, scenario, style, case.p)
			local tag = style .. ", " .. case.name
			local icon = r.icon and rectOf(r.icon)
			if not (icon and r.glow and r.rim) then
				fail(scenario, tag .. ": SKIPPED -- the icon, the glow or the rim is not reachable")
			else
				-- The halos start three units out (two of ring, one beyond).
				local g = 3 - 0.05
				local gap = { icon[1] - g, icon[2] - g, icon[3] + g, icon[4] + g }
				for _, which in ipairs({ { "glow", lights(r.glow) }, { "rim", lights(r.rim) } }) do
					for _, l in ipairs(which[2]) do
						local b = l.box
						if b[1] < gap[3] and gap[1] < b[3] and b[2] < gap[4] and gap[2] < b[4] then
							fail(scenario, ("%s: a piece of the %s lies in the gap round the icon (%.1f..%.1f x %.1f..%.1f),"
								.. " where the lip is out of the light all round"):format(tag, which[1], b[1], b[3], b[2], b[4]))
						end
					end
				end
			end
		end
		local r = upIn(ns, scenario, style, nil, function(p) p.roundIcon = true end)
		if r.glow and r.rim and r.icon and r.icon._mask then
			for _, which in ipairs({ { "glow", lights(r.glow) }, { "rim", lights(r.rim) } }) do
				for _, l in ipairs(which[2]) do
					if l.tex._file == GLOW then
						fail(scenario, ("%s, round icon: a square piece of the %s is drawn round a round icon"):format(style, which[1]))
					end
				end
			end
		end
	end
end)

-- ------------------------------------------------------------------ 3
withTree("bezel-corner: the corner's light is the halo's own", ANNA, function(ns, scenario)
	local r = upIn(ns, scenario, "glass")
	local icon = r.icon and rectOf(r.icon)
	if not (icon and r.glowStrips and r.rimStrips) then
		fail(scenario, "SKIPPED -- the icon or the halos are not reachable")
		return
	end
	local cx, cy = (icon[1] + icon[3]) / 2, (icon[2] + icon[4]) / 2
	local g = 3 - 0.05
	local gap = { icon[1] - g, icon[2] - g, icon[3] + g, icon[4] + g }
	local step = 1 / 128 + 1e-6
	for _, which in ipairs({ { "glow", r.glow, r.glowStrips[1] }, { "rim", r.rim, r.rimStrips[1] } }) do
		local name, frame, side = which[1], which[2], which[3]
		local want = side._color
		local found = 0
		for _, l in ipairs(lights(frame)) do
			local b, t = l.box, l.tex
			if b[1] < gap[3] and gap[1] < b[3] and b[2] < gap[4] and gap[2] < b[4] then
				found = found + 1
				local left, top = (b[1] + b[3]) / 2 < cx, (b[2] + b[4]) / 2 > cy
				local where = (top and "top" or "bottom") .. "-" .. (left and "left" or "right")
				if t._file ~= GLOW or t._blend ~= "ADD" then
					fail(scenario, ("the %s's %s corner is lit by %s (%s), not the halo's glow added on"):format(
						name, where, tostring(t._file), tostring(t._blend)))
				end
				local c = t._color
				if type(c) ~= "table" or type(want) ~= "table" then
					fail(scenario, ("the %s's %s corner carries no vertex colour of the halo's"):format(name, where))
				else
					for i = 1, 4 do
						if math.abs((c[i] or 1) - (want[i] or 1)) > 1e-6 then
							fail(scenario, ("the %s's %s corner is not the colour of its sides (%s against %s)"):format(
								name, where, table.concat(c, ", "), table.concat(want, ", ")))
							break
						end
					end
				end
				local tc = t._texCoord
				if type(tc) ~= "table" or #tc ~= 4 then
					fail(scenario, ("the %s's %s corner is the whole glow, not its middle"):format(name, where))
				else
					local u0, u1 = math.min(tc[1], tc[2]), math.max(tc[1], tc[2])
					local v0, v1 = math.min(tc[3], tc[4]), math.max(tc[3], tc[4])
					local uOk = left and (u0 >= 0.5 - step and u1 <= 0.5 + 1e-6) or (not left and u0 >= 0.5 - 1e-6 and u1 <= 0.5 + step)
					local vOk = top and (v0 >= 0.5 - step and v1 <= 0.5 + 1e-6) or (not top and v0 >= 0.5 - 1e-6 and v1 <= 0.5 + step)
					if not (uOk and vOk) then
						fail(scenario, ("the %s's %s corner is cut from %.4f..%.4f x %.4f..%.4f of the glow, not the texel at its"
							.. " middle on the %s side, so it does not meet the corner piece's brightness"):format(
							name, where, u0, u1, v0, v1, where))
					end
				end
			end
		end
		if found ~= 4 then
			fail(scenario, ("the %s carries its light into %d corners of the gap, not four"):format(name, found))
		end
	end
end)

-- ------------------------------------------------------------------ 4
withTree("bezel-corner: the lip's figures agree with the generator", ANNA, function(ns, scenario)
	local f = io.open(dir .. "/" .. GENERATOR, "r")
	if not f then
		fail(scenario, "SKIPPED -- " .. GENERATOR .. " is not there")
		return
	end
	local src = f:read("*a")
	f:close()
	local function num(pattern)
		local v = src:match(pattern)
		return v and tonumber(v)
	end
	local seam, rim, lip = src:match("\nSEAM, RIM, LIP = ([%d.]+), ([%d.]+), ([%d.]+)\n")
	seam, rim, lip = tonumber(seam), tonumber(rim), tonumber(lip)
	local frame = num("\nICON_FRAME = ([%d.]+)")
	local size = num("\nBEZEL_SIZE = (%d+)")
	local holeCorner = num("d_hole = rrect%(x, y, c %- hole, c %- hole, c %+ hole, c %+ hole, ([%d.]+)%)")
	if not (seam and rim and lip and frame and size and holeCorner) then
		fail(scenario, "the bezel's figures were not found in " .. GENERATOR)
		return
	end
	local hole = size * frame / 2
	if size ~= BEZEL_TEXELS or hole - holeCorner ~= HOLE_CORNER or holeCorner + seam + rim ~= LIP_IN_RADIUS
		or hole + seam + rim ~= LIP_IN_SIDE or lip ~= LIP_WIDTH then
		fail(scenario, ("this file's lip (%d texels, corner %g, radius %g, side %g, width %g) is not the generator's"
			.. " (%g, %g, %g, %g, %g)"):format(BEZEL_TEXELS, HOLE_CORNER, LIP_IN_RADIUS, LIP_IN_SIDE, LIP_WIDTH,
			size, hole - holeCorner, holeCorner + seam + rim, hole + seam + rim, lip))
	end
	local lib = ns.Prompt.lib
	local corner = (hole - holeCorner + (holeCorner + seam + rim) / math.sqrt(2)) / size
	local side = (hole + seam + rim + lip / 2) / size
	if not (type(lib.BEZEL_LIP_CORNER) == "number" and math.abs(lib.BEZEL_LIP_CORNER - corner) < 1e-6) then
		fail(scenario, ("Prompt.lua puts the lip's corner at %s of the file, the generator draws it at %.5f"):format(
			tostring(lib.BEZEL_LIP_CORNER), corner))
	end
	if not (type(lib.BEZEL_LIP_SIDE) == "number" and math.abs(lib.BEZEL_LIP_SIDE - side) < 1e-6) then
		fail(scenario, ("Prompt.lua puts the middle of the lip at %s of the file, the generator draws it at %.5f"):format(
			tostring(lib.BEZEL_LIP_SIDE), side))
	end
end)
