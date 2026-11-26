# The one context decision shape used by buff, cure, own-item and service work.

S = "runscenarios.py"

mutate("Context.lua",
       "\tRESULT.eligible = eligible == true\n",
       "\tRESULT.eligible = true\n",
       "context: a rejected decision is reported eligible",
       expect="context: every decision has the same safe shape",
       script=S)

mutate("Context.lua",
       "\tif dead == true then\n"
       "\t\treturn RejectTarget(kind, unit, \"dead\")\n"
       "\tend\n",
       "",
       "context: a dead target is eligible",
       expect="context: every decision has the same safe shape",
       script=S)

mutate("Context.lua",
       "local REJECT_MAX = 20\n",
       "local REJECT_MAX = 1\n",
       "context: the rejection history is unbounded",
       expect="context: every decision has the same safe shape",
       script=S)

mutate("Context.lua",
       "\tif type(value) ~= \"string\" or value == \"\" then return \"<withheld>\" end\n",
       "\tif type(value) ~= \"string\" or value == \"\" then return tostring(value) end\n",
       "context: a withheld target is written to diagnostics",
       expect="context: every decision has the same safe shape",
       script=S)

mutate("Commands.lua",
       "\t\t\t\tfor _, line in ipairs(ns.ContextRejectionLines and ns.ContextRejectionLines() or {}) do self:Print(\"  \" .. line) end\n",
       "",
       "context: debug omits rejected decisions",
       expect="context: every decision has the same safe shape",
       script=S)

mutate("Queue.lua",
       "\t\tlocal decision = ns.ContextDecision(\"buff\", \"buff\", full, priority, reason, true, nil)\n"
       "\t\tentry.priority, entry.reason = decision.priority, decision.reason\n",
       "\t\tlocal decision = ns.ContextDecision(\"buff\", \"buff\", full, 9, \"nearby\", true, nil)\n"
       "\t\tentry.priority, entry.reason = decision.priority, decision.reason\n",
       "context: a buff bypasses the shared decision",
       expect="a request in any channel is offered, for a minute",
       script=S)

mutate("Modules/Combat/Cures.lua",
       "\t\t\t\t\tlocal decision = ns.ContextDecision(\"cure\", \"cure\", full,\n"
       "\t\t\t\t\t\tPRIORITY, inGroup and \"group\" or \"nearby\", true, nil)\n"
       "\t\t\t\t\tentry.priority, entry.reason = decision.priority, decision.reason\n",
       "\t\t\t\t\tlocal decision = ns.ContextDecision(\"cure\", \"cure\", full,\n"
       "\t\t\t\t\t\t9, \"group\", true, nil)\n"
       "\t\t\t\t\tentry.priority, entry.reason = decision.priority, decision.reason\n",
       "context: a cure bypasses the shared decision",
       expect="cures: a cure comes before a buff, for the same person and in the queue",
       script=S)

mutate("Queue.lua",
       "\tlocal decision = ns.ContextDecision(\"own\", \"self-buff\", full, entry.priority, \"self\", true, nil)\n"
       "\tentry.priority, entry.reason = decision.priority, decision.reason\n",
       "\tlocal decision = ns.ContextDecision(\"own\", \"self-buff\", full, 9, \"group\", true, nil)\n"
       "\tentry.priority, entry.reason = decision.priority, decision.reason\n",
       "context: an own buff bypasses the shared decision",
       expect="own: a mage with no armor is offered their Automatic armor",
       script=S)

mutate("Queue.lua",
       "\t\t\t\tlocal decision = ns.ContextDecision(\"own\", \"item\", full, PRIORITY.self, \"self\", true, nil)\n"
       "\t\t\t\tentry.priority, entry.reason = decision.priority, decision.reason\n",
       "\t\t\t\tlocal decision = ns.ContextDecision(\"own\", \"item\", full, 9, \"group\", true, nil)\n"
       "\t\t\t\tentry.priority, entry.reason = decision.priority, decision.reason\n",
       "context: an own item bypasses the shared decision",
       expect="supplies: on, food leaves the prompt for the button, armed to use it",
       script=S)

mutate("Modules/Services/Courtesy.lua",
       "\t\t\t\t\t\tlocal decision = ns.ContextDecision(\"service\", plan.stage, full,\n"
       "\t\t\t\t\t\t\tasked, st.targeted and \"target\" or \"asked\", true, nil)\n",
       "\t\t\t\t\t\tlocal decision = ns.ContextDecision(\"service\", plan.stage, full,\n"
       "\t\t\t\t\t\t\t9, \"group\", true, nil)\n",
       "context: a service bypasses the shared decision",
       expect="courtesy: water asked for is conjured, then traded, and the trade is never accepted",
       script=S)
