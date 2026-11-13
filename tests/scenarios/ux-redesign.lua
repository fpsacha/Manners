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
-- not opened). `spec.flavour` (the client), `spec.class`, `spec.locale`, `spec.buffs` (the class's buffs it
-- knows, by key), `spec.known` (spell ids), `spec.before(ns)` (after the load,
-- before the window opens). `body(ns, UI)`. Everything put back.
local function session(scenario, spec, body)
	Mock.reset()
	if spec.flavour then Mock.setFlavour(spec.flavour) end
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

-- ------------------------------------------------------------------ greyed, and why
-- The reason a greyed row gives, drawn under it, or nil.
local function offNote(UI, path)
	local row = UI.RowFor(path)
	if not (row and row.offNote and row.offNote:IsShown()) then return nil end
	return row.offNote:GetText()
end

-- 6: a control greyed by a switch somewhere else says which, under itself and
-- in its tooltip, and only while it is greyed.
do
	local scenario = "ux-redesign: a greyed control says which switch greys it"
	session(scenario, { page = "who" }, function(ns, UI)
		local s = ns.db.profile.sources
		if not UI.RowShown("who.groupBuffsUse") then
			fail(scenario, "SKIPPED -- no group buffs row for this character")
			return
		end
		local open = offNote(UI, "who.groupBuffsUse")
		if open then fail(scenario, "with My party and raid on, Use group buffs still says: " .. open) end
		local row = UI.RowFor("who.groupBuffsUse")
		local tall = row.height
		s.group = false
		ns.RefreshOptionsDisplay()
		local label = ns.L["My party and raid"]
		for _, path in ipairs({ "who.groupBuffsUse", "who.skipRaidGroups" }) do
			local note = offNote(UI, path)
			if not (note and note:find(label, 1, true)) then
				fail(scenario, path .. " greyed by My party and raid says " .. tostring(note))
			end
		end
		if not (row.height > tall) then fail(scenario, "the note is drawn over the next row, not under its own") end
		-- The tooltip says it too.
		local lines = {}
		local tip = GameTooltip
		local add, show, owner = tip.AddLine, tip.Show, tip.SetOwner
		tip.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
		tip.Show, tip.SetOwner = function() end, function() end
		local enter = row.hit and row.hit:GetScript("OnEnter")
		if enter then enter(row.hit) end
		tip.AddLine, tip.Show, tip.SetOwner = add, show, owner
		if not table.concat(lines, "\n"):find(label, 1, true) then
			fail(scenario, "the greyed switch's tooltip does not say why")
		end
		s.group = true
		ns.RefreshOptionsDisplay()
		if offNote(UI, "who.groupBuffsUse") then fail(scenario, "the note stayed once the switch was back on") end
	end)
end

-- 3: the chat switches no longer contradict each other: while every Manners
-- line is hidden, the one that shows more of them is greyed, and says why.
do
	local scenario = "ux-redesign: the chat switch greys while all Manners lines are hidden"
	session(scenario, { page = "general" }, function(ns, UI)
		local p = ns.db.profile
		local item = ns.WindowBind.Item("general.verbose")
		p.silentChat = false
		if ns.WindowBind.Disabled(item) then fail(scenario, "the chat switch is greyed with nothing hiding the lines") end
		p.silentChat = true
		ns.RefreshOptionsDisplay()
		if not ns.WindowBind.Disabled(item) then fail(scenario, "both chat switches can be on at once") end
		local silent = ns.WindowBind.Text(ns.WindowBind.Item("general.silentChat"), "name")
		local note = offNote(UI, "general.verbose")
		if not (note and note:find(silent, 1, true)) then
			fail(scenario, "the greyed chat switch does not name the one greying it: " .. tostring(note))
		end
	end)
end

