-- Hunt 39: faults found in the six looks the last hunt did not cover (Glass,
-- Framed, Minimal, Luxe, Toast, Arcane) and in the paint path all nine share.
--
-- Run on the recording CreateFrame in tests/frametree.lua. Every name starts
-- with "hunt39-looks:" so a mutation can name exactly one.
--
-- What it holds:
--   * Glass and Framed take their shadow away with the panel's opacity: the
--     shadow's steps are whole rectangles that lie under the panel as well as
--     round it, so a panel the player made see-through was a dark box all the
--     same (Luxe, Toast and Arcane drop theirs).

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
for _, style in ipairs({ "glass", "framed" }) do
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
			-- And the bevel's shade along the bottom edge, which is no stronger
			-- than the panel it is the edge of.
			local line = r.hairBottom._shown ~= false and r.hairBottom._color and r.hairBottom._color[4] or 0
			if line > alpha + 0.001 then
				fail(scenario, ("with the panel at %.2f opacity the dark line along its bottom is %.2f"):format(alpha, line))
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
