-- tests/skin_surfaces.lua — the consumer facts of the kit's skin-switch test (skinning-§1): every
-- surface Quick Comms paints, declared for tests/_kit/test_skin_switch.lua. `tests/run.lua` calls this
-- with `enableAddon`. Not a suite. The kit flips Ka0s Default against a probe skin that gives every
-- token its own value, so a surface passes only if it reads a token. Each surface repaints through
-- the host's own pass (Surfaces.ApplyAll), which is what a skin change asks for. Coverage is this list.

local OWNER = "QuickComms"
local PAD, DIAL = "p1", "d2"

return function(enableAddon)
    local NS, mock

    local function host()
        if NS then return NS, mock end
        local Dh = dofile("tests/dial_helpers.lua")
        NS, mock = enableAddon()
        NS.Situation.ReadInputs = function() return Dh.MPLUS end
        NS.Situation.RefreshNow("test")
        return NS, mock
    end

    local function repaintPad()
        local snap = NS.Situation.Current()
        NS.Pad.Apply(PAD, NS.Surfaces.BuildPlan(PAD, NS.db.profile.pads[PAD], snap, NS.Surfaces.Deps(snap)))
    end
    local function padInstance()
        host()
        repaintPad()
        return NS.Pad.Instance(PAD)
    end
    local function firstButton() return padInstance().buttons.active[1] end

    local function repaintDial()
        local Dh = dofile("tests/dial_helpers.lua")
        NS.Dial.Apply(1, DIAL, Dh.planOf(NS))
    end
    local function dialInstance()
        host()
        repaintDial()
        return NS.Dial.Instance(DIAL)
    end

    -- Writes a block's "Use the skin's ..." rows, each of `keys`.
    local function follows(kind, id, block, keys)
        return function(on)
            local t = NS.db.profile[kind][id][block]
            for _, key in ipairs(keys) do t[key] = on end
        end
    end
    local function padFollows(block, ...) return follows("pads", PAD, block, { ... }) end
    local function dialFollows(block, ...) return follows("dials", DIAL, block, { ... }) end

    -- A value a look only resolves, read off a mock paint target so the setter spy sees it.
    local function resolved(read)
        local target = { SetVertexColor = function() end }
        return function()
            host()
            return target
        end, function(t) t:SetVertexColor(read()) end
    end

    local surfaces = {
        { name = "a pad's window", companion = padFollows("look", "backgroundFromSkin", "borderColorFromSkin"),
            build = function() return padInstance().root end, paint = repaintPad },
        { name = "a pad's header", companion = padFollows("header", "backgroundFromSkin", "fontColorFromSkin"),
            build = function() return padInstance().header end, paint = repaintPad },
        { name = "a pad button's body", companion = padFollows("button", "backgroundFromSkin"),
            build = function() return firstButton().qcBg end, paint = repaintPad },
        { name = "a pad button's edge", companion = padFollows("button", "borderColorFromSkin"),
            build = function() return firstButton().qcEdge end, paint = repaintPad },
        { name = "a pad button's label", companion = padFollows("button", "fontColorFromSkin"),
            build = function() return firstButton().qcLabel end, paint = repaintPad },
        { name = "a pad button's refused veil", build = function() return firstButton().qcDim end, paint = repaintPad },
        { name = "a pad button's cooling veil", build = function() return firstButton().qcCool end, paint = repaintPad },
        { name = "a pad button's hover wash", build = function() return firstButton().qcHover end, paint = repaintPad },
        { name = "a pad button's padlock", build = function() return firstButton().qcLock end, paint = repaintPad },
        { name = "a dial's slices", companion = dialFollows("slice", "backgroundFromSkin"),
            build = function() return dialInstance().rings.active[1].qcFills[1] end, paint = repaintDial },
        { name = "a dial's hub", companion = dialFollows("hub", "backgroundFromSkin"),
            build = function() return dialInstance().header.qcHub end, paint = repaintDial },
        { name = "a dial's pointer", companion = dialFollows("slice", "pointerColorFromSkin"),
            build = function() return dialInstance().header.qcPointer.qcArrow end, paint = repaintDial },
    }

    local function add(name, read, companion)
        local build, paint = resolved(read)
        surfaces[#surfaces + 1] = { name = name, companion = companion, build = build, paint = paint }
    end

    -- An icon's border and glow go to frames and a glow library the mock does not draw: their colors,
    -- as IconStyle hands them over.
    local function iconConfig()
        local icon = NS.db.profile.pads[PAD].icon
        icon.borderShow, icon.glowEnabled = true, true
        return NS.IconStyle.Config(icon, "pad")
    end
    add("an icon's border", function() return unpack(iconConfig().border.color) end,
        padFollows("icon", "borderColorFromSkin"))
    add("an icon's glow", function()
        local icon = NS.db.profile.pads[PAD].icon
        icon.glowEnabled = true
        return unpack(NS.IconStyle.GlowConfig(icon, "s").color)
    end, padFollows("icon", "glowColorFromSkin"))
    add("a pad button's shine", function()
        return unpack(NS.PadRender.ButtonLook(NS.db.profile.pads[PAD].button).shine.tint)
    end, padFollows("button", "shineFromSkin"))

    add("a section title's text", function()
        local f = NS.PadRender.TitleFont(NS.db.profile.pads[PAD].section)
        return f.r, f.g, f.b, f.a
    end, padFollows("section", "fontColorFromSkin"))
    add("a dial's page dot", function()
        local d = NS.db.profile.dials[DIAL]
        local c = NS.DialRender.Look(120, d.label, d.slice, d).paging.dot
        return c.r, c.g, c.b, c.a
    end, dialFollows("page", "dotColorFromSkin"))

    -- The icon browser's cell and hover art, and the settings pages' marks. A modal's dim is pinned by
    -- tests/test_skin_windows.lua, which opens the popup this file does not.
    surfaces[#surfaces + 1] = { name = "the icon browser's selected cell", build = function()
        host()
        local B = NS.addon.Settings.IconBrowser
        B.Open({ owner = "test", onChoose = function() end })
        return B.cells[1].selected
    end }

    -- A real Texture: the base mock's regions are not, and S.Mark and S.HoverArt draw only on one.
    local function paintedTexture()
        local restore = dofile("tests/_kit/mock_paint.lua")(mock)
        local tex = mock.CreateFrame("Frame"):CreateTexture()
        restore()
        return tex
    end

    surfaces[#surfaces + 1] = { name = "a cell's hover art", scope = "panel", build = function()
        host()
        local tex = paintedTexture()
        NS.Skin.HoverArt(tex, { panel = true })
        return tex
    end }

    surfaces[#surfaces + 1] = { name = "a settings row's remove mark", scope = "panel", build = function()
        host()
        local ace = mock.LibStub("AceGUI-3.0")
        local w = ace:Create("Icon")
        local tex = paintedTexture()
        w.image = tex
        NS.addon.Settings.Editors.RemoveMark(w)
        return tex
    end }

    return {
        owner = OWNER,
        skin = function()
            host()
            return mock.LibStub("LibKa0s-Skin-1.0")
        end,
        surfaces = surfaces,
    }
end
