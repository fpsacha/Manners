-- The Lua half of tools/settings_audit.py: every control of the options model
-- is driven the way the window drives it, and what it offers is checked against
-- what the addon keeps. Run by settings_audit.py; shares the environment of
-- tools/migration_check.lua (the mock with the real AceDB). Not shipped.
--
-- For each control that has a value (toggle, range, select, multiselect, colour,
-- input), and each value it can take:
--
--   set      the control's own set; its get must then read the value back
--            (a range: the nearest step)
--   repair   ns.ClampSettings, which runs at every login and profile change,
--            must leave the value alone: what a control offers is what stays
--   share    the profile exported, reset, imported again must read the same
--            on the control, apart from what a string never carries
--   reload   all controls at once at a value other than the default, the
--            profile logged out through AceDB (defaults stripped) and the
--            addon loaded again on the file: every control the same, and the
--            repair log empty
--
-- Findings are returned as { kind, control, detail }.

local M = dofile(MIG.repo .. "/tools/migration_check.lua")

local copy, diff = M.copy, M.diff

local A = {}
local ns_root -- the model's root, for a control that inherits its get or set from it

-- What a pasted string deliberately never carries (Commands.lua, SHARE_SKIP and
-- the SHARE_KEEP_MINE pair), and what the load-time repair stamps into every
-- profile.
local NOT_SHARED = {
	["enabled"] = true, ["verbose"] = true, ["debugClicks"] = true,
	["prompt.locked"] = true, ["prompt.point"] = true, ["prompt.relPoint"] = true,
	["prompt.x"] = true, ["prompt.y"] = true,
	["speech.enabled"] = true, ["prompt.thankEmote"] = true,
}
local function notShared(path)
	if NOT_SHARED[path] then return true end
	if path:match("^never") or path:match("^minimap") then return true end
	if path:match("^prompt%.anchorCarried") or path:match("^prompt%.offsetsUnscaled") then return true end
	if path == "firstRun" then return true end
	return false
end

local function replace(dst, src)
	for k in pairs(dst) do dst[k] = nil end
	for k, v in pairs(src) do dst[k] = copy(v) end
end

