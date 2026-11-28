-- Detected combat actions: every class gets a learned, opt-in action on each
-- client, and none is active before the player enables it.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

local ALL = {
	[ "camelot" ] = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" },
	vanilla = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" },
	tbc = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" },
	mists = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK",
		"DRUID", "MONK" },
	mainline = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK",
		"DRUID", "MONK", "DEMONHUNTER", "EVOKER" },
}

do
	-- The defensives a class reaches for when low: each on the list once, as
	-- Forever's spell book names it.
	local scenario = "combat-actions: Forever lists every class's emergency defensives once"
	Mock.reset()
	local ns = load(scenario)
	if ns then
		local want = {
			WARRIOR = "combat-self_defense-shield-wall", MAGE = "combat-self_defense-mana-shield",
			HUNTER = "combat-self_defense-feign-death", ROGUE = "combat-self_defense-vanish",
			PRIEST = "combat-target_heal-power-word-shield", PALADIN = "combat-target_heal-blessing-of-protection",
			DRUID = "combat-self_defense-barkskin",
		}
		for class, rows in pairs(ns.MOMENT_SETS and ns.MOMENT_SETS.camelot or {}) do
			local keys, names = {}, {}
			for _, row in ipairs(rows) do
				keys[row.key] = true
				local name = row.key:gsub("^combat%-[%w_]+%-", "")
				if row.key:find("^combat%-") then
					if names[name] then fail(scenario, class .. " lists " .. name .. " twice") end
					names[name] = true
				end
			end
			if want[class] and not keys[want[class]] then fail(scenario, class .. " has no " .. want[class]) end
		end
	end
end

