-- Moving the prompt in the game's Edit Mode (Look, "Move it in Edit Mode";
-- Prompt/Button.lua, "Edit Mode"): a player asked to place the prompt there,
-- with the game's own frames.
--
-- Blizzard's EditModeManager.lua says "EditMode.Enter" and "EditMode.Exit"
-- through EventRegistry on every client's branch. While Edit Mode is open the
-- prompt is unlocked, a drag leaves it unlocked to be nudged again, and Edit
-- Mode closing locks it. Only a prompt Manners unlocked for it is locked by it.
-- These hold Manners to a registry made here that calls back as Blizzard's
-- does, not to the client.
--
-- Every name starts with "editmode:" so a mutation in
-- tests/mutations/editmode.py can name exactly one.

local dir, H = ...
local fail, load = H.fail, H.load

local function said() return table.concat(Mock.printed, "\n") end

-- EventRegistry as the addon uses it: RegisterCallback(event, fn, owner), and
-- TriggerEvent calling each with its owner first.
local function Registry()
	local held = {}
	return {
		RegisterCallback = function(_, event, fn, owner)
			held[event] = held[event] or {}
			table.insert(held[event], { fn, owner })
		end,
		TriggerEvent = function(_, event, ...)
			for _, entry in ipairs(held[event] or {}) do entry[1](entry[2], ...) end
		end,
	}
end

