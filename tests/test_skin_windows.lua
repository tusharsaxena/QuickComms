-- tests/test_skin_windows.lua — the windows Quick Comms draws, painted through its skin facade (QC-02;
-- skinning-§1, §2, anti-pattern #107): the Preview window, the modal window the callout popup and the
-- icon browser are built in (settings/ModalWindow.lua), and the two windows' own chrome.
--
-- What this addon owes and nothing the library pins itself: each window is handed to the owner's
-- primitives with the options DECISIONS rules (the Preview window a Shell with its title in the top
-- bar, D9; the modal window's template chrome kept stock under Ka0s Default and skinned under every
-- other skin, X10 / LK-05; the icon browser's scroller a skin ScrollBar, D3), every color the host
-- draws itself reads a token (the library's, or this addon's own qc.* where Ka0s Default's pixel has
-- no exact library token, X1), each answers today's pixels under Ka0s Default and moves with a skin
-- switch, and no color literal is left in these files.
--
-- Colors are read through the kit's paint recorder (tests/_kit/mock_paint.lua), installed on each
-- case's mock before any window is built (every window is built on its first show). Every case builds
-- its own instance, so nothing leaks between cases.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, fail = T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.fail

local OWNER = "QuickComms"
local OTHER = "obsidian"

-- ── the literal gate, over the window files, the HUD's (QC-03) and the settings pages' (QC-04) ──

local FILES = {
    "modules/PreviewWindow.lua",
    "settings/ModalWindow.lua",
    "settings/CalloutPopup.lua",
    "settings/IconBrowser.lua",
    -- QC-03: the HUD (tests/test_skin_hud.lua holds what each draws)
    "modules/Pad.lua",
    "modules/Pad_Render.lua",
    "modules/Pad_Layout.lua",
    "modules/Dial.lua",
    "modules/Dial_Render.lua",
    "modules/Dial_Slices.lua",
    "modules/IconStyle.lua",
    "modules/Glow.lua",
    -- QC-04: the settings pages QuickComms draws rows on itself (tests/test_skin_tools.lua holds
    -- their AceGUI widgets; the schema files are data and carry no color)
    "settings/Panel.lua",
    "settings/Pads.lua",
    "settings/Dials.lua",
    "settings/Callouts.lua",
    "settings/Groups.lua",
    "settings/Groups_When.lua",
    "settings/Editors.lua",
    "settings/Profiles.lua",
}

-- call name -> the argument positions that hold color components (LootHistory's gate, LH-05).
local COLOR_ARGS = {
    SetTextColor = { 1, 2, 3 }, SetColorTexture = { 1, 2, 3 }, SetVertexColor = { 1, 2, 3 },
    SetBackdropColor = { 1, 2, 3 }, SetBackdropBorderColor = { 1, 2, 3 },
    AddLine = { 2, 3, 4 }, AddDoubleLine = { 3, 4, 5, 6, 7, 8 }, SetText = { 2, 3, 4 },
}

-- What is not chrome: each entry names one file, a plain substring the line carries, and why. An
-- entry that matches nothing fails the gate, so the list cannot outlive what it excuses.
local ALLOW = {
    { file = "settings/IconBrowser.lua", find = "CHAT_GRAY =",
      why = "the combat refusal's chat line: chat output, not a skinned surface (DECISIONS X7)" },
    { file = "modules/Pad_Render.lua", find = "L[\"Channel: %s\"]",
      why = "the channel's name in WoW's chat-type color: a game-meaning color (rung 4)" },
    { file = "modules/Pad_Render.lua", find = "NO_INNER =",
      why = "a cleared inner line: no color is drawn, under any skin" },
    { file = "modules/Dial_Slices.lua", find = "BLACK =",
      why = "the shine overlay's shading: the player's shine art, never skinned (DECISIONS QuickComms D6)" },
    { file = "settings/Groups.lua", find = "|cff%s%s|r",
      why = "a callout's channel in WoW's chat-type color: a game-meaning color (rung 4)" },
    { file = "settings/Editors.lua", find = "if w.image then w.image:SetVertexColor(1, 1, 1, 1) end",
      why = "a pooled Label's image put back to AceGUI's stock white on release: no color is drawn" },
}

local function code(line) return (line:gsub("%-%-.*$", "")) end

--- Split a call's argument list at its top-level commas (parens, braces and quotes nest).
local function splitArgs(s)
    local args, depth, buf, quote = {}, 0, {}, nil
    local i = 1
    while i <= #s do
        local c = s:sub(i, i)
        if quote then
            buf[#buf + 1] = c
            if c == "\\" then buf[#buf + 1] = s:sub(i + 1, i + 1); i = i + 1
            elseif c == quote then quote = nil end
        elseif c == '"' or c == "'" then quote = c; buf[#buf + 1] = c
        elseif c == "(" or c == "{" or c == "[" then depth = depth + 1; buf[#buf + 1] = c
        elseif c == ")" or c == "}" or c == "]" then depth = depth - 1; buf[#buf + 1] = c
        elseif c == "," and depth == 0 then args[#args + 1] = table.concat(buf); buf = {}
        else buf[#buf + 1] = c end
        i = i + 1
    end
    args[#args + 1] = table.concat(buf)
    return args
end

local function isNumber(arg) return arg:match("^%s*%-?%d*%.?%d+%s*$") ~= nil end

-- A color table literal: three or four numbers in braces, the shape every typed look value had here
-- (`local GOLD = { 1, 0.82, 0 }`).
local COLOR_TABLE = "{%s*%-?%d*%.?%d+%s*,%s*%-?%d*%.?%d+%s*,%s*%-?%d*%.?%d+%s*[,}]"

--- Every offending line of one source text: { line = n, text = what was found }.
local function scan(src)
    local lines, hits = {}, {}
    for ln in (src .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = code(ln) end
    local stripped = table.concat(lines, "\n")
    for name, positions in pairs(COLOR_ARGS) do
        local init = 1
        while true do
            local s, e, args = stripped:find("[:%.]" .. name .. "%s*(%b())", init)
            if not s then break end
            init = e + 1
            local list = splitArgs(args:sub(2, -2))
            for _, p in ipairs(positions) do
                if list[p] and isNumber(list[p]) then
                    local n = select(2, stripped:sub(1, s):gsub("\n", "")) + 1
                    hits[#hits + 1] = { line = n, text = lines[n] }
                    break
                end
            end
        end
    end
    for n, ln in ipairs(lines) do
        if ln:find("|c[fF][fF]") or ln:find(COLOR_TABLE) then hits[#hits + 1] = { line = n, text = ln } end
    end
    return hits
end

local function readAll(path)
    local f = io.open((T.root or ".") .. "/" .. path, "rb")
    if not f then fail("skin literal gate: cannot read " .. path) end
    local s = f:read("*a")
    f:close()
    return s
end

test("skin windows: no color literal is left in the window files", function()
    -- red under: any typed look value in these files (`fs:SetTextColor(0.9, 0.9, 0.92)`, `|cffff4040`,
    -- `local GOLD = { 1, 0.82, 0 }`): it would draw Ka0s Default's pixel under every skin.
    local bad, used = {}, {}
    for _, path in ipairs(FILES) do
        for _, h in ipairs(scan(readAll(path))) do
            local ok = false
            for i, a in ipairs(ALLOW) do
                if a.file == path and h.text:find(a.find, 1, true) then used[i], ok = true, true end
            end
            if not ok then bad[#bad + 1] = ("%s:%d: %s"):format(path, h.line, (h.text:gsub("^%s+", ""))) end
        end
    end
    assertEqual(#bad, 0, "hard-coded colors the skin cannot reach (read a token through NS.Skin / "
        .. "NS.SkinColor / NS.SkinEscape, or add an allow-list entry with its reason):\n  "
        .. table.concat(bad, "\n  "))
    for i, a in ipairs(ALLOW) do
        assertTrue(used[i], ("stale allow-list entry: %s %q matches nothing"):format(a.file, a.find))
    end
end)

test("skin windows: the literal gate is falsifiable: a planted literal of each shape is reported", function()
    local planted = table.concat({
        "local x = 1",
        "fs:SetTextColor(0.85, 0.85, 0.85)",
        "tex:SetColorTexture(r, g,",
        "  0.5, 1)",
        'tt:AddLine("n records", 0.7, 0.7, 0.7)',
        'tt:AddDoubleLine("a", "b", r, g, b, 1, 1, 1)',
        'local s = "|cff808080(none)|r"',
        "local GOLD = { 1, 0.82, 0 }",
        "fs:SetTextColor(NS.SkinColor(\"text.body\"))   -- 0.9, 0.9, 0.9 in a comment",
        "tex:SetColorTexture(r, g, b, 0.95)",
        "-- |cffffffff in a comment",
        "local INSET = { left = 8, top = 24 }",
    }, "\n")
    local lines = {}
    for _, h in ipairs(scan(planted)) do lines[#lines + 1] = h.line end
    table.sort(lines)
    assertEqual(table.concat(lines, ","), "2,3,5,6,7,8",
        "the literal lines and only those (a token call, an alpha literal and a comment pass)")
end)

-- ── helpers ──────────────────────────────────────────────────────────────────────────────────────

local function near(a, b) return math.abs((a or 1) - (b or 1)) < 1e-6 end

local function assertColor(got, want, what)
    assertTrue(type(got) == "table", what .. ": nothing painted")
    assertTrue(type(want) == "table", what .. ": no token value to compare")
    for i = 1, 4 do
        assertTrue(near(got[i], want[i]),
            ("%s[%d]: got %s, want %s"):format(what, i, tostring(got[i]), tostring(want[i])))
    end
end

-- The mask calls the dial's round art makes (modules/Dial_Slices.lua), which the paint recorder's
-- regions do not model: answered as no-ops on every texture made from here on, so the dial a
-- preview shows can be built under the recorder. Nothing here asserts a mask.
local MASK_CALLS = { "AddMaskTexture", "RemoveMaskTexture", "SetMask" }

local function maskable(m)
    local create = m.CreateFrame
    m.CreateFrame = function(...)
        local f = create(...)
        local make = rawget(f, "CreateTexture")
        if make then
            rawset(f, "CreateTexture", function(self, ...)
                local t = make(self, ...)
                for _, name in ipairs(MASK_CALLS) do rawset(t, name, function() end) end
                return t
            end)
        end
        return f
    end
end

--- An enabled instance with the paint recorder on, the settings window up and nothing previewed.
local function boot(mock)
    local NS, m = T.enableAddon(mock and { mock = mock } or nil)
    dofile("tests/_kit/mock_paint.lua")(m)
    maskable(m)
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    m.SettingsPanel:Show()
    return NS, m, m.LibStub("LibKa0s-Skin-1.0")
end

--- The value `name` answers for this owner now: a library token or one of its own.
local function now(NS, name)
    local r, g, b, a = NS.Skin.Color(name)
    return { r, g, b, a or 1 }
end

--- Record every call to the facade's `names`, then call through: { [name] = { { target, opts } } }.
local function spy(NS, names)
    local seen = {}
    for _, name in ipairs(names) do
        local real = NS.Skin[name]
        seen[name] = {}
        NS.Skin[name] = function(target, opts, ...)
            table.insert(seen[name], { target = target, opts = opts })
            return real(target, opts, ...)
        end
    end
    return seen
end

local function callOn(list, target)
    for _, c in ipairs(list or {}) do
        if c.target == target then return c end
    end
    return nil
end

--- GameTooltip's lines with the colors each was given: { text, r, g, b } (the mock keeps the text).
local function tipColors(m)
    local tip, lines = m.GameTooltip, {}
    local setText, addLine, addDouble = tip.SetText, tip.AddLine, tip.AddDoubleLine
    tip.SetText = function(t, text, r, g, b, ...)
        lines = { { text, r, g, b } }
        return setText(t, text, r, g, b, ...)
    end
    tip.AddLine = function(t, text, r, g, b, ...)
        lines[#lines + 1] = { text, r, g, b }
        return addLine(t, text, r, g, b, ...)
    end
    tip.AddDoubleLine = function(t, left, right, lr, lg, lb, rr, rg, rb, ...)
        lines[#lines + 1] = { left, lr, lg, lb, right = { right, rr, rg, rb } }
        return addDouble(t, left, right, lr, lg, lb, rr, rg, rb, ...)
    end
    return function() return lines end
end

local function rgbOf(line) return { line[2], line[3], line[4], 1 } end

-- ── the Preview window (D9, D8) ──────────────────────────────────────────────────────────────────

local function previewWindow(NS)
    assertTrue(NS.Preview.SetPreviewAs("arena"))
    return NS.PreviewWindow.__frame()
end

test("skin windows: the Preview window is the owner's Shell, its title in the top bar", function()
    local NS = boot()
    local seen = spy(NS, { "Shell" })
    local f = previewWindow(NS)
    -- red under: NS.ApplySkin(f, NS.SKIN) (Core's own table: the window ignores the skin's top bar)
    local shell = callOn(seen.Shell, f)
    assertTrue(shell ~= nil, "the window is painted by the owner's Shell")
    assertFalse(type(shell.opts) == "table" and shell.opts.noTopBar, "the window carries the top bar")
    local button = callOn(seen.Shell, f.endButton)
    assertTrue(button ~= nil and button.opts.noTopBar == true, "End preview is a Shell box with no top bar")
    -- red under: keep the title at TOP -6 (it sat 6px into a 30px bar, D9)
    local band = NS.Skin.Token("title.height")
    local p = f.title.__points[#f.title.__points]
    assertEqual(p[1], "CENTER")
    assertEqual(p[3], "TOP")
    assertEqual(p[5], -band / 2, "the title centered in the top bar")
    local c = f.closeButton.__points[#f.closeButton.__points]
    assertEqual(c[5], -(band - 18) / 2, "the close mark centered in the top bar")
end)

test("skin windows: End preview's label is the step panels' tokens at rest, hovered and locked", function()
    local NS, m, Skin = boot()
    local f = previewWindow(NS)
    local label = f.endButton.__label
    -- red under: REST = { 0.9, 0.9, 0.92 } typed (the same under every skin)
    assertColor(m.__paint(label).textColor, now(NS, "sem.stepReady"), "rest")
    assertColor(m.__paint(label).textColor, { 0.9, 0.9, 0.92, 1 }, "rest is today's pixel")
    f.endButton:__fire("OnEnter")
    assertColor(m.__paint(label).textColor, now(NS, "btn.hover"), "hovered")
    f.endButton:__fire("OnLeave")
    assertColor(m.__paint(label).textColor, now(NS, "sem.stepReady"), "back at rest")
    local editGroup = NS.Preview.EditGroup
    NS.Preview.EditGroup = function() return "g1" end
    f.endButton:__fire("OnLeave")
    NS.Preview.EditGroup = editGroup
    assertColor(m.__paint(label).textColor, now(NS, "sem.unknown"), "locked")
    assertColor(m.__paint(label).textColor, { 0.6, 0.6, 0.6, 1 }, "locked is today's pixel")
    -- red under: no OnLooksChanged repaint (the label keeps the old skin's color until hovered)
    f.endButton:__fire("OnLeave")
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    assertColor(m.__paint(label).textColor, Skin:ResolveSkin(OTHER)["sem.stepReady"], "rest under " .. OTHER)
end)

test("skin windows: the Preview window's tooltips write their lines in the tooltip tokens", function()
    local NS, m = boot()
    local f = previewWindow(NS)
    local lines = tipColors(m)
    f.endButton:__fire("OnEnter")
    local got = lines()
    -- red under: AddLine(body, 1, 1, 1) and AddLine(typed, GRAY) typed
    assertColor(rgbOf(got[2]), now(NS, "gtip.value"), "the body line")
    assertColor(rgbOf(got[3]), now(NS, "sem.unknown"), "the typed command")
    assertColor(rgbOf(got[3]), { 0.6, 0.6, 0.6, 1 }, "the typed command is today's gray")
end)

-- ── the modal window (X10, D2, LK-05) ────────────────────────────────────────────────────────────

local function openPopup(NS)
    local Pop = NS.addon.Settings.CalloutPopup
    assertTrue(Pop.Open(NS.Library.CreateGroup({ name = "Mine" })))
    return Pop
end

test("skin windows: the modal window's template chrome is stock under Ka0s Default, every call", function()
    local NS = boot()
    local seen = spy(NS, { "Shell", "FadeNineSlice", "TitleBar", "CloseButton" })
    local Pop = openPopup(NS)
    local f = Pop.frame
    -- red under: drop stockDefault from any call (that part is faded and repainted under Ka0s
    -- Default, and the ratified settings-window look is gone, docs/ARCHITECTURE.md)
    local shell = callOn(seen.Shell, f)
    assertTrue(shell and shell.opts.stockDefault == true, "the window's Shell")
    local fade = callOn(seen.FadeNineSlice, f)
    assertTrue(fade and fade.opts.stockDefault == true, "the NineSlice")
    local bar = callOn(seen.TitleBar, f.NineSlice)
    assertTrue(bar and bar.opts.stockDefault == true and bar.opts.noBg == true, "the title")
    assertEqual(bar.opts.text, f.NineSlice.Text, "the title is the template's own text")
    local close = callOn(seen.CloseButton, f.ClosePanelButton)
    assertTrue(close and close.opts.stockDefault == true, "the close X")
end)

test("skin windows: the modal window's Bg is the client's under Ka0s Default and faded under a skin", function()
    local NS, m, Skin = boot()
    -- The template's Bg is a frame whose art is its texture regions (FlatPanelBackgroundTemplate):
    -- the mock's has none, so one is given it, as the client's has.
    local create, art = m.CreateFrame, nil
    m.CreateFrame = function(kind, name, parent, template, ...)
        local f = create(kind, name, parent, template, ...)
        if template == "SettingsFrameTemplate" then art = f.Bg:CreateTexture(nil, "BACKGROUND") end
        return f
    end
    openPopup(NS)
    assertTrue(art ~= nil, "the template was built")
    assertEqual(m.__paint(art).alpha, 1, "Ka0s Default keeps the template's background")
    -- red under: hand the Bg frame to Shell's `stock` (it takes textures: the art is left), or fade
    -- it through FadeRegions (no stockDefault: Ka0s Default would lose the settings window's Bg)
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    assertEqual(m.__paint(art).alpha, 0, OTHER .. " fades it under its own window fill")
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    assertEqual(m.__paint(art).alpha, 1, "a live switch back gives it back")
end)

test("skin windows: the modal catcher's dim is qc.modalDim, today's pixel, and follows a switch", function()
    local NS, m, Skin = boot()
    local Pop = openPopup(NS)
    local dim = Pop.catcher:GetRegions()
    -- red under: DIM = { 0, 0, 0, 0.45 } typed
    assertColor(m.__paint(dim).color, { 0, 0, 0, 0.45 }, "the dim on Ka0s Default")
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    assertColor(m.__paint(dim).color, Skin:ResolveSkin(OTHER)["cover.dim"], "the dim follows cover.dim")
end)

test("skin windows: a client without the template gets the owner's Shell, not the dialog edge", function()
    local NS, m = boot()
    m.missingTemplates.SettingsFrameTemplate = true
    local seen = spy(NS, { "Shell" })
    local Pop = openPopup(NS)
    assertFalse(Pop.chrome.template)
    local shell = callOn(seen.Shell, Pop.chrome.bg)
    -- red under: keep the UI-DialogBox-Border backdrop typed over a 0.05 fill (D2)
    assertTrue(shell ~= nil and shell.opts.noTopBar == true, "the fallback's fill and edge are the skin's")
    local backdrop = m.__paint(Pop.chrome.bg).backdrop
    assertFalse(backdrop ~= nil and tostring(backdrop.edgeFile):find("DialogBox", 1, true) ~= nil,
        "no Blizzard dialog edge")
end)

-- ── the callout popup (W12, W13) ─────────────────────────────────────────────────────────────────

test("skin windows: the popup's refused-field line is sem.badAlt, today's |cffff4040", function()
    local NS, m, Skin = boot()
    local P = dofile("tests/page_helpers.lua")(NS, m)
    local Pop = NS.addon.Settings.CalloutPopup
    local w = P.during(function() Pop.Open(NS.Library.CreateGroup({ name = "Mine" })) end)
    assertFalse((Pop.Save()))
    local function errorLine()
        for _, label in ipairs(P.all(w, "Label")) do
            if label.text and label.text:find("Name:", 1, true) then return label.text end
        end
    end
    assertEqual(errorLine():sub(1, 10), "|cffff4040", "Ka0s Default's pixel")
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    assertFalse((Pop.Save()))
    assertEqual(errorLine():sub(1, 10), NS.SkinEscape("sem.badAlt"), "the escape is the token's under " .. OTHER)
end)

test("skin windows: the popup's token tooltip writes its lines in the tooltip tokens", function()
    local NS, m = boot()
    local Pop = openPopup(NS)
    local lines = tipColors(m)
    Pop.tokenGlyph:__fire("OnEnter")
    local got = lines()
    assertColor(rgbOf(got[1]), now(NS, "gtip.value"), "the title")
    local double
    for _, l in ipairs(got) do if l.right then double = l; break end end
    assertTrue(double ~= nil, "a token line")
    -- red under: AddDoubleLine(..., 1, 0.82, 0, 1, 1, 1) typed
    assertColor(rgbOf(double), now(NS, "gtip.title"), "the token")
    assertColor(rgbOf(double.right), now(NS, "gtip.value"), "what it fills in")
end)

-- ── the icon browser (W14-W21, D3) ───────────────────────────────────────────────────────────────

local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

local function openBrowser(NS, icon, m)
    local B = NS.addon.Settings.IconBrowser
    if m then
        -- The Ace fakes build their frames for themselves, unrecorded: the search box's input frame,
        -- which the magnifier is drawn on, is handed to the recorder as it is made.
        local AceGUI = NS.addon.Settings.Helpers.AceGUI
        local create = AceGUI.Create
        AceGUI.Create = function(self, kind, ...)
            local w = create(self, kind, ...)
            if kind == "EditBox" then m.__paintFrame(w.editbox or w.frame) end
            return w
        end
    end
    assertTrue(B.Open({ icon = icon, owner = "test", onChoose = function() end }))
    return B, B.Widgets()
end

test("skin windows: the browser's selected cell is qc.selStrong, today's gold at 0.7, and follows", function()
    local NS, m, Skin = boot()
    local B = openBrowser(NS, SKULL)
    local sel = B.cells[1].selected
    -- red under: GOLD = { 1, 0.82, 0, 0.7 } typed
    assertColor(m.__paint(sel).color, { 1, 0.82, 0, 0.7 }, "Ka0s Default's selection wash")
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    assertColor(m.__paint(sel).color, Skin:ResolveSkin(OTHER)["list.sel"], "it follows list.sel")
end)

test("skin windows: the browser's scroller is the skin's ScrollBar over its own track", function()
    local NS = boot()
    local seen = spy(NS, { "ScrollBar" })
    local _, parts = openBrowser(NS)
    -- red under: keep the client's knob over a typed 0.35 black track (D3)
    local call = callOn(seen.ScrollBar, parts.slider)
    assertTrue(call ~= nil and call.opts.track == parts.track, "S.ScrollBar(slider, { track = track })")
end)

test("skin windows: the browser's hint box is the drawer box's tokens, and follows a switch", function()
    local NS, m, Skin = boot()
    local _, parts = openBrowser(NS)
    -- red under: HINT_FILL / HINT_EDGE typed
    assertColor(m.__paint(parts.hintFill).color, now(NS, "drawer.boxBg"), "the fill")
    assertColor(m.__paint(parts.hintFill).color, { 0.08, 0.07, 0.05, 0.9 }, "the fill is today's")
    for _, e in ipairs(parts.hintEdges) do
        assertColor(m.__paint(e).color, { 0.24, 0.2, 0.13, 1 }, "an edge is today's")
    end
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    local base = Skin:ResolveSkin(OTHER)
    assertColor(m.__paint(parts.hintFill).color, base["drawer.boxBg"], "the fill under " .. OTHER)
    assertColor(m.__paint(parts.hintEdges[1]).color, base["drawer.boxBorder"], "an edge under " .. OTHER)
end)

test("skin windows: the browser's search glyphs are log.tag and qc.markGray, today's pixels", function()
    local NS, m, Skin = boot()
    local _, parts = openBrowser(NS, nil, m)
    -- red under: MUTED_GOLD / MARK_GRAY typed
    assertColor(m.__paint(parts.magnifier).vertex, { 0xc9 / 255, 0xa6 / 255, 0x6b / 255, 1 }, "the magnifier")
    assertColor(m.__paint(parts.clearGlyph).vertex, { 0.54, 0.54, 0.54, 1 }, "the clear mark")
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    local base = Skin:ResolveSkin(OTHER)
    assertColor(m.__paint(parts.magnifier).vertex, base["log.tag"], "the magnifier under " .. OTHER)
    assertColor(m.__paint(parts.clearGlyph).vertex, base["icon.dim"], "the clear mark follows icon.dim")
end)

test("skin windows: the browser's texts take their roles, each today's color under Ka0s Default", function()
    local NS, m = boot()
    local _, parts = openBrowser(NS)
    -- red under: the font objects' own colors left (a skin switch would leave them stock)
    assertColor(m.__paint(parts.count).textColor, now(NS, "text.disabled"), "the count")
    assertColor(m.__paint(parts.count).textColor, { 0.5, 0.5, 0.5, 1 }, "the count is today's gray")
    assertColor(m.__paint(parts.name).textColor, { 1, 0.82, 0, 1 }, "the name is today's gold")
    assertColor(m.__paint(parts.status).textColor, { 1, 1, 1, 1 }, "the status is today's white")
    assertColor(m.__paint(parts.hintText).textColor, { 1, 1, 1, 1 }, "the hint is today's white")
end)

test("skin windows: the browser's texts keep their font objects' faces (X10), and a switch recolors them", function()
    -- A LibSharedMedia that answers every face, so S.Text WOULD set one.
    local NS, m, Skin = boot(function(mm)
        local lsm = mm.LibStub:NewLibrary("LibSharedMedia-3.0", 1)
        function lsm.Register() end
        function lsm.IsValid() return true end
        function lsm.HashTable() return {} end
        function lsm.Fetch(_, kind, name) return kind == "font" and ("Fonts\\" .. tostring(name)) or nil end
        lsm.MediaType = {}
    end)
    local _, parts = openBrowser(NS)
    local want = { count = "GameFontDisableSmall", name = "GameFontNormal", status = "GameFontHighlight",
        hintText = "GameFontHighlightSmall" }
    -- red under: NS.Skin.Text (S.Text sets the skin's body / title face as well as the color)
    local function faces(where)
        for key, obj in pairs(want) do
            assertEqual(m.__paint(parts[key]).font, nil, key .. " takes no face " .. where)
            assertEqual(m.__paint(parts[key]).fontObject, nil, key .. " takes no font object " .. where)
            assertEqual(m.__paint(parts[key]).template, obj, key .. " keeps " .. obj .. " " .. where)
        end
    end
    faces("under Ka0s Default")
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    faces("under " .. OTHER)
    local base = Skin:ResolveSkin(OTHER)
    assertColor(m.__paint(parts.count).textColor, base["text.disabled"], "the count under " .. OTHER)
    assertColor(m.__paint(parts.status).textColor, base["text.highlight"], "the status under " .. OTHER)
    assertColor(m.__paint(parts.hintText).textColor, base["text.highlight"], "the hint under " .. OTHER)
end)

test("skin windows: the browser's empty footer line is qc.note, today's |cffaaaaaa", function()
    local NS, m, Skin = boot()
    local _, parts = openBrowser(NS)
    local text = m.__paint(parts.name).text
    -- red under: GRAY = "|cffaaaaaa" typed
    assertEqual(text:sub(1, 10), "|cffaaaaaa")
    Skin:SetChoice(OWNER, "ka0s", OTHER)
    assertEqual(m.__paint(parts.name).text:sub(1, 10), NS.SkinEscape("qc.note"),
        "a skin switch redraws the footer in the token's escape")
end)

test("skin windows: the browser's cell tooltip writes its lines in the tooltip tokens", function()
    local NS, m = boot()
    local B = openBrowser(NS)
    -- The Markers tab is open: a marker has no credit line, so the last line is the click hint.
    local lines = tipColors(m)
    local cell
    for _, c in ipairs(B.cells) do if c:IsShown() then cell = c; break end end
    cell:__fire("OnEnter")
    local got = lines()
    -- red under: AddLine(..., 1, 1, 1, true) typed
    assertColor(rgbOf(got[#got]), now(NS, "gtip.value"), "what a click does")
end)
