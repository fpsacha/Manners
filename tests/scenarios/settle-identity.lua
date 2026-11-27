-- Cast events settle only the action their press can identify. A withheld
-- spell id and a matching target are not, by themselves, that identity.

local dir, H = ...
local fail, load = H.fail, H.load

local NAME = "Anna Aim"
local SHORT = "Anna"

local function session(scenario, class)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = class or "MAGE"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		Mock.secureActions = true
		Mock.eventSink = ns.addon
	end
	return ns
end

local function park(ns, buff, change)
	Mock.advance(1)
	ns.pendingClick = nil
	ns.Prompt:InvalidateMacro()
	local entry = {
		name = NAME, targetName = NAME, buff = buff, class = "PRIEST",
		reason = "owed", ranged = true, inGroup = true,
	}
	if change then change(entry) end
	ns.Prompt:ApplyTarget(entry)
	local button = ns.Prompt:GetButton()
	local post = button.scripts.PostClick
	if post then pcall(post, button, "LeftButton", true) end
	return ns.pendingClick, entry
end

local function guarded(ns, scenario)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- A matching target still does not identify a withheld or missing spell.
for _, hidden in ipairs({ { "missing", nil }, { "secret", Mock.SECRET } }) do
	local spelling, value = hidden[1], hidden[2]
	local scenario = "settle-identity: a " .. spelling .. "-id unrelated cast cannot settle the same target"
	local ns = session(scenario, "MAGE")
	if ns then
		local buff = ns.FindBuff("MAGE", "intellect")
		H.owe(ns, NAME)
		ns.db.profile.sources.asked = true
		ns.standingRequests[#ns.standingRequests + 1] = {
			name = SHORT, short = SHORT, full = NAME, keys = { intellect = true },
			at = GetTime(), expires = GetTime() + 60,
		}
		local pending = park(ns, buff)
		if not pending then
			fail(scenario, "SKIPPED -- the press filed nothing")
		else
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", NAME, "Cast-unrelated", value)
			if not ns.owed[NAME] then fail(scenario, "the unrelated cast cleared the favour") end
			if not ns.StillAsked(NAME, "intellect", GetTime()) then
				fail(scenario, "the unrelated cast served the request")
			end
		end
		guarded(ns, scenario)
	end
end

-- The ordinary plain id remains the complete identity of a correct cast.
do
	local scenario = "settle-identity: a known-id cast settles the owed request"
	local ns = session(scenario, "MAGE")
	if ns then
		local buff = ns.FindBuff("MAGE", "intellect")
		H.owe(ns, NAME)
		local pending = park(ns, buff)
		if not pending then
			fail(scenario, "SKIPPED -- the press filed nothing")
		else
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", pending.aimedAt, "Cast-known", buff.ranks[1])
			if ns.owed[NAME] then fail(scenario, "the matching known-id cast left the favour owed") end
		end
		guarded(ns, scenario)
	end
end

-- Group, wide, self-cast and try records all reach the same identity gate.
for _, case in ipairs({
	{ name = "selfcast", class = "MAGE", key = "intellect", landed = nil,
		pending = function(p) p.selfCast = true p.targeted = false end },
	{ name = "group", class = "MAGE", key = "intellect", landed = NAME,
		change = function(entry)
			entry.groupCast = { spell = entry.buff.group and entry.buff.group[1] or entry.buff.ranks[1],
				members = { NAME }, class = nil }
		end },
	{ name = "wide", class = "MAGE", key = "intellect", landed = NAME,
		pending = function(p) p.wideMembers = { NAME } end },
	{ name = "try", class = "MAGE", key = "intellect", landed = NAME,
		pending = function(p) p.targeted = nil p.aimedAt = nil end },
}) do
	local scenario = "settle-identity: " .. case.name .. " without spell identity does not settle"
	local ns = session(scenario, case.class)
	if ns then
		local buff = ns.FindBuff(case.class, case.key)
		H.owe(ns, NAME)
		local pending = park(ns, buff, case.change)
		if not pending then
			fail(scenario, "SKIPPED -- the press filed nothing")
		else
			if case.pending then case.pending(pending) end
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", case.landed, "Cast-" .. case.name, nil)
			if not ns.owed[NAME] then fail(scenario, case.name .. " settled from target or timing alone") end
		end
		guarded(ns, scenario)
	end
end

-- A bar event can be bound another way: the client names Manners' own macro
-- while its cast event is delivered. Its late refusal must still unwind it.
do
	local scenario = "settle-identity: a running Manners bar macro binds a secret-id cast and keeps refusal"
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "MAGE"
	local restore = H.strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		Mock.secureActions = true
		Mock.eventSink = ns.addon
		H.owe(ns, NAME)
		ns.db.profile.sources.asked = true
		ns.standingRequests[#ns.standingRequests + 1] = {
			name = SHORT, short = SHORT, full = NAME, keys = { intellect = true },
			at = GetTime(), expires = GetTime() + 60,
		}
		ns.addon:Tick()
		if not (ns.Prompt.state.current and ns.Prompt.state.current.name == NAME) then
			fail(scenario, "SKIPPED -- the owed favour did not arm the prompt")
		else
			ns.CreateClickMacro()
			if not Mock.dropOnBar(2) then
				fail(scenario, "SKIPPED -- the macro did not go on the bar")
			else
				Mock.castEvents = "sync"
				Mock.spellIdFor = function() return Mock.SECRET end
				Mock.pressBar(2)
				if ns.owed[NAME] then fail(scenario, "the bound bar cast did not settle the favour") end
				if ns.StillAsked(NAME, "intellect", GetTime()) then
					fail(scenario, "the bound bar cast did not serve the request")
				end
				ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-mock-1", nil)
				if not ns.owed[NAME] then fail(scenario, "the late refusal lost the favour it must restore") end
				if ns.StillAsked(NAME, "intellect", GetTime()) then
					fail(scenario, "the late refusal recreated a request it had already served")
				end
			end
		end
		guarded(ns, scenario)
	end
	restore()
	Mock.reset()
end
