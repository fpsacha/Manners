-- A druid's name on the softer looks: orange and a warrior's tan share a hue
-- and a lightness, and taking both towards white (a look's classSoften) left
-- a peach against a cream. A druid is softened no further than the 0.35 looks
-- soften it, except on Luxe, whose names are a tint on white for everybody.
--
-- Every scenario name starts with "tint: " so the mutations in
-- tests/mutations/tint.py can name the one that has to catch them.

local dir, H = ...
local fail, load, freshPrompt = H.fail, H.load, H.freshPrompt

-- CIE76 between two "rrggbb" codes: sRGB linearised, D65 XYZ, Lab.
local function lab(code)
	local function lin(i)
		local v = tonumber(code:sub(i, i + 1), 16) / 255
		if v <= 0.04045 then return v / 12.92 end
		return ((v + 0.055) / 1.055) ^ 2.4
	end
	local r, g, b = lin(1), lin(3), lin(5)
	local x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
	local y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
	local z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883
	local function f(t)
		if t > 216 / 24389 then return t ^ (1 / 3) end
		return (24389 / 27 * t + 16) / 116
	end
	local fx, fy, fz = f(x), f(y), f(z)
	return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)
end

local function distance(a, b)
	local l1, a1, b1 = lab(a)
	local l2, a2, b2 = lab(b)
	return math.sqrt((l1 - l2) ^ 2 + (a1 - a2) ^ 2 + (b1 - b2) ^ 2)
end

-- Hue in degrees and chroma of a code, in Lab.
local function hueChroma(code)
	local _, a, b = lab(code)
	local h = math.deg(math.atan2(b, a))
	if h < 0 then h = h + 360 end
	return h, math.sqrt(a * a + b * b)
end

local COLOURS = { DRUID = "ffff7c0a", WARRIOR = "ffc69b6d", MAGE = "ff40c7eb" }

local function run(scenario, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	local saved = RAID_CLASS_COLORS
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local colours = {}
		for class, str in pairs(COLOURS) do colours[class] = { colorStr = str } end
		RAID_CLASS_COLORS = colours
		freshPrompt(ns, scenario)
		body(ns)
	end)
	RAID_CLASS_COLORS = saved
	if not ok then fail(scenario, "errored: " .. tostring(err)) end
end

local function codeOn(ns, style, class)
	ns.db.profile.prompt.style = style
	ns.Prompt:ApplyStyle()
	local text = ns.Prompt:RenderPrimary({ name = "Elm Oak", short = "Elm", class = class, reason = "nearby" }, 0)
	return text:match("|cff(%x%x%x%x%x%x)"), text
end

do
	local scenario = "tint: a druid's name stays orange on a softened look"
	run(scenario, function(ns)
		for _, look in ipairs({ "wild", "forge", "leather" }) do
			local druid, text = codeOn(ns, look, "DRUID")
			if druid ~= "ffaa60" then
				fail(scenario, ("a druid on %s is %s, not ffaa60: %s"):format(look, tostring(druid), tostring(text)))
			end
			local warrior = codeOn(ns, look, "WARRIOR")
			if not (druid and warrior) then
				fail(scenario, "no class colour on " .. look)
			elseif distance(druid, warrior) <= 35 then
				fail(scenario, ("a druid (%s) and a warrior (%s) are only %.1f apart on %s"):format(
					druid, warrior, distance(druid, warrior), look))
			end
		end
	end)
end

do
	local scenario = "tint: a warrior and a mage keep the look's own softening"
	run(scenario, function(ns)
		local warrior = codeOn(ns, "wild", "WARRIOR")
		local mage = codeOn(ns, "wild", "MAGE")
		if warrior ~= "e3cdb6" then fail(scenario, "a warrior on wild is " .. tostring(warrior) .. ", not e3cdb6") end
		if mage ~= "a0e3f5" then fail(scenario, "a mage on wild is " .. tostring(mage) .. ", not a0e3f5") end
		-- Druid and mage in turn, the cache shared between them.
		for round = 1, 2 do
			local druid = codeOn(ns, "wild", "DRUID")
			local again = codeOn(ns, "wild", "MAGE")
			if druid ~= "ffaa60" then fail(scenario, ("round %d: a druid is %s"):format(round, tostring(druid))) end
			if again ~= "a0e3f5" then
				fail(scenario, ("round %d: a mage after a druid is %s, not a0e3f5"):format(round, tostring(again)))
			end
		end
	end)
end

do
	local scenario = "tint: Luxe keeps a druid's name a tint on white"
	run(scenario, function(ns)
		local druid, text = codeOn(ns, "luxe", "DRUID")
		if not druid then fail(scenario, "no class colour on luxe: " .. tostring(text)) return end
		for i = 1, 5, 2 do
			if tonumber(druid:sub(i, i + 1), 16) < 0.8 * 255 then
				fail(scenario, "a druid's name on Luxe is more than a tint on white: " .. druid)
				break
			end
		end
	end)
end

do
	local scenario = "tint: the default look keeps the full druid orange"
	run(scenario, function(ns)
		local druid, text = codeOn(ns, "glass", "DRUID")
		if not druid then fail(scenario, "no class colour on glass: " .. tostring(text)) return end
		if druid == "ffaa60" then fail(scenario, "the default look softened a druid: " .. druid) end
		local hue, chroma = hueChroma(druid)
		local ownHue = hueChroma("ff7c0a")
		if math.abs(hue - ownHue) > 5 then fail(scenario, ("a druid on glass lost its hue: %s (%.0f degrees)"):format(druid, hue)) end
		if chroma <= 70 then fail(scenario, ("a druid on glass lost its strength: %s (chroma %.0f)"):format(druid, chroma)) end
	end)
end
