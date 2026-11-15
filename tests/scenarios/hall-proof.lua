-- The hall of fame's proof (HallProof.lua): the certificate a player takes a
-- screenshot of. With every milestone earned the favour ledger's Milestones
-- tab wears it beside the window: the name in class colour, the class and the
-- client, the day of the last milestone, the count, every milestone with its
-- date, the code in lines and the build. Start here's "Show my certificate"
-- opens the ledger on that tab. None of it before the last milestone, on
-- another tab or with milestones switched off.
--
-- Every scenario name starts with "hall-proof:" so the mutations in
-- tests/mutations/hall-proof.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

-- 2026-11-14 12:00 UTC.
local NOON = 1794657600
local DAY = 86400

-- The calendar as the client keeps it, in UTC (the mock's own date() answers
-- a clock time whatever is asked).
local function calendar()
	local real = date
	date = function(fmt, t) return os.date("!" .. fmt, t) end
	return function() date = real end
end

local function hidden(control)
	local v = control and control.hidden
	if type(v) == "function" then v = v() end
	return v == true
end

-- A session with a clean ledger and no milestone yet. opts.flavour,
-- opts.realm (what GetRealmName answers), opts.name (the character's).
local function session(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	if opts.name then Mock.playerName = opts.name end
	local restore = calendar()
	local realm = rawget(_G, "GetRealmName")
	rawset(_G, "GetRealmName", opts.realm and function() return opts.realm end or nil)
	local ns, list
	local ok, err = pcall(function()
		ns = load(scenario)
		if not ns then return end
		list = ns.HALL_OF_FAME
		ns.HALL_OF_FAME = {}
		H.freshPrompt(ns, scenario)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.db.char.ledger = nil
		ns.db.char.milestones = nil
		ns.Ledger.Load()
		Mock.epoch = NOON + 30 * DAY
		body(ns, ns.Hall)
		ns.Ledger.Hide()
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if ns then ns.HALL_OF_FAME = list end
	rawset(_G, "GetRealmName", realm)
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Every milestone this character can earn, three days apart, the last of them
-- at `last` and the oldest one marked as passed before milestones were kept;
-- `but` is left out. Answers how many there are and the oldest one's day.
local function earnAll(ns, last, but)
	local rows = ns.Milestones.Rows()
	local st = ns.db.char.milestones
	local oldest
	for i, row in ipairs(rows) do
		if row.id ~= but then
			local at = last - (i - 1) * 3 * DAY
			st.earned[row.id] = i == #rows and -at or at
			oldest = at
		end
	end
	return #rows, oldest
end

-- The certificate, when it is on screen.
local function certificate(ns)
	local window = ns.Ledger.Window()
	local c = window and window.certificate
	if c and window:IsShown() and c:IsShown() then return c, window end
	return nil, window
end

local function tab(window, key)
	for _, t in ipairs(window.tabs) do
		if t.key == key then t.scripts.OnClick(t) end
	end
end

local function said(fs)
	return tostring(fs and fs:IsShown() and fs:GetText() or "")
end

-- The code as the certificate shows it: its lines put together.
local function codeShown(c)
	local out, lines, widest = "", 0, 0
	for _, fs in ipairs(c.codeLines) do
		if fs:IsShown() then
			out = out .. tostring(fs:GetText() or "")
			lines = lines + 1
			widest = math.max(widest, #tostring(fs:GetText() or ""))
		end
	end
	return out, lines, widest
end

-- ------------------------------------------------------------------ when
do
	local scenario = "hall-proof: no certificate before the last milestone, on another tab or with milestones off"
	session(scenario, {}, function(ns, Hall)
		local button = H.findOption(ns.optionsTable, "hallCertificate")
		if not button then
			fail(scenario, "no Show my certificate on Start here")
			return
		end
		earnAll(ns, NOON, "courtesy")
		if Hall.Certificate() ~= nil then fail(scenario, "a certificate with a milestone to go") end
		if not hidden(button) then fail(scenario, "the button shows with a milestone to go") end
		Hall.ShowCertificate()
		local c, window = certificate(ns)
		if not (window and window:IsShown()) then
			fail(scenario, "SKIPPED -- the ledger did not open")
			return
		end
		if c then fail(scenario, "the certificate is drawn with a milestone to go") end

		ns.db.char.milestones.earned.courtesy = NOON + DAY
		ns.Ledger.Scroll(0)
		if not certificate(ns) then
			fail(scenario, "SKIPPED -- every milestone earned, no certificate on the Milestones tab")
			return
		end
		if hidden(button) then fail(scenario, "the button is hidden with every milestone earned") end
		-- Another tab: the certificate belongs to Milestones.
		tab(window, "all")
		if certificate(ns) then fail(scenario, "the certificate stays on the Everything tab") end
		tab(window, "milestones")
		if not certificate(ns) then fail(scenario, "back on Milestones, the certificate is gone") end
		-- Closed with the window.
		ns.Ledger.Hide()
		if certificate(ns) then fail(scenario, "the certificate outlives the window") end
		ns.Ledger.Show()
		if not certificate(ns) then fail(scenario, "the ledger opened again on Milestones without it") end
		-- Milestones off: gone, the button with it, and no facts to draw.
		local switch = H.findOption(ns.optionsTable, "milestones")
		switch.set(nil, false)
		ns.Ledger.Scroll(0)
		if certificate(ns) then fail(scenario, "the certificate shows with milestones switched off") end
		if Hall.Certificate() ~= nil then fail(scenario, "a certificate's facts with milestones switched off") end
		if not hidden(button) then fail(scenario, "the button shows with milestones switched off") end
		switch.set(nil, true)
		Hall.ShowCertificate()
		if not certificate(ns) then fail(scenario, "milestones back on, the certificate does not come back") end
	end)
end

-- ------------------------------------------------------------------ what
do
	local scenario = "hall-proof: the certificate names the character in class colour, the day, the count and the code the fold gives"
	session(scenario, {}, function(ns, Hall)
		local of, oldest = earnAll(ns, NOON + 2 * DAY)
		Hall.ShowCertificate()
		local c = certificate(ns)
		if not c then
			fail(scenario, "no certificate with every milestone earned")
			return
		end
		local L = ns.L
		local me = ns.UnitFullName("player")
		if said(c.heading) ~= L["Gentlefolk of Good Manners"] then
			fail(scenario, "the heading reads: " .. said(c.heading))
		end
		if said(c.name) ~= "|cff40c7eb" .. me .. "|r" then
			fail(scenario, "the name is not " .. me .. " in the mage's colour: " .. said(c.name))
		end
		if not (said(c.detail):find("Mage", 1, true) and said(c.detail):find(L["WoW Forever"], 1, true)) then
			fail(scenario, "the line under the name lacks the class or the client: " .. said(c.detail))
		end
		local day = os.date("!%Y-%m-%d", NOON + 2 * DAY)
		if said(c.date) ~= L["Every milestone earned on %s"]:format(day) then
			fail(scenario, "the date line is not the last milestone's day, " .. day .. ": " .. said(c.date))
		end
		if said(c.count) ~= L["%d of %d milestones"]:format(of, of) then
			fail(scenario, "the count is not " .. of .. " of " .. of .. ": " .. said(c.count))
		end
		-- The same code as the box on Start here, to the letter, on lines that fit.
		local box = H.findOption(ns.optionsTable, "hallCode")
		local code, lines, widest = codeShown(c)
		if code ~= Hall.Code() or code ~= box.get() then
			fail(scenario, "the certificate's code is " .. code .. ", the fold's " .. tostring(box.get()))
		end
		if lines < 2 or widest > 30 then
			fail(scenario, ("the code is on %d line(s), the longest of %d letters"):format(lines, widest))
		end
		-- The code says what the certificate says.
		local who = Hall.Decode(code)
		if not who or who.name ~= me or who.date ~= day:gsub("-", "") then
			fail(scenario, "the code does not read back as the certificate's name and day")
		end
		-- Every milestone with its date, the newest first, the one passed
		-- before milestones were kept dated too.
		local shown = 0
		for _, row in ipairs(c.rows) do
			if row.name:IsShown() then shown = shown + 1 end
		end
		if shown ~= of then fail(scenario, shown .. " milestones listed, not " .. of) end
		local first, last = c.rows[1], c.rows[of]
		if said(first.date) ~= day or said(first.name) == "" then
			fail(scenario, "the first row is not the newest milestone with its day: " .. said(first.name) .. " " .. said(first.date))
		end
		if last and said(last.date) ~= os.date("!%Y-%m-%d", oldest) then
			fail(scenario, "the oldest milestone's row is dated '" .. said(last.date) .. "'")
		end
		if not said(c.build):find(tostring(ns.BUILD), 1, true) or not said(c.build):find("Manners", 1, true) then
			fail(scenario, "the foot does not say which Manners: " .. said(c.build))
		end
		if said(c.hint) == "" then fail(scenario, "nothing says what to do with the picture") end
		if not (c:GetHeight() > 300 and c:GetWidth() > 250) then
			fail(scenario, ("the certificate is %s by %s"):format(tostring(c:GetWidth()), tostring(c:GetHeight())))
		end
	end)
end

-- ------------------------------------------------------------------ realms, long names
do
	local scenario = "hall-proof: a realm's character is named with its realm, and the longest code stays whole"
	session(scenario, { flavour = "vanilla", realm = "Pyrewood Village" }, function(ns, Hall)
		earnAll(ns, NOON)
		Hall.ShowCertificate()
		local c = certificate(ns)
		if not c then
			fail(scenario, "no certificate on Classic Era")
			return
		end
		if not said(c.name):find("-Pyrewood Village", 1, true) then
			fail(scenario, "the name does not carry the realm: " .. said(c.name))
		end
		if not said(c.detail):find(ns.L["Classic Era"], 1, true) then
			fail(scenario, "the client is not Classic Era: " .. said(c.detail))
		end
		if codeShown(c) ~= Hall.Code() then fail(scenario, "the code with a realm is not whole") end
	end)
	-- The longest a code gets: a name and a realm of forty-eight bytes.
	local long = ("Abcdefgh"):rep(6)
	session(scenario, { flavour = "vanilla", realm = long, name = { long, nil } }, function(ns, Hall)
		earnAll(ns, NOON)
		local code = Hall.Code()
		if not code or #code < 230 then
			fail(scenario, "SKIPPED -- no code of the longest kind: " .. tostring(code))
			return
		end
		Hall.ShowCertificate()
		local c = certificate(ns)
		if not c then
			fail(scenario, "no certificate for the longest name")
			return
		end
		local shown, lines = codeShown(c)
		if shown ~= code then
			fail(scenario, ("the longest code is cut: %d of its %d letters on %d lines"):format(#shown, #code, lines))
		end
	end)
end

-- ------------------------------------------------------------------ the lines
do
	local scenario = "hall-proof: the code's lines are of a length and put together are the code"
	session(scenario, {}, function(ns, Hall)
		local codes = {
			"MANNERS1-CAMELOT-MAGE-20261114-4D6F7274204465667265747465-0-DA8EF87D",
			"MANNERS1-VANILLA-PRIEST-20270102-5A6FC3AB-50797265776F6F642056696C6C616765-689BC8DC",
			"MANNERS1-TBC-MAGE-20261114-41-0-12345678",
			("X"):rep(95),
		}
		for _, code in ipairs(codes) do
			local lines = Hall.CodeLines(code, 30)
			if table.concat(lines) ~= code then
				fail(scenario, "the lines of " .. code .. " are not the code: " .. table.concat(lines, " / "))
			end
			local short
			for i, line in ipairs(lines) do
				if #line > 30 or #line == 0 then
					fail(scenario, "a line of " .. #line .. " letters: " .. line)
				end
				if i < #lines and #line < 12 then short = line end
			end
			if short then fail(scenario, "a line of a few letters in the middle of a code: " .. short) end
			if #lines > math.ceil(#code / 30) + 1 then
				fail(scenario, #lines .. " lines for a code of " .. #code .. " letters")
			end
		end
	end)
end

-- ------------------------------------------------------------------ the button
do
	local scenario = "hall-proof: Show my certificate opens the ledger on its Milestones tab"
	session(scenario, {}, function(ns, Hall)
		earnAll(ns, NOON)
		-- The ledger was last left on another tab, and is shut.
		ns.Ledger.Show()
		local window = ns.Ledger.Window()
		tab(window, "given")
		ns.Ledger.Hide()
		local button = H.findOption(ns.optionsTable, "hallCertificate")
		if not button or hidden(button) then
			fail(scenario, "no button with every milestone earned")
			return
		end
		button.func()
		if not window:IsShown() then
			fail(scenario, "the button did not open the ledger")
			return
		end
		local selected
		for _, t in ipairs(window.tabs) do
			if t.selected then selected = t.key end
		end
		if selected ~= "milestones" then fail(scenario, "the ledger opened on " .. tostring(selected)) end
		local top = window.rows[1].entry
		if not (top and top.milestone) then fail(scenario, "the rows are not the milestones") end
		if not certificate(ns) then fail(scenario, "the ledger opened without the certificate") end
		-- Opened as it always was, it keeps the tab it was left on.
		tab(window, "given")
		ns.Ledger.Hide()
		ns.Ledger.Show()
		for _, t in ipairs(window.tabs) do
			if t.selected and t.key ~= "given" then fail(scenario, "a plain open moved to " .. t.key) end
		end
		-- In the window: the button is drawn in the fold, above the code.
		ns.OpenOptions("general")
		local UI = ns.WindowUI
		local where = UI.Where("general.hallCertificate")
		if not (where and where.sec.key == "general.hall") then
			fail(scenario, "the button is not in the hall's fold")
		else
			UI.State().open["general.hall"] = true
			UI.Refresh()
			if not UI.RowShown("general.hallCertificate") then
				fail(scenario, "every milestone earned, the button is not drawn")
			end
		end
		ns.Prompt:ExitTest()
	end)
end

-- ------------------------------------------------------------------ the fold
do
	local scenario = "hall-proof: the fold asks for a screenshot of the certificate, before and after"
	session(scenario, {}, function(ns, Hall)
		local note = H.findOption(ns.optionsTable, "hallNote")
		local function text()
			local v = note.name
			if type(v) == "function" then v = v() end
			return tostring(v or "")
		end
		local of = earnAll(ns, NOON, "courtesy")
		local before = text()
		if not before:find(("%d of %d"):format(of - 1, of), 1, true) then
			fail(scenario, "SKIPPED -- the progress line holds no count: " .. before)
		end
		if before ~= Hall.TEXT.PROGRESS:format(of - 1, of) or not before:find("screenshot of your certificate", 1, true) then
			fail(scenario, "before the last milestone nothing says a screenshot will be the proof: " .. before)
		end
		ns.db.char.milestones.earned.courtesy = NOON + DAY
		local after = text()
		if after ~= Hall.TEXT.INVITE then fail(scenario, "SKIPPED -- the fold does not invite: " .. after) end
		for _, part in ipairs({ "Open your certificate", "Print Screen", "Screenshots folder",
			"Post the screenshot and the code", "github.com/fpsacha/Manners", "nothing of value is asked" }) do
			if not after:find(part, 1, true) then
				fail(scenario, "the invitation does not say: " .. part)
			end
		end
	end)
end

-- ------------------------------------------------------------------ the form and the clerk
do
	local scenario = "hall-proof: the form asks for the code and the screenshot, and the clerk keeps where the proof is"
	local function read(path)
		local f = io.open(dir .. "/" .. path, "r")
		local s = f and f:read("*a") or ""
		if f then f:close() end
		return s
	end
	Mock.reset()
	local ns = load(scenario)
	if ns then
		local form = read(".github/ISSUE_TEMPLATE/hall-of-fame.yml")
		local code = form:match("id: code\n(.-)\n  %- type") or ""
		local shot = form:match("  %- type: textarea\n    id: screenshot\n(.-)\n  %- type") or ""
		if not code:find("required: true", 1, true) then fail(scenario, "the form does not require the code") end
		if shot == "" then
			fail(scenario, "the form has no box to drag the screenshot into")
		else
			if not shot:find("required: true", 1, true) then fail(scenario, "the form does not require the screenshot") end
			if not shot:find("Drag", 1, true) then fail(scenario, "the form does not say to drag the picture in") end
		end
		local tool = read("tools/hall.py")
		if not tool:find('ap.add_argument("--proof"', 1, true) or not tool:find('fields["proof"] = ', 1, true) then
			fail(scenario, "tools/hall.py add keeps no record of the proof")
		end
		if tool:find('fields.append("proof', 1, true) or tool:find('e.get("proof") or ""', 1, true) then
			fail(scenario, "the proof goes out of hall.json")
		end
		if not tool:find("for line in checklist(fields, args.code):", 1, true) then
			fail(scenario, "tools/hall.py check prints no checklist for the screenshot")
		end
	end
	Mock.reset()
end
