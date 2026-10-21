-- tools/render-shine-preview.lua — the shine overlay's truthful preview, half one (a dev-only tool,
-- like tools/gen-shine-textures.py; the client never loads it and .pkgmeta ignores tools/).
--
--     lua tools/render-shine-preview.lua [out.json] [radii]   (from the repo root; radii: "100,150")
--     python3 tools/render-shine-preview.py [out.json] [out_dir]
--
-- It loads the addon headless exactly as the test harness does (tests/loader.lua over
-- tests/wow_mock.lua, the same enableAddon lifecycle as tests/run.lua), so what it dumps is what the
-- addon's own code painted, never a copy of a recipe. For every shine look (None included) it builds
-- the stock Comms Dial (default profile, the Dungeon set) at 4, 8 and 12 slices (at each ring radius
-- of `radii`, comma-separated, 100 when none) and the stock Comms
-- Pad (its default and an icon-only button), then writes every region those frames hold to JSON:
-- the frame tree (anchors, sizes, frame levels, shown), and per region its kind, draw layer and
-- sublevel, texture, size, anchors (or SetAllPoints), rotation, vertex color, blend mode,
-- texcoords, attached masks and a font string's text. tools/render-shine-preview.py lays them out
-- and composites them the way the client blends them.

package.path = "./?.lua;" .. package.path

local mock = dofile("tests/wow_mock.lua")
local loadAddon = dofile("tests/loader.lua")(".", mock)

