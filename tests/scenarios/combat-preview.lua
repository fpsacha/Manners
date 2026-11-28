-- The combat prompt's preview: opening the Combat page shows nothing by
-- itself, and only Move the cards lets the cards be dragged. Trying a look in
-- the gallery shows the prompt, still, and the trial's end puts it away.
--
-- Every scenario name starts with "combat-preview:" so the mutations in
-- tests/mutations/combat-preview.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function ready(scenario)
	Mock.reset()
	Mock.class = "WARRIOR"
	Mock.knownSpells = { [6552] = true }
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Guard("probe combat actions", ns.ProbeCapabilities)
	local entry = ns.caps.moments and ns.caps.moments.byKey["combat-interrupt-pummel"]
	if not entry then fail(scenario, "SKIPPED -- Pummel was not learned") return nil end
	ns.db.profile.moments[entry.row.key] = true
	ns.Moments:Refresh()
	return ns, ns.Moments:Slot(entry.row.slot)
end

do
	local scenario = "combat-preview: opening the Combat page shows and moves nothing"
	local ns = ready(scenario)
	if ns then
		for _, layout in ipairs({ "row", "stack", "free" }) do
			ns.db.profile.moments.layout = layout
			ns.OpenOptions("combat")
			if ns.Moments.Previewing() then fail(scenario, "opening the Combat page (" .. layout .. ") shows the preview") end
			if ns.CloseOptions then ns.CloseOptions() end
		end
	end
	Mock.reset()
end

do
	local scenario = "combat-preview: a look tried shows the cards still, and the trial's end puts them away"
	local ns, slot = ready(scenario)
	if ns then
		ns.db.profile.moments.layout = "free"
		ns.Moments.TryLook("frost")
		if not ns.Moments.Previewing() then fail(scenario, "a look tried is not shown on the combat prompt") end
		if ns.Moments.Anchor():IsMouseEnabled() then fail(scenario, "a look tried lets the row be dragged") end
		if slot.handle and slot.handle:IsShown() then fail(scenario, "a look tried puts a drag handle on each card") end
		ns.Moments.TryLook(nil)
		if ns.Moments.Previewing() then fail(scenario, "the trial's end leaves the preview up") end
		-- A setting changed shows the cards, and they can be dragged from there.
		ns.Moments.Restyle()
		if not (slot.handle and slot.handle:IsShown() and slot.handle:IsMouseEnabled()) then
			fail(scenario, "the preview a setting brings up cannot be dragged")
		end
		ns.Moments.EndPreview()
		-- Move the cards still lets them be dragged.
		ns.Moments.TogglePreview()
		if not (slot.handle and slot.handle:IsShown() and slot.handle:IsMouseEnabled()) then
			fail(scenario, "Move the cards gives no card a handle")
		end
		-- A look tried while moving keeps the move going.
		ns.Moments.TryLook("frost")
		ns.Moments.TryLook(nil)
		if not ns.Moments.Previewing() then fail(scenario, "the trial's end closed a move in progress") end
		ns.Moments.TogglePreview()
		ns.db.profile.moments.layout = "row"
		ns.Moments.TryLook("frost")
		if ns.Moments.Anchor():IsMouseEnabled() then fail(scenario, "a look tried lets the row be dragged") end
		ns.Moments.TryLook(nil)
	end
	Mock.reset()
end
