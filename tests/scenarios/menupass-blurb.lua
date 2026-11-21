-- Every page of the options window opens with a line under its title saying
-- what the page is for (WindowPage.lua, PaintBlurb; Layout.lua, `blurb`).
--
-- Every scenario name starts with "menupass-blurb:".
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

-- Where a region's top and bottom are, down from the top of the page.
local function span(UI, r)
	local _, top = FT.span(UI.view.child, "y")
	local lo, hi = FT.span(r, "y")
	if not (top and lo and hi) then return nil end
	return top - hi, top - lo
end

-- Where the first section with a drawn title or row starts.
local function firstTop(UI)
	local best
	for _, sec in ipairs(UI.Model(UI.page).sections) do
		local frames = {}
		if sec.title and sec.title:IsShown() then frames[#frames + 1] = sec.title end
		if sec.button and sec.button:IsShown() then frames[#frames + 1] = sec.button end
		for _, e in ipairs(sec.entries) do
			if e.row and e.row.frame:IsShown() then frames[#frames + 1] = e.row.frame end
		end
		for _, f in ipairs(frames) do
			local t = span(UI, f)
			if t and (not best or t < best) then best = t end
		end
	end
	return best
end

local function with(scenario, class, body)
	Mock.reset()
	FT.install()
	local known, playerSpell = rawget(_G, "IsSpellKnown"), rawget(_G, "IsPlayerSpell")
	local ok, err = pcall(function()
		Mock.class = class
		local ns = load(scenario)
		if not ns then return end
		Mock.knownSpells = setmetatable({}, { __index = function() return true end })
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		for id in pairs(ns.WindowUI.subOf) do ns.WindowUI.subOf[id] = nil end
		body(ns, ns.WindowUI)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	rawset(_G, "IsSpellKnown", known)
	rawset(_G, "IsPlayerSpell", playerSpell)
	Mock.inCombat = false
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The blurb of the open page: shown, under the title, over the first section.
local function check(scenario, ns, UI, what)
	local m = UI.Model(UI.page)
	local text = m.blurb and m.blurb:GetText()
	if not (m.blurb and m.blurb:IsShown() and text and text ~= "") then
		fail(scenario, what .. ": no line under the title")
		return
	end
	local _, titleBottom = span(UI, m.title)
	local blurbTop, blurbBottom = span(UI, m.blurb)
	if not (titleBottom and blurbTop) then fail(scenario, what .. ": the title or the line has no place") return end
	if blurbTop < titleBottom - 0.5 then
		fail(scenario, ("%s: the line (%s) starts inside the title (ends %s)"):format(what, tostring(blurbTop), tostring(titleBottom)))
	end
	local first = firstTop(UI)
	if first and first < blurbBottom - 0.5 then
		fail(scenario, ("%s: the first section (%s) starts over the end of the line (%s)"):format(what, tostring(first), tostring(blurbBottom)))
	end
end

do
	local scenario = "menupass-blurb: each page says what it is for"
	-- The layout: a short line on every page.
	with(scenario, "MAGE", function(ns)
		for id, page in pairs(ns.WindowLayout.pages) do
			local b = page.blurb
			if type(b) ~= "string" or b == "" then
				fail(scenario, id .. " has no blurb")
			elseif #b > 120 then
				fail(scenario, id .. "'s blurb is " .. #b .. " characters")
			end
		end
	end)
	-- Drawn: the hunter's sidebar holds every page, a rogue the quiet ones.
	for _, class in ipairs({ "HUNTER", "MAGE" }) do
		with(scenario, class, function(ns, UI)
			ns.OpenOptions()
			local ids = {}
			for _, group in ipairs(ns.WindowLayout.groups) do
				for _, id in ipairs(group) do
					if UI.visiblePages[id] then ids[#ids + 1] = id end
				end
			end
			if #ids < 8 then fail(scenario, class .. " sees only " .. #ids .. " pages") end
			for _, view in ipairs({ "full", "simple" }) do
				ns.SetMenuView(view)
				for _, id in ipairs(ids) do
					ns.OpenOptions(id)
					check(scenario, ns, UI, class .. " " .. id .. " in the " .. view .. " view")
					-- One sub-division, where the page has them.
					local subs = UI.SubsShown(id)
					if #subs > 1 then
						UI.ShowSub(id, subs[#subs])
						check(scenario, ns, UI, class .. " " .. id .. " in a sub-division, " .. view .. " view")
						UI.ShowSub(id, nil)
					end
				end
			end
			ns.SetMenuView("full")
		end)
	end
	-- A page put away takes its line with it.
	with(scenario, "MAGE", function(ns, UI)
		ns.OpenOptions("who")
		local m = UI.Model("who")
		ns.OpenOptions("when")
		if m.blurb:IsShown() then fail(scenario, "Who to buff's line is still drawn on When to offer") end
	end)
end
