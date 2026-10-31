-- /manners selftest launch (SelftestLaunch.lua): the launch checks, run against
-- the mock. The mock cannot say whether the game agrees with Manners, so what
-- is held here is the rest: the report on every client, every check reaching a
-- verdict with each client call present and absent or refusing, nothing left
-- changed afterwards, nothing asked in a fight, no protected call, and that a
-- client answering something else is read as CHECK or FAIL and not as PASS.
--
-- Run on the recording CreateFrame in tests/frametree.lua (which lists a
-- frame's regions and children and counts its masks, as the client does) with
-- a screen modelled, so the checks that read where the prompt is have an answer.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local VERDICTS = { PASS = true, CHECK = true, FAIL = true }
local FLAVOURS = { "camelot", "vanilla", "tbc", "mists", "mainline" }
local MORPHEUS = "Fonts\\MORPHEUS.TTF"

local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" },
	nameplate3 = { "Cara", "Close" } }

-- One session, everything put back: three strangers on nameplates and Anna
-- owed a favour, so the prompt has a person, a count chip and a list on it,
-- locked and up. opts.tree false: plain frames; opts.flavour; opts.setup()
-- before the addon loads; opts.after(ns) once it is up and painted.
-- `body(ns)` gets the loaded addon.
local function session(scenario, opts, body)
	opts = opts or {}
	Mock.reset()
	if opts.flavour then Mock.setFlavour(opts.flavour) end
	if opts.tree ~= false then
		Mock.geometry = { width = 1920, height = 1080 }
		FT.install()
	end
	local restore = H.strangers(PEOPLE)
	-- Somebody is targeted, whatever an earlier scenario of a narrowed run
	-- left in UnitExists.
	local realExists = UnitExists
	UnitExists = function() return true end
	if opts.setup then opts.setup() end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		local p = ns.db.profile.prompt
		p.showQueue, p.queueRows, p.clickRows, p.locked = true, 3, true, true
		H.owe(ns, "Anna Aim")
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		ns.Prompt:Refresh()
		Mock.timers = {}
		if not (ns.Selftest and ns.Selftest.RunLaunch) then
			fail(scenario, "SKIPPED -- SelftestLaunch.lua did not load")
			return
		end
		if opts.after then opts.after(ns) end
		body(ns)
	end)
	Mock.inCombat = false
	UnitExists = realExists
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The first result line for check `id`, and its worst status.
local RANK = { PASS = 1, CHECK = 2, FAIL = 3 }
local function result(results, id)
	local first, worst
	for _, r in ipairs(results) do
		if r.id == id then
			first = first or r
			if not worst or RANK[r.status] > RANK[worst] then worst = r.status end
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

-- The timers parked for the half second of listening (the looks park some of
-- their own while they are shown).
local function listenTimers()
	local n = 0
	for _, t in ipairs(Mock.timers) do
		if math.abs(t.at - Mock.now - 0.5) < 0.001 then n = n + 1 end
	end
	return n
end

-- A run to the end: the launch results with the late checks in, and the
-- standard checks beside them for the report.
local function run(ns, opts)
	local results, finish = ns.Selftest.RunLaunch(opts or { createMacro = true })
	finish()
	return results
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

local function differs(a, b, path)
	path = path or "profile"
	-- A table that reaches itself (a frame's parent and children) is not walked for ever.
	if #path > 300 then return path end
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

-- Every check has a line, every line a known verdict, nothing threw or said
-- nothing; one line per registered look.
local function everyCheckReports(scenario, ns, results)
	for _, check in ipairs(ns.Selftest.LAUNCH) do
		if not result(results, check.id) then fail(scenario, check.id .. " reported nothing") end
	end
	local _, keys = ns.Looks.Choices()
	for _, key in ipairs(keys) do
		if not result(results, "launch.look." .. key) then fail(scenario, "look " .. key .. " reported nothing") end
	end
	for _, r in ipairs(results) do
		if not VERDICTS[r.status] then fail(scenario, ("%s reported %s"):format(tostring(r.id), tostring(r.status))) end
		if tostring(r.value):sub(1, 7) == "threw: " then fail(scenario, ("%s threw: %s"):format(r.id, r.value)) end
		if tostring(r.value):find("said nothing", 1, true) then fail(scenario, r.id .. " said nothing") end
	end
end

-- ------------------------------------------------------------------ 1
-- The report on each client, with the recording frames and without them (a
-- client whose frames cannot list their regions): every check has a verdict.
for _, flavour in ipairs(FLAVOURS) do
	for _, tree in ipairs({ true, false }) do
		local scenario = ("selftest-launch: every check reaches a verdict (%s, %s)"):format(flavour,
			tree and "frames that can be listed" or "frames that cannot")
		session(scenario, { flavour = flavour, tree = tree }, function(ns)
			local results = run(ns)
			everyCheckReports(scenario, ns, results)
			local text = ns.Selftest.Report({}, results)
			local first = text:match("\n(Launch checks: [^\n]*)")
			if not first then fail(scenario, "the report has no launch summary line") end
			if os.getenv("MANNERS_LAUNCH_PRINT") == (flavour .. (tree and "" or "-bare")) then
				print(text)
			end
		end)
	end
end

-- ------------------------------------------------------------------ helpers
-- (for the scenarios below)

-- Globals replaced while `body` runs, then put back.
local function withGlobals(map, body)
	local saved = {}
	for name, value in pairs(map) do
		saved[name] = { rawget(_G, name) }
		rawset(_G, name, value == "NIL" and nil or value)
	end
	local ok, err = pcall(body)
	for name, was in pairs(saved) do rawset(_G, name, was[1]) end
	if not ok then error(err, 0) end
end

-- The verdict of check `id` is `status`, and its text holds `needle`.
local function expect(scenario, results, id, status, needle)
	local r, worst = result(results, id)
	if not r then
		fail(scenario, id .. " reported nothing")
	elseif worst ~= status then
		fail(scenario, ("%s reads %s, wanted %s: %s"):format(id, tostring(worst), status, lines(results, id)))
	elseif needle and not lines(results, id):find(needle, 1, true) then
		fail(scenario, ("%s does not say %q: %s"):format(id, needle, lines(results, id)))
	end
end

-- One client answering something else: `setup(ns, scratch)` changes it (and
-- may answer a function that puts it back), `check(results, ns)` judges the
-- report. Every check still reaches a verdict.
local function variation(name, setup, check, opts)
	local scenario = "selftest-launch: " .. name
	session(scenario, opts or {}, function(ns)
		local s = ns.Selftest.Scratch()
		local undo
		local ok, err = pcall(function() undo = setup(ns, s) end)
		if not ok then
			fail(scenario, "setup threw: " .. tostring(err))
			return
		end
		local okRun, results = pcall(run, ns)
		if undo then pcall(undo) end
		if not okRun then
			fail(scenario, "the run threw: " .. tostring(results))
			return
		end
		everyCheckReports(scenario, ns, results)
		check(results, ns, scenario)
	end)
end

-- The player's own Manners macro, as Clicks.lua makes it, with a spell and an
-- item already on its slot.
local function ownMacro(withSlot)
	local index = CreateMacro("Manners", "INV_MISC_NOTE_03", "/click MannersPrompt:LeftButton", false)
	if withSlot then
		Mock.macroList[index].spell = "Arcane Brilliance"
		Mock.macroList[index].item = "item:5760"
	end
	return index
end

-- What the prompt shows: every region switched on from the button down, with
-- what it was told, in a form two sessions can be compared by.
local function signature(ns)
	local out = {}
	local function val(v)
		if v == false then return "nil" end
		if type(v) == "table" and #v >= 3 and v[1] == 1 and v[2] == 1 and v[3] == 1 and (v[4] == nil or v[4] == 1) then
			return "nil"
		end
		if type(v) == "table" then
			if v._serial then return "#" .. v._serial end
			local t = {}
			for i = 1, #v do t[#t + 1] = val(v[i]) end
			return "{" .. table.concat(t, ",") .. "}"
		end
		return tostring(v)
	end
	local function walk(f, live)
		if live then
			for _, r in ipairs({ f:GetRegions() }) do
				if r:IsShown() then
					out[#out + 1] = table.concat({ r._serial, r._kind, val(r._file), val(r._text), val(r._color),
						-- A line anchored at both sides is as wide as its anchors, whatever
						-- width it was once given.
						val(r:GetAlpha()), r._kind == "FontString" and "-" or val(r._width), val(r._height), val(r.points), val(r._texCoord),
						val(r._desaturated), val(r._font and r._font.path), val(r._gradient) }, "|")
				end
			end
		end
		for _, c in ipairs({ f:GetChildren() }) do walk(c, live and c:IsShown()) end
	end
	walk(ns.Prompt.regions.button, true)
	-- By serial: a look that moves a line under its own frame and back leaves
	-- it last in its parent's list, which is no change to what is drawn.
	table.sort(out, function(a, b) return tonumber(a:match("^(%d+)")) < tonumber(b:match("^(%d+)")) end)
	return out
