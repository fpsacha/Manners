-- Round 37, the options window redesign: the twenty findings of the round 36
-- audit of the options window, each held here.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every name
-- starts with "ux-redesign:" so a mutation can name exactly one.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell" }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function near(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (tol or 1e-3) end

-- One session on the recording client, the window open on `spec.page` (none:
-- not opened). `spec.class`, `spec.locale`, `spec.buffs` (the class's buffs it
-- knows, by key), `spec.known` (spell ids), `spec.before(ns)` (after the load,
-- before the window opens). `body(ns, UI)`. Everything put back.
local function session(scenario, spec, body)
	Mock.reset()
	if spec.class then Mock.class = spec.class end
	if spec.locale then Mock.locale = spec.locale end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	FT.install()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		if spec.buffs or spec.known then
			local set = {}
			for _, id in ipairs(spec.known or {}) do set[id] = true end
			for _, key in ipairs(spec.buffs or {}) do
				local buff = ns.FindBuff(Mock.class, key)
				for _, id in ipairs(buff and buff.ranks or {}) do set[id] = true end
			end
			IsSpellKnown = function(id) return set[id] == true end
			IsPlayerSpell = IsSpellKnown
		end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		if spec.before then spec.before(ns) end
		if spec.page then ns.OpenOptions(spec.page, true) end
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		noErrors(scenario, ns)
	end)
	FT.uninstall()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 1
-- The Luxe card's tag: its slices are made when the card is first laid out,
-- after the card was painted, and were left the file's own white until the
-- pointer passed over the card.
do
	local scenario = "ux-redesign: the Luxe card's tag is tinted the first time the page is drawn"
	session(scenario, { class = "WARRIOR", buffs = { "battleshout" }, page = "appearance" }, function(ns, UI)
		local row = UI.RowFor("appearance.style")
		local spec = ns.Looks.previewText.luxe and ns.Looks.previewText.luxe.reason
		local pill = spec and spec.pill
		if not (row and row.cards and pill) then
			fail(scenario, "SKIPPED -- no gallery, or Luxe records no tag")
			return
		end
		local card
		for _, c in ipairs(row.cards) do
			if c:IsShown() and c.key == "luxe" then card = c end
		end
		if not card then
			fail(scenario, "there is no Luxe card")
			return
		end
		-- As on the first paint: no slices yet when the card is painted, made
		-- by the layout that follows, with no paint after it.
		for _, s in ipairs(card.pill) do
			for _, t in ipairs(s) do t:Hide() end
		end
		card.pill = {}
		row:Layout(row.width or 612)
		if #card.pill == 0 then
			fail(scenario, "the layout made no tag")
		end
		for i, layer in ipairs(pill.layers) do
			for j, t in ipairs(card.pill[i] or {}) do
				local c = t._color
				local same = type(c) == "table"
				for k = 1, 4 do
					if same and not near(c[k] == nil and 1 or c[k], layer.color[k] == nil and 1 or layer.color[k]) then same = false end
				end
				if t:IsShown() and not same then
					fail(scenario, ("layer %d slice %d is not the look's colour before any hover"):format(i, j))
				end
			end
		end
	end)
end

-- ------------------------------------------------------------------ layout
-- Where a placed control sits: its page, its section's key, its place in the
-- section (shown or not) and the section, or nil.
local function placed(UI, path)
	local w = UI.Where(path)
	if not (w and w.sec) then return nil end
	for i, e in ipairs(w.sec.entries) do
		if e == w.e then return w.page, w.sec.key, i, w.sec end
	end
	return w.page, w.sec.key, nil, w.sec
end

local function before(UI, scenario, first, second)
	local p1, s1, i1 = placed(UI, first)
	local p2, s2, i2 = placed(UI, second)
	if not (p1 and p2 and p1 == p2 and s1 == s2 and i1 and i2 and i1 < i2) then
		fail(scenario, ("%s does not come before %s in one section (%s %s %s / %s %s %s)"):format(first, second,
			tostring(p1), tostring(s1), tostring(i1), tostring(p2), tostring(s2), tostring(i2)))
	end
