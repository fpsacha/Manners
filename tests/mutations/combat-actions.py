# Every detected combat action starts off, including Counterspell.

S = "runscenarios.py"
N = "combat-actions: "

mutate("Modules/Combat/MomentsData.lua",
       "ns.MOMENT_DEFAULTS = { counterspell = false,",
       "ns.MOMENT_DEFAULTS = { counterspell = true,",
       "combat actions: Counterspell is on by default",
       expect=N + "every client and class has an off-by-default detected action", script=S)

mutate("Modules/Combat/Options.lua",
       "hidden = function() return Off() or not ns.Moments.Has(row.key) end,",
       "hidden = function() return Off() end,",
       "combat actions: unlearned spells are shown in the menu",
       expect=N + "enabling a learned action exposes its option and one secure button", script=S)

mutate("Modules/Combat/MomentsCard.lua",
       "local file, at, textAt = CardFile(key), Looks.PreviewIcon(key), Looks.PreviewText(key)",
       "local file, at, textAt = Looks.PreviewFile(key), Looks.PreviewIcon(key), Looks.PreviewText(key)",
       "combat actions: the combat prompt wears the gallery's boxed picture",
       expect="the combat prompt wears the gallery's boxed picture", script=S)

mutate("Modules/Combat/Moments.lua",
       "local PREVIEW_SECONDS = 120",
       "local PREVIEW_SECONDS = 5",
       "combat actions: the move preview closes before the player is done",
       expect="the preview closed on its own before the player finished moving it", script=S)

mutate("Modules/Combat/Moments.lua",
       "\tMoments.Preview(true)",
       "\tlocal _ = true",
       "combat actions: changing the look does not show the prompt",
       expect="changing the look did not show the combat prompt to see the change", script=S)

mutate("Modules/Combat/Moments.lua",
       "function Moments.TogglePreview()",
       "function Moments.TogglePreview() do return Moments.Preview() end",
       "combat actions: Done moving shows the preview again instead of ending it",
       expect="Done moving did not end the preview", script=S)

mutate("Modules/Combat/Moments.lua",
       'if button == "RightButton" and previewing and Moments.EndPreview then',
       'if button == "MiddleButton" and previewing and Moments.EndPreview then',
       "combat actions: a right-click does not finish the move preview",
       expect="a right-click on the preview did not finish it", script=S)

mutate("Modules/Combat/Options.lua",
       "if switches[row.key] == true then on = on + 1 end",
       "if switches[row.key] == true then on = on end",
       "combat actions: the Combat page's status does not count what is on",
       expect="the status line does not count what is on", script=S)

mutate("Modules/Combat/Options.lua",
       '"moments.alert", "moments.alertSound",',
       '"moments.alert", "moments.alertSound", "moments.promptX",',
       "combat actions: Reset this page on Combat moves the prompt",
       expect="Reset this page on Combat does not put back the actions and look, or moves the prompt", script=S)

mutate("Modules/Combat/MomentsSense.lua",
       'local rawName, _, _, _, _, _, _, rawNotInt = UnitCastingInfo("target")',
       "local rawName, rawNotInt = nil, nil",
       "combat actions: an interruptible target cast is ignored",
       expect=N + "a generated interrupt uses a plain target-cast signal without secure writes", script=S)

mutate("Modules/Combat/Moments.lua",
       "Moments.selected, Moments.yielded = best, yielded",
       "Moments.selected, Moments.yielded = nil, yielded",
       "combat actions: the routed combat action is not exposed to one prompt",
       expect=N + "simultaneous needs use one prompt and one secure click target", script=S)

mutate("Modules/Combat/Moments.lua",
       'ev:RegisterEvent("PLAYER_REGEN_DISABLED")',
       'ev:UnregisterEvent("PLAYER_REGEN_DISABLED")',
       "combat actions: restoring Combat leaves the pull listener off",
       expect=N + "suspending and restoring Combat restores the pull listener", script=S)

mutate("Modules/Combat/ActionsData.lua",
       'needs = {"fight", "ready", "usable", "lowpower", "healthabove"}',
       'needs = {"fight", "ready", "usable", "lowpower"}',
       "combat actions: Life Tap is usable while health is dangerously low",
       expect=N + "generated categories keep dangerous and pet-owned spells correct", script=S)

mutate("Modules/Combat/MomentsSense.lua",
       'if not ok then return "blind", "your auras" end',
       'if not ok then aura = nil end',
       "combat actions: a refused aura read claims a protection is missing",
       expect=N + "generated friend, group, resource and own-aura signals read plain state", script=S)

mutate("Modules/Services/Courtesy.lua",
       "local function PlanItem(row, level)",
       "local function PlanItem(row, level)\n\treturn nil\nend\nlocal function OldPlanItem(row, level)",
       "services: the prompt uses a conjure spell icon instead of bread or water",
       expect="courtesy: water asked for is conjured, then traded, and the trade is never accepted",
       script=S)

