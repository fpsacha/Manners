# Ledger milestones' load-bearing parts, each put back wrong and required to be
# caught by the scenario in tests/scenarios/milestones.lua written for it (the
# layout ones by tests/scenarios/ledgerui.lua, which lays the window out).
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# Where the titles start, and which one a count holds.
mutate("Ledger.lua",
       "\t{ at = 100, name = L[\"Gracious\"],",
       "\t{ at = 90, name = L[\"Gracious\"],",
       "milestones: a title starts at the wrong count",
       expect="milestones: the titles and the way to the next", script=S)
mutate("Ledger.lua",
       "\t\tif Count(returned) >= t.at then level = i end\n",
       "\t\tif Count(returned) > t.at then level = i end\n",
       "milestones: a title one favour late",
       expect="milestones: the titles and the way to the next", script=S)
mutate("Ledger.lua",
       "\t\treturn TEXT.BROKER_FIRST:format(rank.returned, rank.next.at, rank.next.name)\n",
       "\t\treturn TEXT.BROKER_FIRST:format(rank.returned, rank.next.at, TITLES[2].name)\n",
       "milestones: the first title misnamed before it",
       expect="milestones: the titles and the way to the next", script=S)

# The announcement: made at all, made with chat lines off, and made once.
mutate("Ledger.lua",
       "\t\tBump(s, \"returned\")\n\t\tPromote(s)\n",
       "\t\tBump(s, \"returned\")\n",
       "milestones: a new title is never announced",
       expect="milestones: a new title is said once in chat", script=S)
mutate("Ledger.lua",
       "\tif ns.addon and ns.addon.Print then ns.addon:Print(TEXT.EARNED",
       "\tif ns.db.profile.verbose and ns.addon and ns.addon.Print then ns.addon:Print(TEXT.EARNED",
       "milestones: the announcement obeys chat lines",
       expect="milestones: a new title is said once in chat", script=S)
mutate("Ledger.lua",
       "\tif level <= (s.title or 0) then return end\n",
       "\tif level < (s.title or 0) then return end\n",
       "milestones: a title held is announced again",
       expect="milestones: a title taken back and earned again is not said twice", script=S)
mutate("Ledger.lua",
       "\tif level <= (s.title or 0) then return end\n\ts.title = level\n",
       "\tif level <= (s.title or 0) then return end\n",
       "milestones: the title announced is not remembered",
       expect="milestones: a title taken back and earned again is not said twice", script=S)

# The wait before a title is said: Core settles when the cast is sent, and a
# refusal can still take the favour back.
mutate("Ledger.lua",
       "\tif not (C_Timer and C_Timer.After) then return Announce(s) end\n",
       "\tif true then return Announce(s) end\n",
       "milestones: a title said before the refusal can come",
       expect="milestones: a title waits out the refusal of the cast that earned it", script=S)
mutate("Ledger.lua",
       "\tif not (C_Timer and C_Timer.After) then return Announce(s) end\n",
       "\tif not (C_Timer and C_Timer.After) then return end\n",
       "milestones: no timer, no title said",
       expect="milestones: without a timer a title is said at once", script=S)
mutate("Ledger.lua",
       "\tif left and left > 0 then\n\t\tC_Timer.After(left, function() ns.Guard(\"ledger title\", PromoteDue) end)\n"
       "\t\treturn\n\tend\n",
       "",
       "milestones: a later favour does not get its own wait",
       expect="milestones: a title taken back and earned again is not said twice", script=S)
mutate("Ledger.lua",
       "\tpromoteAt = nil\n\tlocal s = Store()\n",
       "\tlocal s = Store()\n",
       "milestones: the wait never ends, no later title said",
       expect="milestones: a title taken back and earned again is not said twice", script=S)
mutate("Ledger.lua",
       "\ts.entries = kept\n\ts.today = nil\n\tChanged()\n",
       "\ts.entries = kept\n\ts.today = nil\n\ts.title = 0\n\tChanged()\n",
       "milestones: Clear forgets the titles announced",
       expect="milestones: Clear keeps the title", script=S)

