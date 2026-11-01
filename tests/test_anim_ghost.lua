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
    f.CreateTexture, f.CreateMaskTexture, f.CreateFontString =
        maker(f.tex, "Texture"), maker(f.masks, "MaskTexture"), maker(f.fonts, "FontString")
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
        GetText = get(d.text), GetFont = function() return d.face or "Face", 10, "OUTLINE" end,
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
    assertEqual(ghost.subs[2].calls.SetFrameLevel[1], 13, "three over it, as the source")
end)

test("anim ghost: a level is held to the room above the stage, and never under it", function()
    local G, ghost = ghostOn()
    local src = frame({ level = 10, regions = {}, kids = {
        frame({ level = 1000, regions = { region("Texture", FILE) } }),
        frame({ level = 4, regions = { region("Texture", FILE) } }) } })
    assertTrue(G.Capture(ghost, src, { src }))
    assertEqual(ghost.subs[1].calls.SetFrameLevel[1], 10 + G.MAX_LEVELS)
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

test("anim ghost: a font string keeps its text, face, color, shadow, alignment and alpha", function()
    local G, ghost = ghostOn()
    local src = frame({ regions = { region("FontString", { text = "Hi", alpha = 0.7 }), region("FontString", { text = "" }) } })
    assertTrue(G.Capture(ghost, src, { src }))
    local fs = ghost.subs[1].fonts[1]
    assertEqual(#ghost.subs[1].fonts, 1, "an empty string draws nothing")
    assertEqual(fs.calls.SetText[1], "Hi")
    assertEqual(fs.calls.SetFont[1], "Face")
    assertEqual(fs.calls.SetFont[3], "OUTLINE")
    assertEqual(fs.calls.SetTextColor[4], 0.8)
    assertEqual(fs.calls.SetJustifyH[1], "RIGHT")
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
    local t, fs = ghost.subs[1].tex[1], ghost.subs[1].fonts[1]
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
    local src = frame({ regions = { region("Texture", FILE) } })
    assertTrue(G.Capture(ghost, src, { src }))
    assertFalse(ghost.subs[1].calls.EnableMouse[1])
end)