end

-- 4: the two place rules hold back everybody; in the list of people on Who to
-- buff they read as a kind of person and contradicted Only in cities and inns.
do
	local scenario = "ux-redesign: the place rules lead Hold back on When to offer"
	session(scenario, { page = "when" }, function(ns, UI)
		for _, path in ipairs({ "who.quietInTowns", "who.quietInInstances" }) do
			local page, sec = placed(UI, path)
			if page ~= "when" or sec ~= "when.holdBack" then
				fail(scenario, ("%s is on %s, %s, not under Hold back on When to offer"):format(path, tostring(page), tostring(sec)))
			elseif not UI.RowShown(path) then
				fail(scenario, path .. " is not drawn on When to offer")
			end
		end
		before(UI, scenario, "who.quietInTowns", "who.quietInInstances")
		before(UI, scenario, "who.quietInInstances", "when.hideMounted")
		local list = ns.OptionsPage.RESET
		local function has(id, field)
			for _, f in ipairs(list[id] or {}) do
				if f == field then return true end
			end
			return false
		end
		for _, field in ipairs({ "filters.quietInTowns", "filters.quietInInstances" }) do
			if not has("when", field) or has("who", field) then
				fail(scenario, field .. " is not put back by When to offer's reset alone")
			end
		end
	end)
end

-- 5: where your own reminders come up, under the families and above Never
-- remind me about, so they do not read as items of that list.
do
	local scenario = "ux-redesign: the Myself place switches come before Never remind me about"
	session(scenario, { page = "who" }, function(ns, UI)
		before(UI, scenario, "who.own_tracking", "who.ownCities")
		before(UI, scenario, "who.ownCities", "who.ownDungeons")
		before(UI, scenario, "who.ownDungeons", "who.own_leave")
		before(UI, scenario, "who.own_leave", "diagnostics.ownDiag")
	end)
end

-- 9: other people's top-up and your own under headings of their own, and the
-- 0 on your own lead said in words.
do
	local scenario = "ux-redesign: your own top-ups have a section of their own and their 0 explained"
	session(scenario, { page = "when" }, function(ns, UI)
		local page, sec, _, s = placed(UI, "when.selfTopUp")
		if page ~= "when" or sec ~= "when.self" or not (s and s.def.header == "when.selfHeader") then
			fail(scenario, "Top up my own buffs is not under My own buffs (" .. tostring(sec) .. ")")
		end
		before(UI, scenario, "when.selfTopUp", "when.selfLead")
		before(UI, scenario, "when.selfLead", "when.selfLeadNote")
		local _, other = placed(UI, "when.whenBuffed")
		if other ~= "when.buffed" then fail(scenario, "If they already have it left its section") end
		local args = ns.optionsTable.args.when.args
		local head = args.selfHeader
		if not (head and head.type == "header" and head.name == ns.L["My own buffs"]) then
			fail(scenario, "the model has no My own buffs header")
		end
		local name = args.buffedHeader and args.buffedHeader.name
		if type(name) == "function" then name = name({}) end
		if name ~= ns.L["Other people already buffed"] then
			fail(scenario, "the first section reads " .. tostring(name) .. " for a class with buffs for others")
		end
		-- The model's order keeps the section after other people's, for the
		-- old dialog.
		if head and not (head.order > args.verifiedOnly.order and args.selfTopUp.order > head.order
			and args.selfLeadNote.order > args.selfLead.order and args.wayHeader.order > args.selfLeadNote.order) then
			fail(scenario, "the model's orders do not keep My own buffs together after other people's")
		end
		ns.db.profile.filters.selfLead = 0
		ns.RefreshOptionsDisplay()
		if not UI.RowShown("when.selfLeadNote") then fail(scenario, "at 0 the slider's 0 is not explained") end
		ns.db.profile.filters.selfLead = 3
		ns.RefreshOptionsDisplay()
		if UI.RowShown("when.selfLeadNote") then fail(scenario, "at 3 the note about 0 is still shown") end
	end)
