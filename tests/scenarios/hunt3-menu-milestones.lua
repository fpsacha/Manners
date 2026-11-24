-- Hunt 3 of the day's work, the options window (Options/Window/WindowSearch.lua,
-- WindowPage.lua, Layout.lua, Widgets.lua, WindowChrome.lua). The milestones it
-- also covered went in 1.12.1.
--
-- Search does not say "turn on" a switch that is on already, or one that
-- would show nothing to this class; the line over the fine print is not drawn
-- over What's new; what Show spell icon governs goes with it; a greyed
-- button still runs its tooltip.
--
-- Every name below starts "hunt3-menu-milestones:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local P = "hunt3-menu-milestones: "

local function guarded(ns, scenario)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- One session with the options window open on `page`, as `class`.
local function session(scenario, class, page, body)
	Mock.reset()
	if class then Mock.class = class end
	FT.install()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		ns.OpenOptions(page, true)
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		guarded(ns, scenario)
	end)
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The search result that leads to `path` through its switch, or nil.
local function found(UI, words, path)
	UI.search.box:SetText(words)
	UI.RunSearch()
	for _, f in ipairs(UI.search.found) do
		if f.ref.via == path then return f end
	end
	return nil
end

-- ------------------------------------------------------------------ 1
-- A control found behind its switch is one that switch would show. A mage's
-- portals are not a priest's, whatever People who ask me in chat says.
do
	local scenario = P .. "search offers a courtesy only to the class that has it"
	session(scenario, "MAGE", "general", function(ns, UI)
		if not (UI.search and UI.search.box) then
			fail(scenario, "SKIPPED -- no search box")
			return
		end
		ns.db.profile.sources.asked = false
		ns.RefreshOptionsDisplay()
		local hit = found(UI, ns.L["Portals, when my group asks"], "who.courtesyPortals")
		if not (hit and hit.first and hit.ref.path == "who.asked") then
			fail(scenario, "SKIPPED -- a mage with the switch off is not led to it for the portals")
		end
		if found(UI, ns.L["Healthstones, when they ask"] or "Healthstone", "who.courtesyHealthstones") then
			fail(scenario, "a mage is told to turn a switch on for a warlock's healthstones")
		end
	end)
	session(scenario, "PRIEST", "general", function(ns, UI)
		if not (UI.search and UI.search.box) then return end
		ns.db.profile.sources.asked = false
		ns.RefreshOptionsDisplay()
		if not UI.Item("who.asked") or UI.Hidden(UI.Item("who.asked")) then
			fail(scenario, "SKIPPED -- a priest has no People who ask me in chat")
			return
		end
		local hit = found(UI, ns.L["Portals, when my group asks"], "who.courtesyPortals")
		if hit then
			fail(scenario, "a priest is told to turn on " .. tostring(hit.first) .. " for a mage's portals")
		end
	end)
end

-- ...and the switch is off. The lines mixed in are hidden by the line set
-- too: with Say a line on and another set chosen, there is nothing to turn on.
do
	local scenario = P .. "search does not say to turn on a switch that is on"
	session(scenario, "MAGE", "general", function(ns, UI)
		if not (UI.search and UI.search.box) then
			fail(scenario, "SKIPPED -- no search box")
			return
		end
		local speech = ns.db.profile.speech
		local words = ns.L["My own lines, mixed in with In character"]
		speech.enabled = true
		if ns.InCharacter.Active(speech) then speech.presetChoice = "plain" end
		if ns.InCharacter.Active(speech) then
			fail(scenario, "SKIPPED -- In character is still the set")
			return
		end
		ns.RefreshOptionsDisplay()
		if not UI.Hidden(UI.Item("click.mixedLines")) then
			fail(scenario, "SKIPPED -- the lines mixed in are shown without In character")
			return
		end
		local hit = found(UI, words, "click.mixedLines")
		if hit then
			fail(scenario, "with Say a line on, the result says: turn on " .. tostring(hit.first) .. " first")
		end
		-- By the switch alone, whatever else the layout knows of the control:
		-- one hidden with its switch on is hidden for a reason the switch is not.
		local also = ns.WindowLayout.parentsIf
		local rule = also["click.mixedLines"]
		also["click.mixedLines"] = nil
		hit = found(UI, words, "click.mixedLines")
		also["click.mixedLines"] = rule
		if hit then
			fail(scenario, "a control hidden with its switch on is found behind it: turn on " .. tostring(hit.first) .. " first")
		end
		-- Line set, hidden by the switch alone, is still found while it is off.
		speech.enabled = false
		ns.RefreshOptionsDisplay()
		if not found(UI, ns.L["Line set"], "click.preset") then
			fail(scenario, "SKIPPED -- Line set is not found while Say a line is off")
		end
		-- And with it off, the lines mixed in wait for the set as well.
		if found(UI, words, "click.mixedLines") then
			fail(scenario, "Say a line off and another set: turning it on would show no lines mixed in")
		end
	end)
