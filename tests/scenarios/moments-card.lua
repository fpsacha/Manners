-- A button for the moment is drawn as a card in the player's look
-- (Prompt/MomentsCard.lua, Looks/CardArt.lua, Prompt/Moments.lua): the look's own
-- picture (the one the Look page's picker shows), the spell's icon at the
-- rectangle the look records for it, and the spell's name and a reason line in the
-- look's own lines, laid out of a fight and only written to in one.
--
-- Held to the mock's model of the client, not to the client itself: how the
-- game draws the card, and whether it hit-tests the cover as the mock does, only a
-- fight can say (STATUS.md).
--
-- Every name starts with "moments-card:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")
-- Written for plain values; Forever's hidden ones are asked for by name.
K.plain = true
-- The frame tree records each texture's file and each animation's state.
dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local KNOWN = {}
for _, id in ipairs(K.MAGE_SPELLS) do KNOWN[#KNOWN + 1] = id end
for _, id in ipairs(K.WARD_SPELLS) do KNOWN[#KNOWN + 1] = id end

local function with(name, body, opts)
	opts = opts or {}
	opts.known = opts.known or KNOWN
	K.withMage(H, "moments-card: " .. name, body, opts)
end
-- With the frame tree, which keeps each texture's file and each animation's state.
local function withTree(name, body, opts)
	FT.install()
	with(name, body, opts)
	FT.uninstall()
end
local function name(s) return "moments-card: " .. s end
local function slot(ns, n) return ns.Moments:Slot(n) end
local function look(ns, n) return ns.Moments:Look(n) end
local function style(key) return function(profile) profile.prompt.style = key end end

local RING = "Interface\\AddOns\\Manners\\Textures\\Ring"
local RING_SQUARE = "Interface\\AddOns\\Manners\\Textures\\RingSq"

local function stun(ns, kind)
	Mock.lossOfControl = { { locType = kind, spellID = 1 } }
	K.event(ns, "LOSS_OF_CONTROL_ADDED", "player", 1)
	K.tick(ns, 0.3)
end

do
	local s = name("the lit card wears the look's picture, the icon at its rectangle with the look's mask, the name and the reason")
	withTree(s, function(ns)
		local Looks = ns.Looks
		K.pull(ns)
		K.cast(ns)
		K.tick(ns, 0.3)
		local c = slot(ns, 1)
		if c.state ~= "lit" then fail(s, "Counterspell is not lit: " .. c.state) return end
		local card = look(ns, 1).card
		local want = Looks.PreviewFile("frost")
		if not want or card.file ~= want or card.shot._file ~= want then
			fail(s, "the card's picture is " .. tostring(card.shot._file) .. ", not " .. tostring(want))
		end
		local at = Looks.PreviewIcon("frost")
		if card.at ~= at then fail(s, "the icon is not at the rectangle the look records") end
		if not at.round or not card.masked or not card.mask or card.mask._file ~= at.mask then
			fail(s, "the round look's icon has no mask of its own: " .. tostring(card.masked))
		end
		local w, h = card.picW, card.picH
		local p = card.icon.points
		if #p ~= 2 or p[1][2] ~= c.inner or p[1][4] ~= at.l * w or p[1][5] ~= -at.t * h or p[2][4] ~= at.r * w then
			fail(s, "the icon is not laid at the look's rectangle in the card's own units")
		end
		if card.icon._file == nil or card.iconFile ~= c.entry.icon then fail(s, "the icon is not the spell's: " .. tostring(card.iconFile)) end
		local text = Looks.PreviewText("frost")
		if look(ns, 1).name:GetText() ~= "Counterspell" then fail(s, "the name line says " .. tostring(look(ns, 1).name:GetText())) end
		if look(ns, 1).reason:GetText() ~= ns.L["your target is casting"] then fail(s, "the reason line says " .. tostring(look(ns, 1).reason:GetText())) end
		local size = math.max(5, math.floor(text.name.size * h + 0.5))
		if card.lineSize.name < math.floor(size * 0.8) or card.lineSize.name > size then
			fail(s, "the name is not in the look's size for this card: " .. tostring(card.lineSize.name) .. " of " .. size)
		end
		local col = text.name.color
		local fs = look(ns, 1).name
		if not (fs._textColor and fs._textColor[1] == col[1] and fs._textColor[2] == col[2] and fs._textColor[3] == col[3]) then
			fail(s, "the name is not in the look's colour")
		end
		if Mock.shownAlpha(card.shot) ~= 1 then fail(s, "the picture is not on the screen: " .. tostring(Mock.shownAlpha(card.shot))) end
	end, { edit = style("frost") })
end

do
	for _, case in ipairs({ { 80, 1, 50 }, { 100, 1, 62 }, { 150, 1, 93 }, { 80, 1.2, 60 }, { 60, 1, 37 } }) do
		local percent, scale, high = case[1], case[2], case[3]
		local s = name(("the button is a card four to one: Card size %d at the prompt's scale %s is %d high"):format(percent, tostring(scale), high))
		with(s, function(ns)
			local b = ns.Moments:Button(1)
			if b:GetHeight() ~= high or b:GetWidth() ~= 4 * high then
				fail(s, ("the button is %s x %s"):format(tostring(b:GetWidth()), tostring(b:GetHeight())))
			end
			local card = look(ns, 1).card
			if card.picW ~= 4 * high or card.picH ~= high then fail(s, "the card is dressed for another size") end
			if ns.Moments.placed.w ~= 4 * high then fail(s, "the placed record says " .. tostring(ns.Moments.placed.w)) end
		end, { edit = function(profile)
			profile.moments.cardSize = percent
			profile.prompt.scale = scale
		end })
	end
end

do
	local s = name("hidden health: the game paints the whole card and it says low health; the first of two clicks shows the ring and the dim card; plain health says it is low")
	with(s, function(ns)
		Mock.healthSecret, Mock.health = true, 100
		K.pull(ns)
		K.tick(ns, 0.3)
		local ice = slot(ns, 2)
		if ice.state ~= "game" then fail(s, "not left to the game: " .. ice.state) return end
		local l = look(ns, 2)
		if l.reason:GetText() ~= ns.L["low health"] then fail(s, "the general reason is " .. tostring(l.reason:GetText())) end
		if K.shown(ns, 2) ~= 0 then fail(s, "the card shows at full health") end
		if l.hint:IsShown() then fail(s, "the dim card shows with no click") end
		K.click(ns, 2)
		if not l.ring:IsShown() or l.ring:GetParent() ~= l.mark then fail(s, "no ring on Lua's own layer") end
		if not l.hint:IsShown() or not l.hintCard.shot:IsShown() or not l.hintCard.lines.name:IsShown() then
			fail(s, "the first click does not show the dim card, picture, icon and name")
		end
		if l.hintCard.lines.name:GetText() ~= "Ice Block" then fail(s, "the dim card's name is " .. tostring(l.hintCard.lines.name:GetText())) end
		if l.hintCard.lines.reason then fail(s, "a dim card has a reason line, which would claim one") end
		if Mock.shownAlpha(l.hintCard.icon) <= 0 then fail(s, "the dim icon is not on the screen") end
	end, { plain = false })
	s = name("plain health: the reason says your health is low")
	with(s, function(ns)
		Mock.health = 10
		K.pull(ns)
		K.tick(ns, 0.3)
		if slot(ns, 2).state ~= "lit" then fail(s, "not lit: " .. slot(ns, 2).state) return end
		if look(ns, 2).reason:GetText() ~= ns.L["your health is low"] then fail(s, "the reason is " .. tostring(look(ns, 2).reason:GetText())) end
	end)
end

do
	local s = name("Blink's reasons: stunned, rooted, and, where the game would not say, lost control")
	with(s, function(ns)
		K.pull(ns)
		stun(ns, "STUN")
		if look(ns, 3).reason:GetText() ~= ns.L["you are stunned"] then fail(s, "stun: " .. tostring(look(ns, 3).reason:GetText())) end
	end)
	with(s, function(ns)
		K.pull(ns)
		stun(ns, "ROOT")
		if look(ns, 3).reason:GetText() ~= ns.L["you are rooted"] then fail(s, "root: " .. tostring(look(ns, 3).reason:GetText())) end
	end)
	with(s, function(ns)
		K.pull(ns)
		stun(ns, Mock.SECRET)
		if slot(ns, 3).state ~= "lit" then fail(s, "not lit: " .. slot(ns, 3).state) return end
		if look(ns, 3).reason:GetText() ~= ns.L["you lost control"] then fail(s, "hidden: " .. tostring(look(ns, 3).reason:GetText())) end
	end)
end

do
	local s = name("the wards say whether the cast or the hit lit them, and Cold Snap names Ice Block")
	with(s, function(ns)
		K.pull(ns)
		K.event(ns, "UNIT_COMBAT", "player", "WOUND", "", 40, 4)
		K.tick(ns, 0.3)
		if slot(ns, 9).state ~= "lit" then fail(s, "Fire Ward not lit by the hit: " .. slot(ns, 9).state) return end
		if look(ns, 9).reason:GetText() ~= ns.L["fire just hit you"] then fail(s, "hit: " .. tostring(look(ns, 9).reason:GetText())) end
	end)
	with(s, function(ns)
		local fire
		for id, mask in pairs(ns.CAST_SCHOOLS or {}) do
			if mask == 4 then fire = id break end
		end
		if not fire then return end
		K.pull(ns)
		Mock.targetCast = { spell = fire, name = "Fireball" }
		K.event(ns, "UNIT_SPELLCAST_START", "target")
		K.tick(ns, 0.3)
		if slot(ns, 9).state ~= "lit" then fail(s, "Fire Ward not lit by the cast: " .. slot(ns, 9).state .. " " .. tostring(slot(ns, 9).why)) return end
		if look(ns, 9).reason:GetText() ~= ns.L["your target casts fire"] then fail(s, "cast: " .. tostring(look(ns, 9).reason:GetText())) end
	end)
	with(s, function(ns)
		K.pull(ns)
		K.event(ns, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 11958)
		Mock.health = 10
		K.event(ns, "UNIT_HEALTH", "player")
		K.tick(ns, 0.3)
		if slot(ns, 7).state ~= "lit" then fail(s, "Cold Snap not lit: " .. slot(ns, 7).state) return end
		local want = ns.L["brings back %s"]:format("Ice Block")
		if look(ns, 7).reason:GetText() ~= want then fail(s, "Cold Snap says " .. tostring(look(ns, 7).reason:GetText())) end
	end)
end

do
	local s = name("a look with no picture wears framed's; Earlier art changes the picture; the ring is round on a round look")
	withTree(s, function(ns)
		ns.Looks.previews.frost = nil
		ns.Moments:Refresh()
		local c = slot(ns, 1)
		if c.picture ~= "framed's" then fail(s, "a look with no picture says its picture is " .. tostring(c.picture)) end
		if look(ns, 1).card.file ~= ns.Looks.PreviewFile("framed") then fail(s, "not framed's picture: " .. tostring(look(ns, 1).card.file)) end
		if look(ns, 1).ring._file ~= RING_SQUARE then fail(s, "framed's icon is square: " .. tostring(look(ns, 1).ring._file)) end
		ns.Looks.previews.frost = true
		ns.Moments:Refresh()
		if c.picture ~= "own" or look(ns, 1).card.file ~= ns.Looks.PreviewFile("frost") then fail(s, "frost's own picture did not come back") end
		if look(ns, 1).ring._file ~= RING then fail(s, "a round look's ring is not round: " .. tostring(look(ns, 1).ring._file)) end
		ns.db.profile.prompt.classicArt = true
		ns.Prompt:ApplyStyle()
		ns.addon:Tick()
		local earlier = ns.Looks.PreviewFile("frost")
		if not tostring(earlier):find("_earlier", 1, true) then fail(s, "Earlier art has no picture of its own: " .. tostring(earlier)) return end
		if look(ns, 1).card.file ~= earlier then fail(s, "the card keeps the picture it had: " .. tostring(look(ns, 1).card.file)) end
	end, { edit = style("frost") })
end

do
	local s = name("a look changed in a fight is dressed only after it; nothing is written to a secure button in a fight")
	with(s, function(ns)
		K.pull(ns)
		K.cast(ns)
		K.tick(ns, 0.3)
		Mock.protectedCalls, Mock.secretOnSecure = {}, {}
		local before = look(ns, 1).card.file
		ns.db.profile.prompt.style = "glass"
		ns.Prompt:ApplyStyle()
		-- Even asked directly, a card is not dressed under the lockdown.
		ns.MomentCard.Dress(slot(ns, 1), "glass", 200, 50)
		K.tick(ns, 0.3)
		if look(ns, 1).card.file ~= before then fail(s, "dressed in a fight: " .. tostring(look(ns, 1).card.file)) end
		Mock.healthSecret = nil
		Mock.health = 10
		K.event(ns, "UNIT_HEALTH", "player")
		stun(ns, "STUN")
		K.endCast(ns)
		K.tick(ns, 0.5)
		if #Mock.protectedCalls > 0 then fail(s, "protected calls in the fight: " .. table.concat(Mock.protectedCalls, ", ")) end
		if #Mock.secretOnSecure > 0 then fail(s, "a hidden value reached a protected frame") end
		K.release(ns)
		K.tick(ns, 0.3)
		if look(ns, 1).card.file ~= ns.Looks.PreviewFile("glass") then fail(s, "not dressed after the fight: " .. tostring(look(ns, 1).card.file)) end
	end, { edit = style("frost") })
end

do
	local s = name("Calm effects and a quiet fight leave nothing looping; full effects pulse the flare")
	withTree(s, function(ns)
		K.pull(ns)
		K.cast(ns)
		K.tick(ns, 0.3)
		if not slot(ns, 1).pulse._playing then fail(s, "full effects: the flare does not pulse") end
		if not look(ns, 1).flare:IsShown() then fail(s, "the flare is not shown while lit") end
	end)
	withTree(s, function(ns)
		K.pull(ns)
		K.cast(ns)
		K.tick(ns, 0.3)
		local l = look(ns, 1)
		if slot(ns, 1).pulse._playing then fail(s, "Calm effects: the flare loops") end
		if not l.flare:IsShown() or l.flare._alpha ~= 0.35 then fail(s, "Calm effects: the flare is not steady: " .. tostring(l.flare._alpha)) end
	end, { edit = function(profile) profile.prompt.effects = "calm" end })
	withTree(s, function(ns)
		K.pull(ns)
		K.cast(ns)
		K.tick(ns, 0.3)
		if slot(ns, 1).pulse._playing then fail(s, "a quiet fight: the flare loops") end
	end, { edit = function(profile) profile.prompt.hideInCombat = true end })
	withTree(s, function(ns)
		K.pull(ns)
		K.cast(ns)
		K.tick(ns, 0.3)
		K.endCast(ns)
		K.tick(ns, 0.5)
		if slot(ns, 1).pulse._playing or look(ns, 1).flare:IsShown() then fail(s, "dark: the flare is still up") end
	end)
end

do
	local s = name("the drink at rest on Forever shows only its dim icon, never a dim card")
	with(s, function(ns)
		Mock.playerLevel = 34
		Mock.manaSecret, Mock.mana = true, 100
		Mock.bags = { [3772] = 3 }
		K.event(ns, "BAG_UPDATE_DELAYED")
		K.tick(ns, 0.3)
		local l = look(ns, 11)
		if slot(ns, 11).state ~= "game" then fail(s, "not left to the game: " .. slot(ns, 11).state) return end
		if not l.hint:IsShown() then fail(s, "an armed drink is invisible") end
		if Mock.shownAlpha(l.hintCard.icon) <= 0 then fail(s, "the dim icon is not on the screen") end
		if l.hintCard.shot:IsShown() or l.hintCard.lines.name:IsShown() then fail(s, "a dim card sits there all the time") end
	end, { plain = false })
end