local OUT = arg and arg[1] or "shine-preview.json"
local LOOKS = { "none", "gloss", "glossfade", "orb", "frost", "fluid", "bevel", "rim" }
local COUNTS = { 4, 8, 12 }
local RADII = {}
for r in tostring(arg and arg[2] or "100"):gmatch("%d+") do RADII[#RADII + 1] = tonumber(r) end

-- ── recording ─────────────────────────────────────────────────────────────────────────────────
-- Every frame and region the instance makes, in creation order, so a dump can walk them and the
-- compositor can break draw-order ties the way the client does (creation order).

local frames, regions
local function record(m)
    frames, regions = {}, {}
    local create = m.CreateFrame
    m.CreateFrame = function(...)
        local f = create(...)
        frames[#frames + 1] = f
        f.__qcSeq = #frames
        for _, maker in ipairs({ "CreateTexture", "CreateFontString", "CreateMaskTexture" }) do
            local inner = f[maker]
            if type(inner) == "function" then
                f[maker] = function(self, ...)
                    local r = inner(self, ...)
                    regions[#regions + 1] = r
                    r.__qcSeq = #regions
                    local args = { ... }
                    if maker == "CreateFontString" then r.__layer = args[2] end
                    if maker ~= "CreateMaskTexture" then
                        local set = r.SetTexture
                        r.SetTexture = function(t, path, ...)
                            t.__solid = nil
                            return set(t, path, ...)
                        end
                        local solid = r.SetColorTexture
                        r.SetColorTexture = function(t, cr, cg, cb, ca)
                            t.__solid = true
                            return solid(t, cr, cg, cb, ca)
                        end
                    end
                    local font = r.SetFontObject
                    r.SetFontObject = function(t, obj, ...)
                        t.__fontObject = obj
                        if type(font) == "function" then return font(t, obj, ...) end
                        return t
                    end
                    return r
                end
            end
        end
        -- A frame's SetAllPoints, recorded as a region's is.
        f.SetAllPoints = function(self, rel)
            self.__allPoints = rel or self.__parent
            return self
        end
        return f
    end
end

local function boot()
    local NS, _, m = loadAddon({ mock = record })
    local AceDB = m.LibStub("AceDB-3.0", true)
    -- the AceDB char section, as tests/run.lua's withCharSection
    local new = AceDB.New
    AceDB.New = function(self, tbl, defaults, ...)
        local db = new(self, tbl, defaults, ...)
        db.sv.char = db.sv.char or {}
        db.char = db.sv.char["Tester - Realm"] or {}
        db.sv.char["Tester - Realm"] = db.char
        for k, v in pairs(defaults and defaults.char or {}) do
            if db.char[k] == nil then db.char[k] = v end
        end
        return db
    end
    NS.addon:OnInitialize()
    NS.addon:OnEnable()
    NS.Situation.ReadInputs = function()
        return { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
            keyLevel = 12, inGroup = true }
    end
    NS.Situation.RefreshNow("preview")
    return NS, m
end

-- ── JSON ──────────────────────────────────────────────────────────────────────────────────────

local function encode(v, out)
    local t = type(v)
    if t == "nil" then out[#out + 1] = "null"
    elseif t == "boolean" then out[#out + 1] = tostring(v)
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then out[#out + 1] = "null"
        else out[#out + 1] = string.format("%.6g", v) end
    elseif t == "string" then
        out[#out + 1] = '"' .. v:gsub('[%c"\\]', function(c)
            if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
            return string.format("\\u%04x", c:byte())
        end) .. '"'
    elseif t == "table" then
        if #v > 0 or next(v) == nil then
            out[#out + 1] = "["
            for i, x in ipairs(v) do
                if i > 1 then out[#out + 1] = "," end
                encode(x, out)
            end
            out[#out + 1] = "]"
        else
            out[#out + 1] = "{"
            local first = true
            local keys = {}
            for k in pairs(v) do keys[#keys + 1] = tostring(k) end
            table.sort(keys)
            for _, k in ipairs(keys) do
                if not first then out[#out + 1] = "," end
                first = false
                encode(k, out)
                out[#out + 1] = ":"
                encode(v[k], out)
            end
            out[#out + 1] = "}"
        end
    end
    return out
end

-- ── the dump ──────────────────────────────────────────────────────────────────────────────────

-- The frames under `root` (it included), by identity.
local function subtree(root)
    local inside = {}
    local function under(f)
        local p = f
        while type(p) == "table" do
            if p == root then return true end
            p = rawget(p, "__parent")
        end
        return false
    end
    for _, f in ipairs(frames) do
        if under(f) then inside[f] = true end
    end
    return inside
end

local function ref(x)
    if type(x) ~= "table" or not x.__qcSeq then return nil end
    return (x.__kind and "r" or "f") .. x.__qcSeq
end

local function points(list)
    local out = {}
    for _, p in ipairs(list or {}) do
        out[#out + 1] = { p[1], ref(p[2]) or false, p[3] or p[1], tonumber(p[4]) or 0, tonumber(p[5]) or 0 }
    end
    return out
end

-- Shown under `root`: the root itself is taken as open (a dial's header is hidden until its key opens it).
local function frameShown(f, root)
    local p = f
    while type(p) == "table" and p.__qcSeq and p ~= root do
        if p.__shown == false then return false end
        p = rawget(p, "__parent")
    end
    return true
end

local function dumpScene(root, extra)
    local inside = subtree(root)
    local out = { root = ref(root), frames = {}, regions = {} }
    for _, f in ipairs(frames) do
        if inside[f] then
            out.frames[#out.frames + 1] = { id = ref(f), parent = ref(rawget(f, "__parent")),
                size = { f.__w, f.__h }, points = points(f.__points), allPoints = ref(f.__allPoints),
                level = f:GetFrameLevel(), shown = f.__shown ~= false, alpha = f.__alpha or 1 }
        end
    end
    for _, r in ipairs(regions) do
        local owner = rawget(r, "__parent")
        if inside[owner] then
            local masks = {}
            for _, mk in ipairs(r.__masks or {}) do masks[#masks + 1] = ref(mk) end
            out.regions[#out.regions + 1] = { id = ref(r), kind = r.__kind, frame = ref(owner),
                layer = r.__layer, sublevel = r.__sublevel or 0, texture = r.__texture,
                solid = r.__solid == true, size = r.__size, points = points(r.__points),
                allPoints = ref(r.__allPoints), rotation = r.__rotation or 0, color = r.__color,
                blend = r.__blend or "BLEND", texCoord = r.__texCoord, masks = masks,
                shown = r.__shown ~= false and frameShown(owner, root), alpha = r.__alpha or 1,
                text = r.__text, font = r.__font }
        end
    end
    for k, v in pairs(extra or {}) do out[k] = v end
    return out
end

local scenes = {}

-- The dial: the stock d2 over the Dungeon set, its first `n` callouts on one ring of `slices`.
local function dialScene(look, slices, radius)
    local NS = boot()
    local snap = NS.Situation.Current()
    local function seeded(origin)
        for id, g in pairs(NS.db.profile.groups) do
            if type(g) == "table" and g.origin == origin then return id end
        end
    end
    local gid = seeded("bi.mplus")
    local group = { id = gid, title = "Dungeon", slots = {} }
    local callouts = NS.Library.Group(gid).callouts
    for i = 1, slices do
        local cid = callouts[(i - 1) % #callouts + 1]
        local slot = NS.Surfaces.Slot(cid, NS.Library.Callout(cid), snap, { soloFallback = "none", ctx = {} })
        slot.surfaceId = "d2"
        group.slots[#group.slots + 1] = slot
    end
    assert(NS.SchemaRuntime.Set("dial.slice.shineLook", look, "d2"))
    assert(NS.SchemaRuntime.Set("dial.radius", radius, "d2"))
    local rings, open = NS.DialLayout.Rings({ group }, { slices = slices, title = "Comms Dial" })
    local plan = { kind = "dial", surfaceId = "d2", snapshot = snap, order = { gid }, active = {},
        rings = rings, openRing = open, radius = radius }
    assert(NS.Dial.Apply(1, "d2", plan))
    local inst = NS.Dial.Instance("d2")
    local ring
    for _, r in ipairs(inst.rings.active) do
        if r.qcSpec and r.qcSpec.size == slices and #(r.qcSpec.items or {}) == slices then ring = r end
    end
    assert(ring, "no ring of " .. slices)
    for _, r in ipairs(inst.rings.active) do r.__shown = r == ring end
    ring.__shown = true
    ring.qcHighlight:Hide()
    local s = dumpScene(inst.header, { kind = "dial", look = look, slices = slices, radius = radius, ring = ref(ring),
        disc = ring.qcShape.disc })
    scenes[#scenes + 1] = s
end

-- The pad: the stock p1's buttons, in its default style, and one icon-only button.
local function padScene(look, style)
    local NS = boot()
    assert(NS.SchemaRuntime.Set("pad.button.shineLook", look, "p1"))
    if style then assert(NS.SchemaRuntime.Set("pad.layout.style", style, "p1")) end
    local inst = NS.Pad.Instance("p1")
    local buttons = {}
    for _, btn in ipairs(inst.buttons.active) do
        if btn:IsShown() then buttons[#buttons + 1] = ref(btn) end
    end
    local s = dumpScene(inst.root, { kind = "pad", look = look, style = style or "default", buttons = buttons })
    scenes[#scenes + 1] = s
end

for _, look in ipairs(LOOKS) do
    for _, n in ipairs(COUNTS) do
        for _, r in ipairs(RADII) do dialScene(look, n, r) end
    end
    padScene(look)
    padScene(look, "icon")
end

local fh = assert(io.open(OUT, "wb"))
fh:write(table.concat(encode({ scenes = scenes }, {})))
fh:close()
print(("wrote %s (%d scenes)"):format(OUT, #scenes))
