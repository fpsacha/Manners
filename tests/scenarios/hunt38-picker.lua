-- Hunt 38: the theme picker and the switching between the nine looks.
--
-- Hunt 38 asked what a player can reach with the new picker: a look picked
-- and put back leaves nothing of the other behind, a saved style the build no
-- longer knows is the default, the cards survive a character with nothing to
-- show, a broken look file and a narrow window.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

local STYLES = { "glass", "framed", "minimal", "luxe", "toast", "arcane", "ribbon", "letter", "leather" }
local ANNA = { nameplate1 = { "Anna", "Aim" } }
local CROWD = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Brannoc", "Vale" },
	nameplate3 = { "Corwin", "Ash" }, nameplate4 = { "Dagna", "Moss" } }

local function withTree(scenario, names, body, before)
	Mock.reset()
	if before then before() end
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

-- ------------------------------------------------------------------ state dump
-- Every region and frame under the prompt, with everything the recording tree
-- remembers about it, as text; and each function the region carries of its own
-- (a wrapped method shows as another function).
local VOLATILE = { _children = true, _groups = true, _serial = true, _ft = true, _startedAt = true,
	_name = true, _template = true }

local function ser(v, depth)
	local t = type(v)
	if t == "number" then return ("%.4f"):format(v) end
	if t ~= "table" then return tostring(v) end
	if v._serial then return "#" .. v._serial end
	if depth > 3 then return "{...}" end
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local out = {}
	for _, k in ipairs(keys) do
		local x = v[k]
		if type(x) ~= "function" then
			out[#out + 1] = tostring(k) .. "=" .. ser(x, depth + 1)
		end
	end
	return "{" .. table.concat(out, ",") .. "}"
end

local function dumpRegion(r)
	local f, keys = {}, {}
	for k in pairs(r) do
		if type(k) == "string" and k:sub(1, 1) == "_" and not VOLATILE[k] then keys[#keys + 1] = k end
	end
	table.sort(keys)
	for _, k in ipairs(keys) do f[k] = ser(r[k], 0) end
	-- Unset and the default are the same thing to the eye.
	if f._alpha == nil then f._alpha = "1.0000" end
	if f._shown == nil then f._shown = "true" end
	if f._desaturated == nil then f._desaturated = "false" end
	if f._color == "{1=1.0000,2=1.0000,3=1.0000}" or f._color == "{1=1.0000,2=1.0000,3=1.0000,4=1.0000}" then f._color = nil end
	f.points = ser(r.points, 0)
	-- A shadow with no offset is not drawn, whatever colour it was left in.
	if f._shadowOffset == nil or f._shadowOffset == "{1=0.0000,2=0.0000}" then f._shadowColor = nil end
	-- A line anchored at both sides is as wide as the anchors say: the width it
	-- was last given is not read (a look that leaves one is not leaving a fault).
	if r._kind == "FontString" then
		local left, right
		for _, pt in ipairs(r.points or {}) do
			left = left or tostring(pt[1]):find("LEFT") ~= nil
			right = right or tostring(pt[1]):find("RIGHT") ~= nil
		end
		if left and right then f._width = nil end
	end
	local sc = {}
	for k, fn in pairs(r.scripts or {}) do sc[k] = fn end
	f.scripts = sc
	local scNames = {}
	for k in pairs(sc) do scNames[#scNames + 1] = k end
	table.sort(scNames)
	local fns = {}
	for k, v in pairs(r) do
		if type(v) == "function" and type(k) == "string" then fns[k] = v end
	end
	f.fns = fns
	local fnNames = {}
	for k in pairs(fns) do fnNames[#fnNames + 1] = k end
	table.sort(fnNames)
	f.raw = { scripts = sc, fns = fns }
	f.scriptNames, f.fnNames = table.concat(scNames, ","), table.concat(fnNames, ",")
	f.scripts, f.fns = nil, nil
	f.visible = FT.visible(r)
	local g = {}
	for i, grp in ipairs(r._groups or {}) do
		local a = {}
		for j, anim in ipairs(grp._anims or {}) do a[j] = ser(anim, 0) end
		g[i] = { playing = grp._playing and true or false, looping = tostring(grp._looping), anims = table.concat(a, ";") }
	end
	f.groups = g
	return f
end

-- What Prompt's text layout and ground tables hold: the fonts per line, the
-- room each line was given, the sizes it settled on, the ink.
local function dumpKit(ns)
	local kit = ns.Prompt:LookKit()
	local out = {}
	local function keyed(name, t)
		local list = {}
		for k, v in pairs(t) do
			list[#list + 1] = (type(k) == "table" and ("#" .. tostring(k._serial)) or tostring(k)) .. "=" .. ser(v, 1)
		end
		table.sort(list)
		out[name] = table.concat(list, ",")
	end
	for _, k in ipairs({ "path", "flags", "width", "textX", "chipRoom", "right", "left", "twoLine" }) do
		out["fit." .. k] = ser(kit.fit[k], 0)
	end
	for _, k in ipairs({ "paths", "room", "base", "size", "drawn" }) do keyed("fit." .. k, kit.fit[k]) end
	for _, k in ipairs({ "light", "lo", "hi", "sub", "rowReason" }) do out["ink." .. k] = ser(kit.ink[k], 0) end
	local n = 0
	for _ in pairs(kit.ink.codes or {}) do n = n + 1 end
	out["ink.codes"] = tostring(n)
	return out
end

local function dumpAll(root, ns)
	local out = {}
	if ns then out.kit = dumpKit(ns) end
	local function walk(r)
		out[r._serial] = { r = r, d = dumpRegion(r) }
		for _, c in ipairs(r._children or {}) do walk(c) end
	end
	walk(root)
	-- Regions hung under a frame as children of the tree only; textures are in
	-- _children too in this tree.
	return out
end

local function describe(r)
	local k = r._kind or "?"
	local file = r._file and tostring(r._file):match("([^\\]+)$") or ""
	local txt = r._text and ("'" .. tostring(r._text):sub(1, 14) .. "'") or ""
	return ("#%d %s %s %s%s"):format(r._serial, k, r._name or "", file, txt)
end

local function diff(a, b, into, ignoreHidden, identity)
	if a.kit and b.kit then
		for k, v in pairs(a.kit) do
			if b.kit[k] ~= v then into[#into + 1] = ("Prompt's %s was %s now %s"):format(k, v, tostring(b.kit[k])) end
		end
	end
	for id, ea in pairs(a) do
		local eb = id ~= "kit" and b[id]
		if eb then
			local hidden = not ea.d.visible and not eb.d.visible
			-- A line with nothing in it draws nothing, wherever it is anchored.
			if ea.r._kind == "FontString" and ea.r._text == "" and eb.r._text == "" then hidden = true end
			if not (ignoreHidden and hidden) then
				if identity then
					for _, which in ipairs({ "scripts", "fns" }) do
						for k, fn in pairs(ea.d.raw[which]) do
							if eb.d.raw[which][k] ~= fn then
								into[#into + 1] = ("%s: %s.%s is another function"):format(describe(ea.r), which, k)
							end
						end
					end
				end
				for k, v in pairs(identity ~= "only" and ea.d or {}) do
					local w = eb.d[k]
					if k == "raw" then
					elseif type(v) == "table" then
						-- scripts, fns, groups: compare entry by entry
						local keys = {}
						for kk in pairs(v) do keys[kk] = true end
						for kk in pairs(w or {}) do keys[kk] = true end
						for kk in pairs(keys) do
							local x, y = v[kk], (w or {})[kk]
							if type(x) == "table" or type(y) == "table" then
								x = x or { playing = false, looping = "nil", anims = "" }
								y = y or { playing = false, looping = "nil", anims = "" }
								-- A group made since and not running is only a group.
								local idle = not x.playing and not y.playing and (x.anims == "" or y.anims == "")
								if not idle and (x.playing ~= y.playing or x.looping ~= y.looping or x.anims ~= y.anims) then
									into[#into + 1] = ("%s: animation group %s was %s/%s now %s/%s"):format(
										describe(ea.r), tostring(kk), tostring(x.playing), x.looping,
										tostring(y.playing), tostring(y.looping))
								end
							elseif x ~= y then
								into[#into + 1] = ("%s: %s.%s changed"):format(describe(ea.r), k, tostring(kk))
							end
						end
					elseif v ~= w then
						into[#into + 1] = ("%s: %s was %s now %s"):format(describe(ea.r), k, tostring(v), tostring(w))
					end
				end
				for k, w in pairs(identity ~= "only" and eb.d or {}) do
					if ea.d[k] == nil and type(w) ~= "table" then
						into[#into + 1] = ("%s: %s appeared: %s"):format(describe(ea.r), k, tostring(w))
					end
				end
			end
		end
	end
end

local VARIANTS = {
	{ name = "default" },
	{ name = "round icon, list, accent both", edit = function(p)
		p.roundIcon = true
		p.showQueue, p.queueRows = true, 3
		p.accentMode = "both"
	end },
	{ name = "no icon, no second line, no count, calm, light panel, large, list above", edit = function(p)
		p.showIcon, p.showSub, p.showCount = false, false, false
		p.effects = "calm"
		p.bgColor = { 0.95, 0.93, 0.85, 0.9 }
		p.fontColor = { 0.2, 0.1, 0.1, 1 }
		p.accentMode = "stripe"
		p.flashStyle = "off"
		p.width, p.height, p.fontSize = 320, 58, 17
		p.showQueue, p.queueRows = true, 2
		Mock.promptCentreY = 40
	end },
}

local function settle(ns)
	ns.addon:Tick()
	FT.settle()
end

local function setStyle(ns, style)
	ns.db.profile.prompt.style = style
	ns.Prompt:ApplyStyle()
	settle(ns)
end

-- What happens to the first look before the second is picked: nothing, or an
-- outcome showing when a fight starts (the pick is made in it).
local MOMENTS = {
	{ name = "settled" },
	{ name = "outcome then fight", combat = true,
		into = function(ns) ns.Prompt:ShowOutcome("failed", "Anna Aim", "Out of range.") end },
}

local function prepare(ns, scenario, variant)
	freshPrompt(ns, scenario)
	local p = ns.db.profile.prompt
	if variant.edit then variant.edit(p) end
	for _, n in ipairs({ "Anna Aim", "Brannoc Vale", "Corwin Ash" }) do owe(ns, n) end
end

-- What the recording tree cannot tell from the client, left to the three looks
-- Prompt draws itself: a texture there keeps one mask (the client's keeps
-- every one it was given, so a look taking its own off leaves the round
-- icon's).
local FILTERS = { "_mask was #%d+ now nil" }

-- `a` up, the moment happening, `b` picked (nil: the look stays), and back to
-- `a` after the fight if there was one: the dump, and the dump of `a` before.
local function play(ns, scenario, variant, moment, a, b)
	prepare(ns, scenario, variant)
	setStyle(ns, a)
	Mock.advance(10)
	setStyle(ns, a)
	local mine = dumpAll(UIParent, ns)
	if moment.into then moment.into(ns) FT.settle() end
	if moment.combat then
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		settle(ns)
	end
	for _, step in ipairs(type(b) == "table" and b or { b }) do
		ns.db.profile.prompt.style = step
		ns.Prompt:ApplyStyle()
		settle(ns)
	end
	if moment.combat then
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		settle(ns)
	end
	ns.db.profile.prompt.style = a
	ns.Prompt:ApplyStyle()
	Mock.advance(10)
	settle(ns)
	ns.Prompt:ApplyStyle()
	settle(ns)
	local out = dumpAll(UIParent, ns)
	Mock.optionsOpen = nil
	return out, mine
end

local NATIVE = { glass = true, framed = true, minimal = true }

local function compare(base, after, mine, a)
	local out = {}
	diff(base, after, out, true)
	diff(mine, after, out, false, "only")
	for i = #out, 1, -1 do
		for _, f in ipairs(NATIVE[a] and FILTERS or {}) do
			if out[i]:find(f) then table.remove(out, i) break end
		end
	end
	-- New regions the other look made must be hidden.
	for id, e in pairs(after) do
		if id ~= "kit" and not base[id] and e.d.visible and e.r._kind ~= "Frame" then
			out[#out + 1] = "new region visible: " .. describe(e.r)
		end
	end
	return out
end

-- ------------------------------------------------------------------ the pairs
-- Every look to every other and back, in the three situations a player makes
-- them in: at rest, with a list up and a round icon asked for, and with an
-- outcome showing when a fight starts, the pick made in it and the fight over.
-- What comes back is what a fresh start in that look draws: every region and
-- frame under the prompt (shown, alpha, size, points, font, colours, parent,
-- frame level, scripts, the methods it carries, its animations and whether
-- they play), and Prompt's text layout and ink. The fresh start is worked out
-- once per look, under the name of whichever scenario needs it first.
local PAIR_RUNS = {
	{ variant = VARIANTS[1], moment = MOMENTS[1], label = "at rest" },
	{ variant = VARIANTS[2], moment = MOMENTS[1], label = "round icon, list, both marks" },
	{ variant = VARIANTS[3], moment = MOMENTS[1], label = "no icon, calm, light panel, large" },
	{ variant = VARIANTS[1], moment = MOMENTS[2], label = "outcome, fight, pick" },
}

local BASES = {}
local function baseOf(a, run, scenario)
	local key = a .. "/" .. run.label
	if BASES[key] then return BASES[key] end
	withTree(scenario, CROWD, function(ns)
		BASES[key] = play(ns, scenario, run.variant, run.moment, a, nil)
	end)
	return BASES[key]
end

for _, run in ipairs(PAIR_RUNS) do
	for _, a in ipairs(STYLES) do
		for _, b in ipairs(STYLES) do
			if a ~= b then
				local scenario = ("hunt38-picker: switching %s -> %s -> %s (%s) leaves nothing behind")
					:format(a, b, a, run.label)
				local base = baseOf(a, run, scenario)
				if base then
					withTree(scenario, CROWD, function(ns)
						local after, mine = play(ns, scenario, run.variant, run.moment, a, b)
						local out = compare(base, after, mine, a)
						if #ns.errors > 0 then
							out[#out + 1] = "guarded: " .. tostring(ns.errors[1].where) .. " -> " .. tostring(ns.errors[1].err)
						end
						if #out > 0 then
							fail(scenario, #out .. " differences, first: " .. table.concat(out, " | ", 1, math.min(#out, 6)))
						end
					end)
				end
			end
		end
	end
end

-- ------------------------------------------------------------------ the cards
-- Every card of the gallery, clicked in every order, in one session with the
-- options window open: the style is the card's, the prompt draws that look and
-- no other, one card is marked, and nothing threw.
do
	local scenario = "hunt38-picker: clicking every card after every other draws that look and only that"
	withTree(scenario, CROWD, function(ns)
		prepare(ns, scenario, VARIANTS[1])
		ns.OpenOptions("appearance", true)
		ns.Prompt:ExitTest()
		local UI = ns.WindowUI
		local row = UI.RowFor("appearance.style")
		if not (row and row.cards) then fail(scenario, "SKIPPED -- the gallery is not on the Look page") return end
		local function click(key)
			for _, card in ipairs(row.cards) do
				if card:IsShown() and card.key == key then
					local onClick = card:GetScript("OnClick")
					onClick(card, "LeftButton", false)
					return true
				end
			end
		end
		local p = ns.db.profile.prompt
		for _, a in ipairs(STYLES) do
			for _, b in ipairs(STYLES) do
				for _, key in ipairs({ a, b }) do
					if not click(key) then
						fail(scenario, "no card for " .. key)
					else
						settle(ns)
						if p.style ~= key then fail(scenario, ("clicking %s left the style at %s"):format(key, tostring(p.style))) end
						local r = ns.Prompt:Regions()
						if r.look ~= ns.Looks.Get(key) then
							fail(scenario, ("after %s then %s the prompt draws %s"):format(a, b, tostring(r.look and r.look.key)))
						end
						for other, look in pairs(ns.Looks.list) do
							if look.own and look ~= r.look then
								for i, x in ipairs(look.own) do
									if FT.visible(x) then
										fail(scenario, ("after %s then %s, %s's region %d is still drawn"):format(a, b, other, i))
										break
									end
								end
							end
						end
						local marked = 0
						for _, card in ipairs(row.cards) do
							if card:IsShown() and card.selected then marked = marked + 1 end
						end
						if marked ~= 1 then fail(scenario, ("after %s then %s, %d cards are marked"):format(a, b, marked)) end
					end
				end
			end
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
end

-- ------------------------------------------------------------------ a fight
-- Every look picked in a fight waits for its end, whatever look is up: the
-- secure button is not touched while it lasts, and the pick is drawn when it is
-- over.
do
	local scenario = "hunt38-picker: a look picked in a fight is drawn when the fight is over, whichever looks they are"
	withTree(scenario, ANNA, function(ns)
		freshPrompt(ns, scenario)
		owe(ns, "Anna Aim")
		local p = ns.db.profile.prompt
		for _, a in ipairs(STYLES) do
			for _, b in ipairs(STYLES) do
				setStyle(ns, a)
				Mock.protect(ns.Prompt:GetButton())
				Mock.protectedCalls = {}
				Mock.inCombat = true
				ns.addon:PLAYER_REGEN_DISABLED()
				p.style = b
				ns.Prompt:ApplyStyle()
				settle(ns)
				if ns.Prompt:Regions().look ~= ns.Looks.Get(a) then
					fail(scenario, ("%s was restyled as %s in a fight"):format(a, b))
				end
				if #Mock.protectedCalls > 0 then
					fail(scenario, ("%s -> %s touched the secure button in a fight: %s"):format(a, b, table.concat(Mock.protectedCalls, ", ")))
				end
				Mock.inCombat = false
				ns.addon:PLAYER_REGEN_ENABLED()
				settle(ns)
				if ns.Prompt:Regions().look ~= ns.Looks.Get(b) then
					fail(scenario, ("%s was picked in a fight over %s and not drawn after it"):format(b, a))
				end
				if ns.Prompt.pendingStyle then fail(scenario, "the pick was still pending after the fight") end
			end
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
end

-- ------------------------------------------------------------------ saved styles
-- A style the build does not know (three that lived only in builds nobody
-- got, nothing, a number, a table, another case, a key of the language's own)
-- is the default look wherever it comes from: a saved profile, a profile
-- switched to, an import. None of them throws, and the prompt is drawn.
local GARBAGE = { "whisper", "heritage", "slate", "Luxe", "", "__index", "list", 7, true, 0 / 0, {} }

do
	local scenario = "hunt38-picker: a style no look has is the default look, wherever it comes from"
	withTree(scenario, ANNA, function(ns)
		freshPrompt(ns, scenario)
		owe(ns, "Anna Aim")
		local p = ns.db.profile.prompt
		local seen = #(ns.errors or {})
		local function drawn(why)
			ns.Prompt:ApplyStyle()
			settle(ns)
			if p.style ~= "glass" then fail(scenario, why .. ": the style is " .. tostring(p.style)) end
			if ns.Prompt:Regions().look ~= nil then fail(scenario, why .. ": the prompt does not draw the default look") end
			for key, look in pairs(ns.Looks.list) do
				for i, x in ipairs(look.own or {}) do
					if FT.visible(x) then fail(scenario, why .. (": %s's region %d is drawn"):format(key, i)) break end
				end
			end
			for i = seen + 1, #(ns.errors or {}) do
				local e = ns.errors[i]
				fail(scenario, why .. ": guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
			seen = #(ns.errors or {})
		end
		-- A saved profile, read at the next login.
		for _, junk in ipairs(GARBAGE) do
			for _, from in ipairs({ "glass", "luxe", "leather" }) do
				setStyle(ns, from)
				p.style = junk
				ns.ClampSettings()
				drawn(("saved %s over %s"):format(tostring(junk), from))
			end
		end
		-- nil is a setting that was never written.
		setStyle(ns, "ribbon")
		p.style = nil
		ns.ClampSettings()
		drawn("a style that was never saved")
		-- A string from a build that had one of them, pasted in.
		for _, junk in ipairs({ "whisper", "heritage", "slate" }) do
			setStyle(ns, "letter")
			p.style = junk
			local text = ns.ExportSettings()
			setStyle(ns, "toast")
			local ok, message = ns.ImportSettings(text)
			if not ok then fail(scenario, ("importing %s was refused: %s"):format(junk, tostring(message))) end
			drawn("imported " .. junk)
		end
		-- And back: what an import changed, its undo puts back, the look included.
		setStyle(ns, "arcane")
		p.style = "ribbon"
		local text = ns.ExportSettings()
		setStyle(ns, "leather")
		local ok = ns.ImportSettings(text)
		if not ok or p.style ~= "ribbon" or ns.Prompt:Regions().look ~= ns.Looks.Get("ribbon") then
			fail(scenario, "importing a ribbon profile did not draw the ribbon: " .. tostring(p.style))
		end
		ns.addon:HandleSlash("import undo")
		if p.style ~= "leather" or ns.Prompt:Regions().look ~= ns.Looks.Get("leather") then
			fail(scenario, "undoing the import did not bring the leather back: " .. tostring(p.style))
		end
	end)
end

-- A look's own style survives the round trip through a shared string, for each.
do
	local scenario = "hunt38-picker: every look's style goes out in a string and comes back drawn"
	withTree(scenario, ANNA, function(ns)
		freshPrompt(ns, scenario)
		owe(ns, "Anna Aim")
		local p = ns.db.profile.prompt
		for _, key in ipairs(STYLES) do
			setStyle(ns, key)
			local text = ns.ExportSettings()
			setStyle(ns, key == "glass" and "luxe" or "glass")
			local ok, message = ns.ImportSettings(text)
			if not ok then
				fail(scenario, ("%s's own string was refused: %s"):format(key, tostring(message)))
			else
				settle(ns)
				if p.style ~= key then fail(scenario, ("%s came back as %s"):format(key, tostring(p.style))) end
				if ns.Prompt:Regions().look ~= ns.Looks.Get(key) then
					fail(scenario, key .. " came back and was not drawn")
				end
			end
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
end

-- A profile switched to wears its own look, and the one left takes its down.
do
	local scenario = "hunt38-picker: switching profile switches look and leaves nothing of the old one"
	withTree(scenario, ANNA, function(ns)
		freshPrompt(ns, scenario)
		owe(ns, "Anna Aim")
		if not ns.db.SetProfile then fail(scenario, "SKIPPED -- the mock database has no profiles") return end
		setStyle(ns, "glass")
		for _, key in ipairs(STYLES) do
			ns.db:SetProfile("Alt " .. key)
			ns.db.profile.prompt.style = key
			ns.addon:RefreshConfig("OnProfileChanged")
			settle(ns)
			if ns.Prompt:Regions().look ~= ns.Looks.Get(key) then
				fail(scenario, "profile " .. key .. " does not draw its look")
			end
			ns.db:SetProfile("Default")
			ns.addon:RefreshConfig("OnProfileChanged")
			settle(ns)
			local r = ns.Prompt:Regions()
			if r.look ~= ns.Looks.Get(ns.db.profile.prompt.style) then
				fail(scenario, "back on Default the prompt still draws " .. tostring(r.look and r.look.key))
			end
			for other, look in pairs(ns.Looks.list) do
				if look.own and look ~= r.look then
					for i, x in ipairs(look.own) do
						if FT.visible(x) then fail(scenario, ("%s's region %d is drawn on Default after %s"):format(other, i, key)) break end
					end
				end
			end
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
end

-- ------------------------------------------------------------------ the round switch
-- "Round the icon off" is greyed out on exactly the looks that do not read it:
-- toggling it changes nothing a look draws there, and on every look that does
-- read it the toggle is live. (The answer is the prompt's own, asked of each
-- look: two fresh starts that differ only in that setting.)
do
	local scenario = "hunt38-picker: Round the icon off is greyed out on the looks that ignore it, and only those"
	for _, key in ipairs(STYLES) do
		local drawn, off = {}, nil
		for _, round in ipairs({ false, true }) do
			withTree(scenario, CROWD, function(ns)
				prepare(ns, scenario, { name = "round", edit = function(p) p.roundIcon = round end })
				setStyle(ns, key)
				Mock.advance(10)
				setStyle(ns, key)
				drawn[round] = dumpAll(ns.Prompt:GetButton(), ns)
				if not round then
					local toggle = H.findOption(ns.optionsTable, "roundIcon")
					off = toggle and toggle.disabled() == true
				end
			end)
		end
		if drawn[false] and drawn[true] and off ~= nil then
			local out = {}
			diff(drawn[false], drawn[true], out, true)
			local reads = #out > 0
			if reads and off then
				fail(scenario, key .. " draws the icon differently when asked for a round one, and the switch is greyed out")
			elseif not reads and not off then
				fail(scenario, key .. " ignores the round icon switch, and the switch is live")
			end
		end
	end
end
