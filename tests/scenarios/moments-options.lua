-- The options of the buttons for the moment: every control placed once in the
-- In a fight page's own section with its key under its switch, hidden for a
-- spell the character has not learned, the key box binding the button and saying
-- the spell, the reset putting the twelve fields back, the changed marks, search
-- finding each by its words and naming the switch to turn on, and the simple
-- view holding the keys. A character with no prompt and a moment row still sees
-- its switch.
--
-- Held to the mock's model of the options window, not to the window itself.
--
-- Every name starts with "moments-options:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")
-- Written for plain values: Forever's hidden ones are asked for by name (Mock.healthSecret, ...).
K.plain = true

local KEYS = { "counterspell", "spellsteal", "blink", "iceblock", "coldsnap", "evocation", "managem", "drink", "slowfall",
	"fireward", "frostward", "purge", "dispel", "tranq", "shieldslam" }

local function with(name, body, opts) K.withMage(H, "moments-options: " .. name, body, opts) end
local function name(s) return "moments-options: " .. s end
local function cap(key) return key:sub(1, 1):upper() .. key:sub(2) end

local function option(ns, key)
	local look = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.appearance
	return look and look.args and look.args[key]
end

local function hidden(node)
	if type(node.hidden) == "function" then return node.hidden() == true end
	return node.hidden == true
end

local function section(ns)
	local found
	local function walk(t)
		if type(t) ~= "table" or found then return end
		if t.key == "fight.moments" and type(t.items) == "table" then found = t return end
		for _, v in pairs(t) do walk(v) end
	end
	walk(ns.WindowLayout)
	return found
end