end

-- ------------------------------------------------------------------ 2
-- The line over a page's folds introduces fine print. What's new is a fold
-- with no setting in it: nothing is drawn over it on Start here.
do
	local scenario = P .. "no fine-print caption over What's new on Start here"
	session(scenario, "MAGE", "general", function(ns, UI)
		local w = UI.Where("general.newsNote1")
		if not (w and w.sec.fold and w.sec.visible) then
			fail(scenario, "SKIPPED -- What's new is no fold drawn on Start here")
			return
		end
		local cap = UI.Model("general").caption
		if not cap then
			fail(scenario, "SKIPPED -- the page has no caption to show or hide")
		elseif cap.text:IsShown() then
			fail(scenario, "Start here draws over What's new: " .. tostring(cap.text:GetText()))
		end
	end)
	session(scenario, "MAGE", "appearance", function(ns, UI)
		local cap = UI.Model("appearance").caption
		if not (cap and cap.text:IsShown()) then
			fail(scenario, "SKIPPED -- Look draws no caption over its folds")
		end
	end)
end

-- ------------------------------------------------------------------ 3
-- Everything Show spell icon governs is indented straight under it, so it is
-- not drawn while the icon is off; the gryphons, which go by the look, stay.
do
	local scenario = P .. "with Show spell icon off, its sub-options are not drawn"
	session(scenario, "MAGE", "appearance", function(ns, UI)
		local prompt = ns.db.profile.prompt
		-- Round the icon off is with the look's own settings (the look decides
		-- it), greyed there with the icon off, saying why.
		local governed = { "appearance.iconSize", "appearance.iconFrame", "appearance.showCooldown" }
		local function shown(path)
			local w = UI.Where(path)
			return w ~= nil and UI.EntryShown(w.e)
		end
		prompt.showIcon = true
		ns.RefreshOptionsDisplay()
		for _, path in ipairs(governed) do
			if not shown(path) then fail(scenario, "SKIPPED -- " .. path .. " is not drawn with the icon on") end
		end
		local gryphons = shown("appearance.gryphons")
		prompt.showIcon = false
		ns.RefreshOptionsDisplay()
		for _, path in ipairs(governed) do
			if shown(path) then fail(scenario, path .. " is still drawn, greyed, with Show spell icon off") end
		end
		if shown("appearance.gryphons") ~= gryphons then
			fail(scenario, "Gryphons at the ends went with the icon, which does not govern it")
		end
		local w = UI.Where("appearance.gryphons")
		if w and w.e.parent then fail(scenario, "Gryphons at the ends is indented under " .. tostring(w.e.parent.path)) end
	end)
end

-- ------------------------------------------------------------------ 8
-- A greyed button is a disabled one, and the client runs no OnEnter on it
-- unless told to: every button with a tooltip is told.
do
	local scenario = P .. "a greyed button still runs its tooltip"
	session(scenario, "MAGE", "general", function(ns, UI)
		local row = UI.RowFor("general.verbose")
		if not (row and row.hit and row.hit:GetScript("OnEnter")) then
			fail(scenario, "SKIPPED -- no switch with a tooltip on Start here")
		elseif not (row.hit._ft and row.hit._ft.motionWhileDisabled) then
			fail(scenario, "a switch's button runs no OnEnter while it is disabled")
		end
		local move = UI.header and UI.header.move
		if not (move and move:GetScript("OnEnter")) then
			fail(scenario, "SKIPPED -- no Move the prompt in the header")
		elseif not (move._ft and move._ft.motionWhileDisabled) then
			fail(scenario, "Move the prompt runs no OnEnter while it is disabled, which is in a fight")
		end
	end)
end