# An old ledger's back catalogue, taken quietly, and a damaged mark.
mutate("Ledger.lua",
       "\t\ts.title = TitleLevel(totals.returned)\n",
       "\t\ts.title = 0\n",
       "milestones: an old ledger's titles all announced",
       expect="milestones: an old ledger takes its title quietly", script=S)
mutate("Ledger.lua",
       "\t\ts.title = math.min(title, #TITLES)\n",
       "\t\ts.title = title\n",
       "milestones: a mark past the last title kept",
       expect="milestones: a damaged mark is repaired quietly", script=S)
mutate("Ledger.lua",
       "\tlocal title = s.title\n\tif Whole(title) then\n",
       "\tlocal title = s.title\n\tif type(title) == \"number\" then\n",
       "milestones: a mark that is no whole number kept",
       expect="milestones: a damaged mark is repaired quietly", script=S)

# The window and the minimap tooltip.
mutate("Ledger.lua",
       "\tPaintRank(sum)\n",
       "",
       "milestones: the window never paints the title",
       expect="milestones: the window and the minimap tooltip show the title", script=S)
mutate("Ledger.lua",
       "\ttooltip:AddLine(Ledger.RankText(sum), RANK_INK[1], RANK_INK[2], RANK_INK[3], true)\n",
       "",
       "milestones: the minimap tooltip has no title",
       expect="milestones: the window and the minimap tooltip show the title", script=S)
mutate("Ledger.lua",
       "\tr.progress:SetText(rank.next and TEXT.RANK_PROGRESS:format(rank.returned, rank.next.at, rank.next.name)\n",
       "\tr.progress:SetText(rank.next and TEXT.RANK_PROGRESS:format(rank.returned, rank.next.at, rank.title and rank.title.name or \"\")\n",
       "milestones: the way to the next names the title held",
       expect="milestones: the window and the minimap tooltip show the title", script=S)
mutate("Ledger.lua",
       "\t\tshare = (rank.returned - rank.from) / (rank.next.at - rank.from)\n",
       "\t\tshare = rank.returned / rank.next.at\n",
       "milestones: the bar counts from nothing, not the title held",
       expect="milestones: the window and the minimap tooltip show the title", script=S)
mutate("Ledger.lua",
       "\tr.fill:SetShown(share > 0)\n",
       "\tr.fill:SetShown(true)\n",
       "milestones: an empty bar drawn",
       expect="milestones: the window and the minimap tooltip show the title", script=S)
mutate("Ledger.lua",
       "\t\tGameTooltip:AddLine(rank.title.flavour, 1, 1, 1, true)\n",
       "",
       "milestones: hovering the title tells no flavour",
       expect="milestones: the window and the minimap tooltip show the title", script=S)

# The title's place at the top of the window.
mutate("Ledger.lua",
       "local HEADLINE_TOP = -66\n",
       "local HEADLINE_TOP = -46\n",
       "milestones: the headline over the title",
       expect="ledgerui: rows and header are laid out without overlap", script=S)
mutate("Ledger.lua",
       "local RANK_TOP = -37\n",
       "local RANK_TOP = -22\n",
       "milestones: the title in the title band",
       expect="ledgerui: rows and header are laid out without overlap", script=S)
mutate("Ledger.lua",
       "\tr.name:SetPoint(\"TOPRIGHT\", r.progress, \"TOPLEFT\", -8, 2)\n",
       "\tr.name:SetPoint(\"TOPRIGHT\", r, \"TOPRIGHT\", 0, 0)\n",
       "milestones: the title runs under the way to the next",
       expect="ledgerui: rows and header are laid out without overlap", script=S)

# ===========================================================================
# Milestones.lua: the marks of good manners, their toast, tab and switch. Each
# promise undone, and caught by its "milestones: earned:" scenario.
# ===========================================================================

E = "milestones: earned: "

# The ledger tells it: a settle, a refusal, the login, a new title.
mutate("Ledger.lua",
       "\tif ns.Milestones then ns.Guard(\"milestones\", ns.Milestones.Settled, undo.entry, pending) end\n",
       "",
       "milestones: the ledger never tells them of a settle",
       expect=E + "the first favour returned earns one", script=S)
