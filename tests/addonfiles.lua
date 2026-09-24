-- The addon's own Lua files, in the order the game loads them, read from
-- Manners.toc rather than written out by hand.
--
-- Each test loader used to carry its own copy of the list, and a file added to
-- the toc was loaded by the game and by none of the tests until somebody
-- remembered all three. embeds.xml is skipped: the libraries are stubbed by the
-- mocks. Any other .xml the toc names is expanded through its <Script file>
-- lines, relative to the folder it sits in.
--
--   local files = dofile(dir .. "/tests/addonfiles.lua")(dir)

return function(dir)
	local files = {}
	local toc = assert(io.open(dir .. "/Manners.toc", "r"))
	for raw in toc:lines() do
		local line = raw:gsub("\r$", ""):match("^%s*(.-)%s*$")
		if line ~= "" and not line:find("^#") then
			local path = line:gsub("\\", "/")
			if path:lower() == "embeds.xml" then
				-- The libraries: stubbed.
			elseif path:lower():find("%.xml$") then
				local folder = path:match("^(.*)/[^/]*$")
				local xml = assert(io.open(dir .. "/" .. path, "r"))
				local body = xml:read("*a")
				xml:close()
				for script in body:gmatch("<Script%s+file%s*=%s*\"([^\"]+)\"") do
					local file = script:gsub("\\", "/")
					files[#files + 1] = folder and (folder .. "/" .. file) or file
				end
			else
				files[#files + 1] = path
			end
		end
	end
	toc:close()
	return files
end
