-- Bug hunt 38, the options window and its words: Show every error, the Right
-- now line, Quick setup's numbering, search after a non-ASCII quote, a greyed
-- control's tooltip, what Diagnostics says for a class it cannot read, the
-- flask switch of a class with no other prompt, and three sentences that
-- named things as they no longer are.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every name
-- starts with "window-fixes38:" so the mutations in
-- tests/mutations/window-fixes38.py can name exactly one.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "C_Item", "InCombatLockdown" }

-- One session, the window open on `spec.page` (none: not opened).
-- `spec.flavour`, `spec.class`, `spec.before(ns)` (after the load, before the
-- window opens). `body(ns, UI)`. Everything put back.
local function session(scenario, spec, body)
	Mock.reset()
	if spec.flavour then Mock.setFlavour(spec.flavour) end
	if spec.class then Mock.class = spec.class end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	FT.install()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		if spec.before then spec.before(ns) end
		if spec.page then ns.OpenOptions(spec.page, true) end
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		wipe(ns.errors)
	end)
	FT.uninstall()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function rowText(UI, path)
	local row = UI.RowFor(path)
	return row and row.text and row.text:GetText() or ""
end

local function nameOf(ns, path, field)
	local B = ns.WindowBind
	local item = B and B.Item(path)
	return item and B.Text(item, field or "name") or ""
end

-- ------------------------------------------------------------------ O1
-- Show every error ran /manners errors, which lists the last five: its
-- tooltip promises every error this session.
do
	local scenario = "window-fixes38: Show every error lists every one kept"
	session(scenario, {}, function(ns)
		local button = H.findOption(ns.optionsTable, "allErrors")
		if not (button and button.func) then
			fail(scenario, "there is no Show every error")
			return
		end
		local NAMES = { "alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel" }
		for _, word in ipairs(NAMES) do
			ns.Guard("window-fixes38 " .. word, error, "broke " .. word, 0)
		end
		Mock.printed = {}
		button.func()
		local said = table.concat(Mock.printed, "\n")
		for _, word in ipairs(NAMES) do
			if not said:find("broke " .. word, 1, true) then
				fail(scenario, "Show every error left out the error '" .. word .. "': " .. said)
			end
		end
		-- /manners errors keeps the short form its help promises.
		Mock.printed = {}
		ns.addon:HandleSlash("errors")
		said = table.concat(Mock.printed, "\n")
		if said:find("broke alpha", 1, true) or not said:find("broke hotel", 1, true) then
			fail(scenario, "/manners errors is no longer the last few: " .. said)
		end
	end)
end

-- ------------------------------------------------------------------ O2
-- The Right now line was painted when the page was, and stayed while the
-- prompt moved on; unlocked or snoozed, it said nobody was about.
do
	local scenario = "window-fixes38: the Right now line follows the prompt"
	session(scenario, { page = "who" }, function(ns, UI)
		H.freshPrompt(ns, scenario)
		ns.Prompt:ExitTest()
		ns.addon:Tick()
		ns.RefreshOptionsDisplay()
		if not UI.RowShown("who.rightNow") then
			fail(scenario, "SKIPPED -- the line is not drawn on Who to buff")
			return
		end
		local before = rowText(UI, "who.rightNow")
		-- Somebody new buffs you: the scan changes the line, nothing else
		-- repaints the page.
		H.owe(ns, "Zora Zeal")
		H.owe(ns, "Yuri Yew")
		ns.addon:Tick()
		local want = ns.OptionsPage.RightNow()
		if want == before then
			fail(scenario, "SKIPPED -- two favours did not change the line: " .. tostring(want))
		elseif rowText(UI, "who.rightNow") ~= want then
			fail(scenario, "after the scan the page still reads " .. rowText(UI, "who.rightNow")
				.. ", where the prompt now says " .. tostring(want))
		end
		-- Unlocked, the prompt holds everybody back: said as that.
		ns.db.profile.prompt.locked = false
		ns.Prompt:Refresh()
		local line = ns.OptionsPage.RightNow() or ""
		if line:find(ns.L["Right now: nobody to offer."], 1, true) then
			fail(scenario, "unlocked, the line says nobody is about: " .. line)
		end
		if rowText(UI, "who.rightNow") ~= line then
			fail(scenario, "unlocked, the page still reads " .. rowText(UI, "who.rightNow"))
		end
		ns.db.profile.prompt.locked = true
		-- In a fight with nobody on the prompt, nobody new can come on it.
		ns.Prompt:ApplyTarget(nil)
		ns.Prompt:GetButton():Hide()
		rawset(_G, "InCombatLockdown", function() return true end)
		line = ns.OptionsPage.RightNow() or ""
		rawset(_G, "InCombatLockdown", function() return false end)
		if not line:find(ns.L["Right now: nobody, and nobody new comes on the prompt until this fight ends."], 1, true) then
			fail(scenario, "in a fight with nobody on the prompt, the line says " .. line)
		end
	end)
