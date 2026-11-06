-- Presses of the Manners macro on an action bar, after the review of the bar
-- macro (Clicks.lua, click macro; Prompt/Press.lua, OnBarClick and
-- BarWaiting): whose body it is, whose press it is, a body a session before
-- left, the cooldown, and a press with nothing to cast.
--
-- As in barclick.lua, these hold Manners' wiring to the mock's model of the
-- client (tests/mockmacros.lua, "running macros"), not the client.
--
-- Every name starts with "barpress:" so a mutation in tests/mutations/
-- barpress.py can name exactly one.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe, clearClicks = H.strangers, H.freshPrompt, H.owe, H.clearClicks

local BAR_LINE = "/click MannersBar"
local GCD = 61304
local ANNA, BOB, CARL = { "Anna", "Aim" }, { "Bob", "Bright" }, { "Carl", "Cole" }
local STALE = "still holds the last session's lines"
local NO_CAST = "Manners writes no cast into it"
local WARNED = "still targets"
-- The globals a scenario replaces, put back whatever happens.
local TOUCHED = { "UnitGUID", "UnitName", "UnitExists", "CreateMacro", "EditMacro", "MacroFrame", "C_Spell",
	"IsUsableSpell", "IsSpellKnown", "IsPlayerSpell", "MannersPrompt" }

local function said() return table.concat(Mock.printed, "\n") end
local function flat(t) return (tostring(t):gsub("\n", " / ")) end
local function count(text, needle)
	local n, from = 0, 1
	while true do
		local at = text:find(needle, from, true)
		if not at then return n end
		n, from = n + 1, at + #needle
	end
end
local function macroIndex() return GetMacroIndexByName("Manners") end
local function bodyNow()
	local m = Mock.macroList[macroIndex()]
	return m and m.body or nil
end
local function targetOf(body) return type(body) == "string" and body:match("\n/target ([^\n]+)") or nil end

-- The addon's view of "target" follows whom the mock's macros targeted.
local function followTarget()
	local guid, name, exists = UnitGUID, UnitName, UnitExists
	rawset(_G, "UnitGUID", function(u, ...)
		if u == "target" then
			local t = Mock.runTarget
			if not t then return nil end
			return guid(t.unit)
		end
		return guid(u, ...)
	end)
	rawset(_G, "UnitName", function(u, ...)
		if u == "target" then
			local t = Mock.runTarget
			if not t then return nil end
			return name(t.unit)
		end
		return name(u, ...)
	end)
	rawset(_G, "UnitExists", function(u, ...)
		if u == "target" then return Mock.runTarget ~= nil end
		return exists(u, ...)
	end)
end

