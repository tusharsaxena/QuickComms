# Go/no-go test record (issue #6)

Run in game on 2026-10-11 (client 12.1, interface 120100) with the throwaway harness in [`harness/`](harness/). Issue: [#6](https://github.com/tusharsaxena/QuickComms/issues/6), closed as done. The plan and summary results are in §13 of [`../04-brainstorm.md`](../04-brainstorm.md).

**Verdict: GO.** A secure button running macro text, pressed by the player with a click or a key binding, sends group chat during Midnight chat lockdown. That held in a real M+ key (trash and boss), a real LFR boss, and under every forced restriction. Addon Lua calling `C_ChatInfo.SendChatMessage` is blocked in all of them.

## The harness

`QCTest` is a movable panel with four buttons and a status line that shows chat lockdown, combat and channel.

| Button | What it does |
|---|---|
| **0 Baseline** | Plain `Button`; its `OnClick` calls `C_ChatInfo.SendChatMessage(...)`. It should be blocked. |
| **A Secure macrotext** | `SecureActionButtonTemplate`, `type=macro`, `macrotext="/p QC test A (secure macrotext)"` |
| **B Real macro** | `SecureActionButtonTemplate`, `type=macro`, `macro="QCTEST_B"`. The macro is a per-character macro created with `CreateMacro`. |
| **T Tokens** | Like A, with `macrotext="/p QC tokens: target=%t mark={rt8} g1={g1}"` |

The slash commands are:
- `/qct ch p|i|raid|rw` sets the channel.
- `/qct bind KEY` uses `SetOverrideBindingClick` to bind a key to A.
- `/qct status` prints the lockdown state and every console variable whose name contains "restrict".

The harness logs:
- every click, with its `GetTime()`
- every party, instance or raid message that arrives, with its time; it doesn't read the message text, which can be secret
- `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN` and `ADDON_RESTRICTION_STATE_CHANGED`

## Findings

1. **Path A works.** Secure `macrotext` sent every time it was tested: forced lockdown, a real LFR boss, and a real M+ key on trash and on a boss. It worked from a mouse click and from a key binding (F6).
2. **Path B works too,** but it isn't needed. Real macros behave the same as A, so the design does not need a macro-slot budget.
3. **The baseline is always blocked.** Button 0 raised `ADDON_ACTION_BLOCKED UNKNOWN()` in every context, which shows each test really was under lockdown.
4. **Latency:** a message arrives back about 0.5–0.75 s after the click.
5. **During bosses, the game silently drops sends that are too close together.**

   | Context | Spacing | Result |
   |---|---|---|
   | LFR boss | 0.27 s | 3 → 2 |
   | M+ boss | ≈0.5 s | 3 → 2 |
   | LFR boss | ≈0.8 s | 3 → 3 |
   | M+ trash | ≈0.5 s | 3 → 3 |
   | Out of combat in M+ | ≈0.5 s | 3 → 3 |

   So bosses throttle sends roughly 0.5–0.8 s apart, and the game gives no error. **The design needs a per-button cooldown of about 1 s, with a visible sent or dropped cue.**
6. **A single key press sends once.** A secure button registered for `AnyUp` and `AnyDown` and bound with `SetOverrideBindingClick` did not double-fire on key-down and key-up. Three F6 presses gave at most three sends, never six.
7. **Tokens:**

   | Token | Result |
   |---|---|
   | `%t` | The target's name, or `<no target>`. A player target also gets their class or role icon. |
   | `{rt8}` | The skull icon. |
   | `{gN}` | In a raid, the names of the members of raid subgroup N. In a party it stays as the literal `{g1}`; in the follower dungeon it arrived as `\|g\|`. It is usable only in raids, and it is noisy. |

8. **Lockdown covers the whole M+ key.** Chat lockdown turned on when the key started and stayed on out of combat. The secure path sent the whole time.
9. **The console variables used to force lockdown,** as listed by the client:
   - `addonChatRestrictionsForced`
   - `addonEncounterRestrictionsForced`
   - `addonChallengeModeRestrictionsForced`
   - `addonPvPMatchRestrictionsForced`
   - `addonCombatRestrictionsForced`
   - `addonMapRestrictionsForced`

   **`secretEncounterRestrictionsForced` does not exist.** `GetCVar` returns `nil` for it, and `/console` silently ignores it.
10. **API notes:**
    - `C_Console` is nil in 12.1; the global `ConsoleGetAllCommands()` does exist.
    - `ADDON_RESTRICTION_STATE_CHANGED` exists and fired when the M+ key started.
    - `C_ChatInfo.InChatMessagingLockdown()` reported the lockdown state correctly throughout.

## Raw output

Everything below is the output exactly as the user shared it. Times are `GetTime()` seconds.

### Setup: finding the console variables

Status before and after `/console secretEncounterRestrictionsForced 1`. Nothing changed, because no such variable exists:

```
09:37:28 QCTest chat lockdown: ON   combat: no   channel: /i
09:37:28 QCTest addonChatRestrictionsForced = 1
09:37:28 QCTest secretEncounterRestrictionsForced = nil
09:37:28 QCTest addonChallengeModeRestrictionsForced = 0
```

The first listing attempt, which used `C_Console.GetAllCommands`:

```
09:43:12 QCTest chat lockdown: ON   combat: no   channel: /p
09:43:12 QCTest could not list console variables: Interface/AddOns/QCTest/QCTest.lua:156: attempt to index global 'C_Console' (a nil value)
```

The listing through `ConsoleGetAllCommands`:

```
09:44:29 QCTest chat lockdown: ON   combat: no   channel: /p
09:44:29 QCTest characterSocialRestrictionSettingsApplied = 0
09:44:29 QCTest addonChallengeModeRestrictionsForced = 0
09:44:29 QCTest addonEncounterRestrictionsForced = 0
09:44:29 QCTest addonMapRestrictionsForced = 0
09:44:29 QCTest addonCombatRestrictionsForced = 0
09:44:29 QCTest restrictCalendarInvites = 1
09:44:29 QCTest addonPvPMatchRestrictionsForced = 0
09:44:29 QCTest addonChatRestrictionsForced = 1
09:44:29 QCTest 8 matching console variables
```

### Round 1: forced lockdown, follower dungeon, channel `/i`

Each forced variable was added on top of the ones before it.

#### Boss pull: `/console addonEncounterRestrictionsForced 1`

```
09:49:04 QCTest chat lockdown: ON   combat: no   channel: /i
09:49:04 QCTest characterSocialRestrictionSettingsApplied = 0
09:49:04 QCTest addonChallengeModeRestrictionsForced = 0
09:49:04 QCTest addonEncounterRestrictionsForced = 1
09:49:04 QCTest addonMapRestrictionsForced = 0
09:49:04 QCTest addonCombatRestrictionsForced = 0
09:49:04 QCTest restrictCalendarInvites = 1
09:49:04 QCTest addonPvPMatchRestrictionsForced = 0
09:49:04 QCTest addonChatRestrictionsForced = 1
09:49:04 QCTest 8 matching console variables
```

Out of combat ([screenshot](screenshots/01-follower-encounter-ooc.png)):

```
09:49:33 QCTest click 0 at 150606.52
09:49:33 QCTest ADDON_ACTION_BLOCKED UNKNOWN()
09:49:34 QCTest click A at 150607.57
09:49:34 QCTest INSTANCE_CHAT_LEADER arrived at 150608.16
09:49:35 QCTest click B at 150608.67
09:49:36 QCTest INSTANCE_CHAT_LEADER arrived at 150609.29
09:49:36 QCTest click T at 150609.62
09:49:37 QCTest INSTANCE_CHAT_LEADER arrived at 150610.20
```

In combat ([screenshot](screenshots/02-follower-encounter-combat.png)):

```
:50:30 QCTest click 0 at 150663.87
09:50:30 QCTest ADDON_ACTION_BLOCKED UNKNOWN()
09:50:31 QCTest click A at 150664.56
09:50:31 QCTest INSTANCE_CHAT_LEADER arrived at 150665.17
09:50:32 QCTest click B at 150665.36
09:50:32 QCTest INSTANCE_CHAT_LEADER arrived at 150665.96
09:50:32 QCTest click T at 150666.17
09:50:33 QCTest INSTANCE_CHAT_LEADER arrived at 150666.82
```

#### M+ key: `/console addonChallengeModeRestrictionsForced 1`

```
QCTest restriction state changed: chat lockdown: ON   combat: no   channel: /i
QCTest chat lockdown: ON   combat: no   channel: /i
QCTest characterSocialRestrictionSettingsApplied = 0
QCTest addonChallengeModeRestrictionsForced = 1
QCTest addonEncounterRestrictionsForced = 1
QCTest addonMapRestrictionsForced = 0
QCTest addonCombatRestrictionsForced = 0
QCTest restrictCalendarInvites = 1
QCTest addonPvPMatchRestrictionsForced = 0
QCTest addonChatRestrictionsForced = 1
QCTest 8 matching console variables
```

Out of combat ([screenshot](screenshots/03-follower-challengemode-ooc.png)):

```
QCTest INSTANCE_CHAT_LEADER arrived at 150726.46
QCTest click 0 at 150728.71
QCTest ADDON_ACTION_BLOCKED UNKNOWN()
QCTest click A at 150730.10
QCTest INSTANCE_CHAT_LEADER arrived at 150730.80
QCTest click B at 150731.31
QCTest INSTANCE_CHAT_LEADER arrived at 150731.82
QCTest click T at 150732.51
QCTest INSTANCE_CHAT_LEADER arrived at 150733.10
```

In combat ([screenshot](screenshots/04-follower-challengemode-combat.png)):

```
QCTest click 0 at 150780.10
QCTest ADDON_ACTION_BLOCKED UNKNOWN()
QCTest click A at 150781.16
QCTest INSTANCE_CHAT_LEADER arrived at 150781.75
QCTest click B at 150782.12
QCTest INSTANCE_CHAT_LEADER arrived at 150782.71
QCTest click T at 150783.00
QCTest INSTANCE_CHAT_LEADER arrived at 150783.59
```

#### PvP match: `/console addonPvPMatchRestrictionsForced 1`

```
QCTest chat lockdown: ON   combat: no   channel: /i
QCTest characterSocialRestrictionSettingsApplied = 0
QCTest addonChallengeModeRestrictionsForced = 1
QCTest addonEncounterRestrictionsForced = 1
QCTest addonMapRestrictionsForced = 0
QCTest addonCombatRestrictionsForced = 0
QCTest restrictCalendarInvites = 1
QCTest addonPvPMatchRestrictionsForced = 1
QCTest addonChatRestrictionsForced = 1
QCTest 8 matching console variables
```

Out of combat ([screenshot](screenshots/05-follower-pvpmatch-ooc.png)):

```
QCTest INSTANCE_CHAT_LEADER arrived at 150991.44
QCTest click 0 at 150994.84
QCTest ADDON_ACTION_BLOCKED UNKNOWN()
QCTest click A at 150995.92
QCTest INSTANCE_CHAT_LEADER arrived at 150996.67
QCTest click B at 150996.68
QCTest INSTANCE_CHAT_LEADER arrived at 150997.30
QCTest click T at 150997.49
QCTest INSTANCE_CHAT_LEADER arrived at 150998.13
```

In combat ([screenshot](screenshots/06-follower-pvpmatch-combat.png)):

```
QCTest click 0 at 151032.99
QCTest ADDON_ACTION_BLOCKED UNKNOWN()
QCTest click A at 151033.77
QCTest INSTANCE_CHAT_LEADER arrived at 151034.37
QCTest click B at 151034.64
QCTest INSTANCE_CHAT_LEADER arrived at 151035.24
QCTest click T at 151035.47
QCTest INSTANCE_CHAT_LEADER arrived at 151036.07
```

#### Combat: `/console addonCombatRestrictionsForced 1`

```
QCTest chat lockdown: ON   combat: no   channel: /i
QCTest characterSocialRestrictionSettingsApplied = 0
QCTest addonChallengeModeRestrictionsForced = 1
QCTest addonEncounterRestrictionsForced = 1
QCTest addonMapRestrictionsForced = 0
QCTest addonCombatRestrictionsForced = 1
QCTest restrictCalendarInvites = 1
QCTest addonPvPMatchRestrictionsForced = 1
QCTest addonChatRestrictionsForced = 1
QCTest 8 matching console variables
```

Out of combat ([screenshot](screenshots/07-follower-combat-ooc.png)):

```
QCTest click 0 at 151225.90
QCTest ADDON_ACTION_BLOCKED UNKNOWN()
QCTest click A at 151226.95
QCTest INSTANCE_CHAT_LEADER arrived at 151227.58
QCTest click B at 151227.89
QCTest INSTANCE_CHAT_LEADER arrived at 151228.40
QCTest click T at 151228.73
QCTest INSTANCE_CHAT_LEADER arrived at 151229.33
```

In combat ([screenshot](screenshots/08-follower-combat-combat.png)):

```
QCTest click 0 at 151185.93
QCTest ADDON_ACTION_BLOCKED UNKNOWN()
QCTest click A at 151186.80
QCTest INSTANCE_CHAT_LEADER arrived at 151187.52
QCTest click B at 151187.93
QCTest INSTANCE_CHAT_LEADER arrived at 151188.56
QCTest click T at 151188.81
QCTest INSTANCE_CHAT_LEADER arrived at 151189.40
```

#### After the reset attempt

`addonChatRestrictionsForced` was still 1 here and was set to 0 later:

```
10:01:14 QCTest chat lockdown: ON   combat: no   channel: /i
10:01:14 QCTest characterSocialRestrictionSettingsApplied = 0
10:01:14 QCTest addonChallengeModeRestrictionsForced = 0
10:01:14 QCTest addonEncounterRestrictionsForced = 0
10:01:14 QCTest addonMapRestrictionsForced = 0
10:01:14 QCTest addonCombatRestrictionsForced = 0
10:01:14 QCTest restrictCalendarInvites = 1
10:01:14 QCTest addonPvPMatchRestrictionsForced = 0
10:01:14 QCTest addonChatRestrictionsForced = 1
10:01:14 QCTest 8 matching console variables
```

### Round 2: real LFR boss, no forced settings, channel `/i`

```
QCTest chat lockdown: ON   combat: yes   channel: /i
QCTest characterSocialRestrictionSettingsApplied = 0
QCTest addonChallengeModeRestrictionsForced = 0
QCTest addonEncounterRestrictionsForced = 0
QCTest addonMapRestrictionsForced = 0
QCTest addonCombatRestrictionsForced = 0
QCTest restrictCalendarInvites = 1
QCTest addonPvPMatchRestrictionsForced = 0
QCTest addonChatRestrictionsForced = 0
QCTest 8 matching console variables
```

Buttons clicked during the boss ([screenshot](screenshots/09-lfr-boss-buttons.png); `{g1}` expanded to the names in raid group 1):

```
QCTest click 0 at 151748.23
QCTest ADDON_ACTION_BLOCKED UNKNOWN()
QCTest click A at 151749.08
QCTest INSTANCE_CHAT arrived at 151749.67
QCTest click B at 151749.89
QCTest INSTANCE_CHAT arrived at 151750.49
QCTest click T at 151750.70
QCTest INSTANCE_CHAT arrived at 151751.33
```

F6, bound to A with `/qct bind F6`, pressed three times quickly during the boss. Only two messages arrived ([screenshot](screenshots/10-lfr-boss-f6-burst.png)):

```
QCTest click A at 151777.24
QCTest click A at 151777.51
QCTest click A at 151777.79
QCTest INSTANCE_CHAT arrived at 151777.82
QCTest INSTANCE_CHAT arrived at 151778.37
```

### Round 3: real M+ key, no forced settings, channel `/p`

Out of combat and on trash ([screenshot](screenshots/11-mplus-key.png)). The arrivals at 152618.48 and 152637.04 are other players' party messages.

```
QCTest click 0 at 152584.78
QCTest ADDON_ACTION_BLOCKED UNKNOWN()
QCTest click A at 152585.16
QCTest click B at 152585.65
QCTest PARTY arrived at 152585.79
QCTest click T at 152586.16
QCTest restriction state changed: chat lockdown: ON   combat: no   channel: /p
QCTest PARTY arrived at 152586.31
QCTest PARTY arrived at 152586.78
QCTest click 0 at 152608.60
QCTest ADDON_ACTION_BLOCKED UNKNOWN()
QCTest click A at 152609.13
QCTest click B at 152609.63
QCTest PARTY arrived at 152609.84
QCTest click T at 152610.16
QCTest PARTY arrived at 152610.39
QCTest PARTY arrived at 152610.97
QCTest PARTY arrived at 152618.48
QCTest PARTY arrived at 152637.04
```

Boss. Three clicks about 0.5 s apart produced two arrivals:

```
QCTest click 0 at 152823.83
QCTest ADDON_ACTION_BLOCKED UNKNOWN()
QCTest click A at 152824.42
QCTest click B at 152824.98
QCTest PARTY arrived at 152825.06
QCTest click T at 152825.47
QCTest PARTY arrived at 152825.61
```