-- 4: Only in cities and inns (passers-by) greys while nothing at all is
-- offered in cities and inns, and says so.
do
	local scenario = "ux-redesign: Only in cities and inns greys under Offer nothing in cities and inns"
	session(scenario, { page = "who" }, function(ns, UI)
		local f = ns.db.profile.filters
		local item = ns.WindowBind.Item("who.restingOnly")
		f.quietInTowns = false
		if ns.WindowBind.Disabled(item) then fail(scenario, "greyed with passers-by on and nothing held back") end
		f.quietInTowns = true
		ns.RefreshOptionsDisplay()
		if not ns.WindowBind.Disabled(item) then fail(scenario, "the two contradicting switches can both be on") end
		local quiet = ns.WindowBind.Text(ns.WindowBind.Item("who.quietInTowns"), "name")
		local note = offNote(UI, "who.restingOnly")
		if not (note and note:find(quiet, 1, true) and note:find(ns.L["When to offer"], 1, true)) then
			fail(scenario, "the greyed switch does not say which switch, on which page: " .. tostring(note))
		end
	end)
end

-- 12: the footer's button says what it does.
do
	local scenario = "ux-redesign: the footer's reset reads Reset this page"
	session(scenario, { page = "who" }, function(ns, UI)
		local item = ns.WindowBind.Item("advanced.resetAdvanced")
		local name = item and ns.WindowBind.Text(item, "name")
		if name ~= ns.L["Reset this page"] then fail(scenario, "the reset reads " .. tostring(name)) end
	end)
end

-- ------------------------------------------------------------------ words
local function name(ns, path)
	local item = ns.WindowBind.Item(path)
	return item and ns.WindowBind.Text(item, "name") or nil
end

local function expectName(ns, scenario, path, want)
	local got = name(ns, path)
	if got ~= want then fail(scenario, ("%s reads %q, not %q"):format(path, tostring(got), want)) end
end

-- 2: a new profile is asked once: the paragraph first, the two questions,
-- the two buttons side by side; step 1 away while they ask the same thing.
do
	local scenario = "ux-redesign: Quick setup asks once, its buttons side by side"
	session(scenario, { page = "general" }, function(ns, UI)
		if not ns.QuickSetup.Asking() then
			fail(scenario, "SKIPPED -- a new profile is not asked the two questions")
			return
		end
		local sections = ns.WindowLayout.pages.general.sections
		if not (sections[1].key == "general.lead" and sections[2].key == "general.firstRun") then
			fail(scenario, "the paragraph about the prompt does not come before the questions")
		end
		for _, path in ipairs({ "general.quickWho", "general.quickWhoSummary" }) do
			if UI.RowShown(path) then fail(scenario, path .. " asks again under Quick setup") end
		end
		expectName(ns, scenario, "general.firstDone", ns.L["Use these"])
		expectName(ns, scenario, "general.firstSkip", ns.L["Not now"])
		for _, pair in ipairs({ { "general.firstDone", "general.firstSkip" }, { "general.makeMacro", "general.openBindings" } }) do
			local a, b = UI.Where(pair[1]), UI.Where(pair[2])
			-- Open key bindings only where the client has the page to open.
			if not (UI.RowShown(pair[1]) and UI.RowShown(pair[2])) then
				if pair[1] == "general.firstDone" then fail(scenario, pair[1] .. " or " .. pair[2] .. " is not drawn") end
			elseif not (a.e.y == b.e.y and b.e.x > a.e.x
				and b.e.x - (a.e.x + (a.e.row.button or a.e.row.frame):GetWidth()) <= 20) then
				fail(scenario, ("%s is not right beside %s (%s,%s / %s,%s)"):format(pair[2], pair[1], tostring(a.e.x),
					tostring(a.e.y), tostring(b.e.x), tostring(b.e.y)))
			end
		end
		-- The two dropdowns at one width.
		local who, voice = UI.RowFor("general.firstWho"), UI.RowFor("general.firstVoice")
		if who and voice and who.field:GetWidth() ~= voice.field:GetWidth() then
			fail(scenario, ("the two questions' dropdowns are %d and %d wide"):format(who.field:GetWidth(), voice.field:GetWidth()))
		end
		ns.QuickSetup.FinishFirstRun(false)
		if not UI.RowShown("general.quickWho") then fail(scenario, "Offer my buff to is not back once Quick setup is done") end
	end)
