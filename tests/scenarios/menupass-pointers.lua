-- Text that tells a player where a control is names the page through the
-- window's own layout (Page.TabOf), so a control that moves, or a page that is
-- renamed or translated, is followed by every chat line and tooltip.
--
-- The fight buttons' tooltips (Will of the Forsaken, Mend Pet, the cure, the
-- consumables button) say where their settings are: those checks sit beside
-- each button's own hover in fightbuttons.lua, curefight.lua and supplies.lua,
-- under the name "menupass-pointers: the fight buttons say where their
-- settings are".
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

-- ------------------------------------------------------------------ 1
local scenario = "menupass-pointers: a page name follows its control"
Mock.reset()
FT.install()
Mock.class = "PALADIN"
local known, playerSpell = rawget(_G, "IsSpellKnown"), rawget(_G, "IsPlayerSpell")
local ns = load(scenario)
if ns then
	-- A paladin who knows his blessings, so the window has a Who to buff page.
	local set = {}
	for _, key in ipairs({ "wisdom", "might", "kings" }) do
		local buff = ns.FindBuff("PALADIN", key)
		for _, id in ipairs(buff and buff.ranks or {}) do set[id] = true end
	end
	IsSpellKnown = function(id) return set[id] == true end
	IsPlayerSpell = IsSpellKnown
	drive(scenario, ns)
	ns.Guard("probe", ns.ProbeCapabilities)
	ns.Prompt:ExitTest()
	local UI, Page = ns.WindowUI, ns.OptionsPage
	ns.OpenOptions("who")
	ns.Prompt:ExitTest()
	if not (UI and Page and Page.TabOf) then
		fail(scenario, "the options page has no TabOf")
	else
		local paths = { "who.quietInTowns", "when.hideMounted", "when.manaFloor", "who.restingOnly", "who.self",
			"who.curesSelf", "click.showPlates", "appearance.breakFree", "diagnostics.diag" }
		for _, path in ipairs(paths) do
			local id = UI.PageOf(path)
			local page = id and ns.WindowLayout.pages[id]
			local got = Page.TabOf(path)
			if not page then
				fail(scenario, path .. " is not placed on any page")
			elseif got ~= page.title then
				fail(scenario, path .. " is on the page " .. tostring(page.title) .. " but TabOf says " .. tostring(got))
			end
		end
		if Page.TabOf("nothing.here") ~= nil then fail(scenario, "an unplaced path got a page name") end
		-- A translation, or a test's override, is followed at the moment it is asked.
		ns.L["Quiet times"] = "X"
		local named = Page.TabOf("when.hideMounted")
		ns.L["Quiet times"] = nil
		if named ~= "X" then fail(scenario, "TabOf kept an old name for the page: " .. tostring(named)) end
		if Page.TabOf("when.hideMounted") ~= "Quiet times" then fail(scenario, "TabOf did not give the name back") end
	end
end
rawset(_G, "IsSpellKnown", known)
rawset(_G, "IsPlayerSpell", playerSpell)
FT.uninstall()
Mock.reset()

-- ------------------------------------------------------------------ 2
scenario = "menupass-pointers: no sentence names a page by hand"
Mock.reset()
do
	local function slurp(path)
		local f = io.open(path, "rb")
		if not f then return nil end
		local data = f:read("*a")
		f:close()
		return data
	end
	-- The root files, Options/, Options/Window/ and Prompt/: what the toc loads
	-- there, which is every file a sentence could be said from.
	local function wanted(file)
		if file:find("^Locales[\\/]") or file:find("^Libs[\\/]") then return false end
		return file:find("[\\/]") == nil or file:find("^Options[\\/]") or file:find("^Prompt[\\/]")
	end
	local LITERALS = { "Who to buff", "Who to skip", "When to offer", "What I say", "Look" }
	local seen = 0
	for _, file in ipairs(ADDON_FILES) do
		if wanted(file) then
			local text = slurp(dir .. "/" .. file)
			if text then
				seen = seen + 1
				local n = 0
				for line in (text .. "\n"):gmatch("(.-)\r?\n") do
					n = n + 1
					local code = line:gsub("^%s*%-%-.*$", "")
					local name = file:gsub("\\", "/")
					if code:find("Ref%(.-,%s*TAB%.") then
						fail(scenario, name .. ":" .. n .. " points at a page with TAB: use Page.RefTo")
					end
					for _, word in ipairs(LITERALS) do
						if code:find('L%["' .. word .. '"%]') then
							local home = name == "Options/Shared.lua"
								or (name == "Options/Window/Layout.lua" and code:find("title%s*=%s*L%["))
								or (name == "Options/Who.lua" and code:find("skipHeader", 1, true))
							if not home then
								fail(scenario, name .. ":" .. n .. " writes the page name " .. word .. " by hand: use Page.TabOf")
							end
						end
					end
				end
			end
		end
	end
	if seen < 20 then fail(scenario, "read only " .. seen .. " files: the file list is wrong") end
end
Mock.reset()
