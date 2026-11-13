-- Manners -- options: the Diagnostics tab.

local _, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local B, HasClassBuffs, OnlyReachesGroup, TAB = Page.B, Page.HasClassBuffs, Page.OnlyReachesGroup, Page.TAB

-- Everything somebody would otherwise be asked for twice, in one block that can
-- be selected and pasted. No colour codes: this is written to be quoted
-- somewhere that is not a chat frame.
local function BugReport()
	local lines = { ("Manners %s"):format(tostring(ns.BUILD)) }

	-- Guarded: this is read from a `get`, which nothing wraps, and must not take
	-- the page down while somebody is reporting a bug.
	local ok, version, build, _, toc = pcall(GetBuildInfo)
	if ok and version then
		lines[#lines + 1] = ("client %s (%s), interface %s")
			:format(tostring(version), tostring(build), tostring(toc))
	end

	local caps = ns.caps
	lines[#lines + 1] = ("class %s | secrets %s | auras secret now %s | nameplates %s")
		:format(tostring(caps.class), tostring(caps.hasSecrets),
			tostring(caps.aurasSecretNow), tostring(caps.namePlates))
	-- Which spell tables this client was handed, so a spell never offered can be
	-- told from one that does not exist on the reporter's client.
	lines[#lines + 1] = ("buff data %s%s"):format(tostring(ns.BUFFS_SOURCE),
		ns.BUFFS_MISSING and (" -- " .. tostring(ns.BUFFS_MISSING)) or "")

	for _, buff in ipairs(ns.GetClassBuffs(caps.class) or {}) do
		local info = ns.BuffInfo(buff)
		lines[#lines + 1] = ("  %-12s known=%s readable=%s off=%s"):format(
			buff.key,
			tostring(info and info.known),
			tostring(info and info.readable),
			tostring(ns.BuffOff(buff, B())))
		if info and info.unresolved and #info.unresolved > 0 then
			lines[#lines + 1] = ("    no such spell on this client: %s"):format(
				table.concat(info.unresolved, ", "))
		end
		-- The group version the prompt would cast, and the reagent it would
		-- eat as the bags hold it now: "never offers the group buff" is most
		-- often answered here.
		if info and info.groupRank then
			local count = ns.ReagentCount and ns.ReagentCount(info.groupReagent)
			-- Forever's Reagent Economy, as GroupBuffs.lua reads it.
			local waived = ns.ReagentWaived and ns.ReagentWaived(info, count)
			lines[#lines + 1] = ("    group spell %s, reagent %s x%s%s"):format(
				tostring(info.groupRank), tostring(info.groupReagent), tostring(count),
				waived and " (waived: the client says it is usable without)" or "")
		end
	end

	-- The settings that change what it does, rather than how it looks. A report
	-- that leaves these out is a report about the defaults. The /thank is one:
	-- with it on, somebody buffing you is noticed even with owed off.
	local db = ns.db.profile
	lines[#lines + 1] = ("enabled=%s buff=%s sources owed/group/strangers/self=%s/%s/%s/%s"
		.. " whenBuffed=%s targetFirst=%s keepDebts=%s thank=%s"):format(
		tostring(db.enabled), tostring(db.buff.choice),
		tostring(db.sources.owed), tostring(db.sources.group), tostring(db.sources.strangers),
		tostring(db.sources.self),
		tostring(db.filters.whenBuffed), tostring(db.priority.target),
		tostring(db.timing.keepDebts), tostring(db.prompt.thankEmote))
	-- "Myself": where, and per family you know its pick and the one last up
	-- (key=pick/last), which is what Automatic reads.
	local picks = {}
	local memory = type(ns.db.char) == "table" and ns.db.char.ownLast
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		picks[#picks + 1] = ("%s=%s/%s"):format(family.key, tostring((ns.OwnPick(family))),
			tostring(type(memory) == "table" and memory[family.key] or nil))
	end
	lines[#lines + 1] = ("own inCities=%s %s"):format(tostring(db.ownBuffs.inCities),
		#picks > 0 and table.concat(picks, " ") or "none known")
	-- Every scroll switched off at once (Who to buff, Scrolls), when it is.
	if db.ownBuffs.scrolls == false then lines[#lines + 1] = "own scrolls=off" end
	-- The spells ticked under Never remind me about, when there are any.
	local left = {}
	for key, on in pairs(db.ownBuffs.leave or {}) do
		if on == true then left[#left + 1] = key end
	end
	if #left > 0 then
		table.sort(left)
		lines[#lines + 1] = "own leftOut=" .. table.concat(left, ",")
	end
	-- A mage's scrolls in the bags, each with whether it can be used now
	-- (Core.lua, ScrollReady): a scroll never offered is most often a level
	-- or a weapon it does not fit.
	local scrolls = {}
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		for _, spell in ipairs(family.scroll and family.spells or {}) do
			local ready, why = ns.ScrollReady(spell)
			if why ~= "bags" then
				scrolls[#scrolls + 1] = ("%s=%s"):format(spell.key, ready and "ready" or tostring(why))
			end
		end
	end
	if #scrolls > 0 then lines[#lines + 1] = "scrolls " .. table.concat(scrolls, " ") end
	-- Who is ordered and who is held back: "my friend is never offered" is most
	-- often answered by the last number here.
	lines[#lines + 1] = ("friendsFirst=%s restingOnly=%s skipPvP=%s neverOffered=%d"):format(
		tostring(db.priority.friends), tostring(db.filters.restingOnly),
		tostring(db.filters.skipPvP), #ns.NeverList())
	-- The place rules, Offer nothing in cities and inns with where it holds,
	-- and the thank's pause and whisper.
	lines[#lines + 1] = ("quietInTowns=%s where=%s quietInInstances=%s quietTargets=%s thankWhisper=%s thankDelay=%s")
		:format(tostring(db.filters.quietInTowns), tostring(db.filters.quietInTownsWhere),
			tostring(db.filters.quietInInstances), tostring(db.filters.quietTargets),
			tostring(db.prompt.thankWhisper), tostring(db.prompt.thankDelay))
	-- A favour returned by refreshing what its giver already wears, when that
	-- is switched on (off, the default, lets such a favour go).
	if db.filters.repayCovered == true then lines[#lines + 1] = "repayCovered=on" end
	lines[#lines + 1] = ("groupBuffs=%s atLeast=%s"):format(
		tostring(db.groupBuffs.use), tostring(db.groupBuffs.atLeast))
	-- The dungeon and raid settings, each of which leaves people out or moves
	-- them up: the raid groups as the ones switched off.
	local skipped = {}
	for group = 1, 8 do
		if db.filters.skipRaidGroups[group] then skipped[#skipped + 1] = tostring(group) end
	end
	lines[#lines + 1] = ("manaFloor=%s readyCheckFirst=%s revivedFirst=%s raidGroupsOff=%s"):format(
		tostring(db.filters.manaFloor), tostring(db.priority.readyCheck),
		tostring(db.priority.revived), #skipped > 0 and table.concat(skipped, ",") or "none")

	local scan = ns.auraScan
	lines[#lines + 1] = ("own buffs: %s read, baseline %s, primed=%s, doubt=%s"):format(
		tostring(scan.read), tostring(scan.held), tostring(scan.primed), tostring(scan.doubt))

	-- The second favour source, left out entirely on a client with no combat
	-- log rather than reported as zeroes.
	if caps.combatLog then
		local log = ns.logScan
		lines[#lines + 1] = ("combat log: armed=%s, %s seen, %s filed"):format(
			tostring(log.armed), tostring(log.applied), tostring(log.noted))
	end

	if #ns.errors == 0 then
		lines[#lines + 1] = "errors: none this session"
	else
		-- How many have happened, then how many are still here to read: the
		-- ring holds thirty, so its length is not the count.
		lines[#lines + 1] = ("errors: %d this session (%d kept), last five:")
			:format(ns.errorCount or #ns.errors, #ns.errors)
		for i = math.max(1, #ns.errors - 4), #ns.errors do
			local e = ns.errors[i]
			lines[#lines + 1] = ("  %s %s -- %s"):format(
				tostring(e.at), tostring(e.where), tostring(e.err))
		end
	end

	return table.concat(lines, "\n")
end

-- The full check-up (Diagnostics, Run a full check-up): everything a bug report
-- is asked for, in one block. The bug report above, the self-test (Selftest.lua),
-- what /manners debug and /manners errors say, your own buffs' reasons and the
-- settings as /manners export writes them, each under a heading. The command
-- answers are caught as they print (addon:Print), not sent to chat. No colour
-- codes: it is written to be pasted into a comment or an issue.
local function Plain(text)
	return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("||", "|"))
end

function ns.FullReport()
	local lines = {
		L["Manners full check-up. Copy all of it (click in the box, Ctrl+A, Ctrl+C) and paste it into a comment on CurseForge or an issue at github.com/fpsacha/Manners/issues, with a few words on what went wrong."],
	}
	local addon = ns.addon
	-- Lines the aliasing leaves alone: the opening paragraph, the headings and
	-- the settings string, which are the report's own words.
	local fixed = { [1] = true }
	local function Section(title, fn)
		lines[#lines + 1] = ""
		lines[#lines + 1] = "== " .. title .. " =="
		fixed[#lines] = true
		local ok, err = pcall(fn)
		if not ok then lines[#lines + 1] = "(this part failed: " .. Plain(err) .. ")" end
	end
	-- What a command prints, caught line by line while it runs.
	local function Caught(fn)
		local real = addon.Print
		addon.Print = function(_, ...)
			local parts = {}
			for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
			lines[#lines + 1] = Plain(table.concat(parts, " "))
		end
		local ok, err = pcall(fn)
		addon.Print = real
		if not ok then error(err, 0) end
	end

	Section("Bug report", function()
		for line in (BugReport() .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = Plain(line) end
	end)
	Section("Self-test", function()
		if InCombatLockdown() then
			lines[#lines + 1] = "(not run: in a fight)"
			return
		end
		local text = ns.Selftest.Report(ns.Selftest.Run())
		for line in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = Plain(line) end
	end)
	Section("/manners debug", function() Caught(function() addon:HandleSlash("debug") end) end)
	Section("/manners errors", function() Caught(function() addon:HandleSlash("errors") end) end)
	Section("Your own buffs", function()
		for _, line in ipairs(ns.MyselfLines(GetTime()) or {}) do lines[#lines + 1] = Plain(line) end
	end)

	-- Other people are named by an alias (Person 1, Person 2...): the report is
	-- pasted in public, and what matters is which lines are about the same one.
	local alias, aliases = {}, 0
	local function Alias(name)
		if type(name) ~= "string" or name == "" then return nil end
		if not alias[name] then
			aliases = aliases + 1
			alias[name] = "Person " .. aliases
		end
		return alias[name]
	end

	Section("The queue now", function()
		local queue = ns.BuildQueue()
		lines[#lines + 1] = ("%d waiting"):format(#queue)
		for i, e in ipairs(queue) do
			lines[#lines + 1] = ("%d. %s -- %s, %s, priority %s%s%s"):format(i, tostring(Alias(e.name)),
				tostring(e.buff and e.buff.key), tostring(e.reason), tostring(e.priority),
				e.remaining and (", " .. math.floor(e.remaining) .. "s left") or "",
				e.groupCast and ", a group cast" or "")
		end
	end)
	Section("Where you are", function()
		local function Ask(fn, ...)
			if type(fn) ~= "function" then return "n/a" end
			local ok, a, b = pcall(fn, ...)
			if not ok then return "n/a" end
			a, b = ns.plain(a), ns.plain(b)
			if b ~= nil then return tostring(a) .. " " .. tostring(b) end
			return tostring(a)
		end
		lines[#lines + 1] = ("in a fight: %s, resting: %s, instance: %s, group members: %s, in a raid: %s"):format(
			Ask(_G.InCombatLockdown), Ask(_G.IsResting), Ask(_G.IsInInstance), Ask(_G.GetNumGroupMembers),
			Ask(_G.IsInRaid))
		lines[#lines + 1] = ("mounted: %s, flying: %s, level: %s, dead: %s"):format(Ask(_G.IsMounted),
			Ask(_G.IsFlying), Ask(_G.UnitLevel, "player"), Ask(_G.UnitIsDeadOrGhost, "player"))
		-- The map, and whether Manners reads it as a capital (Range.lua,
		-- ns.InCity): what Offer nothing in cities and inns' Where goes by.
		local maps = _G.C_Map
		lines[#lines + 1] = ("map: %s, a capital: %s"):format(
			type(maps) == "table" and Ask(maps.GetBestMapForUnit, "player") or "n/a",
			tostring(ns.InCity and ns.InCity()))
		local db = ns.db and ns.db.profile
		if db then
			lines[#lines + 1] = ("on: %s, locked: %s, snoozed: %s, preview: %s, options open: %s"):format(
				tostring(db.enabled), tostring(db.prompt.locked), tostring(ns.SnoozeLeft and ns.SnoozeLeft() ~= nil),
				tostring(ns.Prompt and ns.Prompt:InTest()), tostring(ns.OptionsOpen and ns.OptionsOpen()))
		end
	end)
	Section("The bar macro", function()
		local state = ns.BarMacroState and ns.BarMacroState() or nil
		lines[#lines + 1] = "state: " .. tostring(state)
		local body = ns.BarBodyNow and ns.BarBodyNow() or nil
		lines[#lines + 1] = "body: " .. (body and Plain(body):gsub("\n", " / ") or "(none)")
	end)
	Section("What happened lately", function()
		local trail = ns.db and ns.db.char and ns.db.char.trail or {}
		if #trail == 0 then
			lines[#lines + 1] = "(nothing yet this session)"
			return
		end
		for _, t in ipairs(trail) do
			local when = (type(t.at) == "number" and date("%H:%M:%S", t.at)) or "?"
			local who = t.who and (" [" .. tostring(Alias(t.who)) .. "]") or ""
			lines[#lines + 1] = ("%s %s%s %s"):format(when, tostring(t.kind), who, Plain(t.text))
		end
	end)
	Section("Other addons loaded", function()
		local addons = _G.C_AddOns
		local count = (addons and addons.GetNumAddOns) or _G.GetNumAddOns
		local info = (addons and addons.GetAddOnInfo) or _G.GetAddOnInfo
		local loaded = (addons and addons.IsAddOnLoaded) or _G.IsAddOnLoaded
		if type(count) ~= "function" or type(info) ~= "function" or type(loaded) ~= "function" then
			lines[#lines + 1] = "(the client will not say)"
			return
		end
		local names = {}
		for i = 1, count() do
			local name = info(i)
			if type(name) == "string" and name ~= "Manners" and loaded(name) then names[#names + 1] = name end
		end
		table.sort(names)
		lines[#lines + 1] = #names > 0 and table.concat(names, ", ") or "(none)"
	end)
	Section("Settings", function()
		lines[#lines + 1] = Plain(ns.ExportSettings and ns.ExportSettings() or "(none)")
		fixed[#lines] = true
	end)

	-- Last, over everything above: the names the queue and the trail know, and
	-- the ones /manners debug prints from elsewhere (somebody who asked from out
	-- of reach, one held back for PvP or backed off, one who owes you a return
	-- or was last thanked), each replaced by its alias wherever it was written.
	local function Heard(list)
		for _, line in ipairs(list or {}) do
			for name in tostring(line):gmatch("|cffffffff(.-)|r") do Alias(name) end
		end
	end
	pcall(function() Heard(ns.RequestLines()) end)
	pcall(function() Heard(ns.RefusalLines(GetTime())) end)
	pcall(function() Heard(ns.PvPLines()) end)
	for name in pairs(ns.owed or {}) do Alias(name) end
	local thanks = ns.thankLog or {}
	if thanks.thanked then Alias(thanks.thanked.name) end
	if thanks.skipped then Alias(thanks.skipped.name) end
	local names = {}
	for name in pairs(alias) do names[#names + 1] = name end
	-- The longest first, so "Anna Aim" goes before "Anna".
	table.sort(names, function(a, b) return #a > #b end)
	-- A name is a whole word: a letter, digit or underscore on either side
	-- (accented letters included) means it is part of something longer.
	local function Part(c) return c ~= "" and c:find("[%w_\128-\255]") ~= nil end
	local function Swap(line, name, to)
		local out, at = {}, 1
		while true do
			local s, e = line:find(name, at, true)
			if not s then break end
			if (s > 1 and Part(line:sub(s - 1, s - 1))) or Part(line:sub(e + 1, e + 1)) then
				out[#out + 1] = line:sub(at, e)
			else
				out[#out + 1] = line:sub(at, s - 1) .. to
			end
			at = e + 1
		end
		out[#out + 1] = line:sub(at)
		return table.concat(out)
	end
	for i, line in ipairs(lines) do
		if not fixed[i] then
			for _, name in ipairs(names) do line = Swap(line, name, alias[name]) end
			lines[i] = line
		end
	end
	return table.concat(lines, "\n")
end

-- What this client allows, what has broken, and a bug report.
-- The distance line in plain words: what is measuring, not the client call
-- or the library's name, which /manners debug keeps for a bug report.
local SOURCE_WORDS = {
	{ "CheckInteractDistance", function() return L["the duel range"] end },
	{ "LibRangeCheck%-3%.0", function() return L["spell and item ranges"] end },
}
local function PlainSources(text)
	for _, pair in ipairs(SOURCE_WORDS) do
		text = text:gsub(pair[1], pair[2])
	end
	return text
end

function Page.BuildDiagnosticsTab()
	return {
		type = "group",
		name = TAB.diagnostics,
		order = 7,
		args = {
			-- Lines printed to your own chat frame, never said aloud: the
			-- header says so, so it does not read as an addon that talks
			-- to other players. The everyday switch, Tell me in chat, is on
			-- Start here; this one is for working out a failed cast.
			chatHeader = { type = "header", name = L["Messages in chat"], order = 1 },
			debugClicks = {
				type = "toggle",
				name = L["Log every click (noisy)"],
				desc = L["Prints what the prompt held and what the game did, to work out why a cast failed."],
				order = 3,
				width = "full",
				get = function() return ns.db.profile.debugClicks end,
				set = function(_, v) ns.db.profile.debugClicks = v end,
			},

			capsHeader = { type = "header", name = L["What Manners can see"], order = 10 },
			diag = {
				type = "description",
				order = 11,
				fontSize = "medium",
				hidden = function() return not HasClassBuffs() end,
				name = function()
					-- The class is the client's own token, MAGE and the
					-- like; shown in the player's language where the
					-- client names it, and as the token where it does not.
					local class = ns.caps.class
					local names = _G.LOCALIZED_CLASS_NAMES_MALE
					local shown = (names and class and names[class]) or class
					local lines = { L["Class: |cffffffff%s|r"]:format(tostring(shown)) .. "\n" }
					for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
						local info = ns.BuffInfo(buff)
						-- Each field is one key with its label, so the
						-- translator sees what "yes" or "blocked" answers
						-- and can make the words agree.
						lines[#lines + 1] = ("|cffffffff%s|r  --  %s   %s"):format(
							(info and info.name) or buff.key,
							(info and info.known) and L["learned: |cff00ff00yes|r"]
								or L["learned: |cff808080no|r"],
							(info and info.readable) and L["can see who has it: |cff00ff00yes|r"]
								or L["can see who has it: |cffff8080no|r"])
						-- Manners being wrong about the game, rather than
						-- the game withholding something. "Never offer"
						-- only where no rank resolves: a missing group id
						-- (Arcane Brilliance) costs only the check of
						-- whether somebody is wearing it.
						if info and info.unresolved and #info.unresolved > 0 then
							local missing = {}
							for _, id in ipairs(info.unresolved) do missing[id] = true end
							local rankResolves = false
							for _, id in ipairs(buff.ranks) do
								if not missing[id] then rankResolves = true end
							end
							if not info.known and not rankResolves then
								lines[#lines + 1] = "|cffff4040    "
									.. L["this client has never heard of spell %s, so Manners will never offer this one. That is a mistake in Manners -- please report it."]
										:format(table.concat(info.unresolved, ", "))
									.. "|r"
							else
								lines[#lines + 1] = "|cffff4040    "
									.. L["this client doesn't know spell %s, so somebody already carrying that version may be offered this anyway. That is a mistake in Manners -- please report it."]
										:format(table.concat(info.unresolved, ", "))
									.. "|r"
							end
						end
					end
					lines[#lines + 1] = "\n|cff888888"
						.. L["Where Manners cannot see a buff, people are still offered, but some may already have it."]
						.. "|r"
					return table.concat(lines, "\n")
				end,
			},
			-- "Myself": what holds it back and each of your own buffs, in
			-- the words /manners debug uses (ns.MyselfLines), since "why am I
			-- not reminded" is asked here as often as there.
			ownDiag = {
				type = "description",
				order = 11.7,
				fontSize = "medium",
				hidden = function() return #ns.MyselfLines(GetTime()) == 0 end,
				name = function()
					return "|cffffffff" .. L["Myself"] .. "|r\n" .. table.concat(ns.MyselfLines(GetTime()), "\n")
				end,
			},
			-- How long each of your buffs lasts and when a top-up of it is due,
			-- in the words /manners debug uses (ns.LeadLines): the lead is
			-- worked out per buff, so "why did it come back now" or "why not
			-- yet" is answered here.
			leadDiag = {
				type = "description",
				order = 11.6,
				fontSize = "medium",
				hidden = function() return #ns.LeadLines() == 0 end,
				name = function()
					return "|cffffffff" .. ns.LeadHeading() .. "|r\n" .. table.concat(ns.LeadLines(), "\n")
				end,
			},
			-- Who "Skip players flagged for PvP" is holding back, in the
			-- words /manners debug uses (ns.PvPLines): somebody missing
			-- from the prompt for it has nothing else on screen to say why.
			-- A scan of its own, since the page is not repainted by one; one
			-- a paint, since in a battleground crowd a scan is a whole
			-- queue. `hidden` runs it -- whatever draws the line asks that
			-- first -- and the text reads what the scan left.
			pvpDiag = {
				type = "description",
				order = 11.8,
				fontSize = "medium",
				hidden = function() return #ns.PvPLines(true) == 0 end,
				name = function()
					return "|cffffffff" .. L["Flagged for PvP"] .. "|r\n" .. table.concat(ns.PvPLines(), "\n")
				end,
			},
			-- What is measuring how near a passer-by is, and how often it
			-- answers: a filter that has quietly stopped measuring looks
			-- the same as nobody being nearby. The only place it is shown.
			proximityDiag = {
				type = "description",
				order = 12,
				fontSize = "medium",
				-- And for a class with nobody to measure (a rogue).
				hidden = function() return OnlyReachesGroup() or not HasClassBuffs() end,
				name = function()
					return "|cff888888"
						.. PlainSources(L["Passer-by distance: %s"]:format(tostring(ns.ProximitySummary())))
						.. "|r"
				end,
			},
			-- Grey, not red: a class with nothing for others is not a fault.
			-- Start here and the launcher send a character with nothing to
			-- cast here to learn why, so the other two reasons are said, in
			-- red: the game never named the class, or Manners has no buffs
			-- for it (no buff data for this client at all, or a class it does
			-- not list).
			noDiag = {
				type = "description",
				order = 11.5,
				fontSize = "medium",
				hidden = HasClassBuffs,
				name = function()
					local class = ns.caps.class
					if ns.BUFFS_MISSING then
						return "|cffff8080"
							.. L["%s -- nobody will be offered a buff. Please report this, with the output of /manners debug."]
								:format(ns.BUFFS_MISSING)
							.. "|r"
					elseif type(class) ~= "string" or class == "" then
						return "|cffff8080"
							.. L["The game did not say which class this character is, so Manners cannot tell which buffs it has. A /reload usually mends it; if it does not, please report it."]
							.. "|r"
					elseif not (ns.CLASSES_WITHOUT_BUFFS and ns.CLASSES_WITHOUT_BUFFS[class]) then
						return "|cffff8080"
							.. L["Manners has no buffs listed for the class %s on this client. That is a mistake in Manners -- please report it."]
								:format(class)
							.. "|r"
					end
					return "|cff888888"
						.. L["Nothing to report: this character has no buffs it can put on another player."]
						.. "|r"
				end,
			},

			-- What ns.Guard caught, on the page where somebody is looking
			-- when nothing works.
			errorsHeader = { type = "header", name = L["Errors this session"], order = 20 },
			errorList = {
				type = "description",
				order = 21,
				fontSize = "medium",
				hidden = function() return #ns.errors == 0 end,
				name = function()
					local lines = {}
					for i = math.max(1, #ns.errors - 4), #ns.errors do
						local e = ns.errors[i]
						lines[#lines + 1] = ("|cff808080%s|r %s -- |cffff8080%s|r"):format(
							tostring(e.at), tostring(e.where), tostring(e.err))
					end
					-- The count, not the ring's length: the ring holds thirty.
					if #ns.errors > 5 then
						-- Two whole sentences, and the command an argument:
						-- it is what the player types, in any language.
						-- "all": /manners errors alone lists these same five.
						local total = ns.errorCount or #ns.errors
						local text
						if total > #ns.errors then
							text = L["(%d in all this session, %d kept -- |cffffd100%s|r)"]
								:format(total, #ns.errors, "/manners errors all")
						else
							text = L["(%d in all this session -- |cffffd100%s|r)"]
								:format(total, "/manners errors all")
						end
						lines[#lines + 1] = "|cff888888" .. text .. "|r"
					end
					return table.concat(lines, "\n")
				end,
			},
			-- /manners errors all as a button, once there are more than the
			-- five listed above: every one kept, where /manners errors alone
			-- lists those five again.
			allErrors = {
				type = "execute",
				name = L["Show every error"],
				desc = L["Lists every error this session in your chat window, the oldest first."],
				order = 21.2,
				hidden = function() return #ns.errors <= 5 end,
				func = function() ns.addon:HandleSlash("errors all") end,
			},
			noErrors = {
				type = "description",
				order = 21.5,
				fontSize = "medium",
				hidden = function() return #ns.errors > 0 end,
				name = L["Nothing has gone wrong this session."],
			},

			reportHeader = { type = "header", name = L["Reporting a bug"], order = 30 },
			buildNote = {
				type = "description",
				order = 31,
				fontSize = "medium",
				-- The first question on every bug report.
				name = function()
					return ("Manners |cffffffff%s|r"):format(tostring(ns.BUILD))
				end,
			},
			-- Who makes Manners, and the character they play, in the window's footer
			-- under the build (Options/Window/Layout.lua): a credit and nothing
			-- more. Blizzard's add-on policy forbids an add-on to ask for
			-- donations in the game, gold included, so this line asks for nothing
			-- and never will (tests/scenarios/about.lua holds every language to it).
			aboutNote = {
				type = "description",
				-- Its own place in the fallback dialog too, right under the build.
				order = 31.2,
				fontSize = "medium",
				name = function()
					return L["Manners is made by %s, who plays on the RP-PvP server of WoW Forever."]
						:format("|cffffffff" .. tostring(ns.AUTHOR) .. "|r")
				end,
			},
			-- Which of the two buttons below somebody asked for a report wants.
			reportHint = {
				type = "description",
				order = 31.5,
				fontSize = "medium",
				name = function()
					return L["Asked for a report? Press %s and paste everything in the box."]
						:format("|cffffd100" .. L["Run a full check-up"] .. "|r")
				end,
			},
			copyReport = {
				type = "execute",
				name = function() return Page.reportOpen and L["Hide the report"] or L["Show a short summary"] end,
				desc = L["Opens a box with the build, what this client allows, the settings that matter and anything that has broken, ready to copy."],
				order = 32,
				func = function()
					Page.reportOpen = not Page.reportOpen
					ns.RefreshOptionsDisplay()
				end,
			},
			-- Everything at once, for a player asked for a report: one press,
			-- one box to copy (ns.FullReport), in the box the self-test uses.
			fullReport = {
				type = "execute",
				name = L["Run a full check-up"],
				desc = L["Runs every check Manners has and gathers the results, what this client allows, your settings and anything that broke into one box, ready to copy and send with a bug report. Nothing is said to anybody, and nothing is changed."],
				order = 32.5,
				func = function()
					local text = ns.FullReport()
					if not (ns.ShowSelftestBox and ns.ShowSelftestBox(text)) then
						ns.addon:Reply(L["the options window would not open, so the check-up follows here."])
						for line in text:gmatch("[^\n]+") do ns.addon:Reply(line) end
					end
				end,
			},
			-- /manners selftest launch as a button: the checks of how the
			-- looks, the bar slot and the tooltip draw on this client, into the
			-- same box. Out of combat: it puts looks on the real prompt.
			launchCheck = {
				type = "execute",
				name = L["Check how Manners draws in this game"],
				desc = L["Puts every look on the real prompt, tries the action bar slot and the tooltip, and puts everything back: the report opens in the box below. Nothing is cast or said."],
				order = 32.7,
				disabled = function() return InCombatLockdown() end,
				func = function() ns.addon:HandleSlash("selftest launch") end,
			},
			report = {
				type = "input",
				name = "",
				order = 33,
				multiline = 14,
				width = "full",
				hidden = function() return not Page.reportOpen end,
				get = function() return BugReport() end,
				-- Read-only in the only way AceConfig offers: anything
				-- typed in is discarded.
				set = function() end,
			},
			-- /manners selftest's report (Selftest.lua), shown by
			-- ns.ShowSelftestBox until the window shuts. Read-only, as above.
			selftest = {
				type = "input",
				name = "",
				order = 34,
				multiline = 14,
				width = "full",
				hidden = function() return Page.selftestText == nil end,
				get = function() return Page.selftestText or "" end,
				set = function() end,
			},
		},
	}
end
