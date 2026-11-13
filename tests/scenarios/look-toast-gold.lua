-- Toast re-gilded (tools/make_toast_textures.py drawing through
-- tools/materials.py): the rails planished, the studs rosettes, the gem set
-- in claws, and the gold ring hugging the icon a twist of rope from a file of
-- its own, Toast_Rope. What the regild promised, held to numbers:
--
--   * every piece of baked gold stays under luma 0.60 (GOLD_CAP), read back
--     through tests/materials_check.lua: 1.5.1's gold ran up to near white
--     and glared in the game;
--   * the enamel keeps its colour: it is still grey (vertex-tinted art) and
--     the mean luma of the band's middle half is what it was before the
--     regild, within 0.02, so the reason colour readable-toast.lua judges
--     on it has not moved; the girdle and the specular were allowed, the
--     base and the light were not;
--   * the ring is twisted: round the outer band Toast_Rope's luminance
--     varies at least four times as much as Toast_Gold's at the same radius
--     (a rope, not a smooth disc);
--   * the look's ring draws Toast_Rope and the medallion's rim keeps
--     Toast_Gold (drawn twice at different radii, one baked rope would show
--     sliced on the rim), and ROPE_BAND in Looks/Toast.lua is the
--     generator's.
--
-- The scenarios that read files draw them afresh with the generator into a
-- folder of their own (once per run of this file, as materials.lua does), so
-- a generator that lets the cap go or stops twisting is caught here and not
-- only by the shipped bytes (hunt35-effects.lua compares those). Without
-- numpy and Pillow (CI's test job) they return quietly, as hunt35's do.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree
local MC = dofile(dir .. "/tests/materials_check.lua")

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local python = os.getenv("MANNERS_PYTHON") or "python"
local GENERATOR = "tools/make_toast_textures.py"
local SHIPPED = "Textures/Toast"

-- GOLD_CAP in the generator: the brightest any gold texel may be.
local GOLD_CAP = 0.60
-- The baked gold the regild touched.
local GOLD = { "Toast_Border", "Toast_BorderSlim", "Toast_Gold", "Toast_Rope", "Toast_GemSet" }
-- DISC_FILL in the generator and in Looks/Toast.lua: where a disc's edge
-- sits, as a fraction of the file's half-size.
local DISC_FILL = 0.98
-- The enamel before the regild: the mean Rec.601 luma of the opaque texels
-- between 0.8875 and 0.9625 of the disc's radius (the middle half of the
-- band the ring exposes, which spans about 0.85 to 1.0), read from the
-- Toast_Enamel.tga that shipped in 1.10.4, and how far it may move.
local ENAMEL_RECORDED, ENAMEL_SLACK = 0.840, 0.02
local BAND_IN, BAND_OUT = 0.8875, 0.9625
-- How much more the rope's luminance varies round the band than the plain
-- gold's, at this fraction of the disc's radius, over this many angles.
local TWIST, TWIST_AT, TWIST_ANGLES = 4, 0.95, 48

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
	return (base:gsub("\\", "/")) .. "/manners-toast-gold-" .. token .. "-" .. tostring(os.time())
end

-- The generator, run once for the whole file into a folder of its own.
-- `gen` is false when python would not run, "skipped" when numpy or Pillow
-- is missing, else { out, names, log }.
local gen