-- Forever, Anna and Bob on nameplates unless opts.people says otherwise. T
-- counts the presses filed and the macro lines run; T.onLine sees each line.
local function with(scenario, body, opts)
	opts = opts or {}
	Mock.reset()
	Mock.setFlavour(opts.flavour or "camelot")
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local people = {}
	for unit, n in pairs(opts.people or { nameplate1 = ANNA, nameplate2 = BOB }) do people[unit] = { n[1], n[2] } end
	local restore = strangers(people)
	followTarget()
	local exec = Mock.execLine
	local T = { filings = 0, lines = {} }
	Mock.execLine = function(line)
		T.lines[#T.lines + 1] = line
		if T.onLine then T.onLine(line) end
		return exec(line)
	end
	local ok, err = true, nil
	local ns = load(scenario)
	if ns then
		ok, err = pcall(function()
			freshPrompt(ns, scenario)
			local abandon = ns.AbandonPendingClick
			ns.AbandonPendingClick = function(...)
				T.filings = T.filings + 1
				return abandon(...)
			end
			ns.db.profile.sources.strangers = false
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			body(ns, scenario, T)
			for _, e in ipairs(ns.errors or {}) do
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end)
	end
	Mock.execLine = exec
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function onBar(ns, slot)
	ns.CreateClickMacro()
	return Mock.dropOnBar(slot)
end

local function spellIds(ns)
	return function()
		local entry = ns.Prompt.bar.current or ns.Prompt.state.current
		local info = entry and entry.buff and ns.BuffInfo(entry.buff)
		return info and info.topRank or 0
	end
end

-- A clean start: the clock past every cooldown, `names` owed, a scan.
local function again(ns, names)
	clearClicks(ns)
	ns.db.profile.debugClicks = true
	for _, name in ipairs(names) do owe(ns, name) end
	ns.addon:Tick()
	Mock.runTimers(0)
end

-- One press of `slot`: the casts, the presses filed, and what was printed.
local function press(ns, T, slot, how)
	local f0 = T.filings
	Mock.printed = {}
	local casts = Mock.pressBar(slot, how)
	return casts or {}, T.filings - f0, said()
end

-- ------------------------------------------------------------------ 1
-- Only a shape Manners writes is Manners': at most one /target, then one
-- /cast or one /use item: (with one /use 16|17), then after a /target at most
-- one hand-back, in that order. A login puts a body of that shape back to the
-- bar line (nobody is owed); any other body, a trinket's /use 13 added under
-- the cast included, is the player's: left as written, and said once.
local SHAPES = {
	{ BAR_LINE, ours = true },
	{ BAR_LINE .. "\n/cast Battle Shout", ours = true },
	{ BAR_LINE .. "\n/use item:5760", ours = true },
	{ BAR_LINE .. "\n/use item:5760\n/use 17", ours = true },
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect", ours = true },
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/targetlasttarget", ours = true },
	{ "#showtooltip\n" .. BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/cleartarget", ours = true,
		becomes = "#showtooltip\n" .. BAR_LINE },
	{ BAR_LINE .. "\n/use 13", said = NO_CAST },
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/use 13", said = WARNED },
	{ BAR_LINE .. "\n/cast Arcane Intellect\n/use 13", said = NO_CAST },
	{ BAR_LINE .. "\n/cast Thorns\n/cast Mark of the Wild", said = NO_CAST },
	{ BAR_LINE .. "\n/cast Thorns\n/target Bob Bright", said = WARNED },
	{ BAR_LINE .. "\n/target Bob Bright\n/target Carl Cole\n/cast Thorns", said = WARNED },
	{ BAR_LINE .. "\n/target Bob Bright\n/cast [@focus] Thorns", said = WARNED },
	{ BAR_LINE .. "\n/cleartarget", said = NO_CAST },
	{ BAR_LINE .. "\n/cast Thorns\n/targetlasttarget", said = NO_CAST },
	{ BAR_LINE .. "\n/use item:5760\n/use 13", said = NO_CAST },
	{ BAR_LINE .. "\n/target Bob Bright\n/use item:5760", said = WARNED },
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/targetlasttarget\n/cleartarget", said = WARNED },
	-- The spoken line (1.11.6, issue #7): one, after the cast and before the
	-- hand-back, in a channel Manners speaks in, with no conditional.
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/say Thanks, Bob Bright.\n/targetlasttarget", ours = true },
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/party Thanks, Bob Bright.", ours = true },
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/w Bob Bright Thanks, Bob.\n/targetlasttarget", ours = true },
	{ BAR_LINE .. "\n/cast Battle Shout\n/yell Thanks, all.", ours = true },
	{ BAR_LINE .. "\n/target Bob Bright\n/say Thanks.\n/cast Arcane Intellect", said = WARNED },
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/say Thanks.\n/say Again.", said = WARNED },
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/say [mod:shift] Thanks.", said = WARNED },
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/targetlasttarget\n/say Thanks.", said = WARNED },
	{ BAR_LINE .. "\n/target Bob Bright\n/cast Arcane Intellect\n/run print(1)", said = WARNED },
}
for i, case in ipairs(SHAPES) do
	local scenario = ("barpress: only a shape Manners writes is Manners' (%d)"):format(i)
	Mock.reset()
	Mock.setFlavour("camelot")
	local restore = strangers({})
	Mock.macroList[1] = { name = "Manners", icon = "INV_MISC_NOTE_03", body = case[1] }
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			ns.addon:OnInitialize()
			ns.addon:OnEnable()
			Mock.runTimers(3)
			local now = Mock.macroList[1] and Mock.macroList[1].body
			local state = ns.BarMacroState()
			if case.ours then
				local want = case.becomes or BAR_LINE
				if state ~= "ours" or now ~= want then
					fail(scenario, ("%s, a shape Manners writes, is %s and holds %s, not %s"):format(
						flat(case[1]), state, flat(now), flat(want)))
				end
			else
				if state ~= "foreign" or now ~= case[1] then
					fail(scenario, ("%s, a body of the player's, is counted %s and holds %s"):format(flat(case[1]), state, flat(now)))
				end
				if count(said(), case.said) ~= 1 then
					fail(scenario, ("%s was said about %d times: %s"):format(flat(case[1]), count(said(), case.said), flat(said())))
				end
				-- Looked at again (the macro list changing), said no more.
				ns.addon:UPDATE_MACROS()
				ns.addon:UPDATE_MACROS()
				if count(said(), case.said) ~= 1 then fail(scenario, "said again at the next look: " .. flat(said())) end
			end
			for _, e in ipairs(ns.errors or {}) do fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err)) end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	restore()
	Mock.reset()
