# Mutations for breaking free in a fight (Prompt/BreakFree.lua and the places
# that call it). Caught by tests/scenarios/breakfree.lua; each undoes one rule.

S = "runscenarios.py"
BF = "Prompt/BreakFree.lua"
ARMED = "breakfree: armed out of combat, shown by its own driver in a fight, nothing protected from Lua"

# --- 1. armed out of combat, shown by the driver, nothing protected in a fight

mutate(BF,
       "function BreakFree:Refresh()\n\tif InCombatLockdown() then return end\n",
       "function BreakFree:Refresh()\n",
       "breakfree: armed and placed from Lua under the lockdown",
       expect=ARMED, script=S)

mutate(BF,
       "\tif bright then\n\t\tglow:Show()\n",
       "\tif bright then\n\t\tbutton:Show()\n\t\tglow:Show()\n",
       "breakfree: the paint shows the button in a fight",
       expect=ARMED, script=S)

mutate(BF,
       "\tif newstate == \"fight\" and self:GetAttribute(\"manners-on\") then\n\t\twotf:Show(true)\n",
       "\tif newstate == \"fight\" and self:GetAttribute(\"manners-on\") then\n",
       "breakfree: the snippet never shows it",
       expect=ARMED, script=S)

mutate(BF,
       "\telse\n\t\twotf:Hide(true)\n\tend\n",
       "\tend\n",
       "breakfree: the snippet never hides it after the fight",
       expect="breakfree: its driver hides it as the fight ends", script=S)

mutate(BF,
       "\tArm(info.name)\n",
       "",
       "breakfree: never armed",
       expect=ARMED, script=S)

# --- 2. only a character with the ability

mutate(BF,
       "\t\tif row.race == race and ns.SpellKnown(row.spell) then\n",
       "\t\tif ns.SpellKnown(row.spell) or true then\n",
       "breakfree: any race and any spell book",
       expect="breakfree: not for a human", script=S)

mutate(BF,
       "\t\tif row.race == race and ns.SpellKnown(row.spell) then\n",
       "\t\tif row.race == race then\n",
       "breakfree: a Forsaken without the spell",
       expect="breakfree: not for a Forsaken without the spell", script=S)

mutate("Options/Look.lua",
       "\t\t\t\thidden = function() return ns.caps.breakFree == nil end,\n",
       "\t\t\t\thidden = function() return false end,\n",
       "breakfree: the switch shown to anybody",
       expect="breakfree: not for a human", script=S)

# --- 3. switched off

mutate(BF,
       "\t\tif button then\n\t\t\tDisarm()\n",
       "\t\tif button then\n",
       "breakfree: switched off and still armed",
       expect="breakfree: switched off, disarmed and not shown in a fight", script=S)

mutate(BF,
       "\tif newstate == \"fight\" and self:GetAttribute(\"manners-on\") then\n",
       "\tif newstate == \"fight\" then\n",
       "breakfree: the snippet shows it switched off",
       expect="breakfree: switched off, disarmed and not shown in a fight", script=S)

# --- 4. the button carries its own display

mutate(BF,
       "\tSetTo(to)\n",
       "\tSetTo(0.35)\n",
       "breakfree: the button never lights up",
       expect="breakfree: feared with the prompt off the screen, the button lights up", script=S)

mutate(BF,
       "\t\tkeyText:SetText(keyLabel and L[\"press %s to break free\"]:format(keyLabel) or L[\"click to break free\"])\n",
       "\t\tkeyText:SetText(\"\")\n",
       "breakfree: the button says nothing of its key",
       expect="breakfree: feared with the prompt off the screen, the button lights up", script=S)

# --- 5. the prompt, when it is up

mutate("Prompt/Refresh.lua",
       "\t\tif breakFree then breakFree.PaintPrompt(self, p) end\n",
       "",
       "breakfree: the prompt never names it",
       expect="breakfree: feared with the prompt up, the prompt names it and its key", script=S)

# --- 6. a stun or a root is no reason (a fear by mechanic is one: wotfneed.py)

mutate(BF,
       "\t\tbreaks = { FEAR = true, FEAR_MECHANIC = true, CHARM = true, SLEEP = true }, cooldown = 120 },\n",
       "\t\tbreaks = { FEAR = true, FEAR_MECHANIC = true, CHARM = true, SLEEP = true, STUN = true }, cooldown = 120 },\n",
       "breakfree: a stun lights it",
       expect="breakfree: STUN is no reason", script=S)

