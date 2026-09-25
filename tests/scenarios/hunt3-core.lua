-- Core.lua fixes from the third bug hunt: the never-offer list and the ledger,
-- the lines said about the never-offer list, the snooze and the mount, a late
-- refusal meeting a newer favour, who counts as a guildmate, sharing settings
-- and undoing an import, the greeting while snoozed, the cooldown sweep, and
-- the phrase box an English-only build wrote.
--
-- Every scenario name starts with "core:" so the mutations in
-- tests/mutations/hunt3-core.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local PETRA = "Petra Stonewell"

local function said()
	return table.concat(Mock.printed, "\n")
end

-- A clean ledger, after the lifecycle has run. Driving it can file a favour
-- from the mock's standing auras, so each scenario starts from nothing.
local function freshLedger(ns)
	ns.db.char.ledger = nil
	ns.Ledger.Load()
	return ns.db.char.ledger
end

-- The row for Petra's favour, newest first.
local function petraRow(s)
	for i = #s.entries, 1, -1 do
		local e = s.entries[i]
		if e.kind == "received" and e.name == PETRA then return e end
	end
end

-- The prompt armed at `entry` and pressed, and the game reporting the cast
-- going out with a cast guid on it, which is what a late refusal names.
local function pressWithGuid(ns, entry, spellId, guid)
	local button = ns.Prompt:GetButton()
	Mock.advance(1)
	ns.pendingClick = nil
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyTarget(entry)
	local post = button.scripts.PostClick
	if post then pcall(post, button, "LeftButton", true) end
	if not ns.pendingClick then return false end
	ns.addon:UNIT_SPELLCAST_SENT(nil, "player", nil, guid, spellId)
	return true
end

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- ------------------------------------------------------------------ core-1
-- Letting a favour go through the never-offer list closes its ledger row. Left
-- open, the row read "Still owed" all session, a later favour from the same
-- person was folded into it as a second buff of the old favour, and the next
-- login filed it as expired or not kept.
for _, route in ipairs({ "call", "shift-right-click", "slash" }) do
	Mock.reset()
	local scenario = "core: the never-offer list lets the favour go in the ledger (" .. route .. ")"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local s = freshLedger(ns)
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 1459, 4101)
		local row = petraRow(s)
		if not ns.owed[PETRA] or not row or row.state ~= "owed" then
			fail(scenario, "SKIPPED -- no favour from Petra was filed")
		else
			if route == "call" then
				ns.PutOnNeverList(PETRA)
			elseif route == "slash" then
				ns.addon:HandleSlash("never " .. PETRA)
			else
				ns.addon:Tick()
				local showing = ns.Prompt:Showing()
				if not showing or showing.name ~= PETRA then
					fail(scenario, "SKIPPED -- Petra is not on the prompt to be shift-right-clicked")
				else
					local realShift = IsShiftKeyDown
					IsShiftKeyDown = function() return true end
					H.pressButton(ns, "RightButton")
					IsShiftKeyDown = realShift
				end
			end
			if not ns.IsNeverOffered(PETRA) then
				fail(scenario, "SKIPPED -- Petra did not go onto the never-offer list")
			elseif ns.owed[PETRA] then
				fail(scenario, "SKIPPED -- the favour was not let go")
			else
				if row.state == "owed" then
					fail(scenario, "the favour was let go and the ledger still says it is owed")
				end
				if ns.Ledger.Summary().owed ~= 0 then
					fail(scenario, "the ledger still counts " .. tostring(ns.Ledger.Summary().owed)
						.. " favour(s) owed after the only one was let go")
				end
				local rows = #s.entries
				Mock.advance(3600)
				wipe(ns.tried)
				H.primeAuras(ns)
				H.favourFrom(ns, "nameplate1", 10938, 4102)
				if #s.entries ~= rows + 1 then
					fail(scenario, "her next favour was not a row of its own (times on the old row: "
						.. tostring(row.times) .. ")")
				end
				if s.totals.received ~= 2 then
					fail(scenario, "two favours are counted as " .. tostring(s.totals.received))
				end
			end
		end
		guarded(scenario, ns)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ core-2
