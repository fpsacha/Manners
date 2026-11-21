-- The consumables button wears its look (Prompt/Supplies.lua, Wear; Looks/
-- Painted.lua, Painted.Socket). With "Put consumables on a button of their own"
-- on (ownBuffs.apart) the button wears the socket of the look the prompt has: the
-- painting's frame cut out round the icon's hole, the icon inset into it, rounded
-- where the socket is round. Earlier art leaves it plain, except for a look that
-- has no earlier art (paintedOnly). A new look reaches it at the next repaint, an
-- idle scan redraws nothing, and nothing is drawn in a fight.
--
-- The prompt is left unlocked, so the button shows its drag placeholder and no
-- bag fixture is wanted. Every scenario name starts with "supplieslook:" so the
-- mutations in tests/mutations/supplieslook.py can name the one that catches them.

local dir, H = ...
local fail, load, freshPrompt = H.fail, H.load, H.freshPrompt

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function sameCoords(got, want)
	if type(got) ~= "table" then return false end
	for i = 1, 4 do
		if not near(got[i], want[i]) then return false end
	end
	return true
end

-- One session with the button up, as `class`; `body(ns, button, refresh)`.
local function session(scenario, class, edit, body)
	Mock.reset()
	FT.install()
	if class then Mock.class = class end
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		local p = ns.db.profile
		p.ownBuffs.apart = true
		p.prompt.locked = false
		if edit then edit(ns, p) end
		local function refresh()
			ns.Supplies:Refresh()
			FT.settle()
		end
		refresh()
		local button = ns.Supplies:Button()
		if not button then
			fail(scenario, "the consumables button was never made")
			return
		end
		body(ns, button, refresh, p)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	Mock.inCombat = false
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function socketOf(ns, key)
	local data = ns.PaintedData and ns.PaintedData[key]
	return data, ns.Looks.Painted and ns.Looks.Painted.Socket
end

do
	local scenario = "supplieslook: the button wears the look's socket"
	session(scenario, nil, function(_, p) p.prompt.style = "frost" end, function(ns, button)
		local d, socketFor = socketOf(ns, "frost")
		if not (d and socketFor) then fail(scenario, "no painting for frost, or no Painted.Socket") return end
		local sock = button.socket
		if not sock then fail(scenario, "the button has no socket texture") return end
		if not FT.visible(sock) or sock._shown ~= true then fail(scenario, "the socket is not shown") end
		if sock._file ~= d.left.file then
			fail(scenario, "the socket draws " .. tostring(sock._file) .. ", not frost's left piece")
		end
		local u0, u1, v0, v1 = socketFor(d)
		if not sameCoords(sock._texCoord, { u0, u1, v0, v1 }) then
			fail(scenario, "the socket's texcoords are not Painted.Socket's for frost")
		end
		if not (u0 < u1 and v0 < v1) then fail(scenario, "the socket's texcoords are empty") end
		-- Worked out again here, not read back from Painted.Socket: the square is
		-- centred on the hole, which sits `above` down from the piece's top.
		local s, l = d.socket, d.left
		local tall = d.above + 1 + d.below
		local mid = (d.above + s.y) / tall * l.b
		if not (near((v0 + v1) / 2, mid) and near((u0 + u1) / 2, s.x / l.w * l.r)) then
			fail(scenario, "the socket's square is not centred on the icon's hole")
		end
		if not (u1 <= l.r + 1e-9 and v0 >= -1e-9 and v1 <= l.b + 1e-9) then
			fail(scenario, "the socket's square reaches past the left piece")
		end
		local icon = nil
		for _, r in ipairs(FT.all) do
			if r._parent == button and r._kind == "Texture" and r ~= sock and r._allPointsTo == nil and r._layer == "ARTWORK" then
				icon = r
			end
		end
		if not icon then fail(scenario, "the icon is on all points of the button: not inset into the socket") end
	end)
end

do
	local scenario = "supplieslook: a round socket rounds the icon"
	session(scenario, nil, function(_, p) p.prompt.style = "frost" end, function(ns, button, refresh, p)
		local mask = button.socketMask
		if not mask then fail(scenario, "no round mask on the button") return end
		if mask._shown ~= true then fail(scenario, "frost's socket is round and its mask is not shown") end
		p.prompt.style = "forge"
		refresh()
		if mask._shown ~= false then fail(scenario, "forge's socket is square and its mask is still shown") end
	end)
end

do
	local scenario = "supplieslook: earlier art leaves it plain"
	session(scenario, nil, function(_, p) p.prompt.style = "frost" end, function(ns, button, refresh, p)
		if button.socket._shown ~= true then fail(scenario, "frost's socket is not shown to begin with") return end
		p.prompt.classicArt = true
		refresh()
		if button.socket._shown ~= false then fail(scenario, "under Earlier art the socket is still shown") end
		if button.socketMask and button.socketMask._shown ~= false then
			fail(scenario, "under Earlier art the round mask is still shown")
		end
		for _, r in ipairs(FT.all) do
			if r._parent == button and r._kind == "Texture" and r ~= button.socket and r._layer == "ARTWORK" then
				if r._allPointsTo ~= button then fail(scenario, "under Earlier art the icon is not back on all of the button") end
			end
		end
		p.prompt.classicArt = false
		refresh()
		if button.socket._shown ~= true then fail(scenario, "Earlier art off again, the socket does not come back") end
	end)
