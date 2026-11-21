-- Pass 2, the window lens: what the review of 1.11.34's options window found.
-- Each scenario is red on the tree it was written against and goes green with
-- its fix. Every name starts with "pass2-window: " so a mutation can name one.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local freshPrompt, findOption = H.freshPrompt, H.findOption

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- One locale's table, loaded as that client.
local function localeTable(scenario, code)
	Mock.reset()
	Mock.locale = code
	local ns = load(scenario)
	Mock.reset()
	return ns and ns.L
end

-- ------------------------------------------------------------------ 1
do
	local scenario = "pass2-window: the German Cure myself too says cleanse, not remove"
	local L = localeTable(scenario, "deDE")
	if L then
		local text = tostring(L["Cure myself too"])
		if text:find("entfernen", 1, true) or not text:find("reinigen", 1, true) then
			fail(scenario, "the switch reads " .. text)
		end
	end
end

-- ------------------------------------------------------------------ 2
-- The client's own names (spells 543 and 6143 on each client's spell data).
do
	local WARDS = {
		frFR = { "Gardien de feu", "Gardien de givre" },
		koKR = { "화염계 수호", "냉기계 수호" },
	}
	for _, code in ipairs({ "frFR", "koKR" }) do
		local scenario = "pass2-window: Fire Ward and Frost Ward carry the client's names in " .. code
		local L = localeTable(scenario, code)
		if L then
			local label = tostring(L["Fire Ward or Frost Ward"])
			local note = tostring(L["Mana Shield, Fire Ward and Frost Ward are reminded outside a fight only: from the pull until the fight ends Manners offers none of them, so in a fight you recast them yourself. Each lasts a minute or less."])
			for _, name in ipairs(WARDS[code]) do
				if not label:find(name, 1, true) then fail(scenario, "the row's label lacks " .. name .. ": " .. label) end
				if not note:find(name, 1, true) then fail(scenario, "the note lacks " .. name) end
			end
		end
	end
end

