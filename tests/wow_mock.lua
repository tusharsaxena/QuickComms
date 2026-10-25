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
--   generalChannel C_ChatInfo.GetGeneralChannelLocalID()'s answer (1 by default; nil = not joined)
--   macroIcons, macroItemIcons  what GetMacroIcons / GetMacroItemIcons fill the handed table with
--   restrictionStates  C_RestrictedActions' state per Enum.AddOnRestrictionType value (absent = 0)
--   prints         every line handed to the Lua global `print` (the printer's sink)
--   popupsShown    every StaticPopup_Show(which, ...) call, in order
--   ldbObjects     LibDataBroker objects by name; minimapButtons LibDBIcon registrations by name
--   fireEvent      fireEvent(name, ...) dispatches a game event to AceEvent handlers
--   blocked        every protected call refused in combat: { frame, call } (ADDON_ACTION_BLOCKED)
--   sentMacros     every macrotext a secure click ran: { text, at, frame }
--   stateDrivers   [frame] = { [state] = expression }
--   cvars          GetCVarBool's answers ("1" is true); ActionButtonUseKeyDown defaults on
--   modifiers      { shift, ctrl, alt }: the keys held (IsShiftKeyDown and the rest); a secure click
--                  reads its attributes with that prefix, as SecureButton_GetModifiedAttribute does
--   playerGUID     UnitGUID("player")
--   playerMap      C_Map.GetBestMapForUnit("player")'s map id (nil: no map, as in an instance)
--   playerPos      { x, y } (fractions 0-1): C_Map.GetPlayerMapPosition's GetXY on playerMap (nil: none)
--   __click(b[, mouseButton])  a full press: the registered down edge, then the up edge; each edge
--                  runs the button's PreClick script before its OnClick, as the client does
--   __setCombat(on)            sets inCombat and re-evaluates every visibility driver
--   restrictedBindings  [key] = { owner, target, button }: what a header's snippet bound with SetBindingClick (the newest
--                  owner's; __bindingStacks keeps every owner's, so a ClearBindings hands the key back)
--   overrideBindings    [key] = { owner, name, button }: SetOverrideBindingClick (refused in combat)
--   bindingActions      [key] = the action the player's own WoW binding names (GetBindingAction)
--   bindingKeys         [command] = the first key the player bound to a command in WoW's menu; GetBindingKey
--                  answers it, then every other key bindingActions names for the command (a second key)
--   SetBinding(key, command)  WoW's own binding (refused in combat): key -> command in bindingActions,
--                  and the command's first key in bindingKeys; a nil command unbinds the key
--   bindingSaves        every SaveBindings(set) call's set, in order (refused in combat)
--   bindingSet          GetCurrentBindingSet()'s answer (1, the account's; 2, the character's)
--   cursor              { x, y }: GetCursorPosition's answer
--   __named[name]       every named frame (a binding clicks a frame by its name)
--   missingTemplates    [template] = true makes CreateFrame raise on it, as a client without it does;
--                  a SettingsFrameTemplate frame gets the template's Bg, NineSlice.Text and ClosePanelButton
--   __pressKey(key)     a key press: a snippet's binding first, then an override binding; false if unbound
--   __runSnippet(h, params, body, ...)  run restricted source in header h's environment
-- A secure button's click runs `type = "macro"` (its macrotext) or `type = "click"` (clicks its
-- `clickbutton` with the same button), each read as `type-<button>` first (SecureButton_
-- GetModifiedAttribute: LeftButton is "1", a non-mouse name such as "w3" itself); Click(button)
-- presses it as `__click` does. The restricted GetMousePosition answers the cursor's place over a
-- frame (fractions from its bottom left; nil outside). An addon Button takes the mouse until
-- EnableMouse(false) (IsMouseEnabled).
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

    -- C_ChatInfo: chatLockdown is InChatMessagingLockdown's answer; generalChannel is the number the
    -- zone's General channel holds (QF-04, F-007), GetGeneralChannelLocalID's answer: joined as /1 by
    -- default, nil when not joined, another number when the player reordered the channels.
    M.chatLockdown = false
    M.generalChannel = 1
    M.C_ChatInfo = {
        InChatMessagingLockdown = function() return M.chatLockdown end,
        GetGeneralChannelLocalID = function() return M.generalChannel end,
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

    -- The macro icon selector's lists: each reader fills the table it is handed, as the client's do.
    -- A list left empty is a client whose icon list has not loaded yet.
    M.macroIcons     = { 136243, 136116, 132089 }
    M.macroItemIcons = { 134400, 133784, 136243 }
    M.GetMacroIcons = function(t)
        for _, v in ipairs(M.macroIcons) do t[#t + 1] = v end
    end
    M.GetMacroItemIcons = function(t)
        for _, v in ipairs(M.macroItemIcons) do t[#t + 1] = v end
    end

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

    -- AceGUI's Icon carries its texture as `image` from the moment it is made, as the real widget
    -- does, so a glyph dressed in an atlas (`image:SetAtlas`, recorded as `image.atlas`) has a
    -- texture to dress, and a tint (SetVertexColor, recorded as `image.vertexColor`, white until set). SetImage still records its arguments at `image[1..n]`, the base's shape, and
    -- a new path replaces the atlas, as SetTexture does in the client.
    M.__libs["AceGUI-3.0"]:RegisterWidgetType("Icon", function()
        local w = M.__makeAceGUIWidget("Icon")
        local texture = { vertexColor = { 1, 1, 1 } }
        function texture.SetAtlas(tex, name) tex.atlas = name; return tex end
        function texture.SetVertexColor(tex, r, g, b) tex.vertexColor = { r, g, b }; return tex end
        w.image = texture
        function w:SetImage(...)
            for k in pairs(texture) do if type(k) == "number" then texture[k] = nil end end
            texture.atlas = nil
            for i = 1, select("#", ...) do texture[i] = (select(i, ...)) end
            return self
        end
        return w
    end)

    -- AceGUI's Label likewise carries its image texture from the start, and the real widget's pool
    -- hands it back with the last vertex color it was given, so a row drawn white must say so. The
    -- texture records SetVertexColor at `image.vertexColor` (white until set); SetImage records its
    -- arguments at `image[1..n]`, as the base's Label does.
    M.__libs["AceGUI-3.0"]:RegisterWidgetType("Label", function()
        local w = M.__makeAceGUIWidget("Label")
        -- The face it was given, recorded as `fontObject`.
        function w:SetFontObject(font) self.fontObject = font; return self end
        local texture = { vertexColor = { 1, 1, 1 } }
        function texture.SetVertexColor(tex, r, g, b) tex.vertexColor = { r, g, b }; return tex end
        w.image = texture
        function w:SetImage(...)
            for k in pairs(texture) do if type(k) == "number" then texture[k] = nil end end
            for i = 1, select("#", ...) do texture[i] = (select(i, ...)) end
            return self
        end
        return w
    end)

    -- ── secure frames (phase 2: the send engine and the Comms Pad) ─────────────────────────────
    -- The client's protected-frame rules, modeled so a suite sees a refusal instead of trusting
    -- that none happened (testing-§1, fidelity rules 3 and 5). A frame built from a Secure*
    -- template is protected, and so is every ancestor below UIParent once it has such a child. In
    -- combat a PROTECTED call on a protected frame is refused: nothing is applied and the refusal
    -- is recorded in `blocked`. A click acts on ONE edge, as SecureActionButtonTemplate does: the
    -- `useOnKeyDown` attribute when set, else the ActionButtonUseKeyDown cvar; hooks still hear
    -- both edges. Frames under a root whose name starts "QuickComms" get regions of their own (the
    -- base aliases CreateTexture to the frame itself, its documented divergence) and record
    -- SetPoint, SetAlpha and SetSize, so a pad's buttons, padlocks and flashes can be asserted on.
    M.blocked      = {}
    M.sentMacros   = {}
    M.stateDrivers = {}
    M.cvars        = { ActionButtonUseKeyDown = "1" }
    M.modifiers    = {}
    M.IsShiftKeyDown   = function() return M.modifiers.shift == true end
    M.IsControlKeyDown = function() return M.modifiers.ctrl == true end
    M.IsAltKeyDown     = function() return M.modifiers.alt == true end
    M.playerGUID   = "Player-1-00000001"
    M.playerMap    = nil
    M.playerPos    = nil
    M.C_Map = {
        GetBestMapForUnit = function(unit)
            if unit == "player" then return M.playerMap end
            return nil
        end,
        GetPlayerMapPosition = function(mapID, unit)
            if unit ~= "player" or mapID == nil or mapID ~= M.playerMap or not M.playerPos then return nil end
            local pos = M.playerPos
            return { GetXY = function() return pos[1], pos[2] end }
        end,
    }

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
        CHANNEL1 = { r = 1.0, g = 0.75, b = 0.75 },
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
        -- The client answers nil for a texture with no file set (the shine overlay asks, modules/Shine.lua).
        function r:GetTexture() return self.__texture end
        function r:SetBlendMode(v) self.__blend = v return self end
        function r:GetBlendMode() return self.__blend or "BLEND" end
        -- Turns and masks (the dial's slices and their shine overlay, modules/Dial_Slices.lua), recorded so
        -- a test can ask how a texture is turned and what cuts it.
        function r:SetRotation(v) self.__rotation = v return self end
        function r:GetRotation() return self.__rotation or 0 end
        function r:AddMaskTexture(m)
            self.__masks = self.__masks or {}
            self.__masks[#self.__masks + 1] = m
            return self
        end
        function r:SetColorTexture(cr, cg, cb, ca) self.__color = { cr, cg, cb, ca } return self end
        function r:SetVertexColor(cr, cg, cb, ca) self.__color = { cr, cg, cb, ca } return self end
        function r:SetTextColor(cr, cg, cb, ca) self.__color = { cr, cg, cb, ca } return self end
        -- A font string's face, recorded; true as the client answers for a face it accepts.
        function r:SetFont(path, size, flags) self.__font = { path, size, flags } return true end
        function r:SetShadowOffset(x, y) self.__shadow = { x, y } return self end
        function r:SetAlpha(a) self.__alpha = a return self end
        -- The Icons tab's texture calls (modules/IconStyle.lua), recorded so a crop, a desaturation
        -- and an icon size can be asserted on.
        function r:SetTexCoord(...) self.__texCoord = { ... } return self end
        function r:SetDesaturated(v) self.__desaturated = v return self end
        function r:SetSize(w, h) self.__size = { w, h } return self end
        function r:GetAlpha() return self.__alpha or 1 end
        -- Anchors, recorded (the pad header's situation text is asserted on its left edge); no anchor
        -- answers nil, as the client does.
        r.__points = {}
        function r:SetPoint(point, rel, relPoint, x, y)
            self.__points[#self.__points + 1] = { point, rel, relPoint, x, y }
            return self
        end
        function r:ClearAllPoints() self.__points = {} return self end
        -- SetAllPoints, recorded as the region it covers (nil: the parent), so a test can ask what a
        -- texture is laid over.
        function r:SetAllPoints(rel) self.__allPoints = rel or self.__parent return self end
        function r:GetPoint(i)
            local p = self.__points[i or 1]
            if not p then return nil end
            return p[1], p[2], p[3], p[4], p[5]
        end
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
            if f.__qcOurs then return true end
            f = f.__parent
        end
        return false
    end

    -- A region made on a frame knows it (GetParent), so a test can ask which layer drew it.
    local function regionOn(frame, kind)
        local r = region(kind)
        r.__parent = frame
        r.GetParent = function(x) return x.__parent end
        return r
    end

    local function dress(frame)
        frame.CreateTexture = function(self, _, layer, _, sub)
            local r = regionOn(self, "Texture")
            r.__layer, r.__sublevel = layer, sub   -- the draw layer, so a test can ask what sits over what
            return r
        end
        frame.CreateFontString = function(self) return regionOn(self, "FontString") end
        frame.CreateMaskTexture = function(self, _, layer, _, sub)
            local r = regionOn(self, "MaskTexture")
            r.__layer, r.__sublevel = layer, sub
            return r
        end
        -- Frame levels as the client keeps them: a child sits one above its parent until it is set.
        frame.SetFrameLevel = function(self, level)
            self.__level = level
            return self
        end
        frame.GetFrameLevel = function(self)
            if self.__level then return self.__level end
            local p = rawget(self, "__parent")
            return (type(p) == "table" and type(rawget(p, "GetFrameLevel")) == "function" and p:GetFrameLevel() or 0) + 1
        end
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
        -- A disabled control runs no OnEnter or OnLeave in the client unless told to
        -- (SetMotionScriptsWhileDisabled): recorded, so a disabled control's tooltip can be asserted on.
        frame.SetMotionScriptsWhileDisabled = function(self, on)
            self.__motionWhileDisabled = on and true or false
            return self
        end
        frame.GetMotionScriptsWhileDisabled = function(self) return self.__motionWhileDisabled == true end
        frame.GetCenter = function(self) return self.__cx or 0, self.__cy or 0 end
        frame.GetEffectiveScale = function() return 1 end
        -- Mouse input, as the client keeps it: a Button takes the mouse until told otherwise (the dial's
        -- wedges are turned off, dial polish 2026-10-21), any other frame does not.
        frame.__mouse = frame.__frameType == "Button"
        frame.EnableMouse = function(self, on)
            self.__mouse = on and true or false
            return self
        end
        frame.IsMouseEnabled = function(self) return self.__mouse == true end
        frame.SetSize = function(self, w, h)
            self.__w, self.__h = w, h
            return self
        end
        frame.SetHeight = function(self, h)
            self.__h = h
            return self
        end
    end

    -- A region's anchors, as the client keeps them: SetPoint replaces the anchor of the same point,
    -- GetPoint(i) and GetNumPoints read them. `points` are the anchors AceGUI's constructor sets,
    -- each { point, relativeTo, relativePoint, x, y }.
    local function anchored(r, points)
        r.__anchors = {}
        function r.SetPoint(self, point, rel, relPoint, x, y)
            for _, a in ipairs(self.__anchors) do
                if a[1] == point then
                    a[2], a[3], a[4], a[5] = rel, relPoint, x, y
                    return self
                end
            end
            self.__anchors[#self.__anchors + 1] = { point, rel, relPoint, x, y }
            return self
        end
        function r.GetNumPoints(self) return #self.__anchors end
        function r.GetPoint(self, i)
            local a = self.__anchors[i]
            if not a then return nil end
            return a[1], a[2], a[3], a[4], a[5]
        end
        for _, p in ipairs(points) do r:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
        return r
    end
    M.__anchored = anchored

    -- AceGUI's EditBox draws its label as a font string of its own (`w.label`, GameFontNormalSmall,
    -- anchored across the top of the widget): the kit's fake keeps only the label's text. Here the
    -- label is a region that shows what SetLabel gave it, answers a face of size 10 (GetFont) and a
    -- width of 6 per letter (GetStringWidth), and frames made on the box's frame are dressed, so a
    -- glyph anchored beside the label (settings/CalloutPopup.lua) records its points and size. The
    -- label keeps its anchors (AceGUI's: TOPLEFT and TOPRIGHT of the widget, 2 down).
    M.__libs["AceGUI-3.0"]:RegisterWidgetType("EditBox", function()
        local w = M.__makeAceGUIWidget("EditBox")
        local label = anchored(region("FontString"), {
            { "TOPLEFT", w.frame, "TOPLEFT", 0, -2 }, { "TOPRIGHT", w.frame, "TOPRIGHT", 0, -2 } })
        function label.GetFont() return "Fonts\\FRIZQT__.TTF", 10, "" end
        function label.GetStringWidth(r) return 6 * #(r.__text or "") end
        w.label = label
        w.frame.__qcOurs = true
        function w:SetLabel(v)
            self.labelText = v
            label:SetText(v)
            return self
        end
        return w
    end)

    -- AceGUI's Dropdown: its label (`w.label`, anchored across the top of the widget) and the
    -- dropdown frame (`w.dropdown`, 15 left of the widget and 14 down under a label, its art inset
    -- in it), with the anchors AceGUI sets. SetLabel puts the dropdown's TOPLEFT back, as AceGUI's
    -- does on every acquire.
    M.__libs["AceGUI-3.0"]:RegisterWidgetType("Dropdown", function()
        local w = M.__makeAceGUIWidget("Dropdown")
        w.label = anchored(region("FontString"), {
            { "TOPLEFT", w.frame, "TOPLEFT", 0, 0 }, { "TOPRIGHT", w.frame, "TOPRIGHT", 0, 0 } })
        w.dropdown = anchored(region("Frame"), {
            { "TOPLEFT", w.frame, "TOPLEFT", -15, 0 }, { "BOTTOMRIGHT", w.frame, "BOTTOMRIGHT", 17, 0 } })
        function w:SetLabel(v)
            self.labelText = v
            self.label:SetText(v)
            self.dropdown:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -15, v and -14 or 0)
            return self
        end
        return w
    end)

    -- AceGUI's Heading: its two rule textures (`w.left`, `w.right`), 3 in from the widget's sides.
    M.__libs["AceGUI-3.0"]:RegisterWidgetType("Heading", function()
        local w = M.__makeAceGUIWidget("Heading")
        w.left = anchored(region("Texture"), { { "LEFT", w.frame, "LEFT", 3, 0 } })
        w.right = anchored(region("Texture"), { { "RIGHT", w.frame, "RIGHT", -3, 0 } })
        return w
    end)

    -- AceGUI's AddChild takes the widget to insert the child before, as its second argument (the
    -- callout popup puts its column gap between two widgets this way); the kit's fake appends.
    do
        local gui = M.__libs["AceGUI-3.0"]
        local create = gui.Create
        gui.Create = function(self, wtype, ...)
            local w = create(self, wtype, ...)
            local add = w.AddChild
            function w.AddChild(widget, child, before)
                if before then
                    for i, sibling in ipairs(widget.children) do
                        if sibling == before then
                            table.insert(widget.children, i, child)
                            return widget
                        end
                    end
                end
                return add(widget, child)
            end
            return w
        end
    end

    -- GameTooltip, recorded (fidelity rule 3): the owner and anchor SetOwner names, and the lines
    -- since, each { left, right } (SetText and AddLine have no right side). SetOwner starts a new
    -- tooltip, as the client's does.
    local tip = M.GameTooltip
    tip.__lines = {}
    function tip.SetOwner(t, owner, anchor)
        t.__owner, t.__anchor, t.__lines = owner, anchor, {}
        return t
    end
    function tip.ClearLines(t) t.__lines = {} return t end
    -- Its anchors, recorded as a region's are, so a tooltip placed by hand (the dial's, outside the
    -- dial) can be asserted on.
    tip.__points = {}
    function tip.ClearAllPoints(t) t.__points = {} return t end
    function tip.SetPoint(t, point, rel, relPoint, x, y)
        t.__points[#t.__points + 1] = { point, rel, relPoint, x, y }
        return t
    end
    function tip.GetPoint(t, i)
        local p = t.__points[i or 1]
        if not p then return nil end
        return p[1], p[2], p[3], p[4], p[5]
    end
    function tip.SetText(t, text)
        t.__lines = { { text } }
        return t
    end
    function tip.AddLine(t, text)
        t.__lines[#t.__lines + 1] = { text }
        return t
    end
    function tip.AddDoubleLine(t, left, right)
        t.__lines[#t.__lines + 1] = { left, right }
        return t
    end

    local function actsOn(button, down)
        local useDown = button.__attrs.useOnKeyDown
        if useDown == nil then useDown = M.cvars.ActionButtonUseKeyDown == "1" end
        return (down and true or false) == (useDown and true or false)
    end

    -- SecureButton_GetModifiedAttribute: the suffix is a mouse button by its number, any other button
    -- name (a catcher's "w3") as itself; the prefix is the modifiers held ("alt-ctrl-shift-", in that
    -- order). It reads <prefix><name>-<suffix>, then *<name>-<suffix>, then <prefix><name>*, *<name>*,
    -- and last the plain name, so while a modifier is held a plain `type-w3` is never read.
    local SUFFIX = { LeftButton = "1", RightButton = "2", MiddleButton = "3", Button4 = "4", Button5 = "5" }
    local function modified(button, name, mouseButton)
        local a = button.__attrs
        local mods = M.modifiers or {}
        local prefix = (mods.alt and "alt-" or "") .. (mods.ctrl and "ctrl-" or "") .. (mods.shift and "shift-" or "")
        local suffix = SUFFIX[mouseButton] or mouseButton
        local keys = {}
        if suffix then
            local sfx = "-" .. tostring(suffix)
            keys[#keys + 1] = prefix .. name .. sfx
            keys[#keys + 1] = "*" .. name .. sfx
        end
        keys[#keys + 1] = prefix .. name .. "*"
        keys[#keys + 1] = "*" .. name .. "*"
        keys[#keys + 1] = name
        for _, k in ipairs(keys) do
            local v = a[k]
            if v ~= nil then return v end
        end
        return nil
    end

    -- The secure action: a macro runs its macrotext; a click (`type = "click"`) clicks its
    -- `clickbutton` with the same button, as SECURE_ACTIONS.click does. Both read the attribute for
    -- the clicking button first (`type-w3`, `clickbutton-w3`, with the modifier prefix or `*`), then the
    -- plain one.
    local function secureOnClick(button, mouseButton, down)
        if not actsOn(button, down) then return end
        local kind = modified(button, "type", mouseButton)
        if kind == "macro" then
            local text = modified(button, "macrotext", mouseButton)
            if type(text) == "string" then
                M.sentMacros[#M.sentMacros + 1] = { text = text, at = M.GetTime(), frame = button }
            end
        elseif kind == "click" then
            local delegate = modified(button, "clickbutton", mouseButton)
            if type(delegate) == "table" and delegate.Click then delegate:Click(mouseButton) end
        end
    end

    -- ── secure handlers and key bindings (phase 4: the Comms Dial) ──────────────────────────────
    M.restrictedBindings = {}
    M.__bindingStacks    = {}   -- [key] = { entry, ... }: every owner's binding of the key, newest last
    M.overrideBindings   = {}
    M.bindingActions     = {}
    M.bindingKeys        = {}
    M.bindingSaves       = {}
    M.bindingSet         = 1
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

    -- A frame's center for the restricted mouse read: through its CENTER anchor on another of the
    -- addon's frames (a dial's catcher on its ring, the ring on the header), else its own GetCenter, so
    -- it agrees with what the insecure side reads off the header.
    local function centerOf(f)
        local p = rawget(f, "__points") and f.__points[1]
        local rel = p and p[2]
        if p and p[1] == "CENTER" and (p[3] == nil or p[3] == "CENTER") and type(rel) == "table"
            and rawget(rel, "__points") then
            local rx, ry = centerOf(rel)
            return rx + (tonumber(p[4]) or 0), ry + (tonumber(p[5]) or 0)
        end
        local cx, cy = f:GetCenter()
        return tonumber(cx) or 0, tonumber(cy) or 0
    end

    -- What a snippet may call on a handle beyond the frame's own methods.
    local function addHandleMethods(f)
        -- The cursor over the frame, as fractions of its width and height from its bottom left (the
        -- client's restricted read); nil when the cursor is outside it or it has no size.
        f.GetMousePosition = function(self)
            restricted("GetMousePosition")
            local w, h = tonumber(rawget(self, "__w")) or 0, tonumber(rawget(self, "__h")) or 0
            if w <= 0 or h <= 0 then return nil end
            local cx, cy = centerOf(self)
            local scale = self:GetEffectiveScale()
            local x = (M.cursor.x / scale - (cx - w / 2)) / w
            local y = (M.cursor.y / scale - (cy - h / 2)) / h
            if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
            return x, y
        end
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

    -- OnShow / OnHide fired on a change, as the client fires them for any frame. They are the addon's
    -- insecure code, even when a snippet's Show or Hide fires them: the restricted environment's
    -- privilege is dropped while they run. Every secure frame takes it (a header, and a dial ring the
    -- header's snippets show and hide).
    local function liveShow(f)
        if f.__liveShow then return end
        f.__liveShow = true
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
        liveShow(f)
    end

    -- ── Blizzard's settings-window template (settings/CalloutPopup.lua's window) ─────────────────
    -- SettingsFrameTemplate's parentKeys, as Blizzard_SettingsPanelTemplates.xml declares them: Bg
    -- (FlatPanelBackgroundTemplate), NineSlice with its Text (the window title, GameFontNormal), and
    -- ClosePanelButton (UIPanelCloseButtonDefaultAnchors, whose own click hides the window). The
    -- title records what it is set to (`text`), and Bg answers its alpha (GetAlpha) and its frame level:
    -- 0 until set, as the template declares it (frameLevel="0", an absolute level, not the parent's
    -- plus one). A template named in `missingTemplates` raises, as CreateFrame does in a client without it.
    M.missingTemplates = {}
    local function dressSettingsFrame(f)
        local nine = M.CreateFrame("Frame", nil, f)
        local title = {}
        function title.SetText(t, v) t.text = v; return t end
        function title.GetText(t) return t.text end
        nine.Text = title
        f.NineSlice = nine
        local bg = M.CreateFrame("Frame", nil, f)
        function bg.SetAlpha(b, v) b.__alpha = v; return b end
        function bg.GetAlpha(b) return b.__alpha or 1 end
        function bg.SetFrameLevel(b, v) b.__level = v; return b end
        function bg.GetFrameLevel(b) return b.__level or 0 end
        f.Bg = bg
        local close = M.CreateFrame("Button", nil, f)
        close:SetScript("OnClick", function() f:Hide() end)
        f.ClosePanelButton = close
    end

    local secureFrames = {}
    local baseCreateFrame = M.CreateFrame
    M.CreateFrame = function(frameType, name, parent, template)
        if type(template) == "string" and M.missingTemplates[template] then
            error("CreateFrame: Couldn't find inherited node \"" .. template .. "\"", 2)
        end
        local f = baseCreateFrame(frameType, name, parent, template)
        if template == "SettingsFrameTemplate" then dressSettingsFrame(f) end
        if ours(f) then dress(f) end
        if type(name) == "string" then M.__named[name] = f end
        -- A plain Button records its registered clicks too (the client's default is LeftButtonUp), so
        -- `__click` and a CLICK binding (`__pressKey`) reach one only on an edge it registered.
        if frameType == "Button" and not (type(template) == "string" and template:find("Secure", 1, true)) then
            f.__clicks = { "LeftButtonUp" }
            f.RegisterForClicks = function(self, ...)
                self.__clicks = { ... }
                return self
            end
        end
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
            -- Button:Click(button): a virtual press, down then up as `__click` presses it (a
            -- `type = "click"` forward reaches its delegate this way).
            f.Click = function(self, mouseButton) M.__click(self, mouseButton) end
            -- A wrap must come before an OnClick hook (makeHeader's WrapScript checks this flag).
            local hook = f.HookScript
            f.HookScript = function(self, script, fn)
                if script == "OnClick" then self.__hooked = true end
                return hook(self, script, fn)
            end
            addHandleMethods(f)
            if template:find("SecureHandler", 1, true) then makeHeader(f) end
            liveShow(f)
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
        if registered("Down") then
            button:__fire("PreClick", mouseButton, true)
            button:__fire("OnClick", mouseButton, true)
        end
        if registered("Up") then
            button:__fire("PreClick", mouseButton, false)
            button:__fire("OnClick", mouseButton, false)
        end
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
    -- Every key bound to `command`: bindingKeys' first, then any other key bindingActions names it
    -- for (sorted), as the menu holds two per action.
    M.GetBindingKey = function(command)
        local first = M.bindingKeys[command]
        local rest = {}
        for key, action in pairs(M.bindingActions) do
            if action == command and key ~= first then rest[#rest + 1] = key end
        end
        table.sort(rest)
        if first == nil then return unpack(rest) end
        return first, unpack(rest)
    end

    M.SetBinding = function(key, command)
        if M.inCombat then
            refuse(nil, "SetBinding")
            return false
        end
        local prev = M.bindingActions[key]
        if prev and M.bindingKeys[prev] == key then M.bindingKeys[prev] = nil end
        M.bindingActions[key] = command
        if command and not M.bindingKeys[command] then M.bindingKeys[command] = key end
        return true
    end
    M.SaveBindings = function(set)
        if M.inCombat then
            refuse(nil, "SaveBindings")
            return
        end
        M.bindingSaves[#M.bindingSaves + 1] = set
    end
    M.GetCurrentBindingSet = function() return M.bindingSet end
    M.GetCursorPosition = function() return M.cursor.x, M.cursor.y end

    --- A key press as the client routes it: a snippet's binding first, then an override binding, then
    --- the player's own WoW binding when it is a CLICK one ("CLICK <frame>:<button>"); the target is
    --- clicked with the binding's button, down then up as `__click` presses it.
    --- @return boolean routed
    M.__pressKey = function(key)
        local b = M.restrictedBindings[key] or M.overrideBindings[key]
        if not b then
            local name, button = tostring(M.bindingActions[key] or ""):match("^CLICK ([^:]+):(.+)$")
            if name then b = { name = name, button = button } end
        end
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

    -- UIParent's frame level, as the client answers it: a band over UIParent (settings/ModalWindow.lua's
    -- catchers, item 030) is its level plus a named offset, and the base's metatable would hand back
    -- the frame itself.
    rawset(M.UIParent, "GetFrameLevel", function() return 0 end)

    return M
end

return build