end

-- 20e: in German the two choices are of different lengths, and the two
-- dropdowns were drawn at different widths.
do
	local scenario = "ux-redesign: the two Quick setup dropdowns are one width in German"
	session(scenario, { page = "general", locale = "deDE" }, function(ns, UI)
		local who, voice = UI.RowFor("general.firstWho"), UI.RowFor("general.firstVoice")
		if not (who and voice and UI.RowShown("general.firstWho")) then
			fail(scenario, "SKIPPED -- Quick setup is not asked")
		elseif who.field:GetWidth() ~= voice.field:GetWidth() then
			fail(scenario, ("the two questions' dropdowns are %d and %d wide"):format(who.field:GetWidth(), voice.field:GetWidth()))
		end
	end)
end

-- 3, 13, 14, 16's neighbours: what the switches are called now.
do
	local scenario = "ux-redesign: the switches say what they do"
	session(scenario, { page = "general" }, function(ns, UI)
		local L = ns.L
		expectName(ns, scenario, "general.silentChat", L["Hide all Manners messages in my chat window"])
		expectName(ns, scenario, "general.verbose", L["Show what Manners is doing in my chat window"])
		expectName(ns, scenario, "general.minimapHeader", L["Minimap and chat window"])
		expectName(ns, scenario, "when.verifiedOnly", L["Don't offer when the game hides their buffs (fights)"])
		expectName(ns, scenario, "appearance.hideInCombat", L["No flashes in combat"])
		expectName(ns, scenario, "advanced.owedClassBuffsOnly", L["Count only class buffs as favours"])
		expectName(ns, scenario, "general.bindKey", L["Key that casts what the prompt shows"])
		expectName(ns, scenario, "advanced.reasonUnknown", L["Reason text: buffs hidden"])
		expectName(ns, scenario, "appearance.accentByReason", L["Colour by why they are offered"])
		expectName(ns, scenario, "appearance.accentMode", L["Where the colour shows"])
		expectName(ns, scenario, "appearance.accentColor", L["Colour when not by reason"])
		expectName(ns, scenario, "appearance.reasonPalette", L["Colour set"])
		expectName(ns, scenario, "advanced.favoursHeader", L["Buffing back"])
		expectName(ns, scenario, "who.quietInTowns", L["Offer nothing in cities and inns"])
		expectName(ns, scenario, "who.quietInInstances", L["Offer nothing in dungeons, raids and battlegrounds"])
		expectName(ns, scenario, "when.refreshUnder", L["Top up at most this many minutes early"])
		expectName(ns, scenario, "when.selfLead", L["Remind me this many minutes early"])
		expectName(ns, scenario, "diagnostics.copyReport", L["Show a short summary"])
		-- The mana switch names what it holds back.
		local mana = name(ns, "who.relevantOnly") or ""
		local ai = ns.FindBuff("MAGE", "arcaneint") or (ns.GetClassBuffs("MAGE") or {})[1]
		local spell = ai and ns.BuffName(ai) or "?"
		if not mana:find(spell, 1, true) then fail(scenario, "the mana switch does not name " .. spell .. ": " .. mana) end
	end)
end

-- 13: the distance line in plain words, never the client call's name.
do
	local scenario = "ux-redesign: the passer-by distance line names no client call"
	session(scenario, { page = "diagnostics" }, function(ns, UI)
		local row = UI.RowFor("diagnostics.proximityDiag")
		local text = row and row.text and row.text:GetText() or ""
		if text == "" then
			fail(scenario, "SKIPPED -- no distance line")
		elseif text:find("CheckInteractDistance", 1, true) or text:find("LibRangeCheck", 1, true) then
			fail(scenario, "the distance line names the API: " .. text)
		end
	end)
end

