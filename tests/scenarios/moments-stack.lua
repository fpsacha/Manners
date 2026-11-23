-- Where the cards of the buttons for the moment sit (Prompt/Moments.lua, Place):
-- stacked above the prompt, nearest first, each in a place of its own (a secure
-- button cannot move in a fight), clear of the list of names, of the painted art
-- over and under the bar and of the buttons beside the prompt; below the prompt
-- where there is no room above; a column that is too tall wraps to the next. The
-- rectangles are worked out here from the points the buttons were given, with the
-- prompt's own rectangle written by the scenario (the mock has no screen).
--
-- Every name starts with "moments-stack:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")
-- Written for plain values.
K.plain = true

local KNOWN = {}
for _, id in ipairs(K.MAGE_SPELLS) do KNOWN[#KNOWN + 1] = id end
for _, id in ipairs(K.WARD_SPELLS) do KNOWN[#KNOWN + 1] = id end
for _, id in ipairs(K.GEM_SPELLS) do KNOWN[#KNOWN + 1] = id end

local function with(name, body, opts)
	opts = opts or {}
	opts.known = opts.known or KNOWN
	K.withMage(H, "moments-stack: " .. name, body, opts)
end
local function name(s) return "moments-stack: " .. s end
local function slot(ns, n) return ns.Moments:Slot(n) end

-- The prompt where the scenario puts it: left and bottom, and the rest from its size.
local function put(ns, left, bottom)
	local p = ns.db.profile.prompt
	local b = ns.Prompt:GetButton()
	local s = p.scale
	b._left, b._bottom = left, bottom
	b._right, b._top = left + p.width * s, bottom + p.height * s
	return b
end

-- A card's rectangle { left, bottom, right, top } from its last point.
local function rectOf(ns, s)
	local b = s.button
	local pt = b.points[#b.points]
	local pr = ns.Prompt:GetButton()
	local w, h = b:GetWidth(), b:GetHeight()
	if pt[1] == "BOTTOMLEFT" then
		return { pr._left + pt[4], pr._top + pt[5], pr._left + pt[4] + w, pr._top + pt[5] + h }
	end
	return { pr._left + pt[4], pr._bottom + pt[5] - h, pr._left + pt[4] + w, pr._bottom + pt[5] }
end

local function overlap(a, b)
	return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
end

local function armed(ns)
	local out = {}
	for n = 1, 11 do
		local s = slot(ns, n)
		if s and s.armed then out[#out + 1] = s end
	end
	return out
end

local function place(ns)
	ns.Moments.Place(ns.db.profile.prompt)
end

local function byKey(ns, key)
	for _, s in ipairs(armed(ns)) do
		if s.row.key == key then return s end
	end
end

local SCREEN = 1000

do
	local s = name("nearest first: Blink, Counterspell, Ice Block, Cold Snap")
	with(s, function(ns)
		put(ns, 600, 400)
		place(ns)
		local last = -1
		for _, key in ipairs({ "blink", "counterspell", "iceblock", "coldsnap" }) do
			local card = byKey(ns, key)
			if not card then fail(s, key .. " is not armed") return end
			local r = rectOf(ns, card)
			if r[2] <= last then fail(s, key .. " is not above the one before it: " .. r[2] .. " after " .. last) end
			last = r[2]
		end
		if ns.Moments.placed.side ~= "above" then fail(s, "not above the prompt: " .. tostring(ns.Moments.placed.side)) end
	end, { known = { 2139, 11958, 1953, 12472 } })
end

do
	local s = name("clear of the list above, of the painted art over the bar and of the buttons beside the prompt")
	with(s, function(ns)
		local p = ns.db.profile.prompt
		local b = put(ns, 600, 400)
		p.showQueue, p.queueRows = true, 3
		local state = ns.Prompt.state
		state.queueAbove, state.queueGap = true, 30
		place(ns)
		local first = rectOf(ns, byKey(ns, "blink"))
		local reach = (4 + 30 + 3 * math.max(p.fontSize + 4, state.rowPitch or 0) + 4) * p.scale
		if first[2] < b._top + reach then fail(s, "the first card is over the list: " .. first[2] .. " < " .. (b._top + reach)) end
		-- The painted art over the bar, with no list.
		p.showQueue = false
		state.queueGap, state.artAbove = nil, 25
		place(ns)
		first = rectOf(ns, byKey(ns, "blink"))
		if first[2] < b._top + 25 * p.scale then fail(s, "the first card is over the painted art: " .. first[2]) end
		-- A card wider than the prompt reaches the buttons beside it.
		state.artAbove = nil
		ns.db.profile.moments.cardSize = 150
		p.iconSize = 48
		ns.caps.breakFree = {}
		place(ns)
		local w = byKey(ns, "blink").button:GetWidth()
		if w <= p.width * p.scale then fail(s, "the card is not wider than the prompt: " .. w) return end
		first = rectOf(ns, byKey(ns, "blink"))
		local side = math.max(0, 48 * p.scale / 2 + 16 - p.height * p.scale / 2)
		if first[2] < b._top + side + 6 * p.scale then fail(s, "the first card is over Will of the Forsaken's name: " .. first[2]) end
		-- Not when the card stops short of the prompt's edge.
		ns.db.profile.moments.cardSize = 80
		place(ns)
		first = rectOf(ns, byKey(ns, "blink"))
		if first[2] ~= b._top + 6 * p.scale then fail(s, "the beside buttons held back a card that does not reach them: " .. first[2]) end
	end)
end

do
	local s = name("no room above: below the prompt, clear of the list and of the second cure")
	with(s, function(ns)
		local p = ns.db.profile.prompt
		local b = put(ns, 600, 400)
		-- The prompt near the top of the screen.
		b._top = SCREEN - 20
		b._bottom = b._top - p.height * p.scale
		p.showQueue, p.queueRows = true, 3
		ns.Prompt.state.queueAbove = false
		place(ns)
		if ns.Moments.placed.side ~= "below" then fail(s, "not below: " .. tostring(ns.Moments.placed.side)) return end
		local first = rectOf(ns, byKey(ns, "blink"))
		local reach = (4 + 0 + 3 * math.max(p.fontSize + 4, ns.Prompt.state.rowPitch or 0) + 4) * p.scale
		if first[4] > b._bottom - reach then fail(s, "the first card is over the list below: " .. first[4]) end
		-- The second cure beside the prompt, below the first.
		p.showQueue = false
		ns.db.profile.moments.cardSize = 150
		p.iconSize = 48
		p.cureFightEach = true
		ns.CureFight.Applies = function() return true end
		ns.CureFightSpells = function() return { {}, {} } end
		place(ns)
		first = rectOf(ns, byKey(ns, "blink"))
		local two = 1.5 * 48 * p.scale + 10 + 14 - p.height * p.scale / 2
		if first[4] > b._bottom - two - 6 * p.scale then fail(s, "the first card is over the second cure: " .. first[4]) end
	end)
end

do
	local s = name("a tall column wraps left, or right at the screen's left edge")
	with(s, function(ns)
		local p = ns.db.profile.prompt
		local b = put(ns, 600, 400)
		-- Room for two above the prompt.
		b._top = SCREEN - 150
		b._bottom = b._top - p.height * p.scale
		place(ns)
		local placed = ns.Moments.placed
		if placed.side ~= "above" or placed.perCol ~= 2 or placed.cols < 2 then
			fail(s, ("not wrapped in twos above: %s, %s a column, %s columns"):format(tostring(placed.side), tostring(placed.perCol), tostring(placed.cols)))
			return
		end
		local one = rectOf(ns, byKey(ns, "blink"))
		local widest = 0
		for _, c in ipairs(armed(ns)) do
			local r = rectOf(ns, c)
			if r[1] < b._left then widest = widest + 1 end
		end
		if widest == 0 then fail(s, "no column went left of the first") end
		if one[1] ~= b._left then fail(s, "the first column is not on the prompt's left edge") end
		-- At the screen's left edge the columns go right.
		put(ns, 20, 400)
		b._top = SCREEN - 150
		b._bottom = b._top - p.height * p.scale
		place(ns)
		local right = 0
		for _, c in ipairs(armed(ns)) do
			local r = rectOf(ns, c)
			if r[1] < b._left then fail(s, "a column went off the screen's left edge") end
			if r[1] > b._left then right = right + 1 end
		end
		if right == 0 or not ns.Moments.placed.rightwards then fail(s, "no column went right") end
	end)
end

do
	local s = name("no two shown cards overlap, and none overlaps a neighbour, with every neighbour on")
	for _, case in ipairs({ { 80, true }, { 150, true }, { 80, false }, { 100, false } }) do
		local percent, listAbove = case[1], case[2]
		with(s, function(ns)
			local p = ns.db.profile.prompt
			local b = put(ns, 600, 400)
			ns.db.profile.moments.cardSize = percent
			p.iconSize = 40
			p.showQueue, p.queueRows = true, 2
			local state = ns.Prompt.state
			state.queueAbove = listAbove
			state.queueGap = listAbove and 12 or nil
			state.artAbove, state.artBelow = 12, 12
			ns.caps.breakFree = {}
			p.cureFightEach = true
			ns.CureFight.Applies = function() return true end
			ns.CureFightSpells = function() return { {}, {} } end
			-- Room for three in a column, so some wrap.
			b._top = SCREEN - 220
			b._bottom = b._top - p.height * p.scale
			place(ns)
			local cards = {}
			for _, c in ipairs(armed(ns)) do
				if not c.row.calm then cards[#cards + 1] = { key = c.row.key, r = rectOf(ns, c) } end
			end
			local pitch = math.max(p.fontSize + 4, state.rowPitch or 0)
			local reach = 4 + (listAbove and 12 or 12) + 2 * pitch + 4
			local neighbours = { { "prompt", { b._left, b._bottom, b._right, b._top } } }
			local sideSize = 40
			local mid = (b._top + b._bottom) / 2
			neighbours[#neighbours + 1] = { "list", listAbove and { b._left, b._top, b._right, b._top + reach }
				or { b._left, b._bottom - reach, b._right, b._bottom } }
			neighbours[#neighbours + 1] = { "will of the forsaken", { b._right + 10, mid - sideSize / 2 - 16, b._right + 10 + sideSize, mid + sideSize / 2 + 16 } }
			neighbours[#neighbours + 1] = { "the cures", { b._right + 10, mid - sideSize * 1.5 - 24, b._right + 10 + sideSize, mid + sideSize / 2 + 16 } }
			for i, a in ipairs(cards) do
				for j = i + 1, #cards do
					if overlap(a.r, cards[j].r) then fail(s, ("%s and %s overlap at %d %%"):format(a.key, cards[j].key, percent)) end
				end
				for _, n in ipairs(neighbours) do
					if overlap(a.r, n[2]) then
						fail(s, ("%s overlaps %s at %d %%, list %s: card %s, neighbour %s"):format(a.key, n[1], percent,
							listAbove and "above" or "below", table.concat(a.r, ","), table.concat(n[2], ",")))
					end
				end
			end
		end)
	end
end

do
	local s = name("the drink shares the first place and is never shown with a fight card")
	with(s, function(ns)
		put(ns, 600, 400)
		place(ns)
		local drink, first = byKey(ns, "drink"), byKey(ns, "blink")
		if not drink or not first then fail(s, "no drink or no Blink armed") return end
		local a, b = drink.button.points[#drink.button.points], first.button.points[#first.button.points]
		if a[4] ~= b[4] or a[5] ~= b[5] or a[1] ~= b[1] then fail(s, "the drink has a place of its own: " .. tostring(a[5]) .. " and " .. tostring(b[5])) end
		K.pull(ns)
		Mock.lossOfControl = { { locType = "STUN", spellID = 1 } }
		K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
		K.tick(ns, 0.3)
		if first.state ~= "lit" or not first.button:IsShown() then fail(s, "Blink is not up") end
		if drink.button:IsShown() then fail(s, "the drink is shown with a fight card") end
	end)
end

do
	local s = name("Wanted re-places after a drag, a new card size or the list switched on; an idle scan places nothing")
	with(s, function(ns)
		local p = ns.db.profile.prompt
		put(ns, 600, 400)
		if ns.Moments:Wanted() then ns.Moments:Refresh() end
		local blink = byKey(ns, "blink")
		local was = blink.button.points[#blink.button.points]
		for _ = 1, 20 do ns.Moments:Wanted() end
		ns.addon:Tick()
		Mock.runTimers(0)
		if blink.button.points[#blink.button.points] ~= was then fail(s, "an idle scan placed the cards again") end
		if ns.Moments:Wanted() then fail(s, "Wanted asks for a refresh with nothing changed") end
		-- A drag ends in ApplyStyle.
		ns.Prompt:ApplyStyle()
		if not ns.Moments:Wanted() then fail(s, "a drag is not noticed") end
		ns.Moments:Refresh()
		if ns.Moments:Wanted() then fail(s, "still wanted after the refresh") end
		-- A new card size.
		ns.db.profile.moments.cardSize = 120
		if not ns.Moments:Wanted() then fail(s, "a new card size is not noticed") end
		ns.Moments:Refresh()
		if blink.button:GetHeight() ~= 74 then fail(s, "the cards are not placed at the new size: " .. tostring(blink.button:GetHeight())) end
		-- The list switched on, which restyles the prompt.
		p.showQueue = not p.showQueue
		ns.Prompt.state.queueAbove = true
		ns.Prompt:ApplyStyle()
		if not ns.Moments:Wanted() then fail(s, "the list switched on is not noticed") end
	end)
end

do
	local s = name("the painted bar tells the cards how far its art hangs over and under it, and a look with no painting tells them nothing")
	with(s, function(ns)
		local p = ns.db.profile.prompt
		local state = ns.Prompt.state
		p.style = "glass"
		ns.Prompt:ApplyStyle()
		if not (state.artAbove and state.artAbove > 0 and state.artAbove == state.queueGap and state.artBelow and state.artBelow > 0) then
			fail(s, "the painted glass says " .. tostring(state.artAbove) .. " over and " .. tostring(state.artBelow) .. " under")
		end
		if type(state.rowPitch) ~= "number" or state.rowPitch < p.fontSize + 4 then fail(s, "no row pitch: " .. tostring(state.rowPitch)) end
		local serial = state.styleSerial
		p.style = "framed"
		ns.Prompt:ApplyStyle()
		if state.artAbove ~= nil or state.artBelow ~= nil then
			fail(s, "framed keeps the glass's art: " .. tostring(state.artAbove) .. ", " .. tostring(state.artBelow))
		end
		if state.styleSerial == serial then fail(s, "restyling does not move the serial") end
		-- The first card clears the painted art.
		p.style = "glass"
		ns.Prompt:ApplyStyle()
		local b = put(ns, 600, 400)
		place(ns)
		local first = rectOf(ns, byKey(ns, "blink"))
		if first[2] < b._top + state.artAbove * p.scale then fail(s, "the first card is over the glass's art: " .. first[2]) end
	end)
end
