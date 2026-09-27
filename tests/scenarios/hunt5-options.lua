-- The fifth bug hunt, on the options page and the launcher's menu: the minimap
-- switch promising a compartment another addon has hidden, the Font dropdown
-- going blank on a font the client never registered, the colour-blind palette
-- counting its colours, and the Profiles submenu sorting by raw bytes.
--
-- Every scenario name starts with "hunt5-options:" so the mutations in
-- tests/mutations/hunt5-options.py can name the one that has to catch them.

local dir, H = ...
local fail, findOption = H.fail, H.findOption

-- The addon loaded and through its login, so the options page and the
-- launcher exist.
local function load(scenario)
	local ns = H.load(scenario)
	if ns then H.drive(scenario, ns) end
	return ns
end

local COMPARTMENT = "Manners stays in the addon compartment under the minimap either way."

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- ------------------------------------------------------------------ compartment
-- The minimap switch says hiding the button loses nothing only while the
-- compartment really holds Manners: registered there, and the compartment
-- itself on screen. BetterBlizzFrames and EnhanceQoL hide it.
local function compartmentFrame(canRegister)
	local frame = { registered = {}, shown = true }
	if canRegister then
		function frame:RegisterAddon(data) self.registered[#self.registered + 1] = data end
	end
	function frame:IsShown() return self.shown end
	function frame:Hide() self.shown = false end
	function frame:Show() self.shown = true end
	return frame
end

local function minimapDesc(ns)
	local toggle = findOption(ns.optionsTable, "minimap")
	if not toggle then return nil, "no Show minimap button control" end
	if type(toggle.desc) ~= "function" then return toggle.desc end
	local ok, desc = pcall(toggle.desc)
	if not ok then return nil, "the description threw: " .. tostring(desc) end
	return desc
end

Mock.reset()
do
	local scenario = "hunt5-options: the minimap switch promises the compartment only while it shows"
	local real = AddonCompartmentFrame
	AddonCompartmentFrame = compartmentFrame(true)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		if #AddonCompartmentFrame.registered ~= 1 then
			fail(scenario, "SKIPPED -- Manners was not registered in the compartment")
			return
		end
		local desc, why = minimapDesc(ns)
		if why then
			fail(scenario, why)
		elseif desc ~= COMPARTMENT then
			fail(scenario, "with the compartment showing, the switch says: " .. tostring(desc))
		end
		AddonCompartmentFrame:Hide()
		desc, why = minimapDesc(ns)
		if why then
			fail(scenario, why)
		elseif desc == COMPARTMENT or type(desc) ~= "string" or not desc:find("/manners", 1, true) then
			fail(scenario, "with the compartment hidden, the switch still says: " .. tostring(desc))
		end
		AddonCompartmentFrame:Show()
		if minimapDesc(ns) ~= COMPARTMENT then
			fail(scenario, "the compartment shown again, the switch no longer names it")
		end
		noErrors(scenario, ns)
	end)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	AddonCompartmentFrame = real
	Mock.reset()
end

Mock.reset()
do
	local scenario = "hunt5-options: the minimap switch promises no compartment Manners is not in"
	local real = AddonCompartmentFrame
	-- A frame that is there and showing, but would not take an entry.
	AddonCompartmentFrame = compartmentFrame(false)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local desc, why = minimapDesc(ns)
		if why then
			fail(scenario, why)
		elseif desc == COMPARTMENT or type(desc) ~= "string" or not desc:find("/manners", 1, true) then
			fail(scenario, "never registered, the switch still says: " .. tostring(desc))
		end
		noErrors(scenario, ns)
	end)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	AddonCompartmentFrame = real
	Mock.reset()
end

-- ------------------------------------------------------------------ font
-- LibSharedMedia registers "Friz Quadrata TT", the default font, on none of
-- koKR, zhCN and zhTW, so the dropdown lists the chosen font itself.
Mock.reset()
do
	local scenario = "hunt5-options: the Font dropdown keeps a font nobody registered"
	Mock.locale = "koKR"
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		local lsm = LibStub("LibSharedMedia-3.0")
		lsm.media.font = { ["2002"] = "Fonts\\2002.TTF" }
		local chosen = ns.db.profile.prompt.font
		if chosen ~= "Friz Quadrata TT" then
			fail(scenario, "SKIPPED -- the default font is " .. tostring(chosen))
			return
		end
		local option = findOption(ns.optionsTable, "font")
		local values = option and type(option.values) == "function" and option.values() or nil
		if not values then
			fail(scenario, "no Font dropdown to read")
			return
		end
		local label = values[chosen]
		if type(label) ~= "string" then
			fail(scenario, "the chosen font is missing from the Font dropdown, which draws blank")
		elseif label == chosen or not label:find(chosen, 1, true) or not label:find("|cff808080", 1, true) then
			fail(scenario, "the unregistered font is labelled " .. label)
		end
		if values["2002"] ~= "2002" then
			fail(scenario, "a registered font is labelled " .. tostring(values["2002"]))
		end
		noErrors(scenario, ns)
	end)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	Mock.locale = nil
	Mock.reset()
