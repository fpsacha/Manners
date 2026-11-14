# Mutations for asking, not only giving (Ask.lua): each undoes one promise of
# the ask -- off until ticked, the two rests, never in a fight, a battleground
# or (unticked) a city, never the listed, the ignored, the dead or the busy,
# only what you would want and plainly do not wear, last on the prompt, one
# whispered line and nothing cast -- and is caught by the scenario in
# tests/scenarios/ask.lua that names it.

S = "runscenarios.py"

OFF = "ask: off until it is ticked, and then somebody who could give you a buff comes up"
PRESS = "ask: a press whispers one polite line, targets nobody and casts nothing"
RESTS = "ask: one ask a person for a buff in ten minutes, and one ask in all in two"
FIGHT = "ask: nobody is asked in a fight, and the pull leaves no ask on the button"
BATTLE = "ask: nobody is asked in a battleground or an arena"
TOWN = "ask: nobody is asked in a city or an inn until that is ticked"
NEVER = "ask: nobody on the never-offer list or the ignore list, dead, fighting or away is asked"
WANT = "ask: only for a buff you would want and plainly do not wear"
PALADIN = "ask: a mage asks a paladin for Wisdom, never Might"
TALENT = "ask: never for a talent, or for a buff handed out only on request"
PASTE = "ask: a pasted settings string never switches asking on"
LAST = "ask: an ask ranks after everything else on the prompt"
LINES = "ask: /say as a choice, and each of the three lines"
POOL = "ask: with the In character set on, a line from its own pool, short and safe in a macro"
NAME = "ask: nobody whose whisper the chat box would send to somebody else"
NOTHING = "ask: a class with nothing to give has a prompt for it, and is shown the switch on Start here"
RESET = "ask: a class with buffs to give finds the switch on Who to buff alone"
DEBUG = "ask: /manners debug says whether anybody is asked, and what holds it back"
GROUP = "ask: somebody in your group is asked, and the tooltip says what the press will say"

# ------------------------------------------------------------ the switch

# On out of the box: every player whispering strangers without having asked to.
mutate("Core.lua",
       "\t\t\task = false,\n",
       "\t\t\task = true,\n",
       "ask: on out of the box",
       expect=OFF, script=S)

# A class with nothing to give never reaches the queue's end: its own way out.
mutate("Queue.lua",
       "\t\tif db.sources.ask == true and ns.AskInto then return ns.AskInto(own and { own } or {}, own and {} or true) end\n",
       "",
       "ask: nobody asked by a class with nothing to cast",
       expect=OFF, script=S)

# And everybody else's.
mutate("Queue.lua",
       "\tif db.sources.ask == true and ns.AskInto then return ns.AskInto(queue, rejected) end\n",
       "",
       "ask: nobody asked by a class with buffs of its own",
       expect=LAST, script=S)

# Switched off, and /manners debug says somebody can be asked.
mutate("Ask.lua",
       "\tif not (db and type(db.sources) == \"table\" and db.sources.ask == true) then return \"off\" end\n",
       "\tif not db then return \"off\" end\n",
       "ask: held back by nothing while switched off",
       expect=DEBUG, script=S)

# ----------------------------------------------------------- the two rests

mutate("Ask.lua",
       "Ask.PERSON_SECONDS = 600\n",
       "Ask.PERSON_SECONDS = 60\n",
       "ask: the same person asked again after a minute",
       expect=RESTS, script=S)

mutate("Ask.lua",
       "\tif Ask.lastAt and now - Ask.lastAt < Ask.REST_SECONDS then return \"rest\" end\n",
       "",
       "ask: no rest between two asks",
       expect=RESTS, script=S)

mutate("Ask.lua",
       "\tasked[id] = now\n\tAsk.lastAt = now\n",
       "\tAsk.lastAt = now\n",
       "ask: nobody remembered as asked",
       expect=DEBUG, script=S)

# ------------------------------------------------- never in a fight, etc.

mutate("Ask.lua",
       "\tif InCombatLockdown() or (prompt and prompt.armedForFight == true) then return \"fight\" end\n",
       "",
       "ask: armed at the pull and frozen for the fight",
       expect=FIGHT, script=S)

mutate("Ask.lua",
       "\tif type(fighting) == \"function\" and plain(fighting(\"player\")) == true then return \"fight\" end\n",
       "",
       "ask: asked while in combat before the lockdown",
       expect=FIGHT, script=S)

mutate("Prompt/Macro.lua",
       "\tif entry.ask then return nil end\n",
       "",
       "ask: the fight's rota holds an ask",
       expect=FIGHT, script=S)

mutate("Ask.lua",
       "\tif ns.InBattleground() then return \"battle\" end\n",
       "",
       "ask: asked in a battleground",
       expect=BATTLE, script=S)

