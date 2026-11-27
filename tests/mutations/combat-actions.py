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
       '"moments.alert", "moments.alertSound",\n\t\t}',
       '"moments.alert", "moments.alertSound", "moments.promptX",\n\t\t}',
       "combat actions: Reset this page on Combat moves the prompt",
       expect="Reset this page on Combat does not put back the actions and look, or moves the prompt", script=S)

mutate("Modules/Combat/MomentsSense.lua",
       'local rawName, _, _, _, _, _, _, rawNotInt = UnitCastingInfo("target")',
       "local rawName, rawNotInt = nil, nil",
       "combat actions: an interruptible target cast is ignored",
       expect=N + "a generated interrupt uses a plain target-cast signal without secure writes", script=S)

mutate("Modules/Combat/Moments.lua",
       "Moments.selected = best",
       "Moments.selected = nil",
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
       "local pinned = best ~= nil",
       "local pinned = false",
       "combat actions: a first click can authorize a newly urgent spell",
       expect=N + "the two-click confirmation cannot switch to another action", script=S)

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
       "previewing = false",
       "previewing = true",
       "combat actions: ending a preview leaves its drag frame over the prompt",
       expect="turning off the last action left the drag frame over the prompt", script=S)

mutate("Modules/Services/Courtesy.lua",
       'local cache = key .. "\\0" .. tostring(item or 0)',
       'local cache = key',
       "services: different recipients share and overwrite one service item icon",
       expect="courtesy: mists: one refreshment spell keeps each recipient's item icon",
       script=S)
