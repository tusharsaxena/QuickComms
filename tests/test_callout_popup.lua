-- tests/test_callout_popup.lua — settings/CalloutPopup.lua (callouts-owned-by-groups spec, "The
-- callout popup"): the Save/Cancel draft editor a user group's Callouts tab opens, and what
-- settings/Callouts.lua keeps for it (the token list, the preview lines). Driven headlessly through
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

test("popup: a pick, a token or a seam write keeps the text typed without Enter", function()
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
    P.find(w, "Dropdown", "Insert a token"):__fire("OnValueChanged", "{target}")
    assertEqual(Pop.Draft().text, "Kick {focus} {target}", "the token follows the typed text")
    assertEqual(text:GetText(), "Kick {focus} {target}")
    -- a seam write elsewhere refreshes every rendered panel, the popup's among them
    name:SetText("Stop")
    NS.addon:OnSlashCommand("set callout.text " .. cid .. " Slashed")
    assertEqual(name:GetText(), "Stop")
    assertTrue(Pop.Save())
    local c = NS.db.profile.callouts[cid]
    assertEqual(c.name, "Stop")
    assertEqual(c.text, "Kick {focus} {target}")
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

test("popup: Insert a token appends to the draft's text", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    local w = P.during(function() Pop.Open(gid, cid) end)
    P.find(w, "Dropdown", "Insert a token"):__fire("OnValueChanged", "{target}")
    assertEqual(Pop.Draft().text, "Kick {target}")
    assertEqual(NS.db.profile.callouts[cid].text, "Kick", "the stored text waits for Save")
    -- the token list follows the draft's channel: {group1} only where it can resolve to Raid
    local tokens = P.find(w, "Dropdown", "Insert a token")
    assertNil(tokens.list["{group1}"])
    P.find(w, "Dropdown", "Channel"):__fire("OnValueChanged", "raid")
    assertEqual(tokens.list["{group1}"], "{group1}")
end)

-- The picker's icon showing `path`, among the widgets `w`.
local function iconFor(P, w, path)
    for _, icon in ipairs(P.all(w, "Icon")) do
        if icon.image and icon.image[1] == path then return icon end
    end
    return nil
end

test("popup: Choose an icon writes the draft's icon", function()
    local NS, _, P, Pop = open()
    local gid, cid = withKick(NS)
    local w = P.during(function() Pop.Open(gid, cid) end)
    assertTrue(P.find(w, "Heading", "Choose an icon") ~= nil)
    iconFor(P, w, SKULL):__fire("OnClick")
    -- red under: hand the picker the seam row (it would write the stored callout at once)
    assertEqual(Pop.Draft().icon, SKULL)
    assertNil(NS.db.profile.callouts[cid].icon, "the stored icon waits for Save")
    assertEqual(P.find(w, "EditBox", "Icon").text, SKULL, "the Icon box shows the pick")
    assertTrue(Pop.Save())
    assertEqual(NS.db.profile.callouts[cid].icon, SKULL)
    -- the palette: a LibKa0s mark by its path, the built-in sets' own icons, and no window chrome
    w = P.during(function() Pop.Open(gid, cid) end)
    local chat = NS.Icon("chat")
    assertTrue(chat ~= nil and iconFor(P, w, chat) ~= nil)
    assertTrue(iconFor(P, w, "Interface\\Icons\\Spell_Nature_Bloodlust") ~= nil)
    assertNil(iconFor(P, w, "Interface\\Icons\\INV_Misc_QuestionMark"))
    assertNil(iconFor(P, w, NS.Icon("close")), "the catalog's window chrome is not offered")
    local byPath = {}
    for _, e in ipairs(NS.addon.Settings.Editors.IconPalette()) do byPath[e.path] = e.label end
    assertEqual(byPath[SKULL], "Skull", "a raid marker carries its localized name")
    assertEqual(byPath[NS.Icon("speech-bubble")], "Speech bubble", "a catalog mark carries a localized label")
end)

test("popup: its close control is the shared close mark", function()
    local NS, _, _, Pop = open()
    local made = {}
    local make = NS.MakeCloseButton
    NS.MakeCloseButton = function(parent, onClick)
        made[#made + 1] = { parent = parent, onClick = onClick }
        return make(parent, onClick)
    end
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    Pop.Open(gid)
    -- red under: build the popup's close control by hand instead of through NS.MakeCloseButton
    assertEqual(#made, 1)
    assertTrue(made[1].parent == Pop.frame)
    made[1].onClick()
    assertFalse(Pop.IsOpen(), "the close mark cancels")
    Pop.Open(gid)
    assertEqual(#made, 1, "one popup, built once")
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
