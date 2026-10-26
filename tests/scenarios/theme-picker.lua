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
-- And the live icon on each card: a texture over the picture's tile at the
-- rectangle tools/make_look_previews.py recorded for that look (scaled to the
-- picture, at any card width), showing the icon of the buff this character
-- casts (a mage's Arcane Intellect, a priest's Fortitude, a hunter's aspect,
-- else the question mark), cropped as the prompt crops it; with the look's own
-- round mask where the look is round and none where it is square; greyed with
-- a greyed-out control; set at the paint, never on a timer; and recorded for
-- every look the registry holds.
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
			-- The live icon and its mask are regions of the card too.
			return { card, card.badge, card.icon, card.mask }
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

-- ------------------------------------------------------------------ the live icon
dofile(dir .. "/tests/frametree.lua")
local FT = FrameTree

-- The mock answers every spell with one icon, so spells are told apart here: a
-- buff's icon is 700000 plus its id.
local TEXTURE_BASE = 700000

-- The ids of a buff or an own spell straight out of Buffs.lua, from a copy of
-- the addon loaded for nothing else.
local function ranksOf(scenario, class, key)
	local probe = load(scenario .. " (reading ids)")
	local buff = probe and (probe.FindBuff(class, key) or probe.FindOwnSpell(key))
	return buff and buff.ranks or {}
end

