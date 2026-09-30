-- The options table as AceConfigRegistry-3.0 judges it.
--
-- The mock's AceConfig takes any table, and the real one does not: the first
-- time the page opens, AceConfigRegistry:ValidateOptionsTable walks every
-- option and refuses a key it does not know or a value of the wrong type. 1.1.2
-- to 1.4.0 sized buttons with a function in `width`, which AceConfigDialog
-- itself would have read, and the validator stopped the whole page opening
-- ("Manners.args.profiles.args.shareCopy.width: expected a string or number,
-- got 'function: ...'", a player's report). Nothing here could see it.
--
-- So the validator's rules are written out below, as Ace3's
-- AceConfigRegistry-3.0.lua (r1296, BSD licence) has them -- the key types, the
-- per-type keys and the walk -- and the table the addon registers is run
-- through them: in English and German, for a class with buffs to give and for
-- ones with only their own or nothing, and again after the page has been
-- opened, since opening measures the controls afresh.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local isstring = { ["string"] = true, _ = "string" }
local isstringfunc = { ["string"] = true, ["function"] = true, _ = "string or funcref" }
local istable = { ["table"] = true, _ = "table" }
local ismethodtable = { ["table"] = true, ["string"] = true, ["function"] = true, _ = "methodname, funcref or table" }
local optstring = { ["nil"] = true, ["string"] = true, _ = "string" }
local optstringfunc = { ["nil"] = true, ["string"] = true, ["function"] = true, _ = "string or funcref" }
local optstringnumberfunc = { ["nil"] = true, ["string"] = true, ["number"] = true, ["function"] = true,
	_ = "string, number or funcref" }
local optnumber = { ["nil"] = true, ["number"] = true, _ = "number" }
local optmethodfalse = { ["nil"] = true, ["string"] = true, ["function"] = true, ["boolean"] = { [false] = true },
	_ = "methodname, funcref or false" }
local optmethodnumber = { ["nil"] = true, ["string"] = true, ["function"] = true, ["number"] = true,
	_ = "methodname, funcref or number" }
local optmethodtable = { ["nil"] = true, ["string"] = true, ["function"] = true, ["table"] = true,
	_ = "methodname, funcref or table" }
local optmethodbool = { ["nil"] = true, ["string"] = true, ["function"] = true, ["boolean"] = true,
	_ = "methodname, funcref or boolean" }
local opttable = { ["nil"] = true, ["table"] = true, _ = "table" }
local optbool = { ["nil"] = true, ["boolean"] = true, _ = "boolean" }
local optboolnumber = { ["nil"] = true, ["boolean"] = true, ["number"] = true, _ = "boolean or number" }
local optstringnumber = { ["nil"] = true, ["string"] = true, ["number"] = true, _ = "string or number" }

local basekeys = {
	type = isstring, name = isstringfunc, desc = optstringfunc, descStyle = optstring,
	order = optmethodnumber, validate = optmethodfalse, confirm = optmethodbool,
	confirmText = optstring, disabled = optmethodbool, hidden = optmethodbool,
	guiHidden = optmethodbool, dialogHidden = optmethodbool, dropdownHidden = optmethodbool,
	cmdHidden = optmethodbool, tooltipHyperlink = optstringfunc, icon = optstringnumberfunc,
	iconCoords = optmethodtable, handler = opttable, get = optmethodfalse, set = optmethodfalse,
	func = optmethodfalse, arg = { ["*"] = true }, width = optstringnumber, relWidth = optnumber,
}

local controls = { control = optstring, dialogControl = optstring, dropdownControl = optstring }
local function with(extra)
	local t = {}
	for k, v in pairs(controls) do t[k] = v end
	for k, v in pairs(extra or {}) do t[k] = v end
	return t
end

local typedkeys = {
	header = with(),
	description = with({ image = optstringnumberfunc, imageCoords = optmethodtable, imageHeight = optnumber,
		imageWidth = optnumber, fontSize = optstringfunc }),
	group = { args = istable, plugins = opttable, inline = optbool, cmdInline = optbool, guiInline = optbool,
		dropdownInline = optbool, dialogInline = optbool, childGroups = optstring },
	execute = with({ image = optstringnumberfunc, imageCoords = optmethodtable, imageHeight = optnumber,
		imageWidth = optnumber }),
	input = with({ pattern = optstring, usage = optstring, multiline = optboolnumber }),
	toggle = with({ tristate = optbool, image = optstringnumberfunc, imageCoords = optmethodtable }),
	tristate = {},
	range = with({ min = optnumber, softMin = optnumber, max = optnumber, softMax = optnumber, step = optnumber,
		bigStep = optnumber, isPercent = optbool }),
	select = with({ values = ismethodtable, sorting = optmethodtable, itemControl = optstring,
		style = { ["nil"] = true, ["string"] = { dropdown = true, radio = true }, _ = "string: 'dropdown' or 'radio'" } }),
	multiselect = with({ values = ismethodtable, style = optstring, tristate = optbool }),
	color = with({ hasAlpha = optmethodbool }),
	keybinding = with(),
}

-- The first complaint, as the registry words it, or nil when the table passes.
local function problem(options, path)
	if type(options) ~= "table" then return path .. ": expected a table, got a " .. type(options) end
	if type(options.type) ~= "string" then return path .. ".type: expected a string" end
	local tk = typedkeys[options.type]
	if not tk then return path .. ".type: unknown type '" .. options.type .. "'" end
	for k in pairs(options) do
		if not (tk[k] or basekeys[k]) then return path .. "." .. tostring(k) .. ": unknown parameter" end
	end
	local function check(k, oktypes)
		local v = options[k]
		local ok = oktypes[type(v)] or oktypes["*"]
		if not ok then
			return path .. "." .. k .. ": expected a " .. oktypes._ .. ", got '" .. tostring(v) .. "'"
		end
		if type(ok) == "table" and not ok[v] then
			return path .. "." .. k .. ": did not expect " .. type(v) .. " value '" .. tostring(v) .. "'"
		end
	end
	for k, oktypes in pairs(basekeys) do
		local bad = check(k, oktypes)
		if bad then return bad end
	end
	for k, oktypes in pairs(tk) do
		local bad = check(k, oktypes)
		if bad then return bad end
	end
	if options.type == "group" then
		for k, v in pairs(options.args) do
			if type(k) ~= "string" then return path .. ".args[" .. tostring(k) .. "] - key is not a string" end
			local bad = problem(v, path .. ".args." .. k)
			if bad then return bad end
		end
	end
	return nil
end

for _, case in ipairs({
	{ "enUS", "MAGE" }, { "deDE", "MAGE" }, { "enUS", "HUNTER" }, { "enUS", "WARRIOR" }, { "enUS", "ROGUE" },
}) do
	local locale, class = case[1], case[2]
	local scenario = ("aceconfig: the options table passes AceConfigRegistry's validation (%s, %s)")
		:format(locale, class)
	Mock.reset()
	Mock.locale, Mock.class = locale, class
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		if type(ns.optionsTable) ~= "table" then
			fail(scenario, "SKIPPED -- no options table was registered")
		else
			local bad = problem(ns.optionsTable, "Manners")
			if bad then fail(scenario, bad) end
			-- Opening the page measures the controls again.
			if ns.OpenOptions then pcall(ns.OpenOptions) end
			bad = problem(ns.optionsTable, "Manners")
			if bad then fail(scenario, "after opening the page: " .. bad) end
		end
	end
	Mock.locale, Mock.class = nil, nil
end
