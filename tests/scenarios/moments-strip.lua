-- The spells that strip a buff from a hostile target, for the moment
-- (Prompt/MomentsData.lua's slot 8, Prompt/MomentsSense.lua's `removable`):
-- a shaman's Purge, a priest's Dispel Magic, a hunter's Tranquilizing Shot and a
-- warrior's Shield Slam. Lit in a fight while a hostile target in range carries
-- a buff the spell removes and the spell is ready. Plain where the auras are
-- readable: the aura's kind (Magic; "" or Enrage for an enrage) or, for a spell
-- that takes magic, the game's own stealable-or-purgeable flag. Where the flags
-- are hidden they are handed to the game, ORed, and the button takes two
-- clicks; where only the kinds are hidden, the game's own filter of what can be
-- removed decides while you are on your own. Shield Slam ships off.
--
-- Held to the mock's model of the client (tests/momentskit.lua), not to the
-- client (STATUS.md).
--
-- Every name starts with "moments-strip:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")
-- Written for plain values: the hidden ones are asked for by name (Mock.buffsWithheld, ...).
K.plain = true

local SLOT = 8

local function with(name, body, opts)
	K.withMage(H, "moments-strip: " .. name, body, opts)
end
local function name(s) return "moments-strip: " .. s end
local function slot(ns) return ns.Moments:Slot(SLOT) end
local function state(ns) return slot(ns) and slot(ns).state or "none" end
local function why(ns) return tostring(slot(ns) and slot(ns).why) end

local SHAMAN = { class = "SHAMAN", known = { 8012, 370 } }
local PRIEST = { class = "PRIEST", known = { 527, 988 } }
local HUNTER = { class = "HUNTER", known = { 19801 } }
local function warrior(edit)
	return { class = "WARRIOR", known = { 23922, 23923 }, edit = edit }
end
local function on(opts, flavour)
	local copy = {}
	for k, v in pairs(opts) do copy[k] = v end
	copy.flavour = flavour
	return copy
end

local function casts(spell)
	local n = 0
	for _, e in ipairs(Mock.castLog or {}) do
		if e.spell == spell then n = n + 1 end
	end
	return n
end

local function look(ns, buffs)
	Mock.targetBuffs = buffs
	K.event(ns, "UNIT_AURA", "target")
	K.tick(ns, 0.3)
end

