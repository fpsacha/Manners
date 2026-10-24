-- Bug hunt 33, settings: the profile, its share string, its reset lists.
-- Every scenario name starts with "hunt33-settings:".

local dir, H = ...
local fail, load = H.fail, H.load

local function session(scenario, class, flavour)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	Mock.class = class or "PALADIN"
	local ns = load(scenario)
	if not ns then return nil end
	H.drive(scenario, ns)
	ns.Prompt:ExitTest()
	return ns
end

-- A paladin's own Buff order (Who to buff, 1.8.3) is a profile setting like the
-- rest, saved in profile.buff.order. Its default is an empty table, which the
-- share string walks into and finds nothing, so the order is neither written
-- into /manners export, nor put back to Automatic by /manners import (which
-- says everything the string does not name goes back to its default), nor
-- brought back by /manners import undo.
do
	local scenario = "hunt33-settings: the buff order travels in a settings string"
	local ns = session(scenario, "PALADIN")
	if ns then
		-- Put Might ahead of Wisdom.
		local moved = ns.MoveBuff("might", -1)
		local order = ns.BuffOrder()
		if not moved or not order then
			fail(scenario, "SKIPPED -- the order could not be set: " .. tostring(moved))
		else
			local mine = table.concat(order, ",")
			local text = ns.ExportSettings()
			-- Another player's profile: Automatic.
			ns.ClearBuffOrder()
			local ok, said = ns.ImportSettings(text)
			if not ok then fail(scenario, "the player's own export did not import: " .. tostring(said)) end
			local after = ns.BuffOrder()
			if not after or table.concat(after, ",") ~= mine then
				fail(scenario, "the buff order " .. mine .. " was exported and imported as "
					.. tostring(after and table.concat(after, ",") or "Automatic"))
			end
			-- And the other way: a string that carries none is a profile on Automatic.
			ns.MoveBuff("might", -1)
			local plain = ns.ExportSettings()
			local keep = ns.BuffOrder()
			if keep then
				ns.ClearBuffOrder()
				local bare = ns.ExportSettings()
				ns.MoveBuff("might", -1)
				ns.ImportSettings(bare)
				if ns.BuffOrder() then
					fail(scenario, "importing a string with no buff order left the player's own order in place; the import says everything it does not name goes back to its default")
				end
			end
			local _ = plain
		end
	end
end

-- ------------------------------------------------------------------ font
-- LibSharedMedia registers "Friz Quadrata TT" on every client but koKR, zhCN
-- and zhTW (its own table: those clients have no Latin face under that name),
-- and the prompt's font default is that name everywhere (Core.lua defaults).
-- The prompt itself falls back to the library's default font for an unknown
-- key, so it draws; but the Look page's Font list does not know the key and
-- labels the player's own, untouched default "(not loaded)".
for _, locale in ipairs({ "koKR", "zhCN", "zhTW" }) do
	local scenario = "hunt33-settings: " .. locale .. ": a fresh profile's font is not 'not loaded'"
	Mock.reset()
	Mock.locale = locale
	-- The mock's library holds no Friz Quadrata TT, as the shipped one on these clients.
	local ns = load(scenario)
	if ns then
		H.drive(scenario, ns)
		ns.Prompt:ExitTest()
		local option = H.findOption(ns.optionsTable, "font")
		local values = option and option.values
		if type(values) == "function" then values = values() end
		local label = type(values) == "table" and values[ns.db.profile.prompt.font]
		if type(label) ~= "string" then
			fail(scenario, "the Font list has no entry for the font the profile holds: " .. tostring(ns.db.profile.prompt.font))
		elseif label:find("not loaded", 1, true) or label:find("|cff808080", 1, true) then
			fail(scenario, "the player's untouched default font reads \"" .. label:gsub("[\128-\255]", "?")
				.. "\" on the Look page")
		end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ language
-- The phrase box is filled at load in the client's language and kept in the
-- profile. A player who changes the game's language later keeps a box in the old
-- one: the repair only knows an English set (ns.EnglishPhraseSet), so a set
-- written in German reads as the player's own lines on an English client.
do
	local scenario = "hunt33-settings: a phrase set saved in German follows the client into English"
	Mock.reset()
	Mock.locale = "deDE"
	local ns = load(scenario)
	if ns then
		H.drive(scenario, ns)
		local german = ns.db.profile.speech.phrases
		local file = Mock.sv
		Mock.reset()
		Mock.sv = file
		Mock.locale = "enUS"
		local again = load(scenario)
		if again then
			H.drive(scenario, again)
			local box = again.db.profile.speech.phrases
			if box == german and german ~= again.PhraseSetText("roleplay") then
				fail(scenario, "the unedited Roleplay set saved by a German client is still German on an English client")
			end
		end
	end
	Mock.reset()
end
