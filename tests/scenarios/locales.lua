-- Every language the addon is translated into, loaded and driven.
--
-- tests/validate.py checks each translation's shape against the English: the
-- same format specifiers, {tokens} and escapes, in order. This runs the addon in
-- each language the way a player on that client meets it -- loaded, driven
-- through its lifecycle, every command the help lists, every closure on the
-- options page, a favour on the prompt and its tooltip. A translation that
-- throws does so only in its own language, which nobody testing in English
-- ever sees; here it fails by name.
--
-- The list of languages is read from Locales/Locales.xml, so a language added
-- there is covered without touching this file.

local dir, H = ...
local fail, load, drive, walkOptions = H.fail, H.load, H.drive, H.walkOptions

local function localeFiles()
	local f = io.open(dir .. "/Locales/Locales.xml", "r")
	if not f then return {} end
	local body = f:read("*a")
	f:close()
	local codes = {}
	for code in body:gmatch("<Script%s+file%s*=%s*\"(%a%a%a%a)%.lua\"") do
		-- Init.lua is four letters too; it is the table, not a language.
		if code ~= "Init" then codes[#codes + 1] = code end
	end
	return codes
end

-- A file that answers for more than one client locale is run as each of them.
local ANSWERS = { esES = { "esES", "esMX" } }

for _, file in ipairs(localeFiles()) do
	for _, code in ipairs(ANSWERS[file] or { file }) do
		local scenario = "the addon in " .. code
		Mock.reset()
		Mock.locale = code
		local restoreUnits = H.strangers({ nameplate1 = { "Anna", "Aim" } })
		local ns = load(scenario)
		if ns then
			-- The file really applied on this client: something comes back
			-- other than its English key. A guard naming the wrong locale leaves
			-- the whole language silently English.
			local translated = 0
			for key, value in pairs(ns.L) do
				if value ~= key then translated = translated + 1 end
			end
			if translated == 0 then
				fail(scenario, "Locales/" .. file .. ".lua loaded but translated nothing on a "
					.. code .. " client")
			end

			drive(scenario, ns)
			H.owe(ns, "Anna Aim")
			ns.addon:Tick()
			ns.Prompt:Refresh()
			local button = ns.Prompt:GetButton()
			if button and button.scripts and button.scripts.OnEnter then
				local ok, err = pcall(button.scripts.OnEnter, button)
				if not ok then fail(scenario, "the prompt's tooltip threw: " .. tostring(err)) end
			end

			-- Every command the help advertises, the help itself, and a word
			-- that is nearly a command. Each prints sentences built from
			-- translated format strings.
			local words = { "help", "snoze", "" }
			for _, command in ipairs(ns.COMMANDS or {}) do words[#words + 1] = command.word end
			for _, word in ipairs(words) do
				local ok, err = pcall(ns.addon.HandleSlash, ns.addon, word)
				if not ok then
					fail(scenario, ("/manners %s threw: %s"):format(word, tostring(err)))
				end
			end

			local options = ns.optionsTable
			if type(options) == "table" and type(options.args) == "table" then
				for key, group in pairs(options.args) do
					if key ~= "profiles" then walkOptions(scenario, group, key) end
				end
			else
				fail(scenario, "no options table was built")
			end

			-- Guard catches what a command or a handler throws and files it
			-- rather than letting it through to pcall above, so the error log
			-- is where a broken translation actually shows up.
			if (ns.errorCount or 0) > 0 then
				local first = ns.errors and ns.errors[1]
				fail(scenario, ("%d error(s) while running in %s, the first in %s: %s"):format(
					ns.errorCount, code, tostring(first and first.where), tostring(first and first.err)))
			end
		end
		restoreUnits()
		Mock.locale = nil
	end
end
Mock.reset()