end

-- A trinket's line added by hand under the cast the macro carries: the body is
-- the player's from then on, never written over at the next change of the
-- prompt, and its presses are not filed.
with("barpress: a /use added by hand under the cast is the player's", function(ns, scenario, T)
	local anna = ns.UnitFullName("nameplate1")
	again(ns, { anna })
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	local index = macroIndex()
	local full = bodyNow()
	if not targetOf(full) then fail(scenario, "SKIPPED -- the macro carries no cast: " .. flat(full)) return end
	local mine = full .. "\n/use 13"
	EditMacro(index, nil, nil, mine)
	local edits = Mock.editCalls
	owe(ns, ns.UnitFullName("nameplate2"))
	ns.owed[anna] = nil
	for _ = 1, 4 do
		Mock.advance(1)
		ns.addon:Tick()
		Mock.runTimers(0)
	end
	if bodyNow() ~= mine then fail(scenario, "the player's /use 13 was written over: " .. flat(bodyNow())) end
	if Mock.editCalls ~= edits then fail(scenario, ("the player's macro was written %d time(s)"):format(Mock.editCalls - edits)) end
	local _, filed = press(ns, T, 2)
	if filed ~= 0 then fail(scenario, "a press of the player's macro was filed") end
end)

-- ------------------------------------------------------------------ 2
-- A macro of the player's own with the bar line runs its own lines: nothing
-- of it is filed against the person the Manners macro names, and nothing is
-- said of them after. The Manners macro itself still is.
for _, extra in ipairs({ "", "\n/cast Frost Armor" }) do
	local scenario = "barpress: the player's own macro with the bar line is not filed" .. (extra == "" and "" or " (and a cast)")
	with(scenario, function(ns, _, T)
		local anna = ns.UnitFullName("nameplate1")
		Mock.castEvents = "after"
		Mock.spellIdFor = spellIds(ns)
		Mock.gcdOnCast = 1.5
		again(ns, { anna })
		if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
		if targetOf(bodyNow()) ~= anna then fail(scenario, "SKIPPED -- the macro carries " .. flat(bodyNow())) return end
		Mock.bar[3] = CreateMacro("Mine", "INV_MISC_NOTE_03", BAR_LINE .. extra, false)
		local casts, filed, text = press(ns, T, 3)
		for _, c in ipairs(casts) do
			if c.target == anna then fail(scenario, "the player's own macro cast at " .. anna) end
		end
		if filed ~= 0 or ns.pendingClick then
			fail(scenario, ("a press of the player's own macro was filed as a press on %s"):format(
				tostring(ns.pendingClick and ns.pendingClick.name)))
		end
		if not text:find("via=bar body=other", 1, true) then fail(scenario, "the click line does not say whose macro ran: " .. flat(text)) end
		Mock.advance(2.5)
		Mock.printed = {}
		ns.addon:Tick()
		if said():find("answered that press with nothing", 1, true) or said():find("still owed", 1, true) then
			fail(scenario, "then: " .. flat(said()))
		end
		-- The Manners macro, after the cooldown: filed as Anna's.
		again(ns, { anna })
		local own, ownFiled = press(ns, T, 2)
		if #own ~= 1 or own[1].target ~= anna or ownFiled ~= 1 then
			fail(scenario, ("a press of the Manners macro cast %d time(s), filed %d"):format(#own, ownFiled))
		end
	end)
end

-- ------------------------------------------------------------------ 3
-- A login or a /reload in a fight: the macro still holds what the last
-- session wrote, and nothing can write it until the fight ends. A press runs
-- those lines (nothing can stop them); it is said once, naming them, never
-- filed, and its click line is not "edited". The fight over, the macro is
-- put right.
local function loginInAFight(scenario, lines, check)
	Mock.reset()
	Mock.setFlavour("camelot")
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bob", "Bright" } })
	followTarget()
	Mock.macroList[1] = { name = "Manners", icon = "INV_MISC_NOTE_03", body = lines }
	Mock.bar[1] = 1
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			Mock.inCombat = true
			Mock.runTarget = { unit = "nameplate2", name = "Bob Bright" }
			ns.addon:OnInitialize()
			ns.addon:OnEnable()
			ns.addon:PLAYER_ENTERING_WORLD("PLAYER_ENTERING_WORLD", false, true)
			Mock.runTimers(3)
			ns.db.profile.debugClicks = true
			ns.db.profile.verbose = true
			Mock.secureActions = true
			Mock.eventSink = ns.addon
			ns.addon:Tick()
			check(ns)
			for _, e in ipairs(ns.errors or {}) do fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err)) end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.inCombat = false
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
end

