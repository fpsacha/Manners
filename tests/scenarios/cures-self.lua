-- Curing yourself (Cures.lua, ns.CureSelf; sources.curesSelf, off): a poison, a
-- disease, a curse or a harmful spell on you that your class can take off is
-- offered its cure on the prompt, out of combat, through the entry you get
-- (Queue.lua, SelfEntry): reason "self", the usual press on yourself, and the
-- one entry for you, so it wins over a buff for yourself. A switch of its own,
-- under Who to buff's cures: it asks no walk of anybody else.
--
-- The mock's aura list knows no debuffs, so each session stands its own
-- C_UnitAuras in front of it, as cures.lua does: a harmful read answers from
-- `debuffs`, by unit token, and is counted (`reads`).
--
-- Every scenario name starts with "cures-self:" so the mutations in
-- tests/mutations/cures-self.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Hugo", "Holt" },
}

local MOTW, CURE_POISON, REMOVE_CURSE = 1126, 8946, 2782
local DRUID = { MOTW, CURE_POISON, REMOVE_CURSE }

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitInParty", "C_UnitAuras", "IsUsableSpell" }

local function filed(pair)
	return Mock.surnames and pair[2] and (pair[1] .. " " .. pair[2]) or pair[1]
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
end

local function debuff(kind, left, id, can, name)
	return { kind = kind, left = left, id = id or 90000, can = can, name = name or ((kind or "Plain") .. " thing") }
end

