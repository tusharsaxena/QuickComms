-- tests/test_page_callouts.lua — settings/Callouts.lua (spec §13.1): the banner's picker and New
-- callout, the General tab's rows, token insert, live line and acts, and the Used by tab. Driven
-- headlessly through tests/page_helpers.lua.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MPLUS = { inInstance = true, instanceType = "party", difficultyID = 8, keystoneActive = true,
    keyLevel = 12, inGroup = true }

local function open(inputs)
    local NS, m = T.enableAddon()
    NS.Situation.ReadInputs = function() return inputs or {} end
    NS.Situation.RefreshNow("test")
    local P = dofile("tests/page_helpers.lua")(NS, m)
    P.show("Callouts")
    return NS, m, P
end

test("callouts page: with no callouts it says how to make one, and New callout makes and selects one", function()
    local NS, _, P = open()
    local w = P.redraw("callouts")
    assertTrue(P.hasText(w, "No callouts yet"))
    P.bannerAction(P.ctx("callouts")):__fire("OnClick")
    P.flush()
    local id = NS.State.editing.callout
    assertTrue(id ~= nil and NS.db.profile.callouts[id] ~= nil)
    w = P.redraw("callouts")
    assertEqual(P.find(w, "EditBox", "Name").text, "New callout")
    assertEqual(P.banner(P.ctx("callouts")).value, id)
end)

test("callouts page: the rows write the selected callout through the seam", function()
    local NS, _, P = open()
    local id = NS.addon.Settings.Callouts.Create()
    local w = P.redraw("callouts")
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Bloodlust")
    P.find(w, "EditBox", "Text"):__fire("OnEnterPressed", "Lust now")
    P.find(w, "Dropdown", "Channel"):__fire("OnValueChanged", "party")
    local c = NS.db.profile.callouts[id]
    assertEqual(c.name, "Bloodlust")
    assertEqual(c.text, "Lust now")
    assertEqual(c.channel, "party")
end)

test("callouts page: [review 5] an empty name is refused with its reason and nothing changes", function()
    local NS, m, P = open()
    local id = NS.addon.Settings.Callouts.Create()
    local w = P.redraw("callouts")
    m.prints = {}
    local box = P.find(w, "EditBox", "Name")
    box:SetText("")   -- as the player's typing leaves it
    box:__fire("OnEnterPressed", "")
    assertEqual(NS.db.profile.callouts[id].name, "New callout")
    -- red under: hand NS.SchemaRuntime.Set to the options descriptor unwrapped (the refusal is silent)
    assertTrue(table.concat(m.prints, "\n"):find("A name is 1 to 32 characters.", 1, true) ~= nil)
    assertEqual(box.text, "New callout", "the box shows the stored name again")
end)

test("callouts page: [phase 3] the token picker offers {group1}-{group8} only when the channel can resolve to Raid", function()
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

test("callouts page: [phase 3] the live line refreshes in place when the callout changes", function()
    local NS, _, P = open(MPLUS)
    local id = NS.addon.Settings.Callouts.Create()
    NS.SchemaRuntime.Set("callout.channel", "party", id)
    NS.SchemaRuntime.Set("callout.text", "Pull", id)
    local w = P.redraw("callouts")
    local line
    for _, label in ipairs(P.all(w, "Label")) do
        if label.text and label.text:find("Sends:", 1, true) then line = label end
    end
    assertTrue(line ~= nil)
    NS.State.editing.callout = id
    NS.addon:OnSlashCommand("set callout.text Kick")   -- a real write: the seam's refresh, nothing by hand
    -- red under: draw the live line without its Ed.Live refresher in settings/Callouts.lua, or drop
    -- Ed.Live's append to ctx.refreshers in settings/Editors.lua (the library's scalar refresh)
    assertTrue(line.text:find("Sends: /p Kick", 1, true) ~= nil, line.text)
end)

test("callouts page: Insert a token adds it to the end of the text", function()
    local NS, _, P = open()
    local id = NS.addon.Settings.Callouts.Create()
    NS.SchemaRuntime.Set("callout.text", "Kick", id)
    local w = P.redraw("callouts")
    P.find(w, "Dropdown", "Insert a token"):__fire("OnValueChanged", "{target}")
    assertEqual(NS.db.profile.callouts[id].text, "Kick {target}")
end)

