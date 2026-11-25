#!/usr/bin/env python3
"""tools/seeds/test_seeds.py: offline tests for tools/seeds/seeds.py (no network: tiny fixture
tables and seed files in a temporary folder). Run: python3 -m pytest -q tools/seeds

Mutation-checked: `test_apply_refuses_while_unruled` fails when the unruled guard in seeds.plan is
broken (`if left:` changed to `if False:`), and passes again once it is restored (2026-11-15).
"""

from __future__ import annotations

import csv
import gzip
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import seeds  # noqa: E402

GAMEIDS = """local _, NS = ...
-- fixture header
G.DUNGEONS = {
    2526,   -- Algeth'ar Academy
    658,    -- Pit of Saron (a note)
}
G.RAIDS = {
    2912,   -- The Voidspire
}

G.CLASSES = { "WARRIOR", "PALADIN" }

G.SPECS = {
    WARRIOR = { 71, 72 }, PALADIN = { 65, 66 },
}
"""

INSTANCES = """local _, NS = ...
G.INSTANCES = {
    33,  -- Shadowfang Keep
    409,  -- Molten Core
    500,  -- Old Name
    600,  -- Not In Journal
}

G.ARENAS = {
    572,  -- Ruins of Lordaeron
    999,  -- Gone Arena
}
"""

CLIENTS = """local _, NS = ...
local FOREVER_DUNGEONS = {
    36,   -- Deadmines
    -- a comment row
    2959, -- City of Dalaran
}

local FOREVER_RAIDS = {
    409,  -- Molten Core
}

local FOREVER_CLASSES = { "WARRIOR",
    "MAGE" }
"""

RETAIL = {
    "Map": [
        {"ID": "33", "MapName_lang": "Shadowfang Keep", "InstanceType": "1"},
        {"ID": "36", "MapName_lang": "Deadmines", "InstanceType": "1"},
        {"ID": "409", "MapName_lang": "Molten Core", "InstanceType": "2"},
        {"ID": "500", "MapName_lang": "New Name", "InstanceType": "1"},
        {"ID": "600", "MapName_lang": "Not In Journal", "InstanceType": "1"},
        {"ID": "658", "MapName_lang": "Pit of Saron", "InstanceType": "1"},
        {"ID": "700", "MapName_lang": "Fresh Dungeon", "InstanceType": "1"},
        {"ID": "757", "MapName_lang": "World Boss Raid", "InstanceType": "2"},
        {"ID": "2526", "MapName_lang": "Algeth'ar Academy", "InstanceType": "1"},
        {"ID": "2912", "MapName_lang": "The Voidspire", "InstanceType": "0"},
        {"ID": "572", "MapName_lang": "Ruins of Lordaeron", "InstanceType": "4"},
        {"ID": "1505", "MapName_lang": "Nagrand Arena", "InstanceType": "4"},
    ],
    "JournalInstance": [
        {"ID": "1", "Name_lang": "Shadowfang Keep", "MapID": "33", "Flags": "0"},
        {"ID": "2", "Name_lang": "Molten Core", "MapID": "409", "Flags": "0"},
        {"ID": "3", "Name_lang": "New Name", "MapID": "500", "Flags": "0"},
        {"ID": "4", "Name_lang": "Fresh Dungeon", "MapID": "700", "Flags": "0"},
        {"ID": "5", "Name_lang": "World Boss Raid", "MapID": "757", "Flags": "2"},
    ],
    "LFGDungeons": [
        {"ID": "10", "Name_lang": "Shadowfang Keep", "MapID": "33"},
        {"ID": "11", "Name_lang": "Molten Core", "MapID": "409"},
        {"ID": "12", "Name_lang": "Old", "MapID": "500"},
        {"ID": "13", "Name_lang": "Pit", "MapID": "658"},
        {"ID": "14", "Name_lang": "Academy", "MapID": "2526"},
        {"ID": "15", "Name_lang": "Voidspire", "MapID": "2912"},
    ],
    "ChrClasses": [
        {"ID": "1", "Filename": "WARRIOR", "Name_lang": "Warrior"},
        {"ID": "2", "Filename": "PALADIN", "Name_lang": "Paladin"},
        {"ID": "15", "Filename": "TRAVELER", "Name_lang": "Traveler"},
    ],
    "ChrSpecialization": [
        {"ID": "71", "ClassID": "1", "Name_lang": "Arms", "OrderIndex": "0"},
        {"ID": "72", "ClassID": "1", "Name_lang": "Fury", "OrderIndex": "1"},
        {"ID": "73", "ClassID": "1", "Name_lang": "Protection", "OrderIndex": "2"},
        {"ID": "65", "ClassID": "2", "Name_lang": "Holy", "OrderIndex": "0"},
        {"ID": "66", "ClassID": "1", "Name_lang": "Moved", "OrderIndex": "1"},
        {"ID": "74", "ClassID": "0", "Name_lang": "Ferocity", "OrderIndex": "0"},
    ],
}

