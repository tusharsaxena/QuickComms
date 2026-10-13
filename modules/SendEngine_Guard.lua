local _, NS = ...
-- modules/SendEngine_Guard.lua — the send engine's PURE decisions (spec §9.1-§9.3): the soft spam
-- guard's timing, which click edge a secure button acts on, the echo tracker that infers a drop
-- from a missing CHAT_MSG_* echo, and the keyed combat-end queue. Plain values in, plain values
-- out; no client call, no frame. modules/SendEngine.lua is the edge that feeds it.
--
-- THE GUARD IS SOFT (owner, 2026-10-13; C5 unverified): insecure code cannot cancel a secure
-- click, so Decide only classifies a press. A "guarded" press still reaches the game; the pads dim
-- for the window to discourage it, and the echo tracker reports the drop if the game swallows it.
--
-- THE ECHO NEVER READS TEXT (F7). It matches on the chat type and, when it can be read, on whether
-- the sender is the player. An unreadable (secret) sender is UNKNOWN (C6 unverified): it may be
-- our echo, so it consumes the oldest pending press of that type and is never counted as a drop.
-- Other players' messages on the channel can still mask a drop: accepted as best effort (§9.3).

NS.SendGuard = NS.SendGuard or {}
local G = NS.SendGuard

-- Seconds a press waits for its echo (spec §9.3; the measured round trip was 0.5-0.75 s).
G.ECHO_WINDOW = 1.5

-- The player's own channels, by the event that echoes them. Never a guild or custom channel (§8.4).
G.CHAT_TYPE_BY_EVENT = {
    CHAT_MSG_SAY = "SAY",
    CHAT_MSG_YELL = "YELL",
    CHAT_MSG_PARTY = "PARTY",
    CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID",
    CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_RAID_WARNING = "RAID_WARNING",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
}

G.ECHO_EVENTS = {}
for event in pairs(G.CHAT_TYPE_BY_EVENT) do G.ECHO_EVENTS[#G.ECHO_EVENTS + 1] = event end
table.sort(G.ECHO_EVENTS)

-- ── the click and the guard ─────────────────────────────────────────────────────────────────

--- True on the edge the secure template acts on. A button registered for AnyUp and AnyDown hears
--- both edges in its OnClick hook; the action fires on one of them (go/no-go finding 6).
--- @param down boolean|nil the hook's `down` argument
--- @param useKeyDown boolean|nil the useOnKeyDown attribute, else the ActionButtonUseKeyDown cvar
--- @return boolean
function G.IsActingEdge(down, useKeyDown)
    return (down and true or false) == (useKeyDown and true or false)
end

--- Classify a press against the last one (spec §9.2). Never a cancel: the press is sent either way.
--- @return string "ok" | "guarded"
function G.Decide(now, last, window)
    if type(now) ~= "number" or type(last) ~= "number" or type(window) ~= "number" then return "ok" end
    if now - last < window then return "guarded" end
    return "ok"
end

--- Seconds left in the guard window, never negative.
function G.Remaining(now, last, window)
    if type(now) ~= "number" or type(last) ~= "number" or type(window) ~= "number" then return 0 end
    return math.max(0, window - (now - last))
end

-- ── the echo tracker ────────────────────────────────────────────────────────────────────────

function G.NewEcho()
    return { pending = {}, sent = 0, dropped = 0, unknown = 0, ignored = 0 }
end

--- Remember a press that should come back as a CHAT_MSG_* of `chatType`.
function G.Record(e, at, chatType, meta)
    e.pending[#e.pending + 1] = { at = at, chatType = chatType, meta = meta }
end

--- An echo arrived. `fromMe` is true (the player sent it), false (someone else did) or nil (the
--- sender could not be read). Consumes and returns the oldest matching press within the window.
--- @return table|nil entry
function G.Match(e, chatType, now, fromMe)
    if chatType == nil then return nil end
    if fromMe == false then
        e.ignored = e.ignored + 1
        return nil
    end
    for i, p in ipairs(e.pending) do
        if p.chatType == chatType and type(now) == "number" and now - p.at <= G.ECHO_WINDOW then
            table.remove(e.pending, i)
            e.sent = e.sent + 1
            if fromMe == nil then e.unknown = e.unknown + 1 end
            return p
        end
    end
    return nil
end

--- The presses whose window has passed with no echo, oldest first: each one is a drop.
--- @return table entries
function G.Expire(e, now)
    local out, keep = {}, {}
    for _, p in ipairs(e.pending) do
        if type(now) == "number" and now - p.at > G.ECHO_WINDOW then
            out[#out + 1] = p
        else
            keep[#keep + 1] = p
        end
    end
    e.pending = keep
    e.dropped = e.dropped + #out
    return out
end

-- ── the keyed combat-end queue (spec §9.1) ──────────────────────────────────────────────────

function G.NewQueue()
    return { keys = {}, fns = {} }
end

--- File `fn` under `key`, replacing an earlier entry under the same key (which keeps its place).
--- @return boolean replaced
function G.Put(q, key, fn)
    local replaced = q.fns[key] ~= nil
    if not replaced then q.keys[#q.keys + 1] = key end
    q.fns[key] = fn
    return replaced
end

--- Every entry in filing order, emptying the queue.
function G.Take(q)
    local out = {}
    for i, key in ipairs(q.keys) do out[i] = { key = key, fn = q.fns[key] } end
    q.keys, q.fns = {}, {}
    return out
end

function G.Keys(q)
    local out = {}
    for i, key in ipairs(q.keys) do out[i] = key end
    return out
end

function G.Count(q)
    return #q.keys
end
