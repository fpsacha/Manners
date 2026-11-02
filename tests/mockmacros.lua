-- The client's macros, its cursor and its key texts, as the mock answers them.
-- Loaded at the end of mockapi.lua, after tests/mockwindow.lua.
--
-- Macros as the game keeps them: 1..120 account-wide, 121..150 per character.
-- Mock.macroList (index -> { name, icon, body, spell, item }) is wiped by
-- Mock.reset. Mock.macros (name -> index) is the older way for a scenario to
-- say "this macro is there"; it still answers GetMacroIndexByName and lets
-- PickupMacro find it, but it has no body.
--
-- In a fight the macro calls are refused as the client refuses a protected
-- call from an addon: nothing happens and there is no Lua error, and the call
-- is written down in Mock.blockedCalls. Which of them the client protects in a
-- fight is not told anywhere an addon can read (Blizzard's API documentation
-- lists none of the macro functions), so every one the addon makes is held to
-- the strictest answer.
--
-- SetMacroSpell and SetMacroItem set what the macro's slot on an action bar
-- draws, whatever its text says: the spell's or item's icon, cooldown, range
-- and usability. Mock.slotShows(slot) says what a bar slot holding the macro
-- would draw, which is all a scenario can know of it. All five clients have
-- both (each branch's GlobalAPI lists them); a scenario that wants a client
-- without sets the global to nil.
--
-- GetBindingText is not in the mock by default: the looks' key chips fall
-- back to their own words where the client gives none, and scenarios hold
-- that. Mock.withBindingText() puts the client's in and answers the call that
-- takes it out again.

Mock.macroList = {}
Mock.blockedCalls = {}
Mock.cursor = nil
Mock.bar = {}

local MACRO_ACCOUNT, MACRO_CHARACTER = 120, 30
local unpack = table.unpack or unpack

local function blocked(name)
	if not Mock.inCombat then return false end
	Mock.blockedCalls[#Mock.blockedCalls + 1] = name
	return true
end

local function macroAt(index)
	return type(index) == "number" and Mock.macroList[index] or nil
end

function GetNumMacros()
	local account, character = 0, 0
	for index in pairs(Mock.macroList) do
		if index > MACRO_ACCOUNT then character = character + 1 else account = account + 1 end
	end
	return account, character
end

-- The macro Put Manners on an action bar writes, once a scenario has made it:
-- its place, or 0.
function GetMacroIndexByName(name)
	if Mock.macros and Mock.macros[name] then return Mock.macros[name] end
	for index, macro in pairs(Mock.macroList) do
		if macro.name == name then return index end
	end
	return 0
end

function GetMacroInfo(index)
	local macro = macroAt(index)
	if macro then return macro.name, macro.icon, macro.body end
end

function GetMacroBody(index)
	local macro = macroAt(index)
	return macro and macro.body or nil
end

-- A list at its cap raises an error rather than answering with nothing
-- (warcraft.wiki.gg API_CreateMacro).
function CreateMacro(name, icon, body, perCharacter)
	if blocked("CreateMacro") then return end
	local first, last = 1, MACRO_ACCOUNT
	if perCharacter then first, last = MACRO_ACCOUNT + 1, MACRO_ACCOUNT + MACRO_CHARACTER end
	for index = first, last do
		if not Mock.macroList[index] then
			Mock.macroList[index] = { name = name, icon = icon, body = body }
			return index
		end
	end
	error("Macro limit reached", 2)
end

-- Every call is counted (Mock.editCalls), a refused one too. With a scenario's
-- Mock.eventSink set, the client's UPDATE_MACROS is handed to it and to every
-- frame listening, inside the call: the earliest the game could send it.
function EditMacro(index, name, icon, body)
	Mock.editCalls = (Mock.editCalls or 0) + 1
	if blocked("EditMacro") then return end
	local macro = macroAt(index)
	if not macro then return end
	if name ~= nil then macro.name = name end
	if icon ~= nil then macro.icon = icon end
	if body ~= nil then macro.body = body end
	if Mock.eventSink then Mock.macrosChanged() end
	return index
end

-- An empty string takes the spell or the item back. Every call is counted,
-- whether or not there is a macro at that place for it to change.
function SetMacroSpell(index, spell)
	if blocked("SetMacroSpell") then return end
	Mock.macroSpellCalls = (Mock.macroSpellCalls or 0) + 1
	local macro = macroAt(index)
	if not macro then return end
	if spell == nil or spell == "" then macro.spell = nil else macro.spell = spell end
end

-- What a macro's slot was given, as the client answers it: the spell's id
-- (a number; the mock keeps the name it was given, and Mock.spellIds says what
-- id a name has, else the name itself comes back), and the item's name and
-- link. Nothing for a macro that was given none, an empty string included.
function GetMacroSpell(index)
	local macro = macroAt(index)
	if not (macro and macro.spell) then return nil end
	return Mock.spellIds and Mock.spellIds[macro.spell] or macro.spell
end

function GetMacroItem(index)
	local macro = macroAt(index)
	if not (macro and macro.item) then return nil end
	local id = tostring(macro.item):match("item:(%d+)")
	return id and ("Item " .. id) or tostring(macro.item), tostring(macro.item)
end

-- Taking a macro away, by place or by name, as the game does (the list closes
-- up behind it only in the macro window; here the place is simply free).
function DeleteMacro(which)
	if blocked("DeleteMacro") then return end
	local index = which
	if type(which) == "string" then index = GetMacroIndexByName(which) end
	if type(index) ~= "number" or index <= 0 then return end
	Mock.macroList[index] = nil
	if Mock.macros then
		for name, at in pairs(Mock.macros) do
			if at == index then Mock.macros[name] = nil end
		end
	end
	for slot, at in pairs(Mock.bar) do
		if at == index then Mock.bar[slot] = nil end
	end
end

function SetMacroItem(index, item)
	if blocked("SetMacroItem") then return end
	Mock.macroItemCalls = (Mock.macroItemCalls or 0) + 1
	local macro = macroAt(index)
	if not macro then return end
	if item == nil or item == "" then macro.item = nil else macro.item = item end
end

-- The cursor: a macro picked up from the list, by place or by name.
function PickupMacro(which)
	if blocked("PickupMacro") then return end
	local index = which
	if type(which) == "string" then index = GetMacroIndexByName(which) end
	if type(index) ~= "number" or index <= 0 then return end
	local known = macroAt(index) ~= nil
	for _, at in pairs(Mock.macros or {}) do known = known or at == index end
	if known then Mock.cursor = { "macro", index } end
end

function GetCursorInfo()
	if Mock.cursor then return unpack(Mock.cursor) end
end

function ClearCursor() Mock.cursor = nil end

-- Dropping what the cursor holds on an action bar slot, which the game
-- refuses in a fight.
function Mock.dropOnBar(slot)
	if Mock.inCombat then return false end
	local cursor = Mock.cursor
	if not (cursor and cursor[1] == "macro") then return false end
	Mock.bar[slot] = cursor[2]
	Mock.cursor = nil
	return true
end

-- What the macro on a bar slot would draw: its spell or item when it was
-- given one, otherwise its own icon.
function Mock.slotShows(slot)
	local macro = macroAt(Mock.bar[slot])
	if not macro then return nil end
	if macro.spell then return "spell", macro.spell end
	if macro.item then return "item", macro.item end
	return "icon", macro.icon
end

---------------------------------------------------------------------------
-- key texts
---------------------------------------------------------------------------

-- GetBindingText(binding, abbreviated) as the client answers it: the
-- modifiers first ("SHIFT-" or, short, "s-"), then the key. A gamepad button
-- is an inline atlas of its glyph, 64 pixels' worth drawn 24 wide, or the
-- short form's 32 drawn 14 wide (Blizzard_SharedXML/SharedConstants.lua,
-- SetGamepadBindingStrings; the client has the same table on every branch).
-- Face buttons are the generic numbered ones, as the game draws them until a
-- controller says what it is.
local MODIFIERS = { SHIFT = "s", CTRL = "c", ALT = "a" }
local PADS = {
	PAD1 = "Gen_1", PAD2 = "Gen_2", PAD3 = "Gen_3", PAD4 = "Gen_4", PAD5 = "Gen_5", PAD6 = "Gen_6",
	PADDUP = "Gen_Up", PADDRIGHT = "Gen_Right", PADDDOWN = "Gen_Down", PADDLEFT = "Gen_Left",
	PADLSHOULDER = "Gen_LShoulder", PADRSHOULDER = "Gen_RShoulder",
	PADLTRIGGER = "Gen_LTrigger", PADRTRIGGER = "Gen_RTrigger",
	PADLSTICK = "Gen_LStickIn", PADRSTICK = "Gen_RStickIn",
	PADFORWARD = "Gen_Forward", PADBACK = "Gen_Back", PADSYSTEM = "Gen_System", PADSOCIAL = "Gen_Share",
}

local function bindingText(binding, short)
	if type(binding) ~= "string" or binding == "" then return "" end
	local out, rest = "", binding
	while true do
		local mod, tail = rest:match("^(%u+)%-(.+)$")
		if not (mod and MODIFIERS[mod]) then break end
		out = out .. (short and MODIFIERS[mod] or mod) .. "-"
		rest = tail
	end
	local pad = PADS[rest]
	if pad then
		return out .. (short and ("|A:Gamepad_" .. pad .. "_32:14:14|a") or ("|A:Gamepad_" .. pad .. "_64:24:24|a"))
	end
	return out .. rest
end
Mock.bindingText = bindingText

function Mock.withBindingText()
	local was = rawget(_G, "GetBindingText")
	_G.GetBindingText = bindingText
	return function() _G.GetBindingText = was end
end

---------------------------------------------------------------------------
-- running macros
---------------------------------------------------------------------------
--
-- Opt-in, so every scenario written before this judges exactly as it did:
-- Mock.secureActions on makes a Click on a frame made from
-- SecureActionButtonTemplate run the client's own SecureActionButton_OnClick
-- (Mock.secureOnClick, ported line for line from Blizzard's classic_era
-- SecureTemplates.lua 684-823: ShouldUseOnKeyDown,
-- GetConvertedButtonUnitAndActionType, PerformAction; forever and live have
-- the same function), and its "macro" type run the macro text here, a line at
-- a time, as the client's macro system does: /click as SlashCommands.lua
-- 721-737 has it, /target by the start of a name, /cast logged with whoever is
-- targeted then. A line the mock does not know raises an error rather than
-- being let through.
--
-- What the client refuses is a model the scenario picks, since no addon can
-- read it:
--   Mock.macroChain   "refused" (the default): a macro that /clicks a button
--                     which runs a macro casts nothing from that button
--                     (Blizzard, WoWUIBugs #552: "one macro cannot /click a
--                     button that itself would execute another macro");
--                     "allowed": the client before that.
--   Mock.clickContext "none" (the default): a Click carries no isKeyPress or
--                     isSecureAction, as Blizzard's SecureTemplates.xml says of
--                     every addon button; "inherit": a /click inside a bar
--                     press is handed that press's flags.
--   Mock.castEvents   nil, "sync" (UNIT_SPELLCAST_SENT handed to
--                     Mock.eventSink at the /cast, inside the macro) or "after"
--                     (once the outermost macro has run).
--   Mock.gcdOnCast    seconds of global cooldown a /cast that went out starts
--                     (Mock.spellCooldowns[61304]); a /cast inside one goes
--                     nowhere. nil: casts start nothing, as before.
-- Mock.spellIdFor(name) gives the id UNIT_SPELLCAST_SENT carries.

local GCD_ID = 61304

local function resetRunning()
	Mock.secureActions = false
	Mock.macroChain = "refused"
	Mock.clickContext = "none"
	Mock.castEvents = nil
	Mock.gcdOnCast = nil
	Mock.spellIdFor = nil
	Mock.eventSink = nil
	Mock.macroLog, Mock.castLog, Mock.saidLog = {}, {}, {}
	Mock.macroDepth, Mock.pressFlags = 0, nil
	-- The place of the macro a bar press is running (Mock.pressBar), for
	-- GetRunningMacro; nil outside one.
	Mock.runningMacro = nil
	Mock.editCalls = 0
	Mock.queuedEvents = {}
	-- Whom the macros have targeted: { unit, name } or nil, and the one before.
	Mock.runTarget, Mock.runLastTarget = nil, nil
	Mock.cvars = { ActionButtonUseKeyDown = "1", ActionButtonUseKeyHeldSpell = "0" }
end
resetRunning()
do
	local reset = Mock.reset
	function Mock.reset()
		reset()
		resetRunning()
	end
end

local function cvarBool(name)
	local value = Mock.cvars and Mock.cvars[name]
	return value == "1" or value == true
end

-- An event as the client dispatches it to the addon (AceEvent's handler) and
-- to every frame registered for it.
local function dispatch(event, ...)
	local sink = Mock.eventSink
	if sink and type(sink[event]) == "function" then sink[event](sink, event, ...) end
	if Mock.frameEvent then Mock.frameEvent(event, ...) end
end
Mock.dispatch = dispatch

function Mock.macrosChanged()
	dispatch("UPDATE_MACROS")
end

-- SecureButton_GetModifierPrefix and SecureButton_GetButtonSuffix.
local function prefixOf()
	local prefix = ""
	if IsShiftKeyDown and IsShiftKeyDown() then prefix = "shift-" .. prefix end
	if IsControlKeyDown and IsControlKeyDown() then prefix = "ctrl-" .. prefix end
	if IsAltKeyDown and IsAltKeyDown() then prefix = "alt-" .. prefix end
	return prefix
end
local SUFFIX = { LeftButton = "1", RightButton = "2", MiddleButton = "3" }
local function suffixOf(button)
	if SUFFIX[button] then return SUFFIX[button] end
	local n = type(button) == "string" and button:match("^Button(%d+)$")
	if n then return n end
	if button and button ~= "" then return "-" .. tostring(button) end
	return ""
end

-- SecureButton_GetModifiedAttribute: the client's GetAttribute(prefix, name,
-- suffix), the most particular form first and the bare name last.
local function modified(frame, name, button, prefix, suffix)
	prefix = prefix or prefixOf()
	suffix = suffix or suffixOf(button)
	for _, key in ipairs({ prefix .. name .. suffix, "*" .. name .. suffix, prefix .. name .. "*",
		"*" .. name .. "*", prefix .. name, "*" .. name, name }) do
		local value = frame:GetAttribute(key)
		if value ~= nil then
			if value == "" then return nil end
			return value
		end
	end
	return nil
end

local function shouldUseOnKeyDown(frame)
	local value = modified(frame, "useOnKeyDown", nil, "", "")
	if value == nil then value = cvarBool("ActionButtonUseKeyDown") end
	return value
end

-- PerformAction for the two action types the addon's buttons use: a macro,
-- by text or by index, and "none" (any other type is logged and does nothing).
local function perform(frame, button, pressType, entry)
	if pressType == "down" then button = modified(frame, "downbutton", button) or button end
	local unit = modified(frame, "unit", button)
	if unit and unit ~= "none" and not UnitExists(unit) then entry.type = "no unit" return end
	local actionType = modified(frame, pressType == "release" and "typerelease" or "type", button)
	entry.type = actionType
	if actionType ~= "macro" then return end
	local index = modified(frame, "macro", button)
	local text
	if index then
		local macro = macroAt(tonumber(index) or GetMacroIndexByName(tostring(index)))
		text = macro and macro.body
	else
		text = modified(frame, "macrotext", button)
	end
	entry.text = text
	if text then Mock.runMacroText(text) end
end

-- SecureActionButton_OnClick, line for line. Its flags are nil for every
-- addon button unless Mock.clickContext hands it a running bar press's.
function Mock.secureOnClick(self, inputButton, down)
	local isKeyPress, isSecureAction
	if Mock.clickContext == "inherit" and Mock.pressFlags then
		isKeyPress, isSecureAction = Mock.pressFlags.isKeyPress, Mock.pressFlags.isSecureAction
	end
	local isSecureMousePress = not isKeyPress and isSecureAction
	local pressAndHoldAction = modified(self, "pressAndHoldAction", nil, "", "")
	local useOnKeyDown = not isSecureMousePress and (shouldUseOnKeyDown(self) or pressAndHoldAction)
	local clickAction = (down and useOnKeyDown) or (not down and not useOnKeyDown)
	local releasePressAndHoldAction = (not down) and (pressAndHoldAction or cvarBool("ActionButtonUseKeyHeldSpell"))
	local entry = { frame = self._name, down = down and true or false,
		flags = { isKeyPress = isKeyPress, isSecureAction = isSecureAction } }
	Mock.macroLog[#Mock.macroLog + 1] = entry
	if clickAction then
		entry.action = "click"
		perform(self, inputButton, down and "down" or "up", entry)
		return true
	elseif releasePressAndHoldAction then
		entry.action = "release"
		perform(self, inputButton, "release", entry)
		return true
	end
	entry.action = "none"
	return false
end

-- Whoever answers to the start of a name, as /target finds them: the player
-- and every unit the scenario named.
local function findUnit(text)
	local want = tostring(text):lower()
	if want == "" then return nil end
	local function full(first, second)
		if type(first) ~= "string" then return nil end
		if type(second) == "string" and second ~= "" then return first .. " " .. second end
		return first
	end
	local candidates = { { "player", full(UnitName("player")) } }
	local units = {}
	for unit in pairs(Mock.unitNames or {}) do units[#units + 1] = unit end
	table.sort(units)
	for _, unit in ipairs(units) do
		local n = Mock.unitNames[unit]
		candidates[#candidates + 1] = { unit, full(n[1], n[2]) }
	end
	for _, c in ipairs(candidates) do
		local name = c[2]
		if name and name:lower():sub(1, #want) == want then return { unit = c[1], name = name } end
	end
	return nil
end

local function retarget(to)
	local was = Mock.runTarget
	if was == to then return end
	Mock.runLastTarget = was
	Mock.runTarget = to
	dispatch("PLAYER_TARGET_CHANGED")
end

local CHANNELS = { say = true, s = true, yell = true, y = true, party = true, p = true, raid = true,
	ra = true, emote = true, e = true, me = true, w = true, whisper = true, tell = true }

local function castLine(spell)
	local now = Mock.now
	local cd = Mock.spellCooldowns and Mock.spellCooldowns[GCD_ID]
	if Mock.gcdOnCast and type(cd) == "table" and (cd.startTime or 0) + (cd.duration or 0) > now then
		Mock.castLog[#Mock.castLog + 1] = { spell = spell, refused = "cooldown", at = now }
		return
	end
	local target = Mock.runTarget and Mock.runTarget.name or nil
	local entry = { spell = spell, target = target, at = now, depth = Mock.macroDepth }
	Mock.castLog[#Mock.castLog + 1] = entry
	if Mock.gcdOnCast then
		Mock.spellCooldowns = Mock.spellCooldowns or {}
		Mock.spellCooldowns[GCD_ID] = { startTime = now, duration = Mock.gcdOnCast, isActive = true }
	end
	if not Mock.castEvents then return end
	local id = Mock.spellIdFor and Mock.spellIdFor(spell) or 0
	local args = { "UNIT_SPELLCAST_SENT", "player", target or (UnitName("player")), "Cast-mock-" .. #Mock.castLog, id }
	if Mock.castEvents == "sync" then
		dispatch(unpack(args))
	else
		Mock.queuedEvents[#Mock.queuedEvents + 1] = args
	end
end

-- One line of a running macro.
function Mock.execLine(line)
	if line == "" or line:sub(1, 1) == "#" then return end
	local command, rest = line:match("^/(%S+)%s*(.-)%s*$")
	if not command then error("mock macro: not a command: " .. line, 0) end
	command = command:lower()
	if command == "click" then
		-- SlashCommands.lua: name, then the button, then the down flag
		-- (TypeUtil's StringToBoolean of "" is false: an up click).
		local name, mouseButton, down = rest:match("([^%s]+)%s+([^%s]+)%s*(.*)")
		if not name then name = rest end
		if not mouseButton then mouseButton = "LeftButton" end
		down = down and (down:lower() == "1" or down:lower() == "true") or false
		local button = (Mock.namedFrames and Mock.namedFrames[name]) or rawget(_G, name)
		if type(button) == "table" and button._frameType == "Button" and button.Click then
			button:Click(mouseButton, down)
		end
	elseif command == "target" then
		local found = findUnit(rest)
		if found then retarget(found) end
	elseif command == "cleartarget" then
		retarget(nil)
	elseif command == "targetlasttarget" then
		retarget(Mock.runLastTarget)
	elseif command == "cast" then
		castLine(rest)
	elseif command == "use" then
		Mock.castLog[#Mock.castLog + 1] = { use = rest, at = Mock.now, depth = Mock.macroDepth }
	elseif CHANNELS[command] then
		Mock.saidLog[#Mock.saidLog + 1] = { channel = command, text = rest, at = Mock.now }
	elseif command == "cancelqueuedspell" then
		return
	else
		error("mock macro: no such command /" .. command, 0)
	end
end

-- A macro's text run as the client runs one: every line, top to bottom. Run
-- from inside another macro, under Mock.macroChain "refused", nothing of it
-- runs.
function Mock.runMacroText(text)
	if Mock.macroDepth > 0 and Mock.macroChain == "refused" then
		Mock.macroLog[#Mock.macroLog + 1] = { refused = "chain", text = text }
		return false
	end
	Mock.macroDepth = Mock.macroDepth + 1
	local ok, err = pcall(function()
		for line in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do Mock.execLine(line) end
	end)
	Mock.macroDepth = Mock.macroDepth - 1
	if Mock.macroDepth == 0 and #Mock.queuedEvents > 0 then
		local queued = Mock.queuedEvents
		Mock.queuedEvents = {}
		for _, args in ipairs(queued) do dispatch(unpack(args)) end
	end
	if not ok then error(err, 0) end
	return true
end

-- GetRunningMacro: the place of the macro running, as the client answers it
-- while one runs (every branch's GlobalAPI has it), nil otherwise.
function GetRunningMacro()
	return Mock.runningMacro
end

-- The macro on an action bar slot pressed, by `how.via` "mouse" or "key": the
-- bar's own button runs it (ActionButton.lua: a mouse press with isKeyPress
-- false and isSecureAction true, a key with both true; `how.keyDown` says on
-- which phase, which changes nothing about what runs). GetRunningMacro names
-- it while it runs. The casts it logged.
function Mock.pressBar(slot, how)
	how = how or { via = "mouse" }
	local macro = macroAt(Mock.bar[slot])
	if not macro then return nil end
	local before = #Mock.castLog
	Mock.pressFlags = how.via == "key" and { isKeyPress = true, isSecureAction = true }
		or { isKeyPress = false, isSecureAction = true }
	local was = Mock.runningMacro
	Mock.runningMacro = Mock.bar[slot]
	local ok, err = pcall(Mock.runMacroText, macro.body or "")
	Mock.runningMacro = was
	Mock.pressFlags = nil
	if not ok then error(err, 0) end
	local casts = {}
	for i = before + 1, #Mock.castLog do
		if Mock.castLog[i].spell and not Mock.castLog[i].refused then casts[#casts + 1] = Mock.castLog[i] end
	end
	return casts
end
