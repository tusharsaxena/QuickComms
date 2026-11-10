# tools/client_tables.py — used by tools/derive-gameids.py: fetch the
# client's own data tables as wago.tools exports them (CSV), and read one. Dev-only: never loaded by
# the client or the TOC, and .pkgmeta-ignored (layout-§1, "Where an authored generator lives").
# Python 3, standard library only.
import csv
import os
import re
import sys
import urllib.parse
import urllib.request

URL = "https://wago.tools/db2/{}/csv"


def fail(msg):
    """Stop loudly: a thin or partial derivation must never look like a result."""
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def fetch(directory, tables, build=None):
    """Download each table into `directory` (made new; it must not already hold files). Answers the
    client build the export names (from its Content-Disposition file name). Every table must name
    one, and the same one: a table with no build, or another build, fails. With `build`, each table
    is asked for at that build (`?build=`, how wago.tools serves a product that is not Retail's
    latest, such as WoW Forever's `wowf`), and an export of any other build fails."""
    os.makedirs(directory, exist_ok=True)
    if os.listdir(directory):
        fail(directory + " is not empty: give --fetch a new directory")
    pinned = build
    for t in tables:
        url = URL.format(t) + ("?build=" + urllib.parse.quote(pinned) if pinned else "")
        req = urllib.request.Request(url, headers={"User-Agent": "QuickComms-tools"})
        with urllib.request.urlopen(req, timeout=120) as r:
            m = re.search(r'filename="[^.]+\.([0-9.]+)\.csv"', r.headers.get("Content-Disposition") or "")
            if not m:
                fail(t + "'s export names no client build (its Content-Disposition has none)")
            build = build or m.group(1)
            if m.group(1) != build:
                fail("{} is build {}, {} {}".format(t, m.group(1), "asked for" if pinned else "the others", build))
            with open(os.path.join(directory, t + ".csv"), "wb") as f:
                f.write(r.read())
    return build


def read(directory, table):
    path = os.path.join(directory, table + ".csv")
    if not os.path.isfile(path):
        fail("no " + path + ": run with --fetch first")
    with open(path, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        fail(path + " is empty")
    return rows
