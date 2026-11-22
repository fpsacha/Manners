# Mutations for your cure in a fight (Prompt/CureFight.lua, Cures.lua's
# CureFightSpells and CureFightRead, and the places that place its controls).
# Caught by tests/scenarios/curefight.lua; each undoes one rule.

S = "runscenarios.py"
CF = "Prompt/CureFight.lua"
CU = "Cures.lua"
ARMED = "curefight: armed out of combat, shown by its own driver at alpha 0"

# --- 1. out of sight until somebody needs a cure; armed out of combat; off by default

mutate(CF,
       "\tlocal to = on and (ready and 1 or 0.6) or 0\n",
       "\tlocal to = on and (ready and 1 or 0.6) or 0.35\n",
       "curefight: dim for the whole fight",
       expect="curefight: nothing shows until somebody needs a cure", script=S)

mutate(CF,
       "\tif newstate == \"fight\" and self:GetAttribute(\"manners-on\") then\n\t\tcure:Show(true)\n",
       "\tif newstate == \"fight\" and self:GetAttribute(\"manners-on\") then\n",
       "curefight: the snippet never shows it",
       expect=ARMED, script=S)

mutate(CF,
       "function CureFight:Refresh()\n\tif InCombatLockdown() then return end\n",
       "function CureFight:Refresh()\n",
       "curefight: armed and placed from Lua under the lockdown",
       expect=ARMED, script=S)

mutate("Core.lua",
       "\t\t\tcureFight = true,\n",
       "\t\t\tcureFight = false,\n",
       "curefight: off out of the box",
       expect="curefight: on out of the box, nothing shown until needed", script=S)

mutate(CF,
       "db.prompt.cureFight == true) then return false end",
       "db.prompt.cureFight ~= nil) then return false end",
       "curefight: armed with the switch off",
       expect="curefight: switched off, nothing is shown or armed", script=S)

# --- 2. what the cure may be offered for

mutate(CU,
       " and plain(aura.canActivePlayerDispel) ~= false\n\t\t\t\t\tand type(expires)",
       "\n\t\t\t\t\tand type(expires)",
       "curefight: offered for a debuff the client says you cannot remove",
       expect="curefight: what the cure cannot take off", script=S)

mutate(CU,
       "\t\t\t\t\tif type(kind) == \"string\" then deniedKind[kind] = true else blind = true end\n",
       "\t\t\t\t\tblind = false\n",
       "curefight: a debuff never removed is forgotten",
       expect="curefight: what the cure cannot take off", script=S)

mutate(CU,
       "and expires - now > FIGHT_SECONDS\n",
       "and expires > now\n",
       "curefight: offered for a debuff about to end",
       expect="curefight: what the cure cannot take off", script=S)

mutate(CU,
       "\t\t\t\t\tif kinds and kinds[denied] then spares = false break end\n",
       "",
       "curefight: a cure that would lift a debuff never removed is offered",
       expect="curefight: what the cure cannot take off", script=S)

mutate(CU,
       "\t\t\tif expires and (allowed == nil or allowed[kind]) then\n",
       "\t\t\tif expires then\n",
       "curefight: a kind the macro cannot cast hides one it can",
       expect="curefight: only what the armed macro can cast is chosen", script=S)

mutate(CU,
       "\t\tif not bestKind then return nil, nil, nil, secret, candidate == true end\n",
       "\t\tif not bestKind then return nil, nil, nil, secret, false end\n",
       "curefight: a cure held back by a debuff never removed is not remembered",
       expect="curefight: a debuff never removed that goes lets the cure show", script=S)

mutate(CF,
       "\tif not needy[unit] and not held[unit] and type(info)",
       "\tif not needy[unit] and type(info)",
       "curefight: a held-back unit is read only when a debuff is added",
       expect="curefight: a debuff never removed that goes lets the cure show", script=S)

# --- 3. where the client hides debuffs, and what a fight costs

mutate(CF,
       "\tif secret then last.secret = last.secret + 1 end\n",
       "",
       "curefight: withheld reads are not counted",
       expect="curefight: forever: the game hides debuffs", script=S)

mutate(CF,
       "\tif caps.secretRestrictions == true then\n\t\twatched.focus = nil\n\t\treturn\n\tend\n",
       "",
       "curefight: the group is read where the client withholds auras",
       expect="curefight: forever: the game hides debuffs", script=S)

