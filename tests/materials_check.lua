-- Reads a shipped texture and answers the questions tools/materials.py's caps
-- ask of it, so each look's own scenario file can hold its own files to them:
--
--   local MC = dofile(dir .. "/tests/materials_check.lua")
--   local ok, maxLuma = MC.capOK(dir .. "/Textures/GlassPane.tga", 0.80)
--
-- Nothing here is shared state: every look's scenario file dofiles this and
-- declares its own files, so no table is edited by two worktrees at once.
--
--   MC.readTGA(path)         -> { w, h, data, offset } for a 32-bit type-2
--                               (uncompressed true-colour) TGA, else nil
--   MC.capOK(path, cap)      -> ok, maxLuma: the brightest opaque texel's
--                               Rec.601 luma (alpha over a half), <= cap
--   MC.underText(path)       -> ok, mean: the mean luma of the opaque texels
--                               is at most MC.UNDER_TEXT (a ground words
--                               stay legible on)
--   MC.isGrey(path)          -> every texel has r == g == b (vertex-tinted art)
--   MC.pow2(path)            -> both sides powers of two, at most 256
--   MC.luma(r, g, b)         -> Rec.601 luma of 0..255 channels, 0..1
--
-- The texel walk is plain Lua 5.1 on string.byte; a 128 x 128 file is 16,384
-- texels, well under a second even on lupa.

local MC = {}

-- The threshold for "opaque": the alpha a texel must have to count toward a
-- cap, as a fraction of 1.
MC.OPAQUE = 0.5
-- The mean luma a ground under text may have.
MC.UNDER_TEXT = 0.32

function MC.luma(r, g, b)
	return (r * 0.299 + g * 0.587 + b * 0.114) / 255
end

function MC.readTGA(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	if not data or #data < 18 then return nil end
	local b = { data:byte(1, 18) }
	-- Type 2 (uncompressed true colour), no colour map, 32 bits a texel.
	if b[3] ~= 2 or b[2] ~= 0 or b[17] ~= 32 then return nil end
	local w, h = b[13] + b[14] * 256, b[15] + b[16] * 256
	local offset = 18 + b[1]
	if #data < offset + w * h * 4 then return nil end
	return { w = w, h = h, data = data, offset = offset }
end

-- Walks every texel as (b, g, r, a) bytes, calling fn(r, g, b, a).
local function each(tga, fn)
	local data, at = tga.data, tga.offset
	for i = 0, tga.w * tga.h - 1 do
		local bb, gg, rr, aa = data:byte(at + i * 4 + 1, at + i * 4 + 4)
		fn(rr, gg, bb, aa)
	end
end

function MC.capOK(path, cap)
	local tga = MC.readTGA(path)
	if not tga then return false, nil end
	local maxLuma = 0
	local opaque = MC.OPAQUE * 255
	each(tga, function(r, g, b, a)
		if a > opaque then
			local l = MC.luma(r, g, b)
			if l > maxLuma then maxLuma = l end
		end
	end)
	return maxLuma <= cap + 1e-9, maxLuma
end

function MC.underText(path)
	local tga = MC.readTGA(path)
	if not tga then return false, nil end
	local sum, n = 0, 0
	local opaque = MC.OPAQUE * 255
	each(tga, function(r, g, b, a)
		if a > opaque then
			sum = sum + MC.luma(r, g, b)
			n = n + 1
		end
	end)
	local mean = n > 0 and sum / n or 0
	return mean <= MC.UNDER_TEXT, mean
end

function MC.isGrey(path)
	local tga = MC.readTGA(path)
	if not tga then return false end
	local grey = true
	each(tga, function(r, g, b)
		if r ~= g or g ~= b then grey = false end
	end)
	return grey
end

local function powerOfTwo(n)
	if n < 1 then return false end
	while n > 1 do
		if n % 2 ~= 0 then return false end
		n = n / 2
	end
	return true
end

function MC.pow2(path)
	local tga = MC.readTGA(path)
	if not tga then return false end
	return powerOfTwo(tga.w) and powerOfTwo(tga.h) and tga.w <= 256 and tga.h <= 256
end

return MC
