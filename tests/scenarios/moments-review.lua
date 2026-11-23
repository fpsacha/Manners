-- The review of the cards for the moment (Prompt/Moments.lua, Prompt/MomentsCard.lua,
-- Prompt/MomentsSense.lua, Prompt/Panel.lua): seven things a reader found wrong, each
-- held here.
--   * a look from Looks/ tells the cards how far its painting hangs over and under
--     the bar and how far its list is pushed off it (Place keeps clear of both);
--   * a held-dark line on the trail does not take the place of the lit line that
--     follows it a moment later;
--   * a card takes clicks over its icon alone, so the invisible stack of dark cards
--     of a fight does not swallow clicks meant for the world;
--   * a card is the size of the player's own prompt in the look, whatever the
--     height of the picture the look is cut from;
--   * a ward says "just hit you" only for a hit that is recent;
--   * the reason on a card that stays lit follows the facts behind it.
--
-- Every name starts with "moments-review:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")
-- Written for plain values.
K.plain = true

local KNOWN = {}
for _, id in ipairs(K.MAGE_SPELLS) do KNOWN[#KNOWN + 1] = id end
for _, id in ipairs(K.WARD_SPELLS) do KNOWN[#KNOWN + 1] = id end
for _, id in ipairs(K.GEM_SPELLS) do KNOWN[#KNOWN + 1] = id end

local BLINK = 1953

local function with(name, body, opts)
	opts = opts or {}
	opts.known = opts.known or KNOWN
	K.withMage(H, "moments-review: " .. name, body, opts)
end
local function name(s) return "moments-review: " .. s end
local function slot(ns, n) return ns.Moments:Slot(n) end
local function look(ns, n) return ns.Moments:Look(n) end

local function trailLines(ns, text)
	local n = 0
	for _, e in ipairs(ns.addon.db.char.trail or {}) do
		if tostring(e.text):find(text, 1, true) then n = n + 1 end
	end
	return n
end

local function stun(ns, kind)
	Mock.lossOfControl = { { locType = kind, spellID = 1 } }
	K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
	K.tick(ns, 0.3)
end

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

local function blinkCard(ns)
	for n = 1, 11 do
		local s = slot(ns, n)
		if s and s.armed and s.row.key == "blink" then return s end
	end
end

---------------------------------------------------------------------------
-- a look from Looks/ keeps the cards clear of its painting and its list
---------------------------------------------------------------------------

-- What the look itself draws, read from the look and not from what the prompt
-- says about it: how far its painting hangs over the bar, and how deep its list is.
local function reach(ns, p, above)
	local look = ns.Looks.Get(p.style)
	local g = look.paintedArt and look.paintedArt.g
	if not g then return nil end
	local over, under = math.max(0, -g.y0), math.max(0, g.y1 - p.height)
	local rows = math.max(1, p.queueRows)
	local depth = rows * look.pitch + 7 + (look.listGap or 0)
	return over, under, depth
end

for _, case in ipairs({
	{ "frost", 44, true }, { "frost", 48, true }, { "frost", 44, false }, { "frost", 52, false },
	{ "lightbringer", 44, true }, { "lightbringer", 44, false }, { "wild", 44, true }, { "toast", 44, false },
}) do
	local key, height, listAbove = case[1], case[2], case[3]
	local s = name(("%s at height %d, the list %s: the cards keep clear of the painted art and of the list"):format(
		key, height, listAbove and "above" or "below"))
	with(s, function(ns, _, profile)
		local p = profile.prompt
		p.style, p.height, p.showQueue, p.queueRows = key, height, true, 3
		-- Low on the screen the list goes above the prompt, high up it goes below.
		local b = put(ns, 600, listAbove and 100 or 800)
		Mock.screenHeight, Mock.promptCentreY = 1000, listAbove and 122 or 822
		ns.Prompt:ApplyStyle()
		local state = ns.Prompt.state
		if (state.queueAbove and true or false) ~= listAbove then fail(s, "the list is on the other side: " .. tostring(state.queueAbove)) return end
		local over, under, depth = reach(ns, p, listAbove)
		if not over then fail(s, key .. " draws no painting here") return end
		put(ns, 600, listAbove and 100 or 800)
		-- Room on either side: cards on the side of the list, as the stack puts them.
		ns.Moments.Place(p)
		local first = rectOf(ns, blinkCard(ns))
		local side = ns.Moments.placed.side
		local scale = p.scale
		if listAbove then
			if side ~= "above" then fail(s, "the cards are not above: " .. side) return end
			-- The painting over the bar, and the list the look lays over it.
			if first[2] < b._top + over * scale then
				fail(s, ("the first card (bottom %.1f) covers the painted art over the bar (to %.1f)"):format(first[2], b._top + over * scale))
			end
			if first[2] < b._top + depth * scale then
				fail(s, ("the first card (bottom %.1f) covers the list (to %.1f)"):format(first[2], b._top + depth * scale))
			end
		else
			-- The list is below the prompt; the cards are above, clear of the art over the bar.
			if side ~= "above" then fail(s, "the cards are not above: " .. side) return end
			if first[2] < b._top + over * scale then
				fail(s, ("the first card (bottom %.1f) covers the painted art over the bar (to %.1f)"):format(first[2], b._top + over * scale))
			end
			-- Pushed below the prompt by a prompt near the top of the screen: clear of the art under it.
			b._top = 1000 - 20
			b._bottom = b._top - p.height * scale
			ns.Moments.Place(p)
			if ns.Moments.placed.side ~= "below" then fail(s, "not below at the top of the screen: " .. tostring(ns.Moments.placed.side)) return end
			first = rectOf(ns, blinkCard(ns))
			if first[4] > b._bottom - under * scale then
				fail(s, ("the first card (top %.1f) covers the painted art under the bar (to %.1f)"):format(first[4], b._bottom - under * scale))
			end
			if first[4] > b._bottom - depth * scale then
				fail(s, ("the first card (top %.1f) covers the list (to %.1f)"):format(first[4], b._bottom - depth * scale))
			end
		end
	end)
end

---------------------------------------------------------------------------
-- a held-dark line leaves the room for the lit line that follows it
---------------------------------------------------------------------------

do
	local s = name("a Blink held dark and lit within two seconds has both lines on the trail")
	with(s, function(ns)
		K.pull(ns)
		K.tick(ns, 0.3)
		-- A cooldown of the game's own that ends in about a second.
		Mock.cooldown = { [BLINK] = { isActive = true, isOnGCD = false, startTime = Mock.now - 10, duration = 11 } }
		K.cooldownEvent(ns)
		Mock.lossOfControl = { { locType = "STUN", spellID = 1 } }
		K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
		K.tick(ns, 0.3)
		local blink = slot(ns, 3)
		if blink.state ~= "dark" then fail(s, "not held dark: " .. blink.state .. " " .. tostring(blink.why)) return end
		if trailLines(ns, "held dark") ~= 1 then fail(s, "no held line: " .. trailLines(ns, "held dark")) end
		Mock.cooldown = {}
		K.cooldownEvent(ns)
		K.tick(ns, 0.7)
		if blink.state ~= "lit" then fail(s, "not lit after the cooldown: " .. blink.state .. " " .. tostring(blink.why)) return end
		if trailLines(ns, "moment blink: lit") ~= 1 then
			fail(s, "the lit line is not on the trail (" .. trailLines(ns, "moment blink: lit") .. " of it)")
		end
	end)
end

---------------------------------------------------------------------------
-- a card takes clicks over its icon alone
---------------------------------------------------------------------------

for _, key in ipairs({ "frost", "glass", "ebon" }) do
	local s = name(key .. ": the button and its cover take clicks over the icon alone, the rest of the card reaches the world")
	with(s, function(ns)
		local c = blinkCard(ns)
		local card = look(ns, c.n).card
		local at = card.at
		if not at then fail(s, "the look records no icon") return end
		local w, h = c.button:GetWidth(), c.button:GetHeight()
		local inset = c.button._hitRect
		if not inset then fail(s, "the button's hit area is the whole card") return end
		local out = 3 * h / 50
		local left, right, top, bottom = inset[1], inset[2], inset[3], inset[4]
		-- The rectangle that is left: the icon, with the ring's room round it.
		local x0, x1, y0, y1 = left, w - right, top, h - bottom
		if math.abs(x0 - (at.l * w - out)) > 1.01 or math.abs(x1 - (at.r * w + out)) > 1.01
			or math.abs(y0 - (at.t * h - out)) > 1.01 or math.abs(y1 - (at.b * h + out)) > 1.01 then
			fail(s, ("the hit area is %.1f,%.1f to %.1f,%.1f of %d x %d, not the icon's %.1f,%.1f to %.1f,%.1f"):format(
				x0, y0, x1, y1, w, h, at.l * w - out, at.t * h - out, at.r * w + out, at.b * h + out))
		end
		if (x1 - x0) * (y1 - y0) > 0.2 * w * h then fail(s, "the hit area is most of the card") end
		-- The cover sits over that rectangle and no more.
		local pts = c.cover.points
		if #pts ~= 2 or pts[1][2] ~= c.button or pts[2][2] ~= c.button then
			fail(s, "the cover is not anchored to the button at two points: " .. #pts) return
		end
		if math.abs(pts[1][4] - x0) > 0.01 or math.abs(pts[1][5] + y0) > 0.01
			or math.abs(pts[2][4] - x1) > 0.01 or math.abs(pts[2][5] + y1) > 0.01 then
			fail(s, "the cover is not over the icon's rectangle")
		end
		-- Never written in a fight.
		K.pull(ns)
		local before = c.button._hitRect
		ns.Moments.Place(ns.db.profile.prompt)
		if c.button._hitRect ~= before then fail(s, "the hit area was moved in a fight") end
	end, { edit = function(profile) profile.prompt.style = key end })
end

---------------------------------------------------------------------------
-- a card is the size of the prompt in the look
---------------------------------------------------------------------------

for _, key in ipairs({ "frost", "ebon", "lightbringer", "glass" }) do
	local s = name(key .. ": at 100 the card's icon is the size of the prompt's own, and the default is 100")
	with(s, function(ns, _, profile)
		if profile.moments.cardSize ~= 100 then fail(s, "the default card size is " .. tostring(profile.moments.cardSize)) end
		local c = blinkCard(ns)
		local card = look(ns, c.n).card
		local at = card.at
		local lk = ns.Looks.Get(key)
		local g = lk and lk.paintedArt and lk.paintedArt.g
		if not (at and g) then
			-- glass is drawn by the panel, not by a look from Looks/: its picture is the standard view.
			if key == "glass" and c.button:GetHeight() ~= 62 then fail(s, "glass at 100 is " .. c.button:GetHeight() .. " high, not 62") end
			return
		end
		local icon = (at.b - at.t) * c.button:GetHeight()
		if math.abs(icon - g.iconSize) > 0.04 * g.iconSize then
			fail(s, ("the card's icon is %.1f units, the prompt's own %.1f (the card is %d high)"):format(icon, g.iconSize, c.button:GetHeight()))
		end
		local view = ns.Looks.PreviewView and ns.Looks.PreviewView(key)
		if not view or math.abs(c.button:GetHeight() - view) > 1 then
			fail(s, "the card is " .. c.button:GetHeight() .. " high, the look's view " .. tostring(view))
		end
	end, { edit = function(profile) profile.prompt.style = key end })
end

do
	local s = name("the card size runs from 80 to 150 and the slider says what 100 is")
	with(s, function(ns, _, profile)
		profile.moments.cardSize = 60
		ns.ClampSettings()
		if profile.moments.cardSize ~= 80 then fail(s, "60 is clamped to " .. tostring(profile.moments.cardSize)) end
		profile.moments.cardSize = 200
		ns.ClampSettings()
		if profile.moments.cardSize ~= 150 then fail(s, "200 is clamped to " .. tostring(profile.moments.cardSize)) end
		-- The slider's own range is the same, and its words say what 100 is.
		local look = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.appearance
		local slider = look and look.args and look.args.momentCardSize
		if not slider then fail(s, "no Card size slider") return end
		if slider.min ~= 80 or slider.max ~= 150 then fail(s, "the slider runs " .. tostring(slider.min) .. " to " .. tostring(slider.max)) end
		if not tostring(slider.desc):find("as big as the prompt itself", 1, true) then
			fail(s, "the slider does not say what 100 is: " .. tostring(slider.desc))
		end
	end)
end

---------------------------------------------------------------------------
-- a ward says "just hit you" only for a recent hit
---------------------------------------------------------------------------

do
	local s = name("an old fire hit and a target casting a spell the client gives no school for: the ward says the target casts, not that fire just hit you")
	-- A client with no table of spells: every cast is a guess from the last hit.
	with(s, function(ns)
		local ward = slot(ns, 9)
		if not ward or ward.row.key ~= "fireward" then fail(s, "no Fire Ward") return end
		K.pull(ns)
		K.event(ns, "UNIT_COMBAT", "player", "WOUND", "", 40, 4)
		K.tick(ns, 0.3)
		if ward.state ~= "lit" or look(ns, 9).reason:GetText() ~= ns.L["fire just hit you"] then
			fail(s, "the hit does not light it as a hit: " .. ward.state .. " " .. tostring(look(ns, 9).reason:GetText())) return
		end
		-- Forty seconds on, the target starts a spell.
		K.tick(ns, 40)
		K.cast(ns, { spell = 116 })
		K.tick(ns, 0.3)
		if ward.state ~= "lit" then fail(s, "Fire Ward is not lit by the guess: " .. ward.state .. " " .. tostring(ward.why)) return end
		local said = look(ns, 9).reason:GetText()
		if said ~= ns.L["your target casts fire"] then fail(s, "the reason says " .. tostring(said)) end
	end, { flavour = "tbc", plain = true,
		preload = function(ns) for id in pairs(ns.CAST_SCHOOLS) do ns.CAST_SCHOOLS[id] = nil end end })
	s = name("a recent fire hit still says it just hit you")
	with(s, function(ns)
		K.pull(ns)
		K.event(ns, "UNIT_COMBAT", "player", "WOUND", "", 40, 4)
		K.tick(ns, 0.3)
		if slot(ns, 9).state ~= "lit" then fail(s, "Fire Ward is not lit: " .. slot(ns, 9).state) return end
		if look(ns, 9).reason:GetText() ~= ns.L["fire just hit you"] then fail(s, "says " .. tostring(look(ns, 9).reason:GetText())) end
	end)
end

---------------------------------------------------------------------------
-- the reason follows the facts while a card stays lit
---------------------------------------------------------------------------

do
	local s = name("Blink lit by a root and then a stun says you are stunned, with no change of state between")
	with(s, function(ns)
		K.pull(ns)
		stun(ns, "ROOT")
		local blink = slot(ns, 3)
		if blink.state ~= "lit" then fail(s, "not lit by the root: " .. blink.state) return end
		if look(ns, 3).reason:GetText() ~= ns.L["you are rooted"] then fail(s, "root: " .. tostring(look(ns, 3).reason:GetText())) return end
		Mock.lossOfControl = { { locType = "STUN", spellID = 2 } }
		K.event(ns, "LOSS_OF_CONTROL_UPDATE", "player")
		K.tick(ns, 0.3)
		if blink.state ~= "lit" then fail(s, "no longer lit: " .. blink.state) return end
		if look(ns, 3).reason:GetText() ~= ns.L["you are stunned"] then
			fail(s, "after the stun the card still says " .. tostring(look(ns, 3).reason:GetText()))
		end
	end)
end
