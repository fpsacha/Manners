-- Use my class's look on each character (prompt.classLook, Looks/Looks.lua's ONE LOOK A CLASS; asked for on CurseForge): off by default and a profile from before it unchanged; on, every character on one profile wears the look made for its class, a mage the one of the mage's looks last clicked on a mage, any other look clicked the profile's own, worn with it off; the picker's line says which look is in use and why; the Look page's reset and a settings string carry it; every client.
-- Called by scenarios.lua with the addon directory and its helpers. Every name starts with "classlook:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function press(frame)
	local onClick = frame and frame:GetScript("OnClick")
	if onClick then onClick(frame, "LeftButton", false) end
end

local function enter(card)
	card._mouseOver = true
	local fn = card:GetScript("OnEnter")
	if fn then fn(card) end
end

local function leave(card)
	card._mouseOver = false
	local fn = card:GetScript("OnLeave")
	if fn then fn(card) end
end

local function cardOf(row, key)
	for _, card in ipairs(row.cards) do
		if card.key == key then return card end
	end
end

-- One session of a character of `opts.class` on `opts.sv`, the options window
-- open on Look; answers the saved variables to carry to the next.
local function session(scenario, opts, body)
	Mock.reset()
	Mock.class = opts.class or "MAGE"
	if opts.character then Mock.character = opts.character end
	if opts.sv then Mock.sv = opts.sv end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.OpenOptions("appearance", true)
		ns.Prompt:ExitTest()
		local UI = ns.WindowUI
		local row = UI.RowFor("appearance.style")
		if not (row and row.cards and UI.RowShown("appearance.style")) then
			fail(scenario, "the gallery is not on the Look page")
			return
		end
		row.tab = "all"
		ns.RefreshOptionsDisplay()
		body(ns, UI, row, ns.db.profile.prompt)
		noErrors(scenario, ns)
	end)
	local sv = Mock.sv
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
	return sv
end

local function switch(ns, UI, on)
	ns.WindowBind.Commit(UI.Item("appearance.classLook"), on)
	ns.RefreshOptionsDisplay()
end

local function has(text, part)
	return type(text) == "string" and text:find(part, 1, true) ~= nil
end

do
	local scenario = "classlook: off by default, and a profile from before it is as it was"
	local sv = session(scenario, { class = "MAGE" }, function(ns, UI, row, p)
		if p.classLook ~= false then fail(scenario, "classLook is " .. tostring(p.classLook)) end
		if p.style ~= "glass" then fail(scenario, "style is " .. tostring(p.style)) end
		if rawget(p, "profileStyle") ~= nil then fail(scenario, "profileStyle is set") end
		if not (type(p.classStyles) == "table" and next(p.classStyles) == nil) then
			fail(scenario, "classStyles is not an empty table")
		end
		ns.ClampSettings()
		if p.style ~= "glass" then fail(scenario, "the repair changed the style to " .. tostring(p.style)) end
		if row.whyShown ~= false or row.why:IsShown() then fail(scenario, "the in-use line shows with the switch off") end
		p.style = "luxe"
		p.classLook = nil
		p.classStyles = nil
	end)
	session(scenario, { class = "DRUID", character = "Dora Alt", sv = sv }, function(ns, UI, row, p)
		if p.style ~= "luxe" then fail(scenario, "an older profile's style is " .. tostring(p.style)) end
		if p.classLook ~= false then fail(scenario, "classLook is " .. tostring(p.classLook)) end
		if rawget(p, "profileStyle") ~= nil then fail(scenario, "profileStyle is set") end
		if type(p.classStyles) ~= "table" then fail(scenario, "classStyles is " .. tostring(p.classStyles)) end
	end)
end

