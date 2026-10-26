-- Hunt 38: faults found in the code every look shares (Prompt/Text.lua,
-- Prompt/Paint.lua, Looks/Looks.lua's kit) and in what the looks hand it.
--
-- Run on the recording CreateFrame in tests/frametree.lua. Every name starts
-- with "hunt38-shared:" so a mutation can name exactly one.
--
-- What it holds:
--   * a look whose ground is its own (Ribbon's cloth, Leather's hide) reads
--     the same whatever colour the player gave the panel (Letter's parchment
--     is tinted a little by it, and look-letter.lua holds its ink to the paper
--     instead): the
--     shared text code judges every colour code against the panel's own colour,
--     so a look that is not drawn on the panel has to say so (`inkOnDark`, or
--     the ink it writes), and Ribbon did not: on a pale panel colour its list's
--     reasons went from a peach to a near-black on dark crimson cloth, and its
--     gold name a shade of mustard.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local COLOURS = {
	MAGE = "ff3fc7eb", PRIEST = "ffffffff", ROGUE = "fffff468", SHAMAN = "ff0070dd", WARRIOR = "ffc69b6d",
}

local function withTree(scenario, names, body)
	Mock.reset()
	FT.install()
	local restore = strangers(names or {})
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns, scenario) end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function plain(text)
	return (tostring(text):gsub("|", "!"))
end

-- ------------------------------------------------------------------ 1
-- The text a look writes does not depend on the panel colour when the look
-- does not draw the panel colour as its ground.
for _, style in ipairs({ "ribbon", "leather" }) do
	local scenario = "hunt38-shared: " .. style .. " writes the same ink on a pale panel colour as on a dark one"
	withTree(scenario, { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" } }, function(ns)
		local saved = RAID_CLASS_COLORS
		local colours = {}
		for class, str in pairs(COLOURS) do colours[class] = { colorStr = str } end
		RAID_CLASS_COLORS = colours
		local ok, err = pcall(function()
			freshPrompt(ns, scenario)
			local p = ns.db.profile.prompt
			p.style, p.showSub, p.showIcon, p.classColor, p.showQueue, p.queueRows = style, true, true, true, true, 2
			local r
			local function written(bg, class)
				p.bgColor = { bg[1], bg[2], bg[3], bg[4] }
				ns.Prompt:ApplyStyle()
				r = ns.Prompt:Regions()
				Mock.unitClass = class
				owe(ns, "Anna Aim")
				owe(ns, "Brannoc Vale")
				ns.addon:Tick()
				FT.settle()
				Mock.advance(0.5)
				FT.settle()
				local rows = {}
				for i = 1, 2 do rows[i] = r.rows[i]:GetText() end
				return { name = r.name:GetText(), sub = r.sub:GetText(), rows = rows }
			end
			local dark = { 0.04, 0.04, 0.06, 0.88 }
			local lights = { { 1, 1, 1, 1 }, { 0.95, 0.95, 0.88, 1 }, { 0.86, 0.84, 0.78, 0.92 } }
			for class in pairs(COLOURS) do
				local base = written(dark, class)
				if not tostring(base.rows[1]):find("|c", 1, true) and not tostring(base.rows[2]):find("|c", 1, true) then
					fail(scenario, "SKIPPED -- no list row carries a colour code, so there is nothing to compare")
					return
				end
				for _, light in ipairs(lights) do
					local got = written(light, class)
					local label = ("%s, panel %.2f %.2f %.2f"):format(class, light[1], light[2], light[3])
					if got.name ~= base.name then
						fail(scenario, ("%s: the name reads %s, not %s as on a dark panel"):format(label, plain(got.name),
							plain(base.name)))
					end
					if got.sub ~= base.sub then
						fail(scenario, ("%s: the reason reads %s, not %s as on a dark panel"):format(label, plain(got.sub),
							plain(base.sub)))
					end
					for i = 1, 2 do
						if got.rows[i] ~= base.rows[i] then
							fail(scenario, ("%s: row %d reads %s, not %s as on a dark panel"):format(label, i,
								plain(got.rows[i]), plain(base.rows[i])))
						end
					end
				end
			end
		end)
		RAID_CLASS_COLORS = saved
		if not ok then error(err, 0) end
	end)
end
