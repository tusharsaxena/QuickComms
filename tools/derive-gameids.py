# tools/derive-gameids.py — derive the instance-id extraction tests/test_gameids.lua holds
# (CLIENT_MAPS) and the season's candidate lists from the client's own data tables, and check the
# repository against them (spec §12.1, §13.2). Dev-only: never loaded by the client or the TOC, and
# .pkgmeta-ignored (layout-§1, "Where an authored generator lives"). Python 3, standard library only.
#
#   python3 -I tools/derive-gameids.py --fetch DIR    download the tables into DIR (a new directory)
#   python3 -I tools/derive-gameids.py DIR            derive from DIR and check; exit 1 on any mismatch
#
# What it checks, each a loud failure (exit 1):
#   - every CLIENT_MAPS row in tests/test_gameids.lua equals the row derived from Map (InstanceType)
#     and MapChallengeMode (a challenge map names it); an id Map does not have fails
#   - defaults/GameIds.lua's DUNGEONS are exactly the maps of the Mythic+ season SEASON
#     (MythicPlusSeasonTrackedMap -> MapChallengeMode)
#   - defaults/GameIds.lua's RAIDS are raid maps in the journal's Current Season tier under the launch
#     condition LAUNCH, and not a world-boss entry; a candidate not shipped is printed as NOT SHIPPED
#     (the owner's ruling decides it, never this script)
#   - defaults/GameIds_Instances.lua's INSTANCES are exactly the Encounter Journal's dungeons and
#     raids (JournalInstance -> a Map row of instance type 1 or 2, world-boss entries skipped)
#   - its ARENAS are exactly the arena maps (Map instance type 4), less DROPPED_ARENAS (legacy maps
#     a current arena of the same place replaced), and no two of them carry one name
#   - every id the two files ship has its CLIENT_MAPS row
#   - each spec id in SPECS names its class in ChrSpecialization
# It prints the derived CLIENT_MAPS block, the INSTANCES and ARENAS blocks and the build, for the
# header lines and for review as a diff.
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import client_tables as ct  # noqa: E402

TABLES = ["Map", "MapChallengeMode", "MythicPlusSeasonTrackedMap", "JournalTier",
          "JournalTierXInstance", "JournalInstance", "ChrSpecialization"]
SEASON = 34            # Midnight season 1's DisplaySeasonID in MythicPlusSeasonTrackedMap
CURRENT_TIER = 505     # the journal's "Current Season" tier (JournalTier.ID)
LAUNCH = 149388        # the AvailabilityCondition the launch season's raids carry in that tier
WORLD_BOSSES = 2       # JournalInstance.Flags bit: a world-boss entry, not an instance
SPECS = {1480: 12}     # specID -> ClassID: the Demon Hunter's Devourer
PARTY, RAID, ARENA = 1, 2, 4   # Map.InstanceType
# Arena maps not shipped: legacy copies a newer map of the same arena replaced (Map's own names mark
# them). The owner rules on this list; this script prints it and checks each is an arena map.
DROPPED_ARENAS = {559: "Nagrand Arena (old)", 562: "zzOldBlade's Edge Arena"}
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def block(path, start):
    """The body of the Lua table that opens on the line starting `start`, comments stripped."""
    if not os.path.isfile(path):
        ct.fail("no " + path)
    text = open(path, encoding="utf-8").read()
    m = re.search(re.escape(start) + r"(.*?)\n\}", text, re.S)
    if not m:
        ct.fail("no '" + start + "' table in " + path)
    return re.sub(r"--[^\n]*", "", m.group(1))


def lua_ids(path, start):
    """The integers listed in the Lua table that opens on the line starting `start`. The body must be
    integers and commas only: anything else fails, so no entry is ever skipped silently."""
    body = block(path, start)
    if re.search(r"[^\d,\s]", body):
        ct.fail("'" + start + "' in " + path + " holds something other than whole ids")
    return [int(x) for x in re.findall(r"\d+", body)]


def print_ids(name, ids, maps):
    """A shipped id list, one id a line with its client name, as defaults/ holds it."""
    print(name + " = {")
    for i in ids:
        print("    {},  -- {}".format(i, maps[i]["MapName_lang"]))
    print("}")


ROW = r"\[\s*(\d+)\s*\]\s*=\s*\{\s*type\s*=\s*(\d+)\s*,\s*challenge\s*=\s*(true|false)\s*,?\s*\}"


def fixture_rows(path):
    """CLIENT_MAPS's rows. Every `[id] =` entry in the block must parse as a row, however it is
    spaced or comma'd: one that does not fails, so the derivation never runs over fewer rows."""
    body = block(path, "local CLIENT_MAPS = {")
    rows = re.findall(ROW, body)
    entries = re.findall(r"\[\s*\d+\s*\]\s*=", body)
    if not rows:
        ct.fail("no CLIENT_MAPS rows in " + path)
    if len(rows) != len(entries):
        ct.fail("{} of CLIENT_MAPS's {} entries in {} are not {{ type = N, challenge = B }} rows".format(
            len(entries) - len(rows), len(entries), path))
    return {int(i): (int(t), c == "true") for i, t, c in rows}


