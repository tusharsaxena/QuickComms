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
-- THE POSE'S MOTIONS (the dial styles). A copy hangs off its sub-frame, so a place's radial offset is one
-- SetPoint on each of its sub-frames, and its scale one SetScale, about the dial's center as the mockup
-- has it. A turn cannot be one SetPoint: a fill's texture center is its apex, near the dial's center,
-- while its bead and its icon sit far out, so each copy of a turning place is re-anchored at its own
-- turned offset. Art tagged `qcGhostTurn` (a fill, a shine layer, their masks, the highlight) also takes
-- SetRotation from the base rotation the capture kept; an icon and a string stay upright, and what has
-- no place (the hub, the arrow, the title) never turns. A whole-dial offset moves the stage, and the sent
-- place undoes it: it stays put, whatever the style.
--
-- ONE AXIS is a Scale animation, a leg at a time as the text's is, on each art sub-frame, about the
-- dial's center: SetScale has one number. It is per sub-frame so the sent place can leave it. The text
-- takes both axes in its own leg, and its place from the pose. A leg's end delay holds it until the next
-- leg or the hide, because a finished animation lets go, which at a Squash's line would flash the whole
-- dial. THE SUBSTITUTE: where a frame takes no Scale animation (Compat.StretchAnimation) both axes
-- become the smaller one, uniform, so a Squash or a Flip reads as a shrink. Never 0: the client raises on
-- SetScale(0), so every scale written is at least MIN_SCALE.
--
-- THE FLASH is one additive texture on a frame over everything, made the first time a pose asks for it.
--
-- Frames, regions and animations are pooled per ghost, made on first use and never destroyed; making a
-- plain frame is allowed in combat. MAX_LEVELS bounds a sub-frame's source level above the stage.

NS.AnimGhost = NS.AnimGhost or {}
local G = NS.AnimGhost

G.MAX_LEVELS = 400
G.LEVEL_STEP = 2    -- frame levels per source level: its art, then its text
G.MIN_SCALE = 0.01  -- the client raises on a scale of 0
G.LEG_HOLD = 0.25   -- seconds a finished leg holds its end for the next one
G.FLASH_REACH = 195 / 165   -- the bloom's radius over the dial's, the mockup's

local SMOOTHING = { open = "OUT", close = "IN", linear = "NONE" }   -- the client's nearest to A.Ease

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
    return { stage = stage, text = text, subs = {}, used = 0, textSubs = {}, textUsed = 0, scale = 1, size = 1,
        start = 0, radius = 0, offX = 0, offY = 0 }
end

local function floored(s)
    return math.max(G.MIN_SCALE, s)
end

-- Put `frame` at (x, y) from `to`'s center, when it is not there already.
local function moveFrame(frame, to, x, y)
    if frame.qcOffX == x and frame.qcOffY == y then return end
    frame.qcOffX, frame.qcOffY = x, y
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", to, "CENTER", x, y)
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
    if sub.qcStretchGroup then sub.qcStretchGroup:Stop() end
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
        sub.qcOffX, sub.qcOffY = 0, 0
        if layer == ghost.stage then sub.qcStretchGroup, sub.qcStretch = NS.Compat.StretchAnimation(sub) end
        list[ghost[usedKey]] = sub
    end
    if layer == ghost.stage then ghost.stretch = ghost.stretch ~= false and sub.qcStretchGroup ~= nil end
    sub.qcGroup, sub.qcTurned, sub.qcScaled = group, 0, 1
    moveFrame(sub, layer, 0, 0)
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

-- Hang a copy off its sub-frame where `src` is, and keep that offset and what it may turn from.
local function place(r, ctx, sub, src, factor)
    local x, y = src:GetCenter()
    if not x then return false end
    r.qcX, r.qcY = (x - ctx.cx) * factor, (y - ctx.cy) * factor
    r.qcTurn = src.qcGhostTurn and (src:GetRotation() or 0) or nil
    r:ClearAllPoints()
    r:SetPoint("CENTER", sub, "CENTER", r.qcX, r.qcY)
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
    if not place(m, ctx, sub, src, factor) then return nil end
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
    if rotation ~= 0 or src.qcGhostTurn then t:SetTexCoord(0, 1, 0, 1) else t:SetTexCoord(src:GetTexCoord()) end
    t:SetRotation(rotation)
    t:SetDesaturated(src:IsDesaturated() and true or false)
