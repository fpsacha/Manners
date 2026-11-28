-- Manners: Pets -- options owned by the optional module.

local api = assert(MannersAPI, 'Manners is required')
local ns = assert(api:ModuleContext('pets'), 'Manners module API is missing')
local L = ns.L
local function S() return api:GetProfile().sources end

local function AddBeastControls(args)
	local function NotHunter() return not (ns.Beast and ns.Beast.IsHunter()) end
	local function SelfOff() return S().self ~= true end
	local function AllOff() return ns.db.profile.beast.all == false end
	local function BondOff() return AllOff() or ns.db.profile.beast.bond ~= true end
	local function Toggle(key, field, name, desc, order, hidden, disabled)
		args[key] = {
			type = "toggle",
			name = name,
			desc = desc,
			order = order,
			width = "full",
			hidden = hidden or NotHunter,
			disabled = function() return AllOff() or (disabled ~= nil and disabled()) end,
			get = function() return ns.db.profile.beast[field] == true end,
			set = function(_, value)
				ns.db.profile.beast[field] = value == true
				ns.Guard("pet repaint", ns.Prompt.Refresh, ns.Prompt)
			end,
		}
	end

	-- The master, built by hand: Toggle greys a row while it is off.
	args.beastAll = { type = "toggle", name = L["Everything for my pet"],
		desc = L["Off, Manners leaves your pet to you: no care, no moments, no hints and no Mend Pet button in a fight. Each switch below keeps its own setting for when this is on again."],
		order = 15.980, width = "full", hidden = NotHunter,
		get = function() return ns.db.profile.beast.all ~= false end,
		set = function(_, value)
			ns.db.profile.beast.all = value == true
			ns.Guard("pet repaint", ns.Prompt.Refresh, ns.Prompt)
			if ns.MendPet then ns.Guard("mend pet", ns.MendPet.Refresh, ns.MendPet) end
		end }
	Toggle("beastCall", "call", L["Call my pet when none is out"],
		L["Offers Call Pet when no pet is with you. Not in a fight, not while mounted, not in a city unless your own buffs are offered there, and not after you dismissed it yourself."],
		15.981, nil, SelfOff)
	Toggle("beastRevive", "revive", L["Revive my pet when it is dead"],
		L["Offers Revive Pet when your pet has died."], 15.982, nil, SelfOff)
	Toggle("beastFeed", "feed", L["Feed my pet when it is not happy"],
		L["Offers Feed Pet with a food it eats from your bags while it is not happy, and nothing once it is. Food that makes you Well Fed is kept for you."],
		15.983, function() return NotHunter() or not ns.Beast.Feeds() end, SelfOff)
	Toggle("beastMend", "mend", L["Mend my pet when it is hurt after a fight"],
		L["Offers Mend Pet when your pet is badly hurt and the fight is over."], 15.984, nil, SelfOff)
	-- The fight's own Mend Pet button (Prompt/MendPet.lua) has its switch on
	-- Look, In a fight; the same switch sits here too, under the other Mend
	-- Pet one, where a hunter turning Mend Pet off looks for it.
	args.beastMendFight = { type = "toggle", name = L["Show a Mend Pet button in a fight when my pet is badly hurt"],
		desc = L["A button of its own beside the prompt, with its own key. It shows while your pet is under half health, in reach, and Mend Pet is ready. Where the game hides your pet's health in a fight, it shows only with Show the fight buttons set to All fight; its key works either way. A change made in a fight counts from the next one."],
		order = 15.9841, width = "full",
		hidden = function() return not ns.MendPet or NotHunter() or not ns.Beast.KnowsMend() end,
		disabled = AllOff,
		get = function() return ns.db.profile.beast.fightMend ~= false end,
		set = function(_, value)
			ns.db.profile.beast.fightMend = value == true
			if ns.MendPet then ns.Guard("mend pet", ns.MendPet.Refresh, ns.MendPet) end
		end }
	Toggle("beastLeaveFood", "leaveFood", L["Tell me at a vendor when my pet is low on food"],
		L["At a vendor who sells a food your pet eats, a line in chat when your bags hold fewer than five meals for your pet. Once a vendor each session. Manners never buys anything."],
		15.9844, function() return NotHunter() or not ns.Beast.Feeds() end)
	Toggle("beastGrowl", "growl", L["Remind me about Growl in groups and alone"],
		L["A line in chat when Growl is on autocast in a dungeon or raid with a tank in your group (once a zone), or off while you are alone in the open world (once a session). Manners never changes it for you. Off by default: the game does not always say who the tank is."],
		15.9845)
	Toggle("beastTraining", "training", L["Tell me when my pet has training points to spend"],
		L["A line in chat when your pet has training points left unspent: once a session, and again when there are more, at most once in fifteen minutes."],
		15.9846, function() return NotHunter() or not ns.Beast.Trains() end)
	Toggle("beastBond", "bond", L["Bond with my pet"],
		L["Now and then, after a hard fight, a revive, at login or on a quiet road, offers a moment with your pet: an emote for it, and a line from your people when In character is on and lines go in /say. Never in a fight; letting it pass costs nothing."],
		15.985)
	args.beastPace = { type = "select", name = L["How often moments come"],
		desc = L["The least time between two moments with your pet: an hour, twenty minutes or ten. Before one on a quiet road: half an hour, a quarter of an hour or ten minutes."],
		order = 15.9851, hidden = NotHunter, disabled = BondOff,
		values = { rarely = L["Rarely"], sometimes = L["Sometimes"], often = L["Often"] },
		sorting = { "rarely", "sometimes", "often" },
		get = function() return ns.db.profile.beast.pace end,
		set = function(_, value) ns.db.profile.beast.pace = value ns.Guard("pet repaint", ns.Prompt.Refresh, ns.Prompt) end }
	local function Moment(extra) return function() return NotHunter() or BondOff() or (extra ~= nil and extra()) end end
	local feeds = function() return not ns.Beast.Feeds() end
	local MOMENTS = {
		{ "beastPraise", "praise", L["After a hard fight or a boss: well done"] },
		{ "beastComfort", "comfort", L["After a fight your pet barely lived through: comfort"] },
		{ "beastWelcome", "welcome", L["After a revive: welcome back"] },
		{ "beastSorry", "sorry", L["After a revive, when your pet fell in a fight: say sorry"], L["Takes turns with welcome back when both are on; never both at once."] },
		{ "beastHello", "hello", L["At login: hello"] },
		{ "beastMorning", "morning", L["After a night at an inn: good morning"], L["With a line in chat at login that your pet slept by the fire."] },
		{ "beastRoad", "road", L["On a quiet road: a pat"] },
		{ "beastPlay", "play", L["On a quiet road: a game of fetch"], L["Takes turns with the pat when both are on."] },
		{ "beastShare", "share", L["When you sit down to eat: share your meal"], L["While your pet is not happy and a food your pet eats is in your bags: offered once your meal is over, so a press never stands you up."], feeds },
		{ "beastFamily", "family", L["A newly tamed pet: welcome to the family"], L["Right after Tame Beast. If the name is still the kind's (Wolf, Cat), the prompt suggests choosing one."] },
		{ "beastMissed", "missed", L["Back after three days or more apart"] },
		{ "beastSaved", "saved", L["When your pet saved you: thanks"], L["After a fight you ended alive below a fifth of your health, with your pet out from start to end."] },
		{ "beastGrown", "grown", function() return ns.Beast.Loyal() and L["When your pet grows: a level, or more loyalty"] or L["When your pet gains a level"] end },
		{ "beastAnniversary", "anniversary", L["Your days together: 7, 30, 100 and 365"] },
		{ "beastAnswer", "answer", L["My pet answers"], L["After the gesture, how your pet answers, by kind: a wolf wags, an owl hoots."] },
		{ "beastWords", "words", L["Say a line to my pet"], L["With In character on and lines going in /say, a line from your people to your pet with each moment."] },
		{ "beastMilestones", "memory", L["Remember fights, pats and meals, with a line at milestones"], L["What Manners counts of each pet by name, and a line in chat at a milestone. Off, nothing is counted and nothing is said."] },
	}
	for i, row in ipairs(MOMENTS) do Toggle(row[1], row[2], row[3], row[4], 15.987 + i / 10000, Moment(row[5])) end
	args.beastMemory = {
		type = "description",
		order = 15.9899,
		hidden = function() return NotHunter() or BondOff() or ns.db.profile.beast.memory == false end,
		name = function()
			local lines = ns.Beast.MemoryLines()
			if #lines == 0 then return "|cff888888" .. L["No pet remembered yet."] .. "|r" end
			return "|cff888888" .. table.concat(lines, "\n") .. "|r"
		end,
	}
