-- The four looks retired in 1.11.19 -- Framed, Luxe, Arcane, Toast -- and what
-- becomes of a profile that still names one.
--
-- The author asked for every look to be its own, and for the ones too like a
-- neighbour to go. Their files, their art and Framed's drawing in
-- Prompt/Panel.lua are gone. What is left is a key somebody's SavedVariables
-- may still hold (Looks/Looks.lua, Looks.retired) and the move ClampSettings
-- makes for it (Core.lua). What these hold the addon to:
--
--   * a profile saved with a retired key logs in wearing that look's heir --
--     framed and luxe on Glass, arcane on Archmage, toast on Ribbon -- and so
--     does one still holding "blizzard", the name Framed had before 1.0;
--   * the player is told, once, in one line that names the look that went and
--     the look they now wear, in the client's language; not at the next login,
--     and never on a profile that held a look still here;
--   * a settings string from somebody else that names a retired look ends on
--     its heir as well;
--   * the picker's cards and the fallback dialog's dropdown offer exactly the
--     ten looks there are, in the same order;
--   * Looks.Allowed() refuses the four keys, and Looks.Choices() offers none
--     of them, whatever registers under one;
--   * nothing of the four still ships: no file the toc names, no texture
--     folder, no generator.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every name
-- starts with "looks-retired:" so a mutation can name exactly one.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local savedProfile, findOption = H.savedProfile, H.findOption