do
	local s = name("Purge: a magic buff lights it, one click casts, none and a buff of no kind do not")
	with(s, function(ns)
		if not ns.Moments.Has("purge") then fail(s, "a shaman has no Purge row") return end
		Mock.targetBuffs = { { kind = nil } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or why(ns) ~= "nothing you can remove" then fail(s, "lit with nothing to remove: " .. state(ns) .. " " .. why(ns)) end
		look(ns, { { kind = nil }, { kind = "Magic" } })
		if state(ns) ~= "lit" or K.shown(ns, SLOT) ~= 1 then fail(s, "not lit with a magic buff: " .. state(ns) .. " " .. why(ns)) end
		if K.macro(ns, SLOT) ~= "/stopcasting\n/cast Purge" then fail(s, "the macro: " .. tostring(K.macro(ns, SLOT))) end
		local hit = K.click(ns, SLOT)
		if hit ~= ns.Moments:Button(SLOT) or casts("Purge") ~= 1 then fail(s, "one click did not cast: " .. casts("Purge")) end
		look(ns, { { kind = "Poison" } })
		if state(ns) ~= "dark" then fail(s, "lit on a buff Purge does not take: " .. state(ns)) end
		look(ns, {})
		if state(ns) ~= "dark" or why(ns) ~= "your target has no buffs" then fail(s, "not dark with no buffs: " .. why(ns)) end
	end, SHAMAN)
	s = name("Purge: the game's own stealable-or-purgeable flag lights it too")
	with(s, function(ns)
		Mock.targetBuffs = { { steal = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit by the game's flag: " .. state(ns) .. " " .. why(ns)) end
	end, SHAMAN)
	s = name("Purge: dark with no target, a friendly target, out of range, not castable")
	with(s, function(ns)
		Mock.targetBuffs = { { kind = "Magic" } }
		Mock.noTarget = true
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" then fail(s, "lit with no target") end
		Mock.noTarget, Mock.targetFriendly = nil, true
		K.event(ns, "PLAYER_TARGET_CHANGED")
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" then fail(s, "lit on a friend") end
		Mock.targetFriendly, Mock.targetOutOfRange = nil, true
		K.event(ns, "PLAYER_TARGET_CHANGED")
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or why(ns) ~= "out of range" then fail(s, "lit out of range: " .. state(ns)) end
		Mock.targetOutOfRange = nil
		Mock.usable = { [8012] = { usable = false, noMana = true } }
		K.event(ns, "PLAYER_TARGET_CHANGED")
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or why(ns) ~= "not enough mana" then fail(s, "lit with no mana for it: " .. state(ns) .. " " .. why(ns)) end
		Mock.usable = nil
		K.event(ns, "PLAYER_TARGET_CHANGED")
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit once all is well: " .. state(ns) .. " " .. why(ns)) end
	end, SHAMAN)
end

do
	local s = name("Dispel Magic: the priest's row, named by the client, lit by a magic buff")
	with(s, function(ns)
		if ns.Moments.NameOf("dispel") ~= "Dispel Magic" then fail(s, "named " .. tostring(ns.Moments.NameOf("dispel"))) end
		Mock.targetBuffs = { { kind = "Magic" } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit: " .. state(ns) .. " " .. why(ns)) end
		if K.macro(ns, SLOT) ~= "/stopcasting\n/cast Dispel Magic" then fail(s, "the macro: " .. tostring(K.macro(ns, SLOT))) end
	end, PRIEST)
	s = name("Dispel Magic on Mists is 528, where 527 is Purify")
	with(s, function(ns)
		if not ns.Moments.Has("dispel") or ns.Moments.NameOf("dispel") ~= "Dispel Magic" then
			fail(s, "not learned from 528: " .. tostring(ns.Moments.NameOf("dispel")))
		end
	end, { class = "PRIEST", flavour = "mists", known = { 527, 528 } })
	s = name("Dispel Magic: a priest who knows only Purify gets no row")
	with(s, function(ns)
		if ns.Moments.Has("dispel") then fail(s, "Purify was taken for Dispel Magic") end
	end, { class = "PRIEST", flavour = "mists", known = { 527 } })
end

do
	local s = name("Tranquilizing Shot: an enrage lights it, a magic buff does not on Forever")
	with(s, function(ns)
		Mock.targetBuffs = { { kind = "Magic", steal = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or why(ns) ~= "nothing you can remove" then fail(s, "lit on magic: " .. state(ns) .. " " .. why(ns)) end
		look(ns, { { kind = "Magic" }, { kind = "" } })
		if state(ns) ~= "lit" then fail(s, "not lit by an enrage: " .. state(ns) .. " " .. why(ns)) end
		look(ns, { { kind = "Enrage" } })
		if state(ns) ~= "lit" then fail(s, "not lit by an aura named Enrage: " .. state(ns)) end
		if K.macro(ns, SLOT) ~= "/stopcasting\n/cast Tranquilizing Shot" then fail(s, "the macro: " .. tostring(K.macro(ns, SLOT))) end
	end, HUNTER)
	s = name("Tranquilizing Shot on Mists takes magic too")
	with(s, function(ns)
		Mock.targetBuffs = { { kind = "Magic" } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit by magic on Mists: " .. state(ns) .. " " .. why(ns)) end
	end, on(HUNTER, "mists"))
end

do
	local s = name("Shield Slam ships off: no macro until its switch is on, then lit, and no stopcasting")
	with(s, function(ns, _, profile)
		if not ns.Moments.Has("shieldslam") then fail(s, "a warrior has no Shield Slam row") return end
		if profile.moments.shieldslam ~= false then fail(s, "Shield Slam is on by default") end
		if K.macro(ns, SLOT) ~= nil then fail(s, "armed with its switch off") end
		profile.moments.shieldslam = true
		K.relearn(ns)
		Mock.targetBuffs = { { kind = "Magic" } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit once on: " .. state(ns) .. " " .. why(ns)) end
		if K.macro(ns, SLOT) ~= "/cast Shield Slam" then fail(s, "the macro: " .. tostring(K.macro(ns, SLOT))) end
	end, warrior())
	s = name("Shield Slam: no row on retail, where it no longer dispels")
	with(s, function(ns)
		if ns.Moments.Has("shieldslam") then fail(s, "a retail warrior has the row") end
	end, { class = "WARRIOR", flavour = "mainline", known = { 23922 } })
end

do
	local s = name("withheld, in a group: the hidden flags are ORed by the game, and it takes two clicks")
	with(s, function(ns)
		Mock.groupSize = 2
		Mock.buffsWithheld = true
		Mock.targetBuffs = { { steal = false, dispel = true }, { steal = false } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "game" then fail(s, "not left to the game: " .. state(ns) .. " " .. why(ns)) end
		if K.shown(ns, SLOT) ~= 0 then fail(s, "shown with nothing to remove") end
		look(ns, { { steal = true, dispel = true }, { steal = false } })
		if K.shown(ns, SLOT) ~= 1 then fail(s, "not shown with a buff to remove: " .. tostring(K.shown(ns, SLOT))) end
		if #Mock.secretOnSecure > 0 or Mock.secureAlphaWrites ~= 0 then fail(s, "a hidden value reached a secure frame") end
		local hit = K.click(ns, SLOT)
		if hit == ns.Moments:Button(SLOT) then fail(s, "one click reached a game-painted Purge") end
		Mock.runTimers(0.5)
		hit = K.click(ns, SLOT)
		if hit ~= ns.Moments:Button(SLOT) then fail(s, "the second click did not reach it") end
	end, SHAMAN)
	s = name("withheld, on your own: the game's filter decides plainly")
	with(s, function(ns)
		Mock.buffsWithheld = true
		Mock.targetBuffs = { { steal = true, dispel = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "lit" then fail(s, "not lit by the filter: " .. state(ns) .. " " .. why(ns)) end
		look(ns, { { steal = true } })
		if state(ns) ~= "dark" or why(ns) ~= "nothing you can remove" then fail(s, "not dark with an empty filter: " .. state(ns) .. " " .. why(ns)) end
	end, SHAMAN)
	s = name("only the kinds hidden: in a group Tranquilizing Shot stays dark, on your own the filter lights it")
	with(s, function(ns)
		Mock.groupSize = 2
		Mock.kindsHidden = true
		Mock.targetBuffs = { { kind = "", dispel = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or K.shown(ns, SLOT) ~= 0 then fail(s, "lit in a group on a buff somebody else may remove: " .. state(ns)) end
		Mock.groupSize = nil
		look(ns, { { kind = "", dispel = true } })
		if state(ns) ~= "lit" then fail(s, "not lit on your own: " .. state(ns) .. " " .. why(ns)) end
	end, HUNTER)
	s = name("the filter refused: asked once, said in the trail, and the button stays dark")
	with(s, function(ns)
		Mock.kindsHidden = true
		Mock.filterThrows = true
		Mock.targetBuffs = { { kind = "", dispel = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" then fail(s, "lit with the filter refused: " .. state(ns)) end
		if not ns.Sense.listRefused then fail(s, "the refusal was not kept") end
		look(ns, { { kind = "", dispel = true } })
		if state(ns) ~= "dark" then fail(s, "lit after the refusal") end
		if ns.errors and #ns.errors > 0 then fail(s, "the refusal was thrown on: " .. tostring(ns.errors[1].err)) end
	end, HUNTER)
	s = name("records hidden whole, in a group: dark")
	with(s, function(ns)
		Mock.groupSize = 2
		Mock.buffsHidden = true
		Mock.targetBuffs = { { kind = "Magic", steal = true, dispel = true } }
		K.pull(ns)
		K.tick(ns, 0.3)
		if state(ns) ~= "dark" or K.shown(ns, SLOT) ~= 0 then fail(s, "lit with the records hidden: " .. state(ns)) end
	end, SHAMAN)
end

do
	local s = name("the rows per client: the ids of each, slot 8, two clicks, defaults")
	with(s, function(ns)
		local want = {
			camelot = { SHAMAN = { "purge", 8012 }, PRIEST = { "dispel", 988 }, HUNTER = { "tranq", 19801 }, WARRIOR = { "shieldslam", 23925 } },
			vanilla = { SHAMAN = { "purge", 8012 }, PRIEST = { "dispel", 988 }, HUNTER = { "tranq", 19801 }, WARRIOR = { "shieldslam", 23925 } },
			tbc = { SHAMAN = { "purge", 8012 }, PRIEST = { "dispel", 988 }, HUNTER = { "tranq", 19801 }, WARRIOR = { "shieldslam", 30356 } },
			mists = { SHAMAN = { "purge", 370 }, PRIEST = { "dispel", 528 }, HUNTER = { "tranq", 19801 }, WARRIOR = { "shieldslam", 23922 } },
			mainline = { SHAMAN = { "purge", 370 }, PRIEST = { "dispel", 528 }, HUNTER = { "tranq", 19801 } },
		}
		for flavour, classes in pairs(want) do
			for class, w in pairs(classes) do
				local found
				for _, row in ipairs(ns.Moments.Sets[flavour][class] or {}) do
					if row.key == w[1] then found = row end
				end
				if not found then fail(s, flavour .. " " .. class .. " has no " .. w[1])
				else
					if found.ranks[1] ~= w[2] then fail(s, flavour .. " " .. w[1] .. " starts at " .. tostring(found.ranks[1])) end
					if found.slot ~= 8 or found.guard ~= "twice" then fail(s, flavour .. " " .. w[1] .. ": slot or clicks") end
					if found.needs[#found.needs] ~= "removable" then fail(s, flavour .. " " .. w[1] .. " does not wait for a buff to remove") end
				end
			end
			if (ns.Moments.Sets[flavour].WARRIOR or {})[1] and flavour == "mainline" then fail(s, "retail has a warrior row") end
		end
		if ns.MOMENT_DEFAULTS.shieldslam ~= false or ns.MOMENT_DEFAULTS.purge ~= true
			or ns.MOMENT_DEFAULTS.dispel ~= true or ns.MOMENT_DEFAULTS.tranq ~= true then
			fail(s, "the defaults")
		end
		local mistsTranq, oldTranq
		for _, row in ipairs(ns.Moments.Sets.mists.HUNTER) do if row.key == "tranq" then mistsTranq = row end end
		for _, row in ipairs(ns.Moments.Sets.camelot.HUNTER) do if row.key == "tranq" then oldTranq = row end end
		if not (mistsTranq.kinds.Magic and mistsTranq.purge) then fail(s, "Mists' Tranquilizing Shot does not take magic") end
		if oldTranq.kinds.Magic or oldTranq.purge then fail(s, "Forever's Tranquilizing Shot takes magic") end
	end)
end

do
	local s = name("the options: the switch says the client's name and shows for the class that has it")
	with(s, function(ns)
		local look = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.appearance
		local node = look and look.args and look.args.momentPurge
		if not node then fail(s, "no Purge control") return end
		local text = type(node.name) == "function" and node.name() or node.name
		if text ~= "Show Purge when my target has a buff I can remove" then fail(s, "the name: " .. tostring(text)) end
		if node.hidden() then fail(s, "hidden for a shaman") end
		local slam = look.args.momentShieldslam
		if not slam or not slam.hidden() then fail(s, "Shield Slam shows for a shaman") end
		local desc = slam and (type(slam.desc) == "function" and slam.desc() or slam.desc) or ""
		if not desc:find("Off at first", 1, true) then fail(s, "Shield Slam's words do not say it ships off: " .. desc) end
	end, SHAMAN)
end