end



-- Moments with a companion pet, for every class (Companion.lua): only where the
-- client has a pet journal that says which one is out.
local function NoJournal()
	local journal = _G.C_PetJournal
	return not (type(journal) == "table" and type(journal.GetSummonedPetGUID) == "function")
end

local function AddCompanionControls(args)
	local function Off() return ns.db.profile.beast.companion ~= true end
	local function Switch(key, field, name, desc, order)
		args[key] = { type = "toggle", name = name, desc = desc, order = order, width = "full",
			hidden = NoJournal, disabled = Off,
			get = function() return ns.db.profile.beast[field] ~= false end,
			set = function(_, value)
				ns.db.profile.beast[field] = value == true
				ns.Guard("companion repaint", ns.Prompt.Refresh, ns.Prompt)
			end }
	end
	args.beastCompanionPace = { type = "select", name = L["How often moments come"],
		desc = L["The least time between two moments with your companion: an hour, twenty minutes or ten. Before one on a quiet road: half an hour, a quarter of an hour or ten minutes."],
		order = 15.98981, hidden = NoJournal, disabled = Off,
		values = { rarely = L["Rarely"], sometimes = L["Sometimes"], often = L["Often"] },
		sorting = { "rarely", "sometimes", "often" },
		get = function() return ns.db.profile.beast.companionPace end,
		set = function(_, value) ns.db.profile.beast.companionPace = value end }
	Switch("beastCompanionHello", "companionHello", L["At login or when I call it: hello"], nil, 15.98982)
	Switch("beastCompanionPraise", "companionPraise", L["After a long fight: well done"],
		L["After a fight of 45 seconds or more, with your companion out from start to end."], 15.98983)
	Switch("beastCompanionRoad", "companionRoad", L["On a quiet road: a pat"], nil, 15.98984)
	Switch("beastCompanionPlay", "companionPlay", L["Standing still a while: we play"],
		L["After a minute or so standing still, not away, out of a fight."], 15.989841)
	Switch("beastCompanionLevel", "companionLevel", L["When I level up: we celebrate"], nil, 15.989842)
	Switch("beastCompanionHome", "companionHome", L["At an inn or a city: a cuddle"], nil, 15.989843)
	Switch("beastCompanionBack", "companionBack", L["Back from the dead: it waited for me"], nil, 15.989844)
	Switch("beastCompanionQuest", "companionQuest", L["A quest handed in: a treat"], nil, 15.989845)
	Switch("beastCompanionAnswer", "companionAnswer", L["My companion answers"],
		L["After the gesture, how your companion answers: it nuzzles closer, chirps, spins with joy."], 15.98985)
	Switch("beastCompanionWords", "companionWords", L["Say a line to my companion"],
		L["With In character on and lines going in /say, something sweet said to your companion with each moment."], 15.98986)
	args.beastCompanion = { type = "toggle", name = L["Moments with my companion"],
		desc = L["Now and then offers a moment with the companion pet that follows you: hello when it comes out, a pat on the road, a game when you stand still, a cuddle at the inn, a treat for a quest, a celebration when you level up. A press does an emote for it, and says something sweet when In character is on and lines go in /say; it targets it by its name and gives your target back. Never in a fight; letting it pass costs nothing."],
		order = 15.9898, width = "full", hidden = NoJournal,
		get = function() return ns.db.profile.beast.companion == true end,
		set = function(_, value)
			ns.db.profile.beast.companion = value == true
			local companion = ns.Beast and ns.Beast.Companion
			if companion then ns.Guard("companion resume", companion.Resume) end
			ns.Guard("companion repaint", ns.Prompt.Refresh, ns.Prompt)
		end }
