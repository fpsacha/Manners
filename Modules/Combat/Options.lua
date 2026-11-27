-- Manners: Combat -- cures and detected combat-action controls.

local api = assert(MannersAPI, "Manners is required")
local ns = assert(api:ModuleContext("combat"), "Manners module API is missing")
local L = ns.L
local Page = assert(ns.OptionsPage, "Manners options API is missing")

local function Profile()
	return api:GetProfile()
end

local function CombatLooks()
	local values, sorting = ns.Looks.Choices()
	values.same = L["Same as Manners"]
	table.insert(sorting, 1, "same")
	return values, sorting
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

local GROUPS = {
	interrupt = { order = 1, title = L["Interrupts and dispels"], key = "combat.interrupt" },
	enemy_dispel = { order = 1, title = L["Interrupts and dispels"], key = "combat.interrupt" },
	self_defense = { order = 2, title = L["Defensive actions"], key = "combat.defense" },
	enemy_self_heal = { order = 2, title = L["Defensive actions"], key = "combat.defense" },
	control = { order = 3, title = L["Movement and control"], key = "combat.control" },
	target_heal = { order = 4, title = L["Healing"], key = "combat.heal" },
	party_heal = { order = 4, title = L["Healing"], key = "combat.heal" },
	self_heal = { order = 4, title = L["Healing"], key = "combat.heal" },
	self_resource = { order = 5, title = L["Resource and recovery"], key = "combat.resource" },
	other = { order = 6, title = L["Other combat actions"], key = "combat.other" },
}

local function ActionGroup(row)
	if row.key == "coldsnap" then return "self_defense" end
	if row.category and GROUPS[row.category] then return row.category end
	local needs = {}
	for _, need in ipairs(row.needs or {}) do needs[need] = true end
	if needs.casting or needs.interruptible then return "interrupt" end
	if needs.removable or needs.stealable then return "enemy_dispel" end
	if needs.lowmana or needs.lowpower or needs.itemready or needs.partnercooling then return "self_resource" end
	if needs.friendlowhealth or needs.partylowhealth then return "party_heal" end
	if needs.lowhealth then return "self_defense" end
	if row.school then return "self_defense" end
	if needs.stuck or needs.falling or needs.schoolhit then return "control" end
	return "other"
end

local function ActionDescription(row)
	local category = row.category
	local key = row.key
	if category == "interrupt" or ActionGroup(row) == "interrupt" then
		return L["Detected when: a hostile target is casting or channeling an interruptible spell, and this action is ready and in range."]
	end
	if category == "enemy_dispel" or ActionGroup(row) == "enemy_dispel" then
		return L["Detected when: a hostile target has a beneficial effect this action can remove, and the action is ready and in range."]
	end
	if category == "target_heal" then
		return L["Detected when: your current friendly target is alive, in range and below the health threshold."]
	end
	if category == "party_heal" then
		return L["Detected when: a living party or raid member is below the health threshold."]
	end
	if category == "enemy_self_heal" then
		return L["Detected when: your health is below the threshold and a hostile target is alive and in range."]
	end
	if category == "self_heal" then
		return L["Detected when: your health is below the threshold."]
	end
	if category == "self_resource" or ActionGroup(row) == "self_resource" then
		if key == "managem" then
			return L["Detected when: your mana is below the threshold and a usable mana gem is in your bags or can be conjured."]
		end
		return L["Detected when: your primary resource is below the threshold and this action is ready and usable."]
	end
	if key == "blink" then
		return L["Detected when: the client reports a stun or root, or a brief loss of control where the kind is withheld."]
	end
	if key == "coldsnap" then
		return L["Detected when: your health is below the threshold and a spell this action restores is cooling down."]
	end
	if row.school then
		return L["Detected when: matching fire or frost damage hits you, or the target's incoming spell is known to use that school."]
	end
	if category == "self_defense" or ActionGroup(row) == "self_defense" then
		return L["Detected when: your health is below the threshold, the protection is not already active, and the action is ready and usable."]
	end
	return L["Detected when: the client's combat read reports the need for this action. Secret values are never guessed."]
