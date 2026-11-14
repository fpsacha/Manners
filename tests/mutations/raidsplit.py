# Mutations for sharing the group with other Manners users (sources.share):
# the hello and the split (Share.lua), the walk's question (Queue.lua, visit),
# the group cast's one caster (GroupBuffs.lua), the addon message handed on
# (Clicks.lua), the tick (Core.lua), the setting (Core.lua, Options/Who.lua,
# Options/Advanced.lua, Options/Window/Layout.lua) and the words (Commands.lua,
# Options/Diagnostics.lua). Each is caught by the scenario in
# tests/scenarios/raidsplit.lua that names it.

S = "runscenarios.py"

# ------------------------------------------------------------ the switch
# Off in a new profile: two users are sent to the same member as before.
mutate("Core.lua",
       "\t\t\tshare = true,\n",
       "\t\t\tshare = false,\n",
       "raidsplit: off in a new profile",
       expect="raidsplit: on in a new profile, and with no other user everybody is offered", script=S)

# The switch off, and the group is split all the same.
mutate("Share.lua",
       "db.sources.group == true and db.sources.share == true\n\t\tand not",
       "db.sources.group == true\n\t\tand not",
       "raidsplit: the switch off still splits the group",
       expect="with the switch off the queue is", script=S)

# The switch turned off, and the split stands until the next hello.
mutate("Share.lua",
       "\tif Sharing() ~= me.on then Share.dirty = true end\n",
       "",
       "raidsplit: the switch turned off waits for a hello",
       expect="the switch turned off, the next scan still leaves Bert his share", script=S)

# Shown with My party and raid off, when it shares nothing.
mutate("Options/Who.lua",
       "\t\t\t\torder = 12.6,\n\t\t\t\twidth = \"full\",\n\t\t\t\thidden = function() return not S().group end,\n",
       "\t\t\t\torder = 12.6,\n\t\t\t\twidth = \"full\",\n",
       "raidsplit: the switch is shown with the group switch off",
       expect="raidsplit: the switch sits under My party and raid, and is reset and repaired", script=S)

# Drawn level with My party and raid, as a source of its own.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.share\", indent = true },\n",
       "\t\t\t\t\t{ \"who.share\" },\n",
       "raidsplit: the switch is not a step in under the group switch",
       expect="the switch is not a step in", script=S)

# Search finds the hidden switch and cannot say what to turn on first.
mutate("Options/Window/Layout.lua",
       "\t\t[\"who.share\"] = \"who.group\",\n",
       "",
       "raidsplit: search is not told the switch's parent",
       expect="search is not told the switch's parent", script=S)

# The page's reset leaves the switch as it was.
mutate("Options/Advanced.lua",
       "\"sources.pets\", \"sources.share\", ",
       "\"sources.pets\", ",
       "raidsplit: the page's reset leaves the switch",
       expect="the page's reset leaves the switch", script=S)

# ------------------------------------------------------------ the walk
# The walk never asks: both users are offered everybody.
mutate("Queue.lua",
       "\t\t\tand ns.ShareHolds(opts, buff, owner, has, remaining, queue) then\n",
       "\t\t\tand false then\n",
       "raidsplit: the walk never asks whose share it is",
       expect="raidsplit: two users in a party: every member is in one share, the same on both sides", script=S)

# Your target and focus held back with the rest.
mutate("Queue.lua",
       "\t\tif buff and reason == \"group\" and not pointed and ns.ShareHolds\n",
       "\t\tif buff and reason == \"group\" and ns.ShareHolds\n",
       "raidsplit: your target is held back by the split",
       expect="your target, in the other share, was held back", script=S)

# A favour owed and a request held back with the rest.
mutate("Queue.lua",
       "\t\tif buff and reason == \"group\" and not pointed and ns.ShareHolds\n",
       "\t\tif buff and not pointed and ns.ShareHolds\n",
       "raidsplit: a favour owed is held back by the split",
       expect="a favour owed to somebody in the other share was held back", script=S)

# Held for one buff, they are offered nothing else of yours either.
mutate("Queue.lua",
       "\t\t\tbuff, has, remaining, seconds, lead, leadKind = ns.ShareOther(candidates, opts, ReadAura, owner)\n",
       "\t\t\tbuff = nil\n",
       "raidsplit: nothing else of yours is offered to the other's share",
       expect="raidsplit: a buff only you cast is offered to the other's share at once", script=S)

