-- Manners -- things said once, so a default does not read as a fault.
--
-- The first of them: your own buffs wait while the game calls you resting, in
-- a city or an inn (Queue.lua, HeldBackExceptList: "resting"; Who to buff,
-- Also in cities and inns, off). Most players log in at an inn, and a warlock
-- wrote on CurseForge that with no Demon Armor at login "the addon dont pop up
-- to buff". The rule stands (nobody needs Inner Fire at the auction house);
-- what was missing is anybody saying so. Said once a character, a little
-- after the screen is up, and only when something of yours is in fact missing.
-- The second, ns.UnnamedBuffHint, is below.

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
	-- Nor with Hide all Manners messages on: the line would be dropped
	-- (Core.lua, addon:Print), and must not be counted as said.
	if db.profile.silentChat == true then return false end
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

-- The second: somebody's class buff landed on you and the game gave no token
-- for the caster (Favours.lua, Sight), so there is nobody to buff back. On
-- WoW Forever, with no combat log, a stranger is named only through a token,
-- and with the game's friendly nameplates off, as a fresh install has them, a
-- passer-by has none: the buff came, and nothing came up and nothing was
-- said. Said once a session, on three sessions a character at most
-- (`hints.unnamed` counts them), and only when the nameplates are why: out of
-- a fight, where a caster withheld looks the same as none, and with the
-- client saying plainly that they are off.
local UNNAMED_SESSIONS = 3
local unnamedSaid = false

-- The line names what can be done: the nameplates, and, for a player who
-- thanks with an emote, Thank them even when I can't see who it was. With
-- that on, and the caster plainly nobody (`unseen`, Favours.lua's Sight: not
-- withheld), it says the emote thanks them where it may, never that nothing
-- could be done.
function ns.UnnamedBuffHint(unseen)
	if unnamedSaid then return false end
	local db = ns.db
	if not (db and db.profile and db.char) then return false end
	if InCombatLockdown() or db.profile.silentChat == true then return false end
	if not ns.FriendlyPlatesOff() then return false end
	local hints = db.char.hints
	local told = type(hints) == "table" and type(hints.unnamed) == "number" and hints.unnamed or 0
	unnamedSaid = true
	if told >= UNNAMED_SESSIONS then return false end
	if type(hints) ~= "table" then
		hints = {}
		db.char.hints = hints
	end
	hints.unnamed = told + 1
	local plates = "|cffffd100" .. L["Show friendly nameplates"] .. "|r"
	local start = "|cffffd100" .. L["Start here"] .. "|r"
	local prompt = type(db.profile.prompt) == "table" and db.profile.prompt or {}
	if prompt.thankEmote == true and prompt.thankUnseen == true and unseen == true then
		ns.addon:Print(L["Somebody just buffed you, but with friendly nameplates off the game would not say who. Manners thanks them with your emote where it may, but cannot buff them back: %s on %s (|cffffd100/manners|r) turns them on."]:format(
			plates, start))
	elseif prompt.thankEmote == true and prompt.thankUnseen ~= true then
		ns.addon:Print(L["Somebody just buffed you, but with friendly nameplates off the game would not say who, so Manners cannot buff them back or thank them. %s on %s (|cffffd100/manners|r) turns them on, or %s on %s thanks them with your emote all the same."]:format(
			plates, start, "|cffffd100" .. L["Thank them even when I can't see who it was"] .. "|r",
			"|cffffd100" .. L["What I say"] .. "|r"))
	else
		ns.addon:Print(L["Somebody just buffed you, but with friendly nameplates off the game would not say who, so Manners cannot buff them back. %s on %s (|cffffd100/manners|r) turns them on."]:format(
			plates, start))
	end
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