end

do
	local scenario = "supplieslook: a painted-only look stays painted under earlier art"
	session(scenario, nil, function(_, p) p.prompt.style = "priest" p.prompt.classicArt = true end, function(ns, button)
		local look = ns.Looks.list.priest
		if not (look and look.paintedOnly) then fail(scenario, "priest is not a painted-only look") return end
		local d = ns.PaintedData.priest
		if button.socket._shown ~= true then fail(scenario, "priest under Earlier art lost its socket") end
		if button.socket._file ~= d.left.file then fail(scenario, "priest's socket draws " .. tostring(button.socket._file)) end
	end)
end

do
	local scenario = "supplieslook: a new look reaches the button"
	session(scenario, nil, function(_, p) p.prompt.style = "frost" end, function(ns, button, refresh, p)
		if button.socket._file ~= ns.PaintedData.frost.left.file then fail(scenario, "frost's socket is not drawn first") return end
		p.prompt.style = "forge"
		refresh()
		if button.socket._file ~= ns.PaintedData.forge.left.file then
			fail(scenario, "after frost to forge the socket still draws " .. tostring(button.socket._file))
		end
		p.prompt.style = "glass"
		refresh()
		if button.socket._file ~= ns.PaintedData.glass.left.file then
			fail(scenario, "after forge to glass the socket still draws " .. tostring(button.socket._file))
		end
	end)
	-- A class look: the character's own class's look is the style.
	session(scenario, "MAGE", function(ns, p)
		p.prompt.classStyles = { MAGE = "archmage" }
		ns.Looks.SetClassLook(p.prompt, true)
	end, function(ns, button, _, p)
		if p.prompt.style ~= "archmage" then fail(scenario, "the class look did not put archmage on the prompt: " .. tostring(p.prompt.style)) return end
		if button.socket._file ~= ns.PaintedData.archmage.left.file then
			fail(scenario, "a mage's class look: the socket draws " .. tostring(button.socket._file))
		end
	end)
	-- A look with a fallback draws its fallback's socket: none is written yet.
	local fallback
	Mock.reset()
	local ns = load(scenario)
	if ns then
		for key, look in pairs(ns.Looks.list) do
			if look.fallback and ns.PaintedData and ns.PaintedData[look.fallback] then fallback = key end
		end
	end
	Mock.reset()
	if fallback then
		session(scenario, nil, function(_, p) p.prompt.style = fallback end, function(nsf, button)
			local want = nsf.PaintedData[nsf.Looks.list[fallback].fallback].left.file
			if button.socket._file ~= want then fail(scenario, fallback .. " does not draw its fallback's socket") end
		end)
	end
end

do
	local scenario = "supplieslook: an idle scan redraws nothing"
	session(scenario, nil, function(_, p) p.prompt.style = "frost" end, function(ns, button, refresh)
		local sock = button.socket
		local calls = 0
		local texture, coords = sock.SetTexture, sock.SetTexCoord
		sock.SetTexture = function(self, ...) calls = calls + 1 return texture(self, ...) end
		sock.SetTexCoord = function(self, ...) calls = calls + 1 return coords(self, ...) end
		refresh()
		refresh()
		sock.SetTexture, sock.SetTexCoord = texture, coords
		if calls ~= 0 then fail(scenario, "a scan with nothing changed redrew the socket " .. calls .. " times") end
	end)
end

do
	local scenario = "supplieslook: nothing is drawn in a fight"
	session(scenario, nil, function(_, p) p.prompt.style = "frost" end, function(ns, button, refresh, p)
		local frost = ns.PaintedData.frost.left.file
		Mock.inCombat = true
		p.prompt.style = "forge"
		refresh()
		if button.socket._file ~= frost then fail(scenario, "in a fight the socket was redrawn as " .. tostring(button.socket._file)) end
		Mock.inCombat = false
		refresh()
		if button.socket._file ~= ns.PaintedData.forge.left.file then
			fail(scenario, "out of the fight the socket does not follow the look: " .. tostring(button.socket._file))
		end
	end)
end

do
	local scenario = "supplieslook: glass wears its socket"
	session(scenario, nil, nil, function(ns, button, _, p)
		if p.prompt.style ~= "glass" then fail(scenario, "the default look is " .. tostring(p.prompt.style)) return end
		local d = ns.PaintedData.glass
		if not d then fail(scenario, "no painting for glass") return end
		if button.socket._shown ~= true then fail(scenario, "glass, a native look, has no socket") return end
		if button.socket._file ~= d.left.file then fail(scenario, "glass draws " .. tostring(button.socket._file)) end
	end)
end
