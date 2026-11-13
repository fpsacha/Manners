-- Looks/Flow.lua: art that moves by its texture coordinates.
--
--   * a scroll moves its window by its speed and the clock's own time, wraps
--     at the file's edge, keeps the window's size, and rests where it stood;
--   * a sheet shows one drawn frame at a time, left to right and top to bottom,
--     loops or stops on its last frame and says so once;
--   * the clock is one OnUpdate on a frame of the look's art, shown only while
--     something plays, and writes at most thirty times a second;
--   * nothing here is written by adding up: the same moment gives the same
--     coordinates however many frames the game drew on the way.

local dir, H = ...
local fail, load = H.fail, H.load

local function near(a, b) return math.abs(a - b) < 1e-4 end

local function coords(tex)
	local c = tex._texCoord or {}
	return c[1], c[2], c[3], c[4]
end

-- On the recording CreateFrame of tests/frametree.lua, which keeps each
-- texture's coordinates and each frame's parent.
dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local function with(scenario, body)
	Mock.reset()
	FT.install()
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then
		ok, err = pcall(function()
			local parent = CreateFrame("Frame", nil, UIParent)
			local flow = ns.Looks.Flow.New(parent)
			body(ns, flow, parent)
		end)
	end
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "flow: a scroll moves by the clock, wraps, keeps its window and rests where it stood"
	with(scenario, function(ns, flow, parent)
		local tex = parent:CreateTexture(nil, "ARTWORK")
		local lava = flow:Scroll(tex, 0.25, -0.5, 2, 0.5)
		local l, r, t, b = coords(tex)
		if not (near(l, 0) and near(r, 2) and near(t, 0) and near(b, 0.5)) then
			fail(scenario, ("at rest the window is %s %s %s %s"):format(tostring(l), tostring(r), tostring(t), tostring(b)))
		end
		if lava:IsPlaying() or flow.driver:IsShown() then fail(scenario, "a scroll runs before it is played") end
		lava:Play()
		if not flow.driver:IsShown() then fail(scenario, "the clock is not running with a scroll playing") end
		Mock.advance(1)
		flow:Tick(GetTime())
		l, r, t, b = coords(tex)
		if not (near(l, 0.25) and near(r, 2.25)) then fail(scenario, ("after a second at 0.25 a second the window starts at %s"):format(tostring(l))) end
		-- A speed the other way wraps to the far edge, never below nothing.
		if not (near(t, 0.5) and near(b, 1.0)) then fail(scenario, ("a scroll up at half a file a second is at %s to %s"):format(tostring(t), tostring(b))) end
		-- From the clock, not from the frames drawn: ten ticks or one, the same.
		for _ = 1, 10 do
			Mock.advance(0.3)
			flow:Tick(GetTime())
		end
		l = coords(tex)
		-- (The edge is the edge from either side: 0.99999 of a file is 0.)
		if not (near(l % 1, 0) or near(l % 1, 1)) then fail(scenario, ("after four seconds the window starts at %s, not back at the file's edge"):format(tostring(l))) end
		Mock.advance(0.4)
		flow:Tick(GetTime())
		lava:Stop()
		if flow.driver:IsShown() then fail(scenario, "the clock runs on with nothing playing") end
		local rested = coords(tex)
		Mock.advance(5)
		flow:Tick(GetTime())
		if not near(coords(tex), rested) then fail(scenario, "a stopped scroll went on moving") end
		lava:Play()
		if not near(coords(tex), rested) then fail(scenario, ("played again, the scroll jumped from %s to %s"):format(tostring(rested), tostring((coords(tex))))) end
		-- A new window (the region changed size) keeps the place.
		lava:Window(3, 1)
		l, r, t, b = coords(tex)
		if not (near(r - l, 3) and near(b - t, 1) and near(l, rested)) then fail(scenario, "a new window lost its size or its place") end
	end)
end

