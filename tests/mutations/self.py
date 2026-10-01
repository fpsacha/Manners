# Mutations for "Buff myself": the offer of your own buff (Queue.lua), how the
# prompt shows and casts it (Prompt.lua, Speech.lua), what a press on yourself
# files (Clicks.lua), you in your party's group cast (GroupBuffs.lua), and the
# switch on the options page and in the saved settings (Core.lua, Options.lua,
# Commands.lua). Each is caught by the scenario in tests/scenarios/self.lua
# that names it.

S = "runscenarios.py"

# --- the offer ---

# Never made at all.
mutate("Queue.lua",
       "\tif mine then\n\t\tqueue[#queue + 1] = mine\n",
       "\tif mine then\n\t\tlocal _ = mine\n",
       "self: never offered",
       expect="you were not offered your own Intellect", script=S)

# The switch ignored (for both kinds of your own buff, ns.MyselfHeldBack).
mutate("Queue.lua",
       "\tif db.sources.self ~= true then return \"switch\" end\n",
       "",
       "self: switch ignored",
       expect="offered with the switch off", script=S)

# Offered on a reading the client withheld.
mutate("Queue.lua",
       "\tif not (has == false or remaining ~= nil) then return nil end\n",
       "",
       "self: offered on a guess",
       expect="offered on a reading the client withheld", script=S)

# The top-up setting not passed on.
mutate("Queue.lua",
       "\t\twhenBuffed = f.whenBuffed,\n\t\trefreshUnder = f.refreshUnder,\n\t\tname = full,\n",
       "\t\twhenBuffed = \"skip\",\n\t\trefreshUnder = f.refreshUnder,\n\t\tname = full,\n",
       "self: top-up ignored",
       expect="two minutes left and top-ups on", script=S)

# The pin let through past the list the walk was handed.
mutate("Queue.lua",
       "\tif not ns.CastsOnSelf(buff) then return nil end\n",
       "\tif not buff then return nil end\n",
       "self: a pin past the self list",
       expect="a pinned Source of Magic was offered", script=S)

# A shout offered to the warrior alone.
mutate("Core.lua",
       "\treturn buff ~= nil and not buff.selfCast and not buff.notSelf and not buff.neverSelf\n",
       "\treturn buff ~= nil and not buff.notSelf and not buff.neverSelf\n",
       "self: shout offered to yourself",
       expect="a solo warrior was offered his own shout", script=S)

# A spell the game keeps off its caster offered to the caster.
mutate("Core.lua",
       "\treturn buff ~= nil and not buff.selfCast and not buff.notSelf and not buff.neverSelf\n",
       "\treturn buff ~= nil and not buff.selfCast and not buff.neverSelf\n",
       "self: notSelf ignored",
       expect="while wearing the Blessing", script=S)

# Your own name on the never-offer list ignored.
mutate("Queue.lua",
       "\tif ListedAs(full, verdict) then return nil end\n",
       "",
       "self: never-offer list ignored",
       expect="with your name on the never-offer list", script=S)

# --- where you stand ---

mutate("Queue.lua",
       "PRIORITY.self = 1.75\n",
       "PRIORITY.self = 2.5\n",
       "self: behind your group",
       expect="not the favour owed, then you", script=S)

mutate("Queue.lua",
       "PRIORITY.self = 1.75\n",
       "PRIORITY.self = 0.9\n",
       "self: ahead of a favour owed",
       expect="not the favour owed, then you", script=S)

# --- the prompt ---

mutate("Queue.lua",
       "\t\tdisplay = L[\"You\"],\n",
       "",
       "self: named rather than You",
       expect="the first line does not say You", script=S)

mutate("Prompt/Prompt.lua",
       "REASON_KEY.self = \"reasonSelf\"\n",
       "",
       "self: reason line a passer-by's",
       expect="the reason line reads", script=S)

mutate("Prompt/Button.lua",
       "\telseif entry.reason == \"self\" then\n\t\t-- Offered to you only on a reading",
       "\telseif false then\n\t\t-- Offered to you only on a reading",
       "self: tooltip calls you nearby",
       expect="the tooltip does not say it is your own and missing", script=S)

