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
-- AceDB a profile whose `enabled` reads nil. The design's data model (spec §5.1) lives here too:
-- the Behavior values and the registry, whose only writer is modules/Library.lua.

NS.C = {
    PROFILE = {
        enabled    = true,       -- master switch (the `disabled` hold reads it)
        visibility = "always",   -- Master controls: General visibility (options-ui-§15)
        scale      = 1.0,        -- Master scale, multiplied into every pad's own scale
        alpha      = 1.0,        -- Master alpha, the ceiling of every pad's fade
        locked     = false,      -- Lock frame: a new profile starts unlocked (owner, 2026-10-22; spec §5.1 locked)

        behavior = {
            soloFallback = "none",   -- "none" | "self" | "say": smart channels when solo (spec §8.2)
            spamGuard    = 1.0,      -- seconds between any two sends, 0.6-2.0 (spec §9.2, D12)
            dropNotes    = true,     -- the [QC] chat note when a drop is inferred (spec §9.3)
            whyTooltips  = true,
            lockdownChip = true,     -- shown only when lockdown affects a visible callout (spec §8.4)
            sounds       = false,
            autoPromote  = false,    -- narrower When floats up within a surface's order (spec §7)
            previewOnEdit = true,    -- the Groups page previews the group it edits on every surface
        },
        -- The registry (spec §5.1). Library (modules/Library.lua) is the ONLY writer of these keys.
        nextId    = 1,
        callouts  = {},   -- empty here: Library.Prepare seeds the shipped sets into callouts and groups
        groups    = {},
        seededSets = {},  -- the shipped set and node ids this profile was given as groups: { [id] = true }
        pads      = {},
        dials     = {},
        padOrder  = {},
        dialOrder = {},
        seeded    = false, -- set by Library.Prepare once the default pad and dial exist

        -- The Preview as selector window's place (modules/PreviewWindow.lua), written on drag stop.
        previewWindow = { point = "TOP", relPoint = "TOP", x = 0, y = -140 },

        -- The skin this addon wears (core/SkinSetup.lua; General > Skin, skinning-§2): Ka0s Default,
        -- the settings panel left the client's (the owner's call of 2026-10-27, as LootHistory), the
        -- fonts skinned, the skin's own font and texture, and the first-run picker not yet seen on
        -- any profile, old or new (owner ruling O3, 2026-10-29). New keys with defaults, so AceDB
        -- merges them into every existing profile and no migration is owed.
        skin = {
            source = "ka0s", skin = "ka0s", ignorePanel = true, ignoreFonts = false,
            font = "", texture = "", pickerSeen = false,
            -- The Font outline (LibKa0s v1.82.0, Skin minor 9, D-06): "all" text, "hud" text
            -- only (the default since v1.83.0, D-10), or "off". AceDB merges a new key into every profile.
            outline = "hud",
        },
    },

    -- schemaVersion is 0, never the current version (savedvariables-§1).
    GLOBAL_DEFAULTS = { schemaVersion = 0, minimap = { hide = false } },

    -- Genuinely per-character (savedvariables-§1's `char`, 2026-10-21): whether `/qc toggle`, the
    -- launcher's Show window or the Toggle Comms Pads key last hid this character's Comms Pads. It
    -- survives a /reload and a logout, and follows no profile (settings/SlashVerbs.lua V.TogglePads).
    CHAR_DEFAULTS = { padsHidden = false },
}
