-- Manners: Services -- one page, present only while the module is loaded.

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("services"), "Manners module API is missing")
local L, Courtesy = ns.L, ns.Courtesy
local InCombatLockdown = _G.InCombatLockdown

local function Profile()
	return api:GetProfile()
end

local function LegacyToggle(key, label, desc, order)
	return {
		type = "toggle", name = label, desc = desc, order = order, width = "full",
		hidden = function()
			local profile = Profile()
			return not (profile and profile.sources.asked and Courtesy.Has(key))
		end,
		get = function()
			local profile = Profile()
			return profile and profile.sources[key] == true
		end,
		set = function(_, value)
			local profile = Profile()
			if profile then profile.sources[key] = value == true end
			Courtesy.Forget()
			Courtesy.Sync()
			api:RefreshPrompt()
		end,
	}
end

local function ServiceToggle(args, key, service, setting, label, desc, order)
	args[key] = {
		type = "toggle", name = label, desc = desc, order = order, width = "full",
		hidden = function() return not Courtesy.Has(setting) end,
		disabled = function()
			local profile = Profile()
			return InCombatLockdown() or api:ModuleActive("services") ~= true
				or not (profile and profile.sources.asked)
		end,
		get = function() return Courtesy.ServiceOn(service) end,
		set = function(_, value) Courtesy.SetServiceOn(service, value) end,
	}
end

local function Policy(args, service, setting, prefix, order, words)
	local function Available()
		return Courtesy.Has(setting)
	end
	local function Disabled()
		local profile = Profile()
		return InCombatLockdown() or api:ModuleActive("services") ~= true
			or not (profile and profile.sources.asked) or not Courtesy.ServiceOn(service)
	end
	args[prefix .. "Scope"] = {
		type = "multiselect", name = L["Requests I accept"], order = order + .01,
		desc = L["Choose the people whose request this service may answer: your current target, party or raid chat, and direct whispers. Clear all three to leave the service on but silent."],
		hidden = function() return not Available() end, disabled = Disabled,
		values = {
			group = L["Party or raid chat"],
			whisper = L["Whispers"],
			target = L["Your target."],
		},
		get = function(_, scope) return Courtesy.Scope(service, scope) end,
		set = function(_, scope, on)
			Courtesy.SetScope(service, scope, on)
			api:RefreshPrompt()
		end,
	}
	args[prefix .. "Combat"] = {
		type = "select", name = L["If they ask in a fight"], order = order + .02,
		desc = L["A service is never cast in combat. Hold keeps an allowed request for the moment the fight ends; Ignore drops it immediately."],
		hidden = function() return not Available() end, disabled = Disabled,
		values = { hold = L["Hold until the fight ends"], ignore = L["Ignore the request"] },
		sorting = { "hold", "ignore" },
		get = function() return Courtesy.ServiceSetting(service, "combat", "hold") end,
		set = function(_, value)
			Courtesy.SetServiceSetting(service, "combat", value)
			api:RefreshPrompt()
		end,
	}
	args[prefix .. "Where"] = {
		type = "select", name = L["Where it may be offered"], order = order + .03,
		desc = L["Anywhere obeys the usual quiet-time rules. Outside instances never offers this service in a dungeon, raid or battleground."],
		hidden = function() return not Available() end, disabled = Disabled,
		values = { anywhere = L["Anywhere"], outside = L["Outside instances"] },
		sorting = { "anywhere", "outside" },
		get = function() return Courtesy.ServiceSetting(service, "where", "anywhere") end,
		set = function(_, value)
			Courtesy.SetServiceSetting(service, "where", value)
			api:RefreshPrompt()
		end,
	}
	if words ~= false then
		args[prefix .. "Words"] = {
			type = "select", name = L["Words that count"], order = order + .04,
			desc = L["The spell or item's own name is always read. Short aliases also accept the familiar request words, such as water, hs or summon, without reading ordinary conversation as a request."],
			hidden = function() return not Available() end, disabled = Disabled,
			values = { strict = L["Explicit names only"], aliases = L["Explicit names and short aliases"] },
			sorting = { "strict", "aliases" },
			get = function() return Courtesy.ServiceSetting(service, "matching", "aliases") end,
			set = function(_, value)
				Courtesy.SetServiceSetting(service, "matching", value)
				api:RefreshPrompt()
			end,
		}
	end
