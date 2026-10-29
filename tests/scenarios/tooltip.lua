-- The tooltip over the prompt and over the names in its list: how much it says
-- (Full, Short, only while holding Shift, Off), where it goes (beside the
-- prompt, on the side with more room, or where the game puts tooltips), and
-- what a player's saved settings, a pasted profile and a translation do to it.
-- Prompt/Button.lua; the settings are prompt.tooltip and prompt.tooltipPosition.
--
-- Every scenario name starts with "tooltip:" so the mutations in
-- tests/mutations/tooltip.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" },
	nameplate3 = { "Cara", "Close" } }

-- ------------------------------------------------------------------ the world

-- The tooltip as the client keeps it: who owns it, and whether it was hidden.
-- Held while `body` runs, put back after. The lines are Mock.tooltip's.
local function tracked(body)
	local owner
	local realSetOwner, realIsOwned, realHide = GameTooltip.SetOwner, GameTooltip.IsOwned, GameTooltip.Hide
	GameTooltip.SetOwner = function(self, frame, anchor)
		realSetOwner(self, frame, anchor)
		owner = frame
	end
	GameTooltip.IsOwned = function(_, frame) return owner ~= nil and owner == frame end
	GameTooltip.Hide = function(self)
		owner = nil
		return realHide(self)
	end
	local ok, err = pcall(body)
	GameTooltip.SetOwner, GameTooltip.IsOwned, GameTooltip.Hide = realSetOwner, realIsOwned, realHide
	if not ok then error(err, 0) end
end

-- A session: three strangers on nameplates, Anna owed a favour, the list on with
-- three rows and the click option on, the prompt locked and up, on a 1920x1080
-- screen. `opts.edit(ns, p)` changes the settings before the first scan.
-- `body` gets the loaded addon, the prompt's regions and its settings.
local function session(scenario, opts, body)
	if type(opts) == "function" then opts, body = nil, opts end
	opts = opts or {}
	Mock.reset()
	Mock.geometry = { width = 1920, height = 1080 }
	Mock.class = "MAGE"
	local restore = H.strangers(PEOPLE)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		Mock.timers = {}
		local p = ns.db.profile.prompt
		p.showQueue, p.queueRows, p.clickRows, p.locked = true, 3, true, true
		if opts.edit then opts.edit(ns, p) end
		H.owe(ns, "Anna Aim")
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		tracked(function() body(ns, ns.Prompt:Regions(), p) end)
		Mock.inCombat = false
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	Mock.modifiers = {}
	Mock.geometry = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function blob() return table.concat(Mock.tooltip or {}, " / ") end

-- The cursor onto a frame: the lines the tooltip says, nil when it is not up.
local function hover(frame)
	Mock.tooltip = {}
	frame.scripts.OnEnter(frame)
	if not GameTooltip:IsOwned(frame) then return nil end
	return blob()
end

local function leave(frame) frame.scripts.OnLeave(frame) end