local function staleChecks(scenario, lines)
	return function(ns)
		Mock.printed = {}
		Mock.pressBar(1)
		local first = said()
		if ns.pendingClick then fail(scenario, "a press of the last session's lines was filed as " .. tostring(ns.pendingClick.name)) end
		if count(first, STALE) ~= 1 or not first:find("/target Anna Aim", 1, true) then
			fail(scenario, "the press did not say whose lines it ran: " .. flat(first))
		end
		if not first:find("via=bar body=stale", 1, true) or first:find("body=edited", 1, true) then
			fail(scenario, "the click line reads: " .. flat(first))
		end
		Mock.advance(2)
		Mock.printed = {}
		Mock.pressBar(1)
		if count(said(), STALE) ~= 0 then fail(scenario, "said again at the next press: " .. flat(said())) end
		if ns.pendingClick then fail(scenario, "the second press was filed") end
		-- The fight over: the macro follows the prompt again (to the bar line
		-- alone, or to whoever the prompt now offers).
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		ns.addon:Tick()
		Mock.runTimers(0)
		local after = Mock.macroList[1].body
		local current = ns.Prompt.state.current
		if after == lines or (after ~= BAR_LINE and not (current and targetOf(after) == current.name)) then
			fail(scenario, ("after the fight the macro holds %s, the prompt shows %s"):format(flat(after), tostring(current and current.name)))
		end
		Mock.printed = {}
		Mock.pressBar(1)
		if said():find("body=stale", 1, true) or said():find("body=edited", 1, true) or count(said(), STALE) > 0 then
			fail(scenario, "after the fight a press was still taken for the last session's: " .. flat(said()))
		end
	end
end

do
	local scenario = "barpress: a login in a fight finds the last session's body"
	local lines = BAR_LINE .. "\n/target Anna Aim\n/cast Arcane Intellect\n/targetlasttarget"
	loginInAFight(scenario, lines, staleChecks(scenario, lines))
end

-- The fight over, the prompt arms the very lines the last session left (the
-- same person, the same hand-back): nothing needs writing, and a press of
-- them is the prompt's, filed as theirs.
do
	local scenario = "barpress: after a fight a login was in, the same lines are the prompt's"
	local lines = BAR_LINE .. "\n/target Anna Aim\n/cast Arcane Intellect\n/targetlasttarget"
	loginInAFight(scenario, lines, function(ns)
		Mock.printed = {}
		Mock.pressBar(1)
		if count(said(), STALE) ~= 1 then fail(scenario, "SKIPPED -- the press in the fight said " .. flat(said())) end
		ns.nameplateUnits.nameplate1 = true
		ns.db.profile.sources.strangers = false
		owe(ns, "Anna Aim")
		Mock.advance(2)
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		ns.addon:Tick()
		Mock.runTimers(0)
		local current = ns.Prompt.state.current
		if not (current and current.name == "Anna Aim") or Mock.macroList[1].body ~= lines then
			fail(scenario, ("SKIPPED -- after the fight the prompt is on %s, the macro %s"):format(
				tostring(current and current.name), flat(Mock.macroList[1].body)))
			return
		end
		Mock.printed = {}
		ns.pendingClick = nil
		local casts = Mock.pressBar(1)
		if #casts ~= 1 or casts[1].target ~= "Anna Aim" then fail(scenario, ("the press cast %d time(s)"):format(#casts)) end
		if not (ns.pendingClick and ns.pendingClick.name == "Anna Aim") then
			fail(scenario, "a press of the prompt's own lines was not filed: " .. flat(said()))
		end
	end)
