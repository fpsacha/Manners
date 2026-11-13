-- The options window can be made bigger (1.11.20): a grip in its bottom-right
-- corner, dragged, sizes it between its usual 820 x 600 and the screen; the
-- rows are laid out across the new width and the page scrolls within the new
-- height. The size is kept in ns.db.global.window (w, h) with the place, never
-- in the profile; a right click on the grip puts the usual size back
-- (Options/Window/Window.lua, UI.Resized, UI.SetWindowSize, UI.SavedSize).
--
-- Every scenario name starts with "window-resize:" so the mutations in
-- tests/mutations/window-resize.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local RAIL_TILE = 16

local function near(a, b, eps) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 0.5) end

local function with(scenario, opts, body)
	Mock.reset()
	FT.install()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		if opts.saved then
			ns.db.global.window = ns.db.global.window or {}
			for k, v in pairs(opts.saved) do ns.db.global.window[k] = v end
		end
		ns.OpenOptions(opts.page or "when")
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

-- The width a full-width row on the page is laid out at.
local function rowWidth(UI, path)
	local row = UI.RowFor(path)
	local frame = row and (row.frame or row)
	return frame and frame.GetWidth and frame:GetWidth() or nil
end

do
	local scenario = "window-resize: the grip makes the window bigger, the rows wider and the page taller"
	with(scenario, {}, function(ns, UI)
		local f = UI.frame
		if not UI.grip then fail(scenario, "the window has no grip to resize it by") return end
		if not near(f:GetWidth(), 820) or not near(f:GetHeight(), 600) then
			fail(scenario, ("a new window is %s x %s, not 820 x 600"):format(tostring(f:GetWidth()), tostring(f:GetHeight())))
		end
		local path = "when.hideMounted"
		local before, tall = rowWidth(UI, path), UI.view.height
		UI.SetWindowSize(1100, 800)
		if not near(f:GetWidth(), 1100) or not near(f:GetHeight(), 800) then
			fail(scenario, ("set to 1100 x 800 it is %s x %s"):format(tostring(f:GetWidth()), tostring(f:GetHeight())))
		end
		if UI.WIDTH ~= 1100 or UI.HEIGHT ~= 800 then fail(scenario, "the window's own size reads " .. UI.WIDTH .. " x " .. UI.HEIGHT) end
		local after = rowWidth(UI, path)
		if before and not (after and near(after - before, 280)) then
			fail(scenario, ("a row laid out at %s before is %s after, not 280 wider"):format(tostring(before), tostring(after)))
		end
		if not near(UI.view.child:GetWidth(), 1100 - UI.SIDEBAR - 13) then fail(scenario, "the scrolled page is as narrow as before") end
		if not near(UI.view.height - tall, 200) then
			fail(scenario, ("the page's room went from %s to %s"):format(tostring(tall), tostring(UI.view.height)))
		end
		local rail = UI.Dress.headerRail
		local c = rail and rail._texCoord or {}
		if not near((c[2] or 0) - (c[1] or 0), 1100 / RAIL_TILE, 0.01) then
			fail(scenario, "the header's rail is stretched, not tiled along the wider window")
		end
		local saved = Mock.sv.global and Mock.sv.global.window
		if not (saved and saved.w == 1100 and saved.h == 800) then fail(scenario, "the size is not kept in the window's state") end
		if Mock.sv.profile.window ~= nil then fail(scenario, "the window's size went into the profile") end
	end)
end

do
	local scenario = "window-resize: a right click on the grip puts the usual size back"
	with(scenario, {}, function(ns, UI)
		UI.SetWindowSize(1000, 700)
		local click = UI.grip and UI.grip:GetScript("OnClick")
		if not click then fail(scenario, "the grip has no click") return end
		click(UI.grip, "RightButton")
		if not near(UI.frame:GetWidth(), 820) or not near(UI.frame:GetHeight(), 600) then
			fail(scenario, "after a right click it is " .. tostring(UI.frame:GetWidth()) .. " x " .. tostring(UI.frame:GetHeight()))
		end
		local s = UI.State()
		if s.w ~= nil or s.h ~= nil then fail(scenario, "the usual size is still kept as a size of its own") end
	end)
end

do
	local scenario = "window-resize: the size it was left at opens again, held to the usual size and the screen"
	with(scenario, { saved = { w = 960, h = 700 } }, function(ns, UI)
		if not near(UI.frame:GetWidth(), 960) or not near(UI.frame:GetHeight(), 700) then
			fail(scenario, "a window left at 960 x 700 opened at " .. tostring(UI.frame:GetWidth()) .. " x " .. tostring(UI.frame:GetHeight()))
		end
		UI.SetWindowSize(400, 300)
		if not near(UI.frame:GetWidth(), 820) or not near(UI.frame:GetHeight(), 600) then
			fail(scenario, "made smaller than the usual size: " .. tostring(UI.frame:GetWidth()) .. " x " .. tostring(UI.frame:GetHeight()))
		end
		UI.SetWindowSize(99999, 99999)
		local maxW, maxH = UIParent:GetWidth() - 40, UIParent:GetHeight() - 40
		if UI.frame:GetWidth() > maxW + 0.5 or UI.frame:GetHeight() > maxH + 0.5 then
			fail(scenario, "made bigger than the screen: " .. tostring(UI.frame:GetWidth()) .. " x " .. tostring(UI.frame:GetHeight()))
		end
		local s = UI.State()
		s.w, s.h = "wide", 0 / 0
		local w, h = UI.SavedSize()
		if w ~= 820 or h ~= 600 then fail(scenario, "a damaged saved size read as " .. tostring(w) .. " x " .. tostring(h)) end
		if s.w ~= nil or s.h ~= nil then fail(scenario, "a damaged saved size was kept") end
	end)
end