mutate("Ledger.lua",
       "\tif ns.Milestones then ns.Guard(\"milestones\", ns.Milestones.Refused, undo.entry) end\n",
       "",
       "milestones: a refused buff still counts",
       expect=E + "a refused cast earns nothing", script=S)
mutate("Ledger.lua",
       "\tif ns.Milestones then ns.Guard(\"milestones\", ns.Milestones.Load) end\n",
       "",
       "milestones: an old ledger is not read at login",
       expect=E + "an old ledger is marked quietly", script=S)
mutate("Ledger.lua",
       "\tif ns.Milestones then ns.Guard(\"milestones\", ns.Milestones.Ranked, t) end\n",
       "",
       "milestones: a new title gets no toast",
       expect=E + "a new title gets a toast", script=S)
mutate("Ledger.lua",
       "FILTERS.milestones = true\n",
       "",
       "milestones: the ledger has no such tab",
       expect=E + "the tab lists them", script=S)

# Counted only once the server could no longer refuse the cast.
mutate("Milestones.lua",
       "\tif not (C_Timer and C_Timer.After) then\n\t\tw.clock = w.clock - (Ledger.PROMOTE_SECONDS or 3)\n",
       "\tif true then\n\t\tw.clock = w.clock - (Ledger.PROMOTE_SECONDS or 3)\n",
       "milestones: earned at the press",
       expect=E + "the first favour returned earns one", script=S)
mutate("Milestones.lua",
       "\tif not Setting(\"sound\") or type(_G.PlaySound) ~= \"function\" then return end\n",
       "\tif type(_G.PlaySound) ~= \"function\" then return end\n",
       "milestones: the fanfare ignores its switch",
       expect=E + "a refused cast earns nothing", script=S)

# Quiet for an old ledger, and nothing to be had by turning the switch.
mutate("Milestones.lua",
       "\tlocal had = Evaluate(st, true)\n",
       "\tlocal had = Evaluate(st, false)\n",
       "milestones: an old ledger is toasted at login",
       expect=E + "an old ledger is marked quietly", script=S)
mutate("Milestones.lua",
       "local function On()\n\treturn Setting(\"enabled\")\nend\n",
       "local function On()\n\treturn true\nend\n",
       "milestones: the master switch switches nothing off",
       expect=E + "switched off, nothing is counted", script=S)
mutate("Milestones.lua",
       "\t\t\tif st.seeded then Evaluate(st, true) else Begin(st) end\n",
       "\t\t\tif st.seeded then Evaluate(st, false) else Begin(st) end\n",
       "milestones: switching back on toasts what was passed",
       expect=E + "switched off, nothing is counted", script=S)
mutate("Milestones.lua",
       "\treturn on and filter == \"milestones\" and M or nil\n",
       "\treturn filter == \"milestones\" and M or nil\n",
       "milestones: the tab's page answers while off",
       expect=E + "switched off, nothing is counted", script=S)
mutate("Core.lua",
       "\t\tmilestones = { enabled = true, toast = true, sound = true },\n",
       "\t\tmilestones = { enabled = false, toast = true, sound = true },\n",
       "milestones: off by default",
       expect=E + "switched off, nothing is counted", script=S)
mutate("Options/Start.lua",
       "\t\t\t\t\tns.Guard(\"milestones\", ns.Milestones.Switched)\n",
       "",
       "milestones: the switch does not tell them",
       expect=E + "switched off, nothing is counted", script=S)

# Don't be annoying.
mutate("Milestones.lua",
       "\tif InCombatLockdown() then return \"fight\" end\n",
       "",
       "milestones: a toast in a fight",
       expect=E + "a toast waits out a fight and the minute", script=S)
mutate("Milestones.lua",
       "\tif lastShown and now - lastShown < TOAST_GAP then return \"minute\" end\n",
       "",
       "milestones: toasts one after another",
       expect=E + "a toast waits out a fight and the minute", script=S)
mutate("Milestones.lua",
       "\tif InCombatLockdown() then\n\t\tself:Hide()\n\t\treturn\n\tend\n",
       "",
       "milestones: a toast stays up into a fight",
       expect=E + "a toast waits out a fight and the minute", script=S)
