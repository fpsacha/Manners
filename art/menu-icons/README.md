# The options window's page icons (sources)

Twelve square pictures, one per page of the options window, painted with an image
model in November 2026 in the style of a classic fantasy MMO's own item icons:
one chunky object, a bold dark outline, a few tones of hand-painted shading, a
plain dark ground. `python tools/make_menu_icons.py` turns them into
`Textures/Menu/<Name>.tga` (64 x 64), which is what ships; this folder does not.

| File | Page | Object |
|---|---|---|
| icon-start.jpg | Start here | a rolled map |
| icon-who.jpg | Who to buff | a hand holding a rune stone |
| icon-skip.jpg | Who to skip | a round wooden shield |
| icon-when.jpg | When to offer | an hourglass |
| icon-say.jpg | What I say | a quill in an inkwell |
| icon-look.jpg | Look | a paint brush and pot |
| icon-profiles.jpg | Profiles | two tomes |
| icon-diagnostics.jpg | Diagnostics | a spyglass |
| icon-fight.jpg | In a fight | a notched longsword |
| icon-quiet.jpg | Quiet times | a snuffed candle with a brass snuffer |
| icon-self.jpg | My own buffs | a hand mirror with a glowing rune |
| icon-pet.jpg | My pet | a leather collar with a paw-print tag |

To change one, replace its picture here and run the tool; never edit a texture.
