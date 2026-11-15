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
