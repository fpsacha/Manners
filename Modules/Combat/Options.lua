-- Manners: Combat -- out-of-fight cure controls in Who to buff.

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("combat"), "Manners module API is missing")
local L = ns.L
local Page = assert(ns.OptionsPage, "Manners options API is missing")

local function Profile()
	return api:GetProfile()
end

local function NoCures()
	return not api:ModuleActive("combat") or not ns.ClassHasCures()
end

local function Source(key)
	local profile = Profile()
	return profile and profile.sources[key] == true
end

api:RegisterOptionsExtension("who", function(_, args)
	local function CuresOff()
		return not (Source("cures") or Source("curesStrangers") or Source("curesSelf"))
	end
	args.curesHeader = { type = "header", name = L["Cures"], order = 14.9, hidden = NoCures }
	args.curesNote = {
		type = "description",
		order = 14.91,
		hidden = NoCures,
		name = function() return "|cff888888" .. ns.CureSummary() .. "|r" end,
	}
	args.cures = {
		type = "toggle",
		name = L["Cure my party and raid"],
		desc = L["Out of combat, offer to take a poison, a disease, a curse or a harmful spell off someone in your party or raid, with the spell your class has for it. A cure comes before a buff for the same person, and after a favour you owe."],
		order = 14.92, width = "full", hidden = NoCures,
		get = Page.sGet, set = Page.sSet,
	}
	args.curesStrangers = {
		type = "toggle",
		name = L["Cure passers-by"],
		desc = L["The same for players near you who are not in your group, seen through nameplates, your target, focus and mouseover."],
		order = 14.93, width = "full", hidden = NoCures,
		get = Page.sGet, set = Page.sSet,
	}
	args.curesSelf = {
		type = "toggle",
		name = L["Cure myself too"],
		desc = L["Out of combat, offer to take a poison, a disease, a curse or a harmful spell off yourself, with the spell your class has for it. It comes before your own buffs."],
		order = 14.935, width = "full", hidden = NoCures,
		get = Page.sGet, set = Page.sSet,
	}
	args.cureSeconds = {
		type = "range",
		name = L["Only when it has at least this long left"],
		desc = L["In seconds."] .. " " .. L["A poison, disease, curse or spell about to run out on its own is left alone. One with no timer is never offered."],
		order = 14.94, min = 0, max = 120, step = 5,
		hidden = NoCures, disabled = CuresOff,
		get = Page.fGet, set = Page.fSet,
	}
	args.curesFight = {
		type = "description",
		name = function()
			return L["The cure button for a fight is set on its own page: %s, with its key and which cure Shift and Ctrl cast."]
				:format(Page.RefTo(
					L["Show my cure on a button in a fight, only while somebody needs it"],
					"appearance.cureFight"))
		end,
		order = 14.95, width = "full",
		hidden = function() return NoCures() or not ns.CureFight or not ns.CureLearned() end,
	}
end)

api:InsertLayoutItems("who", "who.resStrangers", {
	"who.curesNote", "who.cures", "who.curesStrangers", "who.curesSelf",
	{ "who.cureSeconds", indent = true }, "who.curesFight",
})

api:RegisterOptionsExtension("appearance", function(_, args)
	args.reactiveWards = {
		type = "toggle",
		name = L["Show a matching ward button when fire or frost hits me in a fight"],
		desc = L["The matching Fire Ward or Frost Ward is armed on a secure button before the fight. After a fire or frost damage read in the fight, one click casts it. The button hides after a ward is cast, while either ward is active, and when the fight ends. Off until you turn it on."],
		order = 32.493,
		width = "full",
		hidden = function()
			return not ns.ReactiveWards or not ns.ReactiveWards.Supported()
				or not ns.ReactiveWards.Knows()
		end,
		get = Page.pGet,
		set = function(info, value)
			Page.pSet(info, value)
			if value == true then
				ns.Guard("reactive wards", ns.ReactiveWards.Refresh, ns.ReactiveWards)
			else
				ns.Guard("reactive wards off", ns.ReactiveWards.Release, ns.ReactiveWards)
			end
		end,
	}
end)
