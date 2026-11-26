-- Everything about a fight is on one page, In a fight: the prompt's fight
-- switches and the buttons made for one (Will of the Forsaken, Mend Pet, the
-- cure). Look keeps what the prompt looks like. The page has
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

-- The nine controls, by path.
local FIGHT = {
	"appearance.fightRota",
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
		if opts.known then
			local set = opts.known
			IsSpellKnown = function(id) return set[id] == true end
			IsPlayerSpell = IsSpellKnown
		elseif opts.class == "HUNTER" then
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
		-- Off by default since 1.12: switched on first, then off.
		ns.db.profile.prompt.breakFree = true
		ns.OpenOptions("fight")
		ns.RefreshOptionsDisplay()
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
		local fields = { "fightRota", "breakFree", "cureFight", "cureFightEach" }
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

-- The fallback dialog has the line on Look already: the copy the strip reads
-- for In a fight must stay out of it, or a fight shows the same line twice.
do
	local scenario = "menupass-fight: the dialog shows the combat line once"
	with(scenario, nil, function(ns, UI)
		ns.OpenOptions("fight")
		Mock.inCombat = true
		for _, page in ipairs({ "fight", "quiet" }) do
			local copy = UI.Item(ns.WindowLayout.strip.combat[page])
			if not copy then
				fail(scenario, page .. " has no combat line in the layout")
			elseif UI.Hidden(copy) then
				fail(scenario, "the window's own strip does not read the copy on " .. page)
			end
		end
		ns.CloseOptions()
		for _, page in ipairs({ "fight", "quiet" }) do
			local copy = UI.Item(ns.WindowLayout.strip.combat[page])
			if copy and not UI.Hidden(copy) then fail(scenario, "with the window shut the dialog would show the line twice on " .. page) end
		end
		Mock.inCombat = false
	end)
end

-- ------------------------------------------------------------------ no prompt
-- A Forsaken rogue with nothing to offer still gets the Will of the Forsaken
-- button (the spell is racial), so its switch must be on In a fight even
-- though Look, for a character with no prompt, shows nothing else. The
-- button's tooltip points at a page only while the control is shown.
do
	local scenario = "menupass-fight: a Forsaken rogue with no prompt can reach the Will of the Forsaken switch"
	with(scenario, { class = "ROGUE", race = "Scourge" }, function(ns, UI)
		ns.OpenOptions("fight")
		if not (UI.visiblePages or {}).fight then fail(scenario, "In a fight is not in the sidebar") end
		if (UI.visiblePages or {}).appearance then fail(scenario, "Look is in the sidebar for a character with no prompt") end
		if not UI.RowShown("appearance.breakFree") then fail(scenario, "the Will of the Forsaken switch is not shown") end
		for _, path in ipairs({ "appearance.fightButtons", "appearance.fightRota" }) do
			if UI.RowShown(path) then fail(scenario, path .. " is shown with no prompt") end
		end
		local lines = {}
		local tip = { AddLine = function(_, text) lines[#lines + 1] = text end }
		ns.AddSettingsLine(tip, "appearance.breakFree")
		if #lines ~= 1 then fail(scenario, "the button's tooltip has " .. #lines .. " settings lines") end
	end)
	-- The same for a hunter who knows Mend Pet and has no aspect to offer.
	scenario = "menupass-fight: a hunter with no prompt can reach the Mend Pet switch"
	-- (The mock has no pet calls: a dead pet keeps the button from reading its health.)
	local realDead = rawget(_G, "UnitIsDead")
	rawset(_G, "UnitIsDead", function() return true end)
	with(scenario, { class = "HUNTER", race = "Human", known = { [883] = true, [982] = true, [136] = true } }, function(ns, UI)
		ns.OpenOptions("fight")
		if not UI.RowShown("appearance.mendInFight") then fail(scenario, "the Mend Pet switch is not shown") end
		-- Call, Revive and Mend Pet are on the prompt (Options/Shared.lua's HasPrompt
		-- counts pet care since the retail hunter's window was found cut down), so
		-- the fight's rota is a real choice for this hunter.
		if not UI.RowShown("appearance.fightRota") then fail(scenario, "the rota's switch is not shown for a hunter whose prompt is pet care") end
		local lines = {}
		local tip = { AddLine = function(_, text) lines[#lines + 1] = text end }
		ns.AddSettingsLine(tip, "appearance.mendInFight")
		if #lines ~= 1 then fail(scenario, "the Mend Pet tooltip has " .. #lines .. " settings lines") end
	end)
	rawset(_G, "UnitIsDead", realDead)
	scenario = "menupass-fight: a tooltip points only at a control that is shown"
	with(scenario, { class = "ROGUE", race = "Human" }, function(ns, UI)
		local lines = {}
		local tip = { AddLine = function(_, text) lines[#lines + 1] = text end }
		ns.AddSettingsLine(tip, "appearance.breakFree")
		if #lines ~= 0 then fail(scenario, "a human's tooltip points at " .. tostring(lines[1])) end
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
		if not normal then
			fail(scenario, "the usual window has no sidebar height")
			return
		end
		local normalCompact = fits(scenario, ns, UI, "usual size")
		local was = UI.HEIGHT
		UI.HEIGHT = UI.HEADER + (UI.strip.height or 0) + UI.FOOTER + normal - 12
		ns.RefreshOptionsDisplay()
		if not fits(scenario, ns, UI, "short of room") then
			fail(scenario, "with 12 less than the pages need they were not laid out smaller")
		end
		if not normalCompact and UI.side.bottom >= normal then
			fail(scenario, "the compact list is no shorter")
		end
		UI.HEIGHT = was
		ns.RefreshOptionsDisplay()
		if fits(scenario, ns, UI, "room again") ~= normalCompact then
			fail(scenario, "the sidebar did not restore the usual page list")
		end
	end)
end
