-- Everything about a fight is on one page, In a fight: the prompt's fight
-- switches and the buttons made for one (Will of the Forsaken, Mend Pet, the
-- cure, the fight key). Look keeps what the prompt looks like. The page has
-- its own reset and its own combat line, and the sidebar, which does not
-- scroll, is laid out smaller when its pages do not fit.
--
-- Every scenario name starts with "menupass-fight:".
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local HAWK, MONKEY = 13165, 13163
local WOTF = 7744

-- The thirteen controls, by path.
local FIGHT = {
	"appearance.hideInFight", "appearance.fightRota", "appearance.fightKeySpell", "appearance.fightKeyOn",
	"appearance.hideInCombat", "appearance.dimInCombat",
	"appearance.breakFree", "appearance.breakFreeKey", "appearance.mendInFight", "appearance.mendInFightKey",
	"appearance.fightButtons", "appearance.cureFight", "appearance.cureFightKey",
}

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- opts.class (default PRIEST), opts.race (default Scourge), opts.locale.
local function with(scenario, opts, body)
	opts = opts or {}
	Mock.reset()
	Mock.class = opts.class or "PRIEST"
	Mock.playerRace = opts.race or "Scourge"
	Mock.locale = opts.locale
	local ns = load(scenario)
	if not ns then return end
	local savedKnown, savedPlayer = rawget(_G, "IsSpellKnown"), rawget(_G, "IsPlayerSpell")
	local ok, err = pcall(function()
		if opts.class == "HUNTER" then
			local set = { [HAWK] = true, [MONKEY] = true, [WOTF] = true }
			IsSpellKnown = function(id) return set[id] == true end
			IsPlayerSpell = IsSpellKnown
		else
			Mock.knownSpells = { [WOTF] = true }
		end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		ns.Prompt:ExitTest()
		noErrors(scenario, ns)
	end)
	Mock.inCombat = false
	IsSpellKnown, IsPlayerSpell = savedKnown, savedPlayer
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function shown(frame) return frame ~= nil and frame:IsShown() == true end

-- ------------------------------------------------------------------ the page
do
	local scenario = "menupass-fight: everything about a fight is on In a fight"
	with(scenario, nil, function(ns, UI)
		for _, path in ipairs(FIGHT) do
			if UI.PageOf(path) ~= "fight" then
				fail(scenario, path .. " is on " .. tostring(UI.PageOf(path)) .. ", not In a fight")
			end
		end
		local look = ns.WindowLayout.pages.appearance
		local onLook = {}
		for _, sec in ipairs(look.sections) do
			for _, raw in ipairs(sec.items) do
				onLook[type(raw) == "table" and raw[1] or raw] = true
			end
		end
		for _, path in ipairs(FIGHT) do
			if onLook[path] then fail(scenario, "Look still holds " .. path) end
		end
		if ns.OptionsPage.TAB.fight ~= ns.L["In a fight"] then
			fail(scenario, "the page's name is " .. tostring(ns.OptionsPage.TAB.fight))
		end
		ns.OpenOptions("fight")
		if ns.OptionsTab() ~= "fight" then fail(scenario, "OpenOptions(\"fight\") opened " .. tostring(ns.OptionsTab())) end
		if ns.WindowLayout.pages.fight.title ~= ns.OptionsPage.TAB.fight then
			fail(scenario, "the page's title is " .. tostring(ns.WindowLayout.pages.fight.title))
		end
	end)
end

-- ------------------------------------------------------------------ a Forsaken
do
	local scenario = "menupass-fight: a Forsaken finds Will of the Forsaken there and turns it off"
	with(scenario, nil, function(ns, UI)
		ns.OpenOptions("fight")
		if not UI.RowShown("appearance.breakFree") then
			fail(scenario, "a Scourge priest's In a fight has no Will of the Forsaken row")
			return
		end
		if not UI.RowShown("appearance.breakFreeKey") then fail(scenario, "its key row is not drawn while it is on") end
		ns.db.profile.prompt.breakFree = false
		ns.RefreshOptionsDisplay()
		if UI.RowShown("appearance.breakFreeKey") then fail(scenario, "its key row is drawn with the switch off") end
		if not UI.RowShown("appearance.breakFree") then fail(scenario, "the switch went with itself") end
		local button = _G.MannersBreakFree
		if button and shown(button) and button:GetAlpha() ~= 0 then
			fail(scenario, "the button stayed up with the switch off")
		end
	end)
end

