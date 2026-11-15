# Trust (the weakest-point review of 2026-11-15): a scan that keeps failing is
# shown where a player with chat silenced still looks (tests/scenarios/par-trust.lua).
# Each fault is caught by the scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ a scan that keeps failing

mutate("Core.lua",
       "\tpcall(NoteFailing, label)\n",
       "",
       "par-trust: a repeating fault is never noted",
       expect="par-trust: silent chat, a scan that keeps failing is shown off chat", script=S)

mutate("Options/Launcher.lua",
       "\telseif ns.Broken and ns.Broken() then\n",
       "\telseif false then\n",
       "par-trust: the launcher's state ignores a broken scan",
       expect="par-trust: silent chat, a scan that keeps failing is shown off chat", script=S)

mutate("Options/Launcher.lua",
       "\tif Enabled() and ns.Broken and ns.Broken() then return L[\"%s |cffff4040something broke|r\"]",
       "\tif false then return L[\"%s |cffff4040something broke|r\"]",
       "par-trust: the broker text ignores a broken scan",
       expect="par-trust: silent chat, a scan that keeps failing is shown off chat", script=S)

mutate("Core.lua",
       "\tif not broken.told and db and db.silentChat == true then\n",
       "\tif db and db.silentChat == true then\n",
       "par-trust: the screen line said at every new run",
       expect="par-trust: a scan that recovers takes the mark down", script=S)

mutate("Core.lua",
       "\tif not broken.told and db and db.silentChat == true then\n",
       "\tif not broken.told and db then\n",
       "par-trust: the screen line said over the chat line",
       expect="par-trust: with chat on, the chat line says it and the screen does not", script=S)

mutate("Options/Window/WindowChrome.lua",
       "local STRIP_KINDS = { off = true, broken = true,",
       "local STRIP_KINDS = { off = true, broken = false,",
       "par-trust: the strip says nothing of a broken scan",
       expect="par-trust: the options window's strip says the scan is broken", script=S)

mutate("Core.lua",
       "local BROKEN_AFTER, BROKEN_SECONDS = 3, 10\n",
       "local BROKEN_AFTER, BROKEN_SECONDS = 1, 10\n",
       "par-trust: one failure reads as a broken scan",
       expect="par-trust: one failure does not mark the scan broken", script=S)

mutate("Core.lua",
       "\tif not run or now - run.last > BROKEN_SECONDS then\n",
       "\tif not run then\n",
       "par-trust: failures far apart add up",
       expect="par-trust: one failure does not mark the scan broken", script=S)

mutate("Core.lua",
       "\tif ns.Guard(\"Tick\", addon.TickBody, self) then MendedScan() end\n",
       "\tns.Guard(\"Tick\", addon.TickBody, self)\n",
       "par-trust: a mended scan keeps the mark up",
       expect="par-trust: a scan that recovers takes the mark down", script=S)

mutate("Core.lua",
       "\t\tif run.n >= BROKEN_AFTER and now - run.last <= BROKEN_SECONDS\n",
       "\t\tif run.n >= BROKEN_AFTER\n",
       "par-trust: a broken scan is broken for good",
       expect="par-trust: a scan that recovers takes the mark down", script=S)

# ------------------------------------------- /manners selftest launch, the session

mutate("SelftestLaunch.lua",
       "\t\tfor _, event in ipairs({ \"ADDON_ACTION_BLOCKED\", \"ADDON_ACTION_FORBIDDEN\" }) do\n"
       "\t\t\tpcall(frame.RegisterEvent, frame, event)\n",
       "\t\tfor _, event in ipairs({}) do\n"
       "\t\t\tpcall(frame.RegisterEvent, frame, event)\n",
       "par-trust: nothing listens for the game's refusals",
       expect="par-trust: the launch report lists what the game refused Manners", script=S)

mutate("SelftestLaunch.lua",
       "\t\t\tif who ~= \"Manners\" then return end\n",
       "",
       "par-trust: another addon's refusal is put on Manners",
       expect="par-trust: the launch report lists what the game refused Manners", script=S)

mutate("SelftestLaunch.lua",
       "\tif refused.count == 0 then\n",
       "\tif true then\n",
       "par-trust: a refusal reads as a clean session",
       expect="par-trust: the launch report lists what the game refused Manners", script=S)

mutate("SelftestLaunch.lua",
       "\tlocal okC, city = pcall(function() return ns.InCity and ns.InCity() end)\n",
       "\tlocal okC, city = true, nil\n",
       "par-trust: the town line does not ask the town rule",
       expect="par-trust: the launch report says where the town rule thinks you are", script=S)

mutate("SelftestLaunch.lua",
       "\tif okM ~= true or type(id) ~= \"number\" then\n",
       "\tif okM ~= true then\n",
       "par-trust: no map reads as a map",
       expect="par-trust: the launch report says where the town rule thinks you are", script=S)

mutate("SelftestLaunch.lua",
       "\telseif given < timed then\n",
       "\telseif false then\n",
       "par-trust: a debuff with no expiry reads as fine",
       expect="par-trust: the launch report reads a debuff's timer", script=S)

mutate("SelftestLaunch.lua",
       "\tif timed == 0 then\n\t\tadd(CHECK, line",
       "\tif false then\n\t\tadd(CHECK, line",
       "par-trust: nothing timed reads as a pass",
       expect="par-trust: the launch report reads a debuff's timer", script=S)

mutate("SelftestLaunch.lua",
       "\t\t\t\tlocal ok, aura = pcall(get, unit, i, \"HARMFUL\")\n",
       "\t\t\t\tlocal ok, aura = pcall(get, unit, i, \"HELPFUL\")\n",
       "par-trust: the debuff check reads helpful auras",
       expect="par-trust: the launch report reads a debuff's timer", script=S)

# ------------------------------------------- the gates off Forever (validate.py)

V = "validate.py"

mutate("tests/scenarios.lua",
       "ns = load(\"paladin auto\")\n-- Wisdom and Might are the classic family's and Forever's (hasBuffs).\n"
       "ns = hasBuffs(ns, \"PALADIN\", \"wisdom\", \"might\")\n",
       "ns = load(\"paladin auto\")\n-- Wisdom and Might are the classic family's and Forever's (hasBuffs).\n",
       "par-trust: block 16 stops the main file on Mists and retail again",
       expect="a guard was lost", script=V)

mutate("tests/scenarios.lua",
       "\t\tif not ns.FindBuff(class, (select(i, ...))) then return nil end\n",
       "",
       "par-trust: hasBuffs lets every block through",
       expect="SCENARIO HARNESS ERROR", script=V)

mutate("tools/check.py",
       "        args.lint = args.flavours = args.anchors = args.baselines = True\n",
       "        args.lint = args.flavours = args.anchors = True\n",
       "par-trust: --release leaves the baselines out",
       expect="check.py --release no longer runs --baselines", script=V)

mutate("tools/check.py",
       "            for client in OTHERS for i in range(BASELINE_PARTS)]\n",
       "            for client in OTHERS[1:] for i in range(BASELINE_PARTS)]\n",
       "par-trust: --baselines leaves Classic Era out",
       expect="pieces of vanilla's whole suite", script=V)