end

-- ------------------------------------------------------------------ 2
-- Nothing is left changed: no cast, chat, binding, macro, CVar or target call,
-- the profile and the character's memory as they were, the prompt in the same
-- style with the same regions switched on as a prompt that never ran it, the
-- macro's slot as it was, the cursor empty, the game's own tooltip untouched.
for _, style in ipairs({ "glass", "ribbon" }) do
	local scenario = ("selftest-launch: nothing is left changed (the prompt in %s)"):format(style)
	local fresh
	session(scenario .. " [fresh]", {}, function(ns)
		ns.db.profile.prompt.style = style
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		ns.Prompt:Refresh()
		fresh = signature(ns)
	end)
	session(scenario, {}, function(ns)
		local p = ns.db.profile.prompt
		p.style = style
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		ns.Prompt:Refresh()
		local index = ownMacro(true)
		local called = {}
		local spied = {}
		for _, name in ipairs({ "CastSpellByName", "CastSpellByID", "UseItemByName", "UseInventoryItem",
			"SendChatMessage", "DoEmote", "SetBinding", "SaveBindings", "CreateMacro", "EditMacro", "DeleteMacro",
			"TargetUnit", "ClearTarget", "TargetLastTarget", "RunMacroText", "SetCVar", "SpellTargetItem" }) do
			spied[name] = function() called[#called + 1] = name end
		end
		withGlobals(spied, function()
			local button = ns.Prompt:GetButton()
			local attributes = copy(button.attributes)
			local profile = copy(ns.db.profile)
			local char = copy(ns.db.char)
			local macros = copy(Mock.macroList)
			local tooltip = copy(Mock.tooltip)
			local owner, points = Mock.tooltipOwner, {}
			for i, pt in ipairs(GameTooltip.points or {}) do
				points[i] = { (table.unpack or unpack)(pt, 1, 5) }
			end
			Mock.printed = {}
			local results = run(ns)
			if #called > 0 then fail(scenario, "the launch checks called " .. table.concat(called, ", ")) end
			local changed = differs(attributes, button.attributes, "button")
			if changed then fail(scenario, "the launch checks changed " .. changed) end
			changed = differs(profile, ns.db.profile)
			if changed then fail(scenario, "the launch checks changed " .. changed) end
			changed = differs(char, ns.db.char, "char")
			if changed then fail(scenario, "the launch checks changed " .. changed) end
			changed = differs(macros, Mock.macroList, "macros")
			if changed then fail(scenario, "the macro list changed at " .. changed) end
			if Mock.macroList[index].spell ~= "Arcane Brilliance" or Mock.macroList[index].item ~= "item:5760" then
				fail(scenario, ("the slot was left holding %s, %s"):format(tostring(Mock.macroList[index].spell),
					tostring(Mock.macroList[index].item)))
			end
			if Mock.cursor ~= nil then fail(scenario, "the cursor was left holding something") end
			local movedTip = differs(tooltip, Mock.tooltip, "tooltip") or Mock.tooltipOwner ~= owner
				or #points ~= #(GameTooltip.points or {})
			for i, pt in ipairs(points) do
				for k = 1, 5 do
					if (GameTooltip.points or {})[i] == nil or GameTooltip.points[i][k] ~= pt[k] then movedTip = true end
				end
			end
			if movedTip then fail(scenario, "the game's own tooltip was touched") end
			if #Mock.printed > 0 then fail(scenario, "it said something in chat: " .. table.concat(Mock.printed, " / ")) end
			if rawget(p, "style") ~= style then
				fail(scenario, ("the style is %s, not %s"):format(tostring(rawget(p, "style")), style))
			end
			if #Mock.protectedCalls > 0 or #Mock.blockedCalls > 0 then
				fail(scenario, "a protected call was made: " .. table.concat(Mock.protectedCalls, ", "))
			end
			if listenTimers() > 0 then fail(scenario, "it parked a timer for the listening") end
			local sig = signature(ns)
			if #fresh ~= #sig then
				fail(scenario, ("%d regions switched on afterwards, %d on a prompt that never ran it"):format(#sig, #fresh))
			else
				for i = 1, #sig do
					if sig[i] ~= fresh[i] then
						if os.getenv("MANNERS_LAUNCH_DEBUG") then
							for k = math.max(1, i - 2), math.min(#sig, i + 4) do print("A ", k, sig[k]) print("F ", k, fresh[k]) end
						end
						fail(scenario, ("a region differs from a fresh prompt's: %s -- was %s"):format(sig[i], fresh[i]))
						break
					end
				end
			end
			expect(scenario, results, "launch.looks", "PASS", "put the style back to")
		end)
	end)
end

-- ------------------------------------------------------------------ 3
-- In a fight nothing is asked: the run says so, no protected call is made, no
-- timer is left, and the style, the macro and the cursor stay as they were; a
-- fight that starts while the half second of listening runs makes no call.
do
	local scenario = "selftest-launch: refused in combat, no protected call"
	session(scenario, {}, function(ns)
		ownMacro(true)
		local p = ns.db.profile.prompt
		local style = rawget(p, "style")
		local slotCalls = { Mock.macroSpellCalls, Mock.macroItemCalls }
		Mock.inCombat = true
		Mock.protectedCalls, Mock.blockedCalls, Mock.printed = {}, {}, {}
		local results, finish = ns.Selftest.RunLaunch({ createMacro = true })
		finish()
		if #results ~= 1 or results[1].status ~= "FAIL" or not results[1].value:find("in a fight", 1, true) then
			fail(scenario, "the run in a fight reads " .. lines(results, results[1] and results[1].id or "?"))
		end
		ns.addon:HandleSlash("selftest launch")
		local said = table.concat(Mock.printed, " / ")
		if not said:find("runs out of combat", 1, true) then fail(scenario, "no refusal in chat: " .. said) end
		if ns.Selftest.last ~= nil then fail(scenario, "a report was made in a fight") end
		if #Mock.protectedCalls > 0 or #Mock.blockedCalls > 0 then
			fail(scenario, ("calls in a fight: %s %s"):format(table.concat(Mock.protectedCalls, ", "),
				table.concat(Mock.blockedCalls, ", ")))
		end
		if listenTimers() > 0 then fail(scenario, "a timer was parked in a fight") end
		if rawget(p, "style") ~= style then fail(scenario, "the style moved in a fight") end
		if Mock.macroSpellCalls ~= slotCalls[1] or Mock.macroItemCalls ~= slotCalls[2] then
			fail(scenario, "the macro's slot was touched in a fight")
		end
		Mock.inCombat = false

		-- A fight that begins between the checks and the end of the listening.
		local results2, finish2 = ns.Selftest.RunLaunch({ createMacro = true })
		Mock.inCombat = true
		Mock.protectedCalls, Mock.blockedCalls = {}, {}
		finish2()
		if #Mock.protectedCalls > 0 or #Mock.blockedCalls > 0 then
			fail(scenario, "the end of the listening called something in a fight")
		end
		if not result(results2, "launch.macro.events") then fail(scenario, "the listening never reported") end
		Mock.inCombat = false
	end)
end

-- ------------------------------------------------------------------ 4
-- The macro's slot: the player's own macro is used and put back; with none, a
-- temporary one is made only when asked to, said so, and deleted; a full list,
-- a busy cursor and a macro that cannot be deleted each get their verdict.
do
	local scenario = "selftest-launch: the slot is set, read, cleared and put back on the player's own macro"
	session(scenario, {}, function(ns)
		local index = ownMacro(true)
		local results = run(ns, { createMacro = false })
		expect(scenario, results, "launch.macro.slot", "PASS", "your Manners macro")
		expect(scenario, results, "launch.macro.slot", "PASS", "leaves nil")
		expect(scenario, results, "launch.macro.item", "PASS")
		expect(scenario, results, "launch.macro.pickup", "PASS")
		expect(scenario, results, "launch.macro.cleanup", "PASS", "your own")
		local macro = Mock.macroList[index]
		if macro.spell ~= "Arcane Brilliance" or macro.item ~= "item:5760" then
			fail(scenario, ("the slot holds %s, %s afterwards"):format(tostring(macro.spell), tostring(macro.item)))
		end
		if not Mock.macroSpellCalls or Mock.macroSpellCalls < 2 then fail(scenario, "SetMacroSpell was never asked") end
		if Mock.cursor ~= nil then fail(scenario, "the cursor holds something afterwards") end
	end)

	scenario = "selftest-launch: with no macro, a temporary one is made when asked, said so, and deleted"
	session(scenario, {}, function(ns)
		local made, deleted = {}, {}
		local create, delete = CreateMacro, DeleteMacro
		withGlobals({
			CreateMacro = function(name, ...) made[#made + 1] = name return create(name, ...) end,
			DeleteMacro = function(which) deleted[#deleted + 1] = which return delete(which) end,
		}, function()
			local results = run(ns, { createMacro = true })
			expect(scenario, results, "launch.macro.slot", "PASS", "a temporary macro MannersSelfTest")
			expect(scenario, results, "launch.macro.slot", "PASS", "deleted at its end")
			expect(scenario, results, "launch.macro.cleanup", "PASS", "has been deleted")
			expect(scenario, results, "launch.macro.pickup", "PASS")
		end)
		if #made ~= 1 or made[1] ~= "MannersSelfTest" then
			fail(scenario, "macros made: " .. table.concat(made, ", "))
		end
		if #deleted ~= 1 then fail(scenario, ("%d macros deleted"):format(#deleted)) end
		if next(Mock.macroList) ~= nil then fail(scenario, "a macro was left in the list") end
		if GetMacroIndexByName("MannersSelfTest") ~= 0 then fail(scenario, "MannersSelfTest is still there") end
	end)

	scenario = "selftest-launch: with no macro and not asked, none is made and the macro checks say why"
	session(scenario, {}, function(ns)
		local made = 0
		local create = CreateMacro
		withGlobals({ CreateMacro = function(...) made = made + 1 return create(...) end }, function()
			local results = run(ns, { createMacro = false })
			for _, id in ipairs({ "launch.macro.slot", "launch.macro.item", "launch.macro.pickup" }) do
				expect(scenario, results, id, "CHECK", "skipped: no macro named Manners")
			end
			expect(scenario, results, "launch.macro.events", "CHECK", "no macro call was made")
		end)
		if made > 0 then fail(scenario, "a macro was made without being asked") end
		if next(Mock.macroList) ~= nil then fail(scenario, "the macro list changed") end
	end)

	scenario = "selftest-launch: a full macro list is a CHECK, not a fault, and nothing is left"
	session(scenario, {}, function(ns)
		withGlobals({ CreateMacro = function() error("Macro limit reached", 2) end }, function()
			local results = run(ns, { createMacro = true })
			expect(scenario, results, "launch.macro.slot", "CHECK", "could not be made")
			expect(scenario, results, "launch.macro.cleanup", "PASS")
		end)
	end)

	scenario = "selftest-launch: a busy cursor is left alone"
	session(scenario, {}, function(ns)
		ownMacro(false)
		Mock.cursor = { "item", 6948 }
		local results = run(ns)
		expect(scenario, results, "launch.macro.pickup", "CHECK", "something is on the cursor")
		if not Mock.cursor or Mock.cursor[1] ~= "item" then fail(scenario, "the player's cursor was emptied") end
	end)

	scenario = "selftest-launch: a temporary macro that cannot be deleted is a FAIL naming it"
	session(scenario, {}, function(ns)
		withGlobals({ DeleteMacro = function() end }, function()
			local results = run(ns, { createMacro = true })
			expect(scenario, results, "launch.macro.cleanup", "FAIL", "MannersSelfTest is still there")
		end)
	end)

	scenario = "selftest-launch: a client that does not clear the slot with an empty string is a CHECK"
	session(scenario, {}, function(ns)
		ownMacro(false)
		local set = SetMacroSpell
		local setItem = SetMacroItem
		withGlobals({
			SetMacroSpell = function(index, spell) if spell ~= "" then set(index, spell) end end,
			SetMacroItem = function(index, item) if item ~= "" then setItem(index, item) end end,
		}, function()
			local results = run(ns)
			expect(scenario, results, "launch.macro.slot", "CHECK", "leaves the spell on the slot")
			expect(scenario, results, "launch.macro.item", "CHECK", "leaves the item on the slot")
		end)
	end)

	scenario = "selftest-launch: a slot that cannot be put back exactly is a CHECK saying what it held"
	session(scenario, {}, function(ns)
		local index = ownMacro(true)
		local set = SetMacroSpell
		withGlobals({
			SetMacroSpell = function(i, spell)
				-- The first spell this macro had cannot be given back.
				if spell == "Arcane Brilliance" then return end
				return set(i, spell)
			end,
		}, function()
			local results = run(ns)
			expect(scenario, results, "launch.macro.slot", "CHECK", "could not be put back exactly")
			expect(scenario, results, "launch.macro.slot", "CHECK", "Arcane Brilliance")
		end)
		local _ = index
	end)
end

-- ------------------------------------------------------------------ 5
-- The client answering something else.
local function absent(name, fn) return fn end
local _ = absent

variation("a client with no SetMacroSpell, GetMacroSpell, SetMacroItem or GetMacroItem",
	function() ownMacro(false) end,
	function(results, _, scenario)
		-- Run with each call gone below; this one has them all.
		expect(scenario, results, "launch.macro.slot", "PASS")
	end)

for _, row in ipairs({
	{ "SetMacroSpell", "launch.macro.slot", "CHECK", "SetMacroSpell is missing" },
	{ "GetMacroSpell", "launch.macro.slot", "CHECK", "GetMacroSpell is missing" },
	{ "SetMacroItem", "launch.macro.item", "CHECK", "SetMacroItem is missing" },
	{ "GetMacroItem", "launch.macro.item", "CHECK", "GetMacroItem is missing" },
	{ "PickupMacro", "launch.macro.pickup", "CHECK", "PickupMacro is missing" },
	{ "GetCursorInfo", "launch.macro.pickup", "CHECK", "cannot be checked" },
}) do
	local scenario = "selftest-launch: " .. row[1] .. " missing reads " .. row[3]
	session(scenario, {}, function(ns)
		ownMacro(false)
		local results
		withGlobals({ [row[1]] = "NIL" }, function() results = run(ns) end)
		everyCheckReports(scenario, ns, results)
		expect(scenario, results, row[2], row[3], row[4])
	end)
end

for _, row in ipairs({
	{ "SetMacroSpell", "launch.macro.slot", "threw" },
	{ "SetMacroItem", "launch.macro.item", "threw" },
	{ "PickupMacro", "launch.macro.pickup", "threw" },
}) do
	local scenario = "selftest-launch: " .. row[1] .. " that throws reads FAIL"
	session(scenario, {}, function(ns)
		ownMacro(false)
		local results
		withGlobals({ [row[1]] = function() error("injected", 0) end }, function() results = run(ns) end)
		everyCheckReports(scenario, ns, results)
		expect(scenario, results, row[2], "FAIL", "injected")
	end)
end

variation("GetMacroSpell answering nothing after SetMacroSpell is a CHECK",
	function() ownMacro(false) return nil end,
	function(results, _, scenario) expect(scenario, results, "launch.macro.slot", "PASS") end)

do
	local scenario = "selftest-launch: a spell read back as nothing is a CHECK"
	session(scenario, {}, function(ns)
		ownMacro(false)
		local results
		withGlobals({ GetMacroSpell = function() return nil end }, function() results = run(ns) end)
		expect(scenario, results, "launch.macro.slot", "CHECK", "answered nothing after setting it")
	end)
end

variation("no SetClipsChildren reads CHECK",
	function(_, s) s.clip.SetClipsChildren = nil end,
	function(results, _, scenario) expect(scenario, results, "launch.clip", "CHECK", "SetClipsChildren is missing") end)

variation("a frame that does not read back as clipping reads CHECK",
	function(_, s) s.clip.DoesClipChildren = function() return false end end,
	function(results, _, scenario) expect(scenario, results, "launch.clip", "CHECK", "does not read back as set") end)

variation("a SetClipsChildren that throws reads FAIL",
	function(_, s) s.clip.SetClipsChildren = function() error("injected", 0) end end,
	function(results, _, scenario) expect(scenario, results, "launch.clip", "FAIL", "injected") end)

variation("a CreateMaskTexture that answers nothing reads FAIL",
	function(_, s) s.frame.CreateMaskTexture = function() return nil end end,
	function(results, _, scenario)
		expect(scenario, results, "launch.mask", "FAIL", "answered nothing")
		expect(scenario, results, "launch.picker", "FAIL", "no mask can be made")
	end)

variation("no CreateMaskTexture reads FAIL",
	function(_, s) s.frame.CreateMaskTexture = nil end,
	function(results, _, scenario) expect(scenario, results, "launch.mask", "FAIL", "CreateMaskTexture is missing") end)

variation("no AddMaskTexture reads FAIL",
	function(_, s) s.tex.AddMaskTexture = nil end,
	function(results, _, scenario) expect(scenario, results, "launch.mask", "FAIL", "AddMaskTexture MISSING") end)

variation("masks that cannot be counted read CHECK",
	function(_, s) s.tex.GetNumMaskTextures = nil end,
	function(results, _, scenario) expect(scenario, results, "launch.mask", "CHECK", "no call to count masks") end)

variation("a mask that does not attach reads CHECK",
	function(_, s) s.tex.GetNumMaskTextures = function() return 0 end end,
	function(results, _, scenario) expect(scenario, results, "launch.mask", "CHECK", "not one mask on") end)

variation("a font file the client refuses reads CHECK, here and on the looks that use it",
	function() Mock.badFonts = { [MORPHEUS] = true } end,
	function(results, _, scenario)
		expect(scenario, results, "launch.font", "CHECK", "refused the file")
		for _, key in ipairs({ "ribbon", "letter", "leather" }) do
			expect(scenario, results, "launch.look." .. key, "CHECK", "not in Morpheus")
		end
		expect(scenario, results, "launch.look.glass", "PASS")
		expect(scenario, results, "launch.looks", "PASS")
	end)

variation("SetFont refusing every face reads FAIL",
	function() Mock.badFonts = { [MORPHEUS] = true, ["font.ttf"] = true } end,
	function(results, _, scenario)
		expect(scenario, results, "launch.font", "FAIL", "refuses even the game's own face")
		-- The prompt cannot be laid out in any face: the style goes back, and the line says the layout threw.
		expect(scenario, results, "launch.looks", "FAIL", "putting the style back threw")
	end)

variation("a SetFont that throws reads FAIL",
	function(_, s) s.fs.SetFont = function() error("injected", 0) end end,
	function(results, _, scenario) expect(scenario, results, "launch.font", "FAIL", "injected") end)

variation("a client in another alphabet is not asked for Morpheus",
	function() Mock.badFonts = { [MORPHEUS] = true } end,
	function(results, ns, scenario)
		local r = result(results, "launch.look.ribbon")
		if not r then return end
		-- Not enUS: the looks keep the client's face, so nothing is expected of Morpheus.
		expect(scenario, results, "launch.look.ribbon", "PASS")
		expect(scenario, results, "launch.font", "CHECK", "keep the client's own face")
		local _ = ns
	end,
	{ setup = function() Mock.locale = "koKR" end })

variation("tiling: a SetTexture that throws reads FAIL",
	function(_, s) s.tex.SetTexture = function() error("injected", 0) end end,
	function(results, _, scenario) expect(scenario, results, "launch.tile", "FAIL", "injected") end)

variation("tiling: a span that is not kept reads CHECK",
	function(_, s) s.tex.GetTexCoord = function() return 0, 0, 0, 1, 1, 0, 1, 1 end end,
	function(results, _, scenario) expect(scenario, results, "launch.tile", "CHECK", "would not repeat") end)

variation("tiling: no way to read the span back reads CHECK",
	function(_, s) s.tex.GetTexCoord = nil end,
	function(results, _, scenario) expect(scenario, results, "launch.tile", "CHECK", "cannot read the span back") end)

variation("animations: no CreateAnimationGroup reads FAIL",
	function(_, s) s.animFrame.CreateAnimationGroup = nil end,
	function(results, _, scenario) expect(scenario, results, "launch.anim", "FAIL", "no look can animate") end)

variation("animations: a kind the client refuses reads FAIL",
	function(_, s)
		local group = s.animFrame:CreateAnimationGroup()
		local create = group.CreateAnimation
		group.CreateAnimation = function(self, kind)
			if kind == "Rotation" then error("injected", 0) end
			return create(self, kind)
		end
		s.animFrame.CreateAnimationGroup = function() return group end
	end,
	function(results, _, scenario) expect(scenario, results, "launch.anim", "FAIL", "CreateAnimation(Rotation)") end)

variation("animations: a setting the client lacks reads CHECK",
	function(_, s)
		local group = s.animFrame:CreateAnimationGroup()
		local create = group.CreateAnimation
		group.CreateAnimation = function(self, kind)
			local a = create(self, kind)
			a.SetScaleFrom = nil
			return a
		end
		s.animFrame.CreateAnimationGroup = function() return group end
	end,
	function(results, _, scenario) expect(scenario, results, "launch.anim", "CHECK", "SetScaleFrom") end)

-- Keys and controllers
do
	local scenario = "selftest-launch: the key glyphs, answered and not"
	session(scenario, {}, function(ns)
		local results = run(ns)
		expect(scenario, results, "launch.keys", "CHECK", "GetBindingText is missing")
		local restore = Mock.withBindingText()
		local cvars = { GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateCtrl = "PADRTRIGGER", GamePadEmulateAlt = "PADRSHOULDER",
			GamePadEnable = "1" }
		withGlobals({ GetCVar = function(name) return cvars[name] end }, function()
			results = run(ns)
			expect(scenario, results, "launch.keys", "PASS", "GetBindingText(SHIFT-PAD1)")
			expect(scenario, results, "launch.keys", "PASS", "GamePadEmulateShift=\"PADLTRIGGER\"")
			expect(scenario, results, "launch.keys", "PASS", "the chip shows PAD1 -> ")
			-- No CVars to read: the chip falls back to the client's own short form.
			withGlobals({ GetCVar = "NIL" }, function()
				results = run(ns)
				expect(scenario, results, "launch.keys", "CHECK", "cannot be read")
			end)
			-- A client that answers nothing for a short form.
			withGlobals({ GetBindingText = function(key, short) if short then return "" end return key end }, function()
				results = run(ns)
				expect(scenario, results, "launch.keys", "CHECK", "no short text for PAD1")
			end)
			withGlobals({ GetBindingText = function() error("injected", 0) end }, function()
				results = run(ns)
				expect(scenario, results, "launch.keys", "FAIL", "threw")
			end)
		end)
		restore()
		everyCheckReports(scenario, ns, results)
	end)
end

-- Tooltip
variation("a tooltip that cannot be anchored reads FAIL",
	function(_, s)
		s.tip = CreateFrame("GameTooltip", nil, UIParent)
		-- Only an anchor to the prompt is refused, the game's own place is fine.
		s.tip.SetPoint = function(_, _, rel) if rel ~= UIParent then error("injected", 0) end end
	end,
	function(results, _, scenario) expect(scenario, results, "launch.tooltip", "FAIL", "cannot be anchored above the prompt") end)

variation("an anchor the client reads back differently reads CHECK",
	function(_, s) s.tip = CreateFrame("GameTooltip", nil, UIParent) s.tip.GetPoint = function() return "CENTER", UIParent, "CENTER", 0, 0 end end,
	function(results, _, scenario) expect(scenario, results, "launch.tooltip", "CHECK", "reads another anchor back") end)

variation("no default anchor reads CHECK",
	function() local was = GameTooltip_SetDefaultAnchor GameTooltip_SetDefaultAnchor = nil return function() GameTooltip_SetDefaultAnchor = was end end,
	function(results, _, scenario) expect(scenario, results, "launch.tooltip", "CHECK", "no default anchor") end)

variation("a default anchor that throws reads FAIL",
	function() local was = GameTooltip_SetDefaultAnchor GameTooltip_SetDefaultAnchor = function() error("injected", 0) end return function() GameTooltip_SetDefaultAnchor = was end end,
	function(results, _, scenario) expect(scenario, results, "launch.tooltip", "FAIL", "GameTooltip_SetDefaultAnchor threw") end)

variation("a Shift that cannot be read reads CHECK",
	function() local was = IsShiftKeyDown IsShiftKeyDown = nil return function() IsShiftKeyDown = was end end,
	function(results, _, scenario) expect(scenario, results, "launch.tooltip", "CHECK", "Shift cannot be read") end)

variation("a prompt that cannot be measured reads CHECK",
	function(ns)
		local button = ns.Prompt.regions.button
		local top = button.GetTop
		button.GetTop = function() return nil end
		return function() button.GetTop = top end
	end,
	function(results, _, scenario) expect(scenario, results, "launch.tooltip", "CHECK", "cannot be measured") end)

do
	local scenario = "selftest-launch: the game's tooltip is never the one tried"
	session(scenario, {}, function(ns)
		local touched = {}
		local setOwner, setPoint = GameTooltip.SetOwner, GameTooltip.SetPoint
		GameTooltip.SetOwner = function(...) touched[#touched + 1] = "SetOwner" return setOwner(...) end
		GameTooltip.SetPoint = function(...) touched[#touched + 1] = "SetPoint" return setPoint(...) end
		run(ns)
		GameTooltip.SetOwner, GameTooltip.SetPoint = setOwner, setPoint
		if #touched > 0 then fail(scenario, "the game's tooltip got " .. table.concat(touched, ", ")) end
		local s = ns.Selftest.Scratch()
		if not s.tip or s.tip == GameTooltip then fail(scenario, "no tooltip of its own") end
	end)
end

-- Events
for _, row in ipairs({ { "UPDATE_MACROS", "CHECK", "action bar slot" }, { "UI_SCALE_CHANGED", "CHECK", "UI scale" },
	{ "DISPLAY_SIZE_CHANGED", "CHECK", "resolution" }, { "MODIFIER_STATE_CHANGED", "FAIL", "would throw" } }) do
	variation("an event the client refuses (" .. row[1] .. ") reads " .. row[2],
		function(_, s)
			local register = s.events.RegisterEvent
			s.events.RegisterEvent = function(self, event, ...)
				if event == row[1] then error("unknown event", 0) end
				return register(self, event, ...)
			end
		end,
		function(results, _, scenario)
			expect(scenario, results, "launch.events", row[2], row[1] .. " REFUSED")
			expect(scenario, results, "launch.events", row[2], row[3])
		end)
end

-- /cleartarget
variation("slash commands the client does not have read CHECK",
	function() local a, b = SLASH_CLEARTARGET1, SLASH_TARGET_LAST_TARGET1 SLASH_CLEARTARGET1, SLASH_TARGET_LAST_TARGET1 = nil, nil
		return function() SLASH_CLEARTARGET1, SLASH_TARGET_LAST_TARGET1 = a, b end end,
	function(results, _, scenario)
		expect(scenario, results, "launch.handback", "CHECK", "/cleartarget is not a registered slash command")
	end)

variation("a client with nothing targeted that still answers a GUID reads CHECK",
	function()
		local exists, guid = UnitExists, UnitGUID
		UnitExists = function() return false end
		UnitGUID = function() return "Player-1-target" end
		return function() UnitExists, UnitGUID = exists, guid end
	end,
	function(results, _, scenario)
		expect(scenario, results, "launch.handback", "CHECK", "UnitGUID still answers something")
	end)

variation("nothing targeted reads as the /cleartarget hand-back",
	function()
		local exists, guid = UnitExists, UnitGUID
		UnitExists = function() return false end
		UnitGUID = function(unit) if unit == "target" then return nil end return "Player-1-" .. tostring(unit) end
		return function() UnitExists, UnitGUID = exists, guid end
	end,
	function(results, _, scenario)
		expect(scenario, results, "launch.handback", "PASS", "a press hands back with /cleartarget")
	end)

-- The display
-- The handler for a new scale, with `during` true only inside it.
local function inHandler(ns, on, off)
	local handler = ns.addon.UI_SCALE_CHANGED
	ns.addon.UI_SCALE_CHANGED = function(self, ...)
		on()
		local ok, err = pcall(handler, self, ...)
		off()
		if not ok then error(err, 0) end
	end
	return function() ns.addon.UI_SCALE_CHANGED = handler end
end

variation("a restyle that errors reads FAIL",
	function(ns)
		local apply = ns.Prompt.ApplyStyle
		local failing = false
		ns.Prompt.ApplyStyle = function(self, ...)
			if failing then error("injected", 0) end
			return apply(self, ...)
		end
		local undo = inHandler(ns, function() failing = true end, function() failing = false end)
		return function() undo() ns.Prompt.ApplyStyle = apply end
	end,
	function(results, _, scenario) expect(scenario, results, "launch.display", "FAIL", "raised an error") end)

variation("a restyle that moves the prompt reads CHECK",
	function(ns)
		local apply = ns.Prompt.ApplyStyle
		local button = ns.Prompt.regions.button
		local moving = false
		ns.Prompt.ApplyStyle = function(self, ...)
			apply(self, ...)
			if moving then
				button:ClearAllPoints()
				button:SetPoint("TOP", UIParent, "TOP", 0, -5)
			end
		end
		local undo = inHandler(ns, function() moving = true end, function() moving = false end)
		return function() undo() ns.Prompt.ApplyStyle = apply end
	end,
	function(results, _, scenario) expect(scenario, results, "launch.display", "CHECK", "would move or resize the prompt") end)

variation("no handler for a display change reads CHECK",
	function(ns)
		local handler = ns.addon.DISPLAY_SIZE_CHANGED
		ns.addon.DISPLAY_SIZE_CHANGED = nil
		return function() ns.addon.DISPLAY_SIZE_CHANGED = handler end
	end,
	function(results, _, scenario) expect(scenario, results, "launch.display", "CHECK", "DISPLAY_SIZE_CHANGED has no handler") end)

-- The looks
do
	local scenario = "selftest-launch: a look that throws is its own FAIL and the style still goes back"
	session(scenario, {}, function(ns)
		local ribbon = ns.Looks.Get("ribbon")
		local apply = ribbon.Apply
		ribbon.Apply = function() error("injected look", 0) end
		local p = ns.db.profile.prompt
		local results = run(ns)
		ribbon.Apply = apply
		everyCheckReports(scenario, ns, results)
		expect(scenario, results, "launch.look.ribbon", "FAIL", "injected look")
		expect(scenario, results, "launch.look.letter", "PASS")
		expect(scenario, results, "launch.look.glass", "PASS")
		if rawget(p, "style") ~= "glass" then fail(scenario, "the style is " .. tostring(rawget(p, "style"))) end
		expect(scenario, results, "launch.looks", "PASS", "put the style back to")
	end)

	scenario = "selftest-launch: a look that does not end up on the prompt is a FAIL"
	session(scenario, {}, function(ns)
		local look = ns.Looks.Get("toast")
		local apply = ns.Prompt.ApplyStyle
		-- The prompt keeps wearing what it wore.
		ns.Prompt.ApplyStyle = function(self, ...)
			if ns.db.profile.prompt.style == "toast" then return end
			return apply(self, ...)
		end
		local results = run(ns)
		ns.Prompt.ApplyStyle = apply
		expect(scenario, results, "launch.look.toast", "FAIL", "did not end up wearing it")
		local _ = look
	end)

	scenario = "selftest-launch: no mask on the icon of a look that cuts it reads CHECK"
	session(scenario, {}, function(ns)
		local icon = ns.Prompt.regions.icon
		icon.GetNumMaskTextures = function() return 0 end
		local results = run(ns)
		for _, key in ipairs({ "ribbon", "letter", "leather" }) do
			expect(scenario, results, "launch.look." .. key, "CHECK", "no mask on it")
		end
	end)

	scenario = "selftest-launch: masks on the icon that are all hidden read CHECK, and the count says how many are shown"
	session(scenario, {}, function(ns)
		local icon = ns.Prompt.regions.icon
		local getMask = icon.GetMaskTexture
		local results = run(ns)
		expect(scenario, results, "launch.look.ribbon", "PASS")
		icon.GetMaskTexture = function(self, i)
			return { IsShown = function() return false end, real = getMask(self, i) }
		end
		results = run(ns)
		icon.GetMaskTexture = getMask
		for _, key in ipairs({ "ribbon", "letter", "leather" }) do
			expect(scenario, results, "launch.look." .. key, "CHECK", "no mask on it")
			expect(scenario, results, "launch.look." .. key, "CHECK", "(0 shown)")
		end
	end)

	scenario = "selftest-launch: a Letter with nothing clipping reads CHECK"
	session(scenario, {}, function(ns)
		local make = CreateFrame
		local results
		-- Every frame made from now on answers that it does not clip.
		withGlobals({ CreateFrame = function(...)
			local f = make(...)
			f.DoesClipChildren = function() return false end
			return f
		end }, function() results = run(ns) end)
		expect(scenario, results, "launch.look.letter", "CHECK", "no frame clips its children")
	end)

	scenario = "selftest-launch: a Manners call that throws inside a check is that check's FAIL"
	session(scenario, {}, function(ns)
		local short = ns.Looks.ShortKey
		ns.Looks.ShortKey = function() error("injected key", 0) end
		local results
		withGlobals({ GetBindingText = function(key) return key end }, function() results = run(ns) end)
		ns.Looks.ShortKey = short
		everyCheckReports(scenario, ns, results)
		expect(scenario, results, "launch.keys", "FAIL", "threw")
	end)

	scenario = "selftest-launch: a check that errors outright is a FAIL with the error"
	session(scenario, {}, function(ns)
		local fns = {}
		for _, check in ipairs(ns.Selftest.LAUNCH) do
			if check.id == "launch.font" then fns.run = check.run check.run = function() error("injected check", 0) end end
		end
		local results = run(ns)
		for _, check in ipairs(ns.Selftest.LAUNCH) do if check.id == "launch.font" then check.run = fns.run end end
		expect(scenario, results, "launch.font", "FAIL", "threw: injected check")
		for _, check in ipairs(ns.Selftest.LAUNCH) do
			if not result(results, check.id) then fail(scenario, check.id .. " never ran after the font check threw") end
		end
	end)
end

-- ------------------------------------------------------------------ 6
-- The picker's cards: the little card, and the window's own when drawn.
do
	local scenario = "selftest-launch: the picker's cards, drawn and not"
	session(scenario, {}, function(ns)
		local results = run(ns)
		expect(scenario, results, "launch.picker", "PASS", "the window's cards are not drawn yet")
		ns.OpenOptions("appearance", true)
		ns.Prompt:ExitTest()
		results = run(ns)
		expect(scenario, results, "launch.picker", "PASS", "the window's own cards: 9 shown, 9 with the live icon")
		local row = ns.WindowUI.RowFor("appearance.style")
		local hidden
		for _, card in ipairs(row.cards) do
			if card.iconFile ~= nil and card:IsShown() then hidden = card break end
		end
		if not hidden then
			fail(scenario, "no card has a live icon")
			return
		end
		hidden.icon:Hide()
		results = run(ns)
		expect(scenario, results, "launch.picker", "CHECK", "has its icon hidden")
	end)
end

-- ------------------------------------------------------------------ 7
-- The listening after the calls: events straight away are ordinary, events
-- that go on are a loop.
do
	local scenario = "selftest-launch: UPDATE_MACROS after the calls, ordinary and endless"
	session(scenario, {}, function(ns)
		ownMacro(false)
		local results, finish = ns.Selftest.RunLaunch({ createMacro = false })
		local s = ns.Selftest.Scratch()
		local onEvent = s.events.scripts.OnEvent
		for _ = 1, 6 do onEvent(s.events, "UPDATE_MACROS") end
		finish()
		expect(scenario, results, "launch.macro.events", "PASS", "6 UPDATE_MACROS")
		if s.events._events and s.events._events.UPDATE_MACROS then fail(scenario, "still listening afterwards") end

		results, finish = ns.Selftest.RunLaunch({ createMacro = false })
		onEvent(s.events, "UPDATE_MACROS")
		Mock.advance(0.4)
		onEvent(s.events, "UPDATE_MACROS")
		finish()
		expect(scenario, results, "launch.macro.events", "CHECK", "may be answering in a loop")
	end)
end

-- ------------------------------------------------------------------ 8
-- The command: `launch` runs the usual checks and the launch checks, in one
-- frame, with one timer for the listening; the report opens with the launch
-- summary and is in the box; plain `selftest` has no launch section.
do
	local scenario = "selftest-launch: the command"
	session(scenario, {}, function(ns)
		Mock.printed = {}
		ns.addon:HandleSlash("selftest")
		if ns.Selftest.last:find("Launch checks:", 1, true) then fail(scenario, "plain /manners selftest ran the launch checks") end
		ns.CloseOptions()

		Mock.printed, Mock.timers = {}, {}
		ns.addon:HandleSlash("selftest launch")
		if listenTimers() ~= 1 then fail(scenario, ("%d timers for the listening, wanted one"):format(listenTimers())) end
		ns.addon:HandleSlash("selftest launch")
		if not table.concat(Mock.printed, " / "):find("still running", 1, true) then
			fail(scenario, "a second launch while the first listens said nothing")
		end
		Mock.runTimers(1)
		local text = ns.Selftest.last
		local top = {}
		for line in text:gmatch("[^\n]+") do top[#top + 1] = line if #top >= 4 then break end end
		if not (top[3] or ""):match("^Launch checks: %d+ PASS, %d+ CHECK, %d+ FAIL") then
			fail(scenario, "the third line of the report is " .. tostring(top[3]))
		end
		if not text:find("[Launch checks]", 1, true) then fail(scenario, "no launch section") end
		if not text:find("[Client]", 1, true) or not text:find(" checks: ", 1, true) then
			fail(scenario, "the usual checks are not in the same report")
		end
		if ns.OptionsPage.selftestText ~= text then fail(scenario, "the report is not in its box") end
		local said = table.concat(Mock.printed, " / ")
		if not said:find("launch checks: %d+ passed, %d+ to check, %d+ failed") then fail(scenario, "no launch line in chat: " .. said) end
		if not said:find("self%-test: %d+ passed, %d+ warnings, %d+ failed") then fail(scenario, "no self-test line in chat: " .. said) end
		ns.CloseOptions()

		-- Case, the alias, and a word that is not the flag.
		Mock.timers = {}
		ns.addon:HandleSlash("check LAUNCH")
		if listenTimers() ~= 1 then fail(scenario, "/manners check LAUNCH did not start the launch checks") end
		Mock.runTimers(1)
		Mock.timers = {}
		ns.addon:HandleSlash("selftest launchx")
		if listenTimers() ~= 0 then fail(scenario, "a word that is not the flag started the launch checks") end
	end)

	scenario = "selftest-launch: the report is one pasteable block with the verdicts in order"
	session(scenario, {}, function(ns)
		local results, finish = ns.Selftest.RunLaunch({ createMacro = true })
		finish()
		local text = ns.Selftest.Report({}, results)
		if text:find("\t", 1, true) then fail(scenario, "a tab in the report") end
		for line in text:gmatch("[^\n]+") do
			if #line > 700 then fail(scenario, "a line of " .. #line .. " characters: " .. line:sub(1, 60)) end
		end
		local order = {}
		for line in text:gmatch("[^\n]+") do
			local verdict, label = line:match("^(%u+)  ([^:]+):")
			if VERDICTS[verdict or ""] then order[#order + 1] = label end
		end
		if #order < 20 then fail(scenario, ("only %d verdict lines"):format(#order)) end
		-- Nothing about any other addon, and no Russian, in what the report says.
		if text:find("[\208\209]") then fail(scenario, "Cyrillic in the report") end
	end)
end
