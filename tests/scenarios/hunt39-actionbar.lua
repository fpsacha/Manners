-- Hunt 39: the prompt on an action bar and on a controller, asked what a player
-- can reach that the first scenarios (actionbar.lua) did not.
--
--   * the key chip's words for a controller's buttons follow the client's: a
--     controller of another family told apart after the chip was first drawn
--     changes the glyphs, and the pad's modifier CVars can be moved in a
--     session, so neither is read once for a key and kept;
--   * Start here says "drop it on any slot" only of the macro it put on the
--     cursor, not of any macro the player picked up since.
--
-- Every name starts with "hunt39-actionbar:" so a mutation in
-- tests/mutations/hunt39-actionbar.py can name exactly one.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local COMMAND = "CLICK MannersPrompt:LeftButton"
local BODY = "/click MannersPrompt LeftButton 1"

-- The globals a scenario replaces, put back whatever happens.
local TOUCHED = { "GetCVar", "GetBindingText", "PickupMacro", "GetCursorInfo" }

local function with(scenario, body, tree)
	Mock.reset()
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	if tree then FT.install() end
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns, scenario) end
	restore()
	if tree then FT.uninstall() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function emulate(shift, ctrl)
	rawset(_G, "GetCVar", function(name)
		return ({ GamePadEmulateShift = shift, GamePadEmulateCtrl = ctrl, GamePadEmulateAlt = "none" })[name]
	end)
end

-- ------------------------------------------------------------------ 1
-- The chip's words are the client's as of now.
with("hunt39-actionbar: the key chip follows the controller's glyphs and the pad's modifier settings", function(ns, scenario)
	local restoreText = Mock.withBindingText()
	local plain = Mock.bindingText
	freshPrompt(ns, scenario)
	local checked = 0
	for _, style in ipairs({ "arcane", "toast", "ribbon", "letter", "leather" }) do
		for _, key in ipairs({ "PAD1", "SHIFT-PAD1" }) do
			local tag = style .. ", " .. key
			-- The first look at the controller: its buttons are the generic ones.
			rawset(_G, "GetBindingText", plain)
			emulate("PADLTRIGGER", "PADLSHOULDER")
			Mock.bindings = {}
			SetBinding(key, COMMAND)
			local p = ns.db.profile.prompt
			p.style, p.width, p.locked, p.hideInCombat = style, 250, true, false
			ns.Prompt:ApplyStyle()
			Mock.advance(60)
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			FT.settle()
			local look = ns.Prompt:Regions().look
			if not (look and look.keyText and look.keyText:IsShown()) then
				fail(scenario, "SKIPPED -- " .. tag .. " has no chip up")
			else
				checked = checked + 1
				local function chip()
					Mock.advance(1)
					ns.addon:Tick()
					FT.settle()
					return look.keyText:GetText() or ""
				end
				if not chip():find("Gen_", 1, true) then fail(scenario, "SKIPPED -- " .. tag .. " is not generic to begin with") end
				-- The client tells the controller's family apart: the glyphs are
				-- its own now, and the chip is drawn with them.
				rawset(_G, "GetBindingText", function(binding, short)
					return (plain(binding, short):gsub("Gen_", "Ps5_"))
				end)
				local then1 = chip()
				if then1:find("Gen_", 1, true) or not then1:find("Ps5_", 1, true) then
					fail(scenario, tag .. ": the chip still reads the old controller's glyphs: " .. then1)
				end
				-- The player moves Shift to the right shoulder.
				if key == "SHIFT-PAD1" then
					emulate("PADRSHOULDER", "PADLSHOULDER")
					local then2 = chip()
					if not then2:find("Ps5_RShoulder", 1, true) or then2:find("LTrigger", 1, true) then
						fail(scenario, tag .. ": the chip still reads the old modifier button: " .. then2)
					end
				end
			end
		end
	end
	Mock.bindings = {}
	restoreText()
	if checked == 0 then fail(scenario, "SKIPPED -- no chip was ever up") end
end, true)

-- ------------------------------------------------------------------ 2
-- The macro on the cursor is the one the button put there.
with("hunt39-actionbar: another macro on the cursor is not the one Start here says to drop", function(ns, scenario)
	freshPrompt(ns, scenario)
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	local make = ns.optionsTable.args.general.args.makeMacro
	local status = function() return H.optionText(ns.optionsTable.args.general.args.bindStatus.name) end
	make.func()
	local ours = GetMacroIndexByName("Manners")
	if ours == 0 or GetCursorInfo() ~= "macro" then fail(scenario, "SKIPPED -- the macro is not on the cursor") return end
	if not status():find("Drop it on any action bar slot", 1, true) then
		fail(scenario, "SKIPPED -- Start here does not say where to drop it: " .. status())
		return
	end
	-- The player puts it away and picks up another one from the macro window.
	ClearCursor()
	local other = CreateMacro("Other", "INV_MISC_NOTE_01", "/dance", false)
	PickupMacro(other)
	if select(2, GetCursorInfo()) ~= other then fail(scenario, "SKIPPED -- the other macro is not on the cursor") return end
	if status():find("Drop it on any action bar slot", 1, true) then
		fail(scenario, "Start here says to drop the Manners macro with another macro on the cursor")
	end
	-- And the flag does not come back for it later, with the real one picked up again.
	PickupMacro(ours)
	if status():find("Drop it on any action bar slot", 1, true) then
		fail(scenario, "the pick-up is remembered after another macro took the cursor")
	end
end)
