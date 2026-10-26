-- Hunt 38, the Letter look (Looks/Letter.lua): faults found reading it against
-- every setting and every state it can be in. Each scenario below is red on the
-- code before its fix; tests/mutations/hunt38-letter.py puts each fix back.
--
--   * the bound key's slip, on a prompt as narrow as the slider allows, stood
--     over the seal and the reason line, and out of the prompt on the left;
--   * a list that grew or shrank in the scan that began the unroll put the
--     scroll's three frames at rest under a run that went on, so the paper, its
--     window and the right rod were carried past their places by the whole of
--     the run's offset and snapped back when it ended;
--   * a restyle (a slider dragged) while the scroll unrolled did the same.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function withTree(scenario, names, body, before)
	Mock.reset()
	if before then before() end
	FT.install()
	local restore = strangers(names or {})
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns, scenario) end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.01)
end

local function tick(ns)
	ns.addon:Tick()
	FT.settle()
end

local function upIn(ns, scenario, edit)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	p.style = "letter"
	p.flashStyle = "pulse"
	p.effects = "full"
	p.hideInCombat = false
	p.showIcon = true
	p.showSub = true
	if edit then edit(p) end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	tick(ns)
	local r = ns.Prompt:Regions()
	return r, p, r.look
end

local function rectOf(r)
	local L, R = FT.span(r, "x")
	local B, T = FT.span(r, "y")
	if L and B then return { L, B, R, T } end
end

local function across(a, b)
	return a[1] < b[3] - 0.01 and b[1] < a[3] - 0.01 and a[2] < b[4] - 0.01 and b[2] < a[4] - 0.01
end

local function rel(box, panel)
	return { box[1] - panel[1], panel[4] - box[4], box[3] - panel[1], panel[4] - box[2] }
end

local function playing(look)
	local n = 0
	for _, g in ipairs(look.unrollGroups) do if g._playing then n = n + 1 end end
	return n
end

-- Where the three frames of the unroll stand, as offsets from where they rest.
local function offsets(look)
	local win, sheet, rod = look.paperSlide.points[1], look.paperSheet.points[1], look.rodRight.points[1]
	if not (win and sheet and rod) then return nil end
	return { window = win[4] - look.g.splitX, sheet = sheet[4], rod = rod[4] - look.g.rodR }
end

-- ------------------------------------------------------------------ 1
-- The bound key's slip keeps to the room the lines leave it.
withTree("hunt38-letter: the bound key's slip never stands over the seal or the reason, at any width", ANNA,
	function(ns, scenario)
		local shown = 0
		for _, key in ipairs({ "SHIFT-CTRL-F", "F" }) do
			for _, width in ipairs({ 80, 85, 90, 100, 120, 140 }) do
				for _, case in ipairs({ { 44, 13, true }, { 36, 8, true }, { 56, 16, true }, { 28, 8, false }, { 44, 13, false } }) do
					local height, font, two = case[1], case[2], case[3]
					Mock.bindings = {}
					SetBinding(key, COMMAND)
					local r, _, look = upIn(ns, scenario, function(p)
						p.width, p.height, p.fontSize, p.showSub = width, height, font, two
					end)
					local tag = ("%s on %dx%d, %d pt%s"):format(key, width, height, font, two and "" or ", one line")
					if look and look.keyUp then
						shown = shown + 1
						local panel = rectOf(r.art)
						local slip = rectOf(look.keyBox)
						local g = look.g
						local k = slip and rel(slip, panel)
						if not k then
							fail(scenario, tag .. ": the key's slip has no place")
						else
							if k[1] < g.textX - 0.01 or k[3] > g.textRight + 0.01 then
								fail(scenario, ("%s: the key's slip (%.1f to %.1f) leaves the paper's text room (%.1f to %.1f)"):format(
									tag, k[1], k[3], g.textX, g.textRight))
							end
							local name = rectOf(r.name)
							local sub = r.sub:IsShown() and rectOf(r.sub) or nil
							if name and across(slip, name) then fail(scenario, tag .. ": the key's slip is over the name") end
							if sub and across(slip, sub) then fail(scenario, tag .. ": the key's slip is over the reason") end
						end
					end
				end
			end
		end
		Mock.bindings = {}
		if shown == 0 then fail(scenario, "SKIPPED -- no key's slip was ever up, so nothing was held") end
	end)

