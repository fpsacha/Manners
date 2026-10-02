-- Manners -- options window: the controls (Interface 7).
--
-- A2's stand-in so the window runs on this branch: every kind builds a row
-- that reads its model through ns.WindowBind, but draws only a label. A1's
-- Widgets.lua replaces it at the merge.

local _, ns = ...

local W = {}
ns.WindowWidgets = W
W.Theme = {}

local HEIGHTS = { toggle = 22, select = 44, range = 44, input = 44, execute = 24, keybinding = 44, color = 24,
	header = 20, number = 44, never = 80 }

local function Plain(text)
	return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Everything a real control would read, read the same way, so the model's
-- functions run here as they will under the real widgets.
local function Read(row)
	local B, item, kind = ns.WindowBind, row.item, row.kind
	row.text = B.Text(item, "name") or ""
	row.disabled = B.Disabled(item)
	if kind == "select" or kind == "multiselect" then row.values = B.Values(item) end
	if kind == "multiselect" then
		for _, pair in ipairs(row.values) do B.Value(item, pair[1]) end
	elseif kind ~= "description" and kind ~= "header" and kind ~= "execute" and kind ~= "never" then
		row.value = B.Value(item)
	end
	if kind == "never" then
		for _, path in ipairs(item.layout.ids or {}) do
			local sub = B.Item(path, item.layout, item.ctx)
			if sub then B.Text(sub, "name") end
		end
	end
	row.label:SetText(row.text)
end

local function Widest(row)
	local w = #Plain(row.text) * 6 + 30
	for _, pair in ipairs(row.values or {}) do
		w = math.max(w, #Plain(pair[2]) * 6 + 40)
	end
	return w
end

local function Height(row, width)
	local kind = row.kind
	if kind == "description" then
		local chars = #Plain(row.text)
		return math.max(14, math.ceil(chars * 6 / math.max(width, 60)) * 14)
	end
	if kind == "multiline" then return 20 + (tonumber(row.item.def.multiline) or 4) * 14 end
	if kind == "multiselect" then
		local cols = row.item.layout.columns or 4
		return 20 + math.ceil(#(row.values or {}) / cols) * 22
	end
	return HEIGHTS[kind] or 24
end

function W.Build(kind, parent, item)
	local frame = CreateFrame(kind == "toggle" and "Button" or "Frame", nil, parent)
	local row = { frame = frame, kind = kind, item = item }
	row.label = frame:CreateFontString(nil, "ARTWORK")
	row.label:SetFontObject(GameFontHighlight)
	row.label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	row.Refresh = function(r) Read(r) end
	row.NaturalWidth = function(r) return Widest(r) end
	row.Layout = function(r, width)
		local h = Height(r, width)
		r.frame:SetSize(width, h)
		r.label:SetWidth(width)
		return h
	end
	row.Focus = function() end
	row.Flash = function(r) r.flashes = (r.flashes or 0) + 1 end
	if kind == "toggle" then
		frame:SetScript("OnClick", function()
			ns.Guard("options toggle", function()
				if not ns.WindowBind.Disabled(item) then ns.WindowBind.Commit(item, not ns.WindowBind.Value(item)) end
			end)
		end)
	end
	return row
end

-- The confirm box. The stand-in only keeps what was asked; a scenario
-- answers it.
function W.Modal(parent, text, onYes, onNo)
	W.asked = { parent = parent, text = text, yes = onYes, no = onNo }
end

function W.Button(parent, label, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(120, 22)
	local plate = b:CreateTexture(nil, "BACKGROUND")
	plate:SetAllPoints()
	plate:SetColorTexture(0.53, 0.1, 0.07, 1)
	b.label = b:CreateFontString(nil, "ARTWORK")
	b.label:SetFontObject(GameFontNormal)
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.label:SetText(label)
	b:SetScript("OnClick", function(...)
		if onClick then ns.Guard("options button", onClick, ...) end
	end)
	return b
end
