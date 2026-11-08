-- Round 37, the options window redesign: the twenty findings of the round 36
-- audit of the options window, each held here.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every name
-- starts with "ux-redesign:" so a mutation can name exactly one.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell" }

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function near(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (tol or 1e-3) end

-- One session on the recording client, the window open on `spec.page` (none:
-- not opened). `spec.class`, `spec.locale`, `spec.buffs` (the class's buffs it
-- knows, by key), `spec.known` (spell ids), `spec.before(ns)` (after the load,
-- before the window opens). `body(ns, UI)`. Everything put back.
local function session(scenario, spec, body)
	Mock.reset()
	if spec.class then Mock.class = spec.class end
	if spec.locale then Mock.locale = spec.locale end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	FT.install()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		if spec.buffs or spec.known then
			local set = {}
			for _, id in ipairs(spec.known or {}) do set[id] = true end
			for _, key in ipairs(spec.buffs or {}) do
				local buff = ns.FindBuff(Mock.class, key)
				for _, id in ipairs(buff and buff.ranks or {}) do set[id] = true end
			end
			IsSpellKnown = function(id) return set[id] == true end
			IsPlayerSpell = IsSpellKnown
		end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		if spec.before then spec.before(ns) end
		if spec.page then ns.OpenOptions(spec.page, true) end
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		noErrors(scenario, ns)
	end)
	FT.uninstall()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ 1
-- The Luxe card's tag: its slices are made when the card is first laid out,
-- after the card was painted, and were left the file's own white until the
-- pointer passed over the card.
do
	local scenario = "ux-redesign: the Luxe card's tag is tinted the first time the page is drawn"
	session(scenario, { class = "WARRIOR", buffs = { "battleshout" }, page = "appearance" }, function(ns, UI)
		local row = UI.RowFor("appearance.style")
		local spec = ns.Looks.previewText.luxe and ns.Looks.previewText.luxe.reason
		local pill = spec and spec.pill
		if not (row and row.cards and pill) then
			fail(scenario, "SKIPPED -- no gallery, or Luxe records no tag")
			return
		end
		local card
		for _, c in ipairs(row.cards) do
			if c:IsShown() and c.key == "luxe" then card = c end
		end
		if not card then
			fail(scenario, "there is no Luxe card")
			return
		end
		-- As on the first paint: no slices yet when the card is painted, made
		-- by the layout that follows, with no paint after it.
		for _, s in ipairs(card.pill) do
			for _, t in ipairs(s) do t:Hide() end
		end
		card.pill = {}
		row:Layout(row.width or 612)
		if #card.pill == 0 then
			fail(scenario, "the layout made no tag")
		end
		for i, layer in ipairs(pill.layers) do
			for j, t in ipairs(card.pill[i] or {}) do
				local c = t._color
				local same = type(c) == "table"
				for k = 1, 4 do
					if same and not near(c[k] == nil and 1 or c[k], layer.color[k] == nil and 1 or layer.color[k]) then same = false end
				end
				if t:IsShown() and not same then
					fail(scenario, ("layer %d slice %d is not the look's colour before any hover"):format(i, j))
				end
			end
		end
	end)
end
