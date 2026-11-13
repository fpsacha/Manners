-- The line that says who makes Manners (Options/Diagnostics.lua, aboutNote):
-- in the options window's footer under the build, on every page, naming the
-- author's character, and asking for nothing. Blizzard's add-on policy forbids an add-on to ask for donations in
-- the game, gold included, so the line is a credit in every language and no
-- word of it is a request.

local dir, H = ...
local fail, load = H.fail, H.load
local findOption = H.findOption

local KEY = "Manners is made by %s, who plays on the RP-PvP server of WoW Forever."
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
	local scenario = "about: the window's footer says who makes Manners, and asks for nothing"
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
			-- In the window's footer, under the build, whatever page is open, in
			-- one line that fits between the footer's buttons.
			for _, page in ipairs({ "general", "appearance", "diagnostics" }) do
				ns.OpenOptions(page)
				local UI = ns.WindowUI
				local foot = UI and UI.footer
				local shown = foot and foot.about and foot.about:IsShown() and foot.about:GetText()
				if type(shown) ~= "string" or not shown:find("Mort Defrette", 1, true) then
					fail(scenario, ("on %s the footer does not say who makes Manners: %s"):format(page, tostring(shown)))
				elseif not (foot.build:GetText() or ""):find(tostring(ns.BUILD), 1, true) then
					fail(scenario, "the footer lost the build: " .. tostring(foot.build:GetText()))
				else
					local _, size = foot.about:GetFont()
					local wide = UI.TextWidth(foot.about, size)
					if wide > UI.FooterRoom() + 0.5 then
						fail(scenario, ("the line is %.0f wide in a footer with %.0f of room"):format(wide, UI.FooterRoom()))
					end
					-- Both hang off the middle of the room between the buttons, the
					-- build above it and the line below.
					local bp = foot.build.points[#foot.build.points]
					local brel, by = bp[2], bp[5]
					local ap = foot.about.points[#foot.about.points]
					local arel, ay = ap[2], ap[5]
					if brel ~= foot.mid or arel ~= foot.mid or not (by and ay and by > 0 and ay < 0) then
						fail(scenario, ("the line is not under the build: %s %s"):format(tostring(by), tostring(ay)))
					end
				end
			end
			-- A language that needs more than the room is set smaller, never cut
			-- short: the same line with a name four times as long.
			do
				local UI = ns.WindowUI
				local author = ns.AUTHOR
				ns.AUTHOR = ("Mort Defrette "):rep(4)
				UI.PaintFooter()
				local _, size = UI.footer.about:GetFont()
				local wide = UI.TextWidth(UI.footer.about, size)
				if wide > UI.FooterRoom() + 0.5 then
					fail(scenario, ("a long line is %.0f wide in a footer with %.0f of room"):format(wide, UI.FooterRoom()))
				end
				if not (UI.footer.about:GetText() or ""):find("Forever", 1, true) then fail(scenario, "a long line lost its end") end
				ns.AUTHOR = author
				UI.PaintFooter()
				local _, back = UI.footer.about:GetFont()
				if back and size and not (back > size) then fail(scenario, ("the line stayed small once it fitted again: %s then %s"):format(tostring(size), tostring(back))) end
			end
			if ns.OptionsWindow then ns.OptionsWindow:Hide() end
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
				-- The character alone: the author asked for the account's name out of it.
				if lower:find("fpsacha", 1, true) then fail(scenario, code .. ": the line names the account as well as the character") end
			end
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end
