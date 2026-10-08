-- Start here (Options/Start.lua, BuildStartTab): two numbered steps (who to
-- buff, a key), the ledger, and the minimap and chat switches -- and the items
-- of the same group the options window draws elsewhere: the switch, the
-- preview and the snooze in its header, Lock it in its status strip, the voice
-- choice on What I say. The lock warning and the off notice are the strip's
-- line now (ns.LauncherState), and Where it sits and Lock position are Look's.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function said()
	return table.concat(Mock.printed, "\n")
end

local function text(value)
	if type(value) == "function" then return tostring(value({})) end
	return tostring(value)
end

local function shown(option)
	if not option then return false end
	if type(option.hidden) == "function" then return not option.hidden({}) end
	return not option.hidden
end

-- A session with the tab built. Answers the namespace and the tab's args, or
-- nil after saying why.
local function session(scenario)
	Mock.reset()
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local general = ns.optionsTable and ns.optionsTable.args.general
	if not (general and general.args) then
		fail(scenario, "SKIPPED -- there is no Start here tab")
		return nil
	end
	if not ns.caps.hasClassBuffs then
		fail(scenario, "SKIPPED -- the session has no class buffs, so the steps are hidden")
		return nil
	end
	return ns, general.args, general
end

-- ------------------------------------------------------------------ 1
do
	local scenario = "start here: two numbered steps, in order"
	local ns, a, general = session(scenario)
	if ns then
		if text(general.name) ~= "Start here" or general.order ~= 1 then
			fail(scenario, "the tab is " .. text(general.name) .. " at order " .. tostring(general.order))
		end
		local steps = {
			{ "whoHeader", "1. Who to buff" }, { "keyHeader", "2. Put it on a key" },
		}
		local last = 0
		for _, step in ipairs(steps) do
			local header = a[step[1]]
			if not header then
				fail(scenario, "there is no " .. step[2] .. " header")
			else
				if text(header.name) ~= step[2] then
					fail(scenario, step[1] .. " reads " .. text(header.name))
				end
				if not shown(header) then
					fail(scenario, step[2] .. " is hidden for a class with buffs")
				end
				if header.order <= last then
					fail(scenario, step[2] .. " comes before the step ahead of it")
				end
				last = header.order
			end
		end
		-- Every control of a step sits between its header and the next one.
		local within = {
			whoHeader = { "quickWho", "quickWhoSummary" },
			keyHeader = { "bindKey", "openBindings", "makeMacro", "bindStatus" },
		}
		for header, keys in pairs(within) do
			for _, key in ipairs(keys) do
				local o = a[key]
				if not o then
					fail(scenario, key .. " is not on the tab")
				elseif not (a[header] and o.order > a[header].order and o.order < a[header].order + 10) then
					fail(scenario, key .. " is not under " .. header)
				end
			end
		end
		-- And the copies the window retired: Where it sits and Lock position
		-- are Look's, Only when I buff someone back is What I say's, and the
		-- off and unlocked notices are the status strip's line.
		for _, gone in ipairs({ "startHeader", "miscHeader", "chatHeader",
			"shareHeader", "shareNote", "shareCopy", "shareText", "sharePaste",
			"startPos", "startLocked", "onlyWhenReturning", "offNotice", "lockNotice" }) do
			if a[gone] then fail(scenario, gone .. " is still on Start here") end
		end
		if text(a.enabled.name) ~= "Manners is on" then
			fail(scenario, "the switch reads " .. text(a.enabled.name))
		end
		local how = text(a.howItWorks.name)
		if not how:find("the prompt", 1, true) or how:find("Putting it on a key", 1, true) then
			fail(scenario, "How it works is not the one definition: " .. how)
		end
		if not (a.minimap and a.minimap.order > a.ledgerOpen.order) then
			fail(scenario, "the minimap switch is not last, under the ledger")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 1a
