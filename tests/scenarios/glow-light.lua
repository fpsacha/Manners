-- The shared light, lit from the upper left, and the shapes the motion is
-- drawn with (tools/make-glow.py).
--
-- The built-in looks' halos and rings used to be the same in every direction:
-- web glow. Now relight() in the generator lets the lower-right half of each
-- of Glow, GlowRound, Ring and RingSq fall to 1 - light_bias while the whole
-- lit half, the top and left axis texels included, keeps the shape exactly as
-- it was drawn, so the files read as game light landing on a thing and the
-- measured reach the code declares for the rings cannot move. The four new
-- white shapes (Rule, Glint, Shock, Crack) are held to the edges that matter
-- when they are stretched along a panel: a rule and a crack end soft, a shock
-- has no slant.
--
-- Every scenario here draws the files afresh into a folder of its own with
-- the generator (and once more with --light-bias 0 for the unlit shape), so a
-- generator that stops lighting is caught here and not only by the shipped
-- bytes (hunt35-effects.lua compares those). Without numpy and Pillow (CI's
-- test job) the scenarios return quietly, as hunt35's generator checks do.

local dir, H = ...
local fail, load = H.fail, H.load

local python = os.getenv("MANNERS_PYTHON") or "python"
local SCRIPT = dir .. "/tools/make-glow.py"
local ART = "Interface\\AddOns\\Manners\\Textures\\"

-- What `python tools/make-glow.py --reach` said of the files before the light
-- was added: where each one's brightest line is and how far out it is seen,
-- in fractions of the half-width. The relit files must say the same within
-- one texel of 128 (0.016).
local RECORDED = {
	Glow = { peak = 0.008, reach = 0.898 },
	GlowRound = { peak = 0.711, reach = 0.961 },
	Ring = { peak = 0.781, reach = 0.914 },
	RingSq = { peak = 0.781, reach = 0.914 },
}
local TEXEL = 1 / 64 + 0.0005
local LIT = { "Glow", "GlowRound", "Ring", "RingSq" }
local ALL = { "Glow", "GlowRound", "Ring", "RingSq", "Rule", "Glint", "Shock", "Crack" }

local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

-- As hunt37-effects.lua reads a ring file: 32-bit uncompressed TGA only. A
-- TGA's rows run bottom-up unless bit 5 of the descriptor byte says
-- top-down (Pillow writes them bottom-up), and this light has a top and a
-- bottom, so the reader keeps the flag and alphaAt turns the rows over.
local function readTGA(path)
	local data = slurp(path)
	if not data then return nil end
	local b = { data:byte(1, 18) }
	if #b < 18 or b[3] ~= 2 or b[17] ~= 32 then return nil end
	local w, h = b[13] + b[14] * 256, b[15] + b[16] * 256
	local topDown = math.floor(b[18] / 32) % 2 == 1
	return { w = w, h = h, data = data, offset = 18 + b[1], topDown = topDown }
end

-- Alpha 0..1 of texel (x, y), the top-left texel of the picture being (0, 0).
local function alphaAt(tga, x, y)
	if not tga.topDown then y = tga.h - 1 - y end
	return tga.data:byte(tga.offset + (y * tga.w + x) * 4 + 4) / 255
end

-- The Chebyshev reach of every texel over 2% alpha, as hunt37 measures it.
local function reachOf(tga)
	local half = tga.w / 2
	local reach = 0
	for y = 0, tga.h - 1 do
		for x = 0, tga.w - 1 do
			if alphaAt(tga, x, y) > 0.02 then
				local d = math.max(math.abs(x + 0.5 - half), math.abs(y + 0.5 - half)) / half
				if d > reach then reach = d end
			end
		end
	end
	return reach
end

local function columnMax(tga, x)
	local m = 0
	for y = 0, tga.h - 1 do m = math.max(m, alphaAt(tga, x, y)) end
	return m
end

-- A folder nobody else is writing into: the scenarios run side by side, each
-- in a copy of the tree of its own, so the tree's path tells them apart
-- (hunt35-effects.lua says why the clock alone does not).
local function tempDir(tag)
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-glowlight-" .. token .. "-" .. tostring(os.time()) .. "-" .. tag
end

local function run(args, log)
	-- os.execute and a log file rather than io.popen, which the Lua that
	-- lupa builds on Linux leaves out.
	os.execute(python .. ' "' .. SCRIPT .. '" ' .. args .. ' > "' .. log .. '" 2>&1')
	local text = slurp(log)
	os.remove(log)
	return text
end