-- One character's session with the options window open on Look, on the
-- recording frames: `spec.class` knowing exactly the buffs `spec.keys` names
-- (no keys: the mock's own, who knows Arcane Intellect rank 1), spell icons
-- told apart (`spec.noTexture`: the client has not loaded them yet), everything
-- put back. `body(ns, UI, row, env)`.
local function withCharacter(scenario, spec, body)
	Mock.reset()
	if spec.class then Mock.class = spec.class end
	local known
	if spec.keys then
		known = {}
		for _, key in ipairs(spec.keys) do
			for _, id in ipairs(ranksOf(scenario, spec.class, key)) do known[id] = true end
		end
	end
	local saved = {
		IsSpellKnown = IsSpellKnown, IsPlayerSpell = IsPlayerSpell, C_Spell = rawget(_G, "C_Spell"),
	}
	local env = { noTexture = spec.noTexture }
	local ok, err = pcall(function()
		if known then
			local fn = function(id) return known[id] == true end
			IsSpellKnown, IsPlayerSpell = fn, fn
		end
		local spells = C_Spell
		rawset(_G, "C_Spell", setmetatable({
			GetSpellTexture = function(id)
				if env.noTexture then return nil end
				return TEXTURE_BASE + id
			end,
		}, { __index = spells }))
		FT.install()
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
		body(ns, UI, row, env)
		noErrors(scenario, ns)
	end)
	FT.uninstall()
	IsSpellKnown, IsPlayerSpell = saved.IsSpellKnown, saved.IsPlayerSpell
	rawset(_G, "C_Spell", saved.C_Spell)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Where a card's icon sits, as the client would place it: the offsets of its
-- two corners from the picture's top left, in units.
local function overlayBox(card)
	local p = card.icon.points
	local a, b = p[1], p[2]
	if not (a and b and #p == 2) then return nil, "has " .. #p .. " anchors, not two" end
	for _, point in ipairs({ a, b }) do
		if point[2] ~= card.ground then return nil, "is not anchored to the picture" end
	end
	if a[1] ~= "TOPLEFT" or a[3] ~= "TOPLEFT" or b[1] ~= "BOTTOMRIGHT" or b[3] ~= "TOPLEFT" then
		return nil, "is anchored by the wrong corners"
	end
	return { a[4], a[5], b[4], b[5] }
end

local function near(a, b) return math.abs(a - b) < 1e-6 end

-- How much of its square a 32 bit TGA mask lets through (its mean alpha).
local function maskCover(path)
	local data = slurp(path)
	if not data then return nil end
	local w, h = data:byte(13) + 256 * data:byte(14), data:byte(15) + 256 * data:byte(16)
	if data:byte(3) ~= 2 or data:byte(17) ~= 32 then return nil end
	local start, sum = 18 + data:byte(1), 0
	for i = 1, w * h do sum = sum + data:byte(start + (i - 1) * 4 + 4) end
	return sum / (255 * w * h)
end

-- The disk file behind a texture path of the addon's own.
local function addonFile(path)
	local leaf = type(path) == "string" and path:match("^Interface\\AddOns\\Manners\\(.+)$")
	return leaf and (dir .. "/" .. leaf:gsub("\\", "/") .. ".tga")
end

-- The mask file a look's icon wears on the prompt itself, or nil: the recorded
-- shape is held to what the look does.
local function promptMask(ns, key)
	ns.db.profile.prompt.style = key
	ns.Prompt:ApplyStyle()
	local icon = ns.Prompt:Regions().icon
	return icon._mask and icon._mask._file or nil
end

do
	local scenario = "theme-picker: every card has an icon over its picture, at the rectangle recorded for its look, at any width"
	withCharacter(scenario, {}, function(ns, UI, row)
		local Looks = ns.Looks
		for _, width in ipairs({ 612, 1000, 480, 330 }) do
			row:Layout(width)
			for _, key in ipairs(registry(ns)) do
				local card = cardFor(row, key)
				local at = Looks.previewIcon[key]
				if not card then
					fail(scenario, key .. " has no card")
				elseif not at then
					fail(scenario, key .. " has no icon recorded: run tools/make_look_previews.py")
				elseif not card.icon:IsShown() then
					fail(scenario, ("%s: the icon is not shown at %d wide"):format(key, width))
				else
					local box, why = overlayBox(card)
					local w, h = card.ground._width, card.ground._height
					if not box then
						fail(scenario, ("%s: the icon %s"):format(key, why))
					elseif not (w and h and w > 0 and h > 0) then
						fail(scenario, key .. ": the picture has no size")
					else
						local want = { at.l * w, -at.t * h, at.r * w, -at.b * h }
						for i = 1, 4 do
							if not near(box[i], want[i]) then
								fail(scenario, ("%s at %d wide: icon corner %d is at %.3f, the recorded rectangle puts it at %.3f (picture %.1f x %.1f)")
									:format(key, width, i, box[i], want[i], w, h))
								break
							end
						end
						-- It never leaves the picture.
						if box[1] < 0 or box[2] > 0 or box[3] > w or box[4] < -h then
							fail(scenario, key .. ": the icon runs outside its picture")
						end
					end
				end
			end
		end
		-- A card handed another rectangle (its look re-recorded under it) is
		-- placed anew at once, with no layout in between.
		local luxe = Looks.previewIcon.luxe
		Looks.previewIcon.luxe = { l = luxe.l + 0.05, t = luxe.t, r = luxe.r + 0.05, b = luxe.b,
			round = false, crop = luxe.crop }
		row:Refresh()
		local moved = cardFor(row, "luxe")
		local box = moved and overlayBox(moved)
		if not (box and near(box[1], (luxe.l + 0.05) * moved.ground._width)) then
			fail(scenario, "a card given another rectangle did not move its icon")
		end
		Looks.previewIcon.luxe = luxe
		row:Refresh()
		-- The page's own width as well.
		ns.OpenOptions("appearance", true)
		for _, card in ipairs(shown(row)) do
			local box = overlayBox(card)
			local at = ns.Looks.previewIcon[card.key]
			local w, h = card.ground._width, card.ground._height
			if not (box and at and near(box[3] - box[1], (at.r - at.l) * w) and near(box[4] - box[2], -(at.b - at.t) * h)) then
				fail(scenario, "on the page the icon of " .. tostring(card.key) .. " is not the recorded size")
			end
		end
	end)
end

do
	local scenario = "theme-picker: the icon is the player's own buff, cropped as the prompt crops it"
	-- A mage: Arcane Intellect, the first of her castable buffs.
	withCharacter(scenario .. " (a mage)", {}, function(ns, UI, row)
		local first = ns.CastableBuffs()[1]
		if not (first and first.key == "intellect") then
			fail(scenario, "SKIPPED -- the mage's first buff is " .. tostring(first and first.key))
			return
		end
		local want = TEXTURE_BASE + 1459
		if ns.BuffInfo(first).icon ~= want then
			fail(scenario, "SKIPPED -- the probe's icon is " .. tostring(ns.BuffInfo(first).icon))
			return
		end
		local prompt = ns.Prompt:Regions().icon
		for _, card in ipairs(shown(row)) do
			if card.iconFile ~= want then
				fail(scenario, ("a mage's %s card shows %s, not her Arcane Intellect %s"):format(card.key,
					tostring(card.iconFile), want))
			end
			if card.icon._file ~= want then
				fail(scenario, ("the %s card's icon texture is %s"):format(card.key, tostring(card.icon._file)))
			end
			local crop = card.icon._texCoord
			if not (crop and #crop == 4 and crop[1] == 0.08 and crop[2] == 0.92 and crop[3] == 0.08 and crop[4] == 0.92) then
				fail(scenario, ("the %s card crops its icon as %s"):format(card.key, crop and table.concat(crop, ",") or "nothing"))
			end
			-- As the prompt's own icon is.
			local theirs = prompt._texCoord
			if not (theirs and crop and theirs[1] == crop[1] and theirs[2] == crop[2]
				and theirs[3] == crop[3] and theirs[4] == crop[4]) then
				fail(scenario, "the card crops its icon otherwise than the prompt does")
			end
		end
		-- And as the prompt's own helper reads it for the same buff.
		if ns.Prompt.lib.EntryIcon({ buff = first }) ~= want then
			fail(scenario, "the prompt's icon for the same buff is not the card's")
		end
	end)

	-- A priest: Fortitude, and not the mage's spell.
	withCharacter(scenario .. " (a priest)", { class = "PRIEST", keys = { "fortitude" } }, function(ns, UI, row)
		local ranks = ns.FindBuff("PRIEST", "fortitude").ranks
		local want = TEXTURE_BASE + ranks[1]
		if ns.CastableBuffs()[1] == nil or ns.CastableBuffs()[1].key ~= "fortitude" then
			fail(scenario, "SKIPPED -- the priest's first buff is not Fortitude")
			return
		end
		for _, card in ipairs(shown(row)) do
			if card.iconFile ~= want then
				fail(scenario, ("a priest's %s card shows %s, not Fortitude's %s"):format(card.key,
					tostring(card.iconFile), want))
			end
		end
	end)

	-- Two buffs: the first the prompt would offer, as the player ordered them.
	withCharacter(scenario .. " (the first of two)", { class = "PRIEST", keys = { "fortitude", "spirit" } },
		function(ns, UI, row)
			local castable = ns.CastableBuffs()
			if #castable < 2 then
				fail(scenario, "SKIPPED -- the priest has " .. #castable .. " castable buffs")
				return
			end
			if ns.BuffInfo(castable[1]).icon == ns.BuffInfo(castable[2]).icon then
				fail(scenario, "SKIPPED -- the two buffs share an icon")
				return
			end
			for _, card in ipairs(shown(row)) do
				if card.iconFile ~= ns.BuffInfo(castable[1]).icon then
					fail(scenario, ("the %s card shows %s, the first castable buff's icon is %s"):format(card.key,
						tostring(card.iconFile), tostring(ns.BuffInfo(castable[1]).icon)))
				end
			end
		end)
end

do
	local scenario = "theme-picker: a class with no buff for others wears its own learned buff, else the question mark"
	-- A hunter with an aspect and nothing for anybody else.
	withCharacter(scenario .. " (an aspect)", { class = "HUNTER", keys = { "aspecthawk" } }, function(ns, UI, row)
		if #ns.CastableBuffs() ~= 0 then
			fail(scenario, "SKIPPED -- the hunter has castable buffs")
			return
		end
		local info = ns.caps.own and ns.caps.own.aspecthawk
		if not (info and info.known) then
			fail(scenario, "SKIPPED -- the aspect is not known")
			return
		end
		local want = info.icon
		if want ~= TEXTURE_BASE + ns.FindOwnSpell("aspecthawk").ranks[1] then
			fail(scenario, "SKIPPED -- the aspect's icon is " .. tostring(want))
			return
		end
		for _, card in ipairs(shown(row)) do
			if card.iconFile ~= want then
				fail(scenario, ("a hunter's %s card shows %s, not the aspect's %s"):format(card.key,
					tostring(card.iconFile), want))
			end
		end
	end)

	-- A warrior who has learned nothing: the client's question mark, as itself.
	withCharacter(scenario .. " (nothing)", { class = "WARRIOR", keys = {} }, function(ns, UI, row)
		if #ns.CastableBuffs() ~= 0 then
			fail(scenario, "SKIPPED -- the warrior has castable buffs")
			return
		end
		for _, card in ipairs(shown(row)) do
			if card.iconFile ~= 134400 or not card.icon:IsShown() then
				fail(scenario, ("a character with no buff has %s on the %s card"):format(
					tostring(card.iconFile), card.key))
			end
		end
	end)
end

do
	local scenario = "theme-picker: the icon is set when the page paints, and again once the client knows it"
	withCharacter(scenario, { noTexture = true }, function(ns, UI, row, env)
		-- The client has not loaded the spell's icon yet: the question mark,
		-- not nothing and not another spell's.
		for _, card in ipairs(shown(row)) do
			if card.iconFile ~= 134400 then
				fail(scenario, ("before the client knew it, the %s card showed %s"):format(card.key, tostring(card.iconFile)))
			end
		end
		-- It loads, and the next time the page is drawn the cards have it.
		env.noTexture = false
		ns.ProbeCapabilities()
		ns.RefreshOptionsDisplay()
		local want = TEXTURE_BASE + 1459
		for _, card in ipairs(shown(row)) do
			if card.iconFile ~= want or card.icon._file ~= want then
				fail(scenario, ("once the client knew it, the %s card showed %s"):format(card.key, tostring(card.iconFile)))
			end
		end
		-- Nothing is parked on a timer by painting the gallery.
		local before = #Mock.timers
		row:Refresh()
		row:Layout(612)
		if #Mock.timers ~= before then
			fail(scenario, ("painting the gallery parked %d timer(s)"):format(#Mock.timers - before))
		end
	end)
end

do
	local scenario = "theme-picker: round looks get their own round mask on the icon, square looks none"
	withCharacter(scenario, {}, function(ns, UI, row)
		local Looks = ns.Looks
		local rounds = 0
		for _, key in ipairs(registry(ns)) do
			local card = cardFor(row, key)
			local at = Looks.previewIcon[key]
			if card and at then
				local mask = card.icon._mask
				if at.round then
					rounds = rounds + 1
					if not at.mask then
						fail(scenario, key .. " is round and records no mask file")
					elseif not mask then
						fail(scenario, ("the %s card's icon has no mask: it is square where the look is round"):format(key))
					else
						if mask._file ~= at.mask then
							fail(scenario, ("the %s card's mask is %s, the look's is %s"):format(key, tostring(mask._file), at.mask))
						end
						if mask._allPointsTo ~= card.icon then
							fail(scenario, key .. "'s mask does not cover the icon")
						end
						local cover = addonFile(at.mask) and maskCover(addonFile(at.mask))
						if not cover then
							fail(scenario, ("%s's mask %s is not a file the addon ships"):format(key, at.mask))
						elseif cover > 0.85 then
							fail(scenario, ("%s's mask lets %.0f%% through: not a circle"):format(key, cover * 100))
						end
					end
				else
					if mask then
						fail(scenario, ("the %s card's icon has a mask (%s) where the look is square"):format(key, tostring(mask._file)))
					end
					if at.mask then fail(scenario, key .. " is square and records a mask") end
				end
			end
			-- What the recorded shape stands for: the look's own icon on the prompt.
			local worn = promptMask(ns, key)
			if at and at.round then
				if worn ~= at.mask then
					fail(scenario, ("%s cuts its icon with %s on the prompt, the card says %s"):format(key, tostring(worn), tostring(at.mask)))
				end
			elseif worn then
				local cover = addonFile(worn) and maskCover(addonFile(worn))
				if not cover or cover < 0.85 then
					fail(scenario, ("%s cuts its icon round (%s) on the prompt, and the card says it is square"):format(key, worn))
				end
			end
		end
		if rounds == 0 then fail(scenario, "no look is round") end
		-- A card handed another look takes its mask off, and puts it back.
		local card = cardFor(row, "toast")
		if card then
			local at = Looks.previewIcon.toast
			Looks.previewIcon.toast = { l = at.l, t = at.t, r = at.r, b = at.b, round = false, crop = at.crop }
			ns.RefreshOptionsDisplay()
			if card.icon._mask then fail(scenario, "a card that stopped being round kept its mask") end
			Looks.previewIcon.toast = at
			ns.RefreshOptionsDisplay()
			if not card.icon._mask then fail(scenario, "a card that became round again has no mask") end
		end
	end)
end

do
	local scenario = "theme-picker: a greyed-out control greys the icons too, and a look with no picture has none"
	withCharacter(scenario, {}, function(ns, UI, row)
		local def = ns.optionsTable.args.appearance.args.style
		local was = def.disabled
		def.disabled = function() return true end
		ns.RefreshOptionsDisplay()
		for _, card in ipairs(shown(row)) do
			if not card.icon:IsDesaturated() then fail(scenario, "the icon of " .. card.key .. " is in colour on a greyed-out card") end
			if card.icon:GetAlpha() >= 1 then fail(scenario, "the icon of " .. card.key .. " is not dimmed with its card") end
		end
		def.disabled = was
		ns.RefreshOptionsDisplay()
		for _, card in ipairs(shown(row)) do
			if card.icon:IsDesaturated() or card.icon:GetAlpha() ~= 1 then
				fail(scenario, "the icon of " .. card.key .. " stayed grey once the control was back")
			end
		end
		-- A look with no picture has the addon's mark and no icon.
		register(ns, "fake", { name = "Fake -- a made-up look", order = 60 })
		ns.RefreshOptionsDisplay()
		local fake = cardFor(row, "fake")
		if not fake then
			fail(scenario, "the new look has no card")
		elseif fake.icon:IsShown() then
			fail(scenario, "a look with no picture has an icon over the placeholder")
		end
		-- And the cards of the looks that have one still do.
		ns.Looks.list.fake = nil
		row:Refresh()
		local luxe = cardFor(row, "luxe")
		if not (luxe and luxe.icon:IsShown()) then fail(scenario, "the luxe card lost its icon") end
		-- A card that had an icon and is handed a look with no picture drops it.
		local picture = ns.Looks.previews.luxe
		ns.Looks.previews.luxe = nil
		row:Refresh()
		if luxe.icon:IsShown() or luxe.iconFile ~= nil then
			fail(scenario, "a card whose look lost its picture kept the icon over the placeholder")
		end
		ns.Looks.previews.luxe = picture
		row:Refresh()
		if not luxe.icon:IsShown() then fail(scenario, "the icon did not come back with the picture") end
	end)
end

do
	local scenario = "theme-picker: the icon data covers every registered look, and is held current by the hash"
	withCharacter(scenario, {}, function(ns)
		local Looks = ns.Looks
		local function number(v) return type(v) == "number" and v == v end
		for _, key in ipairs(registry(ns)) do
			local at = Looks.previewIcon[key]
			if not at then
				fail(scenario, key .. " has no icon rectangle: run tools/make_look_previews.py")
			else
				if not (number(at.l) and number(at.t) and number(at.r) and number(at.b)) then
					fail(scenario, key .. "'s rectangle is not four numbers")
				elseif not (0 <= at.l and at.l < at.r and at.r <= 1 and 0 <= at.t and at.t < at.b and at.b <= 1) then
					fail(scenario, ("%s's rectangle is outside its picture or upside down: %s %s %s %s"):format(key,
						at.l, at.t, at.r, at.b))
				else
					-- A square icon in a picture four times as wide as it is high.
					local w, h = (at.r - at.l) * 256, (at.b - at.t) * 64
					if math.abs(w - h) > 0.6 then
						fail(scenario, ("%s's icon is %.1f x %.1f pixels of its picture: not square"):format(key, w, h))
					end
				end
				if type(at.round) ~= "boolean" then fail(scenario, key .. " does not say whether it is round") end
				if at.round and type(at.mask) ~= "string" then fail(scenario, key .. " is round and has no mask") end
				if at.mask and not at.round then fail(scenario, key .. " has a mask and is not round") end
				if not (type(at.crop) == "table" and #at.crop == 4) then fail(scenario, key .. " records no crop") end
			end
		end
		for key in pairs(Looks.previewIcon) do
			if not Looks.list[key] then fail(scenario, "an icon is recorded for " .. key .. ", which is not a look") end
		end
		if Looks.PreviewIcon("no-such-look") ~= nil then fail(scenario, "an unknown look has an icon") end
		-- A look the tool has not drawn has none, whatever the table holds.
		Looks.previewIcon.fake = { l = 0.1, t = 0.1, r = 0.2, b = 0.9, round = false }
		if Looks.PreviewIcon("fake") ~= nil then fail(scenario, "a look with no picture was handed an icon rectangle") end
		Looks.previewIcon.fake = nil
	end)
end
