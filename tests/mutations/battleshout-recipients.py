# Mutations for the opt-in Battle Shout recipient and combat controls.

S = "runscenarios.py"
RECIPIENTS = "battleshout-recipients: only tanks and reliably identified melee"
PURE = "battleshout-recipients: a pure melee class needs no spec; an unknown hybrid is skipped"
DEFAULT = "battleshout-recipients: off by default keeps the old recipients"
ASKS = "battleshout-recipients: owed favours and explicit asks bypass the filters"
COMBAT = "battleshout-recipients: combat timing waits for a dungeon or raid fight"
CONTROLS = "battleshout-recipients: controls are on Who to buff"

mutate("Core.lua",
       "\t\tif buff.recipientMelee and opts.shoutMelee and not (opts.owed or opts.requested)\n"
       "\t\t\tand opts.isMelee ~= true then\n"
       "\t\t\treturn false\n"
       "\t\tend\n",
       "",
       "battleshout-recipients: Castable ignores the recipient control",
       expect=RECIPIENTS, script=S)

mutate("Core.lua",
       "return type(id) == \"number\" and MELEE_SPECS[id] == true",
       "return type(id) == \"number\" and MELEE_SPECS[id] == false",
       "battleshout-recipients: known melee hybrid specs are rejected",
       expect=RECIPIENTS, script=S)

mutate("Core.lua",
       "if MELEE_CLASSES[class] then return true end",
       "if false and MELEE_CLASSES[class] then return true end",
       "battleshout-recipients: pure melee classes require a spec",
       expect=PURE, script=S)

mutate("Core.lua",
       "\t\t\tshoutMelee = false,\n",
       "\t\t\tshoutMelee = true,\n",
       "battleshout-recipients: melee recipients are on by default",
       expect=DEFAULT, script=S)

mutate("Core.lua",
       "\t\tif buff.recipientMelee and opts.shoutMelee and not (opts.owed or opts.requested)\n",
       "\t\tif buff.recipientMelee and opts.shoutMelee and not opts.owed\n",
       "battleshout-recipients: explicit asks are recipient-filtered",
       expect=ASKS, script=S)

mutate("Core.lua",
       "\t\tif buff.recipientMelee and opts.shoutCombatInstances and not (opts.owed or opts.requested)\n"
       "\t\t\tand opts.shoutCombatAllowed ~= true then\n"
       "\t\t\treturn false\n"
       "\t\tend\n",
       "",
       "battleshout-recipients: combat timing never holds the shout",
       expect=COMBAT, script=S)

mutate("Options/Window/Layout.lua",
       "\titems[#items + 1] = \"who.shoutMelee\"\n"
       "\titems[#items + 1] = \"who.shoutCombatInstances\"\n",
       "",
       "battleshout-recipients: the controls are absent from the page",
       expect=CONTROLS, script=S)
