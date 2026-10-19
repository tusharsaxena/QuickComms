local _, NS = ...
-- modules/Library_Migrate.lua — the registry writer's schemaVersion steps (savedvariables-§1), kept
-- beside modules/Library.lua (which is at its line budget). core/Database.lua's runner calls each one
-- for every stored profile, with the raw profile table; each step is idempotent against a fresh
-- default profile and leaves a damaged value as it found it.

NS.Library = NS.Library or {}
local Lib = NS.Library

-- The growth values a step rewrites: `up` (Upward) split into Right and up / Left and up (B2), and
-- the old Upward always drew rightward.
local RETIRED_GROWTH = { up = "rightUp" }

--- Step 4: every pad whose layout still carries a retired growth takes its new value.
function Lib.MigrateGrowth(profile)
    local pads = type(profile) == "table" and profile.pads
    if type(pads) ~= "table" then return end
    for _, pad in pairs(pads) do
        local layout = type(pad) == "table" and pad.layout
        if type(layout) == "table" and RETIRED_GROWTH[layout.growth] then
            layout.growth = RETIRED_GROWTH[layout.growth]
        end
    end
end
