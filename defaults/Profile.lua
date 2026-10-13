local _, NS = ...
-- defaults/Profile.lua — every default VALUE the addon hardcodes (savedvariables-§2).
--
-- Two scopes, each one AceDB defaults table (settings/Schema.lua's Settings.BuildDefaults assembles
-- them with the schema rows' own defaults):
--   profile  the Master controls values (options-ui-§15);
--   global   the schema stamp and LibDBIcon's table.
--
-- The Master controls rows are composed by LibKa0s-Options-1.0, so their values live here too: with
-- the library absent the schema has no `enabled` row, and a schema-only defaults tree would hand
-- AceDB a profile whose `enabled` reads nil. The design's data model (spec §5.1) is added here by
-- the profile task.

NS.C = {
    PROFILE = {
        enabled = true,   -- master switch (the `disabled` hold reads it)
    },

    -- schemaVersion is 0, never the current version (savedvariables-§1).
    GLOBAL_DEFAULTS = { schemaVersion = 0, minimap = { hide = false } },
}