mutate("Prompt/Button.lua",
       "\t\tGameTooltip:AddLine(entry.reason == \"self\" and L[\"Yours expires in %s.\"]:format(left)\n",
       "\t\tGameTooltip:AddLine(false and L[\"Yours expires in %s.\"]:format(left)\n",
       "self: tooltip says theirs of yours",
       expect="the tooltip does not say when yours runs out", script=S)

mutate("Prompt/Macro.lua",
       "\tif entry.reason == \"self\" then\n\t\t-- Nothing about targets: the macro hands your target back (see\n",
       "\tif false then\n\t\t-- Nothing about targets: the macro hands your target back (see\n",
       "self: tooltip says it targets you",
       expect="the tooltip does not say it is cast on you", script=S)

mutate("Prompt/Button.lua",
       "\t\telseif S.current.reason == \"self\" then\n\t\t\t-- The switch, since the list is of other people (StopOfferingSelf).\n",
       "\t\telseif false then\n\t\t\t-- The switch, since the list is of other people (StopOfferingSelf).\n",
       "self: tooltip offers you the never list",
       expect="the tooltip does not say what shift-right-click does to you", script=S)

mutate("Prompt/Prompt.lua",
       "REASON_COLOR.self = REASON_COLOR.group\n",
       "",
       "self: standard colour a passer-by's",
       expect="in the standard palette you are", script=S)

mutate("Prompt/Prompt.lua",
       "REASON_COLOR_CVD.self = REASON_COLOR_CVD.group\n",
       "",
       "self: colour-blind colour a passer-by's",
       expect="in the colourblind palette you are", script=S)

# --- the press ---

# Retired: "self: macro targets you" dropped the self strategy, which since
# the press targets you by name (not [@player]) arms the same macro as the
# target strategy, and the press is still parked as yours from the entry's
# reason. Nothing observable changes, so there is nothing to catch; the two
# mutations below are what the strategy now guards against.

# A bare /cast: with a friendly player targeted, it lands on them.
mutate("Prompt/Macro.lua",
       "\tlocal lines = STRATEGIES.target(entry, spell)\n"
       "\tlocal restore = not StillTargeted(entry) or Prompt.armedForFight == true\n",
       "\tlocal lines, restore = { \"/cast \" .. spell }, false\n",
       "self: cast with no unit",
       expect="the macro reads", script=S)

# [@player]: conditional targeting does not resolve on WoW Forever.
mutate("Prompt/Macro.lua",
       "\tlocal lines = STRATEGIES.target(entry, spell)\n"
       "\tlocal restore = not StillTargeted(entry) or Prompt.armedForFight == true\n",
       "\tlocal lines, restore = { \"/cast [@player] \" .. spell }, false\n",
       "self: cast by [@player]",
       expect="the macro reads", script=S)

mutate("Speech.lua",
       "\t\tif entry.reason == \"self\" then return nil end\n",
       "",
       "self: a line said to yourself",
       expect="the macro reads", script=S)

mutate("Prompt/Press.lua",
       "\t\tonSelf = (S.armed ~= nil and S.armed.onSelf == true) or S.current.reason == \"self\",\n",
       "",
       "self: press not parked as yours",
       expect="the press was not parked as one on yourself", script=S)

# A /manners try macro arms no record, so only the entry says it is you.
mutate("Prompt/Press.lua",
       "\t\tonSelf = (S.armed ~= nil and S.armed.onSelf == true) or S.current.reason == \"self\",\n",
       "\t\tonSelf = S.armed ~= nil and S.armed.onSelf == true,\n",
       "self: a try press on you files a gift",
       expect="a /manners try press on yourself wrote", script=S)

# Settled as a press on somebody else: the ledger writes a row under you.
mutate("Clicks.lua",
       "\tif pending.onSelf then return SettleSelf(pending, spellId, castGUID) end\n",
       "",
       "self: press filed in the ledger",
       expect="the press wrote", script=S)

