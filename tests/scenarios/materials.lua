-- tools/materials.py, the lit-material pipeline every texture generator draws
-- with, held to its own promises on its self-test swatches: the same bytes
-- twice, every swatch under its material's luma cap, no stamped feature
-- under two units, every file a 32-bit power-of-two TGA, the light files
-- white; and tests/materials_check.lua, the reader the looks' own scenario
-- files hold their shipped art with, proven on a swatch with a known
-- brightness before anything else leans on it.
--
-- Only the swatches are read here. A look's shipped files are its own
-- scenario file's business (panel-material.lua,
-- look-forge.lua), each of which dofiles materials_check.lua and names its
-- own files, so nothing here is edited by two worktrees at once.

local dir, H = ...
local fail, load = H.fail, H.load

local MC = dofile(dir .. "/tests/materials_check.lua")

-- Each swatch's material cap, as tools/materials.py's MATERIALS table has
-- them: the line the generator prints must say the same, and the file must
-- keep under it.
local CAPS = {
	Swatch_Gold = 0.60, Swatch_Iron = 0.55, Swatch_Glass = 0.80,
	Swatch_Stone = 0.50, Swatch_Hide = 0.48, Swatch_Grey = 1.00,
}
local SWATCHES = { "Swatch_Gold", "Swatch_Iron", "Swatch_Glass", "Swatch_Stone", "Swatch_Hide", "Swatch_Grey" }

local python = os.getenv("MANNERS_PYTHON") or "python"

local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

-- A directory nobody else is using: the scenarios run in parallel, each in a
-- copy of the tree of its own, so the tree's own path tells them apart.
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-materials-" .. token .. "-" .. tostring(os.time())
end