-- In a fight the secure button is frozen, so putting the person the prompt
-- names on the never-offer list leaves them named and armed: a press still
-- casts at them. The line has to say so, as Skip for now does, and only then.

-- A context menu in the shape the client's MenuUtil hands the generator, as
-- much of it as Who's next uses.
local function newMenu(text, fn)
	local d = { text = text, fn = fn, items = {}, enabled = true }
	local function add(c) d.items[#d.items + 1] = c return c end
	function d:CreateTitle(t) return add({ text = t, title = true, items = {} }) end
	function d:CreateDivider() return add({ divider = true, items = {} }) end
	function d:CreateButton(t, f) return add(newMenu(t, f)) end
	function d:CreateCheckbox(t, get, set)
		local c = newMenu(t, set) c.kind, c.get = "checkbox", get return add(c)
	end
	function d:CreateRadio(t, get, set)
		local c = newMenu(t, set) c.kind, c.get = "radio", get return add(c)
	end
	function d:SetEnabled(on) self.enabled = on and true or false end
	function d:SetTooltip(f) self.tooltip = f end
	return d
end

local function child(root, pattern)
	for _, item in ipairs(root and root.items or {}) do
		if item.text and tostring(item.text):find(pattern) then return item end
	end
end

local function rightClickMenu()
	local real, opened = MenuUtil, nil
	MenuUtil = { CreateContextMenu = function(owner, generator)
		local root = newMenu()
		generator(owner, root)
		opened = root
		return root
	end }
	local ok, err = pcall(Mock.broker.OnClick, {}, "RightButton")
	MenuUtil = real
	if not ok then error("right-clicking threw -> " .. tostring(err)) end
	return opened
end

local CAVEAT = "cannot move off them in this fight"

for _, case in ipairs({
	{ label = "shift-right-click in a fight", fight = true, how = "press" },
	{ label = "the menu in a fight", fight = true, how = "menu" },
	{ label = "shift-right-click out of a fight", fight = false, how = "press" },
}) do
	Mock.reset()
	local scenario = "core: never-offering the person on the prompt in a fight says a press still casts ("
		.. case.label .. ")"
	local restore = H.strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } })
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		H.owe(ns, "Anna Aim")
		ns.addon:Tick()
		local button = ns.Prompt:GetButton()
		local showing = ns.Prompt:Showing()
		if not (showing and showing.name == "Anna Aim" and button:IsShown()) then
			fail(scenario, "SKIPPED -- Anna is not on the prompt")
		else
			if case.fight then
				Mock.protect(button)
				Mock.inCombat = true
				ns.addon:PLAYER_REGEN_DISABLED()
				Mock.runTimers(0)
			end
			Mock.printed = {}
			if case.how == "press" then
				local realShift = IsShiftKeyDown
				IsShiftKeyDown = function() return true end
				H.pressButton(ns, "RightButton")
				IsShiftKeyDown = realShift
			else
				local next = child(rightClickMenu(), "^Who's next$")
				local anna = next and child(next, "^Anna Aim %-%- ")
				local never = anna and child(anna, "^Never offer$")
				if never then never.fn() else fail(scenario, "SKIPPED -- no Never offer for Anna") end
			end
			local line = said()
			if not ns.IsNeverOffered("Anna Aim") then
				fail(scenario, "SKIPPED -- Anna did not go onto the list: " .. line)
			elseif case.fight and not line:find(CAVEAT, 1, true) then
				fail(scenario, "the line claims she will not be offered anything while the frozen"
					.. " prompt still casts at her on a press: " .. line)
			elseif not case.fight and line:find(CAVEAT, 1, true) then
				fail(scenario, "out of a fight the line warns of a fight: " .. line)
			elseif not line:find("will not be offered anything again", 1, true) then
				fail(scenario, "the line no longer says what the list does: " .. line)
			end
			if case.fight then
				-- Somebody the prompt does not name is not armed, so the plain
				-- line is the true one for them even in a fight.
				Mock.printed = {}
				ns.PutOnNeverList("Bert Beside")
				if said():find(CAVEAT, 1, true) then
					fail(scenario, "the fight caveat was said about somebody not on the prompt: " .. said())
				elseif not said():find("will not be offered anything again", 1, true) then
					fail(scenario, "nothing said about Bert: " .. said())
				end
			end
			Mock.inCombat = false
		end
		guarded(scenario, ns)
	end
	restore()
