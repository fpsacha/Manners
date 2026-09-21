# Third-party notices

Manners bundles the libraries below. They are **not** covered by the addon's own
MIT licence — each keeps its own terms, reproduced or linked here.

When built through the CurseForge/WoWInterface packager, `.pkgmeta` pulls these
from their upstream repositories at build time rather than redistributing copies
from this project.

| Library | Author(s) | Licence |
|---|---|---|
| LibStub | Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke | Public domain |
| CallbackHandler-1.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceAddon-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceEvent-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceTimer-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceConsole-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceDB-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceDBOptions-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceGUI-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceConfig-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| LibSharedMedia-3.0 | Elkano | **LGPL v2.1** |
| LibDataBroker-1.1 | tekkub | BSD |
| LibDBIcon-1.0 | Rabbit | BSD-style |

## LibSharedMedia-3.0 — LGPL v2.1

This is the one copyleft dependency. LGPL v2.1 permits distribution alongside a
differently-licensed addon provided the library itself remains under the LGPL
and its source is available. Both hold here: the library ships as readable Lua,
unmodified, and its upstream is linked in `.pkgmeta`. Do not modify the bundled
copy without also publishing those changes under the LGPL.

Full text: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html

## Ace3

Ace3 is distributed under a BSD-style licence permitting use, modification and
redistribution with attribution. Full text and source:
https://www.wowace.com/projects/ace3

## Game assets

Icons and atlas artwork referenced by this addon (for example
`Interface\Icons\Spell_Holy_MagicalSentry` and `Adventures-Spell-Border`) are
Blizzard Entertainment's, used from the client's own files through the public
addon API. None are redistributed with this package.
