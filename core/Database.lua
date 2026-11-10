local _, NS = ...
-- core/Database.lua — the schemaVersion migration runner (savedvariables-§1).
--
-- The defaults tree is built by settings/Schema.lua's Settings.BuildDefaults (profile rows from the
-- schema, plus defaults/Profile.lua's tables) and handed to AceDB in OnInitialize, which runs this
-- runner straight after AceDB:New, before anything reads db.profile, and again from every profile
-- callback. global.schemaVersion defaults to 0, never the current version: AceDB strips a value
-- equal to its default at logout and would backfill it onto a legacy account.
--
-- The runner owns the stamp: it advances it to a step's `to` only after that step returned, so a
-- step that raises is retried on the next load. A `perProfile` step runs for EVERY stored profile
-- (`db.sv.profiles`, the raw SavedVariables table), not only the active one. Each step is idempotent
-- against a fresh default profile.

-- The shipped faces LibKa0s retired, each to its successor (R3-FRIZ; LibKa0s R3-L7).
local RETIRED_FONTS = { ["Ka0s Friz Quadrata TT"] = "Ka0s Ubuntu" }

--- Moves every string naming a retired face, at any depth of `t`, to its successor. Answers how many moved.
function NS.RetireFonts(t)
    local n = 0
    for k, v in pairs(t) do
        if type(v) == "table" then
            n = n + NS.RetireFonts(v)
        elseif RETIRED_FONTS[v] then
            t[k], n = RETIRED_FONTS[v], n + 1
        end
    end
    return n
end

