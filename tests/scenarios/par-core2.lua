-- The fight's three weak points from the review of 2026-11-15 (Prompt/Fight.lua,
-- Prompt/Macro.lua, Prompt/Refresh.lua, Clicks.lua's bar macro):
--
--   1. what the pull arms is somebody worth pressing for, never a passer-by
--      remembered for a few seconds after they walked off;
--   2. the hand-back of a macro armed for a fight runs only when the /target
--      before it found somebody friendly, so a press cannot take a mob away;
--   3. the fight's rota goes round once: nobody it has pressed for in this
--      fight is pressed for again, and the bar macro, which cannot step, says so
--      where it is made.
--
-- These hold Manners to the mock's model of the secure handlers and of the
-- client's macro runner (tests/mockwidgets.lua, tests/mockmacros.lua), not to
-- the client: STATUS.md lists what a real fight must show.
--
-- Every name starts with "par-core2:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local BINDING = "CLICK MannersPrompt:LeftButton"

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

-- The pull as the client orders it: PLAYER_REGEN_DISABLED just before the
-- lockdown, then the lockdown, then the state driver's next frame.
local function pull(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_DISABLED()
	Mock.inCombat = true
	Mock.frameEvent("PLAYER_REGEN_DISABLED")
	Mock.runTimers(0)
end

local function release(ns)
	Mock.inCombat = false
	ns.addon:PLAYER_REGEN_ENABLED()
	Mock.frameEvent("PLAYER_REGEN_ENABLED")
	Mock.runTimers(0)
end

local function castsSince(n)
	local out = {}
	for i = n + 1, #Mock.castLog do
		local e = Mock.castLog[i]
		if e.spell and not e.refused then out[#out + 1] = e end
	end
	return out
end

local function guarded(ns, scenario)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- ------------------------------------------------------------------ 1
-- Passers-by on nameplates, a mage with "Passers-by" on. `names` is the table
-- the mock's units read their names from; `plates` puts exactly these people
-- on nameplates (and takes everybody else off).
local function crowd(scenario, body)
	Mock.reset()
	Mock.class = "MAGE"
	local names = {}
	local restore = strangers(names)
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		ns.db.profile.sources.strangers = true
		local function tick(n)
			for _ = 1, n do
				Mock.advance(0.4)
				Mock.runTimers(0)
				ns.addon:Tick()
			end
		end
		local function plates(list)
			for k in pairs(names) do names[k] = nil end
			for k in pairs(ns.nameplateUnits) do ns.nameplateUnits[k] = nil end
			for i, n in ipairs(list) do
				names["nameplate" .. i] = n
				ns.nameplateUnits["nameplate" .. i] = true
			end
		end
		body(ns, tick, plates)
		guarded(ns, scenario)
	end)
	Mock.inCombat = false
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function armedAt(ns)
	local text = ns.Prompt:GetButton():GetAttribute("macrotext1")
	return type(text) == "string" and text:match("/target ([^\n]+)") or nil, text
end

local GONE = { { "Anna", "Aim" }, { "Bert", "Beside" }, { "Cora", "Cole" } }
local GONE_NAMES = { ["Anna Aim"] = true, ["Bert Beside"] = true, ["Cora Cole"] = true }

crowd("par-core2: a pull three seconds after a crowd walked off arms none of them", function(ns, tick, plates)
	local scenario = "par-core2: a pull three seconds after a crowd walked off arms none of them"
	plates(GONE)
	tick(8)
	local before = armedAt(ns)
	if not (before and GONE_NAMES[before]) then
		fail(scenario, "SKIPPED -- the crowd was never on the prompt: " .. tostring(before))
		return
	end
	-- They walk off; the memory of them still stands three seconds later.
	plates({})
	tick(7)
	local still = armedAt(ns)
	if not (still and GONE_NAMES[still]) then
		fail(scenario, "SKIPPED -- the memory had already let them go before the pull: " .. tostring(still))
		return
	end
	pull(ns)
	local who, text = armedAt(ns)
	if who then fail(scenario, "the pull froze the prompt on " .. who .. ", who left before it: " .. flat(text)) end
	local header = ns.Prompt:FightHeader()
	local n = header and header:GetAttribute("manners-rota-n") or 0
	if n > 0 then
		local held = {}
		for i = 1, n do held[#held + 1] = flat(header:GetAttribute("manners-rota-" .. i)) end
		fail(scenario, "the fight's rota is made of people who left: " .. table.concat(held, " || "))
	end
	if ns.Prompt:GetButton():IsShown() then fail(scenario, "the panel stays up for the fight over nobody") end
	tick(10)
	if ns.Prompt:GetButton():IsShown() then fail(scenario, "the panel came up in the fight over nobody") end
	release(ns)
end)

crowd("par-core2: at a pull with one passer-by still beside you and two gone, the rota is the one beside you", function(ns, tick, plates)
	local scenario = "par-core2: at a pull with one passer-by still beside you and two gone, the rota is the one beside you"
	plates(GONE)
	tick(8)
	-- Anna and Cora walk off; Bert stays on his nameplate.
	plates({ { "Bert", "Beside" } })
	tick(5)
	pull(ns)
	local who, text = armedAt(ns)
	if who ~= "Bert Beside" then fail(scenario, "the pull armed " .. tostring(who) .. ", not the one still beside you: " .. flat(text)) end
	local header = ns.Prompt:FightHeader()
	local n = header and header:GetAttribute("manners-rota-n") or 0
	for i = 1, n do
		local entry = flat(header:GetAttribute("manners-rota-" .. i))
		if entry:find("Anna Aim", 1, true) or entry:find("Cora Cole", 1, true) then
			fail(scenario, "the rota holds somebody who left: " .. entry)
		end
	end
	release(ns)
end)

-- A favour owed is not a memory of where somebody stood: the owed fallback,
-- offered by name with no token, is still armed at the pull as before.
crowd("par-core2: a favour owed with no token is still armed at the pull", function(ns, tick, plates)
	local scenario = "par-core2: a favour owed with no token is still armed at the pull"
	plates({})
	owe(ns, "Dana Dorn")
	tick(3)
	if armedAt(ns) ~= "Dana Dorn" then fail(scenario, "SKIPPED -- the favour is not on the prompt: " .. tostring(armedAt(ns))) return end
	pull(ns)
	if armedAt(ns) ~= "Dana Dorn" then fail(scenario, "the pull let a favour owed go: " .. tostring(armedAt(ns))) end
	release(ns)
end)

-- Out of a fight the memory still keeps a passer-by on the prompt for a few
-- seconds after the cursor or the nameplate left them (the 1.1.0 report): the
-- pull alone leaves them out.
crowd("par-core2: out of a fight a passer-by who walked off is still offered for a few seconds", function(ns, tick, plates)
	local scenario = "par-core2: out of a fight a passer-by who walked off is still offered for a few seconds"
	plates({ { "Anna", "Aim" } })
	tick(4)
	plates({})
	tick(5)
	if armedAt(ns) ~= "Anna Aim" then fail(scenario, "two seconds after she walked off the prompt holds " .. tostring(armedAt(ns))) end
end)

-- Everybody the fight's rota held walked off during it: the fight over, the
-- fuse keeps the panel up a moment as it stands, and its second line must not
-- still say where the fight's rota stood.
crowd("par-core2: the fight over with nobody left, the second line no longer speaks of the fight", function(ns, tick, plates)
	local scenario = "par-core2: the fight over with nobody left, the second line no longer speaks of the fight"
	local B, R = ns.Prompt:GetButton(), ns.Prompt.regions
	plates(GONE)
	tick(8)
	pull(ns)
	tick(2)
	local during = tostring(R.subText:GetText())
	if not during:find("in a fight", 1, true) then fail(scenario, "SKIPPED -- no rota line in the fight: " .. during) return end
	plates({})
	tick(40)
	release(ns)
	tick(1)
	local after = tostring(R.subText:GetText())
	if B:IsShown() and after:find("in a fight", 1, true) then
		fail(scenario, "after the fight the panel still reads " .. after)
	end
end)

-- ------------------------------------------------------------------ 2
-- Three people owed on nameplates, Forever unless named, the prompt up on one
-- of them (fight-rota.lua's own fixture).
local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bob", "Bright" }, nameplate3 = { "Cara", "Cole" } }
local NAMES = { "Anna Aim", "Bob Bright", "Cara Cole" }

local function owedThree(scenario, body, opts)
	opts = opts or {}
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	local restore = strangers(opts.people or PEOPLE)
	local ok, err = true, nil
	local ns = load(scenario)
	if ns then
		ok, err = pcall(function()
			freshPrompt(ns, scenario)
			Mock.timers = {}
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			if opts.edit then opts.edit(ns.db.profile, ns) end
			ns.Prompt:ApplyStyle()
			for _, name in ipairs(opts.owed or NAMES) do owe(ns, name) end
			ns.addon:Tick()
			Mock.runTimers(0)
			body(ns, scenario)
			guarded(ns, scenario)
		end)
	end
	Mock.inCombat = false
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function press()
	Mock.advance(2)
	Mock.pressBinding(BINDING)
end

local BOAR = { unit = "mob", name = "Boar", hostile = true }
local EARLIER = { unit = "nameplate9", name = "Someone Earlier" }

-- The one whose turn it is has gone from the client's view since the pull:
-- the /target finds nobody, the mob stays targeted, and the hand-back must
-- not then switch you off it.
owedThree("par-core2: a press in a fight whose /target finds nobody leaves your mob targeted", function(ns, scenario)
	pull(ns)
	local text = ns.Prompt:GetButton():GetAttribute("macrotext1") or ""
	local first = text:match("/target ([^\n]+)")
	if not first then fail(scenario, "SKIPPED -- nothing armed at the pull") return end
	Mock.runTarget, Mock.runLastTarget = BOAR, EARLIER
	for unit, n in pairs(PEOPLE) do
		if n[1] .. " " .. n[2] == first then Mock.unitNames[unit] = nil end
	end
	press()
	local now = Mock.runTarget and Mock.runTarget.name
	if now ~= "Boar" then fail(scenario, "a press at " .. first .. ", who is gone, left you targeting " .. tostring(now) .. ", not your mob: " .. flat(text)) end
	-- The next one is there: the press reaches them and gives the mob back.
	local before = #Mock.castLog
	press()
	now = Mock.runTarget and Mock.runTarget.name
	if now ~= "Boar" then fail(scenario, "a press that reached somebody handed back " .. tostring(now) .. ", not your mob") end
	local casts = castsSince(before)
	if #casts ~= 1 or casts[1].target == "Boar" then
		fail(scenario, "the second press did not cast at the next person: " .. tostring(casts[1] and casts[1].target))
	end
	release(ns)
end)

-- With no rota (one person owed) the macro the pull armed runs every press:
-- the same, and the shape is the one the client parses: a bare [help], no
-- [@unit].
owedThree("par-core2: the macro armed for a fight hands back only after a /target that found somebody friendly", function(ns, scenario)
	-- Out of a fight the hand-back is as it was: the scan arms it for what is
	-- targeted at that moment.
	local out = ns.Prompt:GetButton():GetAttribute("macrotext1") or ""
	local tail = out:match("([^\n]+)$")
	if tail ~= "/targetlasttarget" and tail ~= "/cleartarget" then fail(scenario, "out of a fight the macro ends " .. tostring(tail)) end
	pull(ns)
	local text = ns.Prompt:GetButton():GetAttribute("macrotext1") or ""
	local last = text:match("([^\n]+)$")
	if last ~= "/targetlasttarget [help]" then fail(scenario, "the fight's macro ends " .. tostring(last) .. ": " .. flat(text)) end
	if text:find("@", 1, true) then fail(scenario, "the fight's macro names a unit in a conditional: " .. flat(text)) end
	Mock.runTarget, Mock.runLastTarget = BOAR, EARLIER
	Mock.unitNames.nameplate1 = nil
	press()
	if not (Mock.runTarget and Mock.runTarget.name == "Boar") then
		fail(scenario, "with Anna gone a press left you targeting " .. tostring(Mock.runTarget and Mock.runTarget.name))
	end
	release(ns)
end, { people = { nameplate1 = { "Anna", "Aim" } }, owed = { "Anna Aim" } })

-- The bar macro the pull writes carries the same hand-back, is still Manners'
-- own (Clicks.lua, Shaped), and keeps the mob too.
owedThree("par-core2: the bar macro in a fight keeps your mob when its /target finds nobody", function(ns, scenario)
	ns.CreateClickMacro()
	Mock.dropOnBar(2)
	for _ = 1, 3 do Mock.advance(1) ns.addon:Tick() Mock.runTimers(0) end
	pull(ns)
	local m = Mock.macroList[GetMacroIndexByName("Manners")]
	local body = m and m.body or ""
	if not body:find("/targetlasttarget [help]", 1, true) then fail(scenario, "the bar macro written at the pull is " .. flat(body)) return end
	-- Read back after the fight as Manners' own, not as lines somebody edited.
	Mock.runTarget, Mock.runLastTarget = BOAR, EARLIER
	Mock.unitNames.nameplate1 = nil
	Mock.advance(2)
	Mock.pressBar(2)
	if not (Mock.runTarget and Mock.runTarget.name == "Boar") then
		fail(scenario, "a bar press at somebody gone left you targeting " .. tostring(Mock.runTarget and Mock.runTarget.name))
	end
	release(ns)
end, { people = { nameplate1 = { "Anna", "Aim" } }, owed = { "Anna Aim" } })

-- A body a fight left in the macro (a /reload or a crash in one) is Manners'
-- own at the next login, and written over; the same hand-back on any other
-- conditional is the player's.
local BAR_LINE = "/click MannersBar"
for i, case in ipairs({
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/targetlasttarget [help]", ours = true },
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/targetlasttarget [harm]" },
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/cleartarget [help]" },
}) do
	local scenario = ("par-core2: the fight's bar macro left from a session before is Manners' own (%d)"):format(i)
	Mock.reset()
	Mock.setFlavour("camelot")
	local restore = strangers({})
	Mock.macroList[1] = { name = "Manners", icon = "INV_MISC_NOTE_03", body = case[1] }
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			ns.addon:OnInitialize()
			ns.addon:OnEnable()
			Mock.runTimers(3)
			local now = Mock.macroList[1] and Mock.macroList[1].body
			local state = ns.BarMacroState()
			if case.ours and (state ~= "ours" or now ~= BAR_LINE) then
				fail(scenario, ("%s, a shape Manners writes, is %s and holds %s"):format(flat(case[1]), tostring(state), flat(now)))
			elseif not case.ours and (state ~= "foreign" or now ~= case[1]) then
				fail(scenario, ("%s, a body of the player's, is counted %s and holds %s"):format(flat(case[1]), tostring(state), flat(now)))
			end
			guarded(ns, scenario)
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	restore()
	Mock.reset()
end

-- /manners selftest launch is where the game answers whether [help] reads the
-- target as UnitCanAssist does: said in the hand-back's check, and a client
-- whose parser disagrees reads CHECK.
for i, case in ipairs({
	{ target = { unit = "nameplate1", name = "Anna Aim" }, assist = true, status = "PASS", says = '[help] answers "yes"' },
	{ target = BOAR, assist = false, status = "PASS", says = '[help] answers "no"' },
	{ target = BOAR, assist = true, status = "CHECK", says = "does not read the target as UnitCanAssist does" },
}) do
	local scenario = ("par-core2: the launch check says what [help] reads (%d)"):format(i)
	Mock.reset()
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local exists, assist = UnitExists, UnitCanAssist
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		if not (ns.Selftest and ns.Selftest.RunLaunch) then fail(scenario, "SKIPPED -- SelftestLaunch.lua did not load") return end
		UnitExists = function() return true end
		UnitCanAssist = function() return case.assist end
		Mock.runTarget = case.target
		local results, finish = ns.Selftest.RunLaunch({ createMacro = false })
		finish()
		local found
		for _, r in ipairs(results) do
			if r.id == "launch.handback" then found = r end
		end
		if not found then
			fail(scenario, "the hand-back's check reported nothing")
		elseif found.status ~= case.status or not tostring(found.value):find(case.says, 1, true) then
			fail(scenario, ("the hand-back's check reads %s: %s"):format(tostring(found.status), tostring(found.value)))
		end
	end)
	UnitExists, UnitCanAssist = exists, assist
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
