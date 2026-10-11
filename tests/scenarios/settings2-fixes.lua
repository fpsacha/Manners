-- Round 34, the settings: two faults, each held here by what the player would
-- see, on every client (the code is shared; each scenario sets its client with
-- Mock.setFlavour, so it also judges on Forever whatever the run's client is).
--
--   * /manners off typed in a fight, and the launcher's middle click, said
--     only "disabled." / "switched off from the launcher" while the prompt's
--     secure button still held the macro the fight froze: a keypress goes on
--     casting /target + /cast at that person until the fight ends (the panel
--     paints "switched off -- a press still casts what the fight froze", the
--     launcher's tooltip says it). The chat line now says it too, with the
--     launcher's own sentence. /manners lock after an unlock made before the
--     fight is left alone: "locked." is true, the panel already says the
--     prompt is held, and a better line needs a new string.
--   * /manners macro (and Start's Make a macro) with the account list and the
--     character's both full: CreateMacro raises an error on a full list
--     (warcraft.wiki.gg API_CreateMacro), so both tries failed and the player
--     read only "could not create the macro." The sentence written for this,
--     "no free macro slots. Delete one and try again.", could not be reached.
--     The caps are Constants.MacroConsts (120 account-wide and 30 per
--     character, live and forever in Gethe/wow-ui-source,
--     MacroConstantsDocumentation) on Forever and retail, and the MAX_*_MACROS
--     globals Blizzard_MacroUI reads on the classic family.
--
-- Every scenario name starts with "settings2-fix:" so the mutations in
-- tests/mutations/settings2-fixes.py can name the one that has to catch them.
-- Globals a scenario replaces are put back after it, whether it finished or
-- threw.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local FLAVOURS = { "camelot", "vanilla", "tbc", "mists", "mainline" }

local function said() return table.concat(Mock.printed or {}, "\n") end

-- ------------------------------------------------------------------ off in a fight

-- A prompt armed at Petra, its button protected the way the client does in a
-- fight, and body(ns, button) run on it. Everything put back after.
local function armed(scenario, flavour, body)
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = "MAGE"
	local restore = H.strangers({ nameplate1 = { "Petra", "" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		Mock.advance(60)
		ns.nameplateUnits["nameplate1"] = true
		ns.Prompt:Refresh()
		local button = ns.Prompt:GetButton()
		Mock.protect(button)
		local macro = button:GetAttribute("macrotext1")
		if type(macro) ~= "string" or not macro:find("Petra", 1, true) then
			fail(scenario, "SKIPPED -- the prompt was not armed at Petra before the fight: " .. tostring(macro))
			return
		end
		body(ns, button, macro)
	end)
	restore()
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local HELD = "a press still casts it"

for _, flavour in ipairs(FLAVOURS) do
	-- The fault: the fight froze the macro on the button, /manners off cannot
	-- clear it, and the line said only "disabled."
	local scenario = "settings2-fix: " .. flavour .. ": /manners off in a fight says a press still casts what the fight froze"
	armed(scenario, flavour, function(ns, button, macro)
		Mock.inCombat = true
		Mock.printed = {}
		ns.addon:HandleSlash("off")
		ns.addon:Tick()
		if button:GetAttribute("macrotext1") ~= macro then
			fail(scenario, "SKIPPED -- the button was disarmed in the fight, so \"disabled.\" is true")
		elseif not said():find(HELD, 1, true) then
			fail(scenario, "/manners off in a fight said only " .. ("%q"):format(said())
				.. " while the button is still armed (" .. macro:gsub("\n", " | ") .. "): a press casts")
		end
	end)

	-- The same word out of a fight: the macro is cleared, a press casts nothing,
	-- and the plain line is the true one.
	scenario = "settings2-fix: " .. flavour .. ": /manners off out of a fight is the plain line"
	armed(scenario, flavour, function(ns, button)
		Mock.inCombat = false
		Mock.printed = {}
		ns.addon:HandleSlash("off")
		if button:GetAttribute("macrotext1") then
			fail(scenario, "SKIPPED -- the button was still armed after /manners off out of a fight")
		elseif said():find(HELD, 1, true) then
			fail(scenario, "/manners off out of a fight says a press still casts: " .. said())
		elseif not said():find("disabled.", 1, true) then
			fail(scenario, "/manners off out of a fight no longer says it is disabled: " .. said())
		end
	end)

	-- A fight that began with nothing on the prompt froze no macro: a press
	-- casts nothing, and the plain line is the true one.
	scenario = "settings2-fix: " .. flavour .. ": /manners off in a fight with nothing armed is the plain line"
	armed(scenario, flavour, function(ns, button)
		Mock.inCombat = false
		ns.addon:HandleSlash("unlock")
		ns.Prompt:Refresh()
		if button:GetAttribute("macrotext1") then
			fail(scenario, "SKIPPED -- an unlocked prompt was still armed")
			return
		end
		Mock.inCombat = true
		Mock.printed = {}
		ns.addon:HandleSlash("off")
		if said():find(HELD, 1, true) then
			fail(scenario, "nothing is armed, yet /manners off says a press still casts: " .. said())
		elseif not said():find("disabled.", 1, true) then
			fail(scenario, "/manners off with nothing armed no longer says it is disabled: " .. said())
		end
	end)

	-- The launcher's middle click throws the same switch with a line of its own.
	scenario = "settings2-fix: " .. flavour .. ": the launcher's middle click in a fight says a press still casts what the fight froze"
	armed(scenario, flavour, function(ns, button, macro)
		local broker = Mock.broker
		if not (broker and broker.OnClick) then
			fail(scenario, "SKIPPED -- no launcher was registered")
			return
		end
		Mock.inCombat = true
		Mock.printed = {}
		broker.OnClick({}, "MiddleButton")
		if ns.db.profile.enabled or button:GetAttribute("macrotext1") ~= macro then
			fail(scenario, "SKIPPED -- the click did not switch it off over a frozen, armed button")
		elseif not said():find(HELD, 1, true) then
			fail(scenario, "switched off in a fight from the launcher, chat says only " .. ("%q"):format(said())
				.. " while the button is still armed")
		elseif not said():find("middle-click it again", 1, true) then
			fail(scenario, "the way back left the line: " .. said())
		end
	end)

	-- Switched back on in the same fight, the line about being off would be a lie.
	scenario = "settings2-fix: " .. flavour .. ": the launcher's middle click switching it back on in a fight does not say it is off"
	armed(scenario, flavour, function(ns, button, macro)
		local broker = Mock.broker
		if not (broker and broker.OnClick) then
			fail(scenario, "SKIPPED -- no launcher was registered")
			return
		end
		Mock.inCombat = true
		broker.OnClick({}, "MiddleButton")
		Mock.printed = {}
		broker.OnClick({}, "MiddleButton")
		if not ns.db.profile.enabled or button:GetAttribute("macrotext1") ~= macro then
			fail(scenario, "SKIPPED -- the second click did not switch it back on over the frozen button")
		elseif said():find(HELD, 1, true) or said():lower():find("switched off", 1, true) then
			fail(scenario, "switched back on, chat still says it is off: " .. said())
		end
	end)

	-- And out of a fight there is nothing held to say.
	scenario = "settings2-fix: " .. flavour .. ": the launcher's middle click out of a fight does not say a press still casts"
	armed(scenario, flavour, function(ns, button)
		local broker = Mock.broker
		if not (broker and broker.OnClick) then
			fail(scenario, "SKIPPED -- no launcher was registered")
			return
		end
		Mock.inCombat = false
		Mock.printed = {}
		broker.OnClick({}, "MiddleButton")
		if ns.db.profile.enabled then
			fail(scenario, "SKIPPED -- the click did not switch it off")
		elseif said():find(HELD, 1, true) then
			fail(scenario, "switched off out of a fight, chat says a press still casts: " .. said())
		end
	end)
end

-- ------------------------------------------------------------------ macro slots

-- The caps as each client keeps them: Constants.MacroConsts on Forever and
-- retail, the globals on the classic family.
local SHAPE = {
	camelot = "constants", mainline = "constants",
	vanilla = "globals", tbc = "globals", mists = "globals",
}

-- One Make a macro with the lists at account/character macros used, the
-- client's own refusal as an error when the list asked for is full (or
-- always, for `alwaysRefuse`), and body(ns, made) run after /manners macro.
-- `caps` is false for a client that tells no cap.
local function macros(scenario, flavour, account, character, options, body)
	options = options or {}
	Mock.reset()
	Mock.setFlavour(flavour)
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local realCreate, realNum, realIndex = CreateMacro, GetNumMacros, GetMacroIndexByName
	local realConstants = rawget(_G, "Constants")
	local realAccount, realCharacter = rawget(_G, "MAX_ACCOUNT_MACROS"), rawget(_G, "MAX_CHARACTER_MACROS")
	local capAccount, capCharacter = 120, SHAPE[flavour] == "constants" and 30 or 18
	if options.caps == false then
		rawset(_G, "Constants", nil)
		rawset(_G, "MAX_ACCOUNT_MACROS", nil)
		rawset(_G, "MAX_CHARACTER_MACROS", nil)
	elseif SHAPE[flavour] == "constants" then
		rawset(_G, "Constants", { MacroConsts = { MAX_ACCOUNT_MACROS = capAccount, MAX_CHARACTER_MACROS = capCharacter } })
		rawset(_G, "MAX_ACCOUNT_MACROS", nil)
		rawset(_G, "MAX_CHARACTER_MACROS", nil)
	else
		rawset(_G, "Constants", nil)
		rawset(_G, "MAX_ACCOUNT_MACROS", capAccount)
		rawset(_G, "MAX_CHARACTER_MACROS", capCharacter)
	end
	local made = {}
	GetNumMacros = function() return account, character end
	GetMacroIndexByName = function(name) return made[name] or 0 end
	CreateMacro = function(name, icon, text, perCharacter)
		if options.alwaysRefuse then error("Interface action failed because of an AddOn", 2) end
		if perCharacter and character >= capCharacter then error("Macro limit reached for character macros", 2) end
		if not perCharacter and account >= capAccount then error("Macro limit reached for account macros", 2) end
		made[name] = perCharacter and 121 or 1
		return made[name]
	end
	local ok, err = pcall(function()
		Mock.printed = {}
		ns.addon:HandleSlash("macro")
		body(ns, made, capAccount, capCharacter)
	end)
	CreateMacro, GetNumMacros, GetMacroIndexByName = realCreate, realNum, realIndex
	rawset(_G, "Constants", realConstants)
	rawset(_G, "MAX_ACCOUNT_MACROS", realAccount)
	rawset(_G, "MAX_CHARACTER_MACROS", realCharacter)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	Mock.reset()
end

local FULL = "no free macro slots"
local COULD_NOT = "could not create the macro"

for _, flavour in ipairs(FLAVOURS) do
	-- The fault: both lists full, both tries raise, and the player was told
	-- only that the macro could not be made.
	local scenario = "settings2-fix: " .. flavour .. ": /manners macro with every macro slot used says the slots are full"
	local cap = SHAPE[flavour] == "constants" and 30 or 18
	macros(scenario, flavour, 120, cap, nil, function(ns, made)
		if made.Manners then
			fail(scenario, "SKIPPED -- a macro was made with every slot used")
		elseif not said():find(FULL, 1, true) then
			fail(scenario, "both macro lists are full and the player is told only: " .. said())
		elseif said():find(COULD_NOT, 1, true) then
			fail(scenario, "both lists are full and the line blames something else too: " .. said())
		end
	end)

	-- Not the slots: a refusal for another reason with room in one list or
	-- both (one short of the character cap, which a hard-coded 18 would call
	-- full on Forever and retail, where it is 30).
	for _, used in ipairs({ { 40, 18 }, { 120, cap - 1 }, { 40, cap } }) do
		scenario = ("settings2-fix: %s: a refusal with %d account and %d character macros used is not blamed on the slots")
			:format(flavour, used[1], used[2])
		macros(scenario, flavour, used[1], used[2], { alwaysRefuse = true }, function(ns, made)
			if said():find(FULL, 1, true) then
				fail(scenario, "one list has room, yet the player is told the slots are full: " .. said())
			elseif not said():find(COULD_NOT, 1, true) then
				fail(scenario, "a refused macro says nothing about it: " .. said())
			end
		end)
	end

	-- The account list full alone: the character's list takes it.
	scenario = "settings2-fix: " .. flavour .. ": with the account list full the macro goes on the character's"
	macros(scenario, flavour, 120, 3, nil, function(ns, made)
		if not made.Manners then
			fail(scenario, "no macro was made with 15 character slots free: " .. said())
		elseif said():find(FULL, 1, true) or said():find(COULD_NOT, 1, true) then
			fail(scenario, "the macro was made and the line says it was not: " .. said())
		end
	end)
end

-- A client that tells no cap is not guessed at: the refusal stays "could not".
do
	local scenario = "settings2-fix: camelot: a macro list cap the client does not tell is not guessed"
	macros(scenario, "camelot", 120, 30, { caps = false, alwaysRefuse = true }, function(ns, made)
		if said():find(FULL, 1, true) then
			fail(scenario, "no cap was readable, yet the player is told the slots are full: " .. said())
		elseif not said():find(COULD_NOT, 1, true) then
			fail(scenario, "a refused macro says nothing about it: " .. said())
		end
	end)
end