end
Mock.reset()

-- ------------------------------------------------------------------ core-3
-- Petra's favour is returned, she buffs you again with another spell, and only
-- then does the server's refusal of your cast arrive. The refusal puts back the
-- debt the settle cleared -- and used to put it over the newer one, which
-- moved its end back to the first favour's and dropped it from the prompt
-- before its own window ran out.
Mock.reset()
do
	local scenario = "core: a late refusal keeps the newer favour's debt"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		freshLedger(ns)
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 1459, 4101)
		local entry = H.inQueue(ns)[PETRA]
		if not (ns.owed[PETRA] and entry) then
			fail(scenario, "SKIPPED -- Petra is not owed and offered")
		elseif not pressWithGuid(ns, entry, 1459, "Cast-9") or ns.owed[PETRA] then
			fail(scenario, "SKIPPED -- the press did not settle her favour")
		else
			Mock.advance(0.5)
			H.favourFrom(ns, "nameplate1", 10938, 4102)
			local newer = ns.owed[PETRA]
			if not newer then
				fail(scenario, "SKIPPED -- her second favour filed no debt")
			else
				local e1 = ns.DebtExpiry(newer)
				Mock.advance(0.5)
				ns.addon:UNIT_SPELLCAST_FAILED(nil, "player", "Cast-9", 1459)
				local now = ns.owed[PETRA]
				if not now then
					fail(scenario, "the refusal lost her debt altogether")
				elseif math.abs(ns.DebtExpiry(now) - e1) > 1e-6 then
					fail(scenario, ("the refusal moved the newer favour's end from %.1f to %.1f"):format(
						e1, ns.DebtExpiry(now)))
				end
			end
		end
		guarded(scenario, ns)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ core-4
-- UnitIsInMyGuild saying no is an answer, and the guild-name comparison is
-- only for a client that gives none. And a guild name is only unique on its
-- realm, so the comparison has to compare realms too: a passer-by from another
-- realm whose guild shares your guild's name was ranked as a guildmate and
-- their tooltip said "In your guild."
local SOCIAL = { "C_FriendList", "C_BattleNet", "UnitIsInMyGuild", "GetGuildInfo" }
local function withSocial(scenario, globals, body)
	local saved = {}
	for _, name in ipairs(SOCIAL) do saved[name] = _G[name] end
	for _, name in ipairs(SOCIAL) do _G[name] = globals[name] end
	local ok, err = pcall(body)
	for _, name in ipairs(SOCIAL) do _G[name] = saved[name] end
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function guildOf(theirRealm)
	return function(unit)
		if unit == "player" then return "Knights", "GM", 0, nil end
		if unit == "nameplate2" then return "Knights", "Member", 3, theirRealm end
		return nil
	end
end

