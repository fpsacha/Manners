-- Manners: Combat -- shared placement for the optional secure fight buttons.

local ns = assert(MannersAPI:ModuleContext("combat"), "Manners module API is missing")

local Layout = {}
ns.CombatLayout = Layout

local GAP = 10

function Layout.Size(profile)
	profile = profile or {}
	return math.floor(math.max(24, math.min(48, tonumber(profile.iconSize) or 30))
		* (tonumber(profile.scale) or 1) + 0.5)
end

function Layout.PlaceRight(button, relative, profile)
	button:ClearAllPoints()
	button:SetPoint("LEFT", relative, "RIGHT", GAP, 0)
	button:SetSize(Layout.Size(profile))
end

function Layout.PlaceBelow(button, relative, profile)
	button:ClearAllPoints()
	button:SetPoint("TOP", relative, "BOTTOM", 0, -GAP)
	button:SetSize(Layout.Size(profile))
end

function Layout.RightOf(...)
	local last
	for index = 1, select("#", ...) do
		local component = select(index, ...)
		if component and type(component.Button) == "function" then
			local button = component:Button()
			local macro = button and button:GetAttribute("macrotext1")
			if type(macro) == "string" and macro ~= "" then last = button end
		end
	end
	return last or ns.Prompt.regions.button
end