end

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
	-- The rows this character has learned, and how many of them are switched on.
	local function Learned()
		local out = {}
		for _, row in ipairs(ns.MOMENTS[ns.caps.class] or {}) do
			if not row.calm and ns.Moments.Has(row.key) then out[#out + 1] = row end
		end
		return out
	end
	local function CountOn()
		local learned, on = Learned(), 0
		local switches = ns.db.profile.moments
		for _, row in ipairs(learned) do
			if switches[row.key] == true then on = on + 1 end
		end
		return on, #learned
	end
	local function Needs(...)
		local wanted = {}
		for i = 1, select("#", ...) do wanted[select(i, ...)] = true end
		for _, row in ipairs(Learned()) do
			for _, need in ipairs(row.needs or {}) do
				if wanted[need] then return true end
			end
		end
		return false
	end
	local function Off() return api:ModuleActive("combat") ~= true end
	local function Restyle()
		ns.Guard("combat prompt look", ns.Moments.Restyle)
	end

	args.combatActionStatus = {
		type = "description", order = 32.4995, width = "full", fontSize = "medium",
		hidden = Off,
		name = function()
			local on, learned = CountOn()
			if learned == 0 then
				return L["This character has not learned an action Manners can offer in a fight yet."]
			end
			if on == 0 then
				return L["Nothing is turned on yet. Pick the actions you want under Actions to offer: the combat prompt only appears in a fight when one of them is needed."]
			end
			return L["%d of %d actions on. The combat prompt appears in a fight only when one of them is needed; click anywhere on it to cast."]
				:format(on, learned)
		end,
	}
	args.combatActionMove = {
		type = "execute", order = 32.4996,
		name = function()
			if ns.Moments.Previewing() then return L["Done moving"] end
			return L["Show and move the combat prompt"]
		end,
		desc = function()
			if not ns.Moments.AnyArmed() then
				return L["Turn on at least one action first: the preview shows the prompt as that action would light it."]
			end
			return L["Shows the combat prompt where it will appear. Drag it to move it, then press this button again or right-click the prompt. Nothing casts from the preview."]
		end,
		disabled = function() return InCombatLockdown() or not ns.Moments.AnyArmed() end,
		hidden = function() return Off() or #Learned() == 0 end,
		func = function() ns.Guard("move combat prompt", ns.Moments.TogglePreview) end,
	}
	args.combatActionReset = {
		type = "execute", name = L["Put the combat prompt on Manners"], order = 32.4997,
		desc = L["Returns the combat prompt to the normal Manners prompt's place."],
		disabled = function()
			local m = ns.db.profile.moments
			return InCombatLockdown() or (m.promptX == nil and m.promptY == nil)
		end,
		hidden = function() return Off() or #Learned() == 0 end,
		func = function() ns.Guard("reset combat prompt place", ns.Moments.ResetPosition, ns.Moments) end,
	}
	local function SetEvery(value)
		local switches = ns.db.profile.moments
		for _, row in ipairs(Learned()) do switches[row.key] = value end
		ns.Guard("combat actions", ns.Moments.Refresh, ns.Moments)
	end
	args.combatActionAllOn = {
		type = "execute", name = L["Turn all on"], order = 32.4998,
		desc = L["Turn on every combat action this character has learned. Each still appears only when it is needed."],
		disabled = function()
			local on, learned = CountOn()
			return InCombatLockdown() or on == learned
		end,
		hidden = function() return Off() or #Learned() < 2 end,
		func = function() SetEvery(true) end,
	}
	args.combatActionAllOff = {
		type = "execute", name = L["Turn all off"], order = 32.4999,
		desc = L["Turn off every combat action. The combat prompt then never appears."],
		disabled = function() return InCombatLockdown() or (CountOn()) == 0 end,
		hidden = function() return Off() or #Learned() < 2 end,
		func = function() SetEvery(false) end,
	}
	args.combatActionHealth = {
		type = "range", name = L["Health below"], order = 32.501,
		desc = L["The health percentage that makes a healing or defensive combat action relevant."],
		min = 5, max = 50, step = 5, width = "full",
		hidden = function() return Off() or not Needs("lowhealth", "friendlowhealth", "partylowhealth") end,
		get = function() return ns.db.profile.moments.health end,
		set = function(_, value)
			ns.db.profile.moments.health = value
			ns.Guard("combat action threshold", ns.Moments.Refresh, ns.Moments)
		end,
	}
	args.combatActionResource = {
		type = "range", name = L["Resource below"], order = 32.502,
		desc = L["The mana or other primary-resource percentage that makes a recovery action relevant."],
		min = 5, max = 50, step = 5, width = "full",
		hidden = function() return Off() or not Needs("lowmana", "lowpower") end,
		get = function() return ns.db.profile.moments.mana end,
		set = function(_, value)
			ns.db.profile.moments.mana = value
			ns.Guard("combat action threshold", ns.Moments.Refresh, ns.Moments)
		end,
	}
	local function SameLook() return ns.db.profile.moments.look == "same" end
	args.combatActionLookSame = {
		type = "toggle", name = L["Wear the Manners prompt's look"], order = 32.5034,
		desc = L["The combat prompt looks like your normal Manners prompt. Turn this off to pick a look of its own below."],
		width = "full", hidden = Off,
		get = function() return SameLook() end,
		set = function(_, value)
			local m = ns.db.profile.moments
			if value then
				m.look = "same"
			elseif SameLook() then
				-- The gallery starts on the look it wore, so nothing jumps.
				local style = ns.db.profile.prompt.style
				m.look = type(style) == "string" and ns.Looks.Allowed()[style] and style or "glass"
			end
			Restyle()
		end,
	}
	args.combatActionLook = {
		type = "select", name = L["Combat prompt look"], order = 32.5035,
		desc = L["Choose any Manners look for the combat prompt, or keep it the same as the normal prompt."],
		values = CombatLooks(),
		sorting = select(2, CombatLooks()),
		width = "full",
		hidden = function() return Off() or SameLook() end,
		get = function()
			local look = ns.db.profile.moments.look
			if look == "same" then return ns.db.profile.prompt.style end
			return type(look) == "string" and ns.Looks.Allowed()[look] and look or ns.db.profile.prompt.style
		end,
		set = function(_, value)
			ns.db.profile.moments.look =
				type(value) == "string" and ns.Looks.Allowed()[value] and value or "same"
			ns.Moments.tried = nil
			Restyle()
		end,
		-- The gallery's cards try a look on the combat prompt under the pointer
		-- (Options/Window/WidgetsTheme.lua, OwnTry), not on the Manners prompt.
		tryLook = function(key) ns.Guard("combat prompt look", ns.Moments.TryLook, key) end,
	}
	args.combatActionSize = {
		type = "range", name = L["Combat prompt size"], order = 32.5036,
		desc = L["A percentage of the normal Manners prompt's size. Bigger is easier to notice and to click in a fight."],
		min = 75, max = 200, step = 5, width = "full",
		hidden = Off,
		get = function() return ns.db.profile.moments.cardSize or 150 end,
		set = function(_, value)
			ns.db.profile.moments.cardSize = value
			ns.db.profile.moments.combatPromptSizeSet = true
			Restyle()
		end,
	}
	args.combatActionAlert = {
		type = "select", name = L["Combat alert"], order = 32.5037,
		desc = L["Quiet keeps the prompt steady. Pulse adds a gentle glow; Strong pulse is faster and brighter for urgent actions."],
		values = { none = L["Quiet"], pulse = L["Pulse"], strong = L["Strong pulse"] },
		sorting = { "none", "pulse", "strong" },
		width = "full",
		hidden = Off,
		get = function() return ns.db.profile.moments.alert or "pulse" end,
		set = function(_, value)
			ns.db.profile.moments.alert = value == "strong" and "strong" or (value == "none" and "none" or "pulse")
			Restyle()
		end,
	}
	args.combatActionSound = {
		type = "toggle", name = L["Play a sound for a combat need"], order = 32.5038,
		desc = L["Play the alert sound once when the one combat prompt changes to a newly detected action. Turning this on plays it once so you hear it."],
		width = "full",
		hidden = Off,
		get = function() return ns.db.profile.moments.alertSound == true end,
		set = function(_, value)
			ns.db.profile.moments.alertSound = value == true
			if value == true then ns.Moments.SampleSound() end
		end,
	}

	local rows = ns.MOMENTS and ns.MOMENTS[ns.caps.class] or {}
	local grouped = {}
	for _, row in ipairs(rows) do
		if not row.calm then
			local suffix = row.key:sub(1, 1):upper() .. row.key:sub(2)
			-- The window's paths are tab.key with letters, digits and _ only.
			local toggle = "moment" .. suffix:gsub("[^%w_]", "_")
			local category = ActionGroup(row)
			local path = "appearance." .. toggle
			local definition = GROUPS[category] or GROUPS.other
			grouped[definition.key] = grouped[definition.key] or { definition = definition, items = {} }
			grouped[definition.key].items[#grouped[definition.key].items + 1] = path
			args[toggle] = {
				type = "toggle",
				name = function() return ns.Moments.NameOf(row.key) or row.key end,
				desc = function()
					return ActionDescription(row) .. "\n\n"
						.. L["The one combat prompt changes to the most urgent detected action. Left-click it to cast; your normal Manners prompt key keeps its usual job."]
				end,
				order = 32.55 + (row.slot or 0) * .001,
				width = "full",
				hidden = function() return Off() or not ns.Moments.Has(row.key) end,
				get = function() return ns.db.profile.moments[row.key] == true end,
				set = function(_, value)
					ns.db.profile.moments[row.key] = value == true
					ns.Guard("combat action", ns.Moments.Refresh, ns.Moments)
				end,
			}
		end
	end

	-- Each group's switches into its section of the Combat page, in place: every
	-- section emptied first, so a group this class lacks keeps nothing of another's.
	local page = ns.WindowLayout and ns.WindowLayout.pages and ns.WindowLayout.pages.combat
	for _, section in ipairs(page and page.sections or {}) do
		if section.home then
			wipe(section.items)
			local group = grouped[section.key]
			for i, path in ipairs(group and group.items or {}) do section.items[i] = path end
		end
	end
	if Page.ForgetPageMap then Page.ForgetPageMap() end
end)

-- The Combat page, in the order it is set up: what it does and where it sits,
-- what to offer (one section per kind of action, filled as the options are
-- built, a section with nothing learned not drawn), then how it looks and when
-- an action counts as needed. Every control keeps its "appearance." path, so
-- its saved setting and a search for it are unchanged.
do
	local sections = {
		{ key = "combat.start", title = L["Combat prompt"], items = {
			"appearance.combatActionStatus",
			{ "appearance.combatActionMove", buttons = true },
			{ "appearance.combatActionReset", buttons = true },
		} },
		{ key = "combat.choose", title = L["Actions to offer"], items = {
			{ "appearance.combatActionAllOn", buttons = true },
			{ "appearance.combatActionAllOff", buttons = true },
		} },
	}
	local actions, seen, order = { title = L["Actions to offer"], "combat.choose" }, {}, {}
	for _, definition in pairs(GROUPS) do
		if not seen[definition.key] then
			seen[definition.key] = true
			order[#order + 1] = definition
		end
	end
	table.sort(order, function(a, b) return a.order < b.order end)
	for _, definition in ipairs(order) do
		-- HOME: this kind of action's switches, filled as the options are built.
		sections[#sections + 1] = { key = definition.key, title = definition.title, items = {}, home = true }
		actions[#actions + 1] = definition.key
	end
	-- Everything In a fight held comes here, so every choice about a fight is on
	-- one page (and In a fight, left with nothing, leaves the sidebar): what the
	-- prompt does once a fight starts, first, and the buttons a fight brings up
	-- beside it (Will of the Forsaken, the cure in a fight, Mend Pet, the ward).
	do
		local fight = ns.WindowLayout and ns.WindowLayout.pages and ns.WindowLayout.pages.fight
		local moved = {}
		for i = #(fight and fight.sections or {}), 1, -1 do
			local section = fight.sections[i]
			if section.key == "fight.prompt" or section.key == "fight.buttons" then
				moved[section.key] = section.items
				table.remove(fight.sections, i)
			end
		end
		if moved["fight.prompt"] then
			sections[#sections + 1] = { key = "combat.rota", title = L["The prompt in a fight"],
				items = moved["fight.prompt"] }
			actions[#actions + 1] = "combat.rota"
		end
		if moved["fight.buttons"] then
			sections[#sections + 1] = { key = "combat.buttons", title = L["Fight buttons beside the prompt"],
				items = moved["fight.buttons"] }
			actions[#actions + 1] = "combat.buttons"
		end
	end
	sections[#sections + 1] = { key = "combat.look", title = L["Look and alerts"], items = {
		"appearance.combatActionLookSame",
		{ "appearance.combatActionLook", widget = "themes" }, "appearance.combatActionSize",
		{ "appearance.combatActionAlert", match = "combatPrompt" }, "appearance.combatActionSound",
	} }
	sections[#sections + 1] = { key = "combat.thresholds", title = L["When an action is needed"], items = {
		"appearance.combatActionHealth", "appearance.combatActionResource",
	} }
	api:RegisterOptionsPage("combat", function()
		return { type = "group", name = L["Combat"], args = {} }
	end, {
		title = L["Combat"],
		blurb = L["One prompt that lights up in a fight when an action you picked is needed."],
		icon = "Interface\\AddOns\\Manners\\Textures\\Manners64",
		sections = sections,
		subpages = { actions, { "combat.look", "combat.thresholds" } },
	}, "modules")
	local layout = ns.WindowLayout
	if layout then
		-- The simple view keeps what sets the page up: how many are on, the
		-- switches for all of them, and moving the prompt.
		if layout.simple and type(layout.simple.items) == "table" then
			for _, path in ipairs({ "appearance.combatActionStatus", "appearance.combatActionMove",
				"appearance.combatActionAllOn", "appearance.combatActionAllOff" }) do
				layout.simple.items[path] = true
			end
		end
		-- In a fight, the page says its changes wait for the fight's end, as In a fight did.
		if type(layout.strip) == "table" and type(layout.strip.combat) == "table" then
			layout.strip.combat.combat = layout.strip.combat.fight
			layout.strip.combat.fight = nil
		end
		if type(layout.units) == "table" then
			layout.units["appearance.combatActionSize"] = { kind = "percent" }
			layout.units["appearance.combatActionHealth"] = { kind = "percent" }
			layout.units["appearance.combatActionResource"] = { kind = "percent" }
		end
	end
end

-- Reset this page on Combat: what it offers, its look and alerts, its
-- thresholds. Where the prompt sits is kept, as on every page; its own button
-- puts it back.
do
	local reset = Page.RESET
	if type(reset) == "table" then
		local list = {
			"moments.health", "moments.mana", "moments.cardSize", "moments.look",
			"moments.alert", "moments.alertSound",
			-- What came here from In a fight: the rota and the fight's buttons.
			"prompt.fightRota", "prompt.breakFree", "beast.fightMend", "prompt.cureFight",
			"prompt.cureFightEach", "prompt.cureFightMods", "prompt.reactiveWards", "prompt.fightButtons",
		}
		for _, key in ipairs(ns.MOMENT_KEYS or {}) do list[#list + 1] = "moments." .. key end
		list.keep = function() return not api:ModuleActive("combat") end
		local fightAfter = reset.fight and reset.fight.after
		list.after = function()
			if fightAfter then fightAfter() end
			if api:ModuleActive("combat") and ns.Moments then
				ns.Guard("reset combat actions", ns.Moments.Refresh, ns.Moments)
			end
		end
		reset.combat = list
	end
end
