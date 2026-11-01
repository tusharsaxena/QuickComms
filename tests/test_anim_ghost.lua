-- tests/test_anim_ghost.lua — the ghost itself (#13, modules/Anim_Ghost.lua): what a capture copies and
-- what a pose draws, on recording frames and hand-made sources, because the mock's own regions swallow
-- most of what the ghost writes. The sweep behind tests/test_anim_surfaces.lua found every line here
-- could change with the suite still green.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function near(a, b, what)
    assertTrue(math.abs(a - b) < 1e-6, (what or "near") .. ": " .. tostring(a) .. " vs " .. tostring(b))
end

-- An object that keeps the last arguments of every capitalized call, and how many calls each had.
local function recorder(kind)
    local o = { kind = kind, calls = {}, count = {} }
    return setmetatable(o, { __index = function(t, k)
        if type(k) ~= "string" or not k:match("^%u") then return nil end
        local fn = function(self, ...)
            self.calls[k] = { ... }
            self.count[k] = (self.count[k] or 0) + 1
            return self
        end
        rawset(t, k, fn)
        return fn
    end })
end

local function recFrame(parent)
    local f = recorder("Frame")
    f.parent, f.tex, f.masks, f.fonts = parent, {}, {}, {}
    local function maker(list, kind)
        return function()
            local r = recorder(kind)
            list[#list + 1] = r
            return r
        end
    end
    f.CreateTexture, f.CreateMaskTexture = maker(f.tex, "Texture"), maker(f.masks, "MaskTexture")
    -- A font string whose animation group and Scale animation are recorders of their own.
    f.CreateFontString = function()
        local fs = recorder("FontString")
        f.fonts[#f.fonts + 1] = fs
        fs.groups = 0
        fs.CreateAnimationGroup = function(self)
            self.groups = self.groups + 1
            self.group, self.anim = recorder("AnimationGroup"), recorder("Scale")
            self.group.CreateAnimation = function() return self.anim end
            return self.group
        end
        return fs
    end
    f.GetFrameLevel = function(self)
        local c = self.calls.SetFrameLevel
        return c and c[1] or 0
    end
    return f
end

-- The addon with CreateFrame answering recording frames, and a fresh ghost.
local function ghostOn()
    local NS, m = T.enableAddon()
    m.CreateFrame = function(_, _, parent) return recFrame(parent) end
    return NS.AnimGhost, NS.AnimGhost.New(), NS
end

local function get(v) return function() return v end end

-- A source region: a plain table answering what the ghost reads.
local function region(kind, d)
    d = d or {}
    return { qcGhostGroup = d.group, GetObjectType = get(kind),
        IsShown = get(d.shown ~= false),
        GetCenter = function() if d.nocenter then return nil end return d.x or 0, d.y or 0 end,
        GetWidth = get(d.w or 10), GetHeight = get(d.h or 20), GetAlpha = get(d.alpha or 1),
        GetAtlas = get(d.atlas), GetTexture = get(d.file), GetHorizTile = get(d.tile),
        GetRotation = get(d.rotation or 0), GetTexCoord = function() return 0.1, 0.2, 0.3, 0.4 end,
        IsDesaturated = get(d.desaturated), GetVertexColor = function() return 0.1, 0.2, 0.3, 0.4 end,
        GetBlendMode = get(d.blend or "ADD"), GetDrawLayer = function() return "BORDER", 3 end,
        GetNumMaskTextures = get(d.masks and #d.masks or 0),
        GetMaskTexture = function(_, i) return d.masks[i] end,
        GetText = get(d.text), GetStringWidth = get(d.sw or 80), GetFont = function() return d.face or "Face", 10, "OUTLINE" end,
        GetJustifyH = get("RIGHT"), GetTextColor = function() return 0.5, 0.6, 0.7, 0.8 end,
        GetShadowOffset = function() return 2, -2 end, GetShadowColor = function() return 0, 0, 0, 0.5 end,
        GetFontObject = get(d.object),
    }
end

-- A source frame: `regions` and `kids`, its level, strata and scale.
local function frame(d)
    d = d or {}
    return { qcGhostGroup = d.group, IsShown = get(d.shown ~= false),
        GetCenter = function() if d.nocenter then return nil end return d.x or 100, d.y or 200 end,
        GetFrameStrata = get(d.strata or "HIGH"), GetFrameLevel = get(d.level or 10), GetScale = get(d.scale or 1),
        GetEffectiveScale = get(d.eff or 1),
        GetRegions = function() return unpack(d.regions or {}) end,
        GetChildren = function() return unpack(d.kids or {}) end }
end

local FILE = { file = "art" }

local function subsAt(ghost)
    local out = {}
    for i = 1, ghost.used do out[#out + 1] = ghost.subs[i] end
    return out
end

test("anim ghost: the stage takes the source's strata and level, and sub-frames keep their stacking", function()
    local G, ghost = ghostOn()
    local src = frame({ level = 10, strata = "DIALOG", regions = { region("Texture", FILE) },
        kids = { frame({ level = 13, regions = { region("Texture", FILE) } }) } })
    assertTrue(G.Capture(ghost, src, { src }))
    -- red under: a ghost that floats under the dial, or flat stacking
    assertEqual(ghost.stage.calls.SetFrameStrata[1], "DIALOG")
    assertEqual(ghost.stage.calls.SetFrameLevel[1], 10)
    assertEqual(ghost.used, 2)
    assertEqual(ghost.subs[1].calls.SetFrameLevel[1], 10, "the root's own level")
    assertEqual(ghost.subs[2].calls.SetFrameLevel[1], 16, "three source levels over it")
end)

test("anim ghost: a level is held to the room above the stage, and never under it", function()
    local G, ghost = ghostOn()
    local src = frame({ level = 10, regions = {}, kids = {
        frame({ level = 1000, regions = { region("Texture", FILE) } }),
        frame({ level = 4, regions = { region("Texture", FILE) } }) } })
    assertTrue(G.Capture(ghost, src, { src }))
    assertEqual(ghost.subs[1].calls.SetFrameLevel[1], 10 + 2 * G.MAX_LEVELS)
    assertEqual(ghost.subs[2].calls.SetFrameLevel[1], 10)
end)

test("anim ghost: one sub-frame per level and place, so a place stays addressable and a level whole", function()
    local G, ghost = ghostOn()
    local src = frame({ regions = { region("Texture", FILE), region("Texture", FILE),
        region("Texture", { file = "art", group = 2 }), region("Texture", { file = "art", group = 2 }) },
        kids = { frame({ level = 11, group = 2, regions = { region("Texture", FILE) } }) } })
    assertTrue(G.Capture(ghost, src, { src }, 4))
    assertEqual(ghost.used, 3)
    assertEqual(#ghost.subs[1].tex, 2)
    assertEqual(ghost.subs[2].qcGroup, 2)
    assertEqual(#ghost.subs[2].tex, 2)
    assertEqual(ghost.subs[3].qcGroup, 2, "another level of the same place")
    assertEqual(ghost.size, 4)
end)

test("anim ghost: a child takes its place from itself, then its parent, and a root's tag counts", function()
    local G, ghost = ghostOn()
    local leaf = frame({ level = 12, regions = { region("Texture", FILE) } })
    local src = frame({ group = 7, regions = { region("Texture", FILE) },
        kids = { frame({ level = 11, group = 3, regions = { region("Texture", FILE) }, kids = { leaf } }) } })
    assertTrue(G.Capture(ghost, src, { src }, 8))
    local got = subsAt(ghost)
    assertEqual(got[1].qcGroup, 7, "the root's tag")
    assertEqual(got[2].qcGroup, 3, "a child's own tag beats its parent's")
    assertEqual(got[3].qcGroup, 3, "an untagged child inherits")
end)

test("anim ghost: only what shows is copied", function()
    local G, ghost = ghostOn()
    local src = frame({ shown = false, regions = { region("Texture", FILE), region("Texture", { file = "art", shown = false }) },
        kids = { frame({ level = 11, shown = false, regions = { region("Texture", FILE) } }) } })
    -- a root is walked hidden (a close captures it just down); its hidden parts are not
    assertTrue(G.Capture(ghost, src, { src }))
    assertEqual(ghost.used, 1)
    assertEqual(ghost.subs[1].qcTexUsed, 1)
end)

test("anim ghost: a color texture the client cannot read back is left out", function()
    local G, ghost = ghostOn()
    local none = frame({ regions = { region("Texture") } })
    assertFalse(G.Capture(ghost, none, { none }), "nothing is left to draw")
end)

test("anim ghost: a file texture keeps its art, tint, crop, turn, blend, layer, alpha and desaturation", function()
    local G, ghost = ghostOn()
    local src = frame({ regions = { region("Texture", { file = "art", tile = true, desaturated = true, alpha = 0.3 }),
        region("Texture", { file = "art", rotation = 0.5 }), region("Texture", { atlas = "atlas" }) } })
    assertTrue(G.Capture(ghost, src, { src }))
    local plain, turned, atlas = ghost.subs[1].tex[1], ghost.subs[1].tex[2], ghost.subs[1].tex[3]
    assertEqual(plain.calls.SetTexture[1], "art")
    assertEqual(plain.calls.SetTexture[2], "REPEAT")
    assertEqual(plain.calls.SetTexCoord[3], 0.3, "the source's crop")
    assertEqual(plain.calls.SetVertexColor[2], 0.2)
    assertEqual(plain.calls.SetBlendMode[1], "ADD")
    assertEqual(plain.calls.SetDrawLayer[1], "BORDER")
    assertEqual(plain.calls.SetDrawLayer[2], 3)
    assertEqual(plain.calls.SetAlpha[1], 0.3)
    assertTrue(plain.calls.SetDesaturated[1])
    assertEqual(turned.calls.SetRotation[1], 0.5)
    assertEqual(turned.calls.SetTexCoord[2], 1, "a turned texture's coordinates are the turn's: never both")
    assertEqual(atlas.calls.SetAtlas[1], "atlas")
    assertNil(atlas.calls.SetTexture)
end)

test("anim ghost: a mask is copied once per source mask, turned, and taken off before the next capture", function()
    local G, ghost = ghostOn()
    local mask = region("MaskTexture", { file = "mask", rotation = 0.25 })
    local src = frame({ regions = { region("Texture", { file = "art", masks = { mask } }),
        region("Texture", { file = "art", masks = { mask } }) } })
    assertTrue(G.Capture(ghost, src, { src }))
    local sub = ghost.subs[1]
    assertEqual(#sub.masks, 1)
    assertEqual(sub.masks[1].calls.SetRotation[1], 0.25)
    assertEqual(sub.tex[1].calls.AddMaskTexture[1], sub.masks[1])
    assertEqual(sub.tex[2].calls.AddMaskTexture[1], sub.masks[1])
    assertTrue(G.Capture(ghost, src, { src }))
    assertEqual(sub.tex[1].count.RemoveMaskTexture, 1, "the client stacks masks on a pooled texture")
end)

test("anim ghost: a font string keeps its text, face, color, shadow and alpha", function()
    local G, ghost = ghostOn()
    local src = frame({ regions = { region("FontString", { text = "Hi", alpha = 0.7 }), region("FontString", { text = "" }) } })
    assertTrue(G.Capture(ghost, src, { src }))
    local fs = ghost.textSubs[1].fonts[1]
    assertEqual(#ghost.textSubs[1].fonts, 1, "an empty string draws nothing")
    assertEqual(fs.calls.SetText[1], "Hi")
    assertEqual(fs.calls.SetFont[1], "Face")
    assertEqual(fs.calls.SetFont[3], "OUTLINE")
    assertEqual(fs.calls.SetTextColor[4], 0.8)
    assertEqual(fs.calls.SetAlpha[1], 0.7)
    assertEqual(fs.calls.SetShadowOffset[1], 2)
    assertEqual(fs.calls.SetShadowColor[4], 0.5)
end)

test("anim ghost: a child scaled apart from the root keeps its drawn size and place", function()
    local G, ghost = ghostOn()
    local src = frame({ x = 100, y = 200, eff = 2, kids = { frame({ level = 11, eff = 4, regions = {
        region("Texture", { file = "art", x = 110, y = 205, w = 10, h = 20 }),
        region("FontString", { text = "Hi", x = 100, y = 200 }) } }) } })
    assertTrue(G.Capture(ghost, src, { src }))
    local t, fs = ghost.subs[1].tex[1], ghost.textSubs[1].fonts[1]
    assertEqual(t.calls.SetSize[1], 20)
    assertEqual(t.calls.SetSize[2], 40)
    assertEqual(t.calls.SetPoint[4], 20)
    assertEqual(t.calls.SetPoint[5], 10)
    assertEqual(fs.calls.SetFont[2], 20)
end)

test("anim ghost: no rect on any part is no capture, and nothing to draw is none", function()
    local G, ghost = ghostOn()
    local tex = frame({ regions = { region("Texture", FILE), region("Texture", { file = "art", nocenter = true }) } })
    assertFalse(G.Capture(ghost, tex, { tex }))
    local fs = frame({ regions = { region("Texture", FILE), region("FontString", { text = "Hi", nocenter = true }) } })
    assertFalse(G.Capture(ghost, fs, { fs }))
    local empty = frame({ regions = { region("FontString", { text = "" }) } })
    assertFalse(G.Capture(ghost, empty, { empty }))
    local placeless = frame({ nocenter = true, regions = { region("Texture", FILE) } })
    assertFalse(G.Capture(ghost, placeless, { placeless }))
end)

test("anim ghost: a capture clears the last one's copies, and a reused sub-frame starts whole", function()
    local G, ghost, NS = ghostOn()
    local src = frame({ regions = { region("Texture", { file = "art", group = 2 }), region("Texture", { file = "art" }) } })
    assertTrue(G.Capture(ghost, src, { src }, 4))
    local old = ghost.subs[1]
    local swell = old.calls.SetScale
    local faded = NS.Anim.Rest()
    faded.alpha = 0.5
    G.Pose(ghost, faded, 1, 2, 0.5)
    assertTrue(old.calls.SetScale ~= swell and old.calls.SetScale[1] > 1, "the pulse ran on it")
    G.Pose(ghost, faded, 1, nil, 0)
    near(old.calls.SetAlpha[1], 0.5, "it faded with the pose")
    local one = frame({ regions = { region("Texture", FILE) } })
    assertTrue(G.Capture(ghost, one, { one }))
    assertEqual(ghost.used, 1)
    assertEqual(old.tex[1].count.Hide, 1)
    assertEqual(ghost.subs[1].calls.SetScale[1], 1)
    assertEqual(ghost.subs[1].calls.SetAlpha[1], 1)
    assertEqual(ghost.subs[2].calls.Hide ~= nil, true, "the spare sub-frame is down")
end)

test("anim ghost: a pose scales the stage and lays the rest alpha over every sub-frame", function()
    local G, ghost, NS = ghostOn()
    local src = frame({ scale = 2, regions = { region("Texture", FILE) } })
    assertTrue(G.Capture(ghost, src, { src }))
    local placed = ghost.stage.count.SetPoint
    local pose = NS.Anim.Rest()
    pose.alpha, pose.scale = 0.5, 0.5
    G.Pose(ghost, pose, 0.8, nil, 0)
    near(ghost.stage.calls.SetScale[1], 1, "the source's own scale counts")
    near(ghost.subs[1].calls.SetAlpha[1], 0.4)
    assertEqual(ghost.stage.count.SetPoint, placed, "about the dial's center: a pose never moves it")
end)

test("anim ghost: a place fades in its turn around the ring", function()
    local G, ghost, NS = ghostOn()
    local src = frame({ regions = { region("Texture", { file = "art", group = 1 }), region("Texture", { file = "art", group = 3 }) } })
    assertTrue(G.Capture(ghost, src, { src }, 4))
    local pose = NS.Anim.Rest()
    pose.fan = 0.5
    G.Pose(ghost, pose, 1, nil, 0)
    near(ghost.subs[1].calls.SetAlpha[1], 1, "the first place leads")
    near(ghost.subs[2].calls.SetAlpha[1], 0.5, "the third is half a ring behind")
end)

test("anim ghost: the sent place alone stays bright, pulses and fades after its hold", function()
    local G, ghost, NS = ghostOn()
    local A = NS.Anim
    local src = frame({ regions = { region("Texture", { file = "art", group = 1 }), region("Texture", { file = "art", group = 2 }) } })
    assertTrue(G.Capture(ghost, src, { src }, 2))
    local sent, other = ghost.subs[1], ghost.subs[2]
    local pose = A.Rest()
    pose.alpha, pose.scale = 0.2, 0.5
    G.Pose(ghost, pose, 0.9, 1, 0.5)
    near(sent.calls.SetAlpha[1], 0.9, "bright through the hold, at the rest alpha")
    near(sent.calls.SetScale[1], (1 + A.EMPHASIS_PULSE) / 0.5, "the pulse's height, undoing the stage's scale")
    near(other.calls.SetAlpha[1], 0.18, "the rest collapse")
    assertNil(other.calls.SetScale and other.calls.SetScale[1] ~= 1 or nil, "only the sent place swells")
    local f = A.EMPHASIS_HOLD + (1 - A.EMPHASIS_HOLD) / 2
    G.Pose(ghost, pose, 1, 1, f)
    near(sent.calls.SetAlpha[1], 0.5, "past the hold it fades out")
end)

test("anim ghost: a ghost takes no mouse, and nothing it makes does", function()
    local G, ghost = ghostOn()
    assertFalse(ghost.stage.calls.EnableMouse[1])
    assertFalse(ghost.text.calls.EnableMouse[1])
    local src = frame({ regions = { region("Texture", FILE), region("FontString", { text = "Hi" }) } })
    assertTrue(G.Capture(ghost, src, { src }))
    assertFalse(ghost.subs[1].calls.EnableMouse[1])
    assertFalse(ghost.textSubs[1].calls.EnableMouse[1])
end)

-- ── the text: no shimmer, no truncation (the owner's second request after smoke testing #13) ───────

-- A captured ghost with one string 30 right of and 40 over the dial's center, on a place's frame.
local function withText(d)
    local G, ghost, NS, m = ghostOn()
    d = d or {}
    local src = frame({ x = 100, y = 200, scale = 2, regions = { region("Texture", { file = "art", group = 1 }),
        region("FontString", { text = "Quick Comms: World", x = 130, y = 240, w = d.w, sw = d.sw, group = 1 }) } })
    assertTrue(G.Capture(ghost, src, { src }, 2))
    return G, ghost, ghost.textSubs[1].fonts[1], NS, m
end

test("anim ghost: text is on a layer no pose scales, so the client never rasterizes a new size", function()
    local G, ghost, fs, NS = withText()
    assertEqual(fs.calls.SetScale, nil)
    assertEqual(ghost.text.calls.SetScale[1], 2, "the source's own scale, once")
    assertEqual(ghost.text.calls.SetPoint[1], "CENTER", "on the dial's center")
    assertEqual(ghost.text.calls.SetFrameStrata[1], "HIGH")
    assertEqual(ghost.text.parent, ghost.stage.parent, "beside the scaled stage, never under it")
    assertEqual(ghost.textSubs[1].parent, ghost.text)
    local pose, scales = NS.Anim.Rest(), ghost.text.count.SetScale
    for _, s in ipairs({ 0.8, 0.9, 1 }) do
        pose.scale = s
        G.Pose(ghost, pose, 1, nil, 0)
    end
    near(ghost.stage.calls.SetScale[1], 2, "the art still scales")
    assertEqual(ghost.text.count.SetScale, scales, "the layer does not")
    assertEqual(ghost.textSubs[1].count.SetScale, 1, "its sub-frame only as a pool resets it")
    assertEqual(ghost.textSubs[1].calls.SetScale[1], 1)
    assertEqual(fs.calls.SetScale, nil, "nor the string")
    assertEqual(#ghost.subs[1].fonts, 0, "no string on the art's frames")
end)

test("anim ghost: a string's copy can never truncate, whatever its source's rect says", function()
    local _, ghost, fs = withText({ w = 10, sw = 200 })
    -- red under: place()'s fixed size on a font string, which is what cut the title short
    assertEqual(fs.calls.SetSize, nil)
    assertEqual(fs.calls.SetWidth, nil)
    assertEqual(fs.calls.SetHeight, nil)
    assertEqual(fs.calls.SetMaxLines, nil)
    assertEqual(fs.calls.SetWordWrap[1], false)
    assertEqual(ghost.textSubs[1].fonts[1], fs)
end)

test("anim ghost: a string scales about its own center, on the client's Vertex mode", function()
    local _, _, fs = withText()
    assertEqual(fs.calls.SetScaleAnimationMode[1], 1, "Enum.FontStringScaleAnimationMode.Vertex")
    assertEqual(fs.calls.SetJustifyH[1], "CENTER", "Vertex scales from the justification")
    assertEqual(fs.calls.SetJustifyV[1], "MIDDLE")
    assertEqual(fs.anim.calls.SetOrigin[1], "CENTER")
    assertEqual(fs.anim.calls.SetOrigin[2], 0)
    assertEqual(fs.anim.calls.SetOrigin[3], 0)
end)

test("anim ghost: a leg plays the string's scale, and a leg at 1 plays nothing", function()
    local G, ghost, fs = withText()
    G.ScaleText(ghost, 0.8, 1, 0.5, "open")
    assertEqual(fs.anim.calls.SetScaleFrom[1], 0.8)
    assertEqual(fs.anim.calls.SetScaleFrom[2], 0.8)
    assertEqual(fs.anim.calls.SetScaleTo[1], 1)
    assertEqual(fs.anim.calls.SetDuration[1], 0.5)
    assertEqual(fs.anim.calls.SetSmoothing[1], "OUT", "A.Ease decelerates into an open")
    assertEqual(fs.group.count.Play, 1)
    local stops = fs.group.count.Stop
    G.ScaleText(ghost, 0.9, 0.8, 0.2, "close")
    assertEqual(fs.group.count.Stop, stops + 1, "a reversal restarts it")
    assertEqual(fs.anim.calls.SetScaleFrom[1], 0.9)
    assertEqual(fs.anim.calls.SetSmoothing[1], "IN", "and accelerates out of a close")
    G.ScaleText(ghost, 1, 1, 0.2, "close")
    assertEqual(fs.group.count.Play, 2, "Fade and Fan keep the text at its size")
    G.ScaleText(ghost, 0.8, 0.8, 0.2, "close")
    assertEqual(fs.group.count.Play, 3, "a reversal from the very start holds its size, not 1")
end)

test("anim ghost: a pose places each string about the dial's center, as the art moves", function()
    local G, ghost, fs, NS = withText()
    assertEqual(fs.calls.SetPoint[2], ghost.text)
    assertEqual(fs.calls.SetPoint[4], 30, "at rest, where its source is")
    assertEqual(fs.calls.SetPoint[5], 40)
    local pose = NS.Anim.Rest()
    pose.scale = 0.5
    G.Pose(ghost, pose, 1, nil, 0)
    assertEqual(fs.calls.SetPoint[1], "CENTER")
    assertEqual(fs.calls.SetPoint[4], 15)
    assertEqual(fs.calls.SetPoint[5], 20)
    local moves = fs.count.SetPoint
    G.Pose(ghost, pose, 1, nil, 0)
    assertEqual(fs.count.SetPoint, moves, "a pose that did not move writes nothing")
end)

test("anim ghost: text fades with the pose and the Fan, as the art does", function()
    local G, ghost, _, NS = withText()
    local pose = NS.Anim.Rest()
    pose.alpha, pose.fan = 0.5, 0.25
    G.Pose(ghost, pose, 0.8, nil, 0)
    near(ghost.textSubs[1].calls.SetAlpha[1], ghost.subs[1].calls.SetAlpha[1], "the same alpha as its art")
    near(ghost.textSubs[1].calls.SetAlpha[1], 0.5 * 0.8 * NS.Anim.FanAlpha(0.25, 0))
end)

test("anim ghost: the sent place's text pulses with its art, out then back, and other text does not", function()
    local G, ghost, fs, NS = withText()
    local A = NS.Anim
    local other = ghost.textSubs[1].qcFont[1]
    assertEqual(other, fs)
    G.ScaleText(ghost, 1, 0.8, 0.4, "close")
    G.EmphasizeText(ghost, 2, 0.4)
    assertEqual(fs.anim.calls.SetScaleFrom[1], 1, "another place keeps its leg")
    assertEqual(fs.anim.calls.SetScaleTo[1], 0.8)
    G.EmphasizeText(ghost, 1, 0.4)
    near(fs.anim.calls.SetScaleTo[1], 1 + A.EMPHASIS_PULSE)
    assertEqual(fs.anim.calls.SetScaleFrom[1], 1)
    near(fs.anim.calls.SetDuration[1], 0.2)
    assertEqual(fs.anim.calls.SetSmoothing[1], "OUT")
    local pose = A.Rest()
    pose.scale = 0.8
    G.Pose(ghost, pose, 1, 1, 0.25)
    near(fs.calls.SetPoint[4], 30 * (1 + A.EMPHASIS_PULSE * math.sin(math.pi * 0.25)), "it rides the pulse, not the pose")
    assertEqual(fs.anim.calls.SetSmoothing[1], "OUT", "still swelling")
    G.Pose(ghost, pose, 1, 1, 0.5)
    near(fs.anim.calls.SetScaleFrom[1], 1 + A.EMPHASIS_PULSE, "the way back starts at the height")
    assertEqual(fs.anim.calls.SetScaleTo[1], 1)
    near(fs.anim.calls.SetDuration[1], 0.2)
    assertEqual(fs.anim.calls.SetSmoothing[1], "IN")
    local plays = fs.group.count.Play
    G.Pose(ghost, pose, 1, 1, 0.75)
    assertEqual(fs.group.count.Play, plays, "it turns once")
end)

test("anim ghost: nothing is left playing when the ghost comes down, or at the next capture", function()
    local G, ghost, fs = withText()
    G.Show(ghost)
    assertEqual(ghost.text.count.Show, 1, "the layer shows with the stage")
    G.ScaleText(ghost, 0.8, 1, 1, "open")
    local stops = fs.group.count.Stop
    G.Hide(ghost)
    assertEqual(fs.group.count.Stop, stops + 1)
    assertTrue(ghost.text.count.Hide >= 2, "the layer hides with the stage")
    G.ScaleText(ghost, 0.8, 1, 1, "open")
    stops = fs.group.count.Stop
    local src = frame({ regions = { region("Texture", FILE) } })
    assertTrue(G.Capture(ghost, src, { src }))
    assertEqual(fs.group.count.Stop, stops + 1, "a pooled string keeps no scale")
end)

test("anim ghost: the animations are pooled with their strings", function()
    local G, ghost, fs = withText()
    local src = frame({ regions = { region("FontString", { text = "Again" }) } })
    for _ = 1, 3 do assertTrue(G.Capture(ghost, src, { src })) end
    assertEqual(ghost.textSubs[1].fonts[1], fs)
    assertEqual(#ghost.textSubs[1].fonts, 1)
    assertEqual(fs.groups, 1)
end)

test("anim ghost: text stacks over its own level's art and under the next one's", function()
    local G, ghost = ghostOn()
    local src = frame({ level = 10, regions = { region("Texture", FILE), region("FontString", { text = "Hi" }) },
        kids = { frame({ level = 11, regions = { region("Texture", FILE) } }) } })
    assertTrue(G.Capture(ghost, src, { src }))
    assertEqual(ghost.text.calls.SetFrameLevel[1], 10)
    local text = ghost.textSubs[1].calls.SetFrameLevel[1]
    assertTrue(text > ghost.subs[1].calls.SetFrameLevel[1], "over its own art")
    assertTrue(text < ghost.subs[2].calls.SetFrameLevel[1], "under the next level's")
end)

-- A missing piece of the API, and what must follow: no scaling at all, in place, never the shimmer.
local function assertFadesInPlace(G, ghost, fs, NS)
    assertEqual(fs.group, nil, "no group is kept")
    G.ScaleText(ghost, 0.8, 1, 1, "open")
    G.EmphasizeText(ghost, 1, 1)
    local pose, moves = NS.Anim.Rest(), fs.count.SetPoint
    pose.scale, pose.alpha = 0.8, 0.5
    G.Pose(ghost, pose, 1, 1, 0.75)
    pose.scale = 0.9
    G.Pose(ghost, pose, 1, nil, 0.75)
    assertEqual(fs.count.SetPoint, moves, "text stays where it is")
    assertEqual(fs.calls.SetScale, nil)
    near(ghost.textSubs[1].calls.SetAlpha[1], 0.5, "and fades")
    assertEqual(ghost.text.count.SetScale, 1, "its layer never takes the pose")
end

test("anim ghost: with no Enum the text fades in place, the art still scaling", function()
    local NS, m = T.enableAddon()
    local G = NS.AnimGhost
    m.CreateFrame = function(_, _, parent) return recFrame(parent) end
    m.Enum.FontStringScaleAnimationMode = nil
    local ghost = G.New()
    local src = frame({ regions = { region("Texture", FILE), region("FontString", { text = "Hi", x = 130 }) } })
    assertTrue(G.Capture(ghost, src, { src }, 1))
    local fs = ghost.textSubs[1].fonts[1]
    assertEqual(fs.calls.SetScaleAnimationMode, nil)
    fs.group = nil
    assertFadesInPlace(G, ghost, fs, NS)
    near(ghost.stage.calls.SetScale[1], 0.9, "the art")
end)

test("anim ghost: with no mode setter the text fades in place", function()
    local NS, m = T.enableAddon()
    local G = NS.AnimGhost
    m.CreateFrame = function(_, _, parent)
        local f = recFrame(parent)
        local make = f.CreateFontString
        f.CreateFontString = function()
            local fs = make()
            rawset(fs, "SetScaleAnimationMode", false)
            return fs
        end
        return f
    end
    local ghost = G.New()
    local src = frame({ regions = { region("FontString", { text = "Hi", x = 130 }) } })
    assertTrue(G.Capture(ghost, src, { src }, 1))
    assertFadesInPlace(G, ghost, ghost.textSubs[1].fonts[1], NS)
end)
