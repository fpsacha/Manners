-- The words read, on every one of the nineteen looks.
--
-- tools/audit_look_contrast.py measures the pictures; this holds what a
-- scenario can, so the floor does not slip between two runs of the tool. On
-- each look, against the ground the look itself states for its words
-- (Prompt's ink: the panel colour, or the luminance a look writes there for
-- its cloth, its hide, its iron):
--
--   * the name's own colour, and every colour code in it -- the deepest class
--     colours, an outcome's red and green -- reads at 4.5:1;
--   * the reason line reads at 4.5:1 for every reason, in both palettes, and
--     for both outcomes;
--   * the list's rows and the words after each name read at 4.5:1;
--   * a look with a ground of its own judges its words against one as bright
--     as it draws;
--   * on a dark ground both lines carry a dark shadow or an outline;
--   * a short name beside the key's tag and the count is drawn at the size the
--     player set: the tags give way before the name is drawn smaller.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local STYLES = { "glass", "framed", "minimal", "luxe", "toast", "arcane", "ribbon", "letter", "leather", "forge", "archmage",
	"lightbringer", "fel", "wild", "frost", "stormcaller", "warchief", "gearworks", "ebon" }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" }, nameplate3 = { "Corwin", "Ash" } }
local COMMAND = "CLICK MannersPrompt:LeftButton"
local FLOOR = 4.5
-- How bright each look's own ground is under its words at its lightest, as
-- tools/audit_look_contrast.py measures it on the picture (relative
-- luminance, a little under the measure): the look has to judge its words
-- against a ground at least that bright, or everything above reads on paper
-- and not on the prompt.
local GROUND = { ribbon = 0.10, leather = 0.10, forge = 0.08, letter = 0.60, gearworks = 0.007 }
-- The looks that hang the key's tag and the count beside the name, where a
-- long name is still drawn at the size set.
local LONG = { fel = true, lightbringer = true, wild = true, frost = true }
-- The class colours a name is written in, the hard ones among them: the mock
-- has the mage's and the priest's.
local CLASSES = {
	SHAMAN = { colorStr = "ff0070dd" }, DEATHKNIGHT = { colorStr = "ffc41e3a" }, PRIEST = { colorStr = "ffffffff" },
	ROGUE = { colorStr = "fffff468" }, MAGE = { colorStr = "ff3fc7eb" }, DRUID = { colorStr = "ffff7c0a" },
}
local REASONS = {
	{ "target", { reason = "target", class = "SHAMAN" } },
	{ "owed", { reason = "owed", class = "PRIEST" } },
	{ "asked", { reason = "asked", class = "DEATHKNIGHT" } },
	{ "self", { reason = "self", class = "ROGUE" } },
	{ "group", { reason = "group", class = "MAGE" } },
	{ "nearby", { reason = "nearby", class = "DRUID" } },
	{ "refresh", { reason = "group", class = "MAGE", remaining = 240 } },
	{ "unknown", { reason = "nearby", class = "DRUID", checked = true } },
}

