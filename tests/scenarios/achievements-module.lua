local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function state()
	local db = MannersAchievementsDB
	if type(db) ~= "table" or type(db.characters) ~= "table" then return nil end
	for _, value in pairs(db.characters) do return value end
end

do
	local scenario = "achievements-module: a late module seeds after CoreReady"
	Mock.reset()
	MannersAchievementsDB = nil
	Mock.sv.char = {
		ledger = {
			entries = {
				{ kind = "received", name = "Late Friend", class = "MAGE", spells = { 1243 },
					at = time() - 5, doneAt = time() - 4, state = "returned" },
			},
			totals = { received = 1, returned = 1, letGo = 0, group = 0, strangers = 0 },
		},
	}
	local ns = load(scenario, true)
	if not ns then return end
	drive(scenario, ns)
	local module = H.loadModule(scenario, "Modules/Achievements/Manners_Achievements.toc")
	if not module then return end
	local st = state()
	if not st or not st.seeded or (st.metrics.returns or 0) ~= 1 then
		fail(scenario, "the late seed did not run")
	end
end

do
	local scenario = "achievements-module: the last 200 ledger rows are credited once"
	Mock.reset()
	MannersAchievementsDB = nil
	Mock.sv.char = {
		ledger = {
			entries = {},
			totals = { received = 10, returned = 10, letGo = 0, group = 0, strangers = 0 },
		},
	}
	for i = 1, 10 do
		Mock.sv.char.ledger.entries[i] = {
			kind = "received", name = "Friend " .. i, class = "MAGE", spells = { 1243 },
			at = time() - (20 - i), doneAt = time() - (10 - i), state = "returned",
		}
	end

	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local st = state()
	if not st or not st.seeded or st.metrics.returns ~= 10 then
		local days, people = 0, 0
		for _, cap in pairs(st and st.capped or {}) do
			days = days + 1
			for _ in pairs(cap) do people = people + 1 end
		end
		fail(scenario, "the bronze seed is " .. tostring(st and st.metrics.returns)
			.. ", " .. days .. " days and " .. people .. " caps, ledger " .. #MannersAPI:RecentLedgerEntries(200))
	end
	if (st.earned.first or 0) < 1 then fail(scenario, "bronze was not earned") end
end

do
	local scenario = "achievements-module: seed rows keep their historical days"
	Mock.reset()
	MannersAchievementsDB = nil
	local realDate = rawget(_G, "date")
	rawset(_G, "date", function(_, at) return tostring(math.floor((at or time()) / 86400)) end)
	local today = time()
	local yesterday = today - 86400
	local before = today - 172800
	Mock.sv.char = {
		ledger = {
			entries = {
				{ kind = "received", name = "Same Friend", class = "MAGE", spells = { 1243 },
					at = before, doneAt = before + 1, state = "returned" },
				{ kind = "received", name = "Same Friend", class = "MAGE", spells = { 1243 },
					at = before + 100, doneAt = before + 101, state = "returned" },
				{ kind = "received", name = "Same Friend", class = "MAGE", spells = { 1243 },
					at = yesterday, doneAt = yesterday + 1, state = "returned" },
			},
			totals = { received = 3, returned = 3, letGo = 0, group = 0, strangers = 0 },
		},
	}
	local ns = load(scenario, true)
	if not ns then return end
	drive(scenario, ns)
	if not H.loadModule(scenario, "Modules/Achievements/Manners_Achievements.toc") then return end
	local st = state()
	rawset(_G, "date", realDate)
	if not st or (st.metrics.returns or 0) ~= 2 then
		local days = {}
		for day in pairs(st and st.capped or {}) do days[#days + 1] = day end
		fail(scenario, "all seed rows counted as today: " .. tostring(st and st.metrics.returns)
			.. " days " .. table.concat(days, ","))
	end
	local todayKey = tostring(math.floor(today / 86400))
	local capped = st and st.capped[todayKey]
	if capped and capped["returns\0Same Friend"] then
		fail(scenario, "a historical row capped today")
	end
end

do
	local scenario = "achievements-module: daily per-person caps stop spam"
	Mock.reset()
	MannersAchievementsDB = nil
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local api = MannersAPI
	local at = GetTime()
	for _ = 1, 20 do
		api:Fire("Favour.Settled", "Repeat", { at = at, class = "MAGE" },
			{ reason = "gift", inGroup = true })
	end
	local st = state()
	if (st.metrics.returns or 0) ~= 1 then fail(scenario, "one person counted more than once") end
	if MannersAchievementsDB.notification ~= "none" or MannersAchievementsDB.sound ~= false then
		fail(scenario, "notifications are not silent by default")
	end
end

do
	local scenario = "achievements-module: toast and chat stay literal notification choices"
	Mock.reset()
	MannersAchievementsDB = { notification = "toast" }
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	if MannersAchievementsDB.notification ~= "toast" then
		fail(scenario, "toast was sanitized to " .. tostring(MannersAchievementsDB.notification))
	end
	local control = H.findOption(ns.optionsTable, "achievementNotification")
	control.set(nil, "chat")
	if MannersAchievementsDB.notification ~= "chat" then fail(scenario, "chat was not retained") end
	control.set(nil, true)
	if MannersAchievementsDB.notification ~= "none" then fail(scenario, "a boolean notification was retained") end
end

do
	local scenario = "achievements-module: the Achievements page holds everything, with no ledger tab"
	Mock.reset()
	MannersAchievementsDB = nil
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	if MannersAPI:LedgerTabs().achievements then fail(scenario, "Achievements still adds a tab to the ledger") end
	if _G.MannersAchievements then fail(scenario, "a separate achievements window was published") end
	if H.findOption(ns.optionsTable, "achievementOpen") then fail(scenario, "the page still sends the player to the ledger") end
	local pages = MannersAPI:OptionsPages()
	if not (pages and pages.achievements) then fail(scenario, "Achievements has no sidebar page") end
	for _, path in ipairs({ "achievementSummary", "achievementRecent", "achievementRow1", "achievementStats",
		"achievementFilter", "achievementSort", "achievementTheme", "achievementNotification", "achievementReset" }) do
		if ns.WindowUI.PageOf("achievements." .. path) ~= "achievements" then
			fail(scenario, path .. " is not on the Achievements page")
		end
	end
	local A = ns.Achievements
	if not (A and #A.DEFS >= 30) then fail(scenario, "fewer than thirty achievements") return end
	local row = H.findOption(ns.optionsTable, "achievementRow1")
	if not (row and type(row.name) == "function" and row.name():find("|T", 1, true)) then
		fail(scenario, "an achievement row has no icon and words")
	end
	-- One returned favour: Much Obliged is earned and the filter finds it alone.
	MannersAPI:Fire("Favour.Settled", "Kind Soul", { at = GetTime(), class = "MAGE" }, { reason = "owed" })
	local filter = H.findOption(ns.optionsTable, "achievementFilter")
	filter.set(nil, "earned")
	local earned = A.List()
	local found = false
	for _, def in ipairs(earned) do
		if def.id == "first" then found = true end
		if (A.State().earned[def.id] or 0) < 1 then fail(scenario, "Earned lists " .. def.id .. ", not earned") end
	end
	if not found then fail(scenario, "Much Obliged was not earned by the first returned favour") end
	filter.set(nil, "all")
	local theme = H.findOption(ns.optionsTable, "achievementTheme")
	theme.set(nil, "courtesy")
	for _, def in ipairs(A.List()) do
		if def.theme ~= "courtesy" then fail(scenario, "Courtesy shows " .. def.id) break end
	end
	theme.set(nil, "all")
	local nextPage = H.findOption(ns.optionsTable, "achievementNext")
	local first = H.findOption(ns.optionsTable, "achievementRow1")
	local ninth = A.List()[9]
	if not (nextPage and ninth) then
		fail(scenario, "the list has no second page")
	else
		nextPage.func()
		if not first.name():find(ninth.name, 1, true) then
			fail(scenario, "Next did not show the ninth achievement first: " .. first.name())
		end
		H.findOption(ns.optionsTable, "achievementFilter").set(nil, "all")
		if not first.name():find(A.List()[1].name, 1, true) then
			fail(scenario, "changing what the list shows did not go back to its first page")
		end
	end
	local points = A.Totals(A.State())
	if points < 15 then fail(scenario, "the earned medal gave " .. tostring(points) .. " points") end
	H.findOption(ns.optionsTable, "achievementReset").func()
	if (A.State().earned.first or 0) ~= 0 or (A.State().metrics.returns or 0) ~= 0 then
		fail(scenario, "Start this character over kept its progress")
	end
end

do
	local scenario = "achievements-module: an old save keeps its counts and earns medals by the new goals"
	Mock.reset()
	MannersAchievementsDB = { characters = {} }
	local ns = load(scenario, true)
	if not ns then return end
	drive(scenario, ns)
	local key = (MannersAPI:Plain(UnitGUID("player")) or "local") .. ":" .. select(2, UnitClass("player"))
	MannersAchievementsDB.characters[key] = { seeded = true, metrics = { returns = 12, res = 1 },
		earned = { first = 3, hundred = 1 }, classes = { MAGE = true, PRIEST = true } }
	if not H.loadModule(scenario, "Modules/Achievements/Manners_Achievements.toc") then return end
	local st = ns.Achievements and ns.Achievements.State()
	if not st then fail(scenario, "no state") return end
	if st.earned.first ~= 1 then fail(scenario, "Much Obliged reads tier " .. tostring(st.earned.first) .. " of its one goal") end
	if st.earned.returns ~= 1 then fail(scenario, "twelve returns did not earn bronze Returning the Favour") end
	if st.earned.res ~= 1 then fail(scenario, "a resurrection did not earn Back on Your Feet") end
	if st.metrics.classes ~= 2 then fail(scenario, "the classes were not counted again: " .. tostring(st.metrics.classes)) end
	if st.earned.hundred then fail(scenario, "a retired achievement kept its medal") end
end

do
	local scenario = "achievements-module: buffs received, refusals and services count"
	Mock.reset()
	MannersAchievementsDB = nil
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	local api = MannersAPI
	api:Fire("Favour.Received", { name = "Giver One" })
	api:Fire("Favour.Received", { name = "Giver Two" })
	api:Fire("Favour.Refused", "Proud One", time())
	api:Fire("Service.Given", "water", "Thirsty One")
	api:Fire("Service.Given", "portal", "Traveller")
	local st = ns.Achievements.State()
	if st.metrics.givers ~= 2 or st.metrics.received ~= 2 then
		fail(scenario, "two people who buffed you read " .. tostring(st.metrics.givers))
	end
	if (st.earned.grace or 0) ~= 1 then fail(scenario, "a refused buff did not reveal No Hard Feelings") end
	if st.metrics.serviceKinds ~= 2 or (st.earned.trades or 0) ~= 1 then
		fail(scenario, "two kinds of service read " .. tostring(st.metrics.serviceKinds))
	end
	if (st.metrics.activeDays or 0) ~= 1 then fail(scenario, "today was not counted as a day of good manners") end
end
