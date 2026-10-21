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
- toc: OptionalDeps names only vendored libraries and the optional suites, and no hard Dependencies
- toc: the landing-page logo exists beside the launcher icon (layout-§4)
- repo: no stored copy of the context pack (documentation-§3, anti-pattern #49)
- repo: the root doc set is README, the CLAUDE stub, DEPENDENCIES and LICENSE
- repo: every authored file opens with the bootstrap and a comment naming its path
- repo: the .pkgmeta has no externals and ignores the dev-only entries

### test_mock_secure.lua (28)

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
- mock: [phase 4] a header's _onclick runs as a snippet, and its globals persist between snippets
- mock: [phase 4] in combat a snippet may show a protected frame; insecure code may not
- mock: [phase 4] the restricted-only handle calls raise outside a snippet
- mock: [phase 4] a wrap's pre snippet can suppress a click, and its message runs the post snippet
- mock: [phase 4] a wrap after an OnClick hook raises (the client's wrap discards the hook)
- mock: [phase 4] a snippet's key binding routes a key press to a named button until it is cleared
- mock: [phase 4] override bindings are refused in combat; a press clicks the bound frame by name
- mock: [phase 4] a header's Show and Hide fire OnShow and OnHide on a change; Execute is refused in combat
- mock: [phase 4] the cursor and a frame's center are numbers a suite can set
- mock: [final 19] a header's OnShow hook runs insecure: a protected call it makes in combat is blocked
- mock: [final 2] two owners binding one key: the newest wins, and clearing it hands the key back
- mock secure: GetMousePosition reads the cursor inside a frame, nil outside
- mock secure: type click forwards to clickbutton-<button>
- mock secure: a held modifier reads <mod>- and * attributes, never the plain button form
- mock secure: a header with its mouse off still runs its _onclick from a binding and from Click

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

### test_setup.lua (27)

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
- perf: [audit QC-12] every bucket key is lowerCamelCase, named for the path it times (naming-cheatsheet)
- perf: the live harness is built, and the stub answers the perf verb
- perf: the `perf` hold stands the addon down, and the verbs keep answering
- perf: the descriptor's SavedVariables global is declared in the TOC
- launcher: one object, labeled with the brand, the logo as its icon, registered on enable
- launcher: the right-click menu is Enabled, Locked, Test mode and Show window
- launcher: Show window calls the handler `/qc toggle` calls and reflects the saved flag
- launcher: Enabled calls the same handler `/qc disable` calls
- launcher: degraded, Register says once that there is no minimap button
- options: the category registers eagerly, with the General page under it
- options: the General page's first group is exactly `Master controls`
- options: the degraded load completes, and the panel says once that it is unavailable
- libs: [phase 5] LibDeflate and LibSerialize are vendored, TOC-listed and loaded before the addon
- perf: [phase 5] a refresh notes situationRefresh, and each plan resolverResolve inside bakeSurface
- perf: [review] a refresh whose signature moves notes situationRefresh before the rebuild it publishes
- perf: [phase 5] the Comms Dial page's Preview notes neither bakeSurface nor resolverResolve

### test_database.lua (18)

- database: the defaults stamp schemaVersion 0, and the runner moves it to the code's target
- database: the target is the last step's `to`, and the steps climb in order
- database: the runner is idempotent, and a stored stamp at the target runs no step
- database: a step that raises leaves the stamp where it was
- database: a perProfile step runs once for every stored profile
- database: [phase 4] step 2 moves the generic battleground set below the per-battleground sets
- database: step 3 turns the built-in overlay into seeded groups, each in its set's place
- database: [review] step 3 puts a set the pad has not seen at the pad's end
- database: [review] step 3 lifts a stale id counter before it seeds
- database: step 3 runs once, and the profile loads without duplicates
- database: step 3 leaves a profile never prepared to Prepare, which seeds it once
- database: the profile defaults carry the Master controls value, and no debug flag
- database: [B2] step 4 rewrites a pad's retired Upward growth as Right and up, once
- database: [B7] step 5 renames the dungeon set, widens its When and gives seeded callouts their glyphs, once
- database: [polish] step 6 colors untouched seeded icons and adds the node sets' own callouts, once
- database: [bg subgroups] step 7 seeds the new objective nodes by origin, once; step 8 drops the retired dial fields
- database: [polish] migrate: step 9 drops the retired slice border
- database: [bg subgroups] a fresh profile seeds every objective node once, and step 7 leaves it as it is

### test_profile.lua (9)

- profile: behavior defaults match spec §5.1
- profile: collections exist; default nextId is 1, past every seeded id after boot
- profile: every behavior row resolves through the seam
- profile: the spam guard clamps to 0.6-2.0 and fallback refuses unknown values
- profile: schema version target is 9 (the dial polish)
- prepare: a callout held by two groups is split into a copy
- prepare: a split copy of a seeded callout keeps no origin
- prepare: a callout held by no group is dropped
- prepare: is idempotent after a split

### test_schema.lua (19)

- schema: every row validates against the defaults
- schema: a stored row whose path has no default is counted, not passed vacuously
- schema: the Minimap button row's backing key resolves against the global defaults
- schema: the Master controls rows are the framed canonical set, in the canonical order
- schema: Preview as sits in Master controls on the General page, after Test mode, on a line of its own
- schema: NS.Setting reads through the seam, and answers the default before the db exists
- schema: a page's rows are the rows whose page is its key
- schema: an unknown path is refused and stores nothing
- schema: the Minimap button row inverts onto LibDBIcon's own hide, with no shown key
- schema: neither reset touches the minimap button (launcher-§3)
- schema: Reset all asks first, through the confirmation popup
- schema: [audit QC-04] the global reset takes every created member back to a fresh profile, and only this one
- schema: [audit QC-01] the reset confirmation is options-ui-§12's sentence, verbatim
- schema: degraded, `enabled` is written through and still reacts
- schema: degraded, a row-less path not in the list is still refused
- schema: [fix wave] the Behavior rows that rebuild the pads resolve Settings.RebuildSurfaces when they run
- schema: [audit QC-13] the panel's color codec is written out for the stored { r, g, b, a } shape
- schema: a callout write that names no id is refused, even with callouts present
- schema: [phase 3] a fresh profile has no row off its default; the member rows are not counted

### test_slash.lua (20)

- slash: NS.COMMANDS is positional triples, every reserved verb present
- slash: `diagnostics` has no alias of any kind (debug-logging-§14)
- slash: both chat commands are registered through AceConsole, and both dispatch
- slash: the bare command opens the settings panel
- slash: enable and disable write `enabled` through the seam and move the latch
- slash: `perf` is the addon's verb and prints the harness's lines
- slash: `reset` with no path explains itself rather than resetting everything
- slash: `debug on` turns logging on without opening the console
- slash: degraded, enable and disable still work and the CLI names the missing library
- slash: [audit QC-05] degraded, `debug on`/`off` flip the flag and ack, and `debug diagnostics` routes
- slash: [phase 3] `why` prints each built pad and why its groups show
- slash: [phase 4] `why` covers the dials too
- slash: [final 16] `why` with nothing built speaks of pads and dials
- slash: a callout's rows take its id after the path; with none the write is refused and names the form
- slash: [final 9] test and preview's help, and the Preview as row, speak of the dials too
- slash: [toggle] the flag is off on a fresh addon and the pads show
- slash: [toggle] `toggle` hides every pad, a second `toggle` shows them again
- slash: [toggle] test mode shows the pads even while they are hidden
- slash: [toggle] in combat the flag flips and the driver waits for combat to end
- slash: [toggle] the hidden state is this character's: a /reload or the next login restores it

### test_disabled.lua (21)

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
- disabled [§7 step 1]: enabled, the registration set holds events and messages, and the surfaces are drawn
- disabled [§7 steps 2-4]: through the seam, nothing stays registered, events or messages, and nothing is armed
- disabled [§7 step 5]: every surface frame that was drawn is hidden
- disabled [§7 step 6]: every event and message in R_on, fired anyway, runs nothing live; the combat handler, reached directly, writes, prints and shows nothing
- disabled [§7 step 7]: every NS.COMMANDS entry and the bare /qc: reserved verbs answer, feature verbs refuse once and write nothing
- disabled [§7 step 8]: the launcher's left-click opens the panel and its menu grays every entry but Enabled
- disabled [§7 step 9]: re-enabled, R_on comes back; a setting changed while disabled is what the stand-up builds
- disabled [§7 step 10]: the library latch: perf, then disabled; perf released first leaves it down
- disabled [§7 step 10]: the library latch: disabled, then perf; enabled first leaves it down
- disabled [§7 step 10]: the stand-in latch: perf, then disabled; perf released first leaves it down
- disabled [§7 step 10]: the stand-in latch: disabled, then perf; enabled first leaves it down

### test_diagnostics.lua (13)

- diagnostics: the sections are the addon's, in report order
- diagnostics: the report names the schema, the profile, the holds and the launcher
- diagnostics: it runs while stood down and says so, without acting
- diagnostics: `enabled` is always listed, and a hidden minimap button is listed
- diagnostics: the situation and library sections report the snapshot and the registry
- diagnostics: [final 1] the restriction section names the active reasons and canSendChat
- diagnostics: the surfaces and send sections name the pads, the armed buttons and the guard
- diagnostics: [phase 3] the surfaces section names the preview
- diagnostics: [final 21] the settings section lists no member row
- diagnostics: [phase 4] the dials and bindings sections name each dial, its key and each entry's WoW binding
- diagnostics: [dial rework] the report names the pads' hidden state, each dial's look, the ring shown and every ring
- diagnostics: [debug] the log follows a dial open, a ring shown, a press and a close, once each
- diagnostics: [shine] the pad's button line and the dial's slices line print the look and strength

### test_compat.lua (12)

- compat: plain readers pass plain values and drop secrets
- compat: InstanceInfo with a secret instanceID reads nil, never raises
- compat: InstanceInfo during a loading screen (all nil) reads safely
- compat: [final] an empty-string realm falls back to the normalized realm name
- compat: UseKeyDown reads the cvar, and defaults on when it cannot
- compat: SenderIsPlayer answers by GUID, then by name, and nil when it cannot read either
- compat: [fix wave] SenderIsPlayer: a cross-realm namesake is not the player; an unreadable realm is unknown
- compat: HasTemplate answers where C_XMLUtil can, and nil where it cannot
- compat: ChatColor reads the client's chat colors and declines what it cannot read
- compat: [phase 3] InstanceName reads the client's name; a secret, empty or missing one is nil
- compat: [phase 3] SpecInfoByID and ClassName read display names; secret or missing ones are nil
- compat: [final 8] BindingKey reads a command's key; a secret or a missing API is nil

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

### test_situation.lua (16)

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
- situation: [arena] an arena snapshot carries its instanceID, which the arena row matches

### test_tokens.lua (8)

- tokens: target and focus become engine tokens and count as live
- tokens: raid markers by number and name, any case
- tokens: group tokens map to {gN}
- tokens: baked values come from ctx; absent ones are missing
- tokens: spell links bake through ctx.spellLink; unknown ids are missing
- tokens: unknown chips stay as typed and are reported
- tokens: typed %t and %f count as live, chips are not double counted
- tokens: non-string text expands to empty

### test_channels.lua (8)

- channels: smartGroup prefers instance, then raid, then party
- channels: smartGroup solo follows the fallback
- channels: smartLead is RW for raid leader/assist and in a home party
- channels: fixed kinds pass through; unknown kinds refuse
- channels: the whisper kinds are not kinds (owner, issue #7)
- channels: prefixes and chat types
- channels: the lock matrix
- channels: [phase 5] the lock matrix has no row for an unknown channel, and reads a missing snapshot as solo

### test_bake.lua (12)

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
- bake: [phase 5] CleanText is the sanitizer short of the escape; Sanitize is CleanText, then the escape

### test_share.lua (37)

- share: a string is !QC1! then printable text, and decodes back to the same payload
- share: [review 1] a pasted string may wrap and carry spaces; a cut-short one is damaged and imports nothing
- share: a string that is not ours, is empty, is garbage after the prefix or is too large is refused
- share: a newer version is refused with a line to update; a damaged version is refused
- share: [review 2] a command or control characters never survive: / is refused, lines are flattened
- share: ids, channels, names, icons and Whens are checked against the schema
- share: a pad keeps the shared groups, and only the fields that travel; a shipped id is a dropped reference
- share: the report counts what arrives, then names each member left out and why
- share: more members than one string may carry is refused before any is checked
- share: [review 1] a hand-made string with a NaN reference, a cyclic field or an infinite icon raises nothing
- share: [review 1] a payload that still raises inside the checks is damaged, never an error
- share: [review 2] a surface's string fields pass the sanitizer; an empty string is kept for the seam to judge
- share: SHARE-3's and SHARE-4's strings (docs/smoke-tests.md) read as the checks say
- share: [review 1] a short string that inflates past MAX_RAW is damaged before it is read
- share: [fix 1] a shared-reference When or field is refused at once, never expanded
- share: [fix 1] one table shared across many fields is bounded by MAX_NODES: the string is too large
- share: [fix 2] one long string referenced 2000 times in a field is refused unread, promptly
- share: [fix 2] a long name, text or icon is refused unread, promptly
- share: [fix 2] shared short strings past the payload's text budget make the string too large
- share: [review] a refused member's malformed id never reaches the report raw: no newline, no live escape
- share: [review] a 200 KB malformed id gives a short report line
- share: [review] a name's live | escape is stored and reported as text (||), as a typed | is
- share: [review] a name that starts with / is a name, never sent: it travels and round-trips
- share: [review] a nested key in a When or a field passes the sanitizer and the byte budget
- share import: groups sharing a callout each get their own copy
- share import: the report counts a shared callout once per group, as the import makes it
- share import: a callout in no imported group is not imported
- share: Collect takes a callout only inside its group; a picked callout alone is nothing
- share: [icons] a glyph's color travels; an old string arrives untinted; a bad color is dropped and counted
- share: [icons] an export carries each member's color, and the string round-trips it
- share: [nesting] a picked parent brings its children, and the import nests them under the new copy
- share: [review] a child picked alone travels without its parent: nothing dropped, and it arrives top-level
- share: [nesting] a parent the string does not carry, itself, or one inside another is dropped and counted
- share: [review] a pad's or dial's reference to a group the string nests is dropped and counted
- share: [inherit] a child's Inherit when conditions travels; an old string's child inherits
- share: [B2] a pad shared before the growth split carries Upward, which lands as Right and up
- share: [B9] a pad's and a dial's Icons rows travel; an old string brings none

### test_resolver.lua (13)

- resolver: an empty When always matches
- resolver: each row matches and fails on its own
- resolver: rows AND, values OR, empty rows ignored
- resolver: keyLevel never matches outside M+
- resolver: ActiveGroups unions enabled matches
- resolver: SurfaceOrder keeps the surface's order; autoPromote floats narrower groups
- resolver: Explain names the matched rows
- resolver: [final] a non-number keyLevel bound is unset, never raises
- resolver: [inherit] a child that inherits is judged by its parent's When, not its own
- resolver: [inherit] WhenOf names the When that judges a group, and whose it is
- resolver: [inherit] SurfaceOrder's narrowness reads the When that judges the group
- resolver: [all] All battlegrounds and All dungeons and raids match the whole kind, the listed ids aside
- resolver: [arena] the arena row matches only in an arena: its listed ids, or all of them

### test_builtins.lua (21)

- builtins: the expected top-level sets exist in order
- builtins: ids are unique, referenced and well formed
- builtins: only top-level groups are in the order, and every top-level group is
- builtins: node sets nest one level
- builtins: bake audit, every callout bakes under its set's snapshot
- builtins: battlegrounds use smart group; arena uses party; raid lead uses smart lead
- builtins: [phase 5] every node set pins each node to a wind, at most eight, Deepwind Gorge's five included
- builtins: [B7] every callout ships a catalog glyph, with a color only where it is a glyph
- builtins: [B7] the generic dungeon set is Dungeon (generic), active in a dungeon and in M+
- builtins: [polish] World (solo) is a solo open-world set of say callouts
- builtins: [polish] every battleground node set has map-wide callouts of its own
- builtins: [polish] every callout icon has a color, and no group is white only
- builtins: [polish] every group has a colored catalog glyph for its icon
- builtins: [bg subgroups] Alterac Valley has every general, captain, bunker, tower and graveyard, north to south
- builtins: [bg subgroups] Isle of Conquest gains Our base and Enemy base beside its five nodes
- builtins: [bg subgroups] the flag maps, Wintergrasp, Ashran, Deephaul Ravine and Seething Shore have objective children
- builtins: [bg subgroups] no callout names a faction
- builtins: [bg buttons] every base-capture node has Attack, Defend, INC and Clear, as Wintergrasp's workshops do
- builtins: [bg buttons] Silvershard Mines has its three tracks and the switches, each with four
- builtins: [bg buttons] Temple of Kotmogu has its four orbs and the center
- builtins: [bg buttons] In Group is a party, raid and instance group set of short smart-group lines

### test_gameids.lua (4)

- game ids: every battleground set matches only battleground maps, and no map is two sets'
- game ids: the shipped dungeons are Mythic+ dungeons and the shipped raids are raids
- game ids: [instances] INSTANCES are dungeons and raids, cover the season's, and reach past it
- game ids: [arena] ARENAS are arena maps, one per arena

### test_library.lua (74)

- library: Prepare seeds every shipped set as a group, on one pad and one dial, once
- library: a seeded group is an ordinary group: its fields, When, callouts and origin
- library: a seeded battleground set holds its nodes as groups inside it, in shipped order, with their winds
- library: callouts validate on create
- library: whisper channels are refused (owner, issue #7)
- library: [review 4] deleting a callout clears its group
- library: [review 4] deleting a group clears every surface
- library: adding a seeded callout copies it (P2); the copy keeps no origin
- library: [review 5] a newly shipped set is seeded once, at the end of every surface; a deleted one stays deleted
- library: a node shipped after its set was seeded goes inside the set's group
- library: [review] a set whose stored parent dangles still takes a node shipped after it
- library: [review] ValidParent takes a parent whose own stored parent dangles
- library: Prepare repairs dangling ids
- library: AllGroups is every user group, a seeded node among them
- library: every mutation announces LIBRARY_CHANGED
- library: no shipped id is a member any more
- library: Prepare survives malformed groups and surfaces
- library: Prepare repairs the order lists
- library: MoveInGroup with a nil target returns false
- library: [final 2] a callout whose copy fails validation is refused cleanly, with no hole
- library: [final 2] the name cap counts characters, not bytes
- library: [final minor 2] Prepare lifts a stale nextId above every existing id
- library: [final minor 3] Prepare repairs corrupt top-level registry keys
- library: SetSurfacePoint stores a copy of a plain anchor, announces it, and nil clears it
- library: SetSurfacePoint refuses an unknown surface or a malformed anchor, and stores nothing
- library: [phase 3] a copy's name stays within the 32-character cap, counted in characters
- library: duplicating a group copies its callouts
- library: [phase 3] CreateGroup keeps only existing user callouts, and validates the When
- library: CreateGroup takes a callout no group holds, and copies one a group holds
- library: [phase 3] OfferGroup puts a user group first on every pad and dial, once
- library: [phase 3] MoveGroupOnSurface reorders a surface's groups and announces it
- library: [phase 3] Member answers the live member of each kind
- library: [phase 3] Touch announces the member it is handed, and the field
- library: [phase 3] MemberIds lists each kind in its picker's order
- library: [phase 3] ValidWhen accepts every shipped When and refuses bad shapes
- library: [final] a surface's offsets are bounded at its smallest scale, not at 1
- library: [phase 3] the point and icon validators
- library: [phase 3] every member template holds a value at every field
- library: [phase 3] Batch holds the announces and sends one per kind it touched
- library: [final 1] Restore, AddToGroup and OfferGroup each send one LIBRARY_CHANGED
- library: [final 1] one Restore click rebuilds the pads once
- library: [final 2] ValidWhen refuses a value its row can never match, and names the row and value
- library: [phase 4] the generic battleground set moves below the per-battleground sets, once
- library: [phase 5] Import makes every member under a fresh id, its references pointing at the copies
- library: [review 3] importing the same string twice makes two copies; nothing that existed changes
- library: [review 4] an imported pad and dial arrive unbound: no key, the default place, no set added
- library: [review] an imported Look keeps a bool a bool and a color its four channels
- library: [phase 5] Import is one act: one LIBRARY_CHANGED; a refused result imports nothing
- library: [phase 5] Prepare gives a pad saved before the Look groups every field it lacks
- library: adding a user callout to a group adds a copy
- library: removing a callout from its group deletes it
- library: deleting a group deletes its callouts
- library: CreateCalloutIn makes and places a callout in one act
- library: [icons] IsGlyph names a catalog icon by its path; ValidIconColor takes none or rrggbb
- library: [icons] a new member keeps a glyph's color, drops it on any other icon, refuses a bad one
- library: [icons] a copy keeps the color: AddToGroup, DuplicateGroup and a held callout's copy
- library: [icons] Prepare drops a malformed stored color and keeps a good one
- library: [icons] an import carries a glyph's color into the fresh copies
- library: [icons] IconTint draws a glyph's color as r, g, b; no color, a bad one or no glyph is white
- library: [nesting] a group takes a top-level group as its parent and leaves every surface
- library: [nesting] one level only: self, a child, a parent with children, a stranger and a shipped id are refused
- library: [nesting] none clears the parent: false, empty text and 'none' all do
- library: [nesting] a group's children are in the order they were made; MemberIds lists them under it
- library: [nesting] deleting a parent makes its children top-level groups in its place on every surface
- library: [nesting] Duplicate keeps a child inside its parent; a parent's copy holds no children
- library: [nesting] Prepare drops a bad parent (gone, itself, a chain, a cycle) and takes a child off every surface
- library: [restore] a deleted set comes back once, as fresh groups at the end of every surface
- library: [restore] a deleted node comes back inside its set; a deleted callout at the end of its group
- library: [restore] a set deleted with its nodes kept brings back only what is missing
- library: [restore] a set nested in another group keeps its place; its nodes stay out
- library: [restore] a new pad holds the seeded sets still top-level, in shipped order
- library: [inherit] a new or seeded group inherits its parent's When; Duplicate and an untick keep false
- library: [all] ValidWhen takes all on the instance and battleground rows, and on no other
- library: [arena] ValidWhen takes arena ids and all on the arena row

### test_members.lua (28)

- members: a callout field is written through the seam by instance id, and announced once
- members: with no id the seam writes the selected member, else the first the page lists, else refuses
- members: [review 5] a bad name or channel is refused with its reason and stores nothing
- members: an icon typed as digits is stored as a texture id; empty text clears it
- members: a seeded group's fields read and write as any group's; the shipped set never changes
- members: a group's When is one structured row: a valid When stores, a bad one is refused
- members: member rows are not AceDB defaults, and each resolves against its template
- members: Library's own writers (the pad point, an icon) go through the seam, one announce each
- members: the structured rows are typed and printed on the CLI through the descriptor's parse and format
- members: [review 1] a callout edited from the CLI in combat waits for combat end, with the stale hint
- members: [fix 1] pad.point refuses an unknown anchor name or a non-finite offset; nothing is stored
- members: [final 2, 11] the CLI maps When values onto their tokens, and refuses one a row never matches
- members: [final 7] what `get group.when` prints types back in
- members: [final 4] an off-screen pad.point is refused; `/qc reset` brings back a pad's place and clears an icon
- members: [phase 4] a dial's fields are member rows, and its position goes through SetSurfacePoint
- members: [keys] a dial has no key row: its key is WoW's binding, set in Options -> Keybindings, never on the CLI
- members: [phase 4] the CLI types and prints a dial's position
- members: [phase 4] an off-screen dial.point is refused; `/qc reset` brings the dial back
- members: [phase 5] a When's key level prints as it types back in: one level, open below, open above
- members: [phase 5] a pad's Look rows are composed member rows: checked, clamped, announced
- members: [icons] a glyph's color is written through the seam by id, typed text read as rrggbb
- members: [icons] a malformed color, a color on no glyph and a shipped id's color are refused
- members: [icons] an icon that is no glyph clears the color in the same act; a glyph keeps it
- members: [icons] Library.SetIcon writes the icon and its color as one act
- members: [icons] `/qc reset` clears a color; a group page's Defaults keeps it with the icon
- members: [inherit] group.inheritWhen is a member row: a bool stores and announces, anything else is refused
- members: [inherit] the Enabled tooltip names whose When a sub-group is shown by
- members: [arena] the CLI sets the arena row by id, name or all, and prints it back

### test_editors.lua (17)

- editors: [review 2] Select keeps the selection, and nothing else; Heal keeps a member that exists
- editors: every membership change asks for one structural repaint, on the next frame
- editors: [phase 3] a scalar member write repaints nothing; a name does
- editors: [phase 3] a situation change repaints only when the set of active groups changes
- editors: [phase 3] with no page body built, no change schedules a repaint
- editors: a profile switch clears every selection
- editors: the stand-down cancels a pending repaint
- editors: ConfirmDelete asks first, and only the accepted popup runs the act, once
- editors: Scalar keeps the rows the flow engine draws, and CancelReorder cancels once
- editors: a row's remove is a glyph, not a button
- editors: a row with edit shows the edit glyph and fires it
- editors: a row centers its widgets and puts the glyphs at its right edge
- editors: [layout] under AceGUI's column rule only the label's column is weighted
- editors: Snapshot is the preview's while Preview as is on
- editors: [icons] a row's glyph is drawn in its color; a row with none is white
- editors: [preview table] TableRows draws a header, then a boxed row per entry: its name in one cell, its text in the other
- editors: [preview table] a table row gives its text the width the name leaves, and grows with the text

### test_callout_popup.lua (38)

- popup: Add opens blank with Smart group
- popup: edit opens filled in
- popup: typing changes the draft only, and the preview follows
- popup: Save on Add creates the callout at the end of the group, one LIBRARY_CHANGED
- popup: Cancel on Add creates nothing and consumes no id
- popup: Save on edit writes only the changed fields through the seam
- popup: Cancel on edit writes nothing
- popup: Save with an empty name stays open and writes nothing
- popup: Save takes the text typed into a box without Enter
- popup: a pick or a seam write keeps the text typed without Enter
- popup: the callout deleted under an open popup closes it; a late Save writes nothing
- popup: closing the settings window cancels
- popup: Escape and a profile change cancel
- popup: there is no token dropdown; an info glyph sits right of the Text label
- popup: the info glyph's tooltip lists the tokens, {group1} to {group8} only for a raid channel
- popup: the preview is headed Preview, a gap above Cancel then Save
- callout helpers: TokenHelp folds {group1}-{group8} into one line and names {spell:ID}
- popup: [icons] Choose icon… opens the browser; its Choose writes the draft's icon, not the callout
- popup: [icons] a glyph chosen with a color: the draft carries both; the swatch writes the draft's color
- popup: [icons] the clear glyph takes the draft's icon and color off; Save stores no icon
- popup: a section's gap sits above Preview: the fields count as a drawn group
- popup: [icons] the swatch writes the draft on a drag tick (OnValueChanged) with no confirm, as OK leaves it
- popup: the window is Blizzard's settings-window template, and its own close X cancels
- popup: the template's background sits over the catcher's dim and under the border
- popup: a settings-window template without its close X falls back to the dialog look
- popup: a client whose C_XMLUtil says it lacks the template is not asked for it
- popup: a client whose C_XMLUtil knows the template gets it
- popup: without the template it keeps the dialog look and the shared close mark
- popup: no scrollbar; the window's height follows the laid-out body
- settings: there is no Callouts page
- callout helpers: [phase 3] the token picker offers {group1}-{group8} only when the channel can resolve to Raid
- callout helpers: PreviewLines says what a callout sends here, or why it sends nothing
- popup: [icons] the draft carries the icon's color; Save writes icon and color in one act
- popup: [icons] an icon chosen that is no glyph drops the draft's color, and Save clears it
- popup: [icons] Add saves a glyph with its color; a malformed color stays open and names the field
- popup: Name and Channel share a line, Text spans both, the icon has no box and sits under an Icon label
- popup: every field's label and control share a left edge; Preview's rule and the buttons the columns' edges
- popup: [icons] an icon that is no texture stays open and names the icon chooser

### test_icon_browser.lua (36)

- icon browser: the window is the popup's chrome, stacked above the popup and its catcher
- icon browser: tabs in order; the stored icon is preselected and its tab opened
- icon browser: a click selects, a double-click chooses; Choose hands the opener the icon
- icon browser: hovering an icon names it, or gives a game icon's texture id
- icon browser: Markers is the eight raid markers, in order; no Suggested list is left
- icon browser: the grid sits a section gap under the toolbar's row
- icon browser: Glyphs is every catalog icon, labeled from its key
- icon browser: Game icons is both macro lists, filtered All / Spells / Items
- icon browser: the game list not loaded yet says so, and loads on a later visit
- icon browser: the grid is virtualized: a fixed set of cells re-dressed as it scrolls
- icon browser: a scroll under the pointer re-says the hovered cell's tooltip, or hides it
- icon browser: a long name in the footer stops at the Choose button, on one line
- icon browser: the wheel over the scrollbar scrolls the grid too
- icon browser: a filtered game list holds each icon once (the loose lists overlap the full ones)
- icon browser: the color picker its swatch opened closes with the browser, and only that one
- icon browser: a chooser's swatch released with the picker up hides it and lets the swatch go
- icon browser: the swatch tints every glyph; Choose hands a glyph its color, white as none
- icon browser: Escape over the popup closes the browser only; the popup's Escape comes back after
- icon browser: the popup closing closes it as Cancel
- icon browser: a popup that closes leaves a browser opened by another owner alone
- icon browser: Choose is refused in combat; nothing is written
- icon browser: a stand-down closes it
- icon browser: Compat.MacroIcons reads both lists, plain texture ids only, never raising
- icon browser: the area follows the tab band when the chrome learns its width (first open)
- icon browser: Compat.MacroIcons reads the loose lists first, as the macro icon selector does
- icon browser: Library.IconColorFrom stores a picked color as hex, white as none
- icon browser: Src.Search matches a marker by name, a glyph by key or label, a game icon by id
- icon browser: the search box filters the tab as you type; the count says N of M
- icon browser: the search box keeps its text inset clear of the magnifier after AceGUI resets it
- icon browser: Src.Search narrows its last results, and stays correct when the query widens or the list grows
- icon browser: the search is kept across tabs and the session's opens, and re-filters each tab
- icon browser: Game icons carries the Wowhead hint; its button shows the address in a copy window
- icon browser: [sets] Src.Glyphs is built once per set: the same table across searches
- icon browser: [sets] a set's prefix is not in its label; Phosphor reads 'Arrow up'
- icon browser: [sets] the Glyphs filter lists the library's sets and narrows to one
- icon browser: [sets] a glyph's tooltip names its set, and a Game-icons mark its author

### test_eui_skin.lua (10)

- eui skin: the popup is painted as EllesmereUI paints the settings window when every condition holds
- eui skin: the icon browser's window is painted the same way, once, when it is built
- eui skin: a callback that comes after the popup was built paints it at once
- eui skin: not painted when any condition fails
- eui skin: never raises without EllesmereUI, or with one that has no RegisterSkin
- eui skin: a facade missing a primitive, or one that raises, leaves the popup stock
- eui skin: paints while the addon is disabled (the popup and the browser are the settings panel's)
- eui skin: the fallback window (no settings-window template) keeps its older look
- eui skin: the diagnostics report names its state
- eui skin: the diagnostics line says, in words, why the skin is or is not on

### test_groups_when.lua (20)

- when: Toggle adds and removes one value, drops an emptied row, and never mutates its input
- when: [review 5] the key-level range refuses lowest above highest; clearing both drops the row
- when: [review 5] a typed key level is refused when the range would be upside down, and nothing is stored
- when: the specialization row offers the player's class, or the classes the class row picked
- when: ActiveLine names the row that does not match
- when: [phase 3] a group turned off never reads Active now, as the picker's dot does not
- when: CharacterId takes Name-Realm as typed and gives a bare name the player's realm
- when: [phase 3] the open rows are session state that a profile switch clears
- when: Write stores a group's When through the seam, a seeded one's too, and refuses a shipped id
- when: the battleground names come from the shipped sets, by instanceID
- when: [final 6] a typed character takes the client's case; the Resolver matches one in any case
- when: [final 2, 11] ResolveValue maps a typed value onto the token or id its row stores, or refuses it
- when: [drawers] Summary reads Any while a row is unset, else its values in the row's order
- when: [drawers] Summary gives the key level and the id rows a short phrase
- when: [drawers] SelectAll ticks every value the row offers, and never mutates its input
- when: [inherit] ActiveText judges an inheriting group by its parent's When
- when: [all] SetAll turns the whole kind on and off and keeps the listed ids; Summary names it
- when: [instances] a typed name finds any journal dungeon or raid, not the season's only
- when: [arena] the arena row: names, Summary, All arenas, the CLI value, and its tooltip
- when: [arena] Add the arena you are in reads the live snapshot, and refuses outside an arena

### test_page_groups.lua (67)

- groups page: [exit] a new group with a callout and a When shows first on the pad in that situation
- groups page: the picker lists every group by name, a seeded set among them, active ones dotted
- groups page: [band] the picker, New group and Preview while editing are one SimpleGroup's, after a group switch too
- groups page: General draws the group's rows, no Preview as; Duplicate and Delete act
- groups page: Callouts drags to reorder, removes, and copies a seeded callout in (P2)
- groups page: Add callout opens the popup for this group
- groups page: Reuse lists every callout as <group>: <callout>, a seeded one too
- groups page: Reuse on a seeded group leaves out its own callouts; another group offers them
- groups page: Reuse draws the group part in muted gold and the callout name in white
- groups page: Reuse sorts the whole list by group, then callout, ignoring case
- groups page: Reuse numbers same-named copies so each entry is unambiguous
- groups page: [review] Reuse names a node's callout with its battleground, so two sets' Farm nodes read apart
- groups page: the Reuse row stretches the dropdown and puts Add at the right edge, as tall as it
- groups page: Add callout spans the row to EDGE_INSET short of the right edge, as Reuse's Add
- groups page: Reuse + Add puts an independent copy at the end
- groups page: picking in Reuse alone adds nothing
- groups page: the edit glyph opens the popup filled in
- groups page: [review 3] the remove glyph asks, then deletes the callout
- groups page: deleting a group deletes its callouts
- groups page: a seeded set's General is any group's: Name, Enabled, Parent group, the icon, Duplicate, Delete
- groups page: a seeded set's Callouts tab is the callout table: Add callout, Reuse, a row per callout
- groups page: a seeded set's When tab edits it as any group's; Preview bakes each callout
- groups page: [review 5] the When tab refuses an upside-down key-level range
- groups page: [final 16] New group rebuilds the pads once, however many pads there are
- groups page: [final 3, 25] a user group's Defaults: Enabled on, Open the dial off, the rest kept, one rebuild
- groups page: [review] a child's Defaults keeps it inside its parent; a named reset takes it out
- groups page: [inherit] a child's Defaults ticks Inherit when conditions again and keeps its own When
- groups page: [restore] Restore built-in groups brings back a deleted set and says so; again, nothing is missing
- groups page: [restore] with every group deleted, General still offers Restore built-in groups
- groups page: [final 12] Duplicate says the copy is on no pad yet
- groups page: [nesting] a child's Duplicate tooltip says the copy sits in the same parent
- groups page: [drawers] the When tab draws one drawer per condition, closed, each with its summary
- groups page: [drawers] a header opens and closes its drawer; the open set is per group and survives a repaint
- groups page: [drawers] Select all ticks every value; Clear (Any) unsets the condition and keeps the drawer open
- groups page: [drawers] an id or key-level drawer has Clear (Any) alone, and Clear unsets it
- groups page: [final 20] the Instances row adds a typed id, removes one, and refuses a fraction or a negative
- groups page: [final 18] Add the instance you are in reads the instance at the click, not at the draw
- groups page: [icons] General shows the icon, Choose icon… and the swatch; the browser's Choose writes the group's icon
- groups page: [icons] General's clear glyph takes the group's icon and color off; idle with no icon
- groups page: [icons] General has no Icon box: the icon is chosen under an Icon label alone
- groups page: [icons] a glyph's swatch writes the group's color; a game icon chosen clears it in the same act
- groups page: [icons] the browser closes as Cancel when the settings window hides or the group is deleted
- groups page: [icons] a callout row in the Callouts tab draws its glyph in the callout's color
- groups page: [icons] a tinted callout row puts its image back to white when released (AceGUI's shared pool)
- groups page: [rows] a callout row reads gold name, the channel in its chat color, then the text
- groups page: [rows] a callout row cuts its text at 40 characters, escapes |, and shows the fallback icon
- groups page: [rows] a callout row's text cut counts UTF-8 characters, not bytes
- groups page: [icons] the swatch writes on a drag tick (OnValueChanged) with no confirm, as OK leaves it
- groups page: [nesting] General's Parent group offers the top-level groups but itself; a pick nests the group
- groups page: [nesting] a group that holds groups cannot take a parent: the dropdown is idle and says why
- groups page: [nesting] the picker lists each child indented under its parent
- groups page: [nesting] deleting a parent asks, saying its groups become top-level groups in its place
- groups page: [nesting] a pad's and a dial's Add a group leave out a child
- groups page: [preview table] Preview is the active-now line, then a table: each callout's name beside what it sends
- groups page: [preview table] a group holding groups shows a titled table for its own callouts, then one per child
- groups page: [review] a parent with no callouts of its own and one child titles the child's table
- groups page: [preview table] a situation change rewrites a row's text in place and lays the table out again
- groups page: [preview table] a group with no callouts says so, with no table
- groups page: [inherit] a seeded battleground's nodes carry no green dot in the open world
- groups page: [inherit] General's Inherit when conditions sits beside Parent group, grayed out with no parent
- groups page: [inherit] an inheriting group's When tab shows its parent's conditions, read-only
- groups page: [all] the battleground drawer's All battlegrounds dims and locks the list, which it keeps
- groups page: [all] a gap separates the Every condition line from the first drawer
- groups page: [arena] the arena drawer's All arenas dims and locks the list, which it keeps
- groups page: [R4] EditGroup opens the Groups page on that group and keeps the tab it was on
- groups page: [R4] EditGroup in combat prints the settings refusal and changes nothing
- groups page: [R4] EditGroup of a group that is gone opens nothing

### test_page_pads.lua (27)

- pads page: New pad makes a second pad holding every built-in, selects it, and the pad is built
- pads page: the Layout rows write the selected pad
- pads page: Grid columns is grayed out unless the orientation is Grid
- pads page: X and Y move the pad through its pad.point row; Reset puts it back
- pads page: General's visibility reaches the pad's state driver
- pads page: Groups lists the pad's groups; remove one, add it back at the end, drag to reorder
- pads page: the remove glyph takes a group off the pad without asking and keeps the group
- pads page: Delete pad asks, then the pad is gone, its frame released, and the page heals
- pads page: General's Unlock pads toggles the one lock
- pads page: [final 3, 15] Defaults puts the pad's rows back as one act: one rebuild
- pads page: [final 4] Defaults keeps the pad's position
- pads page: [final 26] New pad takes the lowest free number, so a delete never leads to two names alike
- pads page: [window tabs] the strip reads General first, then Layout, Pad header, Section header, Window, Buttons, Icons
- pads page: [window tabs] Pad header carries Size, Font, Background and Border under their headings
- pads page: [window tabs] Section header carries Size, Font, Background and Border, and writes the section table
- pads page: [window tabs] Window carries Background and Border, and no font and no Visibility
- pads page: General carries Visibility, Fade and Faded alpha under a Visibility heading, before its buttons
- pads page: [button] Buttons carries Size, Color, Border, Font and Glow, and Button width left Layout for it
- page pads: [shine] the Buttons tab has a Shine heading
- pads page: [B9] Icons carries its headings once each, a companion beside each swatch, and writes the pad
- pads page: [B9] the offsets are grayed out while the glow is off or in Button; its color never is
- pads page: [glow knobs] only the selected style's knobs show, and none while the glow is off
- pads page: [glow knobs] Offset comes right after Glow color, in the schema and on the tab
- pads page: [glow knobs] a Glow or Glow style write repaints the tab, so the right knobs appear
- pads page: [B9] Defaults puts the Icons rows back too, and its tooltip names them
- page pads: [polish] the page is titled Pad
- page pads: [polish] no user-facing string sends the player to a Comms Pad or Comms Dial page

### test_page_dials.lua (28)

- dials page: New dial makes a second dial holding every built-in, selects it, and builds QuickCommsDial2
- dials page: New dial takes the lowest free number, so a delete never leads to two names alike
- dials page: General has no Preview as (it is in Master controls); Enabled off takes the dial down
- dials page: Wheel writes wedges per ring and where it opens; X and Y move the dial; Reset puts it back
- dials page: a refused X or Y says why and puts the box back to the stored offset
- dials page: Defaults puts the dial's rows back as one act, and keeps its key and position
- dials page: [dial rework] no Binding tab: the key is set in Options -> Keybindings alone
- dials page: Groups switches Categories and Flat, and reorders the dial's groups
- dials page: the remove glyph takes a group off the dial without asking and keeps the group
- dials page: Preview lists the rings wedge by wedge, marking the one the dial opens on
- dials page: [final 20] at 12 wedges per ring the Preview names each wedge by its clock position
- dials page: Delete dial asks, then the dial is gone, its header released, and the page heals
- dials page: [final 11] the page's own plan builds are not timed as a surface's bake
- dials page: [B9] Icons follows Wheel, carries its headings once each, and writes the dial
- dials page: [glow knobs] only the selected style's knobs show, and a Glow or Glow style write repaints
- dials page: [labels] Labels shows or hides the wedges' names and styles them; off grays the font
- dials page: [slices] Slices writes the fill, gap and highlight, Hub the pointer, each color with its class color
- page dials: [polish] Slices tab has Slice gap and no Border heading
- page dials: [polish] Hub heading rows on the Hub tab
- dials page: [slices] every slice texture the dial names ships under media/textures
- dials page: [paging] Paging sizes, spaces and colors the arrows and page indicators; the dial follows
- page dials: [paging] Page indicator carries the background and border rows, their ranges and defaults
- dials page: [wheel] Icon offset moves the icons in or out; 0 is the ring radius
- page dials: [polish] a Hub tab right after Slices holds the Hub and Pointer headings
- page dials: [polish] tabs read Slices, Hub, Paging, Slice labels, Group labels, Icons
- page dials: [polish] Icon offset is on the Icons tab, not Wheel
- page dials: [polish] the page is titled Dial
- page dials: [shine] the Slices tab has a Shine heading

### test_page_share.lua (12)

- share page: two tabs, and a seeded set is ticked and exported as any group, its nodes with it
- share page: Defaults unticks everything and forgets the checked string; nothing in the profile changes
- share page: [phase 5] Export ticks a group; its callouts come along, and the string opens in the copy window
- share page: Export lists groups, pads and dials, and no callouts; a ticked group brings its callouts
- share page: [phase 5] Export with nothing ticked says so and opens nothing
- share page: [phase 5] Import checks a pasted string, reports it, then adds it as new members
- share page: [review] editing the box after Accept forgets the check: Import never adds the old string
- share page: [phase 5] an imported dial says where its key comes from
- share page: [phase 5] an imported group no shared pad or dial lists says where to add it
- share page: [phase 5] export and import are refused in combat; nothing is made or added
- share page: [phase 5] a profile switch forgets the ticks and the checked string
- share page: [phase 5] the export window is the LibKa0s copy window, built once and named for the addon

### test_check.lua (6)

- check: a seeded callout prints its line and channel
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

### test_sendengine.lua (30)

- sendengine: a send button is a named secure button registered for both edges
- sendengine: Arm sends exactly the line; Disarm clears both attributes and sends nothing
- sendengine: in combat, building, arming and disarming are declined, so nothing is blocked
- sendengine: RunOrQueue runs now out of combat
- sendengine: in combat the queue keeps the last write per key and drains once at combat end
- sendengine: Drop empties the queue and nothing runs at combat end
- sendengine: a failing queued entry is reported and the others still run
- sendengine: Teardown in combat holds one PLAYER_REGEN_ENABLED and releases it when it fires
- sendengine: [audit QC-06] the held stand-down registers through NS.SafeRegisterEvent, into NS.rejectedEvents
- sendengine: [audit QC-06] a refused hold raises nothing and keeps the teardown held
- sendengine: CancelTeardown releases the held registration without running it
- sendengine: the visibility driver is set out of combat and declined in it
- sendengine: [firewall] no other shipped file makes a secure call (spec §9)
- sendengine: [fix wave] the firewall's patterns catch every Secure* template and SetAttribute spelling
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
- sendengine: [phase 4] a dial header is a named click handler for the down edge, hidden; none in combat
- sendengine: [phase 4] a wedge is wrapped before it is hooked, acts on the up edge, and only a left click is a press
- sendengine: [phase 4] attributes, frame refs and snippets are written out of combat only, never blocked
- sendengine: [keys] no override binding is written: a dial's key is WoW's own binding (modules/Dial.lua)

### test_dial_secure.lua (16)

- dial secure: the header is QuickCommsDial<n>, hidden until the toggle opens it; open, the dial owns Escape and 1-8
- dial secure: [exit] a group wedge opens its ring (the two-stroke); a callout wedge sends once and closes
- dial secure: [review 2] right click, Escape and the hub close without sending; the hub goes up a ring first
- dial secure: [review 5] the wheel turns pages; the number keys pick the shown ring's wedges
- dial secure: [exit] in combat the dial opens, switches rings and sends, with nothing blocked
- dial secure: open at the cursor anchors the hub to it; a dial with no ring opens nothing
- dial secure: [review 6] Open from the insecure side takes no key; the key still closes it; out of combat only
- dial secure: [final 1] a middle or side click on a callout wedge sends nothing and closes; on the hub it closes
- dial secure: [final 12] the down edge alone does nothing: no send, no ring switch, the dial stays open
- dial secure: [final 13] a page turn releases the number keys the new page has no wedge for
- dial secure: [final 2] opening one dial closes another that is open; closing it leaves no key bound
- dial secure: [firewall] no snippet writes an attribute; the ring on screen lives in the header's environment
- dial secure: [polish] catcher and SliceAt agree
- dial secure: [polish] an outside click closes a key-opened dial, in combat
- dial secure: [polish] display open shows no screen catcher
- dial secure: [polish] closing hides the screen catcher

### test_preview.lua (23)

- preview: test mode turns on and off, announcing each edge once
- preview: a start in combat is refused with one line
- preview: the start of combat ends test mode, with one line
- preview: test mode still ends when lockdown has already begun at the combat edge
- preview: the stand-down ends test mode silently, and stood down a start is refused
- preview: [phase 3] Preview as Arena builds the pad from the arena snapshot, every button disarmed
- preview: [review 3] a previewed button sends nothing and reports nothing
- preview: [review 3] a previewed solo button prints nothing, even with the self fallback
- preview: [review 3] combat ends it with one line, and the live buttons come back armed
- preview: [phase 3] refused in combat and while disabled, with one line each
- preview: [review 3] the stand-down ends it silently, and so does closing the settings window
- preview: [phase 3] test mode and Preview as are one switch at a time
- preview: [phase 3] the menu: Current, M+, each dungeon, each raid difficulty, Arena, each battleground, World
- preview: [phase 3] a dungeon entry reads M+ · <dungeon> · <spec> (spec §13.3)
- preview: [phase 3] the Preview as row and `/qc preview` drive the same switch
- preview: [final 13] `/qc preview` reads the situation's name without regard to case
- preview: [final 10] a dungeon preview fills {dungeon}, and the header names the preview as its menu does
- preview: [echo] a previewed button prints [QC] /<slash> <resolved text>, and still sends nothing
- preview: [echo] the slash follows the channel the previewed situation resolves
- preview: [echo review 3] a padlocked previewed button echoes its line, naming no lock
- preview: [echo] a live button prints nothing extra
- preview: [echo] the edit preview echoes too, and a press in combat prints without writing
- preview: [echo] a previewed dial wedge prints the line too

### test_edit_preview.lua (14)

- edit preview: every pad shows only the edited group, whatever its When says, and sends nothing
- edit preview: a battleground set shows its own callouts and every node, outside the battleground
- edit preview: every dial shows only the edited group
- edit preview: it ends back to the live pads, and Preview as and test mode come back after it
- edit preview: combat ends it with one line and the live buttons come back armed; a start in combat is refused
- edit preview: with Preview as on too, combat says so once
- edit preview: closing the settings window and the stand-down end it
- edit preview: a group deleted while previewed leaves the live pads
- edit preview: the why lines say the group is being edited
- edit preview: Preview while editing is a saved Behavior setting, on by default, drawn only in the Groups band
- edit preview: showing the Groups page previews the selected group; a pick follows; hiding the page ends it
- edit preview: the band's Preview while editing box sits under the picker and turns it off and on
- edit preview: the Groups page drawn in combat does not start it
- edit preview: it comes back when combat ends with the Groups page still on screen

### test_master.lua (5)

- master: the frame defaults are spec §5.1's: always shown, scale and alpha 1, locked
- master: /qc unlock and /qc lock write the Lock frame row's path and confirm on one line
- master: the launcher's Locked and Test mode entries call the same handlers
- master: /qc test toggles test mode, and in combat says why it will not
- master: the Test mode row reads and writes the one switch, and Reset all ends it

### test_pad_layout.lua (21)

- layout: horizontal puts a section's buttons on one row under the header
- layout: a titled section draws its label row first
- layout: [section header] opts.titleH above 0 fixes the title rows' height; 0 keeps it automatic
- layout: grid wraps at its column count; vertical is one column
- layout: the style sets the cell
- layout: [B3] narrow buttons never make the pad narrower than its header needs
- layout: [icon only] opts.minWidth is the pad's floor; without it the floor is MIN_PAD_W
- layout: [B1] a section title equal to the header's situation is not drawn; a tab's title is
- layout: [review] a larger Look font grows the button and title rows; the default size changes nothing
- layout: leftward growth mirrors the row; collapsed is the header alone
- layout: [B2] upward growth puts the header at the bottom and stacks the sections up from it
- layout: [B2] the pad's anchor is its growth edge; a drop is converted to that edge exactly
- layout: groups-as picks the sections: sections, merged, one tab at a time
- layout: the wheel steps tabs and wraps both ways
- layout: the visibility expression combines the master and the pad
- layout: the fade follows combat and the mouse, under the master alpha
- layout: [bg subgroups] a grid pad sets a parent's small child sections side by side
- layout: [bg subgroups] only one parent's children pack, only in a grid, only while they fit
- layout: [bg subgroups] packed rows mirror for left growth and stay bottom-aligned growing up
- layout: [window] the header row's height moves every row and is the collapsed pad's height
- layout: [button] a Button height above 0 is the labeled button's height; 0 is automatic; icon-only stays square

### test_dial_layout.lua (29)

- dial layout: four wedges sit on N, E, S and W, clockwise from the top
- dial layout: slices are Auto, 4, 6, 8 or 12; a page is 12 at most, 8 on a ring that holds rings
- dial layout: [auto] one wedge is W, two W and E, three W, N and E, four W, N, E and S; more spread from W
- dial layout: [review 5] more items than wedges go on plain pages, the rest on the last
- dial layout: [nav] a paged ring's pill, dots and arrows sit in one row under the disc and its labels
- dial layout: [hit] the Icon offset moves the wedges in; a bigger pointer sits further out
- dial layout: [exit] Categories with several groups opens on the ring of groups; a group wedge opens its ring
- dial layout: several groups open on the group ring; one group opens straight on it
- dial layout: [review 5] Flat puts every callout on the first ring, highest group first, paged
- dial layout: nothing to show is no ring at all; an empty group is left out
- dial layout: the pointer follows the cursor outside the dead zone
- dial layout: [final 6] a label is anchored by its side, wholly outside the disc; the ring title clears the N label
- dial layout: [final 20] past eight wedges each gets its own direction, as a clock position
- dial layout: [phase 5] a node set's nodes sit on their compass winds; the middle node takes N
- dial layout: [polish] a node set's own callouts take one wedge on the first free wind; the nodes stay pinned
- dial layout: [review 6] [phase 5] nodes that cannot all be pinned keep their shipped order
- dial layout: [bg subgroups] a free node takes a wind left after the middle ones; the set's own wedge keeps its place
- dial layout: [bg subgroups] a set with more children than winds falls back to its unpinned, paged ring
- dial layout: [review 6] a pinned ring ignores the dial's slices; Flat keeps its paging
- dial layout: [icons] a ring entry carries its group's icon color, a send entry its callout's
- dial layout: [polish] fixed 4 places 1-4 items W; W,E; W,N,E; W,N,E,S
- dial layout: [polish] auto keeps its shapes from W
- dial layout: [polish] fixed 8 with 2 items fills W then clockwise
- dial layout: [polish] slice shift
- dial layout: [polish] auto cap
- dial layout: [polish] auto cap at 128 px pages the ring
- dial layout: [polish] SliceAt
- dial layout: [polish] Rings gives every unpinned item its place
- dial layout: [art] DL.ARC is gone; every dial texture the dial modules name ships

### test_surfaces.lua (30)

- surfaces: in a key the default pad's plan is the M+ set, baked to /p
- surfaces: [review 5] a refused callout is a slot with its reason and no line
- surfaces: a node battleground gives one section per node, baked to /i
- surfaces: a Say callout locked by an encounter lights the plan's lockdown chip
- surfaces: solo with the self fallback, a smart callout carries the text to print
- surfaces: the bake context fills {me} from the client
- surfaces: a disabled seeded set leaves the plan
- surfaces: the test plan is placeholder buttons that carry no line
- surfaces: test mode's placeholders wear the built-in callouts' names and icons
- surfaces: test mode's dial holds the four test groups
- surfaces: test mode writes nothing to the profile
- surfaces: the first situation read builds the default pad, armed and shown
- surfaces: ACTIVE_GROUPS_CHANGED is sent once per real change of a pad's active groups
- surfaces: [review 1] a situation change in combat queues: nothing blocked, stale shows, combat end rebuilds
- surfaces: [review 1] a profile switch in combat queues the new profile's pads
- surfaces: [fix wave] enabled in combat (a /reload mid-pull): combat end builds the pad, the queue empties
- surfaces: a setting written in combat waits for combat end, with the stale hint
- surfaces: an encounter lockdown in combat padlocks a Say button and lights the lockdown chip, nothing blocked
- surfaces: test mode draws placeholders that send nothing; combat start brings the live buttons back
- surfaces: if lockdown has already begun at the combat edge, test mode's end is queued, not blocked
- surfaces: disabled out of combat, every pad hides and every button disarms; enabled, they return
- surfaces: [review 2] disabled mid-combat: nothing blocked, one held registration, finished at combat end
- surfaces: [fix wave] disabled then enabled inside one combat: the pad is shown and armed after it
- surfaces: [phase 3] WhyLines names each shown group in order, then the locks
- surfaces: [phase 3] WhyLines in a key explains the seeded set's matched row; a preview says so
- surfaces: [icons] a slot carries its callout's icon color, a dial's group entry its group's
- surfaces: [nesting] a parent draws its own section, then one per child whose When matches
- surfaces: [nesting] a dial draws a parent's own callouts and a ring per child whose When matches
- surfaces: [nesting] a parent that draws nothing leaves its surface with nothing active
- surfaces: [inherit] a child that inherits shows wherever its parent's When matches, whatever its own says

### test_pad_render.lua (23)

- render: Dress builds a button's regions once, each its own object
- render: [audit QC-07] the button's padlock is the catalog's lock mark, tinted gold; the Blizzard art is the nil fallback
- render: an armed button shows its name, no channel letter, no lock, no dim; its tooltip names the channel
- render: [review 5] a refused button is dimmed and its tooltip says why
- render: a locked button shows the padlock and names the lock; RefreshLock follows the slot
- render: the style decides icon and label
- render: a test-mode button and a solo self-print button are not dimmed, and say what they do
- render: flashes take the result's color; the cooldown dims and clears
- render: the situation chip names the content, the dungeon and the key
- render: the header shows the lockdown chip and the stale hint on demand; no test label
- render: the drag-strip seam builds a hidden strip, and answers nil without the library
- render: [R3] the strip label is the pad's name, then PREVIEW or TEST MODE in green
- pad render: [phase 3] a previewed slot's tooltip shows its line and says it sends nothing
- render: [phase 5] a pad's Look is a font and a skin; the defaults are the skin a pad always wore
- render: [review] the skin's 1px inner line is kept only on the default flat 1px edge
- render: [review] a button's label runs to the button's right edge, on one line
- render: [phase 5] Use class color takes the player's class color and keeps the swatch's alpha
- render: [window] the section titles wear the Section header tab's font, gold by default
- render: [section header] SectionLook: no band by default, then the band's skin and the text's inset
- render: [icons] a glyph button is drawn in its color; the button repainted with another icon is white again
- render: [B3] a button's label is one line, and hidden when the button leaves it no room
- pad render: [shine] a look on the Buttons tab paints every button
- pad render: [shine] the pad's look leaves the dial alone

### test_pad.lua (45)

- pad: the default pad shows the M+ callouts, each button armed with its baked line
- pad: [review 5] a refused button is dimmed and disarmed: a click sends and reports nothing
- pad: [review 4] a hidden or locked pad still rebuilds; the driver hides; the strip stays hidden
- pad: a rebuild with fewer buttons parks the rest, disarmed, for the next
- pad: [registry] no file but Library writes a surface's point
- pad: the drag saves the point; locked or in combat it does not move; Reset position clears it
- pad: [fix 1] combat starting mid-drag ends the drag on the edge; the stop is never blocked
- pad: [fix 1] a drag caught after lockdown began is stopped and saved when combat ends
- pad: tabs show one section; the wheel steps them out of combat and is refused in it
- pad: collapse hides the buttons out of combat and is refused, with one line, in it
- pad: a send result flashes its buttons; a press dims every button for the guard window
- pad: the fade follows the mouse and combat through SetAlpha alone
- pad: Sync releases a pad no plan names: hidden, its buttons disarmed
- pad: [fix wave] a profile switch, a switch back and a profile reset each move the pad to that profile's point
- pad: [fix wave] a rebuild during a drag leaves the dragged frame where the cursor has it
- pad: [fix wave] a held drag survives a profile switch in combat: stopped at combat end, nothing blocked
- pad: [fix wave] a held drag on a stand-down in combat is stopped by the held teardown
- pad: [fix wave] a locked button's press is not tracked: no guard, no drop, one lock note
- pad: [fix wave] tabs switch on a wheel over a button or the pad, not only the header
- pad: [fix wave] in combat Reset position, Apply and Release do no protected work; combat end anchors
- pad: [review 5] too long, and solo with no fallback: dimmed, disarmed, the reason shown, a click does nothing
- pad: [phase 3] a held drag whose stand-down is canceled in the same combat is stopped at combat end
- pad: [phase 3] a new drag clears a stale held stop, so the next rebuild re-anchors
- pad: [phase 3] the header's tooltip says why each group shows, unless the player turned it off
- pad: [phase 5] the pad wears its Section header and Main window tabs: the titles' font, the edge and body
- pad: [window] the header wears its own block: gold outlined 16-point text over nothing by default, then what it is given
- pad: [window] the header's text starts at the section titles' left edge, in every growth
- pad: [icon only] the pad is as wide as its buttons when the header is narrower, else as the header needs
- pad: [icon only] a PvP match's lockdown chip, shown out of combat, widens the header row by itself
- pad: [button] a button wears the Buttons tab: the owner's default body, edge, label and size, then what it is given
- pad: [button] the button glow is off by default, then wraps the whole button in its style, and goes with the button
- pad: [review 5] a font or border this machine does not have draws the default, with no error
- pad: [B1] a group named as the header's situation draws no title row of its own
- pad: [B2] down growth pins the pad's top edge; the header is on top and the strip above
- pad: [B2] up growth pins the bottom edge, puts the header at the bottom and the strip below
- pad: [R3] the strip reads the pad's name and PREVIEW / TEST MODE, spans the pad, and shows while locked
- pad: [bg buttons] the strip matches the pad's width through a resize, and below an up-growing pad
- pad: [section header] each title sits on a band its row wide, dressed by the Section header tab
- pad: [R4] each drawn title takes a right-click to edit its group; a left-click does nothing
- pad: [R4] the title's tooltip says Right-click to edit this group
- pad: [R4] in tabs mode the tab's title edits the group the tab shows; the wheel moves it
- pad: [R4] merged pads, collapsed pads and test mode's placeholder groups have no title to click
- pad: [bg subgroups] Alterac Valley draws its nineteen objectives two to a row, each title its block wide
- pad: [polish] header reads Quick Comms: World
- pad: [polish] header reads Quick Comms: M+ · Windrunner Spire +14

### test_dial.lua (63)

- dial: Apply builds QuickCommsDial<n> with a ring per page, each callout wedge armed with its baked line
- dial: a refused callout is a dimmed, disarmed wedge; a ring wedge is disarmed
- dial: [audit QC-07] a wedge's padlock is a catalog mark, with the Blizzard art as the nil fallback (the hub's close retired)
- dial: the hub shows the lockdown chip, the stale hint and TEST MODE; the pointer runs only while open
- dial: a press dims every wedge and button for the guard window; a drop stays red long enough to reopen and see
- dial: Release closes, disarms and forgets a dial; HideAll also releases the keys
- dial: Sync applies each planned dial at its place in the order, and opens dial 1 in test mode
- dial: the first situation read builds the default dial, closed; its key is WoW's own binding
- dial: [keys] a key set in Options -> Keybindings is the dial's key; a dial past the fourth has none
- dial: [exit] in Arathi Basin the dial opens on the groups; the set, Lumber Mill, then INC sends
- dial: [exit] on a raid boss the dial opens and a click on a wedge sends, with nothing blocked
- dial: [exit] the Categories two-stroke: a group wedge opens its ring, a callout wedge sends
- dial: test mode opens dial 1 with placeholder wedges that send nothing, and takes no key
- dial: combat start ends test mode and the live dial comes back closed
- dial: [review 6] test mode ended by a combat whose lockdown began first: no key held, closed at combat end
- dial: Preview as opens dial 1 on the previewed situation, and its wedges send nothing
- dial: [review 3] a wedge change in combat waits for combat end, behind the hub's stale hint; the key works
- dial: [review 1] the key opens nothing where no group is active, and is the game's again while disabled
- dial: [review 3] disabled in combat with the dial open: nothing blocked; combat end hides it and frees the key
- dial: [keys] a profile switch keeps the key: it is WoW's binding, never the profile's
- dial: Reset position puts every pad and dial back, through their point rows, on one line
- dial: the hub's tooltip says why each group shows, unless the player turned it off
- dial: Bindings.xml offers Open Comms Dial 1 to 4, each clicking that dial's header with Toggle
- dial: [keys] Toggle Comms Pads runs exactly /qc toggle's handler, from a key bound in WoW's menu
- dial: the key bindings menu's click opens the dial, even while it is hidden
- dial: [final 2] two dials: opening the second closes the first, and the number keys go with it
- dial: [final 5] test mode opens dial 1 once: a rebuild keeps it open, and after the player closes it, closed
- dial: [phase 5] Arathi Basin's node wedges sit on their winds: Lumber Mill is SW, Blacksmith N
- dial: [review 6] on a four- or six-slice dial every node shows, and the number keys pick the shown wedges from N
- dial: [icons] a wedge draws its glyph in its color; repainted untinted, it is white again
- dial: [rework] a paged ring turns with its arrows and the Left and Right keys; its dots mark the page
- dial: [rework] wedges have no backdrop; the slices, the wedges and their hit squares follow the ring radius
- dial: [slices] each place is a tinted slice; the slice the cursor points into lights, anywhere but the hub
- dial slices: [polish] no border lines are drawn
- dial slices: [polish] a gap shifts each fill outward along its bisector
- dial slices: [polish] gap 0 draws as before
- dial: [paging] the indicators sit on a rounded background sized to the row; off hides it
- dial: [paging] every dot and the pill has a border, its size plus twice the Dot border; 0 draws none
- dial: [front] the hub, its circle and the pointer draw over the slices
- dial: [tooltip] a wedge's tooltip sits outside the dial: above by default, on the Labels tab's side
- dial: [pointer] the pointer is a catalog glyph, sized, colored and placed by the Slices tab, and can be off
- dial: [labels] the Label offset moves every label out from the center; the title and the page row follow
- dial: [polish] a click near the hub sends the lit slice, in combat
- dial: [polish] a click with a modifier held still sends the slice, in combat
- dial: [polish] just outside the hub's circle, on a diagonal, the slice lights and clicks, in combat
- dial: [polish] a click inside the hub's circle runs the hub, any modifier held, in combat
- dial: [polish] the hub's hover shows from the tracker inside its circle and clears outside
- dial: [polish] the dial's key still opens and closes it with the header's mouse off, in combat
- dial: [polish] a click on an empty place does nothing; in the hub it sends nothing
- dial: [polish] hovering anywhere in a slice shows its tooltip
- dial: [polish] wedges take no mouse; keys still click by name
- dial: [polish] a built dial closes on a click outside it, in combat
- dial: [polish] a ring hidden under the hover clears its slice, tooltip and hover glow
- dial: [polish] default hub is a solid gold circle of 22 on a 40 backdrop, no red X
- dial: [polish] hub style solid draws the backdrop rim when its border size is set
- dial: [polish] hub style ring is a hollow ring of the circle size and line width
- dial: [polish] hub style target is a ring with a center dot
- dial: [polish] hub style rimmed is a filled circle on a backdrop with its own rim
- dial: [polish] hub size moves the inner edge everywhere
- dial: [polish] group labels take their font and hide when off
- dial: [art] RingTexture picks the nearest step
- dial: [art] the hub draws textures, not segments
- dial: [art] the pill is three pieces with round ends

### test_dial_shine.lua (8)

- dial: [shine] each look builds its recipe on every slice
- dial: [shine] the overlay follows the slice
- dial: [shine] the orb's bead sits on the slice's inscribed circle, with no dots
- dial: [shine] fluid's blooms span the slice's outer part
- dial: [shine] sprites sit in the slice's frame
- dial: [shine] frost's streak and Bevel are each slice's own edge set
- dial: [shine] fewer slices hide the rest
- dial: [shine] the dial's look leaves the pad alone

### test_icon_style.lua (9)

- icon style: the defaults draw the owner's look on a button and on a wedge
- icon style: zoom crops through SetTexCoord, desaturate and alpha reach the texture
- icon style: the tint multiplies a glyph's own color; white keeps it
- icon style: a pad's icon size feeds the button's geometry
- icon style: a button's border is off by default; on, it is a backdrop over the icon in its color
- icon style: a wedge's border is a round ring behind its icon, icon plus twice the thickness
- icon style: a wedge's ring never grows past the wedge, so it cannot reach the next wedge or its label
- icon style: a pad saved before the Icons tab reads like a new one (fillShape backfills `icon`)
- icon style: [polish] dial icon size reaches 128, pad stays 40

### test_glow.lua (11)

- glow: off by default, so a button starts nothing
- glow: each style starts with the knob table's arguments, on the icon, under the addon's key
- glow: a repaint that changes nothing calls the library not at all; a setting restarts it
- glow: On hover starts on enter and stops on leave
- glow: After sending glows from the send result for SEND_SECONDS, then stops
- glow: a button a rebuild leaves unused stops its glow, and so does every button of a released pad
- glow: in combat a hover glow starts and stops with no protected call; an Icons write waits for combat end
- glow: a wedge glows on its icon too, and on hover
- glow: on a dial, After sending glows again from the next open within DROP_SECONDS
- glow: on a dial, an open later than DROP_SECONDS after the send shows no send glow
- glow: the stand-down puts out a running send glow even when the frames' release is held

### test_shine.lua (7)

- shine: the catalog lists None and the seven looks
- shine: every catalog path exists
- shine: Resolve
- shine: Apply covers the whole button in three pieces
- shine: a square button is the art whole
- shine: blooms only for fluid
- shine: the button's own size when none is given

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
| test_mock_secure.lua | 28 |
| test_bus.lua | 2 |
| test_surface_parity.lua | 15 |
| test_setup.lua | 27 |
| test_database.lua | 18 |
| test_profile.lua | 9 |
| test_schema.lua | 19 |
| test_slash.lua | 20 |
| test_disabled.lua | 21 |
| test_diagnostics.lua | 13 |
| test_compat.lua | 12 |
| test_restrictions.lua | 16 |
| test_situation.lua | 16 |
| test_tokens.lua | 8 |
| test_channels.lua | 8 |
| test_bake.lua | 12 |
| test_share.lua | 37 |
| test_resolver.lua | 13 |
| test_builtins.lua | 21 |
| test_gameids.lua | 4 |
| test_library.lua | 74 |
| test_members.lua | 28 |
| test_editors.lua | 17 |
| test_callout_popup.lua | 38 |
| test_icon_browser.lua | 36 |
| test_eui_skin.lua | 10 |
| test_groups_when.lua | 20 |
| test_page_groups.lua | 67 |
| test_page_pads.lua | 27 |
| test_page_dials.lua | 28 |
| test_page_share.lua | 12 |
| test_check.lua | 6 |
| test_send_guard.lua | 10 |
| test_sendengine.lua | 30 |
| test_dial_secure.lua | 16 |
| test_preview.lua | 23 |
| test_edit_preview.lua | 14 |
| test_master.lua | 5 |
| test_pad_layout.lua | 21 |
| test_dial_layout.lua | 29 |
| test_surfaces.lua | 30 |
| test_pad_render.lua | 23 |
| test_pad.lua | 45 |
| test_dial.lua | 63 |
| test_dial_shine.lua | 8 |
| test_icon_style.lua | 9 |
| test_glow.lua | 11 |
| test_shine.lua | 7 |
| test_vendor_sync.lua | 3 |
| test_eol.lua | 2 |
| test_prose.lua | 15 |
| test_layout_cap.lua | 13 |
| test_diagnostics_contract.lua | 8 |
| test_lizard_sighted.lua | 8 |
| Skipped | 1 |
| **Total** | **1086** |
