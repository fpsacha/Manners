-- Everything about where and when Manners holds back or says nothing is on one
-- page, Quiet times: the place rules, the group rules for the spoken line and
-- the thanks (side by side, not under the one switch that governs only the
-- line), battlegrounds, being mounted and low on mana. Its reset puts them back
-- and keeps what a class with nothing to give never says.
--
-- Every scenario name starts with "menupass-quiet:".
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

-- The sixteen controls, by path.
local QUIET = {
	"who.quietInTowns", "who.quietInTownsWhere", "who.quietShortInTowns", "who.quietShortMinutes",
	"who.quietInInstances", "who.quietTargets",
	"when.hideMounted", "when.manaFloor", "when.manaFloorKeeps",
	"when.battleTeam", "when.battleSpeak", "when.battleThank", "when.battleItems",
	"click.quietInParty", "click.quietInRaid", "click.thankNotInGroup",
}

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- opts.class (default PRIEST).
local function with(scenario, opts, body)
	opts = opts or {}
	Mock.reset()
	Mock.class = opts.class or "PRIEST"
	local ns = load(scenario)
	if not ns then return end
	local ok, err = pcall(function()
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		ns.Prompt:ExitTest()
		noErrors(scenario, ns)
	end)
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function section(ns, key)
	for _, sec in ipairs(ns.WindowLayout.pages.quiet.sections) do
		if sec.key == key then return sec end
	end
end

