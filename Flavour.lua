-- Manners -- which client this is.
--
-- Five live clients run this addon, and they disagree about things no API will
-- answer: whether a macro conditional can name a player, whether the second
-- return of UnitName is a realm or a surname, whether the combat log exists at
-- all. Anything that cannot be probed has to be decided from the client's
-- identity, so the identity is worked out once, here, and every later file asks
-- this file rather than re-deriving it and getting a different answer.
--
-- Loaded first in the toc for that reason: Buffs.lua chooses which data set to
-- publish and Core.lua decides what it is allowed to do, and both need this
-- before they run.
--
-- The five, as of September 2026, and the toc each would load:
--
--   retail "Midnight" 12.1   interface 120100+   Manners_Mainline.toc (not shipped)
--   WoW Forever 1.60.1       interface 16001     Manners_Camelot.toc
--   Mists of Pandaria        interface 50504     Manners_Mists.toc (not shipped)
--   BC Classic Anniversary   interface 20506     (none -- see below)
--   Classic Era 1.15.9       interface 11509     Manners_Vanilla.toc (not shipped)
--
-- 1.0 ships for WoW Forever alone: Manners_Camelot.toc and Manners.toc, whose
-- interface number is 16001 too, are the only tocs in the package. The other
-- three are recognised here and implemented throughout, but nobody has run the
-- addon on them, so their tocs are commented out in tools/maketocs.py until
-- somebody does.
--
-- There is no Manners_TBC.toc on purpose, and there would not be even then. A
-- 2.5 client applies Burning Crusade spell ranks, whose ids are in none of the
-- tables here, so the addon would load and offer nobody anything. The band
-- stays recognised so such a client is named rather than guessed at. Add the
-- ids before adding the toc.

local ADDON, ns = ...
-- Player-facing text, in the client's language: see Locales/Init.lua.
local L = ns.L

-- issecretvalue is simply absent on the clients that never had secret values,
-- so it is normalised once rather than guarded at every call site.
--
-- Local, not global. An addon that writes _G.issecretvalue hands every other
-- addon on the machine its own idea of what is secret, and the day a client
-- ships the real one it would find ours already sitting there. Core.lua's
-- plain() already copes with the function being missing, so nothing else in
-- this project needs a shim -- this one exists because Flavour.lua runs before
-- Core.lua and has no ns.plain to borrow yet.
local issecretvalue = _G.issecretvalue or function() return false end

-- Anything the client hands back may be a secret value, which throws on
-- comparison, so everything branched on here passes through this first. The
-- long version of the comment is in Core.lua, next to the copy this one
-- duplicates on purpose: sharing it would mean loading Core.lua first, which is
-- the one thing this file cannot allow.
local function plain(v)
	if issecretvalue(v) then return nil end
	return v
end

---------------------------------------------------------------------------
-- the interface number
---------------------------------------------------------------------------

-- The bands, in the order they are tried, and the order is load-bearing.
--
-- Forever's 16001 and Classic Era's 11509 are both five digits starting with a
-- 1, so anything that matches on a leading digit -- or on "how many digits is
-- it" -- calls Forever vanilla. That failure is invisible in testing, because
-- vanilla content is exactly what Forever runs: the addon would hand a Forever
-- mage the vanilla tables and they would mostly work. Camelot is therefore
-- tried first, and every band states both of its ends rather than a prefix, so
-- adding a sixth cannot reopen this by accident.
--
-- "family" is the thing the rest of the addon actually branches on: "classic"
-- means the combat log is available, "modern" means it is gone and secret
-- values apply. It is not a guess about the artwork.
local BANDS = {
	{ flavour = "camelot", family = "modern", min = 16000, max = 16999 },
	-- Retail went six-digit at 100000 and has stayed there; nothing else is.
	{ flavour = "mainline", family = "modern", min = 100000, max = 999999 },
	{ flavour = "mists", family = "classic", min = 50000, max = 59999 },
	{ flavour = "tbc", family = "classic", min = 20000, max = 29999 },
	{ flavour = "vanilla", family = "classic", min = 11000, max = 11999 },
}

local function BandFor(interface)
	for _, band in ipairs(BANDS) do
		if interface >= band.min and interface <= band.max then return band end
	end
end

---------------------------------------------------------------------------
-- the project id, as a cross-check only
---------------------------------------------------------------------------

-- WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC is true wherever both names
-- are nil.
--
-- A client old enough to predate WOW_PROJECT_ID, asked about a constant it
-- never had either, compares nil with nil, and every such test passes at once.
-- On retail and on Forever WOW_PROJECT_ID is 1, so a missing constant there
-- makes the comparison false -- the right answer, but only by luck, since it
-- says nothing about whether the constant was ever meant to be asked. That is
-- the reason this addon does not trust the project id for anything on its own,
-- and the reason both sides are required to be numbers before the comparison
-- is allowed to mean anything.
--
-- The constant is looked up by name rather than written as an identifier so
-- that a typo reads as "this client does not have it" instead of quietly
-- becoming a nil global at the top of the file.
local function ProjectIs(name)
	local id = plain(_G.WOW_PROJECT_ID)
	local want = plain(_G[name])
	if type(id) ~= "number" or type(want) ~= "number" then return false end
	return id == want