end

-- ------------------------------------------------------------------ O3
-- While Quick setup asks, step 1 is away: the page went from Quick setup to
-- "2. Put it on a key", and Not now promised the same choices below.
do
	local scenario = "window-fixes38: Quick setup is step 1 while it asks"
	session(scenario, { page = "general" }, function(ns, UI)
		if not ns.QuickSetup.Asking() then
			fail(scenario, "SKIPPED -- a new profile is not asked the two questions")
			return
		end
		local head = nameOf(ns, "general.firstHeader")
		if not head:find("^1%. ") then fail(scenario, "Quick setup is headed " .. head .. ", not as step 1") end
		if UI.RowShown("general.quickWho") then fail(scenario, "step 1 is drawn under Quick setup") end
		local key = nameOf(ns, "general.keyHeader")
		if not key:find("^2%. ") then fail(scenario, "SKIPPED -- the key step reads " .. key) end
		local tip = nameOf(ns, "general.firstSkip", "desc")
		if tip:find("below", 1, true) then fail(scenario, "Not now still says the choices are below: " .. tip) end
		if not (tip:find(ns.L["Who to buff"], 1, true) and tip:find(ns.L["What I say"], 1, true)) then
			fail(scenario, "Not now does not say where the choices are: " .. tip)
		end
	end)
end

-- ------------------------------------------------------------------ O4
-- A word after a German or French quote, or a Spanish ¿, never started a
-- word for the search.
do
	local scenario = "window-fixes38: search finds a word after a non-ASCII quote"
	session(scenario, {}, function(ns)
		local S = ns.WindowSearch
		local at = S and S.AtWordStart
		if not at then
			fail(scenario, "there is no AtWordStart")
			return
		end
		local cases = {
			{ "Nur \226\128\158ungepr\195\188fte\226\128\156 Spieler", "ungepr" },
			{ "le mode \194\171 calme \194\187", "calme" },
			{ "\194\191Quieres ayuda?", "quieres" },
			{ "\194\161Hola!", "hola" },
			{ "the \226\128\156quiet\226\128\157 switch", "quiet" },
			{ "it\226\128\153s \226\128\152off\226\128\153", "off" },
		}
		for _, case in ipairs(cases) do
			if not at(case[1], case[2]) then
				fail(scenario, ("'%s' does not start a word of '%s'"):format(case[2], case[1]))
			end
		end
		-- Still whole words: the middle of one is not a start.
		if at("Nur \226\128\158ungepr\195\188fte\226\128\156", "gepr") then
			fail(scenario, "the middle of a quoted word reads as its start")
		end
	end)
end