do
	local scenario = "flow: a sheet plays its frames in order, loops, or stops on the last and says so once"
	with(scenario, function(ns, flow, parent)
		local tex = parent:CreateTexture(nil, "ARTWORK")
		local fire = flow:Sheet(tex, 4, 2, 6, 10, true)
		local l, r, t, b = coords(tex)
		if not (near(l, 0) and near(r, 0.25) and near(t, 0) and near(b, 0.5)) then fail(scenario, "a sheet does not rest on its first frame") end
		fire:Play()
		local function at(seconds)
			Mock.advance(seconds)
			flow:Tick(GetTime())
			local cl, _, ct = coords(tex)
			return math.floor(cl * 4 + 0.5) + 4 * math.floor(ct * 2 + 0.5)
		end
		if at(0.15) ~= 1 then fail(scenario, "0.15 s in at ten frames a second is not the second frame") end
		if at(0.30) ~= 4 then fail(scenario, "the fifth frame is not the first of the second row") end
		-- Six frames of eight cells: the loop turns at the sixth, not the eighth.
		if at(0.20) ~= 0 then fail(scenario, "a loop of six frames did not come round after the sixth") end
		fire:Stop()

		local once, said = flow:Sheet(parent:CreateTexture(nil, "ARTWORK"), 4, 2, 8, 20, false), 0
		once.done = function() said = said + 1 end
		once:Play()
		Mock.advance(0.2)
		flow:Tick(GetTime())
		if not once:IsPlaying() then fail(scenario, "a sheet played once stopped before its last frame") end
		Mock.advance(1)
		flow:Tick(GetTime())
		flow:Tick(GetTime())
		if once:IsPlaying() then fail(scenario, "a sheet played once is still playing after its last frame") end
		if said ~= 1 then fail(scenario, "its end was said " .. said .. " times, not once") end
		local cl, _, ct = coords(once.tex)
		if not (near(cl, 0.75) and near(ct, 0.5)) then fail(scenario, "a sheet played once does not rest on its last frame") end
		if flow.driver:IsShown() then fail(scenario, "the clock runs on after the last sheet ended") end
		-- Played again, it starts over.
		once:Play()
		cl, _, ct = coords(once.tex)
		if not (near(cl, 0) and near(ct, 0)) then fail(scenario, "played again, a sheet did not start from its first frame") end
	end)
end

do
	local scenario = "flow: one clock, shown only while something plays, thirty writes a second at most"
	with(scenario, function(ns, flow, parent)
		local driver = flow.driver
		if not driver.mannersFlow then fail(scenario, "the clock's frame is not marked as Flow's") end
		if driver._parent ~= parent then fail(scenario, "the clock is not a frame of the look's own art") end
		local update = driver:GetScript("OnUpdate")
		if type(update) ~= "function" then fail(scenario, "the clock has no OnUpdate") return end
		local a = flow:Scroll(parent:CreateTexture(nil, "ARTWORK"), 1, 0)
		local b = flow:Scroll(parent:CreateTexture(nil, "ARTWORK"), 1, 0)
		a:Play()
		b:Play()
		a:Play()
		a:Stop()
		if not driver:IsShown() then fail(scenario, "the clock stopped with a scroll still playing") end
		local writes = 0
		local set = b.tex.SetTexCoord
		b.tex.SetTexCoord = function(self, ...) writes = writes + 1 return set(self, ...) end
		-- A second at 240 frames a second.
		for _ = 1, 240 do
			Mock.advance(1 / 240)
			update(driver, 1 / 240)
		end
		if writes > 31 then fail(scenario, writes .. " writes in a second at 240 frames a second") end
		if writes < 24 then fail(scenario, "only " .. writes .. " writes in a second: the art would stutter") end
		flow:StopAll()
		if driver:IsShown() then fail(scenario, "StopAll left the clock running") end
		writes = 0
		for _ = 1, 30 do update(driver, 0.1) end
		if writes ~= 0 then fail(scenario, "a stopped scroll is still written") end
		-- Every flow made is reached by TickAll, for the renderer.
		b:Play()
		Mock.advance(0.5)
		writes = 0
		ns.Looks.Flow.TickAll(GetTime())
		if writes ~= 1 then fail(scenario, "TickAll did not write a playing scroll once") end
	end)
end
