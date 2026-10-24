-- Bug hunt 34, the buff order in a settings string. A buff order the player
-- set, per class, travels in /manners export as buff.order=CLASS=key:key:key
-- (the classes joined by commas), is read back by an import, put back to
-- Automatic by an import whose string has none, and restored by the undo.
-- Names start with "hunt34-order:".

local dir, H = ...
local fail, load = H.fail, H.load

local function signed(body)
	local head = "MNR1:" .. body
	local h = 0
	for i = 1, #head do h = (h * 31 + head:byte(i)) % 16777213 end
	return head .. ":" .. ("%06x"):format(h)
end

local function session(scenario, class, body)
	Mock.reset()
	Mock.class = class or "PRIEST"
	local ns = load(scenario)
	if ns then
		H.drive(scenario, ns)
		ns.Prompt:ExitTest()
		local ok, err = pcall(body, ns)
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end
	Mock.reset()
end

local function orders(ns)
	local out = {}
	for class, keys in pairs(ns.db.profile.buff.order) do out[#out + 1] = class .. "=" .. table.concat(keys, ":") end
	table.sort(out)
	return table.concat(out, ",")
end

do
	local scenario = "hunt34-order: the order of every class travels in a settings string"
	session(scenario, "PRIEST", function(ns)
		ns.db.profile.buff.order = { PRIEST = { "spirit", "fortitude", "shadow" },
			PALADIN = { "kings", "might", "wisdom", "salvation", "light" } }
		ns.ClampSettings()
		local mine = orders(ns)
		local text = ns.ExportSettings()
		if not text:find("buff.order=PALADIN=kings:might:wisdom:salvation:light,PRIEST=spirit:fortitude:shadow", 1, true) then
			fail(scenario, "the export does not carry the orders as CLASS=key:key: " .. text)
		end
		ns.db.profile.buff.order = {}
		local applied, said = ns.ImportSettings(text)
		if not applied then
			fail(scenario, "the player's own export did not import: " .. tostring(said))
		elseif orders(ns) ~= mine then
			fail(scenario, "the orders " .. mine .. " came back as " .. orders(ns))
		end
	end)
end

do
	local scenario = "hunt34-order: an import with no order puts Automatic back, and the undo brings the order back"
	session(scenario, "PRIEST", function(ns)
		ns.db.profile.buff.order = { PRIEST = { "shadow", "fortitude", "spirit" } }
		ns.ClampSettings()
		local mine = orders(ns)
		local applied = ns.ImportSettings(signed("prompt.width=240"))
		if not applied then fail(scenario, "SKIPPED -- the string was refused") return end
		if ns.BuffOrder() then fail(scenario, "the order stayed after a string that names none: " .. orders(ns)) end
		local undone = ns.UndoImport()
		if not undone then
			fail(scenario, "SKIPPED -- nothing to undo")
		elseif orders(ns) ~= mine then
			fail(scenario, "the undo left the orders as '" .. orders(ns) .. "', not " .. mine)
		end
	end)
end

do
	local scenario = "hunt34-order: a damaged order is refused whole and an unknown buff is dropped"
	session(scenario, "PRIEST", function(ns)
		ns.db.profile.buff.order = { PRIEST = { "shadow", "fortitude", "spirit" } }
		ns.ClampSettings()
		local mine = orders(ns)
		for _, body in ipairs({
			"buff.order=priest=fortitude",
			"buff.order=PRIEST=",
			"buff.order=PRIEST=spirit:",
			"buff.order=PRIEST=spirit,PRIEST=fortitude",
			"buff.order=PRIEST=fort%20itude",
			"buff.order=PRIEST",
		}) do
			local applied = ns.ImportSettings(signed(body))
			if applied then fail(scenario, "a damaged order was imported: " .. body) end
			if orders(ns) ~= mine then fail(scenario, "a refused string changed the orders (" .. body .. ")") end
		end
		-- Read, before anything is applied: the unknown buff is already gone, as
		-- the login's repair would take it.
		local parsed = ns.ParseSettings(signed("buff.order=PRIEST=nonsense:spirit"))
		local read = parsed and parsed.values["buff.order"] and parsed.values["buff.order"].PRIEST
		if not read or read[1] ~= "spirit" or table.concat(read, ":"):find("nonsense", 1, true) then
			fail(scenario, "the string read as " .. (read and table.concat(read, ":") or "nothing"))
		end
		local applied = ns.ImportSettings(signed("buff.order=PRIEST=nonsense:spirit"))
		local list = ns.BuffOrder()
		if not applied or not list then
			fail(scenario, "SKIPPED -- an order with one unknown buff was refused")
		elseif list[1] ~= "spirit" or table.concat(list, ":"):find("nonsense", 1, true) then
			fail(scenario, "the unknown buff stayed: " .. table.concat(list, ":"))
		end
	end)
end
