-- Four faults in Queue.lua that a triage of old bug-hunt candidates proved with
-- a red scenario each (STATUS.md, "Bug-hunt candidates never checked"): the
-- refusal back-off keeping the player from the person they have selected, a
-- namesake from another realm read as a friend, a group member offered from
-- the passer-by memory with "People in my group" off, and your own buff said to
-- come first while your name is on the never-offer list. Every name starts with
-- "hunt23-queue:" and then the fault's own words, so a mutation can name exactly
-- one; a scenario run against several clients says so in its name, and a control
-- that fails reads "SKIPPED --".

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

-- Globals a scenario replaces, put back after it whether it finished or threw.
local TOUCHED = { "C_FriendList", "C_Secrets", "UnitExists", "UnitName", "IsSpellKnown", "IsPlayerSpell" }

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
		-- The client names nobody for a unit that is not there; the mock answers a
		-- stand-in. Matters for a cleared target, which UnitName("target") then
		-- reads as nil, as the client does.
		local named = UnitName
		rawset(_G, "UnitName", function(unit)
			if unit == "target" and names.target == nil then return nil end
			return named(unit)
		end)
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

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
end

-- Lines in chat saying the game keeps refusing somebody.
local function told()
	local out = {}
	for _, line in ipairs(Mock.printed) do
		if line:find("keeps refusing", 1, true) then out[#out + 1] = line end
	end
	return out
end

-- ------------------------------------------------------ the back-off
-- queue-liftbackoff-needs-target-change-event (Queue.lua NoteRefusal,
-- LiftBackoff; Core.lua PLAYER_TARGET_CHANGED)
--
-- "The back-off must never keep the player from somebody they point at": that
-- is the comment above PLAYER_TARGET_CHANGED, and the back-off is lifted only
-- by that event. Somebody who is already the target when the game refuses the
-- third press on them (out of range, say) was backed off for five minutes
-- while standing selected, and no event could lift it: selecting the unit that
-- is selected fires nothing. The chat line said "target them to try again";
-- the player had to clear the target and select them anew. IterateUnits walks
-- "target" as a pointed unit, and visit() turned it away on IsBlocked like
-- anybody.
--
-- But the prompt's own macro makes somebody the target too, and leaves them so
-- where "Hand my target back" is off or nothing was targeted before: that is
-- no choice of the player's (PLAYER_TARGET_CHANGED ignores it), and somebody
-- the game refuses that way must still be let go, or the first reason for the
-- back-off (a prompt that comes straight back, for good) returns.
do
	local scenario = "hunt23-queue: your own target is not backed off while you point at them"
	local function refuseThrice(ns)
		for _ = 1, 3 do
			ns.NoteRefusal("Anna Aim", "Out of range.", nil, true)
			Mock.advance(3)
		end
	end
	-- Control: the same three refusals on somebody who is only on a nameplate
	-- back her off, which is what the back-off is for.
	run(scenario, "camelot", "MAGE", { nameplate1 = { "Anna", "Aim" } }, function(ns)
		Mock.advance(60)
		if not entryFor(ns, "Anna Aim") then
			fail(scenario, "SKIPPED -- Anna on a nameplate was not offered to begin with")
			return
		end
		refuseThrice(ns)
		Mock.advance(20)
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "SKIPPED -- three refusals did not back off somebody on a nameplate")
		end
	end)
	-- The player selects Anna (the client sends PLAYER_TARGET_CHANGED once, as
	-- the target changes) and presses on her three times. Selecting her again
	-- afterwards sends nothing, so nothing is sent here.
	run(scenario, "camelot", "MAGE", { target = { "Anna", "Aim" }, nameplate1 = { "Anna", "Aim" } }, function(ns)
		ns.addon:PLAYER_TARGET_CHANGED()
		Mock.advance(60)
		local before = entryFor(ns, "Anna Aim")
		if not (before and before.unit == "target") then
			fail(scenario, "SKIPPED -- Anna, the standing target, was not offered to begin with")
			return
		end
		Mock.printed = {}
		refuseThrice(ns)
		Mock.advance(20)
		if not entryFor(ns, "Anna Aim") then
			fail(scenario, "Anna has been the player's own target throughout, and after the third refusal the"
				.. " back-off keeps her off the prompt for minutes with nothing that lifts it: the lift"
				.. " waits for a PLAYER_TARGET_CHANGED that selecting the selected unit never sends")
		end
		local lines = told()
		if #lines > 0 then
			fail(scenario, "chat says she will not be offered for a while and to target her to try again,"
				.. " though she is the target and is still offered: " .. lines[1])
		end
		-- The refusals still count: the player moves on to somebody else, and the
		-- next refusal on Anna, now only a passer-by, is her fourth in a row.
		Mock.unitNames.target = nil
		ns.addon:PLAYER_TARGET_CHANGED()
		Mock.advance(3)
		local passerBy = entryFor(ns, "Anna Aim")
		if not (passerBy and passerBy.unit ~= "target") then
			fail(scenario, "SKIPPED -- Anna was not offered as a passer-by once the target was cleared")
			return
		end
		ns.NoteRefusal("Anna Aim", "Out of range.", nil, true)
		Mock.advance(20)
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "the refusals on her as the player's target were not counted: the fourth in a row,"
				.. " as a passer-by, did not back her off")
		end
	end)
	-- Somebody who was selected, and is not any more (the player cleared the
	-- target, an event the player sent): a later press on her is anybody's. The
	-- macro's own /target makes her the target again, and three refusals back her
	-- off, though she was the player's pick once.
	run(scenario, "camelot", "MAGE", { target = { "Anna", "Aim" }, nameplate1 = { "Anna", "Aim" } }, function(ns)
		ns.addon:PLAYER_TARGET_CHANGED()
		Mock.unitNames.target = nil
		ns.addon:PLAYER_TARGET_CHANGED()
		Mock.advance(60)
		if not entryFor(ns, "Anna Aim") then
			fail(scenario, "SKIPPED -- Anna on a nameplate was not offered after the target was cleared")
			return
		end
		for _ = 1, 3 do
			Mock.unitNames.target = { "Anna", "Aim" }
			ns.pressAt = GetTime()
			ns.addon:PLAYER_TARGET_CHANGED()
			ns.NoteRefusal("Anna Aim", "Out of range.", nil, true)
			Mock.advance(3)
		end
		Mock.advance(20)
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "somebody the player selected once and cleared again, whom the macro then targeted,"
				.. " was not backed off after three refusals")
		end
	end)
