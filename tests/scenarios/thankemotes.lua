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
		if order[1] ~= "THANK" or #order ~= 25 then
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

-- /moo (1.11.39, issue 34): any race may use it, so it is on the one list, last.
do
	local scenario = "thankemotes: /moo is offered last and kept, and a thank-you makes it"
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		local prompt = ns.db.profile.prompt
		local control = H.findOption(ns.optionsTable, "thankEmoteToken")
		if not control then fail(scenario, "What I say has no emote choice") return end
		if control.values().MOO ~= "/moo" then
			fail(scenario, "MOO reads " .. tostring(control.values().MOO))
		end
		local order = control.sorting()
		if order[25] ~= "MOO" or order[24] ~= "WELCOME" then
			fail(scenario, ("the list ends %s, %s"):format(tostring(order[24]), tostring(order[25])))
		end
		local more = H.findOption(ns.optionsTable, "thankEmoteMore")
		if not more then fail(scenario, "What I say has no others to pick from") return end
		prompt.thankEmoteToken = "THANK"
		if more.values().MOO ~= "/moo" then
			fail(scenario, "the others do not offer /moo")
		end
		prompt.thankEmoteToken = "MOO"
		prompt.thankEmoteMore = { MOO = true }
		ns.ClampSettings()
		if prompt.thankEmoteToken ~= "MOO" then
			fail(scenario, "a /moo picked was repaired to " .. tostring(prompt.thankEmoteToken))
		end
		if ns.ThankEmoteToken(prompt) ~= "MOO" then
			fail(scenario, "the emote drawn was " .. tostring(ns.ThankEmoteToken(prompt)))
		end
		if prompt.thankEmoteMore.MOO ~= true then
			fail(scenario, "a /moo ticked among the others was dropped")
		end
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
