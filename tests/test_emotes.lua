-- tests/test_emotes.lua — game-emote callouts (QFE-E2, QuickComms#15, design §5.1, §5.2, §5.4): the
-- token -> command map (core/Compat.lua EmoteCommands, modules/Emotes.lua), the bake, the echo, the
-- preview, the library field and the callout popup's emote picker. Both kit profiles.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- The client's globals as ChatEmoteConstants.lua and GlobalStrings define them, cut down: gaps in
-- the indices, INCOMING and FLEE listed twice (the later FLEE's first command is /retreat), and a
-- token with no command.
local function plant(env)
    env.MAXEMOTEINDEX = 310
    local rows = {
        { 1, "AGREE", "/agree" }, { 19, "BYE", "/bye" }, { 35, "DANCE", "/dance" }, { 61, "LAUGH", "/laugh" },
        { 73, "POINT", "/point" }, { 102, "WAVE", "/wave" }, { 157, "INCOMING", "/incoming" },
        { 160, "FLEE", "/flee" }, { 162, "OOM", "/oom" }, { 200, "NOCOMMAND", nil },
        { 304, "INCOMING", "/inc" }, { 306, "FLEE", "/retreat" },
    }
    for _, r in ipairs(rows) do
        env["EMOTE" .. r[1] .. "_TOKEN"] = r[2]
        env["EMOTE" .. r[1] .. "_CMD1"] = r[3]
    end
    env.TextEmoteSpeechList = { "INCOMING", "FLEE", "OOM", "BYE", "MISSING" }
    env.EmoteList = { "WAVE", "DANCE", "POINT", "LAUGH" }
    return env
end

local function snap(over)
    local s = { group = "solo", instanceGroup = false, leader = false, assist = false, lockdown = {} }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end

local function addon()
    local NS, env, m = T.newAddon()
    plant(env)
    NS.Emotes.Reset()
    return NS, env, m
end

local function live()
    local NS, env, m = T.enableAddon()
    plant(env)
    NS.Emotes.Reset()
    NS.Situation.ReadInputs = function() return {} end
    NS.Situation.RefreshNow("test")
    return NS, env, m
end

-- ── the map ──────────────────────────────────────────────────────────────────────────────────

test("emotes: [QFE-E2] the map is EMOTEn_TOKEN to EMOTEn_CMD1 over the client's indices, first index wins", function()
    local NS = addon()
    local map, order = NS.Compat.EmoteCommands()
    -- red under: a scan that stops at the first gap (EMOTE2_TOKEN), or lets a later duplicate win
    assertEqual(map.POINT, "/point")
    assertEqual(map.INCOMING, "/incoming", "157 before 304")
    assertEqual(map.FLEE, "/flee", "160 before 306's /retreat")
    assertNil(map.NOCOMMAND, "a token with no command is left out")
    assertEqual(#order, 9)
    assertEqual(order[1], "AGREE")
end)

test("emotes: [QFE-REV] a command the chat parser runs before an emote is skipped for the token's next one", function()
    local NS, env = addon()
    -- Every locale's SHOUT is /shout, which is Yell (SLASH_YELL4); koKR's LOST is /포기, the secure
    -- /abandon; frFR's /silence is the chat mute; a fourth sits in the parser's own hash only.
    env.EMOTE83_TOKEN, env.EMOTE83_CMD1, env.EMOTE83_CMD2 = "SHOUT", "/shout", "/holler"
    env.EMOTE119_TOKEN, env.EMOTE119_CMD1, env.EMOTE119_CMD2 = "LOST", "/포기", "/lost"
    env.EMOTE120_TOKEN, env.EMOTE120_CMD1 = "SHH", "/silence"
    env.EMOTE121_TOKEN, env.EMOTE121_CMD1, env.EMOTE121_CMD2 = "HUSH", "/hush", "/quiet"
    env.SLASH_YELL1, env.SLASH_YELL2, env.SLASH_YELL3, env.SLASH_YELL4 = "/yell", "/y", "/yell", "/Shout"
    env.SLASH_CHAT_MUTE1 = "/silence"
    -- ChatTypeInfo as the parser leaves it after its first import: the entries moved to the proxy.
    env.ChatTypeInfo = setmetatable({}, { __index = { YELL = {} } })
    env.SlashCmdList = type(env.SlashCmdList) == "table" and env.SlashCmdList or {}
    env.SlashCmdList.CHAT_MUTE = function() end
    env.hash_ChatTypeInfoList = { ["/HUSH"] = "WHISPER" }
    env.IsSecureCmd = function(cmd) return cmd:upper() == "/포기" or nil end
    local map, order = NS.Compat.EmoteCommands()
    -- red under: a filter on the command's shape alone (/shout, /포기, /silence and /hush kept)
    assertEqual(map.SHOUT, "/holler", "Yell's /shout is never an emote")
    assertEqual(map.LOST, "/lost", "the secure /abandon is never an emote")
    assertNil(map.SHH, "a token with no free command is left out")
    assertEqual(map.HUSH, "/quiet")
    assertEqual(map.POINT, "/point", "a free CMD1 is still the command")
    assertEqual(#order, 12)
end)

test("emotes: [QFE-E2] the picker lists speech emotes first, marked as voice, then the animated, then the rest", function()
    local NS = addon()
    local list = NS.Emotes.List()
    local tokens = {}
    for i, e in ipairs(list) do tokens[i] = e.token end
    -- red under: index order only, or a speech token the client lacks (MISSING) listed
    assertEqual(table.concat(tokens, ","), "INCOMING,FLEE,OOM,BYE,WAVE,DANCE,POINT,LAUGH,AGREE")
    assertTrue(list[1].voice)
    assertFalse(list[5].voice)
    assertEqual(list[7].command, "/point")
    assertTrue(NS.Emotes.IsVoice("oom"))
end)

test("emotes: [QFE-E2] Find takes a command or a token; Search matches either, in the picker's order", function()
    local NS = addon()
    assertEqual(NS.Emotes.Find("/point"), "POINT")
    assertEqual(NS.Emotes.Find("Point"), "POINT")
    assertEqual(NS.Emotes.Find(" wave "), "WAVE")
    assertNil(NS.Emotes.Find("/poi"))
    local hits = NS.Emotes.Search("/f")
    assertEqual(#hits, 1)
    assertEqual(hits[1].token, "FLEE")
    assertEqual(#NS.Emotes.Search(""), 9, "an empty search lists every emote")
    assertEqual(#NS.Emotes.Search("", 3), 3)
end)

test("emotes: [QFE-E2] the map is built once, on the first read", function()
    local NS, env = addon()
    assertEqual(NS.Emotes.Command("POINT"), "/point")
    env.EMOTE73_CMD1 = "/changed"
    assertEqual(NS.Emotes.Command("POINT"), "/point", "kept")
    NS.Emotes.Reset()
    assertEqual(NS.Emotes.Command("POINT"), "/changed")
end)

-- ── the bake ─────────────────────────────────────────────────────────────────────────────────

test("emotes: [QFE-E2] a game emote bakes the client's command, never the text", function()
    local NS = addon()
    local line, reason, info = NS.Bake.Bake({ name = "Point", text = "/dance ignored", channel = "gameEmote",
        emote = "POINT" }, snap())
    -- red under: no gameEmote branch (the text bakes, or Resolve answers badChannel)
    assertEqual(line, "/point")
    assertNil(reason)
    assertEqual(info.concrete, "gameEmote")
    assertEqual(info.length, 6)
    assertEqual(#info.missing, 0)
    assertEqual(NS.Channels.ChatType("gameEmote"), "TEXT_EMOTE")
    assertNil(NS.Channels.Prefix("gameEmote"), "no prefix: the command is the line")
    -- a typed "/" is still refused for every other channel
    assertEqual(select(2, NS.Bake.Bake({ name = "x", text = "/dance", channel = "say" }, snap())), "startsWithSlash")
end)

test("emotes: [QFE-E2] an unknown or missing token bakes nothing and says why", function()
    local NS = addon()
    local line, reason, info = NS.Bake.Bake({ name = "X", text = "", channel = "gameEmote", emote = "FROMRETAIL" }, snap())
    assertNil(line)
    assertEqual(reason, "unknownEmote")
    assertEqual(info.emote, "FROMRETAIL")
    assertTrue(NS.PadRender.REASON_TEXT.unknownEmote ~= nil)
    line, reason = NS.Bake.Bake({ name = "X", text = "", channel = "gameEmote" }, snap())
    assertNil(line)
    assertEqual(reason, "noEmote")
    assertTrue(NS.PadRender.REASON_TEXT.noEmote ~= nil)
end)

test("emotes: [QFE-E2] a game emote locks as Say does", function()
    local NS = addon()
    local _, _, info = NS.Bake.Bake({ name = "P", text = "", channel = "gameEmote", emote = "POINT" },
        snap({ lockdown = { encounter = true } }))
    assertEqual(info.lock, "lockdown")
    assertNil(NS.Channels.LockState("gameEmote", snap()))
end)

-- ── the library ──────────────────────────────────────────────────────────────────────────────

test("emotes: [QFE-E2] the library stores the token, copies keep it, and the seam writes it", function()
    local NS = live()
    local Lib = NS.Library
    local cid = Lib.CreateCallout({ name = "/point", text = "", channel = "gameEmote", emote = "POINT" })
    assertEqual(NS.db.profile.callouts[cid].emote, "POINT")
    assertNil((Lib.CreateCallout({ name = "Bad", text = "", channel = "gameEmote", emote = "not a token" })))
    local gid = Lib.CreateGroup({ name = "Mine", callouts = { cid } })
    local copy = Lib.Group(Lib.DuplicateGroup(gid)).callouts[1]
    -- red under: copyCallout drops the field
    assertTrue(copy ~= nil and copy ~= cid, "a fresh copy")
    assertEqual(NS.db.profile.callouts[copy].emote, "POINT")
    local ok1, e1, w1 = NS.SchemaRuntime.Set("callout.emote", "/wave", cid)
    assertTrue(ok1, tostring(e1) .. tostring(w1))
    assertEqual(NS.db.profile.callouts[cid].emote, "WAVE", "a command typed reads through the map")
    local ok2, e2, w2 = NS.SchemaRuntime.Set("callout.emote", "", cid)
    assertTrue(ok2, tostring(e2) .. tostring(w2))
    assertEqual(NS.db.profile.callouts[cid].emote, false, "nothing is none")
    assertFalse((NS.SchemaRuntime.Set("callout.emote", "two words", cid)))
end)

test("emotes: [QFE-E2] the channel row offers Game emote; a Groups row previews the command", function()
    local NS = live()
    local found
    for _, v in ipairs(NS.SchemaRuntime.FindRow("callout.channel").values) do
        if v.value == "gameEmote" then found = v.text end
    end
    assertEqual(found, "Game emote")
    local G = NS.addon.Settings.Groups
    assertEqual(G.CalloutSummary({ channel = "gameEmote", emote = "POINT", text = "" }), "/point")
    assertEqual(G.CalloutSummary({ channel = "gameEmote", emote = "NOPE", text = "" }), "NOPE (not on this client)")
    assertEqual(G.CalloutSummary({ channel = "say", text = "hi" }), "hi")
end)

-- ── the send, the echo and the preview ───────────────────────────────────────────────────────

local function emoteGroup(NS, token)
    local Lib = NS.Library
    local cid = Lib.CreateCallout({ name = "Point", text = "", channel = "gameEmote", emote = token })
    local gid = Lib.CreateGroup({ name = "Emotes here", callouts = { cid } })
    Lib.AddGroupToSurface("pad", "p1", gid, 1)
    return cid
end

test("emotes: [QFE-E2] a pad button arms the command, and its echo is the player's CHAT_MSG_TEXT_EMOTE", function()
    local NS, _, m = live()
    local cid = emoteGroup(NS, "POINT")
    local b = NS.Pad.ButtonsFor("p1", cid)[1]
    assertTrue(b ~= nil)
    assertEqual(b:GetAttribute("macrotext"), "/point")
    local out = {}
    NS.Bus:NewTarget():RegisterMessage(NS.MSG.SEND_RESULT, function(_, _, _, what) out[#out + 1] = what end)
    m.__now = 100
    m.__click(b)
    assertEqual(m.sentMacros[#m.sentMacros].text, "/point")
    m.__fire("CHAT_MSG_EMOTE", "never read", "Testchar-Testrealm", "", "", "", "", 0, 0, "", 0, 1, m.playerGUID)
    assertEqual(NS.SendEngine.EchoState().pending, 1, "a custom emote line is not the echo")
    -- red under: no CHAT_MSG_TEXT_EMOTE row in SendGuard.CHAT_TYPE_BY_EVENT
    m.__fire("CHAT_MSG_TEXT_EMOTE", "never read", "Testchar-Testrealm", "", "", "", "", 0, 0, "", 0, 1, m.playerGUID)
    assertEqual(table.concat(out, ","), "sent")
    assertEqual(NS.SendEngine.EchoState().pending, 0)
end)

test("emotes: [QFE-E2] a previewed game emote prints would emote /point and sends nothing", function()
    local NS, _, m = live()
    local cid = emoteGroup(NS, "POINT")
    assertTrue(NS.Preview.SetPreviewAs("world"))
    m.prints = {}
    m.sentMacros = {}
    m.__click(NS.Pad.ButtonsFor("p1", cid)[1])
    -- red under: SlotEcho re-bakes the line as chat
    assertEqual(m.prints[1], NS.PREFIX .. " would emote /point")
    assertEqual(#m.sentMacros, 0)
end)

-- ── the callout popup ────────────────────────────────────────────────────────────────────────

local function popup()
    local NS, env, m = live()
    local P = dofile("tests/page_helpers.lua")(NS, m)
    m.SettingsPanel:Show()
    return NS, env, m, P, NS.addon.Settings.CalloutPopup
end

test("emotes: [QFE-E2] picking Game emote swaps the Text box for the emote picker; a pick names the callout", function()
    local NS, _, _, P, Pop = popup()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local w = P.during(function() Pop.Open(gid) end)
    assertTrue(P.find(w, "EditBox", "Text") ~= nil)
    w = P.during(function() P.find(w, "Dropdown", "Channel"):__fire("OnValueChanged", "gameEmote") end)
    -- red under: the body is not drawn again for Game emote
    assertNil(P.find(w, "EditBox", "Text"), "no text box")
    assertTrue(P.find(w, "EditBox", "Game emote") ~= nil, "the emote picker")
    -- The kit's AceGUI EditBox has no inner .editbox, so the autocomplete is attached only in the client
    -- (smoke EMOTE-4); here the picker is the box, its search and its pick.
    if P.find(w, "EditBox", "Game emote").editbox then assertTrue(Pop.emoteSuggest ~= nil) end
    local rows = Pop.EmoteSuggestions("o")
    assertEqual(rows[1].token, "INCOMING", "speech first")
    assertEqual(rows[1].text, "/incoming (voice)")
    assertTrue(Pop.PickEmote("POINT"))
    assertEqual(Pop.Draft().emote, "POINT")
    assertEqual(Pop.Draft().name, "/point", "the name defaults to the command")
    assertTrue(Pop.PickEmote("WAVE"))
    assertEqual(Pop.Draft().name, "/wave", "a name still the last pick's command follows the pick")
    assertFalse(Pop.PickEmote("NOPE"))
    assertTrue(Pop.Save())
    local g = NS.Library.Group(gid)
    local c = NS.db.profile.callouts[g.callouts[#g.callouts]]
    assertEqual(c.channel, "gameEmote")
    assertEqual(c.emote, "WAVE")
    assertEqual(c.text, "")
end)

test("emotes: [QFE-E2] Save with Game emote and no pick stays open and names the picker", function()
    local NS, _, _, P, Pop = popup()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local w = P.during(function() Pop.Open(gid) end)
    P.find(w, "EditBox", "Name"):__fire("OnEnterPressed", "Hi")
    P.find(w, "Dropdown", "Channel"):__fire("OnValueChanged", "gameEmote")
    local ok, field = Pop.Save()
    assertFalse(ok)
    assertEqual(field, "emote")
    assertTrue(Pop.IsOpen())
end)

test("emotes: [QFE-E2] a user name is kept, and leaving Game emote drops the token on Save", function()
    local NS, _, _, P, Pop = popup()
    local gid = NS.Library.CreateGroup({ name = "Mine" })
    local cid = NS.Library.CreateCalloutIn(gid, { name = "Look", text = "", channel = "gameEmote", emote = "POINT" })
    local w = P.during(function() Pop.Open(gid, cid) end)
    assertEqual(Pop.Draft().emote, "POINT")
    Pop.PickEmote("WAVE")
    assertEqual(Pop.Draft().name, "Look", "a name the player gave stays")
    w = P.during(function() P.find(w, "Dropdown", "Channel"):__fire("OnValueChanged", "say") end)
    P.find(w, "EditBox", "Text"):__fire("OnEnterPressed", "hello")
    assertTrue(Pop.Save())
    local c = NS.db.profile.callouts[cid]
    assertEqual(c.channel, "say")
    assertEqual(c.text, "hello")
    assertEqual(c.emote, false, "one action per callout")
end)

test("emotes: [QFE-E2] the popup's preview names the emote, and an unknown token's reason", function()
    local NS = live()
    local C = NS.addon.Settings.Callouts
    local lines = C.PreviewLines({ name = "Oom", text = "", channel = "gameEmote", emote = "OOM" })
    assertEqual(lines[1], "Emotes: /oom")
    assertEqual(lines[2], "A voice emote: it also plays its sound.")
    lines = C.PreviewLines({ name = "X", text = "", channel = "gameEmote", emote = "FROMRETAIL" })
    assertEqual(lines[1], "Sends nothing here: This game emote is not on this client.")
    assertEqual(lines[2], "Emote token: FROMRETAIL")
end)
