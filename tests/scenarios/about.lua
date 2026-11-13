-- The line that says who makes Manners (Options/Diagnostics.lua, aboutNote):
-- on the Diagnostics page, naming the author's character, and asking for
-- nothing. Blizzard's add-on policy forbids an add-on to ask for donations in
-- the game, gold included, so the line is a credit in every language and no
-- word of it is a request.

local dir, H = ...
local fail, load = H.fail, H.load
local findOption = H.findOption

local KEY = "Manners is made by fpsacha, who plays %s on the RP-PvP server of WoW Forever."
-- Words a request for a tip would need, in the nine languages.
local ASKS = { "gold", "tip", "donat", "send", "mail", "pay", "gift", "trade", "spend", "spende", "schick", "oro", "propina",
	"envia", "envoy", "pourboire", "mancia", "invia", "ouro", "gorjeta", "\234\184\136", "\237\140\129", "\233\135\145",
	"\230\137\147\232\181\143", "\230\141\144" }

local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

do
	local scenario = "about: the Diagnostics page says who makes Manners, and asks for nothing"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			H.freshPrompt(ns, scenario)
			local note = findOption(ns.optionsTable, "aboutNote")
			if not note then fail(scenario, "the options have no aboutNote") return end
			local text = type(note.name) == "function" and note.name() or note.name
			if type(text) ~= "string" or not text:find("Mort Defrette", 1, true) then
				fail(scenario, "the line does not name the author's character: " .. tostring(text))
			end
			if ns.AUTHOR ~= "Mort Defrette" then fail(scenario, "ns.AUTHOR is " .. tostring(ns.AUTHOR)) end
			-- On the page, as its last line.
			local layout = slurp(dir .. "/Options/Window/Layout.lua") or ""
			if not layout:find('"diagnostics.aboutNote"', 1, true) then fail(scenario, "the line is not placed on the Diagnostics page") end
			-- A credit, never a request, in English and in every translation.
			local lines = { enUS = KEY }
			for _, code in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }) do
				local file = slurp(dir .. "/Locales/" .. code .. ".lua") or ""
				local at = file:find('L["' .. KEY .. '"] = "', 1, true)
				if not at then
					fail(scenario, code .. " does not translate the line")
				else
					lines[code] = file:sub(at + #KEY + 9, file:find("\n", at, true))
				end
			end
			for code, line in pairs(lines) do
				local lower = line:lower()
				for _, word in ipairs(ASKS) do
					if lower:find(word, 1, true) then
						fail(scenario, ("%s: the line reads as a request (%q): %s"):format(code, word, line))
					end
				end
				if not line:find("%s", 1, true) then fail(scenario, code .. ": the line has no place for the character's name") end
			end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end