-- Draws the files into `lit` (the generator as it is) and, when asked, into
-- `unlit` (--light-bias 0), runs the body with the folders and the
-- generator's own --reach lines, and removes what it drew. Returns nothing
-- quietly when the generator cannot run for want of numpy or Pillow.
local function withFiles(scenario, wantUnlit, body)
	local lit, unlit = tempDir(scenario:gsub("[^%w]", ""):sub(-24) .. "-lit"), nil
	local out = run('--out "' .. lit .. '"', lit .. ".log")
	if not out then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	if out:find("No module named", 1, true) then return end
	if not out:find("Glow.tga", 1, true) then
		fail(scenario, "the generator wrote nothing: " .. out:sub(1, 200))
		return
	end
	if wantUnlit then
		unlit = lit:gsub("%-lit$", "-unlit")
		run('--out "' .. unlit .. '" --light-bias 0', unlit .. ".log")
	end
	local reach = run('--reach --out "' .. lit .. '"', lit .. "-reach.log") or ""
	local ok, err = pcall(body, lit, unlit, reach)
	for _, name in ipairs(ALL) do
		os.remove(lit .. "/" .. name .. ".tga")
		if unlit then os.remove(unlit .. "/" .. name .. ".tga") end
	end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 1
-- The light comes from the upper left: on the diagonal, the brightest texel
-- of the upper-left half is at least a quarter brighter than its mirror in
-- the lower right. Read at least six texels out from the centre, where the
-- direction of a texel is not a coin toss.
do
	local scenario = "glow-light: the halo is lit from the upper left"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		withFiles(scenario, false, function(lit)
			for _, name in ipairs({ "Glow", "Ring" }) do
				local tga = readTGA(lit .. "/" .. name .. ".tga")
				if not tga then
					fail(scenario, name .. ".tga cannot be read as a 32-bit TGA")
				else
					local n = tga.w
					local crest, at = 0, nil
					for i = 0, n / 2 - 7 do
						local a = alphaAt(tga, i, i)
						if a > crest then crest, at = a, i end
					end
					if not at or crest < 0.1 then
						fail(scenario, name .. ".tga has no crest on the upper-left diagonal")
					else
						local mirror = alphaAt(tga, n - 1 - at, n - 1 - at)
						if crest < 1.25 * mirror then
							fail(scenario, ("%s.tga is lit %.3f at the upper left and %.3f at the lower right: no light falls on it"):format(
								name, crest, mirror))
						end
					end
				end
			end
		end)
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ 2
-- The lit half is the shape itself: every texel of the column just left of
-- the centre, from the top down to the middle, and of the row just above the
-- centre, from the left edge in, is what the generator draws with no light at
-- all (--light-bias 0), within one step of 255. And the two drawings differ
-- somewhere, or the flag changed nothing and the check proves nothing.
do
	local scenario = "glow-light: the lit half is untouched"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		withFiles(scenario, true, function(lit, unlit)
			for _, name in ipairs(LIT) do
				local a, b = readTGA(lit .. "/" .. name .. ".tga"), readTGA(unlit .. "/" .. name .. ".tga")
				if not (a and b) then
					fail(scenario, name .. ".tga was not drawn both lit and unlit")
				else
					local n = a.w
					local worst, where = 0, ""
					for i = 0, n / 2 - 1 do
						local dTop = math.abs(alphaAt(a, n / 2 - 1, i) - alphaAt(b, n / 2 - 1, i))
						if dTop > worst then worst, where = dTop, ("top axis row %d"):format(i) end
						local dLeft = math.abs(alphaAt(a, i, n / 2 - 1) - alphaAt(b, i, n / 2 - 1))
						if dLeft > worst then worst, where = dLeft, ("left axis column %d"):format(i) end
					end
					if worst > 1 / 255 + 1e-6 then
						fail(scenario, ("%s.tga: the light changed the %s by %.3f; the lit half must be the shape as drawn"):format(
							name, where, worst))
					end
					local differ = 0
					for y = n / 2, n - 1 do
						for x = n / 2, n - 1 do
							if alphaAt(a, x, y) ~= alphaAt(b, x, y) then differ = differ + 1 end
						end
					end
					if differ == 0 then
						fail(scenario, name .. ".tga is the same lit and unlit: --light-bias changed nothing")
					end
				end
			end
		end)
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ 3
-- Where the light is and how far it reaches did not move: the generator's
-- own --reach lines for the four files equal what was recorded before the
-- light was added within one texel, the reach read here agrees, and the ring
-- art the code declares (kit.RingArt) still sits in hunt37's window over the
-- files that ship.
do
	local scenario = "glow-light: the light's reach did not move"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		withFiles(scenario, false, function(lit, _, reachText)
			local said = {}
			for name, peak, reach in reachText:gmatch("(%w+)%.tga peak=([%d%.]+) reach=([%d%.]+)") do
				said[name] = { peak = tonumber(peak), reach = tonumber(reach) }
			end
			for _, name in ipairs(LIT) do
				local want, got = RECORDED[name], said[name]
				if not got then
					fail(scenario, "--reach said nothing of " .. name .. ".tga: " .. reachText:sub(1, 120))
				else
					if math.abs(got.peak - want.peak) > TEXEL then
						fail(scenario, ("%s.tga: the brightest line moved from %.3f to %.3f"):format(name, want.peak, got.peak))
					end
					if math.abs(got.reach - want.reach) > TEXEL then
						fail(scenario, ("%s.tga: the reach moved from %.3f to %.3f"):format(name, want.reach, got.reach))
					end
				end
				local tga = readTGA(lit .. "/" .. name .. ".tga")
				if tga and math.abs(reachOf(tga) - want.reach) > TEXEL then
					fail(scenario, ("%s.tga is seen out to %.3f, it was %.3f"):format(name, reachOf(tga), want.reach))
				end
			end
			-- The rings as they ship, against what the code says of them.
			local lib = ns.Prompt and ns.Prompt.lib
			for _, name in ipairs({ "Ring", "RingSq" }) do
				local art = lib and lib.RingArtOf and lib.RingArtOf(ART .. name)
				local tga = readTGA(dir .. "/Textures/" .. name .. ".tga")
				if not art then
					fail(scenario, "the code does not say how far out " .. name .. ".tga is seen")
				elseif not tga then
					fail(scenario, "Textures/" .. name .. ".tga is not in the package")
				else
					local reach = reachOf(tga)
					if art.edge < reach - 0.0005 or art.edge > reach + 0.06 then
						fail(scenario, ("Textures/%s.tga is seen out to %.3f, the code says %.3f"):format(name, reach, art.edge))
					end
				end
			end
		end)
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ 4
-- A rule ends soft: stretched along a panel's edge, its ends fade over six
-- texels to nothing, never a hard cut; and its core sits across the middle
-- rows with nothing at the top and bottom rows.
do
	local scenario = "glow-light: a rule ends soft"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		withFiles(scenario, false, function(lit)
			local tga = readTGA(lit .. "/Rule.tga")
			if not tga then fail(scenario, "Rule.tga cannot be read as a 32-bit TGA") return end
			if tga.w ~= 128 or tga.h ~= 8 then
				fail(scenario, ("Rule.tga is %dx%d, not 128x8"):format(tga.w, tga.h))
				return
			end
			local peak = columnMax(tga, tga.w / 2)
			if peak < 0.75 then fail(scenario, ("the rule's core is only %.2f"):format(peak)) end
			for _, side in ipairs({ { 0, 1 }, { tga.w - 1, -1 } }) do
				local x0, step = side[1], side[2]
				local last = -1
				for i = 0, 6 do
					local m = columnMax(tga, x0 + i * step)
					if i == 0 and m > 1 / 255 + 1e-6 then
						fail(scenario, ("the rule ends hard: column %d carries %.3f"):format(x0, m))
					end
					if m < last - 1e-6 then
						fail(scenario, ("the rule's end fade is not even at column %d"):format(x0 + i * step))
					end
					last = m
				end
				if last < 0.75 * peak then
					fail(scenario, ("the rule has not risen six texels in from column %d: %.2f of %.2f"):format(x0, last, peak))
				end
			end
			for y = 0, tga.h - 1 do
				local a = alphaAt(tga, tga.w / 2, y)
				if (y == 0 or y == tga.h - 1) and a > 1 / 255 + 1e-6 then
					fail(scenario, ("the rule reaches row %d of 8"):format(y))
				end
			end
			if alphaAt(tga, tga.w / 2, 3) < 0.75 or alphaAt(tga, tga.w / 2, 4) < 0.75 then
				fail(scenario, "the rule's core is not across rows 3 and 4")
			end
		end)
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ 5
-- The shock stands straight: its column maxima are symmetric about the
-- middle, so the wave crosses the panel upright. The crack keeps to its rows:
-- nothing in the top or bottom row at either end, where the line comes in
-- and goes out on the middle row, and a line there at all.
do
	local scenario = "glow-light: the shock stands straight and the crack keeps its rows"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		withFiles(scenario, false, function(lit)
			local shock = readTGA(lit .. "/Shock.tga")
			if not shock then
				fail(scenario, "Shock.tga cannot be read as a 32-bit TGA")
			else
				for x = 0, shock.w / 2 - 1 do
					local left, right = columnMax(shock, x), columnMax(shock, shock.w - 1 - x)
					if math.abs(left - right) > 0.02 then
						fail(scenario, ("the shock slants: column %d carries %.3f, its mirror %.3f"):format(x, left, right))
						break
					end
				end
				if columnMax(shock, shock.w / 2) < 0.95 then fail(scenario, "the shock has no core") end
			end
			local crack = readTGA(lit .. "/Crack.tga")
			if not crack then
				fail(scenario, "Crack.tga cannot be read as a 32-bit TGA")
			else
				local most = 0
				for x = 0, crack.w - 1 do most = math.max(most, columnMax(crack, x)) end
				if most < 0.9 then fail(scenario, ("the crack is faint: %.2f at most"):format(most)) end
				for _, x in ipairs({ 0, 1, 2, 3, 4, 5, crack.w - 6, crack.w - 5, crack.w - 4, crack.w - 3, crack.w - 2, crack.w - 1 }) do
					for _, y in ipairs({ 0, crack.h - 1 }) do
						if alphaAt(crack, x, y) > 1 / 255 + 1e-6 then
							fail(scenario, ("the crack reaches row %d at column %d"):format(y, x))
						end
					end
				end
			end
		end)
	end
	Mock.reset()
end