end

-- Lines typed by hand in the macro window that are exactly what the prompt
-- casts: found when the window shuts, they are the prompt's, and a press of
-- them is filed (not taken for a session before's).
with("barpress: lines typed by hand that the prompt would write are the prompt's", function(ns, scenario, T)
	local anna = ns.UnitFullName("nameplate1")
	again(ns, { anna })
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	local full = bodyNow()
	if targetOf(full) ~= anna then fail(scenario, "SKIPPED -- the macro carries " .. flat(full)) return end
	local window = CreateFrame("Frame", "MacroFrame", UIParent)
	window:Hide()
	rawset(_G, "MacroFrame", window)
	ns.addon:ADDON_LOADED("ADDON_LOADED", "Blizzard_MacroUI")
	window:Show()
	Mock.fire(window, "OnShow")
	if bodyNow() ~= BAR_LINE then fail(scenario, "SKIPPED -- with the window open the macro holds " .. flat(bodyNow())) return end
	-- Typed in the window, saved as it shuts.
	Mock.macroList[macroIndex()].body = full
	window:Hide()
	Mock.fire(window, "OnHide")
	if bodyNow() ~= full then fail(scenario, "SKIPPED -- the window shut, the macro holds " .. flat(bodyNow())) return end
	local casts, filed, text = press(ns, T, 2)
	if #casts ~= 1 or casts[1].target ~= anna then fail(scenario, ("the press cast %d time(s)"):format(#casts)) end
	if filed ~= 1 or text:find("body=stale", 1, true) then
		fail(scenario, ("a press of the prompt's own lines was filed %d times: %s"):format(filed, flat(text)))
	end
end)

-- A loading screen in a fight cannot put the macro back to its first line
-- (ParkMacroBody is refused there): what it leaves is the next login's last
-- session's body.
do
	local scenario = "barpress: a loading screen in a fight leaves the cast, and the next login says so"
	local left
	with(scenario, function(ns)
		local anna = ns.UnitFullName("nameplate1")
		again(ns, { anna })
		if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.inCombat = true
		ns.addon:PLAYER_LEAVING_WORLD()
		left = bodyNow()
		Mock.inCombat = false
		if targetOf(left) ~= anna then fail(scenario, "SKIPPED -- the fight's loading screen left " .. flat(left)) left = nil end
	end)
	if left then loginInAFight(scenario, left, staleChecks(scenario, left)) end
end

-- ------------------------------------------------------------------ 4
-- Early in the global cooldown after a press that landed, the next press is
-- held back and filed as nothing, but its /cast still goes out and the game
-- refuses it. That refusal is about nothing filed: no "could not cast", no
-- "after our cast", no line about anybody still owed.
with("barpress: a press early in the cooldown after a press that landed is quiet", function(ns, scenario, T)
	local anna = ns.UnitFullName("nameplate1")
	local carl = ns.UnitFullName("nameplate3")
	Mock.castEvents = "after"
	Mock.spellIdFor = spellIds(ns)
	Mock.gcdOnCast = 1.5
	ns.db.profile.verbose = true
	again(ns, { anna, carl })
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	-- The client: a /cast in the global cooldown is refused with an error line
	-- and a failed cast, after the macro has run.
	T.onLine = function(line)
		if line:match("^/cast ") then
			local cd = Mock.spellCooldowns and Mock.spellCooldowns[GCD]
			if cd and cd.startTime + cd.duration > Mock.now then
				Mock.queuedEvents[#Mock.queuedEvents + 1] = { "UI_ERROR_MESSAGE", 0, "Spell is not ready yet." }
				Mock.queuedEvents[#Mock.queuedEvents + 1] = { "UNIT_SPELLCAST_FAILED", "player", "Cast-refused-" .. Mock.now, 1459 }
			end
		end
	end
	local c1, f1 = press(ns, T, 2)
	Mock.runTimers(0)
	Mock.runTimers(0.7)
	ns.addon:Tick()
	Mock.runTimers(0)
	local body2 = bodyNow()
	if not targetOf(body2) then fail(scenario, "SKIPPED -- at 0.7s the macro holds " .. flat(body2)) return end
	local c2, f2, t2 = press(ns, T, 2)
	if #c1 ~= 1 or #c2 ~= 0 or f1 ~= 1 or f2 ~= 0 then
		fail(scenario, ("casts %d/%d, filed %d/%d"):format(#c1, #c2, f1, f2))
	end
	if not t2:find("held back", 1, true) then fail(scenario, "SKIPPED -- the press was not held back: " .. flat(t2)) end
	for _, word in ipairs({ "could not cast", "after our cast", "still owed", "not buffed" }) do
		if t2:find(word, 1, true) then fail(scenario, ("a press the cooldown held back printed %q: %s"):format(word, flat(t2))) end
	end
	-- Nor is the refusal taken as the reason for the next one.
	Mock.advance(0.1)
	ns.NoteRefusal(carl, nil)
	local r = ns.refusals[carl]
	if r and r.why == "Spell is not ready yet." then fail(scenario, "the held press's refusal was borrowed as the next refusal's reason") end
end, { people = { nameplate1 = ANNA, nameplate2 = BOB, nameplate3 = CARL } })

-- ------------------------------------------------------------------ 5
-- With nothing to cast for any reason but nobody, a press says why: unlocked,
-- previewing, /manners try, the macro window open.
local WHY = {
	{ "unlocked", "not buffing while unlocked",
		function(ns) ns.db.profile.prompt.locked = false ns.Prompt:Refresh() end,
		function(ns) ns.db.profile.prompt.locked = true end },
	{ "previewing", "a preview is on the prompt",
		function(ns)
			ns.OptionsOpen = function() return true end
			ns.addon:HandleSlash("test")
		end,
		function(ns) ns.OptionsOpen = nil ns.Prompt:ExitTest() end },
	{ "running /manners try", "runs on the prompt only",
		function(ns) ns.addon:HandleSlash("try /cast Arcane Intellect") ns.addon:Tick() end,
		function(ns) ns.addon:HandleSlash("try") end },
	{ "the macro window open", "the macro window is open",
		function(ns)
			local window = CreateFrame("Frame", "MacroFrame", UIParent)
			window:Hide()
			rawset(_G, "MacroFrame", window)
			ns.addon:ADDON_LOADED("ADDON_LOADED", "Blizzard_MacroUI")
			window:Show()
			Mock.fire(window, "OnShow")
		end,
		function() end },
}
for _, case in ipairs(WHY) do
	local scenario = "barpress: a press with nothing to cast says why: " .. case[1]
	with(scenario, function(ns, _, T)
		local anna = ns.UnitFullName("nameplate1")
		again(ns, { anna })
		if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
		ns.db.profile.debugClicks = false
		case[3](ns)
		Mock.runTimers(0)
		if bodyNow() ~= BAR_LINE then fail(scenario, "SKIPPED -- the macro holds " .. flat(bodyNow())) return end
		local casts, filed, text = press(ns, T, 2)
		if #casts ~= 0 or filed ~= 0 then fail(scenario, ("%d casts, filed %d"):format(#casts, filed)) end
		if count(text, case[2]) ~= 1 then fail(scenario, ("a press %s said: %s"):format(case[1], flat(text))) end
		case[4](ns)
	end)
end

-- ------------------------------------------------------------------ 6
-- "The prompt has moved on to Carl -- press again": the bar's next press, a
-- frame later and with no scan between, casts at Carl and is filed as his.
with("barpress: press again after the prompt has moved on", function(ns, scenario, T)
	local anna = ns.UnitFullName("nameplate1")
	local carl = ns.UnitFullName("nameplate3")
	Mock.castEvents = "after"
	Mock.spellIdFor = spellIds(ns)
	Mock.gcdOnCast = 1.5
	again(ns, { carl })
	ns.db.profile.debugClicks = false
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	ns.Prompt:ShowOutcome("cast", anna)
	Mock.runTimers(0)
	if bodyNow() ~= BAR_LINE then fail(scenario, "SKIPPED -- under the flash the macro holds " .. flat(bodyNow())) return end
	local c1, f1, t1 = press(ns, T, 2)
	if not t1:find("press again", 1, true) then fail(scenario, "SKIPPED -- the press said " .. flat(t1)) return end
	if #c1 ~= 0 or f1 ~= 0 then fail(scenario, "the press under the flash cast or was filed") end
	-- The next frame, then a press: no scan between.
	Mock.runTimers(0)
	Mock.advance(0.05)
	local c2, f2, t2 = press(ns, T, 2)
	if #c2 ~= 1 or c2[1].target ~= carl then
		fail(scenario, ("'press again' then a press: %d cast(s) at %s, the macro %s, said %s"):format(
			#c2, tostring(c2[1] and c2[1].target), flat(bodyNow()), flat(t2)))
	end
	if f2 ~= 1 then fail(scenario, ("the press after 'press again' was filed %d times"):format(f2)) end
end, { people = { nameplate1 = ANNA, nameplate2 = BOB, nameplate3 = CARL } })

-- ------------------------------------------------------------------ 7
-- The look the macro list's every change asks for is guarded: an error in it
-- is caught and written down, not handed out of the event.
with("barpress: an error in the look at UPDATE_MACROS is caught", function(ns, scenario)
	if not onBar(ns, 2) then fail(scenario, "SKIPPED -- no macro on the bar") return end
	local sync = ns.SyncMacroBody
	ns.SyncMacroBody = function() error("bar macro look failed") end
	local ok, err = pcall(ns.addon.UPDATE_MACROS, ns.addon)
	ns.SyncMacroBody = sync
	if not ok then fail(scenario, "UPDATE_MACROS threw: " .. tostring(err)) end
	local caught = false
	for _, e in ipairs(ns.errors or {}) do
		if tostring(e.err):find("bar macro look failed", 1, true) then caught = true end
	end
	if not caught then fail(scenario, "the error was not written down") end
	wipe(ns.errors)
end)

-- ------------------------------------------------------------------ 8
-- The launch self-test calls EditMacro on its temporary macro as Clicks.lua
-- does, with the macro's name: a client that refuses a nil name gives no
-- false FAIL.
with("barpress: the launch check writes its macro by name", function(ns, scenario)
	if not (ns.Selftest and ns.Selftest.RunLaunch) then fail(scenario, "SKIPPED -- no launch self-test") return end
	local edit = EditMacro
	rawset(_G, "EditMacro", function(index, name, icon, body)
		if name == nil then error("Usage: EditMacro(index, name, icon, body)", 2) end
		return edit(index, name, icon, body)
	end)
	local results, finish = ns.Selftest.RunLaunch({ createMacro = true })
	finish()
	local line
	for _, r in ipairs(results) do
		if r.id == "launch.macro.body" then line = line or (r.status .. " " .. tostring(r.value)) end
	end
	if not line or not line:find("^PASS") then fail(scenario, "the body check reads " .. tostring(line)) end
end, { people = { nameplate1 = ANNA } })

-- /manners selftest's button line: the key binding names the prompt; no macro
-- clicks it any more.
with("barpress: the self-test's button line names the key binding only", function(ns, scenario)
	local other = CreateFrame("Button", nil, UIParent)
	rawset(_G, "MannersPrompt", other)
	ns.addon:HandleSlash("selftest")
	local report = tostring(ns.Selftest and ns.Selftest.last)
	local line = report:match("[^\n]*not MannersPrompt[^\n]*")
	if not line then fail(scenario, "SKIPPED -- no button line in the report") return end
	if line:find("/click", 1, true) or not line:find("the key binding names MannersPrompt", 1, true) then
		fail(scenario, "the button line reads " .. line)
	end
end)