-- ------------------------------------------------------------------ the page
do
	local scenario = "menupass-quiet: every place and group rule is on Quiet times"
	with(scenario, nil, function(ns, UI)
		for _, path in ipairs(QUIET) do
			if UI.PageOf(path) ~= "quiet" then
				fail(scenario, path .. " is on " .. tostring(UI.PageOf(path)) .. ", not Quiet times")
			end
		end
		if #QUIET ~= 16 then fail(scenario, "the scenario lists " .. #QUIET .. " controls, not 16") end
		if ns.OptionsPage.TAB.quiet ~= ns.L["Quiet times"] then
			fail(scenario, "the page's name is " .. tostring(ns.OptionsPage.TAB.quiet))
		end
		ns.OpenOptions("quiet")
		if ns.OptionsTab() ~= "quiet" then fail(scenario, "OpenOptions(\"quiet\") opened " .. tostring(ns.OptionsTab())) end
		for _, id in ipairs({ "when", "click" }) do
			for _, sec in ipairs(ns.WindowLayout.pages[id].sections) do
				for _, raw in ipairs(sec.items) do
					local path = type(raw) == "table" and raw[1] or raw
					for _, quiet in ipairs(QUIET) do
						if path == quiet then fail(scenario, id .. " still holds " .. path) end
					end
				end
			end
		end
		local sidebar = {}
		for _, group in ipairs(ns.WindowLayout.groups) do
			for _, id in ipairs(group) do sidebar[#sidebar + 1] = id end
		end
		if not table.concat(sidebar, " "):find("when quiet fight click", 1, true) then
			fail(scenario, "the sidebar is " .. table.concat(sidebar, " "))
		end
	end)
end

-- ------------------------------------------------------------------ side by side
do
	local scenario = "menupass-quiet: speech and thanks in a group sit together"
	with(scenario, nil, function(ns, UI)
		local sec = section(ns, "quiet.group")
		if not sec then fail(scenario, "no section quiet.group") return end
		local want = { "click.quietInParty", "click.quietInRaid", "click.thankNotInGroup" }
		if #sec.items ~= #want then fail(scenario, "In a party or a raid holds " .. #sec.items .. " items") end
		for i, path in ipairs(want) do
			local item = sec.items[i]
			if item ~= path then
				fail(scenario, ("item %d is %s, not %s (an indent would hide it under a switch)"):format(i,
					type(item) == "table" and tostring(item[1]) .. " (indented)" or tostring(item), path))
			end
		end
		ns.OpenOptions("quiet")
		for _, path in ipairs(want) do
			if not UI.RowShown(path) then fail(scenario, path .. " is not drawn on Quiet times") end
		end
		local at = UI.Where("click.quietInParty")
		local raid = UI.Where("click.quietInRaid")
		if at and raid and at.e.x ~= raid.e.x then fail(scenario, "the party and raid switches are not at one indent") end
		local text = UI.Where("click.thankNotInGroup")
		if at and text and at.e.x ~= text.e.x then fail(scenario, "the thank switch is not at the speech switches' indent") end
	end)
end

-- ------------------------------------------------------------------ the shared options
do
	local scenario = "menupass-quiet: with only the whisper on, its shared options show"
	with(scenario, nil, function(ns, UI)
		local db = ns.db.profile
		db.prompt.thankEmote, db.prompt.thankWhisper = false, true
		db.prompt.thankAsk, db.prompt.thankDelay = false, false
		ns.OpenOptions("click")
		ns.RefreshOptionsDisplay()
		for _, path in ipairs({ "click.thankDelay", "click.thankAsk", "click.thankUnseen" }) do
			if not UI.RowShown(path) then
				fail(scenario, path .. " is not drawn with the whisper on")
			else
				local row = UI.RowFor(path)
				if row and row.off then fail(scenario, path .. " is greyed with the whisper on") end
				if UI.PageOf(path) ~= "click" then fail(scenario, path .. " is on " .. tostring(UI.PageOf(path))) end
			end
		end
		local sec = section(ns, "quiet.group")
		for _, raw in ipairs(ns.WindowLayout.pages.click.sections) do
			if raw.key == "click.speech" then
				for _, item in ipairs(raw.items) do
					local path = type(item) == "table" and item[1] or item
					if (path == "click.thankDelay" or path == "click.thankAsk" or path == "click.thankUnseen")
						and type(item) == "table" and item.indent then
						fail(scenario, path .. " is indented under one thank switch")
					end
				end
			end
		end
		if not sec then fail(scenario, "no quiet.group") end
	end)
end

-- ------------------------------------------------------------------ the greyed notes
do
	local scenario = "menupass-quiet: greyed group switches say what to tick and where"
	with(scenario, nil, function(ns, UI)
		local W, B = ns.WindowWidgets, ns.WindowBind
		local db = ns.db.profile
		db.speech.enabled = false
		db.prompt.thankEmote, db.prompt.thankWhisper = false, false
		ns.OpenOptions("quiet")
		ns.RefreshOptionsDisplay()
		local say = B.Text(B.Item("click.enabled"), "name")
		for _, path in ipairs({ "click.quietInParty", "click.quietInRaid" }) do
			local row = UI.RowFor(path)
			if not (UI.RowShown(path) and row) then
				fail(scenario, path .. " is not drawn, greyed, with Say a line off")
			else
				if not row.off then fail(scenario, path .. " is live with Say a line off") end
				local note = W.OffNote(row) or ""
				if not note:find(say, 1, true) then fail(scenario, path .. "'s note names no switch: " .. note) end
				if not note:find(ns.L["What I say"], 1, true) then fail(scenario, path .. "'s note names no page: " .. note) end
			end
		end
		local row = UI.RowFor("click.thankNotInGroup")
		if not (UI.RowShown("click.thankNotInGroup") and row and row.off) then
			fail(scenario, "the thank switch is not drawn greyed with both thanks off")
		else
			local note = W.OffNote(row) or ""
			local emote = B.Text(B.Item("click.thankEmote"), "name")
			local whisper = B.Text(B.Item("click.thankWhisper"), "name")
			if not (note:find(emote, 1, true) and note:find(whisper, 1, true) and note:find(ns.L["What I say"], 1, true)) then
				fail(scenario, "the thank switch's note is " .. note)
			end
		end
		-- The pause, the press and the thank for nobody named all say what to tick.
		ns.OpenOptions("click")
		ns.RefreshOptionsDisplay()
		for _, path in ipairs({ "click.thankDelay", "click.thankAsk", "click.thankUnseen" }) do
			local r = UI.RowFor(path)
			if not (UI.RowShown(path) and r and r.off) then
				fail(scenario, path .. " is not drawn greyed with both thanks off")
			else
				local note = W.OffNote(r) or ""
				if not note:find(B.Text(B.Item("click.thankWhisper"), "name"), 1, true) then
					fail(scenario, path .. "'s note names no switch: " .. note)
				end
			end
		end
		-- A search for the switch finds it itself, with no turn-on-first.
		local found = ns.WindowSearch.Find("say nothing in a party", UI.SearchEntries(), 8)
		local hit
		for _, entry in ipairs(found) do
			local ref = entry.ref or {}
			if ref.path == "click.quietInParty" then hit = entry end
		end
		if not hit then
			fail(scenario, "a search for Say nothing in a party does not find it")
		elseif (hit.ref or {}).via or hit.first then
			fail(scenario, "the search sends the player to another switch first")
		end
	end)
end

-- ------------------------------------------------------------------ the reset
do
	local scenario = "menupass-quiet: Quiet times' reset puts them back and keeps a rogue's speech"
	for _, class in ipairs({ "WARRIOR", "ROGUE" }) do
		with(scenario, { class = class }, function(ns, UI)
			local db, d = ns.db.profile, ns.defaults.profile
			local function unsettle()
				db.filters.quietInTowns, db.filters.hideMounted = true, true
				db.battle.speak = not d.battle.speak
				db.speech.quietInParty, db.speech.quietInRaid = true, true
				db.prompt.thankNotInGroup = true
			end
			unsettle()
			if ns.OptionsPage.ResetPage("quiet") ~= true then fail(scenario, class .. ": the reset did not run") return end
			if db.filters.quietInTowns ~= d.filters.quietInTowns or db.filters.hideMounted ~= d.filters.hideMounted then
				fail(scenario, class .. ": a place rule was not put back")
			end
			if db.battle.speak ~= d.battle.speak then fail(scenario, class .. ": a battleground switch was not put back") end
			if db.prompt.thankNotInGroup ~= d.prompt.thankNotInGroup then
				fail(scenario, class .. ": the thank switch was not put back")
			end
			if class == "WARRIOR" then
				-- A warrior has class buffs, so what he says in a group is his to reset.
				if db.speech.quietInParty ~= d.speech.quietInParty or db.speech.quietInRaid ~= d.speech.quietInRaid then
					fail(scenario, "a warrior's speech switches were not put back")
				end
			else
				-- A rogue has nothing to give: the spoken line is an alt's on a shared profile.
				if db.speech.quietInParty ~= true or db.speech.quietInRaid ~= true then
					fail(scenario, "a rogue's reset put back speech he cannot see")
				end
			end
			local list = ns.OptionsPage.RESET.quiet
			for _, path in ipairs({ "filters.quietInTowns", "battle.items", "speech.quietInRaid", "prompt.thankNotInGroup" }) do
				local listed
				for _, p in ipairs(list or {}) do if p == path then listed = true end end
				if not listed then fail(scenario, "the list leaves out " .. path) end
			end
			for _, owner in ipairs({ "when", "click" }) do
				for _, p in ipairs(ns.OptionsPage.RESET[owner]) do
					if p == "speech.quietInParty" or p == "prompt.thankNotInGroup" or p == "filters.hideMounted" then
						fail(scenario, owner .. "'s list still holds " .. p)
					end
				end
			end
		end)
	end
end