-- ------------------------------------------------------------------ the reset
do
	local scenario = "menupass-fight: In a fight's reset puts every fight switch back, Look's leaves them"
	with(scenario, nil, function(ns, UI)
		local p, d = ns.db.profile.prompt, ns.defaults.profile.prompt
		local fields = { "hideInCombat", "hideInFight", "fightRota", "breakFree", "cureFight", "dimInCombat" }
		local function unsettle()
			for _, name in ipairs(fields) do p[name] = not d[name] end
		end
		unsettle()
		if ns.OptionsPage.ResetPage("appearance") ~= true then fail(scenario, "Look's reset did not run") end
		for _, name in ipairs(fields) do
			if p[name] ~= (not d[name]) then fail(scenario, "Look's reset put back " .. name) end
		end
		if ns.OptionsPage.ResetPage("fight") ~= true then fail(scenario, "In a fight's reset did not run") end
		for _, name in ipairs(fields) do
			if p[name] ~= d[name] then fail(scenario, "In a fight's reset left " .. name .. " at " .. tostring(p[name])) end
		end
		local list = ns.OptionsPage.RESET.fight
		local listed = {}
		for _, path in ipairs(list or {}) do listed[path] = true end
		for _, path in ipairs({ "prompt.breakFree", "beast.fightMend", "prompt.cureFight", "prompt.fightButtons" }) do
			if not listed[path] then fail(scenario, "the list leaves out " .. path) end
		end
		for _, path in ipairs(ns.OptionsPage.RESET.appearance) do
			if listed[path] then fail(scenario, "Look's list also holds " .. path) end
		end
	end)
end

-- ------------------------------------------------------------------ the combat line
do
	local scenario = "menupass-fight: in combat the page says changes come after the fight"
	with(scenario, nil, function(ns, UI)
		ns.OpenOptions("fight")
		local item = UI.Item(ns.WindowLayout.strip.combat.fight)
		if not item then fail(scenario, "In a fight has no combat line in the layout") return end
		Mock.inCombat = true
		ns.RefreshOptionsDisplay()
		local text = UI.strip.combat
		if not (type(text) == "string" and text:find(ns.L["In combat: changes here show once the fight ends."], 1, true)) then
			fail(scenario, "in a fight the page shows no line (" .. tostring(text) .. ")")
		end
		Mock.inCombat = false
		ns.RefreshOptionsDisplay()
		if UI.strip.combat then fail(scenario, "the line stays after the fight") end
	end)
end

-- ------------------------------------------------------------------ the sidebar
local function fits(scenario, ns, UI, label)
	local side = UI.side
	-- The room under the strip: the window's height less the header, the strip
	-- and the footer (the sidebar's frame is anchored to those).
	local room = UI.HEIGHT - UI.HEADER - (UI.strip.height or 0) - UI.FOOTER
	local compact = false
	for id, b in pairs(side.buttons) do
		if b:IsShown() then
			if b.compact then compact = true end
			local _, _, _, _, y = b:GetPoint()
			local bottom = -(y or 0) + b:GetHeight()
			if bottom > room then
				fail(scenario, ("%s: the %s button ends at %s, below the sidebar's %s"):format(label, id, tostring(bottom), tostring(room)))
			end
		end
	end
	return compact
end

do
	local scenario = "menupass-fight: the sidebar fits at the smallest window"
	for _, case in ipairs({
		{ "enUS PRIEST", { locale = "enUS" } },
		{ "deDE PRIEST", { locale = "deDE" } },
		{ "enUS HUNTER", { class = "HUNTER", race = "Orc", locale = "enUS" } },
		{ "deDE HUNTER", { class = "HUNTER", race = "Orc", locale = "deDE" } },
	}) do
		with(scenario, case[2], function(ns, UI)
			ns.OpenOptions("fight")
			UI.SetWindowSize(UI.MIN_W, UI.MIN_H)
			-- The strip at its tallest: a snooze running, and a fight, on a page
			-- with a combat line.
			ns.StartSnooze(30)
			Mock.inCombat = true
			ns.RefreshOptionsDisplay()
			fits(scenario, ns, UI, case[1])
			Mock.inCombat = false
			ns.StopSnooze(true)
			ns.RefreshOptionsDisplay()
			fits(scenario, ns, UI, case[1] .. " after")
		end)
	end
end

-- Too little room for the pages at their usual size: the buttons are laid out
-- smaller, and back to the usual size once there is room again.
do
	local scenario = "menupass-fight: the sidebar fits when the room runs short"
	with(scenario, nil, function(ns, UI)
		ns.OpenOptions("fight")
		ns.RefreshOptionsDisplay()
		local normal = UI.side.bottom
		if not normal or fits(scenario, ns, UI, "usual size") then
			fail(scenario, "the usual window needed the compact sidebar")
			return
		end
		local was = UI.HEIGHT
		UI.HEIGHT = UI.HEADER + (UI.strip.height or 0) + UI.FOOTER + normal - 12
		ns.RefreshOptionsDisplay()
		if not fits(scenario, ns, UI, "short of room") then
			fail(scenario, "with 12 less than the pages need they were not laid out smaller")
		end
		if UI.side.bottom >= normal then fail(scenario, "the compact list is no shorter") end
		UI.HEIGHT = was
		ns.RefreshOptionsDisplay()
		if fits(scenario, ns, UI, "room again") then fail(scenario, "the sidebar stayed compact when there was room") end
	end)
end