-- The generator is run twice, once for the whole file; every scenario reads
-- the same two runs. `runs` is false when python would not run, "skipped"
-- when numpy or Pillow is missing (CI's test job installs lupa only), else
-- { a, b, outA, names, lines } with lines[name] the parsed figures of the
-- printed line: `Swatch_Gold.tga 128x128 cap=0.60 max=0.59 mean=0.31
-- minfeature=3.0` (a light file says `peak=` and `mean=`).
local runs

local function generate()
	if runs ~= nil then return runs end
	local a, b = tempDir() .. "-a", tempDir() .. "-b"
	-- os.execute and a log file rather than io.popen, which the Lua that lupa
	-- builds on Linux leaves out.
	local function run(out)
		local log = out .. ".log"
		os.execute(python .. ' "' .. dir .. '/tools/materials.py" --selftest --out "' .. out .. '" > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		return text
	end
	local outA, outB = run(a), run(b)
	if not (outA and outB) then runs = false return runs end
	if outA:find("No module named", 1, true) then runs = "skipped" return runs end
	local names, lines = {}, {}
	for line in outA:gmatch("[^\r\n]+") do
		local file, w, h, rest = line:match("([%w_]+%.tga) (%d+)x(%d+) (.*)$")
		if file then
			names[#names + 1] = file
			local figures = { width = tonumber(w), height = tonumber(h) }
			for key, value in rest:gmatch("(%w+)=([%d%.%-]+)") do
				figures[key] = tonumber(value) or value
			end
			lines[file] = figures
		end
	end
	runs = { a = a, b = b, outA = outA, names = names, lines = lines }
	return runs
end

local function withRuns(scenario, body)
	Mock.reset()
	local ns = load(scenario)
	if not ns then return end
	local r = generate()
	if r == false then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	if r ~= "skipped" then
		if #r.names == 0 then
			fail(scenario, "the generator wrote nothing: " .. r.outA:sub(1, 200))
		else
			local ok, err = pcall(body, r, scenario)
			if not ok then fail(scenario, "threw: " .. tostring(err)) end
		end
	end
	Mock.reset()
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 0.005)
end

-- ------------------------------------------------------------------ 1
-- Every file is a 32-bit uncompressed TGA, a power of two up to 256; the
-- light files are white with the light in their alpha, and the grey swatch
-- is grey on every texel (it is vertex-tinted art).
withRuns("materials: every swatch is a 32-bit power-of-two TGA and the light is white", function(r, scenario)
	local seen = {}
	for _, file in ipairs(r.names) do
		seen[file] = true
		local path = r.a .. "/" .. file
		local tga = MC.readTGA(path)
		if not tga then
			fail(scenario, file .. " is not a 32-bit uncompressed TGA")
		elseif not MC.pow2(path) then
			fail(scenario, ("%s is %dx%d, not a power of two up to 256"):format(file, tga.w, tga.h))
		end
		local figures = r.lines[file]
		if file:find("_Light%.tga$") then
			if not figures.peak or figures.peak > 1.0 then
				fail(scenario, file .. " prints a peak alpha of " .. tostring(figures.peak))
			end
			if not MC.isGrey(path) then fail(scenario, file .. " is a light file and is not white") end
		end
	end
	for _, name in ipairs(SWATCHES) do
		if not seen[name .. ".tga"] then fail(scenario, name .. ".tga was not drawn") end
		if not seen[name .. "_Light.tga"] then fail(scenario, name .. "_Light.tga was not drawn") end
	end
	if not MC.isGrey(r.a .. "/Swatch_Grey.tga") then
		fail(scenario, "Swatch_Grey.tga carries colour: the grey ramp is for vertex-tinted art")
	end
end)

-- ------------------------------------------------------------------ 2
-- Deterministic: the only randomness is a seeded generator, no clock, no set
-- order, so two runs are byte for byte the same.
withRuns("materials: the pipeline draws the same bytes twice", function(r, scenario)
	for _, file in ipairs(r.names) do
		local one, two = slurp(r.a .. "/" .. file), slurp(r.b .. "/" .. file)
		if not one or not two then
			fail(scenario, file .. " was not written by both runs")
		elseif one ~= two then
			fail(scenario, file .. " differs between two runs with the same parameters")
		end
	end
end)

-- ------------------------------------------------------------------ 3
-- Every swatch keeps under its material's luma cap: the generator prints the
-- cap the table holds and a max under it, and the reader agrees with the
-- printed max within a hundredth.
withRuns("materials: every swatch is under its cap", function(r, scenario)
	for _, name in ipairs(SWATCHES) do
		local cap = CAPS[name]
		local figures = r.lines[name .. ".tga"]
		if not figures then
			fail(scenario, name .. ".tga was not drawn")
		else
			if not near(figures.cap, cap) then
				fail(scenario, ("%s prints cap=%s; the material's cap is %.2f"):format(name, tostring(figures.cap), cap))
			end
			if not figures.max or figures.max > cap + 0.005 then
				fail(scenario, ("%s prints max=%s over its cap %.2f"):format(name, tostring(figures.max), cap))
			end
			local ok, maxLuma = MC.capOK(r.a .. "/" .. name .. ".tga", cap)
			if not ok then
				fail(scenario, ("%s has an opaque texel at luma %.3f, over its cap %.2f"):format(name, maxLuma or -1, cap))
			end
			if not near(maxLuma, figures.max, 0.01) then
				fail(scenario, ("%s: the reader finds max luma %.3f, the generator printed %s"):format(name, maxLuma or -1, tostring(figures.max)))
			end
		end
	end
end)

-- ------------------------------------------------------------------ 4
-- No stamped feature under two units on screen: every swatch declares its
-- smallest feature and none is under MIN_FEATURE_UNITS.
withRuns("materials: no feature under two units", function(r, scenario)
	for _, file in ipairs(r.names) do
		local mf = r.lines[file].minfeature
		if type(mf) ~= "number" then
			fail(scenario, file .. " declares no feature size (minfeature=" .. tostring(mf) .. ")")
		elseif mf < 2.0 then
			fail(scenario, ("%s has a feature of %.1f units, under the two-unit floor"):format(file, mf))
		end
	end
end)

-- ------------------------------------------------------------------ 5
-- The reader itself, before the looks lean on it: a swatch with a known max
-- fails a cap just under it and passes one just over; a pale swatch is not a
-- ground for text and a dark one is; gold is not grey; a missing file is
-- nothing.
withRuns("materials: the check helper reads a cap", function(r, scenario)
	local glass = r.lines["Swatch_Glass.tga"]
	local path = r.a .. "/Swatch_Glass.tga"
	if not glass or type(glass.max) ~= "number" then fail(scenario, "Swatch_Glass.tga printed no max") return end
	local ok, maxLuma = MC.capOK(path, glass.max - 0.02)
	if ok then
		fail(scenario, ("capOK passed Swatch_Glass at a cap of %.2f with its max printed as %.2f (read %s)")
			:format(glass.max - 0.02, glass.max, tostring(maxLuma)))
	end
	if not near(maxLuma, glass.max, 0.01) then
		fail(scenario, ("capOK read max luma %s; the generator printed %.2f"):format(tostring(maxLuma), glass.max))
	end
	if not MC.capOK(path, glass.max + 0.01) then
		fail(scenario, "capOK failed Swatch_Glass at a cap just over its max")
	end
	local under, mean = MC.underText(path)
	if under then
		fail(scenario, ("underText passed the glass pane, mean luma %s"):format(tostring(mean)))
	end
	local hide = r.lines["Swatch_Hide.tga"]
	under, mean = MC.underText(r.a .. "/Swatch_Hide.tga")
	if not under then
		fail(scenario, ("underText failed the hide, mean luma %s (printed %s)"):format(tostring(mean), tostring(hide and hide.mean)))
	end
	if MC.isGrey(r.a .. "/Swatch_Gold.tga") then fail(scenario, "isGrey called the gold swatch grey") end
	if MC.readTGA(r.a .. "/Nothing.tga") then fail(scenario, "readTGA read a file that is not there") end
	if MC.pow2(r.a .. "/Nothing.tga") then fail(scenario, "pow2 passed a file that is not there") end
end)

-- ------------------------------------------------------------------ 6
-- The hammer marks wrap round the tile both ways, their tilt with them: the
-- height steps no more from the tile's last column to its first (or last row
-- to first) than between two neighbours inside. A tilt read from the cell's
-- unwrapped centre puts a cliff there, which a REPEAT-tiled plate shows at
-- every seam and a frame's rail along its file edge.
do
	local scenario = "materials: the hammer marks wrap round the tile"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		local log = tempDir() .. "-seams.log"
		os.execute(python .. ' "' .. dir .. '/tools/materials.py" --seams > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		if not text then
			fail(scenario, "SKIPPED -- cannot run " .. python)
		elseif not text:find("No module named", 1, true) then
			local probes = 0
			for line in text:gmatch("[^\r\n]+") do
				local size, rest = line:match("seam (%d+x%d+) (.*)$")
				if size then
					probes = probes + 1
					local f = {}
					for key, value in rest:gmatch("(%w+)=([%d%.%-]+)") do f[key] = tonumber(value) end
					for _, axis in ipairs({ "x", "y" }) do
						local wrap, inner = f["wrap" .. axis], f["inner" .. axis]
						if type(wrap) ~= "number" or type(inner) ~= "number" then
							fail(scenario, size .. ": no figures for " .. axis .. ": " .. line)
						elseif wrap > 1.25 * inner then
							fail(scenario, ("%s, cell %s: the height steps %.4f across the tile's edge (%s), at most %.4f inside: a cliff at the seam")
								:format(size, tostring(f.cell), wrap, axis == "x" and "last column to first" or "last row to first", inner))
						end
					end
				end
			end
			if probes < 3 then fail(scenario, "the generator measured " .. probes .. " probe tiles, not 3: " .. text:sub(1, 200)) end
		end
	end
	Mock.reset()
end

-- The swatches are only evidence: remove them once every scenario has read
-- them (a narrowed run that generated nothing has nothing to remove).
if type(runs) == "table" then
	for _, file in ipairs(runs.names) do
		os.remove(runs.a .. "/" .. file)
		os.remove(runs.b .. "/" .. file)
	end
	os.remove(runs.a)
	os.remove(runs.b)
end
