-- Bug hunt 34, the prompt's font default: the library's own for the client's
-- language (Core.lua defaults), so koKR, zhCN and zhTW, which register no
-- "Friz Quadrata TT", do not read "(not loaded)" on a fresh profile; the other
-- clients keep the default they had. Names start with "hunt34-font:".

local dir, H = ...
local fail, load = H.fail, H.load

local function session(scenario, locale, body, before)
	Mock.reset()
	Mock.locale = locale
	local lsm = LibStub("LibSharedMedia-3.0")
	local savedDefaults = lsm.DefaultMedia
	if before then before(lsm) end
	local ns = load(scenario)
	if ns then
		local ok, err = pcall(function()
			H.drive(scenario, ns)
			ns.Prompt:ExitTest()
			body(ns, lsm)
		end)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	lsm.DefaultMedia = savedDefaults
	Mock.reset()
end

local function label(ns, font)
	local option = H.findOption(ns.optionsTable, "font")
	local values = option and option.values
	if type(values) == "function" then values = values() end
	return type(values) == "table" and values[font] or nil
end

do
	local scenario = "hunt34-font: a Latin client keeps Friz Quadrata TT as the default"
	for _, locale in ipairs({ "enUS", "deDE", "frFR", "ruRU" }) do
		session(scenario, locale, function(ns)
			if ns.defaults.profile.prompt.font ~= "Friz Quadrata TT" then
				fail(scenario, locale .. " reads the default " .. tostring(ns.defaults.profile.prompt.font))
			end
		end)
	end
end

for _, locale in ipairs({ "koKR", "zhCN", "zhTW" }) do
	local scenario = "hunt34-font: " .. locale .. " defaults to the library's own font, and a font picked elsewhere is kept"
	session(scenario, locale, function(ns, lsm)
		local want = lsm.DefaultMedia.font
		if ns.db.profile.prompt.font ~= want or want == "Friz Quadrata TT" then
			fail(scenario, "the default font is " .. tostring(ns.db.profile.prompt.font) .. ", the library's " .. tostring(want))
		end
		-- Picked on a Latin client and carried here: a choice, kept as it stands,
		-- and honestly said not to be loaded.
		ns.db.profile.prompt.font = "Friz Quadrata TT"
		ns.ClampSettings()
		if ns.db.profile.prompt.font ~= "Friz Quadrata TT" then
			fail(scenario, "a font the player picked was rewritten to " .. tostring(ns.db.profile.prompt.font))
		end
		local said = label(ns, "Friz Quadrata TT")
		if type(said) ~= "string" or not said:find("Friz Quadrata TT", 1, true) or not said:find("|cff808080", 1, true) then
			fail(scenario, "a font nobody registered is labelled " .. tostring(said))
		end
	end)
end

do
	local scenario = "hunt34-font: a library with no default of its own leaves Friz Quadrata TT"
	session(scenario, "koKR", function(ns)
		if ns.defaults.profile.prompt.font ~= "Friz Quadrata TT" then
			fail(scenario, "the default font is " .. tostring(ns.defaults.profile.prompt.font))
		end
	end, function(lsm) lsm.DefaultMedia = nil end)
end
