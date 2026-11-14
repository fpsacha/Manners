-- The pictures tools/audit_look_contrast.py measures: one look, at one size,
-- taken through the moments that change what is behind the words or what
-- colour they are. Handed tools/render_prompt.lua's R (already loaded for the
-- look and the size) and whether this is the default size; returns a list of
-- cases, each { state =, reason =, snaps = { tree, ... } }.
--
-- Nothing here paints: every case is the addon driven as a scenario drives it
-- (render_prompt.lua's own helpers) and then photographed with R.snap.
local R, full = ...
local H = R.helpers

-- The class colours a name is written in, the hard ones among them: the
-- shaman's blue and the death knight's red are the darkest the game has, the
-- rogue's yellow and the priest's white the lightest. The mock has two.
RAID_CLASS_COLORS = {
	SHAMAN = { colorStr = "ff0070dd" }, DEATHKNIGHT = { colorStr = "ffc41e3a" }, PRIEST = { colorStr = "ffffffff" },
	ROGUE = { colorStr = "fffff468" }, MAGE = { colorStr = "ff3fc7eb" }, DRUID = { colorStr = "ffff7c0a" },
	WARLOCK = { colorStr = "ff8788ee" }, HUNTER = { colorStr = "ffaad372" }, WARRIOR = { colorStr = "ffc69b6d" },
	PALADIN = { colorStr = "fff48cba" },
}

local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" }, nameplate3 = { "Corwin", "Ash" } }
-- Each reason as the prompt paints it, with the class its name is coloured in.
-- "refresh" and "unknown" are the two reason lines that are not a reason of
-- their own: a top-up's, and a reading the client withheld.
local REASONS = {
	{ "target", { reason = "target", class = "SHAMAN" } },
	{ "owed", { reason = "owed", class = "PRIEST" } },
	{ "asked", { reason = "asked", class = "DEATHKNIGHT" } },
	{ "self", { reason = "self", class = "ROGUE" } },
	{ "group", { reason = "group", class = "MAGE" } },
	{ "nearby", { reason = "nearby", class = "DRUID" } },
	{ "refresh", { reason = "group", class = "WARLOCK", remaining = 240 } },
	{ "unknown", { reason = "nearby", class = "HUNTER", checked = true } },
}

local cases = {}
local function case(state, reason, snaps)
	cases[#cases + 1] = { state = state, reason = reason, snaps = snaps }
end

local ns = H.load()
H.boot(ns, CROWD)
local P = ns.Prompt
local p = ns.db.profile.prompt
p.effects, p.flashStyle, p.showIcon, p.hideInCombat, p.showQueue = "full", "pulse", true, false, false
P:ApplyStyle()
H.tick(ns)
Mock.advance(3)
FrameTree.settle()

local function wait(seconds)
	Mock.advance(seconds)
	FrameTree.settle()
	return R.snap(ns)
end

-- At rest, each reason painted on the panel: both palettes at the default
-- size, the passer-by alone at the others.
local buff = ns.ResolveBuff(true)
for _, palette in ipairs(full and { "standard", "colourblind" } or { "standard" }) do
	p.reasonPalette = palette
	P:ApplyStyle()
	H.tick(ns)
	Mock.advance(3)
	FrameTree.settle()
	for _, row in ipairs(REASONS) do
		if full or row[1] == "nearby" then
			local entry = { name = "Brannoc Vale", short = "Brannoc", buff = buff }
			for k, v in pairs(row[2]) do entry[k] = v end
			P:Paint(entry, 2)
			FrameTree.settle()
			case("rest" .. (palette == "colourblind" and " (colour-blind)" or ""), row[1], { R.snap(ns) })
		end
	end
end
p.reasonPalette = "standard"
P:ApplyStyle()

-- Somebody owed, the lights at three moments of their run: the arrival's
-- flash, the pulse on its way and at its top.
H.owe(ns, "Anna Aim")
H.tick(ns)
case("owed", "owed", { wait(0.15), wait(0.5), wait(0.6) })
Mock.advance(3)
FrameTree.settle()
H.tick(ns)

-- An outcome that succeeded: once the words have swapped (their cross-fade
-- is a fifth of a second of neither line), in its flash and after it.
P:ShowOutcome("cast", "Anna Aim")
case("succeeded", "owed", { wait(0.3), wait(0.4) })
Mock.advance(3)
FrameTree.settle()
H.tick(ns)

-- An outcome that was refused.
H.owe(ns, "Anna Aim")
H.tick(ns)
P:ShowOutcome("failed", "Anna Aim", "Out of range.")
case("refused", "owed", { wait(0.3), wait(0.4) })
Mock.advance(3)
FrameTree.settle()
H.tick(ns)

-- Under the cursor.
if full then
	local b = P:GetButton()
	if b.scripts.OnEnter then
		b.scripts.OnEnter(b)
		case("hover", "owed", { wait(0.3) })
		if b.scripts.OnLeave then b.scripts.OnLeave(b) end
		Mock.advance(1)
		FrameTree.settle()
	end
end

-- The list shown, two more owed under the first.
p.showQueue, p.queueRows = true, 3
H.owe(ns, "Brannoc Vale")
H.owe(ns, "Corwin Ash")
P:ApplyStyle()
H.tick(ns)
case("list", "owed", { wait(3) })
p.showQueue = false
P:ApplyStyle()
H.tick(ns)

-- In a fight, settled.
H.fight(ns)
case("fight", "owed", { R.snap(ns) })

H.restore()
return cases