end

-- ------------------------------------------------------------------ palette
-- The colour-blind palette's description stays true however many reasons the
-- prompt paints, so it does not count them.
Mock.reset()
do
	local scenario = "hunt5-options: the colour-blind description counts no colours"
	local ns = load(scenario)
	if ns then
		local option = findOption(ns.optionsTable, "reasonPalette")
		local desc = option and option.desc
		if type(desc) == "function" then desc = desc() end
		if type(desc) ~= "string" then
			fail(scenario, "no Reason colours description to read")
		elseif desc:find("four", 1, true) or not desc:find("colour-blind", 1, true) then
			fail(scenario, "the Reason colours description reads: " .. desc)
		end
	end
	Mock.reset()
end

-- It claims no more than the palette does: every reason the queue writes is
-- read back in the colour-blind set, and askers drawn in the passers-by colour
-- must be owned up to, while askers given a colour of their own must not be
-- said to share one.
Mock.reset()
do
	local scenario = "hunt5-options: the colour-blind description admits the colours it shares"
	local ns = load(scenario)
	if ns then
		local option = findOption(ns.optionsTable, "reasonPalette")
		local desc = option and option.desc
		if type(desc) == "function" then desc = desc() end
		local p = ns.db.profile.prompt
		p.accentByReason, p.reasonPalette = true, "colourblind"
		local function colour(reason) return { ns.Prompt:AccentColor(reason) } end
		local asked, nearby = colour("asked"), colour("nearby")
		local shared = math.abs(asked[1] - nearby[1]) + math.abs(asked[2] - nearby[2])
			+ math.abs(asked[3] - nearby[3]) < 0.05
		if type(desc) ~= "string" then
			fail(scenario, "no Reason colours description to read")
		elseif shared and (desc:find("every", 1, true) or not desc:find("asked", 1, true)) then
			fail(scenario, "askers share the passers-by colour, yet the description reads: " .. desc)
		elseif not shared and desc:find("share", 1, true) then
			fail(scenario, "askers have a colour of their own, yet the description reads: " .. desc)
		end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ profiles
-- The same menu shape minimap.lua hands the generator.
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
	function d:SetEnabled(on) self.enabled = on and true or false end
	function d:SetTooltip(fn) self.tooltip = fn end
	return d
end

-- Folds the Cyrillic capitals, А-П to а-п and Р-Я to р-я, then ASCII, the
-- way the client's strcmputf8i folds every script.
local function foldCyrillic(s)
	s = s:gsub("\208([\144-\175])", function(c)
		local b = c:byte()
		if b < 160 then return "\208" .. string.char(b + 32) end
		return "\209" .. string.char(b - 32)
	end)
	return s:lower()
end

Mock.reset()
do
	local scenario = "hunt5-options: the Profiles submenu sorts names in any language"
	local ANNA, BORIS, YANA = "\208\144\208\189\208\189\208\176", "\208\177\208\190\209\128\208\184\209\129",
		"\208\175\208\189\208\176"
	Mock.locale = "ruRU"
	local realFold, realMenu = strcmputf8i, MenuUtil
	strcmputf8i = function(a, b)
		a, b = foldCyrillic(a), foldCyrillic(b)
		if a == b then return 0 end
		return a < b and -1 or 1
	end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		ns.db.GetProfiles = function(_, t)
			t = t or {}
			t[1], t[2], t[3] = YANA, BORIS, ANNA
			return t, 3
		end
		ns.db.GetCurrentProfile = function() return ANNA end
		local opened
		MenuUtil = {
			CreateContextMenu = function(owner, generator)
				local root = newMenu()
				generator(owner, root)
				opened = root
				return root
			end,
		}
		if not (Mock.broker and Mock.broker.OnClick) then
			fail(scenario, "SKIPPED -- no launcher to right-click")
			return
		end
		Mock.broker.OnClick({}, "RightButton")
		-- Found by what it holds: the submenu's own title is in Russian here.
		local list
		for _, item in ipairs(opened and opened.items or {}) do
			for _, sub in ipairs(item.items or {}) do
				if sub.text == ANNA then list = item end
			end
		end
		if not list then
			fail(scenario, "SKIPPED -- no Profiles submenu in the menu")
			return
		end
		-- Reported in Latin letters: a Windows console cannot print Cyrillic.
		local latin = { [ANNA] = "Anna", [BORIS] = "boris", [YANA] = "Yana" }
		local got = {}
		for _, sub in ipairs(list.items) do got[#got + 1] = latin[sub.text] or "?" end
		if table.concat(got, " / ") ~= "Anna / boris / Yana" then
			fail(scenario, "the profiles are listed as " .. table.concat(got, " / "))
		end
		noErrors(scenario, ns)
	end)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	strcmputf8i, MenuUtil = realFold, realMenu
	Mock.locale = nil
	Mock.reset()
end
