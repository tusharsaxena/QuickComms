# Profiles — Ka0s Quick Comms

AceDB profiles are user-visible: the Profiles page (`settings/Profiles.lua`) draws AceDBOptions'
table, and `/qc profile [name]` lists or switches profiles.

- Every setting except the minimap button lives in the profile. The minimap button is a
  per-installation preference in `global.minimap` (launcher-§3).
- A profile switch, copy or reset runs the migrations, applies the incoming profile's skin, refreshes
  the panels, re-reads the latch from the incoming profile's `enabled`, offers the first-run skin
  picker while that profile has not closed it, and sends `NS.MSG.PROFILE_CHANGED`
  (`core/QuickComms.lua` `reloadProfile`). The skin is per profile (`skin.*`, [schema.md](schema.md)). It is logged once, by the profile handler.
- Reset all settings is a profile reset (options-ui-§12): it resets the current profile only.
- `profile` answers while the addon is disabled, since switching to an enabled profile is one way
  back.
