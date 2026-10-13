-- tests/wow_mock.lua
--
-- This addon's THIN EXTENDER over the shared kit's mock_base (testing-§1). The base owns everything
-- universal: LibStub with a real NewLibrary, the Ace fakes, AceDB's merge-in-place defaults, the
-- AceGUI recorder, the Settings registrars, the timer queue, the event dispatch and the recorders.
-- This file adds what Ka0s Quick Comms reads that the base deliberately leaves out, as settable
-- fields on the mock so a suite seeds the client's answers before driving the addon.
--
-- Returns a BUILDER: each call is a fresh, isolated environment. `M._G = M`, so the table a suite
-- reads as `mock` and the table the addon's chunks read as `_G` are the same object.
--
-- Mock fields:
--   inCombat       InCombatLockdown()'s answer, and UnitAffectingCombat("player")'s
--   loadedAddons   the names C_AddOns.IsAddOnLoaded answers true for (this addon's own folder is in)
--   chatLockdown   C_ChatInfo.InChatMessagingLockdown()'s answer
--   restrictionStates  C_RestrictedActions' state per Enum.AddOnRestrictionType value (absent = 0)
--   prints         every line handed to the Lua global `print` (the printer's sink)
--   popupsShown    every StaticPopup_Show(which, ...) call, in order
--   ldbObjects     LibDataBroker objects by name; minimapButtons LibDBIcon registrations by name
--   fireEvent      fireEvent(name, ...) dispatches a game event to AceEvent handlers
--   blocked        every protected call refused in combat: { frame, call } (ADDON_ACTION_BLOCKED)
--   sentMacros     every macrotext a secure click ran: { text, at, frame }
--   stateDrivers   [frame] = { [state] = expression }
--   cvars          GetCVarBool's answers ("1" is true); ActionButtonUseKeyDown defaults on
--   playerGUID     UnitGUID("player")
--   __click(b[, mouseButton])  a full press: the registered down edge, then the up edge
--   __setCombat(on)            sets inCombat and re-evaluates every visibility driver

local base = dofile("tests/_kit/mock_base.lua")

local function build()
    local M = base()
    M._G = M

    M.inCombat     = false
    M.prints       = {}
    M.popupsShown  = {}
    M.loadedAddons = { QuickComms = true }

    M.InCombatLockdown    = function() return M.inCombat == true end
    M.UnitAffectingCombat = function() return M.inCombat == true end

    M.Enum = {
        AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4,
            Chat = 5 },
        AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 },
    }

    -- C_ChatInfo: chatLockdown is InChatMessagingLockdown's answer.
    M.chatLockdown = false
    M.C_ChatInfo = {
        InChatMessagingLockdown = function() return M.chatLockdown end,
    }

    -- C_RestrictedActions: restrictionStates[type] is the state; absent means Inactive.
    M.restrictionStates = {}
    M.C_RestrictedActions = {
        GetAddOnRestrictionState = function(rtype) return M.restrictionStates[rtype] or 0 end,
        IsAddOnRestrictionActive = function(rtype) return (M.restrictionStates[rtype] or 0) ~= 0 end,
    }

    -- The client's addon list; the base leaves C_AddOns out on purpose (its own NOTE).
    M.C_AddOns = {
        IsAddOnLoaded = function(name)
            local on = M.loadedAddons[name] == true
            return on, on
        end,
        GetAddOnMetadata = function() return nil end,
    }

    -- The chat sink core/CoreSetup.lua hands the printer: captured, so a suite can read it back.
    M.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        M.prints[#M.prints + 1] = table.concat(parts, " ")
    end

    M.StaticPopup_Show = function(which, ...) M.popupsShown[#M.popupsShown + 1] = { which, ... } end

    M.fireEvent = function(event, ...) return M.__fireEvent(event, ...) end

    -- The launcher's two libraries (launcher-§1), present by default because both are vendored and
    -- TOC-listed. Their whole surface as LibKa0s-Launcher-1.0 uses it; a case that wants the
    -- degraded install clears one through the loader's `mock` option.
    M.ldbObjects = {}
    M.__libs["LibDataBroker-1.1"] = {
        NewDataObject = function(_, name, tbl)
            if M.ldbObjects[name] then return nil end
            M.ldbObjects[name] = tbl
            return tbl
        end,
        GetDataObjectByName = function(_, name) return M.ldbObjects[name] end,
    }
    M.minimapButtons = {}
    M.__libs["LibDBIcon-1.0"] = {
        Register = function(_, name, object, db)
            M.minimapButtons[name] = { object = object, db = db, shown = not (db and db.hide) }
        end,
        IsRegistered = function(_, name) return M.minimapButtons[name] ~= nil end,
        Show = function(_, name)
            local b = M.minimapButtons[name]
            if b then b.shown = true end
        end,
        Hide = function(_, name)
            local b = M.minimapButtons[name]
            if b then b.shown = false end
        end,
        GetMinimapButton = function(_, name) return M.minimapButtons[name] end,
    }

    -- ── secure frames (phase 2: the send engine and the Comms Pad) ─────────────────────────────
    -- The client's protected-frame rules, modeled so a suite sees a refusal instead of trusting
    -- that none happened (testing-§1, fidelity rules 3 and 5). A frame built from a Secure*
    -- template is protected, and so is every ancestor below UIParent once it has such a child. In
    -- combat a PROTECTED call on a protected frame is refused: nothing is applied and the refusal
    -- is recorded in `blocked`. A click acts on ONE edge, as SecureActionButtonTemplate does: the
    -- `useOnKeyDown` attribute when set, else the ActionButtonUseKeyDown cvar; hooks still hear
    -- both edges. Frames under a root whose name starts "QuickComms" get regions of their own (the
    -- base aliases CreateTexture to the frame itself, its documented divergence) and record
    -- SetPoint, SetAlpha and SetSize, so a pad's chips, padlocks and flashes can be asserted on.
    M.blocked      = {}
    M.sentMacros   = {}
    M.stateDrivers = {}
    M.cvars        = { ActionButtonUseKeyDown = "1" }
    M.playerGUID   = "Player-1-00000001"

    M.GetCVarBool = function(name) return M.cvars[name] == "1" end
    M.C_CVar      = { GetCVarBool = function(name) return M.cvars[name] == "1" end }
    M.UnitGUID    = function(unit)
        if unit == "player" then return M.playerGUID end
        return nil
    end
    M.SOUNDKIT     = { TELL_MESSAGE = 3081 }
    M.ChatTypeInfo = {
        PARTY = { r = 0.67, g = 0.67, b = 1.0 }, RAID = { r = 1.0, g = 0.5, b = 0.0 },
        INSTANCE_CHAT = { r = 1.0, g = 0.5, b = 0.0 }, RAID_WARNING = { r = 1.0, g = 0.28, b = 0.0 },
        SAY = { r = 1.0, g = 1.0, b = 1.0 }, YELL = { r = 1.0, g = 0.25, b = 0.25 },
    }

    local function refuse(frame, call)
        M.blocked[#M.blocked + 1] = { frame = frame, call = call }
    end

    local PROTECTED_CALLS = { "SetAttribute", "Show", "Hide", "SetShown", "SetPoint", "ClearAllPoints",
        "SetAllPoints", "SetParent", "SetScale", "SetSize", "SetWidth", "SetHeight", "RegisterForClicks",
        "EnableMouse", "StartMoving", "StopMovingOrSizing", "SetFrameStrata", "SetFrameLevel", "SetMovable",
        "SetClampedToScreen" }

    local function protect(frame)
        if frame.__protected then return end
        frame.__protected = true
        for _, call in ipairs(PROTECTED_CALLS) do
            local inner = frame[call]
            frame[call] = function(self, ...)
                if M.inCombat then
                    refuse(self, call)
                    return self
                end
                return inner(self, ...)
            end
        end
    end

    -- A texture or font string of its own. Getters the region does not record answer 0, so a
    -- library measuring a label gets a number rather than a table.
    local function region(kind)
        local r = { __kind = kind, __shown = true }
        function r:Show() self.__shown = true return self end
        function r:Hide() self.__shown = false return self end
        function r:SetShown(v) self.__shown = not not v return self end
        function r:IsShown() return self.__shown end
        function r:IsVisible() return self.__shown end
        function r:SetText(v) self.__text = v return self end
        function r:GetText() return self.__text end
        function r:SetTexture(v) self.__texture = v return self end
        function r:SetColorTexture(cr, cg, cb, ca) self.__color = { cr, cg, cb, ca } return self end
        function r:SetVertexColor(cr, cg, cb, ca) self.__color = { cr, cg, cb, ca } return self end
        function r:SetTextColor(cr, cg, cb, ca) self.__color = { cr, cg, cb, ca } return self end
        function r:SetAlpha(a) self.__alpha = a return self end
        function r:GetAlpha() return self.__alpha or 1 end
        return setmetatable(r, { __index = function(_, key)
            if type(key) ~= "string" then return nil end
            if key:match("^Get") then return function() return 0 end end
            if key:match("^%u") then return function(self) return self end end
            return nil
        end })
    end

    local function ours(frame)
        local f = frame
        while type(f) == "table" do
            if type(f.__name) == "string" and f.__name:find("^QuickComms") then return true end
            f = f.__parent
        end
        return false
    end

    local function dress(frame)
        frame.CreateTexture = function() return region("Texture") end
        frame.CreateFontString = function() return region("FontString") end
        frame.__points = {}
        frame.SetPoint = function(self, point, rel, relPoint, x, y)
            self.__points[#self.__points + 1] = { point, rel, relPoint, x, y }
            return self
        end
        frame.ClearAllPoints = function(self)
            self.__points = {}
            return self
        end
        frame.GetPoint = function(self, i)
            local p = self.__points[i or 1]
            if not p then return nil end
            return p[1], p[2], p[3], p[4], p[5]
        end
        frame.SetAlpha = function(self, a)
            self.__alpha = a
            return self
        end
        frame.GetAlpha = function(self) return self.__alpha or 1 end
        frame.SetSize = function(self, w, h)
            self.__w, self.__h = w, h
            return self
        end
    end

    local function actsOn(button, down)
        local useDown = button.__attrs.useOnKeyDown
        if useDown == nil then useDown = M.cvars.ActionButtonUseKeyDown == "1" end
        return (down and true or false) == (useDown and true or false)
    end

    local function secureOnClick(button, _, down)
        if not actsOn(button, down) then return end
        local a = button.__attrs
        if a.type == "macro" and type(a.macrotext) == "string" then
            M.sentMacros[#M.sentMacros + 1] = { text = a.macrotext, at = M.GetTime(), frame = button }
        end
    end

    local secureFrames = {}
    local baseCreateFrame = M.CreateFrame
    M.CreateFrame = function(frameType, name, parent, template)
        local f = baseCreateFrame(frameType, name, parent, template)
        if ours(f) then dress(f) end
        if type(template) == "string" and template:find("Secure", 1, true) then
            if M.inCombat then refuse(f, "CreateFrame") end
            f.__attrs, f.__clicks = {}, {}
            f.GetName = function() return name end
            f.SetAttribute = function(self, key, value)
                self.__attrs[key] = value
                return self
            end
            f.GetAttribute = function(self, key) return self.__attrs[key] end
            f.RegisterForClicks = function(self, ...)
                self.__clicks = { ... }
                return self
            end
            f.__scripts.OnClick = secureOnClick
            protect(f)
            local p = parent
            while type(p) == "table" and p ~= M.UIParent do
                protect(p)
                p = p.__parent
            end
            secureFrames[#secureFrames + 1] = f
        end
        return f
    end
    M.__secureFrames = function() return secureFrames end

    M.__click = function(button, mouseButton)
        mouseButton = mouseButton or "LeftButton"
        local function registered(edge)
            for _, c in ipairs(button.__clicks or {}) do
                if c == "Any" .. edge or c == mouseButton .. edge then return true end
            end
            return false
        end
        if registered("Down") then button:__fire("OnClick", mouseButton, true) end
        if registered("Up") then button:__fire("OnClick", mouseButton, false) end
    end

    -- "[combat] a; [nocombat] b; c" or "a": the first clause whose condition holds. Any other
    -- bracketed condition raises, so a driver the mock cannot model fails loudly instead of being
    -- skipped.
    local CONDITIONS = {
        combat   = function() return M.inCombat end,
        nocombat = function() return not M.inCombat end,
    }
    local function evaluate(expression)
        for clause in (expression .. ";"):gmatch("([^;]*);") do
            local c = clause:match("^%s*(.-)%s*$")
            if c:sub(1, 1) == "[" then
                local cond, value = c:match("^%[(%w+)%]%s*(%S+)$")
                if not (cond and CONDITIONS[cond]) then
                    error("wow_mock: unsupported state-driver condition: " .. c, 2)
                end
                if CONDITIONS[cond]() then return value end
            elseif c ~= "" then
                return c
            end
        end
        return nil
    end

    -- The driver is the secure environment's own: it shows and hides past the combat refusal.
    M.__applyStateDrivers = function()
        for frame, drivers in pairs(M.stateDrivers) do
            local value = drivers.visibility and evaluate(drivers.visibility)
            if value == "show" then
                frame.__shown = true
            elseif value == "hide" then
                frame.__shown = false
            end
        end
    end

    M.RegisterStateDriver = function(frame, state, expression)
        if M.inCombat then
            refuse(frame, "RegisterStateDriver")
            return
        end
        M.stateDrivers[frame] = M.stateDrivers[frame] or {}
        M.stateDrivers[frame][state] = expression
        M.__applyStateDrivers()
    end

    M.UnregisterStateDriver = function(frame, state)
        if M.inCombat then
            refuse(frame, "UnregisterStateDriver")
            return
        end
        if M.stateDrivers[frame] then M.stateDrivers[frame][state] = nil end
    end

    M.__setCombat = function(on)
        M.inCombat = on and true or false
        M.__applyStateDrivers()
    end

    return M
end

return build
