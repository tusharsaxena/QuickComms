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
    -- 6 -> 7 (bg subgroups): the battleground sets' new objective nodes go inside each set's copy, and
    -- the sets that shipped flat open into their ring, wherever the player has not changed them.
    { to = 7, perProfile = true, run = function(_, profile) NS.Library.MigrateBattlegroundNodes(profile) end },
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
    if from ~= g.schemaVersion and NS.DebugAtEnable then
        NS.DebugAtEnable("Migrate", "v%s -> v%s", from, g.schemaVersion)
    end
end
