-- The options menu's task-based hierarchy: overview, buffing, speech, prompt,
-- optional modules and support. The module pages join the Modules group, and
-- the short view still exposes the module switches with their explanations.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function session(scenario, class)
	Mock.reset()
	Mock.class = class or "HUNTER"
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	return ns
end

do
	local scenario = "menu-overhaul: sidebar categories group pages by task"
	local ns = session(scenario)
	if ns then
		local ids = {}
		for _, group in ipairs(ns.WindowLayout.groups) do
			for _, id in ipairs(group) do ids[#ids + 1] = id end
		end
		local got = table.concat(ids, " ")
		local want = "general who skip when click quiet fight appearance modules combat achievements pet self services profiles diagnostics"
		if got ~= want then fail(scenario, "the sidebar reads " .. got) end
		local labels = ns.WindowLayout.groupLabels or {}
		local expected = {
			[2] = "Buffing", [3] = "Speech", [4] = "Prompt",
			[5] = "Optional modules", [6] = "Support",
		}
		for group, text in pairs(expected) do
			if labels[group] ~= text then
				fail(scenario, ("group %d reads %s, not %s"):format(group, tostring(labels[group]), text))
			end
		end
		local modules = ns.WindowLayout.groups[5] or {}
		if table.concat(modules, " ") ~= "modules combat achievements pet self services" then
			fail(scenario, "module pages are outside the Optional modules group: " .. table.concat(modules, " "))
		end
	end
end

do
	local scenario = "menu-overhaul: module switches live on their own page"
	local ns = session(scenario)
	if ns then
		local UI = ns.WindowUI
		ns.OpenOptions("modules")
		if UI.PageOf("general.modulesCombat") ~= "modules"
			or UI.PageOf("general.modulesServices") ~= "modules" then
			fail(scenario, "module switches are not mapped to the Modules page")
		end
		for _, path in ipairs({
			"general.modulesCombat", "general.modulesCombatHelp",
			"general.modulesAchievements", "general.modulesAchievementsHelp",
			"general.modulesPets", "general.modulesPetsHelp",
			"general.modulesMyBuffs", "general.modulesMyBuffsHelp",
			"general.modulesServices", "general.modulesServicesHelp",
		}) do
			if not UI.RowShown(path) then fail(scenario, path .. " is not visible on Modules") end
		end
		ns.OpenOptions("general")
		if UI.RowShown("general.modulesCombat") or UI.RowShown("general.modulesServices") then
			fail(scenario, "Start here still holds module switches")
		end
	end
end

do
	local scenario = "menu-overhaul: module reload action comes before the switches"
	local ns = session(scenario)
	if ns then
		local sections = ns.WindowLayout.pages.modules.sections
		local reload, list
		for i, section in ipairs(sections) do
			if section.key == "modules.reload" then reload = i end
			if section.key == "modules.list" then list = i end
		end
		if not (reload and list and reload < list) then
			fail(scenario, "Reload now is below the module list, out of view after a toggle")
		end
	end
end

do
	local scenario = "menu-overhaul: the Modules page stays available in Simple view"
	local ns = session(scenario)
	if ns then
		local UI = ns.WindowUI
		ns.db.profile.menuView = "simple"
		ns.OpenOptions("modules")
		UI.Refresh()
		if not (UI.visiblePages or {}).modules then
			fail(scenario, "Modules leaves the sidebar in Simple view")
		end
		if not UI.RowShown("general.modulesCombat") or not UI.RowShown("general.modulesCombatHelp") then
			fail(scenario, "the Combat module and its explanation are hidden in Simple view")
		end
		if not UI.RowShown("general.modulesServices") then
			fail(scenario, "Services is hidden in Simple view")
		end
	end
end

do
	local scenario = "menu-overhaul: sidebar category labels paint above their groups"
	local ns = session(scenario, "MAGE")
	if ns then
		local UI = ns.WindowUI
		ns.SetMenuView("full")
		ns.OpenOptions("modules")
		local labels = UI.side and UI.side.labels or {}
		for _, group in ipairs({ 2, 3, 4, 5, 6 }) do
			local label = labels[group]
			if not (label and label:IsShown() and (label:GetText() or "") ~= "") then
				local visible = {}
				for _, id in ipairs(ns.WindowLayout.groups[group] or {}) do
					visible[#visible + 1] = id .. "=" .. tostring((UI.visiblePages or {})[id])
				end
				fail(scenario, ("category label %d is not painted (exists=%s, shown=%s, text=%s, pages=%s)")
					:format(group, tostring(label ~= nil), tostring(label and label:IsShown()),
						tostring(label and label:GetText()),
						table.concat(visible, ",")))
			end
		end

		do
			local scenario = "menu-overhaul: disabled modules keep their descriptions visible"
			Mock.reset()
			Mock.class = "MAGE"
			local ns = load(scenario, true)
			if ns then
				drive(scenario, ns)
				ns.Prompt:ExitTest()
				local UI = ns.WindowUI
				ns.OpenOptions("modules")
				for _, path in ipairs({
					"general.modulesCombatHelp", "general.modulesAchievementsHelp",
					"general.modulesPetsHelp", "general.modulesMyBuffsHelp",
					"general.modulesServicesHelp",
				}) do
					if not UI.RowShown(path) then
						fail(scenario, path .. " disappears when its module is off")
					end
				end
			end
		end
	end
end