-- 14: one word for the people near you that are not in your group.
do
	local scenario = "ux-redesign: the launcher calls a passer-by a passer-by"
	session(scenario, {}, function(ns)
		local restore = H.strangers({ nameplate1 = { "Anna", "Aim" } })
		H.freshPrompt(ns, scenario)
		ns.addon:Tick()
		local broker = Mock.broker
		local lines = {}
		if broker and broker.OnTooltipShow then
			broker.OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = tostring(text) end })
		end
		restore()
		local text = table.concat(lines, "\n")
		if not text:find("Anna", 1, true) then
			fail(scenario, "SKIPPED -- the tooltip does not show the passer-by: " .. text)
		elseif text:find("nearby", 1, true) or not text:find("a passer-by", 1, true) then
			fail(scenario, "the tooltip does not call her a passer-by: " .. text)
		end
	end)
end

-- 15: no key is not a fault.
do
	local scenario = "ux-redesign: no key is said in gold, with no red dot"
	session(scenario, { page = "general" }, function(ns, UI)
		local row = UI.RowFor("general.bindStatus")
		local text = row and row.text and row.text:GetText() or ""
		if text:find("|cffff8080", 1, true) or not text:find("|cffffd100", 1, true) then
			fail(scenario, "the line under step 2 is not gold: " .. text)
		end
		if ns.OptionsPage.Warn.general ~= nil then fail(scenario, "Start here still has a red dot for the key") end
	end)
end

-- 16: the profile controls in the player's words, over the library's.
do
	local scenario = "ux-redesign: Profiles speaks the player's words"
	session(scenario, {}, function(ns)
		local lib = LibStub("AceDBOptions-3.0")
		local real = lib.GetOptionsTable
		local developer = {}
		for _, key in ipairs({ "current", "choosedesc", "new", "choose", "copydesc", "copyfrom", "deldesc", "delete", "descreset", "reset" }) do
			local note = key:find("desc") or key == "current"
			developer[key] = { type = note and "description" or "execute", name = "library " .. key, desc = not note and "library tip" or nil }
		end
		local shared = { type = "group", name = "Profiles", args = developer }
		lib.GetOptionsTable = function() return shared end
		local ok, tab = pcall(ns.OptionsPage.BuildProfilesTab)
		lib.GetOptionsTable = real
		if not ok then
			fail(scenario, "building the tab threw: " .. tostring(tab))
			return
		end
		local L = ns.L
		local want = { new = L["New profile"], choose = L["Use profile"], copyfrom = L["Copy from"], delete = L["Delete"],
			reset = L["Reset this profile"],
			choosedesc = L["Type a name to start a new profile, or pick one you already have."] }
		for key, words in pairs(want) do
			if tab.args[key].name ~= words then fail(scenario, key .. " reads " .. tostring(tab.args[key].name)) end
		end
		for key, option in pairs(tab.args) do
			local text = type(option.name) == "function" and option.name({ handler = { GetCurrentProfile = function() return "Default" end } })
				or option.name
			if tostring(text):find("library", 1, true) or tostring(option.desc or ""):find("library", 1, true) then
				fail(scenario, key .. " still reads the library's words")
			end
		end
		if developer.new.name ~= "library new" then fail(scenario, "the library's own table was written to") end
	end)
end

-- 20: the polish.
do
	local scenario = "ux-redesign: Stay silent is not followed by Silent."
	session(scenario, { page = "click" }, function(ns, UI)
		local quick = ns.QuickSetup
		quick.Apply(quick.VOICE, "silent")
		ns.RefreshOptionsDisplay()
		if UI.RowShown("general.quickVoiceSummary") then fail(scenario, "Stay silent is followed by its summary") end
		quick.Apply(quick.VOICE, "thank")
		ns.RefreshOptionsDisplay()
		if not UI.RowShown("general.quickVoiceSummary") then fail(scenario, "Just /thank them has no summary") end
	end)
end