test("callouts page: the live line shows what it sends here, or why it sends nothing", function()
    local NS, _, P = open(MPLUS)
    local id = NS.addon.Settings.Callouts.Create()
    NS.SchemaRuntime.Set("callout.text", "Pulling {rt8}", id)
    NS.SchemaRuntime.Set("callout.channel", "party", id)
    local w = P.redraw("callouts")
    assertTrue(P.hasText(w, "Sends: /p Pulling {rt8}"))
    assertTrue(P.hasText(w, "of 255 bytes"))
    -- [review 5] text that starts with / is stored, and the page says at once that it sends nothing
    NS.SchemaRuntime.Set("callout.text", "/run x", id)
    assertEqual(NS.db.profile.callouts[id].text, "/run x")
    w = P.redraw("callouts")
    assertTrue(P.hasText(w, "Sends nothing here: Callout text cannot start with /."))
    -- under a previewed raid, a party callout is fine; a raid one in the open world is padlocked
    NS.SchemaRuntime.Set("callout.text", "Stack", id)
    NS.SchemaRuntime.Set("callout.channel", "raid", id)
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    w = P.redraw("callouts")
    assertTrue(P.hasText(w, "Locked: you are not in a raid."))
    NS.Preview.SetPreviewAs("raid:heroic")
    w = P.redraw("callouts")
    assertFalse(P.hasText(w, "Locked: you are not in a raid."))
    assertTrue(P.hasText(w, "Previewing: Raid"))
end)