end

api:RegisterOptionsExtension("who", function(_, args)
	args.servicesModule = {
		type = "toggle", name = L["Manners: Services"], order = 13.98, width = "full",
		desc = L["Load or unload the optional Services addon. Turning it off stops its requests, frames and queue work immediately; Reload UI completes the addon change."],
		disabled = function() return InCombatLockdown() end,
		get = function() return api:IsModuleEnabled("services") == true end,
		set = function(_, value) api:SetModuleEnabled("services", value == true) Courtesy.Sync() end,
	}
	args.servicesModuleHelp = {
		type = "description", order = 13.981,
		name = L["Mage refreshments and portals, warlock summons and stones, Priest Levitate, Shaman Water Walking, and Fire Shield where the client supports them."],
	}
	args.servicesReload = {
		type = "execute", name = L["Reload now"], order = 13.982, width = "full",
		desc = L["Apply an optional-module load or unload change."],
		hidden = function() return not api:ModuleReloadPending() end,
		disabled = function() return InCombatLockdown() end,
		func = function()
			if not InCombatLockdown() and type(ReloadUI) == "function" then ReloadUI() end
		end,
	}
	args.servicesAsked = {
		type = "toggle", name = L["People who ask me in chat"],
		desc = L["For a minute, offer your buff to someone who asks for it (\"fort pls\"); off by default because chat is guesswork."],
		order = 13.983, width = "full",
		disabled = function() return InCombatLockdown() end,
		get = function()
			local profile = Profile()
			return profile and profile.sources.asked == true
		end,
		set = function(_, value)
			local profile = Profile()
			if profile then profile.sources.asked = value == true end
			Courtesy.Forget()
			Courtesy.Sync()
			api:RefreshPrompt()
		end,
	}

	-- Kept as a real, saved control for old profiles and settings-search
	-- links. The Services page separates the two refreshments below.
	args.courtesyRefresh = LegacyToggle("courtesyRefresh", L["Water and food, when they ask"],
		L["Somebody who asks for water or food is offered it. New profiles can choose water and food separately on Manners: Services."], 70.00)

	ServiceToggle(args, "courtesyWater", "water", "courtesyWater", L["Conjured water, when they ask"],
		L["A person allowed below who asks for water is offered the best conjured rank that suits their level. With none in your bags, the first press conjures it and the next opens a trade."], 70.10)
	Policy(args, "water", "courtesyWater", "courtesyWater", 70.10)
	ServiceToggle(args, "courtesyFood", "food", "courtesyFood", L["Conjured food, when they ask"],
		L["A person allowed below who asks for food is offered the best conjured rank that suits their level. With none in your bags, the first press conjures it and the next opens a trade."], 70.20)
	Policy(args, "food", "courtesyFood", "courtesyFood", 70.20)

	args.courtesyPortals = LegacyToggle("courtesyPortals", L["Portals, when my group asks"],
		L["A member of your party or raid who explicitly asks for a learned destination is offered that portal. The press targets nobody, and Manners casts only the destination named in chat."], 70.30)
	Policy(args, "portal", "courtesyPortals", "courtesyPortal", 70.30, false)
	args.courtesyPortalDestinations = {
		type = "multiselect", name = L["Portal destinations"],
		desc = L["Only ticked destinations can be matched from chat. A destination must also be learned and in range of its own rules before it is offered."],
		order = 70.35, hidden = function() return not Courtesy.Has("courtesyPortals") end,
		disabled = function()
			local profile = Profile()
			return InCombatLockdown() or not (profile and profile.sources.asked
				and profile.sources.courtesyPortals)
		end,
		values = function() return Courtesy.PortalDestinations() end,
		get = function(_, spell) return Courtesy.Destination(spell) end,
		set = function(_, spell, on)
			Courtesy.SetDestination(spell, on)
			api:RefreshPrompt()
		end,
	}

	args.courtesyHealthstones = LegacyToggle("courtesyHealthstones", L["Healthstones and Soulwell"],
		function()
			if Courtesy.FromSoulwell() then
				return L["A member of your group who asks for a healthstone is offered a Soulwell. On older clients, a stone that suits them is created or traded instead."]
			end
			return L["A person allowed below who asks for a healthstone is offered one. With none in your bags, the first press creates it and the next opens a trade."]
		end, 70.40)
	Policy(args, "healthstone", "courtesyHealthstones", "courtesyHealthstone", 70.40)

	args.courtesySummons = LegacyToggle("courtesySummons", L["Group summons, when they ask"],
		L["A member of your party or raid who explicitly asks for a summon is offered Ritual of Summoning. The press targets them and leaves them targeted for the summons portal."], 70.50)
	Policy(args, "summon", "courtesySummons", "courtesySummon", 70.50)
	ServiceToggle(args, "courtesySoulstone", "soulstone", "courtesySoulstone", L["Soulstone preparation"],
		L["On a clear request, Manners creates the best learned Soulstone when needed, then targets the requester and uses it. A target already carrying a Soulstone is never offered another."], 70.60)
	Policy(args, "soulstone", "courtesySoulstone", "courtesySoulstone", 70.60)
	ServiceToggle(args, "courtesySlowFall", "slowfall", "courtesySlowFall", L["Slow Fall on request"],
		L["An explicit, in-range Slow Fall request is answered for an alive, friendly visible player, with the learned spell, required reagent and cooldown checked first."], 70.70)
	Policy(args, "slowfall", "courtesySlowFall", "courtesySlowFall", 70.70)
	ServiceToggle(args, "courtesyLevitate", "levitate", "courtesyLevitate", L["Levitate on request"],
		L["An explicit, in-range Levitate request is answered for an alive, friendly visible player, with the learned spell, required reagent and cooldown checked first."], 70.80)
	Policy(args, "levitate", "courtesyLevitate", "courtesyLevitate", 70.80)
	ServiceToggle(args, "courtesyWaterWalking", "waterwalking", "courtesyWaterWalking", L["Water Walking on request"],
		L["An explicit, in-range Water Walking request is answered for an alive, friendly visible player, with the learned spell, required reagent and cooldown checked first."], 70.90)
	Policy(args, "waterwalking", "courtesyWaterWalking", "courtesyWaterWalking", 70.90)

	args.courtesyTarget = {
		type = "toggle", name = L["Offer water and food to my target"],
		desc = L["Out of a fight, a friendly player you target is offered water and food that suits their level, or food alone for a class without mana. Nothing is offered if their level, viability or trade range cannot be read."],
		order = 71.00, width = "full",
		hidden = function() return not Courtesy.Has("courtesyRefresh") end,
		disabled = function() return InCombatLockdown() or api:ModuleActive("services") ~= true end,
		get = function() local p = Profile(); return p and p.sources.courtesyTarget == true end,
		set = function(_, value)
			local p = Profile()
			if p then p.sources.courtesyTarget = value == true end
			Courtesy.Sync()
			api:RefreshPrompt()
		end,
	}
	args.courtesyAmount = {
		type = "select", name = L["How much to trade"], order = 71.01,
		desc = L["One stack of each requested refreshment, or as many stacks as the trade window and your bags hold that suit them."],
		values = { fill = L["Fill the trade window"], one = L["One stack"] }, sorting = { "fill", "one" },
		hidden = function()
			local p = Profile()
			return not (p and Courtesy.Has("courtesyRefresh")
				and (p.sources.courtesyTarget or (p.sources.asked
					and (p.sources.courtesyRefresh or Courtesy.ServiceOn("water") or Courtesy.ServiceOn("food")))))
		end,
		get = function() local p = Profile(); return p and p.sources.courtesyAmount or "fill" end,
		set = function(_, value)
			local p = Profile()
			if p then p.sources.courtesyAmount = value == "one" and "one" or "fill" end
		end,
	}

	if type(Courtesy.SetFireShield) == "function" then
		args.courtesyFireShield = {
			type = "toggle", name = L["Fire Shield from my imp on the tank"],
			desc = L["The imp's Fire Shield is an optional party-tank service on the clients that prove it. It is offered only with the imp's spell learned, never in combat, and never on yourself."],
			order = 71.02, width = "full",
			disabled = function() return InCombatLockdown() or api:ModuleActive("services") ~= true end,
			get = Courtesy.FireShieldOn,
			set = function(_, value) Courtesy.SetFireShield(value) end,
		}
	end
end)