local function generate()
	if gen ~= nil then return gen end
	local out = tempDir()
	local log = out .. ".log"
	-- os.execute and a log file rather than io.popen, which the Lua that lupa
	-- builds on Linux leaves out.
	os.execute(python .. ' "' .. dir .. "/" .. GENERATOR .. '" --out "' .. out .. '" > "' .. log .. '" 2>&1')
	local text = slurp(log)
	os.remove(log)
	if not text then gen = false return gen end
	if text:find("No module named", 1, true) then gen = "skipped" return gen end
	local names = {}
	for file in text:gmatch("([%w_]+%.tga)") do names[#names + 1] = file end
	gen = { out = out, names = names, log = text }
	return gen
end

local function withFiles(scenario, body)
	Mock.reset()
	local ns = load(scenario)
	if not ns then return end
	local g = generate()
	if g == false then fail(scenario, "SKIPPED -- cannot run " .. python) return end
	if g ~= "skipped" then
		if #g.names == 0 then
			fail(scenario, "the generator wrote nothing: " .. g.log:sub(1, 200))
		else
			local ok, err = pcall(body, g, scenario)
			if not ok then fail(scenario, "threw: " .. tostring(err)) end
		end
	end
	Mock.reset()
end

-- The texel (x, y) of a 32-bit TGA as r, g, b, a bytes. The rows run
-- bottom-up unless the descriptor says top-down; the readings here are
-- taken on rings round the centre, which a vertical flip leaves the same.
local function texel(tga, x, y)
	local at = tga.offset + (y * tga.w + x) * 4
	local b, g, r, a = tga.data:byte(at + 1, at + 4)
	return r, g, b, a
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= eps
end

-- ------------------------------------------------------------------ 1
-- Every piece of baked gold the regild touched stays under GOLD_CAP, the
-- files the generator draws and the files that ship alike.
withFiles("look-toast-gold: gold stays under luma 0.60", function(g, scenario)
	for _, name in ipairs(GOLD) do
		for _, where in ipairs({ { g.out, "drawn" }, { dir .. "/" .. SHIPPED, "shipped" } }) do
			local path = where[1] .. "/" .. name .. ".tga"
			local ok, most = MC.capOK(path, GOLD_CAP)
			if most == nil then
				fail(scenario, ("%s (%s) could not be read as a 32-bit TGA"):format(name, where[2]))
			elseif not ok then
				fail(scenario, ("%s (%s) is gold as bright as %.3f, over the cap of %.2f"):format(name, where[2], most, GOLD_CAP))
			end
		end
	end
end)

-- ------------------------------------------------------------------ 2
-- The enamel keeps its colour: grey, and the band's middle half as bright
-- as it was before the regild.
withFiles("look-toast-gold: the enamel keeps its colour", function(g, scenario)
	local path = g.out .. "/Toast_Enamel.tga"
	if not MC.isGrey(path) then
		fail(scenario, "Toast_Enamel is not grey on every texel: it is vertex-tinted art")
	end
	local tga = MC.readTGA(path)
	if not tga then fail(scenario, "Toast_Enamel could not be read as a 32-bit TGA") return end
	local half = tga.w / 2
	local sum, n = 0, 0
	for y = 0, tga.h - 1 do
		for x = 0, tga.w - 1 do
			local rho = math.sqrt((x + 0.5 - half) ^ 2 + (y + 0.5 - half) ^ 2) / (DISC_FILL * half)
			if rho >= BAND_IN and rho <= BAND_OUT then
				local r, gg, b, a = texel(tga, x, y)
				if a > MC.OPAQUE * 255 then
					sum = sum + MC.luma(r, gg, b)
					n = n + 1
				end
			end
		end
	end
	if n == 0 then fail(scenario, "no opaque texel in the enamel's band") return end
	local mean = sum / n
	if not near(mean, ENAMEL_RECORDED, ENAMEL_SLACK) then
		fail(scenario, ("the enamel's band is %.3f at its middle half, not the %.3f it was (within %.2f)")
			:format(mean, ENAMEL_RECORDED, ENAMEL_SLACK))
	end
end)

-- ------------------------------------------------------------------ 3
-- The ring is twisted: round the outer band the rope's luminance varies far
-- more than the plain gold's at the same radius.
local function twist(tga)
	local half = tga.w / 2
	local r = TWIST_AT * DISC_FILL * half
	local vals, sum = {}, 0
	for i = 0, TWIST_ANGLES - 1 do
		local ang = i * 2 * math.pi / TWIST_ANGLES
		local x = math.floor(half + r * math.cos(ang))
		local y = math.floor(half + r * math.sin(ang))
		local rr, gg, bb, a = texel(tga, x, y)
		local v = MC.luma(rr, gg, bb) * a / 255
		vals[#vals + 1] = v
		sum = sum + v
	end
	local mean = sum / #vals
	local var = 0
	for _, v in ipairs(vals) do var = var + (v - mean) ^ 2 end
	return var / #vals
end

withFiles("look-toast-gold: the ring is twisted", function(g, scenario)
	local rope, gold = MC.readTGA(g.out .. "/Toast_Rope.tga"), MC.readTGA(g.out .. "/Toast_Gold.tga")
	if not rope then fail(scenario, "Toast_Rope was not drawn as a 32-bit TGA") return end
	if not gold then fail(scenario, "Toast_Gold was not drawn as a 32-bit TGA") return end
	if rope.w ~= gold.w or rope.h ~= gold.h then
		fail(scenario, ("Toast_Rope is %dx%d and Toast_Gold %dx%d: the ring and the rim are sized from one disc"):format(
			rope.w, rope.h, gold.w, gold.h))
		return
	end
	local vr, vg = twist(rope), twist(gold)
	if vr < TWIST * vg then
		fail(scenario, ("round the outer band the rope varies %.5f against the plain gold's %.5f, under %d times: no twist")
			:format(vr, vg, TWIST))
	end
end)

-- ------------------------------------------------------------------ 4
-- The look's ring wears the rope, the rim keeps the plain gold, the file
-- ships, and the Lua and the generator agree on ROPE_BAND.
do
	local scenario = "look-toast-gold: the ring wears the rope and the figures agree"
	Mock.reset()
	FT.install()
	local restore = strangers(ANNA)
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			freshPrompt(ns, scenario)
			local p = ns.db.profile.prompt
			p.style = "toast"
			ns.Prompt:ApplyStyle()
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			FT.settle()
			local look = ns.Prompt:Regions().look
			if not (look and look.ring and look.rim) then
				fail(scenario, "SKIPPED -- Toast is not the look in use")
				return
			end
			local ringFile, rimFile = tostring(look.ring._file), tostring(look.rim._file)
			if not ringFile:find("Toast_Rope$") then
				fail(scenario, "the ring hugging the icon draws " .. ringFile .. ", not Toast_Rope")
			end
			if not rimFile:find("Toast_Gold$") then
				fail(scenario, "the medallion's rim draws " .. rimFile .. ", not Toast_Gold")
			end
			if not slurp(dir .. "/" .. SHIPPED .. "/Toast_Rope.tga") then
				fail(scenario, "Toast_Rope.tga is not in the package")
			end
			if look.ring._shown == false then fail(scenario, "the ring is not shown with the icon up") end
			local lua = slurp(dir .. "/Looks/Toast.lua") or ""
			local py = slurp(dir .. "/" .. GENERATOR) or ""
			local luaBand = tonumber(lua:match("\nlocal ROPE_BAND = ([%d%.]+)"))
			local pyBand = tonumber(py:match("\nROPE_BAND = ([%d%.]+)"))
			if not luaBand then
				fail(scenario, "Looks/Toast.lua does not name ROPE_BAND")
			elseif not pyBand then
				fail(scenario, GENERATOR .. " does not name ROPE_BAND")
			elseif luaBand ~= pyBand then
				fail(scenario, ("ROPE_BAND is %s in Looks/Toast.lua and %s in the generator"):format(luaBand, pyBand))
			end
			-- The generator's docstring lists the file, so a reader of the tool
			-- knows it ships.
			if not py:find("Toast_Rope           128x128", 1, true) then
				fail(scenario, "the generator's docstring does not list Toast_Rope")
			end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	restore()
	FT.uninstall()
	Mock.reset()
end