# --- 7. charmed by UnitIsCharmed alone

mutate(BF,
       "\tif not hit and info.row.breaks.CHARM and plain(UnitIsCharmed(\"player\")) == true then\n",
       "\tif false then\n",
       "breakfree: a charm the client reports by UnitIsCharmed alone missed",
       expect="breakfree: charmed by UnitIsCharmed alone", script=S)

# --- 8. a secret is never a reason

mutate(BF,
       "\t\telseif type(raw) ~= \"nil\" then\n\t\t\tfirst, how = first or \"?\", how or \"secret\"\n",
       "\t\telseif type(raw) ~= \"nil\" then\n\t\t\tdo return true, \"?\", \"secret\" end\n",
       "breakfree: a secret type taken for a fear",
       expect="wotfneed: a secret report while you plainly have control is no reason", script=S)

mutate(BF,
       "\tif not hit and info.row.breaks.CHARM and plain(UnitIsCharmed(\"player\")) == true then\n",
       "\tif not hit and info.row.breaks.CHARM and UnitIsCharmed(\"player\") then\n",
       "breakfree: a secret charm taken for one",
       expect="wotfneed: a plain empty report and a secret charm are no reason", script=S)

mutate(BF,
       "\t\t\tif type(plain(data)) ~= \"table\" then return data end\n",
       "\t\t\tdata = plain(data)\n\t\t\tif type(data) ~= \"table\" then return data end\n",
       "breakfree: a secret record said as a plain loss of control of no type",
       expect="breakfree: a secret loss-of-control record is said as secret", script=S)

# --- 9. its key casts the one spell, steps nothing, files nothing

mutate(BF,
       "\t\tif index <= 5 then button:SetAttribute(\"type\" .. index, \"none\") end\n\t\tbutton:SetAttribute(\"*type\" .. index, \"none\")\n",
       "",
       "breakfree: every mouse button casts it",
       expect="breakfree: its key casts the spell alone, steps no rota and files nothing", script=S)

# --- 10. the pending-click guard

mutate(BF,
       "\tif pending and ns.ExpirePendingClick then ns.ExpirePendingClick(pending, L[\"you broke free instead\"]) end\n",
       "",
       "breakfree: the prompt's press kept waiting through a break free",
       expect="breakfree: a prompt press then its key settles no favour", script=S)

# The review's fault put back: any cast event for a moment after a break-free
# press (its spell still awaited) settles nothing, so a prompt press made then
# is swept as nothing cast. Read off the mock's record of the frame's events.
mutate("Clicks.lua",
       "\tif not pending then return end\n\t-- No break-free test here:",
       "\tif not pending then return end\n\tlocal bf = ns.BreakFree and ns.BreakFree.frame\n"
       "\tif bf and bf._events and bf._events.UNIT_SPELLCAST_SUCCEEDED then return end\n\t-- No break-free test here:",
       "breakfree: its cast settles the prompt's press",
       expect="breakfree: its key then a prompt press settles the favour (ready)", script=S)

mutate("Clicks.lua",
       "\tif not pending then return end\n\t-- No break-free test here:",
       "\tif not pending then return end\n\tlocal bf = ns.BreakFree and ns.BreakFree.frame\n"
       "\tif bf and bf._events and bf._events.UNIT_SPELLCAST_SUCCEEDED then return end\n\t-- No break-free test here:",
       "breakfree: a press of the disarmed button holds the prompt's settle",
       expect="breakfree: its key then a prompt press settles the favour (switched off)", script=S)

# --- 11. the cooldown

mutate(BF,
       "\tif readyAt then\n\t\tif now < readyAt then return false end\n",
       "\tif readyAt then\n\t\tif false then return false end\n",
       "breakfree: lit while it cools down",
       expect="breakfree: dim while it cools down, lit again once ready", script=S)

mutate(BF,
       "\t\tif now < readyAt then return false end\n\t\treadyAt = nil\n",
       "\t\tif now < readyAt + 600 then return false end\n\t\treadyAt = nil\n",
       "breakfree: never ready again",
       expect="breakfree: dim while it cools down, lit again once ready", script=S)