end

local function copyTexture(ctx, sub, src, factor)
    if not (src:GetAtlas() or src:GetTexture()) then return end
    local t = pooled(sub, "qcTex", "qcTexUsed", function() return sub:CreateTexture(nil, "ARTWORK") end)
    if not place(t, ctx, sub, src, factor) then
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

-- A string at (x, y) from the dial's center. A string with no scale of its own stays put.
local function moveText(ghost, fs, x, y)
    if fs.qcAtX == x and fs.qcAtY == y then return end
    fs.qcAtX, fs.qcAtY = x, y
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", ghost.text, "CENTER", x, y)
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
    fs.qcX, fs.qcY, fs.qcAtX, fs.qcAtY = (x - ctx.cx) * factor, (y - ctx.cy) * factor, nil, nil
    moveText(ctx.ghost, fs, fs.qcX, fs.qcY)
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

--- Mirror what `roots` draw onto `ghost`, placed about `src`'s center. `size` is the ring's slices, and
--- `shape` its { start, disc }, which a place's bisector and the radial motions read. Roots are walked whether shown or not: a closing surface has just
--- been hidden, and a root's children keep their own flags.
--- @return boolean captured false: nothing to draw, or no rect yet (the track snaps)
function G.Capture(ghost, src, roots, size, shape)
    for i = 1, ghost.used do resetSub(ghost.subs[i]) end
    for i = 1, ghost.textUsed do resetSub(ghost.textSubs[i]) end
    ghost.used, ghost.textUsed, ghost.size = 0, 0, math.max(1, tonumber(size) or 1)
    ghost.start = shape and tonumber(shape.start) or 0
    ghost.radius = (shape and tonumber(shape.disc) or 0) / 2
    ghost.src, ghost.sent, ghost.stretch, ghost.turnAfter = src, nil, nil, nil
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
    ghost.offX, ghost.offY = 0, 0
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

-- The uniform scale and the two axes a pose comes to on this ghost: the substitute where art cannot take
-- one axis alone.
local function axes(ghost, pose)
    if ghost.stretch then return pose.scale, pose.scaleX, pose.scaleY end
    return pose.scale * math.min(pose.scaleX, pose.scaleY), 1, 1
end

local function placeOf(pose, group)
    return group and pose.places and pose.places[group] or nil
end

-- (x, y) turned `a` radians clockwise.
local function turned(x, y, a)
    if a == 0 then return x, y end
    local c, s = math.cos(a), math.sin(a)
    return x * c + y * s, y * c - x * s
end

-- What the pose does to `group`: its turn (orbit plus spin), its scale, and its offset from the dial's
-- center along its bisector, carried round by the orbit and not by the spin. Nothing, without a place.
local function motion(ghost, pose, group)
    if not group then return 0, 1, 0, 0 end
    local p = placeOf(pose, group)
    if not p then return pose.rot, 1, 0, 0 end
    local orbit, x, y = pose.rot + p.angle, 0, 0
    if p.radius ~= 1 then
        local a = NS.DialSlices.Middle(group, ghost.size, ghost.start) + orbit
        local d = (p.radius - 1) * ghost.radius
        x, y = d * math.sin(a), d * math.cos(a)
    end
    return orbit + p.spin, floored(p.scale), x, y
end

-- A sub-frame's alpha at this pose: the sent place bright through its hold, a place alone and through
-- the Fan, and what has no place by the hub's.
local function subAlpha(ghost, sub, pose, restAlpha, emphasized, f)
    local A = NS.Anim
    if emphasized then
        return restAlpha * (f <= A.EMPHASIS_HOLD and 1 or (1 - f) / (1 - A.EMPHASIS_HOLD))
    end
    local alpha = pose.alpha * restAlpha
    local group = sub.qcGroup
    if not group then return alpha * pose.hub end
    local p = placeOf(pose, group)
    if p then alpha = alpha * A.Clamp(p.alpha) end
    return alpha * A.FanAlpha(pose.fan, (group - 1) / ghost.size)
end

-- One Scale animation's leg. Nothing plays at 1 on both ends of both axes.
local function playScale(group, anim, fx, fy, tx, ty, duration, smoothing)
    group:Stop()
    if fx == 1 and fy == 1 and tx == 1 and ty == 1 then return end
    anim:SetScaleFrom(floored(fx), floored(fy))
    anim:SetScaleTo(floored(tx), floored(ty))
    anim:SetDuration(math.max(duration, 0.001))
    anim:SetSmoothing(smoothing)
    if anim.SetEndDelay then anim:SetEndDelay(G.LEG_HOLD) end
    group:Play()
