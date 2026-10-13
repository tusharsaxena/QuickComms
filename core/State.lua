local _, NS = ...
-- core/State.lua — session-only runtime state; reset every /reload and never in SavedVariables.

NS.State = NS.State or {}
local State = NS.State

-- The debug-logging flag (debug-logging-§5): default off, independent of the console window.
-- `/qc debug on|off` and the console's own toggle write it through the DebugLog seam.
State.debug = false

-- The member each editor page has selected (settings/Editors.lua): { callout, group, pad, builtin }.
-- A member row written with no instance argument writes this member, else the first member its page
-- lists (settings/Schema.lua Settings.EditingId).
State.editing = {}

-- "Preview as…" (modules/Preview.lua, spec §13.3): the preset key the pads are drawn as, or nil.
-- Session-only; test mode's second flavor, so it is never on with State.testMode.
State.previewAs = nil
