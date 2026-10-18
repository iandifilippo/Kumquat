#!/usr/bin/env python3
"""Fails if any L("…") string lacks a translation, or a table repeats a key
(a repeated key in a Swift dictionary literal crashes the app at launch)."""
import collections, pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent
loc = root / "Sources/Kumquat/Localization"
keys = set()
for f in (root / "Sources/Kumquat").rglob("*.swift"):
    keys |= set(re.findall(r'\bL\("((?:[^"\\]|\\.)*)"', f.read_text()))
# File-name suffixes are looked up too.
core = (root / "Sources/KumquatCore/Options.swift").read_text()
suffixes = set(re.findall(r'return "([^"]+)"', core.split("englishSuffix")[1].split("}\n    }")[0]))
keys |= suffixes

tables = {}
for f in sorted(loc.glob("Translations*.swift")):
    for name, body in re.findall(r'static let (\w+): \[String: String\] = \[(.*?)\n    \]', f.read_text(), re.S):
        tables[name] = re.findall(r'^\s*"((?:[^"\\]|\\.)*)":', body, re.M)

failed = False
for name, entries in sorted(tables.items()):
    dupes = [k for k, c in collections.Counter(entries).items() if c > 1]
    missing = sorted(keys - set(entries))
    if dupes:
        failed = True
        print(f"[{name}] repeated keys: {dupes}")
    if missing:
        failed = True
        print(f"[{name}] {len(missing)} missing:")
        for k in missing:
            print("  -", k)
if failed:
    sys.exit(1)
print(f"All {len(keys)} strings are translated in {len(tables)} languages: {', '.join(sorted(tables))}.")
