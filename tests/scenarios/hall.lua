-- The hall of fame, "Gentlefolk of Good Manners" (Hall.lua, HallOfFame.lua,
-- tools/hall.py). A character with every milestone it can earn is shown a code
-- on Start here to post on the addon's GitHub page; before that the section
-- says how far along it is; under both is the list as shipped, the player's
-- own name marked. All of it hidden while milestones are switched off.
--
-- The code's arithmetic lives twice, in Hall.lua and in tools/hall.py: the
-- first scenario reads the codes tools/hall.py is held to (its VECTORS, which
-- `python tools/hall.py --check` verifies there) and holds Hall.lua to them.
--
-- Every scenario name starts with "hall:" so the mutations in
-- tests/mutations/hall.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

-- 2026-11-14 12:00 UTC, and a day later.
local NOON = 1794657600
local DAY = 86400

-- The calendar as the client keeps it, in UTC so a test reads the same
-- everywhere (the mock's own date() answers a clock time whatever is asked).
local function calendar()
	local real = date
	date = function(fmt, t) return os.date("!" .. fmt, t) end
	return function() date = real end
end

local function text(control, field)
	local v = control and control[field]
	if type(v) == "function" then v = v() end
	return tostring(v or "")
end

local function hidden(control)
	local v = control and control.hidden
	if type(v) == "function" then v = v() end
	return v == true
end

-- A session with a clean ledger and no milestone yet. opts.flavour, opts.class,
-- opts.realm (what GetRealmName answers), opts.list (the hall as shipped).
local function session(scenario, opts, body)
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	if opts.class then Mock.class = opts.class end
	local restore = calendar()
	local realm = rawget(_G, "GetRealmName")
	rawset(_G, "GetRealmName", opts.realm and function() return opts.realm end or nil)
	local ns, list
	local ok, err = pcall(function()
		ns = load(scenario)
		if not ns then return end
		list = ns.HALL_OF_FAME
		ns.HALL_OF_FAME = opts.list or {}
		H.freshPrompt(ns, scenario)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.db.char.ledger = nil
		ns.db.char.milestones = nil
		ns.Ledger.Load()
		Mock.printed = {}
		body(ns, ns.Hall)
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

-- Every milestone this character can earn, marked earned a minute apart, the
-- last of them at `last`; `but` is left out.
local function earnAll(ns, last, but)
	local rows = ns.Milestones.Rows()
	local st = ns.db.char.milestones
	for i, row in ipairs(rows) do
		if row.id ~= but then st.earned[row.id] = last - (#rows - i) * 60 end
	end
	return #rows
end

local function printed(line)
	local n = 0
	for _, said in ipairs(Mock.printed or {}) do
		if tostring(said):find(line, 1, true) then n = n + 1 end
	end
	return n
end

-- ------------------------------------------------------------------ the code
do
	local scenario = "hall: a code round-trips, a two-word and an accented name too, and tools/hall.py agrees"
	session(scenario, {}, function(ns, Hall)
		local ZOE = "Zo\195\171"
		local cases = {
			{ name = "Mort Defrette", realm = "", client = "camelot", class = "MAGE", date = "20261114" },
			{ name = ZOE, realm = "Pyrewood Village", client = "vanilla", class = "PRIEST", date = "20270102" },
			{ name = "\195\137lo\195\175se d'Or", realm = "", client = "camelot", class = "DEATHKNIGHT", date = "20261231" },
		}
		local made = {}
		for _, who in ipairs(cases) do
			local code = Hall.Encode(who)
			if type(code) ~= "string" then
				fail(scenario, "no code for " .. who.name)
			else
				made[code] = true
				if not code:find("^MANNERS1%-[%u%d%-]+$") then
					fail(scenario, "a code that is not capitals, digits and dashes: " .. code)
				end
				local back, why = Hall.Decode(code)
				if not back then
					fail(scenario, who.name .. ": its own code does not read (" .. tostring(why) .. ")")
				else
					for _, field in ipairs({ "name", "realm", "client", "class", "date" }) do
						if back[field] ~= who[field] then
							fail(scenario, ("%s: %s came back as %s"):format(who.name, field, tostring(back[field])))
						end
					end
				end
			end
		end
		-- The codes tools/hall.py is held to: Hall.lua reads each and makes
		-- the same one again from what it read.
		local f = io.open(dir .. "/tools/hall.py", "r")
		local source = f and f:read("*a") or ""
		if f then f:close() end
		local vectors = source:match("VECTORS = %[(.-)\n%]") or ""
		local n = 0
		for code in vectors:gmatch('"(MANNERS1%-[%w%-]+)"') do
			n = n + 1
			local back, why = Hall.Decode(code)
			if not back then
				fail(scenario, "tools/hall.py's " .. code .. " does not read here (" .. tostring(why) .. ")")
			elseif Hall.Encode(back) ~= code then
				fail(scenario, "tools/hall.py's " .. code .. " is made here as " .. tostring(Hall.Encode(back)))
			end
			if n <= 2 and not made[code] then
				fail(scenario, "tools/hall.py's " .. code .. " is not the code made here for the same player")
			end
		end
		if n < 2 then fail(scenario, "SKIPPED -- tools/hall.py holds " .. n .. " code(s) to check against") end
		-- What a code cannot carry is no code.
		if Hall.Encode({ name = "", client = "camelot", class = "MAGE", date = "20261114" }) then
			fail(scenario, "a code with no name")
		end
		if Hall.Encode({ name = ("x"):rep(60), client = "camelot", class = "MAGE", date = "20261114" }) then
			fail(scenario, "a code with a name of sixty letters")
		end
		if Hall.Encode({ name = "Mort", client = "camelot", class = "MAGE", date = "12:00:00" }) then
			fail(scenario, "a code with no day")
		end
	end)
end

do
	local scenario = "hall: a changed character fails the checksum"
	session(scenario, {}, function(ns, Hall)
		local code = Hall.Encode({ name = "Mort Defrette", realm = "", client = "camelot", class = "MAGE", date = "20261114" })
		if not (code and Hall.Decode(code)) then
			fail(scenario, "SKIPPED -- the code does not read to begin with")
			return
		end
		-- Every character after the prefix, changed for its neighbour.
		for i = #"MANNERS1-" + 1, #code do
			local c = code:sub(i, i)
			if c ~= "-" then
				local other = c == "9" and "8" or c == "F" and "E" or c == "Z" and "Y" or string.char(c:byte() + 1)
				local bent = code:sub(1, i - 1) .. other .. code:sub(i + 1)
				local back, why = Hall.Decode(bent)
				if back then
					fail(scenario, ("character %d changed from %s to %s and the code still reads"):format(i, c, other))
					break
				elseif why ~= "checksum" and why ~= "shape" then
					fail(scenario, "a bent code is refused for " .. tostring(why))
				end
			end
		end
		-- Two characters swapped.
		local swapped = code:gsub("4D6F", "6F4D", 1)
		if Hall.Decode(swapped) then fail(scenario, "two letters of the name swapped and the code still reads") end
		local _, why = Hall.Decode(swapped)
		if why ~= "checksum" then fail(scenario, "a swap is refused as " .. tostring(why) .. ", not the checksum") end
		-- A paste is forgiven its case and its line breaks; other text is no code.
		if not Hall.Decode("  " .. code:sub(1, 30):lower() .. "\n" .. code:sub(31) .. " ") then
			fail(scenario, "a code pasted in lower case over two lines does not read")
		end
		local _, shape = Hall.Decode("hello")
		if shape ~= "shape" then fail(scenario, "text that is no code is refused as " .. tostring(shape)) end
	end)
end

-- ------------------------------------------------------------------ before
do
	local scenario = "hall: before every milestone is earned the section says how many, and there is no code"
	session(scenario, {}, function(ns, Hall)
		local note = H.findOption(ns.optionsTable, "hallNote")
		local box = H.findOption(ns.optionsTable, "hallCode")
		local list = H.findOption(ns.optionsTable, "hallList")
		if not (note and box and list) then
			fail(scenario, "the hall of fame is not on Start here")
			return
		end
		local of = earnAll(ns, NOON, "first")
		local earned, total, done = Hall.Progress()
		if earned ~= of - 1 or total ~= of or done then
			fail(scenario, ("with one to go the hall reads %s of %s, done %s"):format(tostring(earned), tostring(total), tostring(done)))
		end
		if Hall.Code() ~= nil then fail(scenario, "a code with a milestone still to earn: " .. tostring(Hall.Code())) end
		if not hidden(box) then fail(scenario, "the code box shows with a milestone still to earn") end
		if box.get() ~= "" then fail(scenario, "the hidden box holds " .. tostring(box.get())) end
		local want = Hall.TEXT.PROGRESS:format(of - 1, of)
		if text(note, "name") ~= want then
			fail(scenario, "the section does not say how many are earned: " .. text(note, "name"))
		end
		if not want:find(("%d of %d"):format(of - 1, of), 1, true) then
			fail(scenario, "SKIPPED -- the progress line holds no count")
		end
		if hidden(note) or hidden(list) then fail(scenario, "the section hides before the hall opens") end
		if printed(Hall.TEXT.OPEN) ~= 0 then fail(scenario, "the hall was announced with a milestone to go") end
	end)
end

-- ------------------------------------------------------------------ complete
do
	local scenario = "hall: every milestone earned, the code is this character's, dated the last one, in a box that only copies"
	session(scenario, {}, function(ns, Hall)
		earnAll(ns, NOON + DAY, "courtesy")
		-- The last, through its own path: the hall says so once in chat.
		Mock.epoch = NOON + 3 * DAY
		ns.Milestones.Note("courtesy")
		local _, _, done = Hall.Progress()
		if not done then
			fail(scenario, "SKIPPED -- a mage's last milestone did not land")
			return
		end
		if printed(Hall.TEXT.OPEN) ~= 1 then
			fail(scenario, "the last milestone said the hall is open " .. printed(Hall.TEXT.OPEN) .. " times")
		end
		local code = Hall.Code()
		local who = code and Hall.Decode(code)
		if not who then
			fail(scenario, "no code with every milestone earned: " .. tostring(code))
			return
		end
		if who.name ~= ns.UnitFullName("player") or not who.name:find(" ", 1, true) then
			fail(scenario, "the code names " .. tostring(who.name) .. ", not the two words of " .. tostring(ns.UnitFullName("player")))
		end
		if who.class ~= "MAGE" or who.client ~= "camelot" or who.realm ~= "" then
			fail(scenario, ("the code says %s on %s, realm '%s'"):format(who.class, who.client, who.realm))
		end
		if who.date ~= os.date("!%Y%m%d", NOON + 3 * DAY) then
			fail(scenario, "the code is dated " .. who.date .. ", not the day of the last milestone")
		end
		local note = H.findOption(ns.optionsTable, "hallNote")
		local box = H.findOption(ns.optionsTable, "hallCode")
		if hidden(box) then fail(scenario, "the code box is hidden with every milestone earned") end
		if box.get() ~= code then fail(scenario, "the box holds " .. tostring(box.get())) end
		box.set(nil, "MANNERS1-SOMETHING-ELSE")
		if box.get() ~= code then fail(scenario, "typing in the box changed the code") end
		if text(note, "name") ~= Hall.TEXT.INVITE then
			fail(scenario, "the section does not invite: " .. text(note, "name"))
		end
		-- Earning nothing new says nothing again.
		ns.Milestones.Note("courtesy")
		if printed(Hall.TEXT.OPEN) ~= 1 then fail(scenario, "the hall was announced a second time") end
	end)
end

do
	local scenario = "hall: a client with realms puts the realm in the code, Forever does not"
	session(scenario, { flavour = "vanilla", realm = "Pyrewood Village" }, function(ns, Hall)
		earnAll(ns, NOON)
		local who = Hall.Code() and Hall.Decode(Hall.Code())
		if not who then
			fail(scenario, "no code on Classic Era")
		elseif who.realm ~= "Pyrewood Village" or who.client ~= "vanilla" then
			fail(scenario, ("Classic Era's code says realm '%s' on %s"):format(who.realm, who.client))
		end
	end)
	session(scenario, { realm = "Somewhere" }, function(ns, Hall)
		earnAll(ns, NOON)
		local who = Hall.Code() and Hall.Decode(Hall.Code())
		if not who then
			fail(scenario, "no code on Forever")
		elseif who.realm ~= "" then
			fail(scenario, "Forever's code carries a realm: " .. who.realm)
		end
	end)
end

-- ------------------------------------------------------------------ off
do
	local scenario = "hall: hidden with milestones switched off"
	session(scenario, {}, function(ns, Hall)
		earnAll(ns, NOON)
		local controls = {}
		for _, key in ipairs({ "hallHeader", "hallNote", "hallCode", "hallList" }) do
			controls[key] = H.findOption(ns.optionsTable, key)
			if not controls[key] then
				fail(scenario, "no " .. key .. " on Start here")
				return
			end
			if hidden(controls[key]) then fail(scenario, "SKIPPED -- " .. key .. " is hidden with milestones on") end
		end
		local switch = H.findOption(ns.optionsTable, "milestones")
		switch.set(nil, false)
		for key, control in pairs(controls) do
			if not hidden(control) then fail(scenario, key .. " shows with milestones switched off") end
		end
		switch.set(nil, true)
		for key, control in pairs(controls) do
			if hidden(control) then fail(scenario, key .. " stays hidden with milestones back on") end
		end
	end)
end

-- ------------------------------------------------------------------ the list
do
	local scenario = "hall: the list is newest first in class colours, marks your own name, and says when nobody is listed"
	local LIST = {
		{ name = "Petra Stonewell", client = "camelot", class = "PRIEST", date = "2026-11-20" },
		{ name = "Mort Defrette", client = "camelot", class = "MAGE", date = "2026-12-01" },
		{ name = "Anna", realm = "Pyrewood Village", client = "vanilla", class = "MAGE", date = "2026-11-25" },
		-- The same name on another client is somebody else, of the same class
		-- too (another class is somebody else by that alone).
		{ name = "Mort Defrette", client = "tbc", class = "MAGE", date = "2026-11-01" },
	}
	session(scenario, { list = LIST }, function(ns, Hall)
		local list = H.findOption(ns.optionsTable, "hallList")
		local shown = text(list, "name")
		local lines = {}
		for line in (shown .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
		if lines[1] ~= Hall.TEXT.HEAD or #lines ~= 5 then
			fail(scenario, "the list is not a heading and four names: " .. shown)
			return
		end
		local order = { "Mort Defrette", "Anna%-Pyrewood Village", "Petra Stonewell", "Mort Defrette" }
		for i, name in ipairs(order) do
			if not lines[i + 1]:find(name) then
				fail(scenario, ("line %d is not %s: %s"):format(i, name, lines[i + 1]))
			end
		end
		if not lines[2]:find("|cff40c7ebMort Defrette|r", 1, true) then
			fail(scenario, "a mage is not in the mage's colour: " .. lines[2])
		end
		if not lines[4]:find("|cffffffffPetra Stonewell|r", 1, true) then
			fail(scenario, "a priest is not in the priest's colour: " .. lines[4])
		end
		if not (lines[2]:find("2026-12-01", 1, true) and lines[2]:find(ns.L["WoW Forever"], 1, true)) then
			fail(scenario, "a line lacks its client or its date: " .. lines[2])
		end
		if not lines[3]:find(ns.L["Classic Era"], 1, true) then
			fail(scenario, "a Classic Era player's line does not say so: " .. lines[3])
		end
		local mark = Hall.TEXT.YOU:match("%%s%s*(.+)$")
		if not lines[2]:find(mark, 1, true) then fail(scenario, "your own name is not marked: " .. lines[2]) end
		for i = 3, 5 do
			if lines[i]:find(mark, 1, true) then fail(scenario, "somebody else is marked as you: " .. lines[i]) end
		end
		-- Listed: the section thanks, invites no more, and the last milestone
		-- says nothing about a place already taken.
		earnAll(ns, NOON, "courtesy")
		ns.Milestones.Note("courtesy")
		if text(H.findOption(ns.optionsTable, "hallNote"), "name") ~= Hall.TEXT.LISTED then
			fail(scenario, "somebody listed is still invited")
		end
		if printed(Hall.TEXT.OPEN) ~= 0 then fail(scenario, "somebody listed was told the hall is open") end
		-- More than the window lists: the rest are counted.
		local many = {}
		for i = 1, Hall.MAX_ROWS + 3 do
			many[i] = { name = "Guest " .. i, client = "camelot", class = "MAGE", date = "2026-11-10" }
		end
		ns.HALL_OF_FAME = many
		local long = text(list, "name")
		if not long:find(Hall.TEXT.MORE:format(3), 1, true) or long:find("Guest " .. (Hall.MAX_ROWS + 1), 1, true) then
			fail(scenario, "a long list is not cut at " .. Hall.MAX_ROWS .. " with the rest counted")
		end
		-- Nobody: the first place is open.
		ns.HALL_OF_FAME = {}
		if text(list, "name") ~= Hall.TEXT.EMPTY then
			fail(scenario, "an empty hall reads: " .. text(list, "name"))
		end
		if Hall.TEXT.EMPTY ~= ns.L["Nobody is listed yet. The first place is open."] then
			fail(scenario, "the empty hall does not say the first place is open")
		end
	end)
end

-- ------------------------------------------------------------------ as shipped
do
	local scenario = "hall: the shipped list is a list the addon can draw, generated from tools/hall.json"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		local list = ns.HALL_OF_FAME
		if type(list) ~= "table" then
			fail(scenario, "HallOfFame.lua left no list")
		else
			local clients = { camelot = true, vanilla = true, tbc = true, mists = true, mainline = true }
			for i, row in ipairs(list) do
				if type(row.name) ~= "string" or row.name == "" or not clients[row.client]
					or type(row.class) ~= "string" or not tostring(row.date):find("^%d%d%d%d%-%d%d%-%d%d$") then
					fail(scenario, "row " .. i .. " of the hall does not read")
				end
			end
			local ok, shown = pcall(ns.Hall.ListText)
			if not ok or type(shown) ~= "string" or shown == "" then
				fail(scenario, "the shipped list does not draw: " .. tostring(shown))
			end
		end
		local f = io.open(dir .. "/HallOfFame.lua", "r")
		local source = f and f:read("*a") or ""
		if f then f:close() end
		if not source:find("GENERATED by tools/hall.py", 1, true) then
			fail(scenario, "HallOfFame.lua does not say it is generated")
		end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ the window
do
	local scenario = "hall: the window draws it in a fold on Start here"
	session(scenario, {}, function(ns, Hall)
		ns.OpenOptions("general")
		local UI = ns.WindowUI
		local where = UI.Where("general.hallNote")
		if not (where and where.page == "general" and where.sec.fold and where.sec.key == "general.hall") then
			fail(scenario, "the hall is not a fold of its own on Start here")
			return
		end
		UI.State().open["general.hall"] = true
		UI.Refresh()
		if not (UI.RowShown("general.hallNote") and UI.RowShown("general.hallList")) then
			fail(scenario, "the fold open, the progress line or the list is not drawn")
		end
		if UI.RowShown("general.hallCode") then fail(scenario, "the code box is drawn with nothing earned") end
		earnAll(ns, NOON)
		UI.Refresh()
		if not UI.RowShown("general.hallCode") then
			fail(scenario, "every milestone earned, the code box is not drawn")
		end
		-- A box that only copies: what is typed in it is thrown away.
		local row = UI.RowFor("general.hallCode")
		local box = row and row.box
		local typed = box and box:GetScript("OnTextChanged")
		if not typed then
			fail(scenario, "SKIPPED -- the code's row has no box to type in")
		else
			box:SetText("MANNERS1-MINE")
			typed(box, true)
			if box:GetText() ~= Hall.Code() then
				fail(scenario, "the window's box kept what was typed over the code: " .. tostring(box:GetText()))
			end
		end
		H.findOption(ns.optionsTable, "milestones").set(nil, false)
		UI.Refresh()
		for _, path in ipairs({ "general.hallNote", "general.hallCode", "general.hallList" }) do
			if UI.RowShown(path) then fail(scenario, path .. " is drawn with milestones switched off") end
		end
		ns.Prompt:ExitTest()
	end)
end
