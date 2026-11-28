-- A control in the options window that names one of your spells wears that
-- spell's icon (Options/Window/Widgets.lua, W.SpellIcon): a switch beside its
-- box, a dropdown's words inline. One that names no spell wears none.
--
-- Every scenario name starts with "menu-icons:" so tests/mutations/menu-icons.py
-- can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local function context()
	local ctx = { changes = {}, holds = {}, pages = {}, relayouts = 0 }
	ctx.Window = CreateFrame("Frame", "MannersOptionsSpellIconTest", UIParent)
	ctx.Window:SetSize(820, 600)
	ctx.OnChange = function() end
	ctx.OnHold = function() end
	ctx.ScrollPage = function() end
	ctx.Relayout = function(row) row:Layout(row.width) end
	return ctx
end

do
	local scenario = "menu-icons: a switch naming your spell wears its icon, one naming none wears nothing"
	Mock.reset()
	Mock.class = "PRIEST"
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local W = ns.WindowWidgets
		local spirit = ns.FindBuff("PRIEST", "spirit")
		local name = spirit and ns.SpellNameFor(spirit.ranks[1])
		local want = spirit and C_Spell.GetSpellTexture(spirit.ranks[1])
		if not (name and want) then
			fail(scenario, "SKIPPED -- Divine Spirit has no name or icon on this client")
		else
			local ctx = context()
			local mana = ns.WindowBind.Item("who.relevantOnly", {}, ctx)
			local pets = ns.WindowBind.Item("who.pets", {}, ctx)
			if not (mana and pets) then
				fail(scenario, "SKIPPED -- the model has no Only to players with mana or pets switch")
			else
				local row = W.Build("toggle", ctx.Window, mana)
				row:Refresh()
				row:Layout(560)
				if W.Image(row) ~= want or not row.icon:IsShown() then
					fail(scenario, "Only give " .. name .. " to players with mana wears " .. tostring(W.Image(row)))
				end
				local plain = W.Build("toggle", ctx.Window, pets)
				plain:Refresh()
				plain:Layout(560)
				if W.Image(plain) ~= nil or plain.icon:IsShown() then
					fail(scenario, "My group's pets too wears an icon: " .. tostring(W.Image(plain)))
				end
			end
			local inline = W.WithIcon("Automatic (" .. name .. ")")
			if not inline:find("^|T") or not inline:find(name, 1, true) then
				fail(scenario, "a dropdown's words naming " .. name .. " lead with no icon: " .. inline)
			end
			if W.WithIcon("Nearby (about 10 yards)") ~= "Nearby (about 10 yards)" then
				fail(scenario, "words naming no spell were given an icon")
			end
		end
	end
	Mock.reset()
end
