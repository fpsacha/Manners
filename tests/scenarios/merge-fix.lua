-- After the painted looks were merged: what one engine does for every
-- painting, and what the three looks drawn by Prompt/Panel.lua leave behind
-- them. Every painted look: the middle reaches a unit under each end, so no
-- hairline of the world shows at a seam; on a prompt too narrow for the words
-- beside it the keycap and its letter step aside, and at the prompt's own size
-- they stay. The framed painting leaves no frame of its own switched on under
-- another look, and the rows past the list's own where any built-in look
-- leaves them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local PEOPLE = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" }, nameplate3 = { "Cara", "Close" } }

local function withTree(scenario, body)
	Mock.reset()
	Mock.geometry = { width = 1920, height = 1080 }
	FT.install()
	local restore = strangers(PEOPLE)
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns, scenario) end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

local function box(t)
	local x0, x1 = FT.span(t, "x")
	local y0, y1 = FT.span(t, "y")
	if not (x0 and x1 and y0 and y1) then return nil end
	return { x0 = x0, x1 = x1, y0 = math.min(y0, y1), y1 = math.max(y0, y1) }
end

local function up(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.effects, p.showIcon = "full", true
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	return p
end

-- The painting a style wears now: a look's own, or a built-in look's dressing.
local function artOf(ns, style)
	local look = ns.Looks.Get(style) or ns.Prompt:Regions().dress
	return look, look and look.paintedArt
end

-- Every style the data paints.
local function paintedStyles(ns)
	local out = {}
	local _, keys = ns.Looks.Choices()
	for _, key in ipairs(keys) do
		if ns.PaintedData and ns.PaintedData[key] then out[#out + 1] = key end
	end
	return out
end

-- ------------------------------------------------------------------ 1
withTree("merge-fix: every painting's middle reaches a unit under each end", function(ns, scenario)
	local p = up(ns, scenario)
	local seen = 0
	for _, style in ipairs(paintedStyles(ns)) do
		for _, size in ipairs({ { 320, 58 }, { 233, 41 } }) do
			p.style, p.width, p.height = style, size[1], size[2]
			ns.Prompt:ApplyStyle()
			tick(ns)
			local _, art = artOf(ns, style)
			if art and art.on and FT.visible(art.pieces[2]) then
				seen = seen + 1
				local L, M, R = box(art.pieces[1]), box(art.pieces[2]), box(art.pieces[3])
				local inL, inR = L and M and (L.x1 - M.x0), M and R and (M.x1 - R.x0)
				-- A painted shadow (data seam) has the middle reach further, by its band.
				local limit = 1.05 + (art.data and art.data.seam or 0) * size[2]
				if not (inL and inR and inL >= 0.5 and inL <= limit and inR >= 0.5 and inR <= limit) then
					fail(scenario, ("%s at %dx%d: the middle reaches %s under the left end and %s under the right"):format(style,
						size[1], size[2], tostring(inL), tostring(inR)))
				end
			end
		end
	end
	if seen < 20 then fail(scenario, "SKIPPED -- only " .. seen .. " paintings drawn with a middle") end
end)

-- ------------------------------------------------------------------ 2
withTree("merge-fix: the painted keycap steps aside on a prompt too narrow for the words, and stays at the prompt's own size", function(ns, scenario)
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
	local p = up(ns, scenario, function(pp) pp.keycap = "show" end)
	local dropped, kept = 0, 0
	for _, style in ipairs(paintedStyles(ns)) do
		-- At the prompt's own size, the keycap is up on every painting.
		p.style, p.width, p.height = style, 320, 58
		ns.Prompt:ApplyStyle()
		tick(ns)
		local look, art = artOf(ns, style)
		if art and art.on then
			kept = kept + 1
			if not FT.visible(art.keycap) then fail(scenario, style .. ": at 320x58 the keycap is not drawn") end
		end
		-- Narrow and tall: the bar drawn smaller, little room in the well.
		p.width, p.height = 110, 64
		ns.ClampSettings()
		ns.Prompt:ApplyStyle()
		tick(ns)
		look, art = artOf(ns, style)
		if art and art.on and art.g then
			local g = art.g
			local room = (g.keyX - g.keyW / 2) - g.textX
			local fits = room >= 4 * p.fontSize
			if not fits then
				dropped = dropped + 1
				if FT.visible(art.keycap) then
					fail(scenario, ("%s at %dx%d: the keycap stands with %.1f units left for the words"):format(style, p.width,
						p.height, room))
				end
				if look.keyText and FT.visible(look.keyText) then
					fail(scenario, ("%s at %dx%d: the key's letter is written with the keycap gone"):format(style, p.width, p.height))
				end
			elseif not FT.visible(art.keycap) then
				fail(scenario, ("%s at %dx%d: the keycap is gone with %.1f units for the words"):format(style, p.width, p.height, room))
			end
		end
	end
	if kept < 20 then fail(scenario, "SKIPPED -- only " .. kept .. " paintings drawn") end
	if dropped == 0 then fail(scenario, "SKIPPED -- no painting was too narrow for its keycap") end
end)

-- ------------------------------------------------------------------ 3
-- The live frames and regions drawing something under the button, by serial
-- and anchor.
local function tree(ns)
	local frames, regions = {}, {}
	local function walk(f, live)
		if live then
			frames[#frames + 1] = tostring(f._serial)
			for _, r in ipairs({ f:GetRegions() }) do
				-- A line with nothing written in it draws nothing (the list's rows
				-- unfilled, which a look of Looks/ lays as it fills them).
				local text = r._kind == "FontString" and r:GetText() or "x"
				if r:IsShown() and text ~= nil and text ~= "" then
					local pts = {}
					for _, pt in ipairs(r.points or {}) do
						local t = {}
						for i = 1, 5 do
							local v = pt[i]
							if type(v) == "number" then v = ("%.2f"):format(v) end
							t[i] = type(v) == "table" and ("#" .. tostring(v._serial)) or tostring(v)
						end
						pts[#pts + 1] = table.concat(t, ",")
					end
					regions[#regions + 1] = tostring(r._serial) .. "|" .. table.concat(pts, ";")
				end
			end
		end
		for _, c in ipairs({ f:GetChildren() }) do walk(c, live and c:IsShown()) end
	end
	walk(ns.Prompt.regions.button, true)
	table.sort(frames)
	table.sort(regions)
	return frames, regions
end

local function missingFrom(a, b)
	local had, out = {}, {}
	for _, x in ipairs(a) do had[x] = true end
	for _, x in ipairs(b) do
		if not had[x] then out[#out + 1] = x end
	end
	return out
end

withTree("merge-fix: the framed painting leaves no frame of its own on, nor anything moved", function(ns, scenario)
	local p = up(ns, scenario, function(pp) pp.showQueue, pp.queueRows, pp.clickRows = true, 3, true end)
	if not ns.PaintedData.framed then fail(scenario, "SKIPPED -- no framed painting in the data") return end
	for _, base in ipairs({ "glass", "ribbon" }) do
		p.style = base
		ns.Prompt:ApplyStyle()
		tick(ns)
		local f0, r0 = tree(ns)
		p.style = "framed"
		ns.Prompt:ApplyStyle()
		tick(ns)
		local _, art = artOf(ns, "framed")
		if not (art and art.on) then fail(scenario, "SKIPPED -- the framed look did not wear its painting") return end
		p.style = base
		ns.Prompt:ApplyStyle()
		tick(ns)
		local f1, r1 = tree(ns)
		local frames = missingFrom(f0, f1)
		if #frames > 0 then
			fail(scenario, ("%s -> framed -> %s: a frame is switched on that was not before (%s)"):format(base, base,
				table.concat(frames, ", ")))
		end
		local moved = missingFrom(r0, r1)
		if #moved > 0 then
			fail(scenario, ("%s -> framed -> %s: a region is not where it was: %s"):format(base, base, table.concat(moved, " ; ")))
		end
	end
end)