do
	local scenario = "classlook: on, each character wears the look made for its class"
	local sv = session(scenario, { class = "DRUID" }, function(ns, UI, row, p)
		switch(ns, UI, true)
		if p.classLook ~= true then fail(scenario, "the switch did not turn it on") end
		if p.style ~= "wild" then fail(scenario, "a druid wears " .. tostring(p.style)) end
		if p.profileStyle ~= "glass" then fail(scenario, "profileStyle is " .. tostring(p.profileStyle)) end
		local look = ns.Looks.Get(p.style)
		if not look or look.key ~= "wild" then fail(scenario, "the registry has no look for " .. tostring(p.style)) end
	end)
	sv = session(scenario, { class = "PALADIN", character = "Paula Alt", sv = sv }, function(ns, UI, row, p)
		if p.style ~= "lightbringer" then fail(scenario, "a paladin wears " .. tostring(p.style)) end
		if p.profileStyle ~= "glass" then fail(scenario, "profileStyle is " .. tostring(p.profileStyle)) end
	end)
	session(scenario, { class = "DRUID", sv = sv }, function(ns, UI, row, p)
		if p.style ~= "wild" then fail(scenario, "the druid back wears " .. tostring(p.style)) end
		if p.profileStyle ~= "glass" then fail(scenario, "profileStyle is " .. tostring(p.profileStyle)) end
	end)
end

do
	local scenario = "classlook: a mage keeps the look picked among the mage's"
	local sv = session(scenario, { class = "MAGE" }, function(ns, UI, row, p)
		switch(ns, UI, true)
		if ns.Looks.ForClass("MAGE")[1] ~= "frost" then fail(scenario, "the first mage look is " .. tostring(ns.Looks.ForClass("MAGE")[1])) end
		if p.style ~= "frost" then fail(scenario, "a mage first wears " .. tostring(p.style)) end
		press(cardOf(row, "archmage"))
		ns.RefreshOptionsDisplay()
		if p.style ~= "archmage" then fail(scenario, "the click left " .. tostring(p.style)) end
		if p.classStyles.MAGE ~= "archmage" then fail(scenario, "the pick is " .. tostring(p.classStyles.MAGE)) end
		ns.ClampSettings()
		if p.style ~= "archmage" then fail(scenario, "the repair changed it to " .. tostring(p.style)) end
		if p.profileStyle ~= "glass" then fail(scenario, "profileStyle is " .. tostring(p.profileStyle)) end
	end)
	sv = session(scenario, { class = "PRIEST", character = "Prue Alt", sv = sv }, function(ns, UI, row, p)
		if p.style ~= "priest" then fail(scenario, "a priest wears " .. tostring(p.style)) end
	end)
	session(scenario, { class = "MAGE", sv = sv }, function(ns, UI, row, p)
		if p.style ~= "archmage" then fail(scenario, "the mage back wears " .. tostring(p.style)) end
	end)
end

do
	local scenario = "classlook: turning it on keeps a mage's own look"
	session(scenario, { class = "MAGE" }, function(ns, UI, row, p)
		press(cardOf(row, "firemage"))
		ns.RefreshOptionsDisplay()
		if p.style ~= "firemage" then
			fail(scenario, "the click did not pick Fire Mage")
			return
		end
		switch(ns, UI, true)
		if p.style ~= "firemage" then fail(scenario, "style is " .. tostring(p.style)) end
		if p.classStyles.MAGE ~= "firemage" then fail(scenario, "the pick is " .. tostring(p.classStyles.MAGE)) end
		if p.profileStyle ~= "firemage" then fail(scenario, "profileStyle is " .. tostring(p.profileStyle)) end
	end)
end

do
	local scenario = "classlook: another look clicked becomes the profile's own"
	session(scenario, { class = "DRUID" }, function(ns, UI, row, p)
		switch(ns, UI, true)
		press(cardOf(row, "luxe"))
		ns.RefreshOptionsDisplay()
		if p.style ~= "wild" then fail(scenario, "style is " .. tostring(p.style)) end
		if p.profileStyle ~= "luxe" then fail(scenario, "profileStyle is " .. tostring(p.profileStyle)) end
		p.classStyles.MAGE = "archmage"
		switch(ns, UI, false)
		if p.style ~= "luxe" then fail(scenario, "off, style is " .. tostring(p.style)) end
		if rawget(p, "profileStyle") ~= nil then fail(scenario, "off, profileStyle is " .. tostring(p.profileStyle)) end
		if p.classStyles.MAGE ~= "archmage" then fail(scenario, "off, the mage's pick is " .. tostring(p.classStyles.MAGE)) end
		switch(ns, UI, true)
		if p.style ~= "wild" then fail(scenario, "on again, style is " .. tostring(p.style)) end
		if p.profileStyle ~= "luxe" then fail(scenario, "on again, profileStyle is " .. tostring(p.profileStyle)) end
	end)