-- ------------------------------------------------------------------ 2
-- A list that changes under a running unroll leaves it going.
withTree("hunt38-letter: a list that changes while the scroll unrolls does not carry it past its place", CROWD,
	function(ns, scenario)
		local r, _, look = upIn(ns, scenario, function(p) p.showQueue, p.queueRows = true, 3 end)
		if not (look and look.unrollGroups) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
		if playing(look) ~= 3 then fail(scenario, "SKIPPED -- the arrival did not unroll the scroll") return end
		local from = offsets(look)
		if not (from and from.window < -1) then fail(scenario, "SKIPPED -- the unroll did not start from its start") return end
		Mock.advance(0.1)
		local shown = look.listShown
		look:PaintQueue(r.rows and {}, shown > 1 and 1 or 2, look.listAt)
		if look.listShown == shown then fail(scenario, "SKIPPED -- the list was not laid again") return end
		local now = offsets(look)
		if playing(look) ~= 3 then fail(scenario, "a list laid again stopped the unroll") end
		if not (now and near(now.window, from.window) and near(now.sheet, from.sheet) and near(now.rod, from.rod)) then
			fail(scenario, ("a list laid again under a running unroll left the window at %s, the paper at %s and the rod at %s from their places, not where the run began (%s, %s, %s)"):format(
				tostring(now and now.window), tostring(now and now.sheet), tostring(now and now.rod),
				tostring(from.window), tostring(from.sheet), tostring(from.rod)))
		end
		-- The run still ends at rest.
		Mock.advance(0.5)
		FT.settle()
		local rest = offsets(look)
		if playing(look) ~= 0 or not (rest and near(rest.window, 0) and near(rest.sheet, 0) and near(rest.rod, 0)) then
			fail(scenario, "the unroll did not end at rest after the list changed")
		end
	end)

-- ------------------------------------------------------------------ 3
-- A restyle while it unrolls ends it, at rest.
withTree("hunt38-letter: a restyle while the scroll unrolls leaves it at rest, not carried past its place", ANNA,
	function(ns, scenario)
		local r, p, look = upIn(ns, scenario)
		if not (look and look.unrollGroups) then fail(scenario, "SKIPPED -- Letter is not the look in use") return end
		if playing(look) ~= 3 then fail(scenario, "SKIPPED -- the arrival did not unroll the scroll") return end
		Mock.advance(0.1)
		p.width = p.width + 40
		ns.Prompt:ApplyStyle()
		FT.settle()
		local now = offsets(look)
		if playing(look) ~= 0 then
			fail(scenario, "an unroll went on running after a restyle moved what it walks")
		end
		if not (now and near(now.window, 0) and near(now.sheet, 0) and near(now.rod, 0)) then
			fail(scenario, "a restyle during the unroll left the scroll out of its place")
		end
		Mock.advance(1)
		FT.settle()
		local later = offsets(look)
		if not (later and near(later.window, 0) and near(later.sheet, 0) and near(later.rod, 0)) then
			fail(scenario, "the scroll was out of its place after a restyle's unroll ended")
		end
	end)

-- ------------------------------------------------------------------ 4
-- The count's drop of wax has a place whichever way the count first shows.
withTree("hunt38-letter: the count's drop of wax is placed when the count first stands beside the lines", CROWD,
	function(ns, scenario)
		local checked = 0
		for _, two in ipairs({ false, true }) do
			Mock.bindings = {}
			local r, _, look = upIn(ns, scenario, function(p)
				p.width, p.showIcon, p.showSub, p.showCount = 260, false, two, true
			end)
			local tag = two and "with a reason line" or "with one line"
			if not (look and look.countMode and look.countMode ~= "seal") then
				fail(scenario, "SKIPPED -- the count did not stand beside the lines " .. tag)
			else
				checked = checked + 1
				local pin, light, box = rectOf(look.countPin), rectOf(look.countPinLight), rectOf(look.countBox)
				if look.countPin._shown == false then
					fail(scenario, tag .. ": the count's slip has no drop of wax shown")
				elseif not (pin and light and box) then
					fail(scenario, tag .. ": the count's drop of wax is shown with no place, so nothing is drawn")
				else
					local cx, cy = (pin[1] + pin[3]) / 2, (pin[2] + pin[4]) / 2
					if not (cx > box[1] - 1 and cx < box[1] + (box[3] - box[1]) / 2 and cy > box[4] - (box[4] - box[2]) / 2 and cy < box[4] + 1) then
						fail(scenario, tag .. ": the count's drop of wax is not on its slip's upper left corner")
					end
				end
			end
		end
		if checked == 0 then fail(scenario, "SKIPPED -- the count never stood beside the lines") end
	end)