end

-- Play one string's scale: only ever this one animation, so no chain's composition is relied on.
local function runScale(fs, fx, fy, tx, ty, duration, smoothing)
    if fs.qcScaleGroup then playScale(fs.qcScaleGroup, fs.qcScale, fx, fy, tx, ty, duration, smoothing) end
end

local function runPlace(ghost, wanted, from, to, duration, smoothing)
    for i = 1, ghost.textUsed do
        local sub = ghost.textSubs[i]
        if sub.qcGroup == wanted then
            for j = 1, sub.qcFontUsed do runScale(sub.qcFont[j], from, from, to, to, duration, smoothing) end
        end
    end
end

-- A string's two scales in `pose`, for `group`.
local function textScale(ghost, pose, group)
    local s, x, y = axes(ghost, pose)
    local p = placeOf(pose, group)
    if p then s = s * p.scale end
    return s * x, s * y
end

local function legText(ghost, sub, from, to, duration, smoothing)
    local fx, fy = textScale(ghost, from, sub.qcGroup)
    local tx, ty = textScale(ghost, to, sub.qcGroup)
    for j = 1, sub.qcFontUsed do runScale(sub.qcFont[j], fx, fy, tx, ty, duration, smoothing) end
end

--- Run one leg of the client's scales, `from` and `to` being poses: every string's, and the art's one
--- axis. An open, a close, a reversal or a knot's, whichever picks the smoothing. After G.Show: a hidden
--- region does not play. The art's uniform tween is the script's and this one the client's. The sent place
--- is on its pulse and takes no leg.
function G.ScaleText(ghost, from, to, duration, phase)
    local smoothing = SMOOTHING[phase]
    for i = 1, ghost.textUsed do
        local sub = ghost.textSubs[i]
        if sub.qcGroup == nil or sub.qcGroup ~= ghost.sent then legText(ghost, sub, from, to, duration, smoothing) end
    end
    if not ghost.stretch then return end
    for i = 1, ghost.used do
        local sub = ghost.subs[i]
        if sub.qcGroup == nil or sub.qcGroup ~= ghost.sent then
            playScale(sub.qcStretchGroup, sub.qcStretch, from.scaleX, from.scaleY, to.scaleX, to.scaleY, duration, smoothing)
        end
    end
end

--- The sent place's text leaves its leg for the pulse, over the `duration` the close has left: up
--- now, and back when G.Pose passes the middle. Its art leaves the one-axis leg: it stays whole.
function G.EmphasizeText(ghost, sent, duration)
    ghost.turnAfter, ghost.sent = duration / 2, sent
    runPlace(ghost, sent, 1, 1 + NS.Anim.EMPHASIS_PULSE, ghost.turnAfter, SMOOTHING.open)
    for i = 1, ghost.used do
        local sub = ghost.subs[i]
        if sub.qcGroup == sent and sub.qcStretchGroup then sub.qcStretchGroup:Stop() end
    end
end

-- Every copy on an art sub-frame at its own offset turned `a`, and the art off its base rotation.
local function turnList(sub, list, used, a)
    for i = 1, used do
        local r = list[i]
        local x, y = turned(r.qcX, r.qcY, a)
        r:ClearAllPoints()
        r:SetPoint("CENTER", sub, "CENTER", x, y)
        if r.qcTurn then r:SetRotation(r.qcTurn - a) end
    end
end

local function turnSub(sub, a)
    if sub.qcTurned == a then return end
    sub.qcTurned = a
    turnList(sub, sub.qcTex, sub.qcTexUsed, a)
    turnList(sub, sub.qcMaskTex, sub.qcMaskUsed, a)
end

local function scaleSub(sub, s)
    if sub.qcScaled == s then return end
    sub.qcScaled = s
    sub:SetScale(s)
end

