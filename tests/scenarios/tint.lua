-- Dark looks use the client's class colour as it is. Only a look on a light
-- ground changes it, to keep the name readable.
--
-- Every scenario name starts with "tint: " so the mutations in
-- tests/mutations/tint.py can name the one that has to catch them.

local dir, H = ...
local fail, load, freshPrompt = H.fail, H.load, H.freshPrompt

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
	ns.Prompt.lib.SetLine(ns.Prompt:Regions().name, text)
	text = ns.Prompt:Regions().name:GetText()
	return text:match("|cff(%x%x%x%x%x%x)"), text
end

do
	local scenario = "tint: dark looks keep Blizzard class colours"
	run(scenario, function(ns)
		for _, look in ipairs({ "glass", "wild", "forge", "leather", "toast", "luxe" }) do
			for class, wanted in pairs(COLOURS) do
				local code, text = codeOn(ns, look, class)
				if code ~= wanted:sub(3) then
					fail(scenario, ("%s on %s is %s, not Blizzard %s: %s"):format(
						class, look, tostring(code), wanted:sub(3), tostring(text)))
				end
			end
		end
	end)
end

do
	local scenario = "tint: a light ground keeps class-colour contrast"
	run(scenario, function(ns)
		local mage, text = codeOn(ns, "letter", "MAGE")
		if not mage then fail(scenario, "no class colour on letter: " .. tostring(text)) return end
		if mage == COLOURS.MAGE:sub(3) then
			fail(scenario, "Letter left a pale class colour unreadable on parchment: " .. tostring(text))
		end
	end)
end