-- ------------------------------------------------------------------ O5
-- Flash when someone buffs me greys for the reason its tooltip already
-- gives, and the tooltip said it twice.
do
	local scenario = "window-fixes38: a greyed control's tooltip says its reason once"
	session(scenario, { page = "appearance" }, function(ns, UI)
		local p = ns.db.profile.prompt
		p.style, p.accentMode, p.showIcon, p.effects = "glass", "icon", false, "calm"
		ns.RefreshOptionsDisplay()
		local row = UI.RowFor("appearance.flashStyle")
		if not (row and UI.RowShown("appearance.flashStyle") and row.off) then
			fail(scenario, "SKIPPED -- Flash when someone buffs me is not drawn greyed")
			return
		end
		local lines = {}
		local tip = GameTooltip
		local add, show, owner = tip.AddLine, tip.Show, tip.SetOwner
		tip.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
		tip.Show, tip.SetOwner = function() end, function() end
		-- Whichever of the row's frames opens its tooltip (W.Tip): the field
		-- of a dropdown, the first button of a row of choices.
		local frames = {}
		for _, key in ipairs({ "hit", "field", "button" }) do
			if row[key] then frames[#frames + 1] = row[key] end
		end
		for _, list in ipairs({ row.buttons or {}, row.boxes or {}, row.choices or {} }) do
			for _, frame in ipairs(list) do frames[#frames + 1] = frame end
		end
		local entered = false
		for _, frame in ipairs(frames) do
			local enter = not entered and type(frame) == "table" and frame.GetScript and frame:GetScript("OnEnter")
			if enter and frame.row == row then
				enter(frame)
				entered = true
			end
		end
		tip.AddLine, tip.Show, tip.SetOwner = add, show, owner
		if not entered then
			local keys = {}
			for k in pairs(row) do keys[#keys + 1] = tostring(k) end
			table.sort(keys)
			fail(scenario, "SKIPPED -- no frame of the " .. tostring(row.kind) .. " row opens a tooltip: "
				.. table.concat(keys, " "))
			return
		end
		local reason = ns.L["Needs the icon, the stripe or Full animations."]
		local times = 0
		for _, line in ipairs(lines) do
			if line == reason then times = times + 1 end
		end
		if times ~= 1 then
			fail(scenario, ("the tooltip says why %d times: %s"):format(times, table.concat(lines, " / ")))
		end
	end)
end

-- ------------------------------------------------------------------ O6
-- Start here and the launcher send a character with nothing to cast to What
-- Manners can see "for why", where the line said only that there was
-- nothing, whatever the reason.
do
	local scenario = "window-fixes38: What Manners can see says why there is nothing"
	session(scenario, {}, function(ns)
		local note = H.findOption(ns.optionsTable, "noDiag")
		local function said()
			local name = note and note.name
			if type(name) == "function" then name = name() end
			return tostring(name)
		end
		local nothing = ns.L["Nothing to report: this character has no buffs it can put on another player."]
		local caps = ns.caps
		local class, has = caps.class, caps.hasClassBuffs
		caps.hasClassBuffs = false
		caps.class = nil
		local unread = said()
		caps.class = "TINKER"
		local unlisted = said()
		caps.class = "ROGUE"
		ns.CLASSES_WITHOUT_BUFFS.ROGUE = true
		local rogue = said()
		caps.class, caps.hasClassBuffs = class, has
		if unread:find(nothing, 1, true) or not unread:find("|cffff8080", 1, true) then
			fail(scenario, "with the class not read, it says: " .. unread)
		end
		if unlisted:find(nothing, 1, true) or not unlisted:find("TINKER", 1, true) then
			fail(scenario, "for a class Manners does not list, it says: " .. unlisted)
		end
		if not rogue:find(nothing, 1, true) or rogue:find("|cffff8080", 1, true) then
			fail(scenario, "for a rogue, it says: " .. rogue)
		end
	end)
end

-- ------------------------------------------------------------------ B2
-- A retail death knight's only buff of his own is the flask, off until it is
-- turned on, and its switch was on a page hidden while there is no prompt.
do
	local FLASK = 241320
	local function bags()
		local real = C_Item or {}
		rawset(_G, "C_Item", setmetatable({
			GetItemCount = function(id) return id == FLASK and 2 or 0 end,
		}, { __index = real }))
	end
	local scenario = "window-fixes38: a retail death knight reaches the flask switch"
	session(scenario, { flavour = "mainline", class = "DEATHKNIGHT", before = function(ns)
		bags()
		if ns.ForgetScrolls then ns.ForgetScrolls() end
	end, page = "general" }, function(ns, UI)
		if ns.OptionsPage.HasPrompt() then
			fail(scenario, "SKIPPED -- the death knight has a prompt with the flask off")
			return
		end
		local text = rowText(UI, "general.noBuffs")
		if not text:find(ns.L["Your class has no buffs it can cast on another player."], 1, true) then
			fail(scenario, "Start here no longer says the class has nothing for others: " .. text)
		end
		if not text:find(ns.L["Myself"], 1, true) then
			fail(scenario, "Start here does not say where the switch is: " .. text)
		end
		if not UI.PageVisible("who") then
			fail(scenario, "Who to buff is hidden, and the flask's switch with it")
			return
		end
		UI.ShowPage("who")
		if not UI.RowShown("who.own_flask") then fail(scenario, "Who to buff has no flask switch") end
		-- Switched on, the flask gives him a prompt.
		ns.db.profile.ownBuffs.pick.flask = "auto"
		ns.ForgetScrolls()
		if not ns.OptionsPage.HasPrompt() then fail(scenario, "with the flask on there is still no prompt") end
	end)

	-- A retail paladin who is not Holy: his buffs for others are talents he
	-- has not taken, so he has a Who to buff and nothing that goes on him,
	-- and the flask's switch stood without Myself, its heading, or the
	-- Myself switch that greys it.
	scenario = "window-fixes38: a retail paladin without Beacon reaches the flask switch"
	session(scenario, { flavour = "mainline", class = "PALADIN", before = function(ns)
		bags()
		rawset(_G, "IsSpellKnown", function() return false end)
		rawset(_G, "IsPlayerSpell", function() return false end)
		ns.Guard("probe", ns.ProbeCapabilities)
		if ns.ForgetScrolls then ns.ForgetScrolls() end
	end, page = "who" }, function(ns, UI)
		if not (UI.PageVisible("who") and #ns.SelfBuffs() == 0 and #ns.KnownOwnFamilies() == 0) then
			fail(scenario, "SKIPPED -- the paladin has no Who to buff, or something of his own")
			return
		end
		UI.ShowPage("who")
		if not UI.RowShown("who.own_flask") then fail(scenario, "Who to buff has no flask switch for the paladin") end
		if not UI.RowShown("who.self") then
			fail(scenario, "the flask switch is drawn without the Myself switch it hangs from")
		end
	end)
end

-- ------------------------------------------------------------------ T5-T7
do
	local scenario = "window-fixes38: the quiet help names the switch as it reads"
	session(scenario, {}, function(ns)
		local help
		for _, command in ipairs(ns.COMMANDS) do
			if command.word == "quiet" then help = command.help end
		end
		help = tostring(help)
		if help:find("say nothing", 1, true) or not help:find("chat window", 1, true) then
			fail(scenario, "/manners quiet is described as " .. help)
		end
	end)
end

do
	local scenario = "window-fixes38: Offer nothing in cities and inns names the page Myself is on"
	session(scenario, {}, function(ns)
		local desc = tostring((H.findOption(ns.optionsTable, "quietInTowns") or {}).desc)
		if not (desc:find(ns.L["Myself"], 1, true) and desc:find(ns.L["Who to buff"], 1, true)) then
			fail(scenario, "the tooltip, drawn on When to offer, says: " .. desc)
		end
	end)
end

do
	local scenario = "window-fixes38: the colour-left note names the setting, not a marker"
	session(scenario, {}, function(ns)
		local p = ns.db.profile.prompt
		p.accentMode, p.showIcon = "icon", false
		local note = H.findOption(ns.optionsTable, "accentDead")
		local said = note and note.name and note.name() or ""
		if said:find("marker", 1, true) or not said:find(ns.L["Where the colour shows"], 1, true) then
			fail(scenario, "the note says: " .. said)
		end
	end)
end
