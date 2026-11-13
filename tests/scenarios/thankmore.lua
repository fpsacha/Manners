-- Several emotes for the /thank (1.11.20). A player on CurseForge asked to
-- pick more than one: *Emote to use* stays the main one, and *Or one of these,
-- at random* ticks others; each thank-you draws one of them all
-- (Favours.lua, ns.ThankEmoteToken; Core.lua, prompt.thankEmoteMore).
--
-- Every scenario name starts with "thankmore:" so the mutations in
-- tests/mutations/thankmore.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

-- math.random answering `pick` for a draw from 1..n, and what it was asked.
local function withRandom(pick, fn)
	local real = math.random
	local asked = {}
	math.random = function(n)
		asked[#asked + 1] = n
		return math.min(pick, n or 1)
	end
	local ok, err = pcall(fn, asked)
	math.random = real
	if not ok then error(err, 0) end
end

do
	local scenario = "thankmore: with nothing ticked the emote picked is the only one"
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		local prompt = ns.db.profile.prompt
		if type(prompt.thankEmoteMore) ~= "table" or next(prompt.thankEmoteMore) ~= nil then
			fail(scenario, "a new profile's others to pick from are not an empty table")
		end
		prompt.thankEmoteToken = "CHEER"
		withRandom(1, function(asked)
			for _ = 1, 5 do
				local token = ns.ThankEmoteToken(prompt)
				if token ~= "CHEER" then fail(scenario, "nothing ticked made " .. tostring(token)) return end
			end
			if #asked > 0 then fail(scenario, "a draw was made with nothing ticked") end
		end)
	end)
	if not ok then fail(scenario, err) end
end

do
	local scenario = "thankmore: a thank-you draws from the one picked and the ones ticked"
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		local prompt = ns.db.profile.prompt
		prompt.thankEmoteToken = "CHEER"
		-- BOW comes before WAVE in ns.THANK_EMOTES whatever order they were ticked in.
		prompt.thankEmoteMore = { WAVE = true, BOW = true, CHEER = true }
		local order = {}
		for _, token in ipairs(ns.THANK_EMOTES) do
			if token == "BOW" or token == "WAVE" then order[#order + 1] = token end
		end
		local want = { "CHEER", order[1], order[2] }
		for pick = 1, 3 do
			withRandom(pick, function(asked)
				local token = ns.ThankEmoteToken(prompt)
				if asked[1] ~= 3 then
					fail(scenario, "the draw was from " .. tostring(asked[1]) .. " emotes, not 3 (the main one counted once)")
				end
				if token ~= want[pick] then
					fail(scenario, "draw " .. pick .. " made " .. tostring(token) .. ", not " .. tostring(want[pick]))
				end
			end)
		end
		-- A token the list does not hold, before the repair has run, is never made.
		prompt.thankEmoteMore = { DANCE = true }
		withRandom(2, function()
			local token = ns.ThankEmoteToken(prompt)
			if token ~= "CHEER" then fail(scenario, "an emote the list lacks was drawn: " .. tostring(token)) end
		end)
	end)
	if not ok then fail(scenario, err) end
end

do
	local scenario = "thankmore: the repair keeps only known emotes ticked true"
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		local prompt = ns.db.profile.prompt
		prompt.thankEmoteMore = { BOW = true, DANCE = true, WAVE = "yes", [3] = true, HUG = false }
		ns.ClampSettings()
		local more = prompt.thankEmoteMore
		if more.BOW ~= true then fail(scenario, "a known emote ticked was dropped") end
		for _, key in ipairs({ "DANCE", "WAVE", 3, "HUG" }) do
			if more[key] ~= nil then fail(scenario, tostring(key) .. " was kept as " .. tostring(more[key])) end
		end
		prompt.thankEmoteMore = "BOW"
		ns.ClampSettings()
		if type(prompt.thankEmoteMore) ~= "table" or next(prompt.thankEmoteMore) ~= nil then
			fail(scenario, "a string in place of the table was not made an empty table")
		end
	end)
	if not ok then fail(scenario, err) end
end

do
	local scenario = "thankmore: What I say ticks the others under Emote to use"
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		local prompt = ns.db.profile.prompt
		local control = H.findOption(ns.optionsTable, "thankEmoteMore")
		if not control then fail(scenario, "What I say has no others to pick from") return end
		if control.type ~= "multiselect" then fail(scenario, "the control is a " .. tostring(control.type)) end
		local main = H.findOption(ns.optionsTable, "thankEmoteToken")
		if main and not (control.order > main.order) then fail(scenario, "the others come before Emote to use") end
		prompt.thankEmoteToken = "THANK"
		local values = control.values()
		if values.THANK ~= nil then fail(scenario, "the emote picked is offered again among the others") end
		if values.BOW ~= "/bow" or values.CHEER ~= "/cheer" then
			fail(scenario, "the others read /bow as " .. tostring(values.BOW) .. " and /cheer as " .. tostring(values.CHEER))
		end
		control.set({ "thankEmoteMore" }, "BOW", true)
		if prompt.thankEmoteMore.BOW ~= true or not control.get({ "thankEmoteMore" }, "BOW") then
			fail(scenario, "ticking /bow wrote " .. tostring(prompt.thankEmoteMore.BOW))
		end
		control.set({ "thankEmoteMore" }, "BOW", false)
		if prompt.thankEmoteMore.BOW ~= nil then
			fail(scenario, "unticking /bow left " .. tostring(prompt.thankEmoteMore.BOW))
		end
		prompt.thankEmote = false
		if not (type(control.disabled) == "function" and control.disabled()) then
			fail(scenario, "the others stay live with the /thank switch off")
		end
	end)
	if not ok then fail(scenario, err) end
end

do
	local scenario = "thankmore: the ticks travel with a profile"
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		ns.db.profile.prompt.thankEmoteMore = { BOW = true, WAVE = true }
		local text = ns.ExportSettings and ns.ExportSettings() or nil
		if not (text and text:find("prompt.thankEmoteMore=BOW,WAVE", 1, true)) then
			fail(scenario, "the export does not carry the ticks: " .. tostring(text))
		end
	end)
	if not ok then fail(scenario, err) end
end