mutate("Modules/Combat/Moments.lua",
       "\t\t\tif not best or Priority(slot) < Priority(best)",
       "\t\t\tif not best or Priority(slot) > Priority(best)",
       "combat actions: the least urgent action takes the prompt",
       expect=N, script=S)

mutate("Modules/Combat/ActionsData.lua",
       '{ key = "combat-interrupt-call-felhunter", category = "interrupt", ranks = {212619}',
       '{ key = "combat-self_resource-dark-transformation", category = "self_resource", ranks = {1233448}, needs = {"fight", "ready", "usable", "lowpower"}, cooldown = 30, fast = true, guard = "twice", self = true, stop = true },\n\t\t\t{ key = "combat-interrupt-call-felhunter", category = "interrupt", ranks = {212619}',
       "combat actions: a pet-targeted resource cast is made self-targeted",
       expect=N + "generated categories keep dangerous and pet-owned spells correct", script=S)

mutate("Modules/Combat/Moments.lua",
       'ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")',
       'ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")',
       "combat actions: a pet cast never starts its cooldown clock",
       expect=N + "generated categories keep dangerous and pet-owned spells correct", script=S)

mutate("Modules/Combat/ActionsData.lua",
       '{ key = "combat-party_heal-light-of-dawn", category = "party_heal", ranks = {85222}, needs = {"fight", "ready", "usable", "partylowhealth"}, cooldown = 0, fast = true, guard = "twice", stop = true }',
       '{ key = "combat-party_heal-light-of-dawn", category = "party_heal", ranks = {85222}, needs = {"fight", "ready", "usable", "partylowhealth"}, cooldown = 0, fast = true, guard = "twice", partyOnly = true, stop = true }',
       "combat actions: a raid-wide heal is limited to the player's subgroup",
       expect=N + "generated categories keep dangerous and pet-owned spells correct", script=S)

mutate("Modules/Combat/MomentsSense.lua",
       'if slot.row.category == "interrupt" or slot.row.key == "counterspell" then',
       'if false and (slot.row.category == "interrupt" or slot.row.key == "counterspell") then',
       "combat actions: a secret interruptibility read inserts a reveal click delay",
       expect=N + "a generated interrupt uses a plain target-cast signal without secure writes", script=S)

mutate("Modules/Combat/MomentsCard.lua",
       "button:SetHitRectInsets(0, 0, 0, 0)",
       "button:SetHitRectInsets(0, w, 0, h)",
       "combat actions: only the spell icon of the prompt is clickable",
       expect=N + "enabling a learned action exposes its option and one secure button", script=S)

mutate("Modules/Combat/Moments.lua",
       "if look ~= nil and look ~= \"same\" and ns.Looks and ns.Looks.Allowed()[look] then return look end",
       "if look ~= nil and look ~= \"same\" and ns.Looks and ns.Looks.Allowed()[look] then return p.style or \"glass\" end",
       "combat actions: the battle prompt cannot use an independent look",
       expect=N + "enabling a learned action exposes its option and one secure button", script=S)

mutate("Modules/Combat/MomentsCard.lua",
       'slot.pulseLevel = level',
       'slot.pulseLevel = "pulse"',
       "combat actions: Strong pulse is ignored by the alert animation",
       expect=N + "a generated interrupt uses a plain target-cast signal without secure writes", script=S)

mutate("Modules/Combat/Moments.lua",
       "previewing, moving = false, false",
       "previewing, moving = true, false",
       "combat actions: ending a preview leaves its drag frame over the prompt",
       expect="turning off the last action left the drag frame over the prompt", script=S)

mutate("Modules/Services/Courtesy.lua",
       'local cache = key .. "\\0" .. tostring(item or 0)',
       'local cache = key',
       "services: different recipients share and overwrite one service item icon",
       expect="courtesy: mists: one refreshment spell keeps each recipient's item icon",
       script=S)

mutate("Modules/Combat/Moments.lua",
       "\t\t\t\tslot.button:SetFrameStrata(PREVIEW_STRATA)",
       "\t\t\t\tlocal _ = PREVIEW_STRATA",
       "combat actions: the preview is drawn under the options window",
       expect="the preview is drawn under the options window", script=S)

mutate("Modules/Combat/Moments.lua",
       "\t\tif slot and not InCombatLockdown() then slot.button:SetFrameStrata(\"MEDIUM\") end",
       "",
       "combat actions: the prompt stays over every window after the preview",
       expect="the prompt stayed over every window after the preview", script=S)
mutate("Modules/Combat/Moments.lua",
       "\t\t\tif ns.CloseOptions then ns.Guard(\"options close\", ns.CloseOptions) end",
       "",
       "combat actions: the settings stay open over the prompt being moved",
       expect="the settings stayed open over the prompt being moved", script=S)

mutate("Modules/Combat/Moments.lua",
       "\t\tns.Guard(\"options reopen\", ns.OpenOptions, \"combat\")",
       "",
       "combat actions: the settings never come back after a move",
       expect="the settings did not come back on the Combat page", script=S)

