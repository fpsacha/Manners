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
