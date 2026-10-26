"""Listing images for CurseForge, Wago and the README, drawn by the renderers.

These used to be product shots painted by hand in Pillow, with the panel's
size and colours read out of Core.lua and everything else restated here. Every
restated detail was a way for the pictures to drift from the addon, and they
did: the panel they showed was an older look. Now nothing about the prompt, the
ledger or the options window is drawn here. tools/render_prompt.py,
tools/render_ledger.py and tools/render_options.py load the addon on the mock
client, put it into a state and draw the frame tree it built; this file only
chooses the states, lays the results out on a painted backdrop and writes the
captions. Three things are laid on afterwards, none of them the addon's to
draw: a tooltip's box and a mouse pointer (the words in the box are what the
addon told GameTooltip, with its colours), and a ring round a control of the
window (found in the frame tree).

    python tools/make-screenshots.py            # into .github/media
    python tools/make-screenshots.py --strict   # refuse to draw anything doubtful
    python tools/make-screenshots.py --out DIR --addon OTHER_TREE

What it writes, all 1280 pixels wide:

    manners-prompt.png     the moment your buff lands, rings and sweep
    manners-moment.png     film strips: they buffed you, it lands, it is refused
    manners-reasons.png    the five reasons somebody is offered, each in its colour
    manners-looks.png      the same favour in each of the six looks, named
    manners-ledger.png     the favour ledger with a day of ordinary play in it
    manners-languages.png  the prompt in German, French and Chinese
    manners-palette.png    the standard and the colour-blind reason colours
    manners-list.png       the list under the prompt, a name lit and its tooltip up
    manners-options.png    the options window on Who to buff, a buff order of its own
    manners-yourself.png   three prompts for the player's own buffs

Every player name is invented. Real names from a live session once reached a
draft of these images; they belong to real people and were scrubbed. Keep it
that way.

--strict refuses to write anything when a picture would show something other
than what it claims: a state the addon cannot build or that raised a guarded
error, the wrong person or the wrong reason on the prompt, a list that is not
the people and buffs the picture names or a name under the cursor the tooltip
is not about, a tooltip that no longer says what each click does, an options
window that fails render_options' own checks (text cut, rows overlapping,
a control off the window, contrast under 4.5:1) or whose buff order is not the
one shown, a ledger row the queue would never have produced, a line the client
would cut with an ellipsis, a translated picture still in English, a character
the font cannot draw (a Chinese line in a Latin face comes out as boxes), or no
TrueType face at all. Without it the same
problems are printed and the images are written anyway, so a local run still
shows what went wrong. CI runs it strictly.

Needs lupa, Pillow and numpy, as the renderers do. The Chinese picture needs a
CJK face: Microsoft YaHei on Windows, Noto Sans CJK on Linux (fonts-noto-cjk).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fonts  # noqa: E402 - the caption faces
import render_prompt as rp  # noqa: E402 - the prompt's drawing code

# render_ledger replaces render_prompt's layout class with its own reading of
# one unsettled anchoring case when it is imported. That reading is right for
# the ledger and deliberately not for the prompt, so both are kept and each
# picture is drawn with its own.
PromptTree = rp.Tree
import render_ledger as rl  # noqa: E402 - the ledger's drawing code
LedgerTree = rl.Tree
import render_options as ro  # noqa: E402 - the options window's drawing code

ROOT = rp.ROOT
OUT = os.path.join(ROOT, ".github", "media")
WIDTH = 1280
# The renderers draw at twice the size and scale down; the pictures here are
# composed at that size too, so the backdrop and the panels are shrunk together.
SS = rp.SUPER

# The client language each translated picture is drawn in, and the name the
# picture gives it. The spell name is what that client calls Arcane Intellect:
# the mock answers in English for every client, and a German prompt offering
# "Arcane Intellect" is a picture of a client that does not exist.
LANGUAGES = [
    ("deDE", "Deutsch", "Arkane Intelligenz"),
    ("frFR", "Français", "Intelligence des Arcanes"),
    ("zhCN", "简体中文", "奥术智慧"),
]

# Faces with the Chinese glyphs in, by platform. Latin text drawn with them is
# still text; the Latin faces render_prompt prefers have no Chinese at all.
CJK_REGULAR = [
    r"C:\Windows\Fonts\msyh.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/google-noto-cjk/NotoSansCJK-Regular.ttc",
    "/System/Library/Fonts/PingFang.ttc",
]
CJK_BOLD = [
    r"C:\Windows\Fonts\msyhbd.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/google-noto-cjk/NotoSansCJK-Bold.ttc",
    "/System/Library/Fonts/PingFang.ttc",
] + CJK_REGULAR
CJK_LOCALES = ("zhCN", "zhTW", "koKR")
LATIN_REGULAR = list(rp.FONT_CANDIDATES)
LATIN_BOLD = list(rp.BOLD_CANDIDATES)

problems = []


def problem(msg):
    if msg not in problems:
        problems.append(msg)
        print("  problem: " + msg, file=sys.stderr)


# ---------------------------------------------------------------- states
#
# The renderers' own states are built to test the look -- one person each, or
# the same four names over and over. The listing pictures want a scene, so they
# have states of their own, added to the renderers' lists at run time. They
# drive the addon the way render_prompt.lua's do, through the handlers and
# entry points the client and Core would call, and never paint anything.
#
# Each prompt state leaves the person the addon put on top, and why, in
# ShotTop, so the run can check the picture shows what its caption says.

# The spell API the states and the options window are drawn over, shared by
# both chunks: the mock names every spell it does not know Arcane Intellect and
# gives every spell the same icon. These are the names the pictures need
# besides its own (a mage's armor), and the icon each spell is shown with,
# keyed by the name the client gives it. An icon is a file id the pictures
# paint an emblem for (EMBLEMS, below): the id is the client's, the art is ours.
SPELL_LUA = r"""
local OWN_NAMES = {}
for _, id in ipairs({ 10220, 10219, 7320, 7302, 7301, 7300, 168 }) do OWN_NAMES[id] = "Frost Armor" end
local ICONS = {
	["Blessing of Wisdom"] = 135970,
	["Blessing of Kings"] = 135995,
	["Blessing of Might"] = 135906,
	["Blessing of Salvation"] = 135969,
	["Blessing of Light"] = 135944,
	["Frost Armor"] = 135843,
}

-- The mock's spell API with those over it. `translated` is what this client
-- calls Arcane Intellect, or nothing.
local function spellApi(translated)
	rawset(_G, "C_Spell", nil)
	local base = C_Spell
	local api = {}
	for k, v in pairs(base) do api[k] = v end
	api.GetSpellName = function(id)
		local name = OWN_NAMES[id] or base.GetSpellName(id)
		if name == "Arcane Intellect" and translated and translated ~= "" then return translated end
		return name
	end
	api.GetSpellTexture = function(id)
		return ICONS[OWN_NAMES[id] or base.GetSpellName(id)] or base.GetSpellTexture(id)
	end
	return api
end
"""

PROMPT_STATES = r"""
local R, spellName = ...

-- What the states below change in the mock, each as the mock has it: every
-- state is put back to these before it runs (see the end), so a paladin in one
-- picture is never the paladin in the next.
local realUnitClass, realPowerMax = UnitClass, UnitPowerMax
local realKnown, realPlayerSpell = IsSpellKnown, IsPlayerSpell
local realLevel, realInventoryItem = rawget(_G, "UnitLevel"), rawget(_G, "GetInventoryItemID")
local realTip = { GameTooltip.SetOwner, GameTooltip.AddLine, GameTooltip.AddDoubleLine }

local function people(names)
	Mock.unitNames = names
	UnitExists = function(unit)
		if unit == "player" then return true end
		return names[unit] ~= nil
	end
end

-- The mock says "in my party" for every unit once there is a group at all; a
-- picture of the list wants the party to be the party tokens and nobody else.
local function partyIsParty()
	UnitInParty = function(unit) return type(unit) == "string" and unit:find("^party") ~= nil end
	UnitInSubgroup = UnitInParty
end

--SPELLS

-- What this client calls the buff, and the icons and names the mock lacks,
-- put in front of the mock, which answers in English whatever the language.
-- A table left from the last state is taken away first, so the mock's own
-- comes back underneath.
local function spells()
	rawset(_G, "C_Spell", spellApi(spellName))
end

-- Who each unit is, for the pictures that give different people different
-- buffs: the mock calls every unit a priest with a mana bar. A warrior or a
-- rogue has none, which is what sends a paladin's Wisdom to somebody else.
local function classes(map)
	UnitClass = function(unit)
		local class = map[unit]
		if not class then return realUnitClass(unit) end
		return class:sub(1, 1) .. class:sub(2):lower(), class
	end
	UnitPowerMax = function(unit, ...)
		local class = map[unit]
		if class == "WARRIOR" or class == "ROGUE" then return 0 end
		return realPowerMax(unit, ...)
	end
end

-- What the player has learned: the ranks of those of the class's buffs for
-- others named by key, and any other spell ids.
local function know(ns, class, keys, ids)
	local set = {}
	for _, id in ipairs(ids or {}) do set[id] = true end
	for _, key in ipairs(keys or {}) do
		local buff = ns.FindBuff(class, key)
		for _, id in ipairs(buff and buff.ranks or {}) do set[id] = true end
	end
	IsSpellKnown = function(id) return set[id] == true end
	IsPlayerSpell = IsSpellKnown
end

