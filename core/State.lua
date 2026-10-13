local _, NS = ...
-- core/State.lua — session-only runtime state; reset every /reload and never in SavedVariables.

NS.State = NS.State or {}
local State = NS.State

-- The debug-logging flag (debug-logging-§5): default off, independent of the console window.
-- `/qc debug on|off` and the console's own toggle write it through the DebugLog seam.
State.debug = false