end

do
	local scenario = "classlook: a class with no look wears the profile's"
	session(scenario, { class = "DRUID" }, function(ns, UI, row, p)
		switch(ns, UI, true)
		local was = ns.Looks.FOR_CLASS.wild
		ns.Looks.FOR_CLASS.wild = nil
		ns.ClampSettings()
		if p.style ~= "glass" then fail(scenario, "style is " .. tostring(p.style)) end
		local _, why = ns.Looks.InUse(p)
		if why ~= "profile" then fail(scenario, "why is " .. tostring(why)) end
		ns.RefreshOptionsDisplay()
		local want = ns.L["In use: %s, this profile's own look, as no look is made for your class."]:format(ns.WindowWidgets.Trim((ns.Looks.Card("glass"))))
		if not has(row.why:GetText(), want) then fail(scenario, "the line reads " .. tostring(row.why:GetText())) end
		press(cardOf(row, "luxe"))
		ns.RefreshOptionsDisplay()
		if p.style ~= "luxe" then fail(scenario, "style is " .. tostring(p.style)) end
		if p.profileStyle ~= "luxe" then fail(scenario, "profileStyle is " .. tostring(p.profileStyle)) end
		ns.Looks.FOR_CLASS.wild = was
	end)
end

do
	local scenario = "classlook: the picker says which look is in use and why"
	session(scenario, { class = "MAGE" }, function(ns, UI, row, p)
		local L, W = ns.L, ns.WindowWidgets
		local function title(k) return W.Trim((ns.Looks.Card(k))) end
		local own = L["This profile's own look, which every character wears with the switch above off: %s."]
		local ownHead = own:match("^(.-)%%s")
		if row.whyShown ~= false or row.why:IsShown() then fail(scenario, "the line shows with the switch off") end
		if not has(row.hint:GetText(), L["Point at a look to try it on the prompt; click to keep it."]) then
			fail(scenario, "the off hint reads " .. tostring(row.hint:GetText()))
		end
		switch(ns, UI, true)
		if row.whyKind ~= "first" or not row.why:IsShown() then fail(scenario, "whyKind is " .. tostring(row.whyKind)) end
		local text = row.why:GetText()
		if not has(text, L["In use: %s, the first of the looks made for your class."]:format(title("frost"))) then
			fail(scenario, "the line reads " .. tostring(text))
		end
		if not has(text, own:format(title("glass"))) then fail(scenario, "the own look is not named: " .. tostring(text)) end
		if not has(row.hint:GetText(), L["Point at a look to try it on the prompt. Click one of your class's looks to wear it; click any other to make it this profile's own look."]) then
			fail(scenario, "the on hint reads " .. tostring(row.hint:GetText()))
		end
		if not (type(row.why.y) == "number" and type(row.hint.y) == "number" and row.why.y > row.hint.y) then
			fail(scenario, "the line is not under the hint")
		end
		for _, c in ipairs(row.cards) do
			if c:IsShown() and type(c.y) == "number" and c.y < row.why.y then
				fail(scenario, "card " .. tostring(c.key) .. " starts over the line")
			end
		end
		press(cardOf(row, "archmage"))
		ns.RefreshOptionsDisplay()
		if row.whyKind ~= "picked" then fail(scenario, "after a pick whyKind is " .. tostring(row.whyKind)) end
		local kept = row.why:GetText()
		if not has(kept, L["In use: %s, the one you picked of the looks made for your class."]:format(title("archmage"))) then
			fail(scenario, "the line reads " .. tostring(kept))
		end
		enter(cardOf(row, "luxe"))
		ns.RefreshOptionsDisplay()
		if row.why:GetText() ~= kept then fail(scenario, "a look tried changed the line to " .. tostring(row.why:GetText())) end
		leave(cardOf(row, "luxe"))
		p.profileStyle = "archmage"
		ns.RefreshOptionsDisplay()
		if has(row.why:GetText(), ownHead) then fail(scenario, "the own look is named though it is the one worn") end
	end)
	session(scenario, { class = "DRUID" }, function(ns, UI, row, p)
		switch(ns, UI, true)
		if row.whyKind ~= "only" then fail(scenario, "a druid's whyKind is " .. tostring(row.whyKind)) end
		local want = ns.L["In use: %s, the look made for your class."]:format(ns.WindowWidgets.Trim((ns.Looks.Card("wild"))))
		if not has(row.why:GetText(), want) then fail(scenario, "the line reads " .. tostring(row.why:GetText())) end
	end)