# --- 12. the prompt given back

mutate(BF,
       "\t\t\t\tif S.current then\n\t\t\t\t\tR.icon:SetTexture(EntryIcon(S.current))\n\t\t\t\telse\n\t\t\t\t\tR.icon:SetTexture(iconBefore)\n\t\t\t\tend\n",
       "",
       "breakfree: the prompt keeps the spell's icon once the fear ends",
       expect="breakfree: the fear ends and the prompt names the rota's person again", script=S)

mutate(BF,
       "\t\t\t\telse\n\t\t\t\t\tR.icon:SetTexture(iconBefore)\n\t\t\t\tend\n",
       "\t\t\t\tend\n",
       "breakfree: with nobody on the prompt the spell's icon stays",
       expect="breakfree: with nobody on the prompt the fear's end puts its icon back", script=S)

mutate(BF,
       "\tlocal lit = Paint()\n\tif (was ~= afflicted or lit ~= litShown) and InCombatLockdown() then\n",
       "\tlocal lit = Paint()\n\tif was ~= afflicted and InCombatLockdown() then\n",
       "breakfree: the prompt not told when the cooldown ends mid-fear",
       expect="breakfree: the cooldown ends mid-fear and the prompt names it with the button", script=S)

mutate("Core.lua",
       "\tif ns.BreakFree then ns.Guard(\"break free release\", ns.BreakFree.Release, ns.BreakFree) end\n",
       "",
       "breakfree: nothing let go as the fight ends",
       expect="breakfree: the fight's end takes it down with the combat flag late", script=S)

mutate(BF,
       "\t\tif header:GetAttribute(\"state-\" .. STATE) ~= \"peace\" then header:SetAttribute(\"state-\" .. STATE, \"peace\") end\n",
       "",
       "breakfree: its driver left on fight after the fight",
       expect="breakfree: the fight's end takes it down with the combat flag late", script=S)

# --- 14. nothing Manners chooses keeps it from a fight

mutate(BF,
       "\treturn caps.breakFree ~= nil and db ~= nil and db.enabled == true and db.prompt.breakFree ~= false\n",
       "\treturn caps.breakFree ~= nil and db ~= nil and db.enabled == true and db.prompt.breakFree ~= false\n\t\tand not ns.SnoozeLeft()\n",
       "breakfree: a snooze takes it",
       expect="breakfree: a snooze of the prompt leaves it", script=S)

# --- 15. the switch and its key