local function lin(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- A colour's contrast on the ground the look states, at its worse end.
local function reads(ink, r, g, b)
	local l = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
	return math.min(ratio(l, ink.lo), ratio(l, ink.hi))
end

-- Every colour a line is written in: its own, where any of its text is not
-- inside a code, and each code's.
local function colours(fs)
	local out = {}
	local text = tostring(fs._text or "")
	local c = fs._textColor
	local bare = text:gsub("|c%x%x%x%x%x%x%x%x.-|r", "")
	if c and bare:find("%S") then out[#out + 1] = { c[1], c[2], c[3], "its own colour" } end
	for code in text:gmatch("|c%x%x(%x%x%x%x%x%x)") do
		out[#out + 1] = { tonumber(code:sub(1, 2), 16) / 255, tonumber(code:sub(3, 4), 16) / 255, tonumber(code:sub(5, 6), 16) / 255,
			"|cff" .. code }
	end
	return out
end

local function StandardClassCode(code)
	for _, class in pairs(RAID_CLASS_COLORS) do
		if type(class) == "table" and type(class.colorStr) == "string"
			and class.colorStr:lower() == code:sub(3):lower() then
			return true
		end
	end
	return false
end

local function held(scenario, ink, fs, what, when)
	if not fs:IsShown() or tostring(fs._text or "") == "" then return end
	for _, c in ipairs(colours(fs)) do
		-- Standard class colours are deliberately exact on dark grounds. The
		-- dedicated tint scenario proves that identity (and Letter's contrast
		-- still has to change a pale code); a contrast floor belongs to every
		-- other colour, not to Blizzard's fixed class palette.
		if what == "name" and type(c[4]) == "string" and StandardClassCode(c[4]) then
			-- exact class colour, checked by tint.lua
		else
		local at = reads(ink, c[1], c[2], c[3])
		if at < FLOOR then
			fail(scenario, ("%s: the %s (%s, \"%s\") reads at %.2f:1 on the look's ground, under %.1f"):format(when, what, c[4],
				tostring(fs._text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), at, FLOOR))
			return
		end
		end
	end
end

for _, style in ipairs(STYLES) do
	local scenario = "looks-read: " .. style .. ": the words read on the look's own ground"
	Mock.reset()
	Mock.bindings = { F = COMMAND }
	local classes = RAID_CLASS_COLORS
	RAID_CLASS_COLORS = CLASSES
	FT.install()
	local restore = strangers(CROWD)
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then
		ok, err = pcall(function()
			local P = ns.Prompt
			freshPrompt(ns, scenario)
			local p = ns.db.profile.prompt
			p.style, p.effects, p.showIcon, p.showQueue = style, "full", true, false
			P:ApplyStyle()
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			FT.settle()
			local r = P:Regions()
			local ink, fit = P.lib.ink, P.lib.fit
			if style ~= "glass" and style ~= "framed" and style ~= "minimal" and not r.look then
				fail(scenario, "SKIPPED -- " .. style .. " is not the look in use")
				return
			end
			-- (A look wearing its painting stands on the painted well, which
			-- the audit measures from the painting itself.)
			local painted = r.look and r.look.paintedArt and r.look.paintedArt.on
			if GROUND[style] and not painted and not (ink.hi >= GROUND[style]) then
				fail(scenario, ("the look judges its words against a ground of %.3f, and draws one of %.3f under them"):format(ink.hi or 0,
					GROUND[style]))
			end
			-- A short name beside the key's tag and the count, at the size set.
			local base = fit.base[r.name]
			local drawn = r.name._font and r.name._font.size
			if not (base and drawn) then
				fail(scenario, "the name has no size to read")
			elseif base < p.fontSize then
				fail(scenario, ("the look sets the name at %s, under the %s the player set"):format(tostring(base), tostring(p.fontSize)))
			elseif drawn < base then
				fail(scenario, ("\"Anna Aim\" is drawn at %s beside the tags, not at the %s it is set in"):format(tostring(drawn), tostring(base)))
			end
			-- And a long one, on the looks that hang two tags beside the
			-- name: it is drawn at its size too, a tag giving way.
			if LONG[style] and base then
				local long = { name = "Elowen Thistledown", short = "Elowen Thistledown", reason = "owed", buff = ns.ResolveBuff(true) }
				P:Paint(long, 2)
				P:Paint(long, 2)
				local size = r.name._font and r.name._font.size
				if not (size and size >= base) then
					fail(scenario, ("\"Elowen Thistledown\" is drawn at %s beside the tags, not at the %s it is set in"):format(tostring(size), tostring(base)))
				end
			end
			-- Both lines over a dark shadow, or outlined, where the ground is dark.
			if ink.light and p.textShadow ~= false then
				for what, fs in pairs({ name = r.name, ["reason line"] = r.sub }) do
					-- Luxe sets its reason in a tinted tag, where a shadow reads as dirt.
					if not (style == "luxe" and fs == r.sub) then
						local flags = tostring(fs._font and fs._font.flags or "")
						local s, o = fs._shadowColor or {}, fs._shadowOffset or {}
						local shadowed = (s[4] or 0) >= 0.75 and ((o[1] or 0) ~= 0 or (o[2] or 0) ~= 0)
							and (s[1] or 0) < 0.2 and (s[2] or 0) < 0.2 and (s[3] or 0) < 0.2
						if not (shadowed or flags:find("OUTLINE", 1, true)) then
							fail(scenario, "the " .. what .. " has neither a dark shadow nor an outline on a dark ground")
						end
					end
				end
			end
			-- Every reason, in both palettes, each with a class's colour on the name.
			local buff = ns.ResolveBuff(true)
			for _, palette in ipairs({ "standard", "colourblind" }) do
				p.reasonPalette = palette
				P:ApplyStyle()
				ns.addon:Tick()
				for _, row in ipairs(REASONS) do
					local entry = { name = "Brannoc Vale", short = "Brannoc", buff = buff }
					for k, v in pairs(row[2]) do entry[k] = v end
					P:Paint(entry, 2)
					local when = row[1] .. ", " .. palette
					held(scenario, ink, r.name, "name", when)
					held(scenario, ink, r.sub, "reason line", when)
				end
			end
			p.reasonPalette = "standard"
			P:ApplyStyle()
			ns.addon:Tick()
			-- Both outcomes.
			P:ShowOutcome("cast", "Anna Aim")
			held(scenario, ink, r.name, "name", "a buff that landed")
			held(scenario, ink, r.sub, "reason line", "a buff that landed")
			Mock.advance(3)
			FT.settle()
			owe(ns, "Anna Aim")
			ns.addon:Tick()
			P:ShowOutcome("failed", "Anna Aim", "Out of range.")
			held(scenario, ink, r.name, "name", "a refusal")
			held(scenario, ink, r.sub, "reason line", "a refusal")
			Mock.advance(3)
			FT.settle()
			-- The list.
			p.showQueue, p.queueRows = true, 3
			owe(ns, "Anna Aim")
			owe(ns, "Brannoc Vale")
			owe(ns, "Corwin Ash")
			P:ApplyStyle()
			ns.addon:Tick()
			local rows = 0
			for i, fs in ipairs(r.rows or {}) do
				if fs:IsShown() and tostring(fs._text or "") ~= "" then
					rows = rows + 1
					held(scenario, P.lib.ink, fs, "list's row " .. i, "the list")
				end
			end
			if rows == 0 then fail(scenario, "the list shows no row to read") end
		end)
	end
	restore()
	FT.uninstall()
	RAID_CLASS_COLORS = classes
	Mock.bindings = nil
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