# The pick made again among every buff, the held one too: offered all the same.
mutate("Share.lua",
       "\t\tif not whose or whose.me then others[#others + 1] = buff end\n",
       "\t\tothers[#others + 1] = buff\n",
       "raidsplit: the buff held back is picked again",
       expect="raidsplit: two users in a party: every member is in one share, the same on both sides", script=S)

# A pin is walked past for another buff's sake.
mutate("Share.lua",
       "\tif ns.PinnedBuff() then return nil end\n",
       "",
       "raidsplit: a pinned buff is offered to the other's share",
       expect="with Fortitude pinned, Dain is offered", script=S)

# Every blessing starts at the same paladin: the second waits out the grace.
mutate("Share.lua",
       "\tfor i, key in ipairs(keys) do out[key] = i - 1 end\n",
       "\tfor _, key in ipairs(keys) do out[key] = 0 end\n",
       "raidsplit: every blessing is the same paladin's",
       expect="raidsplit: two paladins give one member two blessings, and not the same one twice", script=S)

# No hello is ever handed to Share.lua.
mutate("Clicks.lua",
       "\t\tif ns.plain(prefix) == PREFIX and ns.ShareHeard and ns.ShareHeard(text, channel, sender) then return end\n",
       "",
       "raidsplit: a hello is never read",
       expect="raidsplit: two users in a party: every member is in one share, the same on both sides", script=S)

# Every message with the prefix is taken for a hello: the author's word is lost.
mutate("Clicks.lua",
       "ns.ShareHeard and ns.ShareHeard(text, channel, sender) then return end\n",
       "ns.ShareHeard then return end\n",
       "raidsplit: the author's word is swallowed",
       expect="raidsplit: the author's line is still heard, and a hello is not taken for it", script=S)

# ------------------------------------------------------------ the split
# Each side puts itself first: the two sides deal differently.
mutate("Share.lua",
       "\ttable.sort(sharers, ByGuid)\n",
       "",
       "raidsplit: the users are not sorted",
       expect="raidsplit: two users in a party: every member is in one share, the same on both sides", script=S)

# Everybody to the first user.
mutate("Share.lua",
       "\t\treturn eligible[(at - 1 + plan.offset) % #eligible + 1]\n",
       "\t\treturn eligible[1]\n",
       "raidsplit: nobody is dealt in turn",
       expect="the members were not dealt in turn", script=S)

# Every subgroup of a raid to the first user.
mutate("Share.lua",
       "plan.bySub[sub] = Pick(wide and 1 or i, sub) or false end\n",
       "plan.bySub[sub] = Pick(1, sub) or false end\n",
       "raidsplit: the subgroups are not dealt in turn",
       expect="raidsplit: three users in a raid: the subgroups are dealt in turn, the same on every side", script=S)

# A user is dealt like anybody, and is in nobody's share.
mutate("Share.lua",
       "\t\tif own and not wide then\n",
       "\t\tif false then\n",
       "raidsplit: a user is not in their own share",
       expect="raidsplit: two users in a party: every member is in one share, the same on both sides", script=S)

# A raid group somebody does not buff is dealt to them all the same.
mutate("Share.lua",
       " and (not inRaid or Buffs(user.groups, sub)) then\n",
       " then\n",
       "raidsplit: the raid groups a user buffs are not read",
       expect="of group 2 that Bert does not buff", script=S)

# Your own raid groups are never said.
mutate("Share.lua",
       "\tme.groups = Mask(db)\n",
       "\tme.groups = 255\n",
       "raidsplit: your own raid groups are not said",
       expect="of group 3 that you do not buff", script=S)

# A shout is dealt member by member, and two warriors shout at once.
mutate("Share.lua",
       "\tlocal wide = buff ~= nil and (buff.selfCast == true or (ns.WIDE_CASTS == true and not buff.alone))\n",
       "\tlocal wide = false\n",
       "raidsplit: a shout is shared out like a single buff",
       expect="a shout for", script=S)

# A paladin's keys all start at the same user.
mutate("Share.lua",
       "\t\tinRaid = inRaid, offset = offset or 0 }\n",
       "\t\tinRaid = inRaid, offset = 0 }\n",
       "raidsplit: every key starts at the same user",
       expect="is in the same share for a key that starts one further on", script=S)

