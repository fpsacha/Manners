-- Manners -- options: the What I say tab.

local _, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local P, S, SP, spGet = Page.P, Page.S, Page.SP, Page.spGet
local spSet, HasClassBuffs, TAB = Page.spSet, Page.HasClassBuffs, Page.TAB

-- What I say: the social replies to a buff, the /thank and the line that goes
-- out with a cast. Targeting is on Advanced.
function Page.BuildSpeechTab()
	-- The dropdown's own names for two sets, where the set's label alone does
	-- not say what it is. Every other set keeps the label ns.PHRASE_SETS gives.
	local SET_LABEL = {
		roleplay = L["Fantasy (general)"],
		-- The same words as Start here's quick choice for it.
		incharacter = L["In character (fits your race and class)"],
	}
	-- Loading a set: what picking it in the dropdown does, and what Go back to
	-- In character does without asking.
	local function loadSet(value)
		SP().presetChoice = value
		SP().phrases = ns.PhraseSetText(value) or SP().phrases
		ns.Prompt:InvalidateMacro()
		ns.addon:Print(L["loaded the %s lines."]:format(
			ns.PHRASE_SETS[value] and ns.PHRASE_SETS[value].label or value))
	end
	local function speechOff() return not SP().enabled end
	local function inCharacter() return ns.InCharacter and ns.InCharacter.Active(SP()) end
	return {
		type = "group",
		name = TAB.click,
		order = 4,
		hidden = function() return not HasClassBuffs() end,
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
			intro = {
				type = "description",
				order = 1,
				fontSize = "medium",
				name = L["Optional: thank people, or say a line, when you buff them. %s also has quick choices for this."]
					:format(TAB.general) .. "\n",
			},

			speechHeader = { type = "header", name = L["Thanks and speech"], order = 10 },
			-- The other answer to a favour arriving. Its own get and set:
			-- pSet restyles the prompt, and this changes nothing on it.
			thankEmote = {
				type = "toggle",
				name = L["/thank people who buff me"],
				desc = L["Everyone near you sees it; never in combat or instances, and at most once per person every five minutes."],
				order = 11,
				width = "full",
				-- Nobody is noticed buffing you with that source off.
				disabled = function() return not S().owed end,
				get = function() return P().thankEmote end,
				set = function(_, v) P().thankEmote = v end,
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
					return "\n|cffffd100" .. L["In character picks a line when you click, to fit your race, faction, class and the moment. Editing the lines below turns it off."]
						.. "|r\n"
				end,
			},
			phrases = {
				type = "input",
				name = L["Your lines (one per line)"],
				order = 23,
				multiline = 10,
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
						ns.addon:Print(ns.PickPhrase(fake, ns.PhraseBudget(fake))
							or "|cffff8080" .. L["(nothing -- speech off, or no usable lines)"] .. "|r")
					end
				end,
			},
			limits = {
				type = "description",
				order = 25,
				hidden = speechOff,
				name = "\n|cff888888"
					.. L["A line goes out when you click, even if the cast then fails out of range or line of sight."]
					.. "|r",
			},
		},
	}
end
