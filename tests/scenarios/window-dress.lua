-- What the options window wears (Options/Window/WindowDress.lua): a gilt
-- moulding round it, a beaded rail under the header and over the footer, a
-- grain and a vignette on each pane, a gold rim in each button, a stud before
-- each section and a band and a stud on the page that is open. Decoration
-- only: nothing here asks about a control.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local ART = "Interface\\AddOns\\Manners\\Textures\\Window\\Window_"
local FILES = { "Frame", "Rail", "Ground", "Shade", "Glow", "Fade", "Stud" }
local RAIL_TILE, GROUND_TILE, FRAME_CORNER = 16, 128, 24 / 64

local function near(a, b, eps) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.001) end

local function header(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local h = f:read(18)
	f:close()
	if not h or #h < 18 then return nil end
	local b = { h:byte(1, 18) }
	return { imageType = b[3], width = b[13] + b[14] * 256, height = b[15] + b[16] * 256, bits = b[17] }
end

local function with(scenario, page, body)
	Mock.reset()
	FT.install()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.OpenOptions(page)
		ns.Prompt:ExitTest()
		body(ns, ns.WindowUI)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "window-dress: the window wears a moulding, rails and a grain, all from files that are there"
	with(scenario, "general", function(ns, UI)
		for _, name in ipairs(FILES) do
			local h = header(dir .. "/Textures/Window/Window_" .. name .. ".tga")
			if not h then
				fail(scenario, "Textures/Window/Window_" .. name .. ".tga is missing")
			elseif h.bits ~= 32 or h.imageType ~= 2 or h.width > 256 or h.height > 256 then
				fail(scenario, name .. " is not a 32-bit uncompressed TGA of 256 a side at most")
			end
		end
		local D = UI.Dress
		if not (D and D.frame and D.corners and D.sides) then fail(scenario, "the window wears no moulding") return end
		if #D.corners ~= 4 or #D.sides ~= 4 then fail(scenario, "the moulding is not four corners and four sides") end
		-- Each corner is its own corner of the file, each side the strip between.
		local want = { { 0, FRAME_CORNER, 0, FRAME_CORNER }, { 1 - FRAME_CORNER, 1, 0, FRAME_CORNER },
			{ 0, FRAME_CORNER, 1 - FRAME_CORNER, 1 }, { 1 - FRAME_CORNER, 1, 1 - FRAME_CORNER, 1 } }
		for i, t in ipairs(D.corners) do
			local c = t._texCoord or {}
			for k = 1, 4 do
				if not near(c[k], want[i][k]) then fail(scenario, "corner " .. i .. " of the moulding shows the wrong piece of its file") break end
			end
			if tostring(t._file) ~= ART .. "Frame" then fail(scenario, "corner " .. i .. " draws " .. tostring(t._file)) end
		end
		local top = D.sides[1]._texCoord or {}
		if not (near(top[1], FRAME_CORNER) and near(top[2], 1 - FRAME_CORNER) and near(top[4], FRAME_CORNER)) then
			fail(scenario, "the moulding's top side is not the strip between its corners")
		end
		-- Over everything the window draws, and in nobody's way.
		if D.frame:GetFrameLevel() <= UI.frame:GetFrameLevel() then fail(scenario, "the moulding is under the window") end
		if D.frame.IsMouseEnabled and D.frame:IsMouseEnabled() then fail(scenario, "the moulding takes the mouse") end
		-- The rails: whole tiles along the window, under the header and over the footer.
		-- (By name, one after the other: a rail that is not there is a nil a
		-- table of the two would leave out.)
		for _, name in ipairs({ "header", "footer" }) do
			local rail = D[name .. "Rail"]
			local c = rail and rail._texCoord or {}
			if not (rail and near((c[2] or 0) - (c[1] or 0), UI.WIDTH / RAIL_TILE)) then
				fail(scenario, "the " .. name .. "'s rail is not tiled along the window")
			end
			local wrap = rail and rail._ft or {}
			if wrap.wrapH ~= "REPEAT" then fail(scenario, "the " .. name .. "'s rail does not repeat") end
		end
		-- A button's gold rim.
		local rim = UI.footer.reset.rim
		if not (rim and #rim == 4) then fail(scenario, "a button has no rim of four sides") end
	end)
end

do
	local scenario = "window-dress: the open page has its band and its stud, and each section its stud"
	with(scenario, "general", function(ns, UI)
		local function marks(want)
			for id, b in pairs(UI.side.buttons) do
				local on = b.band and b.band:IsShown() and b.stud and b.stud:IsShown()
				if id == want and not on then fail(scenario, "the open page, " .. id .. ", has no band or no stud") end
				if id ~= want and (b.band and b.band:IsShown() or b.stud and b.stud:IsShown()) then
					fail(scenario, id .. " is marked as open while " .. want .. " is")
				end
			end
		end
		marks("general")
		ns.OpenOptions("profiles")
		marks("profiles")
		-- The open page's second line is written lighter than the others'.
		local sub = UI.side.buttons.profiles.sub
		local r = sub and sub._textColor and sub._textColor[1]
		if not (r and r > 0.8) then fail(scenario, "the open page's second line is still the grey of the others: " .. tostring(r)) end
		ns.OpenOptions("who")
		marks("who")
		r = sub._textColor and sub._textColor[1]
		if not (r and r < 0.7) then fail(scenario, "a page no longer open keeps the lighter second line") end
		-- Every section title on the page has a stud at the start of its rule,
		-- and a section that is not up has none.
		local seen = 0
		for _, sec in ipairs(UI.Model("who").sections or {}) do
			if sec.title and sec.title:IsShown() then
				seen = seen + 1
				if not (sec.stud and sec.stud:IsShown()) then
					fail(scenario, "a section's title has no stud: " .. tostring(sec.title:GetText()))
				else
					local p = sec.stud.points[#sec.stud.points]
					if p[2] ~= sec.rule then fail(scenario, "a section's stud does not hang off its rule") end
				end
			elseif sec.stud and sec.stud:IsShown() then
				fail(scenario, "a section that is not shown still has its stud up")
			end
		end
		if seen == 0 then fail(scenario, "SKIPPED -- the page's sections could not be read") end
		-- Another page opened: the studs of the page left go with its titles
		-- (they stand on the one scrolling pane every page is laid on).
		ns.OpenOptions("general")
		for _, sec in ipairs(UI.Model("who").sections or {}) do
			if sec.stud and sec.stud:IsShown() then
				fail(scenario, "a stud of the page left is still up over the page opened")
				break
			end
		end
	end)
end