# A user whose hello says they do not share is counted.
mutate("Share.lua",
       "\t\t\tif user.live and user.on and user.class == me.class and user.keys[key] then\n",
       "\t\t\tif user.live and user.class == me.class and user.keys[key] then\n",
       "raidsplit: a user who does not share is counted",
       expect="with Bert not sharing the queue is", script=S)

# A user who casts another buff is counted for this one.
mutate("Share.lua",
       "\t\t\tif user.live and user.on and user.class == me.class and user.keys[key] then\n",
       "\t\t\tif user.live and user.on and user.class == me.class then\n",
       "raidsplit: a user who casts another buff is counted",
       expect="with Bert casting another buff the queue is", script=S)

# ------------------------------------------------------------ nobody goes without
# Held for good.
mutate("Share.lua",
       "\tif now - timers.since[name] >= GRACE then\n",
       "\tif false then\n",
       "raidsplit: no grace",
       expect="held 46 seconds and still missing it, Dain is not offered", script=S)

# Twenty seconds, not forty-five.
mutate("Share.lua",
       "local GRACE = 45\n",
       "local GRACE = 20\n",
       "raidsplit: the grace is 20 seconds",
       expect="raidsplit: nobody goes without: held for 45 seconds, they are offered anyway", script=S)

# The 45 seconds never start again.
mutate("Share.lua",
       "before ~= nil and last ~= nil and before > last)\n",
       "false)\n",
       "raidsplit: a hold that lapsed goes on counting",
       expect="missing it again, Dain is offered with no grace given to Bert", script=S)

# A fight's seconds count.
mutate("Share.lua",
       "\tif InCombatLockdown() or now - last > LAPSE then return since + (now - last) end\n",
       "\tif now - last > LAPSE then return since + (now - last) end\n",
       "raidsplit: a fight's seconds count towards the grace",
       expect="raidsplit: the 45 seconds are counted out of a fight", script=S)

# A dead user keeps their share.
mutate("Share.lua",
       "\tif plain(UnitIsDeadOrGhost(unit)) == true then return false end\n",
       "",
       "raidsplit: a dead user keeps their share",
       expect="with Bert dead, his share is still left to him", script=S)

# And one who is offline.
mutate("Share.lua",
       "\tif type(connected) == \"function\" and plain(connected(unit)) == false then return false end\n",
       "",
       "raidsplit: an offline user keeps their share",
       expect="with Bert offline, his share is still left to him", script=S)

# Nobody is asked about again between two hellos.
mutate("Share.lua",
       "\t\t\tif Live(user.unit) ~= user.live then\n",
       "\t\t\tif false then\n",
       "raidsplit: the users are not looked at each scan",
       expect="with Bert dead, his share is still left to him", script=S)

# Somebody who left is kept as a user.
mutate("Share.lua",
       "\t\tif not member then\n\t\t\tusers[name] = nil\n",
       "\t\tif not member then\n\t\t\tuser.live = false\n",
       "raidsplit: a user who left is kept",
       expect="Bert is still kept as a user after leaving", script=S)

# The roster changing is never heard.
mutate("Share.lua",
       "\t\tpcall(frame.RegisterEvent, frame, event)\n",
       "",
       "raidsplit: nothing listens for the roster",
       expect="nothing listens for the roster changing", script=S)

# ------------------------------------------------------------ another player's word
mutate("Share.lua",
       "\tif channel ~= \"PARTY\" and channel ~= \"RAID\" and channel ~= \"INSTANCE_CHAT\" then\n"
       "\t\treturn \"not from the group's channel\"\n\tend\n",
       "",
       "raidsplit: a whispered hello is taken",
       expect="a whisper: it was taken for a hello", script=S)

mutate("Share.lua",
       "\tlocal unit = UnitOf(sender)\n",
       "\tlocal unit = UnitOf(sender) or \"party1\"\n",
       "raidsplit: a sender outside the group is taken",
       expect="a sender outside the group: it was taken for a hello", script=S)

mutate("Share.lua",
       "\tif type(sender) ~= \"string\" or sender == \"\" or #sender > 100 then return \"no sender\" end\n",
       "",
       "raidsplit: a withheld sender is read",
       expect="raidsplit: a hostile or malformed hello changes nothing and never throws", script=S)

