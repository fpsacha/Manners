-- The Look page as a whole (Options/Window/WidgetsTheme.lua, Layout.lua,
-- Options/Look.lua, Looks/Looks.lua): the tabs over the looks, a look tried on
-- the prompt under the pointer, cards that wear the art the prompt draws, and
-- the chosen look's own settings under the gallery.
--
-- What it promises: tabs For my class (the player's class's looks, first, and
-- only for a class that has some), All and one per shelf, each holding what its
-- name says; For my class open the first time where there is one, else All; the
-- tab last chosen kept for the session; every look on exactly one shelf and on
-- All. The pointer on a card puts that look on the prompt and leaving puts the
-- chosen one back, a card put away or a fight starting too; a click keeps it;
-- in a fight nothing changes and the page says so. The cards' pictures follow
-- Earlier art. The section under the gallery is headed by the chosen look's
-- name and holds what goes with it, greying the round icon where the look
-- rounds it itself. New marks the looks Looks.NEW names.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every name
-- starts with "lookpage:".

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

-- One session of `class` with the options window open on Look, the chosen look
-- `style`. `before(ns)` runs before the window opens. `body(ns, UI, row)`.
local function with(scenario, spec, body)
	Mock.reset()
	if spec.class then Mock.class = spec.class end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		if spec.style then ns.db.profile.prompt.style = spec.style end
		if spec.before then spec.before(ns) end
		ns.OpenOptions("appearance", true)
		local UI = ns.WindowUI
		local row = UI.RowFor("appearance.style")
		if not (row and row.cards and row.tabs and UI.RowShown("appearance.style")) then
			fail(scenario, "SKIPPED -- the gallery is not on the Look page")
			return
		end
		body(ns, UI, row)
		noErrors(scenario, ns)
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The keys of the cards shown, in order.
local function shownKeys(row)
	local out = {}
	for _, card in ipairs(row.cards) do
		if card:IsShown() then out[#out + 1] = card.key end
	end
	return out
end

local function cardFor(row, key)
	for _, card in ipairs(row.cards) do
		if card:IsShown() and card.key == key then return card end
	end
end

local function same(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

-- The tabs shown, left to right then down.
local function shownTabs(row)
	local out = {}
	for key, b in pairs(row.tabs) do
		if b:IsShown() then out[#out + 1] = { key = key, x = b.x or 0, y = b.y or 0 } end
	end
	table.sort(out, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
	local keys = {}
	for i, t in ipairs(out) do keys[i] = t.key end
	return keys
end

local function choose(ns, row, tab)
	press(row.tabs[tab])
	ns.RefreshOptionsDisplay()
end

-- ------------------------------------------------------------------ the tabs
local function checkTabs(scenario, ns, row, class, want)
	local Looks = ns.Looks
	local tabs = shownTabs(row)
	local expected = { "mine", "all", "minimal", "classic", "themed", "class" }
	if not same(tabs, expected) then fail(scenario, class .. ": the tabs are " .. table.concat(tabs, ", ")) end
	if row.tab ~= "mine" then fail(scenario, class .. ": the page opened on " .. tostring(row.tab) .. ", not For my class") end
	local mine = shownKeys(row)
	if not same(mine, want) then
		fail(scenario, ("%s: For my class holds %s, not %s"):format(class, table.concat(mine, ", "), table.concat(want, ", ")))
	end
	local label = row.tabs.mine.label:GetText() or ""
	if not label:find(ns.L["For my class"], 1, true) or not label:find(tostring(#want), 1, true) then
		fail(scenario, class .. ": the tab reads " .. label)
	end
	-- Every shelf's tab holds that shelf, in the dropdown's order; All all of them.
	local _, sorting = Looks.Choices()
	choose(ns, row, "all")
	if not same(shownKeys(row), sorting) then fail(scenario, class .. ": All does not hold every look in order") end
	for _, cat in ipairs(Looks.CATEGORIES) do
		choose(ns, row, cat)
		local want2 = {}
		for _, key in ipairs(sorting) do
			if Looks.Category(key) == cat then want2[#want2 + 1] = key end
		end
		if not same(shownKeys(row), want2) then fail(scenario, ("%s: the %s tab holds %s"):format(class, cat, table.concat(shownKeys(row), ", "))) end
	end
end

do
	local scenario = "lookpage: a mage's tabs, For my class first and open, holding the three mage looks"
	with(scenario, { class = "MAGE" }, function(ns, UI, row)
		checkTabs(scenario, ns, row, "MAGE", { "frost", "archmage", "firemage" })
	end)
end

do
	local scenario = "lookpage: a warrior's For my class holds Warrior"
	with(scenario, { class = "WARRIOR" }, function(ns, UI, row)
		checkTabs(scenario, ns, row, "WARRIOR", { "forge" })
	end)
end

do
	local scenario = "lookpage: a class with no look of its own has no For my class and opens on All"
	with(scenario, { class = "MAGE", before = function(ns)
		for key, class in pairs(ns.Looks.FOR_CLASS) do
			if class == "MAGE" then ns.Looks.FOR_CLASS[key] = nil end
		end
	end }, function(ns, UI, row)
		if row.tabs.mine and row.tabs.mine:IsShown() then fail(scenario, "For my class is shown with nothing in it") end
		if row.tab ~= "all" then fail(scenario, "the page opened on " .. tostring(row.tab) .. ", not All") end
		local _, sorting = ns.Looks.Choices()
		if #shownKeys(row) ~= #sorting then fail(scenario, ("All shows %d of %d looks"):format(#shownKeys(row), #sorting)) end
	end)
end

do
	local scenario = "lookpage: the tab chosen is kept while the session lasts"
	with(scenario, { class = "MAGE" }, function(ns, UI, row)
		choose(ns, row, "classic")
		ns.CloseOptions()
		ns.OpenOptions("general", true)
		ns.OpenOptions("appearance", true)
		if row.tab ~= "classic" then fail(scenario, "the window opened Look again on " .. tostring(row.tab)) end
		local keys = shownKeys(row)
		for _, key in ipairs(keys) do
			if ns.Looks.Category(key) ~= "classic" then fail(scenario, key .. " is shown under Classic") end
		end
		if #keys == 0 then fail(scenario, "Classic shows nothing") end
	end)
end

do
	local scenario = "lookpage: every look is on exactly one shelf, on All, and a class look on Class"
	with(scenario, { class = "MAGE" }, function(ns, UI, row)
		local Looks = ns.Looks
		local seen = {}
		for _, cat in ipairs(Looks.CATEGORIES) do
			choose(ns, row, cat)
			for _, key in ipairs(shownKeys(row)) do seen[key] = (seen[key] or 0) + 1 end
		end
		choose(ns, row, "all")
		local all = {}
		for _, key in ipairs(shownKeys(row)) do all[key] = true end
		for key in pairs(Looks.list) do
			if seen[key] ~= 1 then fail(scenario, ("%s is on %d shelves"):format(key, seen[key] or 0)) end
			if not all[key] then fail(scenario, key .. " cannot be reached from All") end
		end
		for key in pairs(Looks.FOR_CLASS) do
			if not Looks.list[key] then fail(scenario, key .. " is made for a class and is no look") end
			if Looks.Category(key) ~= "class" then fail(scenario, key .. " is made for a class and is not on Class") end
		end
		for key in pairs(Looks.NEW) do
			if not Looks.list[key] then fail(scenario, key .. " is marked New and is no look") end
		end
		-- All draws a heading over each shelf.
		for _, cat in ipairs(Looks.CATEGORIES) do
			local h = row.heads[cat]
			if not (h and h:IsShown()) then fail(scenario, "All has no heading for " .. cat) end
		end
		choose(ns, row, "mine")
		for _, h in pairs(row.heads) do
			if h:IsShown() then fail(scenario, "a shelf's heading stays up on For my class") break end
		end
	end)
end

-- ------------------------------------------------------------------ trying a look
do
	local scenario = "lookpage: the pointer on a card puts its look on the prompt, and leaving puts the chosen one back"
	with(scenario, { class = "MAGE", style = "glass" }, function(ns, UI, row)
		local p = ns.db.profile.prompt
		ns.Prompt:ApplyStyle()
		local frost = cardFor(row, "frost")
		enter(frost)
		if ns.Prompt:Regions().look ~= ns.Looks.Get("frost") then
			fail(scenario, "the pointer on Frost Mage left the prompt in " .. tostring(ns.Prompt:Regions().look and ns.Prompt:Regions().look.key))
		end
		ns.RefreshOptionsDisplay()
		if not cardFor(row, "frost") or cardFor(row, "frost").selected then fail(scenario, "the card tried is marked as the one chosen") end
		-- From one card to the next: the second look, and the chosen one under it.
		leave(frost)
		local arcane = cardFor(row, "archmage")
		enter(arcane)
		if ns.Prompt:Regions().look ~= ns.Looks.Get("archmage") then fail(scenario, "the second card's look is not on the prompt") end
		leave(arcane)
		if p.style ~= "glass" then fail(scenario, "after the pointer left the style is " .. tostring(p.style)) end
		if ns.Prompt:Regions().look ~= nil then
			fail(scenario, "after the pointer left the prompt is still " .. tostring(ns.Prompt:Regions().look.key))
		end
	end)
end

do
	local scenario = "lookpage: a click on the card under the pointer keeps its look"
	with(scenario, { class = "MAGE", style = "glass" }, function(ns, UI, row)
		local p = ns.db.profile.prompt
		local frost = cardFor(row, "frost")
		enter(frost)
		press(frost)
		leave(frost)
		if p.style ~= "frost" then fail(scenario, "clicked and left, the style is " .. tostring(p.style)) end
		if ns.Prompt:Regions().look ~= ns.Looks.Get("frost") then fail(scenario, "clicked and left, the prompt is not Frost Mage") end
		ns.RefreshOptionsDisplay()
		local card = cardFor(row, "frost")
		if not (card and card.selected and card.badge:IsShown()) then fail(scenario, "the card clicked is not marked") end
	end)
end

do
	local scenario = "lookpage: a card put away, or a fight starting, puts the chosen look back"
	with(scenario, { class = "MAGE", style = "glass" }, function(ns, UI, row)
		local p = ns.db.profile.prompt
		-- Another tab chosen with the pointer on a card: the card goes.
		enter(cardFor(row, "frost"))
		choose(ns, row, "minimal")
		if p.style ~= "glass" or ns.Prompt:Regions().look ~= nil then
			fail(scenario, "a card put away left its look on: " .. tostring(p.style))
		end
		-- The window shut with the pointer on a card.
		choose(ns, row, "mine")
		enter(cardFor(row, "archmage"))
		ns.CloseOptions()
		if p.style ~= "glass" then fail(scenario, "the window shut on a tried look: " .. tostring(p.style)) end
		ns.OpenOptions("appearance", true)
		-- A fight starting: the client says so just before the lockdown.
		enter(cardFor(row, "firemage"))
		Mock.frameEvent("PLAYER_REGEN_DISABLED")
		if p.style ~= "glass" or ns.Prompt:Regions().look ~= nil then
			fail(scenario, "a fight began on a tried look: " .. tostring(p.style))
		end
		-- And logging out, so a tried look is never saved.
		enter(cardFor(row, "frost"))
		Mock.frameEvent("PLAYER_LOGOUT")
		if p.style ~= "glass" then fail(scenario, "the game logged out with a tried look saved: " .. tostring(p.style)) end
	end)
end

do
	local scenario = "lookpage: in a fight the pointer changes nothing, and the page says so"
	with(scenario, { class = "MAGE", style = "glass" }, function(ns, UI, row)
		local p = ns.db.profile.prompt
		ns.Prompt:ApplyStyle()
		Mock.inCombat = true
		ns.RefreshOptionsDisplay()
		local hint = row.hint:GetText() or ""
		if not hint:find(ns.L["In a fight a look cannot change: the one you click goes on when the fight ends."], 1, true) then
			fail(scenario, "in a fight the line under the tabs reads " .. hint)
		end
		local calls, real = 0, ns.Prompt.ApplyStyle
		ns.Prompt.ApplyStyle = function(...)
			calls = calls + 1
			return real(...)
		end
		local card = cardFor(row, "frost")
		enter(card)
		-- Under the pointer: nothing tried, not even the setting the end of the
		-- fight would draw.
		if p.style ~= "glass" then fail(scenario, "the pointer in a fight set the style to " .. tostring(p.style)) end
		leave(card)
		ns.Prompt.ApplyStyle = real
		if calls ~= 0 then fail(scenario, "the pointer in a fight restyled the prompt " .. calls .. " times") end
		if ns.Prompt:Regions().look ~= nil then fail(scenario, "the prompt changed look in a fight") end
		Mock.inCombat = false
		ns.RefreshOptionsDisplay()
		hint = row.hint:GetText() or ""
		if not hint:find(ns.L["Point at a look to try it on the prompt; click to keep it."], 1, true) then
			fail(scenario, "out of the fight the line reads " .. hint)
		end
	end)
end

-- ------------------------------------------------------------------ the pictures
do
	local scenario = "lookpage: the cards' pictures follow Earlier art"
	with(scenario, { class = "MAGE", style = "frost" }, function(ns, UI, row)
		local Looks, p = ns.Looks, ns.db.profile.prompt
		-- Every look with an earlier art has its second picture, and no other.
		for key in pairs(Looks.list) do
			if Looks.HasEarlierArt(key) ~= (Looks.previewsEarlier[key] == true) then
				fail(scenario, key .. (Looks.HasEarlierArt(key) and " has an earlier art and no picture of it: run tools/make_look_previews.py"
					or " has a picture of an earlier art it has not"))
			end
		end
		local function check(on)
			p.classicArt = on
			ns.RefreshOptionsDisplay()
			for _, key in ipairs(shownKeys(row)) do
				local card = cardFor(row, key)
				local earlier = on and Looks.HasEarlierArt(key)
				local file = tostring(card.file)
				if earlier ~= (file:find("_earlier$") ~= nil) then
					fail(scenario, ("Earlier art %s: the %s card wears %s"):format(on and "on" or "off", key, file))
				end
				local icon = earlier and Looks.previewIconEarlier[key] or Looks.previewIcon[key]
				if card.at ~= icon then fail(scenario, ("Earlier art %s: the %s card's icon is laid where the other picture has it"):format(on and "on" or "off", key)) end
				local text = earlier and Looks.previewTextEarlier[key] or Looks.previewText[key]
				if card.textAt ~= text then fail(scenario, ("Earlier art %s: the %s card's words are laid where the other picture has them"):format(on and "on" or "off", key)) end
			end
		end
		check(true)
		check(false)
		if not Looks.HasEarlierArt("frost") then fail(scenario, "SKIPPED -- Frost Mage has no earlier art") end
	end)
end

do
	local scenario = "lookpage: New marks the looks new in this release, and only those"
	with(scenario, { class = "MAGE" }, function(ns, UI, row)
		choose(ns, row, "all")
		for _, card in ipairs(row.cards) do
			if card:IsShown() and card.newTag:IsShown() ~= (ns.Looks.NEW[card.key] == true) then
				fail(scenario, card.key .. (card.newTag:IsShown() and " is marked New" or " is not marked New"))
			end
			if card:IsShown() and card.title:GetWidth() + card.newTag:GetWidth() > card.w then
				fail(scenario, card.key .. ": the name and New are wider than the card")
			end
		end
	end)
end

-- ------------------------------------------------------------------ the look's own settings
do
	local scenario = "lookpage: under the gallery, the chosen look's settings, named for it"
	with(scenario, { class = "MAGE", style = "frost" }, function(ns, UI, row)
		local L = ns.L
		local m = UI.Model("appearance")
		local own = UI.Where("appearance.roundIcon")
		if not (own and own.sec == m.sections[2] and m.sections[1].key == "appearance.themes") then
			fail(scenario, "the look's settings are not the section under the gallery")
		end
		if own and own.sec.fold then fail(scenario, "the look's settings are folded away") end
		local function title() return UI.SectionText(own.sec) end
		if not title():find(L["Frost Mage"], 1, true) then fail(scenario, "the section is headed " .. title()) end
		for _, path in ipairs({ "appearance.classicArt", "appearance.classicArtNote", "appearance.keycap",
			"appearance.accentByReason", "appearance.accentMode", "appearance.bgColor" }) do
			local w = UI.Where(path)
			if not (w and w.sec == own.sec) then fail(scenario, path .. " is not with the look's settings") end
		end
		-- What Frost Mage decides: the round icon greyed, saying why.
		local W = ns.WindowWidgets
		local e = own.e
		if not (e.row and e.row.off) then fail(scenario, "Round the icon off is live on a look that always rounds it") end
		local note = e.row and W.OffNote(e.row) or ""
		if not note:find(L["Frost Mage"], 1, true) then fail(scenario, "the round icon greys with no word of why: " .. tostring(note)) end
		if not UI.RowShown("appearance.classicArt") or not UI.RowShown("appearance.classicArtNote") then
			fail(scenario, "Earlier art or its line is not shown for a look that has an earlier art")
		end
		if not UI.RowShown("appearance.keycap") then fail(scenario, "Show my key is not shown for a look that draws one") end
		local item = ns.WindowBind.Item("appearance.keycap")
		local values = ns.WindowBind.Values(item)
		if not (values[1] and values[1][2] == L["As the look has it (shown)"]) then
			fail(scenario, "the key's first choice does not say what Frost Mage does: " .. tostring(values[1] and values[1][2]))
		end
		if UI.RowShown("appearance.gryphons") then fail(scenario, "Glass's gryphons are offered on Frost Mage") end
		-- Glass: no earlier art, no key, its gryphons; the round icon live.
		ns.db.profile.prompt.style = "glass"
		ns.RefreshOptionsDisplay()
		if not title():find(L["Glass"], 1, true) then fail(scenario, "with Glass chosen the section is headed " .. title()) end
		if UI.RowShown("appearance.classicArt") then fail(scenario, "Earlier art is offered on Glass, which has none") end
		if UI.RowShown("appearance.keycap") then fail(scenario, "Show my key is offered on Glass, which draws no key") end
		if not UI.RowShown("appearance.gryphons") then fail(scenario, "Glass's gryphons are not with its settings") end
		if own.e.row.off then fail(scenario, "Round the icon off is greyed on Glass, which reads it") end
	end)
end
