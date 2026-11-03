-- tests/test_skin_picker.lua — the first-run skin picker on this addon's seam (QC-04;
-- core/SkinSetup.lua, LibKa0s OptionsSkinPicker 1, the rollout's O3 / X6).
--
-- What this addon owes the picker, and nothing the library pins itself: the spec it hands the
-- Options instance's SkinPicker (its owner, its two seams, General's Skin tab, the eye, the close);
-- WHEN it shows (a profile whose `skin.pickerSeen` is false, two seconds after OnEnable and after
-- every profile event, never while the addon stands down, held through combat); and that only the
-- player's close marks it seen. The trigger cases spy on SkinPicker; the last cases drive the
-- library's real window: the eye turning test mode on, Apply saving through NS.WriteSkinChoice, the
-- close control saving nothing, the gear opening General on its Skin tab, and the stand-down
-- taking the window down unseen.
--
-- Modeled on LootHistory's tests/test_skin_picker.lua, the reference adopter, and AbsorbTracker's.
-- Every case builds its own instance, so nothing leaks between cases.

local T = _G.QUICKCOMMS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "QuickComms"
local PATH = "skin.pickerSeen"

--- An enabled instance with every frame built from here on listed by parent, so a case can reach
--- the picker list's rows (the mock's frames do not list their children, and the picker builds its
--- window on its first show). Answers NS, the mock, the Options instance, the Skin major and the
--- children map.
local function setup()
    local NS, _, m = T.enableAddon()
    local childrenOf = setmetatable({}, { __mode = "k" })
    local create = m.CreateFrame
    m.CreateFrame = function(frameType, name, parent, ...)
        local f = create(frameType, name, parent, ...)
        if parent ~= nil then
            local list = childrenOf[parent] or {}
            childrenOf[parent] = list
            list[#list + 1] = f
        end
        return f
    end
    return NS, m, NS.addon.Settings.Helpers, m.LibStub("LibKa0s-Skin-1.0"), childrenOf
end

local function seen(NS) return NS.SchemaRuntime.Get(PATH) end
local function worn(Skin) return select(2, Skin:GetChoice(OWNER)) end
local function stored(NS) return select(2, NS.SkinChoice()) end

--- Run `fn(calls)` with the instance's SkinPicker replaced by a recorder: each call's spec.
local function spying(O, fn)
    local real = O.SkinPicker
    local calls = {}
    O.SkinPicker = function(spec)
        calls[#calls + 1] = spec
        return { spy = true }
    end
    local ok, err = pcall(fn, calls)
    O.SkinPicker = real
    if not ok then error(err, 0) end
end

--- The picker's login timer: the one AceTimer entry two seconds out, or nil.
local function loginTimer(m)
    for _, t in ipairs(m.__timers or {}) do
        if t.delay == 2 then return t end
    end
    return nil
end

-- ── the key and the spec ─────────────────────────────────────────────────────────────────────────

test("skin picker: the spec names this owner, its seams, General's Skin tab and the eye", function()
    -- red under: a set that is not the write seam (Apply would never reach the profile), a page key
    -- RegisterOptionsPage was not given (the gear would open nothing), or no eye (X6: this addon has
    -- a test mode to preview in). R6-PV: the eye is spec.preview's test mode, and the one-shot
    -- onPreview is gone (with both, the library ignores onPreview anyway).
    local NS = T.enableAddon()
    local spec = NS.SkinPickerSpec()
    assertEqual(spec.owner, OWNER)
    assertTrue(rawequal(spec.get, NS.SkinChoice), "get is the read seam")
    assertTrue(rawequal(spec.set, NS.WriteSkinChoice), "set is the write seam")
    assertEqual(spec.page, "general", "the key settings/Panel.lua gave RegisterOptionsPage")
    assertEqual(spec.tab, "Appearance", "the Skin tab's key")
    local pv = spec.preview
    assertTrue(type(pv) == "table", "spec.preview, the eye's mode (R6-PV)")
    assertEqual(pv.mode, "test", "test mode, /qc test (00_PLAN.md call 2)")
    for _, k in ipairs({ "enter", "exit", "isActive", "isShown" }) do
        assertEqual(type(pv[k]), "function", "preview." .. k)
    end
    assertEqual(spec.onPreview, nil, "the old one-shot eye is gone")
    assertEqual(type(spec.onClose), "function")
end)

test("skin picker: the preview hook goes through test mode's own seam and reads the launcher's state", function()
    -- red under: an enter or exit that writes State.testMode itself (no refusal, no announce, so the
    -- panel's checkbox and the launcher fall out of step), or an isShown that is not the pads' hide.
    local NS = T.enableAddon()
    local pv = NS.SkinPickerSpec().preview
    local P = NS.Preview
    local real, calls = P.SetTestMode, {}
    P.SetTestMode = function(on) calls[#calls + 1] = on; return real(on) end
    local ok, err = pcall(function()
        assertTrue(not pv.isActive(), "test mode starts off")
        pv.enter("eye")
        assertTrue(P.IsTestMode() and pv.isActive(), "enter turned test mode on")
        pv.exit("eye")
        assertTrue(not P.IsTestMode() and not pv.isActive(), "exit turned it off")
        assertEqual(#calls, 2, "both through NS.Preview.SetTestMode, the verb's and the launcher's seam")
        assertEqual(calls[1], true)
        assertEqual(calls[2], false)
    end)
    P.SetTestMode = real
    if not ok then error(err, 0) end
    assertTrue(pv.isShown(), "the pads show by default")
    NS.SlashVerbs.TogglePads()
    assertTrue(not pv.isShown(), "/qc toggle hid them: the main surface reads hidden")
    NS.SlashVerbs.TogglePads()
    assertTrue(pv.isShown(), "shown again: core/LauncherSetup.lua's isWindowShown reads the same PadsShown")
end)

test("skin picker: the picker's enter and restore are quiet where test mode refuses; the eye's is not", function()
    -- red under: a close in combat printing "Test mode is not available in combat." for a restore
    -- the player never asked for.
    local NS, _, m = T.enableAddon()
    local pv = NS.SkinPickerSpec().preview
    m.__setCombat(true)
    local before = #m.prints
    assertEqual(pv.enter("picker"), false, "refused in combat")
    assertEqual(#m.prints, before, "the picker's own enter prints nothing")
    pv.enter("eye")
    assertTrue(#m.prints == before + 1, "the eye's enter prints test mode's own refusal")
    assertTrue(not NS.Preview.IsTestMode(), "and changes nothing")
    m.__setCombat(false)
end)

-- ── when it shows ────────────────────────────────────────────────────────────────────────────────

test("skin picker: an unseen profile shows it; a seen one does not", function()
    local NS, _, O = setup()
    spying(O, function(calls)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 1, "pickerSeen false: the picker shows")
        assertEqual(calls[1].owner, OWNER)
        NS.SchemaRuntime.Set(PATH, true)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 1, "pickerSeen true: it does not show again")
    end)
end)

test("skin picker: it shows two seconds after OnEnable, on the login timer", function()
    -- red under: dropping NS.ScheduleSkinPicker from OnEnable (no profile would ever see it), or a
    -- C_Timer the stand-down cannot cancel.
    local _, m, O = setup()
    local timer = loginTimer(m)
    assertTrue(timer ~= nil, "OnEnable scheduled no two-second start")
    spying(O, function(calls)
        timer.fn()
        assertEqual(#calls, 1, "the login timer shows the picker")
    end)
end)

test("skin picker: the stand-down cancels the login timer", function()
    local NS, m, O = setup()
    local timer = loginTimer(m)
    assertTrue(timer ~= nil, "OnEnable scheduled no two-second start")
    NS.SchemaRuntime.Set("enabled", false)
    spying(O, function(calls)
        NS.SchemaRuntime.Set("enabled", true)
        m.__fireTimers()
        assertEqual(#calls, 0, "a timer the stand-down dropped must not show the picker")
    end)
end)

test("skin picker: in combat a start waits for PLAYER_REGEN_ENABLED, once", function()
    local NS, m, O = setup()
    spying(O, function(calls)
        m.inCombat = true
        assertEqual(NS.MaybeShowSkinPicker(), nil)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 0, "nothing shows in combat")
        m.inCombat = false
        m.__fireEvent("PLAYER_REGEN_ENABLED")
        assertEqual(#calls, 1, "the combat edge shows it, once for two held starts")
        m.__fireEvent("PLAYER_REGEN_ENABLED")
        assertEqual(#calls, 1, "the one-shot target is gone")
    end)
end)

test("skin picker: a held start is dropped by HideSkinPicker", function()
    local NS, m, O = setup()
    spying(O, function(calls)
        m.inCombat = true
        NS.MaybeShowSkinPicker()
        NS.HideSkinPicker()
        m.inCombat = false
        m.__fireEvent("PLAYER_REGEN_ENABLED")
        assertEqual(#calls, 0, "a dropped start must not fire on the combat edge")
    end)
end)

test("skin picker: never while the addon is switched off", function()
    local NS, _, O = setup()
    spying(O, function(calls)
        NS.SchemaRuntime.Set("enabled", false)
        assertTrue(NS.IsStoodDown(), "the switch stood the addon down")
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 0, "a disabled addon shows no picker")
    end)
end)

test("skin picker: a new profile and a reset profile show it again", function()
    -- Both start from the defaults, pickerSeen false (O3). red under: no call on reloadProfile's
    -- path, or one before the latch re-reads the new profile's switch.
    local NS, _, O = setup()
    local db = NS.addon.db
    NS.SchemaRuntime.Set(PATH, true)
    spying(O, function(calls)
        db:SetProfile("PickerProbe")
        assertEqual(#calls, 1, "a new profile shows the picker")
        NS.SchemaRuntime.Set(PATH, true)
        db:ResetProfile()
        assertEqual(#calls, 2, "a reset profile shows it again")
        NS.SchemaRuntime.Set(PATH, true)
        db:SetProfile("Default")
        assertEqual(#calls, 2, "back on a profile that has seen it: no picker")
    end)
end)

test("skin picker: a profile switched off shows no picker on its adoption", function()
    local NS, _, O = setup()
    local db = NS.addon.db
    db:SetProfile("PickerOff")
    NS.SchemaRuntime.Set("enabled", false)
    NS.SchemaRuntime.Set(PATH, true)
    db:SetProfile("Default")
    NS.SchemaRuntime.Set(PATH, true)
    db:SetProfile("PickerOff")
    NS.SchemaRuntime.Set(PATH, false)
    spying(O, function(calls)
        db:SetProfile("Default")
        db:SetProfile("PickerOff")
        assertEqual(#calls, 0, "a profile with the addon off shows nothing")
    end)
end)

-- ── over the pads (#14) ──────────────────────────────────────────────────────────────────────────

test("skin picker: a show raises the window over a pad in its own strata", function()
    -- red under: no Raise, which leaves the picker at its inherited DIALOG level under a pad's root
    -- at UIParent + HUD, taking its clicks.
    local NS, _, O = setup()
    local raised = 0
    local real = O.SkinPicker
    O.SkinPicker = function() return { Raise = function() raised = raised + 1 end } end
    local ok, err = pcall(NS.MaybeShowSkinPicker)
    O.SkinPicker = real
    if not ok then error(err, 0) end
    assertEqual(raised, 1)
end)

test("skin picker: a queued show answers as the library did and raises nothing", function()
    local NS, _, O = setup()
    local real = O.SkinPicker
    O.SkinPicker = function() return nil, "queued" end
    local f, why = NS.MaybeShowSkinPicker()
    O.SkinPicker = real
    assertTrue(f == nil, "nothing shown")
    assertEqual(why, "queued")
end)

-- ── the real window ──────────────────────────────────────────────────────────────────────────────

--- Run `fn(f, NS, m, O, Skin)` on this addon's real picker, shown.
local function onWindow(fn)
    return function()
        local NS, m, O, Skin, childrenOf = setup()
        local f = NS.MaybeShowSkinPicker()
        assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
        fn(f, NS, m, O, Skin, childrenOf)
    end
end

--- Open the window's list and click the row for skin `key`, as the player does.
local function pickRow(f, childrenOf, key)
    f.dd:__fire("OnClick")
    for _, r in ipairs(childrenOf[f.list] or {}) do
        if r.key == key then r:__fire("OnClick"); return end
    end
    error("no row for " .. key, 0)
end

--- Hide the pads, as `/qc toggle` does: the main surface hidden, test mode off.
local function padsHidden(NS)
    NS.SlashVerbs.TogglePads()
    assertTrue(not NS.SlashVerbs.PadsShown(), "the pads are hidden")
    assertTrue(not NS.Preview.IsTestMode(), "test mode is off")
end

test("skin picker: opened with the pads hidden it enters test mode, and stays in front", function()
    -- red under: minor 10's one-shot eye, or an onPreview, where nothing entered test mode at show.
    local NS = setup()
    padsHidden(NS)
    local f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
    assertTrue(NS.Preview.IsTestMode(), "the picker turned test mode on")
    assertTrue(f.preview ~= nil and f.preview:IsShown(), "the eye is shown")
    assertTrue(f.preview.lit, "and lit")
    local raised = rawget(f, "__raised")
    assertTrue(raised == nil or raised >= 1, "raised over the HUD test mode shows, where the mock counts it")
end)

test("skin picker: the eye toggles test mode off and on, and its paint follows", function()
    local NS = setup()
    padsHidden(NS)
    local f = NS.MaybeShowSkinPicker()
    f.preview:__fire("OnClick")
    assertTrue(not NS.Preview.IsTestMode(), "the eye turned test mode off")
    assertTrue(not f.preview.lit, "the eye is dimmed")
    f.preview:__fire("OnClick")
    assertTrue(NS.Preview.IsTestMode(), "the eye turned it back on")
    assertTrue(f.preview.lit, "the eye is lit")
    assertTrue(f:IsShown(), "the picker stays up over the HUD it previews")
end)

-- Every close the player or this addon makes: each puts test mode back as the picker found it.
local CLOSES = {
    { "Apply", function(f) f.apply:__fire("OnClick") end },
    { "the gear", function(f, _, O)
        O.OpenOptionsPanel = function() return true end
        O.SelectTab = function() return true end
        f.settings:__fire("OnClick")
    end },
    { "the close control", function(f) f.close:__fire("OnClick") end },
    { "Escape", function(f) f:Hide(); f:__fire("OnHide") end },
    { "the library's HideSkinPicker", function(_, _, O) O.HideSkinPicker() end },
    { "this addon's own hide (stand-down, profile event)", function(_, NS) NS.HideSkinPicker() end },
}

test("skin picker: every close puts test mode back off when the picker turned it on", function()
    for _, route in ipairs(CLOSES) do
        local NS, _, O = setup()
        local realOpen, realSelect = O.OpenOptionsPanel, O.SelectTab
        padsHidden(NS)
        local f = NS.MaybeShowSkinPicker()
        assertTrue(NS.Preview.IsTestMode(), route[1] .. ": entered at show")
        route[2](f, NS, O)
        O.OpenOptionsPanel, O.SelectTab = realOpen, realSelect
        assertTrue(not f:IsShown(), route[1] .. ": closed")
        assertTrue(not NS.Preview.IsTestMode(), route[1] .. ": test mode is off again")
        assertTrue(not NS.SlashVerbs.PadsShown(), route[1] .. ": the pads stay hidden, as they were")
    end
end)

test("skin picker: a mode on at open that the eye turned off is on again after the close", function()
    local NS = setup()
    padsHidden(NS)
    NS.Preview.SetTestMode(true)
    local f = NS.MaybeShowSkinPicker()
    assertTrue(f.preview.lit, "lit: test mode was already on")
    f.preview:__fire("OnClick")
    assertTrue(not NS.Preview.IsTestMode(), "the eye turned it off")
    f.close:__fire("OnClick")
    assertTrue(NS.Preview.IsTestMode(), "the close turned it back on")
end)

test("skin picker: pads already shown are left alone; the eye still previews and the close undoes it", function()
    local NS = setup()
    assertTrue(NS.SlashVerbs.PadsShown(), "the pads show")
    local f = NS.MaybeShowSkinPicker()
    assertTrue(not NS.Preview.IsTestMode(), "a shown surface is not entered")
    assertTrue(not f.preview.lit, "the eye is dimmed")
    f.preview:__fire("OnClick")
    assertTrue(NS.Preview.IsTestMode(), "the eye turned test mode on")
    f.close:__fire("OnClick")
    assertTrue(not NS.Preview.IsTestMode(), "the close turned it off again")
end)

test("skin picker: test mode turned on by /qc test while the picker is up stays on at the close", function()
    local NS = setup()
    local f = NS.MaybeShowSkinPicker()
    NS.Preview.ToggleTestMode()
    f.close:__fire("OnClick")
    assertTrue(NS.Preview.IsTestMode(), "the player's own verb is not the picker's to undo")
end)

test("skin picker: in combat the picker's enter is refused quietly and nothing is undone", function()
    local NS, m, O = setup()
    padsHidden(NS)
    m.__setCombat(true)
    local before = #m.prints
    local f = O.SkinPicker(NS.SkinPickerSpec())
    assertTrue(f ~= nil and f:IsShown(), "the library shows a first picker whatever the lockdown")
    assertTrue(not NS.Preview.IsTestMode(), "test mode refused in combat")
    assertEqual(#m.prints, before, "no refusal line for an enter the player did not ask for")
    f.close:__fire("OnClick")
    assertTrue(not NS.Preview.IsTestMode(), "the close undoes nothing")
    m.__setCombat(false)
end)

test("skin picker: the player's close marks it seen; this addon's own hide does not", function()
    local NS, _, O = setup()
    local f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
    NS.HideSkinPicker()
    assertTrue(not f:IsShown(), "HideSkinPicker takes it down")
    assertEqual(seen(NS), false, "this addon's own hide is not the player's close")
    f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown(), "it shows again while unseen")
    O.HideSkinPicker()
    assertEqual(seen(NS), true, "the player's close sets pickerSeen")
    assertEqual(NS.MaybeShowSkinPicker(), nil, "and it does not show again")
end)

test("skin picker: the stand-down takes the picker down, unseen", onWindow(function(f, NS)
    NS.SchemaRuntime.Set("enabled", false)
    assertTrue(not f:IsShown(), "a disabled addon keeps no picker up")
    assertEqual(seen(NS), false, "the stand-down is not the player's close")
end))

test("skin picker: a pick previews, unsaved; Apply saves it and marks the picker seen", onWindow(function(f, NS, _, _, Skin, kids)
    -- red under: a spec.set that is not the write seam, or an onClose that writes no pickerSeen.
    pickRow(f, kids, "obsidian")
    assertEqual(worn(Skin), "obsidian", "the pick is worn at once")
    assertEqual(stored(NS), "ka0s", "a pick alone writes nothing to the profile")
    assertEqual(seen(NS), false, "a pick does not end the showing")
    f.apply:__fire("OnClick")
    assertTrue(not f:IsShown(), "Apply closes the window")
    assertEqual(stored(NS), "obsidian", "Apply saves through NS.WriteSkinChoice")
    assertEqual(seen(NS), true, "Apply marks the picker seen")
end))

test("skin picker: the close control puts the old skin back, saves nothing, and marks it seen", onWindow(function(f, NS, _, _, Skin, kids)
    pickRow(f, kids, "obsidian")
    f.close:__fire("OnClick")
    assertTrue(not f:IsShown(), "the close control closes the window")
    assertEqual(worn(Skin), "ka0s", "closing puts back the stored skin")
    assertEqual(stored(NS), "ka0s", "and writes nothing")
    assertEqual(seen(NS), true, "a close by the player still counts as seen")
end))

test("skin picker: a profile switch with a pick pending wears the new profile's skin", onWindow(function(f, NS, _, _, Skin, kids)
    -- reloadProfile takes the picker down BEFORE it applies the new profile's skin, so the
    -- library's put-back cannot land over it. red under: HideSkinPicker after NS.ApplySkinChoice.
    local db = NS.addon.db
    db:SetProfile("PickerEmber")
    NS.WriteSkinChoice("ka0s", "ember")
    NS.SchemaRuntime.Set(PATH, true)
    db:SetProfile("Default")
    f = NS.MaybeShowSkinPicker() or f
    pickRow(f, kids, "obsidian")
    assertEqual(worn(Skin), "obsidian", "the pick is worn")
    db:SetProfile("PickerEmber")
    assertTrue(not f:IsShown(), "the switch took the picker down")
    assertEqual(worn(Skin), "ember", "the new profile's skin is the one worn")
    assertEqual(stored(NS), "ember")
end))

test("skin picker: the gear saves the pick and opens General on its Skin tab", onWindow(function(f, NS, _, O, _, kids)
    -- red under: a page key the library cannot open, or a tab key that is not the Skin tab's.
    local realOpen, realSelect = O.OpenOptionsPanel, O.SelectTab
    local opened, selected = {}, {}
    O.OpenOptionsPanel = function(page) opened[#opened + 1] = page; return true end
    O.SelectTab = function(page, tab) selected[#selected + 1] = { page, tab }; return true end
    local ok, err = pcall(function()
        pickRow(f, kids, "obsidian")
        f.settings:__fire("OnClick")
        assertEqual(opened[1], "general", "the gear opens the General page")
        assertTrue(selected[1] ~= nil, "the gear selects a tab")
        assertEqual(selected[1][1], "general")
        assertEqual(selected[1][2], "Appearance", "the Skin tab")
        assertEqual(stored(NS), "obsidian", "the gear saves the pending pick")
        assertEqual(seen(NS), true, "and marks the picker seen")
    end)
    O.OpenOptionsPanel, O.SelectTab = realOpen, realSelect
    if not ok then error(err, 0) end
end))

-- The owner's "no separator line below header", skin selectors named (Ka0sAddonsCommonTasks
-- docs/2026-11-03-SMOKE_ROUND4/R4_SIGNOFF.md, R4-SEP): the picker is a window, so no line under its
-- title, before and after a live switch. A divider that is present must at least be hidden.
test("skin picker: the window shows no line under its title, before and after a switch (R4-SEP)", onWindow(function(f, _, _, _, Skin)
    local function noRule(what)
        local divider = rawget(f, "divider")
        assertTrue(divider == nil or not divider:IsShown(), what)
    end
    noRule("no line under the picker's title")
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    noRule("no line under the picker's title under Obsidian")
end))

-- ── without the library ──────────────────────────────────────────────────────────────────────────

test("skin picker: without LibKa0s nothing shows and nothing raises", function()
    local NS = T.enableAddon({ skip = T.loadAddon.libFiles })
    assertEqual(NS.MaybeShowSkinPicker(), nil, "the stub's SkinPicker draws nothing")
    NS.HideSkinPicker()
    assertEqual(type(NS.SkinPickerSpec().onClose), "function")
end)