do
	local scenario = "ux-redesign: Skip players below level says what 1 means"
	session(scenario, { page = "skip" }, function(ns, UI)
		ns.db.profile.filters.minLevel = 1
		ns.RefreshOptionsDisplay()
		if not UI.RowShown("who.minLevelNote") then fail(scenario, "at 1 the slider's 1 is not explained") end
		ns.db.profile.filters.minLevel = 20
		ns.RefreshOptionsDisplay()
		if UI.RowShown("who.minLevelNote") then fail(scenario, "at 20 the note about 1 is still shown") end
	end)
end

do
	local scenario = "ux-redesign: a rogue's Diagnostics has no error colour and no distance"
	session(scenario, { class = "ROGUE", page = "diagnostics" }, function(ns, UI)
		if UI.RowShown("diagnostics.proximityDiag") then fail(scenario, "a rogue is shown how passers-by are measured") end
		local row = UI.RowFor("diagnostics.noDiag")
		local text = row and row.text and row.text:GetText() or ""
		if not UI.RowShown("diagnostics.noDiag") then
			fail(scenario, "SKIPPED -- the rogue's line is not drawn")
		elseif text:find("|cffff8080", 1, true) then
			fail(scenario, "a class with nothing for others is told so in red")
		end
	end)
end

do
	local scenario = "ux-redesign: Start here's paragraph is body text, not a heading"
	session(scenario, { page = "general" }, function(ns, UI)
		local w = UI.Where("general.howItWorks")
		if not w then
			fail(scenario, "SKIPPED -- no paragraph")
		elseif w.e.layout.lead then
			fail(scenario, "the paragraph is drawn a size up, as a heading")
		end
	end)
end

-- The new rows of 1.11.11, read on the clients that have them.
do
	local scenario = "ux-redesign: Earth Shield's shaman is not told it is cast on herself"
	session(scenario, { flavour = "mists", class = "SHAMAN", known = { 974, 324 }, page = "who" }, function(ns, UI)
		local item = ns.WindowBind.Item("who.strangersNote")
		if not (item and UI.RowShown("who.strangersNote")) then
			fail(scenario, "SKIPPED -- no passers-by note for a mists shaman")
			return
		end
		local text = ns.WindowBind.Text(item, "name") or ""
		if text:find(ns.L["Everything you can offer is cast on yourself and reaches only your party, so there is nothing for passers-by."], 1, true) then
			fail(scenario, "a shaman whose Earth Shield goes on a tank is told it is cast on herself")
		end
	end)
end

do
	local scenario = "ux-redesign: Beacon of Light is not one of the blessings that replace one another"
	session(scenario, { flavour = "mists", class = "PALADIN", buffs = { "kings", "might", "beacon" }, page = "who" }, function(ns, UI)
		local item = ns.WindowBind.Item("who.autoNote")
		local text = item and ns.WindowBind.Text(item, "name") or ""
		local beacon = ns.FindBuff("PALADIN", "beacon")
		if not (beacon and ns.IsBuffKnown(beacon) and text ~= "") then
			fail(scenario, "SKIPPED -- no Beacon of Light learned")
			return
		end
		local first = text:match("^[^\n]*")
		if first:find(ns.BuffName(beacon), 1, true) then
			fail(scenario, "Beacon of Light is listed among the blessings that replace one another: " .. first)
		end
	end)
end

do
	local scenario = "ux-redesign: a class with nothing for others has Consumables only in dungeons and raids"
	session(scenario, { class = "HUNTER", known = { 13165, 13163 }, page = "who" }, function(ns, UI)
		if not UI.RowShown("who.self") then
			fail(scenario, "SKIPPED -- the hunter has no Myself")
		elseif not UI.RowShown("who.ownDungeons") then
			fail(scenario, "a hunter cannot hold his food and flasks to dungeons")
		end
	end)
end

