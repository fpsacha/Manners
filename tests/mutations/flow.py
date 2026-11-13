# Mutations for Looks/Flow.lua, the clock for art that moves by its texture
# coordinates. Caught by tests/scenarios/flow.lua.

S = "runscenarios.py"
FLOW = "Looks/Flow.lua"

mutate(FLOW,
       "\t\tif since < STEP then return end\n",
       "",
       "flow: the clock writes at every frame the game draws",
       expect="writes in a second at 240 frames a second", script=S)

mutate(FLOW,
       "\t\t\tflow.live = 0\n\t\t\tflow.driver:Hide()\n",
       "\t\t\tflow.live = 0\n",
       "flow: the clock left running with nothing to move",
       expect="the clock runs on with nothing playing", script=S)

mutate(FLOW,
       "\t\tlocal v = ((self.v0 or 0) + self.dv * t) % 1\n",
       "\t\tlocal v = ((self.v0 or 0) + self.dv * t)\n",
       "flow: a scroll run off the file's edge instead of round it",
       expect="a scroll up at half a file a second", script=S)

mutate(FLOW,
       "\t\tif self.kind == \"scroll\" then self:Speed(self.du, self.dv) end\n",
       "",
       "flow: a scroll played again starts over",
       expect="played again, the scroll jumped", script=S)

mutate(FLOW,
       "\t\t\tframe = frame % self.frames\n",
       "\t\t\tframe = frame % (self.cols * self.rows)\n",
       "flow: a loop plays the sheet's empty cells",
       expect="a loop of six frames did not come round", script=S)

mutate(FLOW,
       "\t\t\tif self.playing then\n\t\t\t\tself:Stop()\n",
       "\t\t\tif self.playing then\n",
       "flow: a sheet played once never ends",
       expect="still playing after its last frame", script=S)

mutate(FLOW,
       "\t\tlocal col, row = frame % self.cols, math.floor(frame / self.cols)\n",
       "\t\tlocal col, row = frame % self.cols, 0\n",
       "flow: a sheet stuck on its first row",
       expect="the fifth frame is not the first of the second row", script=S)

mutate(FLOW,
       "\tdriver.mannersFlow = true\n",
       "",
       "flow: the clock not told apart from a stray OnUpdate",
       expect="the clock's frame is not marked as Flow's", script=S)

mutate(FLOW,
       "\tlocal driver = CreateFrame(\"Frame\", nil, parent)\n",
       "\tlocal driver = CreateFrame(\"Frame\", nil, UIParent)\n",
       "flow: the clock runs on with the look's art hidden",
       expect="the clock is not a frame of the look's own art", script=S)

mutate(FLOW,
       "\tfor _, flow in ipairs(Flow.all) do flow:Tick(now or GetTime()) end\n",
       "",
       "flow: the renderer's tick reaches no flow",
       expect="TickAll did not write a playing scroll once", script=S)

mutate(FLOW,
       "\t\tif h.playing then h:Write(now) end\n",
       "\t\th:Write(now)\n",
       "flow: a stopped handle still written",
       expect="a stopped scroll", script=S)