-- One session as a mage on a client with an Edit Mode (or without one, with
-- opts.none), the lifecycle driven, and the globals put back however it ends.
local function with(scenario, body, opts)
	opts = opts or {}
	Mock.reset()
	Mock.class = opts.class or "MAGE"
	local realRegistry, realEdit = rawget(_G, "EventRegistry"), rawget(_G, "C_EditMode")
	local registry = Registry()
	if opts.none then
		_G.EventRegistry, _G.C_EditMode = nil, nil
	else
		_G.EventRegistry, _G.C_EditMode = registry, {}
	end
	local ok, err = true, nil
	local ns = load(scenario)
	if ns then
		ok, err = pcall(function()
			H.freshPrompt(ns, scenario)
			Mock.printed = {}
			body(ns, registry)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
	end
	Mock.inCombat = false
	_G.EventRegistry, _G.C_EditMode = realRegistry, realEdit
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function drag(ns)
	local button = ns.Prompt:GetButton()
	button.scripts.OnDragStart(button)
	button.scripts.OnDragStop(button)
end

-- ------------------------------------------------------------------ in and out
do
	local scenario = "editmode: Edit Mode opening unlocks the prompt, and closing locks it"
	with(scenario, function(ns, registry)
		local p = ns.db.profile.prompt
		if p.moveInEditMode ~= true then fail(scenario, "Move it in Edit Mode is not on to begin with") end
		if p.locked ~= true then
			fail(scenario, "SKIPPED -- the prompt does not start locked")
			return
		end
		registry:TriggerEvent("EditMode.Enter")
		if p.locked ~= false then fail(scenario, "Edit Mode opened and the prompt stayed locked") end
		if not said():find("unlocked for Edit Mode", 1, true) then
			fail(scenario, "nothing in chat says the prompt was unlocked for Edit Mode: " .. said())
		end
		ns.addon:Tick()
		if not ns.Prompt:GetButton():IsShown() then
			fail(scenario, "the unlocked prompt is not on screen to be dragged in Edit Mode")
		end
		if not tostring(ns.Prompt.regions.nameText:GetText()):find("Drag to move", 1, true) then
			fail(scenario, "in Edit Mode the prompt reads " .. tostring(ns.Prompt.regions.nameText:GetText()))
		end
		Mock.printed = {}
		registry:TriggerEvent("EditMode.Exit")
		if p.locked ~= true then fail(scenario, "Edit Mode closed and the prompt stayed unlocked") end
		if not said():find("locked.", 1, true) then
			fail(scenario, "nothing in chat says the prompt was locked again: " .. said())
		end
		-- A second closing with nothing open says nothing more.
		Mock.printed = {}
		registry:TriggerEvent("EditMode.Exit")
		if said() ~= "" then fail(scenario, "Edit Mode closing twice spoke twice: " .. said()) end
	end)
end

-- ------------------------------------------------------------------ the drag
do
	local scenario = "editmode: a drag in Edit Mode saves the place and leaves the prompt unlocked until Edit Mode closes"
	with(scenario, function(ns, registry)
		local p = ns.db.profile.prompt
		registry:TriggerEvent("EditMode.Enter")
		ns.Prompt:Refresh()
		p.x = 999
		Mock.printed = {}
		drag(ns)
		if p.x == 999 then fail(scenario, "a drag in Edit Mode did not save where the prompt landed") end
		if p.locked ~= false then fail(scenario, "one drag in Edit Mode locked the prompt, with Edit Mode still open") end
		if said():find("moved and locked", 1, true) or not said():find("locks when Edit Mode closes", 1, true) then
			fail(scenario, "after a drag in Edit Mode chat says: " .. said())
		end
		-- And a second nudge is taken.
		p.x = 999
		drag(ns)
		if p.x == 999 then fail(scenario, "the second drag in Edit Mode was refused") end
		registry:TriggerEvent("EditMode.Exit")
		if p.locked ~= true then fail(scenario, "Edit Mode closed after a drag and the prompt stayed unlocked") end

		-- Outside Edit Mode a drag locks as it always did.
		ns.addon:HandleSlash("unlock")
		ns.Prompt:Refresh()
		Mock.printed = {}
		drag(ns)
		if p.locked ~= true or not said():find("moved and locked", 1, true) then
			fail(scenario, "after Edit Mode an ordinary drag no longer locks: " .. said())
		end
	end)
end

-- ------------------------------------------------------------------ left alone
do
	local scenario = "editmode: with the switch off, the addon off or a fight on, Edit Mode leaves the prompt alone"
	with(scenario, function(ns, registry)
		local db = ns.db.profile
		local p = db.prompt
		p.moveInEditMode = false
		registry:TriggerEvent("EditMode.Enter")
		if p.locked ~= true then fail(scenario, "Move it in Edit Mode is off and Edit Mode unlocked the prompt") end
		registry:TriggerEvent("EditMode.Exit")
		p.moveInEditMode = true

		Mock.inCombat = true
		registry:TriggerEvent("EditMode.Enter")
		if p.locked ~= true then fail(scenario, "Edit Mode opened in a fight unlocked the prompt, which cannot be moved there") end
		registry:TriggerEvent("EditMode.Exit")
		Mock.inCombat = false

		db.enabled = false
		registry:TriggerEvent("EditMode.Enter")
		if p.locked ~= true then fail(scenario, "switched off, Edit Mode unlocked a prompt that is not on screen") end
		registry:TriggerEvent("EditMode.Exit")
		db.enabled = true
		if said() ~= "" then fail(scenario, "Edit Mode spoke while leaving the prompt alone: " .. said()) end
	end)
end

do
	local scenario = "editmode: a prompt the player unlocked is not locked by Edit Mode closing"
	with(scenario, function(ns, registry)
		local p = ns.db.profile.prompt
		ns.addon:HandleSlash("unlock")
		Mock.printed = {}
		registry:TriggerEvent("EditMode.Enter")
		registry:TriggerEvent("EditMode.Exit")
		if p.locked ~= false then fail(scenario, "Edit Mode closing locked a prompt the player had unlocked") end
		if said() ~= "" then fail(scenario, "Edit Mode spoke over a prompt the player unlocked: " .. said()) end
		ns.addon:HandleSlash("lock")

		-- Locked by hand while Edit Mode is open: closing says nothing more.
		registry:TriggerEvent("EditMode.Enter")
		ns.addon:HandleSlash("lock")
		Mock.printed = {}
		registry:TriggerEvent("EditMode.Exit")
		if p.locked ~= true or said() ~= "" then
			fail(scenario, "locked by hand in Edit Mode, its closing said: " .. said())
		end
	end)
end

-- ------------------------------------------------------------------ a reload
do
	local scenario = "editmode: a reload inside Edit Mode does not leave the prompt unlocked"
	with(scenario, function(ns, registry)
		local p = ns.db.profile.prompt
		registry:TriggerEvent("EditMode.Enter")
		if not ns.db.char.editUnlocked then
			fail(scenario, "nothing saved says the prompt was unlocked for Edit Mode")
		end
		-- The next session's enable finds the mark, with no Edit Mode open.
		ns.WatchEditMode()
		if p.locked ~= true then fail(scenario, "the session after a reload in Edit Mode starts unlocked") end
		if ns.db.char.editUnlocked then fail(scenario, "the mark outlived the session that read it") end
		-- Closed in the ordinary way, the mark goes with it.
		registry:TriggerEvent("EditMode.Exit")
		registry:TriggerEvent("EditMode.Enter")
		registry:TriggerEvent("EditMode.Exit")
		if ns.db.char.editUnlocked then fail(scenario, "the mark stayed after Edit Mode closed") end
	end)
end

-- ------------------------------------------------------------------ the switch
do
	local scenario = "editmode: the switch is on Look where the client has an Edit Mode, and hidden where it has none"
	with(scenario, function(ns)
		local option = ns.optionsTable.args.appearance.args.moveInEditMode
		if not (option and option.type == "toggle") then
			fail(scenario, "Look has no Move it in Edit Mode switch")
			return
		end
		if option.hidden({}) then fail(scenario, "the switch is hidden on a client with an Edit Mode") end
		if option.get({ "moveInEditMode" }) ~= true then fail(scenario, "the switch does not read on") end
		option.set({ "moveInEditMode" }, false)
		if ns.db.profile.prompt.moveInEditMode ~= false then fail(scenario, "the switch did not write the setting") end
		if not H.placedOn(ns, "appearance.moveInEditMode") then
			fail(scenario, "the options window draws the switch nowhere")
		end
	end)
	with(scenario, function(ns)
		local option = ns.optionsTable.args.appearance.args.moveInEditMode
		if option and not option.hidden({}) then
			fail(scenario, "the switch is shown on a client with no Edit Mode")
		end
		if ns.HasEditMode() then fail(scenario, "a client with no Edit Mode is read as having one") end
	end, { none = true })
end