-- What the tooltip is told, kept with its colours: the mock keeps the words
-- alone. The picture draws the box; every word in it is the addon's.
local function recordTooltip()
	ShotTip = nil
	GameTooltip.SetOwner = function(self, owner, anchor)
		realTip[1](self, owner, anchor)
		ShotTip = { anchor = anchor, owner = type(owner) == "table" and owner._serial or nil, lines = {} }
	end
	GameTooltip.AddLine = function(self, text, r, g, b, wrap)
		realTip[2](self, text)
		if ShotTip then
			ShotTip.lines[#ShotTip.lines + 1] = { text = tostring(text), r = r, g = g, b = b, wrap = wrap and true or false }
		end
	end
	GameTooltip.AddDoubleLine = function(self, left, right, lr, lg, lb, rr, rg, rb)
		realTip[3](self, left, right)
		if ShotTip then
			ShotTip.lines[#ShotTip.lines + 1] = { left = tostring(left), right = tostring(right),
				lr = lr, lg = lg, lb = lb, rr = rr, rg = rg, rb = rb }
		end
	end
end

-- As render_prompt.lua boots: up with nobody about, well past the login and
-- every cooldown, and the nameplates the state names known to the scan.
local function boot(ns, names)
	spells()
	people(names)
	ns.addon:OnInitialize()
	ns.addon:OnEnable()
	ns.addon:PLAYER_ENTERING_WORLD()
	Mock.runTimers(3)
	Mock.advance(60)
	wipe(ns.owed)
	wipe(ns.tried)
	ns.pendingClick = nil
	for unit in pairs(names) do
		if unit:find("^nameplate") then ns.nameplateUnits[unit] = true end
	end
	ns.Guard("probe", ns.ProbeCapabilities)
	return ns
end

-- The panel a little wider than the default, for the moments that name
-- Elowen Thistledown in full: "could not buff Elowen Thistledown" is cut at
-- 220 with the fonts CI draws with, and the strip's rows keep one size.
local function roomy(ns)
	ns.db.profile.prompt.width = 260
end

local function owe(ns, name, class)
	ns.owed[name] = { expires = GetTime() + 100, at = GetTime(), class = class or "PRIEST" }
end

-- Somebody asking for the buff in /say, as the client delivers the line.
local function ask(ns, name, unit, line)
	ns.addon:CHAT_MSG_SAY("CHAT_MSG_SAY", line or "int pls?", name, "Common", "", "", "", 0, 0, "", 0, 1,
		"Player-1-" .. unit)
end

local function settle(ns)
	ns.Prompt:ApplyStyle()
	ns.addon:Tick()
	FrameTree.settle()
	local queue = ns.BuildQueue()
	local top = queue[1]
	ShotTop = top and { name = top.name, reason = top.reason } or false
	-- Everybody the addon would offer, in order, and what each would get.
	ShotQueue = {}
	for i, entry in ipairs(queue) do
		ShotQueue[i] = { name = entry.name, reason = entry.reason, buff = entry.buff and entry.buff.key or false }
	end
end

local function list(ns, rows)
	ns.db.profile.prompt.showQueue = true
	ns.db.profile.prompt.queueRows = rows
end

local ELOWEN = { "Elowen", "Thistledown" }
local BRAM = { "Bram", "Cinderfell" }
local MARIBEL = { "Maribel", "Quickwater" }
local OSKAR = { "Oskar", "Fenwick" }
local SABLE = { "Sable", "Harrow" }
-- Short names for the rows under a translated prompt. A row has a fixed width
-- and German and French need most of it for the reason, so a long name there
-- only shows the reason being cut.
local MIRA = { "Mira", "Holt" }
local IVO = { "Ivo", "Lark" }
local TAM = { "Tam", "Rook" }

-- The mouse on a name in the list, as the client does it: the row's own
-- OnEnter lights it and puts the tooltip up (Prompt/Button.lua).
local function hover(ns, n)
	local button = ns.Prompt:Regions().rowButtons[n]
	local onEnter = button:GetScript("OnEnter")
	onEnter(button)
	FrameTree.settle()
	ShotHover = { id = button._serial, row = n }
end

-- A weapon in each hand and what the bags hold, as the client answers about
-- them: the mock's item API is the weapon's enchants alone. Item ids are
-- Buffs.lua's; the dagger is a made-up id of subclass 15, as GetItemInfoInstant
-- answers one.
local INSTANT_POISON, DAGGER = 8928, 900015
local ITEMS = {
	[INSTANT_POISON] = { name = "Instant Poison VI", icon = 132273 },
	[DAGGER] = { weapon = 15 },
}
local function carrying(counts, hands, level)
	rawset(_G, "C_Item", nil)
	local base = C_Item
	local api = {}
	for k, v in pairs(base or {}) do api[k] = v end
	api.GetItemCount = function(id) return counts[id] or 0 end
	api.GetItemNameByID = function(id) return ITEMS[id] and ITEMS[id].name end
	api.RequestLoadItemDataByID = function() end
	api.GetItemIconByID = function(id) return ITEMS[id] and ITEMS[id].icon end
	api.GetItemInfoInstant = function(id)
		local item = ITEMS[id] or {}
		if item.weapon then return id, "Weapon", "", "INVTYPE_WEAPON", 135932, 2, item.weapon end
		return id, "Miscellaneous", "", "", item.icon or 135932, 15, 0
	end
	rawset(_G, "C_Item", api)
	rawset(_G, "GetInventoryItemID", function(unit, slot)
		if unit == "player" then return hands[slot] end
	end)
	rawset(_G, "UnitLevel", function(unit)
		if unit == "player" then return level end
		return 12
	end)
end

local added = {
	-- The hero: a favour to return, the pulse near its brightest.
	{ key = "shot-owed", at = 0.85, setup = function(ns)
		boot(ns, { nameplate1 = ELOWEN })
		owe(ns, "Elowen Thistledown")
		settle(ns)
	end },
	-- The hero's moment: that same favour returned, the cast confirmed. The
	-- queue is read before the outcome is painted, so ShotTop is still the
	-- favour the button was about to return; what the prompt then shows is
	-- the addon's own outcome for a buff that landed. The time is where the
	-- landing reads best: the rings off the icon spread, the sweep crossing
	-- the panel, the words fully drawn.
	{ key = "shot-landed", at = 0.20, setup = function(ns)
		boot(ns, { nameplate1 = ELOWEN })
		roomy(ns)
		owe(ns, "Elowen Thistledown")
		settle(ns)
		ns.Prompt:ShowOutcome("cast", "Elowen Thistledown")
		FrameTree.settle()
	end },
	-- The three moments of the film strip, each from the one favour: it
	-- arrives, the buff lands, the game refuses it. Which frame is taken is
	-- the picture's choice (`--at`), not the state's.
	{ key = "shot-moment-arrival", at = 0.05, setup = function(ns)
		boot(ns, { nameplate1 = ELOWEN })
		roomy(ns)
		owe(ns, "Elowen Thistledown")
		settle(ns)
	end },
	{ key = "shot-moment-refused", at = 0.15, setup = function(ns)
		boot(ns, { nameplate1 = ELOWEN })
		roomy(ns)
		owe(ns, "Elowen Thistledown")
		settle(ns)
		ns.Prompt:ShowOutcome("failed", "Elowen Thistledown", "Out of range.")
		FrameTree.settle()
	end },
	{ key = "shot-target", at = 0.85, setup = function(ns)
		boot(ns, { target = BRAM })
		settle(ns)
	end },
	{ key = "shot-asked", at = 0.85, setup = function(ns)
		boot(ns, { nameplate1 = MARIBEL })
		ns.db.profile.sources.asked = true
		ask(ns, "Maribel Quickwater", "nameplate1")
		settle(ns)
	end },
	{ key = "shot-group", at = 0.85, setup = function(ns)
		Mock.groupSize = 2
		partyIsParty()
		boot(ns, { party1 = OSKAR })
		settle(ns)
	end },
	{ key = "shot-nearby", at = 0.85, setup = function(ns)
		boot(ns, { nameplate1 = SABLE })
		settle(ns)
	end },
	-- A favour on top and three more behind it, each a sentence the
	-- translation had to say: what the translated pictures show. The third is
	-- a second favour rather than a passer-by, because a passer-by's line
	-- names the spell, and a long translation of "needs Arcane Intellect" does not
	-- fit a row at the default width -- the addon cuts it with an ellipsis,
	-- which is true and not what a picture of the translation is for.
	{ key = "shot-list", at = 0.85, setup = function(ns)
		Mock.groupSize = 2
		partyIsParty()
		boot(ns, { nameplate1 = ELOWEN, nameplate2 = MIRA, party1 = TAM, nameplate3 = IVO })
		ns.db.profile.sources.asked = true
		list(ns, 3)
		owe(ns, "Elowen Thistledown")
		Mock.advance(20)
		owe(ns, "Ivo Lark", "DRUID")
		ask(ns, "Mira Holt", "nameplate2")
		settle(ns)
	end },
	-- The list with a name under the cursor. A paladin on Forever, with the
	-- buff order Who to buff shows in its own picture (Wisdom first): a caster
	-- is offered Wisdom and a fighter Kings, so the icons beside the names are
	-- not all one. Five people, five reasons: the target on the panel, the
	-- other four in the list, and the cursor on the second.
	{ key = "shot-click", at = 0.85, setup = function(ns)
		Mock.class = "PALADIN"
		Mock.groupSize = 2
		partyIsParty()
		classes({ target = "WARRIOR", nameplate1 = "DRUID", nameplate2 = "ROGUE",
			party1 = "PALADIN", nameplate3 = "ROGUE" })
		know(ns, "PALADIN", { "wisdom", "might", "kings", "salvation", "light" })
		boot(ns, { target = BRAM, nameplate1 = ELOWEN, nameplate2 = MARIBEL, party1 = OSKAR,
			nameplate3 = SABLE })
		recordTooltip()
		ns.db.profile.sources.asked = true
		list(ns, 4)
		ns.MoveBuff("wisdom", -1)
		owe(ns, "Elowen Thistledown", "DRUID")
		ask(ns, "Maribel Quickwater", "nameplate2", "kings pls?")
		settle(ns)
		hover(ns, 2)
	end },
	-- A mage with Arcane Intellect up and no armor.
	{ key = "shot-self-armor", at = 0.85, setup = function(ns)
		Mock.class = "MAGE"
		know(ns, "MAGE", { "intellect" }, { 168 })
		Mock.playerHeld = { [10157] = true, [10156] = true, [1461] = true, [1460] = true, [1459] = true }
		boot(ns, {})
		settle(ns)
	end },
	-- A rogue with a poison in the bags and a bare dagger in each hand.
	{ key = "shot-self-poison", at = 0.85, setup = function(ns)
		Mock.class = "ROGUE"
		carrying({ [INSTANT_POISON] = 2 }, { [16] = DAGGER, [17] = DAGGER }, 60)
		know(ns, "ROGUE", {}, {})
		boot(ns, {})
		settle(ns)
	end },
	-- A mage who has dropped her own Arcane Intellect: the buff she gives
	-- everybody else, come round to her.
	{ key = "shot-self-intellect", at = 0.85, setup = function(ns)
		Mock.class = "MAGE"
		know(ns, "MAGE", { "intellect" })
		Mock.playerHeld = {}
		boot(ns, {})
		ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
		settle(ns)
	end },
	-- Four of the reasons on screen at once, in either palette: the four the
	-- caption names.
	{ key = "shot-palette-standard", at = 0.85, setup = function(ns)
		Mock.groupSize = 2
		partyIsParty()
		boot(ns, { target = BRAM, nameplate1 = ELOWEN, party1 = OSKAR, nameplate2 = SABLE })
		list(ns, 3)
		owe(ns, "Elowen Thistledown")
		settle(ns)
	end },
	{ key = "shot-palette-colourblind", at = 0.85, setup = function(ns)
		Mock.groupSize = 2
		partyIsParty()
		boot(ns, { target = BRAM, nameplate1 = ELOWEN, party1 = OSKAR, nameplate2 = SABLE })
		list(ns, 3)
		ns.db.profile.prompt.reasonPalette = "colourblind"
		owe(ns, "Elowen Thistledown")
		settle(ns)
	end },
}
-- The same moment in every look the Look tab offers: a favour to return, two
-- passers-by waiting behind it (the count), and a key bound to the prompt, as
-- most players who use it have -- the looks that show the key only show it
-- with one bound. ShotStyle is the look the profile ends up on, so a look the
-- addon refused or put back is caught rather than drawn under another's name.
for _, style in ipairs({ "glass", "framed", "minimal", "luxe", "toast", "arcane", "ribbon", "letter", "leather" }) do
	added[#added + 1] = { key = "shot-look-" .. style, at = 0.85, setup = function(ns)
		Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
		boot(ns, { nameplate1 = ELOWEN, nameplate2 = SABLE, nameplate3 = MIRA })
		ns.db.profile.prompt.style = style
		owe(ns, "Elowen Thistledown")
		settle(ns)
		ns.ClampSettings()
		ShotStyle = ns.db.profile.prompt.style
	end }
end
-- Every state starts from the mock as it was: what an earlier one made of the
-- classes, the spellbook, the bags and the tooltip is put back first.
local function restore()
	UnitClass, UnitPowerMax = realUnitClass, realPowerMax
	IsSpellKnown, IsPlayerSpell = realKnown, realPlayerSpell
	rawset(_G, "C_Item", nil)
	rawset(_G, "UnitLevel", realLevel)
	rawset(_G, "GetInventoryItemID", realInventoryItem)
	GameTooltip.SetOwner, GameTooltip.AddLine, GameTooltip.AddDoubleLine = realTip[1], realTip[2], realTip[3]
	ShotTip, ShotHover, ShotQueue = nil, nil, nil
end
for _, state in ipairs(added) do
	local setup = state.setup
	state.setup = function(ns)
		restore()
		return setup(ns)
	end
	state.title = state.key
	table.insert(R.states, state)
end
"""
PROMPT_STATES = PROMPT_STATES.replace("--SPELLS\n", SPELL_LUA)

# The options window's, added to render_options.lua's in the same way: the
# spell icons put in front of the mock's one for all (re-read by the probe,
# which asked for them at login), and, once the window is open, where the buff
# order's rows and arrows are, and in what order the rows stand, so the run
# can check the picture shows the order it says.
OPTIONS_STATES = r"""
local R = ...
--SPELLS

R.BEFORE.icons = function(ns)
	rawset(_G, "C_Spell", spellApi(nil))
	ns.Guard("probe", ns.ProbeCapabilities)
end

-- A key on the prompt, as most players who use it have: without one the Start
-- here page carries a red dot, which says the setup is not done.
R.BEFORE.keybound = function()
	Mock.bindings = { F = "CLICK MannersPrompt:LeftButton" }
end

R.AFTER.locate = function(ns)
	local row = ns.WindowUI.RowFor("who.orderPick")
	ShotOrder = { list = row.list._serial, lines = {} }
	for i, line in ipairs(row.lines) do
		ShotOrder.lines[i] = { key = line.key, up = line.up._serial, down = line.down._serial }
	end
end
"""
OPTIONS_STATES = OPTIONS_STATES.replace("--SPELLS\n", SPELL_LUA)

# A day of ordinary play, oldest first, through Ledger.lua's own entry points:
# favours returned, one still owed, one that ran out, one nothing you cast
# could return, buffs given to the group and to strangers.
#
# The ledger is written to directly, which skips the addon's judgement of who
# can be offered anything: a row saying Arcane Intellect went to a warrior is a
# row the addon never writes, and one was drawn four rows under a warrior it
# said nothing could reach. So every person here is also put to the queue, the
# way it weighs a favour it has no unit token for -- by class alone -- and a row
# the queue disagrees with is recorded in ShotDoubts for the run to report.
LEDGER_STATES = r"""
local R = ...

-- Whether the queue would offer this person anything. A debt with no token is
-- the one path that judges somebody by class and nothing else, so it asks the
-- addon's own question without restating which classes have mana.
local function offered(ns, name, class)
	local saved = ns.owed[name]
	ns.owed[name] = { expires = GetTime() + 100, at = GetTime(), class = class }
	local found = false
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then found = true end
	end
	ns.owed[name] = saved
	return found
end

local function doubt(msg)
	ShotDoubts[#ShotDoubts + 1] = msg
end

local function received(ns, name, class, spell, useless)
	-- A useless favour is one nothing you cast could return; any other is one
	-- the prompt would have offered to pay back.
	if offered(ns, name, class) == (useless == true) then
		doubt(name .. " (" .. class .. ") is drawn as "
			.. (useless and "beyond anything you cast" or "a favour you could return")
			.. ", and the queue says otherwise")
	end
	ns.Ledger.Received({ name = name, class = class, key = spell }, useless)
end
local function returned(ns, name, ago)
	ns.Ledger.Settled(name, { at = GetTime() - ago }, { buffKey = "intellect" }, 1459)
end
local function gave(ns, name, class, inGroup)
	if not offered(ns, name, class) then
		doubt(name .. " (" .. class .. ") is drawn as given Arcane Intellect, "
			.. "which the queue would never offer them")
	end
	ns.Ledger.Settled(name, nil, { inGroup = inGroup, class = class }, 1459)
end

local function day(ns)
	received(ns, "Isolde Brightwind", "PALADIN", 20217)
	Mock.advance(40)
	returned(ns, "Isolde Brightwind", 40)
	Mock.advance(3 * 3600)
	gave(ns, "Pell Ambersong", "HUNTER", false)
	Mock.advance(300)
	gave(ns, "Nadia Coldbrook", "WARLOCK", false)
	Mock.advance(2400)
	received(ns, "Faelan Dunmere", "DRUID", 1126)
	Mock.advance(900)
	ns.Ledger.LetGo("Faelan Dunmere")
	Mock.advance(3600)
	-- The group's two have mana: Arcane Intellect is no use to anybody
	-- without, and the prompt does not offer it to them.
	gave(ns, "Oskar Fenwick", "PALADIN", true)
	Mock.advance(15)
	gave(ns, "Wren Tallowmere", "HUNTER", true)
	Mock.advance(1200)
	received(ns, "Korwin Blackbriar", "WARRIOR", 6673, true)
	Mock.advance(900)
	received(ns, "Rowan Ashvale", "PRIEST", 21562)
	Mock.advance(25)
	returned(ns, "Rowan Ashvale", 25)
	Mock.advance(600)
	gave(ns, "Sable Harrow", "SHAMAN", false)
	Mock.advance(400)
	received(ns, "Elowen Thistledown", "DRUID", 1126)
	Mock.advance(30)
end

table.insert(R.states, { key = "shot-ledger", title = "shot-ledger", setup = function(ns)
	day(ns)
	-- Months of play behind the day, so the title at the top is one worth
	-- showing: the lifetime counts are kept apart from the list, which holds
	-- only its last 200 rows, so these stand beside it as they would in game.
	local t = ns.db.char.ledger.totals
	t.received, t.returned, t.letGo, t.group, t.strangers = 164, 137, 21, 58, 212
	ns.addon:HandleSlash("ledger")
end })
"""


def fwd(p):
    return p.replace("\\", "/")


def prompt_states(addon_dir, locale="", spell_name=""):
    """render_prompt.lua, loaded as render_prompt.load_states loads it, with the
    listing states added. Loaded here rather than through load_states because
    the states are compiled in the same Lua runtime, which that hides."""
    lua = rl.lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().print = lambda *a: None
    run = lua.eval("function(path, dir, addon, locale) "
                   "local f = assert(loadfile(path)) return f(dir, addon, locale) end")
    R = run(fwd(os.path.join(ROOT, "tools", "render_prompt.lua")), fwd(ROOT), fwd(addon_dir),
            locale)
    # The width the addon is told a line is, as render_prompt sets it: the
    # face this picture draws with, so a line it shrank to fit is drawn fitting.
    lua.globals().FrameTree.measure = lambda text, size: (
        rp.get_font(float(size) * 4).getlength(rp.plain_text(text)) / 4)
    lua.compile(PROMPT_STATES)(R, spell_name)
    return lua, R


def ledger_states(addon_dir):
    lua = rl.lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().print = lambda *a: None
    run = lua.eval("function(path, dir, addon, measure) "
                   "local f = assert(loadfile(path)) return f(dir, addon, measure) end")
    R = run(fwd(os.path.join(ROOT, "tools", "render_ledger.lua")), fwd(ROOT), fwd(addon_dir),
            rl.measure)
    lua.compile(LEDGER_STATES)(R)
    return lua, R


def options_states(addon_dir, cls):
    """render_options.lua, loaded as render_options.load loads it, as the
    class `cls`, with the listing's states added. Loaded here rather than
    through render_options.load because the states are compiled in the same
    Lua runtime, which that hides."""
    lua = ro.lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().print = lambda *a: None
    run = lua.eval("function(path, dir, addon, locale, class, measure, wrap) "
                   "local f = assert(loadfile(path)) return f(dir, addon, locale, class, measure, wrap) end")
    R = run(fwd(os.path.join(ROOT, "tools", "render_options.lua")), fwd(ROOT), fwd(addon_dir),
            "", cls, ro.measure, ro.lua_wrap)
    lua.compile(OPTIONS_STATES)(R)
    return lua, R


def use_faces(locale):
    """Point render_prompt at a face that has the language's script in it."""
    if locale in CJK_LOCALES:
        rp.FONT_CANDIDATES[:] = CJK_REGULAR + LATIN_REGULAR
        rp.BOLD_CANDIDATES[:] = CJK_BOLD + LATIN_BOLD
    else:
        rp.FONT_CANDIDATES[:] = LATIN_REGULAR
        rp.BOLD_CANDIDATES[:] = LATIN_BOLD
    rp._font_cache.clear()


def snap_of(R, lua, key, *args):
    """One state's snapshot, or None with the reason recorded."""
    lua.globals().ShotTop = None
    lua.globals().ShotQueue = None
    lua.globals().ShotHover = None
    lua.globals().ShotTip = None
    try:
        snap = R["run"](key, *args)
    except Exception as e:  # noqa: BLE001 - a Lua error is a state that cannot be built
        problem("%s: the addon could not be put into this state: %s" % (key, e))
        return None, None
    if snap is None:
        problem("%s: the renderer has no such state" % key)
        return None, None
    snap = rp.to_py(snap)
    if snap.get("errors"):
        problem("%s: %d guarded error(s), first %s" % (key, snap["errors"], snap.get("firstError")))
    top = rp.to_py(lua.globals().ShotTop)
    return snap, top if isinstance(top, dict) else None


def shown_texts(snap, tree_class):
    tree = tree_class(snap)
    out = []
    for r in tree.regions.values():
        if r["kind"] != "FontString" or not r.get("text"):
            continue
        if not all(c.get("shown", True) for c in tree.chain(r)):
            continue
        if (r.get("alpha") if r.get("alpha") is not None else 1) <= 0:
            continue
        out.append(rp.plain_text(r["text"]).strip())
    return [t for t in out if t]


def expect_top(key, top, name, reason):
    if not top:
        problem("%s: nobody is on the prompt; the picture would show it empty" % key)
    elif top.get("name") != name or top.get("reason") != reason:
        problem("%s: the prompt shows %s (%s), not %s (%s)"
                % (key, top.get("name"), top.get("reason"), name, reason))


def expect_names(key, texts, names):
    # Read without case: a look may set names in capitals.
    joined = "\n".join(texts).lower()
    for name in names:
        if name.lower() not in joined:
            problem("%s: %s is not drawn anywhere on it" % (key, name))


# ---------------------------------------------------------------- glyphs

_notdef = {}
_glyph = {}


def missing_glyphs(path, text):
    """The characters of `text` the face at `path` draws as its missing-glyph
    box. Pillow draws whatever the face gives it without complaint, so a
    Chinese line in a Latin face is a row of identical boxes that nothing else
    would notice."""
    if path is None:
        return sorted(set(c for c in text if not c.isspace()))
    font = ImageFont.truetype(path, 24)
    if path not in _notdef:
        # A private-use character no face used here defines.
        _notdef[path] = bytes(font.getmask("\U0010FFFD"))
    out = set()
    for c in set(text):
        if c.isspace() or c == "\u200b":
            continue
        key = (path, c)
        if key not in _glyph:
            _glyph[key] = bytes(font.getmask(c)) == _notdef[path]
        if _glyph[key]:
            out.add(c)
    return sorted(out)


def check_glyphs(key, texts):
    for bold in (False, True):
        path = rp.font_path(bold)
        if path is None:
            problem("%s: no TrueType face is installed; the renderer would draw the bitmap "
                    "default" % key)
            return
        gone = missing_glyphs(path, "".join(texts))
        if gone:
            problem("%s: %s cannot draw %s -- it would come out as boxes"
                    % (key, os.path.basename(path), "".join(gone[:12])))


# ---------------------------------------------------------------- layers

# Set while a layer is drawn: the flat colour the renderer's backdrop is
# replaced with, and the canvas it left behind, before it was clipped.
_matte = [None]
_last = [None]
_backdrop = rp.Canvas.backdrop
_image = rp.Canvas.image


def _matte_backdrop(self, kind=None, seed=7):
    if _matte[0] is None:
        return _backdrop(self, kind, seed)
    self.rgb[:] = _matte[0]


def _keep_image(self):
    _last[0] = self.rgb.copy()
    return _image(self)


rp.Canvas.backdrop = _matte_backdrop
rp.Canvas.image = _keep_image

# The lines drawn cut while the current layer is drawn. The addon leaves a
# line that does not fit to the client, which cuts it and adds an ellipsis, so
# the text the addon set is whole and only the drawing shows the cut: a
# translated passer-by row once went out cut short with every check on the
# text passing. The test is the one render_prompt.draw_text cuts
# on, asked before it draws; the ledger's single lines go through it as well.
_cut = []
_draw_text = rp.draw_text


def _noting_cuts(canvas, tree, r, box, alpha, px, grown=1.0):
    text = r.get("text")
    width = box[2] - box[0]
    if text is not None and r.get("wordWrap") is False and width > 0:
        font = r.get("font") or {}
        f = rp.get_font((font.get("size") or 12) * tree.eff_scale(r) * px)
        full = "".join(p[0] for p in rp.runs(str(text), (1, 1, 1, 1)))
        if f.getlength(full) > width + 0.5:
            _cut.append(rp.plain_text(text).strip())
    return _draw_text(canvas, tree, r, box, alpha, px, grown)


rp.draw_text = _noting_cuts


class Layer:
    """A drawn UI element that can be laid over any backdrop.

    Every way the renderer puts a region on its canvas -- blended, added,
    multiplied -- is linear in what was there before. So drawing the same
    frames once over black and once over white gives, per pixel, what the UI
    adds (`add`) and how much of the world shows through (`through`), and over
    any backdrop the result is add + through * backdrop, exactly: the glow, the
    translucent panel and the text over it land on the painted world as they
    would have been drawn on it. Kept at the renderer's supersampled size and
    cropped to what the UI covers."""

    def __init__(self, draw, key, frame=None):
        del _cut[:]
        _matte[0] = 0.0
        draw()
        black = _last[0]
        _matte[0] = 1.0
        draw()
        white = _last[0]
        _matte[0] = None
        for line in _cut:
            problem("%s: a line is drawn cut: %s" % (key, line))
        add, through = black, np.clip(white - black, 0, 1)
        covered = (add.max(axis=2) > 1.5 / 255) | (through.min(axis=2) < 1 - 1.5 / 255)
        ys, xs = np.nonzero(covered)
        pad = 2 * SS
        y0, y1 = max(0, ys.min() - pad), min(add.shape[0], ys.max() + 1 + pad)
        x0, x1 = max(0, xs.min() - pad), min(add.shape[1], xs.max() + 1 + pad)
        self.add = add[y0:y1, x0:x1]
        self.through = through[y0:y1, x0:x1]
        # Where the screen is on it: the screen point at the top left of what
        # was drawn and the pixels to a unit (the prompt's renderer leaves
        # them on draw_state; the options window's are handed in), and how
        # much was cropped off, so a point in screen units can be found on
        # the layer afterwards.
        self.frame = frame or getattr(rp.draw_state, "frame", None)
        self.crop = (x0, y0)

    @property
    def size(self):
        """Width and height in output pixels."""
        return self.add.shape[1] / SS, self.add.shape[0] / SS

    def at(self, x, y):
        """Where the screen point (x, y), in UI units with y up, is on this
        layer, in output pixels from its top left."""
        left, top, px = self.frame
        return ((x - left) * px - self.crop[0]) / SS, ((top - y) * px - self.crop[1]) / SS


def pixels(zoom):
    """Renderer pixels per UI unit for a zoom, which has to be whole. The
    addon fits its lines to widths measured at the true font size, and the
    renderer opens its face at a whole-pixel size: at a fractional scale a
    label rounds a hair wider than it was measured and is drawn cut with an
    ellipsis the game would never show ("All ti..." for "All time")."""
    px = zoom * SS
    if px != int(px):
        raise ValueError("zoom %s gives %s pixels per unit, not a whole number" % (zoom, px))
    return int(px)


def prompt_layer(key, snap, zoom):
    rp.Tree = PromptTree
    # Wide enough that a glow or a list under the button is never clipped;
    # the layer is cropped to what the prompt covers afterwards.
    rp.TILE_W, rp.TILE_H = 640, 360
    return Layer(lambda: rp.draw_state(snap, px=pixels(zoom)), key)


def ledger_layer(key, snap, zoom):
    rp.Tree = LedgerTree
    return Layer(lambda: rl.draw_window(snap, px=pixels(zoom)), key)


def options_layer(key, scene, zoom):
    """The options window, laid out in `scene`, as a layer. The window is
    drawn framed on itself, as render_options draws it, and the frame is
    kept so a control can be found on the layer."""
    frame = ro.window_frame(scene)
    px = pixels(zoom)
    return Layer(lambda: ro.draw_scene(scene, px, None, frame), key, frame=(frame[0], frame[3], px))


class Sheet:
    """A transparent sheet laid over the board like a layer, painted in
    output pixels: what the pictures add to the addon's own drawing -- a
    tooltip box, a mouse pointer, a ring round a control. It never stands in
    for something the addon draws; the words on it are the addon's."""

    def __init__(self, w, h):
        self.w, self.h = int(np.ceil(w)), int(np.ceil(h))
        self.add = np.zeros((self.h * SS, self.w * SS, 3), np.float32)
        self.alpha = np.zeros((self.h * SS, self.w * SS), np.float32)

    @property
    def through(self):
        return np.repeat((1 - self.alpha)[..., None], 3, axis=2)

    @property
    def size(self):
        return self.w, self.h

    def paint(self, shape, colour, alpha=1.0):
        """Lay `colour` over the sheet where `shape` covers it. `shape(draw,
        k)` draws 255 on a mask `k` pixels to an output pixel, and is drawn
        at four times the size and brought down so its edges are smooth."""
        k = SS * 2
        mask = Image.new("L", (self.w * k, self.h * k), 0)
        shape(ImageDraw.Draw(mask), k)
        mask = mask.resize((self.w * SS, self.h * SS), Image.LANCZOS)
        cov = (np.asarray(mask, np.float32) / 255 * alpha)[..., None]
        self.add = np.asarray(colour, np.float32) * cov + self.add * (1 - cov)
        self.alpha = cov[..., 0] + self.alpha * (1 - cov[..., 0])

    def text(self, x, y, raw, size, colour, bold=False):
        """One line, its colour codes honoured, left edge at x and the top of
        its em square at y. Returns its width."""
        face = rp.get_font(size * SS * 2, bold)
        pieces = rp.runs(raw, tuple(colour) + (1,))
        cx = x
        for piece, c in pieces:
            def shape(d, k, piece=piece, cx=cx):
                d.text((cx * k, y * k), piece, font=face, fill=255)
            self.paint(shape, c[:3])
            cx += face.getlength(piece) / (SS * 2)
        return cx - x


def measure_line(raw, size, bold=False):
    """How wide `raw` is drawn at `size` output pixels, colour codes left out."""
    return rp.get_font(size * SS * 2, bold).getlength(rp.plain_text(raw)) / (SS * 2)


def wrap_line(raw, size, width):
    """`raw` broken at its spaces to lines no wider than `width`. A colour code
    open at a break is closed there and opened again on the next line."""
    out, line, open_code = [], "", ""
    for word in raw.split(" "):
        trial = word if not line else line + " " + word
        if line and measure_line(trial, size) > width:
            out.append(line + ("|r" if open_code else ""))
            line = open_code + word
        else:
            line = trial
        for m in rp.COLOR_CODE.finditer(word):
            open_code = "" if m.group(0) == "|r" else m.group(0) if m.group(0).startswith("|c") else open_code
    out.append(line)
    return out


def tooltip_sheet(tip, zoom):
    """The tooltip the addon put up, as the game draws one: a dark box, the
    first line larger, the others in the colours the addon gave them, a line
    set to wrap broken at the box's width, a pair of lines (a name and the
    spell) with the second pushed to the right. The words and colours are the
    addon's own, recorded as it called AddLine; the box and the type are
    stood in for here."""
    u = zoom
    body, head = 12 * u, 14 * u
    pad, gap = 10 * u, 3 * u
    rows = []   # (kind, size, bold, payload)
    natural = 0
    first = True
    for line in tip["lines"]:
        if "text" in line:
            colour = (line.get("r") or 1, line.get("g") or 1, line.get("b") or 1)
            if first:
                rows.append(("one", head, True, (line["text"], colour)))
                natural = max(natural, measure_line(line["text"], head, True))
            elif line.get("wrap"):
                rows.append(("wrap", body, False, (line["text"], colour)))
            else:
                rows.append(("one", body, False, (line["text"], colour)))
                natural = max(natural, measure_line(line["text"], body))
        else:
            left = (line.get("lr") or 1, line.get("lg") or 1, line.get("lb") or 1)
            right = (line.get("rr") or 1, line.get("rg") or 1, line.get("rb") or 1)
            rows.append(("two", body, False, (line["left"], left, line["right"], right)))
            natural = max(natural, measure_line(line["left"], body) + 24 * u
                          + measure_line(line["right"], body))
        first = False
    # Wrapped lines break at the box's width, which is the widest line that
    # does not wrap, so the box is no wider than its widest unwrapped line.
    inner = max(natural, 190 * u)
    laid = []
    for kind, size, bold, payload in rows:
        if kind == "wrap":
            for piece in wrap_line(payload[0], size, inner):
                laid.append(("one", size, bold, (piece, payload[1])))
        else:
            laid.append((kind, size, bold, payload))
    height = pad * 2 + sum(r[1] + gap for r in laid) - gap
    sheet = Sheet(inner + pad * 2 + 2, height + 2)
    box = [1, 1, 1 + inner + pad * 2, 1 + height]

    def rim(d, k):
        d.rounded_rectangle([v * k for v in box], radius=4 * u * k, fill=255)

    def fill(d, k):
        edge = 1.5 * u
        d.rounded_rectangle([(box[0] + edge) * k, (box[1] + edge) * k,
                             (box[2] - edge) * k, (box[3] - edge) * k],
                            radius=3 * u * k, fill=255)
    # A rim in the border's colour with the dark laid over all but its edge.
    sheet.paint(rim, (0.55, 0.57, 0.66))
    sheet.paint(fill, (0.035, 0.035, 0.06))
    y = 1 + pad
    for kind, size, bold, payload in laid:
        x = 1 + pad
        if kind == "two":
            sheet.text(x, y, payload[0], size, payload[1], bold)
            w = measure_line(payload[2], size)
            sheet.text(1 + pad + inner - w, y, payload[2], size, payload[3], bold)
        else:
            sheet.text(x, y, payload[0], size, payload[1], bold)
        y += size + gap
    return sheet


def pointer_sheet(zoom):
    """A mouse pointer, an arrow with a dark edge. It is the pointer's tip at
    (1, 1) on the sheet, so a point is placed by the tip."""
    u = zoom * 1.3
    arrow = [(0, 0), (0, 16), (4, 12.5), (7.2, 19.5), (10, 18.3), (7, 11.6), (12, 11.2)]
    sheet = Sheet(16 * u + 4, 22 * u + 4)

    def outline(d, k):
        d.polygon([(1 * k + x * u * k, 1 * k + y * u * k) for x, y in arrow], fill=255,
                  outline=255, width=int(2.4 * u * k / SS))

    def body(d, k):
        d.polygon([(1 * k + x * u * k, 1 * k + y * u * k) for x, y in arrow], fill=255)
    sheet.paint(outline, (0.02, 0.02, 0.03))
    sheet.paint(body, (1.0, 1.0, 1.0))
    return sheet


# ---------------------------------------------------------------- icons
#
# The renderers draw a spell's icon as its initials on a tile, which is right
# for a test render -- it says which spell a row has -- and wrong for a listing.
# In the game the prompt shows the spell's own icon, and Arcane Intellect's
# initials are "AI": the largest thing in the hero picture, next to the addon's
# name, read by anybody skimming a gallery in 2026 as artificial intelligence.
# Blizzard's icons are not ours to ship, so each spell the pictures use gets a
# painted emblem of its own instead, in the colours the renderers give it.

def _emblem(kind, n):
    """The emblem's shape as an n-by-n mask, drawn in fractions of the tile."""
    m = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(m)

    def pts(seq):
        return [(x * n, y * n) for x, y in seq]

    def disc(cx, cy, rx, ry=None, fill=255):
        ry = rx if ry is None else ry
        d.ellipse([(cx - rx) * n, (cy - ry) * n, (cx + rx) * n, (cy + ry) * n], fill=fill)

    if kind == "arcane":
        # An eight-pointed star in a thin ring: the arcane school's mark.
        star = []
        for i in range(16):
            a = i * np.pi / 8 - np.pi / 2
            r = 0.40 if i % 4 == 0 else (0.21 if i % 2 == 0 else 0.075)
            star.append((0.5 + r * np.cos(a), 0.5 + r * np.sin(a)))
        d.polygon(pts(star), fill=255)
        w = max(1, int(n * 0.025))
        d.ellipse([0.19 * n, 0.19 * n, 0.81 * n, 0.81 * n], outline=255, width=w)
    elif kind == "sun":
        disc(0.5, 0.5, 0.15)
        for i in range(12):
            a = i * np.pi / 6
            tip = (0.5 + 0.40 * np.cos(a), 0.5 + 0.40 * np.sin(a))
            l = (0.5 + 0.19 * np.cos(a - 0.13), 0.5 + 0.19 * np.sin(a - 0.13))
            r = (0.5 + 0.19 * np.cos(a + 0.13), 0.5 + 0.19 * np.sin(a + 0.13))
            d.polygon(pts([l, tip, r]), fill=255)
    elif kind == "flame":
        t = np.linspace(0, 2 * np.pi, 90)
        xs = 0.5 + 0.22 * np.sin(t) * np.abs(np.sin(t / 2))
        ys = 0.52 - 0.32 * np.cos(t)
        d.polygon(pts(zip(xs, ys)), fill=255)
        inner = zip(0.5 + 0.10 * np.sin(t) * np.abs(np.sin(t / 2)), 0.64 - 0.15 * np.cos(t))
        d.polygon(pts(inner), fill=110)
    elif kind == "moon":
        disc(0.48, 0.52, 0.32)
        disc(0.62, 0.42, 0.27, fill=0)
    elif kind == "paw":
        disc(0.5, 0.63, 0.17, 0.14)
        for cx, cy in ((0.28, 0.43), (0.41, 0.30), (0.59, 0.30), (0.72, 0.43)):
            disc(cx, cy, 0.075, 0.09)
    elif kind == "crown":
        d.polygon(pts([(0.20, 0.70), (0.20, 0.36), (0.35, 0.52), (0.5, 0.26), (0.65, 0.52),
                       (0.80, 0.36), (0.80, 0.70)]), fill=255)
        d.rectangle([0.20 * n, 0.73 * n, 0.80 * n, 0.79 * n], fill=255)
        for cx, cy in ((0.20, 0.34), (0.5, 0.24), (0.80, 0.34)):
            disc(cx, cy, 0.045)
    elif kind == "shout":
        # Sound spreading from a horn's mouth.
        d.polygon(pts([(0.16, 0.44), (0.32, 0.34), (0.32, 0.66), (0.16, 0.56)]), fill=255)
        w = max(1, int(n * 0.055))
        for r in (0.16, 0.28, 0.40):
            d.arc([(0.30 - r) * n, (0.5 - r) * n, (0.30 + r) * n, (0.5 + r) * n],
                  -48, 48, fill=255, width=w)
    elif kind == "sword":
        d.polygon(pts([(0.5, 0.14), (0.565, 0.25), (0.565, 0.62), (0.435, 0.62),
                       (0.435, 0.25)]), fill=255)
        d.rectangle([0.31 * n, 0.62 * n, 0.69 * n, 0.68 * n], fill=255)
        d.rectangle([0.47 * n, 0.68 * n, 0.53 * n, 0.80 * n], fill=255)
        disc(0.5, 0.84, 0.045)
    elif kind == "question":
        f = rp.get_font(n * 0.62, bold=True)
        d.text((n / 2, n * 0.54), "?", font=f, fill=255, anchor="mm")
    elif kind == "book":
        # An open book, its pages tilted toward the spine, a few lines on each.
        d.polygon(pts([(0.12, 0.30), (0.47, 0.37), (0.47, 0.78), (0.12, 0.71)]), fill=255)
        d.polygon(pts([(0.88, 0.30), (0.53, 0.37), (0.53, 0.78), (0.88, 0.71)]), fill=255)
        w = max(1, int(n * 0.025))
        for y in (0.46, 0.55, 0.64):
            d.line(pts([(0.19, y - 0.005), (0.41, y + 0.025)]), fill=0, width=w)
            d.line(pts([(0.59, y + 0.025), (0.81, y - 0.005)]), fill=0, width=w)
    elif kind == "feather":
        # A feather laid on the diagonal, its quill cut out of it.
        t = np.linspace(0, 1, 40)
        ax, ay = 0.20 + 0.62 * t, 0.82 - 0.64 * t
        nx, ny = 0.717, 0.697
        half = 0.145 * np.sin(np.pi * t) ** 0.8
        top = list(zip(ax + nx * half, ay + ny * half))
        low = list(zip(ax - nx * half, ay - ny * half))
        d.polygon(pts(top + low[::-1]), fill=255)
        d.line(pts([(0.12, 0.90), (0.76, 0.24)]), fill=0, width=max(1, int(n * 0.03)))
        d.line(pts([(0.12, 0.90), (0.30, 0.72)]), fill=255, width=max(1, int(n * 0.03)))
    elif kind == "cross":
        d.rectangle([0.41 * n, 0.16 * n, 0.59 * n, 0.84 * n], fill=255)
        d.rectangle([0.16 * n, 0.41 * n, 0.84 * n, 0.59 * n], fill=255)
        for cx, cy in ((0.5, 0.16), (0.5, 0.84), (0.16, 0.5), (0.84, 0.5)):
            disc(cx, cy, 0.05)
    elif kind == "snowflake":
        w = max(1, int(n * 0.05))
        for i in range(6):
            a = i * np.pi / 3
            ux, uy = np.cos(a), np.sin(a)
            d.line(pts([(0.5, 0.5), (0.5 + 0.38 * ux, 0.5 + 0.38 * uy)]), fill=255, width=w)
            for dist, size in ((0.22, 0.12), (0.31, 0.08)):
                for side in (-1, 1):
                    b = a + side * np.pi / 4
                    px, py = 0.5 + dist * ux, 0.5 + dist * uy
                    d.line(pts([(px, py), (px + size * np.cos(b), py + size * np.sin(b))]),
                           fill=255, width=w)
        disc(0.5, 0.5, 0.06)
    elif kind == "flask":
        # A round flask with its cork and the line the liquid stands at, and a
        # drop to one side.
        d.rectangle([0.43 * n, 0.20 * n, 0.57 * n, 0.44 * n], fill=255)
        d.rectangle([0.39 * n, 0.15 * n, 0.61 * n, 0.22 * n], fill=255)
        disc(0.5, 0.63, 0.25)
        d.line(pts([(0.27, 0.60), (0.73, 0.60)]), fill=0, width=max(1, int(n * 0.03)))
        disc(0.84, 0.30, 0.04, 0.055)
    elif kind == "map":
        d.polygon(pts([(0.12, 0.25), (0.37, 0.20), (0.63, 0.27), (0.88, 0.21), (0.88, 0.75),
                       (0.63, 0.81), (0.37, 0.74), (0.12, 0.80)]), fill=255)
        w = max(1, int(n * 0.025))
        d.line(pts([(0.37, 0.20), (0.37, 0.74)]), fill=0, width=w)
        d.line(pts([(0.63, 0.27), (0.63, 0.81)]), fill=0, width=w)
    elif kind == "mask":
        disc(0.5, 0.5, 0.34, 0.27)
        disc(0.37, 0.46, 0.085, 0.045, fill=0)
        disc(0.63, 0.46, 0.085, 0.045, fill=0)
        d.line(pts([(0.40, 0.64), (0.5, 0.67), (0.60, 0.64)]), fill=0, width=max(1, int(n * 0.03)))
    elif kind == "clock":
        w = max(1, int(n * 0.06))
        d.ellipse([0.16 * n, 0.16 * n, 0.84 * n, 0.84 * n], outline=255, width=w)
        d.line(pts([(0.5, 0.5), (0.5, 0.27)]), fill=255, width=w)
        d.line(pts([(0.5, 0.5), (0.65, 0.58)]), fill=255, width=w)
        disc(0.5, 0.5, 0.05)
    elif kind == "note":
        d.rectangle([0.22 * n, 0.14 * n, 0.78 * n, 0.86 * n], fill=255)
        for y in (0.30, 0.42, 0.54, 0.66):
            d.line(pts([(0.30, y), (0.70, y)]), fill=0, width=max(1, int(n * 0.03)))
    elif kind == "eye":
        xs = np.linspace(0.10, 0.90, 30)
        lid = 0.24 * (1 - ((xs - 0.5) / 0.4) ** 2)
        d.polygon(pts(list(zip(xs, 0.5 - lid)) + list(zip(xs[::-1], 0.5 + lid[::-1]))), fill=255)
        disc(0.5, 0.5, 0.14, fill=0)
        disc(0.5, 0.5, 0.065)
    elif kind == "head":
        disc(0.5, 0.36, 0.17)
        d.ellipse([0.20 * n, 0.60 * n, 0.80 * n, 1.08 * n], fill=255)
    elif kind == "spyglass":
        w = max(1, int(n * 0.07))
        d.ellipse([0.18 * n, 0.18 * n, 0.62 * n, 0.62 * n], outline=255, width=w)
        d.line(pts([(0.58, 0.58), (0.82, 0.82)]), fill=255, width=int(w * 1.4))
    return m


# Each icon file id the states hand back, and its emblem. The options window
# names the icons it takes from the client by file, and those are here too.
EMBLEMS = {
    135932: "arcane",    # Arcane Intellect
    135987: "sun",       # Power Word: Fortitude
    135898: "flame",     # Divine Spirit
    136121: "moon",      # Shadow Protection
    136078: "paw",       # Mark of the Wild
    135995: "crown",     # Blessing of Kings
    132333: "shout",     # Battle Shout
    135906: "sword",     # Blessing of Might
    134400: "question",  # the client's unknown-spell icon
    135970: "book",      # Blessing of Wisdom
    135969: "feather",   # Blessing of Salvation
    135944: "cross",     # Blessing of Light
    135843: "snowflake",  # Frost Armor
    132273: "flask",     # a rogue's poison
    "INV_Misc_Map_01": "map",                # Start here
    "Ability_Vanish": "mask",                # Who to skip
    "INV_Misc_PocketWatch_01": "clock",      # When to offer
    "INV_Misc_Note_01": "note",              # What I say
    "Spell_Holy_MindVision": "eye",          # Look
    "INV_Misc_Head_Human_01": "head",        # Profiles
    "INV_Misc_Spyglass_03": "spyglass",      # Diagnostics
    "UI-Searchbox-Icon": "spyglass",         # the sidebar's search box
}

# The colours each spell's tile is drawn in, dark and light, where the
# renderers have none for the icon; the window's pages share one tile colour.
TILES = {
    135970: ((0.08, 0.14, 0.42), (0.55, 0.82, 1.00)),
    135995: ((0.30, 0.10, 0.36), (1.00, 0.84, 0.38)),
    135906: ((0.36, 0.08, 0.06), (1.00, 0.58, 0.36)),
    135969: ((0.16, 0.18, 0.36), (1.00, 0.98, 0.84)),
    135944: ((0.34, 0.24, 0.05), (1.00, 0.95, 0.60)),
    135987: ((0.30, 0.20, 0.05), (1.00, 0.90, 0.55)),
    135843: ((0.04, 0.16, 0.36), (0.72, 0.96, 1.00)),
    132273: ((0.04, 0.20, 0.07), (0.62, 1.00, 0.42)),
}
PAGE_TILE = ((0.16, 0.15, 0.24), (0.84, 0.76, 0.62))
for _file, _tile in TILES.items():
    rp.SPELL_ICONS.setdefault(_file, (str(_file),) + _tile)


def emblem_tile(file, w, h):
    """render_prompt.icon_tile's replacement: the same tile, the same colours,
    a painted emblem where the initials were."""
    _, dark, light = rp.SPELL_ICONS.get(file, (None, (0.25, 0.25, 0.25), (0.8, 0.8, 0.8)))
    kind = EMBLEMS.get(file)
    n = max(8, max(w, h) * 4)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / n
    dist = np.sqrt((xx - 0.5) ** 2 + (yy - 0.46) ** 2)
    t = np.clip(1 - dist * 1.9, 0, 1)[..., None] ** 1.3
    dark, light = np.array(dark, np.float32), np.array(light, np.float32)
    rgb = dark * (1 - t) + (light * 0.55 + dark * 0.45) * t
    if kind:
        mask = _emblem(kind, n)
        glow = np.asarray(mask.filter(ImageFilter.GaussianBlur(n * 0.06)), np.float32)[..., None]
        core = np.asarray(mask, np.float32)[..., None] / 255
        rgb = rgb + (glow / 255) * light * 0.9
        rgb = rgb * (1 - core) + (light * 0.35 + 0.65) * core
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    img = img.resize((max(1, w), max(1, h)), Image.LANCZOS)
    return np.asarray(img).astype(np.float32) / 255


rp.icon_tile = emblem_tile

# The options window takes its page icons from the client's own files, and
# draws them as tiles in a colour made from the file's name. Here they are the
# window's pages' emblems in one colour, so the sidebar reads as a set; the
# search box's magnifier too, which is a file of its own.
_icon_colours = ro.icon_colours
_standin = ro.standin


def _page_colours(name):
    return PAGE_TILE if name in EMBLEMS else _icon_colours(name)


def _page_art(file, w, h):
    base = file.replace("/", "\\").rsplit("\\", 1)[-1]
    if "searchbox" in base.lower():
        return ro.icon_art("UI-Searchbox-Icon", w, h)
    return _standin(file, w, h)


ro.icon_colours = _page_colours
ro.standin = _page_art


# ---------------------------------------------------------------- the world

def ridge(w, base, amp, seed, octaves=5, rough=0.55):
    """A skyline across the picture, as fractions of its height from the top."""
    rng = np.random.default_rng(seed)
    x = np.linspace(0, 1, w)
    h = np.zeros(w)
    scale = 1.0
    for o in range(octaves):
        n = 3 * 2 ** o + 1
        pts = rng.uniform(-1, 1, n)
        h += np.interp(x, np.linspace(0, 1, n), pts) * scale
        scale *= rough
    return base - amp * h / 1.6


def world(w, h, seed=11, sun=(0.72, 0.50)):
    """A dusk over hills, painted: a sky warming to the horizon, a low sun, four
    ranges of hills fading into the haze, pines on the near ridge and a few
    fireflies, softly out of focus the way the world is behind a UI you are
    reading. Dark enough at the top and bottom for a dark panel to sit on, and
    in the same family of colours for every picture so they read as a set."""
    rng = np.random.default_rng(seed)
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    x = np.linspace(0, 1, w, dtype=np.float32)[None, :]
    stops = [(0.00, (0.05, 0.07, 0.15)), (0.28, (0.13, 0.15, 0.30)),
             (0.44, (0.40, 0.30, 0.42)), (0.54, (0.86, 0.55, 0.38)),
             (0.62, (0.98, 0.76, 0.48))]
    pos = [s[0] for s in stops]
    sky = np.stack([np.interp(y[:, 0], pos, [s[1][c] for s in stops]) for c in range(3)],
                   axis=-1)[:, None, :].repeat(w, axis=1).astype(np.float32)
    aspect = w / h
    d2 = ((x - sun[0]) * aspect) ** 2 + (y - sun[1]) ** 2
    sky += np.exp(-d2 / 0.004)[..., None] * np.array([1.0, 0.85, 0.60], np.float32) * 0.9
    sky += np.exp(-d2 / 0.08)[..., None] * np.array([0.55, 0.30, 0.15], np.float32) * 0.45
    img = sky

    ranges = [
        # base, amplitude, colour, haze
        (0.585, 0.050, (0.47, 0.36, 0.48), 0.55),
        (0.655, 0.060, (0.28, 0.23, 0.33), 0.35),
        (0.735, 0.055, (0.14, 0.14, 0.20), 0.18),
        (0.850, 0.040, (0.05, 0.07, 0.09), 0.05),
    ]
    sun_row = np.exp(-((x - sun[0]) * aspect) ** 2 / 0.35)[0]
    for i, (base, amp, colour, haze) in enumerate(ranges):
        top = ridge(w, base, amp, seed + 17 * i)
        layer = np.zeros((h, w), np.float32)
        rows = np.arange(h, dtype=np.float32)[:, None] / h
        layer[:] = np.clip((rows - top[None, :]) * h / 1.5, 0, 1)
        if i == 2:
            # Pines along the near-middle ridge, which is what makes it a
            # place rather than a gradient.
            trees = Image.new("L", (w, h), 0)
            d = ImageDraw.Draw(trees)
            n = int(w / 26)
            for _ in range(n):
                tx = rng.uniform(0, w)
                ty = np.interp(tx, np.arange(w), top) * h + 2
                th = rng.uniform(0.018, 0.05) * h
                tw = th * rng.uniform(0.28, 0.36)
                d.polygon([(tx, ty - th), (tx - tw, ty + 2), (tx + tw, ty + 2)], fill=255)
            layer = np.maximum(layer, np.asarray(trees, np.float32) / 255)
        c = np.array(colour, np.float32)
        # Lit from the sun's side along its top edge, and darker further down.
        depth = np.clip((y - top[None, :].astype(np.float32)) * 4, 0, 1)
        shade = c * (1 - 0.35 * depth[..., None])
        rim = (np.clip(1 - (y - top[None, :]) * h / (0.01 * h), 0, 1) * sun_row[None, :]
               * (1 - i / 4))[..., None] * np.array([0.35, 0.20, 0.10], np.float32)
        shade = shade + rim * (layer[..., None] > 0)
        img = img * (1 - layer[..., None]) + shade * layer[..., None]
        # Haze in front of the further ranges, strongest near the horizon.
        mist = np.exp(-((y - base) / 0.03) ** 2) * haze * 0.35
        img = img + (mist[..., None] * np.array([0.90, 0.62, 0.45], np.float32)) * (1 - i / 4)

    im = Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    im = im.filter(ImageFilter.GaussianBlur(w / 900))
    img = np.asarray(im).astype(np.float32) / 255

    # Fireflies over the dark foreground, blurred into points of light.
    flies = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(flies)
    for _ in range(26):
        fx, fy = rng.uniform(0, w), rng.uniform(0.74, 0.98) * h
        r = rng.uniform(0.0015, 0.004) * w
        d.ellipse((fx - r, fy - r, fx + r, fy + r), fill=int(rng.uniform(90, 220)))
    flies = np.asarray(flies.filter(ImageFilter.GaussianBlur(w / 700)), np.float32) / 255
    img = img + flies[..., None] * np.array([1.0, 0.85, 0.45], np.float32) * 0.8

    # A vignette, so the corners fall away and the eye stays on the middle.
    v = ((x - 0.5) * 1.1) ** 2 + ((y - 0.5) * 1.3) ** 2
    img = img * (1 - np.clip(v, 0, 1)[..., None] * 0.55)
    return img.astype(np.float32)


class Board:
    """One listing picture: the world, the UI laid over it, then captions."""

    def __init__(self, height, seed=11, sun=(0.72, 0.50)):
        self.w, self.h = WIDTH, int(height)
        self.rgb = world(self.w * SS, self.h * SS, seed, sun)
        self.texts = []

    def place(self, layer, x, y):
        """`layer` with its top-left at x, y in output pixels."""
        X, Y = int(round(x * SS)), int(round(y * SS))
        h, w = layer.add.shape[:2]
        x0, y0 = max(0, X), max(0, Y)
        x1, y1 = min(self.rgb.shape[1], X + w), min(self.rgb.shape[0], Y + h)
        if x0 >= x1 or y0 >= y1:
            return
        dst = self.rgb[y0:y1, x0:x1]
        add = layer.add[y0 - Y:y1 - Y, x0 - X:x1 - X]
        through = layer.through[y0 - Y:y1 - Y, x0 - X:x1 - X]
        dst[:] = add + through * dst

    def centre(self, layer, cx, cy):
        w, h = layer.size
        self.place(layer, cx - w / 2, cy - h / 2)

    def shade(self, x0, y0, x1, y1, strength=0.45, cap=0.26):
        """Darken a soft-edged band so a caption reads over the bright sky.

        An even darkening was not enough where the horizon's glow crosses the
        band: a caption over it measured 3.4:1 against 12:1 for the rest. So
        on top of it, nothing inside the band is left brighter than `cap` in
        any channel, which pulls the glow down to the sky's level and leaves
        the already-dark sky as it was."""
        mask = Image.new("L", (self.w * SS, self.h * SS), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [x0 * SS, y0 * SS, x1 * SS, y1 * SS], radius=18 * SS, fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(22 * SS))
        m = np.asarray(mask, np.float32)[..., None] / 255
        self.rgb *= 1 - m * strength
        peak = self.rgb.max(axis=2, keepdims=True)
        limit = np.minimum(1, cap / np.maximum(peak, 1e-6))
        self.rgb *= 1 - m * (1 - limit)

    def text(self, xy, text, size, bold=False, fill=(240, 236, 228), anchor="la"):
        self.texts.append((xy, text, size, bold, fill, anchor))

    def image(self):
        im = Image.fromarray((np.clip(self.rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
        im = im.resize((self.w, self.h), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        for (x, y), text, size, bold, fill, anchor in self.texts:
            f = caption_face(text, size, bold)
            # A soft shadow under every caption, so none depends on the sky
            # behind it being dark.
            d.text((x + 1, y + 2), text, font=f, fill=(0, 0, 0), anchor=anchor)
            d.text((x, y), text, font=f, fill=fill, anchor=anchor)
        return im


def is_cjk(text):
    return any(0x2E80 <= ord(c) <= 0x9FFF or 0xAC00 <= ord(c) <= 0xD7AF for c in text)


def caption_face(text, size, bold=False):
    if is_cjk(text):
        for path in (CJK_BOLD if bold else CJK_REGULAR):
            if os.path.exists(path):
                return ImageFont.truetype(path, size)
    return fonts.face("bold" if bold else "regular", size)


def caption_path(text, bold=False):
    """The file caption_face would open for `text`, for the glyph check."""
    if is_cjk(text):
        for path in (CJK_BOLD if bold else CJK_REGULAR):
            if os.path.exists(path):
                return path
        return None
    for path in fonts.CANDIDATES["bold" if bold else "regular"]:
        if os.path.exists(path):
            return path
    return None


def check_captions(board, name):
    for _, text, _, bold, _, _ in board.texts:
        gone = missing_glyphs(caption_path(text, bold), text)
        if gone:
            problem("%s: the caption %r cannot be drawn: %s" % (name, text, "".join(gone)))


def heading(board, title, sub):
    board.shade(20, 12, 20 + 760, 112, 0.35)
    board.text((56, 44), title, 34, bold=True)
    board.text((58, 90), sub, 19, fill=(214, 206, 214))


# ---------------------------------------------------------------- pictures

# Each reason's state, the person it puts on top, and the caption beside it --
# in the order the addon ranks them, which is the order the captions give.
REASONS = [
    ("shot-target", "Bram Cinderfell", "target", "Your target",
     "Whoever you have selected, if they are missing your buff."),
    ("shot-owed", "Elowen Thistledown", "owed", "Buffed you",
     "Somebody who buffed you first: a favour to return."),
    ("shot-asked", "Maribel Quickwater", "asked", "Asked for it",
     "Somebody who asked for your buff in chat, if you turn it on."),
    ("shot-group", "Oskar Fenwick", "group", "In your group",
     "A party or raid member who is missing it."),
    ("shot-nearby", "Sable Harrow", "nearby", "Passing by",
     "A stranger close enough to buff, missing yours."),
]
# The hero: the favour returned, the cast confirmed, at the frame where the
# landing reads best (the rings off the icon spread into two, the light sweep
# started across the panel, the words fully drawn). Earlier the rings are
# tight and the words still fading in; later the rings have thinned out and the
# sweep is off the panel. It is the state's own time, so this is where
# the state is built.
LANDED_AT = 0.20
LANDED_WORDS = ["buffed Elowen Thistledown", "the game confirmed it"]

# The film strip: one favour, three moments, four frames of each. A row is the
# state, the title and caption it carries, and the two lines the prompt has to
# be saying -- and the words it must not, which would make the row's title
# untrue. The frames are the renderer's, taken at these times (--at).
MOMENT_TIMES = (0.05, 0.15, 0.30, 0.60)
MOMENTS = [
    ("shot-moment-arrival", "They buffed you",
     "The favour arrives and the glow wakes.",
     ["Elowen Thistledown", "buffed you"], ["buffed Elowen", "could not buff"]),
    ("shot-landed", "Your buff lands",
     "Rings off the icon, a sweep across the panel.",
     LANDED_WORDS, ["buffed you", "could not buff"]),
    ("shot-moment-refused", "The game refused it",
     "The panel says why, in a few words.",
     ["could not buff Elowen Thistledown", "Out of range."], ["buffed Elowen", "confirmed"]),
]

# Who the translated pictures' list rows name, as PROMPT_STATES' shot-list puts
# them there.
LIST_ROWS = ["Mira Holt", "Tam Rook", "Ivo Lark"]

# The looks the Look tab offers, in the order its gallery shows them, each
# with the name and the few words its card gives it.
LOOKS = [
    ("luxe", "Luxe", "slim dark card, a spine in the reason colour"),
    ("toast", "Toast", "warm banner, gilded medallion"),
    ("arcane", "Arcane", "smoked glass, a rim lit by the reason"),
    ("ribbon", "Ribbon", "a crimson ribbon and a gold medallion"),
    ("letter", "Letter", "parchment and a red wax seal"),
    ("leather", "Leather", "a stitched leather tag with a brass ring"),
    ("glass", "Glass", "dark panel, soft shadow"),
    ("framed", "Framed", "flat panel, thin border"),
    ("minimal", "Minimal", "text only, no panel"),
]


# The list picture: who the addon puts on the panel and in the list, in order,
# the reason each is there and the buff each would get. A paladin whose buff
# order has Wisdom first gives a caster Wisdom and a fighter Kings, so the
# icons beside the names are not all one. The cursor is on the second name.
CLICK_LIST = [
    ("Bram Cinderfell", "target", "kings"),
    ("Elowen Thistledown", "owed", "wisdom"),
    ("Maribel Quickwater", "asked", "kings"),
    ("Oskar Fenwick", "group", "wisdom"),
    ("Sable Harrow", "nearby", "kings"),
]
CLICK_ROW = 2

# The pictures of your own buffs: the state, the word under it, the line
# under that, and a word the prompt's second line has to carry.
SELF_SHOTS = [
    ("shot-self-armor", "Armor", "A mage's armor, once you have learned it.", "Frost Armor"),
    ("shot-self-poison", "Poison", "From your bags, for one weapon at a time.", "Instant Poison"),
    ("shot-self-intellect", "Arcane Intellect", "The buff you give everybody, on you.",
     "Arcane Intellect"),
]

# The buff order the options picture shows, which the window's own Buff order
# list has to stand in: Wisdom moved up one place.
ORDER_KEYS = ["wisdom", "kings", "might", "salvation", "light"]


def shot_extras(lua):
    """What a state left in the Lua globals besides its tree: the queue, the
    cursor and the tooltip."""
    return {"queue": rp.to_py(lua.globals().ShotQueue) or [],
            "hover": rp.to_py(lua.globals().ShotHover) or None,
            "tip": rp.to_py(lua.globals().ShotTip) or None}


def build_click(addon_dir, snaps):
    use_faces("enUS")
    lua, R = prompt_states(addon_dir)
    key = "shot-click"
    snap, top = snap_of(R, lua, key)
    if not snap:
        return
    expect_top(key, top, CLICK_LIST[0][0], CLICK_LIST[0][1])
    got = shot_extras(lua)
    queue = [(q["name"], q["reason"], q["buff"]) for q in got["queue"]]
    if queue != CLICK_LIST:
        problem("%s: the addon offers %s, not %s" % (key, queue, CLICK_LIST))
    texts = shown_texts(snap, PromptTree)
    expect_names(key, texts, [name for name, _, _ in CLICK_LIST])
    check_glyphs(key, texts)
    hover, tip = got["hover"], got["tip"]
    if not hover or hover.get("row") != CLICK_ROW:
        problem("%s: the cursor is not on row %d" % (key, CLICK_ROW))
        return
    if not tip or tip.get("owner") != hover.get("id"):
        problem("%s: there is no tooltip over the name under the cursor" % key)
        return
    # The tooltip is the addon's, about the name the cursor is on, and says
    # what each click does: the caption claims no more than that.
    said = "\n".join(rp.plain_text(line.get("text") or line.get("left") or "")
                     for line in tip.get("lines", []))
    if CLICK_LIST[CLICK_ROW][0] not in said:
        problem("%s: the tooltip is not about %s" % (key, CLICK_LIST[CLICK_ROW][0]))
    if tip.get("anchor") != "ANCHOR_RIGHT":
        problem("%s: the tooltip is anchored %s; the picture hangs it from the name's top right"
                % (key, tip.get("anchor")))
    for words in ("Click to cast", "Right-click to skip", "Shift-right-click to put them on your never-offer"):
        if words not in said:
            problem("%s: the tooltip no longer says %r, which the picture's captions rest on"
                    % (key, words))
    # The name lit: the row's wash is shown, which only its OnEnter does.
    tree = PromptTree(snap)
    wash = [r for r in tree.regions.values()
            if r["kind"] == "Texture" and r.get("parent") == hover.get("id")]
    if not wash or not all(c.get("shown", True) for c in tree.chain(wash[0])):
        problem("%s: the name under the cursor is not lit" % key)
    snap["shot"] = got
    snaps[key] = snap


def build_yourself(addon_dir, snaps):
    use_faces("enUS")
    lua, R = prompt_states(addon_dir)
    for key, _, _, word in SELF_SHOTS:
        snap, top = snap_of(R, lua, key)
        if not snap:
            continue
        if not top or top.get("reason") != "self":
            problem("%s: the prompt is not on the player (%s)" % (key, top))
        texts = shown_texts(snap, PromptTree)
        expect_names(key, texts, ["You", word])
        check_glyphs(key, texts)
        snaps[key] = snap


def build_options(addon_dir, snaps):
    """The options window on Who to buff for a paladin whose buff order is
    Wisdom, Kings, Might ..., drawn and held to render_options' own checks."""
    key = "options"
    ro.use_faces(None)
    lua, R = options_states(addon_dir, "PALADIN")
    lua.globals().ShotOrder = None
    try:
        snap = rp.to_py(R["page"]("who", "icons\nkeybound\norder\nreturning\nlocate"))
    except Exception as e:  # noqa: BLE001 - a Lua error is a window that cannot be built
        problem("%s: the addon could not be put into this state: %s" % (key, e))
        return
    if snap.get("failed"):
        problem("%s: the window could not be drawn: %s" % (key, snap["failed"]))
        return
    if snap.get("errors"):
        problem("%s: %d guarded error(s), first %s" % (key, snap["errors"], snap.get("firstError")))
    if snap.get("page") != "who":
        problem("%s: the window is on %s, not Who to buff" % (key, snap.get("page")))
    scene = ro.Scene(snap)
    for finding in ro.check(scene):
        problem("%s: (%s) %s" % (key, finding["kind"], finding["message"]))
    order = rp.to_py(lua.globals().ShotOrder)
    if not order or not order.get("lines"):
        problem("%s: the page has no Buff order list" % key)
        return
    keys = [line["key"] for line in order["lines"]]
    if keys[:len(ORDER_KEYS)] != ORDER_KEYS:
        problem("%s: the Buff order reads %s, not %s" % (key, keys, ORDER_KEYS))
    if find_button(scene, "Move the prompt") is None:
        problem("%s: there is no Move the prompt button in the header" % key)
        return
    texts = [ro.plain(r["text"]).strip() for r in scene.regions.values()
             if r["kind"] == "FontString" and r.get("text") and scene.visible(r)
             and scene.alpha(r) > 0.01]
    expect_names(key, texts, ["Move the prompt", "Show me the prompt", "Buff order",
                              "Blessing of Wisdom", "Blessing of Kings", "Blessing of Might",
                              "Back to Automatic"])
    if "Stop preview" in texts:
        problem("%s: the header reads Stop preview: the window was opened for the first time" % key)
    check_glyphs(key, texts)
    snaps[key] = {"scene": scene, "order": order}


def build(addon_dir):
    """Every snapshot the pictures need, checked. Nothing is drawn until all of
    them are in, so a strict run refuses before it writes anything."""
    snaps = {}
    use_faces("enUS")
    lua, R = prompt_states(addon_dir)
    for key, name, reason, _, _ in REASONS:
        snap, top = snap_of(R, lua, key)
        if snap:
            expect_top(key, top, name, reason)
            texts = shown_texts(snap, PromptTree)
            expect_names(key, texts, [name])
            check_glyphs(key, texts)
            snaps[key] = snap
    # The hero and the film strip: the same favour at the moments the pictures
    # show. Every frame is held to what its row's title says, so a frame that
    # shows the arrival under "Your buff lands" is caught rather than drawn.
    snap, top = snap_of(R, lua, "shot-landed")
    if snap:
        expect_top("shot-landed", top, "Elowen Thistledown", "owed")
        texts = shown_texts(snap, PromptTree)
        expect_names("shot-landed", texts, LANDED_WORDS)
        check_glyphs("shot-landed", texts)
        snaps["shot-landed"] = snap
    for key, _, _, words, never in MOMENTS:
        for t in MOMENT_TIMES:
            frame = "%s@%.2f" % (key, t)
            snap, top = snap_of(R, lua, key, t)
            if not snap:
                continue
            expect_top(frame, top, "Elowen Thistledown", "owed")
            texts = shown_texts(snap, PromptTree)
            expect_names(frame, texts, words)
            joined = "\n".join(texts)
            for gone in never:
                if gone in joined:
                    problem("%s: the prompt says %r, which is not this moment" % (frame, gone))
            check_glyphs(frame, texts)
            snaps[frame] = snap
    for key in ("shot-palette-standard", "shot-palette-colourblind"):
        snap, top = snap_of(R, lua, key)
        if snap:
            expect_top(key, top, "Bram Cinderfell", "target")
            texts = shown_texts(snap, PromptTree)
            expect_names(key, texts, ["Bram Cinderfell", "Elowen Thistledown", "Oskar Fenwick",
                                      "Sable Harrow"])
            check_glyphs(key, texts)
            snaps[key] = snap
    for style, _, _ in LOOKS:
        key = "shot-look-" + style
        lua.globals().ShotStyle = None
        snap, top = snap_of(R, lua, key)
        if snap:
            expect_top(key, top, "Elowen Thistledown", "owed")
            got = lua.globals().ShotStyle
            if got != style:
                problem("%s: the prompt is drawn in %s, not %s" % (key, got, style))
            texts = shown_texts(snap, PromptTree)
            expect_names(key, texts, ["Elowen Thistledown"])
            check_glyphs(key, texts)
            snaps[key] = snap
    # The list in English, drawn nowhere: what each translated one is held
    # against, line by line.
    snap, top = snap_of(R, lua, "shot-list")
    english = set(shown_texts(snap, PromptTree)) if snap else set()
    list_names = ["Elowen Thistledown"] + LIST_ROWS

    for loc, _, spell in LANGUAGES:
        use_faces(loc)
        lua, R = prompt_states(addon_dir, loc, spell)
        key = "shot-list-" + loc
        snap, top = snap_of(R, lua, "shot-list")
        if not snap:
            continue
        expect_top(key, top, "Elowen Thistledown", "owed")
        texts = shown_texts(snap, PromptTree)
        expect_names(key, texts, list_names)
        check_glyphs(key, texts)
        # A line still in English is a translation that did not load, or a
        # string the translation does not have yet: either way not a picture
        # of the addon in that language. Names and numbers are the same in
        # every language and are left out.
        untranslated = [t for t in texts if t in english and any(ch.isalpha() for ch in t)
                        and t not in list_names]
        if not english:
            problem("%s: there is no English list to hold it against" % key)
        if untranslated:
            problem("%s: still in English: %s" % (key, "; ".join(untranslated)))
        snaps[key] = snap
    use_faces("enUS")

    build_click(addon_dir, snaps)
    build_yourself(addon_dir, snaps)
    build_options(addon_dir, snaps)
    use_faces("enUS")

    lua, R = ledger_states(addon_dir)
    lua.globals().ShotDoubts = lua.table()
    snap, _ = snap_of(R, lua, "shot-ledger", "enUS")
    for doubt in (rp.to_py(lua.globals().ShotDoubts) or []):
        problem("shot-ledger: " + doubt)
    if snap:
        texts = shown_texts(snap, LedgerTree)
        expect_names("shot-ledger", texts, ["Elowen Thistledown", "Rowan Ashvale", "Oskar Fenwick"])
        check_glyphs("shot-ledger", texts)
        snaps["shot-ledger"] = snap
    return snaps


def picture_prompt(snaps):
    """The first picture on the page, so the addon at its best moment: the buff
    has landed and the panel is mid-celebration. No heading; one line under it."""
    board = Board(600, seed=11, sun=(0.87, 0.47))
    layer = prompt_layer("shot-landed", snaps["shot-landed"], 3.0)
    cx = WIDTH / 2 - 40
    board.centre(layer, cx, 270)
    below = 270 + layer.size[1] / 2
    board.shade(cx - 230, below + 22, cx + 230, below + 82, 0.4)
    board.text((cx, below + 52), "The moment your buff lands.", 26, bold=True, anchor="mm")
    return board


def picture_moment(snaps):
    """Three moments of one favour, a row of four frames each: the real
    renderer's output at 0.05, 0.15, 0.30 and 0.60 s after the moment. Drawn
    at the game's own size, because four panels at twice that do not fit the
    page's width; each row's title and caption stand above its frames."""
    zoom = 1.0
    rows = []
    for key, *_ in MOMENTS:
        rows.append([prompt_layer("%s@%.2f" % (key, t), snaps["%s@%.2f" % (key, t)], zoom)
                     for t in MOMENT_TIMES])
    # A strip whose frames are all alike is one that ignored its times.
    for (key, *_), frames in zip(MOMENTS, rows):
        for i, a in enumerate(frames):
            for j in range(i + 1, len(frames)):
                if a.add.shape == frames[j].add.shape and np.array_equal(a.add, frames[j].add):
                    problem("manners-moment.png: %s is the same at %.2f s and %.2f s"
                            % (key, MOMENT_TIMES[i], MOMENT_TIMES[j]))
    fw = max(l.size[0] for frames in rows for l in frames)
    fh = max(l.size[1] for frames in rows for l in frames)
    gap = 4
    left = (WIDTH - 4 * fw - 3 * gap) / 2
    top = 150
    above = 34
    row = above + fh + 36
    board = Board(top + row * len(rows) + 14, seed=19, sun=(0.50, 0.55))
    heading(board, "Three moments",
            "One favour, four frames of each: 0.05, 0.15, 0.30 and 0.60 seconds in.")
    for n, ((_, title, line, _, _), frames) in enumerate(zip(MOMENTS, rows)):
        board.shade(18, top + row * n - 6, WIDTH - 12, top + row * n + above + fh + 30, 0.4)
        board.text((30, top + row * n + 4), title, 21, bold=True)
        board.text((30 + caption_face(title, 21, True).getlength(title) + 16, top + row * n + 9), line, 16,
                   fill=(214, 206, 214))
        y = top + row * n + above
        for i, (t, layer) in enumerate(zip(MOMENT_TIMES, frames)):
            x = left + i * (fw + gap)
            # Every frame by the button's top left, so the panel stands still
            # on the page and only what the addon animates moves: the layer
            # is wider on the side a ring has spread to.
            snap = snaps["%s@%.2f" % (MOMENTS[n][0], t)]
            left_, _, _, top_ = PromptTree(snap).rect(snap["button"])
            ax, ay = layer.at(left_, top_)
            board.place(layer, x + 14 - ax, y + 14 - ay)
            board.text((x + fw / 2, y + fh + 6), "%.2f s" % t, 14, fill=(190, 184, 196), anchor="mm")
    return board


def picture_reasons(snaps):
    layers = [prompt_layer(key, snaps[key], 2.0) for key, *_ in REASONS]
    row = max(l.size[1] for l in layers) + 4
    top = 150
    # The sun low on the left, behind the prompts, so the captions on the
    # right sit on sky dark enough to read.
    board = Board(top + row * len(layers) + 36, seed=5, sun=(0.16, 0.50))
    heading(board, "Why somebody is on the prompt",
            "Five reasons, each with its own colour, offered in this order.")
    lx = 96
    board.shade(lx + max(l.size[0] for l in layers) + 8, top - 6, WIDTH - 40,
                top + row * len(layers) + 6, 0.45)
    for i, ((key, _, _, title, line), layer) in enumerate(zip(REASONS, layers)):
        cy = top + row * i + row / 2
        board.place(layer, lx, cy - layer.size[1] / 2)
        tx = lx + layer.size[0] + 40
        board.text((tx, cy - 14), "%d  %s" % (i + 1, title), 24, bold=True, anchor="lm")
        board.text((tx + 26, cy + 16), line, 18, fill=(214, 206, 214), anchor="lm")
    return board


def picture_ledger(snaps):
    layer = ledger_layer("shot-ledger", snaps["shot-ledger"], 2.0)
    w, h = layer.size
    board = Board(h + 80, seed=23, sun=(0.22, 0.56))
    x = WIDTH - w - 80
    board.place(layer, x, 40)
    # The words sit left of the window, on the side the sun is not.
    board.shade(30, 60, x - 30, 330, 0.35)
    board.text((70, 110), "The favour ledger", 36, bold=True)
    for i, line in enumerate(["Who buffed you, whether you returned it,",
                              "and who you buffed without being asked.",
                              "", "/manners ledger"]):
        board.text((72, 170 + i * 30), line, 20, fill=(214, 206, 214))
    return board


def picture_languages(snaps):
    # One language to a row, and large. Three side by side left the list's
    # lines -- the sentences the picture exists to show -- about thirteen
    # pixels tall, and six once the README shows it at half width.
    layers = []
    for loc, _, _ in LANGUAGES:
        use_faces(loc)
        layers.append(prompt_layer("shot-list-" + loc, snaps["shot-list-" + loc], 2.5))
    use_faces("enUS")
    row = max(l.size[1] for l in layers) + 16
    top = 150
    board = Board(top + row * len(layers) + 24, seed=31, sun=(0.86, 0.50))
    heading(board, "In your language",
            "English and eight translations, chosen by your game client.")
    w = max(l.size[0] for l in layers)
    x = WIDTH - w - 70
    board.shade(20, top, x - 20, top + row * len(layers), 0.45)
    for i, ((loc, label, _), layer) in enumerate(zip(LANGUAGES, layers)):
        cy = top + row * i + row / 2
        board.place(layer, x, cy - layer.size[1] / 2)
        board.text((x - 60, cy - 12), label, 34, bold=True, anchor="rm")
        board.text((x - 60, cy + 26), "%s client" % loc, 18, fill=(214, 206, 214), anchor="rm")
    return board


def picture_palette(snaps):
    layers = [prompt_layer(k, snaps[k], 2.0)
              for k in ("shot-palette-standard", "shot-palette-colourblind")]
    h = max(l.size[1] for l in layers)
    top = 196
    board = Board(top + h + 50, seed=41, sun=(0.62, 0.52))
    heading(board, "A palette for colour blindness",
            "Target, favour, group and passer-by, redrawn for red-green colour blindness.")
    gap = (WIDTH - sum(l.size[0] for l in layers)) / 3
    x = gap
    for label, layer in zip(("Standard", "Colour-blind friendly"), layers):
        w = layer.size[0]
        board.text((x + w / 2, top - 24), label, 24, bold=True, anchor="mm")
        board.place(layer, x, top)
        x += w + gap
    return board


def picture_looks(snaps):
    """Every look, three to a row in the order the Look tab's gallery shows
    them, each named over its panel. Every panel is drawn at the same zoom from
    the same moment, so what differs between them is the look and nothing
    else. The zoom is the largest at which three panels fit a row."""
    layers = [prompt_layer("shot-look-" + style, snaps["shot-look-" + style], 1.5)
              for style, _, _ in LOOKS]
    cols = 3
    rows = (len(layers) + cols - 1) // cols
    cell_w = WIDTH / cols
    label_h = 60
    row = max(l.size[1] for l in layers) + label_h + 18
    top = 140
    board = Board(top + row * rows + 10, seed=17, sun=(0.50, 0.53))
    heading(board, "Nine looks to choose from",
            "The same favour in each. Pick one from the cards under Look; Glass is the default.")
    for i, ((_, name, words), layer) in enumerate(zip(LOOKS, layers)):
        cx = cell_w * (i % cols) + cell_w / 2
        y = top + row * (i // cols)
        board.shade(cx - cell_w / 2 + 12, y + 4, cx + cell_w / 2 - 12, y + label_h, 0.4)
        board.text((cx, y + 20), name, 26, bold=True, anchor="mm")
        board.text((cx, y + 48), words, 17, fill=(214, 206, 214), anchor="mm")
        w, h = layer.size
        board.place(layer, cx - w / 2, y + label_h + (row - label_h - 18 - h) / 2)
    return board


def picture_click(snaps):
    """The prompt with its list, the cursor on the second name: that name lit,
    the tooltip the addon puts up over it, and what each click does beneath."""
    key = "shot-click"
    snap = snaps[key]
    zoom = 2.0
    layer = prompt_layer(key, snap, zoom)
    lw, lh = layer.size
    shot = snap["shot"]
    tip = tooltip_sheet(shot["tip"], zoom)
    pointer = pointer_sheet(zoom)
    # The name's button, in screen units; the tooltip hangs from its top right
    # (ANCHOR_RIGHT, which is what the addon asks for).
    left, bottom, right, top = PromptTree(snap).rect(shot["hover"]["id"])
    corner = layer.at(right, top)
    first = 128
    # The layer sits low enough that the tooltip, which stands above the name,
    # clears the heading, and wide enough in that the tooltip clears the edge.
    ly = max(first + 20, first + tip.h - corner[1] + 12)
    span = max(lw, corner[0] + tip.w)
    lx = (WIDTH - span) / 2
    caption = 130
    board = Board(ly + lh + caption, seed=47, sun=(0.84, 0.52))
    heading(board, "Click any name", "Every name under the prompt is a button of its own.")
    board.place(layer, lx, ly)
    board.place(tip, lx + corner[0], ly + corner[1] - tip.h)
    # The pointer rests at the end of the name's line, past its words, so
    # the names stay legible.
    tx, ty = layer.at(right - 8, (top + bottom) / 2)
    board.place(pointer, lx + tx - 1, ly + ty - 1)
    base = ly + lh + 26
    board.shade(60, base - 12, WIDTH - 60, base + 92, 0.45)
    for i, (word, line) in enumerate((
            ("Left-click", "Buffs that person."),
            ("Right-click", "Skips them for now."),
            ("Shift-right-click", "Never offers them again."))):
        cx = WIDTH * (2 * i + 1) / 6
        board.text((cx, base + 20), word, 26, bold=True, anchor="mm")
        board.text((cx, base + 56), line, 20, fill=(214, 206, 214), anchor="mm")
    return board


def find_button(scene, label):
    """The shown button whose first words are `label`, as render_options sees
    the tree."""
    for rid, r in scene.regions.items():
        if r["kind"] == "Button" and scene.visible(r):
            text = ro.first_text(scene, rid)
            if text and ro.plain(text).strip() == label:
                return rid
    return None


def ring(sheet, layer, rect, grow, zoom, number=None):
    """A gold ring round a rectangle of the window, in screen units, and a
    numbered badge on its corner."""
    (x0, y0), (x1, y1) = layer.at(rect[0], rect[3]), layer.at(rect[2], rect[1])
    x0, y0, x1, y1 = x0 - grow, y0 - grow, x1 + grow, y1 + grow
    width = 3

    def outline(d, k, extra=0):
        d.rounded_rectangle([(x0 - extra) * k, (y0 - extra) * k, (x1 + extra) * k, (y1 + extra) * k],
                            radius=(6 + extra) * k, outline=255, width=int((width + 2 * extra) * k))
    sheet.paint(lambda d, k: outline(d, k, 1.5), (0.0, 0.0, 0.0), 0.55)
    sheet.paint(outline, (1.0, 0.82, 0.25))
    if number is not None:
        r = 13
        cx, cy = x0 - 2, y0 - 2

        def disc(d, k, extra=0):
            d.ellipse([(cx - r - extra) * k, (cy - r - extra) * k, (cx + r + extra) * k, (cy + r + extra) * k],
                      fill=255)
        sheet.paint(lambda d, k: disc(d, k, 2), (0.0, 0.0, 0.0), 0.55)
        sheet.paint(disc, (1.0, 0.82, 0.25))

        def digit(d, k):
            d.text((cx * k, (cy + 0.5) * k), str(number), font=rp.get_font(17 * k, True), fill=255,
                   anchor="mm")
        sheet.paint(digit, (0.10, 0.07, 0.02))


def picture_options(snaps):
    """The options window on Who to buff, a ring on the buff order's arrows
    and one on Move the prompt in the header, and a line under for each."""
    got = snaps["options"]
    scene, order = got["scene"], got["order"]
    zoom = 1.5
    layer = options_layer("options", scene, zoom)
    w, h = layer.size
    geo = scene.geo
    top = 132
    caption = 128
    board = Board(top + h + caption, seed=61, sun=(0.80, 0.50))
    heading(board, "Set it up in one window", "Open it with /manners or the minimap button.")
    x = (WIDTH - w) / 2
    board.place(layer, x, top)
    sheet = Sheet(w, h)
    move = geo.rect(find_button(scene, "Move the prompt"))
    ring(sheet, layer, move, 3, zoom, 2)
    arrows = [geo.rect(line[side]) for line in order["lines"] for side in ("up", "down")]
    ring(sheet, layer, (min(a[0] for a in arrows), min(a[1] for a in arrows),
                        max(a[2] for a in arrows), max(a[3] for a in arrows)), 4, zoom, 1)
    board.place(sheet, x, top)
    base = top + h + 20
    board.shade(40, base - 8, WIDTH - 40, base + 96, 0.45)
    for i, (word, line) in enumerate((
            ("The buff order", "Move a blessing up or down with its arrows."),
            ("Move the prompt", "One click in the header, then drag it where you like."))):
        x0 = 110 + i * 600
        board.text((x0, base + 24), str(i + 1), 26, bold=True, fill=(255, 209, 64), anchor="mm")
        board.text((x0 + 26, base + 24), word, 26, bold=True, anchor="lm")
        board.text((x0 + 26, base + 62), line, 20, fill=(214, 206, 214), anchor="lm")
    return board


def picture_yourself(snaps):
    """Three prompts for the player: what each is, in a word and a line."""
    zoom = 1.5
    layers = [prompt_layer(key, snaps[key], zoom) for key, *_ in SELF_SHOTS]
    h = max(l.size[1] for l in layers)
    top = 156
    board = Board(top + h + 130, seed=71, sun=(0.50, 0.55))
    heading(board, "Your own buffs too",
            "When your own armor, poison or buff is missing, you come up like anybody else.")
    gap = (WIDTH - sum(l.size[0] for l in layers)) / (len(layers) + 1)
    x = gap
    for (_, word, line, _), layer in zip(SELF_SHOTS, layers):
        w = layer.size[0]
        board.place(layer, x, top + (h - layer.size[1]) / 2)
        base = top + h + 34
        board.shade(x - 20, base - 24, x + w + 20, base + 62, 0.4)
        board.text((x + w / 2, base), word, 26, bold=True, anchor="mm")
        board.text((x + w / 2, base + 36), line, 17, fill=(214, 206, 214), anchor="mm")
        x += w + gap
    return board


PICTURES = [
    ("manners-prompt.png", picture_prompt),
    ("manners-moment.png", picture_moment),
    ("manners-reasons.png", picture_reasons),
    ("manners-looks.png", picture_looks),
    ("manners-ledger.png", picture_ledger),
    ("manners-languages.png", picture_languages),
    ("manners-palette.png", picture_palette),
    ("manners-list.png", picture_click),
    ("manners-options.png", picture_options),
    ("manners-yourself.png", picture_yourself),
]


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=OUT, help="where to write them (default: .github/media)")
    ap.add_argument("--addon", default=ROOT, help="the addon tree to draw (default: this one)")
    ap.add_argument("--strict", action="store_true",
                    help="write nothing if any picture would be wrong")
    args = ap.parse_args()

    snaps = build(os.path.abspath(args.addon))
    if args.strict and problems:
        print("refusing to draw: %d problem(s) above" % len(problems), file=sys.stderr)
        sys.exit(1)
    boards = []
    for name, make in PICTURES:
        try:
            boards.append((name, make(snaps)))
        except KeyError as e:
            problem("%s: not drawn, its state %s was not built" % (name, e))
    for name, board in boards:
        check_captions(board, name)
    if args.strict and problems:
        print("refusing to draw: %d problem(s) above" % len(problems), file=sys.stderr)
        sys.exit(1)
    os.makedirs(args.out, exist_ok=True)
    for name, board in boards:
        path = os.path.join(args.out, name)
        im = board.image()
        im.save(path, optimize=True)
        print("  %-24s %dx%d" % (name, im.width, im.height))
    if problems:
        print("%d problem(s); the pictures above may not show what they claim" % len(problems),
              file=sys.stderr)


if __name__ == "__main__":
    main()
