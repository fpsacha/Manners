-- The Lua half of tools/audit_saved_boxes.py: load one tree of the addon on the
-- current mock as one client language, then either list the phrase box "In
-- character" would save for every people, side and class (mode "save"), or ask
-- whether each of the boxes it is handed still reads as the untouched set, and
-- what loading the profile would turn it into (mode "check").
--
-- Called as f(root, tree, locale, mode, input) where root is the tree holding
-- tests/mockapi.lua and tests/addonfiles.lua (this checkout), tree the addon to
-- load (a tag's, or this checkout), locale a client language, and input, for
-- "check", a list of { race, faction, class, box }. Returns a list of strings.

return function(root, tree, locale, mode, input, races, classes)
	dofile(root .. "/tests/mockapi.lua")
	local files = dofile(root .. "/tests/addonfiles.lua")(tree)
	Mock.reset()
	Mock.locale = locale ~= "enUS" and locale or nil
	local ns = {}
	for _, file in ipairs(files) do
		local chunk, err = loadfile(tree .. "/" .. file)
		if not chunk then return { "LOAD " .. file .. ": " .. tostring(err) } end
		local ok, runErr = pcall(chunk, "Manners", ns)
		if not ok then return { "RUN " .. file .. ": " .. tostring(runErr) } end
	end
	local RP = ns.InCharacter
	if not RP then return { "NO InCharacter" } end

	local function stand(race, faction, class)
		rawset(_G, "UnitRace", function(unit)
			if unit == "player" then return race, race, 1 end
		end)
		rawset(_G, "UnitFactionGroup", function(unit)
			if unit == "player" then return faction, faction end
		end)
		rawset(_G, "UnitClass", function(unit)
			if unit == "player" then return "X", class, 1 end
		end)
	end

	local out = {}
	local factions = { "Alliance", "Horde", "Neutral" }
	if mode == "save" then
		for _, race in ipairs(races) do
			for _, faction in ipairs(factions) do
				for _, class in ipairs(classes) do
					stand(race, faction, class)
					local ok, text = pcall(RP.Text)
					if not ok then
						out[#out + 1] = "ERR\t" .. race .. "\t" .. faction .. "\t" .. class .. "\t" .. tostring(text)
					else
						out[#out + 1] = race .. "\t" .. faction .. "\t" .. class .. "\t" .. (text:gsub("\\", "\\\\"):gsub("\n", "\\n"))
					end
				end
			end
		end
	else
		for _, item in ipairs(input) do
			local race, faction, class, box = item[1], item[2], item[3], item[4]
			stand(race, faction, class)
			local speech = { presetChoice = "incharacter", phrases = box }
			local ok, active = pcall(RP.Active, speech)
			if not ok then
				out[#out + 1] = "ERR\t" .. race .. "\t" .. faction .. "\t" .. class .. "\t" .. tostring(active)
			elseif not active then
				out[#out + 1] = "EDITED\t" .. race .. "\t" .. faction .. "\t" .. class
			else
				local ok2, err = pcall(RP.Repair, speech)
				local today = RP.Text()
				if not ok2 then
					out[#out + 1] = "ERR\t" .. race .. "\t" .. faction .. "\t" .. class .. "\trepair: " .. tostring(err)
				elseif not RP.Active(speech) then
					out[#out + 1] = "LOST\t" .. race .. "\t" .. faction .. "\t" .. class
				else
					out[#out + 1] = (speech.phrases == today and "OK" or "OK-OTHER") .. "\t" .. race .. "\t"
						.. faction .. "\t" .. class
				end
			end
		end
	end
	return out
end
