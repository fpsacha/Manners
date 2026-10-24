-- Hunt 34, fixes A: what the hunt-33 scenarios do not pin down on their own. Every
-- name starts with "hunt34-<area>:" so a mutation can name exactly one.
--
--   press     a click a script makes (no up or down) still counts as a press
--   favours   a buff recast while the baseline held it withheld stays new
--   speech    a female speaker skips the lines a language gives a man's voice,
--             and no pool is thinned below what the draw needs

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local TOUCHED = { "C_UnitAuras", "UnitSex", "IsShiftKeyDown" }

-- One scenario: the mock reset to `flavour`, `names` about on their tokens, the
-- addon loaded and driven to a fresh prompt, body(ns) run, everything put back.
local function run(scenario, flavour, names, body)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	Mock.class = "MAGE"
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore
	local ok, err = pcall(function()
		restore = strangers(names or {})
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if restore then restore() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ press
-- hunt34-press: a click with no phase (a script's, the test console's) is a press.
-- Only an up the client says is an up (`down` false) is the end of a held key.
run("hunt34-press: a click with no down or up is a press", nil,
	{ nameplate1 = { "Anna", "Aim" } }, function(ns)
	local scenario = "hunt34-press: a click with no down or up is a press"
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local button = ns.Prompt:GetButton()
	if not button:IsShown() then
		fail(scenario, "SKIPPED -- nobody on the prompt")
		return
	end
	Mock.advance(1)
	button.scripts.PreClick(button, "LeftButton")
	if ns.pressAt ~= GetTime() then
		fail(scenario, "PreClick with no phase did not take the press")
	end
	button.scripts.PostClick(button, "LeftButton")
	if not ns.pendingClick then
		fail(scenario, "a click with no phase filed no press")
	end
end)