# The retry cooldown not written back after the settle.
mutate("Clicks.lua",
       "\tShowOutcome(\"cast\", pending.name)\n\tns.MarkAttempted(pending.name, pending.buffKey)\n",
       "\tShowOutcome(\"cast\", pending.name)\n",
       "self: no cooldown after a press",
       expect="left you only its two seconds of cooldown", script=S)

# Your own buff landing taken for a favour from you.
mutate("Favours.lua",
       "\t\tif not source or source == \"player\" then return end\n\t\tif plain(UnitIsUnit(source, \"player\")) then return end\n",
       "\t\tif not source then return end\n",
       "self: your own buff a favour",
       expect="your own buff filed a favour from you", script=S)

# A different spell going out taken for your buff.
mutate("Clicks.lua",
       "\tif not SpellIsOurs(spellId, pending.buffKey) then\n\t\tlocal why = L[\"|cffffffff%s|r went out instead\"]:format(SpellLabel(spellId))\n\t\tSayStillOwed(pending.name, why)\n",
       "\tif false then\n\t\tlocal why = L[\"|cffffffff%s|r went out instead\"]:format(SpellLabel(spellId))\n\t\tSayStillOwed(pending.name, why)\n",
       "self: any spell counts as yours",
       expect="a Frostbolt was taken for your buff", script=S)

mutate("Clicks.lua",
       "\telseif ns.IsPlayerName(name) then\n\t\t-- A press on yourself",
       "\telseif false then\n\t\t-- A press on yourself",
       "self: refusal names you like a stranger",
       expect="the refusal reads", script=S)

mutate("Prompt/Paint.lua",
       "\tlocal own = ns.IsPlayerName(S.outcomeName)\n",
       "\tlocal own = false\n",
       "self: outcome names you like a stranger",
       expect="the panel reads", script=S)

# --- right-click and the menu ---

mutate("Prompt/Press.lua",
       "\t\tif IsShiftKeyDown and ns.plain(IsShiftKeyDown()) and own then\n",
       "\t\tif false then\n",
       "self: shift-right-click lists you",
       expect="shift-right-click left the switch on", script=S)

mutate("Prompt/Press.lua",
       "\t\tif db and db.verbose and own then\n",
       "\t\tif false then\n",
       "self: skip names you like a stranger",
       expect="the skip reads", script=S)

mutate("Queue.lua",
       "\tdb.sources.self = false\n\taddon:Print(",
       "\taddon:Print(",
       "self: stopping leaves the switch on",
       expect="shift-right-click left the switch on", script=S)

mutate("Options/Launcher.lua",
       "\tif reason == \"self\" then return own end\n",
       "",
       "self: launcher calls you nearby",
       expect="the launcher's tooltip reads", script=S)

mutate("Options/Launcher.lua",
       "\tif entry.reason == \"self\" then\n\t\tns.addon:Print(L[\"skipping your own buff for now.\"])\n",
       "\tif false then\n\t\tns.addon:Print(L[\"skipping your own buff for now.\"])\n",
       "self: menu skip names you like a stranger",
       expect="Skip for now on you reads", script=S)

mutate("Options/Launcher.lua",
       "\tif entry.reason == \"self\" then\n\t\tns.StopOfferingSelf()\n",
       "\tif false then\n\t\tns.StopOfferingSelf()\n",
       "self: menu never lists you",
       expect="Never offer on you did not switch your own buff off", script=S)

# --- the group cast ---

# You never counted into your party: the fold only takes group members.
mutate("Queue.lua",
       "\t\tinGroup = (plain(GetNumGroupMembers and GetNumGroupMembers()) or 0) > 0,\n\t\tpriority = PRIORITY.self,\n",
       "\t\tinGroup = false,\n\t\tpriority = PRIORITY.self,\n",
       "self: not counted into your party",
       expect="made no group cast", script=S)

mutate("GroupBuffs.lua",
       "\tif (a.reason == \"self\") ~= (b.reason == \"self\") then return b.reason == \"self\" end\n",
       "",
       "self: group cast aimed at you",
       expect="made no group cast", script=S)