-- ------------------------------------------------------------------ search
-- 7: a tooltip matches at the start of a word, and Chinese anywhere; other
-- words for a control rank with its choices.
do
	local scenario = "ux-redesign: search reads tooltips by whole words and knows other words"
	session(scenario, {}, function(ns)
		local Search = ns.WindowSearch
		local entries = {
			{ label = "Up", desc = "It stays on screen." },
			{ label = "Speech", desc = "Says a line when you buff someone." },
			{ label = "Silence", keywords = "quiet mute spam" },
			{ label = "Chinese", desc = "\232\175\180\232\175\157" },
		}
		local function labels(query)
			local out = {}
			for _, hit in ipairs(Search.Find(query, entries)) do out[#out + 1] = hit.label end
			return table.concat(out, ", ")
		end
		if labels("tays") ~= "" then fail(scenario, "a word's middle matched a tooltip: " .. labels("tays")) end
		if labels("says") ~= "Speech" then fail(scenario, "a tooltip's word was not found: " .. labels("says")) end
		if labels("mute") ~= "Silence" then fail(scenario, "the other words for a control were not searched") end
		if labels("\232\175\157") ~= "Chinese" then fail(scenario, "Chinese in a tooltip is not found inside a word") end
	end)
end

-- 7: in the window, "quiet" finds the chat switches; a search that finds more
-- than the list holds says so; one that finds nothing says so in words.
do
	local scenario = "ux-redesign: the search box finds quiet, says when there is more and when there is nothing"
	session(scenario, { page = "general" }, function(ns, UI)
		local search = UI.search
		local box = search and search.box
		if not box then
			fail(scenario, "SKIPPED -- no search box")
			return
		end
		local function run(text)
			box:SetText(text)
			UI.RunSearch()
			return search.found
		end
		local found = run("quiet")
		local hit = false
		for _, f in ipairs(found) do
			if f.ref.path == "general.silentChat" then hit = true end
		end
		if not hit then fail(scenario, "quiet does not find Hide all Manners messages") end
		found = run("buff")
		if #found > 8 and not search.moreLine:IsShown() then
			fail(scenario, ("%d things match buff and the list does not say there are more"):format(#found))
		elseif #found <= 8 then
			fail(scenario, "SKIPPED -- buff matches only " .. #found)
		end
		run("zzqqxx")
		if not (search.noneLine:IsShown() and (search.noneLine:GetText() or "") ~= "") then
			fail(scenario, "a search that finds nothing says nothing")
		end
		if search.moreLine:IsShown() then fail(scenario, "an empty search says there are more") end
	end)
end

-- 7: a control hidden until a switch is on is found, and leads to the switch.
do
	local scenario = "ux-redesign: search finds Line set while Say a line is off"
	session(scenario, { page = "general" }, function(ns, UI)
		ns.db.profile.speech.enabled = false
		ns.RefreshOptionsDisplay()
		local box = UI.search and UI.search.box
		if not box then
			fail(scenario, "SKIPPED -- no search box")
			return
		end
		box:SetText(ns.L["Line set"])
		UI.RunSearch()
		local hit
		for _, f in ipairs(UI.search.found) do
			if f.ref.via == "click.preset" then hit = f end
		end
		if not hit then
			fail(scenario, "Line set is not found while Say a line is off")
			return
		end
		if hit.ref.path ~= "click.enabled" or not hit.first then
			fail(scenario, "the result does not lead to Say a line, or does not say to turn it on")
		end
		local e = UI.Choose(hit.ref)
		if not (e and UI.page == "click" and UI.RowShown("click.enabled")) then
			fail(scenario, "choosing it did not open Say a line")
		end
	end)
end

-- ------------------------------------------------------------------ buttons
-- 8: what only a slash command reached, as buttons.
do
	local scenario = "ux-redesign: the slash-only commands have buttons"
	session(scenario, { page = "diagnostics" }, function(ns, UI)
		local said = {}
		local real = ns.addon.HandleSlash
		ns.addon.HandleSlash = function(_, text) said[#said + 1] = text end
		local function press(path)
			local item = ns.WindowBind.Item(path)
			if not item then
				fail(scenario, path .. " is not in the model")
				return
			end
			ns.WindowBind.Run(item)
		end
		press("diagnostics.launchCheck")
		press("general.welcomeAgain")
		ns.addon.HandleSlash = real
		local text = table.concat(said, " / ")
		if text ~= "selftest launch / welcome" then fail(scenario, "the buttons ran " .. text) end
		if not UI.RowShown("diagnostics.launchCheck") then fail(scenario, "Check how Manners draws is not drawn") end
		before(UI, scenario, "diagnostics.fullReport", "diagnostics.launchCheck")
		-- Show every error, once there are more than the five listed.
		if UI.RowShown("diagnostics.allErrors") then fail(scenario, "Show every error with no errors") end
		-- The section stays, with its notes, while the button is away.
		if not UI.RowShown("diagnostics.noErrors") then fail(scenario, "Errors this session went with the button") end
		for i = 1, 6 do ns.Guard("ux test", error, "error " .. i, 0) end
		ns.RefreshOptionsDisplay()
		if not UI.RowShown("diagnostics.allErrors") then fail(scenario, "six errors and no Show every error") end
		if not UI.RowShown("diagnostics.errorList") then fail(scenario, "six errors and no list of them") end
		wipe(ns.errors)
	end)
end

do
	local scenario = "ux-redesign: Put my settings back shows while an import can be undone"
	session(scenario, { page = "profiles" }, function(ns, UI)
		local item = ns.WindowBind.Item("profiles.shareUndo")
		if not item then
			fail(scenario, "there is no Put my settings back")
			return
		end
		if not ns.WindowBind.Hidden(item) then fail(scenario, "Put my settings back with nothing to undo") end
		local text = ns.ExportSettings()
		ns.ImportSettings(text)
		if ns.WindowBind.Hidden(item) then fail(scenario, "after an import there is no Put my settings back") end
		ns.WindowBind.Run(item)
		if not ns.WindowBind.Hidden(item) then fail(scenario, "the undo was not taken, or the button stayed") end
	end)
end

-- ------------------------------------------------------------------ right now
-- 19: who the settings come to right now, read off the last scan.
do
	local scenario = "ux-redesign: the pages say who is on the prompt right now"
	session(scenario, {}, function(ns)
		H.freshPrompt(ns, scenario)
		H.owe(ns, "Anna Aim")
		ns.addon:Tick()
		local built = 0
		local real = ns.BuildQueue
		ns.BuildQueue = function(...)
			built = built + 1
			return real(...)
		end
		local ok, line = pcall(ns.OptionsPage.RightNow)
		ns.BuildQueue = real
		if not ok then
			fail(scenario, "the line threw: " .. tostring(line))
			return
		end
		if built > 0 then fail(scenario, "the line built a queue of its own") end
		-- Whoever the prompt is on (the session's target first), and Anna,
		-- who buffed you, waiting behind them.
		local showing = ns.Prompt:Showing()
		local who = showing and tostring(showing.display or showing.short or showing.name)
		if not (who and line and line:find(who, 1, true)) then
			fail(scenario, "the line does not name who the prompt is on: " .. tostring(line))
		elseif not line:find(ns.L["1 more is waiting."], 1, true) then
			fail(scenario, "the line does not count the one waiting behind: " .. tostring(line))
		end
		ns.OpenOptions("who", true)
		ns.Prompt:ExitTest()
		ns.RefreshOptionsDisplay()
		local UI = ns.WindowUI
		for _, pair in ipairs({ { "who", "who.rightNow" }, { "skip", "who.rightNowSkip" }, { "when", "when.rightNow" } }) do
			UI.ShowPage(pair[1])
			if not UI.RowShown(pair[2]) then fail(scenario, pair[2] .. " is not drawn on " .. pair[1]) end
		end
		ns.Prompt:ApplyTarget(nil)
	end)
	session(scenario, {}, function(ns)
		ns.Prompt:ExitTest()
		local line = ns.OptionsPage.RightNow()
		if not (line and line:find(ns.L["Right now: nobody to offer."], 1, true)) then
			fail(scenario, "with nobody about, the line says " .. tostring(line))
		end
	end)
end
