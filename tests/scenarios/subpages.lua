-- The options window's sub-divisions: a page of many sections lists them in
-- a bar pinned over it (Options/Window/Layout.lua, `subpages`;
-- WindowPage.lua, UI.SubsShown, UI.SubInView, UI.ShowSub; WindowChrome.lua,
-- UI.PaintSubBar; Options/Shared.lua, Page.WarnAt for their red dots).
--
-- Every scenario name starts with "subpages:" so the mutations in
-- tests/mutations/subpages.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

-- The buffs a class has learned, by key (every rank).
local KNOWS = {
	PALADIN = { "wisdom", "might", "kings" },
}

-- opts: class, page, before(ns).
local function with(scenario, opts, body)
	Mock.reset()
	FT.install()
	local known, playerSpell = rawget(_G, "IsSpellKnown"), rawget(_G, "IsPlayerSpell")
	local ok, err = pcall(function()
		if opts.class then Mock.class = opts.class end
		local ns = load(scenario)
		if not ns then return end
		if KNOWS[opts.class or ""] then
			local set = {}
			for _, key in ipairs(KNOWS[opts.class]) do
				local buff = ns.FindBuff(opts.class, key)
				for _, id in ipairs(buff and buff.ranks or {}) do set[id] = true end
			end
			IsSpellKnown = function(id) return set[id] == true end
			IsPlayerSpell = IsSpellKnown
		end
		drive(scenario, ns)
		if KNOWS[opts.class or ""] then ns.Guard("probe", ns.ProbeCapabilities) end
		ns.Prompt:ExitTest()
		if opts.before then opts.before(ns) end
		-- Every sub-division forgotten: the session starts on All.
		for id in pairs(ns.WindowUI.subOf) do ns.WindowUI.subOf[id] = nil end
		ns.OpenOptions(opts.page or "who")
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	rawset(_G, "IsSpellKnown", known)
	rawset(_G, "IsPlayerSpell", playerSpell)
	Mock.inCombat = false
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The chips the bar shows, in order: { key (nil for All), label, chip }.
local function chips(UI)
	local out = {}
	if not UI.subbar.frame:IsShown() then return out end
	for _, b in ipairs(UI.subbar.chips) do
		if b:IsShown() then out[#out + 1] = { key = b.key, label = b.label:GetText(), chip = b } end
	end
	return out
end

-- A chip pressed as a click presses it; false when the bar has no such chip.
local function choose(UI, key)
	for _, c in ipairs(chips(UI)) do
		if c.key == key then
			c.chip:GetScript("OnClick")(c.chip, "LeftButton", false)
			return true
		end
	end
	return false
end

local function keysOf(list)
	local out = {}
	for _, c in ipairs(list) do out[#out + 1] = tostring(c.key) end
	return table.concat(out, ",")
end

-- Whether a section of the open page has a row on screen.
local function drawsRows(sec)
	for _, e in ipairs(sec.entries) do
		if e.row and e.row.frame:IsShown() then return true end
	end
	return false
end

-- The open page's sections that have a row on screen, by key.
local function drawnSections(UI)
	local out = {}
	for _, sec in ipairs(UI.Model(UI.page).sections) do
		if drawsRows(sec) then out[sec.key] = sec end
	end
	return out
end

---------------------------------------------------------------------------
-- the layout
---------------------------------------------------------------------------

do
	local scenario = "subpages: each page of many sections names its sub-divisions, every one its own sections, seven at most"
	with(scenario, {}, function(ns)
		for id, page in pairs(ns.WindowLayout.pages) do
			local keys, titled = {}, 0
			for _, s in ipairs(page.sections) do
				keys[s.key] = true
				if s.header or s.title then titled = titled + 1 end
			end
			local subs = page.subpages
			if titled > 3 and type(subs) ~= "table" then
				fail(scenario, id .. " has " .. titled .. " sections with a title and no sub-divisions")
			end
			if subs ~= nil then
				if #subs < 2 or #subs > 7 then fail(scenario, id .. " has " .. #subs .. " sub-divisions, not 2 to 7") end
				local seen = {}
				for i, sub in ipairs(subs) do
					if #sub == 0 then fail(scenario, id .. "'s sub-division " .. i .. " names no section") end
					for k in pairs(sub) do
						if type(k) ~= "number" and k ~= "title" then
							fail(scenario, id .. "'s sub-division " .. i .. " has a field the window does not know: " .. tostring(k))
						end
					end
					if sub.title ~= nil and (type(sub.title) ~= "string" or sub.title == "") then
						fail(scenario, id .. "'s sub-division " .. i .. " has an empty title")
					end
					for _, key in ipairs(sub) do
						if not keys[key] then fail(scenario, id .. "'s sub-division " .. i .. " names " .. tostring(key) .. ", no section of the page") end
						if seen[key] then fail(scenario, id .. " names " .. tostring(key) .. " in two sub-divisions") end
						seen[key] = true
					end
				end
			end
		end
	end)
end

---------------------------------------------------------------------------
-- the bar, as a class has it
---------------------------------------------------------------------------

-- The bar against the model: All, then each sub-division of the layout with a
-- section shown, labelled by its first section shown with a title.
local function CheckBar(scenario, ns, UI, id)
	ns.OpenOptions(id)
	if UI.page ~= id then fail(scenario, "SKIPPED -- " .. id .. " is not in the sidebar") return end
	local m = UI.Model(id)
	local want = { "nil" }
	for _, def in ipairs(ns.WindowLayout.pages[id].subpages or {}) do
		local shown = false
		for _, key in ipairs(def) do
			for _, sec in ipairs(m.sections) do
				if sec.key == key and sec.visible then shown = true end
			end
		end
		if shown then want[#want + 1] = def[1] end
	end
	if #want < 3 then want = {} end
	local got = chips(UI)
	if keysOf(got) ~= table.concat(want, ",") then
		fail(scenario, ("%s's bar shows %s, not %s"):format(id, keysOf(got), table.concat(want, ",")))
		return
	end
	for i, c in ipairs(got) do
		if i > 1 then
			local sub = UI.SubsShown(id)[i - 1]
			local text = UI.Plain(UI.SubLabel(sub))
			if c.label ~= text or text == "" then
				fail(scenario, ("%s's chip %s reads %q, not %q"):format(id, tostring(c.key), tostring(c.label), text))
			end
		end
	end
	return got
end

do
	local scenario = "subpages: a mage's pages list their sub-divisions from the layout, on the first paint"
	with(scenario, { class = "MAGE" }, function(ns, UI)
		local got = CheckBar(scenario, ns, UI, "who")
		if got and #got == 0 then fail(scenario, "a mage's Who to buff has no sub-divisions bar") end
		-- "What to cast" for the buffs and their order, in one.
		local cast
		for _, c in ipairs(got or {}) do
			if c.key == "who.cast" then cast = c end
		end
		if not cast then fail(scenario, "a mage's Who to buff has no What to cast")
		elseif cast.label ~= ns.L["What to cast"] then fail(scenario, "What to cast reads " .. tostring(cast.label)) end
		for _, id in ipairs({ "general", "when", "appearance" }) do CheckBar(scenario, ns, UI, id) end
		-- A page of few sections has no bar, and the page sits under the strip.
		ns.OpenOptions("click")
		if UI.subbar.frame:IsShown() or UI.subbar.height ~= 0 then fail(scenario, "What I say has a sub-divisions bar") end
	end)
end

do
	local scenario = "subpages: a paladin's Who to buff puts Buff order with What to cast"
	with(scenario, { class = "PALADIN" }, function(ns, UI)
		CheckBar(scenario, ns, UI, "who")
		local order = UI.Where("who.orderPick")
		if not (order and order.sec.sub and order.sec.sub.key == "who.cast") then
			fail(scenario, "Buff order is not in What to cast's sub-division")
		end
		for _, id in ipairs({ "general", "when", "appearance" }) do CheckBar(scenario, ns, UI, id) end
	end)
end

do
	-- A warrior gives nobody a buff: the sections about other people are
	-- hidden for him, and none of them is a sub-division.
	local scenario = "subpages: a section hidden for this class gives no sub-division"
	with(scenario, { class = "WARRIOR" }, function(ns, UI)
		local m = UI.Model("who")
		local hidden = {}
		for _, sub in ipairs(m.subs) do
			local any = false
			for _, sec in ipairs(sub.secs) do any = any or sec.visible end
			if not any then hidden[#hidden + 1] = sub.key end
		end
		if #hidden == 0 then fail(scenario, "SKIPPED -- every sub-division of Who to buff has something for a warrior") return end
		for _, c in ipairs(chips(UI)) do
			for _, key in ipairs(hidden) do
				if c.key == key then fail(scenario, "the bar lists " .. key .. ", which has nothing for a warrior") end
			end
		end
	end)
end

---------------------------------------------------------------------------
-- choosing one
---------------------------------------------------------------------------

do
	local scenario = "subpages: a sub-division chosen draws only its sections, from the top, its folds open"
	with(scenario, { class = "PALADIN" }, function(ns, UI)
		UI.ScrollTo(200)
		if not choose(UI, "who.myself") then fail(scenario, "no Myself chip on a paladin's Who to buff") return end
		if UI.view.scrollY ~= 0 then fail(scenario, "Myself opened scrolled " .. tostring(UI.view.scrollY) .. " down") end
		local sub = UI.SubInView("who")
		if not (sub and sub.key == "who.myself") then fail(scenario, "Myself chosen, the page shows " .. tostring(sub and sub.key)) end
		for key, sec in pairs(drawnSections(UI)) do
			if sec.sub and sec.sub ~= sub then fail(scenario, key .. " is drawn with Myself chosen") end
		end
		if UI.RowShown("who.owed") then fail(scenario, "People who buff me is drawn with Myself chosen") end
		if not UI.RowShown("who.self") then fail(scenario, "Myself's own switch is not drawn with Myself chosen") end
		-- Its first row right under the page's title, where the page's first
		-- section stands on All.
		local self = UI.Where("who.self").e
		if not (self.y and self.y < 120) then fail(scenario, "Myself's first row is " .. tostring(self.y) .. " down the page") end
		-- A fold of fine print, chosen: its rows drawn with the fold never
		-- opened, under its title, with no fold button and no caption.
		UI.State().open["who.first"] = nil
		if not choose(UI, "who.first") then fail(scenario, "no Who comes first chip") return end
		if not UI.RowShown("who.target") then fail(scenario, "Who comes first chosen, its rows are not drawn") end
		local first = UI.Where("who.target").sec
		if first.button and first.button:IsShown() then fail(scenario, "Who comes first is drawn as a shut fold's button") end
		if not (first.title and first.title:IsShown()) then fail(scenario, "Who comes first has no title over it") end
		if UI.Model("who").caption.text:IsShown() then fail(scenario, "the fine print's caption is drawn over one sub-division") end
		if UI.State().open["who.first"] then fail(scenario, "choosing Who comes first opened its fold for the whole page") end
	end)
end

do
	local scenario = "subpages: All draws the whole page again, its folds as they were"
	with(scenario, { class = "PALADIN" }, function(ns, UI)
		local before = {}
		for key in pairs(drawnSections(UI)) do before[#before + 1] = key end
		table.sort(before)
		choose(UI, "who.first")
		if not choose(UI, nil) then fail(scenario, "no All chip") return end
		if UI.SubInView("who") ~= nil then fail(scenario, "All chosen, a sub-division is still in view") end
		local after = {}
		for key in pairs(drawnSections(UI)) do after[#after + 1] = key end
		table.sort(after)
		if table.concat(before, ",") ~= table.concat(after, ",") then
			fail(scenario, "All draws " .. table.concat(after, ",") .. ", where the page drew " .. table.concat(before, ","))
		end
		if UI.RowShown("who.target") then fail(scenario, "back on All, the shut fold Who comes first shows its rows") end
		-- A chip pressed opens its view from the top, All too.
		UI.ScrollTo(200)
		if UI.view.scrollY < 100 then fail(scenario, "SKIPPED -- Who to buff does not scroll") return end
		choose(UI, nil)
		if UI.view.scrollY ~= 0 then fail(scenario, "All pressed again, the page stays " .. tostring(UI.view.scrollY) .. " down") end
		local sec = UI.Where("who.target").sec
		if not (sec.button and sec.button:IsShown()) then fail(scenario, "back on All, Who comes first is no fold") end
	end)
end

do
	local scenario = "subpages: the window remembers each page's sub-division for the session"
	with(scenario, { class = "PALADIN" }, function(ns, UI)
		choose(UI, "who.myself")
		ns.OpenOptions("when")
		if UI.SubInView("when") ~= nil then fail(scenario, "When to offer opened on a sub-division nobody chose") end
		choose(UI, "when.favours")
		ns.OpenOptions("who")
		local sub = UI.SubInView("who")
		if not (sub and sub.key == "who.myself") then fail(scenario, "back on Who to buff, Myself is forgotten") end
		ns.CloseOptions()
		ns.OpenOptions("when")
		sub = UI.SubInView("when")
		if not (sub and sub.key == "when.favours") then fail(scenario, "the window shut and opened again, Buffing back is forgotten") end
		local marked
		for _, c in ipairs(chips(UI)) do
			if c.chip.mark:IsShown() then marked = c.key or "All" end
		end
		if marked ~= "when.favours" then fail(scenario, "the bar marks " .. tostring(marked) .. ", not Buffing back") end
	end)
end

---------------------------------------------------------------------------
-- search, the simple view, the red dots, the strip
---------------------------------------------------------------------------

do
	local scenario = "subpages: search opens the sub-division that holds the setting"
	with(scenario, { class = "PALADIN" }, function(ns, UI)
		choose(UI, "who.myself")
		-- On another sub-division of the same page.
		local e = UI.Choose({ path = "who.owed", page = "who" })
		if not (e and UI.RowShown("who.owed")) then fail(scenario, "searched for People who buff me from Myself, it is not drawn") end
		local sub = UI.SubInView("who")
		if not (sub and sub.key == "who.sources") then fail(scenario, "People who buff me opened " .. tostring(sub and sub.key)) end
		-- Every setting search finds, on every page: drawn once chosen.
		for _, entry in ipairs(UI.SearchEntries()) do
			local found = UI.Choose(entry.ref)
			if not (found and UI.RowShown(found.path)) then
				fail(scenario, ("%s > %s: chosen in search, nothing is drawn"):format(tostring(entry.page), tostring(entry.ref.path)))
			else
				local w = UI.Where(found.path)
				local held = w.sec.sub
				if held and #UI.SubsShown(w.page) > 0 and UI.SubInView(w.page) ~= held then
					fail(scenario, found.path .. " opened a sub-division that does not hold it")
				end
			end
		end
	end)
end

do
	local scenario = "subpages: the simple view lists no sub-division with nothing to show"
	with(scenario, { class = "PALADIN" }, function(ns, UI)
		choose(UI, "who.first")
		ns.SetMenuView("simple")
		for _, c in ipairs(chips(UI)) do
			if c.key then
				local any = false
				for _, sub in ipairs(UI.SubsShown("who")) do
					if sub.key == c.key then
						for _, s in ipairs(sub.secs) do any = any or s.visible end
					end
				end
				if not any then fail(scenario, "the simple view lists " .. c.key .. ", with nothing in it") end
			end
		end
		for _, c in ipairs(chips(UI)) do
			if c.key == "who.first" then fail(scenario, "the simple view lists Who comes first, none of it on the short list") end
		end
		-- The one chosen has nothing now: the page is drawn whole, All marked.
		if UI.SubInView("who") ~= nil then fail(scenario, "the simple view keeps an empty sub-division in view") end
		local all = chips(UI)[1]
		if not (all and all.key == nil and all.chip.mark:IsShown()) then fail(scenario, "All is not marked in the simple view") end
		-- What the short list leaves out is counted for the sub-division in view.
		if not choose(UI, "who.sources") then fail(scenario, "no Offer my buff to in the simple view") return end
		local left = 0
		for _, sec in ipairs(UI.Model("who").sections) do
			if not sec.away then
				for _, e in ipairs(sec.entries) do
					if e.bySimple then left = left + 1 end
				end
			end
		end
		if UI.simpleHidden ~= left then
			fail(scenario, ("the simple view says it leaves %s out of Offer my buff to, not %d"):format(tostring(UI.simpleHidden), left))
		end
		-- Back to the full view, the sub-division chosen first returns.
		ns.SetMenuView("full")
		choose(UI, "who.first")
		local sub = UI.SubInView("who")
		if not (sub and sub.key == "who.first") then fail(scenario, "the full view does not offer Who comes first again") end
	end)
end

do
	local scenario = "subpages: the red dot marks the sub-division that holds the warning"
	with(scenario, { class = "PALADIN" }, function(ns, UI)
		local Page = ns.OptionsPage
		-- The page's dot and its sub-divisions' never disagree.
		local function Consistent(id)
			local any = false
			for path, fn in pairs(Page.WarnAt) do
				if UI.PageOf(path) == id and fn() then any = true end
			end
			if (Page.Warn[id] and Page.Warn[id]() or false) ~= any then
				fail(scenario, id .. "'s red dot and the warnings under it disagree")
			end
		end
		local function Dotted()
			local out = {}
			for _, c in ipairs(chips(UI)) do
				if c.chip.dot:IsShown() then out[#out + 1] = tostring(c.key) end
			end
			return table.concat(out, ",")
		end
		if Dotted() ~= "" then fail(scenario, "a sub-division has a red dot on a fresh profile: " .. Dotted()) end
		local src = ns.db.profile.sources
		src.owed, src.group, src.strangers, src.asked, src.self = false, false, false, false, false
		ns.RefreshOptionsDisplay()
		Consistent("who")
		if Dotted() ~= "who.sources" then
			fail(scenario, "nobody to offer to, the red dots are on " .. Dotted() .. ", not Offer my buff to")
		end
		src.owed, src.group, src.self = true, true, true
		ns.OpenOptions("when")
		ns.db.profile.filters.whenBuffed = "always"
		ns.RefreshOptionsDisplay()
		Consistent("when")
		if Dotted() ~= "when.buffed" then fail(scenario, "Always offer, the red dots are on " .. Dotted()) end
		ns.OpenOptions("appearance")
		ns.db.profile.sound.enabled, ns.db.profile.sound.file = true, "None"
		ns.RefreshOptionsDisplay()
		Consistent("appearance")
		if Dotted() ~= "appearance.attention" then fail(scenario, "a sound of None, the red dots are on " .. Dotted()) end
	end)
end

do
	local scenario = "subpages: the combat line follows the sub-division in view"
	with(scenario, { class = "PALADIN", page = "when" }, function(ns, UI)
		UI.State().open = {}
		Mock.inCombat = true
		ns.RefreshOptionsDisplay()
		if UI.strip.combat then fail(scenario, "SKIPPED -- a combat line with the Targeting fold shut") return end
		if not choose(UI, "when.timing") then fail(scenario, "no Timing chip on When to offer") return end
		if not UI.strip.combat then fail(scenario, "Targeting drawn open in its sub-division, the strip says nothing in a fight") end
		choose(UI, "when.buffed")
		if UI.strip.combat then fail(scenario, "the strip speaks of targeting, which the sub-division in view does not draw") end
		Mock.inCombat = false
	end)
end

---------------------------------------------------------------------------
-- columns and scrolling
---------------------------------------------------------------------------

do
	local scenario = "subpages: a sub-division flows into columns in a wide window, and the wheel over the bar scrolls"
	with(scenario, { class = "PALADIN", page = "appearance" }, function(ns, UI)
		-- The wheel over the bar, on the whole page: the page moves.
		UI.ScrollTo(0)
		local wheel = UI.subbar.frame:GetScript("OnMouseWheel")
		if not wheel then fail(scenario, "the bar takes no mouse wheel")
		else
			wheel(UI.subbar.frame, -1)
			if not (UI.view.scrollY > 0) then fail(scenario, "the wheel over the bar did not scroll the page") end
		end
		UI.SetWindowSize(1320, 720)
		if not choose(UI, "appearance.where") then fail(scenario, "no Position chip on a wide Look") return end
		local m = UI.Model("appearance")
		if m.columns < 2 then fail(scenario, "1320 wide, Look is in " .. tostring(m.columns) .. " column") end
		local columns = {}
		for key, sec in pairs(drawnSections(UI)) do
			if sec.sub and sec.sub.key ~= "appearance.where" then fail(scenario, key .. " is drawn with Position chosen") end
			columns[sec.column or 0] = true
		end
		if not columns[2] then fail(scenario, "Position's three sections are all in one column of a wide window") end
		-- Under the bar, never behind it.
		if UI.view.top < UI.HEADER + UI.subbar.height then fail(scenario, "the page starts behind the bar") end
		UI.SetWindowSize(UI.MIN_W, UI.MIN_H)
	end)
end
