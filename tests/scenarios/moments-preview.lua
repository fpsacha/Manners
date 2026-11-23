-- "Show where the buttons for the moment sit" (Prompt/Moments.lua, Moments.Preview,
-- the Buttons for the moment section of the Look page and the launcher's menu):
-- every armed card lit for a few seconds out of a fight, marked PREVIEW, so the
-- player sees where each one sits and that it draws. Nothing casts from it: every
-- macro is taken off the buttons and every cover is up. Never in a fight, and a
-- fight that begins in the middle of one ends it before the lockdown.
--
-- Held to the mock's model of the client, not to the client (STATUS.md).
--
-- Every name starts with "moments-preview:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")
K.plain = true

local KNOWN = {}
for _, id in ipairs(K.MAGE_SPELLS) do KNOWN[#KNOWN + 1] = id end
for _, id in ipairs(K.WARD_SPELLS) do KNOWN[#KNOWN + 1] = id end

local function with(name, body, opts)
	opts = opts or {}
	opts.known = opts.known or KNOWN
	K.withMage(H, "moments-preview: " .. name, body, opts)
end
local function name(s) return "moments-preview: " .. s end
local function slot(ns, n) return ns.Moments:Slot(n) end

local function said()
	return table.concat(Mock.printed, "\n")
end

local function casts()
	return #(Mock.castLog or {})
end

local function option(ns, key)
	local look = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.appearance
	return look and look.args and look.args[key]
end

local function armedSlots(ns)
	local out = {}
	for n = 1, 11 do
		local s = slot(ns, n)
		if s and s.armed then out[#out + 1] = s end
	end
	return out
end

do
	local s = name("every armed card lights marked PREVIEW, then the drink, then all go dark and are armed again")
	with(s, function(ns)
		Mock.printed = {}
		if ns.Moments.Preview() ~= true then fail(s, "the preview did not start") return end
		if not said():find(ns.L["Showing where each button for the moment sits for a few seconds; nothing casts from them."], 1, true) then
			fail(s, "the preview says nothing: " .. said())
		end
		local list = armedSlots(ns)
		local calm, fight = 0, 0
		for _, c in ipairs(list) do
			local l = ns.Moments:Look(c.n)
			if c.row.calm then
				calm = calm + 1
				if c.button:IsShown() then fail(s, "the drink is up with the fight cards") end
			else
				fight = fight + 1
				if not c.button:IsShown() or c.face:GetAlpha() ~= 1 or K.shown(ns, c.n) ~= 1 then
					fail(s, c.row.key .. " is not lit in the preview")
				end
				if not l.tag:IsShown() or l.tag:GetText() ~= ns.L["PREVIEW"] then fail(s, c.row.key .. " is not marked as a preview") end
				if l.reason:GetText() == nil or l.reason:GetText() == "" then fail(s, c.row.key .. " says no reason") end
				if not l.flare:IsShown() then fail(s, c.row.key .. " does not pulse") end
			end
		end
		if fight < 5 or calm ~= 1 then fail(s, "the mage's cards: " .. fight .. " fight, " .. calm .. " calm") end
		-- Then the drink.
		Mock.runTimers(5.01)
		local drink = slot(ns, 11)
		if not drink.button:IsShown() or not ns.Moments:Look(11).tag:IsShown() then fail(s, "the drink does not follow") end
		for _, c in ipairs(list) do
			if not c.row.calm and c.button:IsShown() then fail(s, c.row.key .. " stays up in the drink's turn") end
		end
		-- Then everything goes dark and is armed again.
		Mock.runTimers(3.01)
		for _, c in ipairs(list) do
			if c.button:IsShown() or c.face:GetAlpha() ~= 0 or ns.Moments:Look(c.n).tag:IsShown() then
				fail(s, c.row.key .. " is still up after the preview")
			end
			if c.cover:IsShown() then fail(s, c.row.key .. " keeps its cover up") end
		end
		if K.macro(ns, 1) ~= "/stopcasting\n/cast Counterspell" then fail(s, "Counterspell is not armed again: " .. tostring(K.macro(ns, 1))) end
		if ns.Moments:Header():GetAttribute("state-mannersmoments") ~= "peace" then fail(s, "the header is not at peace") end
	end)
end

do
	local s = name("a click and a key press cast nothing from a preview")
	with(s, function(ns)
		ns.Moments.Preview()
		if K.macro(ns, 1) ~= nil or K.macro(ns, 3) ~= nil then fail(s, "a macro is still armed during the preview") end
		local before = casts()
		if K.click(ns, 3) == ns.Moments:Button(3) then fail(s, "a click reached the button") end
		Mock.pressBinding("CLICK MannersMoment1:LeftButton")
		Mock.pressBinding("CLICK MannersMoment3:LeftButton")
		if casts() ~= before then fail(s, "something was cast from the preview") end
		Mock.runTimers(9)
	end, { bindings = { ["F1"] = "CLICK MannersMoment1:LeftButton" } })
	s = name("with no key bound a click on a preview card is swallowed too")
	with(s, function(ns)
		ns.Moments.Preview()
		local before = casts()
		if K.click(ns, 1) ~= slot(ns, 1).cover then fail(s, "the cover did not take the click") end
		if casts() ~= before then fail(s, "a click cast from the preview") end
	end)
end

do
	local s = name("refused in a fight, and the options button is greyed")
	with(s, function(ns)
		K.pull(ns)
		Mock.printed = {}
		if ns.Moments.Preview() ~= false then fail(s, "a preview started in a fight") end
		if not said():find(ns.L["|cffff8080not during a fight|r -- the preview can be shown once it ends."], 1, true) then
			fail(s, "no refusal said: " .. said())
		end
		for _, c in ipairs(armedSlots(ns)) do
			if ns.Moments:Look(c.n).tag:IsShown() then fail(s, c.row.key .. " is marked as a preview in a fight") end
		end
		local def = option(ns, "momentPreview")
		if not def or def.type ~= "execute" then fail(s, "no execute option") return end
		if not def.disabled() then fail(s, "the button is not greyed in a fight") end
		K.release(ns)
		if def.disabled() then fail(s, "the button is greyed out of a fight with a button armed") end
	end)
end

do
	local s = name("a pull in the middle of a preview ends it before the lockdown and the macros are armed")
	with(s, function(ns)
		Mock.protectedCalls = {}
		ns.Moments.Preview()
		if K.macro(ns, 1) ~= nil then fail(s, "armed during the preview") end
		Mock.runTimers(1)
		K.pull(ns)
		if K.macro(ns, 1) ~= "/stopcasting\n/cast Counterspell" then fail(s, "not armed at the pull: " .. tostring(K.macro(ns, 1))) end
		K.cast(ns)
		K.tick(ns, 0.3)
		if slot(ns, 1).state ~= "lit" then fail(s, "not lit in the fight after a preview: " .. slot(ns, 1).state) end
		local before = casts()
		K.click(ns, 1)
		if casts() <= before then fail(s, "a click on the lit button cast nothing") end
		if ns.Moments:Look(1).tag:IsShown() then fail(s, "the preview's mark is still up in the fight") end
		-- The timers of the preview do nothing now.
		Mock.runTimers(10)
		if #Mock.protectedCalls > 0 then fail(s, "protected calls in the fight: " .. table.concat(Mock.protectedCalls, ", ")) end
		if slot(ns, 1).state ~= "lit" then fail(s, "a stale timer put the card away") end
	end)
end

do
	local s = name("nothing armed says so in one line")
	with(s, function(ns)
		Mock.printed = {}
		if ns.Moments.Preview() ~= false then fail(s, "a preview with nothing armed") end
		if not said():find(ns.L["No button for the moment is switched on for this character, so there is nothing to show."], 1, true) then
			fail(s, "no line: " .. said())
		end
		local def = option(ns, "momentPreview")
		if not def.disabled() then fail(s, "the options button is not greyed with nothing armed") end
	end, { preload = function(ns)
		for key in pairs(ns.defaults.profile.moments) do
			if type(ns.defaults.profile.moments[key]) == "boolean" then ns.defaults.profile.moments[key] = false end
		end
	end })
end

-- The launcher's menu: a context menu in the shape the client's MenuUtil hands the generator.
local function newMenu(text, fn)
	local d = { text = text, fn = fn, items = {}, enabled = true }
	local function add(c)
		d.items[#d.items + 1] = c
		return c
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

local function child(root, pattern)
	for _, item in ipairs(root and root.items or {}) do
		if item.text and tostring(item.text):find(pattern) then return item end
	end
end

local function menu()
	local real = MenuUtil
	local opened
	MenuUtil = {
		CreateContextMenu = function(owner, generator)
			local root = newMenu()
			generator(owner, root)
			opened = root
			return root
		end,
	}
	local ok, err = pcall(Mock.broker.OnClick, {}, "RightButton")
	MenuUtil = real
	if not ok then error("right-clicking threw -> " .. tostring(err)) end
	return opened
end

do
	local s = name("the launcher's menu has the entry, greyed in a fight; a character with nothing armed has none")
	with(s, function(ns)
		local root = menu()
		local entry = child(root, "^Show where the buttons for the moment sit")
		if not entry then fail(s, "no entry in the menu") return end
		if entry.enabled ~= true then fail(s, "the entry is greyed out of a fight") end
		Mock.printed = {}
		entry.fn()
		if not slot(ns, 3).button:IsShown() then fail(s, "the entry did not start the preview") end
		Mock.runTimers(9)
		K.pull(ns)
		local held = child(menu(), "^Show where the buttons for the moment sit")
		if not held or held.enabled ~= false then fail(s, "the entry is not greyed in a fight") end
		if not tostring(held.text):find("after the fight", 1, true) then fail(s, "the entry does not say why: " .. tostring(held.text)) end
	end)
	with(s, function(ns)
		if child(menu(), "^Show where the buttons for the moment sit") then fail(s, "a warrior is offered the entry") end
	end, { class = "WARRIOR" })
end
