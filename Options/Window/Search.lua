-- Manners -- options window: search matching (Interface 3).
--
-- A2's stand-in so the window runs on this branch; B1's Search.lua replaces
-- it at the merge.

local _, ns = ...

local S = {}
ns.WindowSearch = S

-- Colour codes, textures, atlases and line breaks out; case folded, the
-- two-byte Latin capitals too (A to Thorn, OE, Y with diaeresis).
function S.Normalise(text)
	text = tostring(text or "")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
	text = text:gsub("[\r\n]+", " "):lower()
	text = text:gsub("\195([\128-\158])", function(c)
		local b = c:byte()
		if b == 151 then return "\195" .. c end
		return "\195" .. string.char(b + 32)
	end)
	text = text:gsub("\197\146", "\197\147"):gsub("\197\184", "\195\191")
	return text
end

local function Has(text, q)
	return type(text) == "string" and S.Normalise(text):find(q, 1, true) ~= nil
end

local function Rank(e, q)
	if Has(e.label, q) then return 0 end
	for _, choice in ipairs(e.choices or {}) do
		if Has(choice, q) then return 1 end
	end
	if Has(e.desc, q) then return 2 end
	if Has(e.section, q) or Has(e.page, q) then return 3 end
	return nil
end

function S.Find(query, entries, limit)
	local q = S.Normalise(query):gsub("^%s+", ""):gsub("%s+$", "")
	local out = {}
	if q == "" then return out end
	local ranked = {}
	for i, e in ipairs(entries or {}) do
		local rank = Rank(e, q)
		if rank then ranked[#ranked + 1] = { rank = rank, i = i, e = e } end
	end
	table.sort(ranked, function(a, b)
		if a.rank ~= b.rank then return a.rank < b.rank end
		return a.i < b.i
	end)
	for i = 1, math.min(#ranked, limit or 8) do out[i] = ranked[i].e end
	return out
end