end

do
	local scenario = "hunt23-queue: somebody the macro targeted is still backed off"
	-- Nobody targeted by the player; "Hand my target back" off, so what the
	-- prompt's own /target picked stays the target (a press with nothing
	-- targeted before it leaves them so on the client too). Each press moves the
	-- target within the half second PLAYER_TARGET_CHANGED ignores, as a press
	-- does, and is refused.
	run(scenario, "camelot", "MAGE", { nameplate1 = { "Anna", "Aim" } }, function(ns)
		ns.db.profile.filters.restoreTarget = false
		Mock.advance(60)
		if not entryFor(ns, "Anna Aim") then
			fail(scenario, "SKIPPED -- Anna on a nameplate was not offered to begin with")
			return
		end
		for _ = 1, 3 do
			Mock.unitNames.target = { "Anna", "Aim" }
			ns.pressAt = GetTime()
			ns.addon:PLAYER_TARGET_CHANGED()
			ns.NoteRefusal("Anna Aim", "Out of range.", nil, true)
			Mock.advance(3)
		end
		Mock.advance(20)
		if entryFor(ns, "Anna Aim") then
			fail(scenario, "the macro's own /target made Anna the target, and three refusals on her did not"
				.. " back her off: a prompt the game keeps refusing comes straight back, for good")
		end
		if #told() ~= 1 then
			fail(scenario, "the third refusal did not say so in chat once: " .. #told() .. " lines")
		end
	end)
end