test("callouts page: Duplicate selects the copy; Delete asks, then removes it from every group", function()
    local NS, _, P = open()
    local C = NS.addon.Settings.Callouts
    local id = C.Create()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    id = NS.Library.AddToGroup(gid, id)
    local w = P.redraw("callouts")
    P.find(w, "Button", "Duplicate"):__fire("OnClick")
    local copy = NS.State.editing.callout
    assertTrue(copy ~= id)
    assertEqual(NS.db.profile.callouts[copy].name, "New callout (copy)")
    NS.addon.Settings.Editors.Select("callout", id)
    w = P.redraw("callouts")
    P.find(w, "Button", "Delete"):__fire("OnClick")
    assertTrue(NS.db.profile.callouts[id] ~= nil, "asks first")
    P.accept()
    assertNil(NS.db.profile.callouts[id])
    assertEqual(#NS.db.profile.groups[gid].callouts, 0)
end)

test("callouts page: [review 2] the selected callout deleted elsewhere: the page heals, writes go to the next", function()
    local NS, _, P = open()
    local C = NS.addon.Settings.Callouts
    local first = C.Create()
    NS.SchemaRuntime.Set("callout.name", "Alpha", first)
    local second = C.Create()
    NS.SchemaRuntime.Set("callout.name", "Beta", second)
    NS.addon.Settings.Editors.Select("callout", second)
    P.redraw("callouts")
    NS.Library.DeleteCallout(second)      -- as the Groups page or a profile reset would
    P.flush()
    local w = P.redraw("callouts")
    assertEqual(NS.State.editing.callout, first)
    assertEqual(P.find(w, "EditBox", "Name").text, "Alpha")
    assertTrue(NS.SchemaRuntime.Set("callout.text", "x"))
    assertEqual(NS.db.profile.callouts[first].text, "x")
    assertNil(NS.db.profile.callouts[second])
end)

test("callouts page: Used by lists the groups that hold it, and a click opens that group", function()
    local NS, m, P = open()
    local C = NS.addon.Settings.Callouts
    local id = C.Create()
    local w = P.tab("callouts", "usedBy")
    assertTrue(P.hasText(w, "No group holds this callout yet"))
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    id = NS.Library.AddToGroup(gid, id)
    NS.addon.Settings.Editors.Select("callout", id)   -- the group holds a copy (one owner)
    local opened
    m.Settings.OpenToCategory = function(cid) opened = cid end
    NS.addon.Settings.Editors.categories.groups = { GetID = function() return 9 end }
    w = P.tab("callouts", "usedBy")
    local link = P.find(w, "InteractiveLabel", "Mine")
    assertTrue(link ~= nil)
    link:__fire("OnClick")
    assertEqual(NS.State.editing.group, gid)
    assertEqual(opened, 9)
end)

test("callouts page: [final 3] Defaults resets the callout as one act: one rebuild", function()
    local NS, _, P = open()
    local id = NS.addon.Settings.Callouts.Create()
    NS.SchemaRuntime.Set("callout.channel", "party", id)
    P.redraw("callouts")
    local applied = 0
    local apply = NS.Surfaces.ApplyAll
    NS.Surfaces.ApplyAll = function(...) applied = applied + 1 return apply(...) end
    P.ctx("callouts").panel.defaultsOnClick()
    NS.Surfaces.ApplyAll = apply
    assertEqual(NS.db.profile.callouts[id].channel, "smartGroup")
    assertTrue(applied <= 1, "one rebuild")
end)

test("callouts page: [final 4] Defaults keeps the icon (its default is only for `/qc reset`)", function()
    local NS, _, P = open()
    local id = NS.addon.Settings.Callouts.Create()
    NS.SchemaRuntime.Set("callout.icon", "136012", id)
    NS.SchemaRuntime.Set("callout.channel", "party", id)
    P.redraw("callouts")
    P.ctx("callouts").panel.defaultsOnClick()
    assertEqual(NS.db.profile.callouts[id].channel, "smartGroup")
    -- red under: drop callout.icon from settings/Schema.lua's resetExempt
    assertEqual(NS.db.profile.callouts[id].icon, 136012)
end)

test("callouts page: [review 1] a delete popup accepted after the pull deletes; the pad catches up at combat end", function()
    local NS, m, P = open(MPLUS)
    local C = NS.addon.Settings.Callouts
    local id = C.Create()
    NS.SchemaRuntime.Set("callout.channel", "party", id)
    local gid = NS.Library.CreateGroup({ name = "Mine", callouts = { id } })
    NS.Library.AddGroupToSurface("pad", "p1", gid, 1)
    assertTrue(NS.Pad.ChipsFor("p1", id)[1] ~= nil)
    NS.addon.Settings.Editors.Select("callout", id)
    local w = P.redraw("callouts")
    P.find(w, "Button", "Delete"):__fire("OnClick")
    m.__setCombat(false)
    m.__fire("PLAYER_REGEN_DISABLED")
    m.__setCombat(true)
    -- red under: guard the popup's OnAccept, or route it through anything that drops in combat
    P.accept()
    assertNil(NS.db.profile.callouts[id], "the data write lands in combat")
    assertEqual(#m.blocked, 0, "no protected call")
    assertTrue(NS.Pad.Instance("p1").header.qcStale:IsShown(), "the stale hint")
    m.__setCombat(false)
    m.__fire("PLAYER_REGEN_ENABLED")
    assertTrue(NS.Pad.ChipsFor("p1", id)[1] == nil, "the chip is gone after combat")
    assertFalse(NS.Pad.Instance("p1").header.qcStale:IsShown())
    assertEqual(#m.blocked, 0)
end)

-- The picker's icon showing `path`, among the widgets `w`.
local function iconFor(P, w, path)
    for _, icon in ipairs(P.all(w, "Icon")) do
        if icon.image and icon.image[1] == path then return icon end
    end
    return nil
end

test("callouts page: [phase 5] Choose an icon: a click on the skull is the callout's icon, through the seam", function()
    local NS, _, P = open()
    local id = NS.Library.CreateCallout({ name = "Kill", text = "Kill {skull}", channel = "party" })
    NS.addon.Settings.Editors.Select("callout", id)
    local w = P.redraw("callouts")
    assertTrue(P.find(w, "Heading", "Choose an icon") ~= nil)
    local skull = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
    iconFor(P, w, skull):__fire("OnClick")
    assertEqual(NS.db.profile.callouts[id].icon, skull)
    -- a LibKa0s mark is offered by its path, as the Icon box takes it
    local chat = NS.Icon("chat")
    assertTrue(chat ~= nil and iconFor(P, w, chat) ~= nil)
    -- the built-in sets' icons are read from NS.BuiltIns: their callouts' too, and nothing they do not wear
    -- red under: hard-code a list of game icons in settings/Editors.lua that leaves out the callouts'
    assertTrue(iconFor(P, w, "Interface\\Icons\\Spell_Nature_Bloodlust") ~= nil)
    assertTrue(iconFor(P, w, "Interface\\Icons\\Spell_Nature_Reincarnation") ~= nil)
    assertNil(iconFor(P, w, "Interface\\Icons\\INV_Misc_QuestionMark"))
    assertNil(iconFor(P, w, NS.Icon("close")), "the catalog's window chrome is not offered")
    local labels = {}
    for _, e in ipairs(NS.addon.Settings.Editors.IconPalette()) do labels[#labels + 1] = e.label end
    assertEqual(labels[8], "Skull", "a raid marker carries its localized name")
    -- [review] red under: IconPalette labeling a catalog mark with its raw catalog key ("speech-bubble")
    local byPath = {}
    for _, e in ipairs(NS.addon.Settings.Editors.IconPalette()) do byPath[e.path] = e.label end
    assertEqual(byPath[NS.Icon("speech-bubble")], "Speech bubble", "a catalog mark carries a localized label")
    assertEqual(byPath[NS.Icon("thumb-up")], "Thumbs up")
end)
