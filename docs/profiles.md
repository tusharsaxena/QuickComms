# Profiles — Ka0s Quick Comms

AceDB profiles are user-visible: the Profiles page (`settings/Profiles.lua`) draws AceDBOptions'
table, and `/qc profile [name]` lists or switches profiles.

- Every setting except the minimap button lives in the profile. The minimap button is a
  per-installation preference in `global.minimap` (launcher-§3).
- A profile switch, copy or reset runs the migrations, refreshes the panels, re-reads the latch from
  the incoming profile's `enabled`, and sends `NS.MSG.PROFILE_CHANGED` (`core/QuickComms.lua`
  `reloadProfile`). It is logged once, by the profile handler.
- A profile switch also forgets the Share page's ticks and its checked string (they name the old
  profile's ids).
- Reset all settings is a profile reset (options-ui-§12): it resets the current profile only.
- `profile` answers while the addon is disabled, since switching to an enabled profile is one way
  back.
