-- tests/page_helpers.lua — drives an editor page the way a player does, on a fresh environment.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit; shaped after
-- AuraMaster's tests/page_helpers.lua. The kit's AceGUI fake records every widget it hands out
-- (`__created`) and exposes `__fire`, and the kit's panels expose `__fire` for the deferred OnShow
-- render, so a page can be drawn and clicked headlessly. `redraw` runs a page's whole render as a
-- tab click or a repaint does; `tab` is a tab click (the library sets `activeTab` and calls the
-- page's `rerender`).
return function(NS, m)
    local P = {}
    local ace = m.LibStub("AceGUI-3.0")
    local Settings = NS.addon.Settings
    local H = Settings.Helpers

    local function since(mark)
        local out = {}
        for i = mark + 1, #ace.__created do
            local w = ace.__created[i]
            if not w.__released then out[#out + 1] = w end
        end
        return out
    end

    function P.ctx(pageKey) return H.__panelFor(pageKey) end

    --- Fire a page's OnShow by its sidebar title; answers the widgets the render drew.
    function P.show(title)
        local mark = #ace.__created
        m.__subcategories[title]:__fire("OnShow")
        return since(mark)
    end

    --- Run a page's whole render now; answers the widgets it drew.
    function P.redraw(pageKey)
        local mark = #ace.__created
        Settings.Editors.redraw[pageKey](P.ctx(pageKey))
        return since(mark)
    end

    --- A tab click: the active tab moves and the page's rerender draws it.
    function P.tab(pageKey, key)
        P.ctx(pageKey).activeTab = key
        return P.redraw(pageKey)
    end

    --- The widgets `fn` creates while it runs.
    function P.during(fn)
        local mark = #ace.__created
        fn()
        return since(mark)
    end

    --- Run the deferred repaint (Editors.RequestRefresh) and every other queued timer.
    function P.flush() m.__fireTimers() end

    function P.find(widgets, wtype, label)
        for _, w in ipairs(widgets) do
            if (wtype == nil or w.type == wtype) and (w.labelText == label or w.text == label) then return w end
        end
        return nil
    end

    function P.all(widgets, wtype, label)
        local out = {}
        for _, w in ipairs(widgets) do
            if w.type == wtype and (label == nil or w.labelText == label or w.text == label) then out[#out + 1] = w end
        end
        return out
    end

    --- The texts of the Label and InteractiveLabel widgets, in draw order.
    function P.texts(widgets)
        local out = {}
        for _, w in ipairs(widgets) do
            if (w.type == "Label" or w.type == "InteractiveLabel") and w.text then out[#out + 1] = w.text end
        end
        return out
    end

    function P.hasText(widgets, needle)
        for _, t in ipairs(P.texts(widgets)) do
            if t:find(needle, 1, true) then return true end
        end
        return false
    end

    -- The live AceGUI widget of `wtype` whose frame the library's chrome ledger lists.
    local function inBand(ctx, wtype)
        local band = {}
        for _, f in ipairs(ctx and ctx.__chromeKids or {}) do band[f] = true end
        for i = #ace.__created, 1, -1 do
            local w = ace.__created[i]
            if w.type == wtype and w.frame and band[w.frame] and not w.__released then return w end
        end
        return nil
    end

    --- The page banner's picker (O.PageBanner's Dropdown) and its create action (its Button).
    function P.banner(ctx) return inBand(ctx, "Dropdown") end
    function P.bannerAction(ctx) return inBand(ctx, "Button") end

    --- Accept the last popup shown, as the player's Yes does.
    function P.accept()
        local shown = m.popupsShown[#m.popupsShown]
        m.StaticPopupDialogs[shown[1]].OnAccept(nil, shown[4])
    end

    --- Record every ReorderList built from here on: { opts, rows } per list, latest last.
    function P.reorderSpy()
        local W = m.LibStub("LibKa0s-Widgets-1.0")
        local real = W.ReorderList
        local lists = {}
        W.ReorderList = function(opts)
            local r = real(opts)
            local seen = { opts = opts, rows = 0 }
            lists[#lists + 1] = seen
            local add = r.AddRow
            r.AddRow = function(self, ...)
                seen.rows = seen.rows + 1
                return add(self, ...)
            end
            return r
        end
        return lists
    end

    return P
end