mutate("Ask.lua",
       "and ns.Resting() ~= false then return \"town\" end\n",
       "and false then return \"town\" end\n",
       "ask: asked in a city with the switch unticked",
       expect=TOWN, script=S)

# The scan holds an ask back in a city; the arming of a name the prompt kept
# has to as well.
mutate("Ask.lua",
       "\tif db and not Ask.HeldBack(db, now) and not ns.IsBlocked(name, key, now)\n",
       "\tif db and not ns.IsBlocked(name, key, now)\n",
       "ask: a kept name armed whatever holds asking back",
       expect=TOWN, script=S)

# ------------------------------------------------------- who is never asked

mutate("Ask.lua",
       "\tif ns.IsNeverOffered(full) then return nil end\n",
       "",
       "ask: the never-offer list asked",
       expect=NEVER, script=S)

mutate("Ask.lua",
       "\tif ns.IsBlocked(full, mine.key, now) then return nil end\n",
       "",
       "ask: somebody skipped with a right-click asked",
       expect=NEVER, script=S)

mutate("Ask.lua",
       "\tif ns.Ignored(unit, plain(UnitGUID(unit))) then return nil end\n",
       "",
       "ask: the ignore list asked",
       expect=NEVER, script=S)

mutate("Ask.lua",
       "\tif plain(UnitIsDeadOrGhost(unit)) ~= false then return nil end\n",
       "",
       "ask: the dead asked",
       expect=NEVER, script=S)

mutate("Ask.lua",
       "\tif type(fighting) == \"function\" and plain(fighting(unit)) ~= false then return nil end\n",
       "",
       "ask: somebody in a fight asked",
       expect=NEVER, script=S)

mutate("Ask.lua",
       "\tif type(away) == \"function\" and plain(away(unit)) == true then return nil end\n",
       "",
       "ask: somebody away asked",
       expect=NEVER, script=S)

mutate("Ask.lua",
       "\tif type(busy) == \"function\" and plain(busy(unit)) == true then return nil end\n",
       "",
       "ask: somebody not to be disturbed asked",
       expect=NEVER, script=S)

# ------------------------------------------------------ what you would want

mutate("Ask.lua",
       "\t\t\t\thas = true\n\t\t\t\tbreak\n",
       "\t\t\t\thas = false\n\t\t\t\tbreak\n",
       "ask: asked for what you wear",
       expect=WANT, script=S)

mutate("Ask.lua",
       "\t\t\tif not ok or (secret and secret(aura)) then\n\t\t\t\thas = nil\n",
       "\t\t\tif not ok or (secret and secret(aura)) then\n\t\t\t\thas = false\n",
       "ask: asked on a reading the client refused",
       expect=WANT, script=S)

mutate("Ask.lua",
       "\tif buff.manaOnly and me.relevantOnly and me.hasMana == false then return false end\n",
       "",
       "ask: a warrior asks for Intellect",
       expect=WANT, script=S)

mutate("Ask.lua",
       "\tif type(class) ~= \"string\" or class == me.class or ns.BUFFS[class] == nil then return nil end\n",
       "\tif type(class) ~= \"string\" or ns.BUFFS[class] == nil then return nil end\n",
       "ask: your own class asked",
       expect=PALADIN, script=S)

mutate("Ask.lua",
       "\tif buff.talent or buff.optIn or buff.returnOnly",
       "\tif buff.optIn or buff.returnOnly",
       "ask: asked for a talent",
       expect=TALENT, script=S)

mutate("Ask.lua",
       "\tif buff.talent or buff.optIn or buff.returnOnly",
       "\tif buff.talent or buff.returnOnly",
       "ask: asked for a buff that is off until switched on",
       expect=TALENT, script=S)

mutate("Ask.lua",
       "\t\t\tif not buff.oneTarget and Wearing(buff, now, true) ~= false then return nil end\n",
       "",
       "ask: a second blessing asked for over the one worn",
       expect=PALADIN, script=S)

# ------------------------------------------------------- last on the prompt

mutate("Ask.lua",
       "Ask.PRIORITY = 9\n",
       "Ask.PRIORITY = 0\n",
       "ask: an ask ahead of everybody",
       expect=LAST, script=S)

mutate("Ask.lua",
       "\tif not full or taken[full] then return nil end\n",
       "\tif not full then return nil end\n",
       "ask: somebody with a buff coming asked for one",
       expect=LAST, script=S)

# ------------------------------------------------------------- the press

# The cast's own macro in place of the line: a /target and a /cast of a spell
# this character does not have.
mutate("Prompt/Macro.lua",
       "\tif entry.ask then return ns.AskArm(R, S, entry) end\n",
       "",
       "ask: armed as a cast",
       expect=PRESS, script=S)

