local _, NS = ...
-- modules/Anim_Ghost.lua — a surface's insecure copy, the thing the open and close animations actually
-- move (#13, the design's "The ghost"). The dial's header and a pad's root are secure or protected:
-- nothing here may show, hide, place or scale them, and once secure code hides one its regions cannot
-- be seen. So the ghost mirrors them: a plain, mouse-off frame under UIParent, anchored to the real
-- frame's center (an insecure frame may anchor to a protected one; never the other way round), in its
-- strata, and carrying a copy of each texture and font string it shows.
--
-- CAPTURE ONLY READS the secure frames, so it is safe in combat, and it works on a just-hidden one:
-- the hide cleared the root's own shown flag, not its children's. The stacking holds because regions
-- are grouped into sub-frames by their source frame's level above the root. A region or frame tagged
-- `qcGhostGroup` (a dial's place) goes into a sub-frame of its own, which the Fan and the send's
-- emphasis address. `qcNoGhost` leaves a frame out (a pad's drag strip, which ignores the pad's
-- alpha). A color texture cannot be read back, so its painter records `qcGhostColor`; one with neither
-- a file nor a record is left out. Rects may be missing on a frame never laid out: capture then answers
-- false, and the track snaps (the rulings' fallback, never a guess).
--
-- Frames and regions are pooled per ghost, made on first use and never destroyed; making a plain frame
-- is allowed in combat. MAX_LEVELS bounds a sub-frame's level above the stage.

NS.AnimGhost = NS.AnimGhost or {}
local G = NS.AnimGhost

G.MAX_LEVELS = 400

local made = 0

--- An empty ghost. Its stage is a child of UIParent, hidden until a track plays it, and named, so
--- /fstack can tell it from the surface it copies.
function G.New()
    made = made + 1
    local stage = CreateFrame("Frame", "QuickCommsGhost" .. made, UIParent)
    stage:EnableMouse(false)
    stage:SetSize(1, 1)
    stage:Hide()
    return { stage = stage, subs = {}, used = 0, scale = 1, size = 1 }
end

local function resetSub(sub)
    for i = 1, sub.qcTexUsed do
        local t = sub.qcTex[i]
        for _, mask in ipairs(t.qcMasks or {}) do t:RemoveMaskTexture(mask) end
        t.qcMasks = nil
        t:Hide()
    end
    for i = 1, sub.qcMaskUsed do sub.qcMaskTex[i]:Hide() end
    for i = 1, sub.qcFontUsed do sub.qcFont[i]:Hide() end
    sub.qcTexUsed, sub.qcMaskUsed, sub.qcFontUsed = 0, 0, 0
    sub.qcGroup = nil
    sub:Hide()
end

local function acquireSub(ghost, level, group)
    ghost.used = ghost.used + 1
    local sub = ghost.subs[ghost.used]
    if not sub then
        sub = CreateFrame("Frame", nil, ghost.stage)
        sub:EnableMouse(false)
        sub:SetSize(1, 1)
        sub:SetPoint("CENTER", ghost.stage, "CENTER", 0, 0)
        sub.qcTex, sub.qcMaskTex, sub.qcFont = {}, {}, {}
        sub.qcTexUsed, sub.qcMaskUsed, sub.qcFontUsed = 0, 0, 0
        ghost.subs[ghost.used] = sub
    end
    sub.qcGroup = group
    sub:SetFrameLevel(ghost.stage:GetFrameLevel() + level)
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
    local c, atlas, file = src.qcGhostColor, src:GetAtlas(), src:GetTexture()
    if not (c or atlas or file) then return end
    local t = pooled(sub, "qcTex", "qcTexUsed", function() return sub:CreateTexture(nil, "ARTWORK") end)
    if not place(t, ctx, src, factor) then
        ctx.failed = true
        return
    end
    if c then
        t:SetRotation(0)
        t:SetColorTexture(c[1], c[2], c[3], c[4])
        t:SetVertexColor(1, 1, 1, 1)
    else
        paintFile(t, src)
        t:SetVertexColor(src:GetVertexColor())
    end
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

local function copyFont(ctx, sub, src, factor)
    local text = src:GetText()
    local face, size, flags = src:GetFont()
    if not (text and text ~= "" and face) then return end
    local fs = pooled(sub, "qcFont", "qcFontUsed", function() return sub:CreateFontString(nil, "OVERLAY") end)
    if not place(fs, ctx, src, factor) then
        ctx.failed = true
        return
    end
    fs:SetFont(face, size * factor, flags)
    fs:SetWordWrap(false)
    fs:SetJustifyH(src:GetJustifyH() or "CENTER")
    fs:SetTextColor(src:GetTextColor())
    fs:SetShadowOffset(src:GetShadowOffset())
    fs:SetShadowColor(src:GetShadowColor())
    fs:SetText(text)
    fs:SetAlpha(src:GetAlpha() or 1)
    fs:Show()
    ctx.drawn = ctx.drawn + 1
end

-- The sub-frame for a source level and group: one each, so groups stay addressable and regions at
-- one level keep their draw layers against each other.
local function subFor(ctx, level, group)
    local key = level .. ":" .. tostring(group)
    local sub = ctx.byKey[key]
    if not sub then
        sub = acquireSub(ctx.ghost, level, group)
        ctx.byKey[key] = sub
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
                copyFont(ctx, subFor(ctx, level, tag), r, factor)
            end
        end
    end
end

local function walk(ctx, frame, group)
    local level = math.max(0, math.min(G.MAX_LEVELS, (frame:GetFrameLevel() or 0) - ctx.base))
    local factor = (tonumber(frame:GetEffectiveScale()) or 1) / ctx.scale
    copyRegions(ctx, frame, group, level, factor)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsShown() and not child.qcNoGhost then walk(ctx, child, child.qcGhostGroup or group) end
    end
end

--- Mirror what `roots` draw onto `ghost`, placed about `src`'s center. `size` is the ring's slices,
--- for the Fan (a pad passes none). Roots are walked whether shown or not: a closing surface has just
--- been hidden, and a root's children keep their own flags.
--- @return boolean captured false: nothing to draw, or no rect yet (the track snaps)
function G.Capture(ghost, src, roots, size)
    for i = 1, ghost.used do resetSub(ghost.subs[i]) end
    ghost.used, ghost.size = 0, math.max(1, tonumber(size) or 1)
    local cx, cy = src:GetCenter()
    if not cx then return false end
    local stage = ghost.stage
    stage:SetFrameStrata(src:GetFrameStrata())
    stage:SetFrameLevel(src:GetFrameLevel())
    stage:SetAlpha(1)
    stage:ClearAllPoints()
    stage:SetPoint("CENTER", src, "CENTER", 0, 0)
    ghost.scale, ghost.src = tonumber(src:GetScale()) or 1, src
    local ctx = { ghost = ghost, base = src:GetFrameLevel() or 0, cx = cx, cy = cy, byKey = {}, drawn = 0,
        scale = tonumber(src:GetEffectiveScale()) or 1 }
    for _, root in ipairs(roots) do walk(ctx, root, root.qcGhostGroup) end
    return ctx.drawn > 0 and not ctx.failed
end

local function emphasized(sub, alpha, stageScale, f)
    local A = NS.Anim
    local fade = f <= A.EMPHASIS_HOLD and 1 or (1 - f) / (1 - A.EMPHASIS_HOLD)
    sub:SetAlpha(alpha * fade)
    sub:SetScale((1 + A.EMPHASIS_PULSE * math.sin(math.pi * f)) / stageScale)
end

--- Draw a pose: the stage scaled and moved, each sub-frame at the pose's alpha times `restAlpha` (the
--- real frame's alpha at rest), a place through the Fan, and the place `emphasis` names bright and
--- pulsing, `f` of the way through the close.
function G.Pose(ghost, pose, restAlpha, emphasis, f)
    local stage = ghost.stage
    local scale = math.max(0.01, pose.scale)
    stage:SetScale(ghost.scale * scale)
    stage:ClearAllPoints()
    stage:SetPoint("CENTER", ghost.src, "CENTER", pose.x / scale, pose.y / scale)
    local alpha = pose.alpha * restAlpha
    for i = 1, ghost.used do
        local sub, group = ghost.subs[i], ghost.subs[i].qcGroup
        if emphasis and group == emphasis then
            emphasized(sub, restAlpha, scale, f or 0)
        elseif group then
            sub:SetAlpha(alpha * NS.Anim.FanAlpha(pose.fan, (group - 1) / ghost.size))
        else
            sub:SetAlpha(alpha)
        end
    end
end

function G.Show(ghost)
    ghost.stage:Show()
end

function G.Hide(ghost)
    ghost.stage:Hide()
end
