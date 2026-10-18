-- tests/test_callout_popup.lua — settings/CalloutPopup.lua (callouts-owned-by-groups spec, "The
-- callout popup"): the Save/Cancel draft editor a user group's Callouts tab opens, and what
-- settings/Callouts.lua keeps for it (the token list and its help, the preview lines). Driven headlessly through
-- tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

local function open(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or {} end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    m.SettingsPanel:Show()   -- the popup is opened from a page, so the settings window is up
    return NS, m, P, NS.addon.Settings.CalloutPopup
end

-- A user group holding one callout, "Kick".
local function withKick(NS)
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local cid = NS.Library.CreateCalloutIn(gid, { name = "Kick", text = "Kick", channel = "party" })
    return gid, cid
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- Count the LIBRARY_CHANGED messages sent from here on; the message still goes out.
local function libraryChanges(NS)
    local seen = { n = 0 }
    local send = NS.addon.SendMessage
    NS.addon.SendMessage = function(self, name, ...)
        if name == NS.MSG.LIBRARY_CHANGED then seen.n = seen.n + 1 end
        return send(self, name, ...)
    end
    return seen
end

-- Record every seam write from here on, as { path, id }; the write still lands.
local function seamWrites(NS)
    local writes = {}
    local S = NS.SchemaRuntime
    local set = S.Set
    S.Set = function(path, value, id, ...)
        writes[#writes + 1] = { path, id }
        return set(path, value, id, ...)
    end
    return writes
end

local function labelWith(P, w, needle)
    for _, label in ipairs(P.all(w, "Label")) do
        if label.text and label.text:find(needle, 1, true) then return label end
    end
    return nil
end

test("popup: Add opens blank with Smart group", function()
    local NS, _, P, Pop = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local w = P.during(function() assertTrue(Pop.Open(gid)) end)
    assertTrue(Pop.IsOpen())
    local d = Pop.Draft()
    assertEqual(d.name, "")
    assertEqual(d.text, "")
    assertEqual(d.channel, "smartGroup")
    assertNil(d.icon)
    assertEqual(P.find(w, "EditBox", "Name").text, "")
    assertEqual(P.find(w, "Dropdown", "Channel").value, "smartGroup")
    assertTrue(P.find(w, "Button", "Save") ~= nil and P.find(w, "Button", "Cancel") ~= nil)
    assertNil(P.find(w, "Button", "Duplicate"), "copying is Reuse's job")
    assertNil(P.find(w, "Button", "Delete"), "removing is the list's job")
    -- red under: show the popup without its click-catcher (the settings page underneath stays live)
    assertTrue(Pop.catcher:IsShown(), "modal: the catcher covers the settings window")
    assertTrue(Pop.frame:IsShown())
    assertFalse(Pop.Open("g999"), "no such user group")
    assertFalse(Pop.Open(NS.BuiltIns.order[1]), "a built-in set is read-only")
end)

test("popup: edit opens filled in", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    NS.SchemaRuntime.Set("callout.icon", SKULL, cid)
    local w = P.during(function() Pop.Open(gid, cid) end)
    local d = Pop.Draft()
    assertEqual(d.name, "Kick")
    assertEqual(d.text, "Kick")
    assertEqual(d.channel, "party")
    assertEqual(d.icon, SKULL)
    assertEqual(P.find(w, "EditBox", "Name").text, "Kick")
    assertEqual(P.find(w, "Dropdown", "Channel").value, "party")
    -- the draft is a copy: it never aliases the stored callout
    d.text = "changed"
    assertEqual(NS.db.profile.callouts[cid].text, "Kick")
    -- a second Open replaces the first, and a callout that does not exist opens nothing
    Pop.Open(gid)
    assertEqual(Pop.Draft().name, "")
    assertFalse(Pop.Open(gid, "c999"))
    assertFalse(Pop.IsOpen())
end)

test("popup: typing changes the draft only, and the preview follows", function()
    local NS, _, P, Pop = open(MPLUS)
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local before = count(NS.db.profile.callouts)
    local w = P.during(function() Pop.Open(gid) end)
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Pull")
    P.find(w, "EditBox", "Text"):__fire("OnEnterPressed", "Pulling {rt8}")
    P.find(w, "Dropdown", "Channel"):__fire("OnValueChanged", "party")
    local d = Pop.Draft()
    assertEqual(d.name, "Pull")
    assertEqual(d.text, "Pulling {rt8}")
    assertEqual(d.channel, "party")
    assertEqual(count(NS.db.profile.callouts), before, "nothing is saved yet")
    -- red under: draw the preview once without refreshing it on each draft write
    assertTrue(labelWith(P, w, "Sends: /p Pulling {rt8}") ~= nil, "the preview bakes the draft")
    assertTrue(labelWith(P, w, "of 255 bytes") ~= nil)
    P.find(w, "EditBox", "Text"):__fire("OnEnterPressed", "/run x")
    assertTrue(labelWith(P, w, "Sends nothing here: Callout text cannot start with /.") ~= nil)
end)

test("popup: Save on Add creates the callout at the end of the group, one LIBRARY_CHANGED", function()
    local NS, _, P, Pop = open()
    local gid, first = withKick(NS)
    local w = P.during(function() Pop.Open(gid) end)
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Lust")
    P.find(w, "EditBox", "Text"):__fire("OnEnterPressed", "Lust now")
    local seen = libraryChanges(NS)
    P.find(w, "Button", "Save"):__fire("OnClick")
    -- red under: write the create and the insert apart (two acts, two rebuilds)
    assertEqual(seen.n, 1)
    local list = NS.db.profile.groups[gid].callouts
    assertEqual(#list, 2)
    assertEqual(list[1], first)
    local c = NS.db.profile.callouts[list[2]]
    assertEqual(c.name, "Lust")
    assertEqual(c.text, "Lust now")
    assertEqual(c.channel, "smartGroup")
    assertFalse(Pop.IsOpen(), "Save closes the popup")
    assertFalse(Pop.catcher:IsShown())
end)

test("popup: Cancel on Add creates nothing and consumes no id", function()
    local NS, _, P, Pop = open()
    local gid, first = withKick(NS)
    local p = NS.db.profile
    local nextId, before = p.nextId, count(p.callouts)
    local w = P.during(function() Pop.Open(gid) end)
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Lust")
    P.find(w, "Button", "Cancel"):__fire("OnClick")
    -- red under: create the callout on Open and delete it on Cancel (an id is spent)
    assertEqual(p.nextId, nextId)
    assertEqual(count(p.callouts), before)
    assertEqual(table.concat(p.groups[gid].callouts, ","), first)
    assertFalse(Pop.IsOpen())
    assertFalse(Pop.Save(), "nothing is open to save")
    assertEqual(count(p.callouts), before)
end)

test("popup: Save on edit writes only the changed fields through the seam", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    local w = P.during(function() Pop.Open(gid, cid) end)
    P.find(w, "EditBox", "Text"):__fire("OnEnterPressed", "Kick {target}")
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Kick")   -- typed back to what it was
    local writes = seamWrites(NS)
    local seen = libraryChanges(NS)
    assertTrue(Pop.Save())
    -- red under: write every field on Save, or write around the seam
    assertEqual(#writes, 1)
    assertEqual(writes[1][1], "callout.text")
    assertEqual(writes[1][2], cid)
    assertEqual(seen.n, 1, "one act")
    assertEqual(NS.db.profile.callouts[cid].text, "Kick {target}")
    assertEqual(NS.db.profile.callouts[cid].name, "Kick")
    assertFalse(Pop.IsOpen())
end)

test("popup: Cancel on edit writes nothing", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    local w = P.during(function() Pop.Open(gid, cid) end)
    local writes = seamWrites(NS)
    P.find(w, "EditBox", "Text"):__fire("OnEnterPressed", "Kick {target}")
    P.find(w, "Dropdown", "Channel"):__fire("OnValueChanged", "say")
    Pop.Cancel()
    -- red under: write each field through the seam as it is typed
    assertEqual(#writes, 0)
    assertEqual(NS.db.profile.callouts[cid].text, "Kick")
    assertEqual(NS.db.profile.callouts[cid].channel, "party")
    assertFalse(Pop.IsOpen())
end)

test("popup: Save with an empty name stays open and writes nothing", function()
    local NS, _, P, Pop = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local p = NS.db.profile
    local nextId, before = p.nextId, count(p.callouts)
    local w = P.during(function() Pop.Open(gid) end)
    P.find(w, "EditBox", "Text"):__fire("OnEnterPressed", "Lust now")
    local ok, why = Pop.Save()
    assertFalse(ok)
    assertEqual(why, "name")
    assertTrue(Pop.IsOpen(), "the popup stays open")
    assertEqual(count(p.callouts), before)
    assertEqual(p.nextId, nextId)
    -- red under: refuse silently (the popup must name the field and why)
    assertTrue(labelWith(P, w, "Name: A name is 1 to 32 characters.") ~= nil)
    -- more than 32 characters is refused the same way, and a good name then saves
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", string.rep("x", 33))
    assertFalse((Pop.Save()))
    assertTrue(Pop.IsOpen())
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Lust")
    assertTrue(Pop.Save())
    assertEqual(count(p.callouts), before + 1)
end)

-- A box's SetText with no OnEnterPressed is a player who typed and did not press Enter.
test("popup: Save takes the text typed into a box without Enter", function()
    local NS, _, P, Pop = open()
    local gid, first = withKick(NS)
    local w = P.during(function() Pop.Open(gid) end)
    P.find(w, "EditBox", "Name"):SetText("Lust")
    P.find(w, "EditBox", "Text"):SetText("Lust now")
    P.find(w, "Button", "Save"):__fire("OnClick")
    -- red under: Save reads the draft alone (a name the box shows is refused as empty)
    assertFalse(Pop.IsOpen(), "Save is the commit gesture")
    local list = NS.db.profile.groups[gid].callouts
    assertEqual(#list, 2)
    assertEqual(list[1], first)
    assertEqual(NS.db.profile.callouts[list[2]].name, "Lust")
    assertEqual(NS.db.profile.callouts[list[2]].text, "Lust now")
    -- an edit: a typed name is saved, and a cleared one is refused, naming Name
    local cid = list[1]
    w = P.during(function() Pop.Open(gid, cid) end)
    P.find(w, "EditBox", "Name"):SetText("Interrupt")
    assertTrue(Pop.Save())
    assertEqual(NS.db.profile.callouts[cid].name, "Interrupt")
    w = P.during(function() Pop.Open(gid, cid) end)
    P.find(w, "EditBox", "Name"):SetText("")
    local ok, why = Pop.Save()
    assertFalse(ok)
    assertEqual(why, "name")
    assertTrue(Pop.IsOpen())
    assertEqual(NS.db.profile.callouts[cid].name, "Interrupt")
end)

test("popup: a pick or a seam write keeps the text typed without Enter", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    local w = P.during(function() Pop.Open(gid, cid) end)
    local name, text = P.find(w, "EditBox", "Name"), P.find(w, "EditBox", "Text")
    name:SetText("Interrupt")
    text:SetText("Kick {focus}")
    P.find(w, "Dropdown", "Channel"):__fire("OnValueChanged", "smartGroup")
    -- red under: every draft write runs every box's refresher over the typed text
    assertEqual(name:GetText(), "Interrupt")
    assertEqual(Pop.Draft().name, "Interrupt")
    assertEqual(Pop.Draft().text, "Kick {focus}", "the pick took the typed text in")
    assertEqual(text:GetText(), "Kick {focus}")
    -- a seam write elsewhere refreshes every rendered panel, the popup's among them
    name:SetText("Stop")
    NS.addon:OnSlashCommand("set callout.text " .. cid .. " Slashed")
    assertEqual(name:GetText(), "Stop")
    assertTrue(Pop.Save())
    local c = NS.db.profile.callouts[cid]
    assertEqual(c.name, "Stop")
    assertEqual(c.text, "Kick {focus}")
    assertEqual(c.channel, "smartGroup")
end)

test("popup: the callout deleted under an open popup closes it; a late Save writes nothing", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    local w = P.during(function() Pop.Open(gid, cid) end)
    P.find(w, "EditBox", "Text"):__fire("OnEnterPressed", "Kick {target}")
    NS.addon:OnSlashCommand("set callout.text " .. cid .. " Slashed")   -- a write to it is not a delete
    assertTrue(Pop.IsOpen())
    NS.Library.RemoveFromGroup(gid, 1)   -- as the list's remove, or an import, would
    -- red under: drop the LIBRARY_CHANGED check in settings/CalloutPopup.lua
    assertFalse(Pop.IsOpen())
    local before = count(NS.db.profile.callouts)
    assertFalse(Pop.Save())
    assertEqual(count(NS.db.profile.callouts), before)
    -- a callout gone without a message (a hand-edited table) is caught by Save itself
    gid, cid = withKick(NS)
    Pop.Open(gid, cid)
    Pop.Draft().text = "late"
    NS.db.profile.callouts[cid] = nil
    local ok, why = Pop.Save()
    assertFalse(ok)
    assertEqual(why, "noCallout")
    assertNil(NS.db.profile.callouts[cid], "nothing is written back")
    assertFalse(Pop.IsOpen())
end)

test("popup: closing the settings window cancels", function()
    local NS, m, P, Pop = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local before = count(NS.db.profile.callouts)
    local w = P.during(function() Pop.Open(gid) end)
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Lust")
    m.SettingsPanel:Hide()
    m.SettingsPanel:__fire("OnHide")
    -- red under: drop the SettingsPanel OnHide hook
    assertFalse(Pop.IsOpen())
    assertFalse(Pop.frame:IsShown())
    assertEqual(count(NS.db.profile.callouts), before)
end)

test("popup: Escape and a profile change cancel", function()
    local NS, m, P, Pop = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    P.during(function() Pop.Open(gid) end)
    local listed = false
    for _, name in ipairs(m.UISpecialFrames) do
        if name == Pop.frame.__name then listed = true end
    end
    -- red under: leave the popup out of UISpecialFrames (Escape would close the settings window)
    assertTrue(listed, "Escape closes the popup first")
    Pop.frame:Hide()
    Pop.frame:__fire("OnHide")   -- what Escape does to a special frame
    assertFalse(Pop.IsOpen())
    assertFalse(Pop.catcher:IsShown())
    Pop.Open(gid)
    NS.addon:SendMessage(NS.MSG.PROFILE_CHANGED)
    assertFalse(Pop.IsOpen(), "the draft named the old profile's ids")
end)

-- The token tooltip's lines as shown: hover the glyph, read the mock GameTooltip's record.
local function hoverGlyph(m, glyph)
    glyph:__fire("OnEnter")
    local out = {}
    for i, line in ipairs(m.GameTooltip.__lines) do out[i] = line end
    return out
end

local function tooltipHas(lines, left)
    for _, line in ipairs(lines) do
        if line[1] == left then return line end
    end
    return nil
end

test("popup: there is no token dropdown; an info glyph sits right of the Text label", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    local w = P.during(function() Pop.Open(gid, cid) end)
    -- red under: keep the Insert a token dropdown
    assertNil(P.find(w, "Dropdown", "Insert a token"))
    local text = P.find(w, "EditBox", "Text")
    local glyph = Pop.tokenGlyph
    assertTrue(glyph ~= nil, "the glyph is drawn")
    assertTrue(glyph.__parent == text.frame, "on the Text box's own frame")
    assertTrue(text.frame.qcTokenGlyph == glyph, "kept on that frame for reuse")
    assertTrue(glyph:IsShown())
    assertEqual(glyph.icon.__texture, NS.Icon("info"), "the catalog's info mark")
    -- vertically centered on the label, GLYPH_GAP past its last letter ("Text": 4 letters at 6)
    local point, rel, relPoint, x, y = glyph:GetPoint(1)
    assertEqual(point, "LEFT")
    assertTrue(rel == text.label, "anchored to the label")
    assertEqual(relPoint, "LEFT")
    assertEqual(x, 4 * 6 + 4)
    assertEqual(y, 0)
    assertEqual(glyph.__w, 14, "sized to the label's 10-point face, within 14 to 16")
    assertEqual(glyph.__h, 14)
    -- a render again re-anchors the same glyph, once
    w = P.during(function() Pop.Open(gid, cid) end)
    local again = P.find(w, "EditBox", "Text")
    assertTrue(Pop.tokenGlyph.__parent == again.frame)
    assertEqual(#Pop.tokenGlyph.__points, 1, "one anchor, set afresh")
    -- released with its box: hidden, so a frame reused by another EditBox does not show it
    local shown = Pop.tokenGlyph
    again:__fire("OnRelease")
    -- red under: drop the box's OnRelease callback in settings/CalloutPopup.lua
    assertFalse(shown:IsShown())
end)

test("popup: the info glyph's tooltip lists the tokens, {group1} to {group8} only for a raid channel", function()
    local NS, m, P, Pop = open()
    local gid, cid = withKick(NS)   -- Kick is a party callout
    local w = P.during(function() Pop.Open(gid, cid) end)
    local lines = hoverGlyph(m, Pop.tokenGlyph)
    assertTrue(m.GameTooltip.__owner == Pop.tokenGlyph)
    assertEqual(lines[1][1], "Tokens")
    for _, token in ipairs({ "{target}", "{focus}", "{skull}", "{star}", "{me}", "{spec}", "{role}", "{key}",
        "{dungeon}", "{spell:ID}" }) do
        local line = tooltipHas(lines, token)
        assertTrue(line ~= nil and type(line[2]) == "string" and line[2] ~= "", token .. " is explained")
    end
    assertEqual(tooltipHas(lines, "{skull}")[2], "The Skull raid marker.")
    -- red under: drop the RAID_CAPABLE branch from C.TokensFor
    assertNil(tooltipHas(lines, "{group1} … {group8}"), "a party channel cannot resolve to Raid")
    -- the channel picked since the render is the one the tooltip reads
    P.find(w, "Dropdown", "Channel"):__fire("OnValueChanged", "raid")
    lines = hoverGlyph(m, Pop.tokenGlyph)
    assertTrue(tooltipHas(lines, "{group1} … {group8}") ~= nil, "the eight raid groups on one line")
    assertNil(tooltipHas(lines, "{group1}"), "never one line per group")
    assertNil(tooltipHas(lines, "{group8}"))
    Pop.tokenGlyph:__fire("OnLeave")
    assertFalse(m.GameTooltip:IsShown())
    assertEqual(NS.db.profile.callouts[cid].channel, "party", "hovering writes nothing")
end)

test("popup: the preview is headed Preview, a gap above Cancel then Save", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    local w = P.during(function() Pop.Open(gid, cid) end)
    -- red under: keep the What it sends here heading
    assertTrue(P.find(w, "Heading", "Preview") ~= nil)
    assertNil(P.find(w, "Heading", "What it sends here"))
    local order = {}
    for i, b in ipairs(P.all(w, "Button")) do order[b.text] = i end
    -- red under: hand InlineButtonPair Save first
    assertTrue(order.Cancel ~= nil and order.Save ~= nil and order.Cancel < order.Save, "Cancel left, Save right")
    -- the body: ... the preview line, a section's gap, then the pair's row
    local body = P.find(w, "SimpleGroup")
    local kids = body.children
    local pairAt
    for i, kid in ipairs(kids) do
        for _, b in ipairs(kid.children or {}) do
            if b.type == "Button" and b.text == "Cancel" then pairAt = i end
        end
    end
    assertTrue(pairAt ~= nil and pairAt > 2)
    local gap = kids[pairAt - 1]
    assertEqual(gap.type, "SimpleGroup")
    assertEqual(gap.height, 16, "the gap between the preview and the buttons")
    assertEqual(kids[pairAt - 2].type, "Label", "under the preview line")
    P.find(w, "Button", "Cancel"):__fire("OnClick")
    assertFalse(Pop.IsOpen(), "Cancel still cancels")
end)

test("callout helpers: TokenHelp folds {group1}-{group8} into one line and names {spell:ID}", function()
    local NS = open()
    local C = NS.addon.Settings.Callouts
    local party, raid = C.TokenHelp("party"), C.TokenHelp("smartGroup")
    assertEqual(#party, #C.TOKENS + 1, "each offered token, then {spell:ID}")
    assertEqual(party[#party][1], "{spell:ID}")
    assertEqual(#raid, #C.TOKENS + 2, "the eight groups are one line")
    assertEqual(raid[#C.TOKENS + 1][1], "{group1} … {group8}")
    for _, line in ipairs(raid) do assertTrue(line[2] ~= "", line[1] .. " has its help") end
end)

test("popup: [icons] Choose icon… opens the browser; its Choose writes the draft's icon, not the callout", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    local B = NS.addon.Settings.IconBrowser
    local w = P.during(function() Pop.Open(gid, cid) end)
    -- red under: keep the inline grid (Ed.IconPicker) in the popup
    assertNil(P.find(w, "Heading", "Choose an icon"), "no inline grid")
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    assertTrue(B.IsOpen())
    assertEqual(B.State().owner, "popup")
    assertEqual(B.State().tab, "suggested", "no icon yet: Suggested")
    B.Select(SKULL)
    assertTrue(B.Choose())
    assertFalse(B.IsOpen())
    assertTrue(Pop.IsOpen(), "the popup stays open")
    -- red under: hand the browser a seam write (it would write the stored callout at once)
    assertEqual(Pop.Draft().icon, SKULL)
    assertNil(NS.db.profile.callouts[cid].icon, "the stored icon waits for Save")
    assertEqual(P.find(w, "EditBox", "Icon").text, SKULL, "the Icon box shows the pick")
    assertEqual(P.find(w, "Icon").image[1], SKULL, "the chooser's icon shows the pick")
    assertTrue(Pop.Save())
    assertEqual(NS.db.profile.callouts[cid].icon, SKULL)
end)

test("popup: [icons] a glyph chosen with a color: the draft carries both; the swatch writes the draft's color", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    local B = NS.addon.Settings.IconBrowser
    local w = P.during(function() Pop.Open(gid, cid) end)
    local swatch = P.find(w, "ColorPicker", "Icon color")
    assertTrue(swatch.disabled, "no glyph: the swatch is idle")
    P.find(w, "Button", "Choose icon…"):__fire("OnClick")
    B.SetTab("glyphs")
    B.Select(NS.Icon("star"))
    B.SetColor("ff8000")
    B.Choose()
    assertEqual(Pop.Draft().icon, NS.Icon("star"))
    assertEqual(Pop.Draft().iconColor, "ff8000")
    assertFalse(swatch.disabled)
    swatch:__fire("OnValueConfirmed", 0, 1, 0, 1)
    -- red under: write the swatch's pick through the seam in the popup's chooser spec
    assertEqual(Pop.Draft().iconColor, "00ff00")
    assertTrue(not NS.db.profile.callouts[cid].iconColor, "the stored color waits for Save")
    assertEqual(table.concat(P.find(w, "Icon").image.vertexColor, ","), "0,1,0", "the chooser's icon in the draft's color")
    assertTrue(Pop.Save())
    assertEqual(NS.db.profile.callouts[cid].iconColor, "00ff00")
    -- a game icon chosen over the glyph drops the color from the draft
    Pop.Open(gid, cid)
    Pop.SetIcon(136243, "ff0000")
    assertNil(Pop.Draft().iconColor, "no color on a game icon")
end)

test("popup: [icons] the swatch writes the draft on a drag tick (OnValueChanged) with no confirm, as OK leaves it", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    local w = P.during(function() Pop.Open(gid, cid) end)
    Pop.SetIcon(NS.Icon("star"), "ff8000")
    local swatch = P.find(w, "ColorPicker", "Icon color")
    swatch:__fire("OnValueChanged", 0, 1, 0, 1)
    -- red under: listen for OnValueConfirmed alone in Ed.IconChooser
    assertEqual(Pop.Draft().iconColor, "00ff00")
    swatch:__fire("OnValueConfirmed", 1, 128 / 255, 0, 1)   -- Cancel confirms the old color
    assertEqual(Pop.Draft().iconColor, "ff8000", "Cancel puts the old color back")
end)

-- Record every CreateFrame template from here on (nil for none); the frame is still made.
local function templates(m)
    local seen = {}
    local create = m.CreateFrame
    m.CreateFrame = function(frameType, name, parent, template, ...)
        seen[#seen + 1] = template or false
        return create(frameType, name, parent, template, ...)
    end
    return seen
end

-- Record the frame level each frame created from here on is set to (0 until set). A frame that
-- answers its own level (the template's Bg, in tests/wow_mock.lua) keeps its answer.
local function levels(m)
    local create = m.CreateFrame
    m.CreateFrame = function(...)
        local f = create(...)
        if rawget(f, "GetFrameLevel") == nil then
            rawset(f, "SetFrameLevel", function(self, v) rawset(self, "__level", v); return self end)
            rawset(f, "GetFrameLevel", function(self) return rawget(self, "__level") or 0 end)
        end
        return f
    end
end

local function listed(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

-- Count the NS.MakeCloseButton calls from here on, as { parent, onClick }.
local function closeMarks(NS)
    local made = {}
    local make = NS.MakeCloseButton
    NS.MakeCloseButton = function(parent, onClick)
        made[#made + 1] = { parent = parent, onClick = onClick }
        return make(parent, onClick)
    end
    return made
end

test("popup: the window is Blizzard's settings-window template, and its own close X cancels", function()
    local NS, m, _, Pop = open()
    local made, seen = closeMarks(NS), templates(m)
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    Pop.Open(gid)
    -- red under: build the window as a plain frame with the dialog backdrop
    assertEqual(Pop.frame.__template, "SettingsFrameTemplate")
    assertEqual(Pop.frame.NineSlice.Text.text, "Ka0s Quick Comms", "the window title is the addon's")
    assertFalse(listed(seen, "BackdropTemplate"), "no UI-DialogBox-Border backdrop over the template")
    assertEqual(#made, 0, "the template brings its own close (a documented deviation)")
    assertEqual(Pop.frame.__parent, Pop.catcher, "above the click-catcher")
    Pop.frame.ClosePanelButton:__fire("OnClick")
    assertFalse(Pop.IsOpen(), "the close X cancels")
    assertFalse(Pop.catcher:IsShown())
    Pop.Open(gid)
    assertTrue(Pop.frame:IsShown(), "a closed window opens again")
    assertEqual(#made, 0, "one popup, built once")
end)

test("popup: the template's background sits over the catcher's dim and under the border", function()
    local NS, m, _, Pop = open()
    levels(m)
    Pop.Open(NS.Library.CreateGroup({ name = "Mine" }))
    local dim, bg, window = Pop.catcher:GetFrameLevel(), Pop.frame.Bg:GetFrameLevel(), Pop.frame:GetFrameLevel()
    -- red under: drop the Bg re-level in build() (the template's absolute level 0 sits under the dim,
    -- so the popup's background is darker than the settings window's)
    assertTrue(bg > dim, ("Bg %d over the catcher %d"):format(bg, dim))
    assertTrue(bg < window, ("Bg %d under the window's border %d"):format(bg, window))
    -- red under: drop the close X's re-level in build() (the page, whose top edge it overlaps, would
    -- draw over it)
    local page, close = m.__named.QuickCommsCalloutPopupPage:GetFrameLevel(), Pop.frame.ClosePanelButton:GetFrameLevel()
    assertTrue(close > page, ("close X %d over the page %d"):format(close, page))
end)

test("popup: a settings-window template without its close X falls back to the dialog look", function()
    local NS, m, _, Pop = open()
    local create = m.CreateFrame
    m.CreateFrame = function(frameType, name, parent, template)
        local f = create(frameType, name, parent, template)
        if template == "SettingsFrameTemplate" then f.ClosePanelButton = nil end
        return f
    end
    local made, seen = closeMarks(NS), templates(m)
    -- red under: drop the ClosePanelButton check in makeWindow (build() calls SetScript on nil)
    assertTrue(Pop.Open(NS.Library.CreateGroup({ name = "Mine" })))
    assertFalse(Pop.chrome.template, "the template's parts are not all there")
    assertTrue(listed(seen, "BackdropTemplate"), "the fallback's dialog edge")
    assertEqual(#made, 1, "the fallback's close mark")
    made[1].onClick()
    assertFalse(Pop.IsOpen(), "the close mark cancels")
end)

test("popup: a client whose C_XMLUtil says it lacks the template is not asked for it", function()
    local NS, m, _, Pop = open()
    m.C_XMLUtil = { GetTemplateInfo = function() return nil end }
    local made, seen = closeMarks(NS), templates(m)
    assertTrue(Pop.Open(NS.Library.CreateGroup({ name = "Mine" })))
    -- red under: ignore Compat.HasTemplate's false and create the window from the template anyway
    assertFalse(listed(seen, "SettingsFrameTemplate"), "the template is not tried")
    assertTrue(listed(seen, "BackdropTemplate"), "the fallback's dialog edge")
    assertEqual(#made, 1, "the fallback's close mark")
end)

test("popup: a client whose C_XMLUtil knows the template gets it", function()
    local NS, m, _, Pop = open()
    m.C_XMLUtil = { GetTemplateInfo = function(name)
        if name == "SettingsFrameTemplate" then return { type = "Frame" } end
    end }
    Pop.Open(NS.Library.CreateGroup({ name = "Mine" }))
    -- red under: read GetTemplateInfo's answer the wrong way round in Compat.HasTemplate
    assertEqual(Pop.frame.__template, "SettingsFrameTemplate")
end)

test("popup: without the template it keeps the dialog look and the shared close mark", function()
    local NS, m, _, Pop = open()
    m.missingTemplates.SettingsFrameTemplate = true
    local made, seen = closeMarks(NS), templates(m)
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    -- red under: create the window from the template unguarded (Open raises)
    assertTrue(Pop.Open(gid))
    assertTrue(listed(seen, "BackdropTemplate"), "the dialog edge over a dark fill")
    assertEqual(#made, 1)
    made[1].onClick()
    assertFalse(Pop.IsOpen(), "the close mark cancels")
    Pop.Open(gid)
    Pop.frame:Hide()
    Pop.frame:__fire("OnHide")   -- what Escape does to a special frame
    assertFalse(Pop.IsOpen(), "Escape still cancels")
end)

test("popup: no scrollbar; the window's height follows the laid-out body", function()
    local NS, m, P, Pop = open()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local w = P.during(function() Pop.Open(gid) end)
    -- red under: draw the body into the library's ScrollFrame (EnsureScroll)
    assertNil(P.find(w, "ScrollFrame"), "no scroll frame, no scrollbar")
    -- the plain container, built before any row (the first SimpleGroup the Open draws)
    local body = P.find(w, "SimpleGroup")
    assertTrue(body ~= nil, "the body is a plain AceGUI container")
    assertTrue(P.find(w, "EditBox", "Name") ~= nil, "the rows are drawn into the plain container")
    local heights = {}
    rawset(Pop.frame, "SetHeight", function(_, v) heights[#heights + 1] = v end)
    body.frame:__setGeom(520, 300)
    local laid = body.layoutCount or 0
    P.find(w, "EditBox", "Text"):__fire("OnEnterPressed", "Pull")
    assertTrue((body.layoutCount or 0) > laid, "laid out again before it is measured")
    local first = heights[#heights]
    -- The window: the template's title bar (24) and bottom inset (5), where the library's
    -- CreatePanel starts the page's body (read off the panel it built: its header plus its own
    -- offset), the chrome gap, the body and its 12 under it. The popup restates the body's start as
    -- BODY_TOP and the pages' inset as CONTENT_X (settings/CalloutPopup.lua): red under a re-vendor
    -- that moves the header, the body's offset under it, or the inset.
    local LAYOUT = m.LibStub("LibKa0s-Options-1.0").LAYOUT
    local panel = m.__named.QuickCommsCalloutPopupPage
    local point, rel, relPoint, _, y = panel.body:GetPoint(1)
    assertEqual(point, "TOPLEFT")
    assertEqual(rel, panel)
    assertEqual(relPoint, "TOPLEFT")
    assertEqual(first, 24 + (-y) + LAYOUT.CHROME_GAP + 300 + 12 + 5,
        "the body plus the chrome around it")
    assertEqual(LAYOUT.CONTENT_LEFT, 12, "the pages' left inset, restated as CONTENT_X")
    -- the error line grows the body: the window follows it
    body.frame:__setGeom(520, 340)
    assertFalse((Pop.Save()))
    assertEqual(heights[#heights] - first, 40)
    -- a situation change re-bakes the preview lines (joining a group changes the channel): the
    -- window is measured again
    -- red under: drop the fit() at the end of refreshLive in settings/CalloutPopup.lua
    body.frame:__setGeom(520, 370)
    local before = #heights
    NS.addon:SendMessage(NS.MSG.SITUATION_CHANGED)
    assertTrue(#heights > before, "a situation change measures the window again")
    assertEqual(heights[#heights] - first, 70)
    body.frame:__setGeom(520, 390)
    NS.addon:SendMessage(NS.MSG.TEST_MODE_CHANGED)
    assertEqual(heights[#heights] - first, 90, "so does test mode turning on or off")
end)

test("settings: there is no Callouts page", function()
    local NS, m = T.enableAddon()
    -- red under: keep settings/Callouts.lua's Ed.RegisterPage
    assertNil(m.__subcategories.Callouts)
    assertNil(NS.addon.Settings.Editors.pages.callouts)
    assertNil(NS.addon.Settings.Editors.redraw.callouts)
end)

test("callout helpers: [phase 3] the token picker offers {group1}-{group8} only when the channel can resolve to Raid", function()
    local NS = open()
    local C = NS.addon.Settings.Callouts
    local function has(channel, token)
        for _, t in ipairs(C.TokensFor(channel)) do
            if t == token then return true end
        end
        return false
    end
    -- red under: drop the RAID_CAPABLE branch from C.TokensFor (spec §8.1)
    assertFalse(has("party", "{group1}"))
    assertFalse(has("say", "{group8}"))
    assertTrue(has("raid", "{group1}"))
    assertTrue(has("raidWarning", "{group8}"))
    assertTrue(has("smartGroup", "{group4}"))
    assertTrue(has("smartLead", "{group4}"))
    assertTrue(has("party", "{skull}"), "the markers are offered everywhere")
end)

test("callout helpers: PreviewLines says what a callout sends here, or why it sends nothing", function()
    local NS = open(MPLUS)
    local C = NS.addon.Settings.Callouts
    local function lines(text, channel) return table.concat(C.PreviewLines({ text = text, channel = channel }), "\n") end
    assertTrue(lines("Pulling {rt8}", "party"):find("Sends: /p Pulling {rt8}", 1, true) ~= nil)
    assertTrue(lines("Pulling {rt8}", "party"):find("of 255 bytes", 1, true) ~= nil)
    -- [review 5] text that starts with / says at once that it sends nothing
    assertTrue(lines("/run x", "party"):find("Sends nothing here: Callout text cannot start with /.", 1, true) ~= nil)
    -- under a previewed raid, a raid callout is fine; in the open world it is padlocked
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    assertTrue(lines("Stack", "raid"):find("Locked: you are not in a raid.", 1, true) ~= nil)
    NS.Preview.SetPreviewAs("raid:heroic")
    assertFalse(lines("Stack", "raid"):find("Locked: you are not in a raid.", 1, true) ~= nil)
    assertTrue(lines("Stack", "raid"):find("Previewing: Raid", 1, true) ~= nil)
end)

-- ── a glyph's color (icon browser spec, "Data model") ───────────────────────────────────────

test("popup: [icons] the draft carries the icon's color; Save writes icon and color in one act", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    local star = NS.Icon("star")
    NS.Library.SetIcon("callout", cid, star, "ff0000")
    P.during(function() Pop.Open(gid, cid) end)
    -- red under: copyFields reading FIELDS (the rows drawn), not DRAFT
    assertEqual(Pop.Draft().iconColor, "ff0000")
    Pop.Draft().icon, Pop.Draft().iconColor = NS.Icon("heart"), "00ff00"
    local writes = seamWrites(NS)
    local seen = libraryChanges(NS)
    assertTrue(Pop.Save())
    assertEqual(#writes, 2)
    assertEqual(writes[1][1] .. "," .. writes[2][1], "callout.icon,callout.iconColor", "the icon lands first")
    assertEqual(seen.n, 1, "one act")
    assertEqual(NS.db.profile.callouts[cid].iconColor, "00ff00")
end)

test("popup: [icons] an icon typed in that is no glyph drops the draft's color, and Save clears it", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    NS.Library.SetIcon("callout", cid, NS.Icon("star"), "ff0000")
    local w = P.during(function() Pop.Open(gid, cid) end)
    P.find(w, "EditBox", "Icon"):__fire("OnEnterPressed", "136012")
    -- red under: drop the glyph check from put in settings/CalloutPopup.lua
    assertNil(Pop.Draft().iconColor)
    assertTrue(Pop.Save())
    local c = NS.db.profile.callouts[cid]
    assertEqual(c.icon, 136012)
    assertTrue(not c.iconColor)
end)

test("popup: [icons] Add saves a glyph with its color; a malformed color stays open and names the field", function()
    local NS, _, P, Pop = open()
    local gid = withKick(NS)
    local p = NS.db.profile
    local w = P.during(function() Pop.Open(gid) end)
    assertNil(Pop.Draft().iconColor)
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Mark")
    Pop.Draft().icon, Pop.Draft().iconColor = NS.Icon("star"), "zz"
    local before = count(p.callouts)
    local ok, why = Pop.Save()
    assertFalse(ok)
    assertEqual(why, "iconColor")
    assertTrue(Pop.IsOpen(), "the popup stays open")
    assertEqual(count(p.callouts), before, "nothing written")
    -- red under: drop the iconColor check from check in settings/CalloutPopup.lua
    assertTrue(labelWith(P, w, "Icon color: An icon color is six hex digits (rrggbb), or empty for none.") ~= nil)
    Pop.Draft().iconColor = "0000ff"
    assertTrue(Pop.Save())
    local list = p.groups[gid].callouts
    assertEqual(p.callouts[list[#list]].iconColor, "0000ff")
end)
