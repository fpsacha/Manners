-- Manners -- options window: where every control goes (Interface 2).
--
-- A2's stand-in so the window runs on this branch, written from IA.md
-- section 2; B1's Layout.lua replaces it at the merge.

local _, ns = ...
local L = ns.L

ns.WindowLayout = {
	header = {
		preview = "general.previewStart",
		enabled = "general.enabled",
		snooze = { "general.snooze5", "general.snooze15", "general.snooze30", "general.snoozeStop" },
		snoozeTip = "general.snoozeNote",
	},
	strip = {
		lock = "general.lockNow",
		combat = { click = "click.combatNotice", appearance = "appearance.combatNotice", when = "advanced.advCombatNotice" },
	},
	foldCaption = "advanced.advIntro",
	footer = { reset = "advanced.resetAdvanced", build = "diagnostics.buildNote" },
	groups = { { "general" }, { "who", "skip", "when", "click", "appearance" }, { "profiles", "diagnostics" } },
	pages = {
		general = {
			title = L["Start here"],
			icon = "Interface\\Icons\\INV_Misc_Book_09",
			sections = {
				{ key = "general.lead", items = { { "general.noBuffs", standIn = true }, { "general.howItWorks", lead = true } } },
				{ key = "general.who", header = "general.whoHeader",
					items = { "general.quickWho", { "general.quickWhoSummary", standIn = true } } },
				{ key = "general.key", header = "general.keyHeader",
					items = { "general.bindKey", { "general.makeMacro", pair = true }, "general.openBindings", "general.bindStatus" } },
				{ key = "general.ledger", header = "general.ledgerHeader", items = { "general.ledgerSummary", "general.ledgerOpen" } },
				{ key = "general.minimap", header = "general.minimapHeader", items = { "general.minimap", "general.verbose" } },
			},
		},
		who = {
			title = L["Who to buff"],
			icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
			sections = {
				{ key = "who.cast", header = "who.buffsHeader", items = {
					"who.choice",
					{ "who.offer_fortitude", columns = 2 }, { "who.offer_spirit", columns = 2 }, { "who.offer_shadow", columns = 2 },
					{ "who.offer_wisdom", columns = 2 }, { "who.offer_might", columns = 2 }, { "who.offer_kings", columns = 2 },
					{ "who.offer_salvation", columns = 2 }, { "who.offer_light", columns = 2 }, { "who.offer_sanctuary", columns = 2 },
					"who.relevantOnly", { "who.autoNote", standIn = true }, "who.pinNote",
				} },
				{ key = "who.sources", header = "who.sourcesHeader", items = {
					"who.emptyWarning", "who.owed", "who.group", "who.strangers", { "who.strangersNote", standIn = true },
					{ "who.proximity", indent = true }, { "who.restingOnly", indent = true }, "who.asked",
				} },
				{ key = "who.myself", header = "who.myselfHeader", items = {
					"who.self",
					{ "who.own_omen", indent = true }, { "who.own_aspect", indent = true }, { "who.own_trueshot", indent = true },
					{ "who.own_armor", indent = true }, { "who.own_aura", indent = true }, { "who.own_righteousfury", indent = true },
					{ "who.own_innerfire", indent = true }, { "who.own_touchofweakness", indent = true },
					{ "who.own_shadowguard", indent = true }, { "who.own_shield", indent = true },
					{ "who.own_demonarmor", indent = true }, { "who.own_tracking", indent = true },
					{ "who.ownCities", indent = true }, "diagnostics.ownDiag",
				} },
				{ key = "who.group", header = "who.groupHeader", items = {
					"who.groupBuffsUse", { "who.groupBuffsAtLeast", indent = true }, "who.reagentNote",
					{ "who.skipRaidGroups", columns = 4 },
				} },
				{ key = "who.first", header = "who.firstHeader", fold = true,
					items = { "who.target", "who.friends", "who.readyCheck", "who.revived" } },
			},
		},
		skip = {
			title = L["Who to skip"],
			icon = "Interface\\Icons\\Spell_Holy_SealOfSalvation",
			sections = {
				{ key = "skip.lead", items = {
					"who.skipPvP", { "diagnostics.pvpDiag", indent = true }, "who.skipSameClass", "who.requireInRange", "who.minLevel",
				} },
				{ key = "skip.never", header = "who.neverHeader", items = {
					{ composite = "never", ids = { "who.neverNote", "who.neverPick", "who.neverRemove", "who.neverAdd", "who.neverClear" } },
				} },
			},
		},
		when = {
			title = L["When to offer"],
			icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
			sections = {
				{ key = "when.buffed", header = "when.buffedHeader",
					items = { "when.whenBuffed", { "when.refreshUnder", indent = true }, "when.alwaysNote" } },
				{ key = "when.hold", header = "when.wayHeader", items = { "when.hideMounted", "when.manaFloor", "when.manaNote" } },
				{ key = "when.favours", header = "advanced.favoursHeader", items = {
					"advanced.reciprocateWindow", "advanced.owedClassBuffsOnly", "advanced.reachableOnly",
					{ "advanced.graceSeconds", indent = true }, "advanced.keepDebts",
				} },
				{ key = "when.timing", header = "advanced.timingHeader", fold = true,
					items = { "advanced.retryCooldown", "advanced.scanInterval" } },
				{ key = "when.targeting", header = "advanced.targetingHeader", fold = true,
					items = { "advanced.restoreTarget", { "advanced.noTargetNote", standIn = true } } },
			},
		},
		click = {
			title = L["What I say"],
			icon = "Interface\\Icons\\INV_Misc_Note_02",
			sections = {
				{ key = "click.lead", items = { "general.quickVoice", "general.quickVoiceSummary" } },
				{ key = "click.speech", header = "click.speechHeader", items = {
					"click.thankEmote", "click.enabled", { "click.channel", indent = true },
					{ "click.onlyWhenReturning", indent = true }, { "click.linesOff", standIn = true },
				} },
				{ key = "click.lines", header = "click.phrasesHeader", items = {
					"click.preset", "click.phrasesHelp", "click.inCharacterNote", "click.phrases",
					{ "click.backToInCharacter", pair = true }, "click.roll", "click.limits",
				} },
			},
		},
		appearance = {
			title = L["Look"],
			icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_04",
			sections = {
				{ key = "appearance.where", title = L["Where it sits"],
					items = { { "appearance.posPreset", pair = true }, "appearance.locked" } },
				{ key = "appearance.size", header = "appearance.posHeader", items = {
					{ "appearance.scale", pair = true }, "appearance.alpha", { "appearance.width", pair = true }, "appearance.height",
				} },
				{ key = "appearance.style", header = "appearance.styleHeader", items = {
					{ "appearance.style", pair = true }, "appearance.bgColor", "appearance.accentByReason",
					{ "appearance.reasonPalette", pair = true }, "appearance.accentColor", "appearance.accentMode",
					"appearance.accentDead",
				} },
				{ key = "appearance.attention", header = "appearance.attentionHeader", items = {
					{ "appearance.flashStyle", pair = true }, "appearance.effects", "appearance.hideInCombat",
					"appearance.soundEnabled", { "appearance.soundFile", indent = true },
					{ "appearance.soundOwedOnly", indent = true }, "appearance.noSound",
				} },
				{ key = "appearance.exact", header = "advanced.exactPosHeader", fold = true, items = {
					{ "advanced.x", widget = "number", pair = true }, { "advanced.y", widget = "number" },
				} },
				{ key = "appearance.text", header = "appearance.textHeader", fold = true, items = {
					{ "appearance.font", pair = true }, "appearance.fontSize", { "appearance.fontColor", pair = true },
					"appearance.classColor", "appearance.showSub",
				} },
				{ key = "appearance.wording", header = "advanced.wordingHeader", fold = true, items = {
					"advanced.formatHelp", "advanced.format",
					{ "advanced.reasonTarget", columns = 2 }, { "advanced.reasonOwed", columns = 2 },
					{ "advanced.reasonAsked", columns = 2 }, { "advanced.reasonSelf", columns = 2 },
					{ "advanced.reasonGroup", columns = 2 }, { "advanced.reasonNearby", columns = 2 },
					{ "advanced.reasonRefresh", columns = 2 }, { "advanced.reasonUnknown", columns = 2 },
				} },
				{ key = "appearance.icon", header = "appearance.iconHeader", fold = true, items = {
					"appearance.showIcon", { "appearance.iconSize", indent = true }, "appearance.iconSizeCapped",
					{ "appearance.roundIcon", indent = true }, { "appearance.showCooldown", indent = true },
					"appearance.showCount", "appearance.showQueue", { "appearance.queueRows", indent = true },
				} },
			},
		},
		profiles = {
			title = L["Profiles"],
			icon = "Interface\\Icons\\INV_Misc_GroupNeedMore",
			sections = {
				{ key = "profiles.lead", items = {
					"profiles.profilesIntro", "general.sharedNote", "general.ownProfile", "profiles.current",
					"profiles.choosedesc", { "profiles.new", pair = true }, "profiles.choose", "profiles.copydesc",
					"profiles.copyfrom", "profiles.deldesc", "profiles.delete", "profiles.descreset", "profiles.reset",
				} },
				{ key = "profiles.share", header = "profiles.shareHeader", items = {
					"profiles.shareNote", "profiles.shareCopy", "profiles.shareText", "profiles.sharePaste",
				} },
			},
		},
		diagnostics = {
			title = L["Diagnostics"],
			icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
			sections = {
				{ key = "diagnostics.see", header = "diagnostics.capsHeader",
					items = { "diagnostics.noDiag", "diagnostics.diag", "diagnostics.proximityDiag" } },
				{ key = "diagnostics.errors", header = "diagnostics.errorsHeader",
					items = { "diagnostics.errorList", "diagnostics.noErrors" } },
				{ key = "diagnostics.report", header = "diagnostics.reportHeader",
					items = { "diagnostics.debugClicks", "diagnostics.copyReport", "diagnostics.report" } },
			},
		},
	},
	unplaced = { ["profiles.desc"] = true },
}
