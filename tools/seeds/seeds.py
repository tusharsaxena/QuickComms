#!/usr/bin/env python3
"""tools/seeds/seeds.py: re-validate QuickComms' game-id seed lists against one wago.tools build.

WHAT THIS IS
    The seed-validation tool `/dev-copilot:validate-seeds QuickComms <flavor>` runs, under the
    contract in docs/validate-seeds.md. A flavor is a client: `retail` reads wago.tools product
    `wow`, `forever` reads product `wowf`, each client's own tables and never a filtered copy of the
    other's (clients-§5, clients-§10). Every shipped id is checked against one pinned build, and what
    the build has that a list lacks is proposed. Each proposal and each flag needs a ruling, recorded
    as data in tools/seeds/<flavor>_rulings.json, keyed by list and id, never by build, so a re-run
    on a later build shows only what is new.

    The lists it reads (defaults/, the seed files' own headers are the precedent):
        retail   GameIds.lua           DUNGEONS, RAIDS (the season's: existence only), CLASSES, SPECS
                 GameIds_Instances.lua INSTANCES (every journal dungeon and raid), ARENAS
        forever  GameIds_Clients.lua   FOREVER_DUNGEONS, FOREVER_RAIDS (BY_CLIENT.forever; its
                                       INSTANCES is the two concatenated), FOREVER_CLASSES (its
                                       own class list since the 2026-11-25 split, SF-QC-01)

    Candidates (key `<list>:<id>`, ruled accept or reject), only where a mechanical rule exists:
        retail  instances  a JournalInstance on a party or raid map (Map InstanceType 1 or 2), its
                           world-boss bit (Flags & 2) clear: the header's own rule
                arenas     an arena map (InstanceType 4); the header's two legacy copies are ruled
                classes    a ChrClasses token CLASSES lacks
                specs      a ChrSpecialization row of a shipped class that SPECS lacks
        forever dungeons   a party map Forever's GroupFinderActivity lists (the forever-ids design's D5)
                raids      a raid map it lists
                arenas     any arena map Forever's Map holds (D4: none today)
                classes    a ChrClasses token FOREVER_CLASSES lacks
        DUNGEONS and RAIDS on Retail are the season's choice: checked, never proposed.

    Flags (key `shipped:<kind>:<list>:<id>`, ruled keep or remove), over every shipped id:
        gone         the build has no row for it (Map, ChrClasses, ChrSpecialization)
        renamed      its Map name disagrees with the name in the comment beside it
        kind         its instance type no longer fits the list, or a spec is another class's
        unjournaled  (retail instances) no Encounter Journal entry names the map
        unlisted     retail: no LFGDungeons row is on the map; forever: the group finder lists no
                     activity on it

THE STEPS (docs/validate-seeds.md has them per flavor)
    python3 -I tools/seeds/seeds.py status [--flavor retail|forever]
    python3 -I tools/seeds/seeds.py derive --flavor F --bundle B --date D [--build V] [--replay]
    python3 -I tools/seeds/seeds.py check  --bundle B
    python3 -I tools/seeds/seeds.py rule   --tsv FILE --bundle B
    python3 -I tools/seeds/seeds.py report --bundle B --date D
    python3 -I tools/seeds/seeds.py apply  --bundle B --date D

    `derive` pins one build (the client's newest live build, or --build), fetches each table at
    `?build=` with an identifying User-Agent, streams it into tools/seeds/.cache/<build>/ (git-ignored),
    and freezes the tables it read as the bundle's raw/*.csv.gz, with SOURCES.md and candidates.json.
    `--replay` re-derives from the bundle's raw/ alone. `rule` is the only writer of the rulings
    file. `check` exits 1 while anything is unruled. `report` writes RULINGS.md. `apply` refuses while
    anything is unruled, writes the accepted ids and the ruled removals into the seed files with
    their own line endings and layout, and changes nothing on a second run. The date is always an
    argument; nothing here reads the clock.

    Copied in shape from Aura Master's tools/spell-research/retail.py and sid_seeds.py (patterns,
    never an import across repos). Whether a shared helper should carry the build pin, the cache, the
    bundle and the rulings is LibKa0s#91.

Python 3.8+ and its standard library only. Dev-only: never loaded by the client, and .pkgmeta
ignores tools/.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import re
import shutil
import sys
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
DEFAULTS = ROOT / "defaults"
RESEARCH = ROOT / "docs" / "seed-research"
CACHE = HERE / ".cache"

BUILDS_URL = "https://wago.tools/api/builds"
TABLE_URL = "https://wago.tools/db2/{}/csv?build={}"
USER_AGENT = "QuickComms-seed-check"
CHUNK = 1 << 20
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

PARTY, RAID, ARENA = 1, 2, 4                 # Map.InstanceType
WORLD_BOSSES = 2                             # JournalInstance.Flags bit: a world-boss entry

# Per flavor: the wago product, the tables read (each with why), the columns each must carry, and
# sentinels from the game (not from this tool's output) that a thin export fails on.
FLAVORS = {
    "retail": {
        "product": "wow",
        "client": "Retail",
        "tables": (
            ("Map", "InstanceType and MapName_lang for every shipped map id; the arena candidates"),
            ("JournalInstance", "the Encounter Journal: INSTANCES' source and its candidates (Retail only)"),
            ("LFGDungeons", "the dungeon finder's rows by MapID: the `unlisted` flag"),
            ("ChrClasses", "the classFile tokens (Filename) and their class ids"),
            ("ChrSpecialization", "spec id to ClassID: SPECS"),
        ),
        "columns": {
            "Map": ("ID", "MapName_lang", "InstanceType"),
            "JournalInstance": ("ID", "Name_lang", "MapID", "Flags"),
            "LFGDungeons": ("ID", "Name_lang", "MapID"),
            "ChrClasses": ("ID", "Filename", "Name_lang"),
            "ChrSpecialization": ("ID", "ClassID", "Name_lang", "OrderIndex"),
        },
        # (table, id column, id, column, value)
        "sentinels": (
            ("Map", "ID", "409", "InstanceType", "2"),           # Molten Core, a raid
            ("Map", "ID", "36", "InstanceType", "1"),            # Deadmines, a dungeon
            ("Map", "ID", "572", "InstanceType", "4"),           # Ruins of Lordaeron, an arena
            ("JournalInstance", "MapID", "409", "Name_lang", "Molten Core"),
            ("ChrClasses", "ID", "1", "Filename", "WARRIOR"),
            ("ChrSpecialization", "ID", "71", "ClassID", "1"),   # Arms
        ),
    },
    "forever": {
        "product": "wowf",
        "client": "WoW Forever",
        "tables": (
            ("Map", "InstanceType and MapName_lang for every shipped map id; the arena check (D4)"),
            ("GroupFinderActivity", "the group finder's activities by MapID: the lists' source (D5)"),
            ("ChrClasses", "the classFile tokens (Filename) Forever has"),
        ),
        "columns": {
            "Map": ("ID", "MapName_lang", "InstanceType"),
            "GroupFinderActivity": ("ID", "FullName_lang", "MapID"),
            "ChrClasses": ("ID", "Filename", "Name_lang"),
        },
        "sentinels": (
            ("Map", "ID", "409", "InstanceType", "2"),           # Molten Core
            ("Map", "ID", "36", "InstanceType", "1"),            # Deadmines
            ("GroupFinderActivity", "MapID", "409", "MapID", "409"),
            ("ChrClasses", "ID", "1", "Filename", "WARRIOR"),
        ),
    },
}

# The seed lists: (flavor, list) -> how to find and write it. `want` is the Map instance types the
# list admits; `sorted` lists keep ascending ids, so an insert lands in place.
LISTS = {
    ("retail", "dungeons"): {"file": "GameIds.lua", "start": "G.DUNGEONS = {", "want": (PARTY,),
                             "season": True},
    ("retail", "raids"): {"file": "GameIds.lua", "start": "G.RAIDS = {", "want": (RAID,), "season": True},
    ("retail", "instances"): {"file": "GameIds_Instances.lua", "start": "G.INSTANCES = {",
                              "want": (PARTY, RAID), "sorted": True},
    ("retail", "arenas"): {"file": "GameIds_Instances.lua", "start": "G.ARENAS = {", "want": (ARENA,),
                           "sorted": True},
    ("forever", "dungeons"): {"file": "GameIds_Clients.lua", "start": "local FOREVER_DUNGEONS = {",
                              "want": (PARTY,)},
    ("forever", "raids"): {"file": "GameIds_Clients.lua", "start": "local FOREVER_RAIDS = {",
                           "want": (RAID,)},
}
# Each flavor's class list: (file, the declaration before `= {`). Forever's is its own since the
# 2026-11-25 split (SF-QC-01, owner ruling "split per client"). SPECS is Retail's alone.
CLASSES = {"retail": ("GameIds.lua", "G.CLASSES"), "forever": ("GameIds_Clients.lua", "local FOREVER_CLASSES")}
SPECS_FILE = "GameIds.lua"
LIST_KEYS = {
    "retail": ("dungeons", "raids", "instances", "arenas", "classes", "specs"),
    "forever": ("dungeons", "raids", "arenas", "classes"),
}
# Lists whose accepted candidates or removals need a hand change (a new per-client table): apply
# refuses rather than guess.
HAND_ONLY = {("forever", "arenas")}

CANDIDATE_RULINGS = ("accept", "reject")
FLAG_RULINGS = ("keep", "remove")
FLAG_KINDS = ("gone", "renamed", "kind", "unjournaled", "unlisted")
KEY = re.compile(r"^(?:shipped:(?P<kind>[a-z]+):)?(?P<list>[a-z]+):(?P<id>\w+)$")


def fail(msg: str) -> None:
    """Stop loudly: a thin or partial derivation must never look like a result."""
    raise SystemExit("FAIL: " + msg)


def log(msg: str) -> None:
    print(msg, file=sys.stderr)


# ---------------------------------------------------------------------------
# Files: bytes in, bytes out, line endings kept
# ---------------------------------------------------------------------------

def read_text(path: Path) -> tuple[str, str]:
    """`(text with LF, the file's terminator)`: CRLF when the file has one, else LF."""
    raw = path.read_bytes().decode("utf-8")
    eol = "\r\n" if "\r\n" in raw else "\n"
    return raw.replace("\r\n", "\n"), eol


def write_text(path: Path, text: str, eol: str = "\n") -> None:
    """Write `text` (LF inside) with terminator `eol`, as bytes, so no platform default applies."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.replace("\r\n", "\n").replace("\n", eol).encode("utf-8"))


