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

function EditMacro(index, name, icon, body)
	if blocked("EditMacro") then return end
	local macro = macroAt(index)
	if not macro then return end
	if name ~= nil then macro.name = name end
	if icon ~= nil then macro.icon = icon end
	if body ~= nil then macro.body = body end
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