-- Everything a mage can learn on Forever and the other clients, for a page with
-- every row to show.
local ALL = {}
for _, id in ipairs(K.MAGE_SPELLS) do ALL[#ALL + 1] = id end
for _, id in ipairs(K.WARD_SPELLS) do ALL[#ALL + 1] = id end
for _, id in ipairs(K.GEM_SPELLS) do ALL[#ALL + 1] = id end

do
	local s = name("every control is placed once with its key under it, in the section of its own")
	with(s, function(ns)
		local found = section(ns)
		if not found then fail(s, "no fight.moments section") return end
		local seen = {}
		for i, item in ipairs(found.items) do
			local path = type(item) == "table" and item[1] or item
			if seen[path] then fail(s, path .. " is placed twice") end
			seen[path] = { index = i, indent = type(item) == "table" and item.indent }
		end
		if not seen["appearance.momentsNote"] then fail(s, "no note heads the section") end
		for _, key in ipairs(KEYS) do
			local switch, keyPath = "appearance.moment" .. cap(key), "appearance.moment" .. cap(key) .. "Key"
			if not seen[switch] then fail(s, "no switch for " .. key) end
			if not (seen[keyPath] and seen[keyPath].indent) then fail(s, "no indented key for " .. key) end
			if seen[switch] and seen[keyPath] and seen[keyPath].index ~= seen[switch].index + 1 then fail(s, key .. "'s key is not right under its switch") end
			if ns.WindowLayout.parents[keyPath] ~= switch then fail(s, key .. "'s key does not name its switch for search") end
			if type(ns.WindowLayout.parentsIf[switch]) ~= "function" or type(ns.WindowLayout.parentsIf[keyPath]) ~= "function" then
				fail(s, key .. " has no parentsIf")
			end
			if not (ns.WindowLayout.keywords[switch] and ns.WindowLayout.keywords[switch] ~= "") then fail(s, key .. " has no words to search by") end
			if not ns.WindowLayout.simple.items[switch] or not ns.WindowLayout.simple.items[keyPath] then fail(s, key .. " is not in the simple view") end
			if not option(ns, "moment" .. cap(key)) or not option(ns, "moment" .. cap(key) .. "Key") then fail(s, key .. " has no control") end
		end
		for _, path in ipairs({ "appearance.momentHealth", "appearance.momentMana" }) do
			if not seen[path] then fail(s, path .. " is not placed") end
			if not (ns.WindowLayout.units[path] and ns.WindowLayout.units[path].kind == "percent") then fail(s, path .. " has no percent unit") end
			if not ns.WindowLayout.simple.items[path] then fail(s, path .. " is not in the simple view") end
		end
		if #found.items ~= 1 + 2 * #KEYS + 2 + 2 then fail(s, "the section holds " .. #found.items .. " items") end
		-- The page holds three sections.
		local fightPage
		for _, page in ipairs(ns.WindowLayout.pages or {}) do
			if page.id == "fight" then fightPage = page end
		end
		if fightPage and #fightPage.subpages ~= 3 then fail(s, "the page has " .. #fightPage.subpages .. " subpages") end
	end, { known = ALL })
end

do
	local s = name("a control for a spell not learned is hidden, the rest are shown")
	with(s, function(ns)
		for _, key in ipairs(KEYS) do
			local node = option(ns, "moment" .. cap(key))
			if not node then fail(s, key .. " has no control") else
				local want = key == "counterspell" or key == "drink"
				if hidden(node) == want then fail(s, key .. (want and " is hidden for a known spell" or " is shown for an unknown one")) end
			end
		end
		if not hidden(option(ns, "momentHealth")) then fail(s, "the health slider shows with no health spell") end
		-- The drink uses the share too: a mage with no mana spell still has it.
		if hidden(option(ns, "momentMana")) then fail(s, "the mana slider is hidden though the drink uses it") end
		if hidden(option(ns, "momentsNote")) then fail(s, "the note is hidden for a mage with a button") end
	end, { known = { 2139 } })
	s = name("the sliders show for the spells they serve")
	with(s, function(ns)
		if hidden(option(ns, "momentHealth")) or hidden(option(ns, "momentMana")) then fail(s, "a slider is hidden with its spells known") end
	end, { known = ALL })
end

do
	local s = name("the names carry the client's spell names, never typed ones")
	with(s, function(ns)
		local function text(v) return type(v) == "function" and v() or v end
		if text(option(ns, "momentCounterspell").name) ~= "Show Counterspell when my target starts a cast" then
			fail(s, "Counterspell: " .. tostring(text(option(ns, "momentCounterspell").name)))
		end
		local snap = text(option(ns, "momentColdsnap").name)
		if not snap:find("Cold Snap", 1, true) or not snap:find("Ice Block", 1, true) then fail(s, "Cold Snap's name: " .. snap) end
		local fall = text(option(ns, "momentSlowfall").desc)
		if not fall:find("It needs a ", 1, true) then fail(s, "Slow Fall's text does not say what it needs: " .. fall) end
		if text(option(ns, "momentManagem").name) ~= "Show my mana gem when my mana is low in a fight" then fail(s, "the gem's name") end
	end, { known = ALL })
end

do
	local s = name("the drink's switch and key say the drink; a priest sees them and the mana slider and nothing else")
	with(s, function(ns)
		local function text(v) return type(v) == "function" and v() or v end
		if text(option(ns, "momentDrink").name) ~= "Show a drink when my mana is low out of a fight" then
			fail(s, "the switch's name: " .. tostring(text(option(ns, "momentDrink").name)))
		end
		local desc = text(option(ns, "momentDrink").desc)
		if not desc:find("Out of a fight only.", 1, true) or not desc:find("two quick clicks", 1, true) then fail(s, "the drink's words: " .. desc) end
		if text(option(ns, "momentDrinkKey").name) ~= "Key for Drink" then fail(s, "the key's name: " .. tostring(text(option(ns, "momentDrinkKey").name))) end
		if hidden(option(ns, "momentDrink")) or hidden(option(ns, "momentMana")) then fail(s, "a priest does not see the drink or the mana slider") end
		for _, key in ipairs({ "momentCounterspell", "momentEvocation", "momentManagem", "momentHealth" }) do
			if not hidden(option(ns, key)) then fail(s, "a priest sees " .. key) end
		end
		if option(ns, "momentMana").disabled() then fail(s, "the mana slider is greyed with the drink on") end
		ns.db.profile.moments.drink = false
		if not option(ns, "momentMana").disabled() then fail(s, "the mana slider stays enabled with the drink off") end
	end, { class = "PRIEST" })
end

do
	local s = name("the key box binds the button and says the spell")
	with(s, function(ns)
		local key = option(ns, "momentEvocationKey")
		if not key or key.type ~= "keybinding" then fail(s, "no key control") return end
		Mock.bindings = { G = "JUMP" }
		_G.BINDING_NAME_JUMP = "Jump"
		Mock.printed = {}
		key.set({ "appearance", "momentEvocationKey" }, "G")
		_G.BINDING_NAME_JUMP = nil
		if Mock.bindings.G ~= "CLICK MannersMoment4:LeftButton" or key.get({ "appearance", "momentEvocationKey" }) ~= "G" then
			fail(s, "G was not bound to the button")
		end
		local said
		for _, line in ipairs(Mock.printed or {}) do
			if tostring(line):find("it now casts Evocation", 1, true) then said = true end
		end
		if not said then fail(s, "taking Jump's key did not say it now casts Evocation") end
		-- With the key bound the button takes no mouse: Refresh read it.
		ns.addon:Tick()
		if ns.Moments:Slot(4).keyLabel ~= "G" then fail(s, "the button did not read its key") end
	end, { known = ALL })
end

do
	local s = name("a switch arms and disarms the button, and a key is hidden with its switch off")
	with(s, function(ns)
		local switch, key = option(ns, "momentSlowfall"), option(ns, "momentSlowfallKey")
		if not (switch and key) then fail(s, "no controls") return end
		if hidden(key) then fail(s, "the key is hidden with its switch on") end
		switch.set({ "appearance", "momentSlowfall" }, false)
		if not hidden(key) then fail(s, "the key shows with its switch off") end
		if K.macro(ns, 6) ~= nil then fail(s, "still armed with the switch off") end
		switch.set({ "appearance", "momentSlowfall" }, true)
		if not K.macro(ns, 6) then fail(s, "not armed again") end
	end, { known = ALL })
end

do
	local s = name("the reset puts the twelve fields back and re-arms")
	with(s, function(ns)
		local m = ns.db.profile.moments
		for _, key in ipairs(KEYS) do m[key] = not ns.defaults.profile.moments[key] end
		m.health, m.mana = 45, 5
		local Page = ns.OptionsPage
		local ok, answer = pcall(Page.ResetPage, "fight")
		if not ok or answer ~= true then fail(s, "the reset did not run: " .. tostring(answer)) return end
		for key, want in pairs(ns.defaults.profile.moments) do
			if m[key] ~= want then fail(s, "moments." .. key .. " was not put back") end
		end
		if not K.macro(ns, 1) then fail(s, "the reset did not re-arm the buttons") end
		-- The wards ship on: switched off before the reset, armed again after it.
		if not (ns.Moments:Slot(9) and ns.Moments:Slot(9).armed) then fail(s, "Fire Ward is not armed after the reset to on") end
	end, { known = ALL })
end

do
	local s = name("the changed marks follow each field")
	with(s, function(ns)
		local UI = ns.WindowUI
		if not (UI and UI.Differs) then fail(s, "no window to ask") return end
		local m, defaults = ns.db.profile.moments, ns.defaults.profile.moments
		local function differs(path) return UI.Differs(path, UI.Item and UI.Item(path)) end
		for _, key in ipairs(KEYS) do
			local path = "appearance.moment" .. cap(key)
			if differs(path) then fail(s, key .. " is marked with its default") end
			m[key] = not defaults[key]
			if not differs(path) then fail(s, key .. " is not marked when it differs") end
			m[key] = defaults[key]
			if differs(path .. "Key") then fail(s, key .. "'s key box carries a mark though it has no default") end
		end
		for _, which in ipairs({ "health", "mana" }) do
			local path = "appearance.moment" .. cap(which)
			if differs(path) then fail(s, which .. " is marked with its default") end
			m[which] = defaults[which] == 5 and 10 or 5
			if not differs(path) then fail(s, which .. " is not marked when it differs") end
			m[which] = defaults[which]
		end
	end, { known = ALL })
end

do
	local s = name("search finds each by its words and names the switch to turn on")
	with(s, function(ns)
		local Search = ns.WindowSearch
		if not Search then fail(s, "no search") return end
		local want = {
			counterspell = "interrupt", spellsteal = "steal", blink = "stun", iceblock = "health", coldsnap = "cooldown",
			evocation = "mana", managem = "agate", slowfall = "falling", fireward = "ward", frostward = "ward",
		}
		for key, word in pairs(want) do
			local words = ns.WindowLayout.keywords["appearance.moment" .. cap(key)] or ""
			if not words:lower():find(word, 1, true) then fail(s, key .. "'s words lack '" .. word .. "': " .. words) end
			local keyPath = "appearance.moment" .. cap(key) .. "Key"
			if ns.WindowLayout.parents[keyPath] ~= "appearance.moment" .. cap(key) then fail(s, key .. "'s key names no switch") end
		end
	end, { known = ALL })
end

do
	local s = name("a character with no prompt and a moment row still sees its switch")
	with(s, function(ns)
		-- No buff to offer anybody, none of their own, nobody to ask: no prompt.
		ns.caps.hasClassBuffs = false
		ns.OwnBuffsOnly = function() return false end
		ns.AskLive = function() return false end
		if ns.OptionsPage.HasPrompt() then fail(s, "the character still has a prompt") return end
		local plainControl = option(ns, "scale")
		if not (plainControl and hidden(plainControl)) then fail(s, "a prompt control is shown with no prompt: the stand-in is not one") end
		for _, key in ipairs({ "counterspell", "slowfall" }) do
			local node, keyNode = option(ns, "moment" .. cap(key)), option(ns, "moment" .. cap(key) .. "Key")
			if not node then fail(s, key .. " has no control") return end
			if hidden(node) then fail(s, key .. "'s switch is gone for a character with no prompt") end
			if keyNode and keyNode.hidden == nil then fail(s, key .. "'s key has no rule of its own") end
		end
		if hidden(option(ns, "momentsNote")) then fail(s, "the note is gone for a character with no prompt") end
	end, { known = ALL })
end