end

-- 10: Blessing of Kings first sits on top of the order it changes.
do
	local scenario = "ux-redesign: Kings first sits on top of the Buff order list"
	session(scenario, { class = "PALADIN", buffs = { "wisdom", "might", "kings" }, page = "who" }, function(ns, UI)
		local page, sec, i = placed(UI, "who.kingsFirst")
		if page ~= "who" or sec ~= "who.order" or i ~= 1 then
			fail(scenario, ("Kings first is at %s, %s, %s, not first under Buff order"):format(tostring(page), tostring(sec), tostring(i)))
		end
		if ns.StrongestBuff() and not UI.RowShown("who.kingsFirst") then
			fail(scenario, "Kings first is not drawn for a paladin with Kings")
		end
	end)
end

-- 11: the clickable waiting list out of the icon's fold, in a section of its
-- own above the folds; the fold keeps the icon and says so.
do
	local scenario = "ux-redesign: the waiting list has its own section above the folds"
	session(scenario, { page = "appearance" }, function(ns, UI)
		for _, path in ipairs({ "appearance.showCount", "appearance.showQueue", "appearance.queueRows", "appearance.clickRows" }) do
			local page, sec, _, s = placed(UI, path)
			if page ~= "appearance" or sec ~= "appearance.queue" or (s and s.fold) then
				fail(scenario, ("%s is in %s, not the Waiting list section"):format(path, tostring(sec)))
			end
		end
		before(UI, scenario, "appearance.showQueue", "appearance.clickRows")
		local _, _, _, icon = placed(UI, "appearance.showIcon")
		if not (icon and icon.fold and icon.def.title == ns.L["Icon"]) then
			fail(scenario, "the icon's fold is not titled Icon")
		end
		local _, _, _, queue = placed(UI, "appearance.showQueue")
		if not (queue and queue.def.title == ns.L["Waiting list"]) then
			fail(scenario, "the waiting list's section is not titled Waiting list")
		end
		ns.db.profile.prompt.showQueue = true
		ns.RefreshOptionsDisplay()
		if not UI.RowShown("appearance.clickRows") then
			fail(scenario, "Click a name in the list is not drawn with every fold shut")
		end
	end)
end

-- 17: which report button a player asked for a report wants, and the click
-- log under the buttons.
do
	local scenario = "ux-redesign: Reporting a bug says which button to press, the click log under the buttons"
	session(scenario, { page = "diagnostics" }, function(ns, UI)
		before(UI, scenario, "diagnostics.reportHint", "diagnostics.fullReport")
		before(UI, scenario, "diagnostics.fullReport", "diagnostics.copyReport")
		before(UI, scenario, "diagnostics.copyReport", "diagnostics.debugClicks")
		if not UI.RowShown("diagnostics.reportHint") then fail(scenario, "the hint is not drawn") end
		local row = UI.RowFor("diagnostics.reportHint")
		local text = row and row.text and row.text:GetText() or ""
		if not text:find(ns.L["Run a full check-up"], 1, true) then
			fail(scenario, "the hint does not name Run a full check-up: " .. text)
		end
	end)
end

-- 18: one "Where it sits" a page, not a section title and a dropdown under it.
do
	local scenario = "ux-redesign: Look's place section is titled Position"
	session(scenario, { page = "appearance" }, function(ns, UI)
		local _, sec, _, s = placed(UI, "appearance.posPreset")
		if not (sec == "appearance.where" and s and s.def.title == ns.L["Position"]) then
			fail(scenario, "the section over Where it sits is not Position")
		end
	end)
end