FOREVER = {
    "Map": [
        {"ID": "36", "MapName_lang": "Deadmines", "InstanceType": "1"},
        {"ID": "409", "MapName_lang": "Molten Core", "InstanceType": "2"},
        {"ID": "2959", "MapName_lang": "City of Dalaran", "InstanceType": "1"},
        {"ID": "3001", "MapName_lang": "The Shaper's Terrace", "InstanceType": "1"},
        {"ID": "469", "MapName_lang": "Blackwing Lair", "InstanceType": "2"},
        {"ID": "489", "MapName_lang": "Warsong Gulch", "InstanceType": "3"},
        {"ID": "4000", "MapName_lang": "An Arena", "InstanceType": "4"},
    ],
    "GroupFinderActivity": [
        {"ID": "1", "FullName_lang": "Deadmines", "MapID": "36"},
        {"ID": "2", "FullName_lang": "Molten Core", "MapID": "409"},
        {"ID": "3", "FullName_lang": "The Shaper's Terrace", "MapID": "3001"},
        {"ID": "4", "FullName_lang": "Blackwing Lair", "MapID": "469"},
        {"ID": "5", "FullName_lang": "Warsong Gulch", "MapID": "489"},
    ],
    "ChrClasses": [
        {"ID": "1", "Filename": "WARRIOR", "Name_lang": "Warrior"},
    ],
}


def gz_csv(path: Path, rows: list[dict]) -> None:
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=list(rows[0]))
    w.writeheader()
    w.writerows(rows)
    path.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(path, "wt", encoding="utf-8", newline="") as f:
        f.write(buf.getvalue())


def crlf(text: str) -> bytes:
    return text.replace("\n", "\r\n").encode("utf-8")


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.defaults = self.dir / "defaults"
        self.defaults.mkdir()
        (self.defaults / "GameIds.lua").write_bytes(crlf(GAMEIDS))
        (self.defaults / "GameIds_Instances.lua").write_bytes(crlf(INSTANCES))
        (self.defaults / "GameIds_Clients.lua").write_bytes(crlf(CLIENTS))
        self.sentinels = {k: v["sentinels"] for k, v in seeds.FLAVORS.items()}
        for flavor in seeds.FLAVORS:
            seeds.FLAVORS[flavor]["sentinels"] = (("Map", "ID", "409", "InstanceType", "2"),)

    def tearDown(self):
        for flavor, value in self.sentinels.items():
            seeds.FLAVORS[flavor]["sentinels"] = value
        self.tmp.cleanup()

    def bundle(self, flavor: str, tables: dict) -> Path:
        bundle = self.dir / ("2026-11-15-" + flavor)
        for name, rows in tables.items():
            gz_csv(bundle / "raw" / (name + ".csv.gz"), rows)
        seeds.write_json(bundle / "candidates.json", {"flavor": flavor, "build": "1.2.3.4",
                                                      "buildCreated": None})
        return bundle

    def derive(self, flavor: str, tables: dict) -> tuple[dict, Path]:
        bundle = self.bundle(flavor, tables)
        doc = seeds.derive_bundle(flavor, bundle, "2026-11-15", None, True, self.dir / "cache", self.defaults)
        return doc, bundle

    def keys(self, doc):
        return set(seeds.all_keys(doc))


class TestParse(Fixture):
    def test_list_rows_and_comment_names(self):
        rows = seeds.read_list(self.defaults / "GameIds.lua", "G.DUNGEONS = {")
        self.assertEqual([r["id"] for r in rows], [2526, 658])
        self.assertEqual(rows[1]["name"], "Pit of Saron")
        rows = seeds.read_list(self.defaults / "GameIds_Clients.lua", "local FOREVER_DUNGEONS = {")
        self.assertEqual([r["id"] for r in rows], [36, 2959])

    def test_a_stray_line_fails(self):
        path = self.defaults / "GameIds.lua"
        path.write_bytes(crlf(GAMEIDS.replace("    658,", "    658 + 1,")))
        with self.assertRaises(SystemExit):
            seeds.read_list(path, "G.DUNGEONS = {")

    def test_classes_and_specs(self):
        self.assertEqual(seeds.read_classes(self.defaults / "GameIds.lua"), ["WARRIOR", "PALADIN"])
        self.assertEqual(seeds.read_specs(self.defaults / "GameIds.lua"), {"WARRIOR": [71, 72], "PALADIN": [65, 66]})


