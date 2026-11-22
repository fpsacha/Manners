-- Your own buffs are on one page, My own buffs (the picks, where and when they
-- come up, topping up early, the consumables button and its key, weapons, food
-- and scrolls, your own spells), and a hunter's pet has a page of its own,
-- My pet. Who to buff is about other people again, and its reset leaves your
-- own buffs alone.
--
-- Every scenario name starts with "menupass-self:".
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption = H.findOption

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local HAWK, MONKEY = 13165, 13163
local CALL_PET, REVIVE_PET = 883, 982
local SUPPLIES = "CLICK MannersSupplies:LeftButton"

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- opts.class (default PRIEST), opts.all (every spell known), opts.fortitude
-- (a priest knowing only his Fortitude), opts.known (these spell ids only), opts.frames (the
-- frame tree, for measuring), opts.before(ns) (after the load, before the
-- window opens).
local function with(scenario, opts, body)
	opts = opts or {}
	Mock.reset()
	if opts.frames then FT.install() end
	Mock.class = opts.class or "PRIEST"
	local savedKnown, savedPlayer = rawget(_G, "IsSpellKnown"), rawget(_G, "IsPlayerSpell")
	local ns = load(scenario)
	if not ns then
		if opts.frames then FT.uninstall() end
		return
	end
	local ok, err = pcall(function()
		if opts.all then
			Mock.knownSpells = setmetatable({}, { __index = function() return true end })
		elseif opts.known then
			local set = {}
			for _, id in ipairs(opts.known) do set[id] = true end
			IsSpellKnown = function(id) return set[id] == true end
			IsPlayerSpell = IsSpellKnown
		elseif opts.fortitude then
			-- A priest who has learned his Fortitude: on a client without Well
			-- Fed, that is what gives Myself something to offer.
			local set = {}
			local buff = ns.FindBuff("PRIEST", "fortitude")
			for _, id in ipairs(buff and buff.ranks or {}) do set[id] = true end
			IsSpellKnown = function(id) return set[id] == true end
			IsPlayerSpell = IsSpellKnown
		elseif opts.class == "HUNTER" then
			local set = { [HAWK] = true, [MONKEY] = true, [CALL_PET] = true, [REVIVE_PET] = true }
			IsSpellKnown = function(id) return set[id] == true end
			IsPlayerSpell = IsSpellKnown
		end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		if opts.before then opts.before(ns) end
		body(ns, ns.WindowUI)
		ns.Prompt:ExitTest()
		noErrors(scenario, ns)
	end)
	Mock.inCombat = false
	IsSpellKnown, IsPlayerSpell = savedKnown, savedPlayer
	if opts.frames then FT.uninstall() end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function section(ns, pageId, key)
	for _, sec in ipairs(ns.WindowLayout.pages[pageId].sections) do
		if sec.key == key then return sec end
	end
end

-- The paths a page's sections place.
local function placed(ns, pageId)
	local out = {}
	for _, sec in ipairs(ns.WindowLayout.pages[pageId].sections) do
		for _, raw in ipairs(sec.items) do
			local path = type(raw) == "table" and raw[1] or raw
			if type(path) == "string" then out[path] = true end
			for _, id in ipairs(type(raw) == "table" and raw.ids or {}) do out[id] = true end
		end
	end
	return out
end

