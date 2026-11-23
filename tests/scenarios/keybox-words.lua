-- Every key box says how it is used (Options/*.lua, type = "keybinding"): click,
-- then press a key or a controller button; Esc cancels, a right-click clears it;
-- saved with the game's key bindings. One string for all of them, so a box added
-- later is told to carry it too.
--
-- Every name starts with "keybox-words:".

local dir, H = ...
local fail = H.fail
local K = dofile(dir .. "/tests/momentskit.lua")
K.plain = true

local SENTENCE = "Click, then press a key or a controller button. Esc cancels, a right-click clears it. Saved with your game key bindings, so it works on every profile."

do
	local s = "keybox-words: every key box's tooltip holds the sentence that says how to use it"
	K.withMage(H, s, function(ns)
		local seen, bad = 0, {}
		local function text(def)
			local d = def.desc
			if type(d) == "function" then d = d() end
			return tostring(d)
		end
		local function walk(args, path)
			for key, def in pairs(args or {}) do
				if type(def) == "table" then
					if def.type == "keybinding" then
						seen = seen + 1
						if not text(def):find(ns.L[SENTENCE], 1, true) then bad[#bad + 1] = path .. "." .. key end
					end
					if type(def.args) == "table" then walk(def.args, path .. "." .. key) end
				end
			end
		end
		walk(ns.optionsTable and ns.optionsTable.args, "options")
		if seen < 10 then fail(s, "only " .. seen .. " key boxes found") end
		if #bad > 0 then
			table.sort(bad)
			fail(s, "these key boxes do not say how to use them: " .. table.concat(bad, ", "))
		end
		-- The sentence names the controls and says what it saves with.
		for _, word in ipairs({ "Esc", "right-click", "controller", "game key bindings" }) do
			if not SENTENCE:find(word, 1, true) then fail(s, "the sentence has no " .. word) end
		end
	end)
end
