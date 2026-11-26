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
	local scenario = "achievements-module: the ledger owns the tab"
	Mock.reset()
	MannersAchievementsDB = nil
	local ns = load(scenario)
	if not ns then return end
	drive(scenario, ns)
	if not MannersAPI:LedgerTabs().achievements then fail(scenario, "no achievements tab") end
	if _G.MannersAchievements then fail(scenario, "a separate achievements window was published") end
	ns.Ledger.Show("achievements")
	local window = ns.Ledger.Window()
	if not (window and window.modulePanel and window.modulePanel:IsShown()) then fail(scenario, "the ledger did not paint the tab") end
	if not H.findOption(ns.optionsTable, "achievementNotification") then fail(scenario, "notification controls are missing") end
end
