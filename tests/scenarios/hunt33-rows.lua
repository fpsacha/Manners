-- Bug hunt 33, the clickable names (Prompt/Rows.lua, Prompt/Press.lua row
-- handlers, Prompt/Macro.lua ArmRow). Every scenario is red on 1.8.5 and says
-- what it found; modelled on hunt25-rows.lua, whose click driver it repeats.
--
-- Every scenario name starts with "hunt33-rows:".

local dir, H = ...
local fail, load = H.fail, H.load

local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" },
	nameplate3 = { "Cara", "Close" }, nameplate4 = { "Dane", "Dusk" } }

-- ------------------------------------------------------------------ the client's side

local function lookup(frame, prefix, name, suffix)
	local a = frame.attributes
	for _, key in ipairs({ prefix .. name .. suffix, "*" .. name .. suffix,
		prefix .. name .. "*", "*" .. name .. "*", name }) do
		if a[key] ~= nil then return a[key] end
	end
	return nil
end

local function suffix(button)
	if button == "LeftButton" then return "1" end
	if button == "RightButton" then return "2" end
	if button == "MiddleButton" then return "3" end
	return "-" .. button
end

local function runs(frame, button, prefix)
	if lookup(frame, prefix, "type", suffix(button)) ~= "macro" then return nil end
	return lookup(frame, prefix, "macrotext", suffix(button))
end

-- One click on a button registered for "AnyDown": PreClick, the secure handler,
-- PostClick. Answers the macro that ran, nil for none.
local function click(button, which, prefix, down)
	if not button:IsVisible() then return nil, "hidden" end
	which = which or "LeftButton"
	down = down ~= false
	local pre = button.scripts.PreClick
	if pre then pre(button, which, down) end
	local ran = runs(button, which, prefix or "")
	local post = button.scripts.PostClick
	if post then post(button, which, down) end
	return ran
end

local function session(scenario, opts, body)
	opts = opts or {}
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	Mock.class = opts.class or "MAGE"
	local restore = H.strangers(opts.people or PEOPLE)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		Mock.timers = {}
		local p = ns.db.profile.prompt
		p.showQueue, p.queueRows, p.clickRows = true, 3, true
		p.style = "glass"
		ns.db.profile.speech.enabled = opts.speech == true
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		body(ns, ns.Prompt:Regions(), p)
		Mock.inCombat = false
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function top(ns) return ns.Prompt.state.current end
local function named(r, i)
	local row = r.rowButtons[i] and r.rowButtons[i].mannersRow
	return row and row.name
end

-- ------------------------------------------------------------------ 1
-- /manners try is the console's way of testing a macro against whoever the
-- prompt offers ({name}, {unit}, {aim}, {first} and {spell} are filled from the
-- candidate, Commands.lua ExpandTokens). A press on a name in the list arms
-- the row at that person, and the row's own tooltip says "Runs your /manners
-- try macro against <that person>" -- but the tokens are filled from
-- ns.lastTopEntry, which only the prompt's own arming writes (Macro.lua, Arm:
-- `if not S.isRow`), so the macro runs against whoever is on the prompt.
do
	local scenario = "hunt33-rows: a /manners try macro pressed from a name runs against that name, not the prompt's person"
	session(scenario, nil, function(ns, r)
		local rowName = named(r, 1)
		local promptName = top(ns) and top(ns).name
		if not (rowName and promptName and rowName ~= promptName) then
			fail(scenario, ("SKIPPED -- the list holds %s under %s"):format(tostring(rowName), tostring(promptName)))
			return
		end
		ns.tryMacro = "/cast {name}"
		Mock.advance(1)
		local ran = click(r.rowButtons[1])
		ns.tryMacro = nil
		if not ran then
			fail(scenario, "SKIPPED -- the click ran nothing")
			return
		end
		if not ran:find(rowName, 1, true) then
			fail(scenario, ("a try macro pressed from the name %s ran %q, aimed at the prompt's person %s"):format(
				rowName, ran, promptName))
		end
	end)
end
