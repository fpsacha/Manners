-- Report a bug (Options/BugReport.lua): one window that takes a player from
-- "something went wrong" to a link that opens the issue form on GitHub, filled
-- in, and the full check-up to paste into it. The link carries no name: not the
-- player's own, their realm, their guild, nor anybody the report knows. It stays
-- under 2000 characters. The report is cut to fit GitHub's limit, oldest first.
-- In a fight it is the short summary, since the full check-up waits.
--
-- Every name starts with "bugreport:" so the mutations in
-- tests/mutations/bugreport.py can name exactly one.

local dir, H = ...
local fail, load = H.fail, H.load

local function said() return table.concat(Mock.printed, "\n") end

-- EventRegistry as the addon uses it, as tests/scenarios/editmode.lua makes it.
local function Registry()
	local held = {}
	return {
		RegisterCallback = function(_, event, fn, owner)
			held[event] = held[event] or {}
			table.insert(held[event], { fn, owner })
		end,
		TriggerEvent = function(_, event, ...)
			for _, entry in ipairs(held[event] or {}) do entry[1](entry[2], ...) end
		end,
	}
end

local function open(ns)
	local BR = ns.BugReport
	BR.Show()
	return BR.Window()
end

local function choose(window, index)
	window.radios[index]:Click()
end

-- The window's six radio buttons, a words box, and Make the report pressed.
local function make(ns, index, words)
	local window = open(ns)
	choose(window, index or 1)
	window.words:SetText(words or "")
	window.make:Click()
	return window
end

local GUILD, REALM = "Silver Hand", "Stormbind"

