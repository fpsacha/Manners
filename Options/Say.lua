-- Manners -- options: the What I say tab.

local _, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local P, SP, spGet = Page.P, Page.SP, Page.spGet
local spSet, HasClassBuffs, TAB = Page.spSet, Page.HasClassBuffs, Page.TAB

-- The controls a class with nothing to give keeps: the /thank answers being
-- buffed, which happens to a rogue too, the emote it uses, and the header they
-- sit under. Every
-- other control on the tab is about the line said with a cast.
local THANKS_ONLY = { speechHeader = true, thankEmote = true, thankEmoteToken = true, thankWhisper = true }
THANKS_ONLY.thankEmoteMore = true
-- And the pause before either.
THANKS_ONLY.thankDelay = true
-- And thanking somebody nobody could name.
THANKS_ONLY.thankUnseen = true
-- And Ask me before thanking, which holds every thank for a press.
THANKS_ONLY.thankAsk = true
-- And Don't thank anybody while I'm in a party or a raid.
THANKS_ONLY.thankNotInGroup = true
-- And First name only, which the whispered thank-you says too.
THANKS_ONLY.firstNameOnly = true

-- How often my own lines are said (speech.mixedShare; Speech.lua, OwnTurn).
local MIXED_SHARES = { "third", "half", "twothirds", "always" }