mutate(CF,
       "\t\tif not harmful then return end\n",
       "",
       "curefight: a buff in a raid asks for a read",
       expect="curefight: a raid's buffs in a fight read nobody's debuffs", script=S)

mutate(CF,
       "\tif flushDue then return end\n",
       "",
       "curefight: every event queues its own flush",
       expect="curefight: a burst of debuffs is read once a person", script=S)

mutate(CF,
       "\t\tif reads >= MAX_READS then break end\n",
       "",
       "curefight: a flush reads everybody",
       expect="curefight: a burst of debuffs is read once a person", script=S)

mutate(CF,
       "\t\t\tif plain(UnitIsUnit(RAID[i], \"player\")) ~= true then watched[RAID[i]] = true end\n",
       "\t\t\twatched[RAID[i]] = true\n",
       "curefight: your own raid token is read as well",
       expect="curefight: a burst of debuffs is read once a person", script=S)

# --- 4. who is shown, and when they stop being

mutate(CF,
       "\t\tif rec.ends - now <= 0 then\n",
       "\t\tif false then\n",
       "curefight: a debuff that ran out stays shown",
       expect="curefight: it fades when the debuff runs out with no event", script=S)

mutate(CF,
       "\t\t\tand (unit == \"player\" or ns.InRange(unit, rec.spell.cure) ~= false) then\n",
       "\t\t\tthen\n",
       "curefight: somebody out of reach is shown",
       expect="curefight: somebody out of reach is not shown", script=S)

mutate(CF,
       "\tif fighting and next(needy) then Recheck() end\n",
       "",
       "curefight: nobody is asked again for reach",
       expect="curefight: somebody out of reach is not shown", script=S)

mutate(CF,
       "\t\tif plain(UnitIsDeadOrGhost(unit)) == true or plain(UnitIsConnected(unit)) == false then return false end\n",
       "",
       "curefight: the dead and the offline are shown",
       expect="curefight: a dead or offline member is not shown", script=S)

# --- 5. what a press casts, and what the lines say

mutate(CF,
       "[%s@mouseover,help,nodead][%shelp,nodead][%s@player] %s",
       "[%s@mouseover,help][%shelp][%s@player] %s",
       "curefight: the macro casts at the dead and the hostile",
       expect="curefight: the macro cures your mouseover, else your target, else you", script=S)

mutate(CF,
       "\tif caps.conditionalTargeting then\n\t\treturn (\"[%s@mouseover",
       "\tif true then\n\t\treturn (\"[%s@mouseover",
       "curefight: Forever's macro names a unit",
       expect="curefight: forever: the macro is a bare cast", script=S)

mutate(CF,
       "Clause(list[2].name, true) .. \"; \" .. Clause(list[1].name, false)",
       "Clause(list[1].name, true) .. \"; \" .. Clause(list[2].name, false)",
       "curefight: the cures are the wrong way round",
       expect="curefight: a druid's second cure is on Shift", script=S)

mutate(CF,
       "\tlocal shift = armedTwo and spell == armedSpells[2]\n",
       "\tlocal shift = false\n",
       "curefight: the key line never names Shift",
       expect="curefight: the key line names Shift for the second cure", script=S)

mutate(CF,
       "\tif keyLabel and keyLabel:upper():find(\"SHIFT%-\") then return one, false end\n",
       "",
       "curefight: a key bound with Shift casts the second cure",
       expect="curefight: a key bound with Shift casts the first cure alone", script=S)

mutate(CF,
       "local friendTarget = canAssist and not (caps.conditionalTargeting and plain(UnitIsDeadOrGhost(\"target\")) == true)\n",
       "local friendTarget = canAssist\n",
       "curefight: a dead friend targeted is taken for the one the press lands on",
       expect="curefight: on yourself the key line says so", script=S)

mutate(CF,
       "canAssist and not (caps.conditionalTargeting and plain(UnitIsDeadOrGhost",
       "canAssist and not (true and plain(UnitIsDeadOrGhost",
       "curefight: Forever's bare cast is said to pass a dead friend by",
       expect="curefight: forever: a dead friend targeted still takes a bare cast", script=S)

