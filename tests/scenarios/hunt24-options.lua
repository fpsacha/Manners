-- Options/Look.lua: "Only for people who buff me" (the sound's owedOnly) is
-- greyed out when it can do nothing.
--
-- The prompt's sound reads the setting only where somebody can be owed: with
-- "People who buff me" off (db.sources.owed == false) every new person sounds
-- whatever the toggle says (Prompt/Refresh.lua). The toggle was greyed out only
-- by "Play a sound", so with the source off it stayed live and did nothing. It
-- is greyed out by the source as well, the way the sound's own list is by the
-- switch. The custom options window draws the same model and reads the same
-- `disabled`, so a click on the greyed toggle there changes nothing either.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every
-- scenario name starts with "hunt24-options:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- A driven session, with the Look tab's definition of the toggle, or nil.
local function session(scenario, body)
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local tab = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.appearance
		local control = tab and tab.args and tab.args.soundOwedOnly
		if not control then
			fail(scenario, "SKIPPED -- there is no Only for people who buff me on the Look tab")
			return
		end
		body(ns, control)
		noErrors(scenario, ns)
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Whether a control is greyed out, asked of its `disabled` the way the window
-- and AceConfigDialog ask it.
local function greyed(control)
	local rule = control.disabled
	if type(rule) == "function" then return rule({}) and true or false end
	return rule and true or false
end

-- ------------------------------------------------------------------ the model
-- Every way into the three states: the source off (greyed out, the point),
-- both on (live), and the sound off (greyed out, as before).
do
	local scenario = "hunt24-options: Only for people who buff me is greyed out while People who buff me is off"
	session(scenario, function(ns, control)
		ns.db.profile.sound.enabled = true
		ns.db.profile.sources.owed = true
		if greyed(control) then
			fail(scenario, "SKIPPED -- the toggle is greyed out with both switches on")
			return
		end
		ns.db.profile.sources.owed = false
		if not greyed(control) then
			fail(scenario, "the toggle stays live with People who buff me off, where the sound ignores it"
				.. " (Prompt/Refresh.lua reads db.sources.owed ~= false): a switch that does nothing")
		end
	end)
end

do
	local scenario = "hunt24-options: Only for people who buff me is live with People who buff me and the sound on"
	session(scenario, function(ns, control)
		ns.db.profile.sound.enabled = true
		ns.db.profile.sources.owed = true
		if greyed(control) then
			fail(scenario, "the toggle is greyed out with People who buff me and Play a sound both on")
		end
		-- A profile older than the setting holds no value, which the sound reads as on.
		ns.db.profile.sources.owed = nil
		if greyed(control) then
			fail(scenario, "the toggle is greyed out with People who buff me unset, which the sound reads as on")
		end
	end)
end

do
	local scenario = "hunt24-options: Only for people who buff me is greyed out with the sound off, whoever buffs me"
	session(scenario, function(ns, control)
		ns.db.profile.sources.owed = true
		ns.db.profile.sound.enabled = false
		if not greyed(control) then
			fail(scenario, "the toggle is live with Play a sound off and People who buff me on")
		end
		ns.db.profile.sources.owed = false
		if not greyed(control) then
			fail(scenario, "the toggle is live with Play a sound off and People who buff me off")
		end
		-- And it comes back with the sound: the source alone decides then.
		ns.db.profile.sources.owed = true
		ns.db.profile.sound.enabled = true
		if greyed(control) then
			fail(scenario, "the toggle stayed greyed out after Play a sound came back on")
		end
	end)
end

-- ------------------------------------------------------------------ the window
-- The custom window builds a row from the same definition and asks `disabled`
-- again at the click: with the source off the toggle refuses it and the setting
-- stays where it was; with it on the same click turns the setting over.
do
	local scenario = "hunt24-options: the window's Only for people who buff me refuses a click while People who buff me is off"
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local ctx = { changes = {}, holds = {}, pages = {}, relayouts = 0 }
		ctx.Window = CreateFrame("Frame", "MannersOptionsTest", UIParent)
		ctx.Window:SetSize(820, 600)
		ctx.OnChange = function(item) ctx.changes[#ctx.changes + 1] = item.path end
		ctx.OnHold = function() end
		ctx.ScrollPage = function() end
		ctx.Relayout = function(row) row:Layout(row.width) end

		local item = ns.WindowBind.Item("appearance.soundOwedOnly", {}, ctx)
		if not item then
			fail(scenario, "SKIPPED -- the model has no appearance.soundOwedOnly")
			return
		end
		local row = ns.WindowWidgets.Build("toggle", ctx.Window, item)
		row:Layout(560)
		local sound, sources = ns.db.profile.sound, ns.db.profile.sources
		local function click()
			row.hit.scripts.OnClick(row.hit, "LeftButton")
		end

		sound.enabled = true
		sources.owed = true
		sound.owedOnly = true
		click()
		if sound.owedOnly ~= false then
			fail(scenario, "SKIPPED -- a click on the live toggle did not turn it off (owedOnly=" .. tostring(sound.owedOnly) .. ")")
			return
		end
		click()
		sources.owed = false
		click()
		if sound.owedOnly ~= true then
			fail(scenario, "a click on the toggle changed Only for people who buff me with People who buff me off,"
				.. " where the sound ignores it either way (owedOnly=" .. tostring(sound.owedOnly) .. ")")
		end
		noErrors(scenario, ns)
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