mutate("GroupBuffs.lua",
       "\tif anchor.reason == \"self\" then return nil end\n",
       "",
       "self: group cast for you alone",
       expect="a group cast was made, aimed at", script=S)

mutate("Clicks.lua",
       "\t\t\tif not record.owed and not ns.IsPlayerName(record.name) then\n",
       "\t\t\tif not record.owed then\n",
       "self: group cast files a gift to you",
       expect="the ledger filed a", script=S)

# --- saved settings and the options page ---

mutate("Core.lua",
       "\tboolean(profile.sources, \"self\", true)\n",
       "",
       "self: nonsense switch kept",
       expect="a nonsense switch was kept", script=S)

mutate("Core.lua",
       "\"reasonGroup\", \"reasonSelf\",\n",
       "\"reasonGroup\",\n",
       "self: broken wording kept",
       expect="a broken wording was kept", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\t\tor OffersSelf()\n",
       "",
       "self: warning forgets you",
       expect="with only yourself on, the page says", script=S)

mutate("Options/Start.lua",
       "\tif own then\n\t\twho[#who + 1] =",
       "\tif false then\n\t\twho[#who + 1] =",
       "self: summary forgets you",
       expect="the summary on Start here leaves you out", script=S)

mutate("Options/Who.lua",
       "\t\t\t\torder = 15.1,\n\t\t\t\twidth = \"full\",\n\t\t\t\thidden = NothingForSelf,\n",
       "\t\t\t\torder = 15.1,\n\t\t\t\twidth = \"full\",\n",
       "self: switch shown to a warrior",
       expect="the Myself switch is shown to a warrior", script=S)

mutate("Options/Advanced.lua",
       "\t\t{ \"prompt\", \"reasonSelf\" },\n",
       "",
       "self: reset keeps your wording",
       expect="Put these back to default kept", script=S)

mutate("Options/Diagnostics.lua",
       "\t\ttostring(db.sources.self),\n",
       "\t\t\"?\",\n",
       "self: bug report leaves the switch out",
       expect="the bug report leaves the switch out", script=S)

mutate("Commands.lua",
       "\t\tif not db.sources.self then\n",
       "\t\tif true then\n",
       "self: debug says the switch is off",
       expect="/manners debug does not say your own buff is offered", script=S)

# --- saving mana keeps your own buff, and says so ---

mutate("Prompt/Button.lua",
       "\t\tGameTooltip:AddLine((ns.OffersSelf()\n",
       "\t\tGameTooltip:AddLine((false\n",
       "self: saving-mana tooltip leaves you out",
       expect="the tooltip under your own buff says", script=S)

mutate("Commands.lua",
       "\t\t\tself:Print((ns.OffersSelf()\n",
       "\t\t\tself:Print((false\n",
       "self: saving-mana debug leaves you out",
       expect="/manners debug while saving mana leaves your own buff out", script=S)

mutate("Prompt/Press.lua",
       "\t\t\tlocal line = ns.OffersSelf()\n",
       "\t\t\tlocal line = false\n",
       "self: saving-mana empty press leaves you out",
       expect="an empty press while saving mana leaves your own buff out", script=S)

mutate("Options/When.lua",
       "\t\t\t\t\treturn OffersSelf() and L[\"Below this, only your own buff",
       "\t\t\t\t\treturn false and L[\"Below this, only your own buff",
       "self: mana floor description leaves you out",
       expect="the mana floor's description leaves your own buff out", script=S)

mutate("Options/When.lua",
       "\t\t\t\t\telseif OffersSelf() then\n",
       "\t\t\t\t\telseif false then\n",
       "self: mana note leaves you out",
       expect="the mana note leaves your own buff out", script=S)

# The switch not asked: every line keeps your own buff with it off.
mutate("Core.lua",
       "\treturn db ~= nil and db.sources.self == true\n\t\tand (#ns.SelfBuffs()",
       "\treturn db ~= nil\n\t\tand (#ns.SelfBuffs()",
       "self: saving-mana lines ignore the switch",
       expect="with Myself off, a line still keeps your own buff", script=S)

# --- Start here ---