for _, flavour in ipairs({ "camelot", "mainline" }) do
	for _, case in ipairs({
		{ label = "a definite no from UnitIsInMyGuild", realm = "Ravencrest", guild = false,
			inMyGuild = function() return false end },
		-- The realm check alone does not cover this one: whatever the names
		-- say, the client has answered.
		{ label = "a definite no over matching names", realm = nil, guild = false,
			inMyGuild = function() return false end },
		{ label = "no UnitIsInMyGuild, another realm", realm = "Ravencrest", guild = false },
		{ label = "no UnitIsInMyGuild, the same realm", realm = nil, guild = true },
		{ label = "UnitIsInMyGuild withheld, another realm", realm = "Ravencrest", guild = false,
			inMyGuild = function() return Mock.SECRET end },
	}) do
		Mock.reset()
		Mock.setFlavour(flavour)
		Mock.crossRealm = true
		local scenario = "core: a guild of the same name is not your guild (" .. flavour .. ", "
			.. case.label .. ")"
		local restore = H.strangers({ nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Zed", "Ravencrest" } })
		withSocial(scenario, {
			C_FriendList = { IsFriend = function() return false end },
			UnitIsInMyGuild = case.inMyGuild,
			GetGuildInfo = guildOf(case.realm),
		}, function()
			local ns = load(scenario)
			if not ns then return end
			H.freshPrompt(ns, scenario)
			local queue = ns.BuildQueue()
			local zed
			for _, entry in ipairs(queue) do
				if entry.name:find("^Zed") then zed = entry end
			end
			if #queue ~= 2 or not zed then
				fail(scenario, "SKIPPED -- expected Anna and Zed offered, got " .. #queue)
				return
			end
			if case.guild and zed.close ~= "guild" then
				fail(scenario, "a guildmate on your own realm was not recognised: " .. tostring(zed.close))
			elseif not case.guild and zed.close == "guild" then
				fail(scenario, "Zed was ranked as your guildmate")
			end
			if not case.guild and not queue[1].name:find("^Anna") then
				fail(scenario, "Zed was put ahead of Anna: " .. queue[1].name)
			end
			guarded(scenario, ns)
		end)
		restore()
	end
end
Mock.reset()

-- ------------------------------------------------------------------ core-5
-- A big phrase box makes a big settings string. Nothing caps the export, and
-- the import refused anything over its cap -- so your own export would not go
-- back in, and the undo an import keeps, which is an export, could not be read
-- back: it said "nothing to undo" and the settings from before were gone.
local function checksum(text)
	local h = 0
	for i = 1, #text do h = (h * 31 + text:byte(i)) % 16777213 end
	return ("%06x"):format(h)
end

local function signed(body)
	local head = "MNR1:" .. body
	return head .. ":" .. checksum(head)
end

local function phraseBox(lines)
	local out = {}
	for i = 1, lines do
		out[i] = ("Line %d, friend {name}: may your road be long, your pack light; and your ale cold!"):format(i)
	end
	return table.concat(out, "\n")
end

for _, case in ipairs({
	{ label = "90 lines", lines = 90, big = true },
	{ label = "a short box", lines = 3, big = false },
	{ label = "more than any string can hold", lines = 900, huge = true },
}) do
	Mock.reset()
	local scenario = "core: a long profile's export and its import undo read back (" .. case.label .. ")"
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local p = ns.db.profile
		local phrases = phraseBox(case.lines)
		p.speech.phrases = phrases
		p.prompt.width = 260
		p.sound.enabled = true
		local export = ns.ExportSettings()
		if case.big and #export <= 8000 then
			fail(scenario, "SKIPPED -- the export is only " .. #export .. " characters")
		end
		if not case.huge and not ns.ParseSettings(export) then
			fail(scenario, ("your own export (%d characters) cannot be imported back: %s"):format(
				#export, tostring(select(2, ns.ParseSettings(export)))))
		end
		Mock.printed = {}
		ns.addon:HandleSlash("export")
		if case.huge and not said():find("too long", 1, true) then
			fail(scenario, "an export too long to import back was handed over without a word: " .. said())
		elseif not case.huge and said():find("too long", 1, true) then
			fail(scenario, "an export that reads back was called too long: " .. said())
		end

		ns.addon:HandleSlash("import " .. signed("prompt.width=300"))
		if p.prompt.width ~= 300 then
			fail(scenario, "SKIPPED -- the import did not apply")
		else
			Mock.printed = {}
			ns.addon:HandleSlash("import undo")
			if said():find("nothing to undo", 1, true) then
				fail(scenario, "the undo said there was nothing to undo: " .. said())
			end
			if p.speech.phrases ~= phrases then
				fail(scenario, "the phrase box did not come back")
			end
			if p.prompt.width ~= 260 or p.sound.enabled ~= true then
				fail(scenario, ("the settings from before the import did not come back (width %s, sound %s)")
					:format(tostring(p.prompt.width), tostring(p.sound.enabled)))
			end
		end
		guarded(scenario, ns)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ core-6
-- An import's undo belongs to the profile it was made on -- and survives a
-- visit to another one. Every profile switch used to throw it away, so going
-- to Alt and back left "/manners import undo" saying nothing had been imported.
-- A reset or copy onto the import's own profile, or deleting it, still ends it.
local function fire(ns, event, ...)
	local cb = Mock.dbCallbacks[event]
	if cb then cb.target[cb.method](cb.target, event, ns.db, ...) end
end

for _, case in ipairs({ "round trip", "reset", "copy onto it", "delete it", "no profile names" }) do
	Mock.reset()
	local scenario = "core: an import's undo survives a profile round trip (" .. case .. ")"
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		if case ~= "no profile names" then
			ns.db.GetCurrentProfile = function() return Mock.sv.profileName or "Default" end
		end
		local p = ns.db.profile
		p.prompt.width = 300
		ns.ImportSettings(signed("prompt.width=250"))
		if p.prompt.width ~= 250 then
			fail(scenario, "SKIPPED -- the import did not apply")
		elseif case == "reset" or case == "copy onto it" then
			-- What the library does to the profile you are on, and then says.
			for k in pairs(p) do p[k] = nil end
			for k, v in pairs(ns.defaults.profile) do
				p[k] = type(v) == "table" and {} or v
			end
			p.prompt.width = 200
			fire(ns, case == "reset" and "OnProfileReset" or "OnProfileCopied", "Alt")
			Mock.printed = {}
			ns.addon:HandleSlash("import undo")
			if not said():find("nothing to undo", 1, true) then
				fail(scenario, "an undo outlived a " .. case .. " of the profile it was made on: " .. said())
			end
		else
			ns.db:SetProfile("Alt")
			ns.db.profile.prompt.width = 180
			Mock.printed = {}
			ns.addon:HandleSlash("import undo")
			if ns.db.profile.prompt.width ~= 180 then
				fail(scenario, "an undo made on Default rewrote Alt")
			end
			if case == "no profile names" then
				if not said():find("another one", 1, true) then
					fail(scenario, "on another profile the undo did not say it was made on another one: " .. said())
				end
			elseif not said():find("made on profile Default", 1, true) then
				fail(scenario, "on Alt the undo did not say it was made on Default: " .. said())
			end
			if case == "delete it" then
				fire(ns, "OnProfileDeleted", "Default")
				Mock.sv.profiles.Default = nil
				-- Sending the player back to a profile that no longer exists.
				Mock.printed = {}
				ns.addon:HandleSlash("import undo")
				if said():find("made on profile Default", 1, true) then
					fail(scenario, "the undo sends the player back to a deleted profile: " .. said())
				end
			end
			ns.db:SetProfile("Default")
			Mock.printed = {}
			ns.addon:HandleSlash("import undo")
			if case == "delete it" then
				if not said():find("nothing to undo", 1, true) then
					fail(scenario, "an undo outlived the profile it was made on: " .. said())
				end
			else
				if not said():find("your settings from before the import are back.", 1, true) then
					fail(scenario, "back on Default the undo said: " .. said())
				end
				if ns.db.profile.prompt.width ~= 300 then
					fail(scenario, "back on Default the undo did not put width 300 back: "
						.. tostring(ns.db.profile.prompt.width))
				end
			end
		end
		guarded(scenario, ns)
	end
end
Mock.reset()

-- ------------------------------------------------------------------ core-7
-- An unlocked prompt stays up as "Drag to move" through a snooze, on purpose:
-- /manners unlock during one must still give you something to drag. So the
-- snooze line must not say there is no prompt.
for _, locked in ipairs({ false, true }) do
	Mock.reset()
	local scenario = "core: a snooze while unlocked does not say the prompt is gone ("
		.. (locked and "locked" or "unlocked") .. ")"
	local restore = H.strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		H.owe(ns, "Anna Aim")
		ns.addon:Tick()
		if not locked then
			ns.addon:HandleSlash("unlock")
			ns.addon:Tick()
		end
		Mock.printed = {}
		ns.addon:HandleSlash("snooze 5")
		local line = said()
		if not locked then
			if not ns.Prompt:GetButton():IsShown() then
				fail(scenario, "SKIPPED -- the unlocked prompt did not stay up through the snooze")
			elseif line:find("no prompt until", 1, true) then
				fail(scenario, "the line says there is no prompt over an unlocked one still on screen: " .. line)
			elseif not line:find("unlocked", 1, true) then
				fail(scenario, "the line does not say the prompt is unlocked: " .. line)
			end
		elseif not line:find("no prompt until", 1, true) then
			fail(scenario, "the locked snooze line changed: " .. line)
		end
		ns.StopSnooze(true)
		guarded(scenario, ns)
	end
	restore()
end
Mock.reset()

-- ------------------------------------------------------------------ core-8
-- The greeting counts the queue to decide between "somebody real is on the
-- prompt" and a preview. The queue knows nothing of a snooze, which hides the
-- button -- so a snoozed character with a stranger nearby was told the prompt
-- was on screen, and the preview it was owed never ran.
for _, route in ipairs({ "after a fight", "/manners welcome" }) do
	Mock.reset()
	Mock.sv = {}
	local scenario = "core: the greeting does not point at a snoozed prompt (" .. route .. ")"
	local restore = H.strangers({ nameplate1 = { "Close", "By" } })
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			if route == "after a fight" then Mock.inCombat = true end
			ns.addon:OnInitialize()
			ns.addon:OnEnable()
			ns.nameplateUnits.nameplate1 = true
			Mock.runTimers(2)
			if route == "after a fight" and ns.db.char.welcomed then
				fail(scenario, "SKIPPED -- the greeting did not wait for the fight")
				return
			end
			if #ns.BuildQueue() == 0 then
				fail(scenario, "SKIPPED -- nobody is in the queue, so the crowded greeting cannot be reached")
				return
			end
			ns.addon:HandleSlash("snooze 15")
			Mock.printed = {}
			if route == "after a fight" then
				Mock.inCombat = false
				ns.addon:PLAYER_REGEN_ENABLED()
				Mock.runTimers(1)
			else
				ns.addon:HandleSlash("welcome")
			end
			local line = said()
			if line:find("somebody real on it already", 1, true) then
				fail(scenario, "the greeting says the prompt is on screen while a snooze hides it: " .. line)
			end
			if not ns.Prompt:InTest() then
				fail(scenario, "the preview the greeting promises did not run: " .. line)
			end
		end)
		Mock.inCombat = false
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
		guarded(scenario, ns)
	end
	restore()
end
Mock.reset()

-- ------------------------------------------------------------------ core-9
-- "Returning the favour is on the prompt", said while a snooze keeps the
-- prompt away for up to half an hour -- longer than the favour is kept -- or
-- while Not while mounted does. Neither is true, and the favour usually runs
-- out without ever being shown. Nor while the prompt is unlocked: it is on
-- screen then, but as "Drag to move", arming nobody.
for _, case in ipairs({ "snoozed", "mounted", "unlocked", "neither" }) do
	Mock.reset()
	local scenario = "core: the favour line does not promise a prompt that is kept away (" .. case .. ")"
	local realMounted = IsMounted
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		H.primeAuras(ns)
		if case == "snoozed" then
			ns.addon:HandleSlash("snooze 15")
		elseif case == "mounted" then
			ns.db.profile.filters.hideMounted = true
			IsMounted = function() return true end
			ns.addon:Tick()
		elseif case == "unlocked" then
			ns.addon:HandleSlash("unlock")
			if ns.db.profile.prompt.locked then
				fail(scenario, "SKIPPED -- /manners unlock left the prompt locked")
			end
		end
		local line = H.favourFrom(ns, "nameplate1", 1459, 4101)
		if not ns.owed[PETRA] then
			fail(scenario, "SKIPPED -- no favour was filed: " .. line)
		elseif case == "neither" then
			if not line:find("returning the favour is on the prompt", 1, true) then
				fail(scenario, "the ordinary favour line changed: " .. line)
			end
		elseif line:find("returning the favour is on the prompt", 1, true)
			and not line:find("once you get off your mount", 1, true)
			and not line:find("once you lock it", 1, true) then
			fail(scenario, "the line promises the prompt while it is kept away: " .. line)
		elseif case == "snoozed" and not line:find("snoozed", 1, true) then
			fail(scenario, "the line does not say the prompt is snoozed: " .. line)
		elseif case == "mounted" and not line:find("once you get off your mount", 1, true) then
			fail(scenario, "the line does not say the mount is keeping the prompt away: " .. line)
		elseif case == "unlocked" and not line:find("once you lock it", 1, true) then
			fail(scenario, "the line does not say the prompt waits for the lock: " .. line)
		end
		if ns.StopSnooze then ns.StopSnooze(true) end
		guarded(scenario, ns)
	end
	IsMounted = realMounted
end
Mock.reset()

-- ------------------------------------------------------------------ core-10
-- The server refusing a cast after it was sent: the client takes back the
-- global cooldown it started speculatively, and the sweep over the prompt's
-- icon has to follow -- it went on running for up to a second and a half over
-- a button a press would already go through on.
dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local function withTree(scenario, names, body)
	Mock.reset()
	FT.install()
	local restore = H.strangers(names or {})
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns) end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local IDLE = { startTime = 0, duration = 0 }

-- An event delivered the way the client delivers it: only if the addon asked
-- for it. Calling the handler directly would pass with the registration gone,
-- and on the real client the handler would then never run.
local function send(scenario, ns, event, ...)
	if not Mock.registeredEvents[event] then
		fail(scenario, event .. " is never registered, so the client never delivers it")
		return
	end
	if type(ns.addon[event]) ~= "function" then
		fail(scenario, "there is no " .. event .. " handler")
		return
	end
	ns.addon[event](ns.addon, event, ...)
end

-- Whether the sweep is still running at this moment.
local function sweeping(cd)
	local c = cd._cooldown
	return cd:IsShown() and c ~= nil and c.start + c.duration > Mock.now
end

for _, how in ipairs({ "refused", "cooldown update", "interrupted" }) do
	local scenario = "core: the sweep stops when the global cooldown is given back (" .. how .. ")"
	withTree(scenario, { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } }, function(ns)
		H.freshPrompt(ns, scenario)
		H.owe(ns, "Anna Aim")
		H.owe(ns, "Bert Beside")
		ns.addon:Tick()
		local cd = ns.Prompt:Regions().cooldown
		if not (cd and cd.SetCooldown) then
			fail(scenario, "SKIPPED -- no cooldown frame on the icon")
			return
		end
		Mock.spellCooldowns = { [61304] = IDLE }
		Mock.spellCooldowns[61304] = { startTime = Mock.now, duration = 1.5 }
		send(scenario, ns, "UNIT_SPELLCAST_SENT", "player", "Anna", "Cast-LOS", 1459)
		if not sweeping(cd) then
			fail(scenario, "SKIPPED -- the cast showed no sweep to begin with")
			return
		end
		Mock.advance(0.1)
		Mock.spellCooldowns[61304] = IDLE
		if how == "refused" then
			send(scenario, ns, "UNIT_SPELLCAST_FAILED", "player", "Cast-LOS", 1459)
		elseif how == "cooldown update" then
			send(scenario, ns, "SPELL_UPDATE_COOLDOWN")
		else
			send(scenario, ns, "UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-LOS", 1459)
		end
		local ready = ns.CastReady()
		if ready and sweeping(cd) then
			local c = cd._cooldown
			fail(scenario, ("the icon still sweeps (%s for %s) over a button a press goes through on")
				:format(tostring(c.start), tostring(c.duration)))
		end
		guarded(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ core-11
-- A cast longer than the global cooldown -- a three-second conjure -- keeps a
-- press from going through until it ends, and CastReady says so. The sweep
-- read only the global cooldown, so it ended at a second and a half over a
-- button that answered "ready in 1.0s".
--
-- The cast is only on UnitCastingInfo once it has started, as on the real
-- client, where it is empty at SENT: START is what stretches the sweep over it.
-- And pushback moves the end later with UNIT_SPELLCAST_DELAYED alone.
for _, case in ipairs({
	{ figure = "the client's figure" },
	{ figure = "the tracked block" },
	{ figure = "the client's figure", pushback = true },
}) do
	local figure = case.figure
	local scenario = "core: the sweep lasts until the player's own cast ends (" .. figure
		.. (case.pushback and ", pushed back" or "") .. ")"
	withTree(scenario, { nameplate1 = { "Anna", "Aim" } }, function(ns)
		H.freshPrompt(ns, scenario)
		H.owe(ns, "Anna Aim")
		ns.addon:Tick()
		local cd = ns.Prompt:Regions().cooldown
		if not (cd and cd.SetCooldown) then
			fail(scenario, "SKIPPED -- no cooldown frame on the icon")
			return
		end
		local t0 = Mock.now
		if figure == "the client's figure" then
			Mock.spellCooldowns = { [61304] = { startTime = t0, duration = 1.5 } }
		else
			Mock.spellCooldowns = nil
		end
		send(scenario, ns, "UNIT_SPELLCAST_SENT", "player", nil, "Cast-C", 190336)
		Mock.casting = { spellId = 190336, startsAt = t0, endsAt = t0 + 3 }
		send(scenario, ns, "UNIT_SPELLCAST_START", "player", "Cast-C", 190336)
		local ends = t0 + 3
		if case.pushback then
			Mock.advance(1)
			ends = t0 + 3.5
			Mock.casting.endsAt = ends
			send(scenario, ns, "UNIT_SPELLCAST_DELAYED", "player", "Cast-C", 190336)
			Mock.advance(2.1)
		else
			Mock.advance(2)
		end
		if Mock.spellCooldowns then Mock.spellCooldowns[61304] = IDLE end
		local ready, left = ns.CastReady()
		if ready then
			fail(scenario, "SKIPPED -- CastReady does not see the cast either")
		elseif not sweeping(cd) then
			fail(scenario, ("the icon shows no cooldown while a press is refused for another %.1fs"):format(left))
		else
			local c = cd._cooldown
			if c.start + c.duration < ends - 1e-6 then
				fail(scenario, ("the sweep ends at %.1f and the cast at %.1f"):format(c.start + c.duration - t0, ends - t0))
			end
		end
		guarded(scenario, ns)
	end)
end
Mock.reset()

-- ------------------------------------------------------------------ core-12
-- Earlier builds were English only, and filled the phrase box with the English
-- set; AceDB kept it, since the default is empty. On a translated client that
-- box stayed English -- in the macro, in Roll a few, in every export -- and the
-- set dropdown read blank as though it had been edited. The addon's own
-- English text now becomes the translated set; anything the player wrote stays.
--
-- Run against every set, with the English each shipped as captured before the
-- "translation": that is also what proves the English copy Core keeps has not
-- drifted from the lines themselves.
for _, key in ipairs({ "roleplay", "polite", "cheeky", "quiet" }) do
	Mock.reset()
	local scenario = "core: an English phrase box written by an earlier build is translated (" .. key .. ")"
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local set = ns.PHRASE_SETS[key]
		local english = table.concat(set.lines, "\n")
		local translated = {}
		for i, line in ipairs(set.lines) do translated[i] = "[fr] " .. line end
		set.lines = translated
		local speech = ns.db.profile.speech
		speech.phrases = english
		speech.presetChoice = key ~= "roleplay" and key or nil
		ns.ClampSettings()
		if speech.phrases ~= ns.PhraseSetText(key) then
			fail(scenario, "the English lines an earlier build wrote were kept on a translated client")
		end
		local preset = H.findOption(ns.optionsTable, "preset")
		if preset and preset.get and preset.get({ "preset" }) ~= key then
			fail(scenario, "the set dropdown reads " .. tostring(preset.get({ "preset" }))
				.. " over the untouched set")
		end
		if key == "roleplay" and ns.ExportSettings():find("speech.phrases=", 1, true) then
			fail(scenario, "an untouched phrase box is exported as though it were edited")
		end
		-- The player's own lines are theirs, whatever language they are in.
		speech.phrases = "Thanks, {name}!"
		ns.ClampSettings()
		if speech.phrases ~= "Thanks, {name}!" then
			fail(scenario, "an edited phrase box was replaced: " .. tostring(speech.phrases))
		end
		guarded(scenario, ns)
	end
end
Mock.reset()