-- The page as the window draws it: the lead,
-- the two steps, the ledger, then minimap and chat, nothing folded; the switch,
-- the preview and the snooze in the header, Lock it at the strip's end. Above
-- them all, a new profile's two questions (tests/scenarios/quick-setup.lua).
local START_PAGE = {
	"general.firstWho", "general.firstVoice", "general.firstDone", "general.firstSkip",
	"general.noBuffs", "general.howItWorks", "general.quickWho", "general.quickWhoSummary",
	"general.bindKey", "general.makeMacro", "general.openBindings", "general.bindStatus",
	"general.ledgerSummary", "general.ledgerOpen", "general.minimap", "general.verbose",
}
do
	local scenario = "start here: the page as the window draws it"
	local ns = session(scenario)
	if ns and H.layoutInToc() and not ns.WindowLayout then
		fail(scenario, "the toc loads the window's layout and ns.WindowLayout is not there")
	elseif ns and ns.WindowLayout then
		local layout = ns.WindowLayout
		local list, sections = H.pagePaths(ns, "general")
		list = list or {}
		for i, want in ipairs(START_PAGE) do
			if list[i] ~= want then
				fail(scenario, ("Start here's row %d is %s, not %s"):format(i, tostring(list[i]), want))
			elseif sections[want].fold then
				fail(scenario, want .. " is folded away on Start here")
			end
		end
		if #list ~= #START_PAGE then
			fail(scenario, ("Start here draws %d rows, not %d"):format(#list, #START_PAGE))
		end
		local header = layout.header or {}
		if header.preview ~= "general.previewStart" or header.enabled ~= "general.enabled" then
			fail(scenario, "the switch or the preview is not in the window's header")
		end
		local snooze = table.concat(header.snooze or {}, " ")
		if snooze ~= "general.snooze5 general.snooze15 general.snooze30 general.snoozeStop" then
			fail(scenario, "the header's snooze menu holds " .. snooze)
		end
		if not (layout.strip and layout.strip.lock == "general.lockNow") then
			fail(scenario, "Lock it is not at the end of the status strip")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 1b
-- The minimap button and the chat lines, last, under a header of their own:
-- without one the minimap switch read as a ledger setting, and the chat
-- switch people reach for when the lines annoy them was hidden on Diagnostics.
do
	local scenario = "start here: minimap and chat under their own header"
	local ns, a = session(scenario)
	if ns then
		local header, minimap, verbose = a.minimapHeader, a.minimap, a.verbose
		if not (header and header.type == "header" and text(header.name) == "Minimap and chat") then
			fail(scenario, "there is no Minimap and chat header")
		elseif not (minimap and verbose and header.order > a.ledgerOpen.order
			and minimap.order > header.order and verbose.order > minimap.order) then
			fail(scenario, "the minimap and chat switches are not under their header, after the ledger")
		end
		if verbose then
			if text(verbose.name) ~= "Tell me in chat what Manners is doing" then
				fail(scenario, "the verbose switch reads " .. text(verbose.name))
			end
			if not text(verbose.desc):find("Only you see these", 1, true) then
				fail(scenario, "the verbose switch does not say only you see it: " .. text(verbose.desc))
			end
			-- The same saved key as ever.
			local profile = ns.db.profile
			local was = profile.verbose
			verbose.set({ "verbose" }, not was)
			if profile.verbose ~= not was or verbose.get({ "verbose" }) ~= not was then
				fail(scenario, "the verbose switch does not write profile.verbose")
			end
			verbose.set({ "verbose" }, was)
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 2
do
	local scenario = "start here: nothing to set up without class buffs"
	local ns, a = session(scenario)
	if ns then
		ns.caps.hasClassBuffs = false
		for _, key in ipairs({ "howItWorks", "whoHeader", "quickWho", "quickWhoSummary",
			"keyHeader", "bindKey", "openBindings", "makeMacro", "bindStatus",
			"previewStart", "quickVoice", "quickVoiceSummary",
			"snoozeNote", "snooze5", "snooze15", "snooze30", "lockNow" }) do
			if a[key] and shown(a[key]) then
				fail(scenario, key .. " is shown to a class with nothing to cast")
			end
		end
		if not shown(a.noBuffs) then
			fail(scenario, "the class with nothing to cast is not told so")
		end
		ns.caps.hasClassBuffs = true
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 3
do
	local scenario = "start here: the unlocked prompt is flagged with a Lock it button"
	local ns, a = session(scenario)
	if ns then
		-- The warning is the status strip's line, the launcher's own, on
		-- every page; Lock it sits at its end. Lock position is Look's.
		local function strip()
			local _, line, _, _, _, _, _, kind = ns.LauncherState()
			return kind == "unlocked", tostring(line)
		end
		local locked = ns.optionsTable.args.appearance.args.locked
		local p = ns.db.profile.prompt
		p.locked = true
		if strip() or shown(a.lockNow) then
			fail(scenario, "the unlocked warning is up over a locked prompt")
		end
		locked.set({ "locked" }, false)
		if p.locked ~= false then
			fail(scenario, "Lock position unticked left the prompt locked")
		end
		local up, line = strip()
		if not (up and shown(a.lockNow)) then
			fail(scenario, "the prompt is unlocked and the tab says nothing")
		elseif not line:find("casts nothing", 1, true) then
			fail(scenario, "the unlocked warning reads " .. line)
		end
		-- In a fight too: ApplyStyle holds off, the setting is still written.
		Mock.inCombat = true
		a.lockNow.func({ "lockNow" })
		Mock.inCombat = false
		ns.Prompt:ApplyStyle()
		if p.locked ~= true then
			fail(scenario, "Lock it did not lock the prompt")
		end
		if strip() then
			fail(scenario, "locked, the unlocked warning stayed")
		end
		if locked.get({ "locked" }) ~= true then
			fail(scenario, "Lock position does not read the lock")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 4
do
	local scenario = "start here: Lock position unticked while off says there is nothing to drag"
	local ns = session(scenario)
	if ns then
		local locked = ns.optionsTable.args.appearance.args.locked
		ns.addon:HandleSlash("off")
		Mock.printed = {}
		locked.set({ "locked" }, false)
		if not said():find("no prompt to drag", 1, true) then
			fail(scenario, "unlocked while off, and chat said nothing: " .. said())
		end
		Mock.printed = {}
		locked.set({ "locked" }, true)
		if said():find("no prompt to drag", 1, true) then
			fail(scenario, "locking said there is nothing to drag")
		end
		ns.addon:HandleSlash("on")
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 5
do
	local scenario = "start here: step 1 picks who is offered, and says what it came to"
	local ns, a = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		local who = a.quickWho
		if who.width ~= "full" then fail(scenario, "Offer my buff to is not full width") end
		if who.get({ "quickWho" }) ~= quick.Match(quick.WHO) then
			fail(scenario, "Offer my buff to does not show the preset the profile matches")
		end
		local values, order = who.values({}), who.sorting({})
		if #order ~= #quick.Order(quick.WHO) or values.group ~= "People who buff me, and my group" then
			fail(scenario, "Offer my buff to does not offer the who presets")
		end
		who.set({ "quickWho" }, "group")
		if quick.Match(quick.WHO) ~= "group" or ns.db.profile.sources.strangers ~= false then
			fail(scenario, "picking People who buff me, and my group did not set it up")
		end
		local summary = text(a.quickWhoSummary.name)
		-- Yourself last, which a new profile offers (self.lua), and not in a
		-- city or an inn until Also in cities and inns is ticked (ownbuffs.lua).
		if not summary:find("Offering to: people who buff me, my group, myself (outside cities and inns).", 1, true) then
			fail(scenario, "the summary under step 1 reads " .. summary)
		end
		ns.db.profile.sources.owed = false
		if who.get({ "quickWho" }) ~= "custom" then
			fail(scenario, "changed by hand, the dropdown still names a preset")
		end
		if type(who.confirm) ~= "function" or not who.confirm({ "quickWho" }, "nearby") then
			fail(scenario, "a preset over choices made by hand asks nothing first")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 6
do
	local scenario = "start here: step 4 picks what is said, and says what it came to"
	local ns, a = session(scenario)
	if ns then
		local quick = ns.QuickSetup
		local voice = a.quickVoice
		if voice.get({ "quickVoice" }) ~= "silent" then
			fail(scenario, "a new profile's voice shows " .. tostring(voice.get({ "quickVoice" })))
		end
		voice.set({ "quickVoice" }, "thank")
		if quick.Match(quick.VOICE) ~= "thank" or ns.db.profile.prompt.thankEmote ~= true then
			fail(scenario, "picking Just /thank them did not set it up")
		end
		local summary = text(a.quickVoiceSummary.name)
		if not summary:find("Only /thank.", 1, true) then
			fail(scenario, "the summary under step 4 reads " .. summary)
		end
		if not voice.values({}).polite or voice.sorting({})[1] ~= "silent" then
			fail(scenario, "When I buff someone back does not offer the voice presets")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 7
do
	local scenario = "start here: step 2 puts the prompt on a key"
	local ns, a = session(scenario)
	if ns then
		local key = a.bindKey
		if key.type ~= "keybinding" then fail(scenario, "bindKey is a " .. tostring(key.type)) end
		if not shown(key) then fail(scenario, "the key control is hidden on a client that can bind") end
		local status = text(a.bindStatus.name)
		if not status:find("No key yet", 1, true) then
			fail(scenario, "with no key and no macro, the status reads " .. status)
		end
		key.set({ "bindKey" }, "F7")
		if Mock.bindings.F7 ~= ns.Setup.COMMAND then
			fail(scenario, "the key picked was not bound to the prompt")
		end
		if key.get({ "bindKey" }) ~= "F7" then
			fail(scenario, "the key control does not show the key it bound")
		end
		status = text(a.bindStatus.name)
		if not (status:find("Ready", 1, true) and status:find("F7", 1, true)) then
			fail(scenario, "with a key bound, the status reads " .. status)
		end
		Mock.inCombat = true
		if not (key.disabled and key.disabled({})) then
			fail(scenario, "the key control is live in a fight, where SetBinding is refused")
		end
		if not (a.openBindings.disabled and a.openBindings.disabled({})) then
			fail(scenario, "Open key bindings is live in a fight")
		end
		Mock.inCombat = false
		key.set({ "bindKey" }, "")
		if key.get({ "bindKey" }) ~= "" or Mock.bindings.F7 then
			fail(scenario, "clearing the key left it bound")
		end
		Mock.macros = { Manners = 1 }
		status = text(a.bindStatus.name)
		if not status:find("macro is made", 1, true) then
			fail(scenario, "with the macro made, the status reads " .. status)
		end
		Mock.macros = nil
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 8
do
	local scenario = "start here: Make a macro makes the macro"
	local ns, a = session(scenario)
	if ns then
		if text(a.makeMacro.name) ~= "Make a macro" then
			fail(scenario, "the button reads " .. text(a.makeMacro.name))
		end
		if text(a.makeMacro.desc):find("/click", 1, true) then
			fail(scenario, "the tooltip still shows the raw /click text")
		end
		local real, made = ns.CreateClickMacro, 0
		ns.CreateClickMacro = function() made = made + 1 end
		a.makeMacro.func({ "makeMacro" })
		ns.CreateClickMacro = real
		if made ~= 1 then
			fail(scenario, "Make a macro made nothing")
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 9
do
	-- The preview, which the window draws in its header. Where it sits is
	-- Look's (options-appearance.lua holds it).
	local scenario = "start here: step 3 shows the prompt"
	local ns, a = session(scenario)
	if ns then
		local preview = a.previewStart
		if text(preview.name) ~= "Show me the prompt" then
			fail(scenario, "the preview button reads " .. text(preview.name))
		end
		Mock.inCombat = true
		if not preview.disabled({}) then
			fail(scenario, "the preview can be started in a fight")
		end
		Mock.inCombat = false
		ns.db.profile.enabled = false
		preview.func({ "previewStart" })
		if not ns.Prompt:InTest() then
			fail(scenario, "SKIPPED -- the preview did not start")
		elseif text(preview.name) ~= "Stop preview" then
			fail(scenario, "with a preview up, the button reads " .. text(preview.name))
		end
		ns.Prompt:ExitTest()
		ns.db.profile.enabled = true
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 10
do
	local scenario = "start here: snooze, ledger and minimap wording"
	local ns, a = session(scenario)
	if ns then
		local note = text(a.snoozeNote.name)
		if note ~= "Hide the prompt for a while without turning Manners off." then
			fail(scenario, "the idle snooze note reads " .. note)
		end
		if text(a.snooze5.name) ~= "Snooze 5 minutes" or text(a.snooze30.name) ~= "Snooze 30 minutes" then
			fail(scenario, "the snooze buttons read " .. text(a.snooze5.name) .. " / " .. text(a.snooze30.name))
		end
		if not (a.snooze5.order < a.snooze15.order and a.snooze15.order < a.snooze30.order
			and a.snooze30.order < a.snoozeStop.order and a.snoozeHeader.order < a.snoozeNote.order) then
			fail(scenario, "the snooze controls are out of order")
		end
		a.snooze5.func({ "snooze5" })
		if not ns.SnoozeLeft() or not text(a.snoozeNote.name):find("Snoozed until", 1, true) then
			fail(scenario, "the 5-minute button did not snooze")
		end
		ns.StopSnooze(true)
		if a.ledgerOpen and text(a.ledgerOpen.desc) ~= "Who buffed you, whether you returned it, and who you buffed first." then
			fail(scenario, "Open the ledger's tooltip reads " .. text(a.ledgerOpen.desc))
		end
		local desc = text(a.minimap.desc)
		if not (desc:find("/manners", 1, true) and desc:find("Options > AddOns", 1, true)) then
			fail(scenario, "the minimap switch does not say the other ways in: " .. desc)
		end
		noErrors(scenario, ns)
	end
end