mutate("Core.lua",
       "\t\t\tbreakFree = false,\n",
       "\t\t\tbreakFree = true,\n",
       "breakfree: on out of the box",
       expect="breakfree: the switch is on In a fight and off by default", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t[\"appearance.breakFreeKey\"] = \"appearance.breakFree\",\n",
       "",
       "breakfree: search does not know the key's switch",
       expect="breakfree: the switch is on In a fight and on by default", script=S)

mutate("Options/Look.lua",
       "\t\t\t\t\treturn ns.caps.breakFree == nil or P().breakFree == false or not ns.Setup.CanBind()\n",
       "\t\t\t\t\treturn ns.caps.breakFree == nil or not ns.Setup.CanBind()\n",
       "breakfree: its key shown with the switch off",
       expect="breakfree: the switch is on In a fight and on by default", script=S)

mutate("Options/Start.lua",
       "\t\t\t\tlocal line = said and said(key, name)\n",
       "\t\t\t\tlocal line = nil\n",
       "breakfree: its key said to buff the prompted player",
       expect="breakfree: its key control binds it and says what the key now does", script=S)

mutate("Options/Start.lua",
       "\t\tfor _, old in ipairs(Setup.Keys(command)) do SetBinding(old) end\n",
       "\t\tfor _, old in ipairs(Setup.Keys()) do SetBinding(old) end\n",
       "breakfree: its old key kept",
       expect="breakfree: its key control binds it and says what the key now does", script=S)

mutate("Options/Advanced.lua",
       "\t\"prompt.breakFree\", \"beast.fightMend\", \"prompt.cureFight\", \"prompt.cureFightEach\", \"prompt.fightButtons\",\n",
       "\t\"beast.fightMend\", \"prompt.cureFight\", \"prompt.cureFightEach\", \"prompt.fightButtons\",\n",
       "breakfree: In a fight's reset leaves the switch",
       expect="advanced: put these back to default on In a fight", script=S)

# --- 16. no macro of the prompt's carries it

mutate("Prompt/Macro.lua",
       "\t-- Nobody is asked for anything in a fight (Ask.lua).\n\tif entry.ask then return nil end\n",
       "\t-- Nobody is asked for anything in a fight (Ask.lua).\n\tif entry.ask then return nil end\n\tif ns.caps.breakFree then return \"/cast \" .. ns.caps.breakFree.name, nil end\n",
       "breakfree: the fight's rota casts it",
       expect="breakfree: no prompt, rota or bar macro carries the spell", script=S)

# --- 17. no API: the events are never asked for

mutate(BF,
       "\tif type(_G.C_LossOfControl) == \"table\" then\n\t\tframe:RegisterEvent(\"LOSS_OF_CONTROL_ADDED\")\n",
       "\tdo\n\t\tframe:RegisterEvent(\"LOSS_OF_CONTROL_ADDED\")\n",
       "breakfree: the loss-of-control events asked for where the client has none",
       expect="breakfree: feared and charmed on camelot, loss of control as none", script=S)

mutate(BF,
       "\telseif type(api.GetNumEvents) == \"function\" and type(api.GetEventInfo) == \"function\" then\n",
       "\telseif false then\n",
       "breakfree: the older loss-of-control API unread",
       expect="wotfneed: a plain stun is read as one in the events shape", script=S)

# --- 18. the probe's, never per scan

mutate(BF,
       "\treturn caps.breakFree ~= nil and db ~= nil and db.enabled == true and db.prompt.breakFree ~= false\n",
       "\treturn caps.breakFree ~= nil and ns.SpellKnown(7744) and db ~= nil and db.enabled == true and db.prompt.breakFree ~= false\n",
       "breakfree: the spell book asked on every scan",
       expect="breakfree: the spell book is asked in the probe, never per scan", script=S)

# --- what a scan pays

mutate(BF,
       "\tif dirty then return true end\n\tlocal db = Profile()\n",
       "\tdo return true end\n\tlocal db = Profile()\n",
       "breakfree: every idle scan refreshes it",
       expect="breakfree: an idle scan pays nothing for it (switch on)", script=S)

mutate(BF,
       "\t-- Nobody without the ability, and no button to take down: nothing ever.\n\tif button == nil and caps.breakFree == nil then return false end\n\tif InCombatLockdown() then return false end\n\tif dirty then return true end\n",
       "\tif InCombatLockdown() then return false end\n\tif caps.breakFree ~= nil or button ~= nil then return true end\n\tif dirty then return true end\n",
       "breakfree: every idle scan refreshes it switched off",
       expect="breakfree: an idle scan pays nothing for it (switch off)", script=S)

mutate(BF,
       "\tif on ~= settledOn then return true end\n",
       "",
       "breakfree: the switch thrown is never taken up",
       expect="breakfree: an idle scan pays nothing for it", script=S)

mutate(BF,
       "\tif event == \"PLAYER_REGEN_DISABLED\" then\n\t\tReadKey()\n",
       "\tif event == \"PLAYER_REGEN_DISABLED\" then\n",
       "breakfree: the key not read at the pull",
       expect="breakfree: a key bound since the last scan's work is the one it names", script=S)

# --- 19. what /manners debug and the launch check say

mutate(BF,
       "\t\tlastLoss = { kind = kind or \"none\", how = how or \"plain\", at = GetTime() }\n",
       "",
       "breakfree: the last loss of control forgotten",
       expect="breakfree: /manners debug and the launch check say what they found", script=S)

mutate("Commands.lua",
       "\t\tfor _, line in ipairs(ns.BreakFreeLines and ns.BreakFreeLines() or {}) do self:Print(\"  \" .. line) end\n",
       "",
       "breakfree: /manners debug says nothing of it",
       expect="breakfree: /manners debug and the launch check say what they found", script=S)

mutate("SelftestLaunch.lua",
       "\t\tif text ~= \"/cast \" .. info.name then worse(FAIL, \"the button is not armed with the spell\") end\n",
       "",
       "breakfree: the launch check blind to an unarmed button",
       expect="breakfree: launch check fails an unarmed button", script=S)