local function show(v)
	if type(v) == "table" then
		local t = {}
		for k, x in pairs(v) do t[#t + 1] = tostring(k) .. "=" .. tostring(x) end
		table.sort(t)
		return "{" .. table.concat(t, ",") .. "}"
	end
	if type(v) == "string" and #v > 50 then return ("%q"):format(v:sub(1, 47) .. "...") end
	if type(v) == "string" then return ("%q"):format(v) end
	return tostring(v)
end

local function near(a, b)
	if type(a) == "number" and type(b) == "number" then return math.abs(a - b) < 1e-6 end
	if type(a) == "table" and type(b) == "table" then
		for i = 1, 4 do if not near(a[i], b[i]) then return false end end
		return true
	end
	return a == b
end

---------------------------------------------------------------------------
-- a control
---------------------------------------------------------------------------

local function member(item, name)
	local def = item.def
	local v = def[name]
	if v == nil then v = item.group[name] end
	if v == nil and ns_root then v = ns_root[name] end
	return v
end

local function ask(item, m, ...)
	if type(m) == "function" then return m(item.info, ...) end
	if type(m) == "string" then
		local h = item.info.handler
		return h[m](h, item.info, ...)
	end
	return m
end

local function get(item)
	local g = member(item, "get")
	if g == nil or g == false then return nil end
	if item.def.type == "color" then return ask(item, g) end
	return (ask(item, g))
end

local function getColour(item)
	local g = member(item, "get")
	local r, gr, b, a = ask(item, g)
	return { r, gr, b, a }
end

local function set(item, ...)
	local s = member(item, "set")
	if s == nil or s == false then return false end
	ask(item, s, ...)
	return true
end

local function number(item, field)
	local v = item.def[field]
	if type(v) == "function" then v = v(item.info) end
	return v
end

-- The values worth trying on a control.
local function candidates(item)
	local def = item.def
	local t = def.type
	local out = {}
	if t == "toggle" then
		out = { true, false }
	elseif t == "range" then
		local lo, hi, step = number(item, "min"), number(item, "max"), number(item, "step") or 0
		if type(lo) ~= "number" or type(hi) ~= "number" then return out end
		local function snap(v)
			if step > 0 then v = lo + math.floor((v - lo) / step + 0.5) * step end
			return math.max(lo, math.min(hi, v))
		end
		local seen = {}
		for _, v in ipairs({ lo, hi, snap((lo + hi) / 2), snap(lo + (step > 0 and step or (hi - lo) / 10)),
			snap(hi - (step > 0 and step or (hi - lo) / 10)), snap(lo + (hi - lo) * 0.3) }) do
			local key = ("%.6f"):format(v)
			-- To the six places a slider's step is at most, so the value is the
			-- one a slider would give and not a float that is 0.7 only on screen.
			if not seen[key] then seen[key] = true out[#out + 1] = tonumber(key) end
		end
	elseif t == "select" then
		local ok, values = pcall(ask, item, def.values)
		if ok and type(values) == "table" then
			local keys = {}
			for key in pairs(values) do keys[#keys + 1] = key end
			table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
			out = keys
		end
	elseif t == "color" then
		out = { { 0.2, 0.4, 0.6, 0.8 }, { 0, 0, 0, 0 }, { 1, 1, 1, 1 }, { 0.5, 0.25, 0.75, 1 } }
	elseif t == "input" then
		out = { "abc", "Ünïcode 日本語 ok", "{name} !", ("x"):rep(120), "a|cffff0000b|r", "line one\nline two", "" }
	end
	return out
end

-- Everything in the model that holds a value.
local function controls(ns)
	local list = {}
	local B = ns.WindowBind
	local tabs = {}
	for tab in pairs(ns.optionsTable.args) do tabs[#tabs + 1] = tab end
	table.sort(tabs)
	for _, tab in ipairs(tabs) do
		local keys = {}
		for key in pairs(ns.optionsTable.args[tab].args or {}) do keys[#keys + 1] = key end
		table.sort(keys)
		for _, key in ipairs(keys) do
			local def = ns.optionsTable.args[tab].args[key]
			local t = def.type
			-- The Profiles tab's controls switch, copy and delete profiles, and the
			-- Diagnostics tab's boxes only show text.
			local audited = tab ~= "profiles" and tab ~= "diagnostics"
			if audited and (t == "toggle" or t == "range" or t == "select" or t == "color" or t == "input") then
				local item = B.Item(tab .. "." .. key, nil, nil)
				if item then
					local g = item.def.get
					if g == nil then g = item.group.get end
					if g == nil then g = ns.optionsTable.get end
					if g ~= nil and g ~= false then list[#list + 1] = item end
				end
			end
		end
	end
	return list
end
A.controls = controls

---------------------------------------------------------------------------
-- the audit
---------------------------------------------------------------------------

local function start(ns)
	for _, step in ipairs({ "OnInitialize", "OnEnable", "PLAYER_ENTERING_WORLD" }) do
		local ok, err = pcall(function() ns.addon[step](ns.addon) end)
		if not ok then error("lifecycle " .. step .. ": " .. tostring(err), 0) end
	end
	Mock.printed = {}
end

local function guardedSince(ns, n)
	local out = {}
	for i = n + 1, #(ns.errors or {}) do
		out[#out + 1] = tostring(ns.errors[i].where) .. " -> " .. tostring(ns.errors[i].err)
	end
	return out
end

function A.run()
	M.env()
	local findings = {}
	local function finding(kind, control, detail)
		findings[#findings + 1] = { kind = kind, control = control, detail = detail }
	end
	local ns, why = M.load(MIG.repo)
	if not ns then return { { kind = "load", control = "-", detail = why } }, {} end
	start(ns)
	-- Everything that asks the player a question is answered yes.
	local db = ns.db
	local profile = db.profile
	local base = copy(profile)
	ns_root = ns.optionsTable

	local items = controls(ns)
	local report = { controls = #items, values = 0 }
	local plan = {} -- path -> a non-default value, for the reload

	for _, item in ipairs(items) do
		local def, t = item.def, item.def.type
		local path = item.path
		local before = copy(profile)
		local startDefault = t == "color" and getColour(item) or get(item)
		for _, v in ipairs(candidates(item)) do
			replace(profile, before)
			local errs = #(ns.errors or {})
			local ok, err
			if t == "color" then
				ok, err = pcall(set, item, v[1], v[2], v[3], v[4])
			else
				-- A refused value (validate) is not offered.
				local validate = member(item, "validate")
				local accepted = true
				if validate ~= nil and validate ~= false then
					local vok, said = pcall(ask, item, validate, v)
					if not vok or said ~= true then accepted = false end
				end
				if accepted then ok, err = pcall(set, item, v) else ok = nil end
			end
			if ok == false then
				finding("set threw", path, show(v) .. ": " .. tostring(err))
			elseif ok then
				report.values = report.values + 1
				for _, e in ipairs(guardedSince(ns, errs)) do finding("guarded", path, show(v) .. ": " .. e) end
				local after = t == "color" and getColour(item) or get(item)
				local want = v
				-- A box that adds to a list (the never-offer list's) reads empty
				-- whatever it was given: it is an action, not a setting.
				local action = t == "input" and startDefault == "" and after == ""
				-- 1. the control reads back what it was given
				if not action and not near(after, want) then
					finding("readback", path, "set " .. show(v) .. ", the control reads " .. show(after))
				end
				-- 2. the repair leaves it alone
				local snapshot = copy(profile)
				local log = #ns.repairLog
				local cok, cerr = pcall(ns.ClampSettings)
				if not cok then
					finding("clamp threw", path, show(v) .. ": " .. tostring(cerr))
				else
					local clamped = t == "color" and getColour(item) or get(item)
					if not near(clamped, after) then
						finding("repair", path, "set " .. show(v) .. " (reads " .. show(after) .. "), after the load-time repair "
							.. show(clamped))
					end
					local moved = diff(snapshot, profile)
					for _, line in ipairs(moved) do
						if not line:find("^firstRun") then
							finding("repair side", path, "set " .. show(v) .. ": the repair also changed " .. line)
						end
					end
				end
				-- 3. a string made of it comes back
				local exportOk, text = pcall(ns.ExportSettings)
				if exportOk and type(text) == "string" then
					local p1 = copy(profile)
					local rok = pcall(function() db:ResetProfile() end)
					if rok then
						local iok, applied, said = pcall(ns.ImportSettings, text)
						if not iok then
							finding("import threw", path, show(v) .. ": " .. tostring(applied))
						elseif not applied then
							finding("import refused", path, show(v) .. ": " .. tostring(said))
						else
							for _, line in ipairs(diff(p1, db.profile)) do
								local p = line:match("^(.-):")
								if p and not notShared(p) then
									finding("share", path, "set " .. show(v) .. ": " .. line)
								end
							end
						end
					end
				else
					finding("export threw", path, show(v) .. ": " .. tostring(text))
				end
			end
			replace(db.profile, before)
		end
		-- a value other than the default for the reload
		for _, v in ipairs(candidates(item)) do
			replace(profile, before)
			local ok
			if t == "color" then ok = pcall(set, item, v[1], v[2], v[3], v[4]) else ok = pcall(set, item, v) end
			local now = ok and (t == "color" and getColour(item) or get(item))
			if ok and not near(now, startDefault) and not (t == "input" and v == "") then
				plan[path] = { value = v, tab = item.tab }
				break
			end
		end
		replace(profile, before)
	end

	-- All of them at once, then the file.
	replace(profile, base)
	local order = {}
	for _, item in ipairs(items) do if plan[item.path] then order[#order + 1] = item end end
	for _, item in ipairs(order) do
		local v = plan[item.path].value
		if item.def.type == "color" then pcall(set, item, v[1], v[2], v[3], v[4]) else pcall(set, item, v) end
	end
	pcall(ns.ClampSettings)
	local expected = {}
	for _, item in ipairs(order) do
		expected[item.path] = item.def.type == "color" and getColour(item) or get(item)
	end
	local savedProfile = copy(profile)
	local lok, lerr = pcall(M.logout)
	if not lok then
		finding("logout", "-", tostring(lerr))
		return findings, report
	end

	-- The addon again, on what the logout left.
	local ns2, why2 = M.load(MIG.repo)
	if not ns2 then
		finding("reload", "-", tostring(why2))
		return findings, report
	end
	local ok2, err2 = pcall(start, ns2)
	if not ok2 then finding("reload", "-", tostring(err2)) return findings, report end
	ns_root = ns2.optionsTable
	local repairs = ns2.repairLog or {}
	for _, line in ipairs(repairs) do finding("reload repair", "-", line) end
	for _, line in ipairs(guardedSince(ns2, 0)) do finding("reload guarded", "-", line) end
	local again = {}
	for _, item in ipairs(controls(ns2)) do again[item.path] = item end
	for _, item in ipairs(order) do
		local fresh = again[item.path]
		if not fresh then
			finding("reload", item.path, "the control is gone after a reload")
		else
			local got = fresh.def.type == "color" and getColour(fresh) or get(fresh)
			if not near(got, expected[item.path]) then
				finding("reload", item.path, "was " .. show(expected[item.path]) .. " at logout, " .. show(got) .. " after a reload")
			end
		end
	end
	local d = diff(savedProfile, ns2.db.profile)
	for _, line in ipairs(d) do
		if not line:find("^firstRun") then finding("reload profile", "-", line) end
	end
	return findings, report
end

---------------------------------------------------------------------------
-- a change made while playing against the same change made before logging in
---------------------------------------------------------------------------

-- Everything a control's setter has to reach: the macro on the button, who the
-- queue holds and why, and the words on the prompt.
local function observe(ns)
	local out = {}
	local button = ns.Prompt:GetButton()
	local lines = {}
	for line in tostring(button:GetAttribute("macrotext1")):gmatch("[^\n]+") do
		local command = line:match("^/(%a+)")
		if command == "say" or command == "yell" or command == "party" or command == "raid"
			or command == "emote" or command == "w" then
			line = "/" .. command .. " <line>"
		end
		lines[#lines + 1] = line
	end
	out.macro = table.concat(lines, " | ")
	local q = {}
	for _, e in ipairs(ns.BuildQueue()) do
		q[#q + 1] = tostring(e.name) .. ":" .. tostring(e.reason) .. ":" .. tostring(e.buff and e.buff.key)
	end
	out.queue = table.concat(q, ", ")
	FrameTree.settle()
	local texts = {}
	for _, r in ipairs(FrameTree.all) do
		if r._kind == "FontString" and type(r._text) == "string" and r._text ~= "" and FrameTree.visible(r) then
			texts[#texts + 1] = r._text
		end
	end
	table.sort(texts)
	out.texts = table.concat(texts, " / ")
	return out
end

-- A session: the mock fresh, the addon loaded on whatever MannersDB holds,
-- started, and the same two people about (a stranger on a nameplate and one
-- owed a favour) for as long as every session has the same.
local function session()
	FrameTree.uninstall()
	FrameTree.install()
	Mock.reset()
	Mock.class = MIG.class or "PRIEST"
	if MIG.locale then Mock.locale = MIG.locale end
	IsSpellKnown = function() return true end
	IsPlayerSpell = IsSpellKnown
	local ns, why = M.load(MIG.repo)
	if not ns then error("load: " .. tostring(why), 0) end
	start(ns)
	ns_root = ns.optionsTable
	Mock.unitNames = { nameplate1 = { "Anna", "Aim" } }
	local party = {}
	if MIG.world == "party" then
		-- The four others of a party of five, as the group scenarios make one.
		Mock.groupSize = 5
		Mock.unitNames.party1, Mock.unitNames.party2 = { "Gwen", "Hale" }, { "Bram", "Oake" }
		Mock.unitNames.party3, Mock.unitNames.party4 = { "Cora", "Vell" }, { "Dain", "Moor" }
		party = { party1 = true, party2 = true, party3 = true, party4 = true }
	end
	UnitExists = function(unit) return unit == "player" or unit == "nameplate1" or party[unit] == true end
	ns.nameplateUnits["nameplate1"] = true
	Mock.advance(60)
	for k in pairs(ns.owed) do ns.owed[k] = nil end
	for k in pairs(ns.tried) do ns.tried[k] = nil end
	-- Owed to somebody with no token, or in the speech world to the one on the
	-- nameplate: a line goes out only to a person a token names.
	local debtor = MIG.world == "speech" and "Anna Aim" or "Dunmore"
	ns.owed[debtor] = { expires = GetTime() + 100, at = GetTime(), class = "PRIEST" }
	ns.Guard("probe", ns.ProbeCapabilities)
	pcall(ns.StopSnooze, true)
	ns.addon:Tick()
	return ns
end

-- Long enough for the prompt's hold on whoever it was showing (hysteresis,
-- Prompt/Hold.lua) to let go, and the same for both sides.
local function settle(ns)
	for _ = 1, 6 do
		Mock.advance(1.5)
		ns.addon:Tick()
	end
end

-- What a world switches on before the control under test is touched: the
-- "speech" world has the character saying a line with every cast.
local function base(ns)
	if MIG.world == "speech" then
		local sp = ns.db.profile.speech
		sp.enabled, sp.onlyWhenReturning, sp.channel = true, false, "SAY"
		ns.Prompt:InvalidateMacro()
	end
end

function A.effects()
	M.env()
	dofile(MIG.repo .. "/tests/frametree.lua")
	local findings = {}
	local function finding(kind, control, detail) findings[#findings + 1] = { kind = kind, control = control, detail = detail } end
	local report = { values = 0 }
	_G.MannersDB = nil
	local ns = session()
	local paths = {}
	for _, item in ipairs(controls(ns)) do paths[#paths + 1] = item.path end
	local plain = observe(ns)
	for index, path in ipairs(paths) do
		local item
		for _, candidate in ipairs(controls(ns)) do if candidate.path == path then item = candidate end end
		local t = item.def.type
		local values = candidates(item)
		-- Free text goes into names and phrases the same way whatever it says.
		if t == "input" then values = { values[1], values[3] } end
		for _, v in ipairs(values) do
			-- The player's side: the setting changed while playing.
			_G.MannersDB = nil
			ns = session()
			ns_root = ns.optionsTable
			item = nil
			for _, candidate in ipairs(controls(ns)) do if candidate.path == path then item = candidate end end
			local ok, err
			base(ns)
			if t == "color" then ok, err = pcall(set, item, v[1], v[2], v[3], v[4]) else ok, err = pcall(set, item, v) end
			if ok then
				local errs = #(ns.errors or {})
				settle(ns)
				local live = observe(ns)
				local made = copy(ns.db.profile)
				report.values = report.values + 1
				-- The same setting, found in the file at login.
				pcall(M.logout)
				local ns2 = session()
				ns_root = ns2.optionsTable
				settle(ns2)
				local fresh = observe(ns2)
				for _, field in ipairs({ "macro", "queue", "texts" }) do
					if live[field] ~= fresh[field] then
						finding("stale " .. field, path, "set " .. show(v) .. " while playing: " .. show(live[field])
							.. "; found at login: " .. show(fresh[field]))
					end
				end
				for _, line in ipairs(guardedSince(ns, errs)) do finding("guarded", path, show(v) .. ": " .. line) end
			end
		end
	end
	return findings, report
end

---------------------------------------------------------------------------
-- a settings string from one client into another
---------------------------------------------------------------------------

-- Every control at a value other than its default, the string that makes of
-- the profile, and what each control then reads.
function A.maximal()
	M.env()
	local ns, why = M.load(MIG.repo)
	if not ns then return nil, why end
	start(ns)
	ns_root = ns.optionsTable
	local out = { expected = {}, notes = {} }
	for _, item in ipairs(controls(ns)) do
		local t = item.def.type
		local fresh = t == "color" and getColour(item) or get(item)
		local list = candidates(item)
		for i = #list, 1, -1 do
			local v = list[i]
			if not (t == "input" and v == "") then
				local ok
				if t == "color" then ok = pcall(set, item, v[1], v[2], v[3], v[4]) else ok = pcall(set, item, v) end
				local now = ok and (t == "color" and getColour(item) or get(item))
				if ok and not near(now, fresh) then break end
			end
		end
	end
	pcall(ns.ClampSettings)
	for _, item in ipairs(controls(ns)) do
		out.expected[item.path] = item.def.type == "color" and getColour(item) or get(item)
	end
	out.text = ns.ExportSettings()
	out.flavour = ns.Flavour and ns.Flavour.flavour
	out.profile = copy(ns.db.profile)
	return out
end

-- The string into a fresh profile here: it must be taken, and every control
-- that is shared must read what it did there (a value this client cannot have
-- may differ, and is reported as such by the caller's own comparison).
function A.imported(text, expected, was)
	M.env()
	local ns, why = M.load(MIG.repo)
	if not ns then return { { kind = "load", control = "-", detail = why } } end
	start(ns)
	ns_root = ns.optionsTable
	local findings = {}
	local function finding(kind, control, detail) findings[#findings + 1] = { kind = kind, control = control, detail = detail } end
	local ok, applied, said = pcall(ns.ImportSettings, text)
	if not ok then finding("import threw", "-", tostring(applied)) return findings end
	if not applied then finding("import refused", "-", tostring(said)) return findings end
	report = said
	for _, e in ipairs(guardedSince(ns, 0)) do finding("guarded", "-", e) end
	for _, line in ipairs(ns.repairLog or {}) do finding("repaired", "-", line) end
	-- The profile there against the profile here: what a string does not carry
	-- on purpose is left out, and so is what this client has no data for.
	if type(was) == "table" then
		for _, line in ipairs(diff(was, ns.db.profile)) do
			local path = line:match("^(.-):")
			local pin = path == "buff.choice" and was.buff and was.buff.choice
			-- A pin on a buff no class has on this client goes back to Automatic.
			if pin and not ns.AnyClassHasBuff(pin) then path = nil end
			if path and not notShared(path) and not path:match("^ownBuffs%.pick%.") then
				finding("profile", path, line)
			end
		end
	end
	local seen = {}
	for _, item in ipairs(controls(ns)) do seen[item.path] = true end
	for path in pairs(expected) do
		if not seen[path] then finding("no control", path, "this client has no such control") end
	end
	finding("said", "-", tostring(said))
	return findings
end

-- What the first session of a world shows, for a look at the world itself.
function A.peek()
	M.env()
	dofile(MIG.repo .. "/tests/frametree.lua")
	_G.MannersDB = nil
	local ns = session()
	base(ns)
	settle(ns)
	return observe(ns)
end

return A