-- ------------------------------------------------------------------ 3
-- In a fight, my key casts on the shared Default profile: chosen on a priest,
-- it must not arm a paladin who never chose it.
do
	local scenario = "pass2-window: a fight key chosen on a priest does not arm a paladin on the same profile"
	local sv
	local everything = setmetatable({}, { __index = function() return true end })
	local function login(class, body)
		Mock.reset()
		Mock.setFlavour("vanilla")
		Mock.class = class
		Mock.knownSpells = everything
		-- The one saved file, shared by both logins (the mock's AceDB).
		if sv then Mock.sv = sv else sv = Mock.sv end
		local ok, err = pcall(function()
			local ns = load(scenario)
			if not ns then return end
			freshPrompt(ns, scenario)
			ns.Guard("probe", ns.ProbeCapabilities)
			body(ns)
			noErrors(scenario, ns)
		end)
		Mock.reset()
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	local chose = false
	login("PRIEST", function(ns)
		local select_ = findOption(ns.optionsTable, "fightKeySpell")
		if not select_ or select_.values().flash == nil then
			fail(scenario, "SKIPPED -- the priest has no Flash Heal to pick")
			return
		end
		select_.set({ "fightKeySpell" }, "flash")
		chose = ns.FightKey.Chosen() ~= nil
		if not chose then fail(scenario, "SKIPPED -- the priest's choice did not take") end
	end)
	if chose then
		login("PALADIN", function(ns)
			local row = ns.FightKey.Chosen()
			if row then
				fail(scenario, "the paladin's prompt key is lent to '" .. tostring(row.key) .. "' (spell " .. tostring(row.id) .. ") in a fight, chosen on a priest")
			end
			local select_ = findOption(ns.optionsTable, "fightKeySpell")
			if select_ and select_.hidden() ~= true then
				local value = select_.get({ "fightKeySpell" })
				if select_.values()[value] == nil then
					fail(scenario, "the paladin's select holds " .. tostring(value) .. ", which it does not list")
				end
			end
		end)
		login("WARRIOR", function(ns)
			local select_ = findOption(ns.optionsTable, "fightKeySpell")
			if select_ and select_.hidden() ~= true then
				local value = select_.get({ "fightKeySpell" })
				if select_.values()[value] == nil then
					fail(scenario, "the warrior's select holds " .. tostring(value) .. ", which it does not list: a blank field")
				end
			end
		end)
	end
end

-- ------------------------------------------------------------------ 4
do
	local scenario = "pass2-window: own words cut to fit end on a whole character"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		local function whole(text)
			-- Valid UTF-8 from end to end.
			local i, n = 1, #text
			while i <= n do
				local c = text:byte(i)
				local len = c < 0x80 and 1 or (c >= 0xF0 and 4) or (c >= 0xE0 and 3) or (c >= 0xC0 and 2) or 0
				if len == 0 or i + len - 1 > n then return false end
				for j = i + 1, i + len - 1 do
					local b = text:byte(j)
					if b < 0x80 or b > 0xBF then return false end
				end
				i = i + len
			end
			return true
		end
		for _, sample in ipairs({ string.rep("你", 70), string.rep("é", 101), "a" .. string.rep("감", 70) }) do
			local out = ns.Ask.CleanOwn(sample)
			if #out > ns.Ask.OWN_MAX then fail(scenario, "kept " .. #out .. " bytes") end
			if not whole(out) then
				fail(scenario, ("%d bytes in, %d out, and the last character is cut in half"):format(#sample, #out))
			end
		end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ 5
do
	local scenario = "pass2-window: Who to buff's reset puts back the fight switches it draws"
	Mock.reset()
	Mock.class = "HUNTER"
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			freshPrompt(ns, scenario)
			local Page = ns.OptionsPage
			local p = ns.db.profile
			for _, path in ipairs({ "who.curesFight", "who.beastMendFight" }) do
				if H.layoutInToc() and not H.placedOn(ns, path) then
					fail(scenario, "SKIPPED -- " .. path .. " is drawn on no page")
				end
			end
			p.prompt.cureFight = true
			p.beast.fightMend = false
			Page.ResetPage("who")
			if p.prompt.cureFight ~= false then
				fail(scenario, "Offer my cure in a fight stays " .. tostring(p.prompt.cureFight) .. " after the page's reset")
			end
			if p.beast.fightMend == false then
				fail(scenario, "Offer Mend Pet in a fight stays off after the page's reset")
			end
			noErrors(scenario, ns)
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ 6
-- A mage below the level of Remove Lesser Curse: the cure's key is offered
-- only with a cure to cast, and its line names the spell.
do
	local scenario = "pass2-window: the cure's key is not offered, or said, with no cure learned"
	Mock.reset()
	Mock.setFlavour("vanilla")
	Mock.class = "MAGE"
	Mock.knownSpells = {}
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			freshPrompt(ns, scenario)
			ns.Guard("probe", ns.ProbeCapabilities)
			if ns.CureFightSpells() ~= nil then fail(scenario, "SKIPPED -- the mage knows a cure") return end
			ns.db.profile.prompt.cureFight = true
			local switch = findOption(ns.optionsTable, "cureFight")
			local keyControl = findOption(ns.optionsTable, "cureFightKey")
			if not (switch and keyControl) then fail(scenario, "SKIPPED -- no cure controls") return end
			Mock.bindings = Mock.bindings or {}
			Mock.bindings.F = "MANNERS_SOMETHING_ELSE"
			Mock.printed = {}
			keyControl.set({ "cureFightKey" }, "F")
			local said
			for _, line in ipairs(Mock.printed) do
				if line:find("MANNERS_SOMETHING_ELSE", 1, true) then said = line end
			end
			local shown = switch.hidden() ~= true or keyControl.hidden() ~= true
			if shown and said and said:find("casts %.$") then
				fail(scenario, "the switch is offered with no cure learned, and chat says: " .. said)
			elseif shown and not said then
				fail(scenario, "the switch is offered with no cure learned")
			end
			noErrors(scenario, ns)
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ 7
-- The page grows while its bar is dragged (the Right now line painted again):
-- the thumb stays under the cursor.
do
	local scenario = "pass2-window: the page bar's thumb stays under the cursor when the page grows mid-drag"
	Mock.reset()
	FT.install()
	local was = rawget(_G, "GetCursorPosition")
	local cur = { y = 0 }
	rawset(_G, "GetCursorPosition", function() return 100, cur.y end)
	Mock.buttonsDown.LeftButton = true
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local UI = ns.WindowUI
		ns.OpenOptions()
		local tried = false
		for _, id in ipairs({ "who", "skip", "when", "appearance", "click" }) do
			UI.ShowPage(id)
			local view = UI.view
			if view.range > 0 then
				local bar, thumb = view.bar, view.thumb
				bar._top, bar._height = 600, view.height - 8
				UI.ScrollTo(0)
				local travel = bar._height - thumb:GetHeight()
				if travel > 80 then
					tried = true
					local function offsetNow()
						local p = thumb.points and thumb.points[1]
						return p and -(p[5] or 0) or 0
					end
					-- Halfway down the page, the thumb taken by its middle.
					UI.ScrollTo(view.range / 2)
					local start = offsetNow()
					cur.y = 600 - start - thumb:GetHeight() / 2
					Mock.mouseDown(bar)
					cur.y = cur.y - 40
					bar.scripts.OnUpdate(bar, 0.016)
					-- Three lines more on the page, the cursor where it was.
					UI.SetContentHeight(view.range + view.height + 42)
					bar.scripts.OnUpdate(bar, 0.016)
					local offset = offsetNow()
					if math.abs(offset - (start + 40)) > 1 then
						fail(scenario, ("%s: the cursor is 40 below where it took the thumb at %s, the thumb at %s"):format(id, tostring(start), tostring(offset)))
					end
					Mock.mouseUp(bar)
					break
				end
			end
		end
		if not tried then fail(scenario, "SKIPPED -- no page was long enough to scroll") end
		noErrors(scenario, ns)
	end)
	rawset(_G, "GetCursorPosition", was)
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 8
-- A profile saved before the fight key was kept per class: the one key goes to
-- the class whose list alone holds it; one two classes share goes to the class
-- logging in when its list holds it, and is dropped otherwise.
do
	local scenario = "pass2-window: an old shared fight key goes to the one class that holds it"
	local everything = setmetatable({}, { __index = function() return true end })
	local function login(class, legacy, body)
		Mock.reset()
		Mock.setFlavour("vanilla")
		Mock.class = class
		Mock.knownSpells = everything
		local ok, err = pcall(function()
			local ns = load(scenario)
			if not ns then return end
			freshPrompt(ns, scenario)
			ns.Guard("probe", ns.ProbeCapabilities)
			local p = ns.db.profile.prompt
			p.fightKeySpells = nil
			p.fightKeySpell = legacy
			ns.ClampSettings()
			body(ns, p)
			noErrors(scenario, ns)
		end)
		Mock.reset()
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	login("PRIEST", "shield", function(ns, p)
		if p.fightKeySpell ~= nil then fail(scenario, "the old field is kept: " .. tostring(p.fightKeySpell)) end
		if type(p.fightKeySpells) ~= "table" or p.fightKeySpells.PRIEST ~= "shield" then
			fail(scenario, "Power Word: Shield, only a priest's, was not carried to the priest")
		end
		if ns.FightKey.Value() ~= "shield" then fail(scenario, "the priest's select reads " .. tostring(ns.FightKey.Value())) end
	end)
	login("PALADIN", "flash", function(ns, p)
		if p.fightKeySpell ~= nil then fail(scenario, "the old field is kept: " .. tostring(p.fightKeySpell)) end
		if p.fightKeySpells.PALADIN ~= "flash" then fail(scenario, "flash, shared by two classes, was not carried to the paladin logging in") end
		if p.fightKeySpells.PRIEST ~= nil then fail(scenario, "flash was given to a priest as well") end
	end)
	login("MAGE", "flash", function(ns, p)
		if p.fightKeySpell ~= nil then fail(scenario, "the old field is kept: " .. tostring(p.fightKeySpell)) end
		if next(p.fightKeySpells) ~= nil then fail(scenario, "flash was given to a mage, whose list lacks it") end
	end)
end

-- ------------------------------------------------------------------ 8b
-- The fight key travels in a settings string, class by class.
do
	local scenario = "pass2-window: the fight key travels in a settings string"
	Mock.reset()
	Mock.setFlavour("vanilla")
	Mock.class = "PRIEST"
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.Guard("probe", ns.ProbeCapabilities)
		local p = ns.db.profile.prompt
		p.fightKeySpells = { PRIEST = "flash" }
		local text = ns.ExportSettings() or ""
		if not text:find("prompt.fightKeySpells=PRIEST=flash", 1, true) then
			fail(scenario, "the string lacks PRIEST=flash: " .. text)
		end
		p.fightKeySpells = {}
		if ns.ImportSettings(text) ~= true then
			fail(scenario, "the import was refused")
			return
		end
		if p.fightKeySpells.PRIEST ~= "flash" then
			fail(scenario, "the choice did not come back: " .. tostring(p.fightKeySpells.PRIEST))
		end
		noErrors(scenario, ns)
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 8c
-- Hold back short buffs in cities and inns still holds your own short buffs
-- with Never in cities and inns on, so its controls are not greyed there.
do
	local scenario = "pass2-window: the short-buff hold stays live beside Never in cities and inns"
	Mock.reset()
	Mock.setFlavour("vanilla")
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local f = ns.db.profile.filters
		f.quietInTowns = true
		f.quietShortInTowns = true
		local switch = findOption(ns.optionsTable, "quietShortInTowns")
		local minutes = findOption(ns.optionsTable, "quietShortMinutes")
		if not (switch and minutes) then
			fail(scenario, "the two controls are missing")
			return
		end
		if switch.disabled and switch.disabled({}) then fail(scenario, "the switch is greyed while it acts on you") end
		if minutes.disabled and minutes.disabled({}) then fail(scenario, "the minutes are greyed while the switch is on and acts on you") end
		f.quietShortInTowns = false
		if not (minutes.disabled and minutes.disabled({})) then fail(scenario, "the minutes stay live with the switch off") end
		noErrors(scenario, ns)
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 9
-- The Who page's cure-in-a-fight switch follows the same rule as Look's: a cure
-- learned, or nothing to switch.
do
	local scenario = "pass2-window: the cure's switch on Who to buff is offered only with a cure learned"
	local function check(known)
		Mock.reset()
		Mock.setFlavour("vanilla")
		Mock.class = "MAGE"
		Mock.knownSpells = known
		local ns = load(scenario)
		if ns then
			local ok, err = pcall(function()
				freshPrompt(ns, scenario)
				ns.Guard("probe", ns.ProbeCapabilities)
				local who = findOption(ns.optionsTable, "curesFight")
				local look = findOption(ns.optionsTable, "cureFight")
				if not (who and look) then fail(scenario, "SKIPPED -- no cure controls") return end
				local learned = ns.CureFightSpells() ~= nil
				for name, control in pairs({ who = who, look = look }) do
					if learned and control.hidden() == true then
						fail(scenario, name .. "'s switch is hidden with a cure learned")
					elseif not learned and control.hidden() ~= true then
						fail(scenario, name .. "'s switch is offered with no cure learned")
					end
				end
				noErrors(scenario, ns)
			end)
			if not ok then fail(scenario, "threw: " .. tostring(err)) end
		end
		Mock.reset()
	end
	check({})
	check(setmetatable({}, { __index = function() return true end }))
end

-- ------------------------------------------------------------------ 10
-- Whatever is shown, the key's chat line never says it casts nothing.
do
	local scenario = "pass2-window: the cure key's line never names an empty spell"
	Mock.reset()
	Mock.setFlavour("vanilla")
	Mock.class = "MAGE"
	Mock.knownSpells = {}
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			freshPrompt(ns, scenario)
			ns.Guard("probe", ns.ProbeCapabilities)
			local keyControl = findOption(ns.optionsTable, "cureFightKey")
			if not keyControl then fail(scenario, "SKIPPED -- no cure key") return end
			Mock.bindings = Mock.bindings or {}
			Mock.bindings.F = "MANNERS_SOMETHING_ELSE"
			Mock.printed = {}
			keyControl.set({ "cureFightKey" }, "F")
			local said
			for _, line in ipairs(Mock.printed) do
				if line:find("MANNERS_SOMETHING_ELSE", 1, true) then said = line end
			end
			-- With no cure learned the button casts nothing: the line neither
			-- names an empty spell nor says it buffs the prompted player; it
			-- is not said at all.
			if said then fail(scenario, "chat says: " .. said) end
			noErrors(scenario, ns)
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end
