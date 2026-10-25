-- The look picker: a gallery of cards on the options window's Look page
-- (Options/Window/WidgetsTheme.lua), one per look in the registry
-- (Looks/Looks.lua), drawn from Textures/Previews by tools/make_look_previews.py.
--
-- What it promises: a card for every look the registry holds and none that is
-- not there, in the dropdown's order; the chosen look marked and no other; a
-- click that sets the style and restyles the prompt as the dropdown's pick
-- does, in a fight too, with nothing the picker makes secure and no secure
-- attribute of the prompt changed by it; no OnUpdate in it, ever; cards that fit
-- the page's width in two or three to a row, whatever their number, and never
-- overlap; the search finding it as style, look or theme; the dropdown still
-- the model's control, so the fallback dialog offers every look too; all eight
-- translations of what it says; and pictures that are current.
--
-- Called by scenarios.lua with the addon directory and its helpers. Every name
-- starts with "theme-picker:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function press(frame)
	local onClick = frame and frame:GetScript("OnClick")
	if onClick then onClick(frame, "LeftButton", false) end
end

local function enter(card)
	card._mouseOver = true
	local fn = card:GetScript("OnEnter")
	if fn then fn(card) end
end

local function leave(card)
	card._mouseOver = false
	local fn = card:GetScript("OnLeave")
	if fn then fn(card) end
end

-- One mage's session with the options window open on Look, everything put
-- back. `body(ns, UI, row)`: the gallery's row.
local function with(scenario, body)
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.OpenOptions("appearance", true)
		ns.Prompt:ExitTest()
		local UI = ns.WindowUI
		local row = UI.RowFor("appearance.style")
		if not (row and row.cards and UI.RowShown("appearance.style")) then
			fail(scenario, "SKIPPED -- the gallery is not on the Look page")
			return
		end
		body(ns, UI, row)
		noErrors(scenario, ns)
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- The keys of the registry in the dropdown's order.
local function registry(ns)
	local _, sorting = ns.Looks.Choices()
	return sorting
end