class TestDeriveRetail(Fixture):
    def test_candidates_and_flags(self):
        doc, _b = self.derive("retail", RETAIL)
        keys = self.keys(doc)
        self.assertIn("instances:700", keys)            # a journal dungeon not shipped
        self.assertNotIn("instances:757", keys)         # a world-boss entry is skipped
        self.assertIn("arenas:1505", keys)
        self.assertIn("classes:TRAVELER", keys)
        self.assertIn("specs:73", keys)
        self.assertNotIn("specs:74", keys)              # a pet spec: class 0 is no shipped class
        self.assertFalse([k for k in keys if k.startswith(("dungeons:", "raids:"))], "season lists are never proposed")
        for flag in ("shipped:renamed:instances:500", "shipped:unjournaled:instances:600",
                     "shipped:unlisted:instances:600", "shipped:gone:arenas:999", "shipped:kind:raids:2912",
                     "shipped:kind:specs:66", "shipped:unlisted:instances:33"):
            if flag == "shipped:unlisted:instances:33":
                self.assertNotIn(flag, keys)
            else:
                self.assertIn(flag, keys)
        self.assertNotIn("shipped:renamed:dungeons:658", keys)  # "(a note)" is stripped
        self.assertEqual((_b / "SOURCES.md").read_bytes().count(b"\r\n"),
                         (_b / "SOURCES.md").read_bytes().count(b"\n"))

    def test_thin_export_fails(self):
        seeds.FLAVORS["retail"]["sentinels"] = (("Map", "ID", "1", "InstanceType", "0"),)
        with self.assertRaises(SystemExit):
            self.derive("retail", RETAIL)

    def test_missing_column_fails(self):
        tables = dict(RETAIL, Map=[{k: v for k, v in r.items() if k != "InstanceType"} for r in RETAIL["Map"]])
        with self.assertRaises(SystemExit):
            self.derive("retail", tables)


class TestDeriveForever(Fixture):
    def test_group_finder_and_d4(self):
        doc, _b = self.derive("forever", FOREVER)
        keys = self.keys(doc)
        self.assertIn("dungeons:3001", keys)
        self.assertIn("raids:469", keys)
        self.assertNotIn("dungeons:489", keys)          # a battleground is no dungeon
        self.assertIn("arenas:4000", keys)              # D4: any arena map is proposed
        self.assertIn("shipped:unlisted:dungeons:2959", keys)
        # its own FOREVER_CLASSES (SF-QC-01), never Retail's G.CLASSES
        self.assertIn("shipped:gone:classes:MAGE", keys)
        self.assertNotIn("shipped:gone:classes:PALADIN", keys)
        self.assertFalse([k for k in keys if k.startswith("specs:")], "Forever reads its specs from the client")


