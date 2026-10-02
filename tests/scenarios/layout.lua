-- The options window's layout (Options/Window/Layout.lua) against the model.
--
-- The window draws what the layout places and nothing else, so a control the
-- layout forgets is a setting nobody can reach, and one placed twice is drawn
-- twice. For each class, once SetupOptions has built ns.optionsTable: every
-- entry in it is placed exactly once -- on a page, in the header, the status
-- strip or the footer, or as a section's header= -- or is listed in
-- `unplaced`. Every path the layout names is in the model for some class,
-- every header= names a header, the fold keys are unique and the sidebar's
-- groups name the pages.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local CLASSES = { "MAGE", "PRIEST", "PALADIN", "WARRIOR", "HUNTER", "ROGUE", "DRUID" }

-- Retired with the window (the information architecture, section 3): each
-- was a duplicate of a kept control or a pointer the layout says better. No
-- class's model may have one back, and the layout may not name one.
local RETIRED = {
	["general.startPos"] = true, ["general.startLocked"] = true,
	["general.onlyWhenReturning"] = true, ["general.offNotice"] = true,
	["general.lockNotice"] = true, ["appearance.test"] = true,
	["appearance.wordingNote"] = true, ["when.favoursHeader"] = true,
	["when.favoursNote"] = true, ["click.intro"] = true,
}

-- AceDBOptions' own entries. The mock's stand-in for the library builds only
-- its `desc`, so these are in the model in the game and not here.
local ACEDB = {
	["profiles.current"] = true, ["profiles.choosedesc"] = true, ["profiles.new"] = true,
	["profiles.choose"] = true, ["profiles.copydesc"] = true, ["profiles.copyfrom"] = true,
	["profiles.deldesc"] = true, ["profiles.delete"] = true, ["profiles.descreset"] = true,
	["profiles.reset"] = true,
}

-- The notes that keep their section on screen while the controls they stand
-- in for are hidden (the information architecture, 1.5 rule 4). Every other
-- note is attached and never does.
local STAND_IN = {
	["general.noBuffs"] = true, ["general.quickWhoSummary"] = true, ["who.autoNote"] = true,
	["who.strangersNote"] = true, ["advanced.noTargetNote"] = true, ["click.linesOff"] = true,
}

local GROUPS = { { "general" }, { "who", "skip", "when", "click", "appearance" }, { "profiles", "diagnostics" } }
local FLAGS = { indent = true, pair = true, standIn = true, lead = true, columns = true, widget = true }

-- What each of the frame's own slots has to be in the model.
local SLOT_TYPES = {
	["header.preview"] = "execute", ["header.enabled"] = "toggle", ["header.snooze"] = "execute",
	["header.snoozeTip"] = "description", ["strip.lock"] = "execute", ["strip.combat"] = "description",
	foldCaption = "description", ["footer.reset"] = "execute", ["footer.build"] = "description",
}

-- Every path the layout names, with where and as what. `uses[path]` is a list
-- of { where =, as = "item" | "header" | slot name, entry = item table }.
local function Collect(layout, problem)
	local uses = {}
	local function use(path, where, as, entry)
		if type(path) ~= "string" or not path:find("^%a+%.[%w_]+$") then
			problem(("%s names %s, which is not a tab.key path"):format(where, tostring(path)))
			return
		end
		uses[path] = uses[path] or {}
		table.insert(uses[path], { where = where, as = as, entry = entry or {} })
	end
	local frame = layout.header or {}
	use(frame.preview, "the header", "header.preview")
	use(frame.enabled, "the header", "header.enabled")
	for _, path in ipairs(frame.snooze or {}) do use(path, "the snooze menu", "header.snooze") end
	use(frame.snoozeTip, "the snooze tooltip", "header.snoozeTip")
	local strip = layout.strip or {}
	use(strip.lock, "the status strip", "strip.lock")
	for page, path in pairs(strip.combat or {}) do
		if not (layout.pages or {})[page] then problem("strip.combat names a page that is not there: " .. tostring(page)) end
		use(path, "the status strip", "strip.combat")
	end
	use(layout.foldCaption, "the fold caption", "foldCaption")
	local footer = layout.footer or {}
	use(footer.reset, "the footer", "footer.reset")
	use(footer.build, "the footer", "footer.build")
	for pageId, page in pairs(layout.pages or {}) do
		for s, section in ipairs(page.sections or {}) do
			local where = ("%s, section %d (%s)"):format(pageId, s, tostring(section.key))
			if section.header ~= nil then use(section.header, where, "header") end
			for _, item in ipairs(section.items or {}) do
				if type(item) == "string" then
					use(item, where, "item")
				elseif type(item) == "table" and item.composite then
					for _, path in ipairs(item.ids or {}) do use(path, where, "item", item) end
				elseif type(item) == "table" then
					use(item[1], where, "item", item)
				else
					problem(where .. " holds an item that is neither a path nor a table")
				end
			end
		end
	end
	for path in pairs(layout.unplaced or {}) do use(path, "unplaced", "unplaced") end
	return uses