-- The shown cards, in order.
local function shown(row)
	local out = {}
	for i = 1, #row.cards do
		local card = row.cards[i]
		if card:IsShown() then out[#out + 1] = card end
	end
	return out
end

local function cardFor(row, key)
	for _, card in ipairs(shown(row)) do
		if card.key == key then return card end
	end
end

local function register(ns, key, look)
	look.fallback = look.fallback or "glass"
	ns.Looks.Register(key, look)
end

-- ------------------------------------------------------------------ the page
do
	local scenario = "theme-picker: the Look page leads with the gallery, in place of the dropdown"
	with(scenario, function(ns, UI, row)
		local where = UI.Where("appearance.style")
		if where.e.kind ~= "themes" then fail(scenario, "Panel style is drawn as " .. tostring(where.e.kind)) end
		if row.field then fail(scenario, "the dropdown is drawn as well as the cards") end
		local first = UI.Model("appearance").sections[1]
		if where.sec ~= first then fail(scenario, "the gallery is not the page's first section") end
		local entry
		for _, section in ipairs(ns.WindowLayout.pages.appearance.sections) do
			for _, item in ipairs(section.items) do
				if type(item) == "table" and item[1] == "appearance.style" then entry = item end
			end
		end
		if not (entry and entry.widget == "themes") then
			fail(scenario, "the layout does not place Panel style as widget = \"themes\"")
		end
	end)
end

-- ------------------------------------------------------------------ the cards
do
	local scenario = "theme-picker: one card per registered look, in the dropdown's order, and a new look gets one"
	with(scenario, function(ns, UI, row)
		local keys = registry(ns)
		local cards = shown(row)
		if #keys < 6 then fail(scenario, "the registry holds only " .. #keys .. " looks") end
		if #cards ~= #keys then
			fail(scenario, ("%d cards for %d looks"):format(#cards, #keys))
		end
		for i, key in ipairs(keys) do
			local card = cards[i]
			if not card or card.key ~= key then
				fail(scenario, ("card %d is %s, the dropdown's %d is %s"):format(i, tostring(card and card.key), i, key))
			elseif card.title:GetText() ~= (ns.Looks.Card(key)) then
				fail(scenario, key .. "'s card is called " .. tostring(card.title:GetText()))
			end
		end

		-- A look registered later, by the registry's own interface and nothing
		-- else: the card appears, named and described from its label.
		register(ns, "fake", { name = "Fake -- a made-up look", order = 60 })
		ns.RefreshOptionsDisplay()
		cards = shown(row)
		if #cards ~= #keys + 1 then
			fail(scenario, ("a look was registered and the gallery has %d cards, not %d"):format(#cards, #keys + 1))
		end
		local fake = cardFor(row, "fake")
		if not fake then
			fail(scenario, "the new look has no card")
		else
			if fake.title:GetText() ~= "Fake" then fail(scenario, "its card is called " .. tostring(fake.title:GetText())) end
			if fake.desc:GetText() ~= "a made-up look" then
				fail(scenario, "its card says " .. tostring(fake.desc:GetText()))
			end
			if fake.shot:IsShown() or not fake.mark:IsShown() then
				fail(scenario, "a look with no picture drew one anyway")
			end
		end

		-- A look that says its own title and line keeps them, whatever its
		-- label reads.
		register(ns, "fake2", { name = "Whatever the label says", order = 61, title = "Second", description = "its own line" })
		ns.RefreshOptionsDisplay()
		local second = cardFor(row, "fake2")
		if not second or second.title:GetText() ~= "Second" or second.desc:GetText() ~= "its own line" then
			fail(scenario, "a look's own title and description are not on its card")
		end

		-- And a look taken away loses its card.
		ns.Looks.list.fake, ns.Looks.list.fake2 = nil, nil
		ns.RefreshOptionsDisplay()
		if #shown(row) ~= #keys or cardFor(row, "fake") then
			fail(scenario, "a look left the registry and its card stayed")
		end
	end)
end

do
	local scenario = "theme-picker: a card reads its label split at an English, en or em dash"
	with(scenario, function(ns)
		-- Whatever dash a translation writes its label with, name and line apart.
		local cases = {
			{ "A -- b c", "A", "b c" },
			{ "Glas \226\128\147 dunkler Hintergrund", "Glas", "dunkler Hintergrund" },
			{ "Titel \226\128\148 eine Zeile", "Titel", "eine Zeile" },
			{ "\231\142\187\231\146\131\226\128\148\226\128\148\230\183\177\232\137\178", "\231\142\187\231\146\131", "\230\183\177\232\137\178" },
			{ "Only a name", "Only a name", "" },
		}
		for i, case in ipairs(cases) do
			register(ns, "split" .. i, { name = case[1], order = 70 + i })
			local title, line = ns.Looks.Card("split" .. i)
			if title ~= case[2] or line ~= case[3] then
				fail(scenario, ("%q reads as %q and %q"):format(case[1], tostring(title), tostring(line)))
			end
		end
	end)
end

-- ------------------------------------------------------------------ chosen
do
	local scenario = "theme-picker: the chosen card is the profile's style, and only that card"
	with(scenario, function(ns, UI, row)
		for _, key in ipairs(registry(ns)) do
			ns.db.profile.prompt.style = key
			ns.RefreshOptionsDisplay()
			for _, card in ipairs(shown(row)) do
				local want = card.key == key
				if (card.selected == true) ~= want then
					fail(scenario, ("with %s chosen, the %s card is %s"):format(key, card.key,
						card.selected and "marked" or "not marked"))
				end
				if card.badge:IsShown() ~= want then
					fail(scenario, ("with %s chosen, the tick on %s is %s"):format(key, card.key,
						card.badge:IsShown() and "up" or "down"))
				end
				if card.inner[1]:IsShown() ~= want then
					fail(scenario, ("with %s chosen, the gold edge on %s is %s"):format(key, card.key,
						card.inner[1]:IsShown() and "up" or "down"))
				end
				local gold = card.edges[1]._color
				local isGold = gold and gold[1] == 1 and gold[3] == 0
				if want ~= (isGold == true) then
					fail(scenario, ("with %s chosen, the border of %s is %s"):format(key, card.key,
						isGold and "gold" or "not gold"))
				end
			end
		end
	end)
end

do
	local scenario = "theme-picker: the card under the pointer lights up and lets go"
	with(scenario, function(ns, UI, row)
		ns.db.profile.prompt.style = "glass"
		ns.RefreshOptionsDisplay()
		local other = cardFor(row, "luxe")
		local rest = other.edges[1]._color
		enter(other)
		if not other.wash:IsShown() then fail(scenario, "a card under the pointer has no wash") end
		local hot = other.edges[1]._color
		if not (hot and rest and hot[1] > rest[1]) then fail(scenario, "its border did not lighten") end
		leave(other)
		if other.wash:IsShown() then fail(scenario, "the wash stayed after the pointer left") end
		local back = other.edges[1]._color
		if not (back and back[1] == rest[1]) then fail(scenario, "its border did not go back") end
		-- The chosen card keeps its own look under the pointer.
		local chosen = cardFor(row, "glass")
		enter(chosen)
		if not chosen.badge:IsShown() or not chosen.inner[1]:IsShown() then
			fail(scenario, "the chosen card lost its mark under the pointer")
		end
		leave(chosen)
	end)
end

-- ------------------------------------------------------------------ a click
do
	local scenario = "theme-picker: a click sets the style and restyles the prompt at once"
	with(scenario, function(ns, UI, row)
		local P = ns.db.profile.prompt
		P.style = "glass"
		ns.RefreshOptionsDisplay()
		for _, key in ipairs({ "luxe", "framed", "arcane", "minimal", "toast", "glass" }) do
			local card = cardFor(row, key)
			if not card then
				fail(scenario, "no card for " .. key)
			else
				press(card)
				if P.style ~= key then
					fail(scenario, ("clicking %s left the style at %s"):format(key, tostring(P.style)))
				end
				local r = ns.Prompt:Regions()
				if r.look ~= ns.Looks.Get(key) then
					fail(scenario, ("after clicking %s the prompt draws %s"):format(key, tostring(r.look and r.look.key)))
				end
				for _, c in ipairs(shown(row)) do
					if (c.selected == true) ~= (c.key == key) then
						fail(scenario, ("after clicking %s the %s card is %s"):format(key, c.key,
							c.selected and "marked" or "not marked"))
					end
				end
				if UI.PeekTarget() >= 1 then
					fail(scenario, "the window did not step aside for the prompt after the click")
				end
				-- The next peek is not the last one's.
				UI.EndPeek()
			end
		end
		-- The chosen one again changes nothing, and restyles nothing.
		local calls, real = 0, ns.Prompt.ApplyStyle
		ns.Prompt.ApplyStyle = function(...)
			calls = calls + 1
			return real(...)
		end
		press(cardFor(row, "glass"))
		ns.Prompt.ApplyStyle = real
		if P.style ~= "glass" then fail(scenario, "clicking the chosen look changed it") end
		if calls ~= 0 then fail(scenario, "clicking the chosen look restyled the prompt " .. calls .. " times") end
	end)
end

do
	local scenario = "theme-picker: a click in a fight is kept and flushed when it ends, touching nothing secure"
	with(scenario, function(ns, UI, row)
		local P = ns.db.profile.prompt
		P.style = "glass"
		ns.RefreshOptionsDisplay()
		H.owe(ns, "Anna Aim")
		ns.addon:Tick()
		local button = ns.Prompt:GetButton()
		Mock.protect(button)
		Mock.inCombat = true
		Mock.protectedCalls = {}
		local before = ns.Prompt:Regions().look
		press(cardFor(row, "luxe"))
		if P.style ~= "luxe" then fail(scenario, "the click in a fight did not set the style: " .. tostring(P.style)) end
		if ns.Prompt:Regions().look ~= before then fail(scenario, "the prompt was restyled in a fight") end
		if not ns.Prompt.pendingStyle then fail(scenario, "the restyle was not kept for the end of the fight") end
		if #Mock.protectedCalls > 0 then
			fail(scenario, "the secure button was touched in a fight: " .. table.concat(Mock.protectedCalls, ", "))
		end
		if not cardFor(row, "luxe").selected then fail(scenario, "the card does not show the pick in a fight") end
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		if ns.Prompt:Regions().look ~= ns.Looks.Get("luxe") then
			fail(scenario, "the pick was not drawn when the fight ended")
		end
	end)
end

do
	local scenario = "theme-picker: choosing a look never changes the secure button's attributes"
	with(scenario, function(ns, UI, row)
		H.owe(ns, "Anna Aim")
		ns.addon:Tick()
		local button = ns.Prompt:GetButton()
		local function snapshot()
			local out = {}
			for k, v in pairs(button.attributes) do out[k] = tostring(v) end
			return out
		end
		local base, count = snapshot(), 0
		for _ in pairs(base) do count = count + 1 end
		if count == 0 then
			fail(scenario, "SKIPPED -- the prompt armed nothing to compare")
			return
		end
		for _, key in ipairs(registry(ns)) do
			press(cardFor(row, key))
			ns.addon:Tick()
			local now = snapshot()
			for k, v in pairs(base) do
				if now[k] ~= v then fail(scenario, ("%s changed %s: %s -> %s"):format(key, k, v, tostring(now[k]))) end
			end
			for k, v in pairs(now) do
				if base[k] == nil then fail(scenario, ("%s set %s to %s"):format(key, k, v)) end
			end
		end
	end)
end

do
	local scenario = "theme-picker: a greyed-out control cannot be clicked"
	with(scenario, function(ns, UI, row)
		local P = ns.db.profile.prompt
		P.style = "glass"
		ns.RefreshOptionsDisplay()
		local def = ns.optionsTable.args.appearance.args.style
		local was = def.disabled
		def.disabled = function() return true end
		ns.RefreshOptionsDisplay()
		press(cardFor(row, "luxe"))
		local card = cardFor(row, "luxe")
		local dimmed = card.shot:IsDesaturated() and not card:IsEnabled()
		def.disabled = was
		if P.style ~= "glass" then fail(scenario, "a card was clicked while the control was greyed out") end
		if not dimmed then fail(scenario, "the cards are not greyed while the control is greyed out") end
		ns.RefreshOptionsDisplay()
		if card.shot:IsDesaturated() or not card:IsEnabled() then
			fail(scenario, "the cards stayed grey once the control was back")
		end
	end)
end

-- ------------------------------------------------------------------ nothing secure, no timers
do
	local scenario = "theme-picker: nothing in the picker is secure, runs on a timer, or hangs off the prompt"
	with(scenario, function(ns, UI, row)
		local prompt = ns.Prompt:GetButton()
		local function parts(card)
			return { card, card.badge }
		end
		local function check(when)
			for _, card in ipairs(row.cards) do
				for _, frame in ipairs(parts(card)) do
					if frame._protected then fail(scenario, when .. ": a frame of the picker is protected") end
					if type(frame._template) == "string" and frame._template:find("Secure", 1, true) then
						fail(scenario, when .. ": the card is made from " .. frame._template)
					end
					if frame.scripts.OnUpdate then fail(scenario, when .. ": the picker has an OnUpdate") end
					for _, point in ipairs(frame.points) do
						local to = point[2]
						if to == prompt or to == ns.Prompt:Regions().art or to == UIParent then
							fail(scenario, when .. ": a part of the picker is anchored to the prompt or the screen")
						end
					end
				end
			end
		end
		check("open")
		enter(cardFor(row, "luxe"))
		check("under the pointer")
		leave(cardFor(row, "luxe"))
		press(cardFor(row, "toast"))
		check("after a click")
		-- The row's own frame has none either, unless the search is flashing it.
		if row.frame.scripts.OnUpdate then fail(scenario, "the gallery's frame runs an OnUpdate") end
		ns.CloseOptions()
		check("shut")
		if ns.OptionsWindow:IsShown() then fail(scenario, "SKIPPED -- the window did not close") end
	end)
end

-- ------------------------------------------------------------------ the dropdown
do
	local scenario = "theme-picker: the dropdown is still the model's control, with every look, as the fallback draws it"
	with(scenario, function(ns, UI, row)
		local item = ns.WindowBind.Item("appearance.style")
		local def = ns.optionsTable.args.appearance.args.style
		if def.type ~= "select" then fail(scenario, "Panel style is a " .. tostring(def.type)) end
		-- As AceConfigDialog asks them, with the info it hands out.
		local values = type(def.values) == "function" and def.values(item.info) or def.values
		local sorting = type(def.sorting) == "function" and def.sorting(item.info) or def.sorting
		for _, key in ipairs(registry(ns)) do
			if not (values and values[key]) then
				fail(scenario, "the dropdown has no " .. key)
			elseif values[key] ~= ns.Looks.list[key].name then
				fail(scenario, ("the dropdown calls %s %q, not its label"):format(key, tostring(values[key])))
			end
			local listed = false
			for _, k in ipairs(sorting or {}) do
				if k == key then listed = true end
			end
			if not listed then fail(scenario, "the dropdown's order leaves out " .. key) end
		end
		if type(def.desc) ~= "string" or not def.desc:lower():find("theme", 1, true) then
			fail(scenario, "the dropdown's tooltip does not say what it is: " .. tostring(def.desc))
		end
		-- And a pick through it, as AceConfigDialog makes one.
		ns.WindowBind.Commit(item, "framed")
		if ns.db.profile.prompt.style ~= "framed" then fail(scenario, "picking from the dropdown did not set the style") end
	end)
end

do
	local scenario = "theme-picker: a window that will not build falls back to the dialog, which offers every look"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		if ns.WindowUI.built or ns.WindowUI.frame then
			fail(scenario, "SKIPPED -- the window was built before the scenario")
		else
			ns.WindowUI.BuildFooter = function() error("injected: no footer", 0) end
			local dialog = LibStub("AceConfigDialog-3.0")
			local real, opened = dialog.Open, 0
			dialog.Open = function(...)
				opened = opened + 1
				return real(...)
			end
			ns.OpenOptions()
			dialog.Open = real
			if not ns.OptionsFallback() or opened ~= 1 then
				fail(scenario, ("the window failed and the dialog opened %d times"):format(opened))
			end
			local def = ns.optionsTable.args.appearance.args.style
			local item = ns.WindowBind.Item("appearance.style")
			local values = type(def.values) == "function" and def.values(item.info) or def.values
			for _, key in ipairs(registry(ns)) do
				if not (values and values[key]) then fail(scenario, "the fallback's dropdown has no " .. key) end
			end
			if #registry(ns) < 6 then fail(scenario, "the registry holds fewer than the six looks") end
		end
		-- The injected footer error is the only guarded one there should be.
		for _, e in ipairs(ns.errors or {}) do
			if not tostring(e.err):find("injected", 1, true) then
				fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
			end
		end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ layout
do
	local scenario = "theme-picker: the cards fit the page, two or three to a row, and never overlap, whatever their number"
	with(scenario, function(ns, UI, row)
		local base = #registry(ns)
		local function columns(width) return math.max(1, math.min(3, math.floor((width + 10) / 160))) end
		for _, count in ipairs({ base, base + 1, base + 3, base + 4, base + 9 }) do
			for i = 1, count - base do
				register(ns, "fake" .. i, { name = "Fake " .. i .. " -- a made-up look", order = 60 + i })
			end
			ns.RefreshOptionsDisplay()
			if #shown(row) ~= count then
				fail(scenario, ("%d looks and %d cards"):format(count, #shown(row)))
			end
			-- Wide pages too: never more than three to a row however much room.
			for _, width in ipairs({ 1400, 1000, 612, 480, 400, 330, 300, 200 }) do
				local height = row:Layout(width)
				local cards = shown(row)
				local want = math.min(columns(width), #cards)
				local where = ("%d cards at %d wide"):format(#cards, width)
				local rowsSeen, top = {}, 0
				for i, c in ipairs(cards) do
					if c.x < 0 or c.x + c.w > width then fail(scenario, where .. ": card " .. i .. " runs outside the page") end
					if c.w < 1 or c.h < 1 then fail(scenario, where .. ": card " .. i .. " has no size") end
					if c.title:GetWidth() > c.w or c.desc:GetWidth() > c.w then
						fail(scenario, where .. ": the text of card " .. i .. " is wider than the card")
					end
					top = math.max(top, c.y + c.h)
					rowsSeen[c.y] = (rowsSeen[c.y] or 0) + 1
					for j = i + 1, #cards do
						local d = cards[j]
						if c.x < d.x + d.w and d.x < c.x + c.w and c.y < d.y + d.h and d.y < c.y + c.h then
							fail(scenario, where .. (": cards %d and %d overlap"):format(i, j))
						end
					end
				end
				for y, n in pairs(rowsSeen) do
					if n > 3 then fail(scenario, where .. (": %d cards in the row at %d"):format(n, y)) end
					if n > want then fail(scenario, where .. (": %d cards in a row, %d fit"):format(n, want)) end
				end
				if width >= 330 and want < 2 then fail(scenario, where .. ": fewer than two to a row") end
				if width == 612 and rowsSeen[0] ~= math.min(3, #cards) then
					fail(scenario, where .. (": %d in the first row"):format(rowsSeen[0] or 0))
				end
				if height ~= top then fail(scenario, where .. (": the row says %d high, the cards reach %d"):format(height, top)) end
				-- Rows run the whole width, and every card of a row is as tall as the rest.
				for _, c in ipairs(cards) do
					for _, d in ipairs(cards) do
						if c.y == d.y and c.h ~= d.h then fail(scenario, where .. ": cards of a row differ in height") end
					end
					if c.y == 0 and c.x + c.w > width then fail(scenario, where .. ": a card runs past the width") end
				end
				local first = {}
				for _, c in ipairs(cards) do
					if c.y == 0 then first[#first + 1] = c end
				end
				table.sort(first, function(a, b) return a.x < b.x end)
				if #cards >= want and #first == want and first[#first].x + first[#first].w ~= width then
					fail(scenario, where .. ": the first row stops short of the page's right edge")
				end
				for k = 2, #first do
					if first[k].x - (first[k - 1].x + first[k - 1].w) ~= 10 then
						fail(scenario, where .. ": the gap between two cards is not 10")
					end
				end
			end
		end
		-- On the page itself, in the window's own width.
		local e = UI.Where("appearance.style").e
		ns.OpenOptions("appearance", true)
		for _, c in ipairs(shown(row)) do
			if c.x + c.w > row.width then fail(scenario, "on the page a card runs past the row") end
		end
		if e.h and e.h < 60 then fail(scenario, "the gallery is only " .. tostring(e.h) .. " high on the page") end
	end)
end

-- ------------------------------------------------------------------ search
do
	local scenario = "theme-picker: the search finds the picker as style, look or theme"
	with(scenario, function(ns, UI)
		local Search = ns.WindowSearch
		for _, query in ipairs({ "style", "look", "theme", "panel style" }) do
			local found = Search.Find(query, UI.SearchEntries(), 8)
			local hit
			for _, entry in ipairs(found) do
				if entry.ref and entry.ref.path == "appearance.style" then hit = entry end
			end
			if not hit then fail(scenario, ("%q does not find the picker"):format(query)) end
		end
		-- Chosen from another page, it opens Look and shows the gallery.
		ns.OpenOptions("general", true)
		local found = Search.Find("theme", UI.SearchEntries(), 8)
		local ref
		for _, entry in ipairs(found) do
			if entry.ref.path == "appearance.style" then ref = entry.ref end
		end
		if ref then
			local e = UI.Choose(ref)
			if UI.page ~= "appearance" or not (e and e.row and e.row.cards) then
				fail(scenario, "choosing the result did not open the gallery")
			end
			if not (e and e.row and e.row.Flash) then fail(scenario, "the gallery cannot flash where search lands") end
		end
	end)
end

-- ------------------------------------------------------------------ the strings
do
	local scenario = "theme-picker: every string the picker shows has all eight translations"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		local keys = { "Pick a theme for the prompt. Click a card to switch to it at once." }
		for key, look in pairs(ns.Looks.list) do
			if not (look.title and look.description) then
				fail(scenario, key .. " has no title or no description of its own")
			end
			keys[#keys + 1] = look.title
			keys[#keys + 1] = look.description
		end
		local codes = { "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }
		for _, code in ipairs(codes) do
			local f = io.open(dir .. "/Locales/" .. code .. ".lua", "rb")
			if not f then
				fail(scenario, "no " .. code .. ".lua")
			else
				local text = f:read("*a")
				f:close()
				if text:find("[\208\209][\128-\191]") then fail(scenario, code .. " holds Cyrillic") end
				for _, key in ipairs(keys) do
					local line = 'L["' .. key .. '"] = "'
					local at = text:find(line, 1, true)
					if not at then
						fail(scenario, ("%s has no translation of %q"):format(code, key))
					elseif text:sub(at + #line, at + #line) == '"' then
						fail(scenario, ("%s translates %q as nothing"):format(code, key))
					end
				end
			end
		end
		-- And a client in each language gets a card with words on it.
		for _, code in ipairs(codes) do
			Mock.reset()
			Mock.locale = code
			local loaded = load(scenario .. " (" .. code .. ")")
			if loaded then
				for key in pairs(loaded.Looks.list) do
					local title, line = loaded.Looks.Card(key)
					if title == "" or line == "" then
						fail(scenario, ("%s: the %s card has no %s"):format(code, key, title == "" and "name" or "line"))
					end
					if title:find(" -- ", 1, true) or line:find(" -- ", 1, true) then
						fail(scenario, ("%s: the %s card still shows the label's dash"):format(code, key))
					end
				end
			end
		end
	end
	Mock.reset()
end

-- ------------------------------------------------------------------ the pictures
local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

do
	local scenario = "theme-picker: every look has a picture, and the card draws it"
	with(scenario, function(ns, UI, row)
		local Looks = ns.Looks
		for _, key in ipairs(registry(ns)) do
			if not Looks.previews[key] then
				fail(scenario, key .. " has no picture: run tools/make_look_previews.py")
			else
				local file = Looks.PreviewFile(key)
				local leaf = file and file:match("Textures\\Previews\\(Preview_[%w_]+)$")
				local data = leaf and slurp(dir .. "/Textures/Previews/" .. leaf .. ".tga")
				if not data then
					fail(scenario, key .. "'s picture " .. tostring(file) .. " is not shipped")
				else
					local w = data:byte(13) + 256 * data:byte(14)
					local h = data:byte(15) + 256 * data:byte(16)
					if w ~= 256 or h ~= 64 or data:byte(17) ~= 32 or data:byte(3) ~= 2 then
						fail(scenario, ("%s is %dx%d at %d bits, type %d"):format(leaf, w, h, data:byte(17), data:byte(3)))
					end
				end
				local card = cardFor(row, key)
				if not card then
					fail(scenario, key .. " has no card")
				elseif not card.shot:IsShown() or card.file ~= file then
					fail(scenario, ("the %s card draws %s, not %s"):format(key, tostring(card.file), tostring(file)))
				elseif card.mark:IsShown() then
					fail(scenario, "the " .. key .. " card shows the placeholder over its picture")
				end
			end
		end
		if not (type(Looks.previewHash) == "string" and #Looks.previewHash == 64) then
			fail(scenario, "Looks/Previews.lua holds no hash of what the pictures were drawn from")
		end
	end)
end

-- Where the generated files go, so two copies of the tree never share one.
local function tempDir()
	local base = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
	local token = tostring(dir):gsub("[^%w]", ""):sub(-40)
	return (base:gsub("\\", "/")) .. "/manners-previews-" .. token .. "-" .. tostring(os.time())
end

do
	local scenario = "theme-picker: the pictures were drawn from the looks as they are now"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		local python = os.getenv("MANNERS_PYTHON") or "python"
		local log = tempDir() .. ".log"
		-- os.execute and a log, not io.popen, which the Lua lupa builds on Linux
		-- leaves out.
		os.execute(python .. ' "' .. dir .. '/tools/make_look_previews.py" --check > "' .. log .. '" 2>&1')
		local text = slurp(log)
		os.remove(log)
		if not text then
			fail(scenario, "SKIPPED -- cannot run " .. python)
		elseif text:find("No module named", 1, true) then
			-- lupa is all the check needs; a machine without it cannot judge.
			text = nil
		elseif not text:find("previews current", 1, true) then
			fail(scenario, text:gsub("%s+$", ""):sub(1, 700))
		end
	end
	Mock.reset()
end