mutate(CF,
       "and not (hostileTarget and spell.anyTarget and not caps.conditionalTargeting)",
       "and true",
       "curefight: a hostile target is not said to take Dispel Magic",
       expect="curefight: forever: a priest's own cure with a hostile target", script=S)

# --- 6. the button's own behaviour

mutate(CF,
       "\tif not visible then return end\n\tlocal tip = _G.GameTooltip\n",
       "\tlocal tip = _G.GameTooltip\n",
       "curefight: a tooltip for a button nobody can see",
       expect="curefight: no tooltip while it is out of sight", script=S)

mutate(CF,
       "\tif pending and ns.ExpirePendingClick then ns.ExpirePendingClick(pending, L[\"you cured somebody instead\"]) end\n",
       "",
       "curefight: the prompt's waiting press is kept",
       expect="curefight: its press lets the prompt's waiting press go", script=S)

mutate(CF,
       "\tfor _, event in ipairs(FIGHT_EVENTS) do frame:UnregisterEvent(event) end\n",
       "",
       "curefight: still listening after the fight",
       expect="curefight: out of a fight it listens to nothing", script=S)

mutate(CF,
       "\tif button == nil and (db.prompt.cureFight ~= true or not ns.ClassHasCures() or ns.CureFightSpells() == nil) then\n\t\treturn false\n\tend\n",
       "",
       "curefight: a scan asks the client with the switch off",
       expect="curefight: switched off, a scan pays nothing for it", script=S)

mutate(CF,
       "or not ns.ClassHasCures() or ns.CureFightSpells() == nil) then\n\t\treturn false",
       ") then\n\t\treturn false",
       "curefight: a class with no cure pays a scan the cure's questions",
       expect="curefight: on by default, a scan costs a warrior nothing", script=S)

mutate(CF,
       "\treturn changed and not InCombatLockdown()\n",
       "\treturn not InCombatLockdown() and changed\n",
       "curefight: a settled scan asks the lockdown first",
       expect="curefight: out of a fight it listens to nothing", script=S)

mutate(CF, "button:EnableMouse(keyLabel == nil and Always())",
       "button:EnableMouse(keyLabel == nil)",
       "curefight: the button takes a click out of sight with no key by default",
       expect="curefight: with no key the button takes no click out of sight, and a line says what to set", script=S)

mutate(CF, "\tSetVisible(true, ready)\n\tNudge()\n",
       "\tSetVisible(true, ready)\n",
       "curefight: nothing says a key is missing",
       expect="curefight: with no key the button takes no click out of sight, and a line says what to set", script=S)

mutate(CF,
       "\tfor token in pairs(watched) do dirty[token] = true end\n\tlocal frame = CureFight.frame\n",
       "\tlocal frame = CureFight.frame\n",
       "curefight: nobody is read at the pull",
       expect="curefight: somebody poisoned at the pull shows at once", script=S)

mutate(CF,
       "\t\t\tif unit == \"target\" or plain(UnitIsUnit(unit, \"target\")) == true then rank = 1\n",
       "\t\t\tif false then rank = 1\n",
       "curefight: your target is not named first",
       expect="curefight: your target is named first", script=S)

mutate(CF,
       "\t\t\tseenGuid[key] = true\n",
       "",
       "curefight: one person under two tokens is counted twice",
       expect="curefight: one person under two tokens is counted once", script=S)

mutate(CF,
       "\tlocal ready = left <= 0 and not mana\n",
       "\tlocal ready = not mana\n",
       "curefight: lit bright while the cure cools down",
       expect="curefight: mists: a cure cooling down shows dim", script=S)

# --- 7. where the controls are

mutate("Options/Look.lua",
       "\t\t\t\thidden = function() return not (ns.ClassHasCures() and ns.CureLearned()) end,\n",
       "",
       "curefight: the switch is shown to a class with no cure",
       expect="curefight: a class with no cure never sees it", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"appearance.cureFight\",\n",
       "",
       "curefight: the switch has no place in the window",
       expect="every control has one place in the options window", script=S)

mutate("Options/Advanced.lua",
       "\"beast.fightMend\", \"prompt.cureFight\",",
       "\"beast.fightMend\",",
       "curefight: the reset leaves the switch on",
       expect="advanced: put these back to default on In a fight", script="runscenarios.py")
