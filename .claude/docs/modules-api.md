# Manners -- optional-module API

`Modules.lua` publishes `MannersAPI`; optional addons never receive the core's
raw `ns` table.

- `GetProfile`, `GetDB`, `GetFlavour`: the existing Manners AceDB values.
- `RegisterModule`, `ModuleLoaded`: dependency presence, never feature logic.
- `RegisterModuleLifecycle(id, suspend, resume)`: one pair for loaded modules.
  A pending disable runs `suspend` immediately; a cancellation/re-enable runs
  `resume`. They must stop scans, event frames and visible/armed frames without
  rewriting SavedVariables. Secure-frame creation and destruction wait for
  Reload UI.
- `RegisterCallback` / `Fire`: named core lifecycle and favour events.
- `RegisterOptionsExtension`, `RegisterOptionsPage`, `InsertLayoutItems` and
  `AddLayoutSection`: model and layout ownership for loaded modules only.
- `ModuleContext(id)`: a scoped allow-list used by moved code. Combat, Pets,
  My Buffs and Services each have separate read/write sets.
- `RecentLedgerEntries`: a bounded copy of at most 200 ledger rows, not the
  mutable store. `RegisterLedgerTab` gives a ledger tab one content frame.
- `RegisterServiceBuff` / `UnregisterServiceBuff` are restricted to Services
  and rebuild the buff lookups. Fire Shield uses them lazily so its buff and
  pet events exist only while that service is on. `NotePetBuffCast` settles
  the imp's cast. `ModuleActive` is true only for an addon already loaded this
  session and not pending-disable; enabling an unloaded addon remains inactive
  until Reload UI. `IsModuleEnabled` is the saved addon state.

The saved feature paths remain under `MannersDB` so enabling a module restores
the player's old choices. Achievements alone owns
`MannersAchievementsDB`; it receives core favour events, registers no game
events and cannot touch the prompt or queue.

`MigrateOptionalModules` reads legacy feature switches once per profile. It
enables My Buffs or Services only for a pre-existing profile whose feature
switch was active, preserves its saved values and writes
`optionalModulesMigrated` so a later intentional disable is untouched.