mutate("Share.lua",
       "\tif type(theirs) == \"string\" and theirs ~= guid then return \"another's GUID\" end\n",
       "",
       "raidsplit: a hello may carry another member's GUID",
       expect="another member's GUID: it was taken for a hello", script=S)

mutate("Share.lua",
       "\tif type(token) == \"string\" and token ~= class then return \"another class\" end\n",
       "",
       "raidsplit: a priest may say hello as a mage",
       expect="a priest speaking as a mage: it was taken for a hello", script=S)

mutate("Share.lua",
       "\tif #text > 255 then return \"too long\" end\n",
       "",
       "raidsplit: an oversized hello is taken",
       expect="300 bytes: it was taken for a hello", script=S)

mutate("Share.lua",
       "\tif n ~= 7 then return \"too few fields\" end\n",
       "",
       "raidsplit: a hello short of fields is read",
       expect="raidsplit: a hostile or malformed hello changes nothing and never throws", script=S)

mutate("Share.lua",
       "\tif #build < 1 or #build > 24 or build:find(\"[^%w%.%-]\") then return \"build\" end\n",
       "",
       "raidsplit: a build of any shape is taken",
       expect="a build with a colour code: it was taken for a hello", script=S)

mutate("Share.lua",
       "\tif #class < 1 or #class > 16 or class:find(\"[^%u]\") then return \"class\" end\n",
       "",
       "raidsplit: a class of any shape is read",
       expect="bad hellos", script=S)

mutate("Share.lua",
       "\tif #flags > 4 or flags:find(\"[^gq]\") then return \"flags\" end\n",
       "",
       "raidsplit: flags of any shape are taken",
       expect="flags that are not flags: it was taken for a hello", script=S)

mutate("Share.lua",
       "\tif #groups < 1 or #groups > 3 or groups:find(\"[^%d]\") then return \"groups\" end\n",
       "",
       "raidsplit: raid groups that are not a number are taken",
       expect="raid groups that are not a number: it was taken for a hello", script=S)

mutate("Share.lua",
       "\tif not groups or groups > 255 then return \"groups\" end\n",
       "",
       "raidsplit: raid groups past eight are taken",
       expect="raid groups past eight: it was taken for a hello", script=S)

mutate("Share.lua",
       "\tif not SafeGuid(guid) then return \"guid\" end\n",
       "",
       "raidsplit: a GUID of any shape is taken",
       expect="a GUID with a pipe in it, the client keeping his own back: it was taken for a hello", script=S)

mutate("Share.lua",
       "\t\tif not key or #key > MAX_KEY then return \"keys\" end\n",
       "\t\tif not key then return \"keys\" end\n",
       "raidsplit: a key of any length is taken",
       expect="a key 40 letters long: it was taken for a hello", script=S)

mutate("Share.lua",
       "\t\tif count > MAX_KEYS then return \"too many keys\" end\n",
       "",
       "raidsplit: any number of keys is taken",
       expect="thirty keys: it was taken for a hello", script=S)

# ------------------------------------------------------------ saying hello
# The tick never calls: nothing is ever said.
mutate("Core.lua",
       "\tif share and share.due and share.due <= now then ns.Guard(\"share\", share.Tick, share, now) end\n",
       "",
       "raidsplit: the tick never says hello",
       expect="hellos were said on logging in to a group, not one", script=S)

mutate("Share.lua",
       "\tif InCombatLockdown() then return true end\n\tlocal chat = _G.C_ChatInfo\n",
       "\tlocal chat = _G.C_ChatInfo\n",
       "raidsplit: a hello in a fight",
       expect="a hello was said in a fight", script=S)

mutate("Share.lua",
       "\t\tand plain(chat.InChatMessagingLockdown()) ~= false then\n",
       "\t\tand false then\n",
       "raidsplit: a hello under the chat lockdown",
       expect="a hello was said while the client holds chat back", script=S)

mutate("Share.lua",
       "\tif self.sentAt and now - self.sentAt < GAP then\n",
       "\tif false then\n",
       "raidsplit: no throttle",
       expect="two hellos went out within ten seconds", script=S)

mutate("Share.lua",
       "\treturn plain(IsInRaid and IsInRaid()) == true and \"RAID\" or \"PARTY\"\n",
       "\treturn \"PARTY\"\n",
       "raidsplit: a raid's hello goes to the party",
       expect="in a raid the hello went to", script=S)

