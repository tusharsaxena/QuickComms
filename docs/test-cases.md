# Test Cases

The full inventory of every headless test case in this repo, grouped by the suite file it
lives in. The `## Totals` table below counts the cases that run: its **Total** is the
authoritative pass count, and the README test badge and any count quoted in the docs must equal
it. A declared skip is listed by name in its group and counted on the `Skipped` row, never in
Total.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.

### test_harness.lua (11)

- harness: the addon's file list is the TOC's, Namespace first and Profiles last
- harness: every LibKa0s file comes from LibKa0s.xml, in its order
- harness: every adopted LibKa0s module is the live library, not its stub
- toc: the fixed field order, a single Retail Interface line and the X-Standard field
- toc: the icon is the 128x128 logo, and the file exists
- toc: OptionalDeps names only vendored libraries, and no hard Dependencies
- toc: the landing-page logo exists beside the launcher icon (layout-§4)
- repo: no stored copy of the context pack (documentation-§3, anti-pattern #49)
- repo: the root doc set is README, the CLAUDE stub, DEPENDENCIES and LICENSE
- repo: every authored file opens with the bootstrap and a comment naming its path
- repo: the .pkgmeta has no externals and ignores the dev-only entries

### test_mock_secure.lua (13)

- mock: a secure button keeps its attributes and answers its name
- mock: SetAttribute in combat is refused and recorded, never applied
- mock: a secure child protects its ancestors in combat, and only them
- mock: a click acts once, on the edge the cvar names, and hooks hear both edges
- mock: the useOnKeyDown attribute wins over the cvar
- mock: a button with no macrotext sends nothing
- mock: a visibility state driver follows combat
- mock: registering a state driver in combat is refused
- mock: frames under a QuickComms-named root get regions and points of their own
- mock: a [nocombat] visibility driver shows out of combat and hides in it
- mock: a state-driver condition the mock does not model raises, never skips
- mock: a region answers IsVisible as it answers IsShown
- mock: moving, levels, movable and clamping are refused in combat on a protected frame

### test_bus.lua (2)

- bus: every spec §17 message is declared with its exact name
- bus: no two constants share a name

### test_surface_parity.lua (15)

- parity: the degraded load really is library-absent, and the live one is not
- parity: the Core seam's namespace surface survives the library's absence
- parity: the DebugLog stub carries the whole live surface
- parity: the Slash stub carries the whole live surface
- parity: the Slash stub's one library string is the library's, byte for byte
- parity: the Options helpers stub carries the whole live surface
- parity: the Schema host stub's instance carries the whole live instance surface
- parity: the Schema host stub carries the library's own members
- parity: the Launcher stub carries the whole live surface
- parity: the Lifecycle stand-in carries every member of the live latch
- parity: the Bus stand-in carries every member of the live bus
- parity: the Pool stub carries the LibKa0s-Pool-1.0 surface this addon calls
- parity: the Perf stub carries every Perf member the addon reaches
- parity: the Env seam publishes the same NS members on both paths
- parity: the Media seam publishes the same NS members on both paths

### test_setup.lua (21)

- core: NS.Print is NS.Util.print after AceConsole's embed (architecture-§2)
- core: the printer tags every line with the cyan [QC] prefix
- core: the degraded printer says the library is missing once, then tags every line
- core: the close-button wrapper passes the addon folder as the third argument
- core: no file but the wrapper calls a close-button factory directly
- media: FONT_MONO is the shipped face live, and a real client font degraded
- env: the version falls back to the in-code constant when the TOC cannot be read
- bus: every catalog name is Ka0s_QuickComms_<Event>, and the copy is strict
- bus: a tracked target's registrations come down with the stand-down and back with the stand-up
- bus: a profile switch sends PROFILE_CHANGED once
- perf: every declared bucket has a bracket, and every bracket a declared bucket
- perf: the live harness is built, and the stub answers the perf verb
- perf: the `perf` hold stands the addon down, and the verbs keep answering
- perf: the descriptor's SavedVariables global is declared in the TOC
- launcher: one object, labeled with the brand, the logo as its icon, registered on enable
- launcher: the right-click menu is Enabled, Locked and Test mode
- launcher: Enabled calls the same handler `/qc disable` calls
- launcher: degraded, Register says once that there is no minimap button
- options: the category registers eagerly, with the General page under it
- options: the General page's first group is exactly `Master controls`
- options: the degraded load completes, and the panel says once that it is unavailable

### test_database.lua (6)

- database: the defaults stamp schemaVersion 0, and the runner moves it to the code's target
- database: the target is the last step's `to`, and the steps climb in order
- database: the runner is idempotent, and a stored stamp at the target runs no step
- database: a step that raises leaves the stamp where it was
- database: a perProfile step runs once for every stored profile
- database: the profile defaults carry the Master controls value, and no debug flag

### test_profile.lua (5)

- profile: behavior defaults match spec §5.1
- profile: collections exist; default nextId is 1, 3 after boot
- profile: every behavior row resolves through the seam
- profile: the spam guard clamps to 0.6-2.0 and fallback refuses unknown values
- profile: schema version target is 1

### test_schema.lua (12)

- schema: every row validates against the defaults
- schema: a stored row whose path has no default is counted, not passed vacuously
- schema: the Minimap button row's backing key resolves against the global defaults
- schema: the Master controls rows are the framed canonical set, in the canonical order
- schema: NS.Setting reads through the seam, and answers the default before the db exists
- schema: a page's rows are the rows whose page is its key
- schema: an unknown path is refused and stores nothing
- schema: the Minimap button row inverts onto LibDBIcon's own hide, with no shown key
- schema: neither reset touches the minimap button (launcher-§3)
- schema: Reset all asks first, through the confirmation popup
- schema: degraded, `enabled` is written through and still reacts
- schema: degraded, a row-less path not in the list is still refused

### test_slash.lua (9)

- slash: NS.COMMANDS is positional triples, every reserved verb present
- slash: `diagnostics` has no alias of any kind (debug-logging-§14)
- slash: both chat commands are registered through AceConsole, and both dispatch
- slash: the bare command opens the settings panel
- slash: enable and disable write `enabled` through the seam and move the latch
- slash: `perf` is the addon's verb and prints the harness's lines
- slash: `reset` with no path explains itself rather than resetting everything
- slash: `debug on` turns logging on without opening the console
- slash: degraded, enable and disable still work and the CLI names the missing library

### test_disabled.lua (10)

- disabled 1: enabled, the addon registers exactly the events it declares
- disabled 2: through /qc disable, nothing is registered, heard or scheduled
- disabled 2: through the write seam, nothing is registered, heard or scheduled
- disabled 3: no SavedVariables write from a game event while disabled
- disabled 4: every reserved verb keeps answering while disabled
- disabled 5: a feature verb answers with the one refusal line and does nothing
- disabled 6: the stand-up re-registers from current state and replays the receivers
- disabled 7: a disabled profile loads stood down, with nothing registered
- disabled 8: the launcher's Enabled entry stays live while disabled
- disabled: [final 1] every feature event is declared once (AceEvent keeps one handler per event)

### test_diagnostics.lua (7)

- diagnostics: the sections are the addon's, in report order
- diagnostics: the report names the schema, the profile, the holds and the launcher
- diagnostics: it runs while stood down and says so, without acting
- diagnostics: `enabled` is always listed, and a hidden minimap button is listed
- diagnostics: the situation and library sections report the snapshot and the registry
- diagnostics: [final 1] the restriction section names the active reasons and canSendChat
- diagnostics: the surfaces and send sections name the pads, the armed chips and the guard

### test_compat.lua (7)

- compat: plain readers pass plain values and drop secrets
- compat: InstanceInfo with a secret instanceID reads nil, never raises
- compat: InstanceInfo during a loading screen (all nil) reads safely
- compat: [final] an empty-string realm falls back to the normalized realm name
- compat: UseKeyDown reads the cvar, and defaults on when it cannot
- compat: SenderIsPlayer answers by GUID, then by name, and nil when it cannot read either
- compat: ChatColor reads the client's chat colors and declines what it cannot read

### test_restrictions.lua (16)

- restrictions: nothing restricted, everything allowed and nothing announced
- restrictions: an encounter stops chat and is the reason; its lift is announced
- restrictions: a lift the client does not confirm yet keeps the restriction
- restrictions: the event's boolean payload is read too
- restrictions: each type gives its reason; Map blocks nothing
- restrictions: the reason is the highest in priority
- restrictions: a type the client adds later is reported by name and blocks nothing
- restrictions: the chat lockdown stops chat, a secret answer too
- restrictions: the combat edges set InCombat, ahead of the client's flag
- restrictions: before any edge, the client's combat flag decides
- restrictions: combat under an encounter announces the change of what is allowed
- restrictions: a secret payload never raises; a secret state reads as active
- restrictions: a client without the restriction APIs restricts nothing but combat
- restrictions: Refresh announces a lift no event reported
- restrictions: stood down, nothing is heard; the stand-up announces what is in effect
- restrictions: [final 1] a lockdown lifting under a higher one is announced

### test_situation.lua (15)

- situation: classifier truth table (content, group)
- situation: non-table input classifies as open world solo
- situation: difficulty names by id
- situation: key level and map only inside M+
- situation: signature ignores combat and lockdown
- situation: RefreshNow sends SITUATION_CHANGED only when the signature moves
- situation: Refresh coalesces a burst into one read
- situation: ReadInputs survives a loading screen
- situation: stand-down cancels a pending coalesced refresh
- situation: snapshot.lockdown mirrors Restrictions.ActiveSet
- situation: [final 1] a restriction or combat edge after the refresh reaches Current()
- situation: [final 1] Current() before the first refresh reads the combat edge
- situation: [final 1] stood down, the receiver is down; stood up, it hears again
- situation: [final 1] on the degraded bus the module takes its own receiver down and up
- situation: [final 1b] both combat edges reach Current() even under the Combat restriction type

### test_tokens.lua (8)

- tokens: target and focus become engine tokens and count as live
- tokens: raid markers by number and name, any case
- tokens: group tokens map to {gN}
- tokens: baked values come from ctx; absent ones are missing
- tokens: spell links bake through ctx.spellLink; unknown ids are missing
- tokens: unknown chips stay as typed and are reported
- tokens: typed %t and %f count as live, chips are not double counted
- tokens: non-string text expands to empty

### test_channels.lua (7)

- channels: smartGroup prefers instance, then raid, then party
- channels: smartGroup solo follows the fallback
- channels: smartLead is RW for raid leader/assist and in a home party
- channels: fixed kinds pass through; unknown kinds refuse
- channels: the whisper kinds are not kinds (owner, issue #7)
- channels: prefixes and chat types
- channels: the lock matrix

### test_bake.lua (11)

- bake: a plain callout bakes to prefix + text
- bake: [review 1] a leading slash is refused, even after whitespace
- bake: [review 1] newlines and control characters flatten to one line
- bake: pipes are escaped, spell links are not
- bake: [final minor 5] the 255-byte boundary counts the whole line: prefix, space, text, live tokens
- bake: empty or whitespace-only text is refused
- bake: solo smart callouts follow the fallback
- bake: the lock rides along without blocking the bake
- bake: unknown channel and non-table callout refuse
- bake: baked token values are sanitized; spell links are not
- bake: a typed %t counts as live

### test_resolver.lua (8)

- resolver: an empty When always matches
- resolver: each row matches and fails on its own
- resolver: rows AND, values OR, empty rows ignored
- resolver: keyLevel never matches outside M+
- resolver: ActiveGroups unions enabled matches
- resolver: SurfaceOrder keeps the surface's order; autoPromote floats narrower groups
- resolver: Explain names the matched rows
- resolver: [final] a non-number keyLevel bound is unset, never raises

### test_builtins.lua (6)

- builtins: the expected top-level sets exist in order
- builtins: ids are unique, referenced and well formed
- builtins: only top-level groups are in the order, and every top-level group is
- builtins: node sets open into their ring and nest one level
- builtins: bake audit, every callout bakes under its set's snapshot
- builtins: battlegrounds use smart group; arena uses party; raid lead uses smart lead

### test_library.lua (25)

- library: Prepare seeds one pad and one dial with every built-in, once
- library: callouts validate on create
- library: whisper channels are refused (owner, issue #7)
- library: [review 4] deleting a shared callout clears every group
- library: [review 4] deleting a group clears every surface
- library: adding a built-in callout copies it (P2)
- library: [review 4] Customize swaps the copy in place, then deleting it leaves neither
- library: hidden built-in callouts drop out of the merged group
- library: [review 5] a newly shipped built-in is appended once; a removed one stays removed
- library: Prepare repairs dangling ids
- library: AllGroups is top-level only and merges the overlay
- library: every mutation announces LIBRARY_CHANGED
- library: overlay writers resolve child ids to the top-level overlay
- library: Customize twice is refused until the copy is deleted
- library: Customize copies openInto and flattens node callouts
- library: Prepare survives malformed groups and surfaces
- library: Prepare repairs the order lists
- library: MoveInGroup with a nil target returns false
- library: [final 2] a built-in whose copy fails validation is refused cleanly, with no hole
- library: [final 2] the name cap counts characters, not bytes
- library: [final 2] Customize skips a copy that fails and reports it, leaving no hole
- library: [final minor 2] Prepare lifts a stale nextId above every existing id
- library: [final minor 3] Prepare repairs corrupt top-level registry keys and builtins entries
- library: SetSurfacePoint stores a copy of a plain anchor, announces it, and nil clears it
- library: SetSurfacePoint refuses an unknown surface or a malformed anchor, and stores nothing

### test_check.lua (6)

- check: a built-in callout prints its line and channel
- check: a refused callout prints the reason
- check: an unknown id says so
- check: never calls SendChatMessage
- check: [final minor 4] unknown and send-time tokens are listed
- check: [final minor 4] solo with soloFallback=self says it would print locally

### test_send_guard.lua (10)

- guard: Decide is ok outside the window and guarded inside it
- guard: Remaining counts down to zero
- guard: the acting edge follows the key-down setting
- guard: every echo event maps to one chat type
- echo: our own echo consumes the oldest pending press of its type
- echo: another player's readable message is ignored
- echo: an unreadable sender is unknown, counts as the echo, and is never a drop
- echo: a message of another type or after the window matches nothing
- echo: Expire drops only presses older than the window, oldest first
- queue: a key replaces its earlier entry and keeps its place

### test_sendengine.lua (23)

- sendengine: a send button is a named secure button registered for both edges
- sendengine: Arm sends exactly the line; Disarm clears both attributes and sends nothing
- sendengine: in combat, building, arming and disarming are declined, so nothing is blocked
- sendengine: RunOrQueue runs now out of combat
- sendengine: in combat the queue keeps the last write per key and drains once at combat end
- sendengine: Drop empties the queue and nothing runs at combat end
- sendengine: a failing queued entry is reported and the others still run
- sendengine: Teardown in combat holds one PLAYER_REGEN_ENABLED and releases it when it fires
- sendengine: CancelTeardown releases the held registration without running it
- sendengine: the visibility driver is set out of combat and declined in it
- sendengine: [firewall] no other shipped file makes a secure call (spec §9)
- sendengine: [D12] nothing calls SendChatMessage: the secure button is the one send path
- send: one press is one send and one pending echo, though the hook hears both edges
- send: [review 3] a double press in a boss: guarded, then dropped, with one note, never canceled
- send: the drop note follows behavior.dropNotes
- send: presses further apart than the guard are never guarded
- send: an unreadable sender counts as our echo and is never a drop
- send: another player's message on the channel is not our echo
- send: a disarmed button reports nothing and tracks nothing
- send: a solo self-fallback prints locally and sends nothing
- send: onPress hears the verdict and the window
- send: every echo event is a declared feature event
- send: the stand-down cancels the echo timers and forgets the presses

### test_preview.lua (5)

- preview: test mode turns on and off, announcing each edge once
- preview: a start in combat is refused with one line
- preview: the start of combat ends test mode, with one line
- preview: test mode still ends when lockdown has already begun at the combat edge
- preview: the stand-down ends test mode silently, and stood down a start is refused

### test_master.lua (5)

- master: the frame defaults are spec §5.1's: always shown, scale and alpha 1, locked
- master: /qc unlock and /qc lock write the Lock frame row's path and confirm on one line
- master: the launcher's Locked and Test mode entries call the same handlers
- master: /qc test toggles test mode, and in combat says why it will not
- master: the Test mode row reads and writes the one switch, and Reset all ends it

### test_pad_layout.lua (11)

- layout: horizontal puts a section's chips on one row under the header
- layout: a titled section draws its label row first
- layout: grid wraps at its column count; vertical is one column
- layout: the style sets the cell
- layout: leftward growth mirrors the row; collapsed is the header alone
- layout: upward growth stacks the sections bottom-up, each title above its chips
- layout: groups-as picks the sections: sections, merged, one tab at a time
- layout: the wheel steps tabs and wraps both ways
- layout: the visibility expression combines the master and the pad
- layout: the fade follows combat and the mouse, under the master alpha
- layout: the channel tag names the resolved channel

### test_surfaces.lua (18)

- surfaces: in a key the default pad's plan is the M+ set, baked to /p
- surfaces: [review 5] a refused callout is a slot with its reason and no line
- surfaces: a node battleground gives one section per node, baked to /i
- surfaces: a Say callout locked by an encounter lights the plan's lockdown chip
- surfaces: solo with the self fallback, a smart callout carries the text to print
- surfaces: the bake context fills {me} from the client
- surfaces: a disabled built-in leaves the plan
- surfaces: the test plan is placeholder chips that carry no line
- surfaces: the first situation read builds the default pad, armed and shown
- surfaces: ACTIVE_GROUPS_CHANGED is sent once per real change of a pad's active groups
- surfaces: [review 1] a situation change in combat queues: nothing blocked, stale shows, combat end rebuilds
- surfaces: [review 1] a profile switch in combat queues the new profile's pads
- surfaces: a setting written in combat waits for combat end, with the stale hint
- surfaces: an encounter lockdown in combat padlocks a Say chip and lights the chip, nothing blocked
- surfaces: test mode draws placeholders that send nothing; combat start brings the live chips back
- surfaces: if lockdown has already begun at the combat edge, test mode's end is queued, not blocked
- surfaces: disabled out of combat, every pad hides and every chip disarms; enabled, they return
- surfaces: [review 2] disabled mid-combat: nothing blocked, one held registration, finished at combat end

### test_pad_render.lua (10)

- render: Dress builds a chip's regions once, each its own object
- render: an armed chip shows its name, its channel tag in the chat color, no lock, no dim
- render: [review 5] a refused chip is dimmed and its tooltip says why
- render: a locked chip shows the padlock and names the lock; RefreshLock follows the slot
- render: the style decides icon and label
- render: a test-mode chip and a solo self-print chip are not dimmed, and say what they do
- render: flashes take the result's color; the cooldown dims and clears
- render: the situation chip names the content, the dungeon and the key
- render: the header shows the lockdown chip, the stale hint and the test label on demand
- render: the drag-strip seam builds a hidden strip, and answers nil without the library

### test_pad.lua (13)

- pad: the default pad shows the M+ callouts, each chip armed with its baked line
- pad: [review 5] a refused chip is dimmed and disarmed: a click sends and reports nothing
- pad: [review 4] a hidden or locked pad still rebuilds; the driver hides; the strip stays hidden
- pad: a rebuild with fewer chips parks the rest, disarmed, for the next
- pad: [registry] no file but Library writes a surface's point
- pad: the drag saves the point; locked or in combat it does not move; Reset position clears it
- pad: [fix 1] combat starting mid-drag ends the drag on the edge; the stop is never blocked
- pad: [fix 1] a drag caught after lockdown began is stopped and saved when combat ends
- pad: tabs show one section; the wheel steps them out of combat and is refused in it
- pad: collapse hides the chips out of combat and is refused, with one line, in it
- pad: a send result flashes its chips; a press dims every chip for the guard window
- pad: the fade follows the mouse and combat through SetAlpha alone
- pad: Sync releases a pad no plan names: hidden, its chips disarmed

### test_vendor_sync.lua (3)

- libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
- tests/_kit is the test kit that shipped with that release
- the automated-test runner is recorded executable (100755)

### test_eol.lua (2)

- eol: every tracked file carries the terminator .gitattributes declares for it
- eol: .gitattributes is line-endings-§5's canonical body for this repo kind

### test_prose.lua (15)

- prose: no authored file carries a British spelling from localization-§5's published list
- prose: the gate carries localization-§5's two lists whole, and nothing of its own
- prose self-test: the carve-out suppresses the named generated folder, and only it
- prose self-test: a path the carve-out does not name is not covered by one that looks like it
- prose self-test: a carve-out that is not a set of path strings is a failure, not a silence
- prose self-test: a TOC's file lines are read as paths, and its directives and comments are not
- prose self-test: a .pkgmeta's ignore block is read, and the keys around it are not
- prose self-test: an ignore entry covers a path exactly, by folder, and by wildcard
- prose self-test: the carve-out admits a generated dump and refuses a file the TOC loads
- prose self-test: a waiver-file exclusion meets the same two refusals as the carve-out
- prose self-test: each list is refused on the matching rule its own scan uses
- prose self-test: the scan and the refusals read the added exclusions through one reader
- prose self-test: a narrowing is refused by what it suppresses, not by how it is written
- prose self-test: the disclosure names what each entry suppressed, and says when it is bounded
- prose self-test: a malformed waived is a failure, not a silence

### test_layout_cap.lua (13)

- layoutcap: every authored file over the 1500-line cap is named in the census
- layoutcap: no census row outlives the breach it records
- layoutcap: every over-cap census row carries one of layout-§1's three terminal states
- layoutcap: the census and the exempt set agree about which paths were exempted
- layoutcap: an empty census is written as a result rather than left standing empty
- layoutcap self-test: the parser reads the census nested under the register, and stops there
- layoutcap self-test: a census outside its register, or at the wrong level, is not read
- layoutcap self-test: an over-cap file missing from the census is reported, and an exempt one is not
- layoutcap self-test: a census row that outlives its breach is reported
- layoutcap self-test: an over-cap row that names no terminal state is reported
- layoutcap self-test: the census and the exempt set are held to naming the same paths
- layoutcap self-test: a census that states nothing is told apart from one that states none
- layoutcap self-test: the exempt set takes folders as well as paths

### test_diagnostics_contract.lua (9)

- diagnostics contract: both forms run the report
- diagnostics contract: the debug word is matched in any case
- diagnostics contract: both markers carry the brand and the end counts the report
- diagnostics contract: the report appends after what the console already holds
- diagnostics contract: the report lands with logging off and turns it on for the session
- diagnostics contract: an addon that opts out lands the report and leaves logging off (skipped: this addon keeps the default (Kit.diagnostics.enablesLogging is not false), so its report turns logging on; the case above holds it)
- diagnostics contract: with logging already on, the report writes no second enable line
- diagnostics contract: both forms run while the addon is disabled
- diagnostics contract: no other name runs the report

### test_lizard_sighted.lua (8)

- lizard sighted: every hazard lizard loses a function over is neutralized
- lizard sighted: fields, strings, comments and look-alike names come through unchanged
- lizard sighted: a method definition is rewritten to its dot form with self
- lizard sighted: no line is added or removed, CRLF included
- lizard sighted: countFunctions counts the keyword, not strings, comments or longer names
- lizard sighted: listedCounts reads the per-file table, once per file
- lizard sighted: parity names every file whose counts differ, and only those
- lizard sighted: lizard lists every function of a hazard fixture once it is sanitized

## Totals

| Suite | Cases |
|-------|------:|
| test_harness.lua | 11 |
| test_mock_secure.lua | 13 |
| test_bus.lua | 2 |
| test_surface_parity.lua | 15 |
| test_setup.lua | 21 |
| test_database.lua | 6 |
| test_profile.lua | 5 |
| test_schema.lua | 12 |
| test_slash.lua | 9 |
| test_disabled.lua | 10 |
| test_diagnostics.lua | 7 |
| test_compat.lua | 7 |
| test_restrictions.lua | 16 |
| test_situation.lua | 15 |
| test_tokens.lua | 8 |
| test_channels.lua | 7 |
| test_bake.lua | 11 |
| test_resolver.lua | 8 |
| test_builtins.lua | 6 |
| test_library.lua | 25 |
| test_check.lua | 6 |
| test_send_guard.lua | 10 |
| test_sendengine.lua | 23 |
| test_preview.lua | 5 |
| test_master.lua | 5 |
| test_pad_layout.lua | 11 |
| test_surfaces.lua | 18 |
| test_pad_render.lua | 10 |
| test_pad.lua | 13 |
| test_vendor_sync.lua | 3 |
| test_eol.lua | 2 |
| test_prose.lua | 15 |
| test_layout_cap.lua | 13 |
| test_diagnostics_contract.lua | 8 |
| test_lizard_sighted.lua | 8 |
| Skipped | 1 |
| **Total** | **364** |
