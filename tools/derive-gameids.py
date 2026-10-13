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
#   - each spec id in SPECS names its class in ChrSpecialization
# It prints the derived CLIENT_MAPS block and the build, for the header lines and for review as a diff.
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
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def lua_ids(path, start):
    """The integers listed in the Lua table that opens on the line starting `start`."""
    text = open(path, encoding="utf-8").read()
    m = re.search(re.escape(start) + r"(.*?)\n\}", text, re.S)
    if not m:
        ct.fail("no '" + start + "' table in " + path)
    return [int(x) for x in re.findall(r"^\s*(\d+),", m.group(1), re.M)]


def fixture_rows(path):
    text = open(path, encoding="utf-8").read()
    rows = re.findall(r"\[(\d+)\] = \{ type = (\d), challenge = (true|false) \}", text)
    if not rows:
        ct.fail("no CLIENT_MAPS rows in " + path)
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
    print("OK: {} map rows, {} dungeons, {} raids, {} spec".format(len(fixture), len(dungeons), len(raids), len(SPECS)))


if __name__ == "__main__":
    main(sys.argv)