def repo_eol(path: Path) -> str:
    """The terminator .gitattributes pins for a new file: LF for .py and .sh, CRLF otherwise."""
    return "\n" if path.suffix in (".py", ".sh") else "\r\n"


def write_json(path: Path, doc) -> None:
    write_text(path, json.dumps(doc, indent=1, sort_keys=True, ensure_ascii=False) + "\n", repo_eol(path))


# ---------------------------------------------------------------------------
# wago.tools: one build, cached, streamed
# ---------------------------------------------------------------------------

def _open(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    return urllib.request.urlopen(req, timeout=180)


def live_build(product: str) -> dict:
    """The product's newest build the builds API lists that is not a background download."""
    with _open(BUILDS_URL) as r:
        builds = json.load(r)
    for b in builds.get(product) or ():
        if not b.get("is_bgdl"):
            return b
    fail("the builds API lists no live build for product " + product)
    return {}


def fetch_table(table: str, build: str, cache: Path) -> Path:
    """The table's CSV at `build`, from the cache or streamed into it. The export must name the
    build asked for (its Content-Disposition), or the run fails."""
    path = cache / build / (table + ".csv")
    if path.exists():
        return path
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".part")
    with _open(TABLE_URL.format(table, urllib.parse.quote(build))) as r:
        named = re.search(r'filename="[^"]*?\.([0-9.]+)\.csv"', r.headers.get("Content-Disposition") or "")
        if not named or named.group(1) != build:
            fail("%s's export is not build %s (Content-Disposition %r)"
                 % (table, build, r.headers.get("Content-Disposition")))
        with tmp.open("wb") as f:
            shutil.copyfileobj(r, f, CHUNK)
    tmp.replace(path)
    return path