local scenario = "combat-actions: every client and class has an off-by-default detected action"
Mock.reset()
local ns = load(scenario)
if ns then
	drive(scenario, ns)
	if not (ns.MOMENTS and ns.MOMENT_SETS and ns.MOMENT_DEFAULTS) then
		fail(scenario, "Manners: Combat did not expose its action catalog")
	else
		for flavour, classes in pairs(ALL) do
			local set = ns.MOMENT_SETS[flavour]
			if not set then
				fail(scenario, flavour .. " has no combat-action set")
			else
				for _, class in ipairs(classes) do
					local rows = set[class]
					if not (rows and #rows > 0) then
						fail(scenario, flavour .. " " .. class .. " has no detected combat action")
					else
						local seen = {}
						local seenRanks = {}
						for _, row in ipairs(rows) do
							local category = row.category
							local valid = category == nil or category == "interrupt" or category == "enemy_dispel"
								or category == "self_heal" or category == "target_heal" or category == "party_heal"
								or category == "self_defense" or category == "enemy_self_heal" or category == "self_resource"
							if not valid then fail(scenario, flavour .. " " .. class .. " has unsupported " .. tostring(category)) end
							if not (row.slot >= 1 and row.slot <= 64) then
								fail(scenario, flavour .. " " .. class .. " " .. row.key .. " uses slot " .. tostring(row.slot))
							end
							for _, need in ipairs(row.needs or {}) do
								if type(ns.Sense[need]) ~= "function" then
									fail(scenario, row.key .. " asks for an unimplemented signal " .. need)
								end
							end
							if ns.MOMENT_DEFAULTS[row.key] ~= false then
								fail(scenario, flavour .. " " .. class .. " " .. row.key .. " is on by default")
							end
							if seen[row.slot] then
								fail(scenario, flavour .. " " .. class .. " uses action slot " .. row.slot .. " twice")
							end
							seen[row.slot] = true
							for _, rank in ipairs(row.ranks or {}) do
								if seenRanks[rank] then
									fail(scenario, flavour .. " " .. class .. " lists spell " .. rank .. " in more than one action")
								end
								seenRanks[rank] = true
							end
						end
					end
				end
			end
		end
		for key, value in pairs(ns.MOMENT_DEFAULTS) do
			if value ~= false and key ~= "health" and key ~= "mana" and key ~= "cardSize" then
				fail(scenario, key .. " has default " .. tostring(value))
			end
		end
		for slot = 1, 64 do
			if ns.Moments:Button(slot) then fail(scenario, "action slot " .. slot .. " was made while everything is off") end
		end
	end
end
Mock.reset()

do
	scenario = "combat-actions: enabling a learned action exposes its option and one secure button"
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "WARRIOR"
	Mock.knownSpells = { [6552] = true }
	Mock.secureActions = true
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Guard("probe combat actions", ns.ProbeCapabilities)
		local key = "combat-interrupt-pummel"
		if not ns.Moments.Has(key) then
			local rows = ns.MOMENTS.WARRIOR or {}
			local listed = {}
			for _, row in ipairs(rows) do listed[#listed + 1] = row.key end
			fail(scenario, "the learned warrior interrupt was not discovered: " .. table.concat(listed, ", "))
		end
		local option = H.findOption(ns.optionsTable, "momentCombat_interrupt_pummel")
		if ns.WindowUI.PageOf("appearance.momentCombat_interrupt_pummel") ~= "combat" then
			fail(scenario, "the generated action is not on the Combat page")
		end
		if ns.WindowUI.PageOf("appearance.combatActionHealth") ~= "combat"
			or ns.WindowUI.PageOf("appearance.combatActionMove") ~= "combat" then
			fail(scenario, "the one combat prompt controls are not on the Combat page")
		end
		if H.findOption(ns.optionsTable, "momentCombat_interrupt_pummelKey") then
			fail(scenario, "the one combat prompt still exposes a per-action key")
		end
		if not option or (option.hidden and option.hidden()) then
			fail(scenario, "the learned Pummel action has no visible option")
		else
			option.set({ "appearance", "momentCombat_interrupt_pummel" }, true)
			Mock.runTimers(0)
			local entry = ns.caps.moments and ns.caps.moments.byKey[key]
			local button = entry and ns.Moments:Button(entry.row.slot)
			if not button then
				local errors = {}
				for _, err in ipairs(ns.errors or {}) do errors[#errors + 1] = tostring(err.where) .. ": " .. tostring(err.err) end
				fail(scenario, "enabling Pummel did not make its secure button (" .. table.concat(errors, " / ") .. ")")
			else
				local macro = button:GetAttribute("macrotext1")
				local name = ns.Moments.NameOf(key)
				if not (type(macro) == "string" and macro:find("/cast " .. tostring(name), 1, true)) then
					fail(scenario, "Pummel button macro is " .. tostring(macro))
				end
				local width, height = ns.Moments.CardSize(ns.db.profile.prompt)
				if ns.db.profile.moments.cardSize ~= 150 or button._width ~= width or button._height ~= height then
					fail(scenario, "the combat prompt did not start at the attention-grabbing 150% size")
				end
				local hit = button._hitRect
				if not button:IsMouseEnabled() or not (hit and hit[1] == 0 and hit[2] == 0
					and hit[3] == 0 and hit[4] == 0) then
					fail(scenario, "the combat prompt did not keep the whole panel clickable")
				end
			end
			local look = H.findOption(ns.optionsTable, "combatActionLook")
			local alert = H.findOption(ns.optionsTable, "combatActionAlert")
			local sound = H.findOption(ns.optionsTable, "combatActionSound")
			if not (look and alert and sound) then
				fail(scenario, "the combat prompt theme and alert controls are missing")
			end
			local dressed = ns.Moments:Slot(ns.caps.moments.byKey[key].row.slot)
			local shot
			if dressed and dressed.card and dressed.card.shot then
				dressed.card.shot.SetTexture = function(_, file) shot = file end
			end
			look.set(nil, "frost")
			if dressed.cardLook ~= "frost" then fail(scenario, "the combat prompt could not use an independent look") end
			if not (type(shot) == "string" and shot:find("\\Card_frost$")) then
				fail(scenario, "the combat prompt wears the gallery's boxed picture, not its cut-out: " .. tostring(shot))
			end
			look.set(nil, "same")
			if dressed.cardLook ~= ns.db.profile.prompt.style then
				fail(scenario, "Same as Manners did not follow the normal prompt look")
			end
			alert.set(nil, "strong")
			sound.set(nil, true)
			if ns.db.profile.moments.alert ~= "strong" or ns.db.profile.moments.alertSound ~= true then
				fail(scenario, "combat alert settings were not kept")
			end
			local strata = {}
			local liftedButton = ns.Moments:Button(ns.caps.moments.byKey[key].row.slot)
			if liftedButton then
				local realStrata = liftedButton.SetFrameStrata
				liftedButton.SetFrameStrata = function(self, s, ...)
					strata[#strata + 1] = s
					if realStrata then return realStrata(self, s, ...) end
				end
			end
			if not ns.Moments.Preview() or not ns.Moments.Anchor():IsMouseEnabled() then
				fail(scenario, "the safe combat prompt preview could not be dragged")
			end
			if strata[#strata] ~= "FULLSCREEN_DIALOG" then
				fail(scenario, "the preview is drawn under the options window: " .. tostring(strata[#strata]))
			end
			local move = H.findOption(ns.optionsTable, "combatActionMove")
			if not move or move.name() ~= "Done moving" then
				fail(scenario, "the move button does not offer Done moving while the preview is up")
			end
			Mock.runTimers(10)
			if not ns.Moments.Previewing() then
				fail(scenario, "the preview closed on its own before the player finished moving it")
			end
			look.set(nil, "frost")
			if not ns.Moments.Previewing() then
				fail(scenario, "changing the look closed the preview instead of showing the change")
			end
			move.func()
			if ns.Moments.Previewing() or move.name() ~= "Show and move the combat prompt" then
				fail(scenario, "Done moving did not end the preview")
			end
			if strata[#strata] ~= "MEDIUM" then
				fail(scenario, "the prompt stayed over every window after the preview: " .. tostring(strata[#strata]))
			end
			look.set(nil, "same")
			if not ns.Moments.Previewing() then
				fail(scenario, "changing the look did not show the combat prompt to see the change")
			end
			ns.Moments.Preview()
			local anchorFrame = ns.Moments.Anchor()
			local up = anchorFrame:GetScript("OnMouseUp")
			if up then up(anchorFrame, "RightButton") end
			if ns.Moments.Previewing() then
				fail(scenario, "a right-click on the preview did not finish it")
			end
			local allOff = H.findOption(ns.optionsTable, "combatActionAllOff")
			local status = H.findOption(ns.optionsTable, "combatActionStatus")
			if not (allOff and status) then
				fail(scenario, "the Combat page has no status line or Turn all off")
			elseif not status.name():find("1 of 1", 1, true) then
				fail(scenario, "the status line does not count what is on: " .. tostring(status.name()))
			end
			local reset = ns.OptionsPage.RESET.combat
			local listed = {}
			for _, path in ipairs(reset or {}) do listed[path] = true end
			if not (listed["moments." .. key] and listed["moments.look"]) or listed["moments.promptX"] then
				fail(scenario, "Reset this page on Combat does not put back the actions and look, or moves the prompt")
			end
			local pages = ns.WindowLayout and ns.WindowLayout.pages or {}
			local function onPage(page, path)
				for _, section in ipairs(page and page.sections or {}) do
					for _, item in ipairs(section.items or {}) do
						if item == path or (type(item) == "table" and item[1] == path) then return true end
					end
				end
			end
			for _, path in ipairs({ "appearance.fightRota", "appearance.breakFree" }) do
				if onPage(pages.fight, path) or not onPage(pages.combat, path) then
					fail(scenario, path .. " is not on the Combat page alone")
				end
			end
			ns.db.profile.moments[key] = false
			ns.Moments:Refresh()
			if ns.Moments.Previewing() or ns.Moments.Anchor():IsMouseEnabled() then
				fail(scenario, "turning off the last action left the drag frame over the prompt")
			end
			local shield = H.findOption(ns.optionsTable, "momentCombat_interrupt_shield_bash")
			if shield and not shield.hidden() then fail(scenario, "an unlearned Shield Bash is shown in the menu") end
		end
	end
	Mock.reset()
end

do
	scenario = "combat-actions: a generated interrupt uses a plain target-cast signal without secure writes"
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "WARRIOR"
	Mock.knownSpells = { [6552] = true }
	Mock.secureActions = true
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local savedAttack, savedCast, savedChannel, savedSound =
			rawget(_G, "UnitCanAttack"), rawget(_G, "UnitCastingInfo"), rawget(_G, "UnitChannelInfo"),
			rawget(_G, "PlaySound")
		local ok, err = pcall(function()
			ns.Guard("probe combat actions", ns.ProbeCapabilities)
			local key = "combat-interrupt-pummel"
			local entry = ns.caps.moments and ns.caps.moments.byKey[key]
			if not entry then fail(scenario, "Pummel was not learned") return end
			ns.db.profile.moments[key] = true
			ns.db.profile.moments.alert, ns.db.profile.moments.alertSound = "strong", true
			ns.Guard("combat action", ns.Moments.Refresh, ns.Moments)
			local button = ns.Moments:Button(entry.row.slot)
			if not button then fail(scenario, "Pummel made no button") return end
			local slotBefore = ns.Moments:Slot(entry.row.slot)
			slotBefore.inner.SetAlphaFromBoolean = function(self, value, off, on)
				self._hiddenAlpha = (value == Mock.SECRET and off) or on
				return self
			end
			ns.Sense.Probe(slotBefore.inner)
			Mock.protect(button)
			Mock.protectedCalls = {}
			Mock.eventSink = ns.addon
			local casting, sounds = false, 0
			rawset(_G, "PlaySound", function() sounds = sounds + 1 end)
			rawset(_G, "UnitCanAttack", function() return true end)
			rawset(_G, "UnitCastingInfo", function()
				if casting then return "Dangerous Cast", "", 0, 0, 2000, false, nil, Mock.SECRET end
			end)
			rawset(_G, "UnitChannelInfo", function() return nil end)
			Mock.inCombat = false
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.inCombat = true
			Mock.frameEvent("PLAYER_REGEN_DISABLED")
			Mock.advance(0.2)
			Mock.runTimers(0)
			Mock.timers = {}
			local units = ns.Moments:Frame().unitEvents["UNIT_SPELLCAST_START"]
			if not (units and units[1] == "target") then
				fail(scenario, "Pummel did not register target-cast events for target")
			end
			casting = true
			local heard = Mock.deliver(ns.Moments:Frame(), "UNIT_SPELLCAST_START", "target")
			if not heard then fail(scenario, "the Pummel action did not register the target cast event") end
			Mock.advance(0.2)
			local slot = ns.Moments:Slot(entry.row.slot)
			if not slot or slot.state ~= "lit" then
				fail(scenario, "Pummel did not light for a target cast with secret interruptibility: " .. tostring(slot and slot.why))
			end
			if slot.cover:IsShown() or not button:IsMouseEnabled() then
				fail(scenario, "the interrupt still needed a first reveal click instead of casting at once")
			end
			if slot.pulseLevel ~= "strong" then fail(scenario, "the selected combat alert level did not reach the card") end
			if sounds ~= 1 then
				fail(scenario, "a newly selected combat need did not play exactly one alert sound")
			end
			if #Mock.protectedCalls > 0 then
				fail(scenario, "combat changed protected attributes: " .. table.concat(Mock.protectedCalls, ", "))
			end
			Mock.inCombat = false
			ns.addon:PLAYER_REGEN_ENABLED()
		end)
		Mock.inCombat = false
		rawset(_G, "UnitCanAttack", savedAttack)
		rawset(_G, "UnitCastingInfo", savedCast)
		rawset(_G, "UnitChannelInfo", savedChannel)
		rawset(_G, "PlaySound", savedSound)
		Mock.reset()
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end

do
	scenario = "combat-actions: generated friend, group, resource and own-aura signals read plain state"
	Mock.reset()
	Mock.class = "PRIEST"
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local saved, names = {}, { "UnitExists", "UnitCanAssist", "UnitIsDeadOrGhost", "UnitHealth", "UnitHealthMax",
			"UnitPower", "UnitPowerMax", "UnitPowerType", "UnitPowerPercent", "GetNumGroupMembers", "IsInRaid",
			"UnitGUID", "C_UnitAuras" }
		for _, name in ipairs(names) do
			saved[name] = rawget(_G, name)
		end
		local ok, err = pcall(function()
			rawset(_G, "UnitExists", function() return true end)
			rawset(_G, "UnitCanAssist", function() return true end)
			rawset(_G, "UnitIsDeadOrGhost", function() return false end)
			rawset(_G, "UnitHealth", function(unit) return unit == "party1" and 5 or 100 end)
			rawset(_G, "UnitHealthMax", function() return 100 end)
			rawset(_G, "UnitPower", function() return 10 end)
			rawset(_G, "UnitPowerMax", function() return 100 end)
			rawset(_G, "UnitPowerType", function() return 0 end)
			rawset(_G, "UnitPowerPercent", nil)
			rawset(_G, "GetNumGroupMembers", function() return 2 end)
			rawset(_G, "IsInRaid", function() return false end)
			rawset(_G, "UnitGUID", function(unit) return "Player-" .. unit end)
			local aura = nil
			rawset(_G, "C_UnitAuras", { GetUnitAuraBySpellID = function() return aura end })
			local slot = { row = { ranks = { 17 } } }
			if ns.Sense.friendly(slot) ~= "yes" then fail(scenario, "a friendly target was not accepted") end
			if ns.Sense.friendlowhealth(slot) ~= "no" then fail(scenario, "a healthy friendly target was called low") end
			if ns.Sense.partylowhealth(slot) ~= "yes" then fail(scenario, "a low-health group member was missed") end
			if ns.Sense.lowpower(slot) ~= "yes" then fail(scenario, "low primary resource was missed") end
			if ns.Sense.missingown(slot) ~= "yes" then fail(scenario, "a missing own protection was missed") end
			aura = { spellId = 17 }
			if ns.Sense.missingown(slot) ~= "no" then fail(scenario, "an active own protection was called missing") end
			rawset(_G, "C_UnitAuras", {
				GetUnitAuraBySpellID = function() error("aura read refused") end,
			})
			if ns.Sense.missingown(slot) ~= "blind" then
				fail(scenario, "a refused own-aura read was treated as no protection")
			end
		end)
		for _, name in ipairs(names) do rawset(_G, name, saved[name]) end
		Mock.reset()
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end

do
	scenario = "combat-actions: simultaneous needs use one prompt and one secure click target"
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "WARRIOR"
	Mock.knownSpells = { [6552] = true, [72] = true }
	Mock.secureActions = true
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local savedAttack, savedCast, savedChannel =
			rawget(_G, "UnitCanAttack"), rawget(_G, "UnitCastingInfo"), rawget(_G, "UnitChannelInfo")
		local ok, err = pcall(function()
			ns.Guard("probe combat actions", ns.ProbeCapabilities)
			local pummel = ns.caps.moments and ns.caps.moments.byKey["combat-interrupt-pummel"]
			local bash = ns.caps.moments and ns.caps.moments.byKey["combat-interrupt-shield-bash"]
			if not (pummel and bash) then fail(scenario, "both warrior interrupts were not learned") return end
			ns.db.profile.moments[pummel.row.key] = true
			ns.db.profile.moments[bash.row.key] = true
			ns.Moments:Refresh()
			local first, second = ns.Moments:Button(pummel.row.slot), ns.Moments:Button(bash.row.slot)
			local firstSlot, secondSlot = ns.Moments:Slot(pummel.row.slot), ns.Moments:Slot(bash.row.slot)
			Mock.protect(first)
			Mock.protect(second)
			Mock.protectedCalls = {}
			Mock.eventSink = ns.addon
			local casting = true
			rawset(_G, "UnitCanAttack", function() return true end)
			rawset(_G, "UnitCastingInfo", function()
				if casting then return "Dangerous Cast", "", 0, 0, 2000, false, nil, false end
			end)
			rawset(_G, "UnitChannelInfo", function() return nil end)
			Mock.inCombat = false
			ns.addon:PLAYER_REGEN_DISABLED()
			Mock.inCombat = true
			Mock.frameEvent("PLAYER_REGEN_DISABLED")
			Mock.advance(0.2)
			Mock.runTimers(0)
			local chosen = ns.Moments.selected
			if not chosen or chosen.row.key ~= pummel.row.key then
				fail(scenario, "the priority action was not the one combat prompt")
			end
			if first:GetFrameLevel() ~= 500 or second:GetFrameLevel() ~= 0 then
				fail(scenario, "the combat prompt did not route one secure slot to the top")
			end
			local pummelPoint, bashPoint = first.points[1], second.points[1]
			if not (pummelPoint and bashPoint and pummelPoint[2] == ns.Moments.Anchor()
				and bashPoint[2] == ns.Moments.Anchor()) then
				fail(scenario, "secure combat slots were not placed on one shared prompt")
			end
			if #Mock.protectedCalls > 0 then
				fail(scenario, "routing changed a protected action in combat: " .. table.concat(Mock.protectedCalls, ", "))
			end
			casting = false
			if not Mock.deliver(ns.Moments:Frame(), "UNIT_SPELLCAST_STOP", "target") then
				fail(scenario, "the stop event was no longer registered on the target")
			end
			Mock.advance(0.2)
			Mock.runTimers(0)
			if ns.Moments.selected or first:GetFrameLevel() ~= 0 or firstSlot.face:GetAlpha() ~= 0
				or secondSlot.face:GetAlpha() ~= 0 then
				fail(scenario, ("the combat prompt stayed visible without a detected need: selected %s, levels %s/%s, alpha %s/%s")
					:format(tostring(ns.Moments.selected and ns.Moments.selected.row.key) .. " state "
						.. tostring(firstSlot.state) .. "/" .. tostring(secondSlot.state),
						tostring(first:GetFrameLevel()), tostring(second:GetFrameLevel()),
						tostring(firstSlot.face:GetAlpha()), tostring(secondSlot.face:GetAlpha())))
			end
			Mock.inCombat = false
			ns.addon:PLAYER_REGEN_ENABLED()
		end)
		Mock.inCombat = false
		rawset(_G, "UnitCanAttack", savedAttack)
		rawset(_G, "UnitCastingInfo", savedCast)
		rawset(_G, "UnitChannelInfo", savedChannel)
		Mock.reset()
		if not ok then fail(scenario, "threw: " .. tostring(err)) end
	end
	Mock.reset()
end

do
	scenario = "combat-actions: suspending and restoring Combat restores the pull listener"
	Mock.reset()
	Mock.class = "WARRIOR"
	Mock.knownSpells = { [6552] = true }
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Guard("probe combat actions", ns.ProbeCapabilities)
		ns.db.profile.moments["combat-interrupt-pummel"] = true
		ns.Moments:Refresh()
		MannersAPI:SetModuleEnabled("combat", false)
		MannersAPI:SetModuleEnabled("combat", true)
		local events = ns.Moments:Frame() and ns.Moments:Frame().events
		if not (events and events.PLAYER_REGEN_DISABLED) then
			fail(scenario, "the combat action frame did not regain PLAYER_REGEN_DISABLED")
		end
	end
	Mock.reset()
end

do
	scenario = "combat-actions: generated categories keep dangerous and pet-owned spells correct"
	Mock.reset()
	Mock.setFlavour("mists")
	Mock.class = "WARLOCK"
	Mock.knownSpells = {}
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local life
		for _, row in ipairs(ns.MOMENT_SETS.mists.WARLOCK or {}) do
			if row.key == "combat-self_resource-life-tap" then life = row end
			if row.key == "combat-self_defense-life-tap" then fail(scenario, "Life Tap became a low-health defense") end
		end
		if not life or not table.concat(life.needs, ","):find("healthabove", 1, true) then
			fail(scenario, "Life Tap has no health guard")
		end
		local book = rawget(_G, "C_SpellBook")
		rawset(_G, "C_SpellBook", {
			IsSpellKnown = function(id, bank) return id == 132409 and bank == 1 end,
			IsSpellInSpellBook = function(id, bank) return id == 132409 and bank == 1 end,
		})
		ns.Guard("probe pet combat actions", ns.ProbeCapabilities)
		rawset(_G, "C_SpellBook", book)
		if not ns.Moments.Has("combat-interrupt-spell-lock") then
			fail(scenario, "Spell Lock was not learned from the pet spellbook")
		else
			local entry = ns.caps.moments.byKey["combat-interrupt-spell-lock"]
			ns.db.profile.moments[entry.row.key] = true
			ns.Moments:Refresh()
			local units = ns.Moments:Frame().unitEvents["UNIT_SPELLCAST_SUCCEEDED"]
			local player, pet = false, false
			for _, unit in ipairs(units or {}) do
				player = player or unit == "player"
				pet = pet or unit == "pet"
			end
			if not (player and pet) then fail(scenario, "pet successful casts are not registered") end
			local now = GetTime()
			Mock.deliver(ns.Moments:Frame(), "UNIT_SPELLCAST_SUCCEEDED", "pet", "cast-guid", entry.id)
			if (ns.Moments:Slot(entry.row.slot).readyAt or 0) <= now then
				fail(scenario, "a pet cast did not start Spell Lock's own cooldown")
			end
		end
		local hunter
		for _, row in ipairs(ns.MOMENT_SETS.mainline.HUNTER or {}) do
			if row.key == "combat-self_heal-exhilaration" then
				hunter = row.ranks[1] == 109304
			end
		end
		if not hunter then fail(scenario, "the learned Exhilaration self-heal rank was merged into another trigger") end
		for _, row in ipairs(ns.MOMENT_SETS.mainline.WARLOCK or {}) do
			for _, rank in ipairs(row.ranks or {}) do
				if rank == 1233448 then
					fail(scenario, "a pet-targeted resource spell was made into a self cast")
				end
			end
		end
		local dawn
		for _, row in ipairs(ns.MOMENT_SETS.mists.PALADIN or {}) do
			if row.ranks[1] == 85222 then dawn = row end
		end
		if not dawn or dawn.partyOnly == true then
			fail(scenario, "Light of Dawn was incorrectly restricted to one raid subgroup")
		end
	end
	Mock.reset()
end

do
	scenario = "combat-actions: one click casts where only the game knows; a dark card swallows it"
	Mock.reset()
	Mock.class = "WARRIOR"
	Mock.knownSpells = { [6552] = true, [2565] = true }
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Guard("probe combat actions", ns.ProbeCapabilities)
		local defense = ns.caps.moments and ns.caps.moments.byKey["combat-self_defense-shield-block"]
		if not defense then fail(scenario, "the action was not learned") return end
		ns.db.profile.moments[defense.row.key] = true
		ns.Moments:Refresh()
		local slot = ns.Moments:Slot(defense.row.slot)
		ns.Sense.fighting = true
		slot.state, slot.mouseOn = "game", true
		ns.Moments.Route()
		if ns.Moments.CoverWanted(slot) or slot.cover:IsShown() then
			fail(scenario, "a cover stands over a card the game shows, so a click does nothing")
		end
		slot.state = "dark"
		if not ns.Moments.CoverWanted(slot) then
			fail(scenario, "no cover over a dark card, so a click there would cast")
		end
		local interrupt = ns.caps.moments.byKey["combat-interrupt-pummel"]
		if interrupt then
			ns.db.profile.moments[interrupt.row.key] = true
			ns.Moments:Refresh()
			local urgent = ns.Moments:Slot(interrupt.row.slot)
			slot.state, urgent.state = "lit", "lit"
			ns.Moments.Route()
			if ns.Moments.selected ~= urgent then
				fail(scenario, "with two actions lit, the less urgent one took the prompt")
			end
		else
			fail(scenario, "Pummel was not learned")
		end
		ns.Sense.fighting = false
	end
	Mock.reset()
end

do
	scenario = "combat-actions: a party heal does not light for another raid subgroup"
	Mock.reset()
	Mock.class = "PRIEST"
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		local saved = {}
		for _, name in ipairs({ "IsInRaid", "GetNumGroupMembers", "GetRaidRosterInfo", "UnitIsUnit",
			"UnitExists", "UnitIsDeadOrGhost", "UnitHealth", "UnitHealthMax", "UnitGUID" }) do
			saved[name] = rawget(_G, name)
		end
		rawset(_G, "IsInRaid", function() return true end)
		rawset(_G, "GetNumGroupMembers", function() return 6 end)
		rawset(_G, "GetRaidRosterInfo", function(index)
			return "Raider " .. index, "CLASS", index == 6 and 2 or 1
		end)
		rawset(_G, "UnitIsUnit", function(unit) return unit == "raid1" or unit == "player" end)
		rawset(_G, "UnitExists", function() return true end)
		rawset(_G, "UnitIsDeadOrGhost", function() return false end)
		rawset(_G, "UnitHealth", function(unit) return unit == "raid6" and 5 or 100 end)
		rawset(_G, "UnitHealthMax", function() return 100 end)
		rawset(_G, "UnitGUID", function(unit) return "guid-" .. unit end)
		local partyOnly = { row = { partyOnly = true } }
		local anyGroup = { row = {} }
		if ns.Sense.partylowhealth(partyOnly) ~= "no" then
			fail(scenario, "another raid subgroup lit a party-only heal")
		end
		if ns.Sense.partylowhealth(anyGroup) ~= "yes" then
			fail(scenario, "raid-wide fallback no longer reaches a low raid member")
		end
		for name, value in pairs(saved) do rawset(_G, name, value) end
	end
	Mock.reset()
end

do
	scenario = "combat-actions: moving the prompt puts the settings away and brings them back"
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "WARRIOR"
	Mock.knownSpells = { [6552] = true }
	Mock.secureActions = true
	ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Guard("probe combat actions", ns.ProbeCapabilities)
		local key = "combat-interrupt-pummel"
		ns.db.profile.moments[key] = true
		ns.Moments:Refresh()
		ns.OpenOptions("combat")
		local move = H.findOption(ns.optionsTable, "combatActionMove")
		if not (move and ns.OptionsOpen()) then
			fail(scenario, "SKIPPED -- no move button or no settings window")
		else
			move.func()
			local bar = ns.Moments.Mover()
			if not ns.Moments.Previewing() then fail(scenario, "the move did not show the prompt") end
			if ns.OptionsOpen() then fail(scenario, "the settings stayed open over the prompt being moved") end
			if not (bar and bar:IsShown()) then fail(scenario, "no bar says how to move the prompt and finish") end
			if bar and bar.done then bar.done:GetScript("OnClick")(bar.done) end
			if ns.Moments.Previewing() then fail(scenario, "Done on the bar did not finish the move") end
			if not ns.OptionsOpen() or ns.OptionsTab() ~= "combat" then
				fail(scenario, "the settings did not come back on the Combat page: " .. tostring(ns.OptionsTab()))
			end
			-- Trying a look from the gallery shows it on the combat prompt, without the bar.
			local same = H.findOption(ns.optionsTable, "combatActionLookSame")
			local look = H.findOption(ns.optionsTable, "combatActionLook")
			if not (same and look and type(look.tryLook) == "function") then
				fail(scenario, "the combat look has no gallery to try looks from")
			else
				same.set(nil, false)
				look.tryLook("frost")
				local slot = ns.Moments:Slot(ns.caps.moments.byKey[key].row.slot)
				if not (ns.Moments.Previewing() and slot and slot.cardLook == "frost") then
					fail(scenario, "a look under the pointer was not shown on the combat prompt")
				end
				if bar and bar:IsShown() then fail(scenario, "trying a look showed the move bar") end
				if ns.db.profile.moments.look == "frost" then fail(scenario, "a look only tried was kept") end
				look.tryLook(nil)
				if slot and slot.cardLook == "frost" then fail(scenario, "the tried look stayed after the pointer left") end
				same.set(nil, true)
				if ns.db.profile.moments.look ~= "same" or not look.hidden() then
					fail(scenario, "Wear the Manners prompt's look did not take the gallery's place")
				end
			end
		end
	end
	Mock.reset()
end

do
	-- A switch that names a spell wears its icon in the window, between the box
	-- and the name, so the name moves right to make room.
	local scenario = "combat-actions: a combat action's switch wears its spell's icon"
	Mock.reset()
	Mock.class = "WARRIOR"
	Mock.knownSpells = { [6552] = true, [2565] = true }
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Guard("probe combat actions", ns.ProbeCapabilities)
		local entry = ns.caps.moments and ns.caps.moments.byKey["combat-interrupt-pummel"]
		if not entry then fail(scenario, "Pummel was not learned") Mock.reset() return end
		local ctx = { changes = {}, holds = {}, pages = {}, relayouts = 0 }
		ctx.Window = CreateFrame("Frame", "MannersOptionsIconTest", UIParent)
		ctx.Window:SetSize(820, 600)
		ctx.OnChange = function() end
		ctx.OnHold = function() end
		ctx.ScrollPage = function() end
		ctx.Relayout = function(row) row:Layout(row.width) end
		local suffix = entry.row.key:sub(1, 1):upper() .. entry.row.key:sub(2)
		local item = ns.WindowBind.Item("appearance.moment" .. suffix:gsub("[^%w_]", "_"), {}, ctx)
		if not item then fail(scenario, "the model has no switch for Pummel") Mock.reset() return end
		local row = ns.WindowWidgets.Build("toggle", ctx.Window, item)
		row:Refresh()
		row:Layout(560)
		local want = ns.Moments.IconOf(entry.row.key)
		if want == nil then fail(scenario, "Pummel has no icon to wear") end
		if not row.icon:IsShown() or ns.WindowWidgets.Image(row) ~= want then
			fail(scenario, "the switch shows no Pummel icon: " .. tostring(ns.WindowWidgets.Image(row)))
		end
		local point = row.label.points and row.label.points[#row.label.points]
		local x = point and point[4]
		if not (x and x > 25 + 17) then fail(scenario, "the name sits over the icon (x=" .. tostring(x) .. ")") end
	end
	Mock.reset()
end
