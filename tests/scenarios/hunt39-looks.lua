-- Hunt 39: faults found in the looks the hunt before did not cover (of those
-- still here, Glass and Minimal) and in the paint path every look shares.
--
-- Run on the recording CreateFrame in tests/frametree.lua. Every name starts
-- with "hunt39-looks:" so a mutation can name exactly one.
--
-- What it holds:
--   * Glass takes its shadow away with the panel's opacity: the
--     shadow's steps are whole rectangles that lie under the panel as well as
--     round it, so a panel the player made see-through was a dark box all the
--     same.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

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

-- ------------------------------------------------------------------ 1
-- The glass's shadow does not darken a see-through panel.
for _, style in ipairs({ "glass" }) do
	local scenario = "hunt39-looks: " .. style .. " has no dark box under a see-through panel"
	withTree(scenario, { nameplate1 = { "Anna", "Aim" } }, function(ns)
		freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		p.style = style
		for _, alpha in ipairs({ 0, 0.05, 0.3 }) do
			p.bgColor = { 0.04, 0.04, 0.06, alpha }
			ns.Prompt:ApplyStyle()
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			FT.settle()
			local r = ns.Prompt:Regions()
			-- What the stacked rectangles leave of the world over the panel's
			-- own footprint: each lets through what the one above does not
			-- stop.
			local through = 1
			for _, t in ipairs(r.shadows) do
				if t._shown ~= false and t._color then through = through * (1 - (t._color[4] or 1)) end
			end
			local dark = 1 - through
			-- And the light along the glass's bottom edge, which is no stronger
			-- than the panel it is the edge of, nor the pane itself.
			local piece = r.glassLight and r.glassLight[8]
			local line = piece and piece._shown ~= false and piece._color and piece._color[4] or 0
			if line > alpha + 0.001 then
				fail(scenario, ("with the panel at %.2f opacity the light along its bottom is %.2f"):format(alpha, line))
			end
			local pane = r.pane and r.pane[5]
			local g = pane and pane._shown ~= false and pane._gradient
			local paneAlpha = g and type(g[2]) == "table" and g[2].a or 0
			if paneAlpha > alpha + 0.001 then
				fail(scenario, ("with the panel at %.2f opacity the pane is drawn at %.2f"):format(alpha, paneAlpha))
			end
			if dark > alpha + 0.001 then
				fail(scenario, ("with the panel at %.2f opacity the shadow steps darken its footprint by %.2f"):format(alpha, dark))
			end
		end
		-- And at the default opacity they are what they always were.
		p.bgColor = { 0.04, 0.04, 0.06, 0.88 }
		ns.Prompt:ApplyStyle()
		local r = ns.Prompt:Regions()
		local first = r.shadows[1]._color
		if not first or math.abs(first[4] - 0.50) > 0.001 then
			fail(scenario, "the shadow's rim changed at the default opacity: " .. tostring(first and first[4]))
		end
	end)
end