end

-- The shape of the table itself: pages, groups, sections, keys and flags.
local function CheckShape(layout, problem)
	local pages, inGroups = layout.pages or {}, {}
	for g, group in ipairs(layout.groups or {}) do
		for i, pageId in ipairs(group) do
			if not pages[pageId] then problem("the sidebar names a page that is not there: " .. tostring(pageId)) end
			if inGroups[pageId] then problem("the sidebar lists " .. pageId .. " twice") end
			inGroups[pageId] = true
			if not (GROUPS[g] and GROUPS[g][i] == pageId) then
				problem(("the sidebar's group %d, place %d is %s, not %s"):format(g, i, pageId,
					tostring(GROUPS[g] and GROUPS[g][i])))
			end
		end
	end
	local keys = {}
	for pageId, page in pairs(pages) do
		if not inGroups[pageId] then problem("page " .. pageId .. " is in no sidebar group") end
		if type(page.title) ~= "string" or page.title == "" then problem("page " .. pageId .. " has no title") end
		local icon = page.icon
		if type(icon) == "function" then
			local ok, out = pcall(icon)
			if not ok then problem("page " .. pageId .. "'s icon threw: " .. tostring(out)) end
			icon = ok and out or nil
		end
		if type(icon) == "string" then
			if not icon:find("^Interface\\Icons\\") then problem("page " .. pageId .. "'s icon is not under Interface\\Icons: " .. icon) end
		elseif type(icon) ~= "number" then
			problem("page " .. pageId .. " has no icon")
		end
		for s, section in ipairs(page.sections or {}) do
			local where = pageId .. ", section " .. s
			if type(section.key) ~= "string" or section.key:sub(1, #pageId + 1) ~= pageId .. "." then
				problem(where .. " has no key of the form " .. pageId .. ".<name>: " .. tostring(section.key))
			elseif keys[section.key] then
				problem(where .. " has the key " .. section.key .. ", which " .. keys[section.key] .. " has too")
			else
				keys[section.key] = where
			end
			if section.header ~= nil and section.title ~= nil then problem(where .. " has both a header and a title") end
			if section.title ~= nil and (type(section.title) ~= "string" or section.title == "") then
				problem(where .. " has an empty title")
			end
			if type(section.items) ~= "table" or #section.items == 0 then problem(where .. " has no items") end
			for _, item in ipairs(section.items or {}) do
				if type(item) == "table" and not item.composite then
					for flag in pairs(item) do
						if flag ~= 1 and not FLAGS[flag] then
							problem(where .. ": " .. tostring(item[1]) .. " has a flag the window does not know: " .. tostring(flag))
						end
					end
					if item.columns ~= nil and not (type(item.columns) == "number" and item.columns >= 2) then
						problem(where .. ": " .. tostring(item[1]) .. " has columns = " .. tostring(item.columns))
					end
					if item.widget ~= nil and item.widget ~= "number" then
						problem(where .. ": " .. tostring(item[1]) .. " asks for a widget the window does not have: " .. tostring(item.widget))
					end
				elseif type(item) == "table" and item.composite ~= "never" then
					problem(where .. " has a composite the window does not build: " .. tostring(item.composite))
				end
			end
		end
	end
end

-- One class's model against the layout. `seen` collects every path found in
-- some class's model, for the check after the last class.
local function CheckClass(scenario, ns, layout, seen)
	local function problem(msg) fail(scenario, msg) end
	CheckShape(layout, problem)
	local uses = Collect(layout, problem)
	local model = {}
	for tab, group in pairs(ns.optionsTable.args) do
		for key, option in pairs(type(group) == "table" and group.args or {}) do
			if type(option) == "table" then model[tab .. "." .. key] = option end
		end
	end

	for path, option in pairs(model) do
		local placed, unplaced = 0, false
		local where = {}
		for _, use in ipairs(uses[path] or {}) do
			if use.as == "unplaced" then
				unplaced = true
			else
				placed = placed + 1
				where[#where + 1] = use.where
			end
		end
		if RETIRED[path] then
			problem(path .. " is in the model, which retired it")
		elseif unplaced and placed > 0 then
			problem(path .. " is placed (" .. table.concat(where, "; ") .. ") and listed as unplaced")
		elseif not unplaced and placed == 0 then
			problem(("%s (%s, %q) is in the model and has no place in the window"):format(path,
				tostring(option.type), type(option.name) == "string" and option.name or "?"))
		elseif placed > 1 then
			problem(path .. " is placed " .. placed .. " times: " .. table.concat(where, "; "))
		end
	end

	local standIns = {}
	for path, list in pairs(uses) do
		if RETIRED[path] then problem("the layout names " .. path .. ", which is retired") end
		local option = model[path]
		if option then seen[path] = true end
		for _, use in ipairs(list) do
			local kind = option and option.type
			local entry = use.entry
			if entry.standIn then standIns[path] = true end
			if use.as == "header" then
				if not option then
					problem(use.where .. " takes its title from " .. path .. ", which this class's model does not have")
				elseif kind ~= "header" then
					problem(use.where .. " takes its title from " .. path .. ", a " .. tostring(kind) .. ", not a header")
				end
			elseif option and use.as == "item" and kind == "header" then
				problem(use.where .. " places the header " .. path .. " as an item; a header is a section's title")
			elseif option and SLOT_TYPES[use.as] and kind ~= SLOT_TYPES[use.as] then
				problem(use.as .. " is " .. path .. ", a " .. tostring(kind) .. ", not a " .. SLOT_TYPES[use.as])
			end
			if option and (entry.standIn or entry.lead) and kind ~= "description" then
				problem(path .. " is a " .. tostring(kind) .. "; only a note can stand in or lead")
			end
			if option and entry.widget == "number" and kind ~= "range" then
				problem(path .. " is a " .. tostring(kind) .. "; only a range is a number box")
			end
			if option and entry.columns and not (entry.composite or kind == "toggle" or kind == "multiselect") then
				problem(path .. " is a " .. tostring(kind) .. "; columns are for switches and a multiselect")
			end
		end
	end
	for path in pairs(STAND_IN) do
		if not standIns[path] then problem(path .. " should stand in for the controls it replaces, and does not") end
	end
	for path in pairs(standIns) do
		if not STAND_IN[path] then problem(path .. " stands in for a control, and is not one of the notes that may") end
	end
	return uses
end

local seen, allUses, ran = {}, nil, 0
for _, class in ipairs(CLASSES) do
	Mock.reset()
	Mock.class = class
	local scenario = "every control has one place in the options window (" .. class .. ")"
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local layout = ns.WindowLayout
		if not layout then
			fail(scenario, "the toc loaded no ns.WindowLayout (Options/Window/Layout.lua)")
		elseif not (ns.optionsTable and ns.optionsTable.args) then
			fail(scenario, "SKIPPED -- no options table was built")
		else
			allUses = CheckClass(scenario, ns, layout, seen)
			ran = ran + 1
		end
	end
end
Mock.reset()

-- Only once every class has run: a path one class lacks (a priest's switches,
-- for a mage) is fine while some class has it.
if ran == #CLASSES and allUses then
	local scenario = "every path in the options window's layout is in the model"
	for path, list in pairs(allUses) do
		if not seen[path] and not RETIRED[path] then
			if ACEDB[path] then
				-- In the game's model, not the mock's: see ACEDB above.
			elseif list[1].as == "unplaced" then
				fail(scenario, "unplaced lists " .. path .. ", which no class's model has: drop it")
			else
				fail(scenario, list[1].where .. " places " .. path .. ", which no class's model has")
			end
		end
	end
end
