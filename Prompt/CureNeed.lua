-- Manners -- the cure button's "need" picture where the game alone knows: the
-- game's own aura display under each cure button (Prompt/CureFight.lua).
--
-- WHY. Where the client withholds auras from an addon in a fight (WoW Forever,
-- retail: caps.secretRestrictions), every read of a debuff comes back secret,
-- and on Forever 1.60.1 even the game's list of the harmful auras you can
-- remove throws for an addon ("Auras cannot be accessed when secret while
-- tainted"). Lua cannot know that somebody needs a cure. The game can: its
-- AuraContainer frame (Blizzard_AuraContainer, CustomAuraContainerTemplate,
-- made with allowUntaintedCreation, so an addon may create one and its inbound
-- methods run in the game's own environment) shows the auras of one unit that
-- pass a filter, secrets and all, and Lua never sees them.
--
-- WHAT IS MADE. For each cure button, out of combat and once:
--   holder   a plain frame of Lua's own on UIParent, over the cure button and
--            one level under it, so the button's alpha (0 while dark) does not
--            take it with it. Shown from the pull to the release.
--   wrap     a plain frame a unit (you, your target, focus, party1-4,
--            raid1-40), the holder's child: Lua shows the ones the fight
--            watches, and a target or focus only while it is a friend. Lua
--            never shows, hides or asks anything of the game's frames below.
--   box      CreateFrame("AuraContainer", nil, wrap, "CustomAuraContainerTemplate"),
--            SetUnit(unit), one aura slot ("need", filter "HARMFUL|RAID": the
--            harmful auras you can remove, the filter Blizzard's own dispel
--            displays use), narrowed to the button's kinds by
--            SetAuraSlotCandidateFilters({ includeDispelTypes = ... }) where the
--            button is for some kinds alone. The slot's frame (an AuraButton)
--            shows the debuff's icon and a border of its kind's colour; the game
--            shows and hides it, and Lua may not even ask it whether it is shown
--            in a fight (DenyTaintedAccessWhenAurasAreSecret).
--   mark     a ring and the cure's icon, dim, on the holder: the first of two
--            clicks (Prompt/CureFight.lua), drawn by Lua.
--
-- THE PROBE. Once, at the first button made, protected (setup): a container is
-- made and given a unit and a slot. If the client refuses any of it, or has no
-- such frame (the classic clients), nothing is made and the cure keeps its
-- reads; /manners debug and the self-test say which: "cure need: from the
-- game's aura display", "from the auras" (a client that hands auras back) or
-- "withheld" (and why).
--
-- COST. Nothing per event here. A container listens for UNIT_AURA of its unit
-- only while it is visible (the game's own rule, OnShow and OnHide), so outside
-- a fight, with the holder hidden, the boxes cost nothing.

local _, ns = ...
local caps = ns.caps
local plain = ns.plain

local CureNeed = {}
ns.CureNeed = CureNeed

local FILTER = "HARMFUL|RAID"
local SLOT = "need"
local RING = "Interface\\AddOns\\Manners\\Textures\\RingSq"

-- Every unit a fight may watch (Prompt/CureFight.lua, Watch).
local UNITS = { "player", "target", "focus" }
for i = 1, 4 do UNITS[#UNITS + 1] = "party" .. i end
for i = 1, 40 do UNITS[#UNITS + 1] = "raid" .. i end
CureNeed.UNITS = UNITS

-- nil until asked; true once the client made a container, false when it did
-- not (refused says why) or there was no need to ask.
local probed, refused
-- [index] = { holder, wraps = { [unit] = frame }, boxes = { [unit] = container },
-- kindsKey, ring, hint }
local needs = {}

-- The slot's frame, dressed as it is made (the game calls this before it locks
-- the frame): over its box, no mouse (the cure button above takes the click),
-- the aura's icon, and a border in the colour of its kind.
local function Dress(frame, box)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	if type(frame.EnableMouse) == "function" then pcall(frame.EnableMouse, frame, false) end
	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(frame)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	frame:SetIcon(icon)
	local styles = _G.Enum and _G.Enum.CustomAuraButtonDispelTypeTextureStyle
	if type(styles) == "table" and type(frame.AddDispelTypeTexture) == "function" then
		local edge = frame:CreateTexture(nil, "OVERLAY")
		edge:SetAllPoints(frame)
		pcall(frame.AddDispelTypeTexture, frame, edge, { style = styles.BorderWithIcon, showWhenHarmful = true })
	end
end

-- One container for `unit` under `parent`, with its slot. Throws where the
-- client refuses; the callers protect it (setup only).
local function MakeBox(parent, unit)
	local box = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
	if type(box) ~= "table" or type(box.SetUnit) ~= "function" or type(box.AddAuraSlot) ~= "function"
		or type(box.SetAuraSlotCandidateFilters) ~= "function" then
		error("the aura container has no unit, slot or filter")
	end
	box:SetAllPoints(parent)
	box:SetUnit(unit)
	box:AddAuraSlot(SLOT, FILTER, { initializeFrame = function(frame) Dress(frame, box) end })
	return box
end

-- Whether the game's aura display can stand in for the reads: asked once.
local function Probe()
	if probed ~= nil then return probed end
	if caps.secretRestrictions ~= true then
		probed = false
		return false
	end
	local holder = CreateFrame("Frame", nil, UIParent)
	holder:Hide()
	local ok, err = pcall(MakeBox, holder, "player")
	probed = ok == true
	if not ok then refused = tostring(err) end
	return probed
end

-- The holder of a button's boxes, made the first time (out of combat); nil
-- where the game's display is not to be had.
function CureNeed.Attach(index, button)
	if needs[index] then return needs[index] end
	if not Probe() then return nil end
	local holder = CreateFrame("Frame", nil, UIParent)
	-- The cure button's own strata (Prompt/CureFight.lua, Create).
	holder:SetFrameStrata("MEDIUM")
	holder:SetFrameLevel(math.max(0, (button:GetFrameLevel() or 1) - 1))
	holder:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	holder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	holder:Hide()
	local need = { holder = holder, wraps = {}, boxes = {} }
	local ok, err = pcall(function()
		for _, unit in ipairs(UNITS) do
			local wrap = CreateFrame("Frame", nil, holder)
			wrap:SetAllPoints(holder)
			wrap:Hide()
			need.wraps[unit] = wrap
			need.boxes[unit] = MakeBox(wrap, unit)
		end
	end)
	if not ok then
		probed, refused = false, tostring(err)
		return nil
	end
	-- The first of two clicks, on a frame of Lua's own above the boxes.
	local mark = CreateFrame("Frame", nil, holder)
	mark:SetAllPoints(holder)
	mark:SetFrameLevel(holder:GetFrameLevel() + 5)
	local hint = mark:CreateTexture(nil, "ARTWORK")
	hint:SetAllPoints(mark)
	hint:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	hint:SetAlpha(0.5)
	local ring = mark:CreateTexture(nil, "OVERLAY")
	ring:SetTexture(RING)
	ring:SetBlendMode("ADD")
	ring:SetPoint("TOPLEFT", mark, "TOPLEFT", -8, 8)
	ring:SetPoint("BOTTOMRIGHT", mark, "BOTTOMRIGHT", 8, -8)
	ring:SetVertexColor(1, 0.82, 0.2)
	mark:Hide()
	need.mark, need.hint = mark, hint
	needs[index] = need
	return need
end

-- Whether a button has the game's display under it.
function CureNeed.Has(index)
	return needs[index] ~= nil and probed == true
end

-- The kinds a button's boxes show (a set of the client's words: "Curse",
-- "Poison" ...), out of combat. Every box is told only when the set changed.
function CureNeed.SetKinds(index, kinds)
	local need = needs[index]
	if not need or probed ~= true then return end
	local names = {}
	for kind in pairs(kinds or {}) do names[#names + 1] = kind end
	table.sort(names)
	local key = table.concat(names, ",")
	if key == need.kindsKey then return end
	local ok, err = pcall(function()
		for _, unit in ipairs(UNITS) do
			local set = {}
			for i = 1, #names do set[names[i]] = true end
			need.boxes[unit]:SetAuraSlotCandidateFilters(SLOT, { includeDispelTypes = set })
		end
	end)
	if ok then
		need.kindsKey = key
	else
		probed, refused = false, tostring(err)
		need.holder:Hide()
	end
end

-- A unit's box is out while the fight does not watch it, and a target or focus
-- while it is not a friend (the game's filter would show an enemy's too).
local function WrapWanted(unit, watched)
	if not watched[unit] then return false end
	if unit == "target" or unit == "focus" then return plain(UnitCanAssist("player", unit)) == true end
	return true
end

-- A wrap put up or down, hidden first: the game's box does not follow a token
-- that now names somebody else (a new target or focus, party2 after a reshuffle;
-- Blizzard_AuraContainer listens for UNIT_AURA alone and leaves "target changes"
-- to whoever holds it), but redraws on its OnShow. A wrap already up is taken
-- down and put back, so the box draws the one the token names now.
local function Redraw(wrap, on)
	wrap:Hide()
	wrap:SetShown(on)
end

-- The pull, and the group changing in a fight: the holder up, a box for each
-- unit watched. Lua's own frames only. Answers whether the game shows the need.
function CureNeed.Begin(index, watched)
	local need = needs[index]
	if not need or probed ~= true then return false end
	for _, unit in ipairs(UNITS) do
		Redraw(need.wraps[unit], WrapWanted(unit, watched))
	end
	need.holder:Show()
	return true
end

-- Your target or focus changed in a fight.
function CureNeed.Retarget(index, unit, watched)
	local need = needs[index]
	if not need or probed ~= true then return end
	local wrap = need.wraps[unit]
	if wrap then Redraw(wrap, WrapWanted(unit, watched)) end
end

-- The release: every box down.
function CureNeed.End(index)
	local need = needs[index]
	if not need then return end
	need.holder:Hide()
	if need.mark then need.mark:Hide() end
end

-- The first of two clicks shown (the cure's icon, dim, and a ring), or put away.
function CureNeed.Mark(index, on, texture)
	local need = needs[index]
	if not (need and need.mark) then return end
	if on then need.hint:SetTexture(texture) end
	need.mark:SetShown(on == true)
end

-- Where the cure button learns who needs a cure, in words (/manners debug,
-- the self-test).
function CureNeed.Words()
	if caps.secretRestrictions ~= true then return "from the auras" end
	if probed == true then return "from the game's aura display" end
	if probed == nil then return "withheld (the game's aura display not asked yet)" end
	return "withheld (the game's aura display refused: " .. tostring(refused or "no reason given") .. ")"
end