local function Items(service, prefix, words)
	local out = { "who." .. prefix }
	for _, suffix in ipairs({ "Scope", "Combat", "Where", words ~= false and "Words" or nil }) do
		if suffix then out[#out + 1] = { "who." .. prefix .. suffix, indent = true } end
	end
	return out
end

local layout = {
	title = L["Services"],
	blurb = L["Optional class services for clear requests, with no action taken until you press the prompt."],
	icon = "Interface\\AddOns\\Manners\\Textures\\Manners64",
	sections = {
		{ key = "services.module", title = L["Module"], items = {
			"who.servicesModule", "who.servicesModuleHelp", "who.servicesReload",
			"who.servicesAsked", "who.courtesyRefresh",
		} },
		{ key = "services.water", title = L["Conjured water"], fold = true, items = Items("water", "courtesyWater") },
		{ key = "services.food", title = L["Conjured food"], fold = true, items = Items("food", "courtesyFood") },
		{ key = "services.target", title = L["My target"], fold = true, items = {
			"who.courtesyTarget", { "who.courtesyAmount", indent = true },
		} },
		{ key = "services.portals", title = L["Portals"], fold = true, items = (function()
			local items = Items("portal", "courtesyPortal", false)
			items[1] = "who.courtesyPortals"
			items[#items + 1] = { "who.courtesyPortalDestinations", indent = true }
			return items
		end)() },
		{ key = "services.healthstone", title = L["Healthstones"], fold = true, items = (function()
			local items = Items("healthstone", "courtesyHealthstone")
			items[1] = "who.courtesyHealthstones"
			return items
		end)() },
		{ key = "services.summon", title = L["Group summons"], fold = true, items = (function()
			local items = Items("summon", "courtesySummon")
			items[1] = "who.courtesySummons"
			return items
		end)() },
		{ key = "services.soulstone", title = L["Soulstones"], fold = true, items = Items("soulstone", "courtesySoulstone") },
		{ key = "services.slowfall", title = L["Slow Fall"], fold = true, items = Items("slowfall", "courtesySlowFall") },
		{ key = "services.levitate", title = L["Levitate"], fold = true, items = Items("levitate", "courtesyLevitate") },
		{ key = "services.waterwalking", title = L["Water Walking"], fold = true, items = Items("waterwalking", "courtesyWaterWalking") },
	},
	subpages = {
		{ "services.module", "services.water", "services.food" },
		{ "services.target", "services.portals" },
		{ "services.healthstone", "services.summon", "services.soulstone" },
		{ "services.slowfall", "services.levitate", "services.waterwalking" },
	},
}
if type(Courtesy.SetFireShield) == "function" then
	layout.sections[#layout.sections + 1] = {
		key = "services.fireshield", title = L["Fire Shield"], fold = true,
		items = { "who.courtesyFireShield" },
	}
	layout.subpages[#layout.subpages + 1] = { "services.fireshield" }
end
api:RegisterOptionsPage("services", function()
	return { type = "group", name = L["Services"], args = {} }
end, layout, "modules")
if ns.WindowLayout and ns.WindowLayout.simple and ns.WindowLayout.simple.pages then
	ns.WindowLayout.simple.pages.services = true
end
if ns.WindowLayout and ns.WindowLayout.parents then
	local parents = ns.WindowLayout.parents
	local masters = {
		courtesyWater = "who.courtesyWater", courtesyFood = "who.courtesyFood",
		courtesyPortal = "who.courtesyPortals", courtesyHealthstone = "who.courtesyHealthstones",
		courtesySummon = "who.courtesySummons", courtesySoulstone = "who.courtesySoulstone",
		courtesySlowFall = "who.courtesySlowFall", courtesyLevitate = "who.courtesyLevitate",
		courtesyWaterWalking = "who.courtesyWaterWalking",
	}
	for prefix, parent in pairs(masters) do
		parents[parent] = "who.servicesAsked"
		local setting = prefix == "courtesyPortal" and "courtesyPortals"
			or prefix == "courtesyHealthstone" and "courtesyHealthstones"
			or prefix == "courtesySummon" and "courtesySummons" or prefix
		ns.WindowLayout.parentsIf[parent] = function() return Courtesy.Has(setting) end
		for _, suffix in ipairs({ "Scope", "Combat", "Where", "Words" }) do
			parents["who." .. prefix .. suffix] = parent
		end
	end
	parents["who.courtesyPortalDestinations"] = "who.courtesyPortals"
	parents["who.courtesyAmount"] = "who.courtesyTarget"
end
