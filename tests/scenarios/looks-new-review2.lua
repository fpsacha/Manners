-- The second review of the newer looks (Looks/Warchief.lua, Looks/
-- Gearworks.lua): what moves stops when its reason to move is gone, and the
-- name is not measured at every scan.
--
--   * Warchief: Calm chosen while the crest breathes stops the embers with
--     the breath, not only the three lights.
--   * Gearworks: the prompt taken down stops the cogs, the glint and the
--     bubbles under it.
--   * Warchief and Gearworks: a name drawn at its smallest is measured once
--     for a text at a size, not at every paint of the scan.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local LONG = { nameplate1 = { "Bartholomewz", "Thistledownington" } }

local function withTree(scenario, names, body)
	Mock.reset()
	FT.install()
	local restore = strangers(names or {})
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns, scenario) end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

-- The prompt up in `style` on Full effects, the breath asked for, with `who`
-- owed on top. Returns the settings and the look.
local function upIn(ns, scenario, style, who, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style, p.effects, p.flashStyle, p.showIcon = style, "full", "pulse", true
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, who)
	tick(ns)
	return p, ns.Prompt:Regions().look
end

local function playing(list)
	local n = 0
	for _, g in ipairs(list) do
		if g._playing then n = n + 1 end
	end
	return n
end

-- ------------------------------------------------------------------ 1
-- The embers rise with the breath and with nothing else: Calm chosen in the
-- middle of it ends them with it.
withTree("looks-new-review2: Warchief's embers stop when Calm is chosen mid-breath", ANNA, function(ns, scenario)
	local p, look = upIn(ns, scenario, "warchief", "Anna Aim")
	if not (look and look.rise and look.pulse) then
		fail(scenario, "SKIPPED -- Warchief is not the look in use")
		return
	end
	if not (look.pulse[1]._playing and playing(look.rise) > 0) then
		fail(scenario, "SKIPPED -- owed on Full, the crest does not breathe with its embers rising")
		return
	end
	p.effects = "calm"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if playing(look.pulse) > 0 then fail(scenario, "Calm chosen mid-breath, the crest still breathes") end
	if playing(look.rise) > 0 then
		fail(scenario, ("Calm chosen mid-breath, %d ember(s) still rise from the crest"):format(playing(look.rise)))
	end
	tick(ns)
	if playing(look.rise) > 0 then fail(scenario, "a scan after Calm was chosen, the embers rise again") end
	-- Back on Full with the same person owed, the breath and its embers may
	-- run again: Calm did not break them.
	p.effects = "full"
	ns.Prompt:ApplyStyle()
	tick(ns)
	if look.pulse[1]._playing and playing(look.rise) == 0 then
		fail(scenario, "back on Full the crest breathes with no embers")
	end
end)