end

-- What the project id can and cannot settle.
--
-- WOW_PROJECT_MAINLINE is 1 on retail and 1 on Forever -- Forever is a fork of
-- Midnight, not a separate project -- so it names a family and never a flavour.
-- Telling those two apart is the interface number's job and nothing else's.
local BY_PROJECT = {
	{ constant = "WOW_PROJECT_MISTS_CLASSIC", flavour = "mists", family = "classic" },
	{ constant = "WOW_PROJECT_BURNING_CRUSADE_CLASSIC", flavour = "tbc", family = "classic" },
	{ constant = "WOW_PROJECT_CLASSIC", flavour = "vanilla", family = "classic" },
	{ constant = "WOW_PROJECT_MAINLINE", flavour = nil, family = "modern" },
}

local function ByProject()
	for _, entry in ipairs(BY_PROJECT) do
		if ProjectIs(entry.constant) then return entry end
	end
end

---------------------------------------------------------------------------
-- deciding
---------------------------------------------------------------------------

local function Decide()
	local out = {}

	local build, _build, _date, interface = GetBuildInfo()
	out.build = plain(build)
	out.interface = tonumber(plain(interface))
	out.project = tonumber(plain(_G.WOW_PROJECT_ID))

	local band = out.interface and BandFor(out.interface)
	local project = ByProject()

	if band then
		out.flavour, out.family = band.flavour, band.family
		out.source = "interface"
		out.recognised = true

		-- Recorded, not acted on. If a client ever reports a number in one
		-- family and a project id in another, the interface number wins --
		-- it is the finer-grained of the two and the only one that can tell
		-- Forever from retail -- but a bug report from a client nobody here
		-- can run is worth far more with the disagreement printed on it.
		if project then
			out.agrees = (project.family == band.family)
				and (project.flavour == nil or project.flavour == band.flavour)
		end
	elseif project then
		-- An interface number nobody here has seen. Classified, never
		-- rejected: a client this addon does not recognise still has a user
		-- in front of it, and refusing to load is a worse answer than
		-- carrying on with the family the project id admits to.
		out.flavour = project.flavour or "unknown"
		out.family = project.family
		out.source = "project"
		out.recognised = false
	else
		out.flavour = "unknown"
		-- Modern is the safe guess when there is nothing at all to go on.
		-- Assuming the combat log exists when it does not means registering
		-- an event that throws and losing whatever handler it was in;
		-- assuming it is gone when it is there costs one source of sightings
		-- the aura scan already covers. The two mistakes are not the same
		-- size.
		out.family = "modern"
		out.source = "nothing to go on"
		out.recognised = false
	end

	return out
end

-- Wrapped because a client without GetBuildInfo must not take the addon down
-- with it. ns.Guard lives in Core.lua, which has not loaded yet, so this is the
-- one place in the project that calls pcall directly.
local ok, decided = pcall(Decide)
if not ok or type(decided) ~= "table" then
	decided = {
		flavour = "unknown",
		family = "modern",
		source = "GetBuildInfo failed",
		recognised = false,
		err = not ok and tostring(decided) or nil,
	}
end

ns.Flavour = decided

-- How each way of deciding reads in the summary below. `source` itself stays
-- the English word, because it is compared as a value; only what is printed
-- from it is translated. Each note is one whole key, brackets included, since
-- "decided by" reads differently in most languages before a noun, an idiom and
-- a failure. "(by project)" means by the WOW_PROJECT_ID the client reports,
-- which the summary prints just before it as project=.
local SOURCE_TEXT = {
	project = L["(by project)"],
	["nothing to go on"] = L["(by nothing to go on)"],
	["GetBuildInfo failed"] = L["(by GetBuildInfo failed)"],
}

-- One line, meant to be pasted into an issue. Four of the five clients cannot
-- be tested by anybody working on this addon, so a user running one command is
-- the cheapest evidence there is -- and it is only evidence if it says which
-- client it came from.
--
-- The key=value part is left in English on purpose: it is read by whoever
-- takes the report, and the words in it are field names, not sentences.
function ns.FlavourSummary()
	local f = ns.Flavour or {}
	local out = ("%s/%s interface=%s build=%s project=%s"):format(
		tostring(f.flavour), tostring(f.family), tostring(f.interface),
		tostring(f.build), tostring(f.project))
	if f.source and f.source ~= "interface" then
		-- A source this file does not set cannot have a translation, so it is
		-- shown as it is.
		out = out .. " " .. (SOURCE_TEXT[f.source] or ("(by %s)"):format(tostring(f.source)))
	end
	if f.agrees == false then
		out = out .. " |cffff8080" .. L["interface and project id disagree"] .. "|r"
	end
	if f.err then
		out = out .. " |cffff8080" .. L["GetBuildInfo threw: %s"]:format(tostring(f.err)) .. "|r"
	end
	return out
end