-- One session, a druid in a party of three unless `env` says otherwise:
--   env.class    the player's class (DRUID)
--   env.known    spell ids known (DRUID)
--   env.bare     nobody wears your buff, you included (everybody wears it)
--   env.group    the party's switch sources.cures (off)
--   env.me       Cure myself too (on unless false)
--   env.myself   Myself, when I'm missing my own buff (off)
--   env.solo     nobody else in the group
local function with(scenario, env, body)
	Mock.reset()
	Mock.class = env.class or "DRUID"
	Mock.groupSize = env.solo and 1 or 3
	if not env.bare then Mock.held = { [MOTW] = true } else Mock.playerHeld = {} end
	local names = env.solo and {} or { party1 = PARTY.party1, party2 = PARTY.party2 }
	local restore = strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local world = { debuffs = {}, reads = { n = 0 }, known = {} }
	for _, id in ipairs(env.known or DRUID) do world.known[id] = true end
	local ok, err = pcall(function()
		rawset(_G, "IsSpellKnown", function(id) return world.known[id] == true end)
		rawset(_G, "IsPlayerSpell", function(id) return world.known[id] == true end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d+$") ~= nil
		end)
		local base = C_UnitAuras
		rawset(_G, "C_UnitAuras", setmetatable({
			GetAuraDataByIndex = function(unit, index, filter)
				if filter ~= "HARMFUL" then return base.GetAuraDataByIndex(unit, index, filter) end
				local reads = world.reads
				reads.n = reads.n + 1
				reads[unit] = (reads[unit] or 0) + 1
				local d = world.debuffs[unit] and world.debuffs[unit][index]
				if not d then return nil end
				return {
					name = d.name, spellId = d.id, dispelName = d.kind,
					expirationTime = d.left and (Mock.now + d.left) or 0,
					duration = d.left and 60 or 0,
					canActivePlayerDispel = d.can, isHarmful = true, auraInstanceID = 9000 + index,
				}
			end,
		}, { __index = base }))
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local sources = ns.db.profile.sources
		sources.group, sources.strangers = true, false
		sources.self = env.myself == true
		sources.cures = env.group == true
		sources.curesSelf = env.me ~= false
		ns.Guard("probe", ns.ProbeCapabilities)
		for key in pairs(world.reads) do world.reads[key] = nil end
		world.reads.n = 0
		body(ns, world)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The queue, by name and as a list, past every reading kept.
local function queue(ns)
	Mock.advance(4)
	local list, byName = ns.BuildQueue(), {}
	for _, entry in ipairs(list) do byName[entry.name] = entry end
	return byName, list
end

local function macroFor(ns, entry)
	ns.pendingClick = nil
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyTarget(entry)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

local function me(ns) return ns.UnitFullName("player") end

-- ------------------------------------------------------------ the switch
do
	local scenario = "cures-self: off by default, and your own debuffs are not read"
	with(scenario, { me = false }, function(ns, world)
		if ns.defaults.profile.sources.curesSelf ~= false then
			fail(scenario, "the default is " .. tostring(ns.defaults.profile.sources.curesSelf) .. ", not off")
		end
		world.debuffs.player = { debuff("Poison", 60) }
		local entry = queue(ns)[me(ns)]
		if entry and entry.cure then fail(scenario, "with the switch off you were offered a cure") end
		if world.reads.n ~= 0 then
			fail(scenario, "with the switch off the client was asked for harmful auras " .. world.reads.n .. " times")
		end
		ns.db.profile.sources.curesSelf = true
		entry = queue(ns)[me(ns)]
		if not (entry and entry.cure == "Poison") then
			fail(scenario, "SKIPPED -- with the switch on a poisoned you is not offered the cure")
		end
	end)
end

-- ------------------------------------------------------------ the entry
do
	local scenario = "cures-self: a poison on you is offered the cure, by the usual press on yourself"
	with(scenario, {}, function(ns, world)
		ns.db.profile.filters.restoreTarget = true
		world.debuffs.player = { debuff("Poison", 60, 2818, nil, "Deadly Poison") }
		local byName, list = queue(ns)
		local entry = byName[me(ns)]
		if not entry then fail(scenario, "a poisoned you is offered nothing") return end
		if entry.cure ~= "Poison" or not (entry.buff and entry.buff.cure == "Poison") then
			fail(scenario, "the entry is not a cure for a poison: " .. tostring(entry.buff and entry.buff.key))
			return
		end
		if entry.reason ~= "self" or entry.unit ~= "player" or entry.display ~= "You" then
			fail(scenario, ("the entry reads reason=%s unit=%s display=%s"):format(tostring(entry.reason),
				tostring(entry.unit), tostring(entry.display)))
		end
		if entry.ranged ~= true then fail(scenario, "a cure on yourself is not in reach: " .. tostring(entry.ranged)) end
		if entry.debuff ~= "Deadly Poison" then fail(scenario, "the debuff's name is lost: " .. tostring(entry.debuff)) end
		local count = 0
		for _, e in ipairs(list) do
			if e.name == me(ns) then count = count + 1 end
		end
		if count ~= 1 then fail(scenario, "you have " .. count .. " entries") end
		local ran = macroFor(ns, entry)
		local want = "/target " .. me(ns) .. "\n/cast " .. ns.BuffName(entry.buff)
		if type(ran) ~= "string" or ran:sub(1, #want) ~= want then
			fail(scenario, "the macro reads " .. flat(ran) .. ", not " .. flat(want) .. " and the hand-back")
		elseif ran:find("[@", 1, true) or ran:find("player", 1, true) then
			fail(scenario, "the macro names a unit token or a conditional: " .. flat(ran))
		elseif #ran > 255 then
			fail(scenario, "the macro is " .. #ran .. " characters")
		end
		local line = ns.Prompt:ReasonText(entry)
		if line ~= "Poisoned" then fail(scenario, "the reason line reads " .. tostring(line)) end
	end)
end

do
	local scenario = "cures-self: it asks no walk of anybody else, and the party's switch is its own"
	with(scenario, {}, function(ns, world)
		world.debuffs.party1 = { debuff("Poison", 60) }
		world.debuffs.player = { debuff("Curse", 60) }
		local byName = queue(ns)
		if (byName[filed(PARTY.party1)] or {}).cure then
			fail(scenario, "a party member was offered a cure with only Cure myself too on")
		end
		if (world.reads.party1 or 0) ~= 0 then
			fail(scenario, "a party member's debuffs were read with only Cure myself too on")
		end
		local entry = byName[me(ns)]
		if not (entry and entry.cure == "Curse") then
			fail(scenario, "you were offered " .. tostring(entry and entry.buff.key) .. ", not the cure for a curse")
		end
		-- And the party's own switch alone leaves you out.
		ns.db.profile.sources.curesSelf = false
		ns.db.profile.sources.cures = true
		byName = queue(ns)
		if (byName[me(ns)] or {}).cure then fail(scenario, "Cure my party and raid alone cured you") end
		if not (byName[filed(PARTY.party1)] or {}).cure then
			fail(scenario, "SKIPPED -- the party switch alone does not cure the member")
		end
	end)
end

do
	local scenario = "cures-self: the cure wins over your own buff, and the buff is back once cured"
	with(scenario, { bare = true, myself = true }, function(ns, world)
		local entry = queue(ns)[me(ns)]
		if not (entry and entry.buff.key == "motw" and not entry.cure) then
			local held = ns.MyselfHeldBack(ns.db.profile, Mock.now)
			fail(scenario, "SKIPPED -- a bare druid is not offered Mark of the Wild on himself: held=" .. tostring(held)
				.. " entry=" .. tostring(entry and (entry.buff.key .. "/" .. tostring(entry.cure))))
			return
		end
		world.debuffs.player = { debuff("Poison", 60) }
		local byName, list = queue(ns)
		entry = byName[me(ns)]
		if not (entry and entry.cure == "Poison") then
			fail(scenario, "poisoned and missing your buff you are offered " .. tostring(entry and entry.buff.key))
			return
		end
		local count = 0
		for _, e in ipairs(list) do
			if e.name == me(ns) then count = count + 1 end
		end
		if count ~= 1 then fail(scenario, "you have " .. count .. " entries beside your buff") end
		world.debuffs.player = nil
		ns.addon:UNIT_AURA("UNIT_AURA", "player")
		entry = queue(ns)[me(ns)]
		if not (entry and entry.buff.key == "motw" and not entry.cure) then
			fail(scenario, "cured, you are offered " .. tostring(entry and entry.buff.key) .. ", not Mark of the Wild")
		end
	end)
end

do
	local scenario = "cures-self: it comes without Myself being on, which is about buffs"
	with(scenario, { myself = false }, function(ns, world)
		world.debuffs.player = { debuff("Poison", 60) }
		local entry = queue(ns)[me(ns)]
		if not (entry and entry.cure) then fail(scenario, "with Myself off a poisoned you is offered nothing") end
	end)
end

-- ------------------------------------------------------------ the rules
do
	local scenario = "cures-self: never in a fight, and nothing read there"
	with(scenario, {}, function(ns, world)
		world.debuffs.player = { debuff("Poison", 60) }
		if not (queue(ns)[me(ns)] or {}).cure then
			fail(scenario, "SKIPPED -- out of a fight the poison is not offered a cure")
			return
		end
		world.reads.n = 0
		Mock.inCombat = true
		local entry = queue(ns)[me(ns)]
		Mock.inCombat = false
		if entry and entry.cure then fail(scenario, "a cure on you was offered in a fight") end
		if world.reads.n ~= 0 then fail(scenario, "harmful auras were read in a fight") end
		ns.Prompt.armedForFight = true
		entry = queue(ns)[me(ns)]
		ns.Prompt.armedForFight = false
		if entry and entry.cure then fail(scenario, "a cure on you was armed for the fight at the pull") end
	end)
end

do
	local scenario = "cures-self: a debuff about to run out, one with no timer and a denied one are left alone"
	with(scenario, {}, function(ns, world)
		world.debuffs.player = { debuff("Poison", 8, nil, nil, "Slow Venom") }
		if (queue(ns)[me(ns)] or {}).cure then fail(scenario, "a poison with 8 seconds left was offered, with 10 set") end
		world.debuffs.player = { debuff("Poison", nil) }
		if (queue(ns)[me(ns)] or {}).cure then fail(scenario, "a poison with no timer was offered") end
		world.debuffs.player = { debuff("Poison", 60, 427717, nil, "Unstable Affliction") }
		if (queue(ns)[me(ns)] or {}).cure then fail(scenario, "a poison on the deny list was offered") end
		world.debuffs.player = { debuff("Poison", 60, nil, false, "Stuck Venom") }
		if (queue(ns)[me(ns)] or {}).cure then fail(scenario, "a poison the client says you cannot remove was offered") end
	end)
end

do
	local scenario = "cures-self: a skip of the cure, a skip of you and the never-offer list hold it off"
	with(scenario, {}, function(ns, world)
		world.debuffs.player = { debuff("Poison", 60) }
		local entry = queue(ns)[me(ns)]
		if not (entry and entry.cure) then fail(scenario, "SKIPPED -- no cure is offered") return end
		ns.SkipOwn(me(ns), entry.buff.key, 300)
		if (queue(ns)[me(ns)] or {}).cure then fail(scenario, "a right-click on the cure did not skip it") end
		Mock.advance(400)
		entry = queue(ns)[me(ns)]
		if not (entry and entry.cure) then fail(scenario, "the skip did not end") return end
		ns.BlockPerson(me(ns), 300)
		if (queue(ns)[me(ns)] or {}).cure then fail(scenario, "a ctrl-right-click on yourself did not skip the cure") end
	end)
end

do
	local scenario = "cures-self: your own name on the never-offer list holds the cure off"
	with(scenario, {}, function(ns, world)
		world.debuffs.player = { debuff("Poison", 60) }
		if not (queue(ns)[me(ns)] or {}).cure then fail(scenario, "SKIPPED -- no cure is offered") return end
		ns.PutOnNeverList(me(ns))
		if (queue(ns)[me(ns)] or {}).cure then fail(scenario, "a cure was offered to a name on the never-offer list") end
	end)
end

-- ------------------------------------------------------------ the press
do
	local scenario = "cures-self: a press settles as a cure on yourself, and is not offered again at once"
	with(scenario, {}, function(ns, world)
		world.debuffs.player = { debuff("Poison", 60) }
		local entry = queue(ns)[me(ns)]
		if not (entry and entry.cure) then fail(scenario, "SKIPPED -- no cure is offered") return end
		local button = ns.Prompt:GetButton()
		Mock.advance(1)
		macroFor(ns, entry)
		button.scripts.PostClick(button, "LeftButton", true)
		local pending = ns.pendingClick
		if not pending then fail(scenario, "SKIPPED -- the press parked nothing") return end
		if pending.cure ~= "Poison" or pending.onSelf ~= true then
			fail(scenario, ("the press reads cure=%s onSelf=%s"):format(tostring(pending.cure), tostring(pending.onSelf)))
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, nil, CURE_POISON)
		if ns.pendingClick then fail(scenario, "SKIPPED -- the cast did not settle the press") return end
		local counts = ns.db.char.milestones
		local before = counts and counts.n and counts.n.cure or 0
		Mock.advance(5)
		ns.PruneSettled()
		local after = counts and counts.n and counts.n.cure or 0
		if after ~= before + 1 then
			fail(scenario, ("a cure on yourself that nothing refused counted %d towards its milestone, not 1"):format(after - before))
		end
		local again = queue(ns)[me(ns)]
		if again and again.cure then fail(scenario, "the cure was offered again at once") end
		if ns.lastGave and ns.lastGave[me(ns)] == entry.buff.key then
			fail(scenario, "the cure's key went into the rotation pointer")
		end
	end)
end

do
	local scenario = "cures-self: Shift-right-click switches Cure myself too off, not Myself"
	with(scenario, { myself = true }, function(ns, world)
		world.debuffs.player = { debuff("Poison", 60) }
		local entry = queue(ns)[me(ns)]
		if not (entry and entry.cure) then fail(scenario, "SKIPPED -- no cure is offered") return end
		ns.StopOfferingSelf(entry)
		local sources = ns.db.profile.sources
		if sources.curesSelf ~= false then fail(scenario, "Cure myself too is still " .. tostring(sources.curesSelf)) end
		if sources.self ~= true then fail(scenario, "the cure's Shift-right-click switched Myself off") end
		-- And on a buff of yours it is Myself that goes.
		sources.curesSelf = true
		ns.StopOfferingSelf({ reason = "self", buff = { key = "motw" } })
		if sources.self ~= false or sources.curesSelf ~= true then
			fail(scenario, "a buff's Shift-right-click did not switch Myself off alone")
		end
	end)
end

-- ------------------------------------------------------------ not a druid's alone
do
	local scenario = "cures-self: a class with a cure and no buff for others has a prompt for it"
	with(scenario, { class = "SHAMAN", known = { 526 }, solo = true }, function(ns, world)
		if ns.caps.hasClassBuffs or #ns.CastableBuffs() ~= 0 then
			fail(scenario, "SKIPPED -- the shaman has a buff for somebody else in hand")
			return
		end
		world.debuffs.player = { debuff("Poison", 60) }
		local entry = queue(ns)[me(ns)]
		if not (entry and entry.cure == "Poison") then
			fail(scenario, "a shaman with Cure Poison and no buff for others is offered nothing on himself")
			return
		end
		if not ns.CanCastAnything() then fail(scenario, "with Cure myself too on there is still no prompt") end
		if world.reads.party1 or world.reads.party2 then fail(scenario, "the walk read somebody else's debuffs") end
		ns.db.profile.sources.curesSelf = false
		if ns.CanCastAnything() then
			fail(scenario, "SKIPPED -- the shaman has something to cast with the switch off")
		end
	end)
end

-- ------------------------------------------------------------ the controls
do
	local scenario = "cures-self: the switch is on Who to buff, placed, reset and repaired"
	with(scenario, { me = false }, function(ns)
		local sources = ns.db.profile.sources
		local control = H.findOption(ns.optionsTable, "curesSelf")
		if not control then fail(scenario, "no curesSelf control in the options") return end
		if control.type ~= "toggle" or H.optionText(control.name) ~= "Cure myself too" then
			fail(scenario, "the switch is a " .. tostring(control.type) .. " called " .. H.optionText(control.name))
		end
		if type(control.hidden) ~= "function" or control.hidden() then fail(scenario, "the switch is hidden from a druid") end
		control.set({ "who", "curesSelf" }, true)
		if sources.curesSelf ~= true or control.get({ "who", "curesSelf" }) ~= true then
			fail(scenario, "ticking the switch does not write sources.curesSelf")
		end
		if sources.cures ~= false then fail(scenario, "ticking it ticked the party's switch too") end
		local seconds = H.findOption(ns.optionsTable, "cureSeconds")
		if seconds and seconds.disabled() then fail(scenario, "the seconds are greyed with the switch on") end
		control.set({ "who", "curesSelf" }, false)
		if seconds and not seconds.disabled() then fail(scenario, "the seconds are not greyed with every switch off") end
		for _, bad in ipairs({ "yes", 1, {} }) do
			sources.curesSelf = bad
			ns.ClampSettings()
			if sources.curesSelf ~= false then fail(scenario, "a " .. type(bad) .. " in the file is not repaired to off") end
		end
		local reset = {}
		for _, path in ipairs(ns.OptionsPage.RESET.who or {}) do reset[path] = true end
		if not reset["sources.curesSelf"] then fail(scenario, "Who to buff's reset does not reach it") end
		if H.layoutInToc() and not H.placedOn(ns, "who.curesSelf") then
			fail(scenario, "the window places no who.curesSelf")
		end
	end)
end

do
	local scenario = "cures-self: a class with no cure is not shown the switch"
	with(scenario, { class = "WARRIOR", known = {} }, function(ns)
		local control = H.findOption(ns.optionsTable, "curesSelf")
		if not control then fail(scenario, "no curesSelf control in the options") return end
		if type(control.hidden) ~= "function" or not control.hidden() then
			fail(scenario, "a warrior is shown a switch to cure himself")
		end
	end)
end
