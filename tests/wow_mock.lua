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
--   restrictedBindings  [key] = { owner, target, button }: what a header's snippet bound with SetBindingClick (the newest
--                  owner's; __bindingStacks keeps every owner's, so a ClearBindings hands the key back)
--   overrideBindings    [key] = { owner, name, button }: SetOverrideBindingClick (refused in combat)
--   bindingActions      [key] = the action the player's own WoW binding names (GetBindingAction)
--   bindingKeys         [command] = the key the player bound to a command in WoW's menu (GetBindingKey)
--   cursor              { x, y }: GetCursorPosition's answer
--   __named[name]       every named frame (a binding clicks a frame by its name)
--   __pressKey(key)     a key press: a snippet's binding first, then an override binding; false if unbound
--   __runSnippet(h, params, body, ...)  run restricted source in header h's environment
-- A frame made from a SecureHandler template runs its `_onclick` attribute as a snippet on a click;
-- its snippets run in its own environment (`h.__env`, globals persist), where the protected calls
-- refused in combat are allowed. The restricted handle methods raise outside a snippet; a WrapScript
-- on a button that already has an OnClick hook raises (the client's wrap discards the hook).

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

    -- Inside a restricted snippet (a SecureHandler header's), the protected calls the insecure side is
    -- refused in combat are allowed: the restricted environment's own privilege.
    local secureDepth = 0

    local PROTECTED_CALLS = { "SetAttribute", "Show", "Hide", "SetShown", "SetPoint", "ClearAllPoints",
        "SetAllPoints", "SetParent", "SetScale", "SetSize", "SetWidth", "SetHeight", "RegisterForClicks",
        "EnableMouse", "StartMoving", "StopMovingOrSizing", "SetFrameStrata", "SetFrameLevel", "SetMovable",
        "SetClampedToScreen", "Execute", "WrapScript", "SetFrameRef" }

    local function protect(frame)
        if frame.__protected then return end
        frame.__protected = true
        for _, call in ipairs(PROTECTED_CALLS) do
            local inner = frame[call]
            frame[call] = function(self, ...)
                if M.inCombat and secureDepth == 0 then
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
        frame.GetCenter = function(self) return self.__cx or 0, self.__cy or 0 end
        frame.GetEffectiveScale = function() return 1 end
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

    -- ── secure handlers and key bindings (phase 4: the Comms Dial) ──────────────────────────────
    M.restrictedBindings = {}
    M.__bindingStacks    = {}   -- [key] = { entry, ... }: every owner's binding of the key, newest last
    M.overrideBindings   = {}
    M.bindingActions     = {}
    M.bindingKeys        = {}
    M.cursor             = { x = 0, y = 0 }
    M.__named            = {}

    -- What a snippet may reach besides its handles. The client's restricted environment is wider;
    -- these are the ones this addon's snippets use, so a snippet reaching for anything else fails here.
    local SNIPPET_GLOBALS = { tonumber = tonumber, tostring = tostring, type = type, select = select,
        math = math, string = string }

    local makers = {}
    local function maker(params, body)
        local key = params .. "\0" .. body
        local fn = makers[key]
        if not fn then
            local chunk, err = loadstring("return function(" .. params .. ")\n" .. body .. "\nend", "=snippet")
            if not chunk then error("wow_mock: a snippet does not compile: " .. tostring(err), 3) end
            makers[key], fn = chunk, chunk
        end
        return fn
    end

    -- Run `body` as a function of `params` in `header`'s environment, protected calls allowed.
    local function runSnippet(header, params, body, ...)
        header.__env = header.__env or setmetatable({}, { __index = SNIPPET_GLOBALS })
        local make = maker(params, body)
        setfenv(make, header.__env)
        local fn = make()
        secureDepth = secureDepth + 1
        local results = { pcall(fn, ...) }
        secureDepth = secureDepth - 1
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2, table.maxn(results))
    end
    M.__runSnippet = runSnippet

    local function restricted(name)
        if secureDepth == 0 then error("wow_mock: " .. name .. " is a restricted-environment call", 3) end
    end

    -- What a snippet may call on a handle beyond the frame's own methods.
    local function addHandleMethods(f)
        f.GetFrameRef = function(self, ref)
            restricted("GetFrameRef")
            return self.__frameRefs and self.__frameRefs[ref]
        end
        -- Several owners may bind one key, as the client's override bindings allow: each key keeps a
        -- stack, one entry per owner, the newest on top; `restrictedBindings[key]` is the top, the one a
        -- press routes to, and clearing an owner hands the key back to the entry beneath.
        f.SetBindingClick = function(self, _, key, target, button)
            restricted("SetBindingClick")
            local stack = M.__bindingStacks[key] or {}
            M.__bindingStacks[key] = stack
            for i = #stack, 1, -1 do
                if stack[i].owner == self then table.remove(stack, i) end
            end
            stack[#stack + 1] = { owner = self, target = target, button = button or "LeftButton" }
            M.restrictedBindings[key] = stack[#stack]
        end
        f.ClearBindings = function(self)
            restricted("ClearBindings")
            for key, stack in pairs(M.__bindingStacks) do
                for i = #stack, 1, -1 do
                    if stack[i].owner == self then table.remove(stack, i) end
                end
                M.restrictedBindings[key] = stack[#stack]
            end
        end
        f.RunAttribute = function(self, attr, ...)
            restricted("RunAttribute")
            local body = self.__attrs[attr]
            if type(body) ~= "string" then return nil end
            return runSnippet(self, "self, ...", body, self, ...)
        end
    end

    -- The SecureHandler template's insecure-side API (refused in combat by protect()), its click (the
    -- `_onclick` snippet), and OnShow / OnHide on a change.
    local function makeHeader(f)
        f.__frameRefs = {}
        f.SetFrameRef = function(self, ref, frame)
            self.__frameRefs[ref] = frame
            return self
        end
        f.Execute = function(self, body)
            runSnippet(self, "self", body, self)
            return self
        end
        f.WrapScript = function(self, frame, script, pre, post)
            if script ~= "OnClick" then error("wow_mock: only an OnClick wrap is modeled", 2) end
            if frame.__hooked then
                error("wow_mock: WrapScript after HookScript(\"OnClick\"): the client's wrap discards the hook", 2)
            end
            local inner, header = frame.__scripts.OnClick, self
            frame.__scripts.OnClick = function(btn, button, down)
                local newButton, message
                if pre then
                    local r1, r2 = runSnippet(header, "self, button, down, owner", pre, btn, button, down, header)
                    if r1 == false then return end
                    newButton, message = r1, r2
                end
                if inner then inner(btn, newButton or button, down) end
                if post and message ~= nil then
                    runSnippet(header, "self, message, button, down, owner", post, btn, message, button, down, header)
                end
            end
            return self
        end
        f.__scripts.OnClick = function(self, button, down)
            local body = self.__attrs._onclick
            if type(body) == "string" then runSnippet(self, "self, button, down", body, self, button, down) end
        end
        -- OnShow / OnHide hooks are the addon's insecure code, even when a snippet's Show or Hide fires
        -- them: the restricted environment's privilege is dropped while they run.
        local show, hide = f.Show, f.Hide
        local function fireInsecure(self, script)
            local depth = secureDepth
            secureDepth = 0
            local ok, err = pcall(self.__fire, self, script)
            secureDepth = depth
            if not ok then error(err, 0) end
        end
        f.Show = function(self)
            local was = self.__shown
            show(self)
            if not was then fireInsecure(self, "OnShow") end
            return self
        end
        f.Hide = function(self)
            local was = self.__shown
            hide(self)
            if was then fireInsecure(self, "OnHide") end
            return self
        end
        f.SetShown = function(self, v)
            if v then return self:Show() end
            return self:Hide()
        end
    end

    local secureFrames = {}
    local baseCreateFrame = M.CreateFrame
    M.CreateFrame = function(frameType, name, parent, template)
        local f = baseCreateFrame(frameType, name, parent, template)
        if ours(f) then dress(f) end
        if type(name) == "string" then M.__named[name] = f end
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
            -- A wrap must come before an OnClick hook (makeHeader's WrapScript checks this flag).
            local hook = f.HookScript
            f.HookScript = function(self, script, fn)
                if script == "OnClick" then self.__hooked = true end
                return hook(self, script, fn)
            end
            addHandleMethods(f)
            if template:find("SecureHandler", 1, true) then makeHeader(f) end
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

    M.SetOverrideBindingClick = function(owner, _, key, name, button)
        if M.inCombat then
            refuse(owner, "SetOverrideBindingClick")
            return
        end
        M.overrideBindings[key] = { owner = owner, name = name, button = button or "LeftButton" }
    end

    M.ClearOverrideBindings = function(owner)
        if M.inCombat then
            refuse(owner, "ClearOverrideBindings")
            return
        end
        for key, b in pairs(M.overrideBindings) do
            if b.owner == owner then M.overrideBindings[key] = nil end
        end
    end

    M.GetBindingAction = function(key) return M.bindingActions[key] or "" end
    M.GetBindingKey = function(command) return M.bindingKeys[command] end
    M.GetCursorPosition = function() return M.cursor.x, M.cursor.y end

    --- A key press as the client routes it: a snippet's binding first, then an override binding;
    --- the target is clicked with the binding's button, down then up as `__click` presses it.
    --- @return boolean routed
    M.__pressKey = function(key)
        local b = M.restrictedBindings[key] or M.overrideBindings[key]
        if not b then return false end
        local target = b.target or b.name
        if type(target) == "string" then target = M.__named[target] end
        if type(target) ~= "table" then return false end
        M.__click(target, b.button)
        return true
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
