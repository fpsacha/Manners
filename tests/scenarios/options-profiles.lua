-- The Profiles tab (Options/Profiles.lua, BuildProfilesTab): AceDBOptions'
-- own table, a line above it on what a profile is for, and the Share as text
-- section under it -- the box to copy your settings from and the box to paste
-- some in.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption, optionText = H.findOption, H.optionText

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function session(scenario)
	Mock.reset()
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	return ns
end

-- The profiles tab's own controls, or nil with the failure said.
local function profilesTab(scenario, ns)
	local options = ns.optionsTable
	local tab = options and options.args and options.args.profiles
	if type(tab) ~= "table" or type(tab.args) ~= "table" then
		fail(scenario, "there is no Profiles tab on the options page")
		return nil
	end
	return tab
end

local SHARE = { "shareHeader", "shareNote", "shareCopy", "shareText", "sharePaste" }

-- ------------------------------------------------------------------ the tab
do
	local scenario = "profiles: the tab is last and says what a profile is for"
	local ns = session(scenario)
	local tab = ns and profilesTab(scenario, ns)
	if tab then
		if tab.order ~= 90 then
			fail(scenario, "the Profiles tab has order " .. tostring(tab.order) .. ", not 90")
		end
		for key, other in pairs(ns.optionsTable.args) do
			if key ~= "profiles" and type(other) == "table" and type(other.order) == "number"
				and other.order >= (tab.order or 0) then
				fail(scenario, "the " .. key .. " tab comes after Profiles")
			end
		end

		local intro = tab.args.profilesIntro
		if not intro then
			fail(scenario, "the Profiles tab has no line saying what a profile is for")
		else
			if intro.type ~= "description" then
				fail(scenario, "the profiles intro is a " .. tostring(intro.type) .. ", not a description")
			end
			-- The library's own paragraph is its `desc`, at order 1: the
			-- line in the player's words goes above it.
			if not (type(intro.order) == "number" and intro.order < 1) then
				fail(scenario, "the profiles intro sits below the library's own paragraph (order "
					.. tostring(intro.order) .. ")")
			end
			local text = optionText(intro.name)
			for _, want in ipairs({ "Default profile", "per character" }) do
				if not tostring(text):find(want, 1, true) then
					fail(scenario, "the profiles intro does not say " .. want .. ": " .. tostring(text))
				end
			end
			-- Share as text is a section of the same page in the options
			-- window, so the intro points nowhere.
			if tostring(text):find("Share as text", 1, true) then
				fail(scenario, "the profiles intro points at Share as text on its own page: " .. tostring(text))
			end
		end
		-- The library's paragraph says the same thing, so the tab would open
		-- with it twice.
		local libDesc = tab.args.desc
		if libDesc and libDesc.hidden ~= true then
			fail(scenario, "the library's own paragraph repeats the profiles intro")
		end
		noErrors(scenario, ns)
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ the section
do
	local scenario = "profiles: Share as text lives on this tab, in order, under the library's controls"
	local ns = session(scenario)
	local tab = ns and profilesTab(scenario, ns)
	if tab then
		local last = 0
		for _, key in ipairs(SHARE) do
			local option = tab.args[key]
			if not option then
				fail(scenario, key .. " is not on the Profiles tab")
			else
				if not (type(option.order) == "number" and option.order >= 100) then
					fail(scenario, key .. " has order " .. tostring(option.order)
						.. ", among the library's own controls rather than after them")
				elseif option.order <= last then
					fail(scenario, key .. " is out of order in Share as text (" .. tostring(option.order) .. ")")
				end
				last = type(option.order) == "number" and option.order or last
			end
		end
		-- And nowhere else: one place to look.
		for key, other in pairs(ns.optionsTable.args) do
			if key ~= "profiles" then
				for _, share in ipairs(SHARE) do
					if findOption(other, share) then
						fail(scenario, share .. " is on the " .. key .. " tab as well")
					end
				end
			end
		end
		local header = tab.args.shareHeader
		if header and optionText(header.name) ~= "Share as text" then
			fail(scenario, "the share header reads " .. tostring(optionText(header.name))
				.. " -- the chat lines send the player to Share as text")
		end
		local note = tab.args.shareNote
		local text = note and tostring(optionText(note.name)) or ""
		for _, want in ipairs({ "paste text someone gave you", "minimap button",
			"never turns on Say a line" }) do
			if not text:find(want, 1, true) then
				fail(scenario, "the share note does not say " .. want .. ": " .. text)
			end
		end
		noErrors(scenario, ns)
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ copy
do
	local scenario = "profiles: the copy button shows and hides the box of settings"
	local ns = session(scenario)
	local tab = ns and profilesTab(scenario, ns)
	if tab then
		local button, box = tab.args.shareCopy, tab.args.shareText
		if button and box then
			if not box.hidden() then
				fail(scenario, "the box of settings is open before anybody asked for it")
			end
			if optionText(button.name) ~= "Show my settings as text" then
				fail(scenario, "the copy button reads " .. tostring(optionText(button.name))
					.. " while the box is shut")
			end
			if not tostring(optionText(button.desc)):find("/manners export", 1, true) then
				fail(scenario, "the copy button does not mention /manners export: "
					.. tostring(optionText(button.desc)))
			end
			button.func()
			if box.hidden() then
				fail(scenario, "Show my settings as text left the box shut")
			end
			if optionText(button.name) ~= "Hide the text" then
				fail(scenario, "the copy button reads " .. tostring(optionText(button.name))
					.. " while the box is open")
			end
			if box.get() ~= ns.ExportSettings() or box.get() == "" then
				fail(scenario, "the open box does not hold this profile's settings")
			end
			-- Typing into it changes nothing.
			local before = ns.ExportSettings()
			box.set(nil, "junk")
			if ns.ExportSettings() ~= before then
				fail(scenario, "typing into the box of settings changed them")
			end
			button.func()
			if not box.hidden() then
				fail(scenario, "Hide the text left the box open")
			end
		end
		noErrors(scenario, ns)
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ paste
do
	local scenario = "profiles: a paste says to press Accept, applies, and can be undone"
	local ns = session(scenario)
	local tab = ns and profilesTab(scenario, ns)
	local paste = tab and tab.args.sharePaste
	if paste then
		if not tostring(optionText(paste.name)):find("Accept", 1, true) then
			fail(scenario, "the paste box does not say to press Accept: " .. tostring(optionText(paste.name)))
		end
		if not tostring(optionText(paste.desc)):find("/manners import undo", 1, true) then
			fail(scenario, "the paste box does not say how to undo: " .. tostring(optionText(paste.desc)))
		end
		if paste.get() ~= "" then
			fail(scenario, "the paste box is not empty: " .. tostring(paste.get()))
		end

		local p = ns.db.profile
		local mine = ns.ExportSettings()
		local width = p.prompt.width
		local other = (width == 300) and 320 or 300
		p.prompt.width = other
		local theirs = ns.ExportSettings()
		p.prompt.width = width

		if paste.validate({ "sharePaste" }, "hello") == true then
			fail(scenario, "the paste box accepted text that is not settings")
		end
		if paste.validate({ "sharePaste" }, theirs) ~= true then
			fail(scenario, "the paste box refused settings Manners wrote itself")
		end
		paste.set({ "sharePaste" }, theirs)
		if p.prompt.width ~= other then
			fail(scenario, "pasting settings did not apply them (width " .. tostring(p.prompt.width) .. ")")
		end
		ns.addon:HandleSlash("import undo")
		if ns.ExportSettings() ~= mine then
			fail(scenario, "/manners import undo did not put the settings back after a paste")
		end
		noErrors(scenario, ns)
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ /manners export
do
	local scenario = "profiles: /manners export opens this tab with the box showing"
	local ns = session(scenario)
	local tab = ns and profilesTab(scenario, ns)
	if tab then
		ns.addon:HandleSlash("export")
		local selected = ns.OptionsOpen() and ns.OptionsTab() or nil
		if selected ~= "profiles" then
			fail(scenario, "/manners export opened the options on " .. tostring(selected)
				.. ", not the Profiles tab")
		end
		if tab.args.shareText and tab.args.shareText.hidden() then
			fail(scenario, "/manners export left the box of settings shut")
		end
		noErrors(scenario, ns)
	end
	Mock.reset()
end