mutate("Share.lua",
       "Text(me, not self.greeted), Channel()))\n",
       "Text(me, false), Channel()))\n",
       "raidsplit: the first hello asks for no answer",
       expect="the first hello reads", script=S)

mutate("Share.lua",
       "\t\tShare.reply = true\n\t\tShare.due = 0\n",
       "\t\tShare.due = 0\n",
       "raidsplit: a hello that asks is not answered",
       expect="asked for a hello, 0 were said in answer", script=S)

mutate("Share.lua",
       "\t\tor (self.said ~= nil and self.said ~= sig)\n",
       "",
       "raidsplit: a change is never said",
       expect="with the switch turned off, 0 hellos said so", script=S)

mutate("Share.lua",
       "\t\tstats.result = result\n\t\tself.due = now + GAP\n",
       "\t\tstats.result = result\n",
       "raidsplit: a refused hello is not tried again",
       expect="a refused hello was never tried again", script=S)

mutate("Share.lua",
       "\tif result == nil or result == true or result == 0 then\n",
       "\tif true then\n",
       "raidsplit: a refused hello counts as said",
       expect="a refused hello was never tried again", script=S)

mutate("Share.lua",
       "\t\tif not known[name] then Share.newcomer = true end\n",
       "",
       "raidsplit: somebody new is not told",
       expect="raidsplit: somebody new in the group is said hello to", script=S)

# Only Forever's own registration is left: Classic Era never hears a hello.
mutate("Share.lua",
       "\t\tpcall(chat.RegisterAddonMessagePrefix, PREFIX)\n",
       "",
       "raidsplit: the prefix is registered on Forever alone",
       expect="on Classic Era the prefix is never registered", script=S)

# ------------------------------------------------------------ the group cast
# Both users are offered the group cast.
mutate("GroupBuffs.lua",
       "\t\t\tlocal group = not (ns.ShareLeavesCast and ns.ShareLeavesCast(bucket))\n",
       "\t\t\tlocal group = true\n",
       "raidsplit: every user casts the group cast",
       expect="Bert is offered a group cast too", script=S)

# The caster counts their own share alone.
mutate("Share.lua",
       "\t\tif where and Caster(plan, where) == me then Keep(opts, buff, has, remaining, queue) end\n",
       "",
       "raidsplit: the caster does not count the other's share",
       expect="the group cast does not count", script=S)

# A group cast aimed at somebody of the other share is thrown out after the fold.
mutate("GroupBuffs.lua",
       "\tgroup.foldOnly = nil\n",
       "",
       "raidsplit: a group cast aimed at the other's share is dropped",
       expect="with only Bert's subgroup missing it, Anna is offered", script=S)

# The last who can, not the first.
mutate("Share.lua",
       "\treturn capable[plan.offset % #capable + 1]\n",
       "\treturn capable[#capable]\n",
       "raidsplit: the group cast is the last user's",
       expect="Anna, whose it is to cast, is offered no group cast", script=S)

# ------------------------------------------------------------ saying so
mutate("Commands.lua",
       "\t\tfor _, line in ipairs(ns.ShareLines()) do self:Print(\"  \" .. line) end\n",
       "",
       "raidsplit: /manners debug silent",
       expect="/manners debug says nothing of the share", script=S)

mutate("Share.lua",
       "\theld[name] = now\n",
       "",
       "raidsplit: who was left to another user is not counted",
       expect="/manners debug does not say the scan left anybody to another user", script=S)

mutate("Options/Diagnostics.lua",
       "\t\tfor _, line in ipairs(ns.ShareReport()) do lines[#lines + 1] = Plain(line) end\n",
       "",
       "raidsplit: the check-up leaves the share out",
       expect="the check-up does not count the share", script=S)

mutate("Options/Diagnostics.lua",
       "\tpcall(function() Heard(ns.ShareReport()) end)\n",
       "",
       "raidsplit: the check-up names who you share with",
       expect="the check-up names", script=S)

mutate("Options/Diagnostics.lua",
       "\tif ns.ShareSummary then lines[#lines + 1] = ns.ShareSummary() end\n",
       "",
       "raidsplit: the bug report leaves the hellos out",
       expect="the bug report does not count the users heard", script=S)
