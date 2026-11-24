-- Plain English, part 2: no line calls a page a tab (the page comes from
-- Page.TabOf, in brackets), the launcher says the window's words, and no
-- tooltip says the game calls you resting.
--
-- ns.L is empty in English, so an L["..."] call reads back its own key: the
-- first scenario reads the L["..."] literals from the source files, and the
-- others read what the window and the menu show.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- A menu the way the client builds one, as menupass-snooze.lua has it.
local function newMenu(text, fn)
	local d = { text = text, fn = fn, items = {}, enabled = true }
	local function add(child)
		d.items[#d.items + 1] = child
		return child
	end
	function d:CreateTitle(t) return add({ text = t, title = true, items = {} }) end
	function d:CreateDivider() return add({ divider = true, items = {} }) end
	function d:CreateButton(t, f) return add(newMenu(t, f)) end
	function d:CreateCheckbox(t, get, set)
		local c = newMenu(t, set)
		c.kind, c.get = "checkbox", get
		return add(c)
	end
	function d:CreateRadio(t, get, set)
		local c = newMenu(t, set)
		c.kind, c.get = "radio", get
		return add(c)
	end
	return d
end

local function child(root, pattern)
	for _, item in ipairs(root and root.items or {}) do
		if item.text and tostring(item.text):find(pattern) then return item end
	end
end

-- ------------------------------------------------------------------ 1
do
	local scenario = "menupass-words2: no line calls a page a tab"
	local files = dofile(dir .. "/tests/addonfiles.lua")(dir)
	local checked = 0
	for _, path in ipairs(files) do
		-- Phrases.lua holds the lines said aloud (a bar tab, say), not the window's words.
		local top = not path:find("/", 1, true) and path ~= "Phrases.lua"
		if top or path:find("^Options/") or path:find("^Prompt/") then
			local f = io.open(dir .. "/" .. path, "r")
			if f then
				local body = f:read("*a")
				f:close()
				for key in body:gmatch('L%["(.-)"%]') do
					checked = checked + 1
					if (key:find(" tab.", 1, true) or key:find(" tab,", 1, true)
						or key:find(" tab (", 1, true) or key:find("on the %s tab", 1, true)
						or key:find("%s tab", 1, true)) then
						fail(scenario, path .. " calls a page a tab: " .. key)
					end
				end
			end
		end
	end
	if checked < 500 then fail(scenario, "SKIPPED -- only " .. checked .. " lines were read") end
end

-- ------------------------------------------------------------------ 2
do
	local scenario = "menupass-words2: the launcher uses the window's words"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local broker, real, opened = Mock.broker, MenuUtil, nil
		MenuUtil = {
			CreateContextMenu = function(owner, generator)
				local root = newMenu()
				generator(owner, root)
				opened = root
				return root
			end,
		}
		local ok, err = pcall(function()
			if not (broker and broker.OnClick) then
				fail(scenario, "SKIPPED -- no launcher was registered")
				return
			end
			broker.OnClick({}, "RightButton")
			local prompt = child(opened, "^Prompt$")
			if not prompt then fail(scenario, "SKIPPED -- the menu has no Prompt") return end
			if child(prompt, "^No flashes in a fight$") then fail(scenario, "the Prompt submenu still has No flashes in a fight, gone in 1.12") end
			local animations = child(prompt, "^Animations$")
			if not animations then
				fail(scenario, "the Prompt submenu does not read Animations")
			elseif not child(animations, "^Calm %(less movement%)$") then
				fail(scenario, "the Animations choices do not read Calm (less movement)")
			end
			if child(prompt, "^Effects$") then fail(scenario, "the Prompt submenu still reads Effects") end
		end)
		MenuUtil = real
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
		noErrors(scenario, ns)
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ 3
do
	local scenario = "menupass-words2: no tooltip says the game calls you resting"
	for _, class in ipairs({ "MAGE", "PRIEST", "ROGUE", "WARRIOR", "HUNTER", "PALADIN" }) do
		Mock.reset()
		Mock.class = class
		Mock.knownSpells = setmetatable({}, { __index = function() return true end })
		local ns = load(scenario)
		if ns then
			drive(scenario, ns)
			local function text(value)
				if type(value) == "function" then
					local ok, out = pcall(value)
					value = ok and out or nil
				end
				return type(value) == "string" and value or nil
			end
			local seen = 0
			local function walk(node, key)
				if type(node) ~= "table" then return end
				if key and node.type then
					local desc = text(node.desc)
					if desc then
						seen = seen + 1
						if desc:find("calls you resting", 1, true) then
							fail(scenario, ("%s: %s says the game calls you resting"):format(class, key))
						end
					end
				end
				for k, c in pairs(node.args or {}) do walk(c, k) end
			end
			walk(ns.optionsTable)
			if seen < 50 then fail(scenario, ("SKIPPED -- %s: only %d tooltips were read"):format(class, seen)) end
			noErrors(scenario, ns)
		end
		Mock.reset()
	end
end