-- The Shift key going down or up, as the client announces it.
local function shift(down)
	Mock.modifiers.shift = down
	return Mock.frameEvent("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
end

local function has(text, part) return text ~= nil and text:find(part, 1, true) ~= nil end

-- What marks the full tooltip and what marks the short one.
local FULL_MARKS = { "Manners", "Click to cast", "Right-click to skip this one.", "Shift-right-click" }
local HINT = "Hold Shift for more"

local function isFull(text)
	if not text then return false end
	for _, mark in ipairs(FULL_MARKS) do
		if not has(text, mark) then return false end
	end
	return not has(text, HINT)
end

local function isShort(text)
	return text ~= nil and has(text, HINT) and not has(text, "Click to cast") and not has(text, "Manners /")
end

local function row(r, i) return r.rowButtons[i] end

-- ------------------------------------------------------------------ defaults

do
	local scenario = "tooltip: a new profile gets the short tooltip beside the prompt"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		ns.addon:OnInitialize()
		local p = ns.db.profile.prompt
		if p.tooltip ~= "short" then
			fail(scenario, "the tooltip setting starts as " .. tostring(p.tooltip) .. ", not short")
		end
		if p.tooltipPosition ~= "beside" then
			fail(scenario, "the tooltip position starts as " .. tostring(p.tooltipPosition) .. ", not beside")
		end
	end
	Mock.reset()
end

do
	local scenario = "tooltip: an old saved profile without the keys gets the short tooltip"
	Mock.reset()
	Mock.sv = {}
	local saved = H.savedProfile(scenario, function(profile)
		-- As an earlier release wrote it: a prompt table that has never heard of either.
		profile.prompt = { scale = 1.25, locked = true }
	end)
	local ns = saved and load(scenario)
	if ns then
		ns.addon:OnInitialize()
		local p = ns.db.profile.prompt
		if p.tooltip ~= "short" or p.tooltipPosition ~= "beside" then
			fail(scenario, ("an old profile reads %s and %s"):format(tostring(p.tooltip), tostring(p.tooltipPosition)))
		end
		if p.scale ~= 1.25 then fail(scenario, "the old profile's own scale was lost: " .. tostring(p.scale)) end
	end
	Mock.reset()
end

do
	local scenario = "tooltip: a damaged setting is put back by ClampSettings"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		ns.addon:OnInitialize()
		local p = ns.db.profile.prompt
		for _, junk in ipairs({ 7, true, "banana", {}, "FULL" }) do
			p.tooltip, p.tooltipPosition = junk, junk
			ns.ClampSettings()
			if p.tooltip ~= "short" then
				fail(scenario, ("tooltip %s was repaired to %s, not short"):format(tostring(junk), tostring(p.tooltip)))
			end
			if p.tooltipPosition ~= "beside" then
				fail(scenario, ("position %s was repaired to %s, not beside"):format(tostring(junk), tostring(p.tooltipPosition)))
			end
		end
		for _, value in ipairs({ "full", "short", "shift", "off" }) do
			p.tooltip = value
			ns.ClampSettings()
			if p.tooltip ~= value then fail(scenario, value .. " was not kept: " .. tostring(p.tooltip)) end
		end
		for _, value in ipairs({ "beside", "game" }) do
			p.tooltipPosition = value
			ns.ClampSettings()
			if p.tooltipPosition ~= value then fail(scenario, value .. " was not kept: " .. tostring(p.tooltipPosition)) end
		end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ the amount

for _, case in ipairs({ { "full", isFull }, { "short", isShort } }) do
	local scenario = "tooltip: " .. case[1] .. " on the prompt says what that setting says"
	session(scenario, { edit = function(_, p) p.tooltip = case[1] end }, function(ns)
		local button = ns.Prompt:GetButton()
		local said = hover(button)
		if not said then
			fail(scenario, "no tooltip over the prompt")
		elseif not case[2](said) then
			fail(scenario, "the " .. case[1] .. " tooltip reads: " .. said)
		end
		if case[1] == "short" and said and not has(said, "Buffed you -- return the favour.") then
			fail(scenario, "the short tooltip does not say why: " .. said)
		end
		if said and not has(said, "Anna Aim") then
			fail(scenario, "the tooltip does not name who the prompt is on: " .. said)
		end
		if case[1] == "short" and said then
			-- The name and spell, one line of why, one grey hint: three lines.
			if #Mock.tooltip ~= 3 then
				fail(scenario, ("the short tooltip is %d lines, not three: %s"):format(#Mock.tooltip, said))
			end
			if not has(Mock.tooltip[1], "Arcane Intellect") then
				fail(scenario, "the short tooltip does not name the spell: " .. Mock.tooltip[1])
			end
		end
	end)
end

do
	local scenario = "tooltip: the short tooltip is for a group cast too"
	session(scenario, { edit = function(_, p) p.tooltip = "short" end }, function(ns)
		local top = ns.Prompt.state.current
		if not (top and top.buff) then fail(scenario, "SKIPPED -- the prompt is on nobody") return end
		local group = {}
		for k, v in pairs(top) do group[k] = v end
		group.groupCast = { missing = 4, low = 0, label = "your party", members = {}, reagentWaived = true }
		ns.Prompt:ApplyTarget(group)
		local button = ns.Prompt:GetButton()
		local said = hover(button)
		if not (has(said, "4 in your party are missing") and has(said, HINT)) then
			fail(scenario, "the short tooltip over a group cast reads: " .. tostring(said))
		elseif has(said, "One cast gives it to") or has(said, "No reagent needed") then
			fail(scenario, "the short tooltip over a group cast says more than who needs it: " .. said)
		end
		ns.db.profile.prompt.tooltip = "full"
		leave(button)
		said = hover(button)
		if not (has(said, "One cast gives it to everybody in your party.") and has(said, "No reagent needed.")) then
			fail(scenario, "the full tooltip over a group cast reads: " .. tostring(said))
		end
	end)
end

do
	local scenario = "tooltip: off shows nothing over the prompt"
	session(scenario, { edit = function(_, p) p.tooltip = "off" end }, function(ns)
		local button = ns.Prompt:GetButton()
		local said = hover(button)
		if said or #Mock.tooltip > 0 then fail(scenario, "off still said: " .. blob()) end
		shift(true)
		if GameTooltip:IsOwned(button) or #Mock.tooltip > 0 then
			fail(scenario, "off said something once Shift was held: " .. blob())
		end
		shift(false)
	end)
end

-- ------------------------------------------------------------------ Shift

do
	local scenario = "tooltip: only while holding Shift shows nothing until Shift is held"
	session(scenario, { edit = function(_, p) p.tooltip = "shift" end }, function(ns)
		local button = ns.Prompt:GetButton()
		if hover(button) or #Mock.tooltip > 0 then fail(scenario, "something showed without Shift: " .. blob()) end
		shift(true)
		if not isFull(blob()) or not GameTooltip:IsOwned(button) then
			fail(scenario, "holding Shift did not open the full tooltip: " .. blob())
		end
		shift(false)
		if GameTooltip:IsOwned(button) then fail(scenario, "the tooltip stayed up once Shift was let go") end
		-- Entering with Shift already held shows it at once.
		leave(button)
		Mock.modifiers.shift = true
		local said = hover(button)
		if not isFull(said) then fail(scenario, "entering with Shift held did not show the full tooltip: " .. tostring(said)) end
		leave(button)
		Mock.modifiers.shift = false
	end)
end

do
	local scenario = "tooltip: Shift switches the short tooltip to the full one and back, live"
	session(scenario, { edit = function(_, p) p.tooltip = "short" end }, function(ns)
		local button = ns.Prompt:GetButton()
		if not isShort(hover(button)) then fail(scenario, "not short to begin with: " .. blob()) end
		shift(true)
		if not isFull(blob()) then fail(scenario, "Shift held did not give the full tooltip: " .. blob()) end
		shift(false)
		if not isShort(blob()) then fail(scenario, "Shift let go did not go back to the short one: " .. blob()) end
		-- A key that is not Shift changes nothing: the tooltip is not built again.
		Mock.tooltip = { "untouched" }
		Mock.frameEvent("MODIFIER_STATE_CHANGED", "LCTRL", 1)
		if Mock.tooltip[1] ~= "untouched" then fail(scenario, "another modifier rebuilt the tooltip: " .. blob()) end
	end)
end

do
	local scenario = "tooltip: Shift is watched only while the cursor is on the prompt"
	session(scenario, { edit = function(_, p) p.tooltip = "short" end }, function(ns)
		local button = ns.Prompt:GetButton()
		if shift(true) ~= 0 then fail(scenario, "Shift was watched before the cursor came") end
		shift(false)
		hover(button)
		if shift(true) ~= 1 then fail(scenario, "Shift was not watched with the cursor on the prompt") end
		shift(false)
		leave(button)
		Mock.tooltip = {}
		if shift(true) ~= 0 then fail(scenario, "Shift was still watched after the cursor left") end
		if #Mock.tooltip > 0 or GameTooltip:IsOwned(button) then
			fail(scenario, "a tooltip came up after the cursor left: " .. blob())
		end
		shift(false)
	end)
end

for _, mode in ipairs({ "full", "off" }) do
	local scenario = "tooltip: " .. mode .. " has nothing to watch Shift for"
	session(scenario, { edit = function(_, p) p.tooltip = mode end }, function(ns)
		local button = ns.Prompt:GetButton()
		hover(button)
		if shift(true) ~= 0 then fail(scenario, "Shift was watched under " .. mode) end
		shift(false)
		leave(button)
	end)
end

-- ------------------------------------------------------------------ the list

for _, case in ipairs({ { "full", isFull }, { "short", isShort } }) do
	local scenario = "tooltip: " .. case[1] .. " on a name in the list says what that setting says"
	session(scenario, { edit = function(_, p) p.tooltip = case[1] end }, function(ns, r)
		local b = row(r, 2)
		local entry = b and b.mannersRow and b.mannersRow.entry
		if not entry then fail(scenario, "SKIPPED -- the second name is not a button") return end
		local said = hover(b)
		if not said then
			fail(scenario, "no tooltip over the name")
		elseif not case[2](said) then
			fail(scenario, "the " .. case[1] .. " tooltip over a name reads: " .. said)
		elseif not has(said, ns.ShortName and ns.ShortName(entry.name) or entry.name) and not has(said, entry.name) then
			fail(scenario, "the tooltip over a name is not about them: " .. said)
		end
	end)
end

do
	local scenario = "tooltip: off and only-with-Shift apply to the names in the list"
	for _, mode in ipairs({ "off", "shift" }) do
		session(scenario, { edit = function(_, p) p.tooltip = mode end }, function(ns, r)
			local b = row(r, 2)
			if not (b and b.mannersRow and b.mannersRow.entry) then
				fail(scenario, "SKIPPED -- the second name is not a button")
				return
			end
			if hover(b) or #Mock.tooltip > 0 then fail(scenario, mode .. " said over a name: " .. blob()) end
			if mode == "shift" then
				shift(true)
				if not (GameTooltip:IsOwned(b) and isFull(blob())) then
					fail(scenario, "Shift held over a name did not open the full tooltip: " .. blob())
				end
				shift(false)
				if GameTooltip:IsOwned(b) then fail(scenario, "the tooltip over a name stayed up once Shift was let go") end
			end
			leave(b)
		end)
	end
end

do
	local scenario = "tooltip: Shift over a name in the list works live and stops on leave"
	session(scenario, { edit = function(_, p) p.tooltip = "short" end }, function(ns, r)
		local b = row(r, 2)
		if not (b and b.mannersRow and b.mannersRow.entry) then
			fail(scenario, "SKIPPED -- the second name is not a button")
			return
		end
		if not isShort(hover(b)) then fail(scenario, "not short to begin with: " .. blob()) end
		shift(true)
		if not isFull(blob()) then fail(scenario, "Shift held over a name did not give the full tooltip: " .. blob()) end
		shift(false)
		if not isShort(blob()) then fail(scenario, "Shift let go over a name did not go back: " .. blob()) end
		leave(b)
		if shift(true) ~= 0 then fail(scenario, "Shift was still watched after leaving the name") end
		shift(false)
		-- Moving from a name to the prompt hands the watch over, not drops it.
		local button = ns.Prompt:GetButton()
		hover(b)
		leave(b)
		hover(button)
		if shift(true) ~= 1 then fail(scenario, "Shift was not watched on the prompt after the name") end
		shift(false)
		leave(button)
		if shift(true) ~= 0 then fail(scenario, "Shift was still watched after the prompt") end
		shift(false)
	end)
end

-- ------------------------------------------------------------------ the drag

for _, mode in ipairs({ "full", "short", "shift", "off" }) do
	local scenario = "tooltip: the drag tooltip stays under " .. mode
	session(scenario, { edit = function(_, p) p.tooltip = mode end }, function(ns)
		ns.addon:HandleSlash("unlock")
		ns.addon:Tick()
		local button = ns.Prompt:GetButton()
		local said = hover(button)
		for _, want in ipairs({ "Drag to move", "Let go and it locks itself", "not buffing while unlocked" }) do
			if not has(said, want) then
				fail(scenario, ("the drag tooltip does not say %q: %s"):format(want, tostring(said)))
			end
		end
		if has(said, HINT) then fail(scenario, "the drag tooltip carries the Shift hint: " .. said) end
		ns.addon:HandleSlash("lock")
	end)
end

-- ------------------------------------------------------------------ a fight

for _, mode in ipairs({ "full", "short", "shift", "off" }) do
	local scenario = "tooltip: nothing shows in a fight under " .. mode
	session(scenario, { edit = function(_, p) p.tooltip = mode end }, function(ns, r)
		local button = ns.Prompt:GetButton()
		local b = row(r, 2)
		Mock.inCombat = true
		Mock.protectedCalls = {}
		if hover(button) or #Mock.tooltip > 0 then fail(scenario, "the prompt's tooltip came up in a fight: " .. blob()) end
		if b and hover(b) or #Mock.tooltip > 0 then fail(scenario, "a name's tooltip came up in a fight: " .. blob()) end
		shift(true)
		if #Mock.tooltip > 0 then fail(scenario, "Shift brought a tooltip up in a fight: " .. blob()) end
		shift(false)
		if #Mock.protectedCalls > 0 then
			fail(scenario, "the tooltip touched a protected frame in a fight: " .. table.concat(Mock.protectedCalls, ", "))
		end
		leave(button)
		if b then leave(b) end
		Mock.inCombat = false
	end)
end

do
	local scenario = "tooltip: hovering and Shift never write the button's attributes"
	session(scenario, { edit = function(_, p) p.tooltip = "short" end }, function(ns, r)
		local button = ns.Prompt:GetButton()
		local b = row(r, 2)
		local writes = 0
		local frames = { button, b }
		local real = {}
		for i, f in ipairs(frames) do
			real[i] = f.SetAttribute
			f.SetAttribute = function(self, ...) writes = writes + 1 return real[i](self, ...) end
		end
		for _, mode in ipairs({ "short", "shift", "full", "off" }) do
			ns.db.profile.prompt.tooltip = mode
			for _, f in ipairs(frames) do
				hover(f)
				shift(true)
				shift(false)
				leave(f)
			end
		end
		for i, f in ipairs(frames) do f.SetAttribute = real[i] end
		if writes > 0 then fail(scenario, "hovering or Shift wrote the secure attributes " .. writes .. " times") end
	end)
end

-- ------------------------------------------------------------------ where

-- The point a tooltip was last given: { point, relativeTo, relPoint, x, y }.
local function anchorOf() return GameTooltip.points and GameTooltip.points[1] end

-- Where the prompt sits for each case, its list's side, and the side the
-- tooltip should take: the one with more room, which is above for a prompt in
-- the lower half of the screen and below for the upper.
local PLACES = {
	{ name = "low on the screen", point = "BOTTOM", y = 300, listAbove = true, above = true },
	{ name = "just under the middle", point = "BOTTOM", y = 480, listAbove = false, above = true },
	{ name = "just over the middle", point = "BOTTOM", y = 560, listAbove = false, above = false },
	{ name = "high on the screen", point = "TOP", y = -100, listAbove = false, above = false },
}

for _, place in ipairs(PLACES) do
	local scenario = "tooltip: beside the prompt takes the roomier side, " .. place.name
	session(scenario, { edit = function(_, p)
		p.point, p.relPoint, p.x, p.y = place.point, place.point, 0, place.y
		p.tooltip, p.tooltipPosition = "full", "beside"
	end }, function(ns, r, p)
		local button = ns.Prompt:GetButton()
		if ns.Prompt.state.queueAbove ~= place.listAbove then
			fail(scenario, "SKIPPED -- the list hangs " .. (ns.Prompt.state.queueAbove and "above" or "below")
				.. " here, not " .. (place.listAbove and "above" or "below"))
			return
		end
		-- The prompt itself, then each name in the list: all anchor to the prompt.
		local listed = 0
		for _, fs in ipairs(r.rows) do
			if tostring(fs:GetText() or "") ~= "" then listed = listed + 1 end
		end
		if listed < 2 then fail(scenario, "SKIPPED -- only " .. listed .. " names are listed") return end
		for _, target in ipairs({ button, row(r, 1), row(r, 2) }) do
			if not hover(target) then
				fail(scenario, "no tooltip")
			else
				local at = anchorOf()
				local want = place.above and { "BOTTOM", "TOP" } or { "TOP", "BOTTOM" }
				if Mock.tooltipAnchor ~= "ANCHOR_NONE" then
					fail(scenario, "the tooltip is anchored " .. tostring(Mock.tooltipAnchor))
				elseif not at or at[1] ~= want[1] or at[2] ~= button or at[3] ~= want[2] then
					fail(scenario, ("the tooltip sits %s of %s, not %s of the prompt"):format(
						tostring(at and at[1]), tostring(at and at[3]), want[1]))
				else
					-- Clear of the prompt, and of its list when the list is on that side.
					local rows = listed * (p.fontSize + 4)
					local offset = place.above and at[5] or -at[5]
					local need = place.listAbove == place.above and rows or 0
					if offset < need then
						fail(scenario, ("the tooltip is %s px off the prompt; its list takes %s"):format(offset, need))
					end
					if offset < 1 then fail(scenario, "the tooltip touches the prompt") end
					-- And not so far off that it is nowhere near it.
					if offset > need + 40 then
						fail(scenario, ("the tooltip floats %s px off the prompt; the list takes %s"):format(offset, need))
					end
				end
				leave(target)
			end
		end
	end)
end

do
	local scenario = "tooltip: where the game shows tooltips hands the placing to the client"
	session(scenario, { edit = function(_, p) p.tooltip, p.tooltipPosition = "full", "game" end }, function(ns, r)
		local button = ns.Prompt:GetButton()
		for _, target in ipairs({ button, row(r, 2) }) do
			Mock.tooltipDefault = false
			if not hover(target) then
				fail(scenario, "no tooltip")
			else
				if not Mock.tooltipDefault then fail(scenario, "the client's default anchor was not used") end
				if Mock.tooltipOwner ~= target then fail(scenario, "the tooltip's owner is not the hovered frame") end
				local at = anchorOf()
				if not at or at[2] == button then fail(scenario, "the tooltip is still hung on the prompt") end
			end
			leave(target)
		end
	end)
end

do
	local scenario = "tooltip: a client without a default anchor falls back to the old one"
	session(scenario, { edit = function(_, p) p.tooltip, p.tooltipPosition = "full", "game" end }, function(ns)
		local button = ns.Prompt:GetButton()
		local real = GameTooltip_SetDefaultAnchor
		GameTooltip_SetDefaultAnchor = nil
		local ok, said = pcall(hover, button)
		GameTooltip_SetDefaultAnchor = real
		if not ok then fail(scenario, "threw: " .. tostring(said)) elseif not isFull(said) then
			fail(scenario, "no full tooltip without the default anchor: " .. tostring(said))
		end
	end)
end

do
	local scenario = "tooltip: the position setting is read at each hover"
	session(scenario, { edit = function(_, p) p.tooltip, p.tooltipPosition = "full", "beside" end }, function(ns)
		local button = ns.Prompt:GetButton()
		local p = ns.db.profile.prompt
		hover(button)
		if Mock.tooltipDefault then fail(scenario, "beside used the default anchor") end
		leave(button)
		p.tooltipPosition = "game"
		hover(button)
		if not Mock.tooltipDefault then fail(scenario, "game did not use the default anchor") end
		leave(button)
		p.tooltipPosition = "beside"
		hover(button)
		if Mock.tooltipDefault then fail(scenario, "back to beside still used the default anchor") end
		leave(button)
	end)
end

-- ------------------------------------------------------------------ options

do
	local scenario = "tooltip: the Look tab offers the choices, short first, and they write the profile"
	session(scenario, function(ns)
		local tab = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.appearance
		local args = tab and tab.args
		if not (args and args.tooltip and args.tooltipPosition) then
			fail(scenario, "the Look tab has no tooltip controls")
			return
		end
		local tip, where = args.tooltip, args.tooltipPosition
		local want = { "short", "full", "shift", "off" }
		for i, key in ipairs(want) do
			if not (tip.sorting and tip.sorting[i] == key and tip.values[key]) then
				fail(scenario, "the tooltip choices are not " .. table.concat(want, ", "))
				break
			end
		end
		for _, key in ipairs({ "beside", "game" }) do
			if not where.values[key] then fail(scenario, "no position choice " .. key) end
		end
		if tip.values.short ~= "Short (hold Shift for more)" or tip.values.shift ~= "Only while holding Shift"
			or tip.values.off ~= "Off" or tip.values.full ~= "Full" then
			fail(scenario, "the tooltip choices are labelled otherwise")
		end
		if not (tip.desc and tip.desc:find("unlocked", 1, true) and tip.desc:find("drag", 1, true)) then
			fail(scenario, "the tooltip setting does not say the drag note stays: " .. tostring(tip.desc))
		end
		local p = ns.db.profile.prompt
		for _, key in ipairs(want) do
			tip.set({ "tooltip" }, key)
			if p.tooltip ~= key or tip.get({ "tooltip" }) ~= key then fail(scenario, "setting " .. key .. " did not stick") end
		end
		for _, key in ipairs({ "game", "beside" }) do
			where.set({ "tooltipPosition" }, key)
			if p.tooltipPosition ~= key or where.get({ "tooltipPosition" }) ~= key then
				fail(scenario, "setting " .. key .. " did not stick")
			end
		end
		p.tooltip = "off"
		if not (type(where.disabled) == "function" and where.disabled()) then
			fail(scenario, "the position control is live while the tooltip is off")
		end
		p.tooltip = "short"
		if where.disabled() then fail(scenario, "the position control is greyed under short") end
	end)
end

do
	local scenario = "tooltip: the Look page's reset puts the tooltip back"
	session(scenario, function(ns)
		local Page = ns.OptionsPage
		local list = Page.RESET and Page.RESET.appearance or {}
		local seen = {}
		for _, path in ipairs(list) do seen[path] = true end
		for _, path in ipairs({ "prompt.tooltip", "prompt.tooltipPosition" }) do
			if not seen[path] then fail(scenario, "the Look reset leaves out " .. path) end
		end
	end)
end

-- ------------------------------------------------------------------ sharing

do
	local scenario = "tooltip: the settings travel in an exported profile"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		ns.addon:OnInitialize()
		local p = ns.db.profile.prompt
		local plain = ns.ExportSettings()
		p.tooltip, p.tooltipPosition = "shift", "game"
		local text = ns.ExportSettings()
		if text == plain then fail(scenario, "the export does not change with the tooltip settings") end
		p.tooltip, p.tooltipPosition = "full", "beside"
		local ok, message = ns.ImportSettings(text)
		if not ok then
			fail(scenario, "its own export was refused: " .. tostring(message))
		elseif p.tooltip ~= "shift" or p.tooltipPosition ~= "game" then
			fail(scenario, ("the import gave back %s and %s"):format(tostring(p.tooltip), tostring(p.tooltipPosition)))
		end
		-- A profile that is all defaults says nothing of them, and so puts them back.
		p.tooltip, p.tooltipPosition = "off", "game"
		ok = ns.ImportSettings(plain)
		if not ok or p.tooltip ~= "short" or p.tooltipPosition ~= "beside" then
			fail(scenario, ("importing the defaults left %s and %s"):format(tostring(p.tooltip), tostring(p.tooltipPosition)))
		end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ words

do
	local scenario = "tooltip: every language has the tooltip's words"
	local KEYS = { "Tooltip", "Tooltip on the prompt", "Short (hold Shift for more)", "Only while holding Shift",
		"Off", "Tooltip position", "Beside the prompt", "Where the game shows tooltips", HINT,
		"What the prompt and the names in its list show when the cursor is on them. Short is the name, why they are offered and a hint; hold Shift for everything. The note about dragging that shows while the prompt is unlocked stays whatever you pick, since it explains the drag.",
		"Beside the prompt puts it above or below, on the side with more room on your screen, clear of the prompt and its list. Where the game shows tooltips uses your usual tooltip corner." }
	for _, code in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
		local f = io.open(dir .. "/Locales/" .. code .. ".lua", "rb")
		if not f then
			fail(scenario, code .. ": no locale file")
		else
			local body = f:read("*a")
			f:close()
			for _, key in ipairs(KEYS) do
				-- The key as the file writes it: quotes escaped, nothing else.
				local line = "L[\"" .. key:gsub("\\", "\\\\"):gsub("\"", "\\\"") .. "\"] = \""
				local at = body:find(line, 1, true)
				if not at then
					fail(scenario, code .. " lacks " .. key:sub(1, 40))
				elseif body:sub(at + #line, at + #line) == "\"" then
					fail(scenario, code .. " has an empty translation of " .. key:sub(1, 40))
				end
			end
		end
	end
end
