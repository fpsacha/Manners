-- The fight's rota (Prompt/Fight.lua): with the prompt left up, each press in
-- a fight moves the button on to the next person the queue held as the fight
-- began, instead of casting at the one person again and again.
--
-- An addon's Lua cannot change what the button casts in a fight, so the steps
-- are a secure snippet's, wrapped round the prompt's click. These hold Manners
-- to the mock's model of SecureHandlerWrapScript and Wrapped_Click
-- (tests/mockwidgets.lua, "secure handlers") and of the client's own click
-- (tests/mockmacros.lua), not to the client.
--
-- Every name starts with "fight-rota:".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local BINDING = "CLICK MannersPrompt:LeftButton"
local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bob", "Bright" }, nameplate3 = { "Cara", "Cole" } }
local NAMES = { "Anna Aim", "Bob Bright", "Cara Cole" }

local function flat(text) return (tostring(text):gsub("\n", " / ")) end

local function castsSince(n)
	local out = {}
	for i = n + 1, #Mock.castLog do
		local e = Mock.castLog[i]
		if e.spell and not e.refused then out[#out + 1] = e end
	end
	return out
end

-- Forever unless a scenario names the client: three people on nameplates, all
-- owed, the prompt up on one of them.
local function with(scenario, body, opts)
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
			local p = ns.db.profile.prompt
			if opts.edit then opts.edit(p, ns) end
			ns.Prompt:ApplyStyle()
			for _, name in ipairs(opts.owed or NAMES) do owe(ns, name) end
			ns.addon:Tick()
			Mock.runTimers(0)
			body(ns, scenario, p)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
	end
	Mock.inCombat = false
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

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

-- Who the button's macro targets now.
local function aimed(ns)
	local text = ns.Prompt:GetButton():GetAttribute("macrotext1") or ""
	return text:match("/target ([^\n]+)"), text
end

-- One press of the prompt's key, the cooldown over first.
local function press()
	Mock.advance(2)
	Mock.pressBinding(BINDING)
end

-- ------------------------------------------------------------------ 1
for _, flavour in ipairs({ "camelot", "vanilla", "tbc", "mists", "mainline" }) do
	with("fight-rota: each press in a fight casts at the next person the pull's queue held (" .. flavour .. ")", function(ns, scenario)
		local button = ns.Prompt:GetButton()
		local header = ns.Prompt:FightHeader()
		if not (header and header.rotaWrapped) then fail(scenario, "the prompt's click is not wrapped for the rota") return end
		if button:GetAttribute("type1") ~= "macro" then fail(scenario, "SKIPPED -- the prompt is not armed before the fight") return end
		Mock.protect(button)
		pull(ns)
		local n = header:GetAttribute("manners-rota-n")
		if n ~= 3 then fail(scenario, "the rota holds " .. tostring(n) .. " of the three people owed") return end
		-- Six presses: everybody once, in the queue's order, and then round again.
		Mock.protectedCalls = {}
		local order, before = {}, #Mock.castLog
		for i = 1, 6 do
			local who = aimed(ns)
			local named = ns.Prompt.state.current and ns.Prompt.state.current.name
			if named ~= who then
				fail(scenario, ("before press %d the panel is about %s and the button casts at %s"):format(i, tostring(named), tostring(who)))
			end
			order[i] = who
			press()
		end
		-- Three presses, three people (by whatever name this client's macro
		-- reaches them: Forever's two-part names, a name and its realm elsewhere).
		local seen, distinct = {}, 0
		for i = 1, 3 do
			if order[i] and not seen[order[i]] then
				seen[order[i]] = true
				distinct = distinct + 1
			end
		end
		if distinct ~= 3 then fail(scenario, "three presses reached " .. distinct .. " people: " .. table.concat(order, ", ")) end
		for i = 4, 6 do
			if order[i] ~= order[i - 3] then fail(scenario, "the rota does not come round in the same order: " .. table.concat(order, ", ")) end
		end
		-- The game cast at each of them, in that order.
		local casts = castsSince(before)
		if #casts ~= 6 then fail(scenario, #casts .. " casts went out for six presses") end
		for i, e in ipairs(casts) do
			-- (The mock logs its own two-word name for whoever the macro's
			-- /target reached by the name this client knows them under.)
			local want = tostring(order[i])
			if tostring(e.target):sub(1, #want) ~= want then
				fail(scenario, ("cast %d went at %s, not %s"):format(i, tostring(e.target), want))
			end
		end
		-- The addon's own code touched nothing protected: every step is the snippet's.
		if #Mock.protectedCalls > 0 then
			fail(scenario, "the addon's own code called " .. table.concat(Mock.protectedCalls, ", ") .. " on the secure button in the fight")
		end
		release(ns)
	-- Off Forever the fixtures' two-part names are a name and a realm, and a
	-- favour filed under Forever's spelling is a second person: there the
	-- three are passers-by, which is all this asks.
	end, { flavour = flavour, owed = flavour ~= "camelot" and {} or nil })
end

-- ------------------------------------------------------------------ 2
with("fight-rota: the panel says which of how many, and the press is filed on the person it cast at", function(ns, scenario)
	local r = ns.Prompt:Regions()
	pull(ns)
	Mock.advance(1)
	ns.addon:Tick()
	local sub = tostring(r.sub:GetText())
	if not sub:find("1 of 3", 1, true) then fail(scenario, "in a fight with a rota of three the second line reads " .. sub) end
	local first = aimed(ns)
	Mock.printed = {}
	press()
	local second = aimed(ns)
	if second == first then fail(scenario, "a press did not move the button on") return end
	-- The first person's favour is the one the press settles; the second's stands.
	Mock.advance(1)
	ns.addon:Tick()
	sub = tostring(r.sub:GetText())
	local name = tostring(r.name:GetText())
	if ns.Prompt:OutcomeLive() then
		Mock.advance(ns.Prompt.OUTCOME_SECONDS or 4)
		ns.addon:Tick()
		sub, name = tostring(r.sub:GetText()), tostring(r.name:GetText())
	end
	if not sub:find("2 of 3", 1, true) then fail(scenario, "after one press the second line reads " .. sub) end
	if not name:find((second:gsub(" .*", "")), 1, true) then fail(scenario, "after one press the panel names " .. name .. ", not " .. second) end
	if ns.owed[second] == nil then fail(scenario, "the press at " .. first .. " let " .. second .. "'s favour go") end
	release(ns)
end)

-- ------------------------------------------------------------------ 3
with("fight-rota: a right press and a press with one person owed step nothing", function(ns, scenario)
	local header = ns.Prompt:FightHeader()
	pull(ns)
	local first = aimed(ns)
	-- A right press casts nothing, so it steps nothing.
	ns.Prompt:GetButton():Click("RightButton", true)
	if header:GetAttribute("manners-rota-i") ~= 1 then fail(scenario, "a right press stepped the rota") end
	release(ns)
	if first == nil then fail(scenario, "SKIPPED -- nobody on the button") end
end)

with("fight-rota: one person owed is no rota, and the press keeps to them", function(ns, scenario)
	local header = ns.Prompt:FightHeader()
	pull(ns)
	if (header:GetAttribute("manners-rota-n") or 0) ~= 0 then fail(scenario, "a rota of " .. tostring(header:GetAttribute("manners-rota-n")) .. " for one person") end
	local first = aimed(ns)
	press()
	press()
	if aimed(ns) ~= first then fail(scenario, "with one person the button moved off them") end
	local sub = tostring(ns.Prompt:Regions().sub:GetText())
	if sub:find(" of ", 1, true) then fail(scenario, "with no rota the second line still counts: " .. sub) end
	release(ns)
end, { people = { nameplate1 = { "Anna", "Aim" } }, owed = { "Anna Aim" } })

-- ------------------------------------------------------------------ 4
with("fight-rota: switched off, a fight holds the prompt on the one person as before", function(ns, scenario)
	local header = ns.Prompt:FightHeader()
	pull(ns)
	if (header:GetAttribute("manners-rota-n") or 0) ~= 0 then fail(scenario, "switched off, the pull still made a rota") end
	local first = aimed(ns)
	press()
	press()
	if aimed(ns) ~= first then fail(scenario, "switched off, a press moved the button on") end
	release(ns)
	-- The switch is on the Look page, live while the prompt stays up in a fight.
	local control = H.findOption(ns.optionsTable, "fightRota")
	if not control then fail(scenario, "Look has no switch for the rota") return end
	if control.disabled() then fail(scenario, "the switch is greyed with the prompt left up") end
	ns.db.profile.prompt.hideInFight = true
	if not control.disabled() then fail(scenario, "the switch is live with the prompt hidden for the fight") end
end, { edit = function(p) p.fightRota = false end })

-- ------------------------------------------------------------------ 5
with("fight-rota: the prompt hidden for the fight has no rota, and its key casts nothing", function(ns, scenario)
	local header = ns.Prompt:FightHeader()
	pull(ns)
	if (header:GetAttribute("manners-rota-n") or 0) ~= 0 then fail(scenario, "a rota was armed on a prompt hidden for the fight") end
	local before = #Mock.castLog
	press()
	press()
	if #castsSince(before) > 0 then fail(scenario, "the hidden prompt's key cast in the fight") end
	if ns.Prompt:GetButton():GetAttribute("macrotext1") then fail(scenario, "a press put a macro back on the hidden prompt") end
	release(ns)
end, { edit = function(p) p.hideInFight = true end })

-- ------------------------------------------------------------------ 6
with("fight-rota: the fight over, the snippet steps nothing and the prompt is armed afresh", function(ns, scenario)
	local header = ns.Prompt:FightHeader()
	pull(ns)
	press()
	press()
	release(ns)
	if (header:GetAttribute("manners-rota-n") or 0) ~= 0 then fail(scenario, "the rota is still set after the fight") end
	if ns.Prompt.state.rota then fail(scenario, "the prompt still keeps the fight's rota") end
	Mock.advance(3)
	ns.addon:Tick()
	local who, text = aimed(ns)
	local current = ns.Prompt.state.current
	if not (who and current and current.name == who) then
		fail(scenario, "after the fight the panel is about " .. tostring(current and current.name) .. " and the button casts at " .. tostring(who))
	end
	-- A press now is the ordinary one: the snippet leaves the macro alone.
	local i = header:GetAttribute("manners-rota-i")
	press()
	if header:GetAttribute("manners-rota-i") ~= i then fail(scenario, "out of a fight a press still stepped the rota") end
	if text == nil then fail(scenario, "SKIPPED -- nothing armed after the fight") end
end)

-- ------------------------------------------------------------------ 7
with("fight-rota: a rota never holds more than its most, nor a macro that would not fit", function(ns, scenario)
	local header = ns.Prompt:FightHeader()
	pull(ns)
	local n = header:GetAttribute("manners-rota-n") or 0
	if n < 2 then fail(scenario, "SKIPPED -- no rota for a crowd: " .. tostring(n)) return end
	if n > ns.Prompt.ROTA_MAX then fail(scenario, "a rota of " .. n .. ", over its most of " .. ns.Prompt.ROTA_MAX) end
	local seen = {}
	for i = 1, n do
		local text = header:GetAttribute("manners-rota-" .. i)
		if type(text) ~= "string" or #text > ns.MACRO_LIMIT then
			fail(scenario, "entry " .. i .. " of the rota is " .. (type(text) == "string" and #text .. " characters" or tostring(text)))
		elseif seen[text] then
			fail(scenario, "the rota holds the same macro twice: " .. flat(text))
		else
			seen[text] = true
		end
		-- The cast alone: no line is said from a macro armed for a fight.
		if type(text) == "string" and (text:find("/say", 1, true) or text:find("/w ", 1, true) or text:find("/p ", 1, true)) then
			fail(scenario, "entry " .. i .. " of the rota speaks: " .. flat(text))
		end
	end
	release(ns)
end, {
	people = (function()
		local t = {}
		for i = 1, 16 do t["nameplate" .. i] = { "Person" .. string.char(64 + i), "Of" .. string.char(64 + i) } end
		return t
	end)(),
	owed = (function()
		local t = {}
		for i = 1, 16 do t[i] = "Person" .. string.char(64 + i) .. " Of" .. string.char(64 + i) end
		return t
	end)(),
})

-- ------------------------------------------------------------------ 8
-- A cast already in the rota that reaches somebody leaves them out of it: the
-- members of a group cast, and, where one cast lands on the whole group, the
-- rest of the group for that buff. The queue is the pull's own, with one of
-- its entries made a group cast by hand.
with("fight-rota: nobody a cast in the rota already reaches is given a press of their own", function(ns, scenario)
	local S = ns.Prompt.state
	local header = ns.Prompt:FightHeader()
	local queue = ns.BuildQueue()
	local top = S.current
	if not (top and #queue >= 3) then fail(scenario, "SKIPPED -- no queue of three to make a rota from") return end
	local others = {}
	for _, entry in ipairs(queue) do
		if entry.name ~= top.name then others[#others + 1] = entry end
	end
	-- The one on the prompt as a group cast that takes in the first of the others.
	top.groupCast = { spell = top.buff.ranks and top.buff.ranks[1], spellName = ns.BuffName(top.buff), members = { others[1].name } }
	S.fightQueue = queue
	ns.Prompt:ArmFightRota()
	local n = header:GetAttribute("manners-rota-n") or 0
	if n ~= 2 then
		fail(scenario, "with one of three taken in by a group cast the rota holds " .. n .. ", not 2")
	else
		for i = 1, n do
			local text = header:GetAttribute("manners-rota-" .. i) or ""
			if text:find(others[1].name, 1, true) then
				fail(scenario, "the rota casts again at somebody a group cast in it already reaches: " .. flat(text))
			end
		end
	end
	-- A cast that lands on the whole group: the rest of the group is reached.
	top.groupCast = nil
	local wide = ns.WIDE_CASTS
	ns.WIDE_CASTS = true
	top.inGroup = true
	for _, entry in ipairs(queue) do entry.inGroup = true end
	ns.Prompt:ArmFightRota()
	n = header:GetAttribute("manners-rota-n") or 0
	ns.WIDE_CASTS = wide
	if n ~= 0 then fail(scenario, "one cast lands on the whole group, and the rota still holds " .. n) end
end)
