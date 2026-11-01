local _, NS = ...
-- modules/Anim_Ghost.lua — a dial's insecure copy, the thing the open and close animations actually
-- move (#13, the design's "The ghost"). The dial's header is secure: nothing here may show, hide,
-- place or scale it, and once secure code hides it its regions cannot be seen. So the ghost mirrors it: a plain, mouse-off frame under UIParent, anchored to the real
-- frame's center (an insecure frame may anchor to a protected one; never the other way round), in its
-- strata, and carrying a copy of each texture and font string it shows.
--
-- CAPTURE ONLY READS the secure frames, so it is safe in combat, and it works on a just-hidden one:
-- the hide cleared the root's own shown flag, not its children's. The stacking holds because regions
-- are grouped into sub-frames by their source frame's level above the root. A region or frame tagged
-- `qcGhostGroup` (a dial's place) goes into a sub-frame of its own, which the Fan and the send's
-- emphasis address. A color texture cannot be read back, so one with no file or atlas is left out. A
-- skinned string's shadow lives on its font object (S.HudFont), so the copy wears the same object. Rects may be missing on a frame never laid out: capture then answers
-- false, and the track snaps (the rulings' fallback, never a guess).
--
-- THE TEXT LIVES APART. stage:SetScale moves the effective scale, and at each one the client rasterizes
-- the font afresh: glyphs shimmer, and the wider layout hits any fixed width, so a title truncated
-- mid-animation (the owner's smoke test). So a string never sits under the stage. It is on `ghost.text`,
-- a sibling layer no pose scales, in a text sub-frame per source level and place, stacked between that
-- level's art and the next (LEVEL_STEP). Its scale is its own Scale animation in Vertex mode, whose
-- scaling keeps the layout and follows the string's justification, so a copy is centered both ways and
-- the origin is its own center. That is why the pose places it: each tick puts it at its offset from
-- the dial's center times the pose's scale, which is what the stage does to the art. The script tweens
-- the art, the client the glyphs: G.ScaleText runs one leg per open, close or reversal with the
-- smoothing nearest A.Ease, and a send's pulse is two legs. Where the client has no Vertex mode
-- (Compat.VertexScaleAnimation) a string takes no scale and no pose: it fades in place.
--
-- A COPY NEVER TAKES A WIDTH. With one anchor and none set, a string is as wide as its text, so it
-- cannot truncate. Every string the dial draws is sized that way, so the copy sits on its center.
--
-- Frames, regions and animations are pooled per ghost, made on first use and never destroyed; making a
-- plain frame is allowed in combat. MAX_LEVELS bounds a sub-frame's source level above the stage.

NS.AnimGhost = NS.AnimGhost or {}
local G = NS.AnimGhost

G.MAX_LEVELS = 400
G.LEVEL_STEP = 2    -- frame levels per source level: its art, then its text

local SMOOTHING = { open = "OUT", close = "IN" }   -- the client's nearest to A.Ease

local made = 0

--- An empty ghost. Its stage is a child of UIParent, hidden until a track plays it, and named, so
--- /fstack can tell it from the surface it copies.
function G.New()
    made = made + 1
    local stage = CreateFrame("Frame", "QuickCommsGhost" .. made, UIParent)
    stage:EnableMouse(false)
    stage:SetSize(1, 1)
    stage:Hide()
    local text = CreateFrame("Frame", "QuickCommsGhost" .. made .. "Text", UIParent)
    text:EnableMouse(false)
    text:SetSize(1, 1)
    text:Hide()
    return { stage = stage, text = text, subs = {}, used = 0, textSubs = {}, textUsed = 0, scale = 1, size = 1 }
end

local function resetSub(sub)
    for i = 1, sub.qcTexUsed do
        local t = sub.qcTex[i]
        for _, mask in ipairs(t.qcMasks or {}) do t:RemoveMaskTexture(mask) end
        t.qcMasks = nil
        t:Hide()
    end
    for i = 1, sub.qcMaskUsed do sub.qcMaskTex[i]:Hide() end
    for i = 1, sub.qcFontUsed do
        local fs = sub.qcFont[i]
        if fs.qcScaleGroup then fs.qcScaleGroup:Stop() end
        fs:Hide()
    end
    sub.qcTexUsed, sub.qcMaskUsed, sub.qcFontUsed = 0, 0, 0
    sub.qcGroup = nil
    sub:Hide()
end

-- The next sub-frame of a pool: `layer` (the stage's or the text's) with `offset` frame levels over it.
local function acquireSub(ghost, list, usedKey, layer, offset, group)
    ghost[usedKey] = ghost[usedKey] + 1
    local sub = list[ghost[usedKey]]
    if not sub then
        sub = CreateFrame("Frame", nil, layer)
        sub:EnableMouse(false)
        sub:SetSize(1, 1)
        sub:SetPoint("CENTER", layer, "CENTER", 0, 0)
        sub.qcTex, sub.qcMaskTex, sub.qcFont = {}, {}, {}
        sub.qcTexUsed, sub.qcMaskUsed, sub.qcFontUsed = 0, 0, 0
        list[ghost[usedKey]] = sub
    end
    sub.qcGroup = group
    sub:SetFrameLevel(ghost.stage:GetFrameLevel() + offset)
    sub:SetScale(1)
    sub:SetAlpha(1)
    sub:Show()
    return sub
end

local function pooled(sub, list, used, make)
    sub[used] = sub[used] + 1
    local r = sub[list][sub[used]]
    if not r then
        r = make()
        sub[list][sub[used]] = r
    end
    return r
end

local function place(r, ctx, src, factor)
    local x, y = src:GetCenter()
    if not x then return false end
    r:ClearAllPoints()
    r:SetPoint("CENTER", ctx.ghost.stage, "CENTER", (x - ctx.cx) * factor, (y - ctx.cy) * factor)
    r:SetSize((tonumber(src:GetWidth()) or 0) * factor, (tonumber(src:GetHeight()) or 0) * factor)
    return true
end

-- A mask on the ghost's texture, cut as `src` cuts: one copy per source mask per sub-frame.
local function copyMask(ctx, sub, src, factor)
    sub.qcMaskOf = sub.qcMaskUsed == 0 and {} or sub.qcMaskOf
    local m = sub.qcMaskOf[src]
    if m then return m end
    m = pooled(sub, "qcMaskTex", "qcMaskUsed", function() return sub:CreateMaskTexture(nil, "BACKGROUND") end)
    m:SetTexture(src:GetTexture(), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if not place(m, ctx, src, factor) then return nil end
    m:SetRotation(src:GetRotation() or 0)
    m:Show()
    sub.qcMaskOf[src] = m
    return m
end

local function paintFile(t, src)
    local atlas, file = src:GetAtlas(), src:GetTexture()
    if atlas then
        t:SetAtlas(atlas)
    else
        local wrap = src:GetHorizTile() and "REPEAT" or "CLAMP"
        t:SetTexture(file, wrap, wrap)
    end
    local rotation = src:GetRotation() or 0
    -- A turned texture's coordinates are its rotation's, read back: setting both would turn it twice.
    if rotation ~= 0 then t:SetTexCoord(0, 1, 0, 1) else t:SetTexCoord(src:GetTexCoord()) end
    t:SetRotation(rotation)
    t:SetDesaturated(src:IsDesaturated() and true or false)
end

local function copyTexture(ctx, sub, src, factor)
    if not (src:GetAtlas() or src:GetTexture()) then return end
    local t = pooled(sub, "qcTex", "qcTexUsed", function() return sub:CreateTexture(nil, "ARTWORK") end)
    if not place(t, ctx, src, factor) then
        ctx.failed = true
        return
    end
    paintFile(t, src)
    t:SetVertexColor(src:GetVertexColor())
    t:SetBlendMode(src:GetBlendMode() or "BLEND")
    t:SetDrawLayer(src:GetDrawLayer())
    t:SetAlpha(src:GetAlpha() or 1)
    for i = 1, tonumber(src:GetNumMaskTextures()) or 0 do
        local m = copyMask(ctx, sub, src:GetMaskTexture(i), factor)
        if m then
            t:AddMaskTexture(m)
            t.qcMasks = t.qcMasks or {}
            t.qcMasks[#t.qcMasks + 1] = m
        end
    end
    t:Show()
    ctx.drawn = ctx.drawn + 1
end

-- A string at `s` times its offset from the dial's center. A string with no scale of its own stays put.
local function moveText(ghost, fs, s)
    if fs.qcAt == s then return end
    fs.qcAt = s
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", ghost.text, "CENTER", fs.qcX * s, fs.qcY * s)
end

local function newString(sub)
    local fs = sub:CreateFontString(nil, "OVERLAY")
    fs.qcScaleGroup, fs.qcScale = NS.Compat.VertexScaleAnimation(fs)
    return fs
end

local function copyFont(ctx, sub, src, factor)
    local text = src:GetText()
    local face, size, flags = src:GetFont()
    if not (text and text ~= "" and face) then return end
    local x, y = src:GetCenter()
    if not x then
        ctx.failed = true
        return
    end
    local fs = pooled(sub, "qcFont", "qcFontUsed", function() return newString(sub) end)
    fs.qcX, fs.qcY, fs.qcAt = (x - ctx.cx) * factor, (y - ctx.cy) * factor, nil
    moveText(ctx.ghost, fs, 1)
    local object = src:GetFontObject()
    if type(object) == "table" then fs:SetFontObject(object) end
    if factor ~= 1 or type(object) ~= "table" then fs:SetFont(face, size * factor, flags) end
    fs:SetWordWrap(false)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    fs:SetTextColor(src:GetTextColor())
    if type(object) ~= "table" then
        fs:SetShadowOffset(src:GetShadowOffset())
        fs:SetShadowColor(src:GetShadowColor())
    end
    fs:SetText(text)
    fs:SetAlpha(src:GetAlpha() or 1)
    fs:Show()
    ctx.drawn = ctx.drawn + 1
end

-- The art or text sub-frame for a source level and group: one each, so groups stay addressable and
-- regions at one level keep their draw layers against each other.
local function subFor(ctx, level, group)
    local key = level .. ":" .. tostring(group)
    local sub = ctx.byKey[key]
    if not sub then
        local ghost = ctx.ghost
        sub = acquireSub(ghost, ghost.subs, "used", ghost.stage, level * G.LEVEL_STEP, group)
        ctx.byKey[key] = sub
    end
    return sub
end

local function textSubFor(ctx, level, group)
    local key = level .. ":" .. tostring(group)
    local sub = ctx.textByKey[key]
    if not sub then
        local ghost = ctx.ghost
        sub = acquireSub(ghost, ghost.textSubs, "textUsed", ghost.text, level * G.LEVEL_STEP + 1, group)
        ctx.textByKey[key] = sub
    end
    return sub
end

local function copyRegions(ctx, frame, group, level, factor)
    for _, r in ipairs({ frame:GetRegions() }) do
        if r:IsShown() then
            local kind, tag = r:GetObjectType(), r.qcGhostGroup or group
            if kind == "Texture" then
                copyTexture(ctx, subFor(ctx, level, tag), r, factor)
            elseif kind == "FontString" then
                copyFont(ctx, textSubFor(ctx, level, tag), r, factor)
            end
        end
    end
end

local function walk(ctx, frame, group)
    local level = math.max(0, math.min(G.MAX_LEVELS, (frame:GetFrameLevel() or 0) - ctx.base))
    local factor = (tonumber(frame:GetEffectiveScale()) or 1) / ctx.scale
    copyRegions(ctx, frame, group, level, factor)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsShown() then walk(ctx, child, child.qcGhostGroup or group) end
    end
end

--- Mirror what `roots` draw onto `ghost`, placed about `src`'s center. `size` is the ring's slices,
--- for the Fan. Roots are walked whether shown or not: a closing surface has just
--- been hidden, and a root's children keep their own flags.
--- @return boolean captured false: nothing to draw, or no rect yet (the track snaps)
function G.Capture(ghost, src, roots, size)
    for i = 1, ghost.used do resetSub(ghost.subs[i]) end
    for i = 1, ghost.textUsed do resetSub(ghost.textSubs[i]) end
    ghost.used, ghost.textUsed, ghost.size = 0, 0, math.max(1, tonumber(size) or 1)
    local cx, cy = src:GetCenter()
    if not cx then return false end
    ghost.scale = tonumber(src:GetScale()) or 1
    for _, layer in ipairs({ ghost.stage, ghost.text }) do
        layer:SetFrameStrata(src:GetFrameStrata())
        layer:SetFrameLevel(src:GetFrameLevel())
        layer:SetAlpha(1)
        layer:ClearAllPoints()
        layer:SetPoint("CENTER", src, "CENTER", 0, 0)
    end
    ghost.text:SetScale(ghost.scale)
    local ctx = { ghost = ghost, base = src:GetFrameLevel() or 0, cx = cx, cy = cy, byKey = {}, textByKey = {},
        drawn = 0,
        scale = tonumber(src:GetEffectiveScale()) or 1 }
    for _, root in ipairs(roots) do walk(ctx, root, root.qcGhostGroup) end
    return ctx.drawn > 0 and not ctx.failed
end

local function pulse(f)
    return 1 + NS.Anim.EMPHASIS_PULSE * math.sin(math.pi * f)
end

-- A sub-frame's alpha at this pose: the sent place bright through its hold, a place through the Fan.
local function subAlpha(ghost, sub, pose, restAlpha, emphasized, f)
    local A = NS.Anim
    if emphasized then
        return restAlpha * (f <= A.EMPHASIS_HOLD and 1 or (1 - f) / (1 - A.EMPHASIS_HOLD))
    end
    local alpha = pose.alpha * restAlpha
    if sub.qcGroup then return alpha * A.FanAlpha(pose.fan, (sub.qcGroup - 1) / ghost.size) end
    return alpha
end

-- Play one string's scale: only ever this one animation, so no chain's composition is relied on.
local function runScale(fs, from, to, duration, smoothing)
    local group, anim = fs.qcScaleGroup, fs.qcScale
    if not group then return end
    group:Stop()
    if from == 1 and to == 1 then return end
    anim:SetScaleFrom(from, from)
    anim:SetScaleTo(to, to)
    anim:SetDuration(math.max(duration, 0.001))
    anim:SetSmoothing(smoothing)
    group:Play()
end

local function runPlace(ghost, wanted, from, to, duration, smoothing)
    for i = 1, ghost.textUsed do
        local sub = ghost.textSubs[i]
        if sub.qcGroup == wanted then
            for j = 1, sub.qcFontUsed do runScale(sub.qcFont[j], from, to, duration, smoothing) end
        end
    end
end

--- Run one leg of the text's scale: an open, a close or a reversal. After G.Show: a hidden string does
--- not play. The art's tween is the script's and this one the client's, so `phase` picks the smoothing.
function G.ScaleText(ghost, from, to, duration, phase)
    for i = 1, ghost.textUsed do
        local sub = ghost.textSubs[i]
        for j = 1, sub.qcFontUsed do runScale(sub.qcFont[j], from, to, duration, SMOOTHING[phase]) end
    end
end

--- The sent place's text leaves its leg for the pulse, over the `duration` the close has left: up
--- now, and back when G.Pose passes the middle.
function G.EmphasizeText(ghost, sent, duration)
    ghost.turnAfter = duration / 2
    runPlace(ghost, sent, 1, 1 + NS.Anim.EMPHASIS_PULSE, ghost.turnAfter, SMOOTHING.open)
end

local function poseText(ghost, pose, restAlpha, emphasis, f)
    if emphasis and ghost.turnAfter and f >= 0.5 then
        runPlace(ghost, emphasis, 1 + NS.Anim.EMPHASIS_PULSE, 1, ghost.turnAfter, SMOOTHING.close)
        ghost.turnAfter = nil
    end
    for i = 1, ghost.textUsed do
        local sub = ghost.textSubs[i]
        local sent = emphasis ~= nil and sub.qcGroup == emphasis
        sub:SetAlpha(subAlpha(ghost, sub, pose, restAlpha, sent, f))
        local s = sent and pulse(f) or pose.scale
        for j = 1, sub.qcFontUsed do
            local fs = sub.qcFont[j]
            if fs.qcScaleGroup then moveText(ghost, fs, s) end
        end
    end
end

--- Draw a pose: the stage scaled, each sub-frame at the pose's alpha times `restAlpha` (the real frame's
--- alpha at rest), a place through the Fan, and the place `emphasis` names bright and pulsing, `f` of
--- the way through the close. The text keeps its size: its scale is G.ScaleText's.
function G.Pose(ghost, pose, restAlpha, emphasis, f)
    f = f or 0
    ghost.stage:SetScale(ghost.scale * pose.scale)
    for i = 1, ghost.used do
        local sub = ghost.subs[i]
        local sent = emphasis ~= nil and sub.qcGroup == emphasis
        sub:SetAlpha(subAlpha(ghost, sub, pose, restAlpha, sent, f))
        if sent then sub:SetScale(pulse(f) / pose.scale) end
    end
    poseText(ghost, pose, restAlpha, emphasis, f)
end

function G.Show(ghost)
    ghost.stage:Show()
    ghost.text:Show()
end

--- Down, with no string left scaling.
function G.Hide(ghost)
    for i = 1, ghost.textUsed do
        local sub = ghost.textSubs[i]
        for j = 1, sub.qcFontUsed do
            local group = sub.qcFont[j].qcScaleGroup
            if group then group:Stop() end
        end
    end
    ghost.stage:Hide()
    ghost.text:Hide()
end
