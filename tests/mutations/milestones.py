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