mutate("Options/Start.lua",
       "\t\t[\"filters.whenBuffed\"] = \"skip\", [\"sources.self\"] = false,\n",
       "\t\t[\"filters.whenBuffed\"] = \"skip\",\n",
       "self: Only people who buff me offers you",
       expect="Only people who buff me left you offered", script=S)

mutate("Options/Start.lua",
       "\t\t[\"filters.whenBuffed\"] = \"skip\", [\"sources.self\"] = false,\n\t}, applyOnly = { [\"sources.self\"] = true } },\n",
       "\t\t[\"filters.whenBuffed\"] = \"skip\", [\"sources.self\"] = false,\n\t} },\n",
       "self: an old profile shows Custom",
       expect="a profile from before 1.2 shows", script=S)

mutate("Options/Start.lua",
       "\t\t[\"filters.whenBuffed\"] = \"skip\", [\"sources.self\"] = true,\n",
       "\t\t[\"filters.whenBuffed\"] = \"skip\",\n",
       "self: moving on from favours leaves you out",
       expect="moving on from Only people who buff me to group left you out", script=S)

mutate("Options/Start.lua",
       "\t\t[\"sources.self\"] = true,\n\t}, applyOnly = { [\"filters.proximity\"] = true, [\"sources.self\"] = true } },\n",
       "\t\t[\"sources.self\"] = true,\n\t}, applyOnly = { [\"filters.proximity\"] = true } },\n",
       "self: switching yourself off leaves the preset",
       expect="switching Myself off on nearby shows", script=S)

# --- the other lines about a press on you ---

mutate("Prompt/Paint.lua",
       "\tif top.reason == \"self\" then\n",
       "\tif false then\n",
       "self: moved-on names you like a stranger",
       expect="the moved-on line reads", script=S)

# `unknown` asked before you, as it was.
mutate("Clicks.lua",
       "\telseif ns.IsPlayerName(name) then\n\t\t-- A press on yourself",
       "\telseif unknown then\n\t\taddon:Print(unknown:format(name))\n\telseif ns.IsPlayerName(name) then\n\t\t-- A press on yourself",
       "self: abandoned press names you like a stranger",
       expect="the abandoned press reads", script=S)

mutate("Clicks.lua",
       ",\n\t\tL[\"no answer yet for the press on yourself -- another press arrived first.\"])\n",
       ")\n",
       "self: abandoned press says you were not buffed",
       expect="the abandoned press reads", script=S)

mutate("Queue.lua",
       "\t\tif ns.IsPlayerName(name) then\n\t\t\taddon:Print(type(why) == \"string\"\n",
       "\t\tif false then\n\t\t\taddon:Print(type(why) == \"string\"\n",
       "self: back-off names you like a stranger",
       expect="the back-off line reads", script=S)

mutate("Clicks.lua",
       "\tif pending.answered then\n\t\tlocal db = addon.db and addon.db.profile\n\t\tif db and db.verbose then\n\t\t\taddon:Print(L[\"|cffffd100you were buffed after all|r",
       "\tif false then\n\t\tlocal db = addon.db and addon.db.profile\n\t\tif db and db.verbose then\n\t\t\taddon:Print(L[\"|cffffd100you were buffed after all|r",
       "self: not buffed never taken back",
       expect="after an error and the cast going out, chat reads", script=S)

# --- a Greater Blessing and your own other blessing ---

mutate("GroupBuffs.lua",
       "\tif class == ns.PlayerClass() then\n\t\tlocal name = ns.UnitFullName(\"player\")\n",
       "\tif false then\n\t\tlocal name = ns.UnitFullName(\"player\")\n",
       "self: Greater Blessing over your own Kings",
       expect="was offered over your own Kings", script=S)

# --- under the cursor ---

# Not offered to you, and the cursor on the panel: no verdict written, so the
# cursor holds "You" up after you buffed yourself by hand (the merge of the
# linger work, BuildQueue).
mutate("Queue.lua",
       "\t\tif me then rejected[me] = true end\n",
       "",
       "self: a hovered You held for the cursor",
       expect="stayed up for the cursor", script=S)