-- The steps, in order. `run(sv)` for a global step, `run(sv, profile)` for a `perProfile` one.
NS.MIGRATIONS = {
    { to = 1, run = function() end },   -- 0 -> 1: the stamp itself
    -- 1 -> 2 (phase 4): the generic battleground set moves below the per-battleground sets on every
    -- pad and dial, so the dial opens into a node set (D9). Library is the registry writer; it moves.
    { to = 2, perProfile = true, run = function(_, profile) NS.Library.MoveGenericBattlegroundLast(profile) end },
    -- 2 -> 3 (2026-10-18-builtins-as-groups-design.md): the built-in overlay becomes seeded groups,
    -- each in its set's place on every pad and dial; Library seeds them and converts the lists.
    { to = 3, perProfile = true, run = function(_, profile) NS.Library.SeedFromOverlay(profile) end },
    -- 3 -> 4 (2026-10-19 icons and polish, B2): a pad's retired Upward growth becomes Right and up.
    { to = 4, perProfile = true, run = function(_, profile) NS.Library.MigrateGrowth(profile) end },
    -- 4 -> 5 (B7): "M+ (generic)" becomes "Dungeon (generic)" with a Dungeon + M+ When, and seeded
    -- callouts take their catalog glyphs, wherever the player has not changed them.
    { to = 5, perProfile = true, run = function(_, profile) NS.Library.MigrateBuiltins(profile) end },
    -- 5 -> 6 (groups polish): seeded groups and callouts take their colored glyphs, and the battleground
    -- node sets their map-wide callouts, wherever the player has not changed them.
    { to = 6, perProfile = true, run = function(_, profile) NS.Library.MigrateBuiltinsPolish(profile) end },
    -- 6 -> 7 (bg subgroups): the battleground sets' new objective nodes go inside each set's copy,
    -- wherever the player has not changed them.
    { to = 7, perProfile = true, run = function(_, profile) NS.Library.MigrateBattlegroundNodes(profile) end },
    -- 7 -> 8 (dial rework, 2026-10-21): groups drop Open the dial on this group and Skip on the dial
    -- in content; a dial opens on its one active group, or on a ring of them.
    { to = 8, perProfile = true, run = function(_, profile) NS.Library.MigrateDialFields(profile) end },
    -- 8 -> 9 (dial polish, 2026-10-21): dials drop the Slices tab's retired Border (its size, color and
    -- class color); a Slice gap parts the slices instead.
    { to = 9, perProfile = true, run = function(_, profile) NS.Library.MigrateSliceBorder(profile) end },
    -- 9 -> 10 (QC-03, the skinning rollout, the owner's ruling O2): the one-time reset onto the skin.
    -- Every pad's and dial's font and border pickers follow the skin again, through their "Use the
    -- skin's ..." companions (LibKa0s-Skin-1.0 ResetToSkin); colors stay the player's (DECISIONS X4).
    { to = 10, perProfile = true, run = function(_, profile) NS.Library.MigrateFollowSkin(profile) end },
    -- 10 -> 11 (LibKa0s v1.82.0, Ka0sAddonsCommonTasks D-07 and Addendum 01): every pad's and dial's
    -- font block whose Font flags still hold the old default, OUTLINE, moves to From skin once.
    { to = 11, perProfile = true, run = function(_, profile) NS.Library.MigrateFontFlags(profile) end },
    -- 11 -> 12 (#13): every dial takes the Animation tab's defaults, kept keys kept.
    { to = 12, perProfile = true, run = function(_, profile) NS.Library.MigrateAnim(profile) end },
    -- 12 -> 13 (LibKa0s v1.85.0, cause D7): every pad and dial onto the full skin, once per profile.
    { to = 13, perProfile = true, run = function(_, profile) NS.Library.MigrateFullSkin(profile) end },
    -- 13 -> 14 (#13): a pad's Animation table goes, from any profile step 12 reached while it had one.
    { to = 14, perProfile = true, run = function(_, profile) NS.Library.MigrateDropPadAnim(profile) end },
    -- 14 -> 15 (#13): a dial still holding the old animation defaults takes the new ones, once.
    { to = 15, perProfile = true, run = function(_, profile) NS.Library.MigrateAnimDefaults(profile) end },
    -- 15 -> 16 (#13): a dial on the spiral defaults takes Rotate and scale; Scale and fade is retired.
    { to = 16, perProfile = true, run = function(_, profile) NS.Library.MigrateRotateDefaults(profile) end },
    -- 16 -> 17 (SF-QC-1): Scale in and out merge into Scale, their fading versions into Scale and fade.
    { to = 17, perProfile = true, run = function(_, profile) NS.Library.MigrateMergeScales(profile) end },
    -- 17 -> 18 (R3-FRIZ): LibKa0s v1.85.0 deleted Ka0s Friz Quadrata TT (R3-L7) and WoW Default draws
    -- Ka0s Ubuntu (R3-L6). A stored pick of the deleted face, a pad's or dial's font or the skin's Font
    -- override, moves to Ka0s Ubuntu; Blizzard's own "Friz Quadrata TT" stays.
    { to = 18, perProfile = true, run = function(_, profile) NS.RetireFonts(profile) end },
    -- 18 -> 19 (QFE-E3, QuickComms#15): the Emotes set comes to every stored profile once, after the
    -- World set on each pad and dial; a profile given it already, or whose player deleted it, gains nothing.
    { to = 19, perProfile = true, run = function(_, profile) NS.Library.MigrateEmotesSet(profile) end },
}

-- The runner's target: the highest step's `to`.
NS.SCHEMA_VERSION = NS.MIGRATIONS[#NS.MIGRATIONS].to

function NS:RunMigrations()
    local db = self.db
    local g = db and db.global
    if not g then return end
    -- AceDB exposes the raw SavedVariables table as db.sv; its `profiles` holds every stored profile.
    local sv = db.sv or {}
    local from = g.schemaVersion or 0
    for _, step in ipairs(NS.MIGRATIONS) do
        if (g.schemaVersion or 0) < step.to then
            if step.perProfile then
                for _, profile in pairs(sv.profiles or {}) do step.run(sv, profile) end
            else
                step.run(sv)
            end
            g.schemaVersion = step.to   -- reached only if the step returned
        end
    end
    -- Step 13's record is per profile and the stamp per account, so a profile that arrives later (an
    -- import, a copy, a reset) takes it here. It writes nothing to a profile that holds the record.
    for _, profile in pairs(sv.profiles or {}) do NS.Library.MigrateFullSkin(profile) end
    if from ~= g.schemaVersion and NS.DebugAtEnable then
        NS.DebugAtEnable("Migrate", "v%s -> v%s", from, g.schemaVersion)
    end
end