class TestRulingsAndApply(Fixture):
    def rule_all(self, doc, accept=(), remove=()):
        rulings = {}
        for c in doc["candidates"]:
            seeds.set_ruling(rulings, doc["flavor"], c["key"], "accept" if c["key"] in accept else "reject", "why")
        for f in doc["flags"]:
            seeds.set_ruling(rulings, doc["flavor"], f["key"], "remove" if f["key"] in remove else "keep", "why")
        return rulings

    def test_apply_refuses_while_unruled(self):
        doc, _b = self.derive("retail", RETAIL)
        rulings = self.rule_all(doc)
        del rulings["instances:700"]
        before = (self.defaults / "GameIds_Instances.lua").read_bytes()
        with self.assertRaises(SystemExit):
            seeds.apply_bundle(doc, rulings, self.defaults)
        self.assertEqual((self.defaults / "GameIds_Instances.lua").read_bytes(), before)

    def test_apply_inserts_removes_keeps_crlf_and_is_idempotent(self):
        doc, _b = self.derive("retail", RETAIL)
        rulings = self.rule_all(doc, accept={"instances:700", "arenas:1505", "specs:73", "classes:TRAVELER"},
                                remove={"shipped:gone:arenas:999", "shipped:kind:specs:66"})
        changes = seeds.apply_bundle(doc, rulings, self.defaults)
        self.assertTrue(changes)
        inst = (self.defaults / "GameIds_Instances.lua").read_bytes()
        self.assertEqual(inst.count(b"\r\n"), inst.count(b"\n"))
        text = inst.decode()
        self.assertIn("    600,  -- Not In Journal\r\n    700,  -- Fresh Dungeon\r\n}", text)
        self.assertIn("    572,  -- Ruins of Lordaeron\r\n    1505,  -- Nagrand Arena\r\n}", text)
        self.assertNotIn("999", text)
        ids = (self.defaults / "GameIds.lua").read_bytes().decode()
        self.assertIn('G.CLASSES = { "WARRIOR", "PALADIN", "TRAVELER" }', ids)
        self.assertIn("WARRIOR = { 71, 72, 73 }, PALADIN = { 65 },", ids)
        snapshot = {p.name: p.read_bytes() for p in self.defaults.iterdir()}
        self.assertEqual(seeds.apply_bundle(doc, rulings, self.defaults), [])
        self.assertEqual({p.name: p.read_bytes() for p in self.defaults.iterdir()}, snapshot)

    def test_aligned_column_is_kept(self):
        doc, _b = self.derive("forever", FOREVER)
        rulings = self.rule_all(doc, accept={"dungeons:3001"})
        seeds.apply_bundle(doc, rulings, self.defaults)
        text = (self.defaults / "GameIds_Clients.lua").read_bytes().decode()
        self.assertIn("    2959, -- City of Dalaran\r\n    3001, -- The Shaper's Terrace\r\n}", text)

    def test_forever_classes_apply_to_their_own_list(self):
        doc, _b = self.derive("forever", FOREVER)
        before = (self.defaults / "GameIds.lua").read_bytes()
        rulings = self.rule_all(doc, remove={"shipped:gone:classes:MAGE"})
        self.assertEqual(seeds.apply_bundle(doc, rulings, self.defaults), ["GameIds_Clients.lua classes: -MAGE"])
        text = (self.defaults / "GameIds_Clients.lua").read_bytes().decode()
        self.assertIn('local FOREVER_CLASSES = { "WARRIOR" }', text)
        self.assertEqual((self.defaults / "GameIds.lua").read_bytes(), before, "Retail's CLASSES untouched")

    def test_hand_only_lists_refuse(self):
        doc, _b = self.derive("forever", FOREVER)
        rulings = self.rule_all(doc, accept={"arenas:4000"})
        with self.assertRaises(SystemExit):
            seeds.apply_bundle(doc, rulings, self.defaults)

    def test_set_ruling_validates(self):
        rulings = {}
        for key, ruling, reason in (("nolist:1", "accept", "x"), ("instances:1", "keep", "x"),
                                    ("shipped:gone:instances:1", "accept", "x"), ("instances:1", "accept", ""),
                                    ("shipped:odd:instances:1", "keep", "x"), ("specs:1", "accept", "x")):
            flavor = "forever" if key == "specs:1" else "retail"
            with self.assertRaises(SystemExit, msg=key):
                seeds.set_ruling(rulings, flavor, key, ruling, reason)
        seeds.set_ruling(rulings, "retail", "instances:1", "accept", " a reason ")
        self.assertEqual(rulings, {"instances:1": {"ruling": "accept", "reason": "a reason"}})

    def test_report_lists_rulings(self):
        doc, _b = self.derive("retail", RETAIL)
        md = seeds.rulings_md(doc, {}, "2026-11-15")
        self.assertIn("## Unruled: %d" % len(seeds.all_keys(doc)), md)


class TestStatusAndFetch(Fixture):
    def test_status_line(self):
        self.assertTrue(seeds.status_line("9.9", []).startswith("NEW 9.9"))
        b = self.bundle("retail", {})
        self.assertEqual(seeds.status_line("1.2.3.4", [b]), "CURRENT 1.2.3.4 (%s)" % b.name)
        self.assertTrue(seeds.status_line("1.2.3.5", [b]).startswith("NEW 1.2.3.5 (last ruled 1.2.3.4"))

    def test_fetch_pins_the_build_and_caches(self):
        calls = []

        class Response(io.BytesIO):
            def __init__(self, name):
                super().__init__(b"ID\n1\n")
                self.headers = {"Content-Disposition": 'attachment; filename="Map.%s.csv"' % name}

            def __exit__(self, *exc):
                return False

        real = seeds._open
        try:
            seeds._open = lambda url: calls.append(url) or Response("1.2.3.4")
            path = seeds.fetch_table("Map", "1.2.3.4", self.dir / "cache")
            self.assertEqual(path.read_bytes(), b"ID\n1\n")
            self.assertIn("?build=1.2.3.4", calls[0])
            seeds.fetch_table("Map", "1.2.3.4", self.dir / "cache")
            self.assertEqual(len(calls), 1, "a cached table is not fetched again")
            seeds._open = lambda url: Response("9.9.9.9")
            with self.assertRaises(SystemExit):
                seeds.fetch_table("Map", "1.2.3.5", self.dir / "cache")
        finally:
            seeds._open = real

    def test_rulings_files_are_well_formed(self):
        for flavor in seeds.FLAVORS:
            path = seeds.rulings_path(flavor)
            if not path.exists():
                continue
            data = json.loads(path.read_text(encoding="utf-8"))
            for key, row in data.items():
                seeds.set_ruling({}, flavor, key, row["ruling"], row["reason"])


if __name__ == "__main__":
    unittest.main()
