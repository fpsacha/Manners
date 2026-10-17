-- Hunt 23, Clicks.lua: the global cooldown where the client has no spell 61304
-- (Classic Era 1.15.9 and Burning Crusade Classic 2.5.6), and an isOnGCD read
-- at UNIT_SPELLCAST_SENT, before the cooldown has started. Every name starts
-- with "hunt23-clicks:" and then the fault, so a mutation can name exactly one.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- Globals a scenario replaces, put back after it whether it finished or threw.
local TOUCHED = { "C_FriendList", "C_Secrets", "UnitExists", "IsSpellKnown", "IsPlayerSpell" }

-- One scenario: the mock reset to `flavour` and `class`, `names` standing about
-- as strangers on their tokens, the addon loaded and driven to a fresh prompt,
-- and body(ns) run. Everything is put back and the mock reset after it.
local function run(scenario, flavour, class, names, body, before)
	Mock.reset()
	Mock.setFlavour(flavour)
	Mock.class = class
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore
	local ok, err = pcall(function()
		if before then before() end
		restore = strangers(names)
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	if restore then restore() end
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.inCombat = false
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Classic Era 1.15.9 and Burning Crusade Classic 2.5.6 for what follows. What is
-- known of those clients, from their own data:
--   * spell 61304 has no row in SpellName, Spell, SpellMisc or SpellCategories
--     of Era 1.15.9.70003 or TBC 2.5.6.69795 (wago.tools DB2), where Mists
--     5.5.4.70032 has it as "Global Cooldown"; Blizzard's own UI source of every
--     branch never names it. The same tables hold no row for it on Forever
--     either (1.60.1.70178), where addons do read it (EnhanceQoL's GCD bar), so
--     the data alone is not proof the client answers nothing: what is proved is
--     that nothing on those two clients promises an answer.
--   * On both, the global cooldown is a property of each spell, not a spell:
--     SpellCategories.StartRecoveryCategory is 133 for Arcane Intellect (1459)
--     and Fortitude (1243) and 0 for the Healthstone's spell (6262), which is
--     off it. Blizzard's own Era action bar draws the sweep from the spell's own
--     C_Spell.GetSpellCooldown (Blizzard_ActionBar/Shared/ActionButton.lua,
--     ActionButton_UpdateCooldown), with no global-cooldown special case.
--   * SpellCooldownInfo.isOnGCD (every branch's SpellSharedDocumentation.lua,
--     Era and TBC included): "do not trust this field unless responding to a
--     SPELL_UPDATE_COOLDOWN event". On Forever startTime and duration are secret
--     while cooldowns are restricted (a fight; GetSpellCooldown is
--     SecretWhenCooldownsRestricted), and isOnGCD is NeverSecret.
-- The mock stands in for such a client by having no cooldown entry for 61304
-- (C_Spell.GetSpellCooldown answers nil, as documented for an unknown spell) and
-- by reporting the global cooldown through the spell's own reading, as the
-- client's action bars read it.

-- A press on Anna, owed, the prompt armed on her: `flavour`, with spell cooldowns
-- `cooldowns(intellect)` (a table the body may change as the clock moves).
local function gcdSession(scenario, flavour, cooldowns, body)
	local who = flavour == "camelot" and "Anna Aim" or "Anna"
	run(scenario, flavour, "MAGE", { nameplate1 = { "Anna", flavour == "camelot" and "Aim" or "" } }, function(ns)
		-- The rank this character would cast: the best she knows.
		local intellect = ns.BuffInfo(ns.FindBuff("MAGE", "intellect")).topRank
		Mock.spellCooldowns = cooldowns(intellect)
		H.owe(ns, who)
		ns.addon:Tick()
		body(ns, intellect, who)
	end)
end

-- ------------------------------------------------------ the guess on Era and TBC
-- hunt23-clicks: gcd-spell-61304 (Clicks.lua GCD_SPELL, GlobalCooldownLeft,
-- GcdSpan, NoteCastWentOut)
--
-- The global cooldown is read from spell 61304 and, where that gives nothing,
-- guessed: every cast the player sends holds the prompt for 1.5 seconds.
-- tests/scenarios.lua scenario 230 ("a cast off the global cooldown does not
-- hold the prompt") is the Forever fix for the guess holding a press made just
-- after a healthstone, a potion or a trinket: 61304 reads idle, so the guess is
-- not used. Where the client has no 61304 -- Era and TBC, per the data above --
-- the fix never ran: a healthstone drunk and the prompt pressed 0.3 s later was
-- turned away for the rest of the second and a half, though the spell the press
-- casts reads idle on the client's own bar. In a fight the turned-away press is
-- the worse case the 230 comment describes (the frozen macro goes out anyway,
-- nothing is filed, the debt stays, the same person is cast at again after the
-- fight). The control is Forever, which answers for 61304 and was always right.
for _, flavour in ipairs({ "camelot", "vanilla", "tbc" }) do
	local scenario = "hunt23-clicks: gcd-spell-61304 (" .. flavour .. ")"
	gcdSession(scenario, flavour, function(intellect)
		local idle = { startTime = 0, duration = 0, isActive = false }
		local cooldowns = { [intellect] = idle, [6262] = { duration = 0 } }
		-- Forever answers for the global cooldown itself, idle here.
		if flavour == "camelot" then cooldowns[61304] = idle end
		return cooldowns
	end, function(ns)
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-hand", 6262)
		Mock.advance(0.3)
		-- Whatever the guess says, the spell the press casts reads idle on the
		-- client's own bar: nothing is cooling down.
		if not ns.CastReady() then
			fail(scenario, "a healthstone was drunk 0.3 s ago, nothing is on the global cooldown by the client's"
				.. " own reading of the spell the press casts, and the prompt is held for the guess anyway")
		end
		-- The sweep over the prompt's icon is drawn from the same reading, so an
		-- idle bar shows none, rather than the guess's second and a half.
		if ns.GlobalCooldownSpan() then
			fail(scenario, "nothing is on the global cooldown by the client's own reading, and the prompt's"
				.. " icon sweeps the guess anyway")
		end
	end)
end

-- hunt23-clicks: gcd-reference (Clicks.lua GlobalCooldownReading)
--
-- What stands in for 61304 is read as the client gives it, not as the guess
-- would: a global cooldown that started a moment after the cast was sent and
-- runs 1.3 s (haste) is that, for the "ready in" line and for the sweep. A
-- cooldown of the spell's own, longer than any global one, is not it: an
-- Intellect with eight seconds on it says nothing about the global cooldown, so
-- the guess stands. And a buff with such a cooldown does not end the search:
-- the next buff the player knows is asked.
for _, flavour in ipairs({ "vanilla", "tbc" }) do
	local scenario = "hunt23-clicks: gcd-reference (" .. flavour .. ")"
	local sentAt
	gcdSession(scenario, flavour, function(intellect)
		return { [intellect] = { startTime = 0, duration = 0, isActive = false } }
	end, function(ns, intellect)
		-- A Frostbolt from the bar, the client's own reading of the global
		-- cooldown it started on Anna's Intellect: late, and shorter than 1.5 s.
		sentAt = GetTime()
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Somebody", "Cast-bar", 116)
		Mock.advance(0.3)
		Mock.spellCooldowns[intellect] = { startTime = sentAt + 0.1, duration = 1.3, isActive = true }
		local ready, left = ns.CastReady()
		if ready or math.abs(left - 1.1) > 0.001 then
			fail(scenario, "the global cooldown the client reads runs until 1.4 s after the cast, 1.1 s to go,"
				.. " and the prompt says " .. (ready and "ready" or ("ready in " .. tostring(left))))
		end
		local start, duration = ns.GlobalCooldownSpan()
		if not (start and duration and math.abs(start - (sentAt + 0.1)) < 0.001 and math.abs(duration - 1.3) < 0.001) then
			fail(scenario, "the sweep is not the client's own figure (1.3 s from 0.1 s after the cast): "
				.. tostring(start) .. ", " .. tostring(duration))
		end
		-- The spell has a cooldown of its own now, longer than a global one: the
		-- guess stands, from the cast, for what is left of its second and a half.
		Mock.spellCooldowns[intellect] = { startTime = GetTime(), duration = 8, isActive = true }
		ready, left = ns.CastReady()
		if ready or left > 1.5 then
			fail(scenario, "a spell with eight seconds of its own cooldown stood in for the global cooldown: the"
				.. " prompt says " .. (ready and "ready" or ("ready in " .. tostring(left))) .. " where the guess has 1.2 s to run")
		end
		start, duration = ns.GlobalCooldownSpan()
		if not (start and duration and math.abs(start - sentAt) < 0.001 and math.abs(duration - 1.5) < 0.001) then
			fail(scenario, "a spell with eight seconds of its own cooldown stood in for the global cooldown on the sweep: "
				.. tostring(start) .. ", " .. tostring(duration))
		end
		Mock.advance(2)
		if not ns.CastReady() then
			fail(scenario, "the guess outlived its second and a half")
		end
	end)
end

do
	local scenario = "hunt23-clicks: gcd-reference (the next buff, vanilla)"
	local known = { [1243] = true, [976] = true }
	run(scenario, "vanilla", "PRIEST", { nameplate1 = { "Anna", "" } }, function(ns)
		local fortitude = ns.BuffInfo(ns.FindBuff("PRIEST", "fortitude")).topRank
		local shadow = ns.BuffInfo(ns.FindBuff("PRIEST", "shadow")).topRank
		if fortitude ~= 1243 or shadow ~= 976 then
			fail(scenario, "SKIPPED -- the priest does not know Fortitude and Shadow Protection as set up")
			return
		end
		-- Fortitude is cooling down on its own account; Shadow Protection reads idle.
		Mock.spellCooldowns = {
			[fortitude] = { startTime = GetTime(), duration = 8, isActive = true },
			[shadow] = { startTime = 0, duration = 0, isActive = false },
		}
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-hand", 6262)
		Mock.advance(0.3)
		if not ns.CastReady() then
			fail(scenario, "the first buff the priest knows is on its own cooldown and the next reads idle, and the prompt"
				.. " is held for the guess anyway")
		end
	end, function()
		local is = function(id) return known[id] == true end
		rawset(_G, "IsSpellKnown", is)
		rawset(_G, "IsPlayerSpell", is)
	end)
end

-- ------------------------------------------------------ isOnGCD read at SENT
-- hunt23-clicks: notecast-isongcd-at-sent (Clicks.lua NoteCastWentOut,
-- DropGuessOffGcd)
--
-- UNIT_SPELLCAST_SENT read the cast spell's cooldown and, on `isOnGCD == false`,
-- took the spell for one that triggers no global cooldown and armed nothing. The
-- client's own documentation of the field says it is not to be trusted outside
-- SPELL_UPDATE_COOLDOWN, and SENT is before the cooldown has started: a reading
-- of {startTime 0, duration 0, isOnGCD false} for a spell that is about to take
-- the global cooldown is what that allows. Where the client's own figure for
-- the global cooldown is not to be had the tracking is all there is, and with
-- it unarmed a press 0.3 s after a Power Word or an Intellect goes straight into
-- the running cooldown: out of combat the macro's spoken line goes out over a
-- /cast the client turns away. That is Forever in a fight, where the client
-- withholds every figure (a secret start and length, for 61304 and for the spell
-- alike) but isOnGCD is documented NeverSecret (forever branch
-- SpellSharedDocumentation.lua), so a stale false there is read as plainly as
-- anywhere. Control: the same cast with the field absent (nil) armed.
for _, field in ipairs({ false, "absent" }) do
	local scenario = "hunt23-clicks: notecast-isongcd-at-sent (camelot, figures withheld in a fight, isOnGCD at SENT "
		.. (field == "absent" and "absent" or "false") .. ")"
	local cooldown
	gcdSession(scenario, "camelot", function(intellect)
		-- What the client says as the cast is sent: no cooldown has started.
		cooldown = { startTime = Mock.SECRET, duration = Mock.SECRET, isActive = true }
		if field == false then cooldown.isOnGCD = false end
		return {
			[61304] = { startTime = Mock.SECRET, duration = Mock.SECRET, isActive = true },
			[intellect] = cooldown,
		}
	end, function(ns, intellect)
		Mock.inCombat = true
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Anna", "Cast-hand", intellect)
		-- The cast goes out; by SPELL_UPDATE_COOLDOWN the client's own reading of
		-- the same spell says the global cooldown is what it is on.
		cooldown.isOnGCD = true
		ns.addon:SPELL_UPDATE_COOLDOWN()
		Mock.advance(0.3)
		if ns.CastReady() then
			fail(scenario, "0.3 s after an Arcane Intellect was sent, with every figure withheld, the client says it is on"
				.. " the global cooldown and the prompt calls the press ready: SENT read isOnGCD="
				.. (field == "absent" and "nil" or "false") .. " and armed nothing")
		end
	end)
end

-- The same on Era and TBC, where the figure is the buff's own reading: a stale
-- false at SENT, the cooldown started a moment later, and the prompt still says
-- when the global cooldown ends.
for _, flavour in ipairs({ "vanilla", "tbc" }) do
	local scenario = "hunt23-clicks: notecast-isongcd-at-sent (" .. flavour .. ", the figure the client gives)"
	local cooldown
	gcdSession(scenario, flavour, function(intellect)
		cooldown = { startTime = 0, duration = 0, isActive = false, isOnGCD = false }
		return { [intellect] = cooldown }
	end, function(ns, intellect)
		local sentAt = GetTime()
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", "Anna", "Cast-hand", intellect)
		Mock.advance(0.3)
		cooldown.startTime, cooldown.duration, cooldown.isActive, cooldown.isOnGCD = sentAt, 1.5, true, true
		ns.addon:SPELL_UPDATE_COOLDOWN()
		if ns.CastReady() then
			fail(scenario, "0.3 s after an Arcane Intellect was sent the client's own reading of it says the global"
				.. " cooldown has 1.2 s to run, and the prompt calls the press ready")
		end
	end)
end

-- hunt23-clicks: dropped-off-gcd (Clicks.lua DropGuessOffGcd)
--
-- What SPELL_UPDATE_COOLDOWN says of the cast that armed the guess, with every
-- figure withheld (a fight on Forever): a spell off the global cooldown gives
-- the guess back, a press 0.3 s after a healthstone is not held for it, and in a
-- fight it is filed, so the cast it sends settles the debt; a flag that says
-- nothing keeps the guess, which is what stops a press being refused; a spell on
-- the global cooldown keeps it, and the client is asked about a cast once, not
-- at every cooldown update the fight sends (a raid sends them all the time).
do
	local scenario = "hunt23-clicks: dropped-off-gcd (camelot, figures withheld in a fight)"
	local reads
	local readsOf = 0
	gcdSession(scenario, "camelot", function()
		local secret = function(isOnGCD)
			return { startTime = Mock.SECRET, duration = Mock.SECRET, isActive = true, isOnGCD = isOnGCD }
		end
		return { [61304] = secret(), [6262] = secret(false), [116] = secret(), [2139] = secret(true) }
	end, function(ns)
		Mock.inCombat = true
		-- Every read of Frostbolt's cooldown, to count what asks for it. The mock
		-- builds its C_Spell afresh on each look, so one is set in its place for
		-- the while and taken away after.
		local spells = _G.C_Spell
		local real = spells.GetSpellCooldown
		spells.GetSpellCooldown = function(id)
			if id == 116 then readsOf = readsOf + 1 end
			return real(id)
		end
		rawset(_G, "C_Spell", spells)
		local ok, err = pcall(function()
			-- A healthstone: off it, dropped at the first update.
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-hand", 6262)
			ns.addon:SPELL_UPDATE_COOLDOWN()
			Mock.advance(0.3)
			if not ns.CastReady() then
				fail(scenario, "a healthstone the client says is off the global cooldown still held the prompt")
			end
			Mock.advance(2)

			-- Counterspell, which says it is on it, keeps the guess.
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-hand", 2139)
			ns.addon:SPELL_UPDATE_COOLDOWN()
			Mock.advance(0.3)
			if ns.CastReady() then
				fail(scenario, "a spell the client says is on the global cooldown did not hold the prompt")
			end
			Mock.advance(2)

			-- Frostbolt says nothing at first: the guess stays and the client is asked
			-- at each update; once it says on, never again.
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-hand", 116)
			reads = readsOf
			ns.addon:SPELL_UPDATE_COOLDOWN()
			ns.addon:SPELL_UPDATE_COOLDOWN()
			if readsOf ~= reads + 2 then
				fail(scenario, "a cast the client has said nothing about was asked about " .. (readsOf - reads)
					.. " times in two cooldown updates, wanted 2")
			end
			Mock.advance(0.3)
			if ns.CastReady() then
				fail(scenario, "a spell the client says nothing about did not hold the prompt")
			end
			Mock.spellCooldowns[116].isOnGCD = true
			ns.addon:SPELL_UPDATE_COOLDOWN()
			reads = readsOf
			for _ = 1, 5 do ns.addon:SPELL_UPDATE_COOLDOWN() end
			if readsOf ~= reads then
				fail(scenario, "a cast the client has said is on the global cooldown was asked about again "
					.. (readsOf - reads) .. " times in five cooldown updates")
			end
			if ns.CastReady() then
				fail(scenario, "a spell the client says is on the global cooldown did not hold the prompt")
			end

			-- A guess that has run out is not asked about at all.
			Mock.spellCooldowns[116].isOnGCD = nil
			Mock.advance(2)
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-hand", 116)
			reads = readsOf
			Mock.advance(2)
			ns.addon:SPELL_UPDATE_COOLDOWN()
			if readsOf ~= reads then
				fail(scenario, "a cast whose guess had run out was asked about at the next cooldown update")
			end
		end)
		rawset(_G, "C_Spell", nil)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end)
end

-- And in a fight, the press after the healthstone is filed, so the cast it sends
-- settles the debt (the case scenario 230 plays where 61304 answers).
do
	local scenario = "hunt23-clicks: dropped-off-gcd (a press in a fight, figures withheld)"
	gcdSession(scenario, "camelot", function()
		local secret = function(isOnGCD)
			return { startTime = Mock.SECRET, duration = Mock.SECRET, isActive = true, isOnGCD = isOnGCD }
		end
		return { [61304] = secret(), [6262] = secret(false) }
	end, function(ns, intellect, who)
		local entry = ns.BuildQueue()[1]
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		if not (entry and entry.name == who and entry.buff) then
			fail(scenario, "SKIPPED -- Anna was not the one offered")
			return
		end
		ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-hand", 6262)
		ns.addon:SPELL_UPDATE_COOLDOWN()
		Mock.advance(0.3)
		H.pressButton(ns)
		if not ns.pendingClick then
			fail(scenario, "in a fight, a press just after a healthstone was set aside as turned away, so the buff it"
				.. " casts is never counted")
		else
			ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, "Cast-press", entry.buff.ranks[1])
			if ns.owed[who] then
				fail(scenario, "in a fight, the buff went out and Anna is still owed")
			end
		end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
	end)
end
