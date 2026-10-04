-- /manners selftest (Selftest.lua): the checks the author runs in the real
-- client after each release. Here they run against the mock, which cannot say
-- whether the game agrees with Manners; what it can hold them to is the rest:
-- every check reports on every class and language, a check that breaks is a
-- FAIL while the others carry on, nothing is cast, said, bound or saved, and
-- the comparisons that would have caught 1.6.3's imbue and a lost familiar do
-- go red when Manners and the client disagree.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local STATUSES = { PASS = true, WARN = true, FAIL = true }

local function session(scenario, setup)
	Mock.reset()
	if setup then setup() end
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	if not ns.Selftest then
		fail(scenario, "SKIPPED -- Selftest.lua did not load")
		return nil
	end
	return ns
end

-- The first result line for check `id`, and its worst status.
local function result(results, id)
	local first, worst
	local rank = { PASS = 1, WARN = 2, FAIL = 3 }
	for _, r in ipairs(results) do
		if r.id == id then
			first = first or r
			if not worst or rank[r.status] > rank[worst] then worst = r.status end
		end
	end
	return first, worst
end

local function lines(results, id)
	local out = {}
	for _, r in ipairs(results) do
		if r.id == id then out[#out + 1] = r.status .. " " .. r.label .. ": " .. r.value end
	end
	return table.concat(out, " / ")
end

-- Every check has a line, every line a known status, and nothing threw.
local function everyCheckReports(scenario, ns, results)
	if #ns.Selftest.CHECKS < 40 then
		fail(scenario, ("only %d checks are listed"):format(#ns.Selftest.CHECKS))
	end
	for _, check in ipairs(ns.Selftest.CHECKS) do
		local r = result(results, check.id)
		if not r then fail(scenario, check.id .. " reported nothing") end
	end
	for _, r in ipairs(results) do
		if not STATUSES[r.status] then
			fail(scenario, ("%s reported %s"):format(tostring(r.id), tostring(r.status)))
		end
		if tostring(r.value):find("threw: ", 1, true) and r.id ~= "errors.session" then
			fail(scenario, ("%s threw on the mock: %s"):format(r.id, r.value))
		end
		if tostring(r.value):find("said nothing", 1, true) then
			fail(scenario, r.id .. " said nothing")
		end
	end
end

local function copy(t, seen)
	if type(t) ~= "table" then return t end
	seen = seen or {}
	if seen[t] then return seen[t] end
	local out = {}
	seen[t] = out
	for k, v in pairs(t) do out[k] = copy(v, seen) end
	return out
end

-- The first path at which two tables differ, or nil.
local function differs(a, b, path)
	path = path or "profile"
	if type(a) ~= type(b) then return path end
	if type(a) ~= "table" then
		if a ~= b and not (a ~= a and b ~= b) then return path end
		return nil
	end
	for k, v in pairs(a) do
		local d = differs(v, b[k], path .. "." .. tostring(k))
		if d then return d end
	end
	for k in pairs(b) do
		if a[k] == nil then return path .. "." .. tostring(k) end
	end
	return nil
end

-- ------------------------------------------------------------------ 1
-- Several classes, three languages: every check reports and none throws.
for _, class in ipairs({ "MAGE", "PRIEST", "PALADIN", "WARRIOR", "HUNTER" }) do
	for _, locale in ipairs({ "enUS", "deDE", "koKR" }) do
		local scenario = ("selftest: every check reports (%s, %s)"):format(class, locale)
		local ns = session(scenario, function()
			Mock.class = class
			Mock.locale = locale
		end)
		if ns then
			local ok, results = pcall(ns.Selftest.Run)
			if not ok then
				fail(scenario, "Run threw: " .. tostring(results))
			else
				everyCheckReports(scenario, ns, results)
				local okR, text, pass, warn, failed = pcall(ns.Selftest.Report, results)
				if not okR then
					fail(scenario, "Report threw: " .. tostring(text))
				else
					if pass + warn + failed ~= #ns.Selftest.CHECKS then
						fail(scenario, ("the counts add up to %d over %d checks"):format(
							pass + warn + failed, #ns.Selftest.CHECKS))
					end
					for _, group in ipairs(ns.Selftest.GROUPS) do
						if not text:find("[" .. group.label .. "]", 1, true) then
							fail(scenario, "the report has no " .. group.label .. " section")
						end
					end
					if not text:find(("%d checks: %d pass, %d warn, %d fail"):format(
						#ns.Selftest.CHECKS, pass, warn, failed), 1, true) then
						fail(scenario, "the report does not end in its counts")
					end
				end
			end
		end
	end
end

-- ------------------------------------------------------------------ 2
-- The command touches nothing: no cast, no chat, no emote, no binding, no
-- macro, no CVar, no attribute on the prompt, nothing in the profile or the
-- character's memory. It opens its report on Diagnostics and says one line.
do
	local scenario = "selftest: the command touches nothing"
	local ns = session(scenario, function()
		-- A scroll's imbue on the main hand and a familiar up, so the
		-- readings of your own buffs (which remember what is up) run.
		Mock.weaponEnchants = { [0] = { { hasEnchant = true, enchantType = 3, enchantID = 8708,
			timeLeft = 1800000, charges = 0 } } }
		Mock.playerHeld = { [1296202] = true }
	end)
	if ns then
		local called = {}
		local saved = {}
		local function spy(name, holder)
			holder = holder or _G
			saved[#saved + 1] = { holder, name, rawget(holder, name) }
			rawset(holder, name, function() called[#called + 1] = name end)
		end
		for _, name in ipairs({ "CastSpellByName", "CastSpellByID", "UseItemByName",
			"UseInventoryItem", "SendChatMessage", "DoEmote", "SetBinding", "SaveBindings",
			"CreateMacro", "EditMacro", "TargetUnit", "RunMacroText", "SetCVar", "SpellTargetItem" }) do
			spy(name)
		end
		rawset(_G, "C_ChatInfo", {})
		spy("PerformEmote", C_ChatInfo)
		rawset(_G, "C_CVar", { GetCVar = function(name) return name == "nameplateShowFriends" and "1" or "0" end })
		spy("SetCVar", C_CVar)
		local button = ns.Prompt:GetButton()
		local setAttribute = button.SetAttribute
		button.SetAttribute = function(self, ...)
			called[#called + 1] = "SetAttribute " .. tostring((...))
			return setAttribute(self, ...)
		end
		local attributes = copy(button.attributes)
		local profile = copy(ns.db.profile)
		local char = copy(ns.db.char)

		Mock.printed = {}
		local ok, err = pcall(function() ns.addon:HandleSlash("selftest") end)
		if not ok then fail(scenario, "/manners selftest threw: " .. tostring(err)) end
		local okCheck, errCheck = pcall(function() ns.addon:HandleSlash("check") end)
		if not okCheck then fail(scenario, "/manners check threw: " .. tostring(errCheck)) end

		if #called > 0 then
			fail(scenario, "the self-test called " .. table.concat(called, ", "))
		end
		local changed = differs(attributes, button.attributes, "button")
		if changed then fail(scenario, "the self-test changed " .. changed) end
		changed = differs(profile, ns.db.profile)
		if changed then fail(scenario, "the self-test changed " .. changed) end
		changed = differs(char, ns.db.char, "char")
		if changed then fail(scenario, "the self-test changed " .. changed) end

		-- One line in chat per run, with the counts, and the report in its box.
		local summaries = 0
		for _, line in ipairs(Mock.printed) do
			if line:find("self%-test: %d+ passed, %d+ warnings, %d+ failed") then summaries = summaries + 1 end
		end
		if summaries ~= 2 then
			fail(scenario, ("%d summary lines for two runs: %s"):format(summaries, table.concat(Mock.printed, " / ")))
		end
		local text = ns.OptionsPage.selftestText
		if type(text) ~= "string" or not text:find("self-test", 1, true) then
			fail(scenario, "the report is not in its box: " .. tostring(text))
		elseif text ~= ns.Selftest.last then
			fail(scenario, "the box holds something other than the last report")
		end
		if ns.OptionsTab() ~= "diagnostics" then
			fail(scenario, "the window opened on " .. tostring(ns.OptionsTab()) .. ", not Diagnostics")
		end
		local box = ns.optionsTable.args.diagnostics.args.selftest
		if not box or box.get() ~= text or box.hidden() then
			fail(scenario, "the Diagnostics box does not show the report")
		end
		if ns.Prompt:InTest() then
			fail(scenario, "opening the report started the prompt's preview")
		end

		for i = #saved, 1, -1 do rawset(saved[i][1], saved[i][2], saved[i][3]) end
		rawset(_G, "C_ChatInfo", nil)
		rawset(_G, "C_CVar", nil)
		button.SetAttribute = setAttribute

		-- In a fight it says so and runs nothing.
		ns.CloseOptions()
		ns.Selftest.last = nil
		Mock.inCombat = true
		Mock.printed = {}
		ns.addon:HandleSlash("selftest")
		Mock.inCombat = false
		if ns.Selftest.last ~= nil then
			fail(scenario, "the self-test ran in a fight")
		end
		local said = table.concat(Mock.printed, " / ")
		if not said:find("runs out of combat", 1, true) then
			fail(scenario, "a self-test in a fight did not say why it did not run: " .. said)
		end
	end
end

-- ------------------------------------------------------------------ 3
-- A client call that throws is that check's FAIL, and the rest still run;
-- so is a check of Manners' own that throws.
do
	local scenario = "selftest: a failure is that check's FAIL and the rest run"
	local ns = session(scenario)
	if ns then
		local before = ns.Selftest.Run()
		local _, baseline = result(before, "api.weaponEnchants")
		if baseline ~= "PASS" then
			fail(scenario, "SKIPPED -- C_Item.GetWeaponEnchantInfo is not a PASS on the mock: "
				.. lines(before, "api.weaponEnchants"))
		end
		rawset(_G, "C_Item", { GetWeaponEnchantInfo = function() error("injected", 0) end })
		local summary = ns.ProximitySummary
		ns.ProximitySummary = function() error("injected summary", 0) end
		local ok, results = pcall(ns.Selftest.Run)
		rawset(_G, "C_Item", nil)
		ns.ProximitySummary = summary
		if not ok then
			fail(scenario, "Run threw: " .. tostring(results))
		else
			local r, worst = result(results, "api.weaponEnchants")
			if worst ~= "FAIL" or not r.value:find("injected", 1, true) then
				fail(scenario, "a GetWeaponEnchantInfo that throws reads " .. lines(results, "api.weaponEnchants"))
			end
			r, worst = result(results, "range.proximity")
			if worst ~= "FAIL" or not r.value:find("threw: injected summary", 1, true) then
				fail(scenario, "a check that throws reads " .. lines(results, "range.proximity"))
			end
			-- Every other check still has its line, the last one included.
			for _, check in ipairs(ns.Selftest.CHECKS) do
				if not result(results, check.id) then
					fail(scenario, check.id .. " never ran after the injected failures")
				end
			end
			-- And the mock's GetItemInfoInstant being absent is no reason for
			-- anything but the item checks to fail.
			local _, imbueLine = result(results, "beliefs.mainHand")
			if imbueLine == nil then fail(scenario, "the main hand was never read") end
		end
	end
end

-- ------------------------------------------------------------------ 4
-- The comparisons: the main hand's enchants read through every call against
-- what Manners reads (1.6.3: an imbue only C_Item lists, read as nothing on),
-- and the familiar's aura read directly against what Manners reads.
do
	local scenario = "selftest: the main hand and the familiar are compared"
	local ns = session(scenario, function()
		Mock.weaponEnchants = { [0] = { { hasEnchant = true, enchantType = 3, enchantID = 8708,
			timeLeft = 1800000, charges = 0 } } }
		Mock.playerHeld = { [1296202] = true }
	end)
	if ns then
		local results = ns.Selftest.Run()
		local _, worst = result(results, "beliefs.mainHand")
		if worst ~= "PASS" then
			fail(scenario, "an imbue C_Item lists and Manners reads reads " .. lines(results, "beliefs.mainHand"))
		end
		if not lines(results, "beliefs.mainHand"):find("seen only by C_Item", 1, true) then
			fail(scenario, "the report does not say the imbue is C_Item's alone: " .. lines(results, "beliefs.mainHand"))
		end
		_, worst = result(results, "beliefs.familiar")
		if worst ~= "PASS" or not lines(results, "beliefs.familiar"):find("ratfamiliar", 1, true) then
			fail(scenario, "a Rat up reads " .. lines(results, "beliefs.familiar"))
		end

		-- Manners reading nothing on while the client lists it: the bug the
		-- comparison is for.
		local read = ns.ReadOwnFamily
		ns.ReadOwnFamily = function() return false end
		results = ns.Selftest.Run()
		ns.ReadOwnFamily = read
		_, worst = result(results, "beliefs.mainHand")
		if worst ~= "FAIL" then
			fail(scenario, "Manners reading nothing over a listed imbue reads " .. lines(results, "beliefs.mainHand"))
		end
		_, worst = result(results, "beliefs.familiar")
		if worst ~= "FAIL" then
			fail(scenario, "Manners reading no familiar over a Rat on you reads " .. lines(results, "beliefs.familiar"))
		end

		-- And the other way: nothing on, read as on.
		Mock.weaponEnchants = nil
		Mock.playerHeld = {}
		ns.ReadOwnFamily = function() return true end
		results = ns.Selftest.Run()
		ns.ReadOwnFamily = read
		_, worst = result(results, "beliefs.mainHand")
		if worst ~= "FAIL" then
			fail(scenario, "Manners reading an imbue over an empty list reads " .. lines(results, "beliefs.mainHand"))
		end
	end
end

-- ------------------------------------------------------------------ 5
-- The rest of what the report is for: the secure button's clicks and macro,
-- surnames, the line rule for a target, a saved setting repaired, and an
-- error this session.
do
	local scenario = "selftest: the button, names, the line rule, repairs and errors"
	local ns = session(scenario)
	if ns then
		local results = ns.Selftest.Run()
		local _, worst = result(results, "button.clicks")
		if worst ~= "PASS" or not lines(results, "button.clicks"):find("AnyDown", 1, true) then
			fail(scenario, "the button's clicks read " .. lines(results, "button.clicks"))
		end
		local button = ns.Prompt:GetButton()
		button.attributes.macrotext1 = ("/s " .. ("x"):rep(300))
		button.attributes.type1 = "macro"
		results = ns.Selftest.Run()
		button.attributes.macrotext1, button.attributes.type1 = nil, nil
		_, worst = result(results, "button.macro")
		if worst ~= "FAIL" then
			fail(scenario, "a macro of 303 characters reads " .. lines(results, "button.macro"))
		end

		_, worst = result(results, "api.unitName")
		if worst ~= "PASS" or not lines(results, "api.unitName"):find('"Defrette", read as a surname', 1, true) then
			fail(scenario, "a Camelot surname reads " .. lines(results, "api.unitName"))
		end
		_, worst = result(results, "range.lineRule")
		if worst ~= "PASS" or not lines(results, "range.lineRule"):find("the line is", 1, true) then
			fail(scenario, "the line rule for a target reads " .. lines(results, "range.lineRule"))
		end
		_, worst = result(results, "window.fallback")
		if worst ~= "PASS" then fail(scenario, "the window reads " .. lines(results, "window.fallback")) end

		_, worst = result(results, "errors.repairs")
		if worst ~= "PASS" then fail(scenario, "a clean profile reads " .. lines(results, "errors.repairs")) end
		ns.db.profile.filters.whenBuffed = "sometimes"
		ns.ClampSettings()
		ns.Guard("selftest probe", function() error("on purpose", 0) end)
		results = ns.Selftest.Run()
		_, worst = result(results, "errors.repairs")
		if worst ~= "WARN" or not lines(results, "errors.repairs"):find("whenBuffed (was sometimes)", 1, true) then
			fail(scenario, "a repaired setting reads " .. lines(results, "errors.repairs"))
		end
		_, worst = result(results, "errors.session")
		if worst ~= "FAIL" or not lines(results, "errors.session"):find("selftest probe -- on purpose", 1, true) then
			fail(scenario, "an error this session reads " .. lines(results, "errors.session"))
		end
	end
end
