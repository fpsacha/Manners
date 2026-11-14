-- Manners -- things said once, so a default does not read as a fault.
--
-- The first of them: your own buffs wait while the game calls you resting, in
-- a city or an inn (Queue.lua, HeldBackExceptList: "resting"; Who to buff,
-- Also in cities and inns, off). Most players log in at an inn, and a warlock
-- wrote on CurseForge that with no Demon Armor at login "the addon dont pop up
-- to buff". The rule stands (nobody needs Inner Fire at the auction house);
-- what was missing is anybody saying so. Said once a character, a little
-- after the screen is up, and only when something of yours is in fact missing.

local addonName, ns = ...
local L = ns.L

-- How long after the world loads the line is said: the first scans are over
-- and the login's own chat lines have gone by.
local AFTER = 12

-- Whether a buff of yours would be on the prompt now, were you not resting:
-- any family of your class's own whose verdict names a spell to cast, or the
-- buff you give everybody, missing on yourself (a druid's Mark of the Wild, a
-- priest's Fortitude: Queue.lua, SelfEntry, held back by the same answer).
local function SomethingOfYours(profile, now)
	local name = ns.UnitFullName("player")
	if not name then return false end
	local ctx = { name = name, now = now, whenBuffed = "skip" }
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		if ns.OwnVerdict(family, ctx) then return true end
	end
	return ns.SelfBuffFirst(profile, now, true) ~= nil
end

-- Says it, when it applies and has not been said to this character; true when
-- it was said. Never in a fight, never with Myself off (MyselfHeldBack
-- answers something else then), never with nothing of yours missing. Nor with
-- Manners switched off or snoozed: nothing would come up on leaving, and the
-- once is kept for a login where the line is true.
function ns.RestingHint(now)
	local db = ns.db
	if not (db and db.profile and db.char) then return false end
	local hints = db.char.hints
	if type(hints) == "table" and hints.resting then return false end
	if not db.profile.enabled or ns.SnoozeLeft(now) then return false end
	if ns.MyselfHeldBack(db.profile, now) ~= "resting" then return false end
	if not SomethingOfYours(db.profile, now) then return false end
	if type(hints) ~= "table" then
		hints = {}
		db.char.hints = hints
	end
	hints.resting = true
	ns.addon:Print(L["Your own buffs wait while you rest in a city or an inn, and come up when you leave. To be reminded in town too, tick %s on %s."]:format(
		"|cffffd100" .. L["Also in cities and inns"] .. "|r", "|cffffd100" .. L["Who to buff"] .. "|r"))
	return true
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function()
	if not (C_Timer and C_Timer.After) then return end
	C_Timer.After(AFTER, function()
		ns.Guard("resting hint", function() ns.RestingHint(GetTime()) end)
	end)
end)