local function poseText(ghost, pose, restAlpha, emphasis, f)
    if emphasis and ghost.turnAfter and f >= 0.5 then
        runPlace(ghost, emphasis, 1 + NS.Anim.EMPHASIS_PULSE, 1, ghost.turnAfter, SMOOTHING.close)
        ghost.turnAfter = nil
    end
    local u, ax, ay = axes(ghost, pose)
    local dx, dy = pose.dx * ghost.radius, pose.dy * ghost.radius
    for i = 1, ghost.textUsed do
        local sub = ghost.textSubs[i]
        local sent = emphasis ~= nil and sub.qcGroup == emphasis
        sub:SetAlpha(subAlpha(ghost, sub, pose, restAlpha, sent, f))
        local turn, s, ox, oy = motion(ghost, pose, sub.qcGroup)
        for j = 1, sub.qcFontUsed do
            local fs = sub.qcFont[j]
            if fs.qcScaleGroup and sent then
                local p = pulse(f)
                moveText(ghost, fs, fs.qcX * p, fs.qcY * p)
            elseif fs.qcScaleGroup then
                local x, y = turned(fs.qcX * s, fs.qcY * s, turn)
                moveText(ghost, fs, (x + ox) * u * ax + dx, (y + oy) * u * ay + dy)
            end
        end
    end
end

local function poseArt(ghost, sub, pose, sent, f)
    local stage = ghost.stage
    if sent then
        local p, u = pulse(f), axes(ghost, pose)
        scaleSub(sub, p / floored(u))
        moveFrame(sub, stage, -pose.dx * ghost.radius / p, -pose.dy * ghost.radius / p)
        turnSub(sub, 0)
        return
    end
    local turn, s, x, y = motion(ghost, pose, sub.qcGroup)
    scaleSub(sub, s)
    moveFrame(sub, stage, x / s, y / s)
    turnSub(sub, turn)
end

-- The whole-dial offset, on the stage: in its own scale, so the pose's scale does not carry it.
local function moveStage(ghost, pose, u)
    local x, y = pose.dx * ghost.radius / u, pose.dy * ghost.radius / u
    if ghost.offX == x and ghost.offY == y then return end
    ghost.offX, ghost.offY = x, y
    ghost.stage:ClearAllPoints()
    ghost.stage:SetPoint("CENTER", ghost.src, "CENTER", x, y)
end

local function newFlash(ghost)
    local frame = CreateFrame("Frame", nil, ghost.stage)
    frame:EnableMouse(false)
    frame:SetSize(1, 1)
    frame:SetPoint("CENTER", ghost.stage, "CENTER", 0, 0)
    local t = frame:CreateTexture(nil, "OVERLAY")
    t:SetTexture(NS.DialSlices.MEDIA .. "dial-glow")
    t:SetBlendMode("ADD")
    t:SetPoint("CENTER", frame, "CENTER", 0, 0)
    ghost.flashFrame, ghost.flash = frame, t
    return t
end

local function poseFlash(ghost, flash)
    local t = ghost.flash
    if flash <= 0 then
        if t and ghost.flashOn then t:Hide() end
        ghost.flashOn = false
        return
    end
    t = t or newFlash(ghost)
    local across = 2 * ghost.radius * G.FLASH_REACH
    t:SetSize(across, across)
    local offset = G.LEVEL_STEP * (G.MAX_LEVELS + 1)   -- over every level's art and text
    ghost.flashFrame:SetFrameLevel(ghost.stage:GetFrameLevel() + offset)
    t:SetAlpha(flash)
    t:Show()
    ghost.flashOn = true
end

--- Draw a pose: the stage scaled and offset, each sub-frame at the pose's alpha times `restAlpha` (the
--- real frame's alpha at rest), each place through its own motion and the Fan, and the place `emphasis`
--- names bright, pulsing and where it rests, `f` of the way through the close. The text keeps its size:
--- its scale is G.ScaleText's, its place this one's.
function G.Pose(ghost, pose, restAlpha, emphasis, f)
    f = f or 0
    local u = floored((axes(ghost, pose)))
    ghost.stage:SetScale(ghost.scale * u)
    moveStage(ghost, pose, u)
    for i = 1, ghost.used do
        local sub = ghost.subs[i]
        local sent = emphasis ~= nil and sub.qcGroup == emphasis
        sub:SetAlpha(subAlpha(ghost, sub, pose, restAlpha, sent, f))
        poseArt(ghost, sub, pose, sent, f)
    end
    poseText(ghost, pose, restAlpha, emphasis, f)
    poseFlash(ghost, pose.flash)
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
    for i = 1, ghost.used do
        local group = ghost.subs[i].qcStretchGroup
        if group then group:Stop() end
    end
    ghost.stage:Hide()
    ghost.text:Hide()
end