end

do
	local scenario = "classlook: a look tried under the pointer goes back to the class's"
	session(scenario, { class = "DRUID" }, function(ns, UI, row, p)
		switch(ns, UI, true)
		enter(cardOf(row, "luxe"))
		if p.style ~= "luxe" then fail(scenario, "the trial left " .. tostring(p.style)) end
		leave(cardOf(row, "luxe"))
		if p.style ~= "wild" then fail(scenario, "after the trial style is " .. tostring(p.style)) end
		if p.profileStyle ~= "glass" then fail(scenario, "profileStyle is " .. tostring(p.profileStyle)) end
		if (p.classStyles or {}).DRUID ~= nil then fail(scenario, "a pick was recorded for the druid") end
	end)
end

do
	local scenario = "classlook: a damaged profile is mended"
	session(scenario, { class = "MAGE" }, function(ns, UI, row, p)
		p.classStyles = "x"
		ns.ClampSettings()
		if type(p.classStyles) ~= "table" or next(p.classStyles) ~= nil then fail(scenario, "classStyles is not an empty table") end
		p.classStyles = { MAGE = "wild", [1] = "frost", PRIEST = "nosuch", DRUID = "wild" }
		ns.ClampSettings()
		if p.classStyles.MAGE ~= nil or p.classStyles[1] ~= nil or p.classStyles.PRIEST ~= nil then
			fail(scenario, "a bad pick was kept")
		end
		if p.classStyles.DRUID ~= "wild" then fail(scenario, "a good pick was dropped: " .. tostring(p.classStyles.DRUID)) end
		p.classLook = true
		p.profileStyle = 7
		ns.ClampSettings()
		if p.profileStyle ~= "glass" then fail(scenario, "profileStyle is " .. tostring(p.profileStyle)) end
		if p.style ~= "frost" then fail(scenario, "style is " .. tostring(p.style)) end
		p.classLook = false
		p.profileStyle = "luxe"
		ns.ClampSettings()
		if p.style ~= "luxe" then fail(scenario, "off, style is " .. tostring(p.style)) end
		if rawget(p, "profileStyle") ~= nil then fail(scenario, "off, profileStyle is kept") end
		ns.repairLog = {}
		p.classLook = "yes"
		ns.ClampSettings()
		if p.classLook ~= false then fail(scenario, "classLook is " .. tostring(p.classLook)) end
		if not has(table.concat(ns.repairLog, ";"), "prompt.classLook") then
			fail(scenario, "the repair said " .. table.concat(ns.repairLog, ";"))
		end
	end)
end

do
	local scenario = "classlook: the Look page's reset turns it off"
	session(scenario, { class = "DRUID" }, function(ns, UI, row, p)
		switch(ns, UI, true)
		press(cardOf(row, "luxe"))
		p.classStyles.MAGE = "archmage"
		local ok, answer = pcall(ns.OptionsPage.ResetPage, "appearance")
		if not (ok and answer == true) then
			fail(scenario, "the reset did not run: " .. tostring(answer))
			return
		end
		if p.classLook ~= false then fail(scenario, "classLook is " .. tostring(p.classLook)) end
		if next(p.classStyles) ~= nil then fail(scenario, "the picks were kept") end
		if rawget(p, "profileStyle") ~= nil then fail(scenario, "profileStyle is " .. tostring(p.profileStyle)) end
		if p.style ~= "glass" then fail(scenario, "style is " .. tostring(p.style)) end
	end)
end