mutate("Modules/Combat/Moments.lua",
       "\tif tried and ns.Looks and ns.Looks.Allowed()[tried] then return tried end",
       "",
       "combat actions: a look under the pointer is not shown on the combat prompt",
       expect="a look under the pointer was not shown on the combat prompt", script=S)

mutate("Modules/Combat/Moments.lua",
       "\tanchorLabel:SetShown(previewing == true and moving == true)",
       "\tanchorLabel:SetShown(previewing == true)",
       "combat actions: trying a look shows the move bar",
       expect="trying a look showed the move bar", script=S)
mutate("Modules/Combat/Options.lua",
       "hidden = function() return Off() or SameLook() end,",
       "hidden = Off,",
       "combat actions: the look gallery shows while the Manners look is worn",
       expect="Wear the Manners prompt's look did not take the gallery's place", script=S)

mutate("Modules/Combat/Options.lua",
       'if section.key == "fight.prompt" or section.key == "fight.buttons" then',
       'if section.key == "fight.buttons" then',
       "combat actions: the fight's rota stays alone on In a fight",
       expect="appearance.fightRota is not on the Combat page alone", script=S)
mutate("Modules/Combat/ActionsData.lua",
       '{ key = "combat-self_defense-shield-wall",',
       '{ key = "combat-self_defense-shield-wall-gone",',
       "combat actions: Forever's warrior loses Shield Wall",
       expect="WARRIOR has no combat-self_defense-shield-wall", script=S)

mutate("Modules/Combat/Moments.lua",
       "\treturn slot.state == \"dark\" or slot.routed ~= true\nend\nMoments.CoverWanted = CoverWanted",
       "\treturn slot.state ~= \"lit\" or slot.routed ~= true\nend\nMoments.CoverWanted = CoverWanted",
       "combat actions: a card the game shows keeps its cover, so a click does nothing",
       expect=N + "one click casts where only the game knows; a dark card swallows it", script=S)

mutate("Modules/Combat/Moments.lua",
       "\treturn slot.state == \"dark\" or slot.routed ~= true\nend\nMoments.CoverWanted = CoverWanted",
       "\treturn slot.routed ~= true\nend\nMoments.CoverWanted = CoverWanted",
       "combat actions: a dark card has no cover, so a click casts anyway",
       expect=N + "one click casts where only the game knows; a dark card swallows it", script=S)

mutate("Modules/Combat/Options.lua",
       "\t\t\t\timage = function() return ns.Moments.IconOf(row.key) end,\n",
       "",
       "combat actions: a combat action's switch has no spell icon",
       expect=N + "a combat action's switch wears its spell's icon", script=S)

mutate("Options/Window/Widgets.lua",
       "\t\trow.icon:SetShown(image ~= nil)",
       "\t\trow.icon:SetShown(false)",
       "options window: a switch's spell icon is never shown",
       expect=N + "a combat action's switch wears its spell's icon", script=S)

mutate("Options/Window/Widgets.lua",
       "\t\tlocal x = image and 25 + ICON_SIZE + ICON_GAP or 25",
       "\t\tlocal x = 25",
       "options window: a switch's name is drawn over its spell icon",
       expect=N + "a combat action's switch wears its spell's icon", script=S)

mutate("Modules/Combat/Moments.lua",
       "\tif not busy then return false end\n\tif Sense.fighting",
       "\tdo return false end\n\tif Sense.fighting",
       "combat actions: a card only the game sees takes the buff prompt's click",
       expect=N + "the buff prompt keeps its clicks over a card only the game sees", script=S)
mutate("Modules/Combat/Moments.lua",
       "\tif Sense.fighting and slot.state ~= \"game\" then return false end",
       "\tif false then return false end",
       "combat actions: a needed card in a fight gives way to the buff prompt",
       expect=N + "the buff prompt keeps its clicks over a card only the game sees", script=S)
mutate("Modules/Combat/Moments.lua",
       "\treturn slot.state == \"dark\" or slot.routed ~= true",
       "\treturn slot.state == \"dark\"",
       "combat actions: a card under the buff prompt casts from a click round its edge",
       expect=N + "the buff prompt keeps its clicks over a card only the game sees", script=S)
mutate("Modules/Combat/Moments.lua",
       "\treturn al < br and bl < ar and ab < bt and bb < at",
       "\treturn true",
       "combat actions: a combat prompt moved off Manners still gives way",
       expect=N + "the buff prompt keeps its clicks over a card only the game sees", script=S)
mutate("Modules/Combat/Moments.lua",
       "\tlocal busy = Prompt ~= nil and type(Prompt.Showing) == \"function\" and Prompt:Showing() ~= nil",
       "\tlocal busy = Prompt ~= nil and type(Prompt.Showing) == \"function\"",
       "combat actions: the combat prompt gives way to a buff prompt that offers nothing",
       expect=N + "the buff prompt keeps its clicks over a card only the game sees", script=S)
