-- A setting that is not at its default carries a gold mark in the gutter
-- beside it; a click puts it back through the control's own setter, and the
-- footer's What I changed lists every one, eight at a time.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- One session on `page` as `class`, every spell known, the full view, everything put back.
local function with(scenario, class, page, body)
	Mock.reset()
	Mock.class = class or "MAGE"
	Mock.knownSpells = setmetatable({}, { __index = function() return true end })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		ns.db.profile.menuView = "full"
		ns.OpenOptions(page)
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		ns.Prompt:ExitTest()
		noErrors(scenario, ns)
		ns.CloseOptions()
		ns.Prompt:ExitTest()
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function pages(UI)
	local out = {}
	for _, group in ipairs(UI.Layout().groups) do
		for _, id in ipairs(group) do
			if UI.Layout().pages[id] and UI.PageVisible(id) then out[#out + 1] = id end
		end
	end
	return out
end

local function markShown(UI, path)
	local row = UI.RowFor(path)
	return row and row.mark and row.mark:IsShown() or false
end

local function click(frame)
	local fn = frame:GetScript("OnClick")
	if fn then fn(frame, "LeftButton") end
end

-- The page of `path` open, its fold open, painted.
local function showing(ns, UI, path)
	UI.ShowPage(UI.PageOf(path))
	local at = UI.Where(path)
	if at and at.sec.fold then UI.State().open[at.sec.key] = true end
	ns.RefreshOptionsDisplay()
end

-- ------------------------------------------------------------------ 1
local scenario = "menupass-changed: a fresh profile marks nothing"
for _, class in ipairs({ "MAGE", "PRIEST", "PALADIN", "HUNTER", "ROGUE", "WARRIOR" }) do
	with(scenario, class, "general", function(ns, UI)
		local open = UI.State().open
		for _, id in ipairs(pages(UI)) do
			for _, sec in ipairs(UI.Model(id).sections) do
				if sec.fold then open[sec.key] = true end
			end
		end
		for _, id in ipairs(pages(UI)) do
			UI.ShowPage(id)
			ns.RefreshOptionsDisplay()
			for _, sec in ipairs(UI.Model(id).sections) do
				if sec.fold and UI.FoldChanged(sec) then
					fail(scenario, class .. ": " .. tostring(sec.key) .. "'s dot is lit on a fresh profile")
				end
				for _, e in ipairs(sec.entries) do
					local row = e.row
					if row and row.mark and row.mark:IsShown() then
						fail(scenario, class .. ": " .. e.path .. " on " .. id .. " is marked on a fresh profile")
					end
				end
			end
		end
	end)
end

-- ------------------------------------------------------------------ 2
scenario = "menupass-changed: a changed switch, slider and choice are marked"
with(scenario, "MAGE", "general", function(ns, UI)
	local p = ns.db.profile
	p.prompt.hideInFight = true
	p.timing.skipSeconds = 300
	p.filters.whenBuffed = "always"
	for _, path in ipairs({ "appearance.hideInFight", "advanced.skipSeconds", "when.whenBuffed" }) do
		showing(ns, UI, path)
		if not UI.RowShown(path) then
			fail(scenario, path .. " is not drawn")
		elseif not markShown(UI, path) then
			fail(scenario, path .. " is changed and carries no mark")
		end
	end
	local want = UI.DefaultOf("advanced.skipSeconds", UI.Item("advanced.skipSeconds"))
	if want ~= ns.defaults.profile.timing.skipSeconds then fail(scenario, "DefaultOf answers " .. tostring(want)) end
	p.prompt.hideInFight = false
	showing(ns, UI, "appearance.hideInFight")
	if markShown(UI, "appearance.hideInFight") then fail(scenario, "the mark stays on a switch put back by hand") end
end)

-- ------------------------------------------------------------------ 3
scenario = "menupass-changed: the mark puts one setting back through its own setter"
with(scenario, "MAGE", "general", function(ns, UI)
	local p = ns.db.profile
	p.prompt.hideInFight = true
	p.timing.skipSeconds = 300
	p.filters.whenBuffed = "always"
	local path = "advanced.skipSeconds"
	showing(ns, UI, path)
	local row = UI.RowFor(path)
	if not (row and row.mark and row.mark:IsShown()) then
		fail(scenario, "no mark to click on " .. path)
		return
	end
	local scans, real = 0, ns.addon.StartScanner
	ns.addon.StartScanner = function(...)
		scans = scans + 1
		return real(...)
	end
	click(row.mark)
	ns.addon.StartScanner = real
	if p.timing.skipSeconds ~= ns.defaults.profile.timing.skipSeconds then
		fail(scenario, "skipSeconds is " .. tostring(p.timing.skipSeconds) .. " after the click")
	end
	if scans ~= 1 then fail(scenario, "the click rescanned " .. scans .. " times, not once") end
	if p.prompt.hideInFight ~= true or p.filters.whenBuffed ~= "always" then
		fail(scenario, "the click touched the other changes")
	end
	if row.mark:IsShown() then fail(scenario, "the mark stays after the setting is back") end
end)

-- ------------------------------------------------------------------ 4
scenario = "menupass-changed: What I changed lists every change, and a choice opens it"
with(scenario, "MAGE", "general", function(ns, UI)
	local search = UI.search
	-- Nothing changed: one line saying so.
	local fresh = UI.ShowChanged()
	for _, hit in ipairs(fresh) do fail(scenario, "a fresh profile lists " .. tostring(hit.ref.via or hit.ref.path)) end
	if not search.noneLine:IsShown() or search.noneLine:GetText() ~= ns.L["Nothing changed from the defaults."] then
		fail(scenario, "a fresh profile does not say nothing changed: " .. tostring(search.noneLine:GetText()))
	end
	-- A dozen switches turned from their defaults, and one setting behind a switch.
	local flipped = {}
	for _, hit in ipairs(UI.SearchEntries(true)) do
		local path = hit.ref.path
		local item = not hit.ref.via and UI.Item(path)
		if item and item.def.type == "toggle" and #flipped < 12 then
			local def = UI.DefaultOf(path, item)
			local section = ns.OptionsPage.BOUND[item.def.get]
			if def ~= nil and section then
				ns.db.profile[section][path:match("%.([^.]+)$")] = not def
				flipped[#flipped + 1] = path
			end
		end
	end
	if #flipped < 10 then fail(scenario, "only " .. #flipped .. " switches could be turned for the test") end
	ns.db.profile.speech.enabled = false
	ns.db.profile.speech.channel = "WHISPER"
	ns.RefreshOptionsDisplay()
	local list = UI.ShowChanged()
	if #list < #flipped + 1 then fail(scenario, "the list holds " .. #list .. ", " .. (#flipped + 1) .. " were changed") end
	local at, behind = {}, false
	for i, hit in ipairs(list) do
		at[hit.ref.via or hit.ref.path] = i
		if hit.ref.via == "click.channel" then behind = true end
	end
	if not behind then fail(scenario, "a change behind its switch (Where to say it) is not listed") end
	for _, path in ipairs(flipped) do
		if not at[path] then fail(scenario, path .. " is changed and not listed") end
	end
	-- Page order: no entry sits on an earlier page than the one before it.
	local order = {}
	for i, id in ipairs(pages(UI)) do order[id] = i end
	local last = 0
	for _, hit in ipairs(list) do
		local n = order[hit.ref.page] or 0
		if n < last then fail(scenario, "the list is out of page order at " .. tostring(hit.ref.path)) end
		last = math.max(last, n)
	end
	-- Eight at a time.
	local shown = 0
	for i = 1, 8 do if search.buttons[i]:IsShown() then shown = shown + 1 end end
	if shown ~= 8 then fail(scenario, shown .. " rows are shown, not 8") end
	local more = search.changedMore
	if not more:IsShown() or more.label:GetText() ~= ns.L["%d more"]:format(#list - 8) then
		fail(scenario, "the last line reads " .. tostring(more.label:GetText()))
	else
		click(more)
		local expect = math.min(8, #list - 8)
		shown = 0
		for i = 1, 8 do if search.buttons[i]:IsShown() then shown = shown + 1 end end
		if shown ~= expect then fail(scenario, "the next page shows " .. shown .. " rows, not " .. expect) end
		if search.buttons[1].ref ~= list[9].ref then fail(scenario, "the next page does not start at the ninth change") end
		if #list - 16 > 0 and not more:IsShown() then fail(scenario, "no more line though there are more") end
		if #list - 16 <= 0 and more:IsShown() then fail(scenario, "a more line at the end of the list") end
	end
	-- A choice opens its setting.
	local pick = list[#list]
	local own = pick.ref.via or pick.ref.path
	UI.Choose(pick.ref)
	if UI.page ~= UI.PageOf(own) then fail(scenario, "Choose opened " .. tostring(UI.page) .. ", not " .. tostring(UI.PageOf(own))) end
	if not UI.RowShown(pick.ref.path) then fail(scenario, pick.ref.path .. " is not revealed by Choose") end
	if search.results:IsShown() then fail(scenario, "the list stays over the page after a choice") end
end)
