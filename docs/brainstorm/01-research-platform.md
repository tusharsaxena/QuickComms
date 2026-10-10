# Research 01: What the 12.x client allows

Brainstorm input, gathered 2026-10-11 against retail 12.1.5. Sources are linked inline. Items marked **(verify in game)** came from secondhand reports or were not confirmed by Blizzard's API docs.

## The finding that shapes everything: chat messaging lockdown

Midnight (12.0) added **addon restrictions**. While a restriction is active, any chat send that originates from addon (tainted) code is refused with `ADDON_ACTION_BLOCKED`.

- **The state you can query:** `C_ChatInfo.InChatMessagingLockdown()`, plus `C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.X)`. The types are `Combat`, `Encounter`, `ChallengeMode`, `PvPMatch`, `Map` and `Chat`.
- **The event:** `ADDON_RESTRICTION_STATE_CHANGED` fires *before* a restriction becomes active and *after* it lifts.
  ([ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua), [Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values))
- **When it is on:** during any **boss encounter**, for the whole of an **active Mythic+ key** (trash included), during **PvP matches**, and on "communication-restricted maps".
  ([Planned API changes, 12.0.0](https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes), [EllesmereUI PR #1292](https://github.com/EllesmereGaming/EllesmereUI/pull/1292), [Name2Chat changelog](https://github.com/gOOvER/Name2Chat/blob/master/CHANGELOG.md))
- **What still works during lockdown:** Blizzard's own UI, meaning the chat edit box and **secure macro buttons**. Blizzard's macro rules for encounters (live since March 2026):
  - Macros **can** send to `/raid`, `/party`, `/rw` and instance chat, but are throttled ("prevented from sending multiple messages within a very short time").
  - Every group member must be inside the instance.
  - Whispers work only to targets inside the instance.
  - Guild, community and custom channels are blocked.
  - Macros can mark at most 3 units in a very short window.

  ([MMO-Champion: Midnight macro changes](https://www.mmo-champion.com/content/14060-Midnight-Macro-Changes-Now-Live-Target-Markers-and-Chat-Messages))

A hardware event (a click) does **not** lift lockdown. The block is about taint, not about whether a click happened.

### Two send paths

| Path | How | Works when | Limits |
|---|---|---|---|
| **Direct** | `C_ChatInfo.SendChatMessage` from addon code on click | Open world, dungeon and raid trash between bosses, normal/heroic dungeons; works in combat | Blocked during lockdown. SAY, YELL and CHANNEL need a hardware event outdoors. |
| **Secure** | `SecureActionButtonTemplate` with `type="macro"` and macro text built **out of combat** (OPie-style `SecureHandler` for the dial) | Everywhere, including M+ keys and boss pulls | Only party, raid, rw and instance (plus whispers to targets in the instance) during encounters. Text is frozen until combat drops. Rate-limited during encounters. |

**Brainstorm implication:** the dial and the pad should **always** send through secure buttons for group channels. That is the only path that works in the moments that matter most (pull, lust, interrupt calls). The direct path is useful for what secure macros can't do well: whispers, SAY and YELL with live tokens, and anything sent outside combat.

**Open risk to spike first (verify in game):** a secondary source says `macrotext` on secure buttons became *protected* in 12.0, and that some addons (for example MarkerBar) moved to creating real character macros instead. If that is true, every callout costs a macro slot, which is a real budget (120 account, 30 per character). Settle this with `/console addonChatRestrictionsForced 1` and the Blizzard test encounter on the beach outside The MOTHERLODE!! before any design is final.

## Limits and channels

- **Length:** 255 characters; longer messages are truncated. The editor needs a live counter.
- **RAID_WARNING:** needs raid leader or assistant in a raid. In a party (not a raid) any member can send it.
- **INSTANCE_CHAT:** for LFG/LFR groups, battlegrounds and arenas.
- **The canonical "smart group" resolution** (from the wiki):
  `IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or IsInRaid() and "RAID" or "PARTY"`
  On the secure path a macro conditional does the same job: `/raid [group:raid]` …
- **Whisper target:** `GetUnitName("target", true)` returns `Name-Realm`. During encounters a whisper only reaches targets inside the instance.
- **Throttle:** ChatThrottleLib protects against disconnects from spamming the server but does nothing about lockdown. Use per-callout cooldowns in the UI as well.

### A note from our own collection
MultiMeters removed its "AUTO" export channel on purpose. Guessing who will see a message was judged unsafe, and its default is SELF, which sends nothing (`MultiMeters/core/Constants.lua`). A **smart group** channel is safer than AUTO because its resolution is deterministic (instance > raid > party). It still needs a defined **solo fallback**: do nothing, print to self, or SAY.

## Tokens and substitutions

| Token | Who resolves it | Safe in lockdown? |
|---|---|---|
| `%t` target name, `%f` focus name | **The game client**, at send time ([Chat substitutions](https://warcraft.wiki.gg/wiki/Chat_substitutions)) | Yes. This is the *only* way to name an instance NPC, because addon code can't read secret creature names in 12.x. |
| `{rt1}`–`{rt8}`, `{skull}` … | Each **receiving** client renders the icon | Yes. Use `{rtN}` because it works in every locale. |
| `{g1}`–`{g8}` raid group names | Chat edit box only | Unclear on the macro path **(verify in game)** |
| `%m` mouseover | Not documented | Treat as unsupported |
| Player name, spec, role, key level, dungeon name | **Addon**, at bake time | Yes, if baked into the macro text before combat |
| Spell links (`C_Spell.GetSpellLink(id)`) | Addon | Yes for a fixed spell ID. **Not** for the target's current cast, which is secret. |

**Implication:** the editor should show tokens as chips and quietly map friendly names onto engine tokens (`{target}` becomes `%t`). Tokens the addon has to compute are re-baked whenever the situation changes out of combat.

## Bindings and the dial

- `SetOverrideBindingClick` is **protected in combat**. Bind the dial key out of combat; the binding persists through combat.
- Inside a `SecureHandler` snippet, frame handles can call `SetBindingClick` and `SetAttribute` **during combat**. OPie uses this to grab the mouse buttons and wheel while a ring is open and release them on key-up.
- `SECURE_ACTIONS.macro` runs `C_Macro.RunMacroText`. A snippet can choose `/raid` or `/p` with `SecureCmdOptionParse`.
- **New in 12.0:** `SECURE_ACTIONS.raidtarget` (with `set`, `clear`, `toggle` …) allows a **"mark + callout"** slice: put a skull on the target *and* say "kill {rt8} first".
- **The Blizzard ping wheel cannot be reused.** `C_PingSecure` is secure-only and its bindings are hard-coded. Its *visual* widget (`RadialWheelFrameMixin` in `Blizzard_SharedXML/Blizzard_RadialWheel.lua`) is plain insecure code, so copying its look is fine.

## Detecting the situation (12.x status)

All of these are safe to read for the player and the group:

| Situation | API |
|---|---|
| Instance kind and difficulty | `GetInstanceInfo()`: `instanceType`, `difficultyID`, `instanceID`. Difficulties: dungeon N 1, H 2, M 23, Keystone 8, Follower 205; raid LFR 17, N 14, H 15, M 16, Story 220; Delve 208; PvP 34 |
| Mythic+ key | `C_ChallengeMode.GetActiveChallengeMapID()`, `GetActiveKeystoneInfo()` (level, affixes), `GetMapUIInfo(mapID)` (name) |
| Boss | `ENCOUNTER_START` / `ENCOUNTER_END` (encounterID, difficulty) |
| Lockdown | `C_ChatInfo.InChatMessagingLockdown()`, `ADDON_RESTRICTION_STATE_CHANGED` |
| Class, spec, role | `UnitClass("player")`, `C_SpecializationInfo`, `UnitGroupRolesAssigned("player")` |
| Leader or assist (for RW) | `UnitIsGroupLeader("player")`, `UnitIsGroupAssistant("player")` |
| Group shape | `IsInGroup`, `IsInRaid`, `IsInGroup(LE_PARTY_CATEGORY_INSTANCE)` |
| PvP | `instanceType` "arena" / "pvp", `C_PvP.IsRatedBattleground()` |
| Housing | `C_Housing.IsInsideHouseOrPlot()` |
| Zone | `C_Map.GetBestMapForUnit("player")`, `ZONE_CHANGED_NEW_AREA` |

Match by **ID**, never by localized name (Ka0s localization rule). DropWatcher's `modules/Situations.lua` already classifies most of this with a pure function and should be reused.

## Prior art in the addon space

- **Easy Chat Channel Buttons** has "Prepared Phrase" buttons that *insert into the edit box* without sending, so the player presses Enter. It avoids lockdown, but pre-filling the edit box has tainted the send path for other addons.
- **BattlegroundCallouts (BChip)** has per-battleground buttons. It was last updated for 11.0.7 and is almost certainly broken by PvP-match lockdown.
- **OPie** is the radial standard. People hand-build chat-macro rings for it.
- **There is a gap:** no maintained retail addon offers a context-aware callout pad or dial that works inside Midnight lockdown. An [MMO-Champion thread](https://www.mmo-champion.com/threads/1973443-Chat-wheel-for-World-of-Warcraft) asks for exactly this.

## To verify in game before any spec

1. Can a secure button's `macrotext` send `/p` during an M+ key and a boss pull, or do callouts need real macros?
2. Is the macro path throttled during a *ChallengeMode-only* lockdown (M+ trash), or only during encounters?
3. Does the `Map` restriction alone lock chat in an ordinary dungeon?
4. Does `{gN}` work through the macro path?
5. How tight is the encounter throttle (messages per second)?

Test switches: `/console addonChatRestrictionsForced 1`, `secretEncounterRestrictionsForced 1`, `addonChallengeModeRestrictionsForced 1`.