-- ------------------------------------------------------------------ 2
-- Every loop of the look is stopped when the prompt is down.
local function worksRunning(look)
	local runs = {}
	for i, g in ipairs(look.turns) do
		if g._playing then runs[#runs + 1] = "cog " .. i end
	end
	if look.glintLoop._playing then runs[#runs + 1] = "the glint" end
	if look.bubbleRun:IsPlaying() then runs[#runs + 1] = "the bubbles" end
	if look.flow.driver:IsShown() then runs[#runs + 1] = "Flow's clock" end
	return runs
end

withTree("looks-new-review2: Gearworks stops its works when the prompt goes down", ANNA, function(ns, scenario)
	local _, look = upIn(ns, scenario, "gearworks", "Anna Aim", function(pp) pp.width, pp.classicArt = 260, true end)
	if not (look and look.turns and look.bubbleRun) then
		fail(scenario, "SKIPPED -- Gearworks is not the look in use")
		return
	end
	if not (look.turns[1]._playing and look.glintLoop._playing and look.bubbleRun:IsPlaying()) then
		fail(scenario, "SKIPPED -- with the prompt up on Full the works do not all run: " .. table.concat(worksRunning(look), ", "))
		return
	end
	-- The whistle that greeted the favour is a film played once: it ends on
	-- Flow's own clock, read here as the game would have.
	Mock.advance(3)
	FT.settle()
	ns.Looks.Flow.TickAll(GetTime())
	ns.BlockPerson("Anna Aim")
	tick(ns)
	Mock.advance(3)
	tick(ns)
	if ns.Prompt:GetButton():IsShown() then
		fail(scenario, "SKIPPED -- the panel did not come down with nobody left")
		return
	end
	local runs = worksRunning(look)
	if #runs > 0 then fail(scenario, "with the prompt down the works still run: " .. table.concat(runs, ", ")) end
end)

-- The same call ends a breath while the prompt stays up (the flash turned
-- off): there the works go on running.
withTree("looks-new-review2: Gearworks keeps its works running when only the breath ends", ANNA, function(ns, scenario)
	local p, look = upIn(ns, scenario, "gearworks", "Anna Aim", function(pp) pp.width, pp.classicArt = 260, true end)
	if not (look and look.turns and look.bubbleRun) then
		fail(scenario, "SKIPPED -- Gearworks is not the look in use")
		return
	end
	p.flashStyle = "off"
	tick(ns)
	if not ns.Prompt:GetButton():IsShown() then
		fail(scenario, "SKIPPED -- the panel came down with the flash turned off")
		return
	end
	if not (look.turns[1]._playing and look.glintLoop._playing and look.bubbleRun:IsPlaying()) then
		fail(scenario, "with the prompt up and the breath off, the works stand still")
	end
end)

-- ------------------------------------------------------------------ 3
-- A name too long for its room is drawn at its smallest, and FitLine does not
-- measure it there: the look does, for its tags, once for a text at a size.
-- kit.TextWidth is a pcall, and none may run on a per-scan path.
for _, style in ipairs({ "warchief", "gearworks" }) do
	local title = style == "warchief" and "Warchief" or "Gearworks"
	withTree("looks-new-review2: " .. title .. " measures a name at its smallest once, not at every scan", LONG, function(ns, scenario)
		local _, look = upIn(ns, scenario, style, "Bartholomewz Thistledownington", function(pp) pp.width = 150 end)
		if not (look and look.kit and look == ns.Looks.Get(style)) then
			fail(scenario, "SKIPPED -- " .. title .. " is not the look in use")
			return
		end
		local kit = look.kit
		if kit.fit.drawn[kit.name] ~= nil then
			fail(scenario, "SKIPPED -- the long name is not drawn at its smallest, so the look measures nothing")
			return
		end
		if not (type(look.nameWidth) == "number" and look.nameWidth > 0) then
			fail(scenario, "the look has no width for a name at its smallest: " .. tostring(look.nameWidth))
		end
		local calls, measure = 0, kit.TextWidth
		kit.TextWidth = function(fs, ...)
			if fs == kit.name then calls = calls + 1 end
			return measure(fs, ...)
		end
		for _ = 1, 5 do tick(ns) end
		kit.TextWidth = measure
		if calls > 0 then
			fail(scenario, ("%s measured the name %d times in five scans of the same face"):format(title, calls))
		end
		-- A restyle is a new font and size: the width is taken again there,
		-- and not at the scans after it.
		local function count(fs, ...)
			if fs == kit.name then calls = calls + 1 end
			return measure(fs, ...)
		end
		kit.TextWidth = count
		ns.Prompt:ApplyStyle()
		tick(ns)
		kit.TextWidth = measure
		if kit.fit.drawn[kit.name] == nil and calls < 1 then
			fail(scenario, ("after a restyle %s kept the width it took in the old font"):format(title))
		end
		calls = 0
		kit.TextWidth = count
		for _ = 1, 5 do tick(ns) end
		kit.TextWidth = measure
		if calls > 0 then
			fail(scenario, ("after a restyle %s measured the name %d times in five scans"):format(title, calls))
		end
	end)
end