-- What I say: the social replies to a buff, the /thank and the line that goes
-- out with a cast. The options window leads the page with Start here's voice
-- choice (general.quickVoice), so the page needs no intro pointing at it.
function Page.BuildSpeechTab()
	-- The dropdown's own names for two sets, where the set's label alone does
	-- not say what it is. Every other set keeps the label ns.PHRASE_SETS gives.
	local SET_LABEL = {
		roleplay = L["Azeroth (general)"],
		-- The same words as Start here's quick choice for it.
		incharacter = L["In character (fits your race and class)"],
	}
	-- Loading a set: what picking it in the dropdown does, and what Go back to
	-- In character does without asking.
	local function loadSet(value)
		SP().presetChoice = value
		SP().phrases = ns.PhraseSetText(value) or SP().phrases
		ns.Prompt:InvalidateMacro()
		ns.addon:Reply(L["loaded the %s lines."]:format(
			ns.PHRASE_SETS[value] and ns.PHRASE_SETS[value].label or value))
	end
	local function speechOff() return not SP().enabled end
	local function inCharacter() return ns.InCharacter and ns.InCharacter.Active(SP()) end
	-- Shown to every class: a hunter or a rogue has the /thank alone on it
	-- (THANKS_ONLY, below).
	local tab = {
		type = "group",
		name = TAB.click,
		order = 4,
		args = {
			-- Everything on this tab is a line in the macro, a secure
			-- attribute the fight has frozen: the macro is rebuilt when the
			-- fight ends, and until then a press runs the old one.
			combatNotice = {
				type = "description",
				order = 0.5,
				fontSize = "medium",
				hidden = function() return not InCombatLockdown() end,
				name = "|cffffd100" .. L["In combat: changes here apply once the fight ends."] .. "|r\n",
			},

			-- The same line for Quiet times (layout.lua counts a strip path as a
			-- placement, so the page needs an entry of its own).
			quietCombatNotice = {
				type = "description",
				order = 0.51,
				fontSize = "medium",
				hidden = function() return not InCombatLockdown() end,
				name = "|cffffd100" .. L["In combat: changes here apply once the fight ends."] .. "|r\n",
			},

			speechHeader = { type = "header", name = L["Thanks and speech"], order = 10 },
			-- The other answer to a favour arriving. Its own get and set:
			-- pSet restyles the prompt, and this changes nothing on it. Live
			-- with People who buff me off: either switch has the favour noticed.
			thankEmote = {
				type = "toggle",
				name = L["/thank people who buff me"],
				desc = L["Everyone near you sees it; never in combat or inside a dungeon or a raid, in a battleground or an arena only for your own team, and at most once per person every five minutes."],
				order = 11,
				width = "full",
				get = function() return P().thankEmote end,
				set = function(_, v) P().thankEmote = v end,
			},
			-- Which emote the switch above makes. The slash commands are not translated.
			thankEmoteToken = {
				type = "select",
				name = L["Emote to use"],
				order = 11.5,
				values = function()
					local values = {}
					for _, token in ipairs(ns.THANK_EMOTES) do values[token] = "/" .. token:lower() end
					return values
				end,
				sorting = function() return ns.THANK_EMOTES end,
				disabled = function() return not P().thankEmote end,
				get = function() return P().thankEmoteToken end,
				set = function(_, v) P().thankEmoteToken = v end,
			},
			-- Others to pick from at random, the one above always among them
			-- (Favours.lua, ns.ThankEmoteToken).
			thankEmoteMore = {
				type = "multiselect",
				name = L["Or one of these, at random"],
				desc = L["Each thank-you uses the emote above or one of the ones ticked here, picked at random, so it is not the same every time."],
				order = 11.55,
				values = function()
					local values = {}
					for _, token in ipairs(ns.THANK_EMOTES) do
						if token ~= P().thankEmoteToken then values[token] = "/" .. token:lower() end
					end
					return values
				end,
				disabled = function() return not P().thankEmote end,
				get = function(_, token) return P().thankEmoteMore[token] == true end,
				set = function(_, token, on) P().thankEmoteMore[token] = on and true or nil end,
			},
			-- Asked for on CurseForge: a thank at the very moment a buff lands
			-- reads as an addon's. Off, since somebody buffing in passing on a
			-- mount may be gone by the end of the pause (Favours.lua). The
			-- whisper waits too, so it is live while either switch is on.
			thankDelay = {
				type = "toggle",
				name = L["Wait a moment before thanking"],
				desc = L["The /thank and the whispered thank-you go out a second or three after the buff lands, so they seem less automatic. If they have gone out of sight by then, or a fight has started, nothing is sent."],
				order = 11.6,
				width = "full",
				-- Greyed too while the thanks wait for a press, which is no pause.
				disabled = function() return not (P().thankEmote or P().thankWhisper) or P().thankAsk == true end,
				get = function() return P().thankDelay end,
				set = function(_, v) P().thankDelay = v end,
			},
			-- Asked for on CurseForge: a thank sent by itself does not feel
			-- personal, and a press of your own adds that touch (ThankPress.lua).
			-- Every thank above waits for a press of the prompt. Live while either
			-- the /thank or the whisper is on.
			thankAsk = {
				type = "toggle",
				name = L["Ask me before thanking"],
				desc = L["Nothing goes out by itself: when somebody buffs you, the prompt offers to thank them, and your thank emote and whispered thank-you go only when you press it (a click, or the prompt's key). Left alone, the offer goes away after twenty seconds, and a fight drops it. A favour you owe or a buff your group needs comes first."],
				order = 11.65,
				width = "full",
				disabled = function() return P().thankEmote ~= true and P().thankWhisper ~= true end,
				get = function() return P().thankAsk end,
				set = function(_, v)
					P().thankAsk = v == true
					ns.Guard("thank ask repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},
			-- Asked for on CurseForge: no thanks at all while grouped
			-- (Favours.lua, Held). Live while either thank is on.
			thankNotInGroup = {
				type = "toggle",
				name = L["Don't thank anybody while I'm in a party or a raid"],
				desc = L["While you are in a party or a raid, no /thank and no whispered thank-you go out, to group members or anybody else. In a battleground or an arena, Thank people there decides instead."],
				order = 11.66,
				width = "full",
				disabled = function() return P().thankEmote ~= true and P().thankWhisper ~= true end,
				get = function() return P().thankNotInGroup end,
				set = function(_, v)
					P().thankNotInGroup = v == true
					ns.Guard("thank group repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},
			-- Asked for on CurseForge by a warrior: a word of thanks to whoever
			-- buffs him, with nothing to give back. A whisper, since /say needs
			-- a key press outside an instance. Its own get and set, as above.
			thankWhisper = {
				type = "toggle",
				name = L["Whisper a thank-you to people I can't buff back"],
				desc = L["A line from the In character set, fitting your race and class, whispered to somebody who buffs you when nothing of yours goes back to them. Never in combat, a dungeon or a raid, in a battleground or an arena only to your own team, and at most once per person every five minutes."],
				order = 11.7,
				width = "full",
				get = function() return P().thankWhisper end,
				set = function(_, v) P().thankWhisper = v end,
			},
			-- Asked for on CurseForge by a player who keeps the game's friendly
			-- nameplates off: a buff from somebody the game names to nobody is
			-- thanked all the same, with the emote at nobody (Favours.lua,
			-- ThankUnseen), or by name in a whisper where only the combat log
			-- names them (ThankByName). Live while either switch above is on.
			thankUnseen = {
				type = "toggle",
				name = L["Thank them even when I can't see who it was"],
				desc = L["With friendly nameplates off the game often will not say who buffed you. Then your thank emote goes out with nobody targeted, and on clients that name them in the combat log the whispered thank-you goes by name. Never while you have somebody targeted, never for somebody who may be in your group, and once per buff every five minutes."],
				order = 11.8,
				width = "full",
				disabled = function() return not P().thankEmote and not P().thankWhisper end,
				get = function() return P().thankUnseen end,
				set = function(_, v) P().thankUnseen = v end,
			},
			enabled = {
				type = "toggle",
				name = L["Say a line when I buff someone"],
				order = 12,
				width = "full",
				get = spGet,
				set = spSet,
			},
			channel = {
				type = "select",
				name = L["Where to say it"],
				desc = L["Whisper them sends it only to the person you buff."],
				order = 13,
				disabled = speechOff,
				values = {
					SAY = L["Say"],
					WHISPER = L["Whisper them"],
					EMOTE = L["Emote"],
					PARTY = L["Party"],
					RAID = L["Raid"],
					YELL = L["Yell"],
				},
				sorting = { "SAY", "WHISPER", "EMOTE", "PARTY", "RAID", "YELL" },
				get = spGet,
				set = spSet,
			},
			onlyWhenReturning = {
				type = "toggle",
				name = L["Only when I buff someone back"],
				desc = L["Off, you also speak when you buff someone first."],
				order = 14,
				width = "full",
				disabled = speechOff,
				get = spGet,
				set = spSet,
			},
			-- Asked for by the author: no spoken line in a group, to anybody, a
			-- member or a passer-by (Speech.lua, ns.GroupQuiet). The buff goes out
			-- as before; the /thank, the whispered thank-you and an ask are not
			-- lines said with a cast, and keep their own switches.
			quietInParty = {
				type = "toggle",
				name = L["Say nothing in a party"],
				desc = L["While you are in a party, no line goes out when you buff, to anybody. The buff is still offered and cast."],
				order = 14.1,
				width = "full",
				disabled = speechOff,
				get = spGet,
				set = spSet,
			},
			quietInRaid = {
				type = "toggle",
				name = L["Say nothing in a raid"],
				desc = L["While you are in a raid, no line goes out when you buff, to anybody. The buff is still offered and cast."],
				order = 14.2,
				width = "full",
				disabled = speechOff,
				get = spGet,
				set = spSet,
			},
			-- Asked for on CurseForge by a player on a roleplay realm: {name} as
			-- the first word only (Speech.lua, ns.SaidName), in the line said
			-- with a cast and in the whispered thank-you alike, so live while
			-- either is on. Who a whisper goes to keeps the whole name.
			firstNameOnly = {
				type = "toggle",
				name = L["First name only"],
				desc = L["{name} says only the first word of a name: Petra Stonewell is called Petra. A one-word name is said whole, and a whisper still goes to the whole name."],
				order = 14.3,
				width = "full",
				disabled = function() return speechOff() and not P().thankWhisper end,
				get = spGet,
				set = spSet,
			},

			-- A line goes out only to somebody a token names (Press.lua,
			-- HoldLine), and with the game's friendly nameplates off most
			-- passers-by have none, so their lines are held back unseen. Said
			-- only while that is so, and not in /party or /raid, where no line
			-- goes to a passer-by at all (ns.ChannelOpen, asked of somebody
			-- outside your group); the setting changes only on a click.
			platesNote = {
				type = "description",
				order = 14.5,
				hidden = function() return speechOff() or not ns.FriendlyPlatesOff() or not ns.ChannelOpen({}) end,
				name = "|cff888888" .. L["Turn on friendly nameplates so Manners can tell when strangers are in range to hear you."] .. "|r",
			},
			showPlates = {
				type = "execute",
				name = L["Show friendly nameplates"],
				desc = L["The game's own setting, under Nameplates in its options, where you can turn it off again."],
				order = 14.6,
				hidden = function() return speechOff() or not ns.FriendlyPlatesOff() or not ns.ChannelOpen({}) end,
				-- The client refuses the setting in a fight.
				disabled = function() return InCombatLockdown() end,
				func = function()
					if ns.ShowFriendlyPlates() then ns.RefreshOptionsDisplay() end
				end,
			},

			-- In place of the Lines section while nothing is said.
			linesOff = {
				type = "description",
				order = 19.5,
				hidden = function() return not speechOff() end,
				name = "\n|cff888888" .. L["Tick Say a line to choose what you say."] .. "|r\n",
			},
			phrasesHeader = { type = "header", name = L["Lines"], order = 20, hidden = speechOff },
			preset = {
				type = "select",
				name = L["Line set"],
				desc = L["Replaces the lines below."],
				order = 21,
				hidden = speechOff,
				-- It overwrites hand-written lines with no undo.
				confirm = function(_, value)
					return L["Replace everything in the box below with the %s lines?"]:format(
						(ns.PHRASE_SETS[value] and ns.PHRASE_SETS[value].label)
							or tostring(value))
				end,
				values = function()
					local out = {}
					for _, key in ipairs(ns.PHRASE_SET_ORDER) do
						out[key] = SET_LABEL[key] or ns.PHRASE_SETS[key].label
					end
					return out
				end,
				sorting = function() return ns.PHRASE_SET_ORDER end,
				-- Blank once the box has been edited. AceGUI's dropdown only
				-- fires when the item clicked becomes checked, so a set shown
				-- as chosen could not be picked again to reload it.
				get = function()
					local choice = SP().presetChoice or "roleplay"
					if SP().phrases == ns.PhraseSetText(choice) then return choice end
					-- In character is untouched on every character sharing the
					-- profile, though each one's examples differ.
					if ns.InCharacter and ns.InCharacter.Active(SP()) then return choice end
					return nil
				end,
				set = function(_, value) loadSet(value) end,
			},
			phrasesHelp = {
				type = "description",
				order = 22,
				hidden = speechOff,
				name = L["One line is picked at random. Placeholders: {name} their name, {buff} the spell."]
					.. "\n|cff888888"
					.. L["A line too long for a macro is skipped; Try a few shows what would go out."]
					.. "|r",
			},
			inCharacterNote = {
				type = "description",
				order = 22.5,
				hidden = function() return speechOff() or not inCharacter() end,
				name = function()
					-- The count first: the box holds a handful of examples, and a
					-- player took them for the whole set.
					return "\n|cffffd100" .. L["In character picks one of its %d lines when you click, to fit your race, faction, class and the moment. The box below shows only a few examples; editing it turns In character off."]
						:format(ns.InCharacter.Count()) .. "|r\n"
				end,
			},
			-- Asked for on CurseForge by a player on a roleplay realm: an In
			-- character line they would rather not hear again, left out of the
			-- pick for good (speech.leftOut; Phrases.lua, RP.Pick). The last line
			-- a press or a whispered thank-you carried is remembered for the
			-- session (RP.Remember, RP.Last), so after a reload the button waits
			-- for the next one; a press that said one of the player's own lines
			-- instead greys it until the next In character line (RP.SaidOwn).
			leaveOutLast = {
				type = "execute",
				name = L["Never say my last line again"],
				desc = function()
					local last = ns.InCharacter and ns.InCharacter.Last()
					-- After one of the player's own lines the last line said is
					-- theirs, not In character's (Phrases.lua, RP.SaidOwn).
					if not last and ns.InCharacter and ns.InCharacter.LastWasOwn() then
						return L["Your last line was one of your own: change it in My own lines, mixed in."]
					end
					if not last then return L["No In character line has been said yet this session."] end
					return L["Leaves this line out of In character for good: %s"]:format(last)
				end,
				order = 22.6,
				hidden = speechOff,
				disabled = function()
					local last = inCharacter() and ns.InCharacter.Last()
					if not last then return true end
					local list = SP().leftOut
					if type(list) ~= "table" or #list >= ns.LEFT_OUT_MAX then return true end
					for _, text in ipairs(list) do
						if text == last then return true end
					end
					return false
				end,
				func = function()
					local last = inCharacter() and ns.InCharacter.Last()
					if not last then return end
					local list = type(SP().leftOut) == "table" and SP().leftOut or {}
					for _, text in ipairs(list) do
						if text == last then return end
					end
					if #list >= ns.LEFT_OUT_MAX then return end
					list[#list + 1] = last
					SP().leftOut = list
					ns.Prompt:InvalidateMacro()
					ns.addon:Reply(L["left out: %s"]:format(last))
				end,
			},
			-- The lines left out, one a row: deleting a row brings the line
			-- back; a row typed by hand that is no line of the set leaves
			-- nothing out. Shown while In character is the set, or while the
			-- list holds anything.
			leftOut = {
				type = "input",
				name = L["Lines left out (one per line)"],
				desc = L["In character never says these lines. Delete a row to hear its line again."],
				order = 22.7,
				multiline = 4,
				width = "full",
				hidden = function()
					if speechOff() then return true end
					local list = SP().leftOut
					return not inCharacter() and not (type(list) == "table" and #list > 0)
				end,
				get = function()
					local list = SP().leftOut
					return type(list) == "table" and table.concat(list, "\n") or ""
				end,
				set = function(_, value)
					local list, seen = {}, {}
					for row in (type(value) == "string" and value or ""):gmatch("[^\r\n]+") do
						row = row:match("^%s*(.-)%s*$")
						if row ~= "" and not seen[row] and #list < ns.LEFT_OUT_MAX then
							seen[row] = true
							list[#list + 1] = row
						end
					end
					SP().leftOut = list
					ns.Prompt:InvalidateMacro()
				end,
			},
			phrases = {
				type = "input",
				name = L["Your lines (one per line)"],
				order = 23,
				-- Tall enough for In character's examples, about 25 lines, to
				-- read without scrolling: at 10 rows a player saw a handful and
				-- took them for the whole set.
				multiline = 26,
				width = "full",
				hidden = speechOff,
				-- Typing over In character's examples makes them your own
				-- lines, and In character stops picking.
				confirm = function()
					if ns.InCharacter and ns.InCharacter.Active(SP()) then
						return L["Editing these turns In character off and uses only your lines. Continue?"]
					end
					return false
				end,
				-- In character shows the examples of whoever is logged in,
				-- whichever character's the shared profile was saved with.
				get = function(info)
					if ns.InCharacter and ns.InCharacter.Active(SP()) then
						return ns.PhraseSetText("incharacter")
					end
					return spGet(info)
				end,
				-- An empty box snaps back to the set the dropdown names, the
				-- way the First line does, since the load-time repair would
				-- refill it anyway: what the box shows is what is kept.
				set = function(info, value)
					if type(value) ~= "string" or value:match("^%s*$") then
						value = ns.PhraseSetText(SP().presetChoice) or ns.PhraseSetText("roleplay")
					end
					spSet(info, value)
				end,
			},
			-- The player's own lines said among the In character ones (Speech.lua,
			-- MixedIn), which the box above cannot hold: typing in it turns In
			-- character off. Shown while In character is the set.
			mixedLines = {
				type = "input",
				name = L["My own lines, mixed in (one per line)"],
				desc = L["With In character as the set, some presses say one of these instead of an In character line: How often my own lines are said, below, says how many. {name} is their name and {buff} is the spell. Leave it empty to hear In character alone."],
				order = 23.2,
				multiline = 6,
				width = "full",
				hidden = function()
					return speechOff() or not (ns.InCharacter and ns.InCharacter.Active(SP()))
				end,
				get = function() return SP().mixedLines or "" end,
				set = function(_, value)
					SP().mixedLines = type(value) == "string" and value or ""
					ns.Prompt:InvalidateMacro()
				end,
			},
			-- How often the lines above are said (Speech.lua, OwnTurn): one press
			-- in three as before, half, two in three, or every press, when In
			-- character speaks only if none of them fits. Shown with the box.
			mixedShare = {
				type = "select",
				name = L["How often my own lines are said"],
				desc = L["How many presses say one of your own lines instead of an In character one. With Every press, In character speaks only when none of your lines fits the macro."],
				order = 23.3,
				hidden = function() return not inCharacter() or speechOff() end,
				values = {
					third = L["About one press in three"],
					half = L["About half the presses"],
					twothirds = L["About two presses in three"],
					always = L["Every press"],
				},
				sorting = MIXED_SHARES,
				get = spGet,
				set = spSet,
			},
			-- The way back from edited lines to In character, which the
			-- dropdown cannot give: it shows the set still chosen as blank.
			backToInCharacter = {
				type = "execute",
				name = L["Go back to In character"],
				order = 23.5,
				hidden = function()
					return speechOff() or SP().presetChoice ~= "incharacter" or inCharacter()
				end,
				func = function() loadSet("incharacter") end,
			},
			roll = {
				type = "execute",
				name = L["Try a few lines"],
				desc = L["Prints sample lines in your chat; only you see them."],
				order = 24,
				hidden = speechOff,
				func = function()
					-- In character speaks differently for each reason, so
					-- it rolls one line per reason.
					if ns.InCharacter and ns.InCharacter.Active(SP()) then
						ns.InCharacter.Roll(L["Somebody"])
						return
					end
					-- reason "owed" so the sample survives the
					-- only-when-returning filter either way. The
					-- stand-in name is read in the lines printed, so it
					-- is in the player's language like the lines are.
					local somebody = L["Somebody"]
					local fake = {
						short = somebody,
						name = somebody,
						reason = "owed",
						buff = ns.ResolveBuff(true),
					}
					for _ = 1, 3 do
						-- The same budget the cast path measures, for a
						-- representative name.
						ns.addon:Reply(ns.PickPhrase(fake, ns.PhraseBudget(fake))
							or "|cffff8080" .. L["(nothing -- speech off, or no usable lines)"] .. "|r")
					end
				end,
			},
			limits = {
				type = "description",
				order = 25,
				hidden = speechOff,
				name = "\n|cff888888"
					.. L["A line goes out only with a buff that can land: in range, ready to cast, and with the mana for it. When Manners cannot tell, the buff goes out without it. Line of sight cannot be checked."]
					.. "|r",
			},
		},
	}
	-- With nothing to give there is no cast for a line to go out with: every
	-- control but THANKS_ONLY's is hidden on top of its own rule, the fight
	-- notice too, since nothing left on the page waits for the fight to end.
	for key, control in pairs(tab.args) do
		if not THANKS_ONLY[key] then
			local own = control.hidden
			control.hidden = function(info)
				if not HasClassBuffs() then return true end
				if type(own) == "function" then return own(info) end
				return own
			end
		end
	end
	return tab
end