def freeze(source: Path, member: Path) -> None:
    member.parent.mkdir(parents=True, exist_ok=True)
    with source.open("rb") as src, member.open("wb") as out:
        with gzip.GzipFile(filename="", mode="wb", fileobj=out, compresslevel=9, mtime=0) as dst:
            shutil.copyfileobj(src, dst, CHUNK)


def read_rows(member: Path, columns) -> list[dict]:
    """A frozen table's rows, streamed. Every column named must be in the header."""
    with gzip.open(member, "rt", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        missing = [c for c in columns if c not in (reader.fieldnames or ())]
        if missing:
            fail("%s has no column %s" % (member.name, ", ".join(missing)))
        rows = [{c: row[c] for c in columns} for row in reader]
    if not rows:
        fail(member.name + " is empty")
    return rows


# ---------------------------------------------------------------------------
# The seed files
# ---------------------------------------------------------------------------

LINE = re.compile(r"^(?P<indent>\s*)(?P<id>\d+),(?P<gap>\s*)--\s*(?P<comment>.*?)\s*$")


def _block(text: str, start: str, path: Path) -> tuple[int, int]:
    """`(first body line, closing line)` indexes of the line-per-id table opening on `start`."""
    lines = text.split("\n")
    for i, line in enumerate(lines):
        if line.strip() == start:
            for j in range(i + 1, len(lines)):
                if lines[j].strip() == "}":
                    return i + 1, j
            break
    fail("no '%s' table in %s" % (start, path))
    return 0, 0


def comment_name(comment: str) -> str:
    """The name in a comment, its trailing parenthesised note stripped: `Scarlet Monastery (D1)`."""
    return re.sub(r"\s*\(.*\)\s*$", "", comment).strip()


def read_list(path: Path, start: str) -> list[dict]:
    """Every `id, -- name` row of the table. A line that is neither a row, a comment nor blank
    fails, so no entry is skipped silently."""
    text, _eol = read_text(path)
    first, close = _block(text, start, path)
    rows = []
    for line in text.split("\n")[first:close]:
        if not line.strip() or line.strip().startswith("--"):
            continue
        m = LINE.match(line)
        if not m:
            fail("%s: a line of '%s' is not `id, -- name`: %r" % (path.name, start, line))
        rows.append({"id": int(m.group("id")), "comment": m.group("comment"),
                     "name": comment_name(m.group("comment"))})
    ids = [r["id"] for r in rows]
    if len(set(ids)) != len(ids):
        fail("%s: '%s' lists an id twice" % (path.name, start))
    if not rows:
        fail("%s: '%s' is empty" % (path.name, start))
    return rows


def classes_re(decl: str):
    return re.compile(re.escape(decl) + r"\s*=\s*\{(?P<body>[^}]*)\}")


SPECS_RE = re.compile(r"G\.SPECS\s*=\s*\{(?P<body>.*?)\n\}", re.S)
SPEC_ENTRY = re.compile(r"(?P<token>[A-Z]+)\s*=\s*\{(?P<ids>[\d,\s]*)\}")


def read_classes(path: Path, decl: str = "G.CLASSES") -> list[str]:
    text, _eol = read_text(path)
    m = classes_re(decl).search(text)
    if not m or re.search(r'[^"A-Z,\s]', m.group("body")):
        fail("no %s = { \"TOKEN\", ... } of plain tokens in %s" % (decl, path.name))
    return re.findall(r'"([A-Z]+)"', m.group("body"))


def read_specs(path: Path) -> dict[str, list[int]]:
    text, _eol = read_text(path)
    m = SPECS_RE.search(text)
    if not m:
        fail("no G.SPECS table in " + path.name)
    body = m.group("body")
    out = {e.group("token"): [int(x) for x in re.findall(r"\d+", e.group("ids"))]
           for e in SPEC_ENTRY.finditer(body)}
    if SPEC_ENTRY.sub("", body).strip(" \n,"):
        fail("G.SPECS in %s holds something other than TOKEN = { ids }" % path.name)
    return out


def shipped(flavor: str, defaults: Path) -> dict:
    """Every list the flavor checks: `{list: rows}` for the map lists, plus classes (and specs)."""
    out = {}
    for (fl, key), spec in LISTS.items():
        if fl == flavor:
            out[key] = read_list(defaults / spec["file"], spec["start"])
    name, decl = CLASSES[flavor]
    out["classes"] = read_classes(defaults / name, decl)
    if flavor == "retail":
        out["specs"] = read_specs(defaults / SPECS_FILE)
    return out


# ---------------------------------------------------------------------------
# Derive: candidates and flags
# ---------------------------------------------------------------------------

def _flag(kind, key, ident, name, comment, why):
    return {"key": "shipped:%s:%s:%s" % (kind, key, ident), "kind": kind, "list": key, "id": ident,
            "name": name, "comment": comment, "why": why}


def _cand(key, ident, name, source, notes):
    return {"key": "%s:%s" % (key, ident), "list": key, "id": ident, "name": name, "source": source,
            "notes": notes}


def check_sentinels(flavor: str, tables: dict[str, list[dict]]) -> None:
    missing = []
    for table, idcol, ident, col, value in FLAVORS[flavor]["sentinels"]:
        if not any(r[idcol] == ident and r[col] == value for r in tables[table]):
            missing.append("%s %s=%s with %s=%s" % (table, idcol, ident, col, value))
    if missing:
        fail("%s sentinels missing (a thin or wrong export): %s" % (flavor, "; ".join(missing)))


def map_flags(key: str, rows: list[dict], want, maps: dict, journal: dict | None,
              listed: dict | None, listed_what: str) -> list[dict]:
    out = []
    for row in rows:
        ident, m = row["id"], maps.get(row["id"])
        if m is None:
            out.append(_flag("gone", key, ident, "", row["comment"], "the build's Map has no row %d" % ident))
            continue
        name, itype = m["MapName_lang"], int(m["InstanceType"])
        if row["name"].lower() != name.lower():
            out.append(_flag("renamed", key, ident, name, row["comment"],
                             "Map names it %r, the comment %r" % (name, row["name"])))
        if itype not in want:
            out.append(_flag("kind", key, ident, name, row["comment"],
                             "instance type %d, the list admits %s" % (itype, "/".join(map(str, want)))))
        if journal is not None and ident not in journal:
            out.append(_flag("unjournaled", key, ident, name, row["comment"],
                             "no JournalInstance entry (world bosses skipped) is on the map"))
        if listed is not None and ident not in listed:
            out.append(_flag("unlisted", key, ident, name, row["comment"], "no %s row is on the map" % listed_what))
    return out


def derive_retail(t: dict[str, list[dict]], seeds: dict) -> tuple[list, list]:
    maps = {int(r["ID"]): r for r in t["Map"]}
    journal: dict[int, list[str]] = {}
    for j in t["JournalInstance"]:
        mid = int(j["MapID"])
        if mid in maps and int(maps[mid]["InstanceType"]) in (PARTY, RAID) and not int(j["Flags"]) & WORLD_BOSSES:
            journal.setdefault(mid, []).append("%s %s" % (j["ID"], j["Name_lang"]))
    lfg: dict[int, list[str]] = {}
    for r in t["LFGDungeons"]:
        lfg.setdefault(int(r["MapID"]), []).append(r["Name_lang"])
    flags, cands = [], []
    for key in ("dungeons", "raids", "instances", "arenas"):
        spec = LISTS[("retail", key)]
        flags += map_flags(key, seeds[key], spec["want"], maps, journal if key == "instances" else None,
                           lfg if key != "arenas" else None, "LFGDungeons")
    have = {r["id"] for r in seeds["instances"]}
    for mid in sorted(journal):
        if mid not in have:
            cands.append(_cand("instances", mid, maps[mid]["MapName_lang"], "journal",
                               ["journal: " + "; ".join(journal[mid]),
                                "instance type %s" % maps[mid]["InstanceType"]]))
    have = {r["id"] for r in seeds["arenas"]}
    for mid in sorted(maps):
        if int(maps[mid]["InstanceType"]) == ARENA and mid not in have:
            cands.append(_cand("arenas", mid, maps[mid]["MapName_lang"], "map", ["instance type 4"]))
    flags_c, cands_c, class_id = class_checks(t["ChrClasses"], seeds["classes"])
    flags += flags_c
    cands += cands_c
    specs = {int(r["ID"]): r for r in t["ChrSpecialization"]}
    shipped_specs = {}
    for token, ids in seeds["specs"].items():
        for sid in ids:
            shipped_specs[sid] = token
            s = specs.get(sid)
            if s is None:
                flags.append(_flag("gone", "specs", sid, "", token, "ChrSpecialization has no row %d" % sid))
            elif class_id.get(token) != int(s["ClassID"]):
                flags.append(_flag("kind", "specs", sid, s["Name_lang"], token,
                                   "ChrSpecialization's class is %s, the list files it under %s"
                                   % (s["ClassID"], token)))
    by_id = {v: k for k, v in class_id.items()}
    for sid in sorted(specs):
        s = specs[sid]
        token = by_id.get(int(s["ClassID"]))
        if token in seeds["specs"] and sid not in shipped_specs:
            cands.append(_cand("specs", sid, s["Name_lang"], "chrspec",
                               ["class %s (%s)" % (s["ClassID"], token), "OrderIndex %s" % s["OrderIndex"]]))
    return cands, flags


def class_checks(rows: list[dict], tokens: list[str]) -> tuple[list, list, dict]:
    """`(flags, candidates, {token: class id})` for CLASSES against ChrClasses."""
    class_id = {r["Filename"]: int(r["ID"]) for r in rows}
    flags, cands = [], []
    for token in tokens:
        if token not in class_id:
            flags.append(_flag("gone", "classes", token, "", token, "ChrClasses has no Filename %s" % token))
    for r in sorted(rows, key=lambda r: int(r["ID"])):
        if r["Filename"] not in tokens:
            cands.append(_cand("classes", r["Filename"], r["Name_lang"], "chrclasses", ["class id " + r["ID"]]))
    return flags, cands, class_id


def derive_forever(t: dict[str, list[dict]], seeds: dict) -> tuple[list, list]:
    maps = {int(r["ID"]): r for r in t["Map"]}
    listed: dict[int, list[str]] = {}
    for r in t["GroupFinderActivity"]:
        listed.setdefault(int(r["MapID"]), []).append(r["FullName_lang"])
    flags, cands = [], []
    for key in ("dungeons", "raids"):
        spec = LISTS[("forever", key)]
        flags += map_flags(key, seeds[key], spec["want"], maps, None, listed, "GroupFinderActivity")
        have = {r["id"] for r in seeds[key]}
        for mid in sorted(listed):
            if mid in maps and int(maps[mid]["InstanceType"]) in spec["want"] and mid not in have:
                cands.append(_cand(key, mid, maps[mid]["MapName_lang"], "groupfinder",
                                   ["group finder: " + "; ".join(sorted(set(listed[mid])))]))
    for mid in sorted(maps):
        if int(maps[mid]["InstanceType"]) == ARENA:
            cands.append(_cand("arenas", mid, maps[mid]["MapName_lang"], "map", ["instance type 4 (D4)"]))
    flags_c, cands_c, _ids = class_checks(t["ChrClasses"], seeds["classes"])
    return cands + cands_c, flags + flags_c


def derive(flavor: str, tables: dict[str, list[dict]], seeds: dict) -> tuple[list, list]:
    check_sentinels(flavor, tables)
    cands, flags = (derive_retail if flavor == "retail" else derive_forever)(tables, seeds)
    order = {k: i for i, k in enumerate(LIST_KEYS[flavor])}

    def sort(row):
        ident = row["id"]
        return (order[row["list"]], row.get("kind", ""), (0, ident, "") if isinstance(ident, int) else (1, 0, ident))
    return sorted(cands, key=sort), sorted(flags, key=sort)


# ---------------------------------------------------------------------------
# Bundles
# ---------------------------------------------------------------------------

def load_candidates(bundle: Path) -> dict:
    path = bundle / "candidates.json"
    if not path.exists():
        fail("%s has no candidates.json: run derive first" % bundle)
    return json.loads(path.read_text(encoding="utf-8"))


def bundles(root: Path, flavor: str) -> list[Path]:
    """Every bundle of the flavor under `root`, oldest first (dates sort by name)."""
    return sorted(p for p in root.glob("*-" + flavor) if (p / "candidates.json").exists())


def status_line(live: str, found: list[Path]) -> str:
    """`CURRENT <build> (<bundle>)`, or `NEW <build> ...`: the first word is what the command reads."""
    if not found:
        return "NEW %s (no bundle yet)" % live
    built = load_candidates(found[-1])["build"]
    if built == live:
        return "CURRENT %s (%s)" % (live, found[-1].name)
    return "NEW %s (last ruled %s, %s)" % (live, built, found[-1].name)


def sources_md(doc: dict) -> str:
    fl = FLAVORS[doc["flavor"]]
    lines = ["# Sources: seed validation, %s, %s" % (doc["flavor"], doc["date"]), "",
             "Generated by `tools/seeds/seeds.py derive`. Frozen: never edited after the run.", "",
             "| Field | Value |", "| --- | --- |",
             "| Flavor | `%s` (%s, wago.tools product `%s`) |" % (doc["flavor"], fl["client"], fl["product"]),
             "| Build | `%s` |" % doc["build"],
             "| Build created (builds API) | %s |" % (doc.get("buildCreated") or "not recorded (pinned by --build)"),
             "| Run date | %s |" % doc["date"],
             "| Builds API | <%s> |" % BUILDS_URL,
             "| User-Agent | `%s` |" % USER_AGENT, "",
             "## Tables", "", "| Table | Why | URL |", "| --- | --- | --- |"]
    for table, why in fl["tables"]:
        lines.append("| `%s` | %s | <%s> |" % (table, why, TABLE_URL.format(table, doc["build"])))
    lines += ["", "The gzipped exports are in `raw/`, only the columns named in `tools/seeds/seeds.py` "
              "are read. Replay offline with `derive --replay`.", "",
              "## Counts", "",
              "%d shipped ids checked, %d candidates, %d flags." % (doc["checked"], len(doc["candidates"]),
                                                                    len(doc["flags"])), ""]
    return "\n".join(lines)


def derive_bundle(flavor: str, bundle: Path, date: str, build: str | None, replay: bool,
                  cache: Path, defaults: Path) -> dict:
    fl = FLAVORS[flavor]
    raw = bundle / "raw"
    created = None
    if replay:
        doc = load_candidates(bundle)
        if doc["flavor"] != flavor:
            fail("%s is a %s bundle" % (bundle, doc["flavor"]))
        build, created = doc["build"], doc.get("buildCreated")
    elif build is None:
        b = live_build(fl["product"])
        build, created = b["version"], b.get("created_at")
    tables = {}
    for table, _why in fl["tables"]:
        member = raw / (table + ".csv.gz")
        if not replay:
            freeze(fetch_table(table, build, cache), member)
        elif not member.exists():
            fail("--replay: %s has no raw/%s.csv.gz" % (bundle, table))
        tables[table] = read_rows(member, fl["columns"][table])
    seeds = shipped(flavor, defaults)
    cands, flags = derive(flavor, tables, seeds)
    checked = sum(len(v) if isinstance(v, list) else sum(len(x) for x in v.values()) for v in seeds.values())
    doc = {"flavor": flavor, "product": fl["product"], "build": build, "buildCreated": created, "date": date,
           "tool": "tools/seeds/seeds.py derive", "checked": checked,
           "counts": {k: len(seeds[k]) if isinstance(seeds[k], list) else sum(len(x) for x in seeds[k].values())
                      for k in seeds},
           "candidates": cands, "flags": flags}
    write_json(bundle / "candidates.json", doc)
    write_text(bundle / "SOURCES.md", sources_md(doc), "\r\n")
    return doc


# ---------------------------------------------------------------------------
# Rulings
# ---------------------------------------------------------------------------

def rulings_path(flavor: str, here: Path = HERE) -> Path:
    return here / ("%s_rulings.json" % flavor)


def load_rulings(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def all_keys(doc: dict) -> list[str]:
    return [c["key"] for c in doc["candidates"]] + [f["key"] for f in doc["flags"]]


def unruled(doc: dict, rulings: dict) -> list[str]:
    return [k for k in all_keys(doc) if k not in rulings]


def set_ruling(rulings: dict, flavor: str, key: str, ruling: str, reason: str) -> None:
    m = KEY.match(key)
    if not m or m.group("list") not in LIST_KEYS[flavor]:
        fail("key %r is not <list>:<id> or shipped:<kind>:<list>:<id> for %s" % (key, flavor))
    kind = m.group("kind")
    if kind and kind not in FLAG_KINDS:
        fail("key %r: unknown flag kind %r" % (key, kind))
    allowed = FLAG_RULINGS if kind else CANDIDATE_RULINGS
    if ruling not in allowed:
        fail("ruling for %s must be %s; got %r" % (key, " or ".join(allowed), ruling))
    reason = (reason or "").strip()
    if not reason or "\n" in reason:
        fail("reason for %s must be one non-empty line" % key)
    rulings[key] = {"ruling": ruling, "reason": reason}


def read_tsv(path: Path) -> list[tuple[str, str, str]]:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            fail("%s: a ruling line is key<TAB>ruling<TAB>reason; got %r" % (path, line))
        out.append((parts[0].strip(), parts[1].strip(), parts[2].strip()))
    return out


# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------

def _row_line(lines: list[str], ident: int, name: str) -> str:
    """A new `id, -- name` line in the layout of the block's own rows: the same indent, and the
    comment at the rows' shared column when they align on one, else after the gap they share."""
    rows = [LINE.match(x) for x in lines]
    rows = [m for m in rows if m]
    indent = rows[0].group("indent") if rows else "    "
    cols = {len(m.group("indent")) + len(m.group("id")) + 1 + len(m.group("gap")) for m in rows}
    gaps = {m.group("gap") for m in rows}
    head = "%s%d," % (indent, ident)
    if len(cols) == 1 and len(gaps) > 1:
        head = head.ljust(cols.pop() - 1) + " "
    else:
        head += gaps.pop() if len(gaps) == 1 else "  "
    return "%s-- %s" % (head, name)


def edit_list(text: str, start: str, path: Path, add: list[tuple[int, str]], drop: set[int],
              keep_sorted: bool) -> tuple[str, list[str]]:
    lines = text.split("\n")
    first, close = _block(text, start, path)
    body = lines[first:close]
    changes = []
    out = []
    for line in body:
        m = LINE.match(line)
        if m and int(m.group("id")) in drop:
            changes.append("-%s" % m.group("id"))
            continue
        out.append(line)
    present = {int(m.group("id")) for m in map(LINE.match, out) if m}
    for ident, name in add:
        if ident in present:
            continue
        new = _row_line(out, ident, name)
        at = len(out)
        if keep_sorted:
            for i, line in enumerate(out):
                m = LINE.match(line)
                if m and int(m.group("id")) > ident:
                    at = i
                    break
        out.insert(at, new)
        present.add(ident)
        changes.append("+%d" % ident)
    return "\n".join(lines[:first] + out + lines[close:]), changes


def edit_classes(text: str, add: list[str], drop: set[str], decl: str = "G.CLASSES") -> tuple[str, list[str]]:
    m = classes_re(decl).search(text)
    tokens = re.findall(r'"([A-Z]+)"', m.group("body"))
    changes = ["-" + t for t in tokens if t in drop] + ["+" + t for t in add if t not in tokens]
    if not changes:
        return text, []
    body = m.group("body")
    for t in drop:
        body = re.sub(r'\s*"%s",' % t, "", body) if re.search(r'"%s",' % t, body) else \
            re.sub(r',\s*"%s"' % t, "", body)
    for t in add:
        if t not in tokens:
            body = body.rstrip() + ', "%s" ' % t
    return text[:m.start("body")] + body + text[m.end("body"):], changes


def edit_specs(text: str, add: dict[str, list[int]], drop: set[int]) -> tuple[str, list[str]]:
    m = SPECS_RE.search(text)
    changes = []

    def one(e):
        ids = [int(x) for x in re.findall(r"\d+", e.group("ids"))]
        keep = [i for i in ids if i not in drop]
        changes.extend("-%d" % i for i in ids if i in drop)
        new = [i for i in add.get(e.group("token"), ()) if i not in keep]
        changes.extend("+%d" % i for i in new)
        if keep == ids and not new:
            return e.group(0)
        return "%s = { %s }" % (e.group("token"), ", ".join(str(i) for i in keep + new))
    body = SPEC_ENTRY.sub(one, m.group("body"))
    return text[:m.start("body")] + body + text[m.end("body"):], changes


def plan(doc: dict, rulings: dict) -> tuple[list[dict], list[dict]]:
    """`(accepted candidates, flags ruled remove)`; refuses while anything is unruled, and on a
    list that needs a hand change."""
    left = unruled(doc, rulings)
    if left:
        fail("apply refused: %d key(s) unruled (check lists them)" % len(left))
    adds = [c for c in doc["candidates"] if rulings[c["key"]]["ruling"] == "accept"]
    drops = [f for f in doc["flags"] if rulings[f["key"]]["ruling"] == "remove"]
    for row in adds + drops:
        if (doc["flavor"], row["list"]) in HAND_ONLY:
            fail("apply refused: %s needs a hand change (docs/validate-seeds.md, Rules)" % row["key"])
    return adds, drops


def apply_bundle(doc: dict, rulings: dict, defaults: Path) -> list[str]:
    flavor = doc["flavor"]
    adds, drops = plan(doc, rulings)
    log_lines = []
    files: dict[str, tuple[str, str]] = {}

    def text_of(name):
        if name not in files:
            files[name] = read_text(defaults / name)
        return files[name][0]

    for (fl, key), spec in LISTS.items():
        if fl != flavor:
            continue
        add = [(c["id"], c["name"]) for c in adds if c["list"] == key]
        drop = {f["id"] for f in drops if f["list"] == key}
        if not add and not drop:
            continue
        new, ch = edit_list(text_of(spec["file"]), spec["start"], defaults / spec["file"], add, drop,
                            bool(spec.get("sorted")))
        files[spec["file"]] = (new, files[spec["file"]][1])
        if ch:
            log_lines.append("%s %s: %s" % (spec["file"], key, " ".join(ch)))
    add_c = [c["id"] for c in adds if c["list"] == "classes"]
    drop_c = {f["id"] for f in drops if f["list"] == "classes"}
    if add_c or drop_c:
        name, decl = CLASSES[flavor]
        new, ch = edit_classes(text_of(name), add_c, drop_c, decl)
        files[name] = (new, files[name][1])
        if ch:
            log_lines.append("%s classes: %s" % (name, " ".join(ch)))
    add_s: dict[str, list[int]] = {}
    for c in adds:
        if c["list"] == "specs":
            token = re.search(r"\((\w+)\)", c["notes"][0]).group(1)
            add_s.setdefault(token, []).append(c["id"])
    drop_s = {f["id"] for f in drops if f["list"] == "specs"}
    if add_s or drop_s:
        new, ch = edit_specs(text_of(SPECS_FILE), add_s, drop_s)
        files[SPECS_FILE] = (new, files[SPECS_FILE][1])
        if ch:
            log_lines.append("%s specs: %s" % (SPECS_FILE, " ".join(ch)))
    for name, (text, eol) in files.items():
        before, _ = read_text(defaults / name)
        if text != before:
            write_text(defaults / name, text, eol)
    return log_lines


# ---------------------------------------------------------------------------
# RULINGS.md
# ---------------------------------------------------------------------------

def _cell(text) -> str:
    return str(text if text is not None else "").replace("|", "\\|")


def rulings_md(doc: dict, rulings: dict, date: str) -> str:
    tally: dict[str, int] = {}
    for k in all_keys(doc):
        r = rulings.get(k, {}).get("ruling", "unruled")
        tally[r] = tally.get(r, 0) + 1
    lines = ["# Rulings: seed validation, %s, %s (build %s)" % (doc["flavor"], doc["date"], doc["build"]), "",
             "Generated by `tools/seeds/seeds.py report` on %s from this bundle's `candidates.json` and "
             "`tools/seeds/%s_rulings.json`. Do not edit by hand." % (date, doc["flavor"]), "",
             "%d shipped ids checked; %d candidates, %d flags: %s." % (
                 doc["checked"], len(doc["candidates"]), len(doc["flags"]),
                 ", ".join("%d %s" % (n, r) for r, n in sorted(tally.items())) or "none"), ""]
    left = unruled(doc, rulings)
    if left:
        lines += ["## Unruled: %d" % len(left), ""] + ["- `%s`" % k for k in left] + [""]
    lines += ["## Candidates", ""]
    if not doc["candidates"]:
        lines += ["None.", ""]
    for key in LIST_KEYS[doc["flavor"]]:
        rows = [c for c in doc["candidates"] if c["list"] == key]
        if not rows:
            continue
        lines += ["### %s: %d" % (key, len(rows)), "", "| Id | Name | Source | Notes | Ruling | Reason |",
                  "| --- | --- | --- | --- | --- | --- |"]
        for c in rows:
            r = rulings.get(c["key"], {})
            lines.append("| `%s` | %s | %s | %s | %s | %s |" % (
                c["id"], _cell(c["name"]), c["source"], _cell("; ".join(c["notes"])),
                r.get("ruling", "**unruled**"), _cell(r.get("reason", ""))))
        lines.append("")
    lines += ["## Shipped-id flags: %d" % len(doc["flags"]), ""]
    if doc["flags"]:
        lines += ["| Kind | List | Id | Build name | File comment | Why | Ruling | Reason |",
                  "| --- | --- | --- | --- | --- | --- | --- | --- |"]
        for f in doc["flags"]:
            r = rulings.get(f["key"], {})
            lines.append("| %s | %s | `%s` | %s | %s | %s | %s | %s |" % (
                f["kind"], f["list"], f["id"], _cell(f["name"]), _cell(f["comment"]), _cell(f["why"]),
                r.get("ruling", "**unruled**"), _cell(r.get("reason", ""))))
    else:
        lines.append("None.")
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def _date(value: str) -> str:
    if not DATE_RE.match(value):
        raise argparse.ArgumentTypeError("a date is YYYY-MM-DD; got %r" % value)
    return value


def cmd_status(args) -> int:
    for flavor in ([args.flavor] if args.flavor else list(FLAVORS)):
        line = status_line(live_build(FLAVORS[flavor]["product"])["version"], bundles(args.root, flavor))
        print(line if args.flavor else "%s: %s" % (flavor, line))
    return 0


def cmd_derive(args) -> int:
    doc = derive_bundle(args.flavor, args.bundle, args.date, args.build, args.replay, args.cache_dir,
                        args.defaults)
    left = unruled(doc, load_rulings(args.rulings or rulings_path(args.flavor)))
    for key in LIST_KEYS[args.flavor]:
        log("  %-10s %3d shipped, %d candidates, %d flags" % (
            key, doc["counts"].get(key, 0), sum(c["list"] == key for c in doc["candidates"]),
            sum(f["list"] == key for f in doc["flags"])))
    log("%s build %s: %d shipped ids checked, %d candidates, %d flags, %d unruled" % (
        args.flavor, doc["build"], doc["checked"], len(doc["candidates"]), len(doc["flags"]), len(left)))
    return 0


def _bundle_rulings(args) -> tuple[dict, Path]:
    doc = load_candidates(args.bundle)
    return doc, args.rulings or rulings_path(doc["flavor"])


def cmd_rule(args) -> int:
    doc, path = _bundle_rulings(args)
    known = set(all_keys(doc))
    rulings = load_rulings(path)
    todo = read_tsv(args.tsv)
    if not todo:
        fail("%s holds no ruling" % args.tsv)
    for key, ruling, reason in todo:
        if key not in known:
            fail("%s is not a candidate or flag in %s/candidates.json" % (key, args.bundle))
        set_ruling(rulings, doc["flavor"], key, ruling, reason)
    write_text(path, json.dumps(rulings, indent=2, sort_keys=True, ensure_ascii=False) + "\n", "\r\n")
    log("Recorded %d ruling(s) in %s" % (len(todo), path))
    return 0


def cmd_check(args) -> int:
    doc, path = _bundle_rulings(args)
    left = unruled(doc, load_rulings(path))
    if not left:
        print("OK: every candidate and flag in %s is ruled." % args.bundle.name)
        return 0
    rows = {r["key"]: r for r in doc["candidates"] + doc["flags"]}
    print("%d unruled:" % len(left))
    for key in left:
        print("  %s  %s [%s]" % (key, rows[key]["name"], rows[key].get("source") or rows[key].get("why")))
    return 1


def cmd_report(args) -> int:
    doc, path = _bundle_rulings(args)
    write_text(args.bundle / "RULINGS.md", rulings_md(doc, load_rulings(path), args.date), "\r\n")
    log("Wrote %s" % (args.bundle / "RULINGS.md"))
    return 0


def cmd_apply(args) -> int:
    doc, path = _bundle_rulings(args)
    changes = apply_bundle(doc, load_rulings(path), args.defaults)
    for line in changes:
        log("  " + line)
    log("%d change(s) to defaults/ (%s, build %s, %s)" % (len(changes), doc["flavor"], doc["build"], args.date))
    return 0


def parse_args(argv):
    p = argparse.ArgumentParser(description="Re-validate QuickComms' game-id seeds against a wago.tools build.",
                                epilog="The contract: docs/validate-seeds.md.")
    p.add_argument("--rulings", type=Path, default=None, help="the rulings file (default: per flavor)")
    p.add_argument("--defaults", type=Path, default=DEFAULTS, help="the seed files' folder")
    p.add_argument("--cache-dir", type=Path, default=CACHE, help="the per-build download cache")
    sub = p.add_subparsers(dest="command", required=True)
    s = sub.add_parser("status", help="is there a live build newer than the newest bundle?")
    s.add_argument("--flavor", choices=sorted(FLAVORS))
    s.add_argument("--root", type=Path, default=RESEARCH, help="where the bundles are")
    d = sub.add_parser("derive", help="fetch or replay the tables; write raw/, SOURCES.md, candidates.json")
    d.add_argument("--flavor", choices=sorted(FLAVORS), required=True)
    d.add_argument("--bundle", type=Path, required=True)
    d.add_argument("--date", type=_date, required=True)
    d.add_argument("--build", default=None, help="pin this build instead of the live one")
    d.add_argument("--replay", action="store_true", help="read only the bundle's raw/, no network")
    r = sub.add_parser("rule", help="record rulings (the only writer of the rulings file)")
    r.add_argument("--tsv", type=Path, required=True, help="key<TAB>ruling<TAB>reason lines")
    r.add_argument("--bundle", type=Path, required=True)
    for name, helptext in (("check", "exit 1 while anything is unruled"),
                           ("report", "write the bundle's RULINGS.md"),
                           ("apply", "write accepted ids and ruled removals into defaults/")):
        c = sub.add_parser(name, help=helptext)
        c.add_argument("--bundle", type=Path, required=True)
        if name != "check":
            c.add_argument("--date", type=_date, required=True)
    args = p.parse_args(argv)
    if getattr(args, "replay", False) and args.build:
        p.error("--replay takes the build from the bundle; drop --build")
    return args


def main(argv=None) -> int:
    args = parse_args(argv)
    return {"status": cmd_status, "derive": cmd_derive, "rule": cmd_rule, "check": cmd_check,
            "report": cmd_report, "apply": cmd_apply}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