mutate("Milestones.lua",
       "\telse\n\t\tself:Hide()\n\t\treturn\n\tend\n\t-- The light behind the icon",
       "\tend\n\t-- The light behind the icon",
       "milestones: a toast never goes by itself",
       expect=E + "a toast waits out a fight and the minute", script=S)
mutate("Milestones.lua",
       "\tif #queue > 0 and not (On() and Setting(\"toast\")) then\n",
       "\tif #queue > 0 and not On() then\n",
       "milestones: Show a toast switches nothing off",
       expect=E + "a toast waits out a fight and the minute", script=S)
mutate("Milestones.lua",
       "\t\tif not up or not Covers(f, prompt) then return end\n",
       "\t\tdo return end\n",
       "milestones: a toast over the prompt",
       expect=E + "a toast is never over the prompt", script=S)

# Never a reward for spam.
mutate("Milestones.lua",
       "\tif not fresh then return end\n",
       "",
       "milestones: the same stranger counted at every press",
       expect=E + "the same stranger counts once", script=S)
mutate("Milestones.lua",
       "\t\tif p.day ~= day then\n",
       "\t\tif true then\n",
       "milestones: the same person counted at every favour",
       expect=E + "the same person counts once a day", script=S)
mutate("Milestones.lua",
       "\tif not st.today.names[name] then\n",
       "\tif true then\n",
       "milestones: one person is ten people in a day",
       expect=E + "the same person counts once a day", script=S)
mutate("Milestones.lua",
       "\tif e.doneAt and e.doneAt - e.at <= SWIFT_SECONDS then st.n.swift = st.n.swift + 1 end\n",
       "\tif e.doneAt then st.n.swift = st.n.swift + 1 end\n",
       "milestones: every favour returned is quick",
       expect=E + "the same person counts once a day", script=S)
mutate("Milestones.lua",
       "\t\t\tif e.state ~= \"returned\" then return false end\n",
       "",
       "milestones: a week with a favour let go is kept",
       expect=E + "a week with every favour returned", script=S)
mutate("Milestones.lua",
       "\treturn favours >= WEEK_FAVOURS and dayCount >= WEEK_DAYS\n",
       "\treturn favours >= WEEK_FAVOURS\n",
       "milestones: a week of four days",
       expect=E + "a week with every favour returned", script=S)
mutate("Milestones.lua",
       "\t\tif clock - c.at > SITTING_SECONDS then cast[other] = nil else total = total + c.reach end\n",
       "\t\ttotal = total + c.reach\n",
       "milestones: a sitting never ends",
       expect=E + "a whole raid buffed in one sitting", script=S)
mutate("Milestones.lua",
       "\tif type(pending) == \"table\" and pending.inGroup == true and plain(_G.IsInRaid and _G.IsInRaid()) == true then\n",
       "\tif type(pending) == \"table\" and plain(_G.IsInRaid and _G.IsInRaid()) == true then\n",
       "milestones: a stranger stands in for a raid member",
       expect=E + "a whole raid buffed in one sitting", script=S)

# The tab, the link, and the other features' milestones.
mutate("Milestones.lua",
       "\trow.link:SetShown(earned)\n",
       "\trow.link:SetShown(true)\n",
       "milestones: a link button on what is not earned",
       expect=E + "the tab lists them", script=S)
mutate("Milestones.lua",
       "\t\t\trow.concealed = def.hidden == true and not row.earnedAt\n",
       "\t\t\trow.concealed = false\n",
       "milestones: a hidden milestone gives itself away",
       expect=E + "the tab lists them", script=S)
mutate("Ledger.lua",
       "\tif row.link then ns.Milestones.Unpaint(row) end\n",
       "",
       "milestones: a favour row keeps a milestone's link",
       expect=E + "the tab lists them", script=S)
mutate("Commands.lua",
       "\t\tfor _, line in ipairs(ns.Milestones and ns.Milestones.Lines() or {}) do self:Print(\"  \" .. line) end\n",
       "",
       "milestones: /manners debug silent about them",
       expect=E + "the tab lists them", script=S)
mutate("Milestones.lua",
       "\tif not def.feature then return true end\n",
       "\tdo return true end\n",
       "milestones: a resurrection for a class with none",
       expect=E + "a resurrection, a cure and a courtesy", script=S)
