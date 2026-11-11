-- More emotes for the /thank (1.11.15). A player on CurseForge asked for more
-- than the eight of 1.11.3: Emote to use offers every friendly emote all five
-- clients have (Core.lua, ns.THANK_EMOTES), and a profile keeps any of them.
--
-- Every scenario name starts with "thankemotes:" so the mutations in
-- tests/mutations/thankemotes.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local ADDED = { "APPLAUD", "BLUSH", "CURTSEY", "FLEX", "GREET", "GRIN", "HAIL", "HAPPY", "HIGHFIVE", "HUG",
	"KISS", "KNEEL", "LOVE", "PRAISE", "PROUD", "WELCOME" }

do
	local scenario = "thankemotes: Emote to use offers the longer list, and a profile keeps a choice from it"
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		local control = H.findOption(ns.optionsTable, "thankEmoteToken")
		if not control then fail(scenario, "What I say has no emote choice") return end
		local values = control.values()
		for _, token in ipairs(ADDED) do
			if values[token] ~= "/" .. token:lower() then
				fail(scenario, token .. " reads " .. tostring(values[token]))
			end
		end
		local order = control.sorting()
		if order[1] ~= "THANK" or #order ~= 24 then
			fail(scenario, ("the list starts with %s and holds %d"):format(tostring(order[1]), #order))
		end
		ns.db.profile.prompt.thankEmoteToken = "HIGHFIVE"
		ns.ClampSettings()
		if ns.db.profile.prompt.thankEmoteToken ~= "HIGHFIVE" then
			fail(scenario, "a /highfive picked was repaired to " .. tostring(ns.db.profile.prompt.thankEmoteToken))
		end
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
