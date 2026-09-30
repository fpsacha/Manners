# Round 13, the options page and the settings string (Options.lua,
# Commands.lua): a character's own profile gone back to rather than copied
# over, the Advanced tab for a hunter, "Tell me in chat" kept through a paste,
# and sliders and key bindings sized to their labels. Each fault is caught by
# the scenario in tests/scenarios/hunt13-fix3.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ a profile of its own

# The profile asked about after the switch, which has just made it: every
# press copies the shared profile over what was set up.
mutate("Options.lua",
       "\t\tlocal kept = Setup.OwnProfileExists()\n\t\tdb:SetProfile(mine)\n",
       "\t\tdb:SetProfile(mine)\n\t\tlocal kept = false\n",
       "hunt13-fix3: going back copies over the own profile",
       expect="going back copied over this character's own profile", script=S)

# An empty own profile taken for one worth going back to.
mutate("Options.lua",
       "\treturn type(own) == \"table\" and next(own) ~= nil\n",
       "\treturn type(own) == \"table\"\n",
       "hunt13-fix3: an empty own profile counts",
       expect="an empty profile of its own counts as one to go back to", script=S)

# The button offered wherever somebody else is on the profile, the alts'
# visit to this character's own included.
mutate("Options.lua",
       "\t\t\t\thidden = function() return not Setup.CanOwnProfile() end,\n",
       "\t\t\t\thidden = function() return Setup.SharedWith() == 0 end,\n",
       "hunt13-fix3: the button on a profile the alts came to",
       expect="the button is offered on a profile the others came to", script=S)

# The press there returning without a word, as it did.
mutate("Options.lua",
       "\t\t\tif Setup.SharedWith() > 0 then\n"
       "\t\t\t\tns.addon:Print(L[\"Your other characters are using this character's settings (profile: %s); they can pick their own on the Profiles tab.\"]:format(mine))\n",
       "\t\t\tif false then\n",
       "hunt13-fix3: a press on the own profile says nothing",
       expect="a press on this character's own profile said nothing", script=S)

# The button naming a copy it no longer makes.
mutate("Options.lua",
       "\t\t\t\t\tif Setup.OwnProfileExists() then return L[\"Go back to this character's own settings\"] end\n",
       "",
       "hunt13-fix3: the button promises a copy",
       expect="with a profile of its own, the button reads", script=S)

# The note saying the settings are shared, on the profile the alts came to.
mutate("Options.lua",
       "\t\t\t\t\tif type(db.keys) == \"table\" and name == db.keys.char then\n",
       "\t\t\t\t\tif false then\n",
       "hunt13-fix3: the note on the own profile",
       expect="the note does not say the others are on this character's profile", script=S)

# ------------------------------------------------ Advanced for a hunter

# The tab back on the old rule.
mutate("Options.lua",
       "\t\t-- other people is hidden inside (NoOthers).\n"
       "\t\thidden = function() return not HasPrompt() end,\n",
       "\t\t-- other people is hidden inside (NoOthers).\n"
       "\t\thidden = function() return not HasClassBuffs() end,\n",
       "hunt13-fix3: Advanced hidden from a hunter",
       expect="the Advanced tab is hidden from a hunter", script=S)

# Handing a target back offered where the switch changes nothing.
mutate("Options.lua",
       "\t\t\t\thidden = function() return NeverTargets() or NoOthers() end,\n",
       "\t\t\t\thidden = NeverTargets,\n",
       "hunt13-fix3: a hunter offered the hand-back switch",
       expect="restoreTarget is shown to a hunter", script=S)

# Another person's reason line shown to a hunter.
mutate("Options.lua",
       "order = 54, hidden = NoOthers, get = pGet",
       "order = 54, get = pGet",
       "hunt13-fix3: a hunter shown the favour's reason line",
       expect="reasonOwed is shown to a hunter", script=S)

# The favours section shown to a hunter.
mutate("Options.lua",
       "\tlocal function NoOthers() return not HasClassBuffs() end\n",
       "\tlocal function NoOthers() return false end\n",
       "hunt13-fix3: a hunter shown the favours",
       expect="favoursHeader is shown to a hunter", script=S)

# Look pointing a rogue at a tab he does not have.
mutate("Options.lua",
       "\t\t\t\t\tif not HasPrompt() then return text end\n",
       "",
       "hunt13-fix3: Look points a rogue at Advanced",
       expect="posPreset points a rogue at an Advanced tab", script=S)

# ...and not pointing a hunter at the wording he now has.
mutate("Options.lua",
       "\t\t\t\thidden = function() return not HasPrompt() end,\n"
       "\t\t\t\tname = \"|cff888888\"\n"
       "\t\t\t\t\t.. L[\"Change what the prompt says: %s.\"]",
       "\t\t\t\thidden = function() return not HasClassBuffs() end,\n"
       "\t\t\t\tname = \"|cff888888\"\n"
       "\t\t\t\t\t.. L[\"Change what the prompt says: %s.\"]",
       "hunt13-fix3: Look hides the wording pointer from a hunter",
       expect="wordingNote is hidden from a hunter", script=S)

# ------------------------------------------------ Tell me in chat

# Shared again: a paste resets it.
mutate("Commands.lua",
       "minimap = true, verbose = true }",
       "minimap = true }",
       "hunt13-fix3: a paste resets Tell me in chat",
       expect="a paste changed Tell me in chat back on", script=S)

# An old string's verbose=0 counted as a later version's setting.
mutate("Commands.lua",
       "\t\t\t\telseif SHARE_SKIP[name:match(\"^[^%.]*\")] or SHARE_SKIP_NAMES[name] then\n",
       "\t\t\t\telseif false then\n",
       "hunt13-fix3: an old string's verbose called newer",
       expect="an old string's verbose=0 was called a newer version's setting", script=S)

# ...or every unknown name dropped without a word along with it.
mutate("Commands.lua",
       "\t\t\t\telseif SHARE_SKIP[name:match(\"^[^%.]*\")] or SHARE_SKIP_NAMES[name] then\n",
       "\t\t\t\telseif true then\n",
       "hunt13-fix3: every unknown name skipped silently",
       expect="a setting no version knows was skipped without a word", script=S)

# ------------------------------------------------ labels

# Sliders left at 170 pixels.
mutate("Options.lua",
       "\t\t\t\tkind = \"range\"\n",
       "\t\t\t\tkind = false\n",
       "hunt13-fix3: sliders not fitted",
       expect="refreshUnder is left at 170 pixels", script=S)

# Key bindings left at 170 pixels.
mutate("Options.lua",
       "\t\t\t\tkind = \"keybinding\"\n",
       "\t\t\t\tkind = false\n",
       "hunt13-fix3: key bindings not fitted",
       expect="bindKey is left at 170 pixels", script=S)

# Measured without the label's room: a width a whole unit short.
mutate("Options.lua",
       "\t\treturn ControlWidth(LabelWidth(option and Asked(option.name, info), font), 6)\n",
       "\t\treturn ControlWidth(LabelWidth(option and Asked(option.name, info), font), -170)\n",
       "hunt13-fix3: sliders fitted a unit short",
       expect="the game cuts it with an ellipsis", script=S)