def main(argv):
    if len(argv) == 3 and argv[1] == "--fetch":
        print("fetched build " + str(ct.fetch(argv[2], TABLES)))
        return
    if len(argv) != 2:
        ct.fail("usage: derive-gameids.py --fetch DIR | derive-gameids.py DIR")
    d = argv[1]
    maps = {int(r["ID"]): r for r in ct.read(d, "Map")}
    challenge = {int(r["ID"]): int(r["MapID"]) for r in ct.read(d, "MapChallengeMode")}
    challenged = set(challenge.values())
    bad = []

    fixture = fixture_rows(os.path.join(ROOT, "tests", "test_gameids.lua"))
    print("local CLIENT_MAPS = {")
    for i in fixture:
        if i not in maps:
            ct.fail(str(i) + " is not in the client's Map table")
        got = (int(maps[i]["InstanceType"]), i in challenged)
        print("    [{}] = {{ type = {}, challenge = {} }},  -- {}".format(
            i, got[0], str(got[1]).lower(), maps[i]["MapName_lang"]))
        if got != fixture[i]:
            bad.append("CLIENT_MAPS[{}] is {}, the client says {}".format(i, fixture[i], got))
    print("}")

    season = sorted(challenge[int(r["MapChallengeModeID"])] for r in ct.read(d, "MythicPlusSeasonTrackedMap")
                    if int(r["DisplaySeasonID"]) == SEASON)
    if not season:
        ct.fail("season " + str(SEASON) + " tracks no map")
    dungeons = sorted(lua_ids(os.path.join(ROOT, "defaults", "GameIds.lua"), "G.DUNGEONS = {"))
    if dungeons != season:
        bad.append("DUNGEONS {} are not season {}'s maps {}".format(dungeons, SEASON, season))

    journal = {int(r["ID"]): r for r in ct.read(d, "JournalInstance")}
    candidates = {}
    for r in ct.read(d, "JournalTierXInstance"):
        j = journal.get(int(r["JournalInstanceID"]))
        if int(r["JournalTierID"]) != CURRENT_TIER or int(r["AvailabilityCondition"]) != LAUNCH or not j:
            continue
        mid = int(j["MapID"])
        if mid in maps and int(maps[mid]["InstanceType"]) == 2 and not int(j["Flags"]) & WORLD_BOSSES:
            candidates[mid] = j["Name_lang"]
    if not candidates:
        ct.fail("the Current Season tier lists no raid under condition " + str(LAUNCH))
    raids = lua_ids(os.path.join(ROOT, "defaults", "GameIds.lua"), "G.RAIDS = {")
    for mid in raids:
        if mid not in candidates:
            bad.append("RAIDS lists {}, which is not a launch-season raid".format(mid))
    for mid in sorted(candidates):
        if mid not in raids:
            print("NOT SHIPPED: raid candidate {} {} (an owner ruling decides it)".format(mid, candidates[mid]))

    instances_file = os.path.join(ROOT, "defaults", "GameIds_Instances.lua")
    every = sorted({int(j["MapID"]) for j in journal.values()
                    if int(j["MapID"]) in maps and int(maps[int(j["MapID"])]["InstanceType"]) in (PARTY, RAID)
                    and not int(j["Flags"]) & WORLD_BOSSES})
    if not every:
        ct.fail("the journal lists no dungeon or raid")
    print_ids("G.INSTANCES", every, maps)
    instances = lua_ids(instances_file, "G.INSTANCES = {")
    if sorted(instances) != every or len(set(instances)) != len(instances):
        bad.append("INSTANCES differ from the journal's {} dungeons and raids: extra {}, missing {}".format(
            len(every), sorted(set(instances) - set(every)), sorted(set(every) - set(instances))))

    for mid, name in DROPPED_ARENAS.items():
        if mid not in maps or int(maps[mid]["InstanceType"]) != ARENA or maps[mid]["MapName_lang"] != name:
            bad.append("DROPPED_ARENAS {} is not the arena map '{}'".format(mid, name))
        else:
            print("DROPPED: arena {} {} (owner ruling)".format(mid, name))
    arenas_derived = sorted(i for i, r in maps.items() if int(r["InstanceType"]) == ARENA and i not in DROPPED_ARENAS)
    if not arenas_derived:
        ct.fail("the Map table lists no arena")
    names = [maps[i]["MapName_lang"] for i in arenas_derived]
    for n in sorted(set(x for x in names if names.count(x) > 1)):
        bad.append("two shipped arenas are named '{}': drop one in DROPPED_ARENAS".format(n))
    print_ids("G.ARENAS", arenas_derived, maps)
    arenas = lua_ids(instances_file, "G.ARENAS = {")
    if sorted(arenas) != arenas_derived or len(set(arenas)) != len(arenas):
        bad.append("ARENAS differ from the client's arenas: extra {}, missing {}".format(
            sorted(set(arenas) - set(arenas_derived)), sorted(set(arenas_derived) - set(arenas))))
    for mid in sorted(set(instances) | set(arenas)):
        if mid not in fixture:
            bad.append("{0} is shipped but has no CLIENT_MAPS row in tests/test_gameids.lua: "
                       "[{0}] = {{ type = {1}, challenge = {2} }},  -- {3}".format(
                           mid, maps[mid]["InstanceType"], str(mid in challenged).lower(), maps[mid]["MapName_lang"]))

    specs = {int(r["ID"]): r for r in ct.read(d, "ChrSpecialization")}
    for sid, cls in SPECS.items():
        if sid not in specs or int(specs[sid]["ClassID"]) != cls:
            bad.append("spec {} is not class {}'s".format(sid, cls))
        else:
            print("spec {} = {} (class {})".format(sid, specs[sid]["Name_lang"], cls))

    for b in bad:
        print("MISMATCH: " + b, file=sys.stderr)
    if bad:
        sys.exit(1)
    print("OK: {} map rows, {} dungeons, {} raids, {} instances, {} arenas, {} spec".format(
        len(fixture), len(dungeons), len(raids), len(instances), len(arenas), len(SPECS)))


if __name__ == "__main__":
    main(sys.argv)
