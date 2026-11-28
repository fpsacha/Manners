# Mutations for the combat prompt's preview: only a move drags, a trial's end
# puts its preview away, a restyle keeps a move going.

S = "runscenarios.py"
TRY = "combat-preview: a look tried shows the cards still, and the trial's end puts them away"

mutate("Modules/Combat/Moments.lua",
       "\tlocal dragging = previewing == true and (moving == true or Moments.tried == nil)\n",
       "\tlocal dragging = previewing == true\n",
       "combat-preview: any preview lets the cards be dragged",
       expect=TRY, script=S)
mutate("Modules/Combat/Moments.lua",
       "\tif key == nil and previewing and not moving then\n",
       "\tif false then\n",
       "combat-preview: a trial's end leaves its preview up",
       expect=TRY, script=S)
mutate("Modules/Combat/Moments.lua",
       "\tMoments.Preview(true, wasMoving)\n",
       "\tMoments.Preview(true)\n",
       "combat-preview: a restyle ends a move",
       expect=TRY, script=S)
mutate("Modules/Combat/Moments.lua",
       "\tlocal dragging = previewing == true and (moving == true or Moments.tried == nil)\n",
       "\tlocal dragging = previewing == true and moving == true\n",
       "combat-preview: only Move the cards drags",
       expect=TRY, script=S)