-- ------------------------------------------------------------------ the page
do
	local scenario = "menupass-self: your own buffs are all on My own buffs"
	with(scenario, { fortitude = true }, function(ns, UI)
		local own = placed(ns, "self")
		local want = { "who.self", "who.ownCities", "who.ownDungeons", "who.ownApart", "who.ownApartKey", "who.ownShout",
			"who.ownScrolls", "who.ownSpellAdd", "diagnostics.ownDiag", "when.selfTopUp", "when.selfLead" }
		-- Every own-buff family the layout places at all.
		for id in pairs(ns.WindowLayout.pages) do
			for path in pairs(placed(ns, id)) do
				if path:find("^who%.own_") and id ~= "self" then fail(scenario, path .. " is on " .. id .. ", not My own buffs") end
			end
		end
		-- (The families a character does not know have no control in the model,
		-- so only the layout can say where they are: all on My own buffs above.)
		for _, path in ipairs(want) do
			if UI.PageOf(path) ~= "self" then
				fail(scenario, path .. " is on " .. tostring(UI.PageOf(path)) .. ", not My own buffs")
			end
		end
		for _, id in ipairs({ "who", "when" }) do
			local held = placed(ns, id)
			for _, path in ipairs(want) do
				if held[path] then fail(scenario, id .. " still holds " .. path) end
			end
		end
		if ns.OptionsPage.TAB.self ~= ns.L["My own buffs"] then
			fail(scenario, "the page's name is " .. tostring(ns.OptionsPage.TAB.self))
		end
		ns.OpenOptions("self")
		if ns.OptionsTab() ~= "self" then fail(scenario, "OpenOptions(\"self\") opened " .. tostring(ns.OptionsTab())) end
		if not UI.RowShown("who.self") then fail(scenario, "the Myself switch is not drawn on My own buffs") end
		if not UI.RowShown("when.selfTopUp") then fail(scenario, "Top up my own buffs is not drawn on My own buffs") end
		local sidebar = {}
		for _, group in ipairs(ns.WindowLayout.groups) do
			for _, id in ipairs(group) do sidebar[#sidebar + 1] = id end
		end
		if not table.concat(sidebar, " "):find("when self pet quiet", 1, true) then
			fail(scenario, "the sidebar is " .. table.concat(sidebar, " "))
		end
		-- The top-up heading no longer says what the page is called.
		local top = section(ns, "self", "self.topUp")
		if not (top and top.header == "when.selfHeader") then fail(scenario, "self.topUp has no Topping up early heading") end
	end)
end

-- ------------------------------------------------------------------ the pet
do
	local scenario = "menupass-self: a hunter's pet has a page of its own"
	with(scenario, { class = "HUNTER" }, function(ns, UI)
		local held = placed(ns, "pet")
		local count = 0
		for _, id in ipairs({ "who", "self" }) do
			for path in pairs(placed(ns, id)) do
				if path:find("^who%.beast") then fail(scenario, id .. " still holds " .. path) end
			end
		end
		for path in pairs(held) do
			if path:find("^who%.beast") then count = count + 1 end
		end
		if count < 20 then fail(scenario, "My pet places only " .. count .. " pet controls") end
		for _, path in ipairs({ "who.beastAll", "who.beastCall", "who.beastMend", "who.beastMendFight", "who.beastBond",
			"who.beastPraise", "who.beastMemory" }) do
			if UI.PageOf(path) ~= "pet" then fail(scenario, path .. " is on " .. tostring(UI.PageOf(path)) .. ", not My pet") end
		end
		if ns.OptionsPage.TAB.pet ~= ns.L["My pet"] then fail(scenario, "the page's name is " .. tostring(ns.OptionsPage.TAB.pet)) end
		ns.OpenOptions()
		if not UI.visiblePages.pet then fail(scenario, "a hunter's sidebar has no My pet") end
		ns.OpenOptions("pet")
		if not UI.RowShown("who.beastAll") then fail(scenario, "the pet switch is not drawn on My pet") end
	end)
	with(scenario, { class = "MAGE" }, function(ns, UI)
		ns.OpenOptions()
		if UI.visiblePages.pet then fail(scenario, "a mage has a My pet page") end
	end)
end

-- A hunter who has learned Call and Revive Pet and nothing else (a retail
-- hunter has no aspect): the pet's pages are his, on every client.
do
	local scenario = "menupass-self: a hunter who knows only Call and Revive Pet is shown the pet's pages"
	with(scenario, { class = "HUNTER", known = { CALL_PET, REVIVE_PET } }, function(ns, UI)
		if not ns.Beast.KnowsCare() then fail(scenario, "Beast.KnowsCare is false for a hunter who knows Call Pet") end
		if not ns.OptionsPage.HasPrompt() then fail(scenario, "the options say a hunter with Call and Revive Pet has no prompt") end
		ns.OpenOptions()
		for _, id in ipairs({ "pet", "skip", "appearance" }) do
			if not UI.visiblePages[id] then fail(scenario, "the sidebar has no " .. id .. " page for him") end
		end
	end)
	-- With the pet's switch off the pages stay: it is turned back on there.
	with(scenario, { class = "HUNTER", known = { CALL_PET, REVIVE_PET } }, function(ns, UI)
		ns.db.profile.beast.all = false
		ns.RefreshOptionsDisplay()
		ns.OpenOptions()
		if not UI.visiblePages.pet then fail(scenario, "Everything for my pet off hides My pet, which turns it back on") end
	end)
end

-- ------------------------------------------------------------------ Mend Pet
do
	local scenario = "menupass-self: Mend Pet's two switches stand together"
	with(scenario, { class = "HUNTER" }, function(ns)
		local sec = section(ns, "pet", "pet.care")
		if not sec then fail(scenario, "no section pet.care") return end
		local at
		for i, raw in ipairs(sec.items) do
			if (type(raw) == "table" and raw[1] or raw) == "who.beastMend" then at = i end
		end
		if not at then fail(scenario, "Mend Pet is not on My pet") return end
		local a, b = sec.items[at], sec.items[at + 1]
		if not (type(b) == "table" and b[1] == "who.beastMendFight") then
			fail(scenario, "Mend Pet in a fight does not come right after Mend Pet")
			return
		end
		local function indent(item) return type(item) == "table" and item.indent or false end
		if indent(a) ~= indent(b) then
			fail(scenario, "the two Mend Pet switches are at different indents: " .. tostring(indent(a)) .. " and " .. tostring(indent(b)))
		end
	end)
end

-- ------------------------------------------------------------------ the key
do
	local scenario = "menupass-self: the consumables button's key is set in the window"
	with(scenario, { fortitude = true }, function(ns, UI)
		local profile = ns.db.profile
		profile.ownBuffs.apart = true
		ns.OpenOptions("self")
		ns.RefreshOptionsDisplay()
		if not UI.RowShown("who.ownApartKey") then
			fail(scenario, "no key row under the consumables switch with it on")
			return
		end
		local key = findOption(ns.optionsTable, "ownApartKey")
		if not (key and key.type == "keybinding") then fail(scenario, "the model has no key control") return end
		Mock.bindings = { G = "JUMP" }
		_G.BINDING_NAME_JUMP = "Jump"
		Mock.printed = {}
		key.set({ "who", "ownApartKey" }, "G")
		_G.BINDING_NAME_JUMP = nil
		if Mock.bindings.G ~= SUPPLIES then fail(scenario, "G was not bound to " .. SUPPLIES) end
		if key.get({ "who", "ownApartKey" }) ~= "G" then fail(scenario, "the control reads " .. tostring(key.get({ "who", "ownApartKey" }))) end
		local said = false
		for _, line in ipairs(Mock.printed or {}) do
			if tostring(line):find("consumables button", 1, true) then said = true end
		end
		if not said then fail(scenario, "taking Jump's key did not say it now uses the consumables button") end
		profile.ownBuffs.apart = false
		ns.RefreshOptionsDisplay()
		if UI.RowShown("who.ownApartKey") then fail(scenario, "the key row is drawn with the consumables button off") end
		if not UI.RowShown("who.ownApart") then fail(scenario, "the switch went with its key") end
	end)
end

-- ------------------------------------------------------------------ three screens
do
	local scenario = "menupass-self: every page stays within three screens for a levelled character"
	for _, class in ipairs({ "PRIEST", "DRUID", "HUNTER", "MAGE", "WARLOCK", "PALADIN" }) do
		with(scenario, { class = class, all = true, frames = true }, function(ns, UI)
			ns.db.profile.menuView = "full"
			UI.State().open = {}
			ns.RefreshOptionsDisplay()
			for _, group in ipairs(ns.WindowLayout.groups) do
				for _, id in ipairs(group) do
					ns.OpenOptions(id)
					if UI.page == id then
						local room = UI.view.height + (UI.subbar.height or 0)
						local screens = (UI.view.range + UI.view.height) / room
						if screens > 3.1 then
							fail(scenario, ("%s: %s is %.2f screens of the usual window with its folds shut"):format(class, id, screens))
						end
					end
				end
			end
		end)
	end
end

-- ------------------------------------------------------------------ the resets
do
	local scenario = "menupass-self: Who to buff's reset leaves your own buffs alone"
	with(scenario, nil, function(ns)
		local p = ns.db.profile
		local d = ns.defaults.profile
		p.ownBuffs.inCities = not d.ownBuffs.inCities
		p.ownBuffs.apart = not d.ownBuffs.apart
		p.ownBuffs.scrolls = not d.ownBuffs.scrolls
		p.sources.self = not d.sources.self
		p.filters.selfLead = 7
		p.filters.selfTopUp = not d.filters.selfTopUp
		p.ownBuffs.pick.flask = "auto"
		if ns.OptionsPage.ResetPage("who") ~= true then fail(scenario, "the reset did not run") return end
		if p.ownBuffs.inCities == d.ownBuffs.inCities or p.ownBuffs.apart == d.ownBuffs.apart
			or p.ownBuffs.scrolls == d.ownBuffs.scrolls or p.sources.self == d.sources.self
			or p.filters.selfLead == d.filters.selfLead or p.filters.selfTopUp == d.filters.selfTopUp
			or p.ownBuffs.pick.flask ~= "auto" then
			fail(scenario, "Who to buff's reset put back a setting of My own buffs")
		end
		if ns.OptionsPage.ResetPage("self") ~= true then fail(scenario, "My own buffs' reset did not run") return end
		for _, case in ipairs({
			{ "inCities", p.ownBuffs.inCities, d.ownBuffs.inCities }, { "apart", p.ownBuffs.apart, d.ownBuffs.apart },
			{ "scrolls", p.ownBuffs.scrolls, d.ownBuffs.scrolls }, { "sources.self", p.sources.self, d.sources.self },
			{ "selfLead", p.filters.selfLead, d.filters.selfLead }, { "selfTopUp", p.filters.selfTopUp, d.filters.selfTopUp },
		}) do
			if case[2] ~= case[3] then fail(scenario, "My own buffs' reset left " .. case[1] .. " at " .. tostring(case[2])) end
		end
		if p.ownBuffs.pick.flask == "auto" then fail(scenario, "My own buffs' reset left a pick") end
	end)
	with(scenario, { class = "HUNTER" }, function(ns)
		local b = ns.db.profile.beast
		b.mend, b.fightMend, b.pace = false, false, "rare"
		if ns.OptionsPage.ResetPage("who") ~= true then fail(scenario, "the reset did not run") return end
		if b.mend ~= false or b.fightMend ~= false or b.pace ~= "rare" then
			fail(scenario, "Who to buff's reset put back the pet's settings")
		end
		if ns.OptionsPage.ResetPage("pet") ~= true then fail(scenario, "My pet's reset did not run") return end
		if b.mend ~= ns.defaults.profile.beast.mend or b.fightMend ~= ns.defaults.profile.beast.fightMend then
			fail(scenario, "My pet's reset left Mend Pet where it was")
		end
	end)
end

-- ------------------------------------------------------------------ a fold's memory
do
	local scenario = "menupass-self: an open pet fold stays open"
	with(scenario, { class = "HUNTER" }, function(ns, UI)
		local open = ns.db.global.window and ns.db.global.window.open
		if type(open) ~= "table" then
			ns.db.global.window = ns.db.global.window or {}
			ns.db.global.window.open = {}
			open = ns.db.global.window.open
		end
		open["who.myselfPetMoments"] = true
		open["pet.moments"] = nil
		ns.OpenOptions("pet")
		local now = UI.State().open
		if now["pet.moments"] ~= true then fail(scenario, "the fold the player left open is shut on My pet") end
		if now["who.myselfPetMoments"] ~= nil then fail(scenario, "the old key is kept once the fold moved") end
		-- A fold shut on purpose is not forced open by a stale key.
		now["pet.moments"] = false
		now["who.myselfPetMoments"] = true
		ns.RefreshOptionsDisplay()
		if UI.State().open["pet.moments"] ~= false then fail(scenario, "a fold shut on its new key was opened by the old one") end
	end)
end
