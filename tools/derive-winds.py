# tools/derive-winds.py — derive each battleground node's compass wind from the client's AreaPOI table
# and check defaults/BuiltIns_Battlegrounds.lua against it (spec §12.1). Dev-only: never loaded by the
# client or the TOC, and .pkgmeta-ignored (layout-§1, "Where an authored generator lives"). Python 3,
# standard library only.
#
#   python3 -I tools/derive-winds.py --fetch DIR    download AreaPOI into DIR (a new directory)
#   python3 -I tools/derive-winds.py DIR            derive from DIR and check; exit 1 on any mismatch
#
# A node's wind: its position (Pos_0 is north, Pos_1 west) against the center of its set's nodes,
# north up, the nearest of eight; a node within a third of the farthest node's distance from that
# center is "middle". Each node is named by its AreaPOI id with the name that row must carry, so a
# wrong id fails rather than placing the wrong point. Every node defaults/ ships must be below, and
# every node below must be shipped with the wind derived here. A child with no fixed place (wind
# "free", DialLayout.FREE) or none at all (Alterac Valley's nineteen, more than the eight winds) is
# not a node here, and a set with no node of its own is not checked.
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import client_tables as ct  # noqa: E402

# set key -> (map id, [(node key, AreaPOI id, the POI's name)])
NODES = {
    "ab": (2107, [("stables", 6080, "Stables"), ("lumbermill", 6078, "Lumber Mill"),
                  ("blacksmith", 6079, "Blacksmith"), ("mine", 6076, "Gold Mine"), ("farm", 6077, "Farm")]),
    "eots": (566, [("felreaver", 1944, "Fel Reaver Ruins"), ("bloodelf", 1941, "Blood Elf Tower"),
                   ("draenei", 1950, "Draenei Ruins"), ("magetower", 1947, "Mage Tower"),
                   ("flag", 1962, "Netherstorm Flag")]),
    "bfg": (761, [("lighthouse", 2412, "Lighthouse"), ("waterworks", 2405, "Waterworks"), ("mines", 2404, "Mines")]),
    "dwg": (2245, [("market", 6544, "Market"), ("farm", 6546, "Farm"), ("quarry", 6543, "Quarry"),
                   ("shrine", 6545, "Shrine"), ("ruins", 6547, "Ruins")]),
    "ioc": (628, [("docks", 2356, "Docks"), ("hangar", 2350, "Hangar"), ("workshop", 2345, "Workshop"),
                  ("quarry", 2361, "Quarry"), ("refinery", 2366, "Refinery")]),
    # Wintergrasp's southern towers are one objective; Winter's Edge, the middle tower, places it.
    "wg": (2118, [("fortress", 6027, "Wintergrasp Fortress"),
                  ("brokentemple", 6061, "Broken Temple Vehicle Workshop"),
                  ("sunkenring", 6060, "Sunken Ring Vehicle Workshop"),
                  ("westspark", 6063, "Westspark Vehicle Workshop"),
                  ("eastspark", 6068, "Eastspark Vehicle Workshop"),
                  ("towers", 6065, "Winter's Edge Tower")]),
}
WINDS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
SHIPPED = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "defaults", "BuiltIns_Battlegrounds.lua")


def winds_of(poi, mapid, nodes):
    pos = {}
    for key, pid, name in nodes:
        r = poi.get(pid)
        if r is None:
            ct.fail("AreaPOI has no row {} ({})".format(pid, name))
        if int(r["ContinentID"]) != mapid or r["Name_lang"] != name:
            ct.fail("AreaPOI {} is '{}' on map {}, not '{}' on {}".format(
                pid, r["Name_lang"], r["ContinentID"], name, mapid))
        pos[key] = (float(r["Pos_0"]), float(r["Pos_1"]))
    cx = sum(p[0] for p in pos.values()) / len(pos)
    cy = sum(p[1] for p in pos.values()) / len(pos)
    far = max(math.hypot(x - cx, y - cy) for x, y in pos.values())
    out = {}
    for key, (x, y) in pos.items():
        north, east = x - cx, -(y - cy)
        a = (math.degrees(math.atan2(east, north)) + 360) % 360
        out[key] = "middle" if math.hypot(north, east) < far / 3 else WINDS[int((a + 22.5) // 45) % 8]
    return out


def shipped():
    text = open(SHIPPED, encoding="utf-8").read()
    out = {}
    # each set's text runs from its nodeBattleground( call to the next set's declaration
    starts = [(m.start(), m.group(1)) for m in re.finditer(r'^nodeBattleground\("(\w+)"', text, re.M)]
    if not starts:
        ct.fail("no nodeBattleground(...) in " + SHIPPED)
    for at, key in starts:
        end = re.compile(r'^(nodeBattleground|flatBattleground|BI\.Group)\(', re.M).search(text, at + 1)
        body = text[at:end.start() if end else len(text)]
        # a node row: { "key", L["Name"], "WIND", glyph, color[, rows] }
        nodes = {k: w for k, w in re.findall(r'\{ "(\w+)", L\["[^"]+"\], "(\w+)"[ ,}]', body) if w != "free"}
        if nodes:
            out[key] = nodes
    if not out:
        ct.fail("no nodeBattleground(...) in " + SHIPPED)
    return out


def main(argv):
    if len(argv) == 3 and argv[1] == "--fetch":
        print("fetched build " + str(ct.fetch(argv[2], ["AreaPOI"])))
        return
    if len(argv) != 2:
        ct.fail("usage: derive-winds.py --fetch DIR | derive-winds.py DIR")
    poi = {int(r["ID"]): r for r in ct.read(argv[1], "AreaPOI")}
    have, bad = shipped(), []
    if set(have) != set(NODES):
        bad.append("node sets shipped {} but derived {}".format(sorted(have), sorted(NODES)))
    for setkey, (mapid, nodes) in NODES.items():
        got = winds_of(poi, mapid, nodes)
        print(setkey + ": " + ", ".join("{} {}".format(k, got[k]) for k, _, _ in nodes))
        if have.get(setkey, {}) != got:
            bad.append("{}: shipped {}, derived {}".format(setkey, have.get(setkey), got))
    for b in bad:
        print("MISMATCH: " + b, file=sys.stderr)
    if bad:
        sys.exit(1)
    print("OK: {} node sets".format(len(NODES)))


if __name__ == "__main__":
    main(sys.argv)
