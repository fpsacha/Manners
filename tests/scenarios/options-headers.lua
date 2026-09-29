-- Every section heading on the options page has something under it.
--
-- A heading over nothing reads as a setting that failed to load: the Minimap
-- header once sat over a checkbox hidden on a client without LibDBIcon, and a
-- class with nothing to cast gets a Start here tab with most of it hidden. So
-- on every tab that is shown, a header that is shown needs at least one shown
-- control between it and the next header -- judged by what AceConfig would
-- draw, for a class with buffs, a class with none, and one whose buffs reach
-- only its group.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function shown(option)
	local hidden = option.hidden
	if type(hidden) == "function" then
		local ok, value = pcall(hidden, {})
		return not (ok and value)
	end
	return not hidden
end

local function text(value)
	if type(value) == "function" then
		local ok, out = pcall(value, {})
		return ok and tostring(out) or "?"
	end
	return tostring(value)
end

for _, class in ipairs({ "PRIEST", "ROGUE", "WARRIOR" }) do
	Mock.reset()
	Mock.class = class
	local scenario = "no header is drawn over nothing at all (" .. class .. ")"
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local options = ns.optionsTable
		if not (options and options.args) then
			fail(scenario, "SKIPPED -- no options table was built")
		else
			for tabKey, tab in pairs(options.args) do
				-- The profiles tab is AceDBOptions' own table.
				if tabKey ~= "profiles" and type(tab) == "table" and type(tab.args) == "table"
					and shown(tab) then
					local list = {}
					for key, option in pairs(tab.args) do
						if type(option) == "table" and type(option.order) == "number" then
							list[#list + 1] = { key = key, option = option }
						end
					end
					table.sort(list, function(a, b) return a.option.order < b.option.order end)
					for i, item in ipairs(list) do
						if item.option.type == "header" and shown(item.option) then
							local under = false
							for j = i + 1, #list do
								local next = list[j].option
								if next.type == "header" then break end
								if shown(next) then under = true break end
							end
							if not under then
								fail(scenario, ("the %s header on the %s tab is drawn over nothing at all")
									:format(text(item.option.name), tabKey))
							end
						end
					end
				end
			end
		end
	end
end
Mock.reset()
