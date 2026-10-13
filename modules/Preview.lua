local _, NS = ...
-- modules/Preview.lua — test mode (spec §10.4, preview-mode, options-ui-§15) and the one sender of
-- TEST_MODE_CHANGED (spec §17). Phase 2 owns the switch; "Preview as…" (spec §13.3) joins this file
-- in phase 3. Session-only (NS.State.testMode, never saved): refused while stood down or in combat
-- with one line, ended when combat starts (while secure writes are still allowed, so the pads swap
-- back to live chips at once), and ended by the stand-down. The checkbox, the `test` verb and the
-- launcher entry all call SetTestMode. Copied from DropWatcher core/DropWatcher.lua `NS.SetTestMode`,
-- `testModeRefusal` and `DW.OnCombatStart`; the combat edge arrives as RESTRICTION_CHANGED here,
-- because modules/Restrictions.lua owns PLAYER_REGEN_DISABLED.

NS.Preview = NS.Preview or {}
local P = NS.Preview
local State = NS.State
local L = NS.L

local function fighting()
    return NS.Restrictions.InCombat() or NS.Compat.InCombat()
end

-- The Test mode checkbox follows every start and stop (options-ui-§15).
local function refreshPanel()
    local S = NS.addon.Settings
    local H = S and S.Helpers
    if H and H.RefreshAll then H.RefreshAll() end
end

function P.IsTestMode()
    return State.testMode == true
end

--- Turn test mode on or off. A start is refused, with one line, while stood down or in combat.
--- @return boolean changed
function P.SetTestMode(on)
    on = on and true or false
    if on == P.IsTestMode() then return false end
    if on then
        if NS.IsStoodDown() then
            NS.Print(NS.SlashCommands:DisabledLine())
            return false
        end
        if fighting() then
            NS.Print(L["Test mode is not available in combat."])
            return false
        end
    end
    State.testMode = on
    NS.Debug("Pad", "test mode %s", on and "on" or "off")
    NS.addon:SendMessage(NS.MSG.TEST_MODE_CHANGED, on)
    refreshPanel()
    return true
end

function P.ToggleTestMode()
    return P.SetTestMode(not P.IsTestMode())
end

local function onRestrictionChanged()
    if P.IsTestMode() and NS.Restrictions.InCombat() then
        P.SetTestMode(false)
        NS.Print(L["Test mode ended: you entered combat."])
    end
end

-- Its own target (core/Bus.lua); the degraded bus is handled here, as in modules/Situation.lua.
local receiver
local function listen()
    receiver = receiver or NS.Bus:NewTarget()
    if receiver then receiver:RegisterMessage(NS.MSG.RESTRICTION_CHANGED, onRestrictionChanged) end
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    State.testMode = nil
    if receiver and not NS.Bus.tracked then receiver:UnregisterMessage(NS.MSG.RESTRICTION_CHANGED) end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
