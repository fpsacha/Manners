-- A flat prompt (1.11.9). A player asked for a minimal look with no border
-- round the icon and no outline or shadow on the words. Look has two switches
-- for the built-in looks (Glass, Framed, Minimal): Frame round the icon (the
-- bezel and the shade under the icon) and Shadow and outline on the text. Both
-- on by default, so nothing changes for anybody who leaves them.
--
-- Every scenario name starts with "flatlook:" so the mutations in
-- tests/mutations/flatlook.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local function withTree(scenario, body)
	Mock.reset()
	FT.install()
	local restore = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ns = load(scenario)
	local ok, err = true, nil
	if ns then ok, err = pcall(body, ns) end
	restore()
	FT.uninstall()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function shown(r) return r ~= nil and FT.visible(r) end

local function armed(ns, style, set)
	freshPrompt(ns, "flatlook")
	local p = ns.db.profile.prompt
	p.style = style
	for k, v in pairs(set or {}) do p[k] = v end
	ns.Prompt:ApplyStyle()
	owe(ns, "Anna Aim")
	ns.addon:Tick()
	return ns.Prompt:Regions()
end

do
	local scenario = "flatlook: the icon's frame is drawn by default and can be taken away"
	for _, style in ipairs({ "glass", "framed", "minimal" }) do
		withTree(scenario, function(ns)
			local r = armed(ns, style)
			if not shown(r.bezel) then fail(scenario, style .. ": no bezel by default") end
			r = armed(ns, style, { iconFrame = false })
			if shown(r.bezel) then fail(scenario, style .. ": the bezel is drawn with Frame round the icon off") end
			if shown(r.iconShade) then fail(scenario, style .. ": the shade under the icon is drawn with the frame off") end
		end)
	end
end

do
	local scenario = "flatlook: the text's shadow and outline are drawn by default and can be taken away"
	for _, style in ipairs({ "glass", "minimal" }) do
		withTree(scenario, function(ns)
			local r = armed(ns, style)
			local s = r.name._shadowColor or {}
			if (s[4] or 0) <= 0 then fail(scenario, style .. ": no shadow under the name by default") end
			r = armed(ns, style, { textShadow = false })
			for what, fs in pairs({ name = r.name, ["reason line"] = r.sub }) do
				local shadow = fs._shadowColor or {}
				if (shadow[4] or 0) > 0 then fail(scenario, ("%s: the %s has a shadow with the switch off"):format(style, what)) end
				local flags = fs._font and fs._font.flags or ""
				if tostring(flags):find("OUTLINE", 1, true) then
					fail(scenario, ("%s: the %s is outlined with the switch off"):format(style, what))
				end
			end
		end)
	end
end

do
	local scenario = "flatlook: Look has both switches, on by default"
	withTree(scenario, function(ns)
		freshPrompt(ns, scenario)
		for _, key in ipairs({ "iconFrame", "textShadow" }) do
			local control = H.findOption(ns.optionsTable, key)
			if not control then
				fail(scenario, "Look has no " .. key .. " switch")
			elseif ns.db.profile.prompt[key] ~= true then
				fail(scenario, key .. " is not on in a new profile")
			end
		end
	end)
end