mutate("Ask.lua",
       "\tlocal macro = \"/\" .. command .. \" \" .. line\n",
       "\tlocal macro = \"/target \" .. tostring(entry.targetName) .. \"\\n/\" .. command .. \" \" .. line\n",
       "ask: the press takes your target",
       expect=PRESS, script=S)

# Filed as a cast: parked for the game to settle, counted as a buff given.
mutate("Prompt/Press.lua",
       "\tif S.current and S.current.ask then return ns.AskPressed(S, armedText) end\n",
       "",
       "ask: the press filed as a cast",
       expect=PRESS, script=S)

# Left armed after the press, to be said again by the next one.
mutate("Ask.lua",
       "\tns.MarkAttempted(entry.name, entry.buff.key, Ask.PERSON_SECONDS)\n",
       "",
       "ask: the prompt keeps them after the press",
       expect=PRESS, script=S)

mutate("Core.lua",
       "\tif buff.askInfo then return buff.askInfo end\n",
       "",
       "ask: the buff asked for has no name",
       expect=OFF, script=S)

mutate("Prompt/Paint.lua",
       "\tif entry.ask then return ns.Ask.Reason(entry) end\n",
       "",
       "ask: the prompt's second line a passer-by's",
       expect=OFF, script=S)

# ------------------------------------------------------------- the words

mutate("Ask.lua",
       "\tif db.ask.channel ~= \"SAY\" then\n",
       "\tif true then\n",
       "ask: /say whispered",
       expect=LINES, script=S)

mutate("Core.lua",
       "\tif ns.AskClamp then ns.AskClamp(profile) end\n",
       "",
       "ask: a damaged choice left as it is",
       expect=LINES, script=S)

mutate("Ask.lua",
       "\tif rp and rp.Active and rp.Active(db.speech) then\n",
       "\tif false then\n",
       "ask: the In character set says a plain line",
       expect=POOL, script=S)

# The line said is not the line the tooltip quoted: rolled again at the press.
mutate("Ask.lua",
       "\tif state and state.askKey == identity and state.askLine and #state.askLine <= room then\n",
       "\tif false then\n",
       "ask: the line rolled again at every arming",
       expect=POOL, script=S)

mutate("Ask.lua",
       "\tif to and ns.WhisperGoesTo(macro) ~= to then return nil end\n",
       "",
       "ask: a whisper the chat box sends to somebody else",
       expect=NAME, script=S)

# ------------------------------------------- a class with nothing to give

mutate("Core.lua",
       "\tif ns.AskLive and ns.AskLive() then return true end\n\t-- Or a cure, with one of its switches on (Cures.lua).\n",
       "\t-- Or a cure, with one of its switches on (Cures.lua).\n",
       "ask: no prompt for a class with nothing to cast",
       expect=NOTHING, script=S)

mutate("Options/Shared.lua",
       "\tif ns.AskLive and ns.AskLive() then return true end\n",
       "",
       "ask: Start here has no steps for a class that only asks",
       expect=NOTHING, script=S)

mutate("Options/Start.lua",
       "\t\t\t\thidden = HasClassBuffs,\n",
       "\t\t\t\thidden = function() return true end,\n",
       "ask: the switch hidden on Start here",
       expect=NOTHING, script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"general.startAsk\",\n",
       "",
       "ask: the switch drawn nowhere on Start here",
       expect=NOTHING, script=S)

mutate("Commands.lua",
       "\t\t\t:format(\"|cffffd100\" .. L[\"Ask people for a buff I'm missing\"] .. \"|r\"))\n\t\treturn true\n",
       "\t\t\t:format(\"\"))\n\t\treturn true\n",
       "ask: the greeting names no switch",
       expect=NOTHING, script=S)

mutate("Options/Who.lua",
       "\tPage.AddAskControls(who.args)\n",
       "",
       "ask: Who to buff has no switch",
       expect=RESET, script=S)

mutate("Options/Advanced.lua",
       "\t\t\"sources.ask\", \"ask.channel\", \"ask.line\", \"ask.inTowns\",\n",
       "",
       "ask: the page's reset leaves asking as it is",
       expect=RESET, script=S)

mutate("Commands.lua",
       "\tSHARE_KEEP_MINE[\"sources.ask\"] = \"ask\"\n",
       "",
       "ask: a paste switches asking on",
       expect=PASTE, script=S)

# ------------------------------------------------------------------ debug

mutate("Commands.lua",
       "\t\tfor _, line in ipairs(ns.AskLines and ns.AskLines(now) or {}) do self:Print(\"  \" .. line) end\n",
       "",
       "ask: /manners debug silent about asking",
       expect=DEBUG, script=S)

# -------------------------------------------------------------- the group

mutate("Ask.lua",
       "\t\t\tif plain(checked) == true and plain(near) == false then return nil end\n",
       "",
       "ask: a party member out of range asked",
       expect=GROUP, script=S)