end

local COMPANION_SECTION = { key = "pet.companion", title = L["My companion"], items = {
	"who.beastCompanion", { "who.beastCompanionPace", indent = true },
	{ "who.beastCompanionHello", indent = true }, { "who.beastCompanionPraise", indent = true },
	{ "who.beastCompanionRoad", indent = true }, { "who.beastCompanionPlay", indent = true },
	{ "who.beastCompanionLevel", indent = true }, { "who.beastCompanionHome", indent = true },
	{ "who.beastCompanionBack", indent = true }, { "who.beastCompanionQuest", indent = true },
	{ "who.beastCompanionAnswer", indent = true },
	{ "who.beastCompanionWords", indent = true },
} }
-- The pieces under the switch, folded into it in the window (Layout.lua, parents).
local function CompanionParents(layout)
	for _, key in ipairs({ "Pace", "Hello", "Praise", "Road", "Play", "Level", "Home", "Back", "Quest", "Answer", "Words" }) do
		layout.parents["who.beastCompanion" .. key] = "who.beastCompanion"
	end
end

	if ns.Beast and not ns.Beast.IsHunter() and not NoJournal() then
		api:RegisterOptionsExtension("who", function(_, args) AddCompanionControls(args) end)
		api:RegisterOptionsPage("pet", function()
			return { type = "group", name = L["My companion"], args = {} }
		end, {
			title = L["My companion"],
			blurb = L["Now and then, a moment with the companion pet that follows you."],
			icon = "Interface\\Icons\\INV_Box_PetCarrier_01",
			sections = { COMPANION_SECTION },
		}, "modules")
		ns.WindowLayout.keywords["who.beastCompanion"] = L["companion pet critter emote moment"]
		CompanionParents(ns.WindowLayout)
	end

	if ns.Beast and ns.Beast.IsHunter() then
		api:RegisterOptionsExtension("who", function(_, args)
			AddBeastControls(args)
			AddCompanionControls(args)
		end)
		local layout = {
			title = L["My pet"],
			blurb = L["Looking after your pet, and the moments you share with it."],
			icon = "Interface\\Icons\\Ability_Hunter_BeastTaming",
			sections = {
				{ key = "pet.care", title = L["Looking after my pet"], items = {
					"who.beastAll",
					{ "who.beastCall", indent = true }, { "who.beastRevive", indent = true },
					{ "who.beastFeed", indent = true }, { "who.beastMend", indent = true },
					{ "who.beastMendFight", indent = true }, { "who.beastLeaveFood", indent = true },
					{ "who.beastGrowl", indent = true }, { "who.beastTraining", indent = true },
					{ "who.beastBond", indent = true }, { "who.beastPace", indent = 2 },
				} },
				{ key = "pet.moments", title = L["Each moment with my pet"], fold = true, items = {
					"who.beastPraise", "who.beastComfort", "who.beastWelcome", "who.beastSorry",
					"who.beastHello", "who.beastMorning", "who.beastRoad", "who.beastPlay",
					"who.beastShare", "who.beastFamily", "who.beastMissed", "who.beastSaved",
					"who.beastGrown", "who.beastAnniversary", "who.beastAnswer", "who.beastWords",
					"who.beastMilestones", { "who.beastMemory", indent = true },
				} },
				COMPANION_SECTION,
			},
		}
		api:RegisterOptionsPage("pet", function()
			return { type = "group", name = L["My pet"], args = {} }
		end, layout, "modules")
		local coreLayout = ns.WindowLayout
		coreLayout.renamedFolds["who.myselfPetMoments"] = "pet.moments"
		local parents = coreLayout.parents
		for _, key in ipairs({ "Call", "Revive", "Feed", "Mend", "MendFight", "LeaveFood", "Growl", "Training", "Bond" }) do
			parents["who.beast" .. key] = "who.beastAll"
		end
		parents["who.beastPace"] = "who.beastBond"
		for _, key in ipairs({ "Praise", "Comfort", "Welcome", "Sorry", "Hello", "Morning", "Road", "Play",
			"Share", "Family", "Missed", "Saved", "Grown", "Anniversary", "Answer", "Words", "Milestones" }) do
			parents["who.beast" .. key] = "who.beastBond"
		end
		parents["who.beastMemory"] = "who.beastMilestones"
		coreLayout.parentsIf["who.beastShare"] = function() return ns.Beast.Feeds() end
		coreLayout.parentsIf["who.beastMendFight"] = function() return ns.Beast.KnowsMend() end
		coreLayout.parentsIf["who.beastLeaveFood"] = function() return ns.Beast.Feeds() end
		coreLayout.parentsIf["who.beastTraining"] = function() return ns.Beast.Trains() end
		coreLayout.keywords["who.beastAll"] = L["hunter pet everything all off"]
		coreLayout.keywords["who.beastCall"] = L["hunter pet call summon"]
		coreLayout.keywords["who.beastRevive"] = L["hunter pet revive dead"]
		coreLayout.keywords["who.beastFeed"] = L["hunter pet feed food happy"]
		coreLayout.keywords["who.beastMend"] = L["hunter pet mend heal"]
		coreLayout.keywords["who.beastMendFight"] = L["hunter pet mend fight button key"]
		coreLayout.keywords["who.beastBond"] = L["hunter pet bond emote memory"]
		coreLayout.keywords["who.beastPace"] = L["hunter pet moments often rarely"]
		coreLayout.keywords["who.beastLeaveFood"] = L["hunter pet vendor food buy"]
		coreLayout.keywords["who.beastGrowl"] = L["hunter pet growl autocast tank"]
		coreLayout.keywords["who.beastTraining"] = L["hunter pet training points"]
		coreLayout.keywords["appearance.mendInFight"] = L["hunter pet mend fight button key"]
		coreLayout.keywords["who.beastCompanion"] = L["companion pet critter emote moment"]
		CompanionParents(coreLayout)
	end