local function with(scenario, body, opts)
	opts = opts or {}
	Mock.reset()
	local registry = Registry()
	local realRegistry = rawget(_G, "EventRegistry")
	local realRealm, realGuild = rawget(_G, "GetRealmName"), rawget(_G, "GetGuildInfo")
	_G.EventRegistry = registry
	_G.GetRealmName = function() return REALM end
	_G.GetGuildInfo = function() return GUILD, "Rank", 1 end
	local restore = H.strangers({ nameplate1 = { "Anna", "Aim" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		Mock.printed = {}
		body(ns, registry)
		for _, e in ipairs(ns.errors or {}) do
			if not (opts.errorsOk and e.where:find("^boom")) then
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end
	end)
	Mock.inCombat = false
	Mock.modifiers = {}
	restore()
	_G.EventRegistry, _G.GetRealmName, _G.GetGuildInfo = realRegistry, realRealm, realGuild
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Whether a string of bytes is well-formed UTF-8.
local function utf8ok(s)
	local i = 1
	while i <= #s do
		local b = s:byte(i)
		local n = b < 128 and 0 or (b >= 240 and 3) or (b >= 224 and 2) or (b >= 194 and 1) or nil
		if n == nil then return false end
		for k = 1, n do
			local c = s:byte(i + k)
			if not c or c < 128 or c > 191 then return false end
		end
		i = i + n + 1
	end
	return true
end

local function decode(s)
	return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

do
	local scenario = "bugreport: the link is percent-encoded and names nobody"
	with(scenario, function(ns)
		H.owe(ns, "Anna Aim")
		ns.addon:Tick()
		ns.Trail("favour", "Corvin buffed you", "Corvin")
		local words = "Mort and Corvin and Anna Aim in " .. REALM .. " with " .. GUILD .. " got no prompt"
		local window = make(ns, 2, words)
		local url = window.boxA:GetText()
		if url:sub(1, #ns.BugReport.ISSUE) ~= ns.BugReport.ISSUE then
			fail(scenario, "the link does not open the issue form: " .. url)
		end
		for _, raw in ipairs({ "Mort", "Corvin", "Anna", "Aim", REALM, "Silver", "Hand" }) do
			if url:find(raw, 1, true) then fail(scenario, raw .. " is in the link: " .. url) end
		end
		if url:find(" ", 1, true) then fail(scenario, "a space is raw in the link: " .. url) end
		if not url:find("%20", 1, true) then fail(scenario, "the spaces are not %20 in the link: " .. url) end
		local what = decode(url):match("what=([^&]*)") or ""
		for _, want in ipairs({ "(me)", "(realm)", "(guild)", "Person" }) do
			if not what:find(want, 1, true) then fail(scenario, "the words in the link have no " .. want .. ": " .. what) end
		end
		for _, want in ipairs({ "template=bug_report.yml", "category=", "class=", "version=", "game=" }) do
			if not url:find(want, 1, true) then fail(scenario, "the link has no " .. want) end
		end
		-- The report's own line of their words is scrubbed too.
		local text = window.boxB:GetText()
		local line = text:match("In their words: ([^\n]*)") or ""
		for _, raw in ipairs({ "Mort", "Corvin", "Anna", REALM, "Silver" }) do
			if line:find(raw, 1, true) then fail(scenario, raw .. " is in the report's words line: " .. line) end
		end
	end)
end

do
	-- The full report cannot run in a fight, but a name typed in the words is
	-- still no part of the link or the summary: the group's names are read from
	-- the unit tokens.
	local scenario = "bugreport: in a fight a group member's name leaves the link and the summary"
	with(scenario, function(ns)
		Mock.groupSize = 2
		Mock.unitNames = { party1 = { "Petra", "Stonewell" } }
		local window = open(ns)
		choose(window, 1)
		window.words:SetText("Petra Stonewell never got Fortitude")
		Mock.inCombat = true
		window.make:Click()
		window.shortBtn:Click()
		local url = window.boxA:GetText()
		local text = window.boxB:GetText()
		if url:find("Petra", 1, true) or url:find("Stonewell", 1, true) then
			fail(scenario, "a group member's name is in the link: " .. url)
		end
		if not decode(url):find("Person", 1, true) then fail(scenario, "the link has no alias: " .. decode(url)) end
		local line = text:match("In their words: ([^\n]*)") or ""
		if line:find("Petra", 1, true) or line:find("Stonewell", 1, true) then
			fail(scenario, "a group member's name is in the summary's words: " .. line)
		end
		Mock.groupSize = 0
		Mock.unitNames = nil
	end)
end

do
	local scenario = "bugreport: the link stays under 2000 characters"
	with(scenario, function(ns)
		local words = string.rep("\195\169", 300)
		local window = make(ns, 6, words)
		local url = window.boxA:GetText()
		if #url > 2000 then fail(scenario, "the link is " .. #url .. " characters") end
		if not utf8ok(decode(url)) then fail(scenario, "the link holds a broken UTF-8 letter") end
		if not url:find("what=Something%20else", 1, true) then fail(scenario, "the category left the link: " .. url) end
		-- The box itself holds 300 letters; the link is held to 2000 whatever is handed in.
		local long = ns.BugReport.URL("other", string.rep("\195\169", 600) .. " end", nil)
		if #long > 2000 then fail(scenario, "a long note makes a link of " .. #long .. " characters") end
		if not utf8ok(decode(long)) then fail(scenario, "a long note leaves a broken UTF-8 letter in the link") end
		if not long:find("template=bug_report.yml", 1, true) then fail(scenario, "a long note lost the form from the link") end
		-- A short note goes in whole.
		local short = ns.BugReport.URL("other", "it broke", nil)
		if not decode(short):find("Something else: it broke", 1, true) then
			fail(scenario, "a short note is not in the link: " .. short)
		end
		-- The cut never lands inside a letter.
		local cut = ns.BugReport.CutUTF8("a\195\169b", 2)
		if cut ~= "a" then fail(scenario, "CutUTF8 cut inside a letter: " .. cut:gsub(".", function(c) return ("%02x"):format(c:byte()) end)) end
	end)
end

do
	local scenario = "bugreport: the report starts with the category and the words"
	with(scenario, function(ns)
		local window = make(ns, 1, "nothing at all")
		local text = window.boxB:GetText()
		local lines = {}
		for line in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
		if lines[2] ~= "What went wrong: The prompt never showed up" then fail(scenario, "line 2 is " .. tostring(lines[2])) end
		if lines[3] ~= "In their words: nothing at all" then fail(scenario, "line 3 is " .. tostring(lines[3])) end
		if lines[4] ~= "Marks in the trail: 0" then fail(scenario, "line 4 is " .. tostring(lines[4])) end
		if not text:find("== Self-test ==", 1, true) then fail(scenario, "the full check-up is not in the box") end
		local none = make(ns, 1, "")
		if not none.boxB:GetText():find("In their words: (none)", 1, true) then
			fail(scenario, "no words is not said as (none)")
		end
		if not none.marksNote:GetText():find("No marks in this report", 1, true) then
			fail(scenario, "a report with no marks does not say so: " .. tostring(none.marksNote:GetText()))
		end
	end)
end

do
	local scenario = "bugreport: a report over the cap loses its oldest trail lines and says so"
	with(scenario, function(ns)
		local trail = {}
		for i = 1, 300 do
			trail[i] = { at = time(), kind = "test", text = ("entry-%03d "):format(i) .. string.rep("x", 290) }
		end
		ns.db.char.trail = trail
		local window = make(ns, 1, "too much")
		local text = window.boxB:GetText()
		if #text > ns.BugReport.CAP then fail(scenario, "the report is " .. #text .. " characters") end
		if not text:find("entry-300", 1, true) then fail(scenario, "the newest trail line was cut") end
		if text:find("entry-001", 1, true) then fail(scenario, "the oldest trail line was kept") end
		if not text:find("were left out to fit GitHub's limit", 1, true) then fail(scenario, "the report does not say it was cut") end
		if not window.cutNote:IsShown() then fail(scenario, "the window does not say the report was cut") end
		-- Under the cap nothing is cut.
		ns.db.char.trail = {}
		local small = make(ns, 1, "fine")
		if small.cutNote:IsShown() then fail(scenario, "a short report claims it was cut") end
		if small.boxB:GetText():find("were left out to fit", 1, true) then fail(scenario, "a short report has the left-out note") end
	end)
end

do
	local scenario = "bugreport: in a fight the full report waits and the summary is offered"
	with(scenario, function(ns)
		local runs = 0
		local real = ns.FullReport
		ns.FullReport = function(...) runs = runs + 1 return real(...) end
		local window = open(ns)
		choose(window, 3)
		window.words:SetText("the cure did not show")
		Mock.inCombat = true
		window.make:Click()
		if runs ~= 0 then fail(scenario, "the full report ran in a fight") end
		if (window.boxB:GetText() or "") ~= "" or (window.boxA:GetText() or "") ~= "" then fail(scenario, "a box was written to in a fight") end
		if not window.waitNote:IsShown() then fail(scenario, "no word that the full report waits") end
		if window.waitNote:GetText() ~= "The full report waits for the fight to end. The short summary works now." then
			fail(scenario, "the wait note says: " .. tostring(window.waitNote:GetText()))
		end
		if not window.shortBtn:IsShown() then fail(scenario, "the short summary is not offered") end
		window.shortBtn:Click()
		if runs ~= 0 then fail(scenario, "the short summary ran the full report") end
		local text = window.boxB:GetText()
		if not text:find("What went wrong: A fight button", 1, true) or not text:find("In their words: the cure did not show", 1, true) then
			fail(scenario, "the short summary lacks the category or the words: " .. text:sub(1, 200))
		end
		if not text:find("Manners " .. tostring(ns.BUILD), 1, true) then fail(scenario, "the short summary is not in the box") end
		if not window.boxA:GetText():find("template=bug_report.yml", 1, true) then fail(scenario, "the link is not given in a fight") end
		-- The fight over, the full report is made.
		Mock.inCombat = false
		window.make:Click()
		if runs ~= 1 then fail(scenario, "the full report did not run after the fight") end
	end)
end

do
	local scenario = "bugreport: Select all highlights and focuses, Ctrl+C shows Copied"
	with(scenario, function(ns)
		local window = make(ns, 1, "x")
		for _, name in ipairs({ "boxA", "boxB" }) do
			local box = window[name]
			box.select:Click()
			if Mock.focus ~= box then fail(scenario, name .. ": Select all did not focus the box") end
			if not box._highlight then fail(scenario, name .. ": Select all did not highlight the text") end
			if not box.hint:IsShown() then fail(scenario, name .. ": no hint to press Ctrl+C") end
			-- A plain C shows nothing; Ctrl+C shows Copied for three seconds.
			Mock.fire(box, "OnKeyDown", "C")
			if box.copied:IsShown() then fail(scenario, name .. ": Copied showed without Ctrl") end
			Mock.modifiers = { ctrl = true }
			Mock.fire(box, "OnKeyDown", "C")
			if not box.copied:IsShown() then fail(scenario, name .. ": Ctrl+C did not show Copied") end
			Mock.runTimers(3.1)
			if box.copied:IsShown() then fail(scenario, name .. ": Copied stayed on") end
			Mock.modifiers = {}
			-- Read-only: typing is put back.
			local held = box.fixed
			box:SetText("typed over")
			Mock.fire(box, "OnTextChanged", true)
			if box:GetText() ~= held then fail(scenario, name .. ": the box can be typed in") end
		end
	end)
end

do
	local scenario = "bugreport: every entry point opens the window"
	-- A context menu as ease.lua fakes one.
	local function fakeDescription(text, fn)
		local d = { text = text, fn = fn, items = {} }
		function d:CreateTitle() end
		function d:CreateDivider() end
		function d:CreateButton(t, f)
			local child = fakeDescription(t, f)
			self.items[#self.items + 1] = child
			return child
		end
		return d
	end
	local function find(root, pattern)
		for _, item in ipairs(root.items) do
			if item.text and item.text:find(pattern) then return item end
			local inner = find(item, pattern)
			if inner then return inner end
		end
	end
	local realMenu = MenuUtil
	local opened
	MenuUtil = {
		CreateContextMenu = function(owner, generator)
			local root = fakeDescription()
			generator(owner, root)
			opened = root
			return root
		end,
	}
	with(scenario, function(ns)
		local function shown() local w = ns.BugReport.Window() return w and w:IsShown() end
		local function close() local w = ns.BugReport.Window() if w then w:Hide() end end
		local function expect(how)
			if not shown() then fail(scenario, how .. " did not open the window") end
			close()
		end

		-- The minimap menu.
		local broker = Mock.broker
		if not (broker and broker.OnClick) then
			fail(scenario, "no launcher was registered")
		else
			opened = nil
			broker.OnClick({}, "RightButton")
			local entry = opened and find(opened, "^Report a bug$")
			if not entry then
				fail(scenario, "the minimap menu has no Report a bug")
			else
				entry.fn()
				expect("the minimap menu's entry")
			end
			local mark = opened and find(opened, "^Mark this moment$")
			if not mark then
				fail(scenario, "the minimap menu has no Mark this moment")
			else
				mark.fn()
				local n = 0
				for _, t in ipairs(ns.db.char.trail) do if t.kind == "MARK" then n = n + 1 end end
				if n == 0 then fail(scenario, "the menu's Mark this moment marked nothing") end
			end
		end

		-- The footer button of the options window.
		ns.OpenOptions("general")
		local footer = ns.WindowUI and ns.WindowUI.footer
		if not (footer and footer.bug) then
			fail(scenario, "the options window has no Report a bug button in its footer")
		else
			footer.bug:Click()
			expect("the footer button")
		end

		-- Diagnostics' button, and where the layout draws it.
		local item = H.findOption(ns.optionsTable, "reportBug")
		if not item then
			fail(scenario, "Diagnostics has no Report a bug button")
		else
			item.func()
			expect("the Diagnostics button")
		end
		if H.layoutInToc() then
			if H.placedOn(ns, "diagnostics.reportBug") ~= "diagnostics" then
				fail(scenario, "the Report a bug button is not placed on Diagnostics")
			end
			if H.placedOn(ns, "diagnostics.markKey") ~= "diagnostics" then
				fail(scenario, "the Mark this moment key is not placed on Diagnostics")
			end
		end

		-- The slash commands.
		ns.addon:HandleSlash("bug")
		expect("/manners bug")
		ns.addon:HandleSlash("report")
		expect("/manners report")
	end)
	MenuUtil = realMenu
end

do
	local scenario = "bugreport: a new error offers Report it once a session, and the link opens the window"
	with(scenario, function(ns, registry)
		local function offers()
			local _, n = said():gsub("Haddon:Manners:report", "")
			return n
		end
		ns.Guard("boom one", function() error("first") end)
		if offers() ~= 1 then fail(scenario, "the first error offered the link " .. offers() .. " times") end
		if not said():find("Report it", 1, true) then fail(scenario, "the offer does not say Report it") end
		ns.Guard("boom two", function() error("second") end)
		if offers() ~= 1 then fail(scenario, "a second error offered the link again") end
		-- The link opens the window; another link does not.
		local function up() local w = ns.BugReport.Window() return w and w:IsShown() end
		if up() then ns.BugReport.Window():Hide() end
		registry:TriggerEvent("SetItemRef", "addon:Manners:other", "x", "LeftButton")
		if up() then fail(scenario, "another link opened the window") end
		registry:TriggerEvent("SetItemRef", "addon:Manners:report", "[Report it]", "LeftButton")
		if not up() then
			fail(scenario, "the link did not open the window")
		end
	end, { errorsOk = true })

	with(scenario, function(ns)
		Mock.inCombat = true
		ns.Guard("boom fight", function() error("in a fight") end)
		if said():find("Haddon:Manners:report", 1, true) then fail(scenario, "the link was offered in a fight") end
		Mock.inCombat = false
		Mock.frameEvent("PLAYER_REGEN_ENABLED")
		if not said():find("Haddon:Manners:report", 1, true) then fail(scenario, "the link was not offered when the fight ended") end
	end, { errorsOk = true })
end

do
	local scenario = "bugreport: the link's game and category match the issue form"
	with(scenario, function(ns)
		local f = io.open(dir .. "/.github/ISSUE_TEMPLATE/bug_report.yml", "r")
		if not f then
			fail(scenario, "the issue form could not be read")
			return
		end
		local yml = f:read("*a")
		f:close()
		local function options(id)
			local block = yml:match("id: " .. id .. "\n.-options:\n(.-)\n    validations")
			local out = {}
			for line in (block or ""):gmatch("        %- ([^\n]+)") do out[#out + 1] = line end
			return out
		end
		local function has(list, want)
			for _, v in ipairs(list) do if v == want then return true end end
			return false
		end
		local games, cats = options("game"), options("category")
		local count = 0
		for flavour, name in pairs(ns.BugReport.GAMES) do
			count = count + 1
			if not has(games, name) then fail(scenario, flavour .. "'s " .. name .. " is not a Game option in the form") end
		end
		if count ~= #games then fail(scenario, "the form lists " .. #games .. " games, the link knows " .. count) end
		if #cats ~= #ns.BugReport.CATEGORIES then fail(scenario, "the form lists " .. #cats .. " categories") end
		for i, c in ipairs(ns.BugReport.CATEGORIES) do
			if cats[i] ~= c.en then fail(scenario, "category " .. i .. " differs: " .. c.en .. " / " .. tostring(cats[i])) end
		end
		if not yml:find("Report a bug", 1, true) then fail(scenario, "the form does not point at Report a bug") end
		for flavour in pairs(ns.BugReport.GAMES) do
			if flavour == "" then fail(scenario, "unreachable") end
		end
	end)
end
