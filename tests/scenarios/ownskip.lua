-- A right-click on your own buff skips that buff alone (asked for on
-- CurseForge: one right-click took every buff of yours off the prompt, so the
-- next one never came up). Ctrl-right-click skips them all, as every
-- right-click did before; shift-right-click still stops offering you your own
-- buff. Under the flash of a press on yourself the skip is of the buff that
-- press was for, which the words are about, never the next one armed under
-- them. The launcher's Not now on your own buff skips that one too, and the
-- tooltip says so.
--
-- Every scenario name starts with "ownskip:" so the mutations in
-- tests/mutations/ownskip.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local ME = "Mort Defrette"
-- Arcane Intellect, and the armor family: Frost Armor's ranks, Ice Armor,
-- Mage Armor.
local INTELLECT = 1459
local KNOWN = { 1459, 168, 7300, 7301, 7302, 6117 }

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "MenuUtil" }

local function said() return table.concat(Mock.printed, "\n") end
local function flat(text) return (tostring(text):gsub("\n", " / ")) end
local function key(entry) return tostring(entry and entry.buff and entry.buff.key) end

-- Your own entry in the queue as it stands, or nil.
local function mine(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry end
	end
	return nil
end

-- A mage who knows Arcane Intellect and her armors and wears none of them,
-- nobody else about.
local function with(scenario, body)
	Mock.reset()
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local known = {}
	for _, id in ipairs(KNOWN) do known[id] = true end
	rawset(_G, "IsSpellKnown", function(id) return known[id] == true end)
	rawset(_G, "IsPlayerSpell", function(id) return known[id] == true end)
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		Mock.playerHeld = {}
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		Mock.playerHeld = {}
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		ns.db.profile.verbose = true
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	Mock.modifiers = {}
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The prompt on your first own buff: its key, or nil (reported by the caller).
local function onFirst(ns)
	ns.Prompt:Refresh()
	local showing = ns.Prompt:Showing()
	if not (showing and showing.reason == "self") then return nil end
	return key(showing)
end

do
	local scenario = "ownskip: a right-click skips that buff of yours alone, and the next comes up"
	with(scenario, function(ns)
		local first = onFirst(ns)
		if not first then fail(scenario, "SKIPPED -- the prompt is not on your own buff") return end
		Mock.printed = {}
		H.pressButton(ns, "RightButton")
		if not ns.IsBlocked(ME, first) then fail(scenario, "the right-click did not skip " .. first) end
		if ns.IsBlocked(ME, nil) then fail(scenario, "the right-click skipped every buff of yours") end
		local next = mine(ns)
		if not next then
			fail(scenario, "no other buff of yours came up after skipping " .. first)
		elseif key(next) == first then
			fail(scenario, "still offered " .. first .. " right after skipping it")
		end
		local name = ns.BuffName(ns.FindBuff("MAGE", first) or ns.FindOwnSpell(first))
		if not said():find("skipping your |cffffffff" .. name .. "|r for now.", 1, true) then
			fail(scenario, "the skip reads " .. flat(said()))
		end
		-- The prompt is on the next one now.
		ns.Prompt:Refresh()
		if key(ns.Prompt:Showing()) == first then fail(scenario, "the prompt stayed on " .. first) end
	end)
end

do
	local scenario = "ownskip: ctrl-right-click skips every buff of yours"
	with(scenario, function(ns)
		if not onFirst(ns) then fail(scenario, "SKIPPED -- the prompt is not on your own buff") return end
		Mock.printed = {}
		Mock.modifiers.ctrl = true
		H.pressButton(ns, "RightButton")
		Mock.modifiers.ctrl = nil
		if not ns.IsBlocked(ME, nil) then fail(scenario, "ctrl-right-click did not skip every buff of yours") end
		if mine(ns) then fail(scenario, "still offered " .. key(mine(ns)) .. " after ctrl-right-click") end
		if not said():find("skipping all your own buffs for now.", 1, true) then
			fail(scenario, "the skip reads " .. flat(said()))
		end
		-- Shift is still the switch.
		Mock.advance(60)
		wipe(ns.tried)
		Mock.modifiers.shift = true
		ns.Prompt:Refresh()
		H.pressButton(ns, "RightButton")
		Mock.modifiers.shift = nil
		if ns.db.profile.sources.self ~= false then fail(scenario, "shift-right-click left Myself on") end
	end)
end

do
	local scenario = "ownskip: under the flash of a press on yourself the skip is of the buff pressed"
	with(scenario, function(ns)
		local first = onFirst(ns)
		if not first then fail(scenario, "SKIPPED -- the prompt is not on your own buff") return end
		local pressed = H.pressButton(ns)
		if not (pressed and ns.pendingClick and ns.pendingClick.onSelf) then
			fail(scenario, "SKIPPED -- the press on you did not go out")
			return
		end
		local buff = ns.FindBuff("MAGE", first) or ns.FindOwnSpell(first)
		local info = ns.BuffInfo(buff)
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", ME, "Cast-own-1", (info and info.topRank) or buff.ranks[1])
		if ns.pendingClick then fail(scenario, "SKIPPED -- the press was never settled") return end
		-- The panel's words are the press's; the entry under them the next buff.
		local under = ns.Prompt.state.heldEntry
		if ns.Prompt:PanelName() ~= ME or key(under) == first then
			fail(scenario, ("SKIPPED -- the flash is not over your next buff (%s under %s)")
				:format(key(under), tostring(ns.Prompt:PanelName())))
			return
		end
		local nextKey = key(under)
		H.pressButton(ns, "RightButton")
		if ns.IsBlocked(ME, nextKey) then
			fail(scenario, "a right-click under the flash skipped " .. nextKey .. ", the buff armed under it")
		end
		if ns.IsBlocked(ME, nil) then fail(scenario, "a right-click under the flash skipped every buff of yours") end
	end)
end

do
	local scenario = "ownskip: the tooltip and Not now agree"
	with(scenario, function(ns)
		local first = onFirst(ns)
		if not first then fail(scenario, "SKIPPED -- the prompt is not on your own buff") return end
		local button = ns.Prompt:GetButton()
		ns.db.profile.prompt.tooltip = "full"
		Mock.tooltip = {}
		button.scripts.OnEnter(button)
		local tip = table.concat(Mock.tooltip, " / ")
		if not tip:find("Right-click to skip this buff for now; ctrl-right-click skips all your own buffs.", 1, true) then
			fail(scenario, "the tooltip says " .. tip)
		end
		button.scripts.OnLeave(button)
		-- The launcher's Not now on your own buff skips that one alone.
		local broker = Mock.broker
		if not broker then fail(scenario, "SKIPPED -- no launcher") return end
		local opened
		-- The right-click menu, in the shape the client's MenuUtil builds it.
		local function newMenu(text, fn)
			local d = { text = text, fn = fn, items = {} }
			local function add(c) d.items[#d.items + 1] = c return c end
			function d:CreateTitle(t) return add(newMenu(t)) end
			function d:CreateDivider() return add(newMenu()) end
			function d:CreateButton(t, f) return add(newMenu(t, f)) end
			function d:CreateCheckbox(t, _, f) return add(newMenu(t, f)) end
			function d:CreateRadio(t, _, f) return add(newMenu(t, f)) end
			function d:SetEnabled() end
			function d:SetTooltip() end
			return d
		end
		local function find(root, text)
			for _, item in ipairs(root.items) do
				if item.text and tostring(item.text):find(text, 1, true) then return item end
				local inner = find(item, text)
				if inner then return inner end
			end
		end
		rawset(_G, "MenuUtil", { CreateContextMenu = function(owner, generator)
			opened = newMenu()
			generator(owner, opened)
			return opened
		end })
		broker.OnClick({}, "RightButton")
		local row = opened and find(opened, "(your own buff), on the prompt")
		local skip = row and find(row, "Skip for now")
		if not (skip and skip.fn) then fail(scenario, "SKIPPED -- no Skip for now on your own buff") return end
		Mock.printed = {}
		skip.fn()
		if not ns.IsBlocked(ME, first) then fail(scenario, "Not now did not skip " .. first) end
		if ns.IsBlocked(ME, nil) then fail(scenario, "Not now skipped every buff of yours") end
	end)
end