-- The saved key, the look it ends on, and the two names the line says.
local MOVES = {
	{ key = "framed", heir = "glass", was = "Framed", now = "Glass" },
	{ key = "luxe", heir = "glass", was = "Luxe", now = "Glass" },
	{ key = "arcane", heir = "archmage", was = "Arcane", now = "Archmage" },
	{ key = "toast", heir = "ribbon", was = "Toast", now = "Ribbon" },
	-- The name Framed had before 1.0: carried to Framed, and on with it.
	{ key = "blizzard", heir = "glass", was = "Framed", now = "Glass" },
}
local RETIRED = { "framed", "luxe", "arcane", "toast" }
-- The looks that remain, in the order the picker and the dropdown show them.
local REMAIN = { "ribbon", "letter", "leather", "forge", "archmage", "lightbringer", "fel", "wild", "glass", "minimal" }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- The lines in chat that are about a retired look, in any language: the
-- addon's own string, read from the locale the session loaded.
local function retiredLines(ns)
	local lead = tostring(ns.L["The look %s has been retired, so your prompt now wears %s. The other looks are on the Look page."])
	-- What the sentence starts with, up to its first name.
	local head = lead:match("^(.-)%%s") or lead
	local out = {}
	for _, line in ipairs(Mock.printed) do
		if head ~= "" and tostring(line):find(head, 1, true) then out[#out + 1] = tostring(line) end
	end
	return out
end

-- A session that logs in on a profile saved with `style`, the first six
-- seconds of it played. `locale`: the client's language. `body(ns)`.
local function loggedIn(scenario, style, locale, body)
	Mock.reset()
	Mock.sv = {}
	if locale then Mock.locale = locale end
	local ok, err = pcall(function()
		local saved = savedProfile(scenario, function(profile)
			profile.prompt = profile.prompt or {}
			profile.prompt.style = style
		end)
		if locale then Mock.locale = locale end
		local ns = saved and load(scenario)
		if not ns then return end
		Mock.printed = {}
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		Mock.runTimers(7)
		body(ns)
		noErrors(scenario, ns)
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 1
-- Each retired key, and the older "blizzard", ends on its heir, drawn.
for _, move in ipairs(MOVES) do
	local scenario = ("looks-retired: a profile saved with %s logs in wearing %s"):format(move.key, move.heir)
	loggedIn(scenario, move.key, nil, function(ns)
		local p = ns.db.profile.prompt
		if p.style ~= move.heir then
			fail(scenario, ("the saved style %s became %s, not its heir %s"):format(move.key, tostring(p.style), move.heir))
			return
		end
		-- And the heir is what the prompt draws: the look from Looks/, or for
		-- Glass the pane Prompt/Panel.lua lays.
		ns.Prompt:ApplyStyle()
		local r = ns.Prompt:Regions()
		if move.heir == "glass" then
			if r.look ~= nil or not (r.pane and r.pane[5] and r.pane[5]:IsShown()) then
				fail(scenario, "the prompt is not drawn as Glass: no pane, or a look from Looks/ in its place")
			end
		elseif r.look == nil or r.look ~= ns.Looks.Get(move.heir) then
			fail(scenario, "the prompt is not drawn by " .. move.heir)
		end
	end)
end

-- ------------------------------------------------------------------ 2
-- Told once, naming both looks.
for _, move in ipairs(MOVES) do
	local scenario = ("looks-retired: a player who wore %s is told once, by both names"):format(move.key)
	loggedIn(scenario, move.key, nil, function(ns)
		local lines = retiredLines(ns)
		if #lines ~= 1 then
			fail(scenario, ("%d line(s) in chat about the retired look, not one: %s"):format(#lines,
				table.concat(Mock.printed, " / ")))
			return
		end
		if not lines[1]:find(move.was, 1, true) then
			fail(scenario, "the line does not name the look that went (" .. move.was .. "): " .. lines[1])
		end
		if not lines[1]:find(move.now, 1, true) then
			fail(scenario, "the line does not name the look now worn (" .. move.now .. "): " .. lines[1])
		end
		-- The repair runs again at every profile change and import: nothing
		-- more is said, the style being the heir's by then.
		Mock.printed = {}
		ns.ClampSettings()
		ns.ClampSettings()
		Mock.runTimers(7)
		if #retiredLines(ns) ~= 0 then
			fail(scenario, "the line was said again by a later repair: " .. table.concat(Mock.printed, " / "))
		end
	end)
end

-- Not six seconds early: the line waits for the screen, as the comment in
-- ClampSettings says, so the login's own lines come first.
do
	local scenario = "looks-retired: the line waits until the screen is up"
	Mock.reset()
	Mock.sv = {}
	local ok, err = pcall(function()
		local saved = savedProfile(scenario, function(profile)
			profile.prompt = profile.prompt or {}
			profile.prompt.style = "toast"
		end)
		local ns = saved and load(scenario)
		if not ns then return end
		Mock.printed = {}
		ns.addon:OnInitialize()
		if #retiredLines(ns) ~= 0 then
			fail(scenario, "the line is said during the load, before the screen is up")
		end
		Mock.runTimers(5)
		if #retiredLines(ns) ~= 0 then fail(scenario, "the line is said under six seconds in") end
		Mock.runTimers(1.5)
		if #retiredLines(ns) ~= 1 then
			fail(scenario, ("%d line(s) six seconds in, not one"):format(#retiredLines(ns)))
		end
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- And at the next login nothing is said: the profile holds the heir.
do
	local scenario = "looks-retired: nothing is said at the login after"
	Mock.reset()
	Mock.sv = {}
	local ok, err = pcall(function()
		local saved = savedProfile(scenario, function(profile)
			profile.prompt = profile.prompt or {}
			profile.prompt.style = "arcane"
		end)
		local first = saved and load(scenario)
		if not first then return end
		drive(scenario, first)
		Mock.runTimers(7)
		if first.db.profile.prompt.style ~= "archmage" then
			fail(scenario, "SKIPPED -- the first login did not move the style: " .. tostring(first.db.profile.prompt.style))
			return
		end
		-- The second session, on what the first left in the saved variables.
		Mock.timers = {}
		local second = load(scenario)
		if not second then return end
		Mock.printed = {}
		drive(scenario, second)
		Mock.runTimers(7)
		if second.db.profile.prompt.style ~= "archmage" then
			fail(scenario, "the second login wears " .. tostring(second.db.profile.prompt.style) .. ", not Archmage")
		end
		if #retiredLines(second) ~= 0 then
			fail(scenario, "the retired look is announced again at the next login: " .. table.concat(Mock.printed, " / "))
		end
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 3
-- A profile that never wore one hears nothing, whatever it wears.
for _, style in ipairs(REMAIN) do
	local scenario = "looks-retired: a profile on " .. style .. " keeps it and is told nothing"
	loggedIn(scenario, style, nil, function(ns)
		if ns.db.profile.prompt.style ~= style then
			fail(scenario, "a look that remains was changed to " .. tostring(ns.db.profile.prompt.style))
		end
		local lines = retiredLines(ns)
		if #lines ~= 0 then fail(scenario, "told of a retired look it never wore: " .. lines[1]) end
	end)
end

-- A style no look ever had is the default's, as before, and nothing is said
-- of a retirement: it is not one.
do
	local scenario = "looks-retired: a style no look ever had becomes the default without the line"
	loggedIn(scenario, "whisper", nil, function(ns)
		if ns.db.profile.prompt.style ~= ns.defaults.profile.prompt.style then
			fail(scenario, "an unknown style became " .. tostring(ns.db.profile.prompt.style))
		end
		if #retiredLines(ns) ~= 0 then fail(scenario, "an unknown style is announced as a retired look") end
	end)
end

-- ------------------------------------------------------------------ 4
-- In the client's language, with the names the cards wear there.
do
	local scenario = "looks-retired: a German client is told in German"
	loggedIn(scenario, "toast", "deDE", function(ns)
		local english = "The look %s has been retired, so your prompt now wears %s. The other looks are on the Look page."
		if rawget(ns.L, english) == nil or ns.L[english] == english then
			fail(scenario, "the German translation has no line for a retired look: it would be said in English")
			return
		end
		local lines = retiredLines(ns)
		if #lines ~= 1 then
			fail(scenario, ("%d German line(s), not one: %s"):format(#lines, table.concat(Mock.printed, " / ")))
			return
		end
		if lines[1]:find("has been retired", 1, true) then fail(scenario, "the line is in English: " .. lines[1]) end
		local was, now = ns.Looks.Card("toast"), ns.Looks.Card("ribbon")
		if not (lines[1]:find(was, 1, true) and lines[1]:find(now, 1, true)) then
			fail(scenario, ("the line does not name %s and %s: %s"):format(tostring(was), tostring(now), lines[1]))
		end
	end)
end

-- ------------------------------------------------------------------ 5
-- A string from somebody still on a retired look: its heir, and the line.
do
	local scenario = "looks-retired: an imported string naming a retired look ends on its heir"
	loggedIn(scenario, "letter", nil, function(ns)
		local p = ns.db.profile.prompt
		-- The string a build that had the look wrote: this build writes it
		-- the same way, the style held for the moment of the export.
		p.style = "luxe"
		local text = ns.ExportSettings()
		p.style = "letter"
		ns.ClampSettings()
		if type(text) ~= "string" or not text:find("prompt.style=luxe", 1, true) then
			fail(scenario, "SKIPPED -- the export did not write the style: " .. tostring(text))
			return
		end
		Mock.printed = {}
		local ok, message = ns.ImportSettings(text)
		if not ok then
			fail(scenario, "a string naming a retired look was refused: " .. tostring(message))
			return
		end
		if p.style ~= "glass" then fail(scenario, "the imported luxe became " .. tostring(p.style) .. ", not Glass") end
		Mock.runTimers(7)
		if #retiredLines(ns) ~= 1 then
			fail(scenario, ("%d line(s) about the retired look after the import, not one"):format(#retiredLines(ns)))
		end
	end)
end

-- ------------------------------------------------------------------ 6
-- The registry: the four are no look, no choice and no style to save.
do
	local scenario = "looks-retired: Looks.Allowed() refuses the retired keys and keeps the rest"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		local allowed = ns.Looks.Allowed()
		for _, key in ipairs(RETIRED) do
			if allowed[key] then fail(scenario, key .. " may still be saved as a style") end
			if ns.Looks.Heir(key) == nil then fail(scenario, key .. " has no heir") end
		end
		local count = 0
		for _ in pairs(allowed) do count = count + 1 end
		for _, key in ipairs(REMAIN) do
			if not allowed[key] then fail(scenario, key .. " may not be saved as a style") end
			if ns.Looks.Heir(key) ~= nil then fail(scenario, key .. " is in use and has an heir: " .. tostring(ns.Looks.Heir(key))) end
		end
		if count ~= #REMAIN then fail(scenario, ("%d styles may be saved, not %d"):format(count, #REMAIN)) end
		-- Every heir is a look that is here, and no heir is itself retired.
		for key, heir in pairs(ns.Looks.retired) do
			if not allowed[heir] then fail(scenario, ("%s's heir %s is not a look in use"):format(key, tostring(heir))) end
		end
		-- Whatever registers under a retired key (an old file left in the
		-- folder by a hand install) is still no style to save or to pick.
		for _, key in ipairs(RETIRED) do
			ns.Looks.Register(key, { name = key .. " -- back from the dead", order = 1, fallback = "glass" })
		end
		allowed = ns.Looks.Allowed()
		local values, sorting = ns.Looks.Choices()
		for _, key in ipairs(RETIRED) do
			if allowed[key] then fail(scenario, key .. ", registered again, may be saved as a style") end
			if values[key] ~= nil then fail(scenario, key .. ", registered again, is offered as a choice") end
			for _, listed in ipairs(sorting) do
				if listed == key then fail(scenario, key .. ", registered again, is in the dropdown's order") end
			end
			ns.Looks.list[key] = nil
		end
	end
	Mock.reset()
end

do
	local scenario = "looks-retired: a retired look keeps its name for the line, and nothing else"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		for _, move in ipairs(MOVES) do
			if move.key ~= "blizzard" then
				local title, line = ns.Looks.Card(move.key)
				if title ~= move.was then
					fail(scenario, ("the retired %s is called %s, not %s"):format(move.key, tostring(title), move.was))
				end
				if line ~= "" then fail(scenario, move.key .. " still has a card's line: " .. tostring(line)) end
				if ns.Looks.list[move.key] ~= nil then fail(scenario, move.key .. " is still in the registry") end
				if ns.Looks.Get(move.key) ~= nil then fail(scenario, move.key .. " still hands back a look to draw") end
				if ns.Looks.PreviewFile(move.key) ~= nil then fail(scenario, move.key .. " still has a picture") end
			end
		end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ 7
-- The picker's cards and the fallback dialog's dropdown: exactly the looks
-- that remain, in one order.
do
	local scenario = "looks-retired: the picker and the dropdown offer exactly the looks that remain"
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		-- The dropdown: the model's control, which the fallback dialog draws.
		local option = findOption(ns.optionsTable, "style")
		local values = option and (type(option.values) == "function" and option.values() or option.values)
		local sorting = option and (type(option.sorting) == "function" and option.sorting() or option.sorting)
		if type(values) ~= "table" or type(sorting) ~= "table" then
			fail(scenario, "SKIPPED -- the model has no style dropdown to read")
			return
		end
		if #sorting ~= #REMAIN then
			fail(scenario, ("the dropdown lists %d looks, not %d: %s"):format(#sorting, #REMAIN, table.concat(sorting, ", ")))
		end
		for i, key in ipairs(REMAIN) do
			if sorting[i] ~= key then
				fail(scenario, ("the dropdown's place %d is %s, not %s"):format(i, tostring(sorting[i]), key))
			end
			if type(values[key]) ~= "string" or values[key] == "" then fail(scenario, "the dropdown has no label for " .. key) end
		end
		local offered = 0
		for key in pairs(values) do
			offered = offered + 1
			if ns.Looks.retired[key] then fail(scenario, "the dropdown offers the retired " .. key) end
		end
		if offered ~= #REMAIN then fail(scenario, ("the dropdown offers %d looks, not %d"):format(offered, #REMAIN)) end
		-- The cards.
		ns.OpenOptions("appearance", true)
		ns.Prompt:ExitTest()
		local UI = ns.WindowUI
		local row = UI and UI.RowFor("appearance.style")
		if not (row and row.cards and UI.RowShown("appearance.style")) then
			fail(scenario, "SKIPPED -- the gallery is not on the Look page")
			return
		end
		local shown = {}
		for i = 1, #row.cards do
			if row.cards[i]:IsShown() then shown[#shown + 1] = row.cards[i] end
		end
		if #shown ~= #REMAIN then
			fail(scenario, ("the picker shows %d cards, not %d"):format(#shown, #REMAIN))
		end
		for i, key in ipairs(REMAIN) do
			local card = shown[i]
			if not card or card.key ~= key then
				fail(scenario, ("the picker's card %d is %s, not %s"):format(i, tostring(card and card.key), key))
			elseif not ns.Looks.PreviewFile(key) then
				fail(scenario, "the card for " .. key .. " has no picture")
			end
		end
		for _, card in ipairs(shown) do
			if ns.Looks.retired[card.key] then fail(scenario, "the picker shows a card for the retired " .. tostring(card.key)) end
		end
		noErrors(scenario, ns)
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 8
-- Nothing of the four ships: no file in the toc, no art, no generator, no
-- picture, and Framed's rim is not among the panel's files.
do
	local scenario = "looks-retired: nothing of the four still ships"
	Mock.reset()
	local function exists(path)
		local f = io.open(dir .. "/" .. path, "rb")
		if f then f:close() end
		return f ~= nil
	end
	local function slurp(path)
		local f = io.open(dir .. "/" .. path, "rb")
		if not f then return "" end
		local text = f:read("*a")
		f:close()
		return text
	end
	for _, name in ipairs({ "Luxe", "Toast", "Arcane" }) do
		for _, file in ipairs(ADDON_FILES) do
			if file:find("Looks/" .. name .. ".lua", 1, true) or file:find("Looks\\" .. name .. ".lua", 1, true) then
				fail(scenario, "the toc still loads " .. file)
			end
		end
		if exists("Looks/" .. name .. ".lua") then fail(scenario, "Looks/" .. name .. ".lua is still in the tree") end
		if exists("tools/make_" .. name:lower() .. "_textures.py") then
			fail(scenario, "tools/make_" .. name:lower() .. "_textures.py is still in the tree")
		end
	end
	for _, toc in ipairs({ "Manners.toc", "Manners_Camelot.toc", "Manners_Vanilla.toc", "Manners_TBC.toc",
		"Manners_Mists.toc", "Manners_Mainline.toc" }) do
		local text = slurp(toc)
		for _, name in ipairs({ "Luxe", "Toast", "Arcane" }) do
			if text:find("Looks\\" .. name .. ".lua", 1, true) then fail(scenario, toc .. " still lists Looks\\" .. name .. ".lua") end
		end
	end
	for _, key in ipairs(RETIRED) do
		if exists("Textures/Previews/Preview_" .. key .. ".tga") then
			fail(scenario, "Textures/Previews/Preview_" .. key .. ".tga still ships")
		end
	end
	if exists("Textures/TooltipRim.tga") then fail(scenario, "Textures/TooltipRim.tga, Framed's rim, still ships") end
	for _, file in ipairs({ "Textures/Luxe/Luxe_Spine.tga", "Textures/Toast/Toast_Gold.tga", "Textures/Arcane/Arcane_IconRing.tga" }) do
		if exists(file) then fail(scenario, file .. " still ships") end
	end
	-- No shipped Lua file names a texture of theirs.
	for _, file in ipairs(ADDON_FILES) do
		local text = slurp(file)
		for _, folder in ipairs({ "Textures\\\\Luxe", "Textures\\\\Toast", "Textures\\\\Arcane\\\\", "TooltipRim" }) do
			if text:find(folder, 1, true) then fail(scenario, file .. " still names " .. folder) end
		end
	end
	Mock.reset()
end