do
	local scenario = "classlook: a settings string carries it, and its undo puts it back"
	local text
	session(scenario, { class = "DRUID" }, function(ns, UI, row, p)
		switch(ns, UI, true)
		press(cardOf(row, "luxe"))
		p.classStyles.MAGE = "archmage"
		text = ns.ExportSettings() or ""
		for _, part in ipairs({ "prompt.classLook=1", "prompt.classStyles=MAGE=archmage", "prompt.profileStyle=luxe", "prompt.style=luxe" }) do
			if not has(text, part) then fail(scenario, "the string lacks " .. part) end
		end
	end)
	session(scenario, { class = "MAGE" }, function(ns, UI, row, p)
		p.style = "slate"
		ns.Looks.SetClassLook(p, true)
		if ns.ImportSettings(text) ~= true then
			fail(scenario, "the import was refused")
			return
		end
		if p.classLook ~= true then fail(scenario, "classLook is " .. tostring(p.classLook)) end
		if p.style ~= "archmage" then fail(scenario, "style is " .. tostring(p.style)) end
		if p.profileStyle ~= "luxe" then fail(scenario, "profileStyle is " .. tostring(p.profileStyle)) end
		ns.UndoImport()
		if p.classLook ~= true then fail(scenario, "undone, classLook is " .. tostring(p.classLook)) end
		if p.style ~= "frost" then fail(scenario, "undone, style is " .. tostring(p.style)) end
		if p.profileStyle ~= "slate" then fail(scenario, "undone, profileStyle is " .. tostring(p.profileStyle)) end
	end)
end

do
	local scenario = "classlook: the switch is over the cards on the Look page"
	session(scenario, { class = "MAGE" }, function(ns, UI, row, p)
		if not UI.RowShown("appearance.classLook") then fail(scenario, "the switch is not shown") end
		local a, b = UI.Where("appearance.classLook"), UI.Where("appearance.style")
		if not (a and b and a.sec == b.sec and a.sec.key == "appearance.themes") then
			fail(scenario, "the switch is not in the cards' section")
		end
		local sections = ns.WindowLayout.pages.appearance.sections
		local found
		for _, sec in ipairs(sections) do
			if sec.key == "appearance.themes" then found = sec end
		end
		if not (found and found.items[1] == "appearance.classLook" and type(found.items[2]) == "table"
			and found.items[2][1] == "appearance.style") then
			fail(scenario, "the section's items do not lead with the switch")
		end
		local name = ns.WindowBind.Text(UI.Item("appearance.classLook"), "name")
		if name ~= "Use my class's look on each character" then fail(scenario, "the name is " .. tostring(name)) end
		if not has(ns.WindowLayout.keywords["appearance.classLook"], "alt") then fail(scenario, "no search words") end
		local seen
		for _, entry in ipairs(UI.SearchEntries()) do
			if entry.ref and entry.ref.path == "appearance.classLook" then seen = true end
		end
		if not seen then fail(scenario, "search does not list it") end
		if ns.WindowLayout.simple.items["appearance.classLook"] ~= true then fail(scenario, "the simple view leaves it out") end
	end)
end

do
	local scenario = "classlook: every client"
	local cases = {
		{ "camelot", "PALADIN", "lightbringer" },
		{ "vanilla", "HUNTER", "leather" },
		{ "tbc", "SHAMAN", "stormcaller" },
		{ "mists", "MONK", "monk" },
		{ "mainline", "EVOKER", "evoker" },
	}
	for _, case in ipairs(cases) do
		local flavour, class, look = case[1], case[2], case[3]
		Mock.reset()
		Mock.setFlavour(flavour)
		Mock.class = class
		local ok, err = pcall(function()
			local ns = load(scenario)
			if not ns then return end
			ns.addon:OnInitialize()
			local p = ns.db.profile.prompt
			ns.Looks.SetClassLook(p, true)
			ns.ClampSettings()
			if p.style ~= look then fail(scenario, flavour .. ": " .. class .. " wears " .. tostring(p.style)) end
			for _, e in ipairs(ns.errors or {}) do
				if tostring(e.where):find("ClampSettings", 1, true) then
					fail(scenario, flavour .. ": guarded " .. tostring(e.where) .. " -> " .. tostring(e.err))
				end
			end
		end)
		Mock.reset()
		if not ok then fail(scenario, flavour .. ": threw: " .. tostring(err)) end
	end
end
